// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

<*
 The intrusive queue. First-in first-out.

 The transfer container.
 Nothing here allocates, and every operation is O(1).
 The count is kept, so `len` is O(1).
 `push_back` adds at the back.
 There is no front insert.
 `pop_front` takes the item at the front, and null on an empty queue is an answer and not a fault.
 `append_queue` moves every item of another queue onto the back of this one, in O(1).
 `iter` and `next` are a walker, taken from the queue.
 Removing the current item during a walk is not supported.
 Every chain ends at an item pointing at itself, never at null.
 Nothing in the queue can fail.
*>
module mtk::queue;
import mtk;
import mtk::inner;

<*
 The intrusive queue. First-in first-out.

 The transfer container.
 Nothing here allocates, and every operation is O(1).
 Every chain ends at an item pointing at itself, never at null.
 Nothing in the queue can fail.
 The count is kept, so `len` is O(1).
*>
// [3tk: R2, R6b, R13, V2, Part 8, Part 8.1, Part 8.5, Part 8.10, Part 19.4]
// [3tk: Part 8.1, Part 11.7]
struct InnerQueue
{
    Inner* head;
    Inner* tail;
    usz    count;
}

<*
 A walker over a queue.

 Exhausted when `next` returns null.
 Removing the current item during a walk is not supported.
*>
// [3tk: V18, Part 6.5, Part 8.4]
struct InnerQueueIterator
{
    Inner* cur;
}

// --- The guard -----------------------------------------------------------------

<*
 The insert guard.

 A null handle is a defect.
 An item already on any chain is a defect.
 Both are gone from a fast build.
*>
// [3tk: R6b, V4, Part 8.6]
macro InnerQueue.@guard_insert(&self, Inner* h)
{
    mtk::@check(h != null, "insert of a null handle");
    // [3tk: Part 8.7]
    mtk::@check(!mtk::inner::is_linked(h), "the item is already on a chain");
}

// --- Questions ----------------------------------------------------------------

<*
 True if the queue holds nothing.
*>
// [3tk: Part 8.2]
fn bool InnerQueue.is_empty(&self) @inline => self.count == 0;

<*
 How many items the queue holds. O(1).
*>
// [3tk: Part 8.2, Part 11.7]
fn usz InnerQueue.len(&self) @inline => self.count;

<*
 A walker, taken from the queue.
*>
// [3tk: Part 8.4]
fn InnerQueueIterator InnerQueue.iter(&self) @inline => { .cur = self.head };

<*
 The next handle, or null when the walk is exhausted.
*>
// [3tk: Part 8.4]
fn Inner* InnerQueueIterator.next(&self)
{
    Inner* n = self.cur;
    if (n) self.cur = (n.points_to() == n) ? null : n.points_to();
    return n;
}

// --- Adding --------------------------------------------------------------------

<*
 Adds at the back.

 There is no front insert.
*>
// [3tk: R15, Part 8.2]
fn void InnerQueue.push_back(&self, Inner* h)
{
    self.@guard_insert(h);
    h.repoint_to(h);
    if (self.tail) { self.tail.repoint_to(h); } else { self.head = h; }
    self.tail = h;
    self.count++;
}

<*
 Same as `push_back()`, taking the item from a Slot.

 The Slot is empty afterwards.
 An empty Slot is a defect, not a no-op.
*>
// [3tk: V3, Part 8.2, Part 9.2, Part 12.5]
fn void InnerQueue.push_back_slot(&self, Slot* s)
{
    mtk::@check(s.is_full(), "push_back_slot from an empty Slot");
    if (s.is_empty()) return;
    self.push_back(s.take());
}

// --- Removing ---------------------------------------------------------------------

<*
 Takes the item at the front.

 Null on an empty queue, which is an answer and not a fault.
 The returned item's chain link is cleared.
*>
// [3tk: Part 8.2, Part 8.8, Part 19.4]
fn Inner* InnerQueue.pop_front(&self)
{
    Inner* h = self.head;
    if (!h) return null;
    if (self.head == self.tail)
    {
        self.head = null;
        self.tail = null;
    }
    else
    {
        self.head = h.points_to();
    }
    self.count--;
    mtk::inner::reset(h);
    return h;
}

<*
 Takes everything the queue holds, as one flat queue. O(1).

 The queue is empty afterwards.
*>
// [3tk: Part 8.2]
fn InnerQueue InnerQueue.take(&self) @inline
{
    InnerQueue out = *self;
    self.head = null;
    self.tail = null;
    self.count = 0;
    return out;
}

// --- Moving ------------------------------------------------------------------------

<*
 Moves every item of another queue onto the back of this one. O(1).

 That queue is empty afterwards.
 A queue moved onto itself is a defect.

 @param other : "the queue to empty onto this one; empty afterwards"
*>
// [3tk: Part 8.2, Part 8.9]
fn void InnerQueue.append_queue(&self, InnerQueue* other)
{
    mtk::@check(other != null, "append_queue with a null queue");
    // [3tk: Part 8.9]
    mtk::@check(other != self, "a queue cannot be moved onto itself");
    if (other == self) return;
    if (other.is_empty()) return;

    if (self.tail) { self.tail.repoint_to(other.head); } else { self.head = other.head; }
    self.tail = other.tail;
    self.count += other.count;

    other.head = null;
    other.tail = null;
    other.count = 0;
}
