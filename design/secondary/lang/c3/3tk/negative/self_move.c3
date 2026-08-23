<*
 Part 8.9: moving a list onto itself is refused TWICE.

 Safe build: the tier 2 assert fires and aborts.
 Fast build: the assert is gone, the EARLY RETURN saves the list, and the
 program proves the list survived. That second half is why Part 8.9 wants a
 pair and not an assert.
*>
module neg;
import mtk;
import std::io;

fn int main()
{
    Msg[3] ms;
    NodeList a;
    for (usz i = 0; i < 3; i++)
    {
        ms[i].id = (int)i;
        msg_init(&ms[i]);
        a.push_back(msg_to_any(&ms[i]));
    }

    a.append_list(&a);                // <-- the violation

    always_assert(a.len() == 3, "the early return did not save the list");
    for (usz i = 0; i < 3; i++)
    {
        Msg* m = mtk::helper::from_any{Msg}(a.pop_front());
        always_assert(m != null && m.id == (int)i, "the self-move lost an item");
    }
    io::printn("no check: the early return saved the list");
    return 0;
}
