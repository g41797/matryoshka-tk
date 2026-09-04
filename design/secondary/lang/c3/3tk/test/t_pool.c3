<*
 Part 11.7 to 11.10, Part 12, Part 19.2 — the pool and its hooks.

 Part 18 invariants 24, 25, 27, 28, 29.
*>
module mtk_test;
import mtk;
import std::atomic::types;
import mtk::pool;
import mtk::mailbox;
import std::time;
import std::core::mem::alloc;
import std::thread;

<*
 A hook object. Part 12.1: the implementing object IS the context, so ztk's
 type-erased `ctx` has nothing to do here.

 The counters let the tests assert on WHICH hook ran and how often, which is
 how Part 11.9 — the waiting get never creates — is proved rather than assumed.
*>
struct TestHooks (PoolHooks)
{
    Allocator alloc;
    // Part 12.3: a hook runs outside the pool's mutex, several at once on
    // different threads, so a hook that touches shared state protects it
    // itself. These were plain counters until 3TK-9's ThreadSanitizer run
    // caught three producers and three consumers racing on them. Same
    // mechanism the port uses for its own cross-thread flag.
    Atomic{usz} gets;
    Atomic{usz} puts;
    Atomic{usz} closes;
    Atomic{usz} closed_with;
    Atomic{usz} last_get_count;
    Atomic{usz} last_put_count;

    bool refuse_to_create;      // on_get leaves the Slot empty -> NOT_CREATED
    bool release_on_put;        // on_put empties the Slot -> nothing kept
    usz  extras_on_put;         // on_put also hands back this many parts
}

fn void TestHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic
{
    // Part 12.3, and 3TK-9 found this the hard way: a hook runs OUTSIDE the
    // pool's mutex, several at once on different threads. **A hook that
    // touches shared state protects it itself.** These counters were plain
    // increments until ThreadSanitizer caught three producers and three
    // consumers racing on them. The port was right; its own tests were the
    // application that broke the contract.
    //
    // The fix belongs here and not in the pool. Holding the pool's lock across
    // the hook would silence the warning by breaking Part 12.3.
    //
    // Reads stay plain: every assertion runs after `join`, which orders them.
    self.gets.add(1);
    self.last_get_count.store(in_pool);
    if (self.refuse_to_create) return;             // Part 12.2: an empty Slot is the failure
    if (catch mtk::managed::create(Holder, self.alloc, slot)) return;
}

fn void TestHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic
{
    // Part 12.3, as in on_get above.
    self.puts.add(1);
    self.last_put_count.store(in_pool);

    for (usz i = 0; i < self.extras_on_put; i++)
    {
        Slot part;
        if (catch mtk::managed::create(Holder, self.alloc, &part)) break;
        extra.push_back_slot(&part);
    }

    if (self.release_on_put) mtk::managed::release(Holder, slot);  // released, nothing kept
    // otherwise the Slot stays full: kept as it is
}

fn void TestHooks.on_close(&self, InnerQueue remaining) @dynamic
{
    // Part 12.2 calls the close hook exactly once, so this one cannot race
    // today. It is written the same way as the other two because the contract
    // is the same and the next test to call close from a thread should not have
    // to rediscover 3TK-9.
    self.closes.add(1);
    self.closed_with.store(remaining.len());
    while (Inner* inner = remaining.pop_front())
    {
        Slot s;
        s.fill(inner);
        mtk::managed::release(Holder, &s);
    }
}

fn Pool* new_pool(TestHooks* hooks)
{
    hooks.alloc = mem;
    typeid[1] tags = { Holder::typeid };
    return pool::create(mem, &tags, hooks)!!;
}

<*
 The give-back loop, written once. **R15 deleted `Pool.put_all`**, and this is
 what replaced it — the three lines its doc comment now carries, in the one
 place the tests need them.

 The refusal case is the whole of it: a closed pool leaves the Slot full, the
 caller still owns that outer, and it goes back on the caller's own queue. The
 proposal recorded the risk plainly — a caller who gets this wrong loses outers
 quietly — so the loop is tested here rather than assumed.

 @param outers : "the outers to give back; anything refused is left here"
*>
fn void put_batch(Pool* p, InnerQueue* outers)
{
    while (Inner* inner = outers.pop_front())
    {
        Slot s;
        s.fill(inner);
        p.put(&s);
        if (s.is_full())
        {
            outers.push_back_slot(&s);   // refused; the caller keeps it
            return;
        }
    }
}

