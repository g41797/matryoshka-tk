<*
 The pool, and its hooks. Part 11.7 to 11.10, Part 12, Part 19.2.

 A keeper of reusable items, grouped by type identity. Policy is not in the
 pool. Policy is in the hooks.

 Part 11.8 is the sharpest asymmetry in the toolkit and this file is where it
 lives: the mailbox gives everything back to a caller, and the pool's close
 gives nothing back at all.

 Part 17.2: only the public surface of the core four is used here.
*>
module mtk::pool;
import mtk;
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
     @param extra : "empty on entry; items added here are taken the same way, with the same checks. Part 12.5, the composite mechanism"
    *>
    fn void on_put(usz in_pool, Slot* slot, NodeList* extra);

    <*
     The pool is going down. Part 12.2.

     Called once, with the full list of what remained. The hook is responsible
     for processing or releasing every item in it. Called OUTSIDE the mutex,
     after the closed flag is already set.

     @param remaining : "everything the pool still held"
    *>
    fn void on_close(NodeList* remaining);
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
 One free list per identity. Part 11.7.

 No count field beside it. Part 11.7 asks for one only where the list's length
 is not O(1), and `NodeList.len` is O(1) here — the list keeps its own count.
 Part 12.4's hint is read from `free.len()` under the lock, at the moment it is
 handed to the hook.
*>
struct PoolBucket
{
    typeid   tag;
    NodeList free;
}

<*
 Part 11.2's internal base again, and the pool's own state.

 The identity set is fixed at creation and is not empty — Part 11.7 — so the
 buckets are a flat slice allocated once and scanned linearly. A hash map would
 buy nothing: the set is small, fixed, and never grows.
*>
struct Pool
{
    AnyNode node;

    Mutex             _mu;
    ConditionVariable _cv;
    Allocator         _alloc;

    bool         _closed;
    Atomic{bool} _closed_fast;

    PoolBucket[] _buckets;
    PoolHooks    _hooks;
}

alias init   = mtk::helper::init{Pool};
alias to_any = mtk::helper::to_any{Pool};
alias of     = mtk::helper::from_any{Pool};
alias TYPE   = mtk::helper::TYPE{Pool};

<*
 Create a pool. Part 3.1, Part 11.7, Part 12.1.

 The hooks are a parameter of creation and not a later step: Part 12.1 MUST
 says a pool cannot exist without them.

 The identity set is fixed here and is not empty.

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
    // where the tiers are live, which is the pairing Part 8.6 uses for the
    // insert walk. The set is small, fixed, and scanned once at creation.
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
    init(p);
    p._alloc = a;
    p._hooks = hooks;
    p._mu.init()!;
    p._cv.init()!;

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
 defect of the caller rather than a runtime condition. The check is tier 2 and
 the outcome for a fast build is NOT_AVAILABLE, which is the truthful answer.
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

 Part 12.3: the hook runs outside the mutex. The pool unlocks, calls, relocks —
 and everything it read before unlocking is stale when it returns.

 @param want : "the identity wanted"
 @param mode : "which of Part 11.7's three modes"
 @param slot : "an empty Slot; filled on success"
 @return? mtk::CLOSED, mtk::NOT_AVAILABLE, mtk::NOT_CREATED
