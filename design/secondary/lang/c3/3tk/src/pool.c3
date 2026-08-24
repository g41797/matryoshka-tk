<*
 The pool, and its hooks. Part 11.7 to 11.10, Part 12, Part 19.2.

 A keeper of reusable items, grouped by type identity. Policy is not in the
 pool. Policy is in the hooks.

 Part 11.8 is the sharpest asymmetry in the toolkit and this file is where it
 lives: the mailbox gives everything back to a caller, and the pool's close
 gives nothing back at all.

 **`put_all` is gone — R15.** It was `Pool.put` in a loop: no lock kept across
 iterations, the hook still run once per item, no batching and no atomicity.
 It did not spare the caller the difficult case, it handed the difficult case
 back in a different shape — after it returned, the caller still held a partly
 emptied queue and still had to decide what became of the rest. It cost a
 container operation nothing else needed, a MUST clause in Part 11.8, and the
 most awkward contract in the toolkit. A caller giving a batch back writes:

     while (mtk::Handle h = batch.pop_front())
     {
         Slot s;
         s.fill(h);
         p.put(&s);
         if (s.is_full()) { batch.push_back(h); break; }   // refused
     }

 The counter, recorded because it is real: returning a batch from
 `Mailbox.close` to a pool is a common shape, and the caller now writes that
 loop itself, with a chance of getting the refusal case wrong and losing items
 quietly.

 Part 17.2: only the public surface of the core is used here — five types now
 rather than four, `InnerStack` being the new one.

 **`Pool.put` re-reads the closed flag after the hook** — 3TK-12's P1, ruled
 2026-08-24. Part 12.3 MUST forces the mutex open across a hook, and a close can
 run to completion inside that window. See the comment in `put`.
*>
module mtk::pool;
import mtk;
import mtk::helper;
import std::thread;
import std::time;
import std::core::mem::alloc;
import std::atomic::types;

<*
 The three hooks, as a C3 interface. Part 12.1 MUST — the port spells them in
 the language's own interface mechanism.

 ztk needs a struct of raw function pointers plus a type-erased `ctx`, because
 Zig has no interface keyword. **`ctx` disappears here**: the implementing
 object IS the context.

 Part 12.3, and it is a contract rather than a warning: hooks run OUTSIDE the
 pool's mutex, several at once on different threads. A hook that touches shared
 state protects it itself. A hook does not call back into the pool and does not
 block or wait.
*>
interface PoolHooks
{
    <*
     Asked for an item of a named identity. Part 12.2.

     The Slot is empty on entry. Create one, or leave it empty to report
     failure — an empty Slot afterwards becomes NOT_CREATED. Returning an item
     of a different identity is a defect of the application.

     @param want : "the identity asked for"
     @param in_pool : "how many of this identity remain, AFTER the removal. A hint, and stale. Part 12.4"
     @param slot : "empty on entry; fill it or leave it"
    *>
    fn void on_get(typeid want, usz in_pool, Slot* slot);

    <*
     An item is being given back. Part 12.2, four outcomes and none mandated.

     Released with nothing kept: empty the Slot.
     Kept as it is, or kept after a reset: leave it full.
     Released with a different item put back: replace the contents.

     A full Slot on return means one thing — an item is kept, original or
     replacement.

     @param in_pool : "how many of this identity are held, BEFORE the addition. A hint. Part 12.4"
     @param slot : "full on entry"
     @param extra : "an empty queue; items added here are taken the same way, with the same checks. Part 12.5, the composite mechanism"
    *>
    fn void on_put(usz in_pool, Slot* slot, InnerQueue* extra);

    <*
     The pool is going down. Part 12.2.

     Called with everything that remained, as one flat queue. The hook is responsible
     for processing or releasing every item in it. Called OUTSIDE the mutex,
     after the closed flag is already set.

