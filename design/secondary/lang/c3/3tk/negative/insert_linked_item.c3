<*
 Part 8.7: an item that is on a DIFFERENT container.

 This is the case a same-container walk never could see — walking queue B says
 nothing about an item on queue A — and it is why the old Part 8.6 needed a
 pair of checks. **It survives the redesign and it gets stronger**, because
 after R6b the check that catches it is the whole guard rather than half of it:
 an exact link test refuses an item on ANY chain, so it catches this AND the
 case `insert_twice_same_queue.c3` provokes.

 One check, O(1), tier 2, in place of a link test plus an O(n) walk.

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

    InnerQueue one;
    InnerQueue two;
    one.push_back(msg_to_inner(&a));
    one.push_back(msg_to_inner(&b));

    two.push_back(msg_to_inner(&a));    // <-- the violation: a is on `one`

    io::printn("no check: a linked item was inserted on a second queue");
    return 0;
}
