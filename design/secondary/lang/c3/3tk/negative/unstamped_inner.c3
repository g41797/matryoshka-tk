<*
 `C-1`: an UNSTAMPED outer through the READING door.

 The third boundary, and the newest. `unstamped_insert` reaches
 `@guard_insert` and `unstamped_crossing` reaches `look`; this one reaches
 neither, because `inner()` is where an outer leaves for the toolkit and the
 check now sits there too. Before `3TK-75` this line stamped the outer and the
 defect walked on.

 Safe build: aborts in `OuterHelper.inner`, naming the line below.
 Fast build: the check is not compiled, and the crossing is address arithmetic
 that answers a live `Inner*` on an outer with no identity.
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

	// Null first, because it is the tolerance and not the violation: the door
	// answers null and does not abort.
	if (MSG.inner(null) != null) { io::printn("null did not pass through"); return 1; }

	Inner* i = MSG.inner(&m); // <-- the violation

	io::printfn("no check: an unstamped outer crossed out as %p", (void*)i);
	return 0;
}
