<*
 Part 8 — the intrusive stack. New with the redesign, R2 and R11.

 It is the storage container, available to a caller like the queue, so what is
 tested here is the container itself: order, the self-link at the bottom, the
 repair, and the heterogeneity every Matryoshka container has.

 Part 18 invariants 13, 14, 15, 17, and the self-link invariant.
*>
module mtk_test;
import mtk;

<*
 The defining property: last in, first out. Five in, five out, reversed.

 The pool's reason for wanting it is defect surfacing rather than performance —
 `stack.c3`'s header carries the argument — but no caller is entitled to the
 order, and Part 11.7 stays silent on it. This test is about the CONTAINER,
 which does promise it, and not about the pool, which does not.
*>
fn void the_stack_is_last_in_first_out() @test
{
    Msg[8] ms;
    InnerStack st;

    for (usz i = 0; i < 5; i++) { ms[i].id = (int)i; mtk::helper::init(&ms[i]); st.push(mtk::helper::to_handle(&ms[i])); }
    always_assert(st.len() == 5, "five went in and the count disagrees");

    for (usz i = 5; i > 0; i--)
    {
        Msg* m = mtk::helper::from_handle(st.pop(), Msg);
        always_assert(m != null, "an item came off as the wrong type");
        always_assert(m.id == (int)(i - 1), "the stack is not last-in first-out");
    }
    always_assert(st.is_empty(), "the stack is not empty after five pops");
    always_assert(st.len() == 0, "the count did not reach zero");
}

<*
 Part 8.2: an empty stack answers, and does not fail. Part 19.4 again.
*>
fn void an_empty_stack_answers() @test
{
    InnerStack st;
    always_assert(st.pop() == null, "pop on an empty stack");
    always_assert(st.is_empty(), "an empty stack says it is not empty");
    always_assert(st.len() == 0, "an empty stack has a length");
}

<*
 The self-link, at the bottom of the stack rather than the end of a queue.

 `pop` recognises the sole item by `h.points_to() == h`, so a stack built with a
 null
 terminator would either lose the item or leave `top` dangling. Both states are
 visible from here.
*>
fn void the_bottom_item_points_at_itself() @test
{
    Msg a; Msg b;
    mtk::helper::init(&a); mtk::helper::init(&b);
    a.id = 1; b.id = 2;

    InnerStack st;
    st.push(mtk::helper::to_handle(&a));
    always_assert(mtk::helper::to_handle(&a).points_to() == mtk::helper::to_handle(&a), "the sole item of a stack is not self-linked");

    st.push(mtk::helper::to_handle(&b));
    always_assert(mtk::helper::to_handle(&b).points_to() == mtk::helper::to_handle(&a), "the pushed item does not cover the one below");
    always_assert(mtk::helper::to_handle(&a).points_to() == mtk::helper::to_handle(&a), "the bottom stopped being self-linked");

    always_assert(mtk::helper::from_handle(st.pop(), Msg).id == 2, "pop took the wrong end");
    always_assert(mtk::helper::from_handle(st.pop(), Msg).id == 1, "the bottom item was lost");
    always_assert(st.pop() == null, "the stack did not empty");
}

<*
 Part 8.7: the exact link test, on the stack. An item on a stack is linked,
 including the bottom one, and an item on nothing is not.
*>
fn void the_link_test_is_exact_on_the_stack() @test
{
    Msg a; Msg b;
    mtk::helper::init(&a); mtk::helper::init(&b);

    InnerStack st;
    st.push(mtk::helper::to_handle(&a));

    always_assert(mtk::inner::is_linked(mtk::helper::to_handle(&a)), "the bottom of a stack reports unlinked");
    always_assert(!mtk::inner::is_linked(mtk::helper::to_handle(&b)), "an item on no container reports linked");
}

<*
 Part 8.8: the repair. `pop` clears the link, so the item can be pushed again —
 onto this stack or onto a queue, which is exactly what `Pool.close` does.

 Invariant 17.
*>
fn void pop_repairs_the_link() @test
{
    Msg[8] ms;
    InnerStack st;
    for (usz i = 0; i < 3; i++) { ms[i].id = (int)i; mtk::helper::init(&ms[i]); st.push(mtk::helper::to_handle(&ms[i])); }

    Inner* top    = st.pop();
    Inner* middle = st.pop();
    Inner* bottom = st.pop();

    always_assert(!mtk::inner::is_linked(top), "pop left the top's link set");
    always_assert(!mtk::inner::is_linked(middle), "pop left a middle item's link set");
    always_assert(!mtk::inner::is_linked(bottom), "pop left the bottom's self-link set");

    // the shape Pool.close uses: pop off the stack, push onto a queue
    InnerQueue q;
    q.push_back(bottom);
    q.push_back(middle);
    q.push_back(top);
    always_assert(q.len() == 3, "a repaired item was refused by the queue");
}

<*
 Part 8.1 and 8.3: the stack is heterogeneous and speaks in handles, like every
 other Matryoshka container. Invariants 13 and 14.

 The pool never mixes identities in one bucket, but the container does not know
 that and is not entitled to assume it.
*>
fn void one_stack_three_types() @test
{
    Msg  m; Job  j; Twin t;
    mtk::helper::init(&m); mtk::helper::init(&j); mtk::helper::init(&t);

    InnerStack st;
    st.push(mtk::helper::to_handle(&m));
    st.push(mtk::helper::to_handle(&j));
    st.push(mtk::helper::to_handle(&t));

    always_assert(st.len() == 3, "three types did not fit on one stack");
    always_assert(mtk::helper::from_handle(st.pop(), Twin) == &t, "the Twin came back wrong");
    always_assert(mtk::helper::from_handle(st.pop(), Job) == &j, "the Job came back wrong");
    always_assert(mtk::helper::from_handle(st.pop(), Msg) == &m, "the Msg came back wrong");
}
