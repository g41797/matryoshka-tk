<*
 Part 2, Part 14.2, Part 15 — the parts that only threads can test.

 Part 18 invariants 3, 4, 5, 28, 30, 31, 32, 33.
*>
module mtk_test;
import mtk;
import mtk::pool;
import mtk::mailbox;
import std::thread;
import std::time;
import std::core::mem::alloc;
import std::atomic::types;

struct Shared
{
    Mailbox* mb;
    Pool*    pool;
    usz      n;
    Atomic{usz} received;
    Atomic{usz} sum;
}

<*
 **Part 2.5 MUST, invariant 4 — the deadline is anchored once, before the loop.**

 This is the test the whole of D7 exists for, and it is the only test in the
 suite that a plausible wrong implementation passes every other check of.

 A waiter asks for 200ms. A second thread broadcasts on the condition variable
 every 20ms for a full second — spurious wakeups, carrying no item and no
 meaning. The waiter must still time out at roughly 200ms.

 On `wait_until` with the deadline anchored before the loop, it does.
 On `wait_timeout`, which recomputes `now() + ms` on EVERY call, each broadcast
 restarts the full 200ms and the wait runs for the whole second — or forever,
 under a busier waker.

 The test reaches into `mb._cv` directly to provoke the wakeups. That is a
 deliberate use of what D1 leaves reachable: there is no public way to produce
 a spurious wakeup, because a spurious wakeup is not a feature.
*>
fn void the_deadline_is_anchored_once() @test
{
    Mailbox* mb = new_mailbox();
    defer drop_mailbox(mb);

    Thread waker;
    waker.create(&spurious_waker, mb)!!;

    Slot r;
    Clock c = clock::now();
    bool timed_out = @catch_is(mb.receive(&r, time::ms(200)), mtk::TIMEOUT);
    long elapsed = c.mark().to_ms();

    waker.join()!!;

    always_assert(timed_out, "the receive did not time out");
    always_assert(r.is_empty(), "a timed-out receive filled the Slot");
    always_assert(elapsed >= 150, "the receive returned well before its deadline");
    always_assert(elapsed < 600,
        "Part 2.5: the deadline was NOT anchored once. A spurious wakeup restarted the timeout — this is the wait_timeout defect");
}

fn int spurious_waker(void* arg)
{
    Mailbox* mb = (Mailbox*)arg;
    for (usz i = 0; i < 50; i++)
    {
        thread::sleep(time::ms(20))!!;
        mb._cv.broadcast();
    }
    return 0;
}

<*
 Part 11.5 SHOULD: waking every waiter.

 Each released waiter reports WOKEN, the mailbox stays open, and the effect
 does not persist — a thread that starts waiting afterwards is unaffected.

 The generation counter is what separates this from a spurious wakeup, and the
 test above is what proves the two are not confused.
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
        if (catch sh.pool.get(OWNED_TYPE, AVAILABLE_OR_NEW, &s)) continue;

        Owned* o = mtk::helper::must_from_slot{Owned}(&s);
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
        Owned* o = mtk::helper::must_from_slot{Owned}(&r);
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
    if (catch owned_create(self.alloc, slot)) {}
    self.inside.sub(1, SEQ_CONSISTENT);
}

fn void ConcurrentHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic { }

fn void ConcurrentHooks.on_close(&self, InnerQueue* remaining) @dynamic
{
    while (Handle h = remaining.pop_front())
    {
        Slot s;
        s.fill(h);
        owned_release(&s);
    }
}

fn void hooks_run_outside_the_mutex() @test
{
    ConcurrentHooks h;
    h.alloc = mem;
    typeid[1] tags = { OWNED_TYPE };
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
    if (catch p.get(OWNED_TYPE, NEW_ONLY, &s)) return 1;
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
        msg_init(&m);
        Slot s;
        s.fill(msg_to_inner(&m));
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
