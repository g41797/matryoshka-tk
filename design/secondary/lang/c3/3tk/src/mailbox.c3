<*
 The mailbox. A queue of items, with waiting.

 Many producers, many consumers, on one object.
 A mailbox is itself an item: it can travel through another mailbox.
 It uses only the public surface of the core, and `run-builds.sh` tests that.
 The fields named with a leading underscore are internal. Do not read them.
*>
// [3tk: D1, F2, Part 11.1, Part 11.3, Part 11.4, Part 11.5, Part 11.6, Part 17.2, Part 19.1]
module mtk::mailbox;
import mtk;
import mtk::helper;
import std::thread;
import std::time;
import std::core::mem::alloc;
import std::atomic::types;

<*
 The mailbox itself.

 Two queues, one for out-of-band items and one for ordinary ones.
 The allocator is kept for life.
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

    InnerQueue _oob;
    InnerQueue _regular;

    usz _wake_gen;
}

<*
 The identity of a Mailbox as an item.
*>
// [3tk: H0, Part 11.1]
const typeid TYPE = Mailbox::typeid;

<*
 From a Mailbox to a handle. Cannot fail.
*>
macro Handle to_handle(Mailbox* p) => mtk::helper::to_handle(p);

<*
 The checking crossing back. Null when the handle names another type.
*>
macro Mailbox* of(Handle h) => mtk::helper::from_handle(h, Mailbox);

<*
 Create a mailbox on the heap.

 The allocator is kept for life, and `release` takes none.
 Nothing partially constructed is ever returned: every step undoes what
 succeeded before it.

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
 Frees the mailbox.

 Close it first. Releasing an open mailbox aborts in every build mode,
 including `--safe=no`.
 Takes no allocator.
*>
// [3tk: D6, Part 11.12, Part 13.1]
fn void Mailbox.release(&self)
{
    // [3tk: Part 11.12]
    always_assert(self._closed, "releasing an open mailbox");
    self._cv.destroy()!!;
    self._mu.destroy();
    Allocator a = self._alloc;
    alloc::free(a, self);
}

<*
 The pre-lock read of the closed flag.

 A hint only. Every caller that gets `false` re-reads `_closed` under the lock.
*>
// [3tk: D16, Part 15.4]
macro bool Mailbox.@closed_fast(&self) => self._closed_fast.load(ACQUIRE);

<*
 Puts an item on the queue its class belongs to.

 O(1) in every build mode.
*>
// [3tk: R7, Part 11.3]
fn void Mailbox.enqueue(&self, Handle h, bool oob) @private
{
    if (oob) { self._oob.push_back(h); } else { self._regular.push_back(h); }
}

<*
 Takes the next item.

 Out-of-band first, then ordinary, first-in first-out within each.
*>
// [3tk: R7, R9, Part 11.3]
fn Handle Mailbox.dequeue(&self) @private
{
    Handle h = self._oob.pop_front();
    return h ? h : self._regular.pop_front();
}

<*
 True if anything is queued at all. Reads both queues.
*>
fn bool Mailbox.has_queued(&self) @private @inline
    => !self._oob.is_empty() || !self._regular.is_empty();

<*
 Sends an item.

 The Slot is the answer: cleared on success, untouched on `CLOSED`, and the
 sender still has the item.

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

    self.enqueue(slot.take(), oob);
    self._cv.signal();
}

<*
 Takes an item if one is queued. Never waits.

 Reports `EMPTY` where `receive()` with a zero timeout would report `TIMEOUT`.

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

    Handle h = self.dequeue();
    if (!h) return mtk::EMPTY~;
    slot.fill(h);
}

<*
 Takes an item, waiting up to the timeout.

 Reports `CLOSED`, `TIMEOUT` or `WOKEN` when it takes nothing.
 The deadline is anchored once: a spurious wakeup does not restart it.
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
            if (f != thread::WAIT_TIMEOUT) return f~;

            if (self._closed) return mtk::CLOSED~;
            h = self.dequeue();
            if (h) { slot.fill(h); return; }
            if (self._wake_gen != gen) return mtk::WOKEN~;

            // [3tk: Part 2.6]
            if (self.has_queued()) self._cv.signal();
            return mtk::TIMEOUT~;
        }
    }
}

<*
 Moves every queued item onto the caller's queue.

 Releasing the items is the caller's work.
 The queue is in the order `receive()` would have taken them out.

 @param out : "an empty queue; every queued item is moved onto it, in receive order"
 @return? mtk::CLOSED
*>
// [3tk: R8, Part 11.3, Part 11.6, Part 19.1]
fn void? Mailbox.receive_all(&self, InnerQueue* out)
{
    if (self.@closed_fast()) return mtk::CLOSED~;

    self._mu.lock();
    defer self._mu.unlock();

    if (self._closed) return mtk::CLOSED~;

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

    self._wake_gen++;
    self._cv.broadcast();
}

<*
 Closes the mailbox and gives back what was left. Cannot fail.

 Callable more than once. The second call takes nothing.
 The queue is in the order `receive()` would have taken them out.
 Discarding that queue drops the items, and a later send refuses them.

 @param out : "an empty queue; the remainder is moved onto it, in receive order"
*>
// [3tk: R6b, R8, Part 11.6, Part 11.12, Part 19.1]
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

<*
 True if the mailbox is closed.
*>
fn bool Mailbox.is_closed(&self) => self.@closed_fast();

<*
 How many items are queued.

 A hint. It is stale by the time the caller reads it.
*>
// [3tk: Part 12.4]
fn usz Mailbox.len(&self)
{
    self._mu.lock();
    defer self._mu.unlock();
    return self._oob.len() + self._regular.len();
}
