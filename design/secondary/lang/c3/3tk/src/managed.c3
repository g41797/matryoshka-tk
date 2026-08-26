<*
 The managing helper: `mtk::helper`, plus a create and a release.

 An item created here keeps the allocator it was created with, so its release
 takes none.
 The outer must carry an `Allocator` field; a type without one fails to compile.
 An item that does not want to pay for that field takes `mtk::helper` instead.
 No type declares itself managed. The choice is made at the call site.
*>
// [3tk: D3, D10, E7, H0b, H10, Part 4.2, Part 7.2, Part 7.3, Part 7.4, Part 20]
module mtk::managed;
import mtk;
import mtk::helper;
import std::core::mem::alloc;

<*
 Allocates an outer with the given allocator, initializes it, and fills the Slot.

 The item keeps the allocator; its release takes none.
 On an allocation failure the Slot is left untouched and the fault is returned.

 @param $Type : "the outer type, which must carry an Allocator field"
 @param a : "the allocator the item keeps for life"
 @param slot : "an empty Slot, filled on success"
*>
// [3tk: Part 7.4, Part 9.2, Part 9.8]
macro void? create($Type, Allocator a, Slot* slot)
{
    // [3tk: Part 9.2 rule 3]
    mtk::@check(slot.is_empty(), "an acquisition asserts the Slot is empty on entry");
    $Type* item = alloc::new_try(a, $Type)!;
    *(Allocator*)((char*)item + mtk::required_alloc_offset($Type)) = a;
    helper::init(item);
    slot.fill(helper::to_handle(item));
}

<*
 Frees the item with the allocator it kept.

 No release call takes an allocator as a parameter.
 A no-op on an empty Slot, so a defer registered before the acquisition is safe.
 The Slot is empty afterwards.

 @param $Type : "the outer type, which must carry an Allocator field"
 @param slot : "the Slot holding the item; empty afterwards"
*>
// [3tk: Part 9.2, Part 9.7, Part 13.1]
macro void release($Type, Slot* slot)
{
    if (slot.is_empty()) return;
    $Type* item = helper::must_from_slot(slot, $Type);
    Allocator a = *(Allocator*)((char*)item + mtk::required_alloc_offset($Type));
    slot.take();
    alloc::free(a, item);
}

<*
 The offset of the outer's `Allocator` field.

 A type with no `Allocator` field fails to compile, and is told to take
 `mtk::helper` instead.

 @param $Type : "the outer type"
*>
// [3tk: D3, Part 7.4]
macro usz required_alloc_offset($Type)
{
    var $off = -1;
    $foreach $m : $Type::members:
        $if $m.type == Allocator:
            $off = $m.offset;
        $endif
    $endforeach
    $assert $off >= 0 : "type " +++ $Type::name +++ " has no Allocator field; use mtk::helper instead of mtk::managed";
    return $off;
}