<*
 Part 11.1, invariant 21: the pool is itself an outer, exactly as the mailbox is.
*>
fn void a_pool_is_an_item() @test
{
    TestHooks h;
    Pool* p = new_pool(&h);
    defer { p.close(); p.release(); }

    Inner* ph = pool::to_inner(p);
    always_assert(ph.link.type == pool::TYPE, "the pool carries no identity");
    always_assert(pool::of(ph) == p, "the pool did not survive the round trip");
    always_assert(pool::TYPE != mailbox::TYPE, "the two containers share an identity");
}

<*
 Part 11.7: get in available-or-new mode asks the hook when nothing is stored,
 and takes the stored outer when there is one.

 Part 12.4: the count handed to the hook is the one AFTER removal.
*>
fn void get_creates_then_reuses() @test
{
    TestHooks h;
    Pool* p = new_pool(&h);
    defer { p.close(); p.release(); }

    Slot s;
    if (catch p.get(Holder::typeid, AVAILABLE_OR_NEW, &s)) { always_assert(false, "get failed"); }
    always_assert(s.is_full(), "get did not fill the Slot");
    always_assert(h.gets.load() == 1, "the get hook did not run");
    always_assert(h.last_get_count.load() == 0, "the count handed to on_get is wrong");

    Holder* first = mtk::helper::must_from_slot(&s, Holder);

    p.put(&s);
    always_assert(s.is_empty(), "put did not clear the Slot");
    always_assert(h.puts.load() == 1, "the put hook did not run");
    always_assert(p.count_of(Holder::typeid) == 1, "the outer was not kept");

    if (catch p.get(Holder::typeid, AVAILABLE_OR_NEW, &s)) { always_assert(false, "the second get failed"); }
    always_assert(h.gets.load() == 1, "the second get called the hook instead of reusing");
    always_assert(mtk::helper::must_from_slot(&s, Holder) == first, "a different outer came back");

    p.put(&s);
}

<*
 Part 11.7: available-only never asks the hook, and reports NOT_AVAILABLE.

 Part 19.3: NOT_AVAILABLE comes only from this mode.
*>
fn void available_only_never_creates() @test
{
    TestHooks h;
    Pool* p = new_pool(&h);
    defer { p.close(); p.release(); }

    Slot s;
    always_assert(@catch_is(p.get(Holder::typeid, AVAILABLE_ONLY, &s), mtk::NOT_AVAILABLE),
                  "available-only did not report NOT_AVAILABLE on an empty pool");
    always_assert(h.gets.load() == 0, "available-only called the creation hook");
    always_assert(s.is_empty(), "a failed get filled the Slot");
}

<*
 Part 11.7: new-only always asks the hook, even when an outer is stored.
*>
fn void new_only_always_creates() @test
{
    TestHooks h;
    Pool* p = new_pool(&h);
    defer { p.close(); p.release(); }

    Slot a;
    if (catch p.get(Holder::typeid, AVAILABLE_OR_NEW, &a)) { always_assert(false, "get failed"); }
    p.put(&a);
    always_assert(p.count_of(Holder::typeid) == 1, "the outer was not stored");

    Slot b;
    if (catch p.get(Holder::typeid, NEW_ONLY, &b)) { always_assert(false, "new-only get failed"); }
    always_assert(h.gets.load() == 2, "new-only reused a stored outer");
    always_assert(p.count_of(Holder::typeid) == 1, "new-only consumed a stored outer");

    p.put(&b);
}

<*
 Part 12.2, Part 19.2: a hook that produces nothing becomes NOT_CREATED, and
 the Slot is left empty.
*>
fn void a_hook_that_creates_nothing() @test
{
    TestHooks h;
    h.refuse_to_create = true;
    Pool* p = new_pool(&h);
    defer { p.close(); p.release(); }

    Slot s;
    always_assert(@catch_is(p.get(Holder::typeid, AVAILABLE_OR_NEW, &s), mtk::NOT_CREATED),
                  "a hook that created nothing did not report NOT_CREATED");
    always_assert(h.gets.load() == 1, "the hook was not called");
    always_assert(s.is_empty(), "a failed get filled the Slot");
}

<*
 Part 12.2: on_put's four outcomes. This is the "released, nothing kept" one.
*>
fn void a_put_hook_may_release() @test
{
    TestHooks h;
    h.release_on_put = true;
    Pool* p = new_pool(&h);
    defer { p.close(); p.release(); }

    Slot s;
    if (catch p.get(Holder::typeid, AVAILABLE_OR_NEW, &s)) { always_assert(false, "get failed"); }
    p.put(&s);

    always_assert(s.is_empty(), "put did not clear the caller's Slot");
    always_assert(p.count_of(Holder::typeid) == 0, "the pool kept an outer the hook released");
}

