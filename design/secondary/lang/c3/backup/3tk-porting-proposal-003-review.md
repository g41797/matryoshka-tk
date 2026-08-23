# Review of `3tk-porting-proposal-003.md`

## Scope

This review checks:

- remaining contradictions;
- wrong or weak assumptions;
- implementation risks;
- possible design improvements;
- whether `Mailbox` and `Pool` can hide their implementation without changing
  functionality.

The review is about the design and implementation.

It is not advice about improving the document structure or prose.

---

# Overall judgement

003 is substantially better than 002.

The three literal contradictions found in the previous review were actually
fixed:

- two conceptual parts versus three fields;
- seven Part 7.2 clauses versus nine helper members;
- sixteen versus fifteen list operations.

The previous ambiguity around closed `receive_all` was also removed at the
specification level by invariant 34.

The `Slot` boundary, `@check` side-effect rule, `Pool.put`'s two Slot domains,
list count invariant, and fixed pool bucket rules are all useful improvements.

I found no new fundamental contradiction in the main architecture.

However, I found one important point where **D1's conclusion is based on an
unnecessarily narrow assumption**:

> hiding `Mailbox` and `Pool` requires making the public type an opaque
> `typedef ... = void`, therefore it necessarily breaks Part 11.1.

I do **not** think that conclusion has been proved.

There is a plausible fourth design:

```text
public Mailbox / Pool item
        |
        | owns
        v
private implementation object
````

This preserves the container itself as an item.

It hides the actual mutex, condition variable, lists, buckets and state.

Therefore:

**yes, I think Mbox and Pool implementation can probably be hidden without
changing observable functionality and without violating the architectural
meaning of Part 11.1.**

Whether this is worth doing is a separate question.

My conclusion is that D1 should be reconsidered technically.

Not necessarily reversed.

But the current statement:

> "The only C3 mechanism that delivers it costs Part 11.1 MUST"

is too strong.

---

# 1. Major finding — D1 assumes only two implementation shapes

The current argument is approximately:

```text
Option 1
Public struct and public fields.

Option 2
Opaque public type:
    typedef Pool = void

Therefore hiding means Pool itself cannot embed AnyNode.

Therefore hiding costs Part 11.1.
```

That skips a third important shape:

```text
struct Pool
{
    AnyNode node;
    PoolImpl* impl;
}
```

where:

```text
Pool
    public representation
    application-visible type
    itself an item

PoolImpl
    implementation representation
    hidden inside mtk::pool
```

For example conceptually:

```c3
module mtk::pool;

struct Pool
{
    AnyNode node;
    PoolImpl* impl;
}

@private struct PoolImpl
{
    Mutex mu;
    Atomic(bool) closed;
    Allocator allocator;

    PoolBucket[] buckets;

    // remaining implementation state
}
```

The exact C3 visibility and incomplete-type mechanics must of course be
verified.

But architecturally this is different from:

```c3
typedef Pool = void;
```

The public `Pool` still:

* is the type named by the application;
* embeds `AnyNode`;
* is itself an item;
* can sit on `NodeList`;
* crosses through `mtk::helper{Pool}`;
* satisfies the literal shape of Part 11.1.

Only its mutable implementation state moves elsewhere.

Therefore the statement that hiding necessarily requires replacing `Pool` with
`PoolImpl` is not generally true.

The same applies to `Mailbox`.

---

# 2. The key question is what Part 11.1 actually requires

The proposal correctly treats this as important.

But there are two different requirements that must not be collapsed.

## Requirement A

The container is itself an item.

For example:

```text
Pool
 ├── AnyNode
 └── ...
```

This allows:

```text
Pool*
    ↓ helper
AnyHandle
    ↓
NodeList
```

## Requirement B

Every byte of the container's implementation state is physically inside the
same public struct.

These are not the same requirement.

Part 11.1 appears to require A.

D1 currently assumes A implies B.

That implication needs proof.

Without such proof, a split representation remains possible.

---

# 3. Recommended hidden implementation shape

I would investigate this shape first:

```text
                 application
                     |
                     v
             +---------------+
             |    Mailbox    | public
             |---------------|
             | AnyNode node  |
             | MailboxImpl * |
             +---------------+
                     |
                     v
             +-------------------+
             |    MailboxImpl    | private
             |-------------------|
             | Mutex             |
             | ConditionVariable |
             | closed state      |
             | wake generation   |
             | NodeList          |
             | allocator         |
             +-------------------+
