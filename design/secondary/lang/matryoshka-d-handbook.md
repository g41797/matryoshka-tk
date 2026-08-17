# Matryoshka in D — a porting handbook

Everything from the design session, in one place.

Contents:

```text
 1  What ports cleanly, and what does not
 2  The Slot idiom
 3  PolyNode and PolyHelper
 4  Mbox — sync, wakeUpAll, shared, fan-in/fan-out
 5  Pool — hooks, and the two rules that are not negotiable
 6  The memory policy: Manual and Managed
 7  Application items and the collector
 8  Matryoshka, std.concurrency, and TypeErasedQueue
 9  Toolchain, testing, CI
10  Decisions taken, and what is still open
```

---

# 1. What ports cleanly, and what does not

## Direct mappings

| Zig | D |
|---|---|
| `@fieldParentPtr("poly", n)` | `cast(ubyte*)n - T.poly.offsetof` |
| `comptime` validation, `@compileError` | `static assert` + `__traits(hasMember, ...)` |
| `@hasDecl(T, "x")` + `if` | `__traits(compiles, T.x)` + `static if` |
| `fn PolyHelper(T) type` | `template PolyHelper(T)` |
| `defer` | `scope(exit)` |
| `*anyopaque` | `void*` |
| `?*T`, `Slot` | `PolyNode*` |
| `*Slot` | `ref Slot` |
| `*const Slot` | `const scope ref Slot` |
| `std.atomic.Value(bool)` | `shared bool` + `core.atomic` |
| `.acquire` / `.release` / `.monotonic` | `MemoryOrder.acq` / `.rel` / `.raw` |
| `union(enum) Result` | hand-rolled tagged struct |
| `std.debug.assert` | `assert` |
| `item.* = .{}` | `*p = T.init` |

## The five things that need real work

**1. `core.sync.Mutex` and `Condition` are classes.**

Not structs. They cannot be embedded by value in a `malloc`'d `Mbox`. Write
~60 lines wrapping `pthread_mutex_t` / `pthread_cond_t` and
`CRITICAL_SECTION` / `CONDITION_VARIABLE` as plain structs.

You want this anyway. It gets you `@nogc nothrow`, embedding by value, and
`pthread_condattr_setclock(CLOCK_MONOTONIC)`.

**2. `Io` disappears, and cancellation with it.**

Every `io` parameter and field goes. `lockUncancelable(io)` becomes `m.lock()`.
There is no cancellable mutex acquisition in D, so `Io.Cancelable` leaves both
error sets and `Result.canceled` becomes unreachable.

Drop `receive_future`, `get_wait_future`, `receiveResult`, `getWaitResult`, and
both `Result` unions. That is a large fraction of the surface, and it is
consistent with the conclusion that `Io.Group` is wrong for long-lived thread
pools.

See §4 for what replaces cancellation.

**3. Deadline anchoring is manual.**

`Condition.wait` takes a `Duration`, not a deadline:

```d
immutable deadline = MonoTime.currTime + timeout;
while (!haveItem)
{
    auto left = deadline - MonoTime.currTime;
    if (left <= Duration.zero) return Status.timeout;
    cond.wait(left);
}
```

The clamp at zero is load-bearing. So is `MonoTime` — see the bug in §10.

**4. No intrusive list in the standard library.**

`std.container.DList` is value-based and allocates a wrapper per element. Write
your own, ~40 lines.

You come out ahead: `reset` happens inside `remove`, `popFirst` and `popLast`,
so the hazard documented at the bottom of `polynode.zig` stops existing rather
than being documented. You can also keep an O(1) `len`, which retires the
separate counters in `Mbox` and `Pool`. And `moveFromList` / `moveToList` exist
only for `std.DoublyLinkedList` interop — delete both.

**5. No error unions.**

Exceptions are out under `@nogc`, and they are the wrong tool on a hot path
regardless. Use a `Status` enum plus out-parameters.

`@mustuse` applies to structs and unions, not enums, so a discarded `Status`
is silent. If you want it forced, return a one-field `@mustuse struct`.

---

# 2. The Slot idiom

## D has no optional type

| | non-null pointer | optional | forced unwrap |
|---|---|---|---|
| Zig | `*T` | `?T` | `orelse`, `.?` |
| Odin | no | `Maybe(T)` | `v, ok := m.?` |
| D | no | no | no |

`Nullable!(PolyNode*)` wraps a type that is already nullable and costs two
words. Not useful here.

## Layer 1 — the plain pointer

```d
alias ItemHandle = PolyNode*;
alias Slot       = PolyNode*;   // null == empty
```

