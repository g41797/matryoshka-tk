# Matryoshka in D — design review and porting proposal

This document is a proposal for `matryoshka-dtk`.

It is **not** a porting plan yet.

The first question is whether Matryoshka fits D well enough to justify starting the port.

The goal is not line-by-line compatibility with `matryoshka-ztk`.

The goal is:

> Keep the Matryoshka idea and building blocks.
> Use D where D is better suited to express them.

`matryoshka-otk`, `matryoshka-ztk`, `matryoshka-dtk`, etc. are separate implementations of the same idea.

They do not have to have identical APIs.

---

# 1. Verdict

## Conditional GO

`matryoshka-dtk` looks technically worthwhile.

But the current proposal contains several decisions that should **not** be accepted before prototyping.

The strongest reasons to continue are:

* D has strong compile-time facilities.
* D structs can be made non-copyable.
* D has `@mustuse`.
* D has `shared` and explicit atomic operations.
* D supports `@nogc` and `nothrow`.
* D templates are suitable for compile-time policy selection.
* D structs have deterministic field order.
* D can express the intrusive `PolyNode` model naturally.
* A heap-allocated `struct` gives the desired `T*` API without forcing Matryoshka objects to be D classes.
* D has both GC-managed and manually allocated memory models.

The strongest reasons for caution are:

* D's GC and Manual memory models are very different.
* D's `shared` model can make APIs more complicated.
* `core.sync.Mutex` and `Condition` are classes.
* `-betterC` is a much stronger restriction than `@nogc`.
* D has no direct equivalent of Zig's `Io`.
* Blocking synchronization is deliberately thread-oriented.
* D's ownership/lifetime facilities are useful but are not Rust-style ownership.
* Too much `@trusted` code would make the design unattractive.
* A custom synchronization layer is a substantial maintenance commitment.

Therefore:

> **Do not implement the handbook as written.**
>
> First prove that the core model is natural in D.

---

# 2. What must remain Matryoshka

The following ideas should remain recognizable in every `*-tk` implementation.

```text
Master
  |
  +-- Mailbox
  |
  +-- Pool
  |
  +-- Items
         |
         +-- PolyNode
```

The important concepts are:

* `Master` is a role, not necessarily a language type.
* `Mailbox` moves Items.
* `Pool` manages Item lifecycle and reuse.
* `Item` is application data.
* `PolyNode` gives type-erased infrastructure access.
* `ItemHandle` identifies an Item without knowing its concrete type.
* Mailbox and Pool do not communicate directly.
* Items move between Masters.
* The toolkit does not become the application's scheduler.
* The toolkit does not become an I/O framework.

The D implementation may improve individual mechanisms.

It must not accidentally turn Matryoshka into a different architecture.

---

# 3. First major correction: do not start from API translation

The original proposal starts with a Zig-to-D mapping table.

That is useful later.

It is not the right starting point.

For example:

```text
Zig:
    *Mbox

D:
    Mbox*
```

is obvious.

But the important question is:

```text
Who allocates Mbox?
Who owns it?
How is it shared between threads?
How is it destroyed?
What does Manual mean?
What does Managed mean?
What does the compiler enforce?
```

Those questions determine the D API.

The port should therefore proceed in this order:

```text
architecture
    ↓
lifetime model
    ↓
allocation model
    ↓
concurrency model
    ↓
type-erasure model
    ↓
API
```

Not:

```text
Zig syntax
    ↓
D syntax
```

---

# 4. Heap allocation of Matryoshka objects

The Matryoshka building blocks are heap objects.

The user should normally get:

```d
Mbox* mbx;
Pool* pool;
```

not stack instances.

This is important.

It means D structs are a very attractive representation.

```d
struct Mbox
{
    ...
}
```

and:

```d
Mbox* mbx = ...;
```

gives the desired pointer-based API.

D automatically dereferences a struct pointer for member access.

So:

```d
mbx.send(slot);
```

is natural D.

There is no need to use D classes merely to obtain reference semantics.

This also avoids making the public API:

```d
Mbox mbx;
```

when the Matryoshka object is conceptually long-lived and externally owned.

## Recommended direction

Use:

```text
Mbox  = struct
Pool  = struct
Master-owned handles = pointers
```

unless the prototype demonstrates a strong reason to use classes.

This also makes Manual mode much more realistic.

D structs can be allocated with `new`, or placed into manually managed memory. ([D Programming Language][1])

---

# 5. Information hiding

The original Matryoshka design initially used opaque handles:

```text
mailbox.receive(mbh, ...)
```

That was good for information hiding but uncomfortable in Zig.

The later Zig design moved to:

```text
*Mbox
*Pool
```

D should not blindly copy either choice.

There are three reasonable D designs.

## Option A — public struct

```d
struct Mbox
{
    ...
}
```

User receives:

```d
Mbox* mbx;
```

Private fields remain private.

This is probably the most idiomatic D solution.

## Option B — opaque struct

```d
struct Mbox;
```

Public code only sees:

```d
Mbox* mbx;
```

Implementation code sees the complete definition.

D explicitly supports opaque structs for PIMPL-style information hiding. ([D Programming Language][1])

This is worth investigating.

## Option C — module functions

```d
send(mbx, slot);
receive(mbx, slot);
```

This is the closest to the original Odin design.

It is valid D, but less idiomatic if the object itself can naturally provide methods.

## Recommendation

Prototype **A and B**.