```

and:

```text
                 application
                     |
                     v
             +---------------+
             |     Pool      | public
             |---------------|
             | AnyNode node  |
             | PoolImpl *    |
             +---------------+
                     |
                     v
             +-------------------+
             |     PoolImpl      | private
             |-------------------|
             | Mutex             |
             | closed state      |
             | allocator         |
             | PoolBucket[]      |
             | hook state        |
             | counters          |
             +-------------------+
```

This gives a useful separation:

```text
public identity
    ≠
private operational state
```

The container's identity remains part of the intrusive system.

Its operational machinery becomes hidden.

That is actually consistent with the central boundary already introduced in
section 0.

---

# 4. Would this change functionality?

I do not see an inherent functional change.

The public operations can remain exactly the same.

For example:

```text
Mailbox.create
Mailbox.send
Mailbox.send_oob
Mailbox.receive
Mailbox.poll
Mailbox.wake_all
Mailbox.close
```

and:

```text
Pool.create
Pool.get
Pool.get_wait
Pool.put
Pool.close
```

do not need different semantics.

The application still sees:

```text
Mailbox
Pool
AnyNode
AnyHandle
Slot
```

The implementation merely changes:

```text
self._mu
```

into conceptually:

```text
self.impl.mu
```

That is implementation hiding, not functionality change.

The important exception is lifetime.

The split design creates an additional allocation and lifetime relation.

That is the real cost.

---

# 5. The real cost of hiding is lifetime complexity, not Part 11.1

This is the strongest argument against the split design.

`Mailbox` and `Pool` currently have one allocation identity.

With a private implementation pointer they may have two:

```text
Pool
PoolImpl
```

You must answer:

1. Who allocates `PoolImpl`?
2. Which allocator owns it?
3. Can creation partially fail?
4. What happens if `Pool` is initialized but `PoolImpl` allocation fails?
5. Which object is destroyed first?
6. Can a public `Pool` outlive its implementation?
7. Can the item identity survive after close but before destruction?
8. Is a zero-initialized `Pool` meaningful?
9. Does the implementation pointer itself become another visible field?

These are real costs.

But they are not the same as breaking Part 11.1.

I would therefore replace the D1 reasoning with:

> Full hiding is possible only by adding an indirection or another private
> representation boundary. The public container can remain an item, so Part
> 11.1 need not be sacrificed. The port rejects the extra allocation and
> lifetime complexity rather than claiming that C3 makes the two requirements
> technically incompatible.

That would be a much stronger decision if you keep public fields.

---

# 6. Better option: hide state without a second allocation if C3 permits an incomplete private implementation

There is another possibility worth checking before accepting either design.

Conceptually:

```c3
struct PoolImpl;

struct Pool
{
    AnyNode node;
    PoolImpl impl;
}
```

with the complete `PoolImpl` definition private to the implementation module.

If C3 permits a public struct to contain a value of an incompletely declared
type whose definition is hidden, this would be ideal.

But many languages cannot determine the size of such a public struct without
the complete definition.

So I consider this less likely.

Still, it is worth a small capability test because it would give:

```text
public item identity
+
hidden implementation
+
no second allocation
```

If C3 does not support it, discard it.

Do not assume either way.

---

# 7. Another possible shape: public opaque storage

A more complicated possibility is fixed private storage:

```c3
struct Pool
{
    AnyNode node;
    alignas(...) char[N] storage;
}
```

with the private module treating `storage` as `PoolImpl`.

I do **not** recommend this.

It creates several bad problems:

* fixed implementation size becomes ABI/API;
* alignment becomes part of the public contract;
* changing implementation size can break users;
* manual placement construction is needed;
* type safety becomes worse;
* the public type still exposes mysterious storage.

This is technically possible in some systems languages but is inferior here.

I would reject it unless a strong ABI requirement appears.

---

# 8. My recommendation on hiding

I would not automatically change 3TK to a hidden implementation.

The current direct representation has real advantages:

```text
one allocation
simple lifetime
simple creation
simple destruction
no null impl state
no indirection
easy zero initialization
```

For a low-level toolkit, these are valuable.

My recommendation is:

## Keep the current implementation unless implementation hiding is an important product goal.

But fix D1's assumption.

The decision should say:

```text
D1 — Public direct representation is chosen.

