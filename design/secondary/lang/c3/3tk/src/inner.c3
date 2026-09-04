// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

<*
 The inner, the handle, the Slot, and the link.

 `Inner` is the field you embed.
 The chain link and the identity, in one.
 The identity sits in the same field as the chain link.
 The identity says what the outer type is.
 A pointer to an embedded `Inner` is one item, with the type forgotten.
 That pointer is what the books call a handle, and 3tk transports nothing else.
 It is spelled `Inner*`, because that is all it is.
 `Slot` is a box that holds one handle, or nothing.
 A Slot starts empty.

 The Slot is how the toolkit tells you where an item went.
 Read the Slot after every call that gives or takes an item.

 The chain link is the other half of `Inner`.
 `reset` clears the chain link and not the identity.
 Every chain ends at an item pointing at itself, never at null.
 That is what makes `is_linked` exact.
*>
module mtk::inner;
import mtk;

<*
 The inner, the handle, the Slot, the link test, and the port's check macro.

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

 @param to : "the handle this item now links to; itself, if it is the end"
*>
// [3tk: R6b]
fn void Inner.repoint_to(&self, Inner* to) @inline
    => self.link = any_make(to, self.link.type);

<*
 The item this one links to.

 Null if it is on no chain.
*>
// [3tk: R6b]
fn Inner* Inner.points_to(&self) @inline => (Inner*)self.link.ptr;

<*
 A box that holds one handle, or nothing.

 Zero or one item.
 A Slot starts empty.
*>
// [3tk: D5, Part 9.1, Part 9.2 rule 1, Part 9.2 rule 2]
typedef Slot = Inner*;

// --- The link test, and the repair -------------------------------------------

<*
 True when the handle is on some chain.

 Exact, and O(1).
 False for a null handle.
*>
// [3tk: R6b, D12, V4, V5, Part 8.6, Part 8.7]
fn bool is_linked(Inner* h) @inline => h != null && h.points_to() != null;

<*
 Clears the chain link so the item can be inserted again.

 It clears the link and not the identity.
 Every removal in the queue and the stack calls it for you.
*>
// [3tk: Part 5.4, Part 8.8]
fn void reset(Inner* h) @inline
{
    if (!h) return;
    h.repoint_to(null);
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
 Take the handle out and clear the Slot.

 Null on an empty Slot.
*>
// [3tk: Part 9.2 rule 5, Part 9.9]
fn Inner* Slot.take(&self) @inline
{
    Inner* h = (Inner*)*self;
    *self = (Slot)(Inner*)null;
    return h;
}

<*
 Put a handle in.

 A null handle is a defect.
 Overwriting a full Slot is a defect.

 @param h : "the handle to place; must not be null"
*>
// [3tk: D6, Part 9.2 rule 1, Part 9.9]
fn void Slot.fill(&self, Inner* h) @inline
{
    mtk::@check(h != null, "Slot.fill with a null handle");
    // [3tk: Part 9.2 rule 1]
    mtk::@check(self.is_empty(), "never overwrite a full Slot");
    *self = (Slot)h;
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
    $assert $seen != 0 : "type " +++ $Type::name +++ " has no Inner field; it cannot be a Matryoshka item";
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
