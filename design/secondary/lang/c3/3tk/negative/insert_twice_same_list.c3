<*
 Part 8.6, the WALK half. An item already on THIS list, and alone on it.

 This is the case the link test cannot see — a list of exactly one member
 leaves the item with no neighbours — so only the O(n) walk catches it. It is
 the whole reason Part 8.6 says neither check alone is enough.

 Safe build: aborts in the tier 3 guard.
 Fast build: the list is corrupted, silently. Exits 0 without walking it.
*>
module neg;
import mtk;
import std::io;

fn int main()
{
    Msg m;
    msg_init(&m);

    NodeList list;
    list.push_back(msg_to_any(&m));
    list.push_back(msg_to_any(&m));   // <-- the violation

    io::printn("no check: the item was inserted twice");
    return 0;
}
