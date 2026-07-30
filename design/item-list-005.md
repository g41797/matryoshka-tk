# ItemList (005)

Versioned doc. Replaces [item-list-004.md](item-list-004.md).

The design document for `ItemList` and for the validation question it opened.

Composed by subject, not by round. Every decision that has been made appears as  
a decision with its reason. Every question still open appears in one place at the  
end. Nothing here is a transcript.

Sections 1-4 describe code that shipped: API 8 is complete, 175/175 tests.  
Sections 5-8 describe a defect that predates it and what to do about it. Nothing  
in sections 5-8 is implemented.

---

## 1. What `ItemList` is

A list type that speaks `ItemHandle`.

It completes a trio.

- `ItemHandle` — one item. `= *PolyNode`.
- `Slot` — zero or one item. `= ?ItemHandle`.
- `ItemList` — many items.

All three are the same kind of thing: a way to move items that already exist.  
None is a container in the allocating sense.

### Why it exists

Five public signatures used to speak `std.DoublyLinkedList`, whose element type  
is `*std.DoublyLinkedList.Node`. Everywhere else the toolkit carries  
`ItemHandle`. At those five points the vocabulary dropped to a raw std node, and  
every caller converted back by hand:

```zig
const poly: *polynode.PolyNode = @fieldParentPtr("node", node);
const ev: *items.Event = items.Event.EventPolyHelper.fromNode(poly) orelse return error.CastFailed;
```

Two steps, the first a compiler builtin about struct layout —  
against `src/polynode.zig:14`, which promises *"You don't need to deal with  
@fieldParentPtr."*

Counted before the migration, across `examples/`, `tests/`, `stories/`:

| direction | shape | sites |
|---|---|---|
| inbound | `@fieldParentPtr("node", node)` | ~30 |
| inbound | `popFirst` walk | 34 |
| outbound | `list.append(&x.poly.node)` | 15 |

And the second half of the cause: `std.DoublyLinkedList` leaves `prev`/`next`  
stale on every removal, so `polynode.reset` had to be called by hand after each  
pop. The rule was written into the rules document. **34 pop sites, 13 `reset`  
calls** — 38% compliance, and one real bug: `_add_returned_item` panicked on  
composite lists of three or more items.

A written rule is a trap, not a guard.

### What it is not

- Intrusive, and stays intrusive. The links live in the item.
- Never allocates, and never holds an allocator.
- Never copies, clones, or frees an item, and never inspects a payload.
- Not tag-aware. Dispatch stays `Helper.fromNode(ih)`.
- Gains no method because `std.DoublyLinkedList` has one. Only because a caller
  in this repo needs it.

The last two are the ones under pressure. Every round proposed a method; the  
evidence rule is what has kept the surface at nine.

---

## 2. The API

`src/polynode.zig`. Composition, not casting:

```zig
pub const ItemList = struct {
    _list: std.DoublyLinkedList = .{},
    // ...
};
```

`@ptrCast` to `*std.DoublyLinkedList` would be unsound — see section 4.1.  
`extern struct` is not available, because `std.DoublyLinkedList` is a plain  
struct.

### 2.1 Methods

| method | returns | guarantees |
|---|---|---|
| `append(self, ih: ItemHandle)` | — | links at the end. Validates nothing — section 6 |
| `prepend(self, ih: ItemHandle)` | — | links at the front. Same |
| `insertAfter(self, existing, ih)` | — | both `ItemHandle`. Assumes `existing` is in this list |
| `popFirst(self)` | `?ItemHandle` | **the returned item is never linked** — `reset` has run. `null` if empty |
| `isEmpty(self)` | `bool` | replaces every `list.first == null` check |
| `len(self)` | `usize` | forwards `std`'s walk. O(n). Nothing in `src/` calls it |
| `iterate(self)` | `Iterator` | non-destructive. Yields `ItemHandle`. No unlink, no `reset` |
| `concat(self, other: *ItemList)` | — | keeps `self`'s order, keeps `other`'s order, appends the second to the first, empties `other`. O(1) |
| `moveFromList(list: *std.DoublyLinkedList)` | `ItemList` | takes the contents, empties the source, returns fresh. O(1) |
| `moveToList(self)` | `std.DoublyLinkedList` | hands the contents over, empties `self`. O(1) |

`Iterator.next()` returns `?ItemHandle`. A std list node never reaches a caller.

Neither move can fail: no optional, no `must` variant, an empty source moves an  
empty list.

### 2.2 The `_list` field

`_list` is reachable — Zig has no per-field visibility — and named to say "not  
yours", matching `_Mailbox`, `_Pool`, `_concat`, `_add_returned_item`.

Its shipped doc comment, which is the authority:

```zig
/// The plain std list this ItemList holds.
///
/// Use the methods below instead. Tests use this field — the raw links
/// are what those tests check.
///
/// Take an item out through this field, and:
/// - its prev and next still point at the list it left.
/// - popFirst() did not run, so reset() did not run either.
/// - call reset() on the item yourself.
///
/// Skip that call, and the next code to follow those links reads a list
/// the item is no longer in.
_list: std.DoublyLinkedList = .{},
```

### 2.3 Not included

| omitted | reason |
|---|---|
| `pop` | zero callers. `popFirst` is 31 |
| `remove` | zero callers. Removal happens through a pop |
| `popFirstOf(TAG)`, `splitByTag`, `countOf(TAG)` | zero callers |
| `fromList`, `toList` | a header copy aliases, it does not borrow — section 4.5 |

Rule for adding any of them: first real call site. Not before.

### 2.4 Inside the toolkit

| field / signature | type |
|---|---|
| `_Mailbox.list` | `ItemList` |
| `_Mailbox.oob_last` | `?ItemHandle`, was `?*std.DoublyLinkedList.Node` |
| `_Pool.lists` | map of `ItemList` |
| `PoolHooks.on_put`, `PoolHooks.on_close` | `ItemList` |
| `_concat` (was `pool.zig:415`) | deleted. `ItemList.concat` replaces it |
| `_Mailbox.len`, `_Pool.counts` | unchanged. `len` never replaces them |

**End state.** `@fieldParentPtr` survives in three places, all in  
`src/polynode.zig`: `ItemList.popFirst`, `ItemList.Iterator.next`, and  
`PolyHelper.fromNode`. Everywhere else in the repo it is gone, except the  
raw-link tests in `tests/layer1_polynode.zig` scenarios 6, 7, 8, where the  
layout is the thing under test.

---

## 3. Invariants

### 3.1 Of an `ItemList`

What holds for every list, independent of which methods exist.

- An item appears in at most one list, at most once. **Nothing enforces this** —
  sections 6 and 8.
- Order is preserved by every operation.
- No allocation, ever. Every operation is a pointer update.
- An empty list is `.{}`. There is no other empty representation, and no
  `deinit`.
- Moving a list never walks its items. `concat`, `moveFromList` and `moveToList`
  are O(1).
- `popFirst` always returns an unlinked item.
- `iterate` promises the minimum: it does not unlink, does not `reset`, and does
  not tolerate the list's shape changing while it runs. Link something, or pop  
  something, and the live iterator is invalid. It is a read, not a cursor.
- `_list` is the one hole in all of the above.

### 3.2 Of item access

This one is not about `ItemList`. It is the invariant that makes reading an  
item's own fields defined at all, and seven existing assert lines already rest  
on it:

> At any instant exactly one Master has exclusive access to an item. No two
> Masters modify the same `PolyNode` concurrently. Every transfer that moves an
> item between Masters establishes a happens-before relationship, because the
> address itself travels only through a synchronized primitive.

The last clause is the part that is easy to get wrong. The happens-before edge  
does **not** come from the mutexes — mailbox A's mutex and mailbox B's mutex  
order nothing between them. It comes from the address: a thread cannot touch an  
item until it learns the pointer, and in this toolkit a pointer reaches another  
thread only through a mailbox or a pool, both mutex-synchronized. The handoff  
that delivers the pointer is the same edge that orders the writes to it.

**This is owed to two other documents.** `rules-032.md:405` carries "an object  
sits in exactly one place, in exactly one state, at any moment";  
`matryoshka-model-004.md:30` carries the exclusive-access claim. Neither states  
the happens-before consequence. Writing it down is independent of every open  
question in section 8.

---

## 4. Decisions

Made and shipped. Each one states what was decided, the failure it prevents, the  
alternative rejected, and what it does not promise.

### 4.1 `*Node` is not `*PolyNode`

**Decision.** `@fieldParentPtr` is the only defined conversion from a list node  
to the item holding it. The toolkit performs it, or the application does.

From the langref, `struct` section:

> Zig gives no guarantees about the order of fields and the size of the struct
> but the fields are guaranteed to be ABI-aligned.

`PolyNode` is a plain struct. `node` is written first in the source, and that  
says nothing about its offset.

**Why there was no third option.** `@ptrCast` between the two pointer types is  
unsound even though it compiles and, on today's compiler, works. So there is no  
representation that makes the conversion disappear — only a choice about who  
writes it. That is what made the whole design a fork with two branches, not  
three.

**The failure this prevents.** A `@ptrCast` that passes every test on the current  
compiler and breaks silently when a field is added to `PolyNode`, or when the  
optimizer reorders. No test can catch it, because the layout it depends on was  
never promised.

Checked: nothing in the repo assumes pointer identity. All 14  
`@ptrCast`/`@alignCast` sites convert `*anyopaque` to a hook context. No  
`@offsetOf`, no `@intFromPtr`.

