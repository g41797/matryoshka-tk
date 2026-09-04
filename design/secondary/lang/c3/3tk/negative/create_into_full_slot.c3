<*
 Part 9.2 rule 3: an acquisition asserts the Slot is empty on entry.

 Rule 1 and rule 3 are close enough to be confused, and they are not the same:
 rule 1 forbids the overwrite, rule 3 puts the check at the ENTRY of every
 acquiring operation, before anything is allocated. This provokes the second.

 Safe build: aborts in managed::create, before the allocation.
 Fast build: the check is gone, and the created outer replaces the one in the
 Slot. Exits 0, having leaked — which is what a compiled-out contract costs,
 and why the check exists.
*>
module neg;
import mtk;
import std::io;

struct Holder { int id; Inner inner; Allocator alloc; }

fn int main()
{
    Msg m;
    mtk::helper::init(&m);

    Slot s;
    s.fill(mtk::helper::to_inner(&m));

    if (catch mtk::managed::create(Holder, mem, &s)) return 1;   // <-- the violation

    io::printn("no check: create wrote into a full Slot");
    return 0;
}
