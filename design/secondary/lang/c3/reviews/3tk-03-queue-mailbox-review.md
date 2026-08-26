# 3tk implementation review: `queue.c3` and `mailbox.c3`

Scope:

- Implementation only.
- Comments are not analyzed.
- This review checks contradictions, implementation problems, and improvements supported by the shown code.
- It also checks interaction with the previously shown `mtk.c3`, `inner.c3`, `helper.c3`, and `managed.c3`.
- No redesign suggestions without evidence from the implementation.

# Overall result

The basic design is coherent.

`InnerQueue` correctly uses the existing `Inner.link` representation as a singly linked intrusive chain:

```text
empty queue
    head = null
    tail = null
    count = 0

non-empty queue
    head -> ... -> tail
    tail points to itself
````

The queue operations preserve this representation.

The most important problems are in the mailbox implementation:

1. **`close()` does not check that `out` is empty, although `append_queue()` does not require or enforce an empty destination.**
2. **`receive_all()` has the same problem with `out`.**
3. **`poll()` can report `CLOSED` before taking the mutex, while `receive()` deliberately does not use the fast closed check. This difference is intentional only if immediate closed detection is allowed to win over queued items.**
4. **`send_at()` relies on `@check` to reject an empty Slot, but in a non-safe build it silently succeeds without sending anything.**
5. **The queue's insert guard only detects whether an item currently points somewhere. Its correctness depends on every removal always calling `reset()`. The shown queue implementation does this correctly.**
6. **`append_queue()` has a safe-build-only null check, but dereferences `other` in a non-safe build. This follows the project's defect model, but is worth recognizing explicitly.**

The strongest concrete issue is the destination queue contract for `receive_all()` and `close()`.

---

# 1. `InnerQueue` representation is internally consistent

The queue stores:

```c3
struct InnerQueue
{
    Inner* head;
    Inner* tail;
    usz    count;
}
```

Insertion does:

```c3
h.repoint_to(h);
```

so a newly inserted item initially points to itself.

For a non-empty queue:

```c3
self.tail.repoint_to(h);
```

changes the old tail to point to the new item.

Therefore the representation is:

```text
head -> item -> item -> tail
                         |
                         +---- points to itself
```

`pop_front()` uses:

```c3
self.head = h.points_to();
```

for a queue with more than one item.

The old head is then reset:

```c3
mtk::inner::reset(h);
```

so the returned item becomes:

```text
link.ptr  = null
link.type = original outer type
```

This is consistent with the earlier `Inner` design.

No contradiction was found in the queue representation.

---

# 2. `push_back()` correctly establishes the self-terminal chain

Current implementation:

```c3
fn void InnerQueue.push_back(&self, Handle h)
{
    self.@guard_insert(h);
    h.repoint_to(h);
    if (self.tail) { self.tail.repoint_to(h); } else { self.head = h; }
    self.tail = h;
    self.count++;
}
```

For an empty queue:

```text
head = null
tail = null
```

the result is:

```text
head = h
tail = h
h -> h
```

For a non-empty queue:

```text
old_tail -> old_tail
```

becomes:

```text
old_tail -> h
h -> h
```

This is correct.

---

# 3. `@guard_insert()` depends on the meaning of `is_linked`

Current guard:

```c3
macro InnerQueue.@guard_insert(&self, Handle h)
{
    mtk::@check(h != null, "insert of a null handle");
    mtk::@check(!mtk::inner::is_linked(h), "the item is already on a chain");
}
```

Earlier `is_linked` was:

```c3
fn bool is_linked(Handle h) @inline
    => h != null && h.points_to() != null;
```

This works with the queue representation because:

```text
not queued
    link.ptr = null

queued as tail
    link.ptr = self

queued before tail
    link.ptr = next item
```

Therefore every queued item is detected as linked.

Every removed item must call:

```c3
reset(h);
```

otherwise it cannot be inserted again.

The shown `pop_front()` does this correctly.

`append_queue()` does not remove individual items, so they remain linked throughout the transfer, which is also correct.

No change is needed.

---

# 4. `push_back_slot()` intentionally becomes a no-op in a non-safe build

Current implementation:

```c3
fn void InnerQueue.push_back_slot(&self, Slot* s)
{
    mtk::@check(s.is_full(), "push_back_slot from an empty Slot");
    if (s.is_empty()) return;
    self.push_back(s.take());
}
```

In a safe build:

```text
empty Slot
    -> defect / abort
```

In a non-safe build, `@check` disappears, so:

```text
empty Slot
    -> return
```

This is the same implementation pattern later used by `Mailbox.send_at()`.

It is not internally contradictory if the project deliberately uses:

```text
safe build
    detect programming defects

non-safe build
    avoid undefined behavior
    return/no-op where possible
```

However, this is an API behavior worth making consistent.

`push_back_slot()` does not actually need to dereference a null handle because it explicitly returns on an empty Slot.

That is reasonable.

No required change.

---

# 5. `pop_front()` correctly restores queue invariants

Current implementation:

```c3
fn Handle InnerQueue.pop_front(&self)
{
    Handle h = self.head;
    if (!h) return null;
    if (self.head == self.tail)
    {
        self.head = null;
        self.tail = null;
    }
    else
    {
        self.head = h.points_to();
    }
    self.count--;
    mtk::inner::reset(h);
    return h;
}
```

Single-item case:

```text
before
    head = h
    tail = h
    h -> h

after
    head = null
    tail = null
    h -> null
```

Multi-item case:

```text
before
    h -> next

after
    head = next
    old h -> null
```

The tail remains unchanged.

`count` is decremented exactly once.

Correct.

---

# 6. `append_queue()` correctly performs an O(1) transfer

Current implementation:

```c3
fn void InnerQueue.append_queue(&self, InnerQueue* other)
{
    mtk::@check(other != null, "append_queue with a null queue");
    mtk::@check(other != self, "a queue cannot be moved onto itself");
    if (other == self) return;
    if (other.is_empty()) return;

    if (self.tail) { self.tail.repoint_to(other.head); } else { self.head = other.head; }
    self.tail = other.tail;
    self.count += other.count;

    other.head = null;
    other.tail = null;
    other.count = 0;
}
```

The resulting chain is correct.

If `self` is non-empty:

```text
self.tail -> other.head
```

The final tail remains:

```text
other.tail -> other.tail
```

so the self-terminal invariant is preserved.

If `self` is empty:

```text
self.head = other.head
self.tail = other.tail
```

and the chain is simply transferred.

Then `other` is reset to the empty representation.

Correct.

---

# 7. `append_queue()` does not require the destination queue to be empty

This matters for mailbox use.

`append_queue()` explicitly supports both:

```text
empty destination + source
```

and:

```text
non-empty destination + source
```

because it appends.

Therefore this code:

```c3
out.append_queue(&self._oob);
out.append_queue(&self._regular);
```

does **not** require `out` to be empty to work mechanically.

But it means an existing caller-owned queue is silently prepended before the mailbox contents.

This becomes a contract problem for `receive_all()` and `close()`.

---

# 8. `receive_all()` should enforce its output-queue precondition

Current implementation:

```c3
fn void? Mailbox.receive_all(&self, InnerQueue* out)
{
    if (self.@closed_fast()) return mtk::CLOSED~;

    self._mu.lock();
    defer self._mu.unlock();

    if (self._closed) return mtk::CLOSED~;

    out.append_queue(&self._oob);
    out.append_queue(&self._regular);
}
```

The intended output is the mailbox's queued contents.

But if `out` already contains:

```text
A -> B
```

and the mailbox contains:

```text
OOB: C -> D
REG: E -> F
```

the result is:

```text
A -> B -> C -> D -> E -> F
```

The mailbox order itself is preserved, but `out` no longer means only the result of `receive_all()`.

If the API contract requires an empty output queue, the implementation should check it.

## Recommended fix

Add:

```c3
mtk::@check(out.is_empty(), "receive_all requires an empty output queue");
```

before moving anything.

In a non-safe build, I would still allow append behavior, exactly as `append_queue()` does.

The important part is detecting the API defect in a checked build.

---

# 9. `close()` has the same output-queue problem

Current implementation:

```c3
fn void Mailbox.close(&self, InnerQueue* out)
{
    self._mu.lock();
    defer self._mu.unlock();

    if (self._closed) return;

    self._closed = true;
    self._closed_fast.store(true, RELEASE);

    out.append_queue(&self._oob);
    out.append_queue(&self._regular);

    self._cv.broadcast();
}
```

The first close moves queued items into `out`.

If `out` is already non-empty, mailbox contents are appended to it.

The more important problem is repeated close.

The second call does:

```c3
if (self._closed) return;
```

So it does not modify `out`.

That is mechanically fine.

But the first call should still check that `out` is empty if this is the output/acquisition convention used by the toolkit.

## Recommended fix

At entry:

```c3
mtk::@check(out.is_empty(), "close requires an empty output queue");
```

Then the normal implementation remains unchanged.

This is the strongest queue/mailbox improvement.

---

# 10. `close()` should probably check `out` before taking the lock

The output queue is caller-owned.

The emptiness assertion does not need mailbox synchronization.

Therefore:

```c3
fn void Mailbox.close(&self, InnerQueue* out)
{
    mtk::@check(out.is_empty(), "close requires an empty output queue");

    self._mu.lock();
    defer self._mu.unlock();

    ...
}
```

is simpler.

The same applies to `receive_all()`.

No need to hold the mailbox mutex while checking a caller-owned queue.

---

# 11. `poll()` fast-closes before checking queued items

Current implementation:

```c3
if (self.@closed_fast()) return mtk::CLOSED~;

self._mu.lock();
defer self._mu.unlock();

if (self._closed) return mtk::CLOSED~;

Handle h = self.dequeue();
if (!h) return mtk::EMPTY~;
```

Once `_closed_fast` is true, `poll()` returns `CLOSED` immediately.

This means it does not take an item even if there is a race where:

```text
queue contains item
close has not yet moved it out
_closed_fast becomes visible
```

But `close()` performs the moves while holding the same mutex and only returns the remainder through `out`.

Because `_closed_fast.store(true, RELEASE)` occurs before:

```c3
out.append_queue(...)
```

there is a window where another thread may observe:

```text
closed_fast == true
```

while the queues still contain items.

`poll()` then returns `CLOSED`.

This is probably intentional because a closed mailbox is no longer receivable.

But the order is important.

The implementation's semantics are:

```text
once closed_fast is observed
    no receive/poll operation attempts to take a queued item
```

`receive()` behaves differently because it does not use `@closed_fast` before locking.

It locks and checks `_closed`.

The result is still `CLOSED`, because `close()` sets `_closed` before moving queues.

So both operations ultimately refuse after close.

No functional contradiction is found.

However, the fast flag being published before queue evacuation is safe only because callers are not allowed to access those queues directly and all public receive operations treat closure as terminal.

Keep this order if that is the intended contract.

---

# 12. `send_at()` has an intentional fast-path race and correctly rechecks under the lock

Current implementation:

```c3
if (self.@closed_fast()) return mtk::CLOSED~;

self._mu.lock();
defer self._mu.unlock();

if (self._closed) return mtk::CLOSED~;

self.enqueue(slot.take(), oob);
self._cv.signal();
```

This is correct.

Cases:

```text
fast flag says closed
    -> CLOSED without locking

fast flag says open
    -> lock
    -> check authoritative _closed
```

Therefore a stale false fast read cannot send into a closed mailbox.

This is exactly the correct double-check pattern.

No change needed.

---

# 13. `send_at()` silently succeeds on an empty Slot in a non-safe build

Current implementation:

```c3
mtk::@check(slot.is_full(), "Mailbox.send from an empty Slot");
if (slot.is_empty()) return;
```

In a safe build:

```text
empty Slot
    -> abort
```

In a non-safe build:

```text
empty Slot
    -> ordinary return
    -> no fault
```

This is mechanically safe.

But the return type is:

```c3
void?
```

so a caller can interpret this as successful send.

For example:

```text
send(empty_slot)
    -> no CLOSED
    -> no fault
    -> item was not sent
```

This is a semantic difference from the checked-build contract.

The queue uses the same pattern in `push_back_slot()`.

## Recommendation

I would not change this automatically.

It is consistent with the project's use of `@check` for defects.

But this should be a deliberate project-wide rule:

```text
In a non-safe build, a defect that can safely become a no-op may become a no-op.
```

If that is not the intended rule, `send_at()` should not silently return.

Based on the existing implementation style, keeping it is reasonable.

---

# 14. `poll()` and `receive()` have the same empty-Slot behavior

Both begin with:

```c3
mtk::@check(slot.is_empty(), ...);
```

But unlike `send_at()`, neither has a fallback check.

Therefore in a non-safe build:

```text
full Slot passed to poll/receive
    -> function may overwrite it
```

This is different from the safe no-op behavior of `send_at()`.

For example:

```c3
Handle h = self.dequeue();
if (!h) return ...;
slot.fill(h);
```

If `slot` was already full, `Slot.fill()` may overwrite it.

This means:

```text
send empty Slot
    safe build: defect
    non-safe: no-op

receive full Slot
    safe build: defect
    non-safe: possible loss of the existing Handle
