<*
 Part 5.2: an UNSTAMPED outer at the crossing.

 The other of the two boundaries. Nothing inserts here — the Slot is filled by
 hand — so `@guard_insert` never runs and the crossing is the only guard left.
 `look` is the checking crossing, the one whose null return is an answer rather
 than a failure, and it is guarded anyway: a null identity is not a mismatch
 between two types, it is the absence of the stamp.

 Safe build: aborts in `OuterHelper.look`, naming the line below.
 Fast build: `look` returns null, the identity never having been read.

 The Slot is filled through the raw `to_inner` for the same reason
 `unstamped_insert` inserts through it: `MSG.inner` verifies the stamp, so it
 would abort one line early and the crossing below would never run.
*>
module neg;
import mtk;
import std::io;

alias MSG = helper::OF{Msg};

fn int main()
{
	// NOT allocated through the helper, and it cannot be: `create` always
	// stamps, and an outer that was never stamped is the whole subject here.
	Msg m; // never stamped

	Slot s;
	s.fill(inner::internal::to_inner(&m));

	Msg* p = MSG.look(&s); // <-- the violation

	io::printfn("no check: an unstamped outer crossed as %p", (void*)p);
	return 0;
}