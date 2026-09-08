// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

<*
 The mailbox. A queue of outers, with waiting.

 Transfer of an outer between threads.
 Create, send, receive, close, release.
 Many producers, many consumers, on one mailbox.
 The mailbox keeps outers. It never touches them.
 A mailbox is itself an outer: it can travel through another mailbox.

 The allocator is kept for life.
 Nothing partially constructed is ever returned.
 On send the Slot is the answer: cleared means the mailbox has the outer, untouched means the mailbox is closed and you still have the outer.
 On receive an empty Slot goes in, and a full Slot comes back on success.
 Every other outcome is a fault, and the Slot stays empty.
 On close what was left comes back to you, as one queue.
 Releasing those outers is your work.
 The mailbox never knew what they were.
 Close it first. Releasing an open mailbox aborts in every build mode.
 Closing does not make a mailbox quiet: release it only after every call on it has returned.

 The mailbox and the pool use only the public surface of the core, and `run-builds.sh` tests that.
 The fields named with a leading underscore are internal. Do not read them.
*>
module mtk::mailbox;

<*
 The tool itself.

 Created on the heap, with an allocator it keeps for life.
 Inside it are two queues.
 One for out-of-band outers.
 One for ordinary outers.
*>
typedef Mailbox = void;

<*
 The identity of a `Mailbox` as an outer.
*>
const typeid TYPE = _Mbox::typeid;

// Part 4.6: `_Mbox` is an Outer, and the mailbox is an ordinary client of the
// helper. One `@private` alias, exactly as an application writes one, and every
// crossing below goes through it.
//
// `to_inner` is the one exception, and the reason is concurrency rather than
// taste: the helper's `inner()` stamps on the way out, and a `Mailbox*` being
// crossed by one thread may be on a chain being read by another. A stamp writes
// the same bytes it finds, but it writes them, so this direction keeps the
// read-only macro. Nothing else in the file does.
alias MBOX @private = helper::OF{_Mbox};

<*
 From a `Mailbox*` to its `Inner*`. Cannot fail.
*>
macro Inner* to_inner(Mailbox* p) => inner::to_inner((_Mbox*)p);

<*
 The checking crossing back. Null when the inner names another type.
*>
macro Mailbox* of(Inner* inner) => (Mailbox*)MBOX.look(inner);

<*
 Allocates a mailbox and returns it.

 The allocator is kept for life.
 Nothing partially constructed is ever returned.
 Every step undoes what succeeded before it.

 @param a : "the allocator the mailbox keeps for life"