<*
 Part 12.5 SHOULD: the extra list is the composite mechanism. Each outer in it
 is added the same way, with the same checks.

 Part 12.2: the pool does not check that the parts form a real composite, and
 does not tell composite from simple.
*>
fn void the_extra_list_on_put() @test
{
    TestHooks h;
    h.extras_on_put = 3;
    Pool* p = new_pool(&h);
    defer { p.close(); p.release(); }

    Slot s;
    if (catch p.get(Holder::typeid, AVAILABLE_OR_NEW, &s)) { always_assert(false, "get failed"); }
    p.put(&s);

    // the outer itself, kept, plus three parts
    always_assert(p.count_of(Holder::typeid) == 4, "the extra list was not taken");
}

<*
 Part 11.9 MUST, invariant 25 — **the waiting get never creates.**

 The ztk book says twice that it does. The ztk code says it does not, and the
 code is the truth. The hook counter is what makes this a test rather than a
 claim.

 Part 19.3: where available-only reports NOT_AVAILABLE, the waiting get reports
 TIMEOUT. The divergence is deliberate.
*>
fn void the_waiting_get_never_creates() @test
{
    TestHooks h;
    Pool* p = new_pool(&h);
    defer { p.close(); p.release(); }

    Slot s;
    always_assert(@catch_is(p.get_wait(Holder::typeid, &s, time::ms(60)), mtk::TIMEOUT),
                  "the waiting get did not time out on an empty pool");
    always_assert(h.gets.load() == 0, "Part 11.9: the waiting get called the creation hook");
    always_assert(s.is_empty(), "a timed-out get filled the Slot");
}

<*
 The waiting get takes a stored outer without waiting when one is there.
*>
fn void the_waiting_get_takes_a_stored_item() @test
{
    TestHooks h;
    Pool* p = new_pool(&h);
    defer { p.close(); p.release(); }

    Slot s;
    if (catch p.get(Holder::typeid, AVAILABLE_OR_NEW, &s)) { always_assert(false, "get failed"); }
    p.put(&s);

    Slot w;
    if (catch p.get_wait(Holder::typeid, &w, time::ms(60))) { always_assert(false, "the waiting get found nothing"); }
    always_assert(w.is_full(), "the waiting get did not fill the Slot");
    always_assert(h.gets.load() == 1, "the waiting get created something");
    p.put(&w);
}

<*
 Part 11.8 MUST, invariant 24 — **the pool's close gives NOTHING back to the
 caller.** Everything goes to the hook.

 This is the mirror image of the mailbox's close and the sharpest asymmetry in
 the toolkit, so the two are tested against each other rather than separately.
*>
fn void close_gives_nothing_back() @test
{
    TestHooks h;
    Pool* p = new_pool(&h);

    for (usz i = 0; i < 3; i++)
    {
        Slot s;
        if (catch p.get(Holder::typeid, NEW_ONLY, &s)) { always_assert(false, "get failed"); }
        p.put(&s);
    }
    always_assert(p.count_of(Holder::typeid) == 3, "the pool did not keep three");

    p.close();

    always_assert(h.closes.load() == 1, "the close hook did not run");
    always_assert(h.closed_with.load() == 3, "the close hook was not given everything");
    p.release();
}

<*
 Part 11.12: close is callable more than once, and **the second call does NOT
 run the close hook again.**
*>
fn void pool_close_is_idempotent() @test
{
    TestHooks h;
    Pool* p = new_pool(&h);

    p.close();
    p.close();
    p.close();

    always_assert(h.closes.load() == 1, "the close hook ran more than once");
    p.release();
}

<*
 Part 11.8: a closed pool refuses a put and leaves the Slot unchanged, so the
 caller still has the outer.

 That is the opposite of the mailbox, where a refused send also leaves the outer
 with the sender — the two agree here and disagree about close.
*>
fn void a_closed_pool_refuses_a_put() @test
{
    TestHooks h;
    Pool* p = new_pool(&h);

    Slot s;
    if (catch p.get(Holder::typeid, AVAILABLE_OR_NEW, &s)) { always_assert(false, "get failed"); }

    p.close();
    p.put(&s);

    always_assert(s.is_full(), "a closed pool took the outer anyway");
    always_assert(h.puts.load() == 0, "a closed pool ran the put hook");

    mtk::managed::release(Holder, &s);              // the caller still owns it, and says so
    p.release();
}

