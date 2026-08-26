<*
 One helper allocates and frees, and only if your struct carries the allocator itself.

 `create` allocates the outer, initializes it, and fills the Slot.
 The item keeps the allocator for life.
 On an allocation failure the Slot is untouched and the fault is returned.
 `release` frees the item with the allocator it kept.
 It takes no allocator.
 It is a no-op on an empty Slot, so a `defer` registered before the acquisition is safe.
 No type declares itself managed.
 The choice is made at the call site.
*>
// [3tk: D3, D10, E7, H0b, H10, Part 4.2, Part 7.2, Part 7.3, Part 7.4, Part 20]
module mtk::managed;

<*
 Allocates the outer, initializes it, and fills the Slot.

 The item keeps the allocator for life.
 On an allocation failure the Slot is untouched and the fault is returned.

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
    *(Allocator*)((char*)item + mtk::inner::required_alloc_offset($Type)) = a;
    helper::init(item);
    slot.fill(helper::to_handle(item));
}

<*
 Frees the item with the allocator it kept.

 It takes no allocator.
 A no-op on an empty Slot, so a `defer` registered before the acquisition is safe.
 The Slot is empty afterwards.

 @param $Type : "the outer type, which must carry an Allocator field"
 @param slot : "the Slot holding the item; empty afterwards"
*>
// [3tk: Part 9.2, Part 9.7, Part 13.1]
macro void release($Type, Slot* slot)
{
    if (slot.is_empty()) return;
    $Type* item = helper::must_from_slot(slot, $Type);
    Allocator a = *(Allocator*)((char*)item + mtk::inner::required_alloc_offset($Type));
    slot.take();
    alloc::free(a, item);
}

<*
 Finds the `Allocator` field at compile time.

 A type with no `Allocator` field does not compile.
 The message tells you to take the plain helper instead.

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


//----------------------
// Little-endian imports
//----------------------
import mtk;
import mtk::inner;
import mtk::helper;
import std::core::mem::alloc;