Signatures translate mechanically. `slot.* = null` becomes `slot = null`,
`slot.*.?` becomes `slot`. Use `is` and `!is`, never `==` — a Slot check is
about identity.

Release-before-acquisition survives unchanged:

```d
Slot s = null;
scope(exit) release(s);        // reads s at exit, not at registration

if (create!Request(s) != Status.ok) return;
if (send(s) != Status.ok) return;   // failure leaves the Slot unchanged
```

`release` must be a no-op on empty, not an assert. That is what makes the
early registration correct on every path.

## Layer 2 — the strict Slot

D can enforce two invariants that neither Zig nor Odin can express:

```d
import core.attribute : mustuse;

@mustuse struct Slot
{
    private PolyNode* h;

    @disable this(this);                  // one owner
    @disable void opAssign(ref Slot);

    ~this() @nogc nothrow                 // empty at death
    {
        assert(h is null, "Slot destroyed non-empty - item leaked");
    }

    bool empty() const @nogc nothrow { return h is null; }
    PolyNode* peek()  @nogc nothrow { return h; }

    PolyNode* take() @nogc nothrow { auto t = h; h = null; return t; }

    void put(PolyNode* n) @nogc nothrow
    {
        assert(h is null, "Slot already holds an item");
        assert(n !is null && !isLinked(n));
        h = n;
    }
}
```

```text
@disable this(this)   →  a second name for one item won't compile
~this() assert        →  a dropped item reports at the line it was dropped
@mustuse              →  "never write _ = mbx.close()" becomes a compile error
```

The destructor does not release. It cannot — heap-owned, pool-owned and
borrowed items are indistinguishable from there, which is the same knowledge
the mailbox does not have either. Assert; do not guess.

The trade against Zig: you lose the checked unwrap, you gain single ownership
and leak detection. For this idiom that is the better half.

---

# 3. PolyNode and PolyHelper

```d
struct Node     { Node* prev; Node* next; }
struct PolyNode { Node node; const(void)* tag; }
struct PolyTag  { ubyte _; }
```

## Three traps, in order of how badly they bite

**`static` in D is thread-local.**

```d
private static    PolyTag _tag;   // WRONG — one per thread
private __gshared PolyTag _tag;   // right
```

With `static`, every thread computes a different type ID, and `fromPoly`
returns `null` for any item that crossed a thread boundary. Nothing crashes,
nothing warns, and it looks like memory corruption.

**`void*` arithmetic does not compile in D.** Cast to `ubyte*`.

**`init` is a reserved property name.** The initializer becomes `initItem`.
That is the only rename the port forces.

## The helper

```d
private template TagOf(T)
{
    __gshared PolyTag tag;      // module-level, NOT inside PolyHelper — see §6
}

template PolyHelper(T)
{
    static assert(is(T == struct), T.stringof ~ ": must be a struct");
    static assert(__traits(hasMember, T, "poly"),
        T.stringof ~ ": missing field 'poly: PolyNode'");
    static assert(is(typeof(T.poly) == PolyNode),
        T.stringof ~ ": field 'poly' must have type PolyNode");
    static assert(T.poly.offsetof == 0,
        T.stringof ~ ": 'poly' must be the first field");

    pragma(inline, true)
    const(void)* TAG() @nogc nothrow @trusted
    {
        return cast(const(void)*) &TagOf!T.tag;
    }

    pragma(inline, true)
    PolyNode* toPoly(T* self) @nogc nothrow @trusted { return &self.poly; }

    pragma(inline, true)
    T* fromPoly(PolyNode* n) @nogc nothrow @trusted
    {
        if (n is null || n.tag !is TAG()) return null;
        return cast(T*)(cast(ubyte*) n - T.poly.offsetof);
    }

    T* mustFromPoly(PolyNode* n) @nogc nothrow
    {
        auto p = fromPoly(n);
        assert(p !is null, T.stringof ~ ": wrong tag");
        return p;
    }

    T* fromSlot(const scope ref Slot s) @nogc nothrow
    {
        return fromPoly(cast(PolyNode*) s.peek());
    }

    T* mustFromSlot(const scope ref Slot s) @nogc nothrow
    {
        auto p = fromSlot(s);
        assert(p !is null, T.stringof ~ ": wrong tag or empty Slot");
        return p;
    }

    T* moveFromSlot(ref Slot s) @nogc nothrow
    {
        auto p = fromSlot(s);
        if (p is null) return null;
        assert(!isLinked(s.peek()));
        s.take();
        return p;
    }

    void initItem(T* self) @nogc nothrow
    {
        self.poly = PolyNode.init;
        self.poly.tag = TAG();
    }
}
```