**What it does not promise.** `ItemList` does not make the conversion cheaper.  
Same builtin, same shape — it happens once, in a named place, instead of thirty  
times in application code.

### 4.2 The field is named `_list`

**Decision.** `_list`, not `list`. Tests may use it. Application code does not.

**Why the alternative was refused.** The recommendation was `list`, on the  
grounds that `tests/layer1_polynode.zig` scenarios 6, 7, 8 use the field, so a  
private-looking name would be a lie. The owner drew the line differently: a test  
and an application are not the same reader. A test may reach into a type it is  
testing — that is what tests are for. The name speaks to the application, and to  
the application the answer is no.

**The failure this prevents.** `il.list.append(...)` written in an example, then  
copied into user code, then into the docs, until reaching through `_list` is the  
normal path. A leading underscore does not stop that. It makes it visible in review.

**What it does not promise.** Nothing is enforced. `_list` is reachable and  
mutable from anywhere.

### 4.3 One view at a time

**Decision.** While a caller uses `_list`, the `ItemList` guarantees are  
suspended and `polynode.reset` is theirs to call. Stated in the field's doc  
comment, not enforced.

**The failure this prevents.**

```zig
const ih = il.popFirst().?;          // reset called. Handle is clean.
const node = il._list.popFirst().?;  // no reset. prev/next are stale.
```

Same list, two ways in, one without the guarantee. A stale `next` read after  
removal is the `_add_returned_item` panic again.

**Alternative rejected.** Say nothing, on the grounds that a raw std field is  
self-evidently raw. Rejected because that reasoning already failed once: "call  
`reset` after every pop" was written into the rules and obeyed 13 times out of
34. Self-evident is not a mechanism.

**What it does not promise.** The comment is advice. Nothing checks it. The name  
"one view at a time" is this document's, not the comment's — a caller reading a  
field needs to know what to call, not what to call it.

### 4.4 `popFirst` calls `reset`

**Decision.** A handle returned by `ItemList.popFirst` is never linked.

**The failure this prevents.** `std.DoublyLinkedList` leaves `prev` and `next`  
stale on removal. A later read of `next` on a popped item follows a pointer into  
a list the item is no longer part of. Not hypothetical — that is the  
`_add_returned_item` bug, and the fix was a `reset` call.

**Alternative rejected.** A thin forward with `reset` left to the caller. It  
produces a type that renames the problem. Every argument for `ItemList` is an  
argument for this one line inside it.

**What it does not promise.** `reset` clears links. It does not clear the  
payload, and it does not say the item is free to reuse. That is the pool's  
business, not the list's.

### 4.5 Move, never copy

**Decision.** `moveFromList` and `moveToList` only.

**Why.** A `std.DoublyLinkedList` header is `{first, last}`. Copying it produces  
a second header pointing at the same nodes — an alias, not a borrow. The first  
`popFirst` on either header advances only that header's `first`, and the two  
disagree from then on. The second `popFirst` on the other header returns an item  
that is already gone.

There is no `*const` form that avoids this, because there is no way to inspect a  
list header without holding something that can walk it.

**The precedent.** This is the API 6 accessor rule applied to a container.  
`fromSlot` inspects, takes `*const`, leaves the Slot full; `moveFromSlot`  
extracts and empties. A Slot can be inspected safely because it holds one  
pointer. A list header cannot, so it only ever gets the `move` form.

**Cost.** O(1). A two-word value copy. No walk, and no `reset` — the nodes stay  
correctly linked to each other, only the header changes hands.

### 4.6 `moveFromList` returns fresh

**Decision.** `moveFromList(list: *std.DoublyLinkedList) ItemList`.

**Alternative rejected.** `moveInFrom(self, list)`, filling an existing list. It  
needs a "destination is empty" precondition — the same shape as the Slot Rule —  
or it silently becomes a merge. No measured caller merges two lists from outside  
the toolkit.

**What it does not promise.** It is not a merge. `concat` is the merge.

### 4.7 The omitted surface

**Decision.** `pop`, `remove`, and every tag-aware operation are left out — see  
2.3 for the counts.

The tag-aware group is the interesting one, because it is the only place  
`ItemList` could offer reach that `std` structurally cannot: `std` does not know  
what a `PolyTag` is.

Rejected anyway, because the two candidate callers do not want it.  
`items.freeList` dispatches to a *destructor*, which is application knowledge  
and not a tag test. Per-item dispatch is already `Helper.fromNode(ih)` on each  
popped handle, and that returns null on a tag mismatch — the filter is already  
there, one item at a time.

### 4.8 `concat` replaces `_concat`