```

This is not necessarily a bug.

It is a consequence of treating misuse as unchecked behavior in non-safe builds.

But the behavior is inconsistent if the goal was graceful no-op handling.

## Recommendation

Do not add fallback checks everywhere merely for symmetry.

The stronger and simpler contract is:

```text
Wrong Slot state is a programming defect.
Safe builds detect it.
Non-safe builds require the caller to obey the contract.
```

Under that rule, `send_at()` and `push_back_slot()` are merely defensive extra protection.

That is acceptable.

---

# 15. `receive()` correctly anchors the deadline once

Current code:

```c3
Time deadline = time::now() + timeout;
```

This happens once before entering the wait loop.

The loop does not recalculate it.

Therefore repeated wakeups cannot extend the timeout.

This implementation is correct for the intended absolute-deadline behavior.

No change needed.

---

# 16. `receive()` correctly rechecks state after a timeout

The timeout branch does:

```c3
if (self._closed) return mtk::CLOSED~;
h = self.dequeue();
if (h) { slot.fill(h); return; }
if (self._wake_gen != gen) return mtk::WOKEN~;

if (self.has_queued()) self._cv.signal();
return mtk::TIMEOUT~;
```

This order is important.

At the timeout boundary:

```text
CLOSED
```

wins over:

```text
TIMEOUT
```

A queued item wins over:

```text
TIMEOUT
```

A wake generation change wins over:

```text
TIMEOUT
```

Only then does the function return `TIMEOUT`.

This is internally coherent.

---

# 17. The timeout `signal()` logic needs confirmation against the actual ConditionVariable semantics

This code:

```c3
if (self.has_queued()) self._cv.signal();
return mtk::TIMEOUT~;
```

exists only after the current waiter has found no item.

Because the mutex is still held, this appears intended to avoid leaving another waiter asleep when an item exists.

However, with the shown implementation:

```text
this waiter:
    wakes/times out
    locks mailbox
    finds no item
```

`has_queued()` should normally also be false unless another state transition occurs under the same mutex before this check, which cannot happen while the mutex is held.

So under the obvious interpretation, this branch appears redundant.

There may be a specific condition-variable race or wake-stealing behavior that motivated it.

Based only on the implementation, I cannot prove it is needed.

## Recommendation

Do not remove it merely for brevity unless tests demonstrate it is unnecessary.

But verify the exact C3 `ConditionVariable.wait_until` semantics and the intended multi-consumer wake behavior.

This is a verification point, not a confirmed bug.

---

# 18. `wake_all()` generation logic is coherent

Current implementation:

```c3
self._wake_gen++;
self._cv.broadcast();
```

`receive()` snapshots:

```c3
usz gen = self._wake_gen;
```

after acquiring the mutex.

Then before waiting and after waking it checks:

```c3
if (self._wake_gen != gen) return mtk::WOKEN~;
```

This means:

```text
wake_all before receive snapshots generation
    -> new receiver is unaffected

wake_all after receive snapshots generation
    -> receiver observes changed generation
    -> WOKEN
```

This correctly implements a generation-based one-shot wake-all.

No change needed.

One theoretical issue is wraparound of:

```c3
usz _wake_gen
```

but that requires an enormous number of `wake_all()` calls.

Do not add complexity for it.

---

# 19. `receive_all()` preserves dequeue order

Current code:

```c3
out.append_queue(&self._oob);
out.append_queue(&self._regular);
```

And normal dequeue is:

```c3
Handle h = self._oob.pop_front();
return h ? h : self._regular.pop_front();
```

Therefore:

```text
receive_all order
    all OOB FIFO
    then all regular FIFO
```

matches repeated `receive()` order.

Correct.

The same applies to `close()`.

---

# 20. `close()` publishes closure before moving the queues

Current order:

```c3
self._closed = true;
self._closed_fast.store(true, RELEASE);

out.append_queue(&self._oob);
out.append_queue(&self._regular);

self._cv.broadcast();
```

This is coherent with the public semantics:

```text
closure starts
    mailbox immediately becomes closed
    no sender can enqueue after the authoritative check
    receivers report CLOSED
    queued remainder belongs to close()
```

The queue movement happens while the mutex remains held.

Therefore no sender can enqueue during evacuation.

This is correct.

Do not move `_closed = true` after queue evacuation.

That would create a window where new items could enter while close is collecting the remainder.

---

# 21. `Mailbox.release()` correctly requires closure in every build mode

Current code uses:

```c3
always_assert(self._closed, "releasing an open mailbox");
```

rather than:

```c3
mtk::@check
```

This is an important and correct distinction.

The release operation would otherwise destroy synchronization primitives while another thread could still use the mailbox.

This must remain enforced in all build modes.

The implementation is consistent.

---

# 22. `Mailbox.create()` rollback structure is coherent

Current implementation:

```c3
Mailbox* mb = alloc::new_try(a, Mailbox)!;
defer catch alloc::free(a, mb);

