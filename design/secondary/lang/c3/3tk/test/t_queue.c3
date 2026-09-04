<*
 Part 8 — the intrusive queue.

 Part 18 invariants 13, 14, 15, 17, 20, and the new self-link invariant that
 replaced retired 16.

 **This file replaces half of `t_list.c3`.** Seven of that file's fifteen tests
 exercised operations R2 and R15 deleted — `push_front`, `pop_back`, `front`,
 `back`, `insert_after`, `insert_before`, `remove`, `contains`,
 `push_front_slot` — and are gone rather than adjusted. The two blind-spot
 tests did not survive either, and they did not merely go: they **inverted**.
 What used to assert that the link test misses an item alone on a list now
 asserts that it sees it.

 The insert check aborts in a checking build, so it is proved by the negative
 programs under `negative/`.
*>
module mtk_test;
import mtk;

fn Msg[8] fresh_msgs()
{
    Msg[8] ms;
    for (usz i = 0; i < 8; i++) { ms[i].id = (int)i; }
    return ms;
}

<*
 Part 8.1: insert and take are O(1) and the queue allocates nothing.

 The allocation half is structural — nothing in `queue.c3` takes an allocator —
 so what is tested is that eight items thread on and come off in order.
*>
fn void the_queue_is_first_in_first_out() @test
{
    Msg[8] ms = fresh_msgs();
    InnerQueue q;

    for (usz i = 0; i < 8; i++) { mtk::helper::init(&ms[i]); q.push_back(mtk::helper::to_handle(&ms[i])); }
    always_assert(q.len() == 8, "eight went in and the count disagrees");

    for (usz i = 0; i < 8; i++)
    {
        Msg* m = mtk::helper::from_handle(q.pop_front(), Msg);
        always_assert(m != null, "an item came off as the wrong type");
        always_assert(m.id == (int)i, "the queue is not first-in first-out");
    }
    always_assert(q.is_empty(), "the queue is not empty after eight pops");
    always_assert(q.len() == 0, "the count did not reach zero");
}

<*
 Part 8.2: an empty queue answers, and does not fail.

 Part 19.4: there is no outcome to report and no error type. Null IS the
 answer, and a port that made this a fault would have added an error set the
 specification says does not exist.
*>
fn void an_empty_queue_answers() @test
{
    InnerQueue q;
    always_assert(q.pop_front() == null, "pop_front on an empty queue");
    always_assert(q.is_empty(), "an empty queue says it is not empty");
    always_assert(q.len() == 0, "an empty queue has a length");
}

<*
 The self-link invariant, read from the outside — R6b, and the row that took
 retired 16's place in Part 18.

 An item on a chain has a non-null `link`; the last item points at itself. An
 item on no chain has `link == null`. Everything else in this file rests on it,
 so it is asserted directly, on the sole item of a queue, where the old design
 was blind.
*>
fn void the_last_item_points_at_itself() @test
{
    Msg m;
    mtk::helper::init(&m);
    Inner* h = mtk::helper::to_handle(&m);

    always_assert(h.points_to() == null, "a fresh item is not off-chain");

    InnerQueue q;
    q.push_back(h);
    always_assert(h.points_to() == h, "the sole item of a queue is not self-linked");

    q.pop_front();
    always_assert(h.points_to() == null, "the repair did not clear the link");
}

<*
 Part 8.7 — **the blind spot is gone, and this test is the inversion of the one
 that recorded it.**

 `t_list.c3` used to assert that an item ALONE on a list reports unlinked, and
 called it an accepted cost, D12. With the self-link the link test is exact:
 the sole item of a queue is self-linked and reports linked, with no field
 added and no walk run.

 A test that fails when someone "improves" the queue back into a null-terminated
 chain is the honest way to record what the redesign bought. It is the reason
 `contains` and the O(n) insert walk could be deleted outright.
*>
fn void the_link_test_is_exact() @test
{
    Msg m;
    mtk::helper::init(&m);
    InnerQueue q;
    q.push_back(mtk::helper::to_handle(&m));

    always_assert(q.len() == 1, "the queue should hold exactly one item");
    always_assert(mtk::inner::is_linked(mtk::helper::to_handle(&m)),
        "Part 8.7: an item alone on a queue reports unlinked — the self-link invariant is broken");
}

<*
 The other direction, and it is what the walk never could do: the link test
 sees an item on a DIFFERENT container.

 Two items on queue A. Neither is on queue B. There is no `contains` to ask any
 more, and there does not need to be — one exact check refuses an item on any
 chain at all, which is what let Part 8.6's pair collapse into one.
*>
fn void the_link_test_sees_another_container() @test
{
    Msg[8] ms = fresh_msgs();
    InnerQueue a;
    for (usz i = 0; i < 2; i++) { mtk::helper::init(&ms[i]); a.push_back(mtk::helper::to_handle(&ms[i])); }

    always_assert(mtk::inner::is_linked(mtk::helper::to_handle(&ms[0])), "the link test missed an item on another queue");
    always_assert(mtk::inner::is_linked(mtk::helper::to_handle(&ms[1])), "the link test missed the tail of another queue");
    always_assert(!mtk::inner::is_linked(mtk::helper::to_handle(&ms[2])), "the link test claimed an item on no queue");
}

<*
 Part 8.8: the repair. After a take the item's link is cleared, so it passes
 the link test and can be inserted again. Invariant 17.

 One remover now, not three — `pop_back` and `remove` are gone.
*>
fn void every_removal_repairs() @test
{
    Msg[8] ms = fresh_msgs();
    InnerQueue q;
    for (usz i = 0; i < 3; i++) { mtk::helper::init(&ms[i]); q.push_back(mtk::helper::to_handle(&ms[i])); }

    Inner* a = q.pop_front();
    Inner* b = q.pop_front();
    Inner* c = q.pop_front();

    always_assert(!mtk::inner::is_linked(a), "pop_front left the head's link set");
    always_assert(!mtk::inner::is_linked(b), "pop_front left a middle item's link set");
    always_assert(!mtk::inner::is_linked(c), "pop_front left the last item's self-link set");

    // and a repaired item can be inserted again, which is the point of the repair
    q.push_back(a);
    q.push_back(b);
    q.push_back(c);
    always_assert(q.len() == 3, "a repaired item was refused");
}

<*
 Part 8.4: the walk. It yields handles until exhausted, and it does not remove.

 The end test is `n.points_to() == n`, so a walker written for a null-terminated chain
 would not terminate here. Exhaustion is therefore part of the assertion and
 not an afterthought.
*>
fn void the_walk_yields_every_handle() @test
{
    Msg[8] ms = fresh_msgs();
    InnerQueue q;
    for (usz i = 0; i < 5; i++) { mtk::helper::init(&ms[i]); q.push_back(mtk::helper::to_handle(&ms[i])); }

    usz seen = 0;
    InnerQueueIterator it = q.iter();
    for (Inner* h = it.next(); h; h = it.next())
    {
        always_assert(mtk::helper::from_handle(h, Msg).id == (int)seen, "the walk is out of order");
        seen++;
        always_assert(seen <= 5, "the walk did not end at the self-linked tail");
    }
    always_assert(seen == 5, "the walk did not reach every item");
    always_assert(q.len() == 5, "the walk removed something");
    always_assert(it.next() == null, "an exhausted walker yielded again");
}

<*
 A walk over a queue of exactly one, which is where the self-link end test is
 the whole of the termination argument.
*>
fn void the_walk_of_one_item() @test
{
    Msg m;
    mtk::helper::init(&m);
    InnerQueue q;
    q.push_back(mtk::helper::to_handle(&m));

    InnerQueueIterator it = q.iter();
    always_assert(it.next() == mtk::helper::to_handle(&m), "the walk missed the only item");
    always_assert(it.next() == null, "the walk of one item did not end");
}

<*
 A walk over an empty queue yields nothing and does not fault.
*>
fn void the_walk_of_an_empty_queue() @test
{
    InnerQueue q;
    InnerQueueIterator it = q.iter();
    always_assert(it.next() == null, "an empty queue yielded a handle");
}

<*
 Part 8.2: move every item of another queue onto this one, leaving that one
 empty. O(1), and the count moves with the items.
*>
fn void append_queue_empties_the_other() @test
{
    Msg[8] ms = fresh_msgs();
    InnerQueue a;
    InnerQueue b;
    for (usz i = 0; i < 3; i++) { mtk::helper::init(&ms[i]); a.push_back(mtk::helper::to_handle(&ms[i])); }
    for (usz i = 3; i < 6; i++) { mtk::helper::init(&ms[i]); b.push_back(mtk::helper::to_handle(&ms[i])); }

    a.append_queue(&b);

    always_assert(a.len() == 6, "the counts did not add up");
    always_assert(b.is_empty() && b.len() == 0, "the emptied queue still reports items");

    for (usz i = 0; i < 6; i++)
    {
        always_assert(mtk::helper::from_handle(a.pop_front(), Msg).id == (int)i, "append_queue scrambled the order");
    }
}

<*
 Part 8.2: `take()` hands over everything and leaves the source empty.

 The by-value hand-off the pool's `on_close` relies on. Written where the
 other queue tests live, not in `t_pool.c3`, because nothing here is
 pool-specific.
*>
fn void take_empties_the_source() @test
{
    Msg[8] ms = fresh_msgs();
    InnerQueue a;
    for (usz i = 0; i < 3; i++) { mtk::helper::init(&ms[i]); a.push_back(mtk::helper::to_handle(&ms[i])); }

    InnerQueue b = a.take();

    always_assert(a.is_empty() && a.len() == 0, "take did not empty the source");
    always_assert(b.len() == 3, "take did not carry the count over");

    for (usz i = 0; i < 3; i++)
    {
        always_assert(mtk::helper::from_handle(b.pop_front(), Msg).id == (int)i, "take scrambled the order");
    }
}

<*
 The splice leaves the joined chain intact and still self-terminated.

 This is the one place a single link could quietly break: the old tail of `self`
 stops being self-linked, and the tail of `other` must stay so. A walk after the
 splice is what proves both, because a walk is what would hang if it did not.