## Two things D does better than Zig here

**Deterministic layout.** D lays out plain structs in declaration order, so
`static assert(T.poly.offsetof == 0)` is enforceable. Zig may reorder the fields
of an ordinary struct — which is exactly why `@fieldParentPtr` had to be a
compiler intrinsic.

**The field cannot be forgotten.**

```d
mixin template PolyItem() { PolyNode poly; }

struct Request
{
    mixin PolyItem;        // declares poly, first, at offset 0
    uint id;
}
```

Keep the offset assert in `PolyHelper`, not in the mixin — inside the mixin the
layout is not finished and `offsetof` is asking too early.

---

# 4. Mbox

## Field mapping

| Zig | D |
|---|---|
| `poly` | `PolyNode` |
| `mutex`, `cond` | your own pthread / Win32 wrapper structs |
| `list` | your own intrusive list |
| `len`, `oob_count`, `oob_last`, `wake_epoch` | plain |
| `closed` | `shared bool` + `core.atomic` |
| `io` | gone |
| `alloc` | policy — see §6 |

Do not use `std.experimental.allocator`. `RCIAllocator` is not `@nogc`, and one
field of that type poisons every method that touches it.

## wakeUpAll is more important in D than in Zig

`wakeUpAll` increments `wake_epoch` and broadcasts. Blocked receivers observe
the epoch change and return `Status.wakeup`.

In D it earns a second job.

**druntime suspends threads with a signal during a collection.** A thread
blocked in `pthread_cond_timedwait` can return early because of it. So in a
Managed-mode application, spurious wakeups are not rare — they happen on every
collection, on every waiter.

The epoch counter is what tells a real `wakeUpAll` apart from a collection
artefact. Without it you could not distinguish them, and a naive
"woke up, therefore something happened" loop would report phantom wakeups at
collection rate.

```d
immutable startEpoch = wakeEpoch;
immutable deadline   = MonoTime.currTime + timeout;

while (list.isEmpty())
{
    if (atomicLoad!(MemoryOrder.acq)(closed)) return Status.closed;
    if (wakeEpoch != startEpoch)              return Status.wakeup;

    auto left = deadline - MonoTime.currTime;
    if (left <= Duration.zero)                return Status.timeout;

    cond.wait(left);                          // may return for any reason
}
```

Three exit conditions, all re-checked, none inferred from the wake itself.
That structure is correct in Zig and mandatory in D.

## wakeUpAll is also the cancellation substitute

D has no cancellable mutex acquisition, so `Io.Cancelable` is gone. But
`wake_epoch` plus broadcast is already 80% of a cancellation mechanism.

Add a per-waiter cancel flag checked in the same `while` condition and you have
cancellation without a runtime:

```text
wakeUpAll        broadcast, wakes everyone, epoch-detected
cancel(waiter)   sets that waiter's flag, then broadcast
```

The cost is that both are broadcasts. `Io` cancellation is per-waiter; this is a
thundering herd where only the targeted waiter acts on it. Acceptable for a
control-plane operation, wrong for a hot path. Do not use `wakeUpAll` as a
scheduling mechanism.

## Mbox may be shared — and in D that should be in the type

An `Mbox` is internally synchronised. That is exactly what `shared` is supposed
to mean, so put it in the signature:

```d
struct Mbox
{
    private Mutex     mutex;
    private ItemList  list;
    private shared bool closed;
    ................

    // one cast, one line, one place per public method
    private ref Mbox raw() shared @trusted @nogc nothrow
    {
        return *cast(Mbox*) &this;
    }

    Status send(ref Slot slot) shared @nogc nothrow
    {
        auto self = &raw();
        self.mutex.lock();
        scope(exit) self.mutex.unlock();
        ................
    }
}
```

Why this is worth the noise:

- `shared Mbox*` is now the natural handle type, and it documents thread-safety
  at every call site rather than in a comment.
- It passes `std.concurrency.spawn`'s `hasUnsharedAliasing` check **without a
  cast**, so the spawn form from §8 stops being a lie told to the compiler.
- `closed` stays `shared bool` with `core.atomic` even inside the unshared view,
  because it is read outside the lock.

What not to do: mark every field `shared` and cast at each access. Once casting
is routine the qualifier stops meaning anything.

## Fan-in and fan-out

Both work. This is a direct consequence of an `Mbox` being an object rather than
a thread.

