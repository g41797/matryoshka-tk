<*
 Part 2, Part 14.2, Part 15 — the parts that only threads can test.

 Part 18 invariants 3, 4, 5, 28, 30, 31, 32, 33.
*>
module mtk_test;

struct Shared
{
    Mailbox* mb;
    Pool*    pool;
    usz      n;
    Atomic{usz} received;
    Atomic{usz} sum;
}

// **Part 2.5 MUST, invariant 4 — the deadline is anchored once, before the
// loop.**
//
// `the_deadline_is_anchored_once` reached into `mb._cv` directly to provoke a
// spurious wakeup and prove `wait_until`'s deadline survives it. 3TK-58 made
// `Mailbox` opaque, which put `_cv` out of reach, and there is no black-box
// way to produce a spurious wakeup: every public way to signal the condition
// variable (`send`/`send_oob`, `wake_all()`, `close()`) changes one of the
// three things the receive loop checks before it would loop back to wait, so
// the "signaled, nothing changed" case this test provoked is structurally
// unreachable from outside the module once `_cv` isn't reachable either. The
// test was dropped rather than rewritten; Part 2.5, D7 stays documented, not
// mechanically tested. See the "Tests improvements" TODO in `3tk-status.md`.

<*
 Part 11.5 SHOULD: waking every waiter.

 Each released waiter reports WOKEN, the mailbox stays open, and the effect
 does not persist — a thread that starts waiting afterwards is unaffected.

 The generation counter is what separates this from a spurious wakeup.
*>
fn void wake_all_releases_every_waiter() @test
{
    Mailbox* mb = new_mailbox();
    defer drop_mailbox(mb);

    Shared sh;
    sh.mb = mb;
    sh.n = 4;

    Thread[4] ts;
    foreach (&t : ts) t.create(&woken_waiter, &sh)!!;

    thread::sleep(time::ms(120))!!;
    if (catch mb.wake_all()) { always_assert(false, "wake_all failed on an open mailbox"); }

    foreach (&t : ts) t.join()!!;

    always_assert(sh.received.load(ACQUIRE) == 4, "wake_all did not release every waiter");
    always_assert(!mb.is_closed(), "wake_all closed the mailbox");

    // the effect does not persist: a receive started now still times out
    Slot r;
    always_assert(@catch_is(mb.receive(&r, time::ms(60)), mtk::TIMEOUT), "the wake persisted into a later wait");
}

fn int woken_waiter(void* arg)
{
    Shared* sh = (Shared*)arg;
    Slot r;
    if (catch f = sh.mb.receive(&r, time::sec(5)))
    {
        if (f == mtk::WOKEN) sh.received.add(1, SEQ_CONSISTENT);
    }
    return 0;
}

<*
 Part 2.7 MUST: many producers, many consumers, fan-in and fan-out on one
 object.

 Part 14.2 MUST, invariant 31 — **the transfer orders memory.** Each producer
 writes `id` into the item before sending and each consumer reads it after
 receiving, with no atomics and no fences on the item's own fields. The sum
 coming out right is the guarantee holding: the mailbox's mutex is what carries
 the writes across.

 Part 15.1: no application data is under the toolkit's lock, and the item's
 fields are application data.
*>
fn void many_producers_many_consumers() @test
{
    TestHooks h;
    Pool* pool = new_pool(&h);
    Mailbox* mb = new_mailbox();

    Shared sh;
    sh.mb = mb;
    sh.pool = pool;
    sh.n = 50;

    Thread[3] producers;
    Thread[3] consumers;
    foreach (&t : consumers) t.create(&consumer_fn, &sh)!!;
    foreach (&t : producers) t.create(&producer_fn, &sh)!!;

    foreach (&t : producers) t.join()!!;

    // 3 producers x 50 items
    while (sh.received.load(ACQUIRE) < 150) thread::sleep(time::ms(5))!!;

    InnerQueue left;
    mb.close(&left);
    foreach (&t : consumers) t.join()!!;

    always_assert(sh.received.load(ACQUIRE) == 150, "items were lost in transit");
    // each producer sends ids 0..49, three times over
    always_assert(sh.sum.load(ACQUIRE) == 3 * (49 * 50 / 2), "Part 14.2: an item's fields did not cross the transfer");
    always_assert(left.is_empty(), "the mailbox still held items");

    mb.release();
    pool.close();
    pool.release();
}

fn int producer_fn(void* arg)
{
    Shared* sh = (Shared*)arg;
    for (usz i = 0; i < sh.n; i++)
    {
        Slot s;
        if (catch sh.pool.get(Holder::typeid, AVAILABLE_OR_NEW, &s)) continue;

        Holder* o = mtk::helper::must_from_slot(&s, Holder);
        o.id = (int)i;                              // a plain write, no atomics

        if (catch sh.mb.send(&s)) { sh.pool.put(&s); }
    }
    return 0;
}

