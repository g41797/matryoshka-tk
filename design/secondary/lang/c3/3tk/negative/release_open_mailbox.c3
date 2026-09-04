<*
 Part 11.12 MUST — close before release. **Tier 1 of D6.**

 This is the one contract violation the specification refuses to soften:

   "Both stop the program. In every build mode. Not an assert that compiles
    out. This is the one precondition the toolkit refuses to soften."

 So unlike every other negative program, this one must **abort in all four
 builds**, including `--safe=no -O3`. It uses `always_assert`, not `@check`.

 If it ever prints its last line, the port has softened a MUST.
*>
module neg;
import mtk;
import mtk::mailbox;
import std::io;
import std::core::mem::alloc;

fn int main()
{
    Mailbox* mb = mailbox::create(mem)!!;

    // A queued outer, so a softened check would also leak it.
    Msg m;
    mtk::helper::init(&m);
    Slot s;
    s.fill(mtk::helper::to_inner(&m));
    if (catch mb.send(&s)) return 1;

    mb.release();                    // <-- the violation: never closed

    io::printn("SOFTENED: an open mailbox was released");
    return 0;
}
