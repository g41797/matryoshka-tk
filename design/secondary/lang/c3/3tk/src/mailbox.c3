// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

<*
 The mailbox. A queue of items, with waiting.

 Transfer of an item between threads.
 Create, send, receive, close, release.
 Many producers, many consumers, on one mailbox.
 The mailbox keeps items. It never touches them.
 A mailbox is itself an item: it can travel through another mailbox.

 The allocator is kept for life.
 Nothing partially constructed is ever returned.
 On send the Slot is the answer: cleared means the mailbox has the item, untouched means the mailbox is closed and you still have the item.
 On receive an empty Slot goes in, and a full Slot comes back on success.
 Every other outcome is a fault, and the Slot stays empty.
 On close what was left comes back to you, as one queue.
 Releasing those items is your work.
 The mailbox never knew what they were.
 Close it first. Releasing an open mailbox aborts in every build mode.
 Closing does not make a mailbox quiet: release it only after every call on it has returned.

 The mailbox and the pool use only the public surface of the core, and `run-builds.sh` tests that.
 The fields named with a leading underscore are internal. Do not read them.
*>
// [3tk: D1, F2, Part 11.1, Part 11.3, Part 11.4, Part 11.5, Part 11.6, Part 17.2, Part 19.1]
module mtk::mailbox;

<*
 The tool itself.

 Created on the heap, with an allocator it keeps for life.
 Inside it are two queues.
 One for out-of-band items.
 One for ordinary items.
*>
// [3tk: D1, D3, D16, R7, R9, V6, V7, Part 4.4, Part 11.1, Part 11.2, Part 11.3, Part 11.5, Part 15.3, Part 15.4]
struct Mailbox
{
    Inner node;

    Mutex             _mu;
    ConditionVariable _cv;

    Allocator         _alloc;

    bool         _closed;
    Atomic{bool} _closed_fast;
    usz          _active;

    InnerQueue _oob;
    InnerQueue _regular;

    usz _wake_gen;
}

<*
 The identity of a `Mailbox` as an item.
*>
// [3tk: H0, Part 11.1]
const typeid TYPE = Mailbox::typeid;

<*
 From a `Mailbox*` to a `Handle`. Cannot fail.
*>
macro Handle to_handle(Mailbox* p) => mtk::helper::to_handle(p);

<*
 The checking crossing back. Null when the handle names another type.
*>
macro Mailbox* of(Handle h) => mtk::helper::from_handle(h, Mailbox);

<*
 Allocates a mailbox and returns it.

 The allocator is kept for life.
 Nothing partially constructed is ever returned.
 Every step undoes what succeeded before it.

 @param a : "the allocator the mailbox keeps for life"
*>
// [3tk: D3, Part 3.1]
fn Mailbox*? create(Allocator a)
{
    Mailbox* mb = alloc::new_try(a, Mailbox)!;
    defer catch alloc::free(a, mb);

    mtk::helper::init(mb);
    mb._alloc = a;

    mb._mu.init()!;
    defer catch mb._mu.destroy();

    mb._cv.init()!;

    return mb;
}

<*
 Frees the mailbox, with the allocator it kept.

 Close it first. Releasing an open mailbox aborts in every build mode.
 It takes no allocator.
 The mailbox must be closed and quiet.
 Quiet means no call on the mailbox is still running.
 Closing does not make a mailbox quiet: a receiver parked in `receive` is woken by the close and has not yet returned.
 The usual way to get quiet is to join the threads that touch the mailbox.
 Releasing a mailbox that is not quiet aborts in every build mode.
*>
// [3tk: D6, Part 11.12, Part 13.1]
fn void Mailbox.release(&self)
{
    // Rule 1 of the lifetime contract, and the whole of what `_active` is for.
    // Closed is state; quiet is that state and an empty active set together.
    // The predicate is read UNDER the mutex, never before taking it, and
    // `release` is never counted itself: it would then assert against itself.
    //
    // This is a check and not a wait. A release that waited would block on
    // application code the port does not control. What it catches, it catches
    // on the schedule it happens to see.
    // [3tk: Part 11.12]
    self._mu.lock();
    always_assert(self._closed && self._active == 0,
                  "releasing a mailbox that is not quiet");
    self._mu.unlock();

    // The order is established against the real structs, not assumed. C3's
    // `Mutex.destroy` is `pthread_mutex_destroy`, which aborts on the EBUSY a
    // held mutex returns, so the unlock above must precede it. The condition
    // variable is destroyed first because no waiter can remain: quiet says so.
    self._cv.destroy()!!;
    self._mu.destroy();
    Allocator a = self._alloc;
    alloc::free(a, self);
}