fn int consumer_fn(void* arg)
{
    Shared* sh = (Shared*)arg;
    while (true)
    {
        Slot r;
        if (catch f = sh.mb.receive(&r, time::ms(200)))
        {
            if (f == mtk::CLOSED) return 0;
            continue;
        }
        Holder* o = mtk::helper::must_from_slot(&r, Holder);
        sh.sum.add((usz)o.id, SEQ_CONSISTENT);      // a plain read, no atomics
        sh.received.add(1, SEQ_CONSISTENT);
        sh.pool.put(&r);                            // Part 2.10: the give-back cannot fail
    }
}

<*
 Part 12.3 MUST, invariant 28: hooks run outside the mutex, several at once, on
 different threads, and the pool does not serialize them.

 The hook here counts its own concurrent entries. If the pool held its lock
 across the call, the maximum would be one — and the assertion names that.
*>
struct ConcurrentHooks (PoolHooks)
{
    Allocator   alloc;
    Atomic{usz} inside;
    Atomic{usz} max_inside;
}

fn void ConcurrentHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic
{
    usz now = self.inside.add(1, SEQ_CONSISTENT) + 1;
    if (now > self.max_inside.load(ACQUIRE)) self.max_inside.store(now, RELEASE);
    thread::sleep(time::ms(20))!!;              // hold the hook open
    if (catch mtk::managed::create(Holder, self.alloc, slot)) {}
    self.inside.sub(1, SEQ_CONSISTENT);
}

fn void ConcurrentHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic { }

fn void ConcurrentHooks.on_close(&self, InnerQueue remaining) @dynamic
{
    while (Handle h = remaining.pop_front())
    {
        Slot s;
        s.fill(h);
        mtk::managed::release(Holder, &s);
    }
}

fn void hooks_run_outside_the_mutex() @test
{
    ConcurrentHooks h;
    h.alloc = mem;
    typeid[1] tags = { Holder::typeid };
    Pool* p = pool::create(mem, &tags, &h)!!;

    Thread[4] ts;
    foreach (&t : ts) t.create(&hook_caller, p)!!;
    foreach (&t : ts) t.join()!!;

    always_assert(h.max_inside.load(ACQUIRE) > 1,
        "Part 12.3: the hooks were serialized — a lock is being held across a call into application code");

    p.close();
    p.release();
}

fn int hook_caller(void* arg)
{
    Pool* p = (Pool*)arg;
    Slot s;
    if (catch p.get(Holder::typeid, NEW_ONLY, &s)) return 1;
    p.put(&s);
    return 0;
}

<*
 Part 2.6 MUST, invariant 5: signal hand-off on a lost race.

 Several waiters, one item, and one of them leaves on a timeout. The item must
 still reach somebody. Without the hand-off a pending signal is consumed by a
 waiter that then leaves, and the item sits with nobody woken.

 This is a race, so the test runs the shape repeatedly rather than once.
*>
fn void a_leaver_hands_the_signal_on() @test
{
    for (usz round = 0; round < 20; round++)
    {
        Mailbox* mb = new_mailbox();

        Shared sh;
        sh.mb = mb;

        Thread[2] ts;
        foreach (&t : ts) t.create(&short_waiter, &sh)!!;

        thread::sleep(time::ms(15))!!;

        Msg m;
        mtk::helper::init(&m);
        Slot s;
        s.fill(mtk::helper::to_handle(&m));
        if (catch mb.send(&s)) {}

        foreach (&t : ts) t.join()!!;

        InnerQueue left;
        mb.close(&left);
        // the item is either with a receiver or still queued; never lost
        always_assert(sh.received.load(ACQUIRE) + left.len() == 1,
            "Part 2.6: the item was lost between a leaver and the queue");
        while (left.pop_front()) {}
        mb.release();
    }
}

fn int short_waiter(void* arg)
{
    Shared* sh = (Shared*)arg;
    Slot r;
    if (catch sh.mb.receive(&r, time::ms(25))) return 0;
    sh.received.add(1, SEQ_CONSISTENT);
    return 0;
}