mtk::helper::init(mb);
mb._alloc = a;

mb._mu.init()!;
defer catch mb._mu.destroy();

mb._cv.init()!;

return mb;
```

The intended rollback chain is:

```text
allocation succeeds
    defer free

mutex init succeeds
    defer mutex destroy

condition init succeeds
    return mailbox
```

If condition initialization fails:

```text
mutex destroy
free
```

should happen.

If mutex initialization fails:

```text
free
```

should happen.

This is the correct basic transactional construction pattern.

One point should be verified:

```c3
defer catch alloc::free(a, mb);
```

and:

```c3
defer catch mb._mu.destroy();
```

must have the intended C3 cleanup semantics.

Assuming they do, the implementation is good.

---

# 23. `Mailbox` is correctly initialized as an item before exposure

`create()` does:

```c3
mtk::helper::init(mb);
```

before returning.

Therefore:

```c3
Mailbox.node
```

contains the correct identity before:

```c3
Mailbox*
```

can be converted through:

```c3
to_handle
```

This correctly follows the initialization requirement found in the earlier review.

No problem.

---

# 24. The two queue fields do not need separate identity treatment

`Mailbox` itself has:

```c3
Inner node;
```

The queues:

```c3
InnerQueue _oob;
InnerQueue _regular;
```

are containers, not items.

They do not require:

```text
type identity
Handle conversion
helper::init
```

This separation is correct.

---

# 25. `InnerQueueIterator.next()` is consistent with the self-terminal representation

Current code:

```c3
fn Handle InnerQueueIterator.next(&self)
{
    Inner* n = self.cur;
    if (n) self.cur = (n.points_to() == n) ? null : n.points_to();
    return n;
}
```

For the final item:

```text
n.points_to() == n
```

so:

```text
cur = null
```

and the iterator is exhausted.

For every earlier item:

```text
cur = next
```

Correct.

One minor improvement is possible:

```c3
Inner* next = n.points_to();
self.cur = next == n ? null : next;
```

but the current code is already clear enough.

No change needed.

---

# Recommended minimal changes

## Required

### 1. Add checked output-queue preconditions

For `receive_all()`:

```c3
fn void? Mailbox.receive_all(&self, InnerQueue* out)
{
    mtk::@check(out.is_empty(), "receive_all requires an empty output queue");

    if (self.@closed_fast()) return mtk::CLOSED~;

    ...
}
```

For `close()`:

```c3
fn void Mailbox.close(&self, InnerQueue* out)
{
    mtk::@check(out.is_empty(), "close requires an empty output queue");

    self._mu.lock();
    ...
}
```

This is the main concrete improvement.

It makes the output queue follow the same acquisition-style contract as `Slot`.

---

## Verify

### 2. Verify whether this timeout branch is actually required

```c3
if (self.has_queued()) self._cv.signal();
```

Do not remove it based on this review alone.

Check it against:

* C3 `ConditionVariable.wait_until` semantics;
* multi-consumer tests;
* the reason an item could be queued while the current thread holds `_mu`.

Based only on the shown code, its necessity is not obvious.

---

### 3. Verify fault/defer semantics used by `Mailbox.create()`

Confirm that:

```c3
defer catch ...
```

performs exactly the intended rollback on faults from later initialization.

The structure itself is correct.

---

# Final assessment

`queue.c3` is internally consistent.

The queue implementation correctly maintains:

```text
unlinked item
    link.ptr = null

queued item
    link.ptr = next item

queued tail
    link.ptr = itself
```

and:

```text
push
    establishes link

pop
    removes link

append
    preserves links and transfers ownership of the chain
```

`mailbox.c3` also has a coherent core:

```text
send
    fast closed hint
    lock
    authoritative closed check
    move Slot item into queue
    signal

receive
    lock
    closed check
    dequeue
    generation wake check
    absolute-deadline wait

wake_all
    increment generation
    broadcast

close
    lock
    mark closed
    publish fast flag
    move remainder out
    broadcast
```

The main confirmed issue is the missing checked precondition that `receive_all()` and `close()` receive an empty destination queue.

The other important implementation dependency remains the earlier fix to `must_from_handle`, because typed recovery is part of the safety of the wider toolkit.

I do not see evidence here for a larger redesign.
