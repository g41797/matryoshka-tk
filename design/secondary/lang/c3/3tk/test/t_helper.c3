<*
 Part 3 — `OuterHelper`, the one thing a user binds.

 The decision under test: an outer type costs one alias line, the allocator is
 passed to `create` and `release` rather than kept by the toolkit, and the two
 hooks are optional.

 This file replaced `t_managed.c3` in 3TK-64, when `mtk::managed` was deleted.
 Two of its tests are the positive halves of negative programs the same stage
 retired: an outer with no `Allocator` field, and one with two, are both
 ordinary outers now, and the proof that they are has to run rather than fail
 to compile.
*>
module mtk_test;

<*
 An outer with no `Allocator` field is an ordinary outer.

 This is `nocompile_managed_no_allocator` inverted. Until 3TK-64 the same
 shape was a compile error naming the type; the toolkit reads no field of an
 outer except the `Inner`, so there is nothing left for it to object to.
*>
fn void an_outer_needs_no_allocator_field() @test
{
    Slot s;
    if (catch MSG.create(mem, &s)) { always_assert(false, "create failed on an outer with no Allocator field"); }
    always_assert(s.is_full(), "create did not fill the Slot");
    always_assert(MSG.look(&s) != null, "the created outer is not of its own type");
    MSG.release(mem, &s);
    always_assert(s.is_empty(), "release did not clear the Slot");
}

<*
 An outer with two `Allocator` fields is the outer's own business.

 This is `nocompile_managed_two_allocators` inverted, and RT-12 said it should
 be allowed: an outer that wants two allocators — one for itself, one for what
 it hands out — may have them.
*>
fn void two_allocator_fields_are_the_outers_business() @test
{
    Slot s;
    if (catch TWO.create(mem, &s)) { always_assert(false, "create failed on an outer with two Allocator fields"); }
    Two* o = TWO.must_look(&s);
    always_assert(o.first == mem && o.second == mem, "the init hook did not set both allocators");
    TWO.release(mem, &s);
    always_assert(s.is_empty(), "release did not clear the Slot");
}

<*
 The allocator is named at the call, and the outer keeps it only if it says so.
*>
fn void create_and_release_take_the_allocator() @test
{
    Slot s;
    if (catch HOLDER.create(mem, &s)) { always_assert(false, "create failed on the thread allocator"); }

    always_assert(s.is_full(), "create did not fill the Slot");

    Holder* o = HOLDER.must_look(&s);
    o.id = 42;
    always_assert(o.alloc == mem, "Holder's own init hook did not keep the allocator");

    HOLDER.release(mem, &s);
    always_assert(s.is_empty(), "release did not clear the Slot");
}

<*
 Part 9.8: creation is an acquisition. It fills a Slot and does not return a
 pointer, so it obeys rules 3 and 4 like every other acquisition.
*>
fn void creation_is_slot_shaped() @test
{
    Slot s;
    defer HOLDER.release(mem, &s);

    if (catch HOLDER.create(mem, &s)) { always_assert(false, "create failed"); }

    // the caller's next line moves the outer out of the Slot into a typed pointer
    Holder* o = HOLDER.look(&s);
    always_assert(o != null, "the created outer is not of its own type");
    always_assert(s.peek().outer_tid() == Holder::typeid, "create did not write the identity");
}

<*
 A `defer release` registered BEFORE the create is correct and intended.

 `release` is a no-op on an empty Slot and returns `void`, so it needs no `!`,
 no `!!` and no cast at any of its call sites. Part 3.4.
*>
fn void release_is_a_no_op_on_an_empty_slot() @test
{
    Slot s;
    HOLDER.release(mem, &s);
    always_assert(s.is_empty(), "release on an empty Slot did something");
}

<*
 The created outer is a full Matryoshka outer: it threads onto a list and comes
 back off through the border, like any other.
*>
fn void a_created_outer_is_an_ordinary_outer() @test
{
    Slot s;
    if (catch HOLDER.create(mem, &s)) { always_assert(false, "create failed"); }

    Holder* o = HOLDER.must_look(&s);
    o.id = 7;

    InnerQueue list;
    list.push_back_slot(&s);
    always_assert(s.is_empty(), "the transfer did not clear the Slot");

    s.fill(list.pop_front());
    Holder* back = HOLDER.must_look(&s);
    always_assert(back == o, "the outer came back as a different address");
    always_assert(back.id == 7, "the outer came back with different contents");

    HOLDER.release(mem, &s);
    always_assert(s.is_empty(), "release did not clear the Slot");
}

<*
 Many round trips through create and release. A leak or a double free shows up
 under the test runner's allocator, not in an assertion here.
*>
fn void repeated_create_and_release() @test
{
    for (usz i = 0; i < 64; i++)
    {
        Slot s;
        if (catch HOLDER.create(mem, &s)) { always_assert(false, "create failed"); }
        Holder* o = HOLDER.must_look(&s);
        o.id = (int)i;
        HOLDER.release(mem, &s);
        always_assert(s.is_empty(), "release did not clear the Slot");
    }
}

<*
 A failing `init` hook frees the allocation, propagates the fault unchanged,
 and leaves the Slot untouched.

 It also leaves nothing stamped, which is why step 3 of `create` comes after
 the hook and not before it. Part 3.4.
*>
fn void a_failing_init_hook_propagates_and_frees() @test
{
    Slot s;
    fault f = @catch(PICKY.create(mem, &s));
    always_assert(f == PICKY_REFUSED, "the hook's own fault did not reach the caller");
    always_assert(s.is_empty(), "a failed create filled the Slot");
}