Not because hiding would violate Part 11.1.

A split representation could preserve the container as an item while hiding its
operational state.

It is rejected because the extra pointer, allocation, lifetime state and
indirection are not worth the stronger information hiding for this toolkit.
```

That is, in my view, the correct technical argument.

---

# 9. D1 and section 0 are slightly in tension

Section 0 says:

> `mtk` owns the inner protocol.

and:

> containers sit above the toolkit rather than inside it.

D1 then allows applications to inspect operational container fields.

For example, conceptually:

```text
application
    ↓
Pool._mu
Pool._closed
Pool._buckets
```

The document says this is only a convention problem.

That is true.

But it means the central boundary is not as clean for containers as it is for
application items.

The application cannot legally cross:

```text
outer -> AnyNode
```

by hand.

But it can directly reach:

```text
Pool implementation state
```

because fields are public.

This does not break Matryoshka's polymorphic model.

It does weaken the general information boundary.

That is another reason to distinguish:

```text
polymorphic boundary
```

from:

```text
container implementation hiding
```

They solve different problems.

The helper border does **not** replace implementation hiding.

It only solves the outer/inner crossing problem.

The current D1 wording:

> "the helper border does the work"

therefore overstates what the helper border actually does.

Recommended correction:

> The helper border protects the polymorphic representation boundary.
> It does not hide container operational state.
> The port deliberately accepts public operational fields because the cost of a
> second representation boundary is not justified.

This is much more exact.

---

# 10. Possible implementation improvement — separate identity from operational state even if fields remain public

Even if you keep direct public structs, I recommend grouping fields by role.

Conceptually:

```c3
struct Pool
{
    // Item identity.
    AnyNode node;

    // Lifetime.
    Allocator allocator;

    // Synchronization and state.
    Mutex _mu;
    Atomic(bool) _closed;

    // Pool implementation.
    PoolBucket[] _buckets;

    // ...
}
```

Do the same for `Mailbox`.

This makes the distinction visually explicit:

```text
node
    identity in Matryoshka

everything else
    implementation of this container
```

It also makes a future split representation easier.

---

# 11. Remaining contradiction — Part 4.2 row still contains old D3 wording

003 correctly states elsewhere:

> two conceptual parts / three fields.

But the mapping row still says, according to the retrieved text:

> `prev`, `next`, `type`. 24 bytes. **D3 part 2 refuses a third**

That last clause is still wrong terminology.

There are already three fields.

It should be something like:

> `prev`, `next`, `type`. 24 bytes. Two conceptual parts. D3 refuses an
> additional per-item allocator responsibility in the inner.

This is a small but literal contradiction left after the earlier fix.

---

# 12. Remaining contradiction — D12 still refers to "a third field"

The retrieved D12 text says:

> D3 already refused a third field in the inner for a stronger reason.

Again, the inner already has three fields.

This should be changed to:

> D3 already refused an additional per-item allocator field in the inner for a
> stronger reason.

or:

> D3 already refused adding another field to the inner.

The first is better because it says what the rejected field actually was.

---

# 13. The 24-byte statement is target-specific and should not leak into a general design invariant

The proposal says:

> `prev`, `next`, `type`. 24 bytes.

This is true for the measured Linux x64 configuration.

But the document otherwise describes the port design, not only one exact ABI.

The actual invariant is:

```text
two pointer links
+
one typeid value
```

The 24 bytes are an observation.

Do not accidentally make size part of correctness.

Implementation advice:

* keep the measurement as an implementation assertion/test for Linux x64 if
  desired;
* do not let code or design logic depend on `sizeof(AnyNode) == 24`.

---

# 14. `AnyHandle` nullability and Slot emptiness are still dangerously close concepts

003 improves this by explicitly stating that `AnyHandle` is nullable.

But the design has:

```text
AnyHandle
    nullable pointer

