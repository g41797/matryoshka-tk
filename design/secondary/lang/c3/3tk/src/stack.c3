// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

<*
 The intrusive stack. Last-in first-out.

 The storage container.
 Where the queue carries outers across, the stack holds them still.
 The pool keeps one per identity, and it is the only stack 3tk owns.
 No 3tk signature passes one: the four that take a container take an `InnerQueue*`.
 A caller who wants a stack declares one.
 Four operations: no walker, and no splice.
 The order is not promised.
 No caller is entitled to which outer comes back.
 Every chain ends at an inner pointing at itself, never at null.
 Nothing in the stack can fail.
 The count is kept, so `len` is O(1).
 There is no tail, so flattening the stack is O(n).
*>
module mtk::stack;
import mtk;
import mtk::inner;

<*
 The intrusive stack. Last-in first-out.

 The storage container.
 Where the queue carries outers across, the stack holds them still.
 The pool keeps one per identity, and it is the only stack 3tk owns.
 No 3tk signature passes one: the four that take a container take an `InnerQueue*`.
 Four operations: no walker, and no splice.
 The order is not promised.
 No caller is entitled to which outer comes back.
 Every chain ends at an inner pointing at itself, never at null.
 Nothing in the stack can fail.
 The count is kept, so `len` is O(1).
 There is no tail, so flattening the stack is O(n).
*>
// [3tk: P6, R2, R11, R13, R14, V2, Part 8, Part 8.1, Part 8.4, Part 11.7, Part 11.10, Part 19.4]
// [3tk: R12, Part 8.1, Part 12.4]
struct InnerStack
{
    Inner* top;
    usz    count;
}

<*
 The insert guard.

 A null inner is a defect.
 An outer already on any chain is a defect.
 Both are gone from a fast build.
*>
// [3tk: R6b, Part 8.6]
macro InnerStack.@guard_insert(&self, Inner* inner)
{
    mtk::@check(inner != null, "insert of a null inner");
    // [3tk: Part 8.7]
    mtk::@check(!mtk::inner::is_linked(inner), "the outer is already on a chain");
}

// --- Questions ----------------------------------------------------------------

<*
 True if the stack holds nothing.
*>
// [3tk: Part 8.2]
fn bool InnerStack.is_empty(&self) @inline => self.count == 0;

<*
 How many outers the stack holds. O(1).
*>
// [3tk: Part 8.2, Part 11.7]
fn usz InnerStack.len(&self) @inline => self.count;

// --- Adding --------------------------------------------------------------------

<*
 Adds on top.

 There is no Slot-shaped insert.
*>
// [3tk: P6, R13, Part 8.2]
fn void InnerStack.push(&self, Inner* inner)
{
    self.@guard_insert(inner);
    inner.repoint_to(self.top ? self.top : inner);
    self.top = inner;
    self.count++;
}

// --- Removing ---------------------------------------------------------------------

<*
 Takes the outer on top.

 Null on an empty stack.
 The returned outer's chain link is cleared.
*>
// [3tk: Part 8.2, Part 8.8, Part 19.4]
fn Inner* InnerStack.pop(&self)
{
    Inner* inner = self.top;
    if (!inner) return null;
    self.top = (inner.points_to() == inner) ? null : inner.points_to();
    self.count--;
    mtk::inner::reset(inner);
    return inner;
}