```text
fan-in     N senders   →  1 mailbox  →  1 receiver
           the mutex serialises. Nothing special needed.

fan-out    1 sender    →  1 mailbox  →  N receivers
           send() signals one waiter. Each receiver takes one item.
           A work queue, for free.

fan both   N senders   →  1 mailbox  →  M receivers
```

Three consequences worth documenting:

**`send` should signal, not broadcast.** With N receivers, waking all of them so
one can take an item is pure waste. `wakeUpAll` and `close` broadcast; `send`
signals.

**OOB ordering is queue-global, not per-receiver.** "Every OOB precedes every
regular message" holds for the order items leave the queue. With M receivers it
says nothing about which receiver gets which, or about the order two receivers
process what they took. If per-receiver ordering matters, use M mailboxes.

**`close` must broadcast, then be joined.** Every blocked receiver has to observe
`Status.closed`, not just one.

```text
close()   marks closed, broadcasts, returns the queued items
join()    every receiver has observed Closed and left
destroy() now safe
```

Destroying before joining is a use-after-free on the mutex, and it presents as a
random crash inside `pthread_cond_broadcast`.

## The one context that does not work: fibers

`Condition.wait` blocks the carrier thread. A fiber calling `receive` parks
every other fiber on that thread.

"Execution-context agnostic" means any *thread*, not any scheduler. This is
precisely what `Io.Mutex` buys in Zig 0.16, and D has no integration point.

If a fiber scheduler ever needs to drain a mailbox: `try_receive` plus yield, or
an eventfd/pipe the scheduler can poll. Neither belongs in the toolkit.

---

# 5. Pool

## Replace both hash maps with parallel arrays

`AutoHashMapUnmanaged` has no `@nogc` equivalent, and D's built-in AA is
GC-only. This is a hard blocker.

It is also not a workaround. `lists` and `counts` are keyed by tag, populated
once in `init` from `hooks.tags`, and never gain a key. Two fixed arrays sized
from `hooks.tags` at construction remove the allocator dependency, the
`ensureTotalCapacity` OOM path, and `clearRetainingCapacity` in `close`. Linear
search over a handful of pointers beats hashing at every size you care about.

## Hooks must be nothrow — not negotiable

Zig has no exceptions, so a `void` hook cannot unwind. D can, and `close` is
where it costs everything:

```text
close():
    lists cleared        ← the pool no longer holds the items
    collected = [...]    ← a local ItemList; the only reference
    on_close(collected)  ← throws
    ↓
    collected destroyed on the way out
    ↓
    every remaining item lost, silently, no report
```

`put_all` has a milder version — an exception mid-loop leaves the caller's list
partly transferred and says nothing.

A hook reports trouble through `ctx`, never by throwing.

## @nogc on hook types is a real decision

A `@nogc` function cannot call a function pointer whose type is not `@nogc`. So
you cannot have both `Pool` attributed `@nogc` and hooks a Managed application
can supply without casting.

```text
(a) attribute the hooks @nogc     pool verified; Managed users must cast
(b) leave the attribute off       pool GC-free in fact, not verified
(c) template the pool on Hooks    D infers per instantiation. No trade-off.
```

(c), and see §6 for the one line of care it needs.

## Smaller items

- `on_put` returns `?ItemList` in Zig, where "null" and "empty list" already
  mean the same thing. Return `ItemList` and test `isEmpty()`.
- Keep an outstanding-item counter — incremented on `get`, decremented on `put`.
  `close` reporting `outstanding != 0` is the only leak detector an application
  will ever get, and it costs one integer.
- Hooks run outside the mutex, may run concurrently, must not call pool APIs,
  and must not block. Unchanged from the Zig.

---

# 6. The memory policy: Manual and Managed

```text
Manual      you allocate and release      no GC     -betterC reachable
Managed     the collector owns items      GC        the ordinary D application
```

## Pick Manual if any one of these holds

```text
[ ] A measured tail-latency budget the collector violates.
[ ] Targeting -betterC, or a platform with no runtime.
[ ] A shared library loaded into a host that does not own druntime.
```

Otherwise Managed. Measured, not assumed. "It feels wasteful" is not on the
list. A latency-budgeted server is desktop hardware that needs Manual; an
embedded Linux box with no budget is fine on Managed.

## The audit this design rests on

**Differs between modes:**

```text
1. how an item is allocated and released
2. the attribute set (@nogc or not)
3. the hook function pointer types (they carry the attribute set)
```

**Must not differ:** the Slot idiom, send/receive logic, the tag mechanism, the
free lists, the hook contract, the error model, the list, the sync wrappers, the
API shape, the assert set.