Slot
    typedef around AnyHandle

empty Slot
    null pointer
```

This is correct.

The implementation risk is accidental use of an ordinary `AnyHandle` where the
code is semantically dealing with ownership transfer.

D5 helps only because `Slot` is distinct.

I recommend one stricter implementation rule:

```text
A function returns AnyHandle only when it transfers or exposes an item handle.

A function takes Slot* when it may consume, fill, or preserve a transfer
location.

A function takes AnyHandle when it only observes or links an already-owned
handle according to its contract.
```

This is more useful for implementation review than merely saying "Slot is
distinct".

---

# 15. `NodeList` count and link mutations should be implemented as one internal primitive layer

The count invariant is now explicit.

That is good.

The implementation should go one step further.

Do not let every public list operation separately manipulate:

```text
prev
next
head
tail
len
```

Create a very small private mutation core.

Conceptually:

```text
link_front
link_back
unlink
append_chain
```

Then all public operations compose these.

This reduces the chance of:

```text
links correct
len wrong
```

or:

```text
len correct
tail wrong
```

The proposal already has checks.

But this is an implementation simplification.

For intrusive structures, fewer mutation sites are usually better than more
checks around many duplicated mutations.

---

# 16. Potential wrong assumption — "no path takes two locks, so there is no ordering to state"

The retrieved Part 15.2 wording says:

> No path takes two locks, so there is no ordering to state.

This is true only if:

* application hooks are always called without a container lock;
* no allocator implementation itself introduces relevant locking concerns into
  the toolkit's own lock ordering model;
* no future operation coordinates Mailbox and Pool while holding either lock.

For the current implementation it may be true.

But I would avoid encoding it as a timeless property.

Better:

> No current toolkit path holds one container mutex while acquiring another
> container mutex. Therefore the current toolkit has no inter-container lock
> order.

This is narrower and reviewable.

---

# 17. Potential implementation issue — the pre-lock fast path needs the atomic closed state to be treated as a hint only

The proposal already has:

```text
acquire outside
relaxed inside
release on store
re-read under the lock
```

That is the right general idea.

The important implementation rule is:

```text
outside the lock:
    atomic value may reject work early

inside the lock:
    the mutex-protected state is authoritative
```

Do not let any path do:

```text
if atomic_closed == false
    mutate state without lock
```

The pre-lock atomic is only a fast rejection.

The proposal appears to intend this.

I would make this an implementation invariant because this kind of optimisation
is easy to "improve" incorrectly later.

---

# 18. Pool hook execution deserves one hard state boundary

The proposal correctly has:

```text
unlock
call application hook
relock
```

The implementation should make the handoff state explicit.

Before unlocking:

* the item must already belong to neither the caller's Slot nor a pool list
  unless the operation explicitly intends otherwise;
* every internal invariant visible to another thread must already hold;
* the hook-local Slot must contain the only temporary ownership representation.

After relocking:

* the hook result must be treated as fresh input;
* do not assume the item is still the same unless the hook contract requires it;
* do not retain pointers into mutable pool storage across the unlock.

This is especially important for `on_put`.

The two-Slot design fixes caller semantics.

It does not by itself guarantee safe state handling around arbitrary application
code.

---

# 19. Pool bucket lookup should avoid storing unstable references across hook calls

003 defines a fixed bucket array.

That is good.

If a hook runs outside the mutex, implementation code must not keep:

```text
PoolBucket*
```

or references into bucket storage across:

```text
unlock
hook
relock
```

unless the bucket array is truly immutable in address and lifetime.

The array itself may be fixed.

But its contents are mutable.

My recommendation:

```text
look up by identity again after every application callback
```

The lookup is linear, but the bucket count is fixed and correctness is more
important than preserving a pointer through arbitrary application code.

If performance later matters, prove that the pointer's address and identity are
stable before optimizing.

---

# 20. The fixed bucket array and duplicate identity check are good, but creation failure needs transactional cleanup

003 added duplicate identity rejection.

Good.

Now verify creation as a transaction.

If `Pool.create` does:

1. allocate bucket array;
2. initialize buckets;
3. validate identities;
4. initialize hooks;
5. initialize remaining state;

then every failure after step 1 must free exactly what has already been
allocated or initialized.

Do not rely on `close` unless a partially constructed Pool satisfies `close`'s
normal preconditions.

I recommend a private creation cleanup path:

```text
Pool.create
    ↓
