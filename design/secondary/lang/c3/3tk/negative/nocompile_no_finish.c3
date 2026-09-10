<*
 3TK-74, B-1 and B-4: an outer the helper creates must declare `finish` too,
 and the check sits in `release` as well as in `create`.

 `MissingFinish` declares `init` correctly and declares no teardown hook at
 all. Before this stage `release` simply skipped the call, so whatever the
 outer had acquired was never given up and nothing reported it.

 Expected to FAIL TO COMPILE, in every build mode. The compiler's message is
 the evidence, and it names the hook the type owes.
*>
module neg_nc_finish;
import mtk;
import std::core::mem::alloc;

struct MissingFinish
{
	Inner inner;
	int id;
}

fn void? MissingFinish.init(&self, Allocator a) { return; }

alias MISSING_FINISH = helper::OF{MissingFinish};

fn int main()
{
	Slot s;
	if (catch MISSING_FINISH.create(mem, &s)) { return 1; }
	MISSING_FINISH.release(mem, &s);
	return 0;
}
