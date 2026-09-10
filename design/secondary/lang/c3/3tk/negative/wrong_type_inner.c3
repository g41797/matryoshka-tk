<*
 `C-1`: an outer carrying ANOTHER TYPE's identity, through the reading door.

 The half the stamp could never catch. `inner()` used to write the identity,
 so a `Msg` handed to `Job`'s helper was silently RE-stamped as a `Job` and
 every crossing after it agreed. The door reads now, so the disagreement is
 reported where it is made.

 The cast is the violation and it is deliberate: two structs whose `Inner`
 sits at a different offset, one stamped, then crossed through the wrong
 helper.

 Safe build: aborts in `OuterHelper.inner`, naming the line below.
 Fast build: the check is not compiled and the crossing answers whatever the
 address arithmetic finds.
*>
module neg;
import mtk;
import std::io;

alias MSG = helper::OF{Msg};
alias JOB = helper::OF{Job};

fn int main()
{
	// Hand-made on purpose: the subject is which identity the outer carries,
	// and `create` would only ever write the right one.
	Msg m;
	MSG.stamp(&m);

	Inner* i = JOB.inner((Job*)&m); // <-- the violation

	io::printfn("no check: a Msg crossed out as a Job at %p", (void*)i);
	return 0;
}