So **the policy is an allocator and nothing else.** Everything the compiler
needs follows from that.

The tempting design is two implementations behind a `version`, and it is wrong:
every line that exists in one mode is a line CI tests in one mode.

## The policy type

```d
struct Manual
{
    enum bool managed = false;
    private Arena* arena;

    T* acquire(T)() @nogc nothrow
    {
        return cast(T*) arena.alloc(T.sizeof, T.alignof);
    }
    void release(T)(T* p) @nogc nothrow { arena.dealloc(p, T.sizeof); }
}

struct Managed
{
    enum bool managed = true;

    T* acquire(T)() nothrow { return new T; }
    void release(T)(T* p) nothrow { /* the collector reclaims */ }
}
```

An instance, not a namespace — a Manual application may want a per-connection
arena. `Managed` is stateless and costs one byte of padding.

## Attribute inference does the @nogc work

```text
Mbox!Manual.send    →  inferred @nogc nothrow
Mbox!Managed.send   →  inferred nothrow
```

Same source. You never write `@nogc`. And it is verified — if a line in shared
code allocates, `Mbox!Manual` stops being `@nogc` and the test in §9 fails to
compile.

## Selection: by import, since you work in source mode

```d
// source/matryoshka/manual.d
public import matryoshka.impl;
alias Mbox          = MboxImpl!Manual;
alias PolyHelper(T) = PolyHelperImpl!(T, Manual);
alias Pool(H)       = PoolImpl!(Manual, H);

// source/matryoshka/managed.d — the same, with Managed
```

Consumer:

```d
import matryoshka.manual;   // or matryoshka.managed
```

Better than `version(...)` for a source-distributed library:

- no build flag, no dub configuration, no version identifier to document
- no question about whether `versions` propagates into a dependency
- both modes always compile, in every build — the CI problem disappears rather
  than being solved
- the mode is visible in the file that uses it, not in a build file

Cost: "never mix" is no longer enforced by there being one `DefaultPolicy`.
Importing both in one module gives an ambiguous `Mbox` at the use site. Across
modules, nothing complains. It was a documented rule before too.

## The one thing that must not be templated

If `_tag` lives inside `PolyHelperImpl!(T, Policy)`, then `Request` has two type
IDs. Same for `Pool`'s own tag across `Pool!H` instantiations.

**Template what varies. Never template what establishes identity.** Tags go at
module scope — see `TagOf!T` in §3.

## The payoff: rules become compile errors

```d
static if (!Policy.managed)
    static assert(!hasManagedRefs!T,
        T.stringof ~ ": Manual mode - item types must not hold"
        ~ " GC-managed references");
```

```d
template hasManagedRefs(T)
{
    static if (is(T == class) || is(T == interface))            enum hasManagedRefs = true;
    else static if (isDynamicArray!T || isAssociativeArray!T
                 || isDelegate!T)                               enum hasManagedRefs = true;
    else static if (isStaticArray!T)  enum hasManagedRefs = hasManagedRefs!(typeof(T.init[0]));
    else static if (is(T == struct) || is(T == union))
                                      enum hasManagedRefs = anySatisfy!(hasManagedRefs, Fields!T);
    else                              enum hasManagedRefs = false;
}
```

Honest limit: this checks **types, not provenance**. A `ubyte*` into GC memory
still passes. It catches the mistakes people make, not all of them.

## Two genuine divergences — document, do not hide

**Out of memory.**

```text
Manual     acquire returns null           →  Status.noMemory
Managed    new throws OutOfMemoryError    →  the process dies
```

Leave the null check in `create`; it is a branch, and it keeps one source.

**Destructor timing.**

```text
Manual     ~this at destroy(), synchronously
Managed    ~this at finalization, later, on another thread
```

The fix is a rule: **item types have no destructors.** Items are transported
data. Teardown belongs in `on_put`, where the concrete type is known and the
timing is yours.

```d
static assert(!__traits(hasMember, T, "__dtor"),
    T.stringof ~ ": item types must not have destructors");
```

## Never fork beyond the allocator

`static if (Policy.managed)` appears in three places: `acquire`, `release`, and
the hook aliases. A fourth is a bug waiting for the mode you did not build.

Consequence: the list, the Slot, the node layer and the sync wrappers allocate
nothing, so they need no policy at all. Five of nine modules stay policy-free.

---

# 7. Application items and the collector

Matryoshka never allocates or frees an item. The mailbox never touches one; the
pool touches one only through your hooks. So the allocator is the application's
choice — with **one rule**.

## The rule

An item in flight is reachable only through the toolkit's list nodes.

