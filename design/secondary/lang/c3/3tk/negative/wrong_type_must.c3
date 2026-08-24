<*
 Part 6.3: the ASSERTING crossing on a mismatch.

 A mismatch here is a defect of the program, not a runtime condition — the
 checking crossing is what a caller uses when a mismatch is legitimate.

 Safe build: aborts in must_from_handle.
 Fast build: returns a Msg* that points at a Job. Exits 0 without reading it.
*>
module neg;
import mtk;
import std::io;

fn int main()
{
    Job j;
    mtk::helper::init(&j);

    Msg* m = mtk::helper::must_from_handle(mtk::helper::to_handle(&j), Msg);   // <-- the violation

    io::printfn("no check: a Job crossed as a Msg at %p", (void*)m);
    return 0;
}
