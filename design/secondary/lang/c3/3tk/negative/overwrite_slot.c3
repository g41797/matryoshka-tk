<*
 Part 9.2 rule 1: never overwrite a full Slot.

 Safe build: aborts in Slot.fill.
 Fast build: the second fill wins, silently. Exits 0.
*>
module neg;
import mtk;
import std::io;

alias MSG = helper::OF{Msg};

fn int main()
{
	Slot s;
	Slot other;
	if (catch MSG.create(mem, &s)) return 1;
	if (catch MSG.create(mem, &other)) return 1;

	s.fill(inner::internal::to_inner(MSG.must_look(&other))); // <-- the violation

	io::printn("no check: the full Slot was overwritten");
	return 0;
}