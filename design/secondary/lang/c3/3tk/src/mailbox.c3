<*
 The mailbox. Part 11.3 to 11.6, Part 19.1.

 A queue of items, with waiting. Many producers, many consumers, on one object.

 Part 17.2: this file uses only the public surface of the core. It has no
 privileged access to Inner, Slot or InnerQueue, and every crossing it performs
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
import mtk::helper;
import std::thread;
import std::time;
import std::core::mem::alloc;
import std::atomic::types;

<*
 Part 11.2's five parts, spelled out rather than shared: the inner, a mutex, a
 condition variable, a closed flag, and an allocator kept for life.

 They are not a public type, and after 003 they are not a *base* either — V6.
 002 said *one internal base*; 003 says what every container has and calls a
 shared base one mechanism among several, with Part 4.4 as the reason a port
 may refuse it. This port refuses it: `Pool` repeats the five members rather
 than embedding a shared struct, because sharing them would put a second inner
 in the outer and break Part 4.4. **The refusal is now the specification's to
 allow rather than this port's to justify.**
*>
struct Mailbox
{
    // Item identity. Part 11.1: the mailbox is itself an item.
    Inner node;

    // Synchronization.
    Mutex             _mu;
    ConditionVariable _cv;

    // Lifetime. D3: kept for life, and `release` takes no allocator.
    Allocator         _alloc;

    // Container state, from here down.

    // Part 15.3: read and set under the mutex. Part 15.4: also readable
    // without it, through the atomic, and ALWAYS re-read under it.
    bool         _closed;
    Atomic{bool} _closed_fast;

    // Part 11.3, R7: TWO queues, not one list with an anchor. **003 settled
    // which of those is the rule** — V7: the three ordering guarantees are the
    // MUST, the anchor is ztk's mechanism and two queues are this port's, and
    // 11.3 now shows both. Out-of-band
    // items live in their own queue and every take tries `_oob` first, so
    // absolute priority with first-in first-out inside each class — invariant
    // 22 — falls out of the structure instead of being maintained by hand.
    //
    // The anchor is gone, and with it `insert_after`, `push_front` and the
    // four sites that kept the anchor honest. Invariant 22 is NOT gone: R9.
    // It is a promise to callers about order and it stands; only the mechanism
    // that produced it was deleted.
    InnerQueue _oob;
    InnerQueue _regular;

    // Part 11.5: the wake generation. Bumped by the waker, captured by each
    // waiter before it waits, compared after every wakeup.
    usz _wake_gen;
}

<*
 The container's own identity and crossings, and this container's PUBLIC
 surface — a Mailbox is an item like any other, Part 11.1, so a caller holding a
 Handle needs a way back.

 **H0 left no alias to write.** `mtk::helper`'s members are macros, so the two
 crossings are macros that forward to them, and the identity is C3's own
 `Mailbox::typeid` under the name this container's callers already use. Nothing
 here is a per-type instantiation and nothing here is an alias.
*>
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
 Create a mailbox on the heap. Part 3.1: a participant is allocated once and
 lives for the duration of the run.

 D3: the allocator is kept for life and `release` takes none.

 **Creation is a transaction.** Every step after the allocation can fail, and
 each failure undoes exactly what succeeded before it — `defer catch`, in the
 shape `std::threads::channel` uses for the same problem. Without this, a
 failing `_cv.init()` leaks the Mailbox and the mutex already initialized, and
 the caller receives a fault with no way to reach either. Nothing partially
 constructed is ever returned or observable.

 @param a : "the allocator the mailbox keeps for life"
*>
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
 Part 11.3: put an item on the queue its class belongs to.

 R7: no branch on an anchor, no insert into the middle of a chain. An ordinary
 item goes to the back of `_regular`; an out-of-band item goes to the back of
 `_oob`. Both are O(1) in every build mode.
*>
fn void Mailbox.enqueue(&self, Handle h, bool oob) @private
{
    if (oob) { self._oob.push_back(h); } else { self._regular.push_back(h); }
}

<*
 Take the next item: out-of-band first, then ordinary, first-in first-out
 within each.

 That single line is invariant 22, and it is now the whole implementation of
 it. Nothing has to be repaired afterwards, which is what the anchor existed
 to do.
*>
fn Handle Mailbox.dequeue(&self) @private
{
    Handle h = self._oob.pop_front();
    return h ? h : self._regular.pop_front();
}

<*
 Is anything queued at all. Reads both queues, and reading only one is the
 easiest mistake in this file — §4.4.
*>
fn bool Mailbox.has_queued(&self) @private @inline
    => !self._oob.is_empty() || !self._regular.is_empty();

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
 D14's second clause survives R7 intact: two queues are one priority level with
 a cleaner home, not two levels.

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

    Handle h = self.dequeue();
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

        Handle h = self.dequeue();
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

            // Part 2.6, invariant 5: the leaver hands the signal on — and it
            // must test BOTH queues. A leaver that checked only `_regular`
            // would consume a signal and leave a queued out-of-band item with
            // nobody woken. §4.4 names this as the easiest thing in the
            // redesign to half-fix.
            if (self.has_queued()) self._cv.signal();
            return mtk::TIMEOUT~;
        }
    }
}

<*
 Receive the batch. Part 11.3, Part 19.1: a queue, possibly empty; CLOSED.

 Part 11.6: the whole batch goes to the caller, and releasing the items is the
 caller's work. What they are — items to free, items to give back to a pool —
 is knowledge the mailbox never had.

 **The give-back order, R8, one rule for both this call and `close`:**

   Where the mailbox gives items back as a queue, the queue is in the order
   `receive` would have taken them out.

 So: out-of-band first, then ordinary, first-in first-out within each. It
 changes nothing — the single queue with its anchor already produced exactly
 this order — which is the reason to write it down rather than to argue about
 it. The alternative, ordinary first, would reorder a caller-visible batch to
 no purpose.

 @param out : "an empty queue; every queued item is moved onto it, in receive order"
 @return? mtk::CLOSED
*>
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
 Close. Part 11.6, Part 19.1: returns what was left, as a queue. Cannot fail.

 Part 11.12: close is callable more than once, and the second call takes
 nothing. The test-and-set of the flag is inside the mutex, so a preempted
 closer cannot race a release.

 **The named mistake, Part 11.6:** discarding the queue this returns drops the
 items, and those items keep their links, so a later send refuses them — and
 after R6b that refusal is exact, so the mistake is caught at the first reuse
 rather than at whichever one happened to have a neighbour.

 The release runs unconditionally; an empty queue costs nothing.

 **R8, the same rule as `receive_all`:** out-of-band first, then ordinary,
 first-in first-out within each — the order `receive` would have taken them.

 @param out : "an empty queue; the remainder is moved onto it, in receive order"
*>
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
    return self._oob.len() + self._regular.len();
}