**Decision.** `ItemList.concat`, forwarding to `std`'s `concatByMoving`. The  
hand-written link surgery at the old `pool.zig:415` — ten lines of `prev`/`next`  
assignment — is deleted rather than moved.

**Why it is not a reuse argument.** Making `_Pool.lists` a map of `ItemList`  
already forced this: `_concat` took two `*std.DoublyLinkedList`, and its one  
caller inside `pool.close` now holds `ItemList` on both sides. The real choice  
was between a method on the type and a private `_concat(dst, src)` that reaches  
through `._list` twice — the same code with two reaches into the raw field added,  
in a file that just named that field to discourage them.

**Stated plainly.** This is the one method on the surface with a single caller  
and no application-side demand. It is there because the internal adoption put it  
there.

### 4.9 `len` does not replace the counters

**Decision.** `len` forwards `std`'s walk. `_Mailbox.len` and `_Pool.counts` stay  
exactly as they are.

Those counters exist because the walk is O(n) and the toolkit holds a lock while  
it would run. They are not a duplicate of `len`; they are the reason `len` is  
never called inside `src/`.

The doc comment does not carry the cost note — owner's decision. The two existing  
callers are tests counting a short list, and the note would read as a warning  
against the only use the method has.

### 4.10 `_Mailbox` and `_Pool` adopt `ItemList`

**Decision.** Internal fields and both hook signatures move — see 2.4.

**Why this is where the builtin disappears.** Seven of the eight  
`@fieldParentPtr` sites in `src/` were the same pop-cast-reset triple. They were  
not seven decisions. They were one line written seven times.

**Why the hooks move too.** A hook author is not toolkit infrastructure. They  
write application code that happens to be called back. Leaving `on_close` on the  
std type would mean the one caller most likely to walk a list item by item is  
the one caller still writing the builtin by hand.

### 4.11 One atomic migration

**Decision.** `src/` and every call site changed in the same compile. No  
deprecation path, because the element type changed, not just the name.

Five public signatures changed: `mailbox.receive_batch`, `mailbox.close`,  
`pool.put_all`, `PoolHooks.on_put`, `PoolHooks.on_close`. The toolkit has no  
external users yet, and a half-migrated tree is worse than a clean break.

`toListNode` — the proposed outbound accessor, API 7e — is closed as superseded:  
`append` takes an `ItemHandle`, so the 15 `list.append(&x.poly.node)` sites it  
targeted no longer exist.

### 4.12 The closing gate

**Decision.** The strong form. `@fieldParentPtr` appears only in  
`src/polynode.zig` and in `tests/layer1_polynode.zig` scenarios 6, 7, 8.

**What it does not promise.** The gate is a grep. It proves the builtin is  
absent, not that `ItemList` is used well.

---

## 5. The defect

`ItemList` forwards to `std.DoublyLinkedList`, which validates nothing by  
design — it is a raw intrusive primitive, and every method assumes the caller  
already knows the node's state.

Verified against the shipped `std`:

| misuse | what std does |
|---|---|
| `concat(&self)` — self-concat | list silently empties. `first=null`, `last=null`. Every item leaked |
| `append` a node already in another list | both lists claim it, `prev` reset to null |
| `insertAfter` where `existing` is in a different list | splices across lists, corrupts both |
| `append` a node already in *this* list | cycle |

### 5.1 `is_linked` is unsound

Checking that turned up an older defect. The guard the toolkit already uses does  
not work:

```text
sole member of a list:  prev=null, next=null
is_linked() reports:    false
but list.first == &a:   true
```

`std` never sets the links of a list's only member, and `polynode.is_linked`  
reads exactly those two fields.

This predates `ItemList`. Its doc comment at `src/polynode.zig:67` says "True if  
the node is linked into a list", which is false for a list of one.

### 5.2 The asserts that rest on it

Seven `std.debug.assert` lines across six APIs — Debug and ReleaseSafe only. All  
share the same blind spot:

| site | API | what it means to reject |
|---|---|---|
| `src/mailbox.zig:74` | `mailbox.send` | an item already queued elsewhere |
| `src/mailbox.zig:102` | `mailbox.send_oob` | same, OOB path |
| `src/pool.zig:240` | `pool.put` | double-put of a still-linked item |
| `src/pool.zig:287` | `_add_returned_item` | internal, last guard before `prepend` |
| `src/polynode.zig:275`, `:392` | `PolyHelper.moveFromSlot` | extracting from under a live list. Two sites — the helper is generated twice |
| `src/polynode.zig:315` | `PolyHelper.destroy` | **freeing memory a list still points at** |

> Every one of these is exact for a list of ≥2 and blind for a list of exactly 1.

Four further asserts guard the *destination* rather than an item, and are exact,  
because they read a `Slot`:

| site | API | assert |
|---|---|---|
| `src/polynode.zig:297` | `PolyHelper.create` | `slot.* == null` |
| `src/mailbox.zig:148` | `mailbox.receive` | `slot.* == null` |
| `src/mailbox.zig:205` | `mailbox.receive_oob` | `slot.* == null` |
| `src/pool.zig:157`, `:181` | `pool.get*` | `slot.* == null` |

### 5.3 Whose problem it is

**Ours.** `concat` and `insertAfter` have no application caller — one internal  
caller each. The self-concat and cross-list splice above are unreachable from  
outside `src/`. Guarding them is defensive work on our own code.

**Theirs.** `ItemList.append` is the only transfer in the toolkit that does not  
follow the Slot Rule:

| operation | signature | empties the slot |
|---|---|---|
| `mailbox.send` | `(mbh, slot: *Slot)` | yes |
| `mailbox.send_oob` | `(mbh, slot: *Slot)` | yes |
| `pool.put` | `(ph, slot: *Slot)` | yes |
| `PolyHelper.moveFromSlot` | `(slot: *Slot)` | yes |
| `ItemList.append` | `(ih: ItemHandle)` | no — it cannot |

It takes a handle, so there is no slot for it to clear. All four call sites in  
the repo write the clear by hand on the next line:

```zig
batch.append(slot.?);
slot = null;
```

`examples/layer1/023-tag_dispatch.zig:32,40`,  
`examples/layer1/025-produce_consume.zig:30`, `tests/layer3_pool.zig:627`.

**Why the two defects compound.** Forget that `slot = null`, and the  
defer-destroy-early idiom — the shape `patterns-019` recommends as standard —  
calls `destroy` on an item that is now linked. The guard is `assert(!is_linked)`,  
and for the *first* item appended to an empty list `is_linked` returns false.

So the single-member hole is not an edge case in this path. It is the most likely  
case, because the first append is always into an empty list. The result is a  
use-after-free that the toolkit's own recommended idiom produces and the  
toolkit's own assert misses.

This is not a regression. Before API 8 the same sites read  
`list.append(&slot.?.*.node); slot = null;` — identical hazard. API 8 did not  
create it. It had the chance to close it and did not.

---

## 6. The eight misuse cases

The map. Every question in section 8 refers to these numbers.

| # | misuse | paired APIs | what breaks |
|---|---|---|---|
| 1 | insert an item that is in **another** list | `append` / `prepend` after any earlier insert | both lists' links cross; either list's walk leaves the list |
| 2 | insert an item already in **this** list | `append` twice on the same handle | `len` counts a cycle; `iterate` never ends |
| 3 | insert from a Slot and keep the Slot | `append(mustFromSlot(&slot))` then `destroy(&slot)` | free while linked — case 5 with a delay |
| 4 | `insertAfter` with a foreign `existing` | `insertAfter` | items splice into the wrong list silently |
| 5 | free a linked item | `PolyHelper.destroy` / `pool.put` / `mailbox.send` | the holding list keeps a pointer to freed memory |
| 6 | take out through the raw field | `_list.popFirst` without `reset` | stale `prev`/`next`; the next reader walks a list the item left |
| 7 | mutate during a walk | `iterate` + `append` / `popFirst` | the iterator's `_next` may already be freed or relinked |
| 8 | copy an `ItemList` header | `const b = a;` | two headers alias one chain; the first `popFirst` corrupts the other |

Coverage today, and with everything section 8 proposes:

| # | today | prevention (§7.4) | container check (§7.3) |
|---|---|---|---|
| 1 | partial — caught only if the old list held ≥2 | — | not reachable from `self` |
| 2 | partial — same condition | — | **fixed** |
| 3 | no | **fixed** | — |
| 4 | no | — | **fixed** |
| 5 | partial — same condition | — | no list in hand at those sites |
| 6 | no — by construction | — | — |
| 7 | no | — | — |
| 8 | no — a copy is a language operation | — | — |

Cases 1 and 5 are what remains after everything proposed, and they share the  
`is_linked` condition from 5.2. Case 5 is the one that matters most, because  
`PolyHelper.destroy` is where it becomes a use-after-free. Cases 6, 7 and 8 are  
documented sharp edges, not candidates.

---

## 7. Where a check can live

Three places, and the difference between them decides everything in section 8.

| asks | exact | needs | instances |
|---|---|---|---|
| the **item** | would be | exclusive access to memory another thread may hold | ruled out — 7.1 |
| the **container** | yes | a list in hand | 7.3 |
| the **slot** | yes | nothing beyond the caller's own frame | 7.2, 7.4 |

### 7.1 Asking the item is ruled out

The proposal was a debug-only mark on `PolyNode`:

```zig
const LinkMark = if (std.debug.runtime_safety) bool else void;
```

