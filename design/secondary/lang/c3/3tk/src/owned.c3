<*
 The owning helper: `mtk::helper` plus a create and a release. Part 7.3, D10.

 Two generic modules rather than one branching generator. ztk spells this
 distinction with a marker constant and pays 110 duplicated lines; C3 has no
 property to branch on and needs neither. This module composes `mtk::helper`
 rather than repeating it, so the seven members of Part 7.2 exist once.

 D3 is what makes this module possible. Part 4.2 refuses an allocator field in
 the inner, because every item in the program would pay for it. An item that
 wants a release with no allocator parameter keeps the allocator in its own
 OUTER, and takes this helper. An item that does not want to pay the pointer
 takes `mtk::helper` and manages its own lifetime.

 So Part 20 decision 2 is answered per type, at the type's own choice, and not
 once for the whole port.

     struct Msg { int id; AnyNode node; Allocator alloc; }

     alias msg_create  = mtk::owned::create{Msg};
     alias msg_release = mtk::owned::release{Msg};
*>
module mtk::owned <Type>;
import mtk;
import std::core::mem::alloc;

<*
 The inner's offset, and Part 7.4's validation, through the composed helper.
*>
const usz OFF = mtk::helper::OFF{Type};

<*
 The type identity, through the composed helper.
*>
const typeid TYPE = mtk::helper::TYPE{Type};

<*
 The offset of Type's Allocator field.

 The build-time error for a type that has none is raised inside the macro, and
 it names `mtk::helper` as the alternative.
*>
const usz AOFF = mtk::required_alloc_offset(Type);

<*
 Creation is an acquisition. Part 9.8.

 It fills a Slot and does not return a pointer, so it obeys rules 3 and 4 of
 Part 9.2 like every other acquisition. The caller's next line moves the item
 out of the Slot into a typed pointer.

 On an allocation failure the Slot is left untouched — rule 4 — and the fault
 is returned. `alloc::new_try` and not `alloc::new`: the plain form aborts on
 a failed allocation, which would give rule 4 no path to be true on.

 @param a : "the allocator the item keeps for life"
 @param slot : "an empty Slot, filled on success"
*>
fn void? create(Allocator a, Slot* slot)
{
    mtk::@check(slot.is_empty(), "Part 9.2 rule 3: an acquisition asserts the Slot is empty on entry");
    Type* item = alloc::new_try(a, Type)!;
    *(Allocator*)((char*)item + AOFF) = a;
    mtk::helper::init{Type}(item);
    slot.fill(mtk::helper::to_any{Type}(item));
}

<*
 Release, with the kept allocator. Part 13.1's sharp clause: no release call
 takes an allocator as a parameter.

 Part 9.2 rule 6: a no-op on an empty Slot. That is what makes Part 9.7 legal —
 the defer is registered BEFORE the acquisition, and it runs harmlessly on the
 path where the acquisition failed.

 @param slot : "the Slot holding the item; empty afterwards"
*>
fn void release(Slot* slot)
{
    if (slot.is_empty()) return;
    Type* item = mtk::helper::must_from_slot{Type}(slot);
    Allocator a = *(Allocator*)((char*)item + AOFF);
    slot.take();
    alloc::free(a, item);
}
