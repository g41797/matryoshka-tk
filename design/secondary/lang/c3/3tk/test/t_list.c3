<*
 Part 8 — the intrusive list.

 Part 18 invariants 13, 14, 15, 16, 17.

 The two insert checks abort in a checking build, so they are proved by the
 negative programs under `negative/`. What is testable from inside a passing
 test is the SHAPE of the blind spot — Part 8.7 MUST — and that is here.
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
 Part 8.1: insert and remove are O(1) and the list allocates nothing.

 The allocation half is structural — nothing in list.c3 takes an allocator —
 so what is tested is that eight items thread on and come off in order.
*>
fn void the_list_is_a_queue() @test
{
    Msg[8] ms = fresh_msgs();
    NodeList list;

    for (usz i = 0; i < 8; i++) { msg_init(&ms[i]); list.push_back(msg_to_any(&ms[i])); }
    always_assert(list.len() == 8, "eight went in and the count disagrees");

    for (usz i = 0; i < 8; i++)
    {
        Msg* m = msg_from_any(list.pop_front());
        always_assert(m != null, "an item came off as the wrong type");
        always_assert(m.id == (int)i, "the list is not first-in first-out");
    }
    always_assert(list.is_empty(), "the list is not empty after eight pops");
    always_assert(list.len() == 0, "the count did not reach zero");
}

<*
 Part 8.2: push_front, pop_back, front and back.

 front and back do not remove, which is the clause worth a line of its own.
*>
fn void the_ends_of_the_list() @test
{
    Msg[8] ms = fresh_msgs();
    NodeList list;
    for (usz i = 0; i < 3; i++) { msg_init(&ms[i]); }

    list.push_back(msg_to_any(&ms[1]));
    list.push_front(msg_to_any(&ms[0]));
    list.push_back(msg_to_any(&ms[2]));

    always_assert(list.front() == msg_to_any(&ms[0]), "front is wrong");
    always_assert(list.back() == msg_to_any(&ms[2]), "back is wrong");
    always_assert(list.len() == 3, "front or back removed something");

    always_assert(msg_from_any(list.pop_back()).id == 2, "pop_back took the wrong end");
    always_assert(msg_from_any(list.pop_front()).id == 0, "pop_front took the wrong end");
    always_assert(list.len() == 1, "the count is wrong after two pops");
}

<*
 Part 8.2: an empty list answers, and does not fail.

 Part 19.4: there is no outcome to report and no error type. Null IS the
 answer, and a port that made this a fault would have added an error set the
 specification says does not exist.
*>
fn void an_empty_list_answers() @test
{
    NodeList list;
    always_assert(list.pop_front() == null, "pop_front on an empty list");
    always_assert(list.pop_back() == null, "pop_back on an empty list");
    always_assert(list.front() == null, "front on an empty list");
    always_assert(list.back() == null, "back on an empty list");
    always_assert(list.is_empty(), "an empty list says it is not empty");
}

<*
 Part 8.2: insert after and insert before a named item, including at both ends
 where the head and tail pointers have to move.
*>
fn void insert_in_the_middle() @test
{
    Msg[8] ms = fresh_msgs();
    NodeList list;
    for (usz i = 0; i < 4; i++) { msg_init(&ms[i]); }

    list.push_back(msg_to_any(&ms[0]));
    list.insert_after(msg_to_any(&ms[0]), msg_to_any(&ms[2]));
    list.insert_after(msg_to_any(&ms[0]), msg_to_any(&ms[1]));
    list.insert_before(msg_to_any(&ms[0]), msg_to_any(&ms[3]));

    always_assert(list.len() == 4, "the count is wrong");
    always_assert(msg_from_any(list.pop_front()).id == 3, "insert_before did not move the head");
    always_assert(msg_from_any(list.pop_front()).id == 0, "order after insert_before");
    always_assert(msg_from_any(list.pop_front()).id == 1, "insert_after put the item in the wrong place");
    always_assert(msg_from_any(list.pop_front()).id == 2, "insert_after did not move the tail");
}

<*
 Part 8.2: remove a named item from the middle, and from both ends.