<*
 Part 19.2: a closed pool reports CLOSED from both gets.
*>
fn void a_closed_pool_refuses_a_get() @test
{
    TestHooks h;
    Pool* p = new_pool(&h);
    p.close();

    Slot s;
    always_assert(@catch_is(p.get(Holder::typeid, AVAILABLE_OR_NEW, &s), mtk::CLOSED), "a closed pool served a get");
    always_assert(@catch_is(p.get_wait(Holder::typeid, &s, time::ms(1)), mtk::CLOSED), "a closed pool served a waiting get");
    always_assert(s.is_empty(), "a refused get filled the Slot");

    // still a valid outer, Part 11.12
    always_assert(pool::of(pool::to_inner(p)) == p, "a closed pool stopped being an outer");
    p.release();
}

<*
 **R15: `Pool.put_all` is gone, and this is the test of what replaced it.**

 The call was `Pool.put` in a loop — no lock kept across iterations, the hook
 run once per outer, no batching and no atomicity — and it did not spare the
 caller the difficult case. It handed it back in a different shape: after it
 returned, the caller still held a partly emptied queue and still had to decide
 what became of the rest.

 So the caller writes the loop, `put_batch` above is that loop, and the refusal
 case is what this test exercises. A closed pool refuses every put, the Slot
 comes back full, and every one of the four outers must still be with the
 caller afterwards. The old contract's promise — *stops at the first refusal,
 and the caller reads the queue* — is now the caller's own code, and it still
 holds.

 The one behaviour that is deliberately NOT reproduced is Part 11.8's
 restored-order clause: the refused outer goes back at the BACK, because the
 queue has no front insert any more and no caller was ever entitled to the
 order. The clause and its warning leave the specification with `put_all`.
*>
fn void the_give_back_loop_stops_at_the_first_refusal() @test
{
    TestHooks h;
    Pool* p = new_pool(&h);

    InnerQueue outers;
    for (usz i = 0; i < 4; i++)
    {
        Slot s;
        if (catch p.get(Holder::typeid, NEW_ONLY, &s)) { always_assert(false, "get failed"); }
        outers.push_back_slot(&s);
    }
    always_assert(outers.len() == 4, "four outers were not gathered");

    p.close();                       // every put from here on is refused
    put_batch(p, &outers);

    always_assert(outers.len() == 4, "a closed pool took outers from the give-back loop");
    always_assert(h.puts.load() == 0, "a closed pool ran the put hook");

    // the caller still owns all four and releases them
    while (Inner* x = outers.pop_front())
    {
        Slot s;
        s.fill(x);
        mtk::managed::release(Holder, &s);
    }
    p.release();
}

<*
 The same loop on an OPEN pool takes everything and leaves the queue empty.
*>
fn void the_give_back_loop_takes_the_whole_queue() @test
{
    TestHooks h;
    Pool* p = new_pool(&h);
    defer { p.close(); p.release(); }

    InnerQueue outers;
    for (usz i = 0; i < 4; i++)
    {
        Slot s;
        if (catch p.get(Holder::typeid, NEW_ONLY, &s)) { always_assert(false, "get failed"); }
        outers.push_back_slot(&s);
    }

    put_batch(p, &outers);

    always_assert(outers.is_empty(), "the give-back loop left outers with the caller");
    always_assert(p.count_of(Holder::typeid) == 4, "the pool did not keep them");
    always_assert(h.puts.load() == 4, "the put hook did not run per outer");
}

<*
 Part 12.4 MUST, invariant 29: the count is a hint, and the two hooks are
 handed it from different sides.

 On get it is the count AFTER removal. On put it is the count BEFORE addition.
 A port that passes the same number to both has broken a MUST that no test
 other than this one would notice.
*>
fn void the_count_is_read_from_the_right_side() @test
{
    TestHooks h;
    Pool* p = new_pool(&h);
    defer { p.close(); p.release(); }

    // store two
    InnerQueue outers;
    for (usz i = 0; i < 2; i++)
    {
        Slot s;
        if (catch p.get(Holder::typeid, NEW_ONLY, &s)) { always_assert(false, "get failed"); }
        outers.push_back_slot(&s);
    }
    put_batch(p, &outers);
    always_assert(p.count_of(Holder::typeid) == 2, "two were not stored");
    always_assert(h.last_put_count.load() == 1, "on_put was given the count AFTER the addition");

    // a new-only get removes nothing, so the hook sees what is left: two
    Slot s;
    if (catch p.get(Holder::typeid, NEW_ONLY, &s)) { always_assert(false, "get failed"); }
    always_assert(h.last_get_count.load() == 2, "on_get was given the wrong count");
    p.put(&s);
}

