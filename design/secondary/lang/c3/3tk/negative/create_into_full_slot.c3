<*
 Part 9.2 rule 3: an acquisition asserts the Slot is empty on entry.

 Rule 1 and rule 3 are close enough to be confused, and they are not the same:
 rule 1 forbids the overwrite, rule 3 puts the check at the ENTRY of every
 acquiring operation, before anything is allocated. This provokes the second.

 Safe build: aborts in owned::create, before the allocation.
 Fast build: the check is gone, and the created item replaces the one in the
 Slot. Exits 0, having leaked — which is what a compiled-out contract costs,
 and why the check exists.
*>
module neg;
import mtk;
import std::io;

struct Owned { int id; Inner node; Allocator alloc; }

fn int main()
{
    Msg m;
    msg_init(&m);

    Slot s;
    s.fill(msg_to_inner(&m));

    if (catch mtk::owned::create{Owned}(mem, &s)) return 1;   // <-- the violation

    io::printn("no check: create wrote into a full Slot");
    return 0;
}
