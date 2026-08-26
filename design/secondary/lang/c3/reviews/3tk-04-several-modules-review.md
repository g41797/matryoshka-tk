# 3tk implementation analysis: `mtk`, `managed`, `queue`, `mailbox`, `stack`, `pool`

Analysis is based on implementation code only.
Comments and referenced requirement numbers were not treated as evidence.

---

## 1. Overall implementation

The overall split is coherent:

- `mtk` provides common faults and checking.
- `managed` provides allocator-carrying object lifetime.
- `queue` and `stack` provide intrusive containers.
- `mailbox` owns synchronization and transfer queues.
- `pool` owns synchronization and per-identity reuse stacks.

The main implementation problems are not architectural.
They are mostly about:

1. unchecked checks disappearing in fast builds,
2. Slot contracts becoming unsafe when checks disappear,
3. `Pool.put` losing an item in some hook outcomes,
4. fast closed checks changing required operation semantics,
5. `on_close` straggler handling and release lifetime.

---

# 2. `mtk.c3`

## 2.1 Good

The basic implementation is simple and appropriate.

```c3
faultdef CLOSED, TIMEOUT, NOT_AVAILABLE, NOT_CREATED, EMPTY, WOKEN, UNKNOWN_IDENTITY;
````

is a good central definition.

The safe-mode check wrapper is also reasonable:

```c3
macro @check(#cond, $msg)
{
    $if env::COMPILER_SAFE_MODE:
        always_assert(#cond, $msg);
    $endif
}
```

and:

```c3
const bool CHECKED = env::COMPILER_SAFE_MODE;
```

gives one consistent definition of checked mode.

## 2.2 Important contradiction: `UNKNOWN_IDENTITY`

`UNKNOWN_IDENTITY` is declared as an ordinary fault.

But the implementation uses it in two different ways.

In checked mode:

```c3
mtk::@check(b != null, ...);
if (!b) return mtk::UNKNOWN_IDENTITY~;
```

In safe mode this aborts before returning the fault.

In fast mode it returns the fault.

That means the actual semantics are:

* checked build: defect / abort,
* fast build: recoverable fault.

This is not necessarily wrong, but it is not one semantic category.

The implementation should deliberately choose one of these two models.

### Option A: it is really a fault

Then remove the `@check` and always return:

```c3
if (!b) return mtk::UNKNOWN_IDENTITY~;
```

### Option B: it is really a defect

Then do not expose it as an ordinary public fault.

The current mixed model is the least clear implementation.

My recommendation is **Option A** unless the pool identity set is explicitly intended to be an application invariant that must never be recoverable.

---

# 3. `managed.c3`

## 3.1 Good

The basic lifetime model is coherent.

`create`:

```c3
$Type* item = alloc::new_try(a, $Type)!;
*(Allocator*)((char*)item + mtk::inner::required_alloc_offset($Type)) = a;
helper::init(item);
slot.fill(helper::to_handle(item));
```

does the expected sequence:

1. allocate,
2. store allocator,
3. initialize the intrusive core,
4. publish through the Slot.

`release` correctly obtains the allocator before freeing:

```c3
Allocator a = *(Allocator*)((char*)item + mtk::inner::required_alloc_offset($Type));
slot.take();
alloc::free(a, item);
```

This is also good because the Slot is cleared before the allocation is freed.

## 3.2 Important problem: empty Slot contract disappears in fast mode

`create` does:

```c3
mtk::@check(slot.is_empty(), ...);
...
slot.fill(...);
```

If `slot` is already full in a fast build, the check disappears.

Then the result depends entirely on what `Slot.fill()` does.

This is a general problem throughout the implementation.

The code currently relies on:

```c3
@check(slot.is_empty())
```

for an operation that otherwise overwrites ownership.

If `Slot.fill()` does not itself enforce emptiness in every build, this can silently lose the previous item.

The same pattern exists in:

* `managed.create`
* `Mailbox.poll`
* `Mailbox.receive`
* `Pool.get`
* `Pool.get_wait`

and elsewhere.

### Advice

Ownership transitions should not depend only on a safe-build assertion.

Either:

* `Slot.fill()` must always require an empty Slot, or
* every public operation must have an unconditional runtime guard.

The first is much cleaner.

Then this is sufficient:

```c3
slot.fill(h);
```

because `fill` itself owns the invariant.

The public `@check` can remain as an earlier diagnostic, but correctness must come from `Slot`.

## 3.3 Possible problem: allocator field selection

`required_alloc_offset` selects the last direct member whose type is exactly `Allocator`:

```c3
$foreach $m : $Type::members:
    $if $m.type == Allocator:
        $off = $m.offset;
    $endif
$endforeach
```

Therefore a type with two `Allocator` fields compiles and silently chooses the last one.

That is an implementation ambiguity.

For example:

```c3
struct X
{
    Allocator a;
    Allocator backup;
}
```

`managed.create(X, ...)` has no clear meaning.

### Advice

Require exactly one direct `Allocator` field.

Track a count at comptime and assert:

```c3
$count == 1
```

This makes the convention explicit.

## 3.4 Possible initialization problem

The code writes the allocator before:

```c3
helper::init(item);
```

This is correct only if `helper::init` initializes only the embedded `Inner` and does not initialize or overwrite the whole outer object.

That dependency should be checked carefully.

If `helper::init` can initialize the complete outer object, the allocator write is lost.

The safer order, if valid for `helper::init`, is:

```c3
helper::init(item);
allocator_field = a;
```

I would verify `helper::init` before changing this.

---

# 4. `queue.c3`

## 4.1 The implementation is mostly sound

The queue representation is internally consistent.

Empty:

```c3
head == null
tail == null
count == 0
```

One element:

```c3
head == tail
head.points_to() == head
```

More elements use the self-link only at the tail.

`push_back` correctly creates that representation:

```c3
h.repoint_to(h);
if (self.tail) { self.tail.repoint_to(h); } else { self.head = h; }
self.tail = h;
self.count++;
```

`pop_front` correctly restores an unlinked item:

```c3
mtk::inner::reset(h);
```

`append_queue` is correctly O(1).

## 4.2 Important problem: insert protection disappears in fast builds

The guard is:

```c3
macro InnerQueue.@guard_insert(&self, Handle h)
{
    mtk::@check(h != null, ...);
    mtk::@check(!mtk::inner::is_linked(h), ...);
}
```

In fast mode this becomes effectively nothing.

Then:

```c3
h.repoint_to(h);
```

with `h == null` can dereference null.

Also inserting an already-linked item corrupts a chain.

This may be acceptable if these are explicitly programmer defects and fast mode deliberately gives undefined behaviour.

But the implementation should not accidentally imply that the queue remains protected.

The important point is consistency with the rest of the toolkit:

* some invalid states return faults in fast mode,
* some become no-ops,
* these become memory corruption or null dereferences.

That is inconsistent.

### Advice

For intrusive ownership violations, treating them as unchecked programmer defects is reasonable.

I would keep the fast implementation lean.

But then document the actual implementation rule consistently:

> Checked builds diagnose invalid ownership.
> Fast builds assume the intrusive ownership contract.

Do not rely on `@check` as though it still protects runtime behavior.

## 4.3 `push_back_slot`

This code is slightly redundant:

```c3
mtk::@check(s.is_full(), ...);
if (s.is_empty()) return;
self.push_back(s.take());
```

In checked mode an empty Slot aborts.

In fast mode it becomes a no-op.

That is a deliberate semantic change between builds.

If this is intended as a defect, I would prefer:

```c3
mtk::@check(s.is_full(), ...);
self.push_back(s.take());
```

and let the unchecked contract be unchecked.

If an empty Slot is supposed to be harmless in fast mode, the current code is correct.

The current implementation mixes both ideas.

---

# 5. `stack.c3`

The stack has the same insert-contract issue as the queue.

Apart from that, the implementation is straightforward and internally correct.

```c3
h.repoint_to(self.top ? self.top : h);
self.top = h;
self.count++;
```

and:

```c3
self.top = (h.points_to() == h) ? null : h.points_to();
self.count--;
mtk::inner::reset(h);
```

correctly implement the same self-terminated chain representation.

No structural contradiction found here.

## Advice

Keep `InnerStack` small as it is.

There is no obvious implementation improvement needed.

The only issue is consistency of fast-build defect handling with `InnerQueue`.

---

# 6. `mailbox.c3`

This has the most important implementation issues after `Pool.put`.

## 6.1 Good

The construction rollback sequence is coherent:

```c3
Mailbox* mb = alloc::new_try(a, Mailbox)!;
defer catch alloc::free(a, mb);

mtk::helper::init(mb);
mb._alloc = a;

mb._mu.init()!;
defer catch mb._mu.destroy();

mb._cv.init()!;
```

The receive loop is also structurally correct:

* lock once,
* test closed,
* dequeue,
* test wake generation,
* wait,
* retest everything after wakeup.

That is the correct general shape for a condition-variable loop.

`wake_all` using a generation counter is also a good solution for distinguishing the explicit wake from ordinary queue activity.

## 6.2 Major problem: fast closed check changes `poll` semantics

`poll` starts with:

```c3
if (self.@closed_fast()) return mtk::CLOSED~;
```

before locking.

Suppose:

1. `poll` reads `false`,
2. another thread closes the mailbox,
3. `poll` acquires the lock,
4. `poll` sees `_closed`.

It returns `CLOSED`.

That is fine.

But the opposite ordering is also important:

1. the mailbox contains items,
2. another thread closes it and sets `_closed_fast = true`,
3. `poll` starts,
4. `poll` returns `CLOSED` without taking the lock.

This means queued items are not observed by `poll` after the fast flag is true.

That is only correct if `close` atomically removes every queued item before setting the fast flag.

The implementation does:

```c3
self._closed = true;
self._closed_fast.store(true, RELEASE);

out.append_queue(&self._oob);
out.append_queue(&self._regular);
```

while holding the mutex.

So the items are removed immediately after the flag store, before the lock is released.

A racing `poll` can therefore see `_closed_fast == true` while the queues still temporarily contain items, but it returns `CLOSED` anyway.

That does not lose ownership because the closing thread owns the items.

So this is safe.

However, this makes the fast check more than a hint.
It is part of the operation's linearization semantics.

The same pattern exists in:

* `send`
* `poll`
* `receive_all`
* `wake_all`
* `Pool.get`
* `Pool.put`

I recommend being precise about this internally.

The fast flag means:

> Once observed true, this operation will not enter the object again.

That is stronger than a mere performance hint.

## 6.3 Major problem: `send_at` has different invalid-Slot behavior by build

```c3
mtk::@check(slot.is_full(), ...);
if (slot.is_empty()) return;
```

Again:

* checked: abort,
* fast: no-op.

This is especially problematic for a transfer operation because callers may believe the mailbox accepted the item if they ignore the Slot.

There is no return value indicating the fast-mode no-op.

The same pattern exists in `push_back_slot`.

### Advice

Choose one semantic rule:

### Defect-only API

```c3
mtk::@check(slot.is_full(), ...);
self.enqueue(slot.take(), oob);
```

### Defensive API

Return an explicit fault or answer.

Do not silently convert a programmer defect into a successful no-op.

My preference here is the first option.

## 6.4 `receive` does not use `_closed_fast`

This is good.

A waiting operation must synchronize through the mutex and condition variable.

Do not add the fast check here.

## 6.5 Possible unnecessary `has_queued()` signal

After timeout:

```c3
if (self.has_queued()) self._cv.signal();
return mtk::TIMEOUT~;
```

This is logically harmless.

But the condition is unusual because the thread is timing out while holding the mutex, and it signals another waiter if an item appeared.

The reason is presumably to avoid a timed-out waiter consuming the wakeup opportunity while leaving another item available.

The implementation is defensible.

I would not change it without tests demonstrating the need.

## 6.6 `close` does not validate `out`

`close` immediately does:

```c3
out.append_queue(...)
```

A null `out` dereferences.

That is fine if null is an unchecked programmer defect.

But this differs from some APIs where null gets a checked assertion.

The same applies to `receive_all`.

### Advice

No need to add runtime checks everywhere.

Just make the contract model uniform:

* pointer arguments are assumed non-null,
* checked mode may diagnose ownership/container invariants,
* fast mode assumes the API contract.

Currently the implementation is inconsistent about which violations get a safe fast-mode fallback.

---

# 7. `pool.c3`

This is the file with the most significant implementation problem.

## 7.1 Good

The bucket lookup and stack-per-identity design are coherent.

Creation rollback is also mostly correct:

```c3
Pool* p = alloc::new_try(a, Pool)!;
defer catch alloc::free(a, p);
...
p._cv.init()!;
defer catch p._cv.destroy()!!;

p._buckets = alloc::new_array_try(a, PoolBucket, tags.len)!;
```

The deferred destruction order works because later failure destroys the condition variable before the mutex and finally frees the pool.

`get` correctly unlocks before calling the hook.

`get_wait` correctly never calls a hook.

`close` correctly:

1. sets closed while holding the lock,
2. drains every bucket,
3. wakes waiters,
4. unlocks,
5. calls the hook outside the lock.

That is the right shape.

---

## 7.2 Major bug: `Pool.put` can silently lose the original item

The critical code is:

```c3
Slot mine;
mine.fill(slot.take());

InnerQueue extra;

self._mu.unlock();
self._hooks.on_put(in_pool, &mine, &extra);
self._mu.lock();
```

After the hook returns, the implementation assumes:

* empty `mine` means the item was freed or otherwise consumed,
* full `mine` means one item is to be returned to the pool.

But the public `slot` has already been cleared.

Therefore the caller can never receive the original item back.

That contradicts the implementation's own transfer model whenever the hook refuses to consume the item.

More importantly, there is no way to distinguish:

```c3
mine.take();
```

meaning "I consumed/freed it"

from:

```c3
```

a hook bug that accidentally empties `mine`.

The pool silently accepts both.

### Concrete issue

Suppose the hook decides it cannot keep the item and wants the caller to retain it.

There is no path restoring it to the original `slot`.

The original `slot` remains empty.

The item is lost from the API's ownership graph.

### Advice

Do not take the caller's Slot permanently before the hook outcome is known unless the hook contract explicitly guarantees consumption.

A better shape is to define exactly what `on_put` ownership means.

For example:

```c3
Slot mine;
mine.fill(slot.take());

...
on_put(..., &mine, ...);
```

Then after reacquiring the lock:

* if `mine` is empty, the hook consumed the item,
* if the pool is open and `mine` is full, pool it,
* if the pool is closed and `mine` is full, send it to `on_close`.

That is the current implementation.

So the implementation is only correct if the API contract is:

> Once `put` starts, the caller always gives ownership away.
> A hook may consume it, replace it, or cause it to enter the pool, but never refuse it back to the caller.

If that is the intended model, then `put` should not describe a full Slot as "refused and you still have the item".

The implementation and API must agree.

Based on the code alone, I would change the API wording rather than complicate the implementation.

---

## 7.3 Major bug: fast closed check in `Pool.put` can make put silently do nothing

The beginning is:

```c3
if (slot.is_empty()) return;

if (self.@closed_fast()) return;
```

If the pool is already closed, `put` returns while leaving the Slot full.

Later, if the caller does not inspect the Slot, it may assume the pool consumed the item.

This is unlike the mailbox, where `send` returns `CLOSED`.

`put` has no result.

This behavior is possible only because the Slot itself is supposed to communicate the answer.

So leaving it full is technically a valid answer.

But there is a deeper problem.

The slow path says:

```c3
if (self._closed) { self._mu.unlock(); return; }
```

also leaving the Slot full.

So the behavior is consistent.

This part is actually fine **if the caller's rule is explicitly to inspect the Slot after `put`**.

The implementation correctly preserves ownership on an already-closed pool.

No code change needed.

---

## 7.4 Serious lifetime problem: concurrent `put` and `release`

The implementation allows:

1. `put` removes the item from the caller's Slot,
2. unlocks,
3. runs `on_put`,
4. another thread calls `close`,
5. `close` drains the pool and calls `on_close`,
6. the caller of `close` returns,
7. another thread calls `release`,
8. meanwhile the original `put` hook returns and uses `self` again.

`Pool.put` then does:

```c3
self._mu.lock();
```

on potentially freed memory.

The comment-level intended contract may prohibit release until all concurrent calls finish, but the implementation does not enforce that.

The same general issue exists for `Mailbox.release` versus concurrent operations.

### Advice

This is not necessarily a bug if object lifetime has the normal concurrent rule:

> `release` requires that no other thread is currently calling or will call the object.

If that is the contract, the implementation is fine.

But this must be considered a hard lifetime precondition.

Do not assume `close` itself makes concurrent calls finish.

---

## 7.5 `on_close` straggler path can leave the queue non-empty

In concurrent `put` after close:

```c3
if (self._closed)
{
    InnerQueue stragglers;
    if (mine.is_full()) stragglers.push_back(mine.take());
    stragglers.append_queue(&extra);

    self._mu.unlock();
    if (!stragglers.is_empty()) self._hooks.on_close(&stragglers);
    return;
}
```

This is mechanically fine.

But after `on_close` returns, the local queue may still contain items.

Since the queue is local and then disappears, those items are effectively abandoned.

The implementation therefore depends on `on_close` consuming every item.

That may be the intended contract.

If so, this should be a strong hook invariant.

The implementation cannot enforce it without deciding what to do with leftovers.

### Advice

In checked mode, after the hook returns:

```c3
mtk::@check(stragglers.is_empty(), "Pool.on_close left items behind");
```

Likewise for the normal `close` path:

```c3
self._hooks.on_close(&remaining);
mtk::@check(remaining.is_empty(), "Pool.on_close left items behind");
```

This is a useful defect check because otherwise a hook mistake silently loses intrusive items.

I recommend this strongly.

---

## 7.6 `take_back_handle` and replacement identity

This is good:

```c3
PoolBucket* b = self.bucket_for(h.link.type);
```

The hook is allowed to replace an item.

The replacement is routed according to its actual identity.

That is more robust than assuming it belongs to the original bucket.

No change needed.

---

## 7.7 `get` hook identity check disappears in fast builds

```c3
mtk::@check(slot.peek().link.type == want, ...);
```

In a fast build a wrong item is returned successfully.

That can put an object of one identity into a caller expecting another.

This is a much more dangerous use of a check than a simple diagnostic.

The type identity is part of the public correctness of `get`.

### Advice

This should probably remain enforced in every build.

For example:

```c3
if (slot.peek().link.type != want)
{
    always_assert(false, "...");
}
```

or another unconditional defect mechanism.

A pool returning the wrong identity is not merely an optional safe-build diagnostic.

It breaks the fundamental type-erasure contract.

The same reasoning applies to:

```c3
Pool.put for an identity the pool was not created with
```

and:

```c3
the put hook returned an identity the pool was not created with
```

Those are structural identity violations.

I recommend distinguishing:

### Safe-build checks

Useful but removable:

* Slot expected empty,
* duplicate tags during construction if construction is trusted,
* intrusive item already linked.

### Always-fatal invariants

Must never continue safely:

* hook returns wrong identity,
* hook returns identity outside the pool,
* corrupted handle identity used as a bucket key.

Currently all of them use the same `@check`, which is too coarse.

---

## 7.8 `Pool.get_wait` closed fast path is intentionally absent

This is good.

Like `Mailbox.receive`, a waiting operation needs the mutex as its synchronization point.

No change needed.

---

# 8. Cross-file contradiction: `@check` is being used for two different purposes

This is the biggest design-level issue visible in the implementation.

`@check` currently covers both:

## A. Programmer preconditions

Examples:

```c3
slot.is_empty()
h != null
!is_linked(h)
```

These may reasonably disappear in fast mode.

The fast build assumes the caller follows the contract.

## B. Fundamental integrity checks

Examples:

```c3
slot.peek().link.type == want
bucket_for(returned_identity) != null
```

These should not disappear.

If they disappear, a hook can violate the core type-identity guarantee and the library continues with corrupted ownership semantics.

## Recommendation

Keep `@check` for category A.

Introduce a separate always-live invariant mechanism for category B.

Conceptually:

```c3
macro @check(...)
```

for removable diagnostics.

And:

```c3
macro @require(...)
```

or an existing unconditional assertion mechanism for invariants that cannot safely be ignored.

Do not necessarily add a new public API name.
An internal macro is enough.

This would make the implementation much more consistent.

---

# 9. Cross-file contradiction: Slot ownership checks versus fast-mode no-ops

Several operations do this pattern:

```c3
mtk::@check(slot.is_full(), ...);
if (slot.is_empty()) return;
```

Examples include:

* `InnerQueue.push_back_slot`
* `Mailbox.send_at`

Other operations do:

```c3
mtk::@check(slot.is_empty(), ...);
...
slot.fill(...)
```

Examples include:

* `managed.create`
* `Mailbox.poll`
* `Mailbox.receive`
* `Pool.get`
* `Pool.get_wait`

These have different consequences when checks disappear.

The first group becomes a silent no-op.

The second group may overwrite or otherwise misuse a full Slot depending on `Slot.fill`.

## Recommendation

Make `Slot` the enforcement boundary.

Its primitive operations should have strict ownership semantics.

For example:

* `fill` requires empty,
* `take` requires full,
* `peek` requires full.

Then public methods can use `@check` for better diagnostics without relying on it for correctness.

This is the cleanest improvement across all six files.

---

# 10. Cross-file issue: initialization of synchronization objects

Both `Mailbox.create` and `Pool.create` use this pattern:

```c3
p._mu.init()!;
defer catch p._mu.destroy();

p._cv.init()!;
```

This is good.

But `Pool.create` additionally has:

```c3
defer catch p._cv.destroy()!!;
```

while `Mailbox.create` does not register a corresponding condition-variable cleanup after successful initialization.

`Mailbox.create` is:

```c3
mb._cv.init()!;

return mb;
```

There is no later fallible operation after `_cv.init()`.

Therefore no cleanup is needed.

So this is not a bug.

The difference is justified by the later bucket allocation in `Pool.create`.

No change needed.

---

# 11. Recommended concrete changes

## High priority

### 1. Split removable checks from always-live integrity checks

Especially for pool identity correctness.

### 2. Make Slot primitives enforce ownership

Do not let public correctness depend only on `@check`.

### 3. Decide the exact `Pool.put` ownership contract

The current code implements:

> once `put` begins and the hook is called, ownership has left the caller.

It does **not** implement a general "hook refuses and caller keeps item" model.

Keep the code if that is the intended contract.
Otherwise redesign the post-hook ownership path.

### 4. Check that `on_close` empties its queue in checked builds

Both:

```c3
Pool.close
```

and the concurrent `put` straggler path.

### 5. Make concurrent lifetime preconditions explicit

`close` does not make `release` safe against in-flight operations.

This applies to both `Pool` and `Mailbox`.

---

# 12. Lower priority

### `required_alloc_offset`

Require exactly one `Allocator` member rather than silently selecting the last.

### Queue and stack guards

The current fast-mode behavior is acceptable for unchecked intrusive contracts, but make that model consistent.

### Do not change the queue/stack algorithms

The basic intrusive self-terminated representation is coherent and the O(1) operations look correct.

### Do not change the mailbox receive loop

Its mutex / condition-variable / deadline structure is sound.

### Do not add a closed fast path to waiting operations

`Mailbox.receive` and `Pool.get_wait` are correct to synchronize through the mutex.

---

# Final assessment

The implementation is substantially coherent.

I do not see a fundamental contradiction between the queue, stack, mailbox, and pool data structures.

The main problem is that `@check` currently has too much responsibility.

It is used both for:

* optional safe-build diagnostics,
* and invariants whose violation destroys the toolkit's type and ownership guarantees.

Those should be separated.

The most important file-specific point is `Pool.put`.

The code itself has a consistent ownership transfer model, but it only works if the intended rule is:

> Calling `put` gives the item to the pool operation.
> After `on_put` starts, the item is either consumed, replaced, pooled, or passed to `on_close`.
> It is not returned to the caller.

If that is the actual intended rule, keep the implementation and make the contract match it.

If the intended rule is instead:

> a hook may refuse an item and the caller keeps it,

then `Pool.put` needs an implementation change because the current code has already cleared the caller's Slot before the hook result is known.
