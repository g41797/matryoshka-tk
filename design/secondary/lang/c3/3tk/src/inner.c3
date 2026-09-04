// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

<*
 The inner, the Slot, and the link.

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
*>
module mtk::inner;
import mtk;

<*
 The inner, the Slot, the link test, and the port's check macro.

 The field you embed.
 The chain link and the identity, in one.
*>
// [3tk: D1 to D16, R1 to R15, Part 4, Part 9, Part 10.1]
// [3tk: R5, R6, R6b, D3, V12, Part 4.2, Part 5]
struct Inner
{
    any link;
}

// --- Writing and reading the link -------------------------------------------

<*
 Keeps the identity, swaps the chain link.

 The containers call it.

 @param to : "the inner this one now links to; itself, if it is the end"
*>
// [3tk: R6b]
fn void Inner.repoint_to(&self, Inner* to) @inline
    => self.link = any_make(to, self.link.type);

<*
 The inner this one links to.

 Null if it is on no chain.
*>
// [3tk: R6b]
fn Inner* Inner.points_to(&self) @inline => (Inner*)self.link.ptr;

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
*>
// [3tk: R6b, D12, V4, V5, Part 8.6, Part 8.7]
fn bool is_linked(Inner* inner) @inline => inner != null && inner.points_to() != null;

<*
 Clears the chain link so the outer can be inserted again.

 It clears the link and not the identity.
 Every removal in the queue and the stack calls it for you.
*>
// [3tk: Part 5.4, Part 8.8]
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

 @param $Type : "the outer type"
*>
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

<*
 Finds the `Allocator` field at compile time.

 A type with no `Allocator` field does not compile.
 The message tells you to take the plain helper instead.
 A type with two `Allocator` fields does not compile.
 The message names your type.

 @param $Type : "the outer type"
*>
// [3tk: D3, Part 7.4]
macro usz required_alloc_offset($Type)
{
    var $off = -1;
    var $seen = 0;
    $foreach $m : $Type::members:
        $if $m.type == Allocator:
            $off = $m.offset;
            $seen = $seen + 1;
        $endif
    $endforeach
    $assert $seen != 0 : "type " +++ $Type::name +++ " has no Allocator field; use mtk::helper instead of mtk::managed";
    // [3tk: Part 4.4]
    $assert $seen == 1 : "type " +++ $Type::name +++ " has more than one Allocator field; exactly one is allowed";
    return $off;
}