```text
sender                mailbox                receiver
Slot ── null    ──►   [item] [item]   ──►   Slot ── null
                        ▲
              the only reference in the program
```

> Either the mailbox and pool live in GC-scanned memory, or transported items
> are not GC-allocated.

```text
(a) items malloc'd, toolkit malloc'd    no GC anywhere. Simplest.
(b) items new'd,    toolkit new'd       also fine.
(c) items new'd,    toolkit malloc'd    BROKEN.
```

(c) cannot be fixed inside the toolkit: `GC.addRange` needs the concrete type,
and `ItemHandle` is type-erased. The type is gone by then. Your hooks *can* do
it — that is where erasure ends — at the cost of the GC lock per call.

## Two footnotes

**Threads druntime did not create** must call `thread_attachThis()` on entry and
`thread_detachThis()` on exit. An unattached stack is not scanned, and a
collection may hang waiting for the thread. This matters even in a Manual
application, because a linked library may still trigger a collection.

**Collections cause spurious condvar wakeups.** See §4 — this is why the epoch
counter and the anchored deadline are not optional in D.

## The pool is what makes Managed mode viable

```text
no pool     allocation per message   →   collections at message rate
pool        allocation until warm    →   collections approach zero
```

Most of the benefit of Manual mode, none of the rules. Pool anything sent at
rate; do not pool what you create once.

---

# 8. Matryoshka, std.concurrency, and TypeErasedQueue

Two comparisons, two different axes. Only one of them is shared.

## Axis A — storage and copying

This is the existing `TypeErasedQueue` note, and every row holds for
`std.concurrency` too:

| | TypeErasedQueue | std.concurrency | Mbox |
|---|---|---|---|
| storage | queue owns it | MessageBox owns it | owns none |
| elements | copied in | copied into a `Variant` | moved |
| capacity | bounded | bounded (`setMaxMailboxSize`) | unbounded |
| backpressure | inside | inside | outside — the Pool |
| producer when full | waits for a slot | blocks / throws / drops | waits only for a receiver |

Both standard containers bundle synchronisation, storage, capacity and
allocation policy into one type. Matryoshka splits them four ways:

```text
Mbox        synchronisation + moving items between owners
Pool        lifecycle, capacity, reuse
Allocator   memory
Master      scheduling, application policy
```

Note where backpressure lands. Ten mailboxes at 1000 each bounds you at 10,000
messages of memory. Ten mailboxes on a 1000-item pool bounds you at 1000,
however they distribute. The pool version bounds memory; the per-queue version
bounds a queue.

## Axis B — isolation and identity (D only)

`std.concurrency.send` refuses mutable aliasing at compile time. The check is
`hasUnsharedAliasing`, and it *is* the safety model.

```d
send(tid, request);                // Request* — does not compile
send(tid, cast(shared) request);   // compiles, guarantee gone
send(tid, cast(size_t) request);   // laundered through an integer
```

So it cannot express ownership transfer of a mutable object. The honest test:
**if your messages are pointers to mutable objects, `std.concurrency` is not
doing its job for you** — you have kept the `Variant` and the allocation and
thrown away the reason for them.

Second identity difference:

```text
a Tid is a thread     one mailbox per thread, created and destroyed with it
an Mbox is an object  any number per thread, stored in structs, passed as a
                      value, sent through another mailbox
```

From which: **`std.concurrency` cannot do fan-out.** Two threads cannot receive
from one `Tid`'s mailbox; `receive` operates on `thisTid` only. Fan-in works.
Matryoshka does both (§4).

## Passing a mailbox to a thread — the accurate version

Only `spawn` applies the aliasing check. The other two forms do not:

```d
auto t = new Thread({ worker(mbx); });     // core.thread — no check, Managed only
pthread_create(&tid, null, &entry, mbx);   // void* — works in Manual and betterC
spawn(&worker, cast(shared) mbx);          // needs the cast, unless Mbox is shared (§4)
```

`core.thread.Thread` is a GC class and the closure allocates, so Manual mode
goes to `pthread_create` directly. The `void*` argument is exactly the right
shape.

## What the standard library gives you that Matryoshka does not

Compiler-enforced isolation. Type-dispatched `receive`. `spawn`, `spawnLinked`,
`OwnerTerminated`, supervision. `register` / `locate`. Fibers. Zero
dependencies, and a reviewer who needs no document.

For TypeErasedQueue specifically: **`Io` cancellation.** A blocked producer or
consumer is cancellable per-waiter through the runtime. `wakeUpAll` plus an
epoch is close but is a broadcast (§4). Worth naming in your own doc — it is
more convincing coming from you.