     **Called once by `Pool.close`, and possibly once more with stragglers.**
     Part 12.2 says *called once by close, and once more per straggling put* —
     003 weakened the clause for exactly this, and it is the only MUST 003
     weakens; a `Pool.put` whose hook was still running
     when the close fired has items the pool must not keep and must not lose,
     and it hands them here. `Pool.put`'s body carries the argument. A hook
     writes the same loop either way — process or release every item — and must
     not free its own context on the first call.

     @param remaining : "everything the pool still held, flattened across every identity. No order is promised — R12"
    *>
    fn void on_close(InnerQueue* remaining);
}

<*
 The three modes of a plain get. Part 11.7.
*>
enum GetMode
{
    AVAILABLE_OR_NEW,
    NEW_ONLY,
    AVAILABLE_ONLY,
}

<*
 One free STACK per identity. Part 11.7, R11.

 A stack and not a queue, and the reason is defect surfacing rather than
 performance: the item just given back is on top and the next `get` hands it
 straight to a new owner, so a caller still writing through a stale pointer
 collides with that owner immediately instead of much later. `stack.c3`'s
 header carries the argument in full, because a reader who takes the stack for
 an arbitrary choice will change it back.

 **Part 11.7 promises no order, and Part 11.10 MUST already said so.** What
 makes the property useful is that no caller is entitled to it.

 No count field beside it. Part 11.7 asks for one only where the container's
 length is not O(1), and `InnerStack.len` is O(1) here. Part 12.4's hint is
 read from `free.len()` under the lock, at the moment it is handed to the hook.
*>
struct PoolBucket
{
    typeid     tag;
    InnerStack free;
}

<*
 The five parts of Part 11.2, again, and the pool's own state.

 003 stopped calling them *one internal base* — V6. They are what every
 container has; whether a port shares one struct for them is the port's own
 answer, and this one does not. `Mailbox` carries the argument.

 The identity set is fixed at creation and is not empty — Part 11.7 — so the
 buckets are a flat slice allocated once and scanned linearly. A hash map would
 buy nothing: the set is small, fixed, and never grows.
*>
struct Pool
{
    // Item identity. Part 11.1: the pool is itself an item.
    Inner node;

    // Synchronization.
    Mutex             _mu;
    ConditionVariable _cv;

    // Lifetime. D3: kept for life, and `release` takes no allocator.
    Allocator         _alloc;

    // Container state, from here down.
    bool         _closed;
    Atomic{bool} _closed_fast;

    PoolBucket[] _buckets;
    PoolHooks    _hooks;
}

<*
 The container's own identity and crossings, and this container's PUBLIC
 surface — a Pool is an item like any other, Part 11.1, so a caller holding a
 Handle needs a way back.

 **H0 left no alias to write.** `mtk::helper`'s members are macros, so the two
 crossings are macros that forward to them, and the identity is C3's own
 `Pool::typeid` under the name this container's callers already use. Nothing
 here is a per-type instantiation and nothing here is an alias.
*>
const typeid TYPE = Pool::typeid;

<*
 From a Pool to a handle. Cannot fail.
*>
macro Handle to_handle(Pool* p) => mtk::helper::to_handle(p);

<*
 The checking crossing back. Null when the handle names another type.
*>
macro Pool* of(Handle h) => mtk::helper::from_handle(h, Pool);

<*
 Create a pool. Part 3.1, Part 11.7, Part 12.1.

 The hooks are a parameter of creation and not a later step: Part 12.1 MUST
 says a pool cannot exist without them.

 The identity set is fixed here and is not empty.

 **Creation is a transaction.** The duplicate check below runs before anything
 is allocated, so it needs no cleanup. Everything after does: each step's
 failure undoes exactly what succeeded before it, through `defer catch`, in the
 shape `std::threads::channel` uses for the same problem. The bucket array is
 the last thing allocated and the one most likely to fail, and without this a
 failure there leaks the Pool, the mutex and the condition variable at once.
 Nothing partially constructed is ever returned or observable.

 @param a : "the allocator the pool keeps for life"
 @param tags : "the identities this pool holds. Not empty, and no duplicates — both checked"
 @param hooks : "the policy. Part 12"
