<*
 The intrusive stack. Last-in first-out.

 The pool's private storage. It never crosses the public surface.
 Four operations: no walker, and no splice.
 The order is not promised. No caller is entitled to which item comes back.
 Every chain ends at an item pointing at itself, never at null.
 Nothing here can fail. A pop from an empty stack returns null.
*>
// [3tk: P6, R2, R11, R13, R14, V2, Part 8, Part 8.1, Part 8.4, Part 11.7, Part 11.10, Part 19.4]
module mtk;

<*
 The stack header.

 The count is kept, so `len()` is O(1).
 There is no tail, so flattening the stack is O(n).
*>
// [3tk: R12, Part 8.1, Part 12.4]
struct InnerStack
{
    Inner* top;
    usz    count;
}

<*
 The insert guard.

 Refuses a null handle, and an item already on any chain.
 Tier 2, so it is gone from a fast build.
*>
// [3tk: R6b, Part 8.6]
macro InnerStack.@guard_insert(&self, Handle h)
{
    @check(h != null, "insert of a null handle");
    // [3tk: Part 8.7]
    @check(!is_linked(h), "the item is already on a chain");
}

// --- Questions ----------------------------------------------------------------

<*
 True if the stack holds nothing.
*>
// [3tk: Part 8.2]
fn bool InnerStack.is_empty(&self) @inline => self.count == 0;

<*
 How many items the stack holds. O(1).
*>
// [3tk: Part 8.2, Part 11.7]
fn usz InnerStack.len(&self) @inline => self.count;

// --- Adding --------------------------------------------------------------------

<*
 Adds the item on top.

 There is no Slot-shaped insert.
*>
// [3tk: P6, R13, Part 8.2]
fn void InnerStack.push(&self, Handle h)
{
    self.@guard_insert(h);
    h.repoint_to(self.top ? self.top : h);
    self.top = h;
    self.count++;
}

// --- Removing ---------------------------------------------------------------------

<*
 Takes the item on top.

 Null on an empty stack, which is an answer and not a fault.
 The returned item's chain link is cleared.
*>
// [3tk: Part 8.2, Part 8.8, Part 19.4]
fn Handle InnerStack.pop(&self)
{
    Handle h = self.top;
    if (!h) return null;
    self.top = (h.points_to() == h) ? null : h.points_to();
    self.count--;
    reset(h);
    return h;
}
