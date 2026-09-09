// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//==============================================================================
// The hooks, and a module of its own. 3TK-70.
//
// This is the one place in `src/` where the toolkit is the caller and you are
// the implementer. Everything else on `mtk::pool`'s page is what you call, and
// the charter below is a contract on YOUR code, which read as a digression on a
// page about calling the pool. It is the subject of a page now.
//
// The section opens the file, the way `std::atomic::types` opens `atomic.c3`.
//==============================================================================
<*
 The hooks. You implement them; the pool calls them.

 This is where your code runs inside the toolkit.
 The implementing struct is the context. There is no `ctx` parameter.
 A hook runs outside the pool's mutex, several at once on different threads.
 A hook that touches shared state protects it itself.
 A hook does not call back into the pool.
 A hook does not block and does not wait.
 It is a module of its own so that it is a page of its own.
 A user reaches it through `import mtk;` and writes `PoolHooks` unqualified, as before.
*>
module mtk::pool::hooks;

<*
 Three methods. Implement them to give a pool its policy.
*>
interface PoolHooks
{
    <*
     Asked for an outer of a named identity.

     The Slot is empty on entry. Fill it, or leave it.
     An empty Slot afterwards becomes `NOT_CREATED`.
     An outer of a different identity is a defect of your application.
 That is a checking-build check, and a fast build cannot catch it.

     @param want : "the identity asked for"
     @param in_pool : "how many of this identity remain, AFTER the removal. A hint, and stale"
     @param slot : "empty on entry; fill it or leave it"
    *>
    // [3tk: Part 12.2, Part 12.4]
    fn void on_get(typeid want, usz in_pool, Slot* slot);

    <*
     An outer is being given back. Four outcomes, and none is mandated.

     Freed with nothing kept: empty the Slot.
     Kept as it is, or kept after a reset: leave it full.
     Freed with a different outer put back: replace the contents.
     A full Slot on return means one thing — an outer is kept, original or replacement.
     `extra` starts empty. Outers added there are taken the same way, with the same checks.

     @param in_pool : "how many of this identity are held, BEFORE the addition. A hint"
     @param slot : "full on entry"
     @param extra : "an empty queue; outers added here are taken the same way, with the same checks"
    *>
    // [3tk: Part 12.2, Part 12.4, Part 12.5]
    fn void on_put(usz in_pool, Slot* slot, InnerQueue* extra);

    <*
     Take everything that is left.

     Called with everything that remained, as one flat queue, by value.
     Process or free every outer in it. The pool does not verify it and never
     will.
     No order is promised.
     The hook is called outside the mutex, after the closed flag is set.
     Called once by `close`, and possibly once more with stragglers from a concurrent `put`.
     So a hook must not free its own context on the first call.

     @param remaining : "everything the pool still held, flattened across every identity, by value. No order is promised"
    *>
    // [3tk: Part 12.2]
    fn void on_close(InnerQueue remaining);
}

//----------------------
// Little-endian imports
//----------------------
import mtk;




<*
 Reuse of an outer, decided by your hooks. A keeper of free outers, grouped by type identity.

 Write the hooks, create, get, put, close, release.
 Policy is not in the pool. Policy is in the hooks.
 The pool answers whether a reusable outer is free right now.
 A pool is itself an outer: it can travel through a mailbox.

 One bucket per identity, in a flat slice allocated once at creation.
 The identity set is fixed at creation.
 It is not empty, and it has no duplicate. Both are checked.
 A stack and not a queue, and the reason is defect surfacing.
 The hooks are a parameter of creation. A pool cannot exist without them.
 `mtk::pool::hooks` is what you implement; this module is what you call.
 On get an empty Slot goes in, and a full Slot comes back on success.
 A free outer is taken, or `on_get` is asked to make one.
 On put the Slot is the answer: cleared means the pool took the outer, unchanged means it was refused and you still have the outer.
 On close nothing comes back to you. Everything goes to `on_close`.
 Close it first. Releasing an open pool aborts in every build mode.
 Closing does not make a pool quiet: release it only after every call on it has returned.
 The mailbox gives everything back to a caller.
 The pool's close gives nothing back at all.

 There is no `put_all`. A caller giving a batch back writes the loop.

 ```c3
 while (Inner* inner = batch.pop_front())
 {
     Slot s;
     s.fill(inner);
     p.put(&s);
     if (s.is_full()) { batch.push_back(inner); break; }
 }
 ```

 The mailbox and the pool use only the public surface of the core, and `run-builds.sh` tests that.
*>
module mtk::pool;

<*
 The three modes of a plain get.
*>
enum GetMode
{
    AVAILABLE_OR_NEW,
    NEW_ONLY,
    AVAILABLE_ONLY,
}


<*
 The tool itself.

 Created on the heap, with an allocator it keeps for life.
 One bucket per identity, in a flat slice allocated once at creation.
 The identity set is fixed at creation.
 It is not empty, and it has no duplicate. Both are checked.
*>
typedef Pool = void;


<*
 The identity of a `Pool` as an outer.
*>
const typeid TYPE = _Pool::typeid;

<*
 From a `Pool*` to its `Inner*`. Cannot fail.
*>
// Part 4.6: `_Pool` is an Outer, and the pool is an ordinary client of the
// helper — one `@private` alias, exactly as an application writes one.
// `to_inner` keeps the read-only macro for the reason `mailbox.c3` gives at the
// same site: the helper's `inner()` stamps, and this direction is crossed
// concurrently.
alias POOL @private = helper::OF{_Pool};

macro Inner* to_inner(Pool* p) => inner::internal::to_inner((_Pool*)p);

<*
 The checking crossing back. Null when the inner names another type.
*>
macro Pool* of(Inner* inner) => (Pool*)POOL.look(inner);

<*
 Allocates a pool and returns it.

 The hooks are a parameter of creation. A pool cannot exist without them.
 The identity set is a parameter too, and it never changes.
 The allocator is kept for life.
 Nothing partially constructed is ever returned.
 Every step undoes what succeeded before it.

 @param a : "the allocator the pool keeps for life"
 @param tags : "the identities this pool holds. Not empty, and no duplicates — both checked"
 @param hooks : "the policy"
*>
fn Pool*? create(Allocator a, typeid[] tags, PoolHooks hooks)
{
    // [3tk: Part 11.7]
    mtk::@check(tags.len > 0, "the set of identities is not empty");
    // [3tk: Part 12.1]
    mtk::@check(hooks != null, "a pool cannot exist without hooks");

    // [3tk: Part 11.7]
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

    _Pool* p = alloc::new_try(a, _Pool)!;
    defer catch alloc::free(a, p);

    POOL.stamp(p);
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
    return (Pool*)p;
}

<*
 Frees the pool, with the allocator it kept.

 Close it first. Releasing an open pool aborts in every build mode.
 It takes no allocator.
 The pool must be closed and quiet.
 Quiet means no call on the pool is still running.
 Closing does not make a pool quiet: a hook the pool called is application code that has not returned, and a getter parked in `get_wait` is woken by the close and has not yet returned either.
 The usual way to get quiet is to join the threads that touch the pool.
 Releasing a pool that is not quiet aborts in every build mode.
*>
fn void Pool.release(&pool)
{
    _Pool* self = (_Pool*)pool;

    // Rule 1 of the lifetime contract, and the whole of what `_active` is for.
    // Closed is state; quiet is that state and an empty active set together.
    // The predicate is read UNDER the mutex, never before taking it, and
    // `release` is never counted itself: it would then assert against itself.
    //
    // The pool is the harder of the two tools, because Part 12.3 forces the
    // mutex OPEN across every call into a hook. Taking the mutex proves nothing
    // about a `put` that is inside `on_put`; only the count sees it.
    //
    // This is a check and not a wait. A release that waited would block on
    // application code the port does not control. What it catches, it catches
    // on the schedule it happens to see.
    // [3tk: Part 11.12]
    self._mu.lock();
    always_assert(self._closed && self._active == 0,
                  "releasing a pool that is not quiet");
    self._mu.unlock();

    // The order is established against the real structs, not assumed. C3's
    // `Mutex.destroy` is `pthread_mutex_destroy`, which aborts on the EBUSY a
    // held mutex returns, so the unlock above must precede it. The condition
    // variable is destroyed first because no waiter can remain: quiet says so.
    self._cv.destroy()!!;
    self._mu.destroy();
    Allocator a = self._alloc;
    alloc::free(a, self._buckets);
    alloc::free(a, self);
}


