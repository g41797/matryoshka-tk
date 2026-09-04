<*
 Never a raw allocator call on an outer.

 - The wrong shape is commented out: it would skip `init`.
 - The right shape goes through `mtk::managed::create`, which writes the
   allocator and the identity together.
*>
module shc::no_raw_allocator_call;
import mtk;
import mtk::managed;
import shc::outers;
import shc::helpers;

faultdef NO_RAW_ALLOCATOR_CALL_FAILED;

fn void? never_a_raw_allocator_call(Allocator a)
{
    // WRONG — a raw allocator call on an outer skips `init`:
    // Holder* outer = a.new(Holder);

    Slot s;
    defer mtk::managed::release(Holder, &s);
    mtk::managed::create(Holder, a, &s)!;

    shc::helpers::expect(NO_RAW_ALLOCATOR_CALL_FAILED, mtk::helper::is_mine(s.peek(), Holder), "the outer carries no identity")!;
}
