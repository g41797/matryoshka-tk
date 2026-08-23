<*
 The mailbox. Part 11.3 to 11.6, Part 19.1.

 A queue of items, with waiting. Many producers, many consumers, on one object.

 Part 17.2: this file uses only the public surface of the core four. It has no
 privileged access to AnyNode, Slot or NodeList, and every crossing it performs
 is one an application could write. That is a testable claim and `run-builds.sh`
 tests it.

 Part 11.1: the mailbox is itself an item. It embeds an inner, it has a type
 identity, and it can travel through another mailbox or sit on a list. D1 kept
 that literal by refusing the opaque-type route — a `typedef Mailbox = void`
 embeds nothing.

 The fields below are reachable. They are internal, they are named with a
 leading underscore, and reading them is a documentation problem rather than a
 broken invariant. D1, and F2 of the toolkit notes: C3 0.8.3 hides neither a
 field nor a method.
*>
module mtk::mailbox;
import mtk;
import std::thread;
import std::time;
import std::core::mem::alloc;
import std::atomic::types;

<*
 Part 11.2's internal base, spelled out rather than shared: the inner, a mutex,
 a condition variable, a closed flag, and an allocator kept for life.

 The base is not a public type. Part 11.2 calls it a statement about how the
 two containers are built, not a type the application names, and this port
 takes that literally — `Pool` repeats the five members rather than embedding a
 shared struct. Sharing them would put a second inner in the outer and break
 Part 4.4.
*>
struct Mailbox
{
    AnyNode node;

    Mutex             _mu;
    ConditionVariable _cv;
    Allocator         _alloc;

    // Part 15.3: read and set under the mutex. Part 15.4: also readable
    // without it, through the atomic, and ALWAYS re-read under it.
    bool         _closed;
    Atomic{bool} _closed_fast;

    NodeList  _queue;

    // Part 11.3: the anchor at the last out-of-band item, so the out-of-band
    // insert stays O(1). Null means there is none, and an out-of-band item
    // then goes at the front.
    AnyHandle _oob_anchor;

    // Part 11.5: the wake generation. Bumped by the waker, captured by each
    // waiter before it waits, compared after every wakeup.
    usz _wake_gen;
}

alias init   = mtk::helper::init{Mailbox};
alias to_any = mtk::helper::to_any{Mailbox};
alias of     = mtk::helper::from_any{Mailbox};
alias TYPE   = mtk::helper::TYPE{Mailbox};

<*
 Create a mailbox on the heap. Part 3.1: a participant is allocated once and
 lives for the duration of the run.

 D3: the allocator is kept for life and `release` takes none.

 @param a : "the allocator the mailbox keeps for life"
*>
fn Mailbox*? create(Allocator a)
{
    Mailbox* mb = alloc::new_try(a, Mailbox)!;
    init(mb);
    mb._alloc = a;
    mb._mu.init()!;
    mb._cv.init()!;
    return mb;
}

<*
 Part 11.12 MUST — close before release, and it is the one precondition the
 toolkit refuses to soften.

 **Tier 1 of D6.** `always_assert`, not `@check`. This aborts in every build
 mode, including `--safe=no -O3`, and it is the only site in the port that
 does. Releasing an open mailbox is a defect that cannot be allowed to become
 a silent leak of every item still queued.

 Part 13.1: no allocator parameter.
*>
fn void Mailbox.release(&self)
{
    always_assert(self._closed, "Part 11.12: releasing an open mailbox");
    self._cv.destroy()!!;
    self._mu.destroy();
    Allocator a = self._alloc;
    alloc::free(a, self);
}

<*
 Part 15.4's pre-lock fast path, with the correctness rule attached.

 The acquire load outside the lock lets a closed mailbox report closed with no
 mutex taken. It is an optimization and nothing rests on it: every caller that
 gets `false` here re-reads `_closed` under the lock, because close may fire
 between the two. D16 keeps the pair; Part 15.4 forbids keeping the fast read
 without the re-check.
*>
macro bool Mailbox.@closed_fast(&self) => self._closed_fast.load(ACQUIRE);

