<*
 Parts 4, 5 and 6 — the inner, the identity, and self-identification.

 Part 18 invariants 7, 8, 9, 10, 11, 12.
*>
module mtk_test;
import mtk;

<*
 Part 4.2: the inner has exactly two parts. Three words, and no more.
*>
fn void inner_is_two_parts() @test
{
    always_assert(AnyNode::size == 2 * uptr::size + typeid::size, "the inner grew a field");
}

<*
 Part 4.3: the inner field may sit anywhere. Both ends, in one test.

 Invariant 7.
*>
fn void inner_at_any_offset() @test
{
    always_assert(MSG_OFF != 0, "Msg's inner should not be at offset zero");
    always_assert(JOB_OFF == 0, "Job's inner should be at offset zero");

    Msg m;
    Job j;
    msg_init(&m);
    job_init(&j);

    always_assert(msg_to_any(&m) == (AnyHandle)&m.node, "Msg: to_any is not the inner");
    always_assert(job_to_any(&j) == (AnyHandle)&j.node, "Job: to_any is not the inner");
    always_assert(msg_from_any(msg_to_any(&m)) == &m, "Msg: the round trip lost the outer");
    always_assert(job_from_any(job_to_any(&j)) == &j, "Job: the round trip lost the outer");
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
    msg_init(&a);
    msg_init(&b);
    twin_init(&t);

    always_assert(Msg::size == Twin::size, "the test types are no longer twins");
    always_assert(MSG_TYPE != TWIN_TYPE, "Part 5.1: two identically-shaped types share an identity");
    always_assert(a.node.type == b.node.type, "Part 5.1: two items of one type differ");
    always_assert(a.node.type == MSG_TYPE, "Part 5.4: the identity is not the stored one");
}

<*
 Part 5.4: stored, not computed. The walker reads a field.

 Invariant 10.
*>
fn void identity_is_stored() @test
{
    Msg m;
    msg_init(&m);
    AnyHandle h = msg_to_any(&m);
    always_assert(h.type == MSG_TYPE, "the identity is not in the inner");
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
    always_assert(!msg_is_mine((AnyHandle)&m.node), "an uninitialized inner was claimed");
    always_assert(msg_from_any((AnyHandle)&m.node) == null, "an uninitialized inner crossed the border");
}

<*
 Part 6.1 and 6.3: the checking crossing refuses a mismatch and returns
 nothing. The caller decides what to do.

 Invariants 11 and 12.
*>
fn void checking_crossing_refuses() @test
{
    Twin t;
    twin_init(&t);
    AnyHandle h = twin_to_any(&t);

    always_assert(msg_from_any(h) == null, "a Twin crossed as a Msg");
    always_assert(twin_from_any(h) == &t, "a Twin failed to cross as a Twin");
    always_assert(!msg_is_mine(h), "the predicate claimed a Twin");
}

<*
 A null handle is nobody's. Every crossing takes one without dereferencing it.
*>
fn void null_handle_is_nobodys() @test
{
    always_assert(!msg_is_mine(null), "the predicate claimed null");
    always_assert(msg_from_any(null) == null, "null crossed the border");
    always_assert(msg_to_any(null) == null, "to_any invented a handle from null");
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
    msg_init(&m1); msg_init(&m2); twin_init(&t1); job_init(&j1);

    NodeList list;
    list.push_back(msg_to_any(&m1));
    list.push_back(twin_to_any(&t1));
    list.push_back(job_to_any(&j1));
    list.push_back(msg_to_any(&m2));

    usz mine = 0;
    usz seen = 0;
    NodeListIterator it = list.iter();
    for (AnyHandle h = it.next(); h; h = it.next())
    {
        seen++;
        if (msg_from_any(h)) mine++;
    }
    always_assert(seen == 4, "the walk lost an item");
    always_assert(mine == 2, "the walk claimed the wrong number of items");
}
