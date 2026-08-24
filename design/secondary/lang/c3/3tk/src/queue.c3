<*
 The intrusive queue. Part 8, first-in first-out half.

 **R2: there is no general-purpose list in this port.** `NodeList` reproduced
 Zig's `DoublyLinkedList` and offered sixteen operations; the audit of §1.1
 found that nine of them had no caller in `3tk/src/` at all. What the port
 actually needs is two ordering primitives: a queue for the mailbox, and a
 stack for the pool. This is the queue.

 **003 made that a legal reading of Part 8.1 rather than a deviation from it.**
 002 said *a doubly-linked list*, singular, and R2 argued against the
 specification's own noun; 8.1 now says *ordering primitives*, as many as Part
 11 needs, and shows one general list and two narrow ones side by side. V2.
 `stack.c3` is the other half.

 Seven operations. Nothing here allocates, the item is the node, and every
 operation is O(1) — including `append_queue`, which splices, and including
 every insert in every build mode, because R6b deleted the walk that used to
 make a checking build's insert O(n).

 **It is also the port's TRANSFER container — R13.** What crosses the public
 surface is always an `InnerQueue`: `Mailbox.receive_all`, `Mailbox.close`,
 `PoolHooks.on_put`'s `extra`, `PoolHooks.on_close`'s `remaining`. A hook
 receives a batch to walk and release in order, not a store to reuse from.
 `InnerStack` is the pool's private storage and never appears on that surface.

 **The self-link.** Every chain here ends at an item pointing at itself, never
 at null. `inner.c3` states the invariant; this file maintains it. Every walk
 in this file ends at `n.link == n`, and a walk written without that test does
 not terminate.

 Part 8.5: this is the layer where the checks live. There is no raw queue
 primitive below it — C3's stdlib has no intrusive list, so Part 8.10's
 bridge has no other side and is dropped.

 Part 19.4: no operation here can fail. There is no fault type in this file.
 A take from an empty queue returns null; that is an answer, not an error.
*>
module mtk;

<*
 The queue header. Part 8.1.

 The count is kept, so `len` is O(1). Part 11.7 asks a container for a separate
 count only where its length is not, and this one's is.
*>
struct InnerQueue
{
    Inner* head;
    Inner* tail;
    usz    count;
}

<*
 A walker. Part 8.4.

 Taken from the queue, yields handles one at a time, exhausted when it returns
 null. Removing the current item during a walk is NOT supported — unchanged.

 It has one caller outside the tests: `t_identity.c3`'s heterogeneous walk,
 which is Part 6.5's demonstration and the one place the toolkit shows what a
 type-erased container is for. **The dispatch table itself is the
 application's**, not something the toolkit ships — 003 says so in a sentence
 002 left to inference, V18, so this port ships nothing there and has skipped
 nothing. The stack gets no walker: nothing walks a free
 list, and Part 8.4 is a SHOULD.
*>
struct InnerQueueIterator
{
    Inner* cur;
}

// --- The guard -----------------------------------------------------------------

<*
 The insert guard. Tier 2, and after R6b it is ONE check rather than two.

 002's Part 8.6 used to ask for a pair — the link test for a different
 container, the O(n) walk for an item alone on this one — and said in so many
 words that neither alone was enough. With the self-link the link test is exact and
 refuses an item on ANY chain, this container or another, so it catches
 everything both halves caught. Part 8.6 is deleted from the specification and
 `contains` is deleted from the port.

 What that buys, beyond the deletion: the guard moves from tier 3 to tier 2, so
 an ordinary safe build carries it at O(1) instead of paying O(n) per insert.
*>
macro InnerQueue.@guard_insert(&self, Handle h)
{
    @check(h != null, "insert of a null handle");
    @check(!is_linked(h), "Part 8.7: the item is already on a chain");
}

// --- Questions ----------------------------------------------------------------

<*
 Part 8.2: is it empty.
*>
fn bool InnerQueue.is_empty(&self) @inline => self.count == 0;

<*
 Part 8.2: how many. O(1).
*>
fn usz InnerQueue.len(&self) @inline => self.count;