<*
 Part 11.10: the pool promises nothing about which outer comes back. Put three,
 get three, and the only thing asserted is that three come back — because that
 is all the specification allows a test to assert.
*>
fn void no_sequence_guarantee() @test
{
    TestHooks h;
    Pool* p = new_pool(&h);
    defer { p.close(); p.release(); }

    InnerQueue outers;
    for (usz i = 0; i < 3; i++)
    {
        Slot s;
        if (catch p.get(Holder::typeid, NEW_ONLY, &s)) { always_assert(false, "get failed"); }
        outers.push_back_slot(&s);
    }
    put_batch(p, &outers);

    usz got = 0;
    for (usz i = 0; i < 3; i++)
    {
        Slot s;
        if (catch p.get(Holder::typeid, AVAILABLE_ONLY, &s)) break;
        got++;
        outers.push_back_slot(&s);
    }
    always_assert(got == 3, "three went in and three did not come out");
    put_batch(p, &outers);
}

<*
 **R11: the pool's storage is a stack, and reuse is last-in first-out.**

 Read what this asserts and what it does not. Part 11.10 MUST says the pool
 promises nothing about which outer comes back, Part 11.7 stays silent on order,
 and `no_sequence_guarantee` above is deliberately written to assert nothing
 about it. This test asserts the MECHANISM, not a promise: `PoolBucket.free` is
 an `InnerStack`, and the reason it is one is defect surfacing.

   Under first-in first-out the outer just given back goes to the back of the
   free list, so a caller still writing through a stale pointer collides with
   nobody for a long time and the damage appears far from its cause. Under
   last-in first-out the next get hands that same outer straight to a new owner
   and the collision happens next to the mistake.

 That argument is worth nothing if a later change quietly turns the bucket back
 into a queue, and nothing else in the suite would notice. This test would.

 It is the one place the suite reads the pool's order, and it is the reason no
 OTHER test may: what makes the property useful is that no caller is entitled
 to it.
*>
fn void reuse_is_last_in_first_out() @test
{
    TestHooks h;
    Pool* p = new_pool(&h);
    defer { p.close(); p.release(); }

    // three distinct outers, tagged so they can be told apart
    InnerQueue outers;
    for (usz i = 0; i < 3; i++)
    {
        Slot s;
        if (catch p.get(Holder::typeid, NEW_ONLY, &s)) { always_assert(false, "get failed"); }
        Holder* o = mtk::helper::must_from_slot(&s, Holder);
        o.id = (int)i;
        outers.push_back_slot(&s);
    }

    // given back in the order 0, 1, 2 — so 2 is on top
    put_batch(p, &outers);
    always_assert(p.count_of(Holder::typeid) == 3, "the pool did not keep three");

    for (usz i = 3; i > 0; i--)
    {
        Slot s;
        if (catch p.get(Holder::typeid, AVAILABLE_ONLY, &s)) { always_assert(false, "an available get failed"); }
        Holder* o = mtk::helper::must_from_slot(&s, Holder);
        always_assert(o.id == (int)(i - 1),
            "the pool did not hand back the most recently returned outer — the bucket is not a stack any more");
        outers.push_back_slot(&s);
    }

    put_batch(p, &outers);
}

<*
 **Invariant 34, pool side. Part 11.8:** a closed pool is empty.

 The close collects every bucket in one step under the mutex, and a put after
 the flag is set is refused, so there is no state in which the pool is closed
 and still holds something. That is what makes Part 19.2's outcome set a set
 rather than an ordering: a get on a closed pool never has to choose between
 returning an outer and reporting CLOSED, because there is never an outer to
 return.

 `close_gives_nothing_back` proves the hook receives the outers. This proves the
 other half — that the pool kept none of them.