<*
 **Part 11.8, invariant 34 — the late close. 3TK-12's P1, fixed 2026-08-24.**

 Part 12.3 MUST forces `Pool.put` to release the mutex across `on_put`, so a
 `Pool.close` can run to completion inside that window: it sets both flags,
 drains every bucket, and calls `on_close` — all before `put` relocks. A `put`
 that then stores what its hook kept pushes into a closed and already-drained
 pool, and the item is with NOBODY. The caller's Slot was cleared before the
 hook ran, so Part 9.4 tells the caller truthfully that the pool has it; the
 close hook already ran, so the hook never sees it. Nothing releases it.

 **This test makes that race deterministic**, which is why it exists at all —
 the audit found P1 by reading, and a defect found by reading is one a suite
 does not provoke. The hook parks until a second thread has closed the pool and
 returned, so the window is not narrow, it is held open.

 The hook waits, which Part 12.3 tells a hook not to do. That is the test being
 a test: it is the only way to hold the window open without calling back into
 the pool from the hook, which is the other half of the same contract.

 What is asserted is the rule the fix carries: **what the pool holds when it
 discovers it is closed goes to `on_close`.** Both the kept item and the
 hook's `extra` parts — Part 12.5's composite mechanism, which the caller never
 had and could not be given back — reach the close hook and are released.
*>
struct LateCloseHooks (PoolHooks)
{
    Allocator   alloc;
    Atomic{usz} in_hook;        // the put hook has been entered
    Atomic{usz} close_done;     // the closer thread has returned from close()
    Atomic{usz} closes;         // how many times on_close ran
    Atomic{usz} released;       // items released across every on_close
    usz         extras;         // parts the put hook hands back, Part 12.5
}

fn void LateCloseHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic
{
    if (catch mtk::managed::create(Holder, self.alloc, slot)) {}
}

fn void LateCloseHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic
{
    self.in_hook.store(1, RELEASE);

    // Park until the pool is closed and `close` has returned. Bounded, because
    // a hang reports nothing and a wrong answer reports something.
    for (usz i = 0; i < 2000 && !self.close_done.load(ACQUIRE); i++)
    {
        thread::sleep(time::ms(1))!!;
    }

    for (usz i = 0; i < self.extras; i++)
    {
        Slot part;
        if (catch mtk::managed::create(Holder, self.alloc, &part)) break;
        extra.push_back_slot(&part);
    }

    // The Slot stays full: the hook kept the item. There is nowhere for the
    // pool to put it now, and that is the whole point.
}

fn void LateCloseHooks.on_close(&self, InnerQueue remaining) @dynamic
{
    self.closes.add(1, SEQ_CONSISTENT);
    while (Handle h = remaining.pop_front())
    {
        Slot s;
        s.fill(h);
        mtk::managed::release(Holder, &s);
        self.released.add(1, SEQ_CONSISTENT);
    }
}

fn void a_close_during_the_put_hook_loses_nothing() @test
{
    LateCloseHooks h;
    h.alloc  = mem;
    h.extras = 2;

    typeid[1] tags = { Holder::typeid };
    Pool* p = pool::create(mem, &tags, &h)!!;

    Slot s;
    p.get(Holder::typeid, NEW_ONLY, &s)!!;
    always_assert(s.is_full(), "the get did not produce an item");

    LateCloseArg arg = { p, &h };
    Thread closer;
    closer.create(&late_closer, &arg)!!;

    p.put(&s);          // enters the hook, which parks until the close is done
    closer.join()!!;

    always_assert(h.close_done.load(ACQUIRE) == 1,
        "the closer thread never ran; the test proved nothing");

    // Part 9.4: cleared means the pool took it. It did, and it must therefore
    // account for it.
    always_assert(s.is_empty(), "the put left the item with the caller");

    // Invariant 34: nothing landed in a bucket after the flag was set.
    always_assert(p.count_of(Holder::typeid) == 0,
        "invariant 34: an item is in a closed pool");

    // The straggler call. Without the fix this is 1 and three items leak.
    always_assert(h.closes.load(ACQUIRE) == 2,
        "the stragglers never reached the close hook");
    always_assert(h.released.load(ACQUIRE) == 3,
        "the kept item and its two parts did not all reach the close hook");

    p.release();
}

struct LateCloseArg
{
    Pool*           p;
    LateCloseHooks* h;
}

fn int late_closer(void* arg)
{
    LateCloseArg* a = (LateCloseArg*)arg;

    for (usz i = 0; i < 2000 && !a.h.in_hook.load(ACQUIRE); i++)
    {
        thread::sleep(time::ms(1))!!;
    }
    if (!a.h.in_hook.load(ACQUIRE)) return 1;

    a.p.close();
    a.h.close_done.store(1, RELEASE);
    return 0;
}

//----------------------
// Little-endian imports
//----------------------
import mtk;
import mtk::pool;
import mtk::mailbox;
import std::thread;
import std::time;
import std::core::mem::alloc;
import std::atomic::types;