<*
 Part 8.4: a walker, taken from the queue.
*>
fn InnerQueueIterator InnerQueue.iter(&self) @inline => { .cur = self.head };

<*
 The next handle, or null when the walk is exhausted.

 **The end test is `n.link == n`, and it is not optional.** The last item of a
 chain points at itself, so a walker that followed the link blindly would hand
 the last item back for ever. The field is named `link` and not `next` for
 exactly this reason — on the last item it is not the next thing.
*>
fn Handle InnerQueueIterator.next(&self)
{
    Inner* n = self.cur;
    if (n) self.cur = (n.link == n) ? null : n.link;
    return n;
}

// --- Adding --------------------------------------------------------------------

<*
 Part 8.2: add at the back.

 The new item is the tail, so it is self-linked. The old tail stops being
 self-linked and points at it.

 There is no `push_front` — R15 dropped `Pool.put_all`, which was its only
 caller once the mailbox's out-of-band anchor was gone, and with it the queue's
 last front insert.
*>
fn void InnerQueue.push_back(&self, Handle h)
{
    self.@guard_insert(h);
    h.link = h;
    if (self.tail) { self.tail.link = h; } else { self.head = h; }
    self.tail = h;
    self.count++;
}

<*
 Part 8.2: add at the back, from a Slot. Part 9.2 rule 5: the transfer clears
 the Slot.

 **Required at the public surface, and 003 is why it survived the redesign.**
 002 listed sixteen flat operations; 003 splits them into required, required at
 the public surface, and provided-if-useful, and promotes the Slot-shaped
 insert into the second group with Part 12.5 as the reason — V3. Part 12.5's
 composite hook hands a container to the application, so the Slot-shaped insert
 is the only way in that obeys Part 9.2.

 An empty Slot is a defect, not a no-op: rule 6's tolerance is for RELEASE, and
 this is an insert. The check is tier 2, and the early return is ordinary code,
 so a fast build does nothing rather than dereference a null. That pairing is
 the shape Part 8.9 requires and this file uses it wherever a compiled-out
 check would otherwise leave a hole.
*>
fn void InnerQueue.push_back_slot(&self, Slot* s)
{
    @check(s.is_full(), "push_back_slot from an empty Slot");
    if (s.is_empty()) return;
    self.push_back(s.take());
}

// --- Removing ---------------------------------------------------------------------

<*
 Part 8.2: take from the front. Null on an empty queue, which is an answer and
 not a fault — Part 19.4.

 The returned item's link is cleared. Part 8.8.

 The sole-item case is recognised by `head == tail` rather than by a null
 link: with the self-link there is no null link anywhere on a chain.
*>
fn Handle InnerQueue.pop_front(&self)
{
    Handle h = self.head;
    if (!h) return null;
    if (self.head == self.tail)
    {
        self.head = null;
        self.tail = null;
    }
    else
    {
        self.head = h.link;
    }
    self.count--;
    reset(h);
    return h;
}

// --- Moving ------------------------------------------------------------------------

<*
 Part 8.2: move every item of another queue onto this one, leaving that one
 empty. O(1).

 Part 8.9's pair survives the redesign unchanged, narrowed to the queue. The
 assert is tier 2 and compiles out; the early return is ordinary code and does
 not. Without both, the naive move rings the items into a cycle and clears the
 header, losing every one — and that failure is identical with one link.

 No repair is needed at the join: `other.tail` is already self-linked and stays
 the new tail, and `self.tail` simply stops being the end.

 @param other : "the queue to empty onto this one; empty afterwards"
*>
fn void InnerQueue.append_queue(&self, InnerQueue* other)
{
    @check(other != null, "append_queue with a null queue");
    @check(other != self, "Part 8.9: a queue cannot be moved onto itself");
    if (other == self) return;
    if (other.is_empty()) return;

    if (self.tail) { self.tail.link = other.head; } else { self.head = other.head; }
    self.tail = other.tail;
    self.count += other.count;

    other.head = null;
    other.tail = null;
    other.count = 0;
}
