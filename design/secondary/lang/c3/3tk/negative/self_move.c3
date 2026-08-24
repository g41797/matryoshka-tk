<*
 Part 8.9: moving a queue onto itself is refused TWICE.

 The pair survives the redesign unchanged, narrowed from the general list to
 the queue. The failure it guards is identical with one link: the naive move
 rings the items into a cycle and clears the header, losing every one.

 Safe build: the tier 2 assert aborts.
 Fast build: the assert is gone, the EARLY RETURN saves the queue, and the
 program proves the queue survived. That second half is why Part 8.9 wants a
 pair and not an assert.
*>
module neg;
import mtk;
import std::io;

fn int main()
{
    Msg[3] ms;
    InnerQueue a;
    for (usz i = 0; i < 3; i++)
    {
        ms[i].id = (int)i;
        mtk::helper::init(&ms[i]);
        a.push_back(mtk::helper::to_handle(&ms[i]));
    }

    a.append_queue(&a);                // <-- the violation

    always_assert(a.len() == 3, "the early return did not save the queue");
    for (usz i = 0; i < 3; i++)
    {
        Msg* m = mtk::helper::from_handle(a.pop_front(), Msg);
        always_assert(m != null && m.id == (int)i, "the self-move lost an item");
    }
    io::printn("no check: the early return saved the queue");
    return 0;
}
