// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

<*
 Every crossing between a typed pointer and an `Inner*` lives in one file.

 `to_handle` goes from your pointer to the handle, an `Inner*`.
 Null in, null out.
 `from_handle` goes from an `Inner*` back to `$Type*`, and is null on an identity mismatch.
 A mismatch is an answer, not a failure.
 `must_from_handle` is the same, and it aborts on a mismatch.
 The abort names your line.
 The same three take the item from a Slot, and five of them appear again as methods.
 `from_slot` looks, and the Slot is unchanged.
 `move_from_slot` takes, and on success the Slot is left empty.
 None of these moves an item.
 Reading an identity and casting a pointer leave every container alone.
 No alias to declare, no instantiation, no registration.
*>
// [3tk: D2, H0, Q2, E6, V19, Part 7, Part 7.1, Part 7.2, Part 7.4, Part 7.5, Part 15.5]
module mtk::helper;
import mtk;
import mtk::inner;

<*
 True when the handle names `$Type`.

 False for a null handle.
 False for an item whose `init` was never called.

 @param $Type : "the outer type"
*>
// [3tk: Part 5.5, Part 7.2]
macro bool is_mine(Inner* h, $Type) => h != null && h.link.type == $Type::typeid;

<*
 Writes the identity into the embedded `Inner`.

 Call it once, before first use.
 An item that was never initialized carries no identity.

 @param item : "a pointer to the outer"
 @require $defined($Typeof(*item)::members) : "not a struct that embeds an Inner"
*>
// [3tk: H8, Part 5.4, Part 5.5, Part 7.2]
macro void init(item)
{
    Inner* n = (Inner*)((char*)item + mtk::inner::inner_offset($Typeof(*item)));
    n.link = any_make(null, $Typeof(*item)::typeid);
}

<*
 From your pointer to the handle, an `Inner*`.

 Null in, null out.
 Reading an identity and casting a pointer leave every container alone.

 @param item : "a pointer to the outer, or null"
 @require $defined($Typeof(*item)::members) : "not a struct that embeds an Inner"
*>
// [3tk: H5, Part 7.2]
macro Inner* to_handle(item)
    => item ? (Inner*)((char*)item + mtk::inner::inner_offset($Typeof(*item))) : null;

<*
 From an `Inner*` back to `$Type*`.

 Null on an identity mismatch.
 A mismatch is an answer, not a failure.

 @param $Type : "the outer type expected"
*>
// [3tk: H5, Part 6.2, Part 6.3]
macro from_handle(Inner* h, $Type)
{
    if (!is_mine(h, $Type)) return ($Type*)null;
    return ($Type*)((char*)h - mtk::inner::inner_offset($Type));
}

<*
 Same as `from_handle()`.

 It aborts on a mismatch.
 Use it where a mismatch would be your own defect.
 The abort names your line.
 Under `--safe=no` it is gone.

 @param $Type : "the outer type asserted"
 @require is_mine(h, $Type) : "the handle is not of this type"
*>
// [3tk: H7, Part 5.5, Part 6.3, Part 15.5]
macro must_from_handle(Inner* h, $Type) => ($Type*)((char*)h - mtk::inner::inner_offset($Type));

<*
 Same as `from_handle()`, taking the item from a Slot.

 It looks. The Slot is unchanged.

 @param $Type : "the outer type expected"
*>
// [3tk: Part 7.2]
macro from_slot(Slot* s, $Type) => from_handle(s.peek(), $Type);

<*
 Same as `from_slot()`.

 It looks, and aborts on failure.
 The Slot is unchanged.

 @param $Type : "the outer type asserted"
*>
// [3tk: Part 7.2]
macro must_from_slot(Slot* s, $Type) => must_from_handle(s.peek(), $Type);

<*
 Same as `from_slot()`, and it takes.

 On success the Slot is left empty.
 On failure it is unchanged.

 @param $Type : "the outer type expected"
*>
// [3tk: H6, Part 7.2, Part 9.2 rule 4]
macro move_from_slot(Slot* s, $Type)
{
    Inner* h = s.peek();
    if (!is_mine(h, $Type)) return ($Type*)null;
    s.take();
    return ($Type*)((char*)h - mtk::inner::inner_offset($Type));
}

<*
 Same as `from_handle()`, as a method on the handle.

 @param $Type : "the outer type expected"
*>
macro Inner.to(&self, $Type) => from_handle((Inner*)self, $Type);

<*
 Same as `must_from_handle()`, as a method on the handle.

 @param $Type : "the outer type asserted"
 @require is_mine((Inner*)self, $Type) : "the handle is not of this type"
*>
macro Inner.as(&self, $Type) => ($Type*)((char*)self - mtk::inner::inner_offset($Type));

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
