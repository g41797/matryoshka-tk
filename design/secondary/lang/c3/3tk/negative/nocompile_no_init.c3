<*
 3TK-74, B-1 and B-4: an outer the helper creates must declare `init`, and a
 misspelled name is no longer silent.

 `MissingInit` declares `finish` correctly and spells the other hook
 `initialize` — the near miss `helper.c3`'s module block names. Before this
 stage `$defined(outer.init)` answered false, the branch vanished, and the
 outer came back allocated, stamped and uninitialized with nothing reported.

 Expected to FAIL TO COMPILE, in every build mode. The compiler's message is
 the evidence, and it names the hook the type owes.
*>
module neg_nc_init;
import mtk;
import std::core::mem::alloc;

struct MissingInit
{
	Inner inner;
	int id;
}

fn void? MissingInit.initialize(&self, Allocator a) { return; }
fn void  MissingInit.finish(&self, Allocator a) { }

alias MISSING_INIT = helper::OF{MissingInit};

fn int main()
{
	Slot s;
	if (catch MISSING_INIT.create(mem, &s)) { return 1; }
	MISSING_INIT.release(mem, &s);
	return 0;
}
