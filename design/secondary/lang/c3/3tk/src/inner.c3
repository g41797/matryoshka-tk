// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//==============================================================================
// The inner, the Slot, the link and the crossings — and a module of its own.
// 3TK-63 merged it into `mtk`; 3TK-67 split it back out, because `c3c docgen`
// groups by module and by nothing else, and `mtk` is a landing page of four
// declarations.
//
// The file is written in three parts, in this order:
//
//   1. `module mtk::inner;`           yours, and there is no other way to write it
//   2. `module mtk::inner;`           public, and not yours — the helper is your way in
//   3. `module mtk::inner @private;`  hidden from every other module
//
// Part 1 is the whole of what a user calls directly, and it is there because
// the helper cannot replace it: you embed the field, you read the Slot, and a
// dispatch switch reads an identity before it knows the type. Everything in
// part 2 has a member of `OuterHelper` that does it for you.
//
// A declaration in part 2 or 3 carries a `<* *>` block whose first line is
// `For internal usage.` and which holds, after it, only directives that do
// work. The block stays: a `@require` lives inside it, so deleting the block
// deletes the check and says nothing. Part 2 is public because the compiler
// leaves no choice — `@private` and `@local` are both ignored on method
// declarations, and `InnerStack`, in `mtk::pool`, calls two free functions of
// part 2 from outside this module altogether.
//==============================================================================
<*
 The inner, the Slot, the link and the crossings.

 You send and receive your own struct.
 The struct is the outer, and it is yours.
 You give the infrastructure one thing, an `Inner` embedded in it.
 From then on the infrastructure never sees your type.
 It moves `Inner*`, intrusively and with the type erased.

 `Inner` is the field you embed.
 The chain link and the identity, in one.
 The identity sits in the same field as the chain link.
 The identity says what the outer type is.
 A pointer to an embedded `Inner` is one outer, with the type forgotten.
 It is spelled `Inner*`, because that is all it is, and 3tk transports nothing else.
 `Slot` is a box that holds one `Inner*`, or nothing.
 A Slot starts empty.

 The Slot is how the toolkit tells you where an outer went.
 Read the Slot after every call that gives or takes an outer.

 The chain link is the other half of `Inner`.
 `reset` clears the chain link and not the identity.
 Every chain ends at an inner pointing at itself, never at null.
 That is what makes `is_linked` exact.

 You get your struct back by crossing once, from `Inner*` to `Outer*`.
 The identity in the `Inner` is what makes that crossing safe.

 `to_inner` goes from your pointer to the `Inner*`.
 Null in, null out.
 `from_inner` goes from an `Inner*` back to `$Type*`, and is null on an identity mismatch.
 A mismatch is an answer, not a failure.
 `must_from_inner` is the same, and it aborts on a mismatch.
 The abort names your line.
 The same three take the outer from a Slot, and five of them appear again as methods.
 `from_slot` looks, and the Slot is unchanged.
 `move_from_slot` takes, and on success the Slot is left empty.
 None of these moves an outer.
 Reading an identity and casting a pointer leave every container alone.
 No alias to declare, no instantiation, no registration.

 It is a module of its own so that it is a page of its own.
 A user reaches it through `import mtk;` and writes `Inner` and `Slot` unqualified, as before.
*>
module mtk::inner;

<*
 `Inner` is the field you embed.
 The chain link and the identity, in one.

 A small part of this module is yours to call directly: the Slot's five operations, the identity, and the five crossings written as methods.
 Everything else goes through the helper, and says so with `For internal usage.` at the head of its doc block.
*>
struct Inner
{
    any link;
}

<*
 A box that holds one `Inner*`, or nothing.

 Zero or one outer.
 A Slot starts empty.
*>
typedef Slot = Inner*;

<*
 The identity of the outer this inner is embedded in.

 Null for an inner that was never stamped.
 It exists so that no user ever writes `inner.link.type`.
 The helper cannot do this one for you: a dispatch switch reads the identity before it knows the type.
*>
fn typeid Inner.outer_tid(&self) @inline => self.link.type;

// --- The Slot's five operations ----------------------------------------------

<*
 Which of the two states it is in.
*>
fn bool Slot.is_empty(&self) @inline => !(Inner*)*self;

<*
 Which of the two states it is in.
*>
fn bool Slot.is_full(&self) @inline => (Inner*)*self != null;

<*
 Look without taking.

 Null on an empty Slot.
*>
fn Inner* Slot.peek(&self) @inline => (Inner*)*self;

<*
 Take the `Inner*` out and clear the Slot.

 Null on an empty Slot.
*>
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
fn void Slot.fill(&self, Inner* inner) @inline
{
    mtk::@check(inner != null, "Slot.fill with a null inner");
    // [3tk: Part 9.2 rule 1]
    mtk::@check(self.is_empty(), "never overwrite a full Slot");
    *self = (Slot)inner;
}

// --- The five crossings back to your type ------------------------------------

<*
 From an `Inner*` back to `$Type*`.

 Null on an identity mismatch.
 A mismatch is an answer, not a failure.

 @param $Type : "the outer type expected"
*>
macro Inner.to(&self, $Type) => from_inner((Inner*)self, $Type);

<*
 From an `Inner*` back to `$Type*`, and it aborts on a mismatch.

 Use it where a mismatch would be your own defect.
 The abort names your line.

 @param $Type : "the outer type asserted"
 @require is_mine((Inner*)self, $Type) : "the inner is not of this type"
*>
macro Inner.as(&self, $Type) => ($Type*)((char*)self - inner_offset($Type));

