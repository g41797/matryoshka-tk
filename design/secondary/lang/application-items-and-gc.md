# Application Items and the Garbage Collector

GC, no GC, or does Matryoshka not care?

Short answer: it does not care.

Longer answer: it does not care about *allocation*, and that is almost the whole
question. There are three places where it does care, and two of them are one
sentence each.

The third is the pool.

---

## Why it does not care

An application item is any struct with an embedded `PolyNode`.

Matryoshka moves the handle. It does not own the item.

```text
Mailbox                          Pool

keeps the handle                 keeps the handle
never inspects the item          touches the item only through your hooks
never copies the item            creates nothing itself
never frees the item             frees nothing itself
```

`ItemHandle` is a type-erased `PolyNode*`.

A mailbox cannot allocate an item, because it does not know the type.

A pool does not allocate one either. Your hook does.

So the allocator is the application's choice, and it stays the application's
choice:

```d
struct Request
{
    PolyNode poly;
    uint id;
    ubyte[] data;
}
```

Any of these work, and none of them is visible to the toolkit:

```text
new Request                 GC-allocated
malloc(Request.sizeof)      C heap
your arena                  whatever you built
&stackRequest               a stack item, borrowed for the duration
theAllocator.make!Request   std.experimental.allocator
```

---

## Where it does care: one rule

An item in flight is reachable **only** through the toolkit's list nodes.

Between `send` and `receive`, the item sits in a mailbox's intrusive list. No
application stack, no application struct, no application global holds it.

```text
sender                mailbox                receiver

Slot ── null    ──►   [item] [item]   ──►   Slot ── null
                        ▲
                        │
              the only reference in the program
```

For a GC that scans stacks and registered ranges, that reference is invisible
unless the mailbox itself sits in scanned memory.

If items are GC-allocated and the mailbox is `malloc`'d, the collector can free
an item that is queued and waiting. Type erasure makes it unfixable from inside
the toolkit — `GC.addRange` needs a `TypeInfo` the mailbox does not have.

**The rule:**

> Either the mailbox and pool live in GC-scanned memory, or transported items
> are not GC-allocated.

That is the only allocation-related constraint the toolkit imposes. It follows
from "the queue owns the handle while it is in flight," which is a design
invariant, not an allocator choice.

Three ways to satisfy it:

```text
(a) items malloc'd, toolkit malloc'd      -- no GC anywhere. Simplest.
(b) items GC'd,     toolkit GC'd          -- new Mbox, new Pool. Also fine.
(c) items GC'd,     toolkit malloc'd      -- BROKEN unless you register ranges
                                             yourself, per item, per type.
```

(c) is the configuration that looks reasonable and is not. Pick (a) or (b).

---

## Where it does care: two footnotes

**Threads druntime does not know about.**

If a thread is created outside druntime — by your reactor, by a C library, by
`pthread_create` directly — its stack is not scanned and it cannot be suspended
for a collection. A `PolyNode*` held only in that thread's frame is collectable,
and the collection itself may hang.

`thread_attachThis()` on entry, `thread_detachThis()` on exit. Only you know
where those threads are created.

**Collections cause spurious condvar wakeups.**

druntime suspends threads with a signal. A thread blocked in
`pthread_cond_timedwait` can return early because of it.

Your retry loop already handles this, and the anchored deadline is why:

```d
immutable deadline = MonoTime.currTime + timeout;
while (!haveItem)
{
    auto left = deadline - MonoTime.currTime;
    if (left <= Duration.zero) return Status.timeout;
    cond.wait(left);
}
```

A naive loop that passes the original `timeout` on every iteration would have
its deadline restarted by every collection in the process. Under a GC-using
application that is not a rare event.

This is the same reason the Zig version anchors the deadline before the loop. In
D there is one more thing that can wake you.

---

## The pool is where the choice becomes visible

Everywhere else the toolkit moves handles. The pool is the one place it calls
*into* application code that allocates.

```text
pool.get   ──►  on_get    ──►  your allocator
pool.put   ──►  on_put    ──►  your allocator (maybe)
pool.close ──►  on_close  ──►  your allocator
```

Three hooks. Each one is where GC or no-GC actually happens.

### on_get

The pool takes a stored item if one is free, then calls the hook.

```text
free item available   →  slot filled by the pool  →  hook may keep or replace it
none available        →  slot empty               →  hook creates, or leaves empty
```

An empty slot on return means "not created". Backpressure, reported as
`Status.notCreated`.

The hook decides how the item comes into existence. `new`, `malloc`, an arena,
a freelist of your own — the pool cannot tell and does not check, beyond
asserting that the tag matches what was requested.

### on_put

Four outcomes, all the hook's choice:

```text
kept as-is         slot left non-null, data untouched
kept after reset   slot left non-null, data cleared
released           slot cleared, hook freed the item
replaced           slot holds a different item, hook freed the original
```

A non-null slot on return means one thing: an item is kept. Original or
replacement, the pool does not care.

