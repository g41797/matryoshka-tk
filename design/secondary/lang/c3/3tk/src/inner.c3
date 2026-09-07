// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//==============================================================================
// The core, section 1 of 3: the inner, the Slot, the link, and the crossings.
// No module block: `mtk.c3` carries the description of `module mtk`, and a
// module has one description however many sections it is written in.
// 3TK-63 merged `mtk::inner` and `mtk::helper` into this file and this module.
//==============================================================================
// [3tk: D1 to D16, R1 to R15, Part 4, Part 9, Part 10.1]
// [3tk: R5, R6, R6b, D3, V12, Part 4.2, Part 5]
// [3tk: D2, H0, Q2, E6, V19, Part 7, Part 7.1, Part 7.2, Part 7.4, Part 7.5, Part 15.5]
module mtk;

<*
 `Inner` is the field you embed.
 The chain link and the identity, in one.
*>
struct Inner
{
    any link;
}

// --- Writing and reading the link -------------------------------------------

<*
 Keeps the identity, swaps the chain link.

 Public because C3 cannot hide a method — `@private` is ignored on method declarations.
 It is not part of the user surface.
 The containers call it; nothing else should.

 @param to : "the inner this one now links to; itself, if it is the end"
*>
// [3tk: R6b, Part 4.4]
fn void Inner.repoint_to(&self, Inner* to) @inline
    => self.link = any_make(to, self.link.type);

<*
 The inner this one links to.

 Null if it is on no chain.

 Public because C3 cannot hide a method — `@private` is ignored on method declarations.
 It is not part of the user surface.
 The containers call it; nothing else should.
*>
// [3tk: R6b, Part 4.4]
fn Inner* Inner.points_to(&self) @inline => (Inner*)self.link.ptr;

<*
 The identity of the outer this inner is embedded in.

 Null for an inner that was never stamped.
 It exists so that no user ever writes `inner.link.type`.

 Public because C3 cannot hide a method — `@private` is ignored on method declarations.
 It is part of the user surface: a dispatch switch reads it.
*>
// [3tk: Part 3.5, Part 4.4]
fn typeid Inner.outer_tid(&self) @inline => self.link.type;

<*
 A box that holds one `Inner*`, or nothing.

 Zero or one outer.
 A Slot starts empty.
*>
// [3tk: D5, Part 9.1, Part 9.2 rule 1, Part 9.2 rule 2]
typedef Slot = Inner*;

// --- The link test, and the repair -------------------------------------------

<*
 True when the inner is on some chain.

 Exact, and O(1).
 False for a null inner.

 Public because `InnerStack` calls it from `mtk::pool`, and a submodule cannot see this module's `@private` declarations.
 It is not part of the user surface.
*>
// [3tk: R6b, D12, V4, V5, Part 4.3, Part 8.6, Part 8.7]
fn bool is_linked(Inner* inner) @inline => inner != null && inner.points_to() != null;

<*
 Clears the chain link so the outer can be inserted again.

 It clears the link and not the identity.
 Every removal in the queue and the stack calls it for you.

 Public because `InnerStack` calls it from `mtk::pool`, and a submodule cannot see this module's `@private` declarations.
 It is not part of the user surface.
*>
// [3tk: Part 4.3, Part 5.4, Part 8.8]
fn void reset(Inner* inner) @inline
{
    if (!inner) return;
    inner.repoint_to(null);
}

// --- The Slot's reading shape -----------------------------------------------

<*
 Which of the two states it is in.
*>
// [3tk: Part 9.1, Part 9.9]
fn bool Slot.is_empty(&self) @inline => !(Inner*)*self;

<*
 Which of the two states it is in.
*>
// [3tk: Part 9.1, Part 9.9]
fn bool Slot.is_full(&self) @inline => (Inner*)*self != null;

<*
 Look without taking.

 Null on an empty Slot.
*>
// [3tk: Part 9.9]
fn Inner* Slot.peek(&self) @inline => (Inner*)*self;

<*
 Take the `Inner*` out and clear the Slot.

 Null on an empty Slot.
*>
// [3tk: Part 9.2 rule 5, Part 9.9]
fn Inner* Slot.take(&self) @inline
{
    Inner* inner = (Inner*)*self;
    *self = (Slot)(Inner*)null;
    return inner;
}

<*
 Put an `Inner*` in.

 A null inner is a defect.
 Overwriting a full Slot is a defect.

 @param inner : "the inner to place; must not be null"
*>
// [3tk: D6, Part 9.2 rule 1, Part 9.9]
fn void Slot.fill(&self, Inner* inner) @inline
{
    mtk::@check(inner != null, "Slot.fill with a null inner");
    // [3tk: Part 9.2 rule 1]
    mtk::@check(self.is_empty(), "never overwrite a full Slot");
    *self = (Slot)inner;
}

// --- Compile-time discovery of the outer's fields ----------------------------

<*
 It reads the offset out of your type at compile time.

 It walks `$Type::members` and looks for the one of type `Inner`.
 A type with no `Inner` field does not compile.
 A type with two `Inner` fields does not compile.
 The message names your type.

 `@private`, and it can be: it is a macro and not a method, and every caller shares this module.

 @param $Type : "the outer type"
