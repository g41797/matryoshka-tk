<*
 The pool, and its hooks. A keeper of reusable items, grouped by type identity.

 Policy is not in the pool. Policy is in the hooks.
 The mailbox gives everything back to a caller; the pool's close gives nothing
 back at all.
 There is no `put_all`. A caller giving a batch back writes the loop itself:

 ```c3
 while (mtk::Handle h = batch.pop_front())
 {
     Slot s;
     s.fill(h);
     p.put(&s);
     if (s.is_full()) { batch.push_back(h); break; }
 }
 ```

 It uses only the public surface of the core.
*>
// [3tk: R15, Part 11.7, Part 11.8, Part 11.9, Part 11.10, Part 12, Part 17.2, Part 19.2]
module mtk::pool;
import mtk;
import mtk::helper;
import std::thread;
import std::time;
import std::core::mem::alloc;
import std::atomic::types;

<*
 The three hooks. Implement this to give a pool its policy.

 The implementing object is the context. There is no `ctx` parameter.
 A hook runs OUTSIDE the pool's mutex, several at once on different threads.
 A hook that touches shared state protects it itself.
 A hook does not call back into the pool, and does not block or wait.
*>
// [3tk: Part 12.1, Part 12.3]
interface PoolHooks
{
    <*
     Asked for an item of a named identity.

     Create one, or leave the Slot empty to report failure.
     An empty Slot afterwards becomes `NOT_CREATED`.
     Returning an item of a different identity is a defect of the application.

     @param want : "the identity asked for"
     @param in_pool : "how many of this identity remain, AFTER the removal. A hint, and stale"
     @param slot : "empty on entry; fill it or leave it"
    *>
    // [3tk: Part 12.2, Part 12.4]
    fn void on_get(typeid want, usz in_pool, Slot* slot);

    <*
     An item is being given back. Four outcomes, and none is mandated.

     Released with nothing kept: empty the Slot.
     Kept as it is, or kept after a reset: leave it full.
     Released with a different item put back: replace the contents.
     A full Slot on return means one thing — an item is kept, original or
     replacement.

     @param in_pool : "how many of this identity are held, BEFORE the addition. A hint"
     @param slot : "full on entry"
     @param extra : "an empty queue; items added here are taken the same way, with the same checks"
    *>
    // [3tk: Part 12.2, Part 12.4, Part 12.5]
    fn void on_put(usz in_pool, Slot* slot, InnerQueue* extra);

    <*
     The pool is going down.

     Called with everything that remained, as one flat queue.
     The hook processes or releases every item in it.
     Called OUTSIDE the mutex, after the closed flag is already set.
     Called once by `Pool.close`, and possibly once more with stragglers, so a
     hook must not free its own context on the first call.

     @param remaining : "everything the pool still held, flattened across every identity. No order is promised"
    *>
    // [3tk: R12, V11, Part 12.2]
    fn void on_close(InnerQueue* remaining);
}

<*
 The three modes of a plain get.
*>
// [3tk: Part 11.7]
enum GetMode
{
    AVAILABLE_OR_NEW,
    NEW_ONLY,
    AVAILABLE_ONLY,
}

<*
 The free items of one identity, as a stack.

 A stack and not a queue, and the reason is defect surfacing: the item just
 given back is on top, so a caller still writing through a stale pointer
 collides with the next owner immediately instead of much later.
 No order is promised, and no caller is entitled to one.
*>
// [3tk: R11, Part 11.7, Part 11.10, Part 12.4]
struct PoolBucket
{
    typeid     tag;
    InnerStack free;
}

<*
 The pool itself.

 One bucket per identity, in a flat slice allocated once at creation.
 The identity set is fixed at creation and is not empty.
*>
// [3tk: V6, Part 11.1, Part 11.2, Part 11.7]
struct Pool
{
    Inner node;

    Mutex             _mu;
    ConditionVariable _cv;

    Allocator         _alloc;

    bool         _closed;
    Atomic{bool} _closed_fast;

    PoolBucket[] _buckets;
    PoolHooks    _hooks;
}

<*
 The identity of a Pool as an item.
*>
// [3tk: H0, Part 11.1]
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
 Create a pool on the heap.

 The hooks are a parameter of creation. A pool cannot exist without them.
 The allocator is kept for life, and `release` takes none.
 Nothing partially constructed is ever returned: every step undoes what
 succeeded before it.

 @param a : "the allocator the pool keeps for life"
 @param tags : "the identities this pool holds. Not empty, and no duplicates — both checked"
 @param hooks : "the policy"