*>
fn Pool*? create(Allocator a, typeid[] tags, PoolHooks hooks)
{
    mtk::@check(tags.len > 0, "Part 11.7: the set of identities is not empty");
    mtk::@check(hooks != null, "Part 12.1: a pool cannot exist without hooks");

    // Part 11.7: the set is fixed at creation, so a duplicate is a defect of
    // the caller and never a runtime condition. It has to be refused here
    // because `bucket_for` returns the FIRST match: a second bucket carrying an
    // identity that already has one is unreachable for the whole life of the
    // pool. Items put back would land in the first bucket and the second would
    // stay empty forever — a silent halving of the pool rather than a fault.
    //
    // The check is tier 2 of D6. The O(n^2) scan around it is compiled only
    // where the tiers are live. That pairing — an expensive check behind the
    // tier gate — was Part 8.6's, for the insert walk; **003 deleted Part 8.6**
    // and the pairing survives it as a technique with no Part left to cite. The
    // set is small, fixed, and scanned once at creation.
    $if mtk::CHECKED:
        foreach (i, t : tags)
        {
            foreach (j, u : tags)
            {
                if (i < j) mtk::@check(t != u, "Part 11.7: the pool's set of identities has a duplicate");
            }
        }
    $endif

    Pool* p = alloc::new_try(a, Pool)!;
    defer catch alloc::free(a, p);

    mtk::helper::init(p);
    p._alloc = a;
    p._hooks = hooks;

    p._mu.init()!;
    defer catch p._mu.destroy();

    p._cv.init()!;
    defer catch p._cv.destroy()!!;

    p._buckets = alloc::new_array_try(a, PoolBucket, tags.len)!;
    foreach (i, t : tags)
    {
        p._buckets[i].tag = t;
        p._buckets[i].free = {};
    }
    return p;
}

<*
 Part 11.12 MUST, and the second of the port's two tier 1 sites.

 `always_assert`, aborting in every build mode. Releasing an open pool is a
 defect, and the items it still holds have never reached the close hook.
*>
fn void Pool.release(&self)
{
    always_assert(self._closed, "Part 11.12: releasing an open pool");
    self._cv.destroy()!!;
    self._mu.destroy();
    Allocator a = self._alloc;
    alloc::free(a, self._buckets);
    alloc::free(a, self);
}

<*
 Part 15.4's fast read. Same rule as the mailbox: never without the re-check.
*>
macro bool Pool.@closed_fast(&self) => self._closed_fast.load(ACQUIRE);

<*
 The bucket for an identity, or null. Called under the lock.

 Part 11.7: the set is fixed at creation, so an identity that is not in it is a
 defect of the caller rather than a runtime condition. The check is tier 2, and
 the outcome for a fast build is `UNKNOWN_IDENTITY` — a fault of its own, named
 for the defect it reports. It used to be `NOT_AVAILABLE`, which was a Part 19.3
 violation: 19.3 reserves not-available for the available-only mode, and this
 site produced it from all three. A3, and 3TK-12's finding P2.
*>
fn PoolBucket* Pool.bucket_for(&self, typeid t) @private
{
    foreach (&b : self._buckets) if (b.tag == t) return b;
    return null;
}

<*
 Get. Part 11.7, Part 19.2: item; CLOSED; NOT_AVAILABLE; NOT_CREATED.

 Part 19.3's asymmetry is here: NOT_AVAILABLE comes only from AVAILABLE_ONLY,
 and NOT_CREATED only from a hook that produced nothing.

 `UNKNOWN_IDENTITY` is the fourth thing this can return and it is not a Part 19
 outcome. Part 11.7 makes an identity outside the pool's set a caller defect; a
 checking build aborts on it and a fast build reports it. `inner.c3`'s faultdef
 carries the argument.

 Part 12.3: the hook runs outside the mutex. The pool unlocks, calls, relocks —
 and everything it read before unlocking is stale when it returns.

 @param want : "the identity wanted"
 @param mode : "which of Part 11.7's three modes"
 @param slot : "an empty Slot; filled on success"
 @return? mtk::CLOSED, mtk::NOT_AVAILABLE, mtk::NOT_CREATED, mtk::UNKNOWN_IDENTITY
