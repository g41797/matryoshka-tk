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
    inner::internal::stamp(&a); inner::internal::stamp(&b);

    Slot s;
    s.fill(inner::internal::to_inner(&a));
    s.fill(inner::internal::to_inner(&b));          // <-- the violation

    io::printn("no check: the full Slot was overwritten");
    return 0;
}