allocate
    ↓ failure -> return
initialize partial state
    ↓ failure -> private destroy_partial
validate duplicates
    ↓ failure -> private destroy_partial
publish initialized Pool
```

The public object should not become observable as a valid item until creation
has completely succeeded.

---

# 21. `Pool.close` and `Mailbox.close` should not destroy implementation state if the item can still participate in a higher-level list

This becomes especially important if D1 is changed.

The distinction should remain:

```text
close
    changes container operational state
    gives back contained items
    wakes waiters

destroy / release
    ends the container object's lifetime
```

Do not merge them.

The container itself is an item.

A closed container may still have an `AnyNode` identity and may still need to
be transferred or released by its outer owner.

If the implementation is hidden behind `Impl*`, `close` should not free `Impl`
unless the public lifetime contract explicitly says the container becomes
unusable as an item.

I strongly recommend:

```text
close != destroy
```

as an implementation rule.

---

# 22. Hidden implementation has one important interaction with allocator storage

D3 says:

> Containers keep one allocator.

With:

```text
struct Pool
{
    AnyNode node;
    PoolImpl* impl;
}
```

where should that allocator live?

There are two reasonable answers.

## A. Public Pool stores it

```text
Pool
 ├── node
 ├── allocator
 └── impl
```

Then the item's lifetime owner is visible and the implementation uses it.

## B. PoolImpl stores it

```text
Pool
 ├── node
 └── impl

PoolImpl
 └── allocator
```

Then destroying `PoolImpl` requires reaching the implementation first.

I prefer A if you choose the split design.

Reason:

```text
outer lifetime state
    belongs to outer
```

This is exactly the same principle D3 already uses for application-owned items.

Then:

```text
Pool
    owns its lifetime allocator

PoolImpl
    owns operational state allocated through that lifetime
```

This is more consistent than putting the allocator exclusively in the hidden
implementation.

---

# 23. A possible better D1 design if hiding matters

If you decide that Part 11.11 is worth implementing, I recommend:

```c3
struct Mailbox
{
    AnyNode node;
    Allocator allocator;
    MailboxImpl* impl;
}

struct Pool
{
    AnyNode node;
    Allocator allocator;
    PoolImpl* impl;
}
```

with `MailboxImpl` and `PoolImpl` private.

This preserves:

* literal public container item;
* `AnyNode` embedding;
* one public type for application and helper;
* ordinary `helper{Mailbox}`;
* ordinary `helper{Pool}`;
* all existing public operations;
* no typed handles;
* no change to Slot semantics;
* no change to Mailbox/Pool behaviour.

The cost is:

* one extra pointer;
* likely one extra allocation;
* two-level destruction;
* slightly more complicated partial creation;
* one extra pointer dereference.

This is the real tradeoff.

It should be evaluated as such.

---

# 24. I would not hide `AnyNode`, `NodeList`, or the helper machinery in the same way

The D1 question is specifically more interesting for Mailbox and Pool.

The core toolkit is different.

`AnyNode` deliberately has a visible representation because:

```text
application outer
    contains
AnyNode
```

The helper's compile-time offset logic needs a real field.

`NodeList` is itself a low-level representation type.

Trying to hide those in the same way would fight the central design.

The containers are the natural place for a private operational implementation
boundary because they have much more operational state than identity state.

---

# 25. Strongest remaining assumption to verify experimentally

Before changing D1, write a very small C3 capability experiment.

Test whether this works:

```c3
module mtk::pool;

struct Pool
{
    mtk::AnyNode node;
    PoolImpl* impl;
}

@private struct PoolImpl
{
    int x;
}

fn void use(Pool* p)
{
    p.impl.x = 1;
}
```

Then from another module verify:

```c3
Pool p;
p.node = ...;     // expected visible if Pool fields are public
p.impl = ...;     // what exactly is accessible?
```

The important questions are:

1. Can a public struct field have a private type?
2. Can external code name that field's type?
3. Does C3 permit taking/assigning the field outside the module?
4. Can the private type be forward-declared differently?
5. Does a private pointer type leak a visibility problem into the public struct?

If C3 rejects this shape, try:

```text
public opaque pointer alias
```

with the actual implementation type remaining private.

This is exactly the kind of issue that should be measured, not inferred.

---

# 26. If C3 cannot expose a private pointer type in a public struct

There is still a possible representation boundary using an opaque public handle:

```c3
typedef PoolState = void;

struct Pool
{
    AnyNode node;
    Allocator allocator;
    PoolState* _state;
}
```

Internally:

```c3
@private struct PoolImpl
{
    ...
}

@private macro PoolImpl* impl(PoolState* state)
{
    return (PoolImpl*)state;
}
```

This is less type-safe internally than the private pointer type.

But it may be the practical C3 mechanism if visibility rules require the field's
declared type to be public.

Again:

* `Pool` remains an item;
* `Pool` still embeds `AnyNode`;
* only the operational state becomes opaque.

This directly disproves the claim that:

```text
opaque state
=
opaque container
```

Those are different designs.

---

# 27. Recommended D1 decision after this review

I would change the decision analysis, but not necessarily the ruling.

Recommended ruling:

> **Public direct representation.**
>
> `Mailbox` and `Pool` remain public structs with their operational state stored
> directly in them.
>
> A split representation could hide the operational implementation while
> preserving the public container itself as an item, so information hiding does
> not inherently conflict with Part 11.1.
>
> The port rejects that representation because its extra indirection,
> allocation and lifetime complexity are not justified by the benefit.

Then the rejected alternative becomes:

```text
Split representation:

public Mailbox / Pool
    embeds AnyNode
    owns allocator
    points to private Impl

Rejected:
    preserves functionality and Part 11.1,
    but costs an indirection and more complicated lifetime.
```

This is technically stronger than the current argument.

---

# 28. Priority of changes

## High priority

1. Reconsider the technical premise of D1.
2. At minimum, stop claiming that opaque implementation necessarily breaks
   Part 11.1.
3. Fix the two remaining "third field" references in the implementation
   mapping and D12.
4. Treat the pre-lock atomic closed flag strictly as a hint.
5. Make hook unlock/relock boundaries explicit in implementation.

## Worth a capability test

6. Public `Mailbox`/`Pool` with a pointer to a private implementation type.
7. Public opaque state pointer with private cast inside the module.
8. Whether an incomplete/private implementation can be embedded by value.
9. Visibility behaviour of private field types in public structs.

## Implementation improvements regardless of D1

10. Centralize `NodeList` mutation primitives.
11. Never retain mutable pool references across application hooks.
12. Make `Pool.create` transactional under partial failure.
13. Keep `close` separate from destruction.
14. Group container fields by identity, lifetime and operational state.

---

# Final conclusion

003 fixed the important contradictions from the previous review.

The architecture is now coherent.

The biggest remaining issue is not a contradiction.

It is a **premature impossibility claim in D1**.

The proposal currently treats these as equivalent:

```text
hide the container implementation
        =
make the container type opaque
        =
container can no longer embed AnyNode
        =
break Part 11.1
```

I do not think those equivalences hold.

A split design can be:

```text
public Pool
    |
    +-- AnyNode
    |
    +-- private state pointer
            |
            v
        PoolImpl
```

and therefore:

```text
Pool is still an item
Pool still embeds the inner
helper{Pool} still works
Pool can still sit on NodeList
public functionality is unchanged
only operational representation is hidden
```

So the correct answer to the specific implementation-hiding question is:

# Yes, probably.

`Mailbox` and `Pool` can likely hide their operational implementation without
changing functionality or abandoning their role as items.

But it is not free.

The actual price is:

```text
one extra representation boundary
+ likely one extra allocation
+ lifetime complexity
+ indirection
```

not:

```text
loss of Part 11.1
```

My recommendation is to **run the small C3 capability experiment before making
any design change**.

If the experiment works, keep direct public representation only if you prefer
its simpler lifetime and one-allocation model.

That would then be a deliberate engineering tradeoff.

Not a limitation imposed by the Matryoshka design.
