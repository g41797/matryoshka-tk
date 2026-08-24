<*
 The intrusive stack. Part 8, last-in first-out half.

 Part 8.1 permits it in the plural — *ordering primitives*, as many as Part 11
 needs, since 003. `queue.c3`'s header carries the argument. V2.

 **R2 and R11.** The pool keeps one of these per identity, and it is the only
 `InnerStack` in the port. It never crosses the public surface: what a hook
 receives is always an `InnerQueue` — R13, §5.4.

 Four operations, against the queue's seven. There is no walker, because
 nothing walks a free list and Part 8.4 is a SHOULD; there is no splice,
 because a stack keeps no tail and `Pool.close` wants a queue anyway.

 **There is no Slot-shaped insert, and the reason is R13 — 3TK-12's P6.**
 §5.1 kept `push_slot` for *the put hook's `extra`*, and the measurement found
 that reason belongs to the queue: `extra` is an `InnerQueue`, and the hook that
 fills it is application code. `InnerStack` never crosses a public signature, so
 no application can reach it; the pool does not call a Slot-shaped insert either
 — `take_back` empties the Slot itself and calls `push`. An operation with no
 caller it could ever acquire was deleted 2026-08-24, on the owner's
 instruction. `InnerQueue.push_back_slot` stays: Part 12.5's composite mechanism
 is what needs it.

 **Why the pool reuses last-in first-out, which is a behaviour change and not
 a translation.** The old code was first-in first-out — `NodeList.push_back`
 with `pop_front`. The reason for reversing it is not cache locality and not
 performance. It is defect surfacing, and it is the owner's, recorded here
 because a later reader who takes the stack for an arbitrary choice will
 quietly change it back to a queue:

   Under first-in first-out the item just given back goes to the BACK of the
   free list. Code still holding a pointer to it after `put` writes to an item
   nobody has re-taken, so nothing conflicts. If the put hook did not reset the
   contents, the stale writer reads data that still looks plausible and never
   trips. The item is handed out again much later, and the damage appears far
   from its cause.

   Under last-in first-out the item is on top and the NEXT `get` gives it
   straight to a new owner. The stale writer and the new owner write the same
   item at the same moment, so the defect appears next to its cause.

 It is the same reasoning as not quarantining freed memory: reuse the hottest
 item, so a stale pointer meets a live second owner immediately.

 **No caller is entitled to the order, and that is what keeps the property
 useful.** Part 11.10 MUST already says the pool promises nothing about which
 item comes back, and Part 11.7 stays silent on order — R11. It says the
 container is a stack; it does not promise most-recently-returned-first.

 **The self-link.** As in `queue.c3`: the bottom item points at itself, never
 at null, and `pop` recognises the sole item by `h.link == h`.

 Part 19.4: nothing here can fail. A pop from an empty stack returns null.
*>
module mtk;

<*
 The stack header. Part 8.1.

 `top` and a kept count, so `len` is O(1) — the same reason the queue keeps
 one, and Part 12.4's hint is read from it under the lock.

 There is no `tail`. That is what makes `Pool.close`'s flatten O(n) rather than
 a splice, and R12 accepted the cost: it happens once, on a pool going down,
 and the loop repairs every item's self-link on the way, which a splice would
 have had to walk and do anyway.
*>
struct InnerStack
{
    Inner* top;
    usz    count;
}

<*
 The insert guard. Tier 2, one check — the same guard the queue carries, and
 for the same reason. R6b, §3.
*>
macro InnerStack.@guard_insert(&self, Handle h)
{
    @check(h != null, "insert of a null handle");
    @check(!is_linked(h), "Part 8.7: the item is already on a chain");
}

// --- Questions ----------------------------------------------------------------

<*
 Part 8.2: is it empty.
*>
fn bool InnerStack.is_empty(&self) @inline => self.count == 0;

<*
 Part 8.2: how many. O(1).
*>
fn usz InnerStack.len(&self) @inline => self.count;

// --- Adding --------------------------------------------------------------------

<*
 Part 8.2: add on top.

 An item pushed onto an empty stack is the bottom, so it is self-linked.
 Otherwise it points at the item it covers.
*>
fn void InnerStack.push(&self, Handle h)
{
    self.@guard_insert(h);
    h.link = self.top ? self.top : h;
    self.top = h;
    self.count++;
}

// --- Removing ---------------------------------------------------------------------

<*
 Part 8.2: take from the top. Null on an empty stack — an answer, not a fault.

 The returned item's link is cleared. Part 8.8.
*>
fn Handle InnerStack.pop(&self)
{
    Handle h = self.top;
    if (!h) return null;
    self.top = (h.link == h) ? null : h.link;
    self.count--;
    reset(h);
    return h;
}
