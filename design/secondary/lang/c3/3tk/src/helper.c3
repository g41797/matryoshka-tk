<*
 The helper — Part 7, and the border of Part 7.5.

 Every crossing between a typed pointer and a type-erased handle happens in
 this file and nowhere else. That is what makes the address arithmetic
 auditable: Part 7.5 MUST.

 D2 refused `inline` on the inner field for the same reason. An implicit
 conversion is a crossing that appears at no call site and in no file.

 **There is no instantiation and no alias, for any type, ever — H0.** The
 members are macros over `$Type`, and the code is generated per call site
 rather than per type. C3's own type-erased value takes exactly this shape:
 `anycast`, `any.to` and `any.as` are macros that take the type at the call
 site (`core/builtin.c3`). The stdlib reaches for a generic struct when there
 is state to hold; the helper holds none.

     struct Msg { int id; Inner node; char[64] body; }

     Msg m;
     mtk::helper::init(&m);
     Handle h = mtk::helper::to_handle(&m);

     Msg* p = h.to(Msg);        // checking
     Msg* q = h.as(Msg);        // asserting

 A new outer type costs nothing before it can be used. Not one line.

 **The type identity is C3's own `Msg::typeid`** and the port does not
 re-export it. Part 7.2's first member is *the type identity value*, and that
 is it — native, by Q2: unique at runtime, equal for two items of one type,
 different for two identically-shaped types, O(1) to compare. The per-type
 mutable byte ztk needed against linker merging does not exist here.

 **The border is held by convention and the layering checks, not by
 visibility.** `mtk::inner_offset` is public and cannot be made private
 without breaking this file, so any module that imports `mtk` can compute an
 offset and cast. That was true of the port before H0 and H0 neither creates
 nor fixes it; it is written down here so no reader mistakes this file for a
 wall.

 **A macro is untyped at its boundary**, and the repair is the stdlib's own
 habit — a `@require` guard that fires at the CALLER's line, in the port's own
 words. Part 15.5's tiers come from the language here rather than from
 `mtk::@check`.

 **One thing is lost against the per-type instantiation, and it is named
 rather than buried**: a type that is declared but never crossed with is never
 validated, because there is no instantiation to force Part 7.4's check.

 Part 7.1 as `matryoshka-specification-003.md` words it asks for a helper
 object bound to one type. This port has none, and that sentence is a
 SPECIFICATION defect, not a port defect — E6, and `3tk-deviations-001.md`
 V19. 3TK-17 rewords it. Do not "fix" this file to match it.
*>
module mtk::helper;
import mtk;

<*
 Part 7.2's predicate: does this identity name my type?

 A null handle is not mine. Part 5.5's uninitialized inner carries a zeroed
 typeid, which matches no type, so an item whose init was never called is
 refused here rather than mis-claimed.

 @param $Type : "the outer type"
*>
macro bool is_mine(Handle h, $Type) => h != null && h.type == $Type::typeid;

<*
 Part 7.2's initializer. Writes the identity into the inner. Part 5.4: the
 identity is stored, not computed.

 The link is cleared as well — one field now, not two — so a freshly
 initialized item passes the exact link test of Part 8.7 and can be inserted.

 Every creation site calls this, including the ones that do not allocate.
 Part 5.5. It stays a separate call and is not folded into construction — H8.

 The type is inferred from the pointer; no call site names it.

 @param item : "a pointer to the outer"
 @require $defined($Typeof(*item)::members) : "not a struct that embeds an Inner"
*>
macro void init(item)
{
    Inner* n = (Inner*)((char*)item + mtk::inner_offset($Typeof(*item)));
    n.next = null;
    n.type = $Typeof(*item)::typeid;
}

<*
 Part 7.2's crossing the other way: from a typed pointer to a handle.

 This one cannot fail, and it is the only direction that adds the offset. The
 type is inferred; the outbound direction never needs one named.

 @param item : "a pointer to the outer, or null"
 @require $defined($Typeof(*item)::members) : "not a struct that embeds an Inner"
*>
macro Handle to_handle(item)
    => item ? (Handle)((char*)item + mtk::inner_offset($Typeof(*item))) : null;

