<*
 Part 9.2 rule 1: never overwrite a full Slot.

 Safe build: aborts in Slot.fill.
 Fast build: the second fill wins, silently. Exits 0.
*>
module neg;
import mtk;
import std::io;

fn int main()
{
    Msg a; Msg b;
    mtk::stamp(&a); mtk::stamp(&b);

    Slot s;
    s.fill(mtk::to_inner(&a));
    s.fill(mtk::to_inner(&b));          // <-- the violation

    io::printn("no check: the full Slot was overwritten");
    return 0;
}