Set by the insert methods, cleared by `popFirst` and `reset`, read by  
`is_linked`. It would have made all seven asserts in 5.2 exact without touching  
a single call site, and it cost nothing in shipping builds — 32 bytes under  
safety, 24 in ReleaseFast and ReleaseSmall, where the field is `void`.

It was recommended twice, and it is **withdrawn**. The argument is the owner's,  
and it is short.

**It needs an invariant that was not stated.** The field is written from under  
different locks:

```text
Mailbox A                 Mailbox B

lock A
pop(item)                 ← writes _linked = false
unlock A

                          lock B
                          append(item)   ← writes _linked = true
                          unlock B
```

Mutex A and mutex B do not synchronize with each other. In a correct program the  
two writes never overlap — for the reason in 3.2, the address, not the mutexes.

**In the buggy program the field itself races.** Take the mistake it exists to  
catch, two Masters manipulating one item:

```text
Thread A                  Thread B

_linked = false           _linked = true
```

Concurrent, unsynchronized, no happens-before edge. That is a data race, and a  
data race is undefined behaviour. The field is sound exactly when it is  
unnecessary, and undefined exactly when it would fire.

**Atomics prove nothing.** An atomic bool removes the race and not the bug:

```text
Thread A                  Thread B

append()                  append()
  reads _linked == false    reads _linked == false
  CAS to true               CAS to true
```

Both threads then run the insertion, and the topology is corrupted whatever the  
flag says. The atomic protects the flag; the list is what needed protecting.

**And the argument reaches `prev` and `next`.** `is_linked` reads  
`node.node.prev` and `node.node.next`, written under whichever mutex the current  
list sits behind — exactly like the proposed bool. In the buggy scenario those  
race too, so `is_linked` is undefined in Debug **today**. The bool introduces no  
new race class; it inherits the one already there.

That generalizes the conclusion:

> No state stored in the item can detect cross-Master misuse, because reading
> that state requires the very exclusivity whose absence is the bug.

Which rules out the mark, an owner-pointer variant, and a generation counter  
alike.

**What this is not.** Not an argument that `ItemList` is unsafe: a program  
following the Slot Rule has no race. Not an argument against asserts. Not a  
claim that the misuse is undetectable by any means — ThreadSanitizer sees the  
racing writes without help from a field. What is ruled out is detecting it from  
state kept *in* the item.

### 7.2 Asking the slot is exact

A `Slot` lives in the caller's own frame. Reading it needs nothing the caller  
does not already hold, which is why the four asserts at the end of 5.2 work.

This is also why one further check is free of the whole argument above: `concat`  
comparing `other` against `self` is a pointer comparison between two arguments  
the caller passed in. It needs no shared state at all.

### 7.3 Asking the container is exact

New in 005, from the owner: *insert an item already in this list may be fixed  
walking before insert.*

```zig
// compiled only under std.debug.runtime_safety
fn _holds(self: *const ItemList, ih: ItemHandle) bool {
    var it = self._list.first;
    while (it) |n| : (it = n.next) if (n == &ih.node) return true;
    return false;
}
```

`std.DoublyLinkedList` has no `contains`, so this is ours to write. It is private  
and it is the only new code the check needs.

**Why it survives 7.1.** The resemblance to the withdrawn field is close enough  
to be misleading, so the difference is worth tabulating:

| | the withdrawn mark | the walk |
|---|---|---|
| writes | `_linked`, on every insert and reset | nothing |
| reads | the item's own memory | `self._list`, plus one address |
| needs | exclusive access to an item another thread may hold | exclusive access to a list this caller already holds |
| in the buggy case | the field itself races — undefined | still reads only `self` — defined |

The third row decides it. `&ih.node` computes an address; it does not dereference  
the item. So even in the misuse the check exists to catch, the walk never touches  
memory another thread owns. It asks the container a question about the container.

**What it closes.** Case 2 completely, including the sole-member hole nothing else  
reaches — the walk does not consult `is_linked` at all. Applied to `insertAfter`'s  
`existing`, also case 4, which only the rejected owner-pointer ever covered.

**What it costs.** O(n) per insert under safety builds, nothing outside them. The  
complexity is the easy half; the placement is the hard half. Every internal  
insert holds a mutex:

| site | API |
|---|---|
| `src/mailbox.zig:87` | `mailbox.send` |
| `src/mailbox.zig:117`, `:119` | `mailbox.send_oob` |
| `src/pool.zig:291` | `pool.put` via `_add_returned_item` |
| `src/pool.zig:322` | `pool.close` |

Under Debug, that walks the whole queue with the mailbox locked. Shipping builds  
pay nothing, but the tests run in Debug and ReleaseSafe, and concurrency tests are  
the ones whose timing this changes.

