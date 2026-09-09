<*
 An empty `Slot` needs no initializer.

 - Declare it.
 - Acquire a `Holder` into it.
 - Release it.
*>
module shc::a_slot_and_transfer::empty_slot;
import mtk;
import shc::outers;
import shc::helpers;

alias HOLDER = helper::OF{Holder};

faultdef EMPTY_SLOT_FAILED;

fn void? acquire_into_an_empty_slot(Allocator a)
{
    Slot s;
    shc::helpers::expect(EMPTY_SLOT_FAILED, s.is_empty(), "a fresh Slot is not empty")!;

    defer HOLDER.release(a, &s);
    HOLDER.create(a, &s)!;

    shc::helpers::expect(EMPTY_SLOT_FAILED, s.is_full(), "create left the Slot empty")!;
}