*>
fn Mailbox*? create(Allocator a)
{
    _Mbox* mb = alloc::new_try(a, _Mbox)!;
    defer catch alloc::free(a, mb);

    MBOX.stamp(mb);
    mb._alloc = a;

    mb._mu.init()!;
    defer catch mb._mu.destroy();

    mb._cv.init()!;

    return (Mailbox*)mb;
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
fn void Mailbox.release(&mbox)
{
    _Mbox* self = (_Mbox*)mbox;

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
 Puts the outer on the ordinary queue.

 The Slot is the answer. Cleared on success.
 Untouched on `CLOSED`, and the sender still has the outer.
 An empty Slot is a defect.

 @param slot : "a full Slot; cleared on success, untouched on CLOSED"
 @return? mtk::CLOSED
*>
fn void? Mailbox.send(&mbox, Slot* slot) => ((_Mbox*)mbox).send_at(slot, false);

<*
 Same as `send()`, ahead of every ordinary outer.

 First-in first-out among out-of-band outers themselves.
 One priority level. This is not a priority queue.

 @param slot : "a full Slot; cleared on success, untouched on CLOSED"
 @return? mtk::CLOSED
*>
fn void? Mailbox.send_oob(&mbox, Slot* slot) => ((_Mbox*)mbox).send_at(slot, true);

fn void? _Mbox.send_at(&self, Slot* slot, bool oob)
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
 Takes an outer if one is queued. Never waits.

 Reports `EMPTY` where `receive` with a zero timeout would report `TIMEOUT`.

 @param slot : "an empty Slot; filled on success"
 @return? mtk::CLOSED, mtk::EMPTY
*>
fn void? Mailbox.poll(&mbox, Slot* slot)
{
    _Mbox* self = (_Mbox*)mbox;

    // [3tk: Part 9.2 rule 3]
    mtk::@check(slot.is_empty(), "an acquisition asserts the Slot is empty on entry");

    if (self.@closed_fast()) return mtk::CLOSED~;

    self._mu.lock();
    defer self._mu.unlock();

    if (self._closed) return mtk::CLOSED~;

    self._active++;
    defer self._active--;

    Inner* inner = self.dequeue();
    if (!inner) return mtk::EMPTY~;
    slot.fill(inner);
}

<*
 Takes an outer, waiting up to the timeout.

 Every other outcome is a fault, and the Slot stays empty.
 The deadline is anchored once. A spurious wakeup does not restart it.
 There is no interruption. C3 has no interruptible condition wait.

 @param slot : "an empty Slot; filled on success"
 @param timeout : "how long to wait"
 @return? mtk::CLOSED, mtk::TIMEOUT, mtk::WOKEN
*>
fn void? Mailbox.receive(&mbox, Slot* slot, Duration timeout)
{
    _Mbox* self = (_Mbox*)mbox;

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

        Inner* inner = self.dequeue();
        if (inner) { slot.fill(inner); return; }

        if (self._wake_gen != gen) return mtk::WOKEN~;

        if (catch f = self._cv.wait_until(&self._mu, deadline))
        {
            if (f != thread::WAIT_TIMEOUT) return f~; // dead today: wait_until can only fail with WAIT_TIMEOUT, kept for future wait failures

            if (self._closed) return mtk::CLOSED~;
            inner = self.dequeue();
            if (inner) { slot.fill(inner); return; }
            if (self._wake_gen != gen) return mtk::WOKEN~;

            return mtk::TIMEOUT~;
        }
    }
}

<*
 Moves every queued outer onto your queue.

 The queue is in the order `receive` would have taken them out.
 Releasing the outers is your work.

 @param out : "an empty queue; every queued outer is moved onto it, in receive order"
 @return? mtk::CLOSED
*>
fn void? Mailbox.receive_all(&mbox, InnerQueue* out)
{
    _Mbox* self = (_Mbox*)mbox;

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
fn void? Mailbox.wake_all(&mbox)
{
    _Mbox* self = (_Mbox*)mbox;

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
 Discarding that queue drops the outers, and a later send refuses them.
 Closing does not make a mailbox quiet.

 @param out : "an empty queue; the remainder is moved onto it, in receive order"
*>
fn void Mailbox.close(&mbox, InnerQueue* out)
{
    _Mbox* self = (_Mbox*)mbox;

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


<*
 True when it is closed.
*>
fn bool Mailbox.is_closed(&mbox) => ((_Mbox*)mbox).@closed_fast();

<*
 True when it is closed and no call on it is still running.

 The same predicate `release()` asserts, read under the mutex. The usual way
 to reach this state is to join the threads that touch the mailbox.
*>
fn bool Mailbox.is_quiet(&mbox)
{
    _Mbox* self = (_Mbox*)mbox;
    self._mu.lock();
    defer self._mu.unlock();
    return self._closed && self._active == 0;
}

<*
 How many outers are queued.

 A hint. It is stale by the time you read it.
*>
fn usz Mailbox.len(&mbox)
{
    _Mbox* self = (_Mbox*)mbox;
    self._mu.lock();
    defer self._mu.unlock();
    self._active++;
    defer self._active--;
    return self._oob.len() + self._regular.len();
}

//==============================================================================
// For internal usage - everything below this line.
//
// `_Mbox` is `@private` and its methods cannot be: C3 ignores `@private` and
// `@local` on a method declaration. So the whole of the real mailbox is public
// to the compiler and internal by position, and the banner is where that is
// said. Every public method above casts to `_Mbox*` on its first line.
//==============================================================================

<*
 For internal usage.
*>
// Reads the closed flag before taking the lock. A hint: every caller that gets
// false re-reads the flag under the lock. `is_closed` is the one to call.
macro bool _Mbox.@closed_fast(&self) => self._closed_fast.load(ACQUIRE);

<*
 For internal usage.
*>
// Puts the outer on the ordinary queue, or ahead of every ordinary outer.
// O(1) in every build mode.
fn void _Mbox.enqueue(&self, Inner* inner, bool oob)
{
    if (oob) { self._oob.push_back(inner); } else { self._regular.push_back(inner); }
}

<*
 For internal usage.
*>
// Takes the next outer.
// Out-of-band first, then ordinary, first-in first-out within each.
fn Inner* _Mbox.dequeue(&self)
{
    Inner* inner = self._oob.pop_front();
    return inner ? inner : self._regular.pop_front();
}

<*
 For internal usage.
*>
// True if anything is queued at all. Reads both queues.
fn bool _Mbox.has_queued(&self) @inline
    => !self._oob.is_empty() || !self._regular.is_empty();

<*
 For internal usage.
*>
// The state change, with the mutex already held, and nothing else.
// The only writer of `_closed`. It never takes or releases the mutex, calls no
// hook, destroys nothing and frees nothing. Calling it twice is safe, and the
// second call transfers nothing.
//
// The fast-path store is RELEASE and pairs with the ACQUIRE load in
// `@closed_fast`: a thread that reads the flag set has also seen every write
// made before the store, so the fast path can refuse without the mutex.
fn void _Mbox._close(&self, InnerQueue* out)
{
    if (self._closed) return;

    self._closed = true;
    self._closed_fast.store(true, RELEASE);

    out.append_queue(&self._oob);
    out.append_queue(&self._regular);

    self._cv.broadcast();
}

<*
 For internal usage.
*>
// The real fields, behind the opaque `Mailbox`. Every public method casts on
// its first line and works on this from there.
struct _Mbox @private
{
    Inner inner;

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


//----------------------
// Little-endian imports
//----------------------
import mtk;
import std::thread;
import std::time;
import std::core::mem::alloc;
import std::atomic::types;