*>
// [3tk: Part 4.3, Part 4.4, Part 7.4]
macro usz inner_offset($Type) @private
{
    var $off = -1;
    var $seen = 0;
    $foreach $m : $Type::members:
        $if $m.type == Inner:
            $off = $m.offset;
            $seen = $seen + 1;
        $endif
    $endforeach
    $assert $seen != 0 : "type " +++ $Type::name +++ " has no Inner field; it cannot be a Matryoshka outer";
    // [3tk: Part 4.4]
    $assert $seen == 1 : "type " +++ $Type::name +++ " has more than one Inner field; exactly one is allowed";
    return $off;
}

// --- Crossing between a typed pointer and an Inner* --------------------------

<*
 True when the inner names `$Type`.

 False for a null inner.
 False for an outer that was never stamped.

 @param $Type : "the outer type"
*>
// [3tk: Part 5.5, Part 7.2]
macro bool is_mine(Inner* inner, $Type) => inner != null && inner.link.type == $Type::typeid;

<*
 Writes the identity into the embedded `Inner`.

 Call it any number of times.
 A second call writes what the first one wrote, and it is safe on a linked outer as well as an unlinked one.
 An outer that was never stamped carries no identity.

 The line below rebuilds the whole `any`, because `.type` is not assignable on its own.
 It preserves `link.ptr`, and that is what makes the stamp safe on a linked inner.
 The natural maintenance edit is `any_make(null, ...)`, which silently unlinks a linked outer.
 The correct line differs from the destructive one by a single sub-expression.

 It was called `init` until 3TK-64, when `init` became the name of the user's own hook.

 @param outer : "a pointer to the outer"
 @require $defined($Typeof(*outer)::members) : "not a struct that embeds an Inner"
*>
// [3tk: H8, HR-5, Part 5.1, Part 5.4, Part 5.5, Part 7.2]
macro void stamp(outer)
{
    Inner* inner = (Inner*)((char*)outer + inner_offset($Typeof(*outer)));
    inner.link = any_make(inner.link.ptr, $Typeof(*outer)::typeid);
}

<*
 From your pointer to the `Inner*`.

 Null in, null out.
 Reading an identity and casting a pointer leave every container alone.

 @param outer : "a pointer to the outer, or null"
 @require $defined($Typeof(*outer)::members) : "not a struct that embeds an Inner"
*>
// [3tk: H5, Part 7.2]
macro Inner* to_inner(outer)
    => outer ? (Inner*)((char*)outer + inner_offset($Typeof(*outer))) : null;

<*
 From an `Inner*` back to `$Type*`.

 Null on an identity mismatch.
 A mismatch is an answer, not a failure.

 @param $Type : "the outer type expected"
*>
// [3tk: H5, Part 6.2, Part 6.3]
macro from_inner(Inner* inner, $Type)
{
    if (!is_mine(inner, $Type)) return ($Type*)null;
    return ($Type*)((char*)inner - inner_offset($Type));
}

<*
 Same as `from_inner()`.

 It aborts on a mismatch.
 Use it where a mismatch would be your own defect.
 The abort names your line.
 Under `--safe=no` it is gone.

 @param $Type : "the outer type asserted"
 @require is_mine(inner, $Type) : "the inner is not of this type"
*>
// [3tk: H7, Part 5.5, Part 6.3, Part 15.5]
macro must_from_inner(Inner* inner, $Type) => ($Type*)((char*)inner - inner_offset($Type));

<*
 Same as `from_inner()`, taking the outer from a Slot.

 It looks. The Slot is unchanged.

 @param $Type : "the outer type expected"
*>
// [3tk: Part 7.2]
macro from_slot(Slot* s, $Type) => from_inner(s.peek(), $Type);

<*
 Same as `from_slot()`.

 It looks, and aborts on failure.
 The Slot is unchanged.

 @param $Type : "the outer type asserted"
*>
// [3tk: Part 7.2]
macro must_from_slot(Slot* s, $Type) => must_from_inner(s.peek(), $Type);

<*
 Same as `from_slot()`, and it takes.

 On success the Slot is left empty.
 On failure it is unchanged.

 @param $Type : "the outer type expected"
*>
// [3tk: H6, Part 7.2, Part 9.2 rule 4]
macro move_from_slot(Slot* s, $Type)
{
    Inner* inner = s.peek();
    if (!is_mine(inner, $Type)) return ($Type*)null;
    s.take();
    return ($Type*)((char*)inner - inner_offset($Type));
}

<*
 Same as `from_inner()`, as a method on the inner.

 @param $Type : "the outer type expected"
*>
macro Inner.to(&self, $Type) => from_inner((Inner*)self, $Type);

<*
 Same as `must_from_inner()`, as a method on the inner.

 @param $Type : "the outer type asserted"
 @require is_mine((Inner*)self, $Type) : "the inner is not of this type"
*>
macro Inner.as(&self, $Type) => ($Type*)((char*)self - inner_offset($Type));

<*
 Same as `from_slot()`, as a method on the Slot.

 @param $Type : "the outer type expected"
*>
macro Slot.to(&self, $Type) => from_slot(self, $Type);

<*
 Same as `must_from_slot()`, as a method on the Slot.

 @param $Type : "the outer type asserted"
*>
macro Slot.must(&self, $Type) => must_from_slot(self, $Type);

<*
 Same as `move_from_slot()`, as a method on the Slot.

 @param $Type : "the outer type expected"
*>
macro Slot.move(&self, $Type) => move_from_slot(self, $Type);