Do not decide from ideology.

Choose whichever gives:

* clean public API;
* good information hiding;
* good `shared` handling;
* good Manual/Managed support;
* minimal `@trusted`;
* no unnecessary casts.

---

# 6. Slot

Slot deserves a real D redesign.

The original proposal's idea is good:

```d
@mustuse
struct Slot
{
    PolyNode* h;
    ...
}
```

D gives us facilities that are particularly interesting here.

A struct can explicitly disable copying. It can also explicitly disable moving. `@mustuse` can make discarded Slot-like results a compile-time error. ([D Programming Language][3])

That is potentially better than the Zig implementation.

## But do not assume the final Slot design yet

The prototype should test at least:

```text
plain PolyNode*
```

```text
@mustuse struct Slot
```

```text
non-copyable Slot
```

```text
non-copyable + move-enabled Slot
```

and:

```text
ref Slot
scope ref Slot
return ref Slot
```

D has explicit copy and move constructor mechanisms. This should be exploited instead of treating D as if it only had C-style structs. ([D Programming Language][1])

## Desired semantics

The conceptual API should remain:

```text
empty Slot
    ↓
create item
    ↓
Slot contains ItemHandle
    ↓
send(slot)
    ↓
Slot becomes empty
```

The Slot is not a variable used for storing application values.

It is a temporary container for an ItemHandle.

The D implementation should make this idiom convenient.

## Important rule

Do not make Slot's destructor perform release.

The Slot does not know whether an item belongs to:

* a Pool;
* an allocator;
* another owner;
* application code.

Therefore:

```text
Slot destructor
    ↓
assert empty
```

is potentially useful.

But this should be tested carefully.

A destructor on a struct has deterministic scope semantics when the struct itself is a value object. Heap allocation changes the situation. ([D Programming Language][1])

---

# 7. PolyNode

This part of the proposal is strong.

Recommended shape:

```d
struct PolyNode
{
    ...
}

struct Request
{
    PolyNode poly;
    uint id;
}
```

D lays struct fields out in lexical order.

Therefore:

```d
static assert(Request.poly.offsetof == 0);
```

is meaningful.

This is a real D advantage.

The conversion can therefore be:

```d
cast(T*)(cast(ubyte*)node - T.poly.offsetof)
```

with the offset checked at compile time.

D does not need an equivalent of Zig's `@fieldParentPtr` for this case.

---

# 8. PolyTag

The proposal's idea is correct:

> Every concrete Item type needs a stable identity that is not based on the address of the Item.

But the exact implementation should remain open.

The proposal uses:

```d
__gshared PolyTag tag;
```

That works as a direction, but it introduces `__gshared` and therefore `@system` concerns.

D's ordinary global mutable data is thread-local by default; `__gshared` explicitly makes it shared. `__gshared` provides no synchronization and is not allowed in `@safe` code. ([D Programming Language][4])

Before accepting it, test alternatives.

Candidate:

```text
module-level immutable tag
template-generated tag
__gshared tag
TypeInfo
```

`TypeInfo` is particularly interesting because D already gives every type a distinct runtime type object. ([D Programming Language][5])

But `TypeInfo` brings runtime dependencies.

Therefore:

> Do not use TypeInfo merely because it is convenient unless the Manual build remains acceptable.

The important invariant is:

```text
same T
    → same TAG

different T
    → different TAG

all threads
    → same TAG
```

The mechanism is secondary.

---

# 9. PolyHelper

D templates are a good match for PolyHelper.

A D implementation can validate:

```text
T is a struct
T has poly
T.poly is PolyNode
poly is first
```

at compile time.

D templates and `static if` are strong enough for this job. ([D Programming Language][6])

The API should probably contain:

```d
TAG!T
toPoly
fromPoly
mustFromPoly
initItem
```

Names can be adjusted to normal D style.

Do not force a literal translation of Zig's helper.

---

# 10. Intrusive list

The original proposal is correct that D's standard containers should not automatically determine the Matryoshka representation.

The important property is:

```text
Item
 |
 +-- PolyNode
       |
       +-- links
```

The list node must be inside the Item.

That gives:

* no wrapper allocation;
* no separate list node;
* type erasure;
* O(1) insertion/removal;
* movement between lists without changing the Item.

A small custom intrusive list is justified.

But keep it independent of:

```text
Manual
Managed
Mbox
Pool
```

The list should be a low-level primitive.

---

# 11. Synchronization

This is the first place where the original proposal is too aggressive.

D's:

```d
core.sync.mutex.Mutex
core.sync.condition.Condition
```

are classes.

That is a real problem for a manually allocated `Mbox`.

But it does **not** automatically mean:

> Write our own pthread/Win32 synchronization layer.

The current D runtime already provides `Mutex.lock_nothrow`, `unlock_nothrow`, shared overloads, and `@nogc` support. `Condition` also provides `@nogc`/`nothrow` operations. ([D Programming Language][2])

Therefore the first prototype must answer:

```text
Can core.sync be used for Managed Mbox?
Can core.sync be used acceptably for Manual Mbox?
Can the synchronization objects be allocated with the same policy?
What exactly does Manual require?
```

Only if the answer is no should dtk own OS wrappers.

## Likely final direction

There may be two synchronization implementations:

```text
Managed
    D runtime synchronization

Manual
    small native synchronization wrapper
```

But do not duplicate the entire Mbox.

The abstraction should be:

```text
Mutex
Condition
```

with the rest of Mbox shared.

---

# 12. `shared`

D's `shared` is worth using.

It is specifically intended to describe mutable data shared between threads. It prevents ordinary unshared access and can be combined with `core.atomic`. ([D Programming Language][7])

For a mailbox, this is probably better:

```d
shared(Mbox)* mbx;
```

than:

```d
Mbox* mbx;
```

with a comment saying:

> This object is thread safe.

But the implementation should avoid a forest of casts.

The ideal shape is:

```text
public shared API
        ↓
one trusted boundary
        ↓
ordinary internal representation
```

not:

```text
every field access
        ↓
cast away shared
```

D explicitly permits temporarily casting away `shared` while a mutex provides synchronization. ([D Programming Language][7])

That is useful for Matryoshka.

But it should be isolated in a tiny, auditable section.

## Important

`shared` should describe the **concurrency contract**, not become an implementation accident.

Prototype:

```text
single-thread Mbox
shared Mbox
Mbox passed to std.concurrency
Mbox passed to core.thread
```

Then decide.

---

# 13. `closed` does not necessarily need to be atomic

The original proposal assumes:

```d
shared bool closed;
```

plus atomic access.

That may be unnecessary.

If all mailbox state is protected by the mailbox mutex:

```text
closed
queue
oob state
wake state
```

can remain ordinary fields.

Atomic `closed` is only required if it is deliberately read outside the mutex.

Prefer:

```text
one synchronization mechanism
```

over:

```text
mutex + atomic closed
```

unless there is a measured reason.

This simplifies the memory model.

---

# 14. wakeUpAll

The epoch idea is useful.

But the explanation in the original proposal is too strong.

A condition variable wait must always be written around a predicate.

Conceptually:

```d
while (!condition)
    cond.wait(timeout);
```

A wake does not itself prove anything.

The epoch has a different job:

```text
queue state
    +
wake epoch
```

allows `wakeUpAll()` to be a deliberate Matryoshka event.

For example:

```text
send
    → item available

close
    → mailbox closed

wakeUpAll
    → waiter explicitly awakened

timeout
    → deadline expired

cancel
    → cancellation requested
```

This is much cleaner than trying to interpret every condition-variable wake.

## Keep the epoch

But use it for **Matryoshka wake semantics**.

Do not document it as a GC-wakeup detector.

---

# 15. Cancellation

This is one of the most important changes to the proposal.

The proposal removes cancellation because D has no equivalent of:

```text
Io.Cancelable
```

That is too quick.

Matryoshka cancellation is an architectural channel.

The D implementation does not need cancellable mutex acquisition to preserve it.

A possible model is:

```text
CancelToken
    |
    +-- atomic cancelled
```

and:

```text
receive(slot, timeout, cancel)
```

When cancellation occurs:

```text
cancel token
    ↓
wakeUpAll
    ↓
waiters wake
    ↓
each waiter checks its own token
```

This may produce a broadcast and therefore a thundering herd.

That is acceptable if cancellation is a control-plane operation.

It should not be presented as equivalent to a kernel-level per-waiter cancellation primitive.

## Recommendation

Keep:

```text
Status.canceled
CancelToken
wakeUpAll
```

in the first dtk prototype.

Do not implement a complicated per-waiter cancellation registry unless measurement shows it is necessary.

---

# 16. Timeout

D provides `MonoTime` specifically for monotonic timing.

That is the correct clock for Matryoshka timeouts. ([D Programming Language][8])

The correct conceptual pattern is:

```d
auto deadline = MonoTime.currTime + timeout;

while (!ready)
{
    if (cancelled)
        return Status.canceled;

    auto left = deadline - MonoTime.currTime;

    if (left <= Duration.zero)
        return Status.timeout;

    cond.wait(left);
}
```

The important property is the anchored deadline.

Do not restart the full timeout after every wake.

---

# 17. The Zig monotonic-clock issue

The original proposal identifies a potentially important issue in the Zig implementation:

```text
real clock
```

versus:

```text
monotonic clock
```

This should be checked against the actual current `matryoshka-ztk` implementation before treating it as a confirmed bug.

If confirmed, fix ztk independently.

The D implementation should use monotonic timing regardless.

D's `MonoTime` is explicitly intended for timing because wall-clock adjustments can make wall-clock timers expire too early or too late. ([D Programming Language][8])

---

# 18. Fiber support

No fiber support.

This is a deliberate Matryoshka-Tk rule.

The toolkit is intended for:

```text
threads
OS tasks
similar blocking-capable execution contexts
```

not:

```text
fibers
green threads
cooperative schedulers
event-loop tasks that must never block
```

A blocking mailbox receive is therefore allowed to block the underlying execution context.

This is not a defect in dtk.

It is part of the execution model.

A future adapter may provide:

```text
tryReceive()
+
external wake mechanism
```

but that adapter should not be part of the core toolkit unless there is a compelling reason.

---

# 19. Pool

The basic Pool architecture remains good.

The Pool should:

```text
create items
reuse items
release items
run hooks
```

It should not know concrete Item types beyond the tag/hook mechanism.

## Parallel arrays

The proposal's parallel-array idea is reasonable.

If the set of supported tags is fixed when the Pool is created:

```text
tags[]
lists[]
counts[]
```

can be indexed without a hash table.

That removes unnecessary dynamic lookup machinery.

But first measure the expected number of tags.