<*
 The `finish` hook runs on release, and it receives the allocator from the
 caller rather than reading one off the outer.

 3TK-74 renamed it from `destroy`: `destroy` is C3's own word for tearing a
 thing down, which is the one thing the hook must not do — `release` frees the
 outer after the hook returns.
*>
fn void the_finish_hook_runs_on_release() @test
{
    destroyed = 0;
    Slot s;
    if (catch NOISY.create(mem, &s)) { always_assert(false, "create failed"); }
    always_assert(destroyed == 0, "finish ran before release");
    NOISY.release(mem, &s);
    always_assert(destroyed == 1, "finish did not run exactly once");
}

<*
 An outer with nothing to set up declares both hooks with empty bodies, and
 that is how it says so out loud. 3TK-74, `B-1`.

 Before that stage the hooks were optional and `Job` declared neither. Absence
 was the ambiguity — it meant either this type needs none or you spelled the
 name wrong, and the toolkit could not tell them apart. The behaviour is
 unchanged and it is the behaviour this test still checks: the allocation is
 zeroed and that is the whole initialization. Part 2.2.
*>
fn void empty_hook_bodies_are_how_a_type_says_nothing_to_do() @test
{
    Slot s;
    if (catch JOB.create(mem, &s)) { always_assert(false, "create failed on an outer whose hooks are empty"); }
    Job* j = JOB.must_look(&s);
    always_assert(j.pri == 0, "alloc::new_try did not zero the allocation");
    JOB.release(mem, &s);
    always_assert(s.is_empty(), "release did not clear the Slot");
}

<*
 The stamp is idempotent, and it is safe on a LINKED inner.

 Part 5.1: writing the identity rebuilds the whole `any`, preserving
 `link.ptr`. The destructive edit differs by one sub-expression, so the test
 stamps an outer that is on a queue and then checks the queue still holds it.
*>
fn void the_stamp_is_idempotent_and_safe_on_a_linked_outer() @test
{
    Slot s;
    defer MSG.release(mem, &s);
    if (catch MSG.create(mem, &s)) { always_assert(false, "create failed"); }
    Msg* m = MSG.must_look(&s);

    MSG.stamp(m);
    MSG.stamp(m);
    always_assert(MSG.look(MSG.inner(m)) == m, "a repeated stamp broke the identity");

    InnerQueue q;
    q.push_back(MSG.inner(m));
    always_assert(MSG.linked(m), "the outer did not go onto the queue");

    MSG.stamp(m);                                   // the dangerous moment
    always_assert(MSG.linked(m), "the stamp unlinked a linked outer");
    always_assert(q.len() == 1, "the stamp emptied the queue");
    always_assert(MSG.look(q.pop_front()) == m, "the outer came back as something else");
}

<*
 The four crossings, on both argument types.

 `look` and `must_look` take a `Slot*` or an `Inner*`; `take` and `must_take`
 take a Slot and empty it. Part 3.2.
*>
fn void the_four_crossings() @test
{
    Slot s;
    defer MSG.release(mem, &s);
    if (catch MSG.create(mem, &s)) { always_assert(false, "create failed"); }
    Msg* m = MSG.must_look(&s);

    always_assert(MSG.look(&s) == m, "look on a Slot");
    always_assert(MSG.look(s.peek()) == m, "look on an Inner*");
    always_assert(MSG.must_look(&s) == m, "must_look on a Slot");
    always_assert(MSG.must_look(s.peek()) == m, "must_look on an Inner*");
    always_assert(s.is_full(), "a look emptied the Slot");

    always_assert(TWIN.look(&s) == null, "a mismatch is an answer, not a match");
    always_assert(TWIN.take(&s) == null, "a refused take returned something");
    always_assert(s.is_full(), "a refused take emptied the Slot");

    always_assert(MSG.take(&s) == m, "take on a Slot");
    always_assert(s.is_empty(), "take did not empty the Slot");

    s.fill(MSG.inner(m));
    always_assert(MSG.must_take(&s) == m, "must_take on a Slot");
    always_assert(s.is_empty(), "must_take did not empty the Slot");

    s.fill(MSG.inner(m));                           // back into the Slot the defer releases
}

<*
 `inner()` stamps on the way out, so an outer allocated by hand never has to
 be stamped separately. HR-5.
*>
fn void inner_stamps_on_the_way_out() @test
{
    // Not allocated through the helper, and the sentence above says why: the
    // subject is an outer the user made by hand, which `create` never sees.
    Job j;
    always_assert(JOB.inner(&j).outer_tid() == Job::typeid, "the crossing out did not stamp");
}

<*
 D3's second part, as a size check: the inner did not grow an allocator field.

 `Holder` pays for its allocator in its own struct because its own `init` hook
 puts it there. `Msg`, which declares no hook, pays nothing — and that is the
 whole of the decision.
*>
fn void only_the_outer_that_wants_one_pays() @test
{
    always_assert(Inner::size == uptr::size + typeid::size, "the inner grew a field; D3 part 2 is broken");
    always_assert(Holder::size > Msg::size - 8, "sanity: Holder carries the allocator, Msg does not");
    Slot s;
    defer HOLDER.release(mem, &s);
    if (catch HOLDER.create(mem, &s)) { always_assert(false, "create failed"); }
    Holder* probe = HOLDER.must_look(&s);
    always_assert((char*)HOLDER.inner(probe) - (char*)probe == 8, "Holder's inner moved");
}


import mtk;
import std::core::mem::alloc;