<*
 Takes a free outer, or has the hook make one. Never waits.

 `AVAILABLE_OR_NEW` — take a free one, and ask the hook if there is none.
 `NEW_ONLY` — do not take a free one. Ask the hook.
 `AVAILABLE_ONLY` — take a free one, or report `NOT_AVAILABLE`.
 `NOT_AVAILABLE` comes only from `AVAILABLE_ONLY`.
 `NOT_CREATED` comes only from a hook that produced nothing.
 `UNKNOWN_IDENTITY` is your defect. A checking build aborts on it.
 `on_get` runs outside the pool's mutex.
 Everything read before the mutex is released is stale when it returns.

 @param want : "the identity wanted"
 @param mode : "which of the three modes"
 @param slot : "an empty Slot; filled on success"
 @return? mtk::CLOSED, mtk::NOT_AVAILABLE, mtk::NOT_CREATED, mtk::UNKNOWN_IDENTITY
*>
fn void? Pool.get(&pool, typeid want, GetMode mode, Slot* slot)
{
    _Pool* self = (_Pool*)pool;

    // [3tk: Part 9.2 rule 3]
    mtk::@check(slot.is_empty(), "an acquisition asserts the Slot is empty on entry");

    if (self.@closed_fast()) return mtk::CLOSED~;

    self._mu.lock();

    // A rejected entry never becomes active: it raises nothing.
    if (self._closed) { self._mu.unlock(); return mtk::CLOSED~; }

    // Accepted. Raised here, and lowered under the mutex on every path out of
    // the call — including the one that leaves the mutex to run `on_get`.
    // [3tk: Part 11.12]
    self._active++;

    PoolBucket* b = self.bucket_for(want);
    mtk::@check(b != null, "Pool.get for an identity the pool was not created with");
    if (!b) { self._active--; self._mu.unlock(); return mtk::UNKNOWN_IDENTITY~; }

    if (mode != NEW_ONLY)
    {
        Inner* inner = b.free.pop();
        if (inner)
        {
            self._active--;
            self._mu.unlock();
            slot.fill(inner);
            return;
        }
    }

    if (mode == AVAILABLE_ONLY)
    {
        self._active--;
        self._mu.unlock();
        return mtk::NOT_AVAILABLE~;
    }

    // [3tk: Part 12.4]
    usz in_pool = b.free.len();

    // [3tk: Part 12.3, Part 15.2]
    self._mu.unlock();
    self._hooks.on_get(want, in_pool, slot);

    // The one added acquisition in the design, and the reason it is here: the
    // hook above is application code holding a Slot this pool handed it, so the
    // call is still active while it runs, and the count is lowered under the
    // mutex like every other lowering. The mode taken here is the only one that
    // calls a hook; the three that return above pay nothing.
    // [3tk: Part 11.12]
    self._mu.lock();
    self._active--;
    self._mu.unlock();

    if (slot.is_empty()) return mtk::NOT_CREATED~;
    // [3tk: Part 12.2]
    mtk::@check(slot.peek().link.type == want, "the get hook returned an outer of a different identity");
}

<*
 Takes a free outer, waiting up to the timeout.

 It never creates. No hook is called on this path.
 `TIMEOUT` comes only from `get_wait`, where `AVAILABLE_ONLY` would have said `NOT_AVAILABLE`.
 `UNKNOWN_IDENTITY` is your defect.
 `get_wait` reports it at once rather than after the whole timeout.
 The deadline is anchored once. A spurious wakeup does not restart it.

 @param want : "the identity wanted"
 @param slot : "an empty Slot; filled on success"
 @param timeout : "how long to wait"
 @return? mtk::CLOSED, mtk::TIMEOUT, mtk::UNKNOWN_IDENTITY
