<*
 Part 13 and Part 7.3 — the owning helper, and D3.

 The decision under test: an application item that wants a release with no
 allocator parameter keeps the allocator in its OWN outer, and the inner stays
 two fields wide for every item in the program.
*>
module mtk_test;
import mtk;
import std::core::mem::alloc;

<*
 Part 13.1's sharp clause: no release call takes an allocator as a parameter.

 That is a signature-level fact, so the test is that the round trip compiles
 and runs with the allocator named exactly once.
*>
fn void create_and_release_name_the_allocator_once() @test
{
    Slot s;
    if (catch owned_create(mem, &s)) { always_assert(false, "create failed on the thread allocator"); }

    always_assert(s.is_full(), "create did not fill the Slot");

    Owned* o = mtk::helper::must_from_slot{Owned}(&s);
    o.id = 42;
    always_assert(o.alloc == mem, "the item did not keep the allocator it was created with");

    owned_release(&s);
    always_assert(s.is_empty(), "release did not clear the Slot");
}

<*
 Part 9.8: creation is an acquisition. It fills a Slot and does not return a
 pointer, so it obeys rules 3 and 4 like every other acquisition.
*>
fn void creation_is_slot_shaped() @test
{
    Slot s;
    defer owned_release(&s);

    if (catch owned_create(mem, &s)) { always_assert(false, "create failed"); }

    // the caller's next line moves the item out of the Slot into a typed pointer
    Owned* o = mtk::helper::from_slot{Owned}(&s);
    always_assert(o != null, "the created item is not of its own type");
    always_assert(mtk::helper::is_mine{Owned}(s.peek()), "create did not write the identity");
}

<*
 The created item is a full Matryoshka item: it threads onto a list and comes
 back off through the border, like any other.
*>
fn void an_owned_item_is_an_ordinary_item() @test
{
    Slot s;
    if (catch owned_create(mem, &s)) { always_assert(false, "create failed"); }

    Owned* o = mtk::helper::must_from_slot{Owned}(&s);
    o.id = 7;

    InnerQueue list;
    list.push_back_slot(&s);
    always_assert(s.is_empty(), "the transfer did not clear the Slot");

    s.fill(list.pop_front());
    Owned* back = mtk::helper::must_from_slot{Owned}(&s);
    always_assert(back == o, "the item came back as a different address");
    always_assert(back.id == 7, "the item came back with different contents");

    owned_release(&s);
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
        if (catch owned_create(mem, &s)) { always_assert(false, "create failed"); }
        Owned* o = mtk::helper::must_from_slot{Owned}(&s);
        o.id = (int)i;
        owned_release(&s);
        always_assert(s.is_empty(), "release did not clear the Slot");
    }
}

<*
 D3's second part, as a size check: the inner did not grow an allocator field.

 Owned pays for its allocator in its own struct. Msg, which took the plain
 helper, pays nothing — and that is the whole of the decision.
*>
fn void only_the_owning_type_pays() @test
{
    always_assert(Inner::size == uptr::size + typeid::size, "the inner grew a field; D3 part 2 is broken");
    always_assert(Owned::size > Msg::size - 8, "sanity: Owned carries the allocator, Msg does not");
    always_assert(mtk::helper::OFF{Owned} == 8, "Owned's inner moved");
}