*>
fn void? Pool.get(&self, typeid want, GetMode mode, Slot* slot)
{
    mtk::@check(slot.is_empty(), "Part 9.2 rule 3: an acquisition asserts the Slot is empty on entry");

    if (self.@closed_fast()) return mtk::CLOSED~;

    self._mu.lock();

    if (self._closed) { self._mu.unlock(); return mtk::CLOSED~; }

    PoolBucket* b = self.bucket_for(want);
    mtk::@check(b != null, "Pool.get for an identity the pool was not created with");
    if (!b) { self._mu.unlock(); return mtk::UNKNOWN_IDENTITY~; }

    if (mode != NEW_ONLY)
    {
        Handle h = b.free.pop();
        if (h)
        {
            self._mu.unlock();
            slot.fill(h);
            return;
        }
    }

    if (mode == AVAILABLE_ONLY)
    {
        self._mu.unlock();
        return mtk::NOT_AVAILABLE~;
    }

    // Part 12.4: on get, the count is the one AFTER removal. Nothing was
    // removed on this path, so it is simply what is left.
    usz in_pool = b.free.len();

    // Part 12.3, Part 15.2: no lock is held across a call into application code.
    self._mu.unlock();
    self._hooks.on_get(want, in_pool, slot);

    if (slot.is_empty()) return mtk::NOT_CREATED~;
    mtk::@check(slot.peek().type == want, "Part 12.2: the get hook returned an item of a different identity");
}

<*
 Get, with waiting. Part 11.9 MUST, Part 19.2: item; CLOSED; TIMEOUT.

 **It never creates.** No hook is called on this path. Where a plain get in
 AVAILABLE_ONLY mode reports NOT_AVAILABLE, this reports TIMEOUT, and Part 11.9
 calls the divergence deliberate.

 ztk's book says twice that this calls the creation hook. The ztk code says it
 does not, and the code is the truth. Part 11.9, `audit 5.2`.

 D7's wait loop, exactly as the mailbox writes it: the deadline is anchored
 once, before the loop; the state is re-evaluated from scratch; a leaver hands
 the signal on.

 **It reports `UNKNOWN_IDENTITY` too, and 3TK-15 changed it to.** The old
 behaviour was benign and inside Part 19.2: `b` stayed null, the loop found
 nothing, and the call timed out. It is changed anyway, on two grounds that are
 not conformance. First, the two gets must not disagree about the same defect —
 one caller learns its identity is unknown and the other is told the pool is
 merely slow, from the same mistake in the same pool. Second, the benign answer
 costs the caller the whole timeout to deliver a verdict the pool had before it
 blocked, and a defect that sleeps is a defect that gets diagnosed as a
 performance problem. The `@check` below is unchanged and still aborts first in
 a checking build; this is what a fast build now says instead of waiting.

 @param want : "the identity wanted"
 @param slot : "an empty Slot; filled on success"
 @param timeout : "how long to wait"
 @return? mtk::CLOSED, mtk::TIMEOUT, mtk::UNKNOWN_IDENTITY