If there are normally:

```text
2–8 tags
```

linear lookup is probably preferable.

If there are hundreds or thousands, revisit the representation.

Do not optimize an assumed tag count.

---

# 20. Pool hooks

Keep the hook model close to Matryoshka.

Important rules:

```text
hooks do not throw
hooks do not call Pool recursively
hooks do not block
hooks may run outside the Pool lock
```

The proposal is right that allowing exceptions through Pool lifecycle hooks makes failure semantics much harder.

D can express `nothrow` in the hook type.

That is valuable.

---

# 21. `@nogc` hooks

This should not be solved by casting.

The original proposal considers:

```text
@nogc hooks
non-@nogc hooks
template Pool on Hooks
```

The third direction is the most interesting.

D function types include attributes such as `@nogc` and `nothrow`, so the compiler can propagate these requirements through templates. ([D Programming Language][9])

Therefore a good dtk design may be:

```text
Pool!(Manual, Hooks)
Pool!(Managed, Hooks)
```

or:

```text
Pool!(Policy, Hooks)
```

where the compiler sees the actual hook types.

Do not cast a throwing or GC-allocating hook into a `@nogc` function type.

That would defeat the purpose of compile-time verification.

---

# 22. Manual and Managed

This is a real part of dtk.

It is not a requirement for `matryoshka-otk` or `matryoshka-ztk`.

The desired model is:

```text
matryoshka-dtk
    |
    +-- Manual
    |
    +-- Managed
```

Both are first-class.

The application chooses at compile time.

## The important rule

Manual and Managed should share:

```text
PolyNode
Slot
ItemHandle
Mbox algorithm
Pool algorithm
hooks
Status
intrusive list
```

They should differ primarily in:

```text
allocation
release
attributes
```

That is a good design goal.

But do not force it to exactly three `static if`s.

If D requires more variation, let it happen.

The real rule is:

> Do not maintain two independent implementations of Matryoshka.

---

# 23. Manual does not automatically mean betterC

This is an important correction.

`@nogc` means a function does not perform GC allocation.

`-betterC` is a much larger restriction.

BetterC removes dependence on the D runtime and therefore excludes many ordinary D runtime facilities. At the same time, much of the D language and compile-time machinery remains available. ([D Programming Language][10])

Therefore:

```text
Manual
    ≠
betterC
```

The first target should be:

```text
Manual
    → @nogc
    → minimal runtime dependencies
```

BetterC should be a separate compatibility target.

Do not make the entire dtk design harder merely to satisfy BetterC before there is a concrete user need.

---

# 24. Allocation policy

The original proposal is right that the allocation mechanism should be an object/policy rather than a global namespace.

For example:

```d
struct Manual
{
    Arena* arena;
}

struct Managed
{
}
```

But the public API should not become allocator-heavy.

The user should not have to write:

```d
mbox.send(mbh, allocator, io, ...)
```

for every operation.

The policy belongs to the long-lived Matryoshka object.

Conceptually:

```text
create Mbox
    |
    +-- allocator/policy
    +-- synchronization
    +-- queue
```

After construction:

```text
send
receive
wakeUpAll
close
```

should not require the allocator.

This preserves one of the important Matryoshka design properties.

---

# 25. Managed memory and type-erased Items

This is one of the genuinely difficult parts of dtk.

If:

```text
Item = GC allocated
Mbox = manually allocated
```

and the only reference to the Item is inside the manually allocated Mbox,

the GC may not see the reference.

D provides `GC.addRange`, which can register manually allocated memory for scanning, but this is an explicit runtime mechanism. ([D Programming Language][4])

Therefore the safest first rule is:

```text
Managed
    toolkit storage is GC-visible
    Items may be GC-managed

Manual
    toolkit storage is manually managed
    Items are manually managed
```

Do not support arbitrary mixing initially.

Later, if there is a strong use case:

```text
manual Mbox
+
GC Items
```

can be investigated with explicit GC registration.

---

# 26. Manual item restrictions

Do not attempt to prove complete "no GC references" recursively unless there is a concrete need.

A compile-time trait can catch obvious cases:

```text
class
dynamic array
associative array
delegate
GC-managed fields
```

But it cannot prove provenance of:

```d
void*
ubyte*
```

or an arbitrary pointer.

Therefore document the boundary:

> Manual mode verifies the types it can verify. It does not make arbitrary pointers safe.

The application remains responsible for what an opaque pointer refers to.

---

# 27. Item destructors

The proposal says:

> Item types must not have destructors.

This is probably a good Matryoshka rule.

An Item is transported data.

Its lifecycle is controlled by:

```text
Pool hooks
```

not by GC finalization.

D class destructors are not deterministic under GC, while struct destructors are deterministic for value lifetimes but not necessarily when the struct itself is GC allocated. ([D Programming Language][11])

Therefore:

```text
Item
    data only

Pool hook
    lifecycle actions
```

is a clean rule.

But enforce it only after confirming that useful D Item types do not require destructors.

---

# 28. Error model

D exceptions should not become the normal Matryoshka control flow.

Use a small result/status model.

However, the original proposal says:

```text
Status enum
```

and then notes that an enum can be silently discarded.

A D-specific solution is attractive:

```d
@mustuse
struct Status
{
    Code code;
}
```

Then:

```d
mbox.send(slot);
```

cannot silently ignore the result.

D's `@mustuse` is specifically designed for this kind of discarded-result checking. ([D Programming Language][12])