<*
 Reads the closed flag before taking the lock.

 A hint. Every caller that gets false re-reads the flag under the lock.
 Call `is_closed` instead.
*>
// [3tk: D16, Part 15.4]
macro bool Mailbox.@closed_fast(&self) => self._closed_fast.load(ACQUIRE);

// Puts the item on the ordinary queue, or ahead of every ordinary item.
// O(1) in every build mode. Internal, so not a `<* *>` block: see 3TK-42.
// [3tk: R7, Part 11.3]
fn void Mailbox.enqueue(&self, Handle h, bool oob) @private
{
    if (oob) { self._oob.push_back(h); } else { self._regular.push_back(h); }
}

// Takes the next item.
// Out-of-band first, then ordinary, first-in first-out within each.
// [3tk: R7, R9, Part 11.3]
fn Handle Mailbox.dequeue(&self) @private
{
    Handle h = self._oob.pop_front();
    return h ? h : self._regular.pop_front();
}

// True if anything is queued at all. Reads both queues.
fn bool Mailbox.has_queued(&self) @private @inline
    => !self._oob.is_empty() || !self._regular.is_empty();

<*
 Puts the item on the ordinary queue.

 The Slot is the answer. Cleared on success.
 Untouched on `CLOSED`, and the sender still has the item.
 An empty Slot is a defect.

 @param slot : "a full Slot; cleared on success, untouched on CLOSED"
 @return? mtk::CLOSED
*>
// [3tk: Part 9.3, Part 11.3, Part 11.6, Part 19.1]
fn void? Mailbox.send(&self, Slot* slot) => self.send_at(slot, false);

<*
 Same as `send()`, ahead of every ordinary item.

 First-in first-out among out-of-band items themselves.
 One priority level. This is not a priority queue.

 @param slot : "a full Slot; cleared on success, untouched on CLOSED"
 @return? mtk::CLOSED
*>
// [3tk: D14, R7, Part 11.3, Part 11.4]
fn void? Mailbox.send_oob(&self, Slot* slot) => self.send_at(slot, true);

fn void? Mailbox.send_at(&self, Slot* slot, bool oob) @private
{
    mtk::@check(slot.is_full(), "Mailbox.send from an empty Slot");
    if (slot.is_empty()) return;

    if (self.@closed_fast()) return mtk::CLOSED~;

    self._mu.lock();
    defer self._mu.unlock();

    // [3tk: Part 15.4]
    if (self._closed) return mtk::CLOSED~;

    self._active++;
    defer self._active--;

    self.enqueue(slot.take(), oob);
    self._cv.signal();
}

<*
 Takes an item if one is queued. Never waits.

 Reports `EMPTY` where `receive` with a zero timeout would report `TIMEOUT`.

 @param slot : "an empty Slot; filled on success"
 @return? mtk::CLOSED, mtk::EMPTY
*>
// [3tk: D13, Part 19.1]
fn void? Mailbox.poll(&self, Slot* slot)
{
    // [3tk: Part 9.2 rule 3]
    mtk::@check(slot.is_empty(), "an acquisition asserts the Slot is empty on entry");

    if (self.@closed_fast()) return mtk::CLOSED~;

    self._mu.lock();
    defer self._mu.unlock();

    if (self._closed) return mtk::CLOSED~;

    self._active++;
    defer self._active--;

    Handle h = self.dequeue();
    if (!h) return mtk::EMPTY~;
    slot.fill(h);
}

<*
 Takes an item, waiting up to the timeout.

 Every other outcome is a fault, and the Slot stays empty.
 The deadline is anchored once. A spurious wakeup does not restart it.
 There is no interruption. C3 has no interruptible condition wait.

 @param slot : "an empty Slot; filled on success"
 @param timeout : "how long to wait"
 @return? mtk::CLOSED, mtk::TIMEOUT, mtk::WOKEN
