<*
 Parts 4, 5 and 6 — the inner, the identity, and self-identification.

 Part 18 invariants 7, 8, 9, 10, 11, 12.
*>
module mtk_test;
import mtk;

<*
 Part 4.2: the inner has exactly two parts — **one link and the identity**.

 R5 deleted `prev` and R6 refused the membership field that would have taken
 its place, so the inner is two words rather than three: 16 bytes on
 linux-x64, down from 24. Every item in the program pays for this struct, and
 a word is added to it only with a reason written down.

 Since 3TK-21 the two parts live in ONE field — `Inner.link`, a C3 `any`,
 whose `ptr` is the linkage and whose `type` is the identity. The parts did
 not move and the 16 bytes did not move; only where they are stored did. That
 is why the assertions below read `.link.type` where they used to read
 `.type`.
*>
fn void inner_is_two_parts() @test
{
    always_assert(Inner::size == uptr::size + typeid::size, "the inner grew a field");
}

<*
 Part 4.3: the inner field may sit anywhere. Both ends, in one test.

 Invariant 7.
*>
fn void inner_at_any_offset() @test
{
    always_assert(mtk::inner::inner_offset(Msg) != 0, "Msg's inner should not be at offset zero");
    always_assert(mtk::inner::inner_offset(Job) == 0, "Job's inner should be at offset zero");

    Msg m;
    Job j;
    mtk::helper::init(&m);
    mtk::helper::init(&j);

    always_assert(mtk::helper::to_handle(&m) == (Inner*)&m.node, "Msg: to_handle is not the inner");
    always_assert(mtk::helper::to_handle(&j) == (Inner*)&j.node, "Job: to_handle is not the inner");
    always_assert(mtk::helper::from_handle(mtk::helper::to_handle(&m), Msg) == &m, "Msg: the round trip lost the outer");
    always_assert(mtk::helper::from_handle(mtk::helper::to_handle(&j), Job) == &j, "Job: the round trip lost the outer");
}

<*
 Part 5.1, every clause. The one that matters is the third:

   Two items of different outer types never carry the same identity.

 Msg and Twin have identical layouts. ztk needed a mutable byte per type to
 stop the linker merging two identical constants; C3's typeid needs nothing.

 Invariant 9.
*>
fn void identity_is_per_type() @test
{
    Msg  a;
    Msg  b;
    Twin t;
    mtk::helper::init(&a);
    mtk::helper::init(&b);
    mtk::helper::init(&t);

    always_assert(Msg::size == Twin::size, "the test types are no longer twins");
    always_assert(Msg::typeid != Twin::typeid, "Part 5.1: two identically-shaped types share an identity");
    always_assert(a.node.link.type == b.node.link.type, "Part 5.1: two items of one type differ");
    always_assert(a.node.link.type == Msg::typeid, "Part 5.4: the identity is not the stored one");
}

<*
 Part 5.4: stored, not computed. The walker reads a field.

 Invariant 10.
*>
fn void identity_is_stored() @test
{
    Msg m;
    mtk::helper::init(&m);
    Inner* h = mtk::helper::to_handle(&m);
    always_assert(h.link.type == Msg::typeid, "the identity is not in the inner");
}

<*
 Part 5.5: an inner with no identity written is a defect, and the port's
 mitigation is that a zeroed typeid matches no type.

 An item whose init was never called is REFUSED at the border rather than
 mis-claimed. That is the whole of what C3 gives here, and it is worth a test
 because it is the one place the port is no better than ztk.
*>
fn void uninitialized_inner_is_refused() @test
{
    Msg m = {};
    always_assert(!mtk::helper::is_mine((Inner*)&m.node, Msg), "an uninitialized inner was claimed");
    always_assert(mtk::helper::from_handle((Inner*)&m.node, Msg) == null, "an uninitialized inner crossed the border");
}

<*
 Part 6.1 and 6.3: the checking crossing refuses a mismatch and returns
 nothing. The caller decides what to do.

 Invariants 11 and 12.
