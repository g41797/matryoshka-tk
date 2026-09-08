// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//==============================================================================
// The core, section 1 of 2: the inner, the Slot, the link, and the crossings.
// No module block: `mtk.c3` carries the description of `module mtk`, and a
// module has one description however many sections it is written in.
//
// The file is written in three parts, in this order:
//
//   1. `module mtk;`           yours, and there is no other way to write it
//   2. `module mtk;`           public, and not yours — the helper is your way in
//   3. `module mtk @private;`  hidden from every other module
//
// Part 1 is the whole of what a user calls directly, and it is there because
// the helper cannot replace it: you embed the field, you read the Slot, and a
// dispatch switch reads an identity before it knows the type. Everything in
// part 2 has a member of `OuterHelper` that does it for you.
//
// A declaration in part 2 or 3 carries `// For internal usage.`, its `[3tk:]`
// marks, and nothing else. No `<* *>` block, which is the only visibility
// marker C3 offers a reader: the reference never receives such a declaration,
// and the docs site shows it as a bare signature. Part 2 is public because the
// compiler leaves no choice — `@private` and `@local` are both ignored on
// method declarations, and `InnerStack` calls two free functions from
// `mtk::pool`, which is a submodule and cannot see a `@private` of this module.
//==============================================================================
// [3tk: D1 to D16, R1 to R15, Part 4, Part 9, Part 10.1]
// [3tk: R5, R6, R6b, D3, V12, Part 4.2, Part 4.4a, Part 5]
// [3tk: D2, H0, Q2, E6, V19, Part 7, Part 7.1, Part 7.2, Part 7.4, Part 7.5, Part 15.5]
module mtk;

<*
 `Inner` is the field you embed.
 The chain link and the identity, in one.

 A small part of this module is yours to call directly: the Slot's five operations, the identity, and the five crossings written as methods.
 Everything else goes through the helper, and says so with `// For internal usage.` in place of a description.
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
// [3tk: D5, Part 9.1, Part 9.2 rule 1, Part 9.2 rule 2]
typedef Slot = Inner*;

<*
 The identity of the outer this inner is embedded in.

 Null for an inner that was never stamped.
 It exists so that no user ever writes `inner.link.type`.
 The helper cannot do this one for you: a dispatch switch reads the identity before it knows the type.
*>
// [3tk: Part 3.5, Part 4.4]
fn typeid Inner.outer_tid(&self) @inline => self.link.type;

// --- The Slot's five operations ----------------------------------------------

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

// --- The five crossings back to your type ------------------------------------

<*
 From an `Inner*` back to `$Type*`.

 Null on an identity mismatch.
 A mismatch is an answer, not a failure.

 @param $Type : "the outer type expected"
*>
// [3tk: H5, Part 6.2, Part 6.3, Part 7.2]
macro Inner.to(&self, $Type) => from_inner((Inner*)self, $Type);

<*
 From an `Inner*` back to `$Type*`, and it aborts on a mismatch.

 Use it where a mismatch would be your own defect.
 The abort names your line.

 @param $Type : "the outer type asserted"
 @require is_mine((Inner*)self, $Type) : "the inner is not of this type"
*>
// [3tk: H7, Part 6.3, Part 7.2, Part 15.5]
macro Inner.as(&self, $Type) => ($Type*)((char*)self - inner_offset($Type));

<*
 From the Slot back to `$Type*`. It looks, and the Slot is unchanged.

 Null on an identity mismatch.
 A mismatch is an answer, not a failure.

 @param $Type : "the outer type expected"
*>
// [3tk: Part 7.2]
macro Slot.to(&self, $Type) => from_slot(self, $Type);

<*
 From the Slot back to `$Type*`, and it aborts on a mismatch. The Slot is unchanged.

 Use it where a mismatch would be your own defect.
 The abort names your line.

 @param $Type : "the outer type asserted"
*>
// [3tk: Part 7.2, Part 15.5]
macro Slot.must(&self, $Type) => must_from_slot(self, $Type);

<*
 From the Slot back to `$Type*`, and it takes.

 On success the Slot is left empty.
 On failure it is unchanged.

 @param $Type : "the outer type expected"