*>
// [3tk: D7, D9, Part 2.4, Part 2.5, Part 2.6, Part 2.9, Part 15.3, Part 19.1]
fn void? Mailbox.receive(&self, Slot* slot, Duration timeout)
{
    // [3tk: Part 9.2 rule 3]
    mtk::@check(slot.is_empty(), "an acquisition asserts the Slot is empty on entry");

    // [3tk: Part 2.5]
    Time deadline = time::now() + timeout;

    self._mu.lock();
    defer self._mu.unlock();

    // [3tk: Part 2.4]
    if (self._closed) return mtk::CLOSED~;

    // Raised before the wait can release the mutex, and lowered with the mutex
    // held again. A receiver parked in `wait_until` below is the one mailbox
    // call a release can overlap, and the count is all that sees it.
    self._active++;
    defer self._active--;

    // [3tk: Part 11.5]
    usz gen = self._wake_gen;

    while (true)
    {
        // [3tk: Part 2.4]
        if (self._closed) return mtk::CLOSED~;

        Handle h = self.dequeue();
        if (h) { slot.fill(h); return; }

        if (self._wake_gen != gen) return mtk::WOKEN~;

        if (catch f = self._cv.wait_until(&self._mu, deadline))
        {
            if (f != thread::WAIT_TIMEOUT) return f~; // dead today: wait_until can only fail with WAIT_TIMEOUT, kept for future wait failures

            if (self._closed) return mtk::CLOSED~;
            h = self.dequeue();
            if (h) { slot.fill(h); return; }
            if (self._wake_gen != gen) return mtk::WOKEN~;

            return mtk::TIMEOUT~;
        }
    }
}

<*
 Moves every queued item onto your queue.

 The queue is in the order `receive` would have taken them out.
 Releasing the items is your work.

 @param out : "an empty queue; every queued item is moved onto it, in receive order"
 @return? mtk::CLOSED
*>
// [3tk: R8, Part 11.3, Part 11.6, Part 19.1]
fn void? Mailbox.receive_all(&self, InnerQueue* out)
{
    // [3tk: Part 9.2 rule 3]
    mtk::@check(out.is_empty(), "receive_all asserts the queue is empty on entry");

    if (self.@closed_fast()) return mtk::CLOSED~;

    self._mu.lock();
    defer self._mu.unlock();

    if (self._closed) return mtk::CLOSED~;

    self._active++;
    defer self._active--;

    out.append_queue(&self._oob);
    out.append_queue(&self._regular);
}

<*
 Wakes every current waiter. Each one reports `WOKEN`.

 The mailbox stays open.
 A thread that starts waiting afterwards is unaffected.

 @return? mtk::CLOSED
*>
// [3tk: Part 11.5]
fn void? Mailbox.wake_all(&self)
{
    if (self.@closed_fast()) return mtk::CLOSED~;

    self._mu.lock();
    defer self._mu.unlock();

    if (self._closed) return mtk::CLOSED~;

    self._active++;
    defer self._active--;

    self._wake_gen++;
    self._cv.broadcast();
}

<*
 Closes the mailbox and gives back what was left. Cannot fail.

 Callable more than once. The second call takes nothing.
 The queue is in the order `receive` would have taken them out.
 Discarding that queue drops the items, and a later send refuses them.
 Closing does not make a mailbox quiet.

 @param out : "an empty queue; the remainder is moved onto it, in receive order"
*>
// [3tk: R6b, R8, Part 11.6, Part 11.12, Part 19.1]
fn void Mailbox.close(&self, InnerQueue* out)
{
    // [3tk: Part 9.2 rule 3]
    mtk::@check(out.is_empty(), "close asserts the queue is empty on entry");

    self._mu.lock();
    defer self._mu.unlock();

    // Active for its whole body. The mailbox holds the mutex throughout, so a
    // release cannot observe this raise; it is raised anyway, because what
    // decides is whether the memory can still be touched and not whether this
    // particular tool happens to leave the mutex.
    self._active++;
    defer self._active--;

    self._close(out);
}

// The state change, with the mutex already held, and nothing else.
// The only writer of `_closed`. It never takes or releases the mutex, calls no
// hook, destroys nothing and frees nothing. Calling it twice is safe, and the
// second call transfers nothing.
//
// The fast-path store is RELEASE and pairs with the ACQUIRE load in
// `@closed_fast`: a thread that reads the flag set has also seen every write
// made before the store, so the fast path can refuse without the mutex.
// Internal, so not a `<* *>` block: see 3TK-42.
// [3tk: Part 11.12, Part 15.4]
fn void Mailbox._close(&self, InnerQueue* out) @private
{
    if (self._closed) return;

    self._closed = true;
    self._closed_fast.store(true, RELEASE);

    out.append_queue(&self._oob);
    out.append_queue(&self._regular);

    self._cv.broadcast();
}

<*
 True when it is closed.
*>
fn bool Mailbox.is_closed(&self) => self.@closed_fast();

<*
 How many items are queued.

 A hint. It is stale by the time you read it.
*>
// [3tk: Part 12.4]
fn usz Mailbox.len(&self)
{
    self._mu.lock();
    defer self._mu.unlock();
    self._active++;
    defer self._active--;
    return self._oob.len() + self._regular.len();
}

//----------------------
// Little-endian imports
//----------------------
import mtk;
import mtk::helper;
import std::thread;
import std::time;
import std::core::mem::alloc;
import std::atomic::types;
