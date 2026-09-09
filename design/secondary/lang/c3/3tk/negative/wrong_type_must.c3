<*
 Part 6.3: the ASSERTING crossing on a mismatch.

 A mismatch here is a defect of the program, not a runtime condition — the
 checking crossing is what a caller uses when a mismatch is legitimate.

 Safe build: aborts in must_from_inner.
 Fast build: returns a Msg* that points at a Job. Exits 0 without reading it.
*>
module neg;
import mtk;
import std::io;

alias JOB = helper::OF{Job};

fn int main()
{
	Slot s;
	if (catch JOB.create(mem, &s)) return 1;

	Msg* m = inner::internal::must_from_inner(s.peek(), Msg); // <-- the violation

	io::printfn("no check: a Job crossed as a Msg at %p", (void*)m);
	return 0;
}