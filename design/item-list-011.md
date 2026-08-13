# ItemList (011)

Change from -010: API 13-4 — custody-sense `hands`/`handed` reworded to match  
`src/polynode.zig`. No contract changed.

Change from -009: API 12-4 — the doc speaks the pointer API. Methods on  
`*Mbox` / `*Pool`; `new`, `destroy`, `receiveResult`, `getWaitResult` stay  
free functions on the module.



Change from -008: API 11 — `fromNode` and `toNode` renamed to `fromPoly` and  
`toPoly` wherever this doc names them. No decision changed.

Change from -007: API 10 "ItemList completion" shipped on 2026-07-31. Section 2  
is updated to the shipped API, section 2.3 records the reversal of its own  
"first real call site" rule, and section 12 is the decision record. Sections  
5-8 are unchanged — API 10 widens the checks they argued for, it does not  
revisit the argument.

Change from -006: API 9 "intrusive safety" shipped on 2026-07-30. Section 8's  
decisions are implemented, so the "nothing here is implemented" notices are  
replaced with what was built. No decision changed. Sections 5-7 stay as the  
argument that produced them.

The design document for `ItemList` and for the validation question it opened.

Change from -005: the round 6 questions are answered. Q26 D, Q27 A, Q28 yes,  
Q31 A, Q32 A, Q33 A, Q34 C. Section 8 is now a decision record, not a question  
list. Q25 is closed. Section 9 retitled.

Composed by subject, not by round. Every decision appears as a decision with its  
reason. Nothing here is a transcript.

Sections 1-4 describe API 8: complete, 175/175 tests. Sections 5-8 describe a  
defect that predates it and what was done about it — **API 9, shipped  
2026-07-30, 177/177 tests**. Section 8 is the decision record; section 11 is  
what shipped against it. Section 12 is **API 10, shipped 2026-07-31, 182/182  
tests**: the list completed, and the checks widened.

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
const ev: *items.Event = items.Event.EventPolyHelper.fromPoly(poly) orelse return error.CastFailed;
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
- Not tag-aware. Dispatch stays `Helper.fromPoly(ih)`.
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
| `append(self, ih: ItemHandle)` | — | links at the end. Asserts `!_holds` and `!is_linked` under safety — section 12.2 |
| `prepend(self, ih: ItemHandle)` | — | links at the front. Same |
| `appendFromSlot(self, slot: *Slot)` | — | takes the item and empties the Slot |
| `prependFromSlot(self, slot: *Slot)` | — | same at the front |
| `insertAfter(self, existing, ih)` | — | both `ItemHandle`. Asserts `existing` is in this list |
| `insertBefore(self, existing, ih)` | — | mirror of `insertAfter` |
| `popFirst(self)` | `?ItemHandle` | **the returned item is never linked** — `reset` has run. `null` if empty |
| `popLast(self)` | `?ItemHandle` | same at the other end |
| `remove(self, ih: ItemHandle)` | — | takes one item out wherever it sits, and calls `reset`. Asserts this list holds it |
| `first(self)` / `last(self)` | `?ItemHandle` | look without taking. A list of one returns the same item from both |
| `isEmpty(self)` | `bool` | replaces every `list.first == null` check |
| `len(self)` | `usize` | forwards `std`'s walk. O(n). Nothing in `src/` calls it |
| `iterator(self)` | `Iterator` | non-destructive. Yields `ItemHandle`. No unlink, no `reset` |
| `concat(self, other: *ItemList)` | — | keeps `self`'s order, keeps `other`'s order, appends the second to the first, empties `other`. O(1). The same list twice does nothing |
| `moveFromList(list: *std.DoublyLinkedList)` | `ItemList` | takes the contents, empties the source, returns fresh. O(1). Asserts the header is consistent |
| `moveToList(self)` | `std.DoublyLinkedList` | moves the contents over, empties `self`. O(1) |

`Iterator.next()` returns `?ItemHandle`. A std list node never reaches a caller.

Neither move can fail: no optional, no `must` variant, an empty source moves an  
empty list.

### 2.2 The `_list` field

`_list` is reachable — Zig has no per-field visibility — and named to say "not  
yours", matching `_Mailbox`, `_Pool`, `_concat`, `_add_returned_item`.

Its shipped doc comment, which is the authority:

```zig
/// Don't use it directly.\
/// Use the methods below.
///
/// Using of this field allowed for tests.
///
_list: std.DoublyLinkedList = .{},
```

Since API 10 there is a method for the case that used to force callers here:  
`remove` takes one item out from anywhere and calls `reset` itself.

### 2.3 Not included

| omitted | reason |
|---|---|
| `popFirstOf(TAG)`, `splitByTag`, `countOf(TAG)` | zero callers |
| `fromList`, `toList` | a header copy aliases, it does not borrow — section 4.5 |

Rule for adding any of them: first real call site. Not before.

**API 10 reversed that rule for five methods.** `pop` (as `popLast`), `remove`,  
`first`, `last` and `insertBefore` were declined here for having zero callers.  
They shipped anyway. Section 12.1 says why the rule was wrong for this case.

### 2.4 Inside the toolkit

| field / signature | type |
|---|---|
| `_Mailbox.list` | `ItemList` |
| `_Mailbox.oob_last` | `?ItemHandle`, was `?*std.DoublyLinkedList.Node` |
| `_Pool.lists` | map of `ItemList` |
| `Pool.Hooks.on_put`, `Pool.Hooks.on_close` | `ItemList` |
| `_concat` (was `pool.zig:415`) | deleted. `ItemList.concat` replaces it |
| `_Mailbox.len`, `_Pool.counts` | unchanged. `len` never replaces them |

**End state.** `@fieldParentPtr` survives in three places, all in  
`src/polynode.zig`: `ItemList.popFirst`, `ItemList.Iterator.next`, and  
`PolyHelper.fromPoly`. Everywhere else in the repo it is gone, except the  
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

**This is owed to two other documents.** `rules-033.md:405` carries "an object  
sits in exactly one place, in exactly one state, at any moment";  
`matryoshka-concepts-002.md` carries the exclusive-access claim. Neither states  
the happens-before consequence. Writing it down is independent of every open  
decision in section 8.

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
correctly linked to each other, only the header moves.

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
and not a tag test. Per-item dispatch is already `Helper.fromPoly(ih)` on each  
popped handle, and that returns null on a tag mismatch — the filter is already  
there, one item at a time.

### 4.8 `concat` replaces `_concat`

**Decision.** `ItemList.concat`, forwarding to `std`'s `concatByMoving`. The  
hand-written link surgery at the old `pool.zig:415` — ten lines of `prev`/`next`  
assignment — is deleted rather than moved.

**Why it is not a reuse argument.** Making `_Pool.lists` a map of `ItemList`  
already forced this: `_concat` took two `*std.DoublyLinkedList`, and its one  
caller inside `Pool.close` now holds `ItemList` on both sides. The real choice  
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

Five public signatures changed: `Mbox.receive_batch`, `Mbox.close`,  
`Pool.put_all`, `Pool.Hooks.on_put`, `Pool.Hooks.on_close`. The toolkit has no  
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
| `src/mailbox.zig:74` | `Mbox.send` | an item already queued elsewhere |
| `src/mailbox.zig:102` | `Mbox.send_oob` | same, OOB path |
| `src/pool.zig:240` | `Pool.put` | double-put of a still-linked item |
| `src/pool.zig:287` | `_add_returned_item` | internal, last guard before `prepend` |
| `src/polynode.zig:275`, `:392` | `PolyHelper.moveFromSlot` | extracting from under a live list. Two sites — the helper is generated twice |
| `src/polynode.zig:315` | `PolyHelper.destroy` | **freeing memory a list still points at** |

> Every one of these is exact for a list of ≥2 and blind for a list of exactly 1.

Four further asserts guard the *destination* rather than an item, and are exact,  
because they read a `Slot`:

| site | API | assert |
|---|---|---|
| `src/polynode.zig:297` | `PolyHelper.create` | `slot.* == null` |
| `src/mailbox.zig:148` | `Mbox.receive` | `slot.* == null` |
| `src/mailbox.zig:205` | `mailbox.receive_oob` | `slot.* == null` |
| `src/pool.zig:157`, `:181` | `Pool.get*` | `slot.* == null` |

### 5.3 Whose problem it is

**Ours.** `concat` and `insertAfter` have no application caller — one internal  
caller each. The self-concat and cross-list splice above are unreachable from  
outside `src/`. Guarding them is defensive work on our own code.

**Theirs.** `ItemList.append` is the only transfer in the toolkit that does not  
follow the Slot Rule:

| operation | signature | empties the slot |
|---|---|---|
| `Mbox.send` | `(mbx, slot: *Slot)` | yes |
| `Mbox.send_oob` | `(mbx, slot: *Slot)` | yes |
| `Pool.put` | `(pl, slot: *Slot)` | yes |
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

The map. Every decision in section 8 refers to these numbers.

| # | misuse | paired APIs | what breaks |
|---|---|---|---|
| 1 | insert an item that is in **another** list | `append` / `prepend` after any earlier insert | both lists' links cross; either list's walk leaves the list |
| 2 | insert an item already in **this** list | `append` twice on the same handle | `len` counts a cycle; `iterate` never ends |
| 3 | insert from a Slot and keep the Slot | `append(mustFromSlot(&slot))` then `destroy(&slot)` | free while linked — case 5 with a delay |
| 4 | `insertAfter` with a foreign `existing` | `insertAfter` | items splice into the wrong list silently |
| 5 | free a linked item | `PolyHelper.destroy` / `Pool.put` / `Mbox.send` | the holding list keeps a pointer to freed memory |
| 6 | take out through the raw field | `_list.popFirst` without `reset` | stale `prev`/`next`; the next reader walks a list the item left |
| 7 | mutate during a walk | `iterate` + `append` / `popFirst` | the iterator's `_next` may already be freed or relinked |
| 8 | copy an `ItemList` header | `const b = a;` | two headers alias one chain; the first `popFirst` corrupts the other |

Coverage today, and after section 8 is implemented:

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

Cases 1 and 5 are what remains after everything decided, and they share the  
`is_linked` condition from 5.2. Case 5 is the one that matters most, because  
`PolyHelper.destroy` is where it becomes a use-after-free. Cases 6, 7 and 8 are  
documented sharp edges, not candidates.

---

## 7. Where a check can live

Three places, and the difference between them decided everything in section 8.

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
| `src/mailbox.zig:87` | `Mbox.send` |
| `src/mailbox.zig:117`, `:119` | `Mbox.send_oob` |
| `src/pool.zig:291` | `Pool.put` via `_add_returned_item` |
| `src/pool.zig:322` | `Pool.close` |

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

That is `Mbox.send` minus the mailbox. `slot.* = null` is what does the work;  
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

## 8. Decisions — round 6

Answered by the owner on 2026-07-30. Numbering is preserved from 004 — Q25-Q34  
are cited by number in `STATUS-LOG.md`, `matryoshka-tk-implementation-plan-070.md` and `context.md`, so the  
labels stay even though these are no longer questions.

Every full argument lives in sections 5-7. This section records what was decided  
and why, not the reasoning that produced it.

**Shipped 2026-07-30 as API 9.** See section 11.

### Q25 — the protection list — closed

The API 8 migration ran with three protections applied as written, and all three  
held: `tests/layer1_polynode.zig` scenarios 6, 7 and 8 are still on raw links,  
`polynode.reset` and `polynode.is_linked` are still public with unchanged  
signatures, and the test count went 171 to 175, never down. Recorded in  
§Q25 of an earlier version of this document.

The second half of the question — is anything else off-limits — was asked again  
against the stage this section defines. **Answer: nothing else off-limits.**

