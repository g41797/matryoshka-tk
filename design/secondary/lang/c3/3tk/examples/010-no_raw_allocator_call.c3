<*
 Never a raw allocator call on an outer.

 - The wrong shape is commented out: it would skip the stamp and the hook.
 - The right shape goes through `HOLDER.create`, which runs your `init` hook
   and writes the identity.
*>
module shc::no_raw_allocator_call;
import mtk;
import shc::outers;
import shc::helpers;

alias HOLDER = mtk::OF{Holder};

faultdef NO_RAW_ALLOCATOR_CALL_FAILED;

fn void? never_a_raw_allocator_call(Allocator a)
{
    // WRONG — a raw allocator call on an outer skips the hook and the stamp:
    // Holder* outer = a.new(Holder);

    Slot s;
    defer HOLDER.release(a, &s);
    HOLDER.create(a, &s)!;

    shc::helpers::expect(NO_RAW_ALLOCATOR_CALL_FAILED, mtk::is_mine(s.peek(), Holder), "the outer carries no identity")!;
}
