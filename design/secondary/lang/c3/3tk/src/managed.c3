<*
 The managing helper: `mtk::helper` plus a create and a release. Part 7.3, D10.

 **The name is `managed`, not `owned` — H10.** *Managed* here means one thing
 and one thing only: **the item keeps the allocator it was created with, so
 its release takes none.** There is no collector, no tracing, no background
 anything. Nothing in this port ever frees an item the application did not ask
 it to free. A reader arriving from D or C# should read the word as *the
 allocator is managed for you*, and no further.

 Two modules rather than one branching generator — D10, whose text says *two
 generic modules* because both were, until H0b. Only the ruling's SPELLING
 moved; what it decided did not.
 Part 7.3 allows the distinction to be drawn *by any means the language
 offers: two generators, an interface, a flag, a separate name*, and two
 separate names is on that list. ztk spells the distinction with a marker
 constant and pays 110 duplicated lines; C3 has no property to branch on and
 needs neither. This module composes `mtk::helper` through the module rather
 than repeating it, so the members of Part 7.2 exist once.

 **The distinction lives at the CALL SITE, and D10 is why — E7.** No type
 declares itself managed. It never did: `mtk::owned{Type}` was an
 instantiation written by the APPLICATION, not by the type, and an
 instantiation is a declaration and not a permission. H0b moved that decision
 from the alias line to the call line, and both are on the application's side
 of the fence. The one hard gate is unchanged and is at build time:
 `mtk::required_alloc_offset` refuses a type with no Allocator field and tells
 it which helper to take instead. Do not go looking for a marker; there is
 none, and its absence is a ruling.

 D3 is what makes this module possible. Part 4.2 refuses an allocator field in
 the inner, because every item in the program would pay for it. An item that
 wants a release with no allocator parameter keeps the allocator in its own
 OUTER, and takes this helper. An item that does not want to pay the pointer
 takes `mtk::helper` and manages its own lifetime.

 So Part 20 decision 2 is answered per type, at the type's own choice, and not
 once for the whole port.

     struct Holder { int id; Inner node; Allocator alloc; }

     Slot s;
     mtk::managed::create(Holder, mem, &s)!;
     ...
     mtk::managed::release(Holder, &s);

 `release` names its type, which the instantiated form did not have to. That
 is a real signature change and it is an improvement at the call site:
 releasing is a typed operation, and `owned_release(&s)` hid which type's
 allocator was about to be read.
*>
module mtk::managed;
import mtk;
import mtk::helper;
import std::core::mem::alloc;

<*
 Creation is an acquisition. Part 9.8.

 It fills a Slot and does not return a pointer, so it obeys rules 3 and 4 of
 Part 9.2 like every other acquisition. The caller's next line moves the item
 out of the Slot into a typed pointer.

 On an allocation failure the Slot is left untouched — rule 4 — and the fault
 is returned. `alloc::new_try` and not `alloc::new`: the plain form aborts on
 a failed allocation, which would give rule 4 no path to be true on.

 Part 7.4's validation of the Allocator field happens inside
 `mtk::required_alloc_offset`, at build time, and its message names the type.

 @param $Type : "the outer type, which must carry an Allocator field"
 @param a : "the allocator the item keeps for life"
 @param slot : "an empty Slot, filled on success"
*>
macro void? create($Type, Allocator a, Slot* slot)
{
    mtk::@check(slot.is_empty(), "Part 9.2 rule 3: an acquisition asserts the Slot is empty on entry");
    $Type* item = alloc::new_try(a, $Type)!;
    *(Allocator*)((char*)item + mtk::required_alloc_offset($Type)) = a;
    helper::init(item);
    slot.fill(helper::to_handle(item));
}

<*
 Release, with the kept allocator. Part 13.1's sharp clause: no release call
 takes an allocator as a parameter.

 Part 9.2 rule 6: a no-op on an empty Slot. That is what makes Part 9.7 legal —
 the defer is registered BEFORE the acquisition, and it runs harmlessly on the
 path where the acquisition failed.

 @param $Type : "the outer type, which must carry an Allocator field"
 @param slot : "the Slot holding the item; empty afterwards"
*>
macro void release($Type, Slot* slot)
{
    if (slot.is_empty()) return;
    $Type* item = helper::must_from_slot(slot, $Type);
    Allocator a = *(Allocator*)((char*)item + mtk::required_alloc_offset($Type));
    slot.take();
    alloc::free(a, item);
}
