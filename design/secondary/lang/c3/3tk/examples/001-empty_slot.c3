<*
 An empty `Slot` needs no initializer.

 - Declare it.
 - Acquire a `Holder` into it.
 - Release it.
*>
module shc::empty_slot;
import mtk;
import mtk::managed;
import shc::outers;
import shc::helpers;

faultdef EMPTY_SLOT_FAILED;

fn void? acquire_into_an_empty_slot(Allocator a)
{
    Slot s;
    shc::helpers::expect(EMPTY_SLOT_FAILED, s.is_empty(), "a fresh Slot is not empty")!;

    defer mtk::managed::release(Holder, &s);
    mtk::managed::create(Holder, a, &s)!;

    shc::helpers::expect(EMPTY_SLOT_FAILED, s.is_full(), "create left the Slot empty")!;
}