## What Matryoshka gives you

Works without a GC — not a slower option, not an option. Zero copy for large
payloads. Zero allocation on the message path. Mailboxes as objects, so fan-out
and mailbox-in-mailbox. Heterogeneous queues without boxing. Status codes, so
`nothrow` and `@nogc`. `close` returns your items. OOB with defined ordering.

## The layering argument

> `std.concurrency` could be implemented on top of Matryoshka. The reverse is
> not possible.

Add a `Variant` item type, one mailbox per thread, `spawn` and a registry, and
you have rebuilt it — with pooling underneath. Going the other way is blocked by
the aliasing check by design.

## Using both

```text
control plane   std.concurrency   start, stop, reconfigure, supervise
data plane      Matryoshka        the traffic
```

A worker holds a `Tid` for lifecycle and a `shared Mbox*` for work. Usually the
right answer for a service, and the right answer to a reviewer asking why the
standard library was not enough. It was, for half the problem.

## One correction

`Tid` and `register`/`locate` were designed with out-of-process messaging in
mind, and the module docs say so. **Phobos ships no remote transport** — no wire
format, no serialization, no network `Tid`. Worth knowing before it appears in a
design as an assumed capability.

---

# 9. Toolchain, testing, CI

## The axis usually forgotten: the compiler

| | backend | role |
|---|---|---|
| **DMD** | own | reference frontend. Fastest compiles. Weakest codegen. |
| **LDC** | LLVM | best codegen, best aarch64, best `-betterC`, only one with sanitizers. |
| **GDC** | GCC | in GCC mainline, lags most, what distributions ship. |

This design depends on **attribute inference**, which is frontend behaviour, and
the three ship different frontend versions. DMD and LDC minimum. GDC nightly, if
distribution packaging matters.

D has no LTS. Pick a floor version, document it, test floor and latest.

## Environment

```text
dub               targetType: sourceLibrary
serve-d           the language server; everything else is a client
code-d            VS Code. The mainstream D setup.
Visual D          Visual Studio. Best Windows debugging (mago).
dfmt, dscanner    formatting, static analysis
adrdox            better docs than ddoc; keep MkDocs for prose
```

Debugging: Linux + LDC + GDB is the good experience. LLDB's D support is
thinner. Do not expect comfortable template stack traces on macOS.

**Honest note.** D support in JetBrains IDEs is materially weaker than what you
have for Zig and Odin — the community plugin is behind and lightly maintained.
That is a working-conditions downgrade, and better known before the port than
three weeks in.

## Testing

**`-checkaction=context`** in `dflags`. Turns a bare assert failure into one that
shows the values.

**Keep tests out of `sourcePaths`.** In source mode anything in `sourcePaths`
compiles into the consumer's binary — including your unittest blocks, if they
build with `-unittest`.

```json
"configurations": [
    { "name": "library",  "targetType": "sourceLibrary" },
    { "name": "unittest", "targetType": "executable",
      "sourcePaths": ["source", "tests"] }
]
```

**Struct invariants — Zig has no equivalent.** Checked at every public method
boundary in non-release builds:

```d
invariant
{
    assert(oobCount <= len);
    assert(oobLast is null || oobCount > 0);
    assert((len == 0) == list.isEmpty());
}
```

Free retroactive coverage: every existing test starts checking these on every
call, and the failure points at the method that broke the invariant rather than
the one that later tripped over it. `Pool` has more — per-tag count matches
per-tag list length.

**The `@nogc` verification test.** The most important test in Manual mode is not
a test of behaviour:

```d
@nogc nothrow unittest
{
    // Does not compile if anything reachable here allocates or throws.
    ubyte[4096] storage = void;
    auto arena  = Arena(storage[]);
    auto policy = Manual(&arena);

    Slot s;
    scope(exit) destroyItem!Request(policy, s);

    assert(create!Request(policy, s) == Status.ok);
    assert(mustFromSlot!Request(s) !is null);
}
```

The attribute is the assertion. One per public entry point.

**GC stress — the Managed-mode equivalent.** A background thread collecting
while messages are in flight, with `--DRT-gcopt=heapSizeFactor=1`. This is the
job that catches an item freed while queued. Nothing else will.

**Concurrency suites, all under TSan:**

```text
MPMC saturation        every message arrives exactly once
fan-out fairness       M receivers, one mailbox, no receiver starves
close under contention no item lost, every receiver returns Closed
wakeUpAll race         concurrent with send; the epoch swallows nothing
OOB ordering           every OOB precedes every regular
pool churn             hook call counts reconcile
put_all mid-close      caller's list holds exactly the untransferred items
```