*>
fn void? Pool.get_wait(&pool, typeid want, Slot* slot, Duration timeout)
{
    _Pool* self = (_Pool*)pool;

    // [3tk: Part 9.2 rule 3]
    mtk::@check(slot.is_empty(), "an acquisition asserts the Slot is empty on entry");

    // [3tk: Part 2.5]
    Time deadline = time::now() + timeout;

    self._mu.lock();
    defer self._mu.unlock();

    PoolBucket* b = self.bucket_for(want);
    mtk::@check(b != null, "Pool.get_wait for an identity the pool was not created with");
    // `get_wait` reports it too, on two grounds that are not conformance: the
    // two gets must not disagree about the same defect, and a defect that
    // sleeps for the whole timeout gets diagnosed as a performance problem.
    if (!b) return mtk::UNKNOWN_IDENTITY~;

    // A rejected entry never becomes active. This check duplicates the one at
    // the head of the loop rather than replacing it: the loop's check is what a
    // woken waiter reads, and this one is what decides whether the call was
    // accepted at all.
    // [3tk: Part 2.4, Part 11.12]
    if (self._closed) return mtk::CLOSED~;

    // Raised before the wait can release the mutex, and lowered with the mutex
    // held again. C3 runs deferred statements in reverse, so this one runs
    // before the unlock declared above it.
    // [3tk: Part 11.12]
    self._active++;
    defer self._active--;

    while (true)
    {
        // [3tk: Part 2.4]
        if (self._closed) return mtk::CLOSED~;

        // No `if (b)` guard: the check above made `b` non-null, and a
        // live-looking branch that cannot be taken is a reader's trap.
        Inner* inner = b.free.pop();
        if (inner) { slot.fill(inner); return; }

        if (catch f = self._cv.wait_until(&self._mu, deadline))
        {
            if (f != thread::WAIT_TIMEOUT) return f~; // dead today: wait_until can only fail with WAIT_TIMEOUT, kept for future wait failures

            if (self._closed) return mtk::CLOSED~;

            inner = b.free.pop();
            if (inner) { slot.fill(inner); return; }
            return mtk::TIMEOUT~;
        }
    }
}

<*
 Gives an outer back. Returns nothing.

 The Slot is the answer.
 Cleared: the pool took it.
 Unchanged: the pool refused it before any hook ran, and you still have the outer.
 It cannot fail and cannot be interrupted.
 An empty Slot is a no-op.
 A close that arrives while `on_put` runs is handled.
 The outer goes to `on_close`, and your Slot stays cleared.

 @param slot : "a full Slot; cleared if the pool took the outer"
*>
fn void Pool.put(&pool, Slot* slot)
{
    _Pool* self = (_Pool*)pool;

    // [3tk: Part 9.2 rule 6]
    if (slot.is_empty()) return;

    if (self.@closed_fast()) return;

    self._mu.lock();

    // A rejected entry never becomes active: it raises nothing.
    if (self._closed) { self._mu.unlock(); return; }

    // Accepted, and raised before the mutex is opened for `on_put` below. This
    // is the site the whole mechanism exists for: `:423` re-takes a mutex that
    // a release breaking Rule 1 would already have destroyed and freed.
    // [3tk: Part 11.12]
    self._active++;

    Inner* inner = slot.peek();
    PoolBucket* b = self.bucket_for(inner.link.type);
    mtk::@check(b != null, "Pool.put of an identity the pool was not created with");
    if (!b) { self._active--; self._mu.unlock(); return; }

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

    // [3tk: Part 11.8, Part 12.2, Part 12.3]
    if (self._closed)
    {
        InnerQueue stragglers;
        if (mine.is_full()) stragglers.push_back(mine.take());
        stragglers.append_queue(&extra);

        // [3tk: Part 12.3]
        self._mu.unlock();
        if (!stragglers.is_empty()) self._hooks.on_close(stragglers.take());

        // Lowered after the straggler hook, not before it. A count that stopped
        // at `on_put` would leave application code running with pool-derived
        // outers while a release saw zero.
        // [3tk: Part 11.12]
        self._mu.lock();
        self._active--;
        self._mu.unlock();
        return;
    }

    // [3tk: Part 12.2]
    self.take_back(&mine);

    // [3tk: Part 12.5]
    while (Inner* e = extra.pop_front()) self.take_back_inner(e);

    self._cv.broadcast();
    self._active--;
    self._mu.unlock();
}

// Stores one outer the hook decided to keep. Called under the lock.
fn void _Pool.take_back(&self, Slot* s)
{
    if (s.is_empty()) return;
    self.take_back_inner(s.take());
}

fn void _Pool.take_back_inner(&self, Inner* inner)
{
    PoolBucket* b = self.bucket_for(inner.link.type);
    mtk::@check(b != null, "the put hook returned an identity the pool was not created with");
    // if (!b) return; <- Force failure instead of silent bug
    b.free.push(inner);
}

<*
 Closes the pool. Cannot fail.

 Nothing comes back to you.
 Everything the pool held goes to `on_close`, as one flat queue.
 Callable more than once. The second call takes nothing and does not run the hook again.
 The hook is called outside the mutex, after the closed flag is set.
 Called once by `close`, and possibly once more with stragglers from a concurrent `put`.
 Closing does not make a pool quiet.
*>
fn void Pool.close(&pool)
{
    _Pool* self = (_Pool*)pool;

    self._mu.lock();

    // The second call takes nothing and does not run the hook again, so it
    // never becomes active either.
    if (self._closed) { self._mu.unlock(); return; }

    // Active for the whole of the call, hook included. `Pool.close` is the one
    // close in the toolkit that runs application code after publishing CLOSED,
    // and the port does not bound how long that hook takes.
    // [3tk: Part 11.12]
    self._active++;

    // One flat queue, and no order is promised: the close hook never sees
    // buckets or per-identity groups.
    InnerQueue remaining;
    self._close(&remaining);

    self._mu.unlock();

    // [3tk: Part 12.2]
    self._hooks.on_close(remaining.take());

    // [3tk: Part 11.12]
    self._mu.lock();
    self._active--;
    self._mu.unlock();
}


<*
 True when it is closed.
*>
fn bool Pool.is_closed(&pool) => ((_Pool*)pool).@closed_fast();

<*
 True when it is closed and no call on it is still running.

 The same predicate `release()` asserts, read under the mutex. The usual way
 to reach this state is to join the threads that touch the pool.
*>
fn bool Pool.is_quiet(&pool)
{
    _Pool* self = (_Pool*)pool;
    self._mu.lock();
    defer self._mu.unlock();
    return self._closed && self._active == 0;
}

<*
 How many of one identity are free.

 A hint. It is stale by the time you read it.
*>
fn usz Pool.count_of(&pool, typeid t)
{
    _Pool* self = (_Pool*)pool;
    self._mu.lock();
    defer self._mu.unlock();
    self._active++;
    defer self._active--;
    PoolBucket* b = self.bucket_for(t);
    return b ? b.free.len() : 0;
}


//----------------------
// Little-endian imports
//----------------------
import mtk;
import std::thread;
import std::time;
import std::core::mem::alloc;
import std::atomic::types;


//==============================================================================
// For internal usage - everything below this line.
//
// `PoolBucket`, `_Pool` and its methods are public, and the reason is now the
// docs site rather than the compiler. C3 ignores `@private` and `@local` on a
// method declaration, so the methods never could be hidden; 3TK-70 gave the
// whole of the real pool a module of its own instead, because `c3c docgen`
// groups by module and by nothing else and publishes a `@private` declaration
// as public. A page of its own is the only thing that keeps it off the page a
// user reads.
//
// `_Pool` LOST ITS `@private` here, and it had to: `mtk::pool` casts to
// `_Pool*` on the first line of every public method, and a `@private` in a
// submodule is not visible to its parent. The owner's ruling is that the intent
// is visibility and not preventing use, so where an attribute and the split
// disagree the split wins.
//
// `InnerStack` KEEPS ITS `@local`, because nothing obstructs it: the stack and
// every caller of it are in this one section. The only enforcement there is is
// still the grep in `run-builds.sh` that cuts at its banner.
//==============================================================================
<*
 The real pool, its buckets and its stack. Not the user surface.

 `Pool` is an empty typedef and this is what is behind it.
 Every public method of `mtk::pool` casts to `_Pool*` on its first line and works on this from there.
 The intrusive stack is here too: it is the storage container, private to the pool, and no 3tk signature passes one.
 It is a module of its own so that it is a page of its own.
*>
module mtk::pool::internal;

<*
 For internal usage.
*>
// The free outers of one identity, as an `InnerStack`. A stack and not a queue,
// and the reason is defect surfacing: the outer just given back is on top, so a
// caller still writing through a stale pointer collides with the next owner at
// once instead of much later. No order is promised.
struct PoolBucket
{
    typeid     tag;
    InnerStack free;
}