What that does not license: the stage's own decisions still bound it. Q27 = A  
keeps the `is_linked` name, Q31 = A adds to `append`/`prepend` rather than  
replacing them, and Q33 = A keeps all seven assert lines. Those are constraints  
from decisions, not from a protection list.

### Q26 — `PolyNode` gains no debug field — **D**

**Decision.** No state is added to `PolyNode`. Not the `bool` link mark, not the  
`?*const anyopaque` owner field.

**Why.** Section 7.1. Any flag written into an item is written under whichever  
mutex that item's current list sits behind, so two lists behind two mutexes race  
on it in exactly the case the flag exists to catch. Atomics would protect the  
flag, not the topology. The same argument reaches `prev` and `next`, which is why  
the conclusion is general: no state stored in an item can validate this class of  
mistake.

**Reverses** the recommendation A that item-list-002 made twice. The reversal is  
in an earlier version of this document.

**What this costs, stated plainly.** The seven assert lines of 5.2 stay blind for  
a list of one. `PolyHelper.destroy` keeps guarding a use-after-free with a check  
that cannot see it. Misuse cases 1 and 5 stay open and there is no proposal that  
closes them. That is the price of D and it is not recovered elsewhere — Q34  
recovers cases 2 and 4, which are different cases.

### Q27 — `is_linked` keeps its name, the doc comment is corrected — **A**

**Decision.** The function stays `is_linked` with its current signature. The doc  
comment at `src/polynode.zig:67` is rewritten to claim only what the function  
computes: whether the node has neighbours.

**Why.** With Q26 at D the function cannot be made exact, so the only question is  
what it claims. The present comment — "True if the node is linked into a list" —  
is false for a list of one, and a false statement in a public doc comment is the  
worst of the three options. Renaming to `has_neighbours` would be honest but  
changes nine call sites, including `examples/layer1/021-define_type.zig:48`, and  
teaches a caller nothing the corrected comment does not.

**What it does not promise.** A caller reading `is_linked(ih) == false` still  
learns nothing about whether the item is in a list. The comment stops lying; the  
function is unchanged.

### Q28 — `concat` asserts `other != self` — **yes**

**Decision.** Under `std.debug.runtime_safety`, `concat` asserts its two  
arguments are different lists.

**Why.** Self-concat silently empties the list and leaks every item in it. The  
check is section 7.2 — a pointer comparison between two arguments the caller  
already passed in, needing no shared state and no build-mode reasoning beyond  
the safety gate. It is independent of every other decision here and could ship  
alone.

### Q29 — a dedicated test file — answered earlier

`tests/layer1_itemlist.zig`. Pins current behaviour before any of this changes.  
Second in the ship order below.

### Q31 — `ItemList` gains slot-taking inserts — **A**

**Decision.** Both are added:

```zig
pub fn appendFromSlot(self: *ItemList, slot: *Slot) void
pub fn prependFromSlot(self: *ItemList, slot: *Slot) void
```

Four call sites migrate. `append` and `prepend` stay for the stack-item case —  
`EventPolyHelper.toPoly(&ev)` has no slot to take from.

**Why.** Section 7.4. This is prevention, not detection: the hazard of misuse  
case 3 is that a caller inserts from a slot and forgets to clear it, and an API  
that clears the slot itself makes the mistake unavailable rather than detectable.  
B — `appendFromSlot` only — leaves the pair asymmetric, which gets noticed later  
and reopened for no gain, since the second function is three lines.

**Naming and behaviour.** Follows the API 6 rule: a `move`- or `from`-prefixed  
operation empties its source. On a null slot it asserts, following `send` rather  
than `put` — `put` is tolerant because it is the standard `defer` target, and an  
append is not.

**Independent of Q26.** No field, no build-mode condition. With Q26 at D this is  
the half of the work that has a user-visible payoff.

### Q32 — the stage is "intrusive safety" — **A**

**Decision.** The stage is named for the subject, not for the type the work  
arrived through. `ItemList` is one caller of `PolyNode`, and the asserts that  
benefit live in `src/mailbox.zig`, `src/pool.zig` and `PolyHelper` — none of them  
`ItemList`.