*>
fn void? Pool.get_wait(&self, typeid want, Slot* slot, Duration timeout)
{
    mtk::@check(slot.is_empty(), "Part 9.2 rule 3: an acquisition asserts the Slot is empty on entry");

    Time deadline = time::now() + timeout;      // anchored once. Part 2.5.

    self._mu.lock();
    defer self._mu.unlock();

    // This is the one place in the port that holds a `PoolBucket*` across a
    // release of the mutex — `wait_until` unlocks while it waits. It is safe,
    // and the reason is a property of creation rather than of this loop: the
    // bucket slice is allocated once in `create` and never grown, moved or
    // reallocated, so the address stays valid for the pool's whole life. Only
    // the CONTENTS change under the lock, and they are re-read every turn.
    //
    // No such pointer may be held across a call into application code. A hook
    // may put items back, and the rule there is to look the bucket up again by
    // identity — which is what `take_back_handle` does.
    PoolBucket* b = self.bucket_for(want);
    mtk::@check(b != null, "Pool.get_wait for an identity the pool was not created with");
    if (!b) return mtk::UNKNOWN_IDENTITY~;      // A3. The `defer` above unlocks.

    while (true)
    {
        if (self._closed) return mtk::CLOSED~;

        // No `if (b)` guard on either pop. The early return above made `b`
        // non-null for the rest of the function; before A3 these guards were
        // the whole of the null path, and leaving them would be a reader's
        // trap — a live-looking branch that cannot be taken.
        Handle h = b.free.pop();
        if (h) { slot.fill(h); return; }

        if (catch f = self._cv.wait_until(&self._mu, deadline))
        {
            if (f != thread::WAIT_TIMEOUT) return f~;

            if (self._closed) return mtk::CLOSED~;

            h = b.free.pop();
            if (h) { slot.fill(h); return; }
            // Part 2.6: the leaver hands the signal on.
            if (!b.free.is_empty()) self._cv.signal();
            return mtk::TIMEOUT~;
        }
    }
}

<*
 Put. Part 11.8, Part 19.2.

 **Returns nothing.** Part 9.4: the Slot is the answer, not the outcome.
 Cleared means the pool took it; unchanged means it was refused, and the caller
 still has the item.

 Part 2.10: this path cannot fail and cannot be interrupted. A worker that must
 give its item back must always be able to.

 **A close that fires while the put hook runs is handled, and the body says
 how** — P1, and the closed flag is re-read after the hook. The caller sees
 nothing of it: the Slot was cleared before the hook ran and stays cleared,
 because the pool did take the item.

 @param slot : "a full Slot; cleared if the pool took the item"
*>
fn void Pool.put(&self, Slot* slot)
{
    if (slot.is_empty()) return;             // Part 9.2 rule 6, in spirit

    if (self.@closed_fast()) return;         // refused; the Slot is untouched

    self._mu.lock();

    if (self._closed) { self._mu.unlock(); return; }

    Handle h = slot.peek();
    PoolBucket* b = self.bucket_for(h.type);
    mtk::@check(b != null, "Pool.put of an identity the pool was not created with");
    if (!b) { self._mu.unlock(); return; }

    // Part 12.4: on put, the count is the one BEFORE the addition.
    usz in_pool = b.free.len();

    // The pool takes the item from the caller here. From this line on the
    // caller's Slot is empty and the pool owns the item.
    Slot mine;
    mine.fill(slot.take());

    InnerQueue extra;

    self._mu.unlock();                       // Part 12.3
    self._hooks.on_put(in_pool, &mine, &extra);
    self._mu.lock();

    // **The late close — 3TK-12's P1, and the re-read is the owner's ruling of
    // 2026-08-24.**
    //
    // Part 12.3 MUST requires the mutex to be released across the hook, so
    // `Pool.close` can run to completion inside that window: it sets both
    // flags, drains every bucket into `remaining`, and hands `remaining` to
    // `on_close` — all before this line relocks. Without this re-read the pool
    // then pushes into a bucket of a closed and already-drained pool, and the
    // item is with NOBODY: `slot.take()` above emptied the caller's Slot, so
    // Part 9.4 tells the caller truthfully that the pool has it, and the close
    // hook already ran. Invariant 34 and Part 11.8 both break on that window.
    //
    // Anything this call is still holding therefore goes to the close hook,
    // which is where every other item the pool held went. One rule, and it is
    // the pool's own: **what the pool holds when it discovers it is closed goes
    // to `on_close`.**
    //
    // - Invariant 34 holds: nothing lands in a bucket after the flag is set.
    // - Part 11.8 holds: nothing comes back to the caller, and the caller's
    //   Slot stays cleared because the pool did take the item.
    // - Part 12.2's **called once** is no longer bent, and this comment used to
    //   say it was. 3TK-12's V11 found 002 had no rule for this window at all,
    //   and 003 wrote one: Part 12.3 is a new MUST, invariant 35 is new, and
    //   12.2's clause was weakened to read *called once by close, and once more
    //   per straggling put* — **the only MUST 003 weakens anywhere**. So the
    //   code below now obeys 12.2 rather than deviating from it, and the
    //   deviation that justified it is closed. The reasoning that produced it
    //   stands: losing items is worse than a second call, and the alternative —
    //   restoring the caller's Slot — cannot carry `extra`, whose items the
    //   caller never had.
    //
    // A hook must therefore tolerate a second `on_close` carrying stragglers.
    // It is the same contract it already has for the first one: process or
    // release every item.
    if (self._closed)
    {
        InnerQueue stragglers;
        if (mine.is_full()) stragglers.push_back(mine.take());
        stragglers.append_queue(&extra);

        self._mu.unlock();                   // Part 12.3, as for every hook call
        if (!stragglers.is_empty()) self._hooks.on_close(&stragglers);
        return;
    }

    // Part 12.2: a full Slot on return means one thing — an item is kept.
    // Original or replacement.
    self.take_back(&mine);

    // Part 12.5: each item of the extra container is added the same way, with
    // the
    // same checks. This is how a composite item gives its parts back.
    while (Handle e = extra.pop_front()) self.take_back_handle(e);

    self._cv.broadcast();
    self._mu.unlock();
}