This is a good example of dtk being better than a literal translation.

---

# 29. Result types

Do not automatically recreate Zig tagged unions.

For operations involving a Slot, this may be simpler:

```d
Status receive(ref Slot slot);
```

For operations where several distinct results are required:

```d
@mustuse
struct ReceiveResult
{
    Status status;
    ...
}
```

or a small tagged struct can be used.

The criterion should be:

```text
Is this easier to read and harder to misuse in D?
```

not:

```text
Does this resemble Zig?
```

---

# 30. std.concurrency

The comparison with `std.concurrency` is useful.

But it should not become a reason for dtk to copy `std.concurrency`.

The two systems solve different problems.

Conceptually:

```text
std.concurrency
    thread-oriented actor/message model
    runtime-managed mailbox
    Variant/message copying
    lifecycle/supervision

Matryoshka
    application Item
    zero-copy movement
    Pool-controlled lifecycle
    arbitrary Mailbox topology
    Master-controlled architecture
```

The most useful dtk relationship may actually be:

```text
control plane
    std.concurrency

data plane
    Matryoshka
```

if that combination proves convenient.

Do not make dtk replace `std.concurrency`.

---

# 31. TypeErasedQueue

The important distinction is:

```text
TypeErasedQueue
    owns queue storage

Matryoshka Mbox
    owns no Item storage
```

That distinction should remain.

Matryoshka deliberately separates:

```text
Mbox
    communication

Pool
    lifecycle/reuse

Allocator
    memory

Master
    policy/scheduling
```

This separation is one of the reasons to have Matryoshka.

Do not collapse these responsibilities merely because D has a convenient queue type.

---

# 32. Backpressure

Keep the Matryoshka rule:

> Backpressure belongs outside the Mailbox.

A bounded Pool can impose a system-level memory limit.

A bounded queue imposes a per-mailbox limit.

These are different policies.

For example:

```text
Mailbox A ─┐
Mailbox B ─┼──> Pool
Mailbox C ─┘
```

can share one bounded Item population.

That is different from giving every mailbox its own queue capacity.

---

# 33. `shared` and API shape

The current proposal makes `shared` a major part of the Mbox API.

I think that is promising, but it must be proven with actual D code.

The prototype should answer:

```text
shared(Mbox)*
    |
    +-- send
    +-- receive
    +-- close
    +-- wakeUpAll
```

Can all of these be implemented cleanly?

Can the internal state remain ordinary?

Can a single `@trusted` conversion establish the synchronization boundary?

If yes:

> Use `shared`.

That gives D programmers compiler-visible thread-sharing semantics rather than a comment.

If the result is a maze of casts:

> Do not use shared as the public Mbox representation.

D's `shared` is explicitly designed to prevent unsynchronized access, so it is worth trying before rejecting it. ([D Programming Language][7])

---

# 34. Execution model

`matryoshka-dtk` is thread-oriented.

A blocking operation such as:

```d
receive(...)
```

may block the underlying thread.

That is acceptable.

No fiber abstraction belongs in the core toolkit.

The toolkit does not promise:

```text
non-blocking receive
async receive
fiber-safe blocking
event-loop integration
```

Those can be separate adapters later.

---

# 35. Toolchain

Do not start with a large compiler matrix.

Use:

```text
DMD
LDC
Linux x86-64
debug
Manual
Managed
```

first.

DMD is the reference compiler.

LDC gives the LLVM backend and is important for realistic performance testing.

The current D documentation is versioned around D 2.112.0, so that is a reasonable starting baseline for experimentation. ([D Programming Language][13])

Do not choose the permanent minimum compiler version yet.

After the prototype:

```text
minimum compiler
latest compiler
```

can become CI targets.

GDC can come later.

---

# 36. CI order

Do not begin with:

```text
Linux
Windows
macOS
x86
ARM
DMD
LDC
GDC
TSan
ASan
betterC
GC stress
coverage
```

That is infrastructure before architecture.

Start with:

```text
1. Linux + DMD + Managed
2. Linux + DMD + Manual
3. Linux + LDC + Managed
4. Linux + LDC + Manual
```

Then add:

```text
5. TSan
6. release
7. Windows
8. macOS
9. ARM
10. GDC
11. betterC
```

Only after the design stabilizes.

---

# 37. Testing the design before implementing Matryoshka

The first prototype should not contain all of Matryoshka.

It should contain:

```text
PolyNode
PolyHelper
Slot
one intrusive list
one heap-allocated Mbox
one Item
one sender
one receiver
Manual policy
Managed policy
```

Example:

```text
Request
   |
   +-- PolyNode

Slot
   |
   +-- Request

Mbox
   |
   +-- Slot → send

receiver
   |
   +-- receive → Slot
```

Then test:

```text
create
send
receive
fromPoly
fromSlot
close
timeout
wakeUpAll
cancel
Manual allocation
Managed allocation
```

If this prototype is awkward, stop.

There is no reason to implement Pool, docs, CI, or examples before this works.

---

# 38. The most important feasibility tests

## Test 1 — heap Mbox

Can we create:

```d
Mbox* mbx;
```

with Manual allocation and destroy it deterministically?

Can the same API use Managed allocation?

---

## Test 2 — shared Mbox

Can:

```d
shared(Mbox)* mbx;
```

be passed to two threads and used naturally?

Can internal synchronization be implemented without pervasive casts?

