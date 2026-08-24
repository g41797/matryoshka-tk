<*
 Part 9 — the Slot idiom, and its six rules as six.

 Part 18 invariants 18, 19, 20.

 Three of the six are contract violations: they abort in a checking build and
 cannot be provoked from inside a test that is meant to pass. Those are proved
 by the negative programs under `negative/`, which the build script runs and
 expects to abort. Named at each rule below.
*>
module mtk_test;
import mtk;

<*
 Rule 2: a Slot starts empty.

 The language's default state, which is why there is no initializer to forget.
*>
fn void rule2_a_slot_starts_empty() @test
{
    Slot s;
    always_assert(s.is_empty(), "Part 9.2 rule 2: a Slot did not start empty");
    always_assert(!s.is_full(), "is_full disagrees with is_empty");
    always_assert(s.peek() == null, "an empty Slot yielded a handle");
}

<*
 Rule 5: a transfer clears the Slot.

 And Part 9.4: the Slot, not the outcome, says where the item went.
*>
fn void rule5_a_transfer_clears_the_slot() @test
{
    Msg m;
    mtk::helper::init(&m);

    Slot s;
    s.fill(mtk::helper::to_handle(&m));
    always_assert(s.is_full(), "fill left the Slot empty");

    InnerQueue list;
    list.push_back_slot(&s);

    always_assert(s.is_empty(), "Part 9.2 rule 5: the transfer did not clear the Slot");
    always_assert(list.len() == 1, "the item did not arrive");
}

<*
 Rule 6: a release is a no-op on an empty Slot.

 This is what makes Part 9.7 legal — the cleanup is registered BEFORE the
 acquisition, and runs harmlessly when the acquisition never happened.
*>
fn void rule6_release_is_a_noop_on_empty() @test
{
    Slot s;
    mtk::managed::release(Holder, &s);
    mtk::managed::release(Holder, &s);
    always_assert(s.is_empty(), "a release on an empty Slot did something");
}

<*
 Rule 4, on the moving crossing: a failing acquisition leaves the Slot
 unchanged.

 This is the member of Part 7.2 with two postconditions, and both are here.
 The mismatch half is the one a port is most likely to get half right.
*>
fn void rule4_a_failed_move_leaves_the_slot_untouched() @test
{
    Twin t;
    mtk::helper::init(&t);

    Slot s;
    s.fill(mtk::helper::to_handle(&t));

    always_assert(mtk::helper::move_from_slot(&s, Msg) == null, "a Twin was moved out as a Msg");
    always_assert(s.is_full(), "Part 9.2 rule 4: a failed move emptied the Slot");
    always_assert(s.peek() == mtk::helper::to_handle(&t), "a failed move changed the Slot's contents");
}

<*
 The other half of the moving crossing: on a match, the pointer comes out AND
 the Slot is cleared. Part 7.2.
*>
fn void a_matching_move_returns_and_clears() @test
{
    Msg m;
    mtk::helper::init(&m);

    Slot s;
    s.fill(mtk::helper::to_handle(&m));

    always_assert(mtk::helper::move_from_slot(&s, Msg) == &m, "the move did not return the item");
    always_assert(s.is_empty(), "the move did not clear the Slot");
}

<*
 The looking crossings do not move anything. Part 7.2.

 A Slot read with `from_slot` is a look, not a take, and the difference is the
 whole reason `move_from_slot` is a separate member.
*>
fn void a_look_is_not_a_take() @test
{
    Msg m;
    mtk::helper::init(&m);

    Slot s;
    s.fill(mtk::helper::to_handle(&m));

    always_assert(mtk::helper::from_slot(&s, Msg) == &m, "from_slot did not find the item");
    always_assert(s.is_full(), "from_slot emptied the Slot");
    always_assert(mtk::helper::from_slot(&s, Msg) == &m, "from_slot is not repeatable");
    always_assert(s.is_full(), "from_slot emptied the Slot on the second read");
}

<*
 `take` clears; `peek` does not. The two halves of the reading shape a distinct
 Slot costs, and Part 9.9 said it would.
*>
fn void peek_and_take_differ() @test
{
    Job j;
    mtk::helper::init(&j);

    Slot s;
    s.fill(mtk::helper::to_handle(&j));

    always_assert(s.peek() == mtk::helper::to_handle(&j), "peek found the wrong handle");
    always_assert(s.is_full(), "peek emptied the Slot");
    always_assert(s.take() == mtk::helper::to_handle(&j), "take returned the wrong handle");
    always_assert(s.is_empty(), "take did not clear the Slot");
    always_assert(s.take() == null, "take on an empty Slot invented a handle");
}

<*
 Part 9.6: one place at a time.

 An item moves Slot to list to Slot and is never in two places. The count and
 the Slot's state are read at every step, because between them they are the
 whole invariant.

 Invariant 20.
*>
fn void one_place_at_a_time() @test
{
    Msg m;
    mtk::helper::init(&m);

    Slot a;
    Slot b;
    InnerQueue list;

    a.fill(mtk::helper::to_handle(&m));
    always_assert(a.is_full() && b.is_empty() && list.is_empty(), "start state");

    list.push_back_slot(&a);
    always_assert(a.is_empty() && b.is_empty() && list.len() == 1, "after the send");

    b.fill(list.pop_front());
    always_assert(a.is_empty() && b.is_full() && list.is_empty(), "after the receive");

    always_assert(mtk::helper::move_from_slot(&b, Msg) == &m, "the item came back changed");
    always_assert(b.is_empty(), "the claim did not clear the Slot");
}

<*
 Part 9.7's shape, end to end: the cleanup is registered before the
 acquisition, and every path out of the function releases the item.

 The path taken here is the one the author did not think about — an early
 return between the acquisition and the end.
*>
fn void cleanup_registered_before_acquisition() @test
{
    always_assert(@acquire_and_leave_early() == 1, "the early path did not run");
    always_assert(@acquire_and_leave_early() == 1, "the second call saw a leak of the first");
}

macro int @acquire_and_leave_early()
{
    Slot slot;
    defer mtk::managed::release(Holder, &slot);

    if (catch mtk::managed::create(Holder, mem, &slot)) return 0;
    always_assert(slot.is_full(), "create did not fill the Slot");

    return 1;
}
