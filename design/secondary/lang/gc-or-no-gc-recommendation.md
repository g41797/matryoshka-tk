# GC or no GC

A recommendation for applications built on Matryoshka in D.

This is guidance for application developers. The toolkit itself allocates no
application items and works under either choice.

---

## The recommendation

Three lines:

1. **Pick one mode for the whole application. GC or no GC. Never mixed.**
2. **Default to GC. Use `new` for items, mailboxes and pools.**
3. **Use a pool for anything sent at rate. That is what keeps the GC quiet.**

If you follow those three, nothing else in this document is required reading.

---

## Why one mode, and never mixed

There are three configurations. Two work. One does not, and it is the one that
looks reasonable.

| items | toolkit | verdict |
|---|---|---|
| `new` | `new` | works — no rules |
| `malloc` | `malloc` | works — five rules |
| `new` | `malloc` | **broken** |

The broken one fails because an item in flight is reachable only through the
mailbox's list:

```text
sender                mailbox                receiver

Slot ── null    ──►   [item] [item]   ──►   Slot ── null
                        ▲
                        │
              the only reference in the program
```

If the mailbox is `malloc`'d, the collector never sees that reference. It can
free an item that is queued and waiting.

This cannot be fixed inside the toolkit. `GC.addRange` needs the concrete type,
and `ItemHandle` is a type-erased `PolyNode*`. The type is gone by then.

So: one mode, decided once, at the start of the project.

---

## The default: a GC application

Allocate everything the normal D way.

```d
auto req = new Request;
auto mbx = new Mbox(...);
auto pool = new Pool(...);
```

Rules you must follow: none, beyond the one below that applies to every mode.

Item structs may hold anything:

```d
struct Request
{
    PolyNode poly;
    uint id;
    ubyte[] data;        // fine
    string name;         // fine
    void delegate() cb;  // fine
}
```

Threads: use `std.concurrency` or `core.thread`. Both are attached to druntime
already.

Hooks: `nothrow`. That is the one rule. See below.

### Why this is the default

Most applications are not pause-sensitive. The ones that are usually know it,
with a number attached.

The no-GC mode costs real discipline — five rules, every one of them silent
when broken. That price is worth paying when you have a latency budget. It is
not worth paying speculatively.

### The pool is what makes this work

A GC application that allocates a `Request` per message generates garbage at
message rate. Collections follow.

A GC application that gets a `Request` from a pool and puts it back allocates
only while the pool is warming up. In steady state it allocates nothing, and
collections become rare.

```text
no pool     alloc per message   →   collections at message rate
pool        alloc until warm    →   collections approach zero
```

This is most of the benefit of no-GC mode, without any of the rules. It is the
single highest-value thing you can do, and it is the reason a pool exists.

Pool anything sent at rate. Do not pool the things you create once.

---

## When to leave the default

Three signals. Any one of them is enough. Nothing else is.

**1. You have a measured tail-latency budget the GC violates.**

Measured. Not assumed. Run the GC version, measure p99, compare against the
budget. D's GC is stop-the-world, so the pause lands on every thread — including
a receiver blocked in `receive`.

**2. You are targeting `-betterC`, or an embedded target with no runtime.**

Then the choice is already made for you.

**3. You are a shared library loaded into a host that does not own druntime.**

A plugin, a native extension, a C application calling into your code. Running a
GC inside someone else's process is a decision you should not make on their
behalf.

That is the whole list. "It feels wasteful" is not on it.

---

## The other mode: a no-GC application

Five rules. All of them are silent when broken, which is why the default is the
default.

**1. Allocate items and toolkit objects the same way.**

`malloc`/`free`, or one allocator, used for both. Never `new` for one and
`malloc` for the other.

**2. Keep GC references out of item structs.**

A `malloc`'d item is not scanned. Any GC-allocated thing it points at is
collectable while the item still points at it.

```d
struct Request
{
    PolyNode poly;
    uint id;

    ubyte[] data;        // NO  — if the slice is GC-allocated
    ubyte* ptr;          // yes
    size_t len;          // yes
    char[64] name;       // yes
    void function() cb;  // yes — a function pointer, not a delegate
}
```

If you must hold GC memory in a `malloc`'d item, call `GC.addRange` in `on_get`
and `GC.removeRange` in `on_put` and `on_close`. Your hook knows the concrete
type, so unlike the toolkit, it can do this. Expect to pay the GC lock per call.

**3. Attach every thread druntime did not create.**

A thread from `pthread_create`, from a C library, from your own reactor:

```d
thread_attachThis();
scope(exit) thread_detachThis();
```

An unattached thread's stack is not scanned, and a collection may hang waiting
for it. This matters even in a no-GC application, because a linked library may
still trigger a collection.

**4. Attribute the hooks `@nogc nothrow`.**

Then the pool comes out `@nogc` and the compiler holds you to it.

**5. Use `MonoTime` for every timeout, and anchor the deadline.**

Not wall clock. Not a fresh duration per loop iteration.

```d
immutable deadline = MonoTime.currTime + timeout;
while (!haveItem)
{
    auto left = deadline - MonoTime.currTime;
    if (left <= Duration.zero) return Status.timeout;
    cond.wait(left);
}
```

---

## The one rule that applies to both modes

**Every hook must be `nothrow`.**

Not a style preference. Look at what a throwing `on_close` costs:

```text
pool.close():
    lists cleared        ← the pool no longer holds the items
    collected = [...]    ← a local ItemList; the only reference
    on_close(collected)  ← throws
    ↓
    collected destroyed on the way out
    ↓
    every remaining item lost, silently, no report
```

The pool empties itself before the hook runs. There is no second reference and
no way back. `put_all` has a milder version of the same failure.

A hook that needs to report a problem does it through `ctx`, not by throwing.

```d
alias OnGet   = void function(void* ctx, const(void)* tag, size_t n, ref Slot s) nothrow;
alias OnPut   = ItemList function(void* ctx, size_t n, ref Slot s) nothrow;
alias OnClose = void function(void* ctx, ref ItemList list) nothrow;
```

Add `@nogc` to all three in no-GC mode. Leave it off in GC mode.

---

## If you might switch later

Start in GC mode, but keep item structs free of GC references anyway — rule 2
above, applied early.

Then the switch is mechanical:

```text
change            new → malloc, per allocation site
add               @nogc to the three hook aliases
add               thread_attachThis where needed
change nothing    item structs, Slot usage, send/receive, pool hooks logic
```

Without that discipline, the switch means auditing every item type in the
program for slices, strings, delegates and class references. With it, the switch
is a day.

The cost of the discipline in GC mode is small: `ubyte*` plus a length instead
of a slice, a fixed array instead of a `string`, a function pointer plus a
context pointer instead of a delegate.

Decide up front whether you are paying it. Do not decide halfway.

---

## Checklist

Before the first message is sent:

```text
[ ] Mode chosen and written down.               GC / no GC
[ ] Items and toolkit objects allocated the same way.
[ ] Every hook is nothrow.
[ ] Anything sent at rate comes from a pool.
[ ] Timeouts use MonoTime with an anchored deadline.
```

No-GC mode only:

```text
[ ] No GC references inside item structs.
[ ] Hooks attributed @nogc.
[ ] Threads outside druntime call thread_attachThis.
```

---

## The simple rule

Use the GC. Pool your items. Make your hooks `nothrow`.

Leave the GC when you have a number that says you must, or a target that says
you cannot have it.

Never run half of each.