<*
 The checking crossing. Part 6.3.

 Null when the identity does not match. The caller decides what to do, and a
 mismatch is a legitimate state of a correct program here — a walker of a
 heterogeneous list meets other types by design. Part 6.2.

 The inbound crossings are the ones that name a type, and that is not
 ceremony: a crossing from an erased handle must say what it expects.

 @param $Type : "the outer type expected"
*>
macro from_handle(Handle h, $Type)
{
    if (!is_mine(h, $Type)) return ($Type*)null;
    return ($Type*)((char*)h - mtk::inner_offset($Type));
}

<*
 The asserting crossing. Part 6.3.

 A mismatch is a defect of the program, not a runtime condition, so it is a
 tier 2 check and it compiles out in a fast build — the `@require` is live in
 a safe build and gone under `--safe=no`, and it names the caller's line.
 Named apart from `from_handle` so a reader sees at the call site which one is
 meant.

 **One check, not two — H7.** A null handle and a wrong identity are the same
 kind of wrong: a contract violation, a defect of the calling program, and
 Part 15.5 does not distinguish them. Splitting the guard buys a message and
 costs a branch in exactly the builds where a developer already has the handle
 in a debugger. A zeroed typeid from an uninitialized item is refused here
 rather than mis-claimed, which is Part 5.5 and is the substantive case.

 @param $Type : "the outer type asserted"
 @require is_mine(h, $Type) : "the handle is not of this type"
*>
macro must_from_handle(Handle h, $Type) => ($Type*)((char*)h - mtk::inner_offset($Type));

<*
 The checking crossing from a Slot. Part 7.2.

 The Slot is untouched either way. This is a look, not a take.

 @param $Type : "the outer type expected"
*>
macro from_slot(Slot* s, $Type) => from_handle(s.peek(), $Type);

<*
 The asserting crossing from a Slot. Part 7.2. The Slot is untouched.

 @param $Type : "the outer type asserted"
*>
macro must_from_slot(Slot* s, $Type) => must_from_handle(s.peek(), $Type);

<*
 The moving crossing. Part 7.2, and the one member with two postconditions.

 On a match: the typed pointer is returned AND the Slot is cleared.
 On a mismatch: null is returned AND the Slot is untouched — Part 9.2 rule 4,
 a failing acquisition leaves the Slot unchanged.

 Both halves are tested. Neither is optional.

 The returned pointer is computed from the handle `peek` observed, not from
 `take()`'s return value — H6. It does depend on `Slot.take` returning what
 `peek` saw, but the dependency was invisible at this call site and is exactly
 the sort of thing a later change to `Slot` would break quietly.

 @param $Type : "the outer type expected"
*>
macro move_from_slot(Slot* s, $Type)
{
    Handle h = s.peek();
    if (!is_mine(h, $Type)) return ($Type*)null;
    s.take();
    return ($Type*)((char*)h - mtk::inner_offset($Type));
}

<*
 The checking crossing, as a method on the handle — C3's own name for it.

 `Handle` is an alias for `Inner*`, so a method on `Inner` taking `&self` is
 reached through a handle directly. `to` and `as` are not invented: they are
 the two names `any` uses for these operations, so a C3 reader already knows
 which is which without learning this port's vocabulary.

 @param $Type : "the outer type expected"
*>
macro Inner.to(&self, $Type) => from_handle((Handle)self, $Type);

<*
 The asserting crossing, as a method on the handle. The `as` of `any`.

 @param $Type : "the outer type asserted"
 @require is_mine((Handle)self, $Type) : "the handle is not of this type"
*>
macro Inner.as(&self, $Type) => ($Type*)((char*)self - mtk::inner_offset($Type));

<*
 The three Slot crossings, as methods. Checking, asserting, moving.

 @param $Type : "the outer type expected"
*>
macro Slot.to(&self, $Type) => from_slot(self, $Type);

<*
 @param $Type : "the outer type asserted"
*>
macro Slot.must(&self, $Type) => must_from_slot(self, $Type);

<*
 @param $Type : "the outer type expected"
*>
macro Slot.move(&self, $Type) => move_from_slot(self, $Type);