**Why this is not the O(n) that lost the earlier argument.** The owner-pointer  
variant of 7.1 was rejected partly for costing O(n) under safety builds, so the  
distinction has to be stated: that O(n) fell on `concat`, `moveFromList` and  
`moveToList`, three operations whose O(1) section 3.1 promises and whose O(1) is  
the reason they exist. `append`, `prepend` and `insertAfter` promise nothing about  
complexity. That makes the walk arguable, not free — the locked-insert cost above  
is why it is still a question.

### 7.4 Prevention needs no check at all

`appendFromSlot` reads nothing, so no invariant applies to it:

```zig
pub fn appendFromSlot(self: *ItemList, slot: *Slot) void {
    std.debug.assert(slot.* != null);
    std.debug.assert(!is_linked(slot.*.?));
    self.append(slot.*.?);
    slot.* = null;
}
```

That is `mailbox.send` minus the mailbox. `slot.* = null` is what does the work;  
after it returns, the dangling slot of case 3 cannot exist, so there is nothing  
left to detect. The `is_linked` line in the sketch is inherited habit, not  
mechanism.

### 7.5 The shape of the conclusion

Detection was never the impossible half. The correct statement is narrower than  
"no detection works":

> Detection that requires knowing a fact about an **item** is not implementable.
> Detection answerable from a **container's** own contents, or from the caller's
> own **slot**, is.

Prevention was always immune, because it reads nothing.

---

## 8. Open issues

Numbering is preserved from 004 — Q26-Q34 are cited by number in `STATUS-LOG.md`,  
`plan-049.md` and `context.md`. Q25 predates them and is postponed by choice.

Write answers on the `Answer:` line.

### Q25 — the protection list for a migration stage

Postponed by owner's decision, not undecided. The API 8 migration ran with the  
three proposed protections applied as written. Recorded in
[item-list-004.md](item-list-004.md) §Q25.

**Answer:** postponed

### Q26 — does `PolyNode` gain a debug field?

Full argument: 7.1.

- A. `bool` link mark, `void` outside safety builds.
- B. `?*const anyopaque` owner field. Also covers case 4, at the cost of making
  `concat`, `moveFromList` and `moveToList` O(n) under safety builds.
- C. Head-only check: `!is_linked(ih) and self._list.first != &ih.node`.
  Superseded — this is 7.3 truncated to the first element, so it is a weaker Q34  
  = B rather than an option of its own.
- D. **Nothing.** No state on `PolyNode`.

**Recommendation: D**, on the concurrency argument in 7.1. Reversed from A, which  
002 recommended twice; the reversal and its reasoning are in
[item-list-003.md](item-list-003.md).

What D costs, stated plainly: the seven asserts of 5.2 stay blind for a list of  
one, `PolyHelper.destroy` keeps guarding a use-after-free with a check that  
cannot see it, and cases 1 and 5 stay open. That is not acceptable as a resting  
state, which is what makes Q33 necessary.

Q34 does not change this answer. The walk is not in-item state, so it is not one  
of A/B/C.

**Answer:**

### Q27 — what does `is_linked` say?

With Q26 at D, `is_linked` **cannot** be made exact, so the question is what it  
should claim.

- A. Keep the name, fix the doc comment. It answers "do I have neighbours", and
  the comment says exactly that — no more.
- B. Rename to `has_neighbours`. Honest, and a breaking change on a public
  function.
- C. Leave it, including the comment at `src/polynode.zig:67` that is false for a
  list of one.

**Recommendation: A.** C is a false statement in a public doc comment. B is  
honest, but the name appears in `examples/layer1/021-define_type.zig:48` and  
eight test sites, and renaming it changes nothing a caller can learn.

**Answer:**

### Q28 — does `concat` assert `other != self`?

Self-concat silently empties the list and leaks every item.

**Recommendation: yes**, under `runtime_safety`. Independent of everything else —  
this is 7.2, a pointer comparison between two arguments.

**Answer:**

### Q31 — does `ItemList` get a slot-taking append?

The user-facing half. Mechanism in 7.4, hazard in 5.3.

```zig
pub fn appendFromSlot(self: *ItemList, slot: *Slot) void
pub fn prependFromSlot(self: *ItemList, slot: *Slot) void
```

- A. Both, and the four call sites migrate. `append`/`prepend` stay for the
  stack-item case (`EventPolyHelper.toNode(&ev)`), which has no slot.
- B. `appendFromSlot` only. `prepend` from a slot has no caller today.
- C. Neither. The hand-written `slot = null` stays.

**Recommendation: A.** B leaves the pair asymmetric, which gets noticed later and  
reopened. C keeps a hazard the toolkit closes everywhere else.

Naming follows the API 6 rule: a `move`- or `from`-prefixed operation empties its  
source. On a null slot it should follow `send` and assert, not follow `put` and  
return silently — `put` is tolerant because it is the standard `defer` target,  
and an append is not.