---

## Test 3 — Slot

Can we get:

```d
@mustuse
non-copyable
Slot
```

with convenient:

```d
create(slot);
send(slot);
```

semantics?

---

## Test 4 — Manual

Can the public Manual path compile:

```d
@nogc nothrow
```

without requiring the GC?

---

## Test 5 — Managed

Can the same source be instantiated with:

```d
Managed
```

without a second implementation?

---

## Test 6 — cancellation

Can:

```text
blocked receive
    ↓
cancel
    ↓
wake
    ↓
Status.canceled
```

work without complicated machinery?

---

## Test 7 — PolyNode

Can a type-erased:

```d
PolyNode*
```

be converted back to:

```d
Request*
```

reliably across threads?

---

# 39. What would kill the port

Stop the project if one of these becomes true.

## 1. `shared` makes every API ugly

If every method needs several casts and `@trusted` blocks, reconsider the model.

## 2. Manual and Managed require two implementations

If:

```text
Manual Mbox
Managed Mbox
```

become materially different implementations, the policy design failed.

## 3. Slot cannot become convenient

If users constantly need:

```d
cast(...)
ref
scope
__rvalue
```

to perform ordinary Slot operations, simplify it.

## 4. The GC model becomes unpredictable

If Managed Items cannot reliably remain reachable while inside Mbox/Pool, stop and redesign the allocation boundary.

## 5. Synchronization becomes a library project by itself

A small OS wrapper is acceptable.

A complete synchronization framework is not.

## 6. `@trusted` spreads everywhere

A small trusted boundary is acceptable.

A toolkit whose public API is mostly trusted pointer manipulation is not a good D library.

---

# 40. What would make dtk especially good

D can potentially improve Matryoshka in several areas.

## Slot

```text
non-copyable
move-aware
@mustuse
```

## Compile-time validation

```text
PolyNode present
correct type
correct layout
correct hooks
correct policy
```

## Memory policy

```text
same source
Manual
Managed
```

## API contracts

```text
nothrow
@nogc
@safe where practical
```

## Struct invariants

D provides contracts that can verify internal relationships during development.

This should be used for:

```text
list consistency
counts
OOB state
Pool state
closed state
```

but not relied upon for correctness in release builds.

---

# 41. What should not be copied from the original proposal

Do not start with these decisions.

```text
custom pthread/Win32 synchronization
per-waiter cancellation structure
parallel arrays everywhere
Manual/Managed import aliases
strict Slot destructor
shared Mbox raw-cast pattern
no item destructors
betterC support
large CI matrix
complete documentation port
```

They are hypotheses.

Some will survive.

Some will not.

---

# 42. Proposed first architecture

The first design to prototype is:

```text
                    +----------------+
                    |     Master     |
                    +-------+--------+
                            |
             +--------------+--------------+
             |                             |
        +----v----+                   +----v----+
        |   Mbox  |                   |   Pool  |
        +----+----+                   +----+----+
             |                             |
             | ItemHandle                  |
             |                             |
             +-------------+---------------+
                           |
                      +----v----+
                      |  Item   |
                      | PolyNode|
                      +---------+
```

With:

```text
Mbox*        heap allocated
Pool*        heap allocated
Item*        application allocated
Slot         temporary handle container
PolyNode     embedded in Item
```

Memory policy:

```text
Manual
    manually allocated

Managed
    GC allocated
```

Execution:

```text
threads
```

No fibers.

---

# 43. Proposed API direction

Not final API.

Something approximately like:

```d
Mbox* mbx = createMbox!Manual(...);
Pool* pool = createPool!Manual(...);

Slot slot;

create!Request(slot);

auto request = fromSlot!Request(slot);

auto status = mbx.send(slot);

status = mbx.receive(slot, timeout, cancel);

mbx.wakeUpAll();

mbx.close();
```

The exact syntax is deliberately open.

The important property is:

```text
long-lived infrastructure
    → pointer

temporary Item transfer
    → Slot

application Item
    → ItemHandle / PolyNode
```

This preserves the Matryoshka model while allowing D to shape the syntax.

---

# 44. Memory policy API

The internal implementation can be:

```d
struct Manual
{
    ...
}

struct Managed
{
    ...
}
```

and:

```d
MboxImpl!(Manual)
MboxImpl!(Managed)
```

or a similar design.

But the public API should ideally allow:

```text
matryoshka.manual
matryoshka.managed
```

without duplicating implementation.

The final naming is open.

Do not decide this before the prototype demonstrates what D's template and module system make pleasant.

D templates are powerful enough to parameterize types, values, aliases, and complete aggregate types. ([D Programming Language][6])

---

# 45. BetterC

Treat BetterC as a secondary target.

First establish:

```text
Manual
@nogc
nothrow
minimal runtime dependency
```

Then test:

```text
-betterC
```

If it works naturally:

> support it.

If it requires ugly architecture:

> document Manual as the supported low-level mode and leave BetterC unsupported.

BetterC is a D language subset designed specifically to avoid dependence on the D runtime. It should therefore be evaluated as a separate compatibility target, not confused with Manual memory management. ([D Programming Language][10])

---

# 46. Documentation

Do not port the entire Zig documentation before the implementation exists.

The D site should eventually have:

```text
Overview
Differences from ztk
Installation
Architecture
Slot
PolyNode
Mailbox
Pool
Manual vs Managed
Concurrency
Examples
API reference
```

