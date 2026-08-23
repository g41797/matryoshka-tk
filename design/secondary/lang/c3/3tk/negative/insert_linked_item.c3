<*
 Part 8.6, the LINK TEST half. An item that is on a DIFFERENT list.

 This is the case the walk cannot see — walking list B says nothing about an
 item on list A — so only the link test catches it. The other half of Part
 8.6's argument.

 Safe build: aborts in the tier 2 link test.
 Fast build: exits 0.
*>
module neg;
import mtk;
import std::io;

fn int main()
{
    Msg a; Msg b;
    msg_init(&a); msg_init(&b);

    NodeList one;
    NodeList two;
    one.push_back(msg_to_any(&a));
    one.push_back(msg_to_any(&b));

    two.push_back(msg_to_any(&a));    // <-- the violation: a is on `one`

    io::printn("no check: a linked item was inserted on a second list");
    return 0;
}