*>
fn void remove_from_anywhere() @test
{
    Msg[8] ms = fresh_msgs();
    NodeList list;
    for (usz i = 0; i < 3; i++) { msg_init(&ms[i]); list.push_back(msg_to_any(&ms[i])); }

    list.remove(msg_to_any(&ms[1]));
    always_assert(list.len() == 2, "remove did not reduce the count");
    always_assert(list.front() == msg_to_any(&ms[0]), "remove moved the head");
    always_assert(list.back() == msg_to_any(&ms[2]), "remove moved the tail");

    list.remove(msg_to_any(&ms[0]));
    list.remove(msg_to_any(&ms[2]));
    always_assert(list.is_empty(), "the list is not empty after removing all three");
    always_assert(list.front() == null && list.back() == null, "the header was not cleared");
}

<*
 Part 8.8: the repair. After a removal the item's links are cleared, so it
 passes the link test and can be inserted again.

 Every removal in the surface does this for the caller — so the test walks all
 three removers, not one. Invariant 17.
*>
fn void every_removal_repairs() @test
{
    Msg[8] ms = fresh_msgs();
    NodeList list;
    for (usz i = 0; i < 3; i++) { msg_init(&ms[i]); list.push_back(msg_to_any(&ms[i])); }

    AnyHandle a = list.pop_front();
    AnyHandle b = list.pop_back();
    AnyHandle c = msg_to_any(&ms[1]);
    list.remove(c);

    always_assert(!mtk::is_linked(a), "pop_front left the links set");
    always_assert(!mtk::is_linked(b), "pop_back left the links set");
    always_assert(!mtk::is_linked(c), "remove left the links set");

    // and a repaired item can be inserted again, which is the point of the repair
    list.push_back(a);
    list.push_back(b);
    list.push_back(c);
    always_assert(list.len() == 3, "a repaired item was refused");
}

<*
 Part 8.7 MUST — the link test is NOT a membership test, and this is its blind
 spot, tested rather than merely documented.

 An item alone on a list has no neighbours and reports false. So the link test
 cannot tell "alone on a list" from "on no list at all", and the walk of Part
 8.6 is what covers the difference.

 D12 accepted this. A test that fails when someone "fixes" the link test into a
 membership test is the honest way to record an accepted cost. Invariant 16.
*>
fn void the_link_test_has_a_blind_spot() @test
{
    Msg m;
    msg_init(&m);
    NodeList list;
    list.push_back(msg_to_any(&m));

    always_assert(list.len() == 1, "the list should hold exactly one item");
    always_assert(!mtk::is_linked(msg_to_any(&m)), "Part 8.7: the blind spot is gone, and D12 needs revisiting");
    always_assert(list.contains(msg_to_any(&m)), "the walk cannot see what the link test cannot");
}

<*
 The other half of Part 8.6's argument: the link test sees a DIFFERENT list,
 which the walk cannot.

 Two items on list A. Neither is on list B. The walk of B says nothing about
 them; the link test does.
*>
fn void the_walk_has_a_blind_spot_too() @test
{
    Msg[8] ms = fresh_msgs();
    NodeList a;
    NodeList b;
    for (usz i = 0; i < 2; i++) { msg_init(&ms[i]); a.push_back(msg_to_any(&ms[i])); }

    always_assert(!b.contains(msg_to_any(&ms[0])), "the walk of B found an item of A");
    always_assert(mtk::is_linked(msg_to_any(&ms[0])), "the link test missed an item on another list");
}

<*
 Part 8.4: the walk. It yields handles until exhausted, and it does not remove.
*>
fn void the_walk_yields_every_handle() @test
{
    Msg[8] ms = fresh_msgs();
    NodeList list;
    for (usz i = 0; i < 5; i++) { msg_init(&ms[i]); list.push_back(msg_to_any(&ms[i])); }

    usz seen = 0;
    NodeListIterator it = list.iter();
    for (AnyHandle h = it.next(); h; h = it.next())
    {
        always_assert(msg_from_any(h).id == (int)seen, "the walk is out of order");
        seen++;
    }
    always_assert(seen == 5, "the walk did not reach every item");
    always_assert(list.len() == 5, "the walk removed something");
    always_assert(it.next() == null, "an exhausted walker yielded again");
}

<*
 A walk over an empty list yields nothing and does not fault.
*>
fn void the_walk_of_an_empty_list() @test
{
    NodeList list;
    NodeListIterator it = list.iter();
    always_assert(it.next() == null, "an empty list yielded a handle");
}

<*
 Part 8.2: move every item of another list onto this one, leaving that one
 empty. O(1), and the count moves with the items.