*>
fn void? Pool.get(&self, typeid want, GetMode mode, Slot* slot)
{
    mtk::@check(slot.is_empty(), "Part 9.2 rule 3: an acquisition asserts the Slot is empty on entry");

    if (self.@closed_fast()) return mtk::CLOSED~;

    self._mu.lock();

    if (self._closed) { self._mu.unlock(); return mtk::CLOSED~; }

    PoolBucket* b = self.bucket_for(want);
    mtk::@check(b != null, "Pool.get for an identity the pool was not created with");
    if (!b) { self._mu.unlock(); return mtk::NOT_AVAILABLE~; }

    if (mode != NEW_ONLY)
    {
        AnyHandle h = b.free.pop_front();
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

 @param want : "the identity wanted"
 @param slot : "an empty Slot; filled on success"
 @param timeout : "how long to wait"
 @return? mtk::CLOSED, mtk::TIMEOUT
*>
fn void? Pool.get_wait(&self, typeid want, Slot* slot, Duration timeout)
{
    mtk::@check(slot.is_empty(), "Part 9.2 rule 3: an acquisition asserts the Slot is empty on entry");

    Time deadline = time::now() + timeout;      // anchored once. Part 2.5.

    self._mu.lock();
    defer self._mu.unlock();

    PoolBucket* b = self.bucket_for(want);
    mtk::@check(b != null, "Pool.get_wait for an identity the pool was not created with");

    while (true)
    {
        if (self._closed) return mtk::CLOSED~;

        if (b)
        {
            AnyHandle h = b.free.pop_front();
            if (h) { slot.fill(h); return; }
        }

        if (catch f = self._cv.wait_until(&self._mu, deadline))
        {
            if (f != thread::WAIT_TIMEOUT) return f~;

            if (self._closed) return mtk::CLOSED~;
            if (b)
            {
                AnyHandle h = b.free.pop_front();
                if (h) { slot.fill(h); return; }
                // Part 2.6: the leaver hands the signal on.
                if (!b.free.is_empty()) self._cv.signal();
            }
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

 @param slot : "a full Slot; cleared if the pool took the item"
*>
fn void Pool.put(&self, Slot* slot)
{
    if (slot.is_empty()) return;             // Part 9.2 rule 6, in spirit

    if (self.@closed_fast()) return;         // refused; the Slot is untouched

    self._mu.lock();

    if (self._closed) { self._mu.unlock(); return; }

    AnyHandle h = slot.peek();
    PoolBucket* b = self.bucket_for(h.type);
    mtk::@check(b != null, "Pool.put of an identity the pool was not created with");
    if (!b) { self._mu.unlock(); return; }

    // Part 12.4: on put, the count is the one BEFORE the addition.
    usz in_pool = b.free.len();

    // The pool takes the item from the caller here. From this line on the
    // caller's Slot is empty and the pool owns the item.
    Slot mine;
    mine.fill(slot.take());

    NodeList extra;

    self._mu.unlock();                       // Part 12.3
    self._hooks.on_put(in_pool, &mine, &extra);
    self._mu.lock();

    // Part 12.2: a full Slot on return means one thing — an item is kept.
    // Original or replacement.
    self.take_back(&mine);

    // Part 12.5: each item of the extra list is added the same way, with the
    // same checks. This is how a composite item gives its parts back.
    while (AnyHandle e = extra.pop_front()) self.take_back_handle(e);

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

fn void Pool.take_back_handle(&self, AnyHandle h) @private
{
    PoolBucket* b = self.bucket_for(h.type);
    mtk::@check(b != null, "the put hook returned an identity the pool was not created with");
    if (!b) return;
    b.free.push_back(h);
}

<*
 Put a list. Part 11.8, Part 19.2.

 **Returns nothing. Read the list:** non-empty after the call means the rest was
 refused.

 Part 11.8: a list put stops at the first refusal, puts that item back at the
 FRONT of the caller's list, and returns. The restored order after a mid-batch
 close may differ from the original, and the specification says so.

 @param items : "the items to give back; anything refused is left here"
*>
fn void Pool.put_all(&self, NodeList* items)
{
    while (AnyHandle h = items.pop_front())
    {
        Slot s;
        s.fill(h);
        self.put(&s);
        if (s.is_full())
        {
            // Refused. Back at the front of the caller's list, and stop.
            items.push_front_slot(&s);
            return;
        }
    }
}

<*
 Close. Part 11.8, Part 12.2, Part 19.2. Cannot fail.

 **Nothing comes back to the caller.** Everything the pool held goes to the
 close hook, which is responsible for processing or releasing every item. That
 is the mirror image of the mailbox's close and the sharpest asymmetry in the
 toolkit.

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

    NodeList remaining;
    foreach (&b : self._buckets) remaining.append_list(&b.free);

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