*>
fn void append_queue_keeps_the_chain_walkable() @test
{
    Msg[8] ms = fresh_msgs();
    InnerQueue a;
    InnerQueue b;
    for (usz i = 0; i < 2; i++) { mtk::helper::init(&ms[i]); a.push_back(mtk::helper::to_handle(&ms[i])); }
    for (usz i = 2; i < 4; i++) { mtk::helper::init(&ms[i]); b.push_back(mtk::helper::to_handle(&ms[i])); }

    a.append_queue(&b);

    usz seen = 0;
    InnerQueueIterator it = a.iter();
    for (Inner* h = it.next(); h; h = it.next())
    {
        always_assert(mtk::helper::from_handle(h, Msg).id == (int)seen, "the spliced chain is out of order");
        seen++;
        always_assert(seen <= 4, "the spliced chain does not end");
    }
    always_assert(seen == 4, "the walk did not cross the splice");
}

<*
 append_queue onto an empty queue, and from an empty queue. Both ends of the
 head/tail juggling, which is where an intrusive splice usually breaks.
*>
fn void append_queue_at_the_edges() @test
{
    Msg[8] ms = fresh_msgs();
    InnerQueue a;
    InnerQueue b;
    for (usz i = 0; i < 2; i++) { mtk::helper::init(&ms[i]); b.push_back(mtk::helper::to_handle(&ms[i])); }

    a.append_queue(&b);                      // onto an empty queue
    always_assert(a.len() == 2, "append onto an empty queue lost items");

    a.append_queue(&b);                      // from an empty queue
    always_assert(a.len() == 2, "append from an empty queue changed the count");

    always_assert(mtk::helper::from_handle(a.pop_front(), Msg).id == 0, "append onto empty did not set the head");
    always_assert(mtk::helper::from_handle(a.pop_front(), Msg).id == 1, "append onto empty did not set the tail");
    always_assert(a.is_empty(), "the queue kept more than it was given");
}

<*
 Part 8.9: moving a queue onto itself is refused TWICE — an assert and an early
 return. The pair survives the redesign unchanged, narrowed to the queue.

 The assert is tier 2 and compiles out. The early return is ordinary code and
 does not. This test exercises the early return, and it is the reason the pair
 exists: without it the naive move rings the items into a cycle and clears the
 header, losing every one — which is identical with one link.

 In a checking build the tier 2 assert aborts first, so that case is proved
 there by `negative/self_move.c3`.
*>
fn void self_move_does_not_destroy_the_queue() @test
{
    $if !mtk::CHECKED:
        Msg[8] ms = fresh_msgs();
        InnerQueue a;
        for (usz i = 0; i < 3; i++) { mtk::helper::init(&ms[i]); a.push_back(mtk::helper::to_handle(&ms[i])); }

        a.append_queue(&a);

        always_assert(a.len() == 3, "the self-move changed the count");
        for (usz i = 0; i < 3; i++)
        {
            always_assert(mtk::helper::from_handle(a.pop_front(), Msg).id == (int)i, "the self-move lost or scrambled an item");
        }
    $endif
}

<*
 Part 8.1 and 8.3: the queue is heterogeneous and speaks in handles.

 Three outer types of three different shapes, with the inner at two different
 offsets, on one queue. Nothing in `queue.c3` knows any of their names.

 Invariants 13 and 14.
*>
fn void one_queue_three_types() @test
{
    Msg  m; Job  j; Twin t;
    mtk::helper::init(&m); mtk::helper::init(&j); mtk::helper::init(&t);

    InnerQueue q;
    q.push_back(mtk::helper::to_handle(&m));
    q.push_back(mtk::helper::to_handle(&j));
    q.push_back(mtk::helper::to_handle(&t));

    always_assert(q.len() == 3, "three types did not fit on one queue");
    always_assert(mtk::helper::from_handle(q.pop_front(), Msg) == &m, "the Msg came back wrong");
    always_assert(mtk::helper::from_handle(q.pop_front(), Job) == &j, "the Job came back wrong");
    always_assert(mtk::helper::from_handle(q.pop_front(), Twin) == &t, "the Twin came back wrong");
}

<*
 Part 8.2: adding from a Slot. Part 9.2 rule 5 — the transfer clears it.

 One end now, not two: `push_front_slot` went with `Pool.put_all`, R15, and it
 was that call's only caller.
*>
fn void push_back_from_a_slot() @test
{
    Msg a; Msg b;
    mtk::helper::init(&a); mtk::helper::init(&b);
    a.id = 1;
    b.id = 2;

    InnerQueue q;
    Slot s;

    s.fill(mtk::helper::to_handle(&a));
    q.push_back_slot(&s);
    always_assert(s.is_empty(), "push_back_slot did not clear the Slot");

    s.fill(mtk::helper::to_handle(&b));
    q.push_back_slot(&s);
    always_assert(s.is_empty(), "push_back_slot did not clear the Slot");

    always_assert(mtk::helper::from_handle(q.pop_front(), Msg).id == 1, "push_back_slot went to the wrong end");
    always_assert(mtk::helper::from_handle(q.pop_front(), Msg).id == 2, "push_back_slot went to the wrong end");
}