<*
 Part 11.3: put an item in at the back, or ahead of every ordinary item.

 The out-of-band insert is O(1) because of the anchor: the new item goes after
 the last out-of-band item, or at the front when there is none, and then
 becomes the anchor itself.
*>
fn void Mailbox.enqueue(&self, AnyHandle h, bool oob) @private
{
    if (!oob)
    {
        self._queue.push_back(h);
        return;
    }
    if (self._oob_anchor)
    {
        self._queue.insert_after(self._oob_anchor, h);
    }
    else
    {
        self._queue.push_front(h);
    }
    self._oob_anchor = h;
}

<*
 Take the front item, and keep the anchor honest.

 Part 11.3: the anchor is cleared when the last out-of-band item is taken.
 Every out-of-band item sits ahead of every ordinary one and the anchor is the
 last of them, so taking the anchor means the out-of-band run is drained.
*>
fn AnyHandle Mailbox.dequeue(&self) @private
{
    AnyHandle h = self._queue.pop_front();
    if (h && h == self._oob_anchor) self._oob_anchor = null;
    return h;
}

<*
 Send. Part 11.3, Part 19.1.

 Slot-shaped, Part 9.3: the Slot is the answer. On success it is cleared; on a
 closed mailbox it is untouched and the sender still has the item — Part 11.6.

 @param slot : "a full Slot; cleared on success, untouched on CLOSED"
 @return? mtk::CLOSED
*>
fn void? Mailbox.send(&self, Slot* slot) => self.send_at(slot, false);

<*
 Send out-of-band. Part 11.3: ahead of every ordinary item, first-in
 first-out among out-of-band items themselves.

 Part 11.4 keeps this as ONE priority level. It is not a priority queue, and
 D14 kept it because signals and data share one channel in this design.

 @param slot : "a full Slot; cleared on success, untouched on CLOSED"
 @return? mtk::CLOSED
*>
fn void? Mailbox.send_oob(&self, Slot* slot) => self.send_at(slot, true);

fn void? Mailbox.send_at(&self, Slot* slot, bool oob) @private
{
    mtk::@check(slot.is_full(), "Mailbox.send from an empty Slot");
    if (slot.is_empty()) return;

    if (self.@closed_fast()) return mtk::CLOSED~;

    self._mu.lock();
    defer self._mu.unlock();

    // Part 15.4: the re-read under the lock is not optional.
    if (self._closed) return mtk::CLOSED~;

    self.enqueue(slot.take(), oob);
    self._cv.signal();
}

<*
 Poll. Part 19.1: item; EMPTY; CLOSED. Never waits.

 D13 kept this beside `receive` although a receive with a zero timeout has the
 same reach. The two differ in how the empty case is reported, and a caller
 reading outcomes is entitled to the difference.

 @param slot : "an empty Slot; filled on success"
 @return? mtk::CLOSED, mtk::EMPTY
*>
fn void? Mailbox.poll(&self, Slot* slot)
{
    mtk::@check(slot.is_empty(), "Part 9.2 rule 3: an acquisition asserts the Slot is empty on entry");

    if (self.@closed_fast()) return mtk::CLOSED~;

    self._mu.lock();
    defer self._mu.unlock();

    if (self._closed) return mtk::CLOSED~;

    AnyHandle h = self.dequeue();
    if (!h) return mtk::EMPTY~;
    slot.fill(h);
}

<*
 Receive, with a timeout. Part 19.1: item; CLOSED; TIMEOUT; WOKEN.

 **This is D7's wait loop, and it is the shape every waiting call in the port
 uses.** Four MUSTs live in it:

 - Part 2.5, invariant 4. The deadline is anchored ONCE, before the loop.
   `wait_timeout` recomputes `now() + ms` on every call, so a loop built on it
   restarts the full timeout at every spurious wakeup and never times out. It
   does not appear anywhere in this port.
 - Part 2.4, invariant 3. A wakeup carries no meaning. The state is
   re-evaluated from scratch at the top of every turn, and no single wakeup
   short-circuits the loop.
 - Part 2.6, invariant 5. A waiter leaving on a timeout checks the queue and
   signals if it is not empty. Without it a pending signal is consumed by a
   waiter that then leaves, and a queued item sits with nobody woken.
 - Part 15.3. The closed flag is read under the mutex.

 Part 2.9's `interrupted` is absent: D9 dropped interruption, because C3 has no
 interruptible condition wait.

 @param slot : "an empty Slot; filled on success"
 @param timeout : "how long to wait"
 @return? mtk::CLOSED, mtk::TIMEOUT, mtk::WOKEN