**Why not "ItemList round 2".** That is how the work arrived, not what it is. A  
stage named after `ItemList` would make the mailbox and pool asserts look  
incidental to it, and would make the next intrusive container look like new work  
rather than a beneficiary of this one.

**Ship order.**

1. `appendFromSlot` / `prependFromSlot` (Q31). Prevention. No dependency, and the
   only item with a user-visible payoff.
2. `tests/layer1_itemlist.zig` (Q29), pinning current behaviour before it changes.
3. The walk (Q34) and `is_linked`'s disposition (Q27, Q33). Detection.
4. `concat`'s identity assert (Q28).
5. Docs.

**Prevention before detection.** A bug that cannot happen needs no assert, and  
step 1 removes the hazard for the four real call sites whether or not the rest of  
the stage is ever approved.

### Q33 — the seven assert lines stay, and the hole is documented — **A**

**Decision.** All seven `!is_linked` source asserts stay in place. What they are  
worth is written down: a rules entry stating that the check catches the  
multi-element case and is blind for a list of one.

**Why.** Forced by Q26 = D — if nothing can repair `is_linked`, seven production  
asserts promise a guarantee they do not keep, and the choice is between keeping a  
partial guard and deleting it. They do catch something: most real double-sends  
happen against a list that holds more than one item. B would delete a partial  
guard on a use-after-free and gain nothing but consistency.

**Three test comments are corrected** under this answer, because they read as  
though the check works: `layer1_polynode.zig:71`, `layer2_mailbox.zig:598`,  
`layer3_pool.zig:808`. Scenario 88's comment already documents the hole —  
*"single-node list has prev==next==null"* — written around the defect rather than  
reporting it.

**What the walk cannot do for this.** `PolyHelper.destroy` and `moveFromSlot` are  
passed a `Slot` and have no list to interrogate, so Q34 does not reach the two  
sites where this matters most. That is why A is a resting state and not a fix.

### Q34 — the container walk, all four inserts — **C**

**Decision.** Under `std.debug.runtime_safety`, every insert asserts against the  
container's own contents:

```zig
fn _holds(self: *const ItemList, ih: ItemHandle) bool {
    var it = self._list.first;
    while (it) |n| : (it = n.next) if (n == &ih.node) return true;
    return false;
}
```

- `append`, `prepend`, and both directions of `insertAfter`: `assert(!_holds(ih))`
- `insertAfter` additionally: `assert(_holds(existing))`

Closes misuse cases 2 and 4.

**Why it survives the argument that killed Q26.** The walk computes the address  
`&ih.node` and never dereferences the item. It writes nothing, and reads only the  
chain the container already owns under the container's own lock. It is not  
in-item state, so it is not an option of A/B/C in Q26 — it is a different  
question with a different answer.

**Why C and not D.** D — the same walk behind a length cap — was recorded as the  
fallback if Debug throughput on mailbox or pool measurably suffers, and only  
then. A cap makes the assert's guarantee conditional on list length, which is a  
worse thing to document than an honest O(n) under safety builds. The argument  
against C is placement, not complexity: every internal insert already holds a  
mutex, and Debug is where the concurrency tests run.

**Also applies to `Mbox.send` and `Pool.put`**, which hold their own lists  
under their own locks. Same walk, same soundness, larger lists. This is the part  
inherited from Q33.

**What it does not promise.** Nothing about misuse case 1 — an item in *another*  
list is not reachable from `self`. Nothing outside safety builds.

---

## 9. Required follow-up — done