*>
// [3tk: H6, Part 7.2, Part 9.2 rule 4]
macro Slot.move(&self, $Type) => move_from_slot(self, $Type);


//==============================================================================
// Part 2 of 3: public, and not yours. Still `module mtk;`.
//
// Every declaration below has a member of `OuterHelper` that does it for you —
// `stamp`, `inner`, `look`, `must_look`, `take`, `must_take`, `linked` — or is
// a chain primitive only the queue and the stack may touch. Measured across
// `examples/`: two of these thirteen are named, once each.
//
// `Inner.link` is public and writable besides, so this is a stated boundary and
// not a locked one.
//==============================================================================

// For internal usage.
// [3tk: Part 5.5, Part 7.2]
macro bool is_mine(Inner* inner, $Type) => inner != null && inner.link.type == $Type::typeid;

<*
 @param outer : "a pointer to the outer"
 @require $defined($Typeof(*outer)::members) : "not a struct that embeds an Inner"
*>
// For internal usage.
// [3tk: H8, HR-5, Part 5.1, Part 5.4, Part 5.5, Part 7.2]
macro void stamp(outer)
{
    Inner* inner = (Inner*)((char*)outer + inner_offset($Typeof(*outer)));
    inner.link = any_make(inner.link.ptr, $Typeof(*outer)::typeid);
}

<*
 @param outer : "a pointer to the outer, or null"
 @require $defined($Typeof(*outer)::members) : "not a struct that embeds an Inner"
*>
// For internal usage.
// [3tk: H5, Part 7.2]
macro Inner* to_inner(outer)
    => outer ? (Inner*)((char*)outer + inner_offset($Typeof(*outer))) : null;

// For internal usage.
// [3tk: H5, Part 6.2, Part 6.3]
macro from_inner(Inner* inner, $Type)
{
    if (!is_mine(inner, $Type)) return ($Type*)null;
    return ($Type*)((char*)inner - inner_offset($Type));
}

<*
 @param $Type : "the outer type asserted"
 @require is_mine(inner, $Type) : "the inner is not of this type"
*>
// For internal usage.
// [3tk: H7, Part 5.5, Part 6.3, Part 15.5]
macro must_from_inner(Inner* inner, $Type) => ($Type*)((char*)inner - inner_offset($Type));

// For internal usage.
// [3tk: Part 7.2]
macro from_slot(Slot* s, $Type) => from_inner(s.peek(), $Type);

// For internal usage.
// [3tk: Part 7.2]
macro must_from_slot(Slot* s, $Type) => must_from_inner(s.peek(), $Type);

// For internal usage.
// [3tk: H6, Part 7.2, Part 9.2 rule 4]
macro move_from_slot(Slot* s, $Type)
{
    Inner* inner = s.peek();
    if (!is_mine(inner, $Type)) return ($Type*)null;
    s.take();
    return ($Type*)((char*)inner - inner_offset($Type));
}

// For internal usage.
// [3tk: R6b, Part 4.4, Part 4.4a]
fn void Inner.repoint_to(&self, Inner* to) @inline
    => self.link = any_make(to, self.link.type);

// For internal usage.
// [3tk: R6b, Part 4.4, Part 4.4a]
fn Inner* Inner.points_to(&self) @inline => (Inner*)self.link.ptr;

// For internal usage.
// [3tk: R6b, D12, V4, V5, Part 4.3, Part 8.6, Part 8.7]
fn bool is_linked(Inner* inner) @inline => inner != null && inner.points_to() != null;

// For internal usage.
// [3tk: Part 4.3, Part 5.4, Part 8.8]
fn void reset(Inner* inner) @inline
{
    if (!inner) return;
    inner.repoint_to(null);
}


//==============================================================================
// Part 3 of 3: hidden. `module mtk @private;` — the section default, so no
// declaration below names the attribute. Nothing outside this module can reach
// what is here; the crossings above reach it because a macro body resolves
// against its defining module. `@local` does NOT work here and was measured:
// with it, this file's own macros fail to resolve the name.
//==============================================================================
module mtk @private;

// For internal usage.
// [3tk: Part 4.3, Part 4.4, Part 7.4]
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