The most important D-specific page will probably be:

```text
Differences from matryoshka-ztk
```

because a Matryoshka reader already understands the architecture.

The D documentation should explain:

```text
what stayed the same
what changed
why it changed
```

Do not translate Zig documentation mechanically.

---

# 47. Documentation relationship between *tk repositories

Keep the implementations separate.

Shared conceptual material can remain canonical in one repository where appropriate.

But D-specific subjects should be written in dtk:

```text
D Slot
D shared
D Manual/Managed
D @nogc
D betterC
D synchronization
```

Do not force readers to understand Zig implementation details before understanding dtk.

---

# 48. Recommended development order

```text
1.  PolyNode
2.  PolyHelper
3.  intrusive list
4.  Slot
5.  Manual allocation
6.  Managed allocation
7.  synchronization abstraction
8.  Mbox
9.  cancellation
10. close/wakeup/timeout
11. Pool
12. hooks
13. concurrency tests
14. performance tests
15. Windows
16. macOS
17. BetterC evaluation
18. documentation
```

Do not start with Pool.

Do not start with documentation.

Do not start with CI.

The critical unknowns are lower in the stack.

---

# 49. Initial compiler recommendation

For the first prototype:

```text
DMD
LDC
current stable D
Linux x86-64
```

Do not commit yet to a permanent minimum compiler version.

Once the prototype is working:

```text
minimum supported version
latest stable
```

can be tested in CI.

The important thing is to avoid making the initial design depend on compiler quirks.

---

# 50. Final design questions

These remain deliberately open.

```text
[ ] Public Mbox/Pool: struct pointer or opaque struct pointer?
[ ] Public methods or module functions?
[ ] Exact Slot representation?
[ ] Slot copy/move rules?
[ ] Slot destructor assertion?
[ ] Exact PolyTag mechanism?
[ ] Use shared on Mbox API?
[ ] D runtime synchronization for Managed?
[ ] Native synchronization wrapper for Manual?
[ ] Exact cancellation API?
[ ] Exact Manual/Managed template boundary?
[ ] Exact Item allocation rules?
[ ] Item destructor prohibition?
[ ] BetterC support?
[ ] Minimum compiler version?
```

None of these should be called "decided" until the prototype tests them.

---

# 51. Go / no-go test

Before creating the full `matryoshka-dtk` implementation, build a small experimental repository or branch.

The prototype should be roughly:

```text
PolyNode
PolyHelper
Slot
Item
List
Mbox
Manual
Managed
```

Nothing more.

Success means:

```text
D code looks like D.

Matryoshka concepts remain visible.

Manual and Managed share implementation.

The Slot is pleasant.

Mbox is pleasant.

shared is manageable.

Synchronization is small.

@nogc is actually enforced.

The amount of @trusted code is small.

No hidden GC dependency appears in Manual mode.
```

If those conditions hold:

> **Start matryoshka-dtk.**

If they do not:

> **Do not port the rest.**

---

# 52. Bottom line

The original proposal contains enough good ideas to justify a D experiment.

But it is premature as an implementation specification.

The most promising D-specific direction is:

```text
heap-allocated structs
        +
D templates
        +
non-copyable Slot
        +
@mustuse
        +
shared where it genuinely helps
        +
Manual / Managed compile-time policy
        +
small synchronization boundary
        +
Matryoshka's existing architecture
```

The most dangerous direction is:

```text
custom runtime
+
custom synchronization
+
custom allocator
+
custom ownership system
+
custom cancellation system
+
BetterC
+
large CI matrix
```

That would turn Matryoshka-D into a large systems library before proving that the core idea fits D.

So the recommendation is:

> **Yes, investigate `matryoshka-dtk`.**
>
> **No, do not start the full port from the current handbook.**
>
> First build the smallest possible D prototype and let D decide which parts of this proposal survive.

[1]: https://dlang.org/spec/struct.html?utm_source=chatgpt.com "Structs, Unions - D Programming Language"
[2]: https://dlang.org/library/core/sync/mutex.html?utm_source=chatgpt.com "Module core.sync.mutex - D Programming Language"
[3]: https://dlang.org/spec/attribute.html?utm_source=chatgpt.com "Attributes - D Programming Language"
[4]: https://dlang.org/library/core/memory/gc.add_range.html?utm_source=chatgpt.com "Function GC.addRange - D Programming Language"
[5]: https://dlang.org/book/object.html?utm_source=chatgpt.com "Object - D Programming Language"
[6]: https://dlang.org/spec/template.html?utm_source=chatgpt.com "Templates - D Programming Language"
[7]: https://dlang.org/spec/const3.html?utm_source=chatgpt.com "Type Qualifiers - D Programming Language"
[8]: https://dlang.org/phobos/core_time.html?utm_source=chatgpt.com "core.time - D Programming Language"
[9]: https://dlang.org/spec/function.html?utm_source=chatgpt.com "Functions - D Programming Language"
[10]: https://dlang.org/spec/betterc.html?utm_source=chatgpt.com "Better C - D Programming Language"
[11]: https://dlang.org/spec/class.html?utm_source=chatgpt.com "Classes - D Programming Language"
[12]: https://dlang.org/library/core/attribute.html?utm_source=chatgpt.com "Module core.attribute - D Programming Language"
[13]: https://dlang.org/library/core/sync/mutex/mutex.lock.html?utm_source=chatgpt.com "Function Mutex.lock - D Programming Language"