<*
 For internal usage.
*>
// Reads the closed flag before taking the lock. A hint: every caller that gets
// false re-reads the flag under the lock. `is_closed` is the one to call.
macro bool _Pool.@closed_fast(&self) => self._closed_fast.load(ACQUIRE);

<*
 For internal usage.
*>
// The bucket for an identity, or null. Called under the lock.
fn PoolBucket* _Pool.bucket_for(&self, typeid t)
{
    foreach (&b : self._buckets) if (b.tag == t) return b;
    return null;
}

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
//
// `release` does not call it. Part 11.12 requires the pool to be closed before
// it is released, and a release that closed first would pass its own check —
// so the check comes first and nothing else runs when it fails.
fn void _Pool._close(&self, InnerQueue* out)
{
    if (self._closed) return;

    self._closed = true;
    self._closed_fast.store(true, RELEASE);

    foreach (&b : self._buckets)
    {
        while (Inner* inner = b.free.pop()) out.push_back(inner);
    }

    self._cv.broadcast();
}

<*
 For internal usage.
*>
// The real fields, behind the opaque `Pool`. Every public method casts on its
// first line and works on this from there.
struct _Pool
{
    Inner inner;

    Mutex             _mu;
    ConditionVariable _cv;

    Allocator         _alloc;

    bool         _closed;
    Atomic{bool} _closed_fast;
    usz          _active;

    PoolBucket[] _buckets;
    PoolHooks    _hooks;
}


//==============================================================================
// The intrusive stack — private to the pool. No module line: this is
// `module mtk::pool::internal` still. `stack.c3` was deleted by 3TK-62,
// reversing 3TK-45, and `InnerStack` stopped being a name a user can reach.
//==============================================================================

<*
 For internal usage.
*>
// The intrusive stack, last-in first-out: the storage container. Where the
// queue carries outers across, the stack holds them still. The pool keeps one
// per identity, it is the only stack 3tk owns, and no 3tk signature passes one
// — the four that take a container take an `InnerQueue*`. Four operations: no
// walker and no splice. The order is not promised, no caller is entitled to
// which outer comes back, and nothing in the stack can fail. Every chain ends
// at an inner pointing at itself, never at null. The count is kept, so `len` is
// O(1); there is no tail, so flattening the stack is O(n).
struct InnerStack  @local
{
    Inner* top;
    usz    count;
}

<*
 For internal usage.
*>
// The insert guard. A null inner is a defect, and so is an outer already on any
// chain; both are gone from a fast build.
macro InnerStack.@guard_insert(&self, Inner* inner)
{
    mtk::@check(inner != null, "insert of a null inner");
    // [3tk: Part 8.7]
    mtk::@check(!inner::internal::is_linked(inner), "the outer is already on a chain");
    inner::internal::check_stamped(inner, "the outer was never stamped: make it with `create`, or call `stamp` once");
}

// --- Questions ----------------------------------------------------------------

<*
 For internal usage.
*>
// True if the stack holds nothing.
fn bool InnerStack.is_empty(&self) @inline => self.count == 0;

<*
 For internal usage.
*>
// How many outers the stack holds. O(1).
fn usz InnerStack.len(&self) @inline => self.count;

// --- Adding --------------------------------------------------------------------

<*
 For internal usage.
*>
// Adds on top. There is no Slot-shaped insert.
fn void InnerStack.push(&self, Inner* inner)
{
    self.@guard_insert(inner);
    inner.repoint_to(self.top ? self.top : inner);
    self.top = inner;
    self.count++;
}

// --- Removing ---------------------------------------------------------------------

<*
 For internal usage.
*>
// Takes the outer on top. Null on an empty stack, and the returned outer's
// chain link is cleared.
fn Inner* InnerStack.pop(&self)
{
    Inner* inner = self.top;
    if (!inner) return null;
    self.top = (inner.points_to() == inner) ? null : inner.points_to();
    self.count--;
    inner::internal::reset(inner);
    return inner;
}


//----------------------
// Little-endian imports
//----------------------
import mtk;
import std::thread;
import std::time;
import std::core::mem::alloc;
import std::atomic::types;