*>
fn void? Mailbox.receive(&self, Slot* slot, Duration timeout)
{
    mtk::@check(slot.is_empty(), "Part 9.2 rule 3: an acquisition asserts the Slot is empty on entry");

    // Anchored once. Before the loop. Part 2.5.
    Time deadline = time::now() + timeout;

    self._mu.lock();
    defer self._mu.unlock();

    // Part 11.5: captured before the first wait, compared after every wakeup.
    usz gen = self._wake_gen;

    while (true)
    {
        // Part 2.4: re-evaluate from scratch, every turn.
        if (self._closed) return mtk::CLOSED~;

        AnyHandle h = self.dequeue();
        if (h) { slot.fill(h); return; }

        if (self._wake_gen != gen) return mtk::WOKEN~;

        if (catch f = self._cv.wait_until(&self._mu, deadline))
        {
            if (f != thread::WAIT_TIMEOUT) return f~;

            // One last look: an item may have arrived between the timeout
            // firing and the mutex coming back.
            if (self._closed) return mtk::CLOSED~;
            h = self.dequeue();
            if (h) { slot.fill(h); return; }
            if (self._wake_gen != gen) return mtk::WOKEN~;

            // Part 2.6: the leaver hands the signal on.
            if (!self._queue.is_empty()) self._cv.signal();
            return mtk::TIMEOUT~;
        }
    }
}

<*
 Receive the batch. Part 11.3, Part 19.1: a list, possibly empty; CLOSED.

 Part 11.6: the whole list goes to the caller, and releasing the items is the
 caller's work. What they are — items to free, items to give back to a pool —
 is knowledge the mailbox never had.

 @param out : "an empty list; every queued item is moved onto it"
 @return? mtk::CLOSED
*>
fn void? Mailbox.receive_all(&self, NodeList* out)
{
    if (self.@closed_fast()) return mtk::CLOSED~;

    self._mu.lock();
    defer self._mu.unlock();

    if (self._closed) return mtk::CLOSED~;

    out.append_list(&self._queue);
    self._oob_anchor = null;
}

<*
 Wake every current waiter. Part 11.5.

 Each released waiter reports WOKEN. The mailbox stays open. The effect does
 not persist: a thread that starts waiting afterwards captures the new
 generation and is unaffected.

 @return? mtk::CLOSED
*>
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
 Close. Part 11.6, Part 19.1: returns what was left, as a list. Cannot fail.

 Part 11.12: close is callable more than once, and the second call takes
 nothing. The test-and-set of the flag is inside the mutex, so a preempted
 closer cannot race a release.

 **The named mistake, Part 11.6:** discarding the list this returns drops the
 items, and those items keep their links, so a later send refuses them. The
 release runs unconditionally; an empty list costs nothing.

 @param out : "an empty list; the remainder is moved onto it"
*>
fn void Mailbox.close(&self, NodeList* out)
{
    self._mu.lock();
    defer self._mu.unlock();

    if (self._closed) return;

    self._closed = true;
    self._closed_fast.store(true, RELEASE);

    out.append_list(&self._queue);
    self._oob_anchor = null;

    self._cv.broadcast();
}

<*
 Is it closed. A hint outside the lock, and honest under it.
*>
fn bool Mailbox.is_closed(&self) => self.@closed_fast();

<*
 How many are queued. Part 12.4's warning applies to this too: it is read under
 the lock and stale by the time the caller reads it.
*>
fn usz Mailbox.len(&self)
{
    self._mu.lock();
    defer self._mu.unlock();
    return self._queue.len();
}