# PolyHelper improvements

If PolyHelper may be generated with 2 variants for Manual amd Managed, it can create additionally to tag type of allocation mode - and check in code later

Yes. I think this is a **very good direction**, and actually stronger than keeping Manual/Managed only as an allocator policy.

The important idea is:

> **Make allocation mode part of the generated type information, so Matryoshka can verify that an Item is used with a compatible Pool/allocator at compile time or at a very cheap runtime check.**

For example, conceptually:

```d
PolyHelper!(Request, Manual)
```

could generate:

```d
enum TAG = ...;
enum ALLOCATION_MODE = AllocationMode.manual;
```

while:

```d
PolyHelper!(Request, Managed)
```

generates:

```d
enum TAG = ...;
enum ALLOCATION_MODE = AllocationMode.managed;
```

But there is an important distinction.

### I would NOT make Manual/Managed part of the `TAG`

Keep these as two independent properties:

```text
             Item type
                |
        +-------+-------+
        |               |
       TAG         AllocationMode
        |               |
     Request          Manual
```

`TAG` answers:

> "What Item type is this?"

`AllocationMode` answers:

> "Under which allocation regime was this Item created?"

Combining them into one tag would make the type identity depend on allocation policy:

```text
Request + Manual != Request + Managed
```

That is probably undesirable.

Instead:

```d
struct ItemInfo
{
    PolyTag tag;
    AllocationMode allocation;
}
```

or equivalent generated compile-time information.

---

## The interesting consequence

Suppose:

```d
alias RequestM = PolyHelper!(Request, Manual);
alias RequestG = PolyHelper!(Request, Managed);
```

Then Pool can be parameterized by mode:

```d
Pool!(Manual)
Pool!(Managed)
```

and `get!Request` can verify:

```text
Pool mode == Item mode
```

This gives you a very useful invariant:

```text
Manual Pool
    ↓
Manual Item

Managed Pool
    ↓
Managed Item
```

You don't accidentally do:

```text
Managed Pool
    ↓
Manual Item
```

or:

```text
Manual Pool
    ↓
Managed Item
```

---

# But I would go one step further

I would investigate whether the allocation mode can be encoded **entirely at compile time**.

For example:

```d
enum AllocationMode
{
    manual,
    managed
}

struct PolyHelper(T, AllocationMode mode)
{
    enum TAG = ...;
    enum MODE = mode;
}
```

Then:

```d
Pool!(Manual).get!Request(...)
```

knows at compile time:

```text
Request.MODE == Manual
```

If it doesn't match, compilation fails.

That is much better than:

```d
if (item.mode != pool.mode)
    ...
```

because the latter means you discovered a programming error at runtime.

---

# Where runtime checking is still useful

There is one case where your idea becomes particularly valuable.

Because `PolyNode` is **type-erased**, eventually you may have:

```d
PolyNode*
```

and have lost the D generic information.

At that point the allocation mode may no longer be available through the static type.

So the generated `PolyHelper` could put a tiny descriptor into the erased representation:

```text
PolyNode
   |
   +-- TAG
   +-- AllocationMode
```

Then code operating on an erased Item can verify:

```text
expected mode == actual mode
```

This is a reasonable runtime safety check.

But I would distinguish:

```text
static check
    ↓
when T is known

runtime check
    ↓
when only PolyNode/ItemHandle is known
```

That's a very D-like design.

---

# Even more interesting: this could solve a larger problem

It gives dtk a coherent notion of an **Item's allocation domain**.

For example:

```text
Manual Item
    belongs to Manual Pool
    released by Manual Pool

Managed Item
    belongs to Managed Pool
    released by Managed Pool
```

That is more than just "which allocator did `new` use?"

It becomes a Matryoshka invariant.

You could eventually have:

```d
struct ItemMeta
{
    PolyTag tag;
    AllocationMode mode;
}
```

and perhaps:

```text
Pool
    expected mode
    accepted tags
```

Then the Pool can reject an Item that does not belong to its allocation regime.

---

# One caution

I would **not** let `PolyHelper!(T, Manual)` and `PolyHelper!(T, Managed)` generate two fundamentally different `T` representations.

The application type should remain:

```d
struct Request
{
    PolyNode poly;
    ...
}
```

not:

```d
struct ManualRequest { ... }
struct ManagedRequest { ... }
```

The allocation mode belongs to the **Matryoshka metadata**, not the application Item.

Otherwise Manual/Managed starts leaking into application types, which would defeat the purpose of having one dtk API.

---

# My recommendation

I would change the dtk design in this direction:

```text
                    PolyHelper!(T, Mode)
                           |
              +------------+------------+
              |                         |
             TAG                     ALLOCATION_MODE
              |                         |
          item identity             lifecycle domain
```

Then:

```text
Pool!(Mode)
   |
   +-- accepts Items with matching Mode
```

and:

```text
PolyNode / ItemHandle
   |
   +-- carries enough metadata for runtime verification
       when static type information is unavailable
```

So yes: **I think your idea is better than the current proposal's Manual/Managed design.**

The particularly strong part is not merely "store the mode in the tag". It is:

> **Make allocation mode a first-class property generated together with the type-erasure machinery, with compile-time checking whenever possible and runtime checking only after type erasure.**

That gives `matryoshka-dtk` a clean answer to one of the hardest questions we identified: **how does an erased Item know which lifecycle regime it belongs to?**