- **The happens-before invariant of 3.2** — done 2026-07-30, now in
  `rules-047.md` ("Exclusive access, second half") and `matryoshka-concepts-002.md` ("The transfer  
  orders memory"). Step 0 of the ship order.
- **`src/polynode.zig:67`** — the `is_linked` doc comment now claims only what
  the function computes: whether the node has neighbours.
- **`tests/layer3_pool.zig:627`** — the comment is gone with the line it
  explained. The site is `batch.appendFromSlot(&slot)`, which empties the slot  
  itself.

---

## 10. History

005 replaced 004 and composed the document by subject. 006 answered the round 6  
questions in place, turning section 8 from a question list into a decision  
record. 007 records what shipped against it. No decision in sections 1-4 or 8  
changed.

---

## 11. What shipped — API 9

Approved and built 2026-07-30, in the ship order of Q32. 177/177 tests across  
Debug, ReleaseSafe, ReleaseFast and ReleaseSmall; cross-compile clean.

### 11.1 Prevention (Q31)

```zig
pub fn appendFromSlot(self: *ItemList, slot: *Slot) void
pub fn prependFromSlot(self: *ItemList, slot: *Slot) void
```

Each asserts the Slot holds an item, inserts, and empties the Slot. All four  
call sites migrated: `examples/layer1/023-tag_dispatch.zig` (two),  
`examples/layer1/025-produce_consume.zig`, `tests/layer3_pool.zig`. The  
`slot = null` line no longer appears in any of them, so misuse case 3 is not  
writable at those sites.

`append` and `prepend` stay, unchanged, for the stack-item case.

**Departure from the 7.4 sketch.** The sketch carried a second assert,  
`!is_linked(slot.*.?)`. It was not written. 7.4 itself calls that line  
"inherited habit, not mechanism", and the container walk of 11.2 covers the  
same case exactly, where the assert covered it only in part.

### 11.2 Detection (Q34, Q28)

`ItemList._holds` — private, O(n), the walk of 7.3 verbatim. Called from three  
asserts, all behind `if (std.debug.runtime_safety)`:

| method | assert |
|---|---|
| `append`, `prepend` | `!_holds(ih)` |
| `insertAfter` | `_holds(existing)` and `!_holds(ih)` |

`concat` asserts `self != other` (Q28) — a pointer comparison, not a walk, and  
not gated, since `std.debug.assert` is already a no-op outside safety builds.

**Why the safety gate is explicit.** `assert(_holds(existing))` is a *positive*  
assert. With the walk compiled out it would read false and trip `unreachable` in  
a build where `unreachable` is undefined. The `if` also keeps the positive and  
negative forms looking the same, and puts the O(n) cost at the call site where  
it can be seen.

**Not applied to `Mbox.send` / `Pool.put`.** Q34's closing paragraph extends  
the walk to those two. They reach `ItemList.append` and `ItemList.prepend`, so  
they inherit it — no separate code. What was *not* added is a walk of the  
destination list from inside `send` or `put` before the lock is taken.

### 11.3 `is_linked` (Q27, Q33)

Name and signature unchanged. All seven `!is_linked` asserts kept. The doc  
comment at `src/polynode.zig:67` now says "True if the node has neighbours" and  
states the sole-member case outright. The rules entry is in `rules-047.md`  
("The neighbour check"), and the three test comments of Q33 are corrected.

### 11.4 Tests (Q29)

`tests/layer1_itemlist.zig`. Scenarios 100-103 moved out of  
`tests/layer1_polynode.zig` unchanged — they are `ItemList`'s own contract, and  
that file is `PolyNode`'s. Scenarios 104 and 105 are new: the slot-emptying  
guarantee of both new methods, and the `popFirst` → `appendFromSlot` round trip,  
which shows a popped handle is a legal Slot value.

Test count 175 → 177.

### 11.5 What is still open

Unchanged by this stage, and stated in §6: **misuse cases 1 and 5**. An item  
held by a *different* list is not reachable from `self`, and  
`PolyHelper.destroy` holds a Slot rather than a list. Q26 = D says why nothing  
here reaches them.

Cases 6, 7 and 8 remain documented sharp edges.

---

## 12. What shipped — API 10

**2026-07-31, 182/182 tests.** Prompted by an external review of  
`src/polynode.zig`: implementation 8.5/10, comments 3/10.

### 12.1 The list is complete (reverses §2.3)

`remove`, `popLast`, `first`, `last`, `insertBefore` added.

§2.3 declined them on the "first real call site" rule. The rule assumes an  
omitted method costs nothing until someone needs it. For `remove` that is  
false: a caller who needs it and does not have it reaches through `_list`, and  
the `_list` doc comment then has to explain that `polynode.reset` is now their  
job. The gap does not stay a gap — it becomes a documented sharp edge.

`remove` calls `reset`, so it gives the guarantee `popFirst` gives, and taking  
one item out of the middle stops being a raw-links operation. The other four  
are its neighbours: an intrusive list that can `insertAfter` but not  
`insertBefore`, `popFirst` but not `popLast`, is asymmetric for no reason a  
caller can see.

### 12.2 Both checks, not one (widens §7, does not revisit it)

Q26 = D chose "ask the container, not the item", and `_holds` was written that  
way. Every insert now also asserts `!is_linked` on the new item.

Neither check is complete, and they fail on opposite cases:

| check | sees | blind to |
|---|---|---|
| `_holds` | this list, including a list of one | any other list |
| `is_linked` | any list | the list holding the item alone |

Reading the item is what Q26 = D avoided, because the item's links sit under  
whichever list's mutex currently holds it. That objection stands. Two things  
outweigh it: `PolyHelper.moveFromSlot` and `PolyHelper.destroy` already assert  
`!is_linked`, so the precedent is in the same file; and the addition is strictly  
additive — `_holds` is unchanged, and `is_linked` only widens coverage to  
**misuse case 1**, which §11.5 listed as open.

Misuse case 1 is now partly covered. Case 5 is not.

Owner's instruction: "DoublyLinkedList checks nothing, ItemList should check  
everything."

### 12.3 `concat` self-concat is a leak (strengthens Q28)

Q28 added `std.debug.assert(self != other)`. That assert is `unreachable`  
outside safety builds, so ReleaseFast runs the call.

Traced through `std/DoublyLinkedList.zig:62`. With `list1 == list2`:

```zig
l1_last.next = list2.first;   // ring
l2_first.prev = list1.last;
list1.last = list2.last;
list2.first = null;           // the same header
list2.last = null;
```

The list comes back **empty** and every item in it is unreachable in a cycle.  
Not a no-op, not a corruption to be caught later — a silent leak of the whole  
list.

Fix: keep the assert, add `if (self == other) return;`. The assert still names  
the caller's bug loudly where safety is on; the early return makes it a no-op  
where it is off. Scenario 103 tests the early return under  
`if (!std.debug.runtime_safety)`, since the assert is what runs everywhere else.

### 12.4 `iterate` → `iterator`

The std name. Breaking, no deprecation shim — six in-repo call sites  
(`src/pool.zig`, `tests/layer1_itemlist.zig`, `tests/layer4_cancel.zig`) and  
three design docs. No example used it.

### 12.5 `moveFromList` checks its argument

Asserts `(list.first == null) == (list.last == null)`. It is the one entry point  
that accepts a header built outside the toolkit, so it is the one place a  
half-set `std.DoublyLinkedList` can walk in.

### 12.6 Review points not acted on

| point | why not |
|---|---|
| "`popFirst`'s mention of `reset()` leaks implementation" | It is a documented std-compatibility guarantee — see `kitchen/docs/api/polynode/stdlib-compatibility.md`, "popFirst clears the links". Repairing that std trap is the method's reason to exist |
| "the `_list` comment is poor English" | Owner's own prose. Owner's decision: leave it |
| "`_holds` needs documentation" | `_holds` is private. Its comment was trimmed to two lines |

### 12.7 What is still open

**Misuse case 5** — `PolyHelper.destroy` holds a `Slot`, not a list, so no  
container is reachable from it. Unchanged.

**Misuse case 1** — partly covered now. An item alone in a different list still  
passes both checks: `_holds` cannot see that list, and `is_linked` is false for  
its only member. The `std.DoublyLinkedList` gap of §5 is the reason, and nothing  
in API 10 repairs it.

Cases 6, 7 and 8 remain documented sharp edges.