*>
fn void a_closed_pool_is_empty() @test
{
    TestHooks h;
    Pool* p = new_pool(&h);

    // three outers in the pool, so the close has something real to drain
    for (usz i = 0; i < 3; i++)
    {
        Slot s;
        if (catch p.get(Holder::typeid, NEW_ONLY, &s)) { always_assert(false, "get failed"); }
        p.put(&s);
    }
    always_assert(p.count_of(Holder::typeid) == 3, "the pool did not keep three");

    p.close();

    // invariant 34: nothing is left behind
    always_assert(p.count_of(Holder::typeid) == 0, "a closed pool still holds outers");
    always_assert(h.closed_with.load() == 3, "the drain did not hand over everything");

    // and so the outcome is CLOSED rather than one of the three it used to hold
    Slot s;
    always_assert(@catch_is(p.get(Holder::typeid, AVAILABLE_ONLY, &s), mtk::CLOSED),
        "a closed pool answered a get with an outer");
    always_assert(s.is_empty(), "a refused get filled the Slot");

    p.release();
}

struct PoolLifetime
{
    Pool*       p;
    Atomic{usz} waiting;
    Atomic{usz} returned;
}

fn int parked_getter(void* arg)
{
    PoolLifetime* lf = (PoolLifetime*)arg;
    Slot got;
    lf.waiting.store(1, RELEASE);
    bool closed = @catch_is(lf.p.get_wait(Holder::typeid, &got, time::sec(30)), mtk::CLOSED);
    always_assert(closed, "the close did not wake the parked getter with CLOSED");
    always_assert(got.is_empty(), "a refused get filled the Slot");
    lf.returned.store(1, RELEASE);
    return 0;
}

<*
 **Part 11.12 — CLOSED, then QUIET, then FREED, with an assertion at each step.**

 The positive counterpart of the pool's four tier 1 negatives. Those programs
 prove the port stops when the rule is broken; this one proves what the caller
 is supposed to do instead, and runs it rather than reasoning about it.

 A worker parks in `get_wait`. The close publishes CLOSED and wakes it. The
 worker reports `CLOSED` and finishes. Only then is the pool quiet, and only
 then may it be released.

 `is_quiet()` reads the closed-and-active predicate itself, under the mutex —
 the public way to ask whether a tool is quiet, added by 3TK-58 for exactly
 this.
*>
fn void the_pool_closed_then_quiet_then_freed() @test
{
    TestHooks h;
    Pool* p = new_pool(&h);

    PoolLifetime lf;
    lf.p = p;

    Thread worker;
    worker.create(&parked_getter, &lf)!!;

    while (lf.waiting.load(ACQUIRE) == 0) thread::sleep(time::ms(1))!!;
    thread::sleep(time::ms(50))!!;             // it is inside wait_until by now

    // CLOSED. The getter is woken, and it has NOT returned yet.
    p.close();
    always_assert(p.is_closed(), "the close did not close the pool");
    always_assert(h.closes.load() == 1, "the close hook did not run exactly once");

    // QUIET. This is the step the rule is about, and joining is how to get it.
    worker.join()!!;
    always_assert(lf.returned.load(ACQUIRE) == 1, "the getter did not return");
    always_assert(p.is_quiet(), "the pool is closed but not quiet after the join");

    // FREED.
    p.release();
}

<*
 **The ordinary correct shape on the pool: close, then join, then release.**

 Three workers, each getting an outer and giving it back, twice. They are joined
 first, so every `get` and every `put` — hooks included — has returned before
 the close runs. The close hands everything the pool still held to `on_close`,
 which frees it. Then, and only then, the pool is quiet and can be freed.

 The pool's close gives nothing back to the caller, so unlike the mailbox's
 shape there is no queue to drain here. What the caller owes is the join.
*>
fn void the_pool_close_then_join_then_release() @test
{
    TestHooks h;
    Pool* p = new_pool(&h);

    PoolLifetime[3] work;
    Thread[3]   workers;
    foreach (usz i, &t : workers)
    {
        work[i].p = p;
        t.create(&borrower, &work[i])!!;
    }
    foreach (&t : workers) t.join()!!;

    // every call has returned, and the pool is still open. There is no
    // black-box way to check the active count alone while still open —
    // `is_quiet()` requires closed too — so this step trusts the join and
    // moves straight to close.
    always_assert(!p.is_closed(), "the workers closed the pool");

    p.close();
    always_assert(p.is_quiet(), "the close left the pool active after it returned");

    p.release();
}

fn int borrower(void* arg)
{
    PoolLifetime* lf = (PoolLifetime*)arg;
    for (usz i = 0; i < 2; i++)
    {
        Slot s;
        if (catch lf.p.get(Holder::typeid, AVAILABLE_OR_NEW, &s)) { always_assert(false, "get failed"); }
        lf.p.put(&s);
        always_assert(s.is_empty(), "an open pool refused a put");
    }
    lf.returned.store(1, RELEASE);
    return 0;
}