**Leak accounting:** Manual — the arena reports outstanding at teardown, assert
zero. Managed — `GC.stats` growth across iterations means retention, usually a
list still holding items.

**betterC tests are separate executables** with `extern(C) int main()`. No
unittest runner, no druntime `main`.

## CI matrix

Axes: compiler, compiler version, OS, architecture, build type, memory policy,
betterC (Manual only), libc (optional).

Two need justification. **Build type is three values** — `debug`, `release`,
`release-nobounds` — because `-release` strips your asserts and the `_holds`
O(n) walk, and this design is assert-dense. **Architecture matters** because
x86_64's strong memory model hides a missing acquire/release on `closed` or
`wakeEpoch`; aarch64 does not.

**Tier 1, every push (6 jobs):** linux-x64 × ldc × {debug, release} × {managed,
manual}, plus dmd × debug × both policies.

**Tier 2, PR and main (~12 jobs):** macos-arm64 × ldc × 2 builds × 2 policies;
windows-x64 × ldc × 2 builds × 2 policies, plus dmd debug managed;
release-nobounds × 2 policies; betterC × manual.

Windows is not optional — `Mutex` and `Cond` are a genuinely different
implementation there, and `SleepConditionVariableCS` has different
spurious-wakeup behaviour.

**Dedicated jobs, every push:** TSan (both policies), ASan (manual), GC stress
(managed), coverage, the `@nogc` audit.

**Nightly:** compiler floor versions, gdc, linux-aarch64, musl, betterC on macOS
and Windows.

```yaml
- uses: dlang-community/setup-dlang@v1
  with:
    compiler: ${{ matrix.compiler }}
- run: dub test --config=unittest-${{ matrix.policy }} --build=${{ matrix.build }}
```

## Build order, most value first

```text
1  dub test, linux + ldc, both policies, debug
2  the @nogc verification unittests
3  TSan on the concurrency suite
4  release and release-nobounds
5  windows + macos-arm64
6  GC stress in Managed mode
7  dmd alongside ldc
8  betterC, only if it is a supported target
9  struct invariants
10 coverage reporting
```

2 and 3 find things nothing else finds. The rest is breadth.

---

# 10. Decisions taken, and what is still open

## Taken

```text
Slot                    struct, @mustuse, @disable this(this), ~this asserts empty
in/out parameter        ref Slot. No ** anywhere.
parent pointer          cast(ubyte*)n - T.poly.offsetof; offset 0 asserted
tag storage             __gshared PolyTag at module scope, one per type
sync primitives         own pthread / Win32 structs, CLOCK_MONOTONIC
list                    own intrusive list; reset inside remove
error model             Status enum, both modes, no exceptions
cancellation            dropped; wakeUpAll + epoch (+ optional per-waiter flag)
pool maps               parallel arrays, not hash maps
hooks                   nothrow always; @nogc via templated policy
policy                  Manual / Managed; allocator only; three static ifs
policy selection        by import, not by version — source mode
Mbox thread-safety      shared methods, one cast per method to the raw view
item types              no destructors; no GC refs in Manual mode
```

## One bug in the Zig, to fix before porting

`receive` and `get_wait` build their timeouts with `.clock = .real`. That is
wall clock — an NTP step or a manual clock change extends or collapses every
pending timeout in the process. Timeouts want monotonic.

The D port needs its own condvar wrapper anyway, so set `CLOCK_MONOTONIC` on the
condattr there and use `MonoTime`. Then fix the Zig side, or the two
implementations will disagree under clock adjustment and you will debug it
through a test that only fails on one machine.

## Superseded during the session

Two things said early and corrected later — do not reintroduce them from
earlier notes:

- **`core.sync.Mutex` and `Condition` are classes, not structs.** The
  stack-allocation sketch that treated them as structs was wrong. Write your
  own wrappers.
- **Passing an `Mbox*` to a thread is routine.** Only `std.concurrency.spawn`
  applies the aliasing check; `core.thread` and `pthread_create` do not. And if
  `Mbox` methods are `shared` (§4), even `spawn` takes it without a cast.

## Still open

```text
[ ] Is -betterC a supported target, or only @nogc?
[ ] Manual / Managed, or Embedded / Desktop as the public names?
[ ] Does the toolkit ship a name registry, or is naming the application's?
[ ] Per-waiter cancellation flag, or wakeUpAll broadcast only?
[ ] Does Mbox keep an O(1) len, now that the list can provide one?
[ ] Compiler floor version.
```