*>
fn void append_list_drains_the_other() @test
{
    Msg[8] ms = fresh_msgs();
    NodeList a;
    NodeList b;
    for (usz i = 0; i < 3; i++) { msg_init(&ms[i]); a.push_back(msg_to_any(&ms[i])); }
    for (usz i = 3; i < 6; i++) { msg_init(&ms[i]); b.push_back(msg_to_any(&ms[i])); }

    a.append_list(&b);

    always_assert(a.len() == 6, "the counts did not add up");
    always_assert(b.is_empty() && b.len() == 0, "the drained list is not empty");
    always_assert(b.front() == null && b.back() == null, "the drained header was not cleared");

    for (usz i = 0; i < 6; i++)
    {
        always_assert(msg_from_any(a.pop_front()).id == (int)i, "append_list scrambled the order");
    }
}

<*
 append_list onto an empty list, and from an empty list. Both ends of the
 head/tail juggling, which is where an intrusive splice usually breaks.
*>
fn void append_list_at_the_edges() @test
{
    Msg[8] ms = fresh_msgs();
    NodeList a;
    NodeList b;
    for (usz i = 0; i < 2; i++) { msg_init(&ms[i]); b.push_back(msg_to_any(&ms[i])); }

    a.append_list(&b);                      // onto an empty list
    always_assert(a.len() == 2, "append onto an empty list lost items");
    always_assert(a.front() == msg_to_any(&ms[0]), "append onto empty did not set the head");
    always_assert(a.back() == msg_to_any(&ms[1]), "append onto empty did not set the tail");

    a.append_list(&b);                      // from an empty list
    always_assert(a.len() == 2, "append from an empty list changed the count");
}

<*
 Part 8.9: moving a list onto itself is refused TWICE — an assert and an early
 return.

 The assert is tier 2 and compiles out. The early return is ordinary code and
 does not. This test exercises the early return, and it is the reason the pair
 exists: without it the naive move rings the items into a cycle and clears the
 header, losing every one.

 In a checking build the tier 2 assert fires first, so this case is proved
 there by `negative/self_move.c3`. Here the test asserts the SURVIVAL of the
 list, which is what the early return is for.
*>
fn void self_move_does_not_destroy_the_list() @test
{
    $if !mtk::CHECKED:
        Msg[8] ms = fresh_msgs();
        NodeList a;
        for (usz i = 0; i < 3; i++) { msg_init(&ms[i]); a.push_back(msg_to_any(&ms[i])); }

        a.append_list(&a);

        always_assert(a.len() == 3, "the self-move changed the count");
        for (usz i = 0; i < 3; i++)
        {
            always_assert(msg_from_any(a.pop_front()).id == (int)i, "the self-move lost or scrambled an item");
        }
    $endif
}

<*
 Part 8.1 and 8.3: the list is heterogeneous and speaks in handles.

 Three outer types of three different shapes, with the inner at two different
 offsets, on one list. Nothing in list.c3 knows any of their names.

 Invariants 13 and 14.
*>
fn void one_list_three_types() @test
{
    Msg  m; Job  j; Twin t;
    msg_init(&m); job_init(&j); twin_init(&t);

    NodeList list;
    list.push_back(msg_to_any(&m));
    list.push_back(job_to_any(&j));
    list.push_back(twin_to_any(&t));

    always_assert(list.len() == 3, "three types did not fit on one list");
    always_assert(msg_from_any(list.pop_front()) == &m, "the Msg came back wrong");
    always_assert(job_from_any(list.pop_front()) == &j, "the Job came back wrong");
    always_assert(twin_from_any(list.pop_front()) == &t, "the Twin came back wrong");
}

<*
 Part 8.2: adding from a Slot, at both ends. Part 9.2 rule 5 on both.
*>
fn void push_from_a_slot_at_both_ends() @test
{
    Msg a; Msg b;
    msg_init(&a); msg_init(&b);
    a.id = 1;
    b.id = 2;

    NodeList list;
    Slot s;

    s.fill(msg_to_any(&a));
    list.push_back_slot(&s);
    always_assert(s.is_empty(), "push_back_slot did not clear the Slot");

    s.fill(msg_to_any(&b));
    list.push_front_slot(&s);
    always_assert(s.is_empty(), "push_front_slot did not clear the Slot");

    always_assert(msg_from_any(list.pop_front()).id == 2, "push_front_slot went to the wrong end");
    always_assert(msg_from_any(list.pop_front()).id == 1, "push_back_slot went to the wrong end");
}