<*
 Store one item the hook decided to keep. Called under the lock.
*>
fn void Pool.take_back(&self, Slot* s) @private
{
    if (s.is_empty()) return;                // the hook released it
    self.take_back_handle(s.take());
}

fn void Pool.take_back_handle(&self, Handle h) @private
{
    PoolBucket* b = self.bucket_for(h.type);
    mtk::@check(b != null, "the put hook returned an identity the pool was not created with");
    if (!b) return;
    b.free.push(h);
}

<*
 Close. Part 11.8, Part 12.2, Part 19.2. Cannot fail.

 **Nothing comes back to the caller.** Everything the pool held goes to the
 close hook, as one flat queue, and the hook is responsible for processing or
 releasing every item. That is the mirror image of the mailbox's close and the
 sharpest asymmetry in the toolkit.

 Part 11.12: callable more than once. The second call takes nothing and does
 NOT run the hook again. The test-and-set is inside the mutex.

 Part 12.2: the hook is called ONCE, OUTSIDE the mutex, AFTER the flag is set.
*>
fn void Pool.close(&self)
{
    self._mu.lock();

    if (self._closed) { self._mu.unlock(); return; }

    self._closed = true;
    self._closed_fast.store(true, RELEASE);

    // R12: every bucket is emptied into ONE queue, flattened. The close hook
    // never sees buckets or per-identity groups — one container, one loop.
    //
    // A stack keeps no tail, so the O(1) splice `append_queue` offers is not
    // available and this is `pop` then `push_back`: O(n) in the items kept,
    // once, on a pool going down. The loop has a property a splice lacks —
    // every item passes through `pop` and `push_back`, so its self-link is
    // repaired on the way, which a splice would have had to walk and do
    // anyway.
    //
    // No order is promised. `push_back` is chosen for being the simplest
    // write, not for the order it happens to produce.
    InnerQueue remaining;
    foreach (&b : self._buckets)
    {
        while (Handle h = b.free.pop()) remaining.push_back(h);
    }

    self._cv.broadcast();
    self._mu.unlock();

    // Outside the mutex, after the flag is set, exactly once.
    self._hooks.on_close(&remaining);
}

<*
 Is it closed.
*>
fn bool Pool.is_closed(&self) => self.@closed_fast();

<*
 How many of one identity are held. Part 12.4: a hint, stale on return.
*>
fn usz Pool.count_of(&self, typeid t)
{
    self._mu.lock();
    defer self._mu.unlock();
    PoolBucket* b = self.bucket_for(t);
    return b ? b.free.len() : 0;
}