*>
// [3tk: D3, Part 3.1, Part 11.7, Part 12, Part 12.1]
fn Pool*? create(Allocator a, typeid[] tags, PoolHooks hooks)
{
    // [3tk: Part 11.7]
    mtk::@check(tags.len > 0, "the set of identities is not empty");
    // [3tk: Part 12.1]
    mtk::@check(hooks != null, "a pool cannot exist without hooks");

    // [3tk: D6, Part 11.7]
    $if mtk::CHECKED:
        foreach (i, t : tags)
        {
            foreach (j, u : tags)
            {
                // [3tk: Part 11.7]
                if (i < j) mtk::@check(t != u, "the pool's set of identities has a duplicate");
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
 Frees the pool.

 Close it first. Releasing an open pool aborts in every build mode.
 Takes no allocator.
*>
// [3tk: D6, Part 11.12, Part 13.1]
fn void Pool.release(&self)
{
    // [3tk: Part 11.12]
    always_assert(self._closed, "releasing an open pool");
    self._cv.destroy()!!;
    self._mu.destroy();
    Allocator a = self._alloc;
    alloc::free(a, self._buckets);
    alloc::free(a, self);
}

<*
 The pre-lock read of the closed flag.

 A hint only. Same rule as the mailbox: never without the re-check.
*>
// [3tk: D16, Part 15.4]
macro bool Pool.@closed_fast(&self) => self._closed_fast.load(ACQUIRE);

<*
 The bucket for an identity, or null. Called under the lock.
*>
// [3tk: A3, P2, Part 11.7, Part 19.3]
fn PoolBucket* Pool.bucket_for(&self, typeid t) @private
{
    foreach (&b : self._buckets) if (b.tag == t) return b;
    return null;
}

<*
 Takes an item, or has the hook create one. Never waits.

 `NOT_AVAILABLE` comes only from `AVAILABLE_ONLY`.
 `NOT_CREATED` comes only from a hook that produced nothing.
 `UNKNOWN_IDENTITY` is a caller defect: a checking build aborts on it.
 The hook runs outside the mutex, and everything read before the unlock is
 stale when it returns.

 @param want : "the identity wanted"
 @param mode : "which of the three modes"
 @param slot : "an empty Slot; filled on success"
 @return? mtk::CLOSED, mtk::NOT_AVAILABLE, mtk::NOT_CREATED, mtk::UNKNOWN_IDENTITY
*>
// [3tk: A3, Part 11.7, Part 12.3, Part 19.2, Part 19.3]
fn void? Pool.get(&self, typeid want, GetMode mode, Slot* slot)
{
    // [3tk: Part 9.2 rule 3]
    mtk::@check(slot.is_empty(), "an acquisition asserts the Slot is empty on entry");

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

    // [3tk: Part 12.4]
    usz in_pool = b.free.len();

    // [3tk: Part 12.3, Part 15.2]
    self._mu.unlock();
    self._hooks.on_get(want, in_pool, slot);

    if (slot.is_empty()) return mtk::NOT_CREATED~;
    // [3tk: Part 12.2]
    mtk::@check(slot.peek().link.type == want, "the get hook returned an item of a different identity");
}

<*
 Takes an item, waiting up to the timeout.

 It never creates. No hook is called on this path.
 Where `get()` in `AVAILABLE_ONLY` reports `NOT_AVAILABLE`, this reports
 `TIMEOUT`.
 `UNKNOWN_IDENTITY` is reported at once rather than after the whole timeout.
 The deadline is anchored once: a spurious wakeup does not restart it.

 @param want : "the identity wanted"
 @param slot : "an empty Slot; filled on success"
 @param timeout : "how long to wait"
 @return? mtk::CLOSED, mtk::TIMEOUT, mtk::UNKNOWN_IDENTITY
*>
// [3tk: A3, D7, Part 2.4, Part 2.5, Part 2.6, Part 11.9, Part 19.2]
fn void? Pool.get_wait(&self, typeid want, Slot* slot, Duration timeout)
{
    // [3tk: Part 9.2 rule 3]
    mtk::@check(slot.is_empty(), "an acquisition asserts the Slot is empty on entry");

    // [3tk: Part 2.5]
    Time deadline = time::now() + timeout;

    self._mu.lock();
    defer self._mu.unlock();

    PoolBucket* b = self.bucket_for(want);
    mtk::@check(b != null, "Pool.get_wait for an identity the pool was not created with");
    // [3tk: A3]
    if (!b) return mtk::UNKNOWN_IDENTITY~;

    while (true)
    {
        // [3tk: Part 2.4]
        if (self._closed) return mtk::CLOSED~;

        // [3tk: A3]
        Handle h = b.free.pop();
        if (h) { slot.fill(h); return; }

        if (catch f = self._cv.wait_until(&self._mu, deadline))
        {
            if (f != thread::WAIT_TIMEOUT) return f~;

            if (self._closed) return mtk::CLOSED~;

            h = b.free.pop();
            if (h) { slot.fill(h); return; }
            // [3tk: Part 2.6]
            if (!b.free.is_empty()) self._cv.signal();
            return mtk::TIMEOUT~;
        }
    }
}

<*
 Gives an item back.

 Returns nothing. The Slot is the answer: cleared means the pool took it,
 unchanged means it was refused and the caller still has the item.
 It cannot fail and cannot be interrupted.
 A close that arrives while the put hook runs is handled: the item goes to the
 close hook, and the caller's Slot stays cleared.

 @param slot : "a full Slot; cleared if the pool took the item"
*>
// [3tk: P1, V11, Part 2.10, Part 9.4, Part 11.8, Part 12.2, Part 12.3, Part 19.2]
fn void Pool.put(&self, Slot* slot)
{
    // [3tk: Part 9.2 rule 6]
    if (slot.is_empty()) return;

    if (self.@closed_fast()) return;

    self._mu.lock();

    if (self._closed) { self._mu.unlock(); return; }

    Handle h = slot.peek();
    PoolBucket* b = self.bucket_for(h.link.type);
    mtk::@check(b != null, "Pool.put of an identity the pool was not created with");
    if (!b) { self._mu.unlock(); return; }

    // [3tk: Part 12.4]
    usz in_pool = b.free.len();

    // [3tk: Part 9.4]
    Slot mine;
    mine.fill(slot.take());

    InnerQueue extra;

    // [3tk: Part 12.3]
    self._mu.unlock();
    self._hooks.on_put(in_pool, &mine, &extra);
    self._mu.lock();

    // [3tk: P1, V11, Part 11.8, Part 12.2, Part 12.3]
    if (self._closed)
    {
        InnerQueue stragglers;
        if (mine.is_full()) stragglers.push_back(mine.take());
        stragglers.append_queue(&extra);

        // [3tk: Part 12.3]
        self._mu.unlock();
        if (!stragglers.is_empty()) self._hooks.on_close(&stragglers);
        return;
    }

    // [3tk: Part 12.2]
    self.take_back(&mine);

    // [3tk: Part 12.5]
    while (Handle e = extra.pop_front()) self.take_back_handle(e);

    self._cv.broadcast();
    self._mu.unlock();
}

<*
 Stores one item the hook decided to keep. Called under the lock.
*>
fn void Pool.take_back(&self, Slot* s) @private
{
    if (s.is_empty()) return;
    self.take_back_handle(s.take());
}

fn void Pool.take_back_handle(&self, Handle h) @private
{
    PoolBucket* b = self.bucket_for(h.link.type);
    mtk::@check(b != null, "the put hook returned an identity the pool was not created with");
    if (!b) return;
    b.free.push(h);
}

<*
 Closes the pool. Cannot fail.

 Nothing comes back to the caller. Everything the pool held goes to the close
 hook, as one flat queue, and the hook processes or releases every item.
 Callable more than once. The second call takes nothing and does NOT run the
 hook again.
 The hook is called ONCE, OUTSIDE the mutex, AFTER the flag is set.
*>
// [3tk: R12, Part 11.8, Part 11.12, Part 12.2, Part 19.2]
fn void Pool.close(&self)
{
    self._mu.lock();

    if (self._closed) { self._mu.unlock(); return; }

    self._closed = true;
    self._closed_fast.store(true, RELEASE);

    // [3tk: R12]
    InnerQueue remaining;
    foreach (&b : self._buckets)
    {
        while (Handle h = b.free.pop()) remaining.push_back(h);
    }

    self._cv.broadcast();
    self._mu.unlock();

    // [3tk: Part 12.2]
    self._hooks.on_close(&remaining);
}

<*
 True if the pool is closed.
*>
fn bool Pool.is_closed(&self) => self.@closed_fast();

<*
 How many of one identity are held.

 A hint. It is stale by the time the caller reads it.
*>
// [3tk: Part 12.4]
fn usz Pool.count_of(&self, typeid t)
{
    self._mu.lock();
    defer self._mu.unlock();
    PoolBucket* b = self.bucket_for(t);
    return b ? b.free.len() : 0;
}