**No field, no build-mode condition, independent of Q26 — it can ship alone.**  
With Q26 at D this is the implementable half of the work.

**Answer:**

### Q32 — what is the stage, and in what order does it ship?

- A. **"Intrusive safety".** The subject is `PolyNode` and every intrusive
  container over it, present and future. `ItemList` is one caller.
- B. **"ItemList round 2".** The subject is the type API 8 added.

**Recommendation: A.** B is how the work arrived, not what it is. The payoff is  
existing asserts in `mailbox.zig`, `pool.zig` and `PolyHelper` — none of them  
`ItemList`. A stage named after `ItemList` would make those look incidental, and  
would make the next intrusive container look like new work rather than a  
beneficiary.

Ship order, if A:

1. `appendFromSlot` / `prependFromSlot` (Q31). Prevention. No dependency, and the
   only item with a user-visible payoff.
2. The dedicated test file (Q29, answered), pinning current behaviour before it
   changes.
3. The walk (Q34) and `is_linked`'s disposition (Q27, Q33). Detection.
4. `concat`'s identity assert (Q28).
5. Docs.

Prevention before detection: a bug that cannot happen needs no assert, and step 1  
removes the hazard for the four real call sites whether or not the rest is ever  
approved.

**Answer:**

### Q33 — what becomes of the seven assert lines?

Inventory: 5.2. Forced by Q26 = D — if nothing can repair `is_linked`, seven  
production asserts promise a guarantee they do not keep.

- A. **Keep them, document the hole.** They catch the multi-element case, which
  is most real double-sends. A partial guard is better than none.
- B. **Remove them.** A check that is wrong for a list of one and undefined in
  the concurrent case is worse than nothing, because three tests currently read  
  as though it works.

**Recommendation: A.** The asserts do catch something, and the cost of A is one  
doc-comment fix plus a rules entry saying what the check is worth. B would delete  
a partial guard on a use-after-free and gain nothing.

Under either answer, three tests encode the broken semantics and need their  
comments corrected: `layer1_polynode.zig:71`, `layer2_mailbox.zig:598`,  
`layer3_pool.zig:808`. Scenario 88's comment already documents the hole  
(*"single-node list has prev==next==null"*) — it was written around the defect  
rather than reporting it.

004 carried a third option here — apply the container walk to `pool.put` and  
`mailbox.send` — which is now part of Q34, where it belongs. Note what that  
implies: the walk cannot help the two sites that matter most, because  
`PolyHelper.destroy` and `moveFromSlot` are handed a `Slot` and hold no list to  
interrogate.

**Answer:**

### Q34 — how far does the container walk go?

Mechanism, soundness and cost: 7.3.

- A. **Not at all.** The coverage table of section 6 stands.
- B. **`append` and `prepend`.** `assert(!_holds(ih))`. Closes case 2.
- C. **All four inserts, both directions.** B, plus `insertAfter` asserting
  `!_holds(ih)` and `_holds(existing)`. Closes cases 2 and 4.
- D. **C behind a length cap.** Walk only while the list is short. Bounds the
  worst case at the price of a guarantee that holds only for small lists.

**Recommendation: C**, with D as the fallback if Debug throughput on mailbox or  
pool measurably suffers. Recording D as the fallback rather than the  
recommendation is deliberate: a cap makes the assert's guarantee conditional on  
list length, which is a worse thing to document than an honest O(n).

C is the only option that closes a case no other surviving mechanism can reach.  
The argument against it is placement, not complexity — every internal insert  
holds a mutex, and Debug is where the concurrency tests run.

**Also applies to `mailbox.send` and `pool.put`**, which hold their own lists  
under their own locks. That is the part inherited from Q33, and it should be  
answered here: same walk, same soundness, larger lists.

**Answer:**

---

## 9. What this document owes elsewhere

Independent of every answer above:

- **The happens-before invariant of 3.2** into a new `rules` version and a new
  `matryoshka-model` version. Half of it is written down; the consequence is not,  
  and seven assert lines rest on it.
- **`src/polynode.zig:67`** — the `is_linked` doc comment is false for a list of
  one. Fixed under Q27 = A.
- **`tests/layer3_pool.zig:627`** — a comment explaining that an item now belongs
  to the batch, which Q31 = A makes unnecessary.

---

## 10. History

005 replaces 004 and is composed by subject. The round-by-round argument —  
including the link mark's two recommendations and its withdrawal, the coverage  
table's corrections, and the answers to Q1-Q25 as they were given — is in
[item-list-004.md](item-list-004.md),
[item-list-003.md](item-list-003.md),
[item-list-002.md](item-list-002.md) and
[item-list-001.md](item-list-001.md). Nothing from those versions is contradicted
here; what is dropped is the record of the order in which it was learned.
