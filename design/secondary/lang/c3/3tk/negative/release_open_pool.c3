<*
 Part 11.12 MUST — close before release, pool side. **Tier 1 of D6.**

 Must abort in all four builds. See `release_open_mailbox.c3`.
*>
module neg;
import mtk;
import mtk::pool;
import std::io;
import std::core::mem::alloc;

fn int main()
{
    NullHooks hooks;
    typeid[1] tags = { Msg::typeid };
    Pool* p = pool::create(mem, &tags, &hooks)!!;

    p.release();                     // <-- the violation: never closed

    io::printn("SOFTENED: an open pool was released");
    return 0;
}
