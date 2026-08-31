<*
 An empty `Slot` needs no initializer.

 - Declare it.
 - Acquire a `Holder` into it.
 - Release it.
*>
module exm::empty_slot;
import mtk;
import mtk::managed;
import exm::outers;
import exm::helpers;

faultdef EMPTY_SLOT_FAILED;

fn void? acquire_into_an_empty_slot(Allocator a)
{
    Slot s;
    exm::helpers::expect(EMPTY_SLOT_FAILED, s.is_empty(), "a fresh Slot is not empty")!;

    defer mtk::managed::release(Holder, &s);
    mtk::managed::create(Holder, a, &s)!;

    exm::helpers::expect(EMPTY_SLOT_FAILED, s.is_full(), "create left the Slot empty")!;
}