*>
fn void checking_crossing_refuses() @test
{
    Twin t;
    mtk::helper::init(&t);
    Inner* h = mtk::helper::to_handle(&t);

    always_assert(mtk::helper::from_handle(h, Msg) == null, "a Twin crossed as a Msg");
    always_assert(mtk::helper::from_handle(h, Twin) == &t, "a Twin failed to cross as a Twin");
    always_assert(!mtk::helper::is_mine(h, Msg), "the predicate claimed a Twin");
}

<*
 A null handle is nobody's. Every crossing takes one without dereferencing it.
*>
fn void null_handle_is_nobodys() @test
{
    always_assert(!mtk::helper::is_mine(null, Msg), "the predicate claimed null");
    always_assert(mtk::helper::from_handle(null, Msg) == null, "null crossed the border");
    always_assert(mtk::helper::to_handle((Msg*)null) == null, "to_handle invented a handle from null");
}

<*
 Part 6.2: walking a heterogeneous list and deciding which items to claim.

 This is the third of the three places the check runs, and it is the reason
 the list can hold two types at once. Invariant 13.
*>
fn void heterogeneous_walk_claims_correctly() @test
{
    Msg  m1; Msg  m2;
    Twin t1;
    Job  j1;
    mtk::helper::init(&m1); mtk::helper::init(&m2); mtk::helper::init(&t1); mtk::helper::init(&j1);

    InnerQueue list;
    list.push_back(mtk::helper::to_handle(&m1));
    list.push_back(mtk::helper::to_handle(&t1));
    list.push_back(mtk::helper::to_handle(&j1));
    list.push_back(mtk::helper::to_handle(&m2));

    usz mine = 0;
    usz seen = 0;
    InnerQueueIterator it = list.iter();
    for (Inner* h = it.next(); h; h = it.next())
    {
        seen++;
        if (mtk::helper::from_handle(h, Msg)) mine++;
    }
    always_assert(seen == 4, "the walk lost an item");
    always_assert(mine == 2, "the walk claimed the wrong number of items");
}

<*
 Part 6.3, through the METHODS — H0's second surface, and the one an
 application reads most.

 The crossings are declared on `Inner`, so they are reachable as methods on
 the handle itself. `to` is the checking crossing and `as` is the asserting
 one — C3's own two names, borrowed from `any` rather than invented here, so a
 reader already knows which is which.

 The free macros are exercised everywhere else in this suite. This test exists
 because the method spelling is a separate declaration and a separate way to
 get the arithmetic wrong.
*>
fn void the_methods_cross_the_same_border() @test
{
    Msg  m;
    Twin t;
    mtk::helper::init(&m);
    mtk::helper::init(&t);

    Inner* hm = mtk::helper::to_handle(&m);
    Inner* ht = mtk::helper::to_handle(&t);

    always_assert(hm.to(Msg) == &m, "h.to lost the outer");
    always_assert(hm.as(Msg) == &m, "h.as lost the outer");
    always_assert(hm.to(Msg) == mtk::helper::from_handle(hm, Msg), "the method and the macro disagree");

    // The checking crossing meets another type and says so. Part 6.2: a
    // legitimate state, not a defect — `as` is what refuses this one.
    always_assert(ht.to(Msg) == null, "h.to claimed a Twin as a Msg");
    always_assert(hm.to(Twin) == null, "h.to claimed a Msg as a Twin");
}

<*
 The three Slot crossings as methods — checking, asserting, moving.

 `s.move` carries both of Part 9.2 rule 4's postconditions, and both halves
 are asserted here as they are for the free macro.
*>
fn void the_slot_methods_cross_the_same_border() @test
{
    Msg  m;
    Twin t;
    mtk::helper::init(&m);
    mtk::helper::init(&t);

    Slot s;
    s.fill(mtk::helper::to_handle(&m));

    always_assert(s.to(Msg) == &m, "s.to lost the outer");
    always_assert(s.must(Msg) == &m, "s.must lost the outer");
    always_assert(s.to(Twin) == null, "s.to claimed a Msg as a Twin");
    always_assert(!s.is_empty(), "a look emptied the Slot");

    always_assert(s.move(Twin) == null, "s.move claimed a Msg as a Twin");
    always_assert(!s.is_empty(), "a failed move took the item anyway");

    always_assert(s.move(Msg) == &m, "s.move lost the outer");
    always_assert(s.is_empty(), "a successful move left the Slot full");
}