<*
 From the Slot back to `$Type*`. It looks, and the Slot is unchanged.

 Null on an identity mismatch.
 A mismatch is an answer, not a failure.

 @param $Type : "the outer type expected"
*>
macro Slot.to(&self, $Type) => from_slot(self, $Type);

<*
 From the Slot back to `$Type*`, and it aborts on a mismatch. The Slot is unchanged.

 Use it where a mismatch would be your own defect.
 The abort names your line.

 @param $Type : "the outer type asserted"
*>
macro Slot.must(&self, $Type) => must_from_slot(self, $Type);

<*
 From the Slot back to `$Type*`, and it takes.

 On success the Slot is left empty.
 On failure it is unchanged.

 @param $Type : "the outer type expected"
*>
macro Slot.move(&self, $Type) => move_from_slot(self, $Type);


//==============================================================================
// Part 2 of 3: public, and not yours. Still `module mtk::inner;`.
//
// For internal usage - everything below this line.
//
// Every declaration below has a member of `OuterHelper` that does it for you —
// `stamp`, `inner`, `look`, `must_look`, `take`, `must_take`, `linked` — or is
// a chain primitive only the queue and the stack may touch. Measured across
// `examples/`: two of these thirteen are named, once each.
//
// `Inner.link` is public and writable besides, so this is a stated boundary and
// not a locked one.
//==============================================================================

<*
 For internal usage.
*>
macro bool is_mine(Inner* inner, $Type) => inner != null && inner.link.type == $Type::typeid;

<*
 For internal usage.

 @require $defined($Typeof(*outer)::members) : "not a struct that embeds an Inner"
*>
// The identity and the chain link share one field and `.type` is not
// assignable, so writing the identity rebuilds the whole `any`. The first
// sub-expression is `inner.link.ptr` and NOT `null`: preserving the chain link
// is what makes the stamp safe on a linked outer, and therefore idempotent in
// fact rather than by promise about call order. `any_make(null, ...)` is the
// old `init` body verbatim, it compiles, and it silently unlinks a linked
// outer. The correct line differs from the destructive one by that one
// sub-expression. Do not "simplify" it. [3tk: Part 5.1]
macro void stamp(outer)
{
    Inner* inner = (Inner*)((char*)outer + inner_offset($Typeof(*outer)));
    inner.link = any_make(inner.link.ptr, $Typeof(*outer)::typeid);
}

<*
 For internal usage.
*>
// The safe-build identity check, in one place so that all six sites carry the
// same tolerance and the same shape. Null is not a violation: an empty Slot
// and a null `Inner*` are both answers a crossing is allowed to give. An inner
// that EXISTS and carries no identity is the one case, and it means the user
// hand-allocated an outer and never stamped it. `mtk::@check` is the gate, so
// a fast build carries nothing at all: the condition is not evaluated, and
// `outer_tid` is never called.
macro check_stamped(Inner* inner, $msg)
{
    // A `typeid` does not compare against `null` — c3c answers "You cannot cast
    // 'void*' to 'typeid'" — so the pointer side is what is cast, measured on
    // c3c 0.8.3. A zeroed `Inner` gives `(void*)outer_tid() == null` and a
    // stamped one does not.
    mtk::@check(inner == null || (void*)inner.outer_tid() != null, $msg);
}

<*
 For internal usage.

 @require $defined($Typeof(*outer)::members) : "not a struct that embeds an Inner"
*>
macro Inner* to_inner(outer)
    => outer ? (Inner*)((char*)outer + inner_offset($Typeof(*outer))) : null;

<*
 For internal usage.
*>
macro from_inner(Inner* inner, $Type)
{
    if (!is_mine(inner, $Type)) return ($Type*)null;
    return ($Type*)((char*)inner - inner_offset($Type));
}

<*
 For internal usage.

 @require is_mine(inner, $Type) : "the inner is not of this type"
*>
macro must_from_inner(Inner* inner, $Type) => ($Type*)((char*)inner - inner_offset($Type));

<*
 For internal usage.
*>
macro from_slot(Slot* s, $Type) => from_inner(s.peek(), $Type);

<*
 For internal usage.
*>
macro must_from_slot(Slot* s, $Type) => must_from_inner(s.peek(), $Type);

<*
 For internal usage.
*>
macro move_from_slot(Slot* s, $Type)
{
    Inner* inner = s.peek();
    if (!is_mine(inner, $Type)) return ($Type*)null;
    s.take();
    return ($Type*)((char*)inner - inner_offset($Type));
}

<*
 For internal usage.
*>
fn void Inner.repoint_to(&self, Inner* to) @inline
    => self.link = any_make(to, self.link.type);

<*
 For internal usage.
*>
fn Inner* Inner.points_to(&self) @inline => (Inner*)self.link.ptr;

<*
 For internal usage.
*>
fn bool is_linked(Inner* inner) @inline => inner != null && inner.points_to() != null;

<*
 For internal usage.
*>
fn void reset(Inner* inner) @inline
{
    if (!inner) return;
    inner.repoint_to(null);
}


//==============================================================================
// Part 3 of 3: hidden. `module mtk::inner @private;` — the section default, so no
// declaration below names the attribute. Nothing outside this module can reach
// what is here; the crossings above reach it because a macro body resolves
// against its defining module. `@local` does NOT work here and was measured:
// with it, this file's own macros fail to resolve the name.
//==============================================================================
module mtk::inner @private;

<*
 For internal usage.
*>
macro usz inner_offset($Type)
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


//----------------------
// Little-endian imports
//----------------------
import mtk;
