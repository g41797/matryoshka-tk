<*
 The intrusive list. Part 8.

 Named NodeList and not AnyList. `std::collections::anylist` already exists,
 is heterogeneous under that name, and shallow-copies and owns every element —
 the semantic opposite of this list. D8.

 Nothing here allocates. The item is the node. Insert and remove are O(1),
 except for the walk of Part 8.6, which is O(n) in checking builds and is not
 compiled at all in fast ones.

 Part 8.5: this is the layer where the checks live. There is no raw list
 primitive underneath it — C3's stdlib has no intrusive list, so Part 8.10's
 bridge has no other side and is dropped.

 Part 19.4: no operation on the list can fail. There is no fault type here.
 A take from an empty list returns null; that is an answer, not an error.
*>
module mtk;

<*
 The list header. Part 8.1.

 The count is kept, so `len` is O(1). Part 8.2 asks for the operation, and the
 pool of a later stage needs one count per identity.
*>
struct NodeList
{
    AnyNode* head;
    AnyNode* tail;
    usz      count;
}

<*
 A walker. Part 8.4.

 Taken from the list, yields handles one at a time, exhausted when it returns
 null. Removing the current item during a walk is NOT supported.
*>
struct NodeListIterator
{
    AnyNode* cur;
}

// --- The link test, and the repair -------------------------------------------

<*
 The link test. Part 8.7, and its blind spot, which is a MUST to document.

 This asks whether an item has neighbours. It is NOT a membership test. An
 item alone on a list has no neighbours and reports false, so every assert
 built on it inherits that hole. The walk of Part 8.6 is what covers it, and
 only in checking builds.

 D12 accepted the blind spot. Closing it costs a field per item, and D3 already
 refused a third field in the inner for a stronger reason.
*>
fn bool is_linked(AnyHandle h) @inline => h != null && (h.prev != null || h.next != null);

<*
 The repair. Part 8.8.

 After a removal the item's links are cleared, so it passes the link test and
 can be inserted again. Every removal in this file calls this for the caller.
*>
fn void reset(AnyHandle h) @inline
{
    if (!h) return;
    h.prev = null;
    h.next = null;
}

<*
 Is this item on THIS list? An O(n) walk.

 The tier 3 guards call it, so in a fast build nothing calls it. It stays
 public because C3 ignores `@private` on a method and because it is the
 membership test the link test of Part 8.7 cannot be.

 This is the check the link test cannot make, and the reason Part 8.6 says
 neither check alone is enough. The walk sees a list of exactly one member,
 which the link test cannot.
*>
fn bool NodeList.contains(&self, AnyHandle h)
{
    for (AnyNode* n = self.head; n; n = n.next) if (n == h) return true;
    return false;
}

<*
 Part 8.6's double check, at every insert. Both checks, in checking builds.

 The link test sees a DIFFERENT list, which the walk cannot.
 The walk sees a list of exactly one member, which the link test cannot.
*>
macro NodeList.@guard_insert(&self, AnyHandle h)
{
    @check(h != null, "insert of a null handle");
    @check(!is_linked(h), "Part 8.6 link test: the item already has neighbours");
    $if CHECKED:
        @check(!self.contains(h), "Part 8.6 walk: the item is already on this list");
    $endif
}

// --- Questions ----------------------------------------------------------------

<*
 Part 8.2: is it empty.
*>
fn bool NodeList.is_empty(&self) @inline => self.count == 0;

<*
 Part 8.2: how many. O(1).
*>
fn usz NodeList.len(&self) @inline => self.count;

<*
 Part 8.2: look at the front. Does not remove. Null on an empty list.
*>
fn AnyHandle NodeList.front(&self) @inline => self.head;

<*
 Part 8.2: look at the back. Does not remove. Null on an empty list.
*>
fn AnyHandle NodeList.back(&self) @inline => self.tail;

<*
 Part 8.4: a walker, taken from the list.
*>
fn NodeListIterator NodeList.iter(&self) @inline => { .cur = self.head };

<*
 The next handle, or null when the walk is exhausted.
*>
fn AnyHandle NodeListIterator.next(&self)
{
    AnyNode* n = self.cur;
    if (n) self.cur = n.next;
    return n;
}

// --- Adding --------------------------------------------------------------------

<*
 Part 8.2: add at the back.
*>
fn void NodeList.push_back(&self, AnyHandle h)
{
    self.@guard_insert(h);
    h.prev = self.tail;
    h.next = null;
    if (self.tail) { self.tail.next = h; } else { self.head = h; }
    self.tail = h;
    self.count++;
}

<*
 Part 8.2: add at the front.
*>
fn void NodeList.push_front(&self, AnyHandle h)
{
    self.@guard_insert(h);
    h.prev = null;
    h.next = self.head;
    if (self.head) { self.head.prev = h; } else { self.tail = h; }
    self.head = h;
    self.count++;
}

<*
 Part 8.2: insert after a named item.

 @param at : "an item already on this list"
 @param h : "the item to insert"
*>
fn void NodeList.insert_after(&self, AnyHandle at, AnyHandle h)
{
    @check(at != null, "insert_after with a null anchor");
    $if CHECKED:
        @check(self.contains(at), "insert_after: the anchor is not on this list");
    $endif
    self.@guard_insert(h);
    h.prev = at;
    h.next = at.next;
    if (at.next) { at.next.prev = h; } else { self.tail = h; }
    at.next = h;
    self.count++;
}

<*
 Part 8.2: insert before a named item.

 @param at : "an item already on this list"
 @param h : "the item to insert"
*>
fn void NodeList.insert_before(&self, AnyHandle at, AnyHandle h)
{
    @check(at != null, "insert_before with a null anchor");
    $if CHECKED:
        @check(self.contains(at), "insert_before: the anchor is not on this list");
    $endif
    self.@guard_insert(h);
    h.next = at;
    h.prev = at.prev;
    if (at.prev) { at.prev.next = h; } else { self.head = h; }
    at.prev = h;
    self.count++;
}

// --- Adding from a Slot ----------------------------------------------------------

<*
 Part 8.2: add at the back, from a Slot. Part 9.2 rule 5: the transfer clears
 the Slot.

 An empty Slot is a defect, not a no-op: rule 6's tolerance is for RELEASE, and
 this is an insert. The check is tier 2, and the early return is ordinary code,
 so a fast build does nothing rather than dereference a null. That pairing is
 the shape Part 8.9 requires and this file uses it wherever a compiled-out
 check would otherwise leave a hole.
*>
fn void NodeList.push_back_slot(&self, Slot* s)
{
    @check(s.is_full(), "push_back_slot from an empty Slot");
    if (s.is_empty()) return;
    self.push_back(s.take());
}

<*
 Part 8.2: add at the front, from a Slot. Part 9.2 rule 5.
*>
fn void NodeList.push_front_slot(&self, Slot* s)
{
    @check(s.is_full(), "push_front_slot from an empty Slot");
    if (s.is_empty()) return;
    self.push_front(s.take());
}

// --- Removing ---------------------------------------------------------------------

<*
 Unlink, WITHOUT the repair of Part 8.8. Internal.

 C3 0.8.3 ignores `@private` on a method declaration, so this cannot be
 hidden. It is named for what it leaves undone and documented here instead —
 which is D1's ruling arriving in a place D1 did not anticipate.

 Part 8.8: any path that reaches around the list surface clears the links by
 hand. A caller of this one has reached around the surface. Call `reset` after.
*>
fn void NodeList.unlink_no_repair(&self, AnyHandle h)
{
    if (h.prev) { h.prev.next = h.next; } else { self.head = h.next; }
    if (h.next) { h.next.prev = h.prev; } else { self.tail = h.prev; }
    self.count--;
}

<*
 Part 8.2: take from the front. Null on an empty list, which is an answer and
 not a fault — Part 19.4.

 The returned item's links are cleared. Part 8.8.
*>
fn AnyHandle NodeList.pop_front(&self)
{
    AnyHandle h = self.head;
    if (!h) return null;
    self.unlink_no_repair(h);
    reset(h);
    return h;
}

<*
 Part 8.2: take from the back. Null on an empty list. Links cleared.
*>
fn AnyHandle NodeList.pop_back(&self)
{
    AnyHandle h = self.tail;
    if (!h) return null;
    self.unlink_no_repair(h);
    reset(h);
    return h;
}

<*
 Part 8.2: remove a named item from the middle. Links cleared. Part 8.8.

 The membership check is tier 3, for the reason Part 8.7 gives: the link test
 cannot tell this list from another, and an item alone on a list is
 indistinguishable from an item on none.

 @param h : "an item on this list"
*>
fn void NodeList.remove(&self, AnyHandle h)
{
    @check(h != null, "remove of a null handle");
    $if CHECKED:
        @check(self.contains(h), "remove: the item is not on this list");
    $endif
    if (!h) return;
    self.unlink_no_repair(h);
    reset(h);
}

// --- Moving ------------------------------------------------------------------------

<*
 Part 8.2: move every item of another list onto this one, leaving that one
 empty. O(1).

 Part 8.9's pair, and it is not softened. The assert is tier 2 and compiles
 out; the early return is ordinary code and does not. Without both, the naive
 move rings the items into a cycle and clears the header, losing every one.

 @param other : "the list to drain; empty afterwards"
*>
fn void NodeList.append_list(&self, NodeList* other)
{
    @check(other != null, "append_list with a null list");
    @check(other != self, "Part 8.9: a list cannot be moved onto itself");
    if (other == self) return;
    if (other.is_empty()) return;

    if (self.tail)
    {
        self.tail.next = other.head;
        other.head.prev = self.tail;
    }
    else
    {
        self.head = other.head;
    }
    self.tail = other.tail;
    self.count += other.count;

    other.head = null;
    other.tail = null;
    other.count = 0;
}