This is also where a composite item gives its parts back — parts in the returned
list, parent in the slot.

Note for the D port: the Zig signature returns `?ItemList`, and "null" and
"empty list" already mean the same thing. Return `ItemList` and test
`isEmpty()`. One fewer nullable, no behaviour change.

### on_close

The pool collects every item from every per-tag free list, clears itself, and
hands the whole list to the hook.

```text
pool.close()
    │
    ├─ mark closed
    ├─ collect all free lists into one
    ├─ clear the pool
    ├─ wake blocked get_wait callers
    │
    └─ on_close(list)   ←  the hook releases every item
```

The hook is responsible for all of them. The pool has already forgotten them.

---

## The hook contract

Unchanged from the Zig, restated because it is the load-bearing part:

- Hooks run **outside** the pool's mutex.
- Multiple threads may run a hook at once. The pool does not serialize them.
- A hook that touches shared state locks it itself.
- A hook must not call pool APIs.
- A hook must not block.
- `in_pool_count` is a hint. It is read under the lock and used without it.

Two D-specific additions.

### Hooks must be nothrow

This is not negotiable, and it is not a style preference.

Zig has no exceptions, so a `void`-returning hook cannot fail in a way that
unwinds. D can.

Look at what a throwing `on_close` costs:

```text
close():
    lists cleared        ← pool no longer holds the items
    collected = [...]    ← a local ItemList; the only reference
    on_close(collected)  ← throws
    ↓
    collected destroyed
    ↓
    every remaining item lost, silently, with no report
```

The pool has emptied itself before the hook runs. There is no second reference
and no way back. `put_all` has a milder version of the same problem: an
exception mid-loop leaves the caller's list partly transferred and says nothing.

So:

```d
alias OnClose = void function(void* ctx, ref ItemList list) nothrow;
```

`nothrow` on every hook type. A hook that needs to report a problem does it
through `ctx`, not through the stack.

### @nogc on hook types is a real decision

A `@nogc` function cannot call a function pointer whose type is not `@nogc`.

So you cannot have both of these:

- `Pool.get`, `put`, `close` attributed `@nogc`
- hooks that a GC-using application can supply without casting

Three options:

**(a) Attribute the hooks `@nogc nothrow`.**
The pool is `@nogc` end to end, compiler-verified. GC-using applications must
cast their hook to a `@nogc` pointer — a known D escape hatch, and their
problem. Consistent with a no-GC toolkit; unwelcoming to (b)-style users.

**(b) Leave `@nogc` off the hook types.**
Pool methods carry no `@nogc`. The pool still allocates nothing, ever — it is
GC-free in fact, just not attribute-verified. Both worlds supply hooks freely.

**(c) Template the pool on its hooks type.**
D infers attributes for templates. `Pool!NoGcHooks` comes out `@nogc`;
`Pool!GcHooks` does not. One implementation, both guarantees, no casting.

(c) is the only option with no trade-off, but it needs one line of care: each
instantiation would otherwise get its own `PolyTag`, so a pool would stop having
a single type ID. Put the tag at module scope:

```d
private __gshared PolyTag _poolTag;   // one type ID for every Pool!H
```

Then a pool transported through a mailbox is still recognisably a pool,
whichever hooks type it was built with.

---

## Mixed applications

The interesting case is an application that is mostly GC, with a no-GC hot path.
This works, with one discipline.

Per-tag, not per-pool:

```text
Request   →  malloc'd, hot path, high rate
Config    →  GC'd, cold path, holds a string[] and a delegate
```

A single pool can hold both, because the hooks dispatch on tag and each tag's
hook uses its own allocator. The pool never learns the difference.

What you must not do is let a `malloc`'d item hold the only reference to GC
memory:

```d
struct Request
{
    PolyNode poly;
    ubyte[] data;      // if malloc'd item + GC-allocated slice → dangling
}
```

The item is not scanned, so the slice's target is collectable. Two fixes:

- keep GC references out of `malloc`'d item types, or
- `GC.addRange` in `on_get` and `GC.removeRange` in `on_put`/`on_close` — your
  hook knows the concrete type, so unlike the toolkit, it *can* do this

The hook is the right place for that call precisely because the type erasure
ends there.

---

## Summary table

| | items GC'd | items no-GC |
|---|---|---|
| toolkit GC'd (`new Mbox`) | works | works |
| toolkit no-GC (`malloc`) | **broken** — in-flight items invisible | works |
| hooks may allocate with GC | yes | yes, but see mixed above |
| hooks must be `nothrow` | yes | yes |
| hooks may be `@nogc` | not usefully | yes |
| threads outside druntime | must attach | no requirement |
| spurious condvar wakeups | frequent | rare |

---

## The simple rule

Matryoshka does not allocate application items and does not free them.

The application decides, per type, in the hooks.

Two things the application owes the toolkit:

1. Do not put GC-allocated items into a non-GC-scanned mailbox or pool.
2. Make every hook `nothrow`.

Everything else is yours.
