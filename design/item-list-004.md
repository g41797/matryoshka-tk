# ItemList (004)

Versioned doc. Replaces [item-list-003.md](item-list-003.md).

Working document for API 8.

Describes the problem and the proposed solution.

Written before the code. The type, the tests, and the docs are built from this  
document.

Not an example. Not a pattern page. Not an API reference page.

One difference from [receive-router-001.md](receive-router-001.md), the document  
this one is modelled on: that one argued why a piece of code stays *outside*  
`src/`. This one changes `src/` public API. So its readers include the API  
reference and the rules, not only a pattern page and an example.

Round 6. API 8a-8d were implemented from version 001 — the type, the migration,  
and the docs all shipped, 175/175 tests.

Version 002 asked what `ItemList` inherits by forwarding to a container that  
validates nothing, and proposed a debug-only `bool` on `PolyNode` to fix the  
`is_linked` defect it turned up.

**Version 003 withdrew that proposal.** A concurrency argument from the owner  
showed the field cannot work, and that the argument reaches further than the  
field: no state stored in an item can validate this class of mistake. The  
reasoning is in "Why no state on `PolyNode`" below, and Q26's recommendation is  
reversed there from A to D.

The withdrawal is visible rather than edited away. Version 002 recommended A  
twice, and a reader deciding Q26 needs to see what changed and why.

**This version recovers part of what the withdrawal lost.** The owner observed  
that "insert an item already in this list" can be caught by walking the list  
before the insert. That is not a variant of the withdrawn field — a walk writes  
nothing and reads only the container's own chain — so it survives the argument  
that killed the field, and it closes two of the eight misuse cases the coverage  
table lists. Q34 is new, and two rows of the coverage table are corrected with  
the correction shown rather than edited away.

Q26-Q34: Q29 and Q30 are answered, Q26 carries a recommendation of D, and Q26,  
Q27, Q28, Q31, Q32, Q33, Q34 are open. Q34 is new in this version, Q33 was new  
in 003.

Everything from 001 is unchanged and stays agreed. API 8 as shipped is not in  
question anywhere in this document.

Reading order for the new material, shortest path first:

- "Why no state on `PolyNode`" — the argument that decides Q26, and the
  synchronization invariant it forces into the open.
- "Whose problem is it" — Q26-Q28 harden `src/` against mistakes only `src/` can
  make. Q31 is the one a user hits.
- Q31 — needs no field, no build-mode condition, ships alone. With Q26 answered
  D, this is the whole of API 9's user-facing value.
- "Coverage — case by case" and Q34 — the eight misuse cases as a table, and how
  far the walk goes. New in this version.
- Q33 — what becomes of `is_linked` once nothing can repair it.
- Q32 — what the next stage is, and the order inside it.
- "The debug-only link mark" — kept as the record of the withdrawn proposal.
  Read it only to see what was rejected.

Two short sections carry things this document had left implicit: "What  
`ItemList` is not" and "Invariants".

---

## The problem

Application code re-enters the toolkit like this:

```zig
const poly: *polynode.PolyNode = @fieldParentPtr("node", node);
const ev: *items.Event = items.Event.EventPolyHelper.fromNode(poly) orelse return error.CastFailed;
```

Two steps. The first is a compiler builtin about struct layout.

`src/polynode.zig:14` promises the opposite:

> You don't need to deal with @fieldParentPtr.

The promise does not hold today.

### Why it happens

Five public signatures speak `std.DoublyLinkedList`.

- `mailbox.receive_batch` — `src/mailbox.zig:241`
- `mailbox.close` — `src/mailbox.zig:268`
- `pool.put_all` — `src/pool.zig:306`
- `PoolHooks.on_put` — `src/pool.zig:72`
- `PoolHooks.on_close` — `src/pool.zig:79`

The element type of that list is `*std.DoublyLinkedList.Node`.

It is not `ItemHandle`.

Everywhere else the toolkit carries `ItemHandle` or `Slot`. At these five points  
the vocabulary drops to a raw std node. Every caller converts back by hand.

### The language allows no shortcut

From `zig-x86_64-linux-0.16.0/doc/langref.html`, `struct` section:

> Zig gives no guarantees about the order of fields and the size of the struct
> but the fields are guaranteed to be ABI-aligned.

And, next to the `@fieldParentPtr` example:

> Struct field order is determined by the compiler, however, a base pointer can
> be computed from a field pointer.

`PolyNode` is a plain struct. `node` is written first in the source. That says  
nothing about its offset.

So:

- `*std.DoublyLinkedList.Node` and `*PolyNode` are not the same pointer.
- `@ptrCast` between them is unsound.
- `@fieldParentPtr` is the only defined conversion.

A caller cannot route around the builtin. Either it appears in application code,  
or the toolkit owns it. There is no third choice.

Checked: nothing in the repo assumes pointer identity today. All 14  
`@ptrCast`/`@alignCast` sites convert `*anyopaque` to a hook context. No  
`@offsetOf`. No `@intFromPtr`.

### Both directions

Counted across `examples/`, `tests/`, `stories/`.

| direction | shape | sites |
|---|---|---|
| inbound | `@fieldParentPtr("node", node)` | ~30 |
| inbound | `popFirst` walk | 34 |
| outbound | `list.append(&x.poly.node)` | 15 |

The outbound half is already an open gate — API 7e (`toListNode`) in
[matryoshka-tk-implementation-plan-048.md](matryoshka-tk-implementation-plan-048.md).

It is the other side of this question. Not a separate one.

### The reset trap

`std.DoublyLinkedList` leaves `prev`/`next` stale on every removal.

- `polynode.reset` must be called by hand after each pop.
- The rule is written down in [rules-028.md](rules-028.md).
- 34 pop sites in user code. 13 `reset` calls.

It has already cost a bug. `_add_returned_item` panicked on composite lists of  
three or more items — the API 5 follow-up.

A written rule is a trap. It is not a guard.

### One cause

The toolkit hands out a std container it does not control, holding nodes it does  
not name.

---

## The proposal

A list type that speaks `ItemHandle`.

It completes a trio already in place.

- `ItemHandle` — one item.
- `Slot` — zero or one item.
- `ItemList` — many items.

`ItemHandle` is not new here. It is the toolkit's public transport type since  
API 4 — what `receive` returns, what `send` takes, what a `Slot` holds. The  
question "why not just hand out `*PolyNode`?" was answered then: application code  
names the handle, `src/` names the layout. `ItemList` invents no vocabulary. It  
extends the existing one from one item to many.

```zig
while (batch.popFirst()) |ih| {
    const ev: *items.Event = items.Event.EventPolyHelper.fromNode(ih) orelse return error.CastFailed;
```

One step. No builtin. No `reset` to remember.

Seven of the eight `@fieldParentPtr` sites in `src/` are the same pop-cast-reset  
triple. `ItemList.popFirst` is those three lines, named once — see the evidence  
below.

---

## The design — proposed

Every row below is a proposal for review. Reasoning follows once they are agreed.

### The type

| decision | value |
|---|---|
| name | `ItemList` |
| location | `src/polynode.zig`, beside `ItemHandle`, `Slot`, `reset`, `is_linked` |
| representation | `_list: std.DoublyLinkedList = .{}` — composition |
| `._list` field | reachable, but named to say "not yours". It exists so tests can manipulate raw links, and as the fallback for code holding a `*std.DoublyLinkedList` that `moveFromList` cannot serve. Application code does not need it |
| casting | none. `@ptrCast` to `*std.DoublyLinkedList` is unsound |
| `extern struct` | not available — `std.DoublyLinkedList` is a plain struct |

### Methods

| method | value |
|---|---|
| `append(self, ih)` | takes `ItemHandle` |
| `prepend(self, ih)` | takes `ItemHandle` |
| `insertAfter(self, existing, ih)` | both take `ItemHandle` |
| `popFirst(self)` | returns `?ItemHandle`. Calls `polynode.reset` first |
| `isEmpty(self)` | replaces every `list.first == null` check |
| `len(self)` | forwards std's walk. O(n) |
| `iterate(self)` | non-destructive walk. Yields `ItemHandle`. No `reset` |
| `concat(self, other)` | moves `other`'s items in. Empties `other` |

### Moving between the two vocabularies

| decision | value |
|---|---|
| std to ItemList | `moveFromList(list: *std.DoublyLinkedList) ItemList` |
| ItemList to std | `moveToList(self: *ItemList) std.DoublyLinkedList` |
| both | empty the source |
| cost | O(1). A `{first, last}` value copy. No walk. No `reset` |
| `fromList` / `toList` | do not exist. A header copy aliases, it does not borrow |
| failure | none. No optional. No `must` variant |
| `moveFromList` shape | returns a fresh `ItemList`. Does not fill an existing one |

### Not included

| omitted | reason |
|---|---|
| `pop` | no caller |
| `remove` | no caller |
| tag-aware operations | no caller. Dispatch is already `Helper.fromNode(ih)` |

### Inside the toolkit

| decision | value |
|---|---|
| `_Mailbox.list` | `ItemList` |
| `_Mailbox.oob_last` | `?ItemHandle`, was `?*std.DoublyLinkedList.Node` |
| `_Pool.lists` | map of `ItemList` |
| `_concat` (`pool.zig:415`) | deleted. Becomes `ItemList.concat` |
| `_Mailbox.len`, `_Pool.counts` | stay. `len` never replaces them |
| end state | `@fieldParentPtr` survives in three places: `ItemList.popFirst`, `ItemList.Iterator.next`, and `PolyHelper.fromNode`. All in `src/polynode.zig` |

### Consequences

| decision | value |
|---|---|
| public signatures changed | 5 |
| API 7e (`toListNode`) | superseded. `append` takes an `ItemHandle` already |
| migration | one atomic stage. `src/` and call sites change in the same compile |

### What `ItemList` is not

Stated permanently, so later rounds do not have to re-derive it.

`ItemHandle` carries one item. `Slot` carries zero or one. `ItemList` carries  
many. All three are the same kind of thing: a way to move items that already  
exist. None of them is a container in the allocating sense.

So `ItemList`:

- is intrusive, and stays intrusive. The links live in the item.
- never allocates, and never holds an allocator.
- never copies or clones an item.
- never frees an item, and never inspects a payload.
- is not tag-aware. Dispatch stays `Helper.fromNode(ih)` — Q14.
- gains no method because `std.DoublyLinkedList` has one. Only because a caller
  in this repo needs it — the rule the evidence table below enforces.

The last two are the ones under pressure. Every round so far has proposed a  
method; the evidence table is what has kept the surface at nine.

### Invariants

What holds for every `ItemList`, independent of which methods exist.

- An item appears in at most one list, at most once. Nothing enforces this
  today — that is Q26.
- Order is preserved by every operation. `concat(self, other)` keeps `self`'s
  order, keeps `other`'s order, appends the second to the first, and leaves  
  `other` empty. All three, not just the last.
- No allocation, ever. Every operation is a pointer update.
- An empty list is `.{}`. There is no other empty representation, and no `deinit`.
- Moving a list never walks its items. `concat`, `moveFromList`, and `moveToList`
  are O(1). Q26 option B would break this; that is the reason it is refused.
- `popFirst` always returns an unlinked item. `polynode.reset` has already run —
  Q7.
- `iterate` promises the minimum: it does not unlink, does not `reset`, and does
  not tolerate the list's shape changing while it runs. Link something, or pop  
  something, and the live iterator is invalid. It is a read, not a cursor.
- `_list` is the one hole in all of the above. See "One view at a time".

---

## Evidence for the method surface

Every list operation used anywhere in the repo today.

| operation | sites |
|---|---|
| `popFirst` | 31 |
| `append` | 16 |
| `prepend` | 3 |
| `insertAfter` | 1 — `mailbox.zig:117`, OOB send |
| `first == null` | 3 in user code, 4 in `src/` |
| non-destructive walk | 2 in user code, 1 in `src/` |
| `pop` | 0 |
| `remove` | 0 |
| `concatByMoving` | 0. `_concat` is the hand-written equivalent |

The proposed surface covers every one. Nothing in it lacks a caller.

### The internal shape that drives `popFirst`

Seven of the eight `@fieldParentPtr` sites in `src/` are the same three lines.

```zig
const node = list.popFirst().?;
const poly: *polynode.PolyNode = @fieldParentPtr("node", node);
polynode.reset(poly);
```

- `mailbox.zig:185-193` — `receive`
- `mailbox.zig:221-229` — `try_receive`
- `pool.zig:202-205` — `get_wait`
- `pool.zig:439-442` — `_get_available_or_new`
- `pool.zig:488-491` — `_get_available_only`
- `pool.zig:275-277` — `put`, the hook's returned list
- `pool.zig:322-324` — `put_all`

`ItemList.popFirst` is those three lines, named once.

The eighth site is `pool.zig:314-318` — a non-destructive walk that validates  
every tag under one lock before any item moves. That is the caller for  
`iterate`.

---

## What forwarding inherits

New in 002. Version 001 never asked this question.

`ItemList` forwards to `std.DoublyLinkedList`. That container validates nothing,  
by design — it is a raw intrusive primitive. Every method it exposes assumes the  
caller already knows the node's state.

Verified by running each case against the shipped `std`:

| misuse | what std does | detected? |
|---|---|---|
| `concat(&self)` — self-concat | list silently empties. `first=null`, `last=null`. Every item leaked | no |
| `append` a node already in another list | both lists claim it, `prev` reset to null | no |
| `insertAfter(existing, ih)` where `existing` is in a different list | splices across lists, corrupts both | no |
| `append` a node already in *this* list | cycle | no |

`pop` and `remove` are the other two, and they are already closed — Q13 omitted  
both, so `ItemList` has no way to reach them.

### The defect below it: `is_linked` is unsound

The guard the toolkit already uses does not work.

```
sole member of a list:  prev=null, next=null
is_linked() reports:    false
but list.first == &a:   true
```

A node that is the only item in a list has both links null, because `std` never  
sets them. `polynode.is_linked` reads exactly those two fields.

This predates API 8. It is not caused by `ItemList`. Four existing asserts rest  
on it:

| site | assert | what slips through |
|---|---|---|
| `PolyHelper.destroy` | `!is_linked(poly)` | frees an item still held as a mailbox's sole item — use-after-free |
| `PolyHelper.moveFromSlot` | `!is_linked(node)` | same |
| `pool.zig` `_add_returned_item` | `!is_linked(item)` | re-inserts an item that is another list's sole member — both lists corrupt |
| `mailbox.send` | Open Item 11 | same |

`ItemList` is the first place that can fix it, which is why it lands here and  
not in its own stage.

### Why tests alone do not decide it

A test pins behaviour that exists. If `ItemList` keeps forwarding blindly, a  
misuse test can only assert that corruption happens — which writes the bug into  
the test suite as expected behaviour.

The validation decision comes first. The tests come second, and what they assert  
depends on the answer to Q26.

---

## Whose problem is it

Asked by the owner after the validation questions were drafted, and it reframes  
them.

### Ours

`concat` and `insertAfter` have no application caller. `concat` is called once,  
by `pool.close`. `insertAfter` is called once, by `mailbox.zig:117`, the OOB  
send. Both are internal, and the misuses in the table above are unreachable from  
outside `src/`.

Guarding them is defensive work on our own code. Worth doing, not worth leading  
with.

### Theirs

`ItemList.append` is the only transfer in the toolkit that does not follow the  
Slot Rule.

| operation | signature | empties the slot |
|---|---|---|
| `mailbox.send` | `(mbh, slot: *Slot)` | yes |
| `mailbox.send_oob` | `(mbh, slot: *Slot)` | yes |
| `pool.put` | `(ph, slot: *Slot)` | yes |
| `PolyHelper.moveFromSlot` | `(slot: *Slot)` | yes |
| `ItemList.append` | `(ih: ItemHandle)` | no — it cannot |

It takes a handle, so there is no slot for it to clear. Every call site in the  
repo pays for that. All four write the clear by hand on the next line, and one  
documents why:

```zig
batch.append(slot.?);
slot = null;
```

`tests/layer3_pool.zig:627` even carries a trailing comment explaining that the  
item now belongs to the batch — a comment that would be unnecessary if the  
operation emptied the slot itself.

- `examples/layer1/023-tag_dispatch.zig:32,40`
- `examples/layer1/025-produce_consume.zig:30`
- `tests/layer3_pool.zig:627`

### Why the two defects compound

Forget that `slot = null`, and the defer-destroy-early idiom — the shape  
`patterns-019` recommends as standard — fires `destroy` on an item that is now  
linked into a list. The guard is `assert(!is_linked)`.

For the first item appended to an empty list, `is_linked` returns false.

So the single-member hole is not an edge case in this path. It is the most  
likely case, because the first append is always into an empty list. The result  
is a use-after-free that the toolkit's own recommended idiom produces and the  
toolkit's own assert misses.

### What follows

The link mark *detects* the mistake after it is made. A slot-taking append  
*prevents* it, and restores the one-shape-for-all-transfers rule that API 4  
through API 7 built.

API 9 leads with the second and carries the first as defence in depth. See Q31.

This is not a regression. Before API 8 the same sites read  
`list.append(&slot.?.*.node); slot = null;` — the hazard was identical. API 8  
did not create it. It had the chance to close it and did not.

---

## The debug-only link mark

**Withdrawn. Kept as the record of what was rejected and why.** The section that  
follows this one, "Why no state on `PolyNode`", is the argument that killed it.  
Nothing below is a live proposal.

It stays in the document because the reasoning is sound as far as it goes — the  
`@sizeOf` measurements are real, the O(1) argument against the pointer variant  
is real, and the four-becomes-six assert count matters to Q33. What it lacks is  
a concurrency argument, and that turns out to be the whole question.

The shape proposed for Q26, explained in full.

### What it solves

Today "is this item in a list?" is *inferred* from `prev` and `next`. The  
inference is wrong for a list of one, because `std` leaves both null.

The fix is to stop inferring and record the fact.

```zig
const LinkMark = if (std.debug.runtime_safety) bool else void;

pub const PolyNode = struct {
    node: std.DoublyLinkedList.Node = .{},
    tag: *const anyopaque = undefined,
    _linked: LinkMark = if (std.debug.runtime_safety) false else {},
};
```

- `ItemList.append`, `prepend`, `insertAfter` set it.
- `popFirst` and `polynode.reset` clear it.
- `polynode.is_linked` reads it instead of the two pointers, and is then exact.

The six existing asserts — 002 miscounted them as four, see Q33 — would be  
repaired without touching any of their call sites: `PolyHelper.destroy`,  
`PolyHelper.moveFromSlot`, `_add_returned_item`, `mailbox.send`,  
`mailbox.send_oob`, and `pool.put` all keep calling `is_linked`, and it starts  
telling them the truth.

That was the appeal of the proposal, and it is why the withdrawal costs  
something real. Q33 is where that cost is faced.

### Why "debug-only"

`std.debug.runtime_safety` is true in Debug and ReleaseSafe, false in  
ReleaseFast and ReleaseSmall. When false the field is `void`, and a zero-sized  
field occupies no space.

Measured with `@sizeOf` on the shipped compiler:

| PolyNode | Debug / ReleaseSafe | ReleaseFast / ReleaseSmall |
|---|---|---|
| today | 24 bytes | 24 bytes |
| with the field | 32 bytes | 24 bytes |

Shipping builds pay nothing. No bytes, no branches — the asserts compile out  
entirely.

### Why a bool and not a pointer

The first version of this recommendation said a pointer — `?*const anyopaque`,  
recording *which* list an item is in. Measuring it changed the answer.

Space is identical. Both come to 32 bytes under safety, because alignment  
padding absorbs the bool. So the pointer looked free.

It is not free. It costs time.

- A **bool** records *whether* an item is linked. That does not change when a
  list is moved, so `concat`, `moveFromList`, and `moveToList` never touch it.  
  All three stay O(1).
- A **pointer** records *which list*. All three must then re-stamp every item
  they move — O(n) under safety builds. `moveFromList` and `moveToList` being  
  O(1) is a promise this document already makes, in "Moving between the two  
  vocabularies".

What the pointer buys for that price is exactly one extra case: `insertAfter`  
with an `existing` from a different list. That method has one caller in the  
whole repo — `mailbox.zig:117`, the OOB send. Internal, and the `existing` it  
passes is one the mailbox just took from its own list. There is no application  
caller.

Paying O(n) on three operations to guard a case with no reachable caller is the  
wrong trade.

### What it does not fix

Stated so it is not assumed away.

- Items pushed in through `ItemList._list` are never marked. The invariant is
  only as strong as the escape hatch's discipline. That is inherent, and it is  
  why the field carries a leading underscore.
- Cross-list `insertAfter` stays undetected, per the trade above.
- `PolyNode` is a public type whose layout changes under safety builds. That is
  the real cost, and it is the reason Q26 is a question and not a decision.

---

## Why no state on `PolyNode`

The argument that withdraws the link mark. It came from the owner, and it is  
short.

### The field needs an invariant the toolkit does not state

A `bool` on `PolyNode` only works if this holds:

> A `PolyNode` may only be modified while some synchronization mechanism  
> guarantees exclusive access to that node.

Nothing in the toolkit says that today. And the field is written from under  
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

Mutex A and mutex B do not synchronize with each other. So `_linked` is shared  
mutable state with no common lock.

### In a correct program it is fine — for a reason worth stating

If every transfer is correct, the two writes never overlap, and a plain `bool`  
is defined behaviour.

The reason is *not* the mutexes. A's mutex and B's mutex order nothing between  
them. The reason is the pointer.

Thread B cannot touch the item until it learns the address. In this toolkit the  
only way an item's address reaches another thread is through a mailbox or a  
pool, and both are mutex-synchronized. The handoff that delivers the pointer is  
the same edge that orders the writes to it.

That is the invariant, and it is the missing half of the sentence:

> At any instant exactly one Master has exclusive access to an item. No two  
> Masters modify the same `PolyNode` concurrently. Every transfer that moves an  
> item between Masters establishes a happens-before relationship, because the  
> address itself travels only through a synchronized primitive.

`design/rules-030.md:405` already carries the first part — "an object sits in  
exactly one place, in exactly one state, at any moment" — and  
`design/matryoshka-model-003.md:30` carries the exclusive-access claim. Neither  
states the happens-before consequence. That gap is real and it is  
**independent of Q26**: six existing asserts already rest on it. See Q33.

### In the buggy program the field itself races

Now take the mistake the field exists to catch — two Masters manipulating one  
item:

```text
Thread A                  Thread B

_linked = false           _linked = true
```

Concurrent, unsynchronized, no happens-before edge. That is a data race, and a  
data race is undefined behaviour.

So the debug field intended to detect a bug introduces undefined behaviour while  
trying to detect it. It is sound exactly when it is unnecessary, and undefined  
exactly when it would fire.

### Making it atomic proves nothing

An `atomic bool` removes the data race. It does not remove the bug.

```text
Thread A                  Thread B

append()                  append()
  reads _linked == false    reads _linked == false
  CAS to true               CAS to true
```

One CAS wins, one loses — depending on timing, and only if the check is written  
as a CAS at all, which an assert is not. Either way both threads then run the  
insertion, and the list topology is corrupted regardless of what the flag says.

The atomic protects the flag. The list is what needed protecting. Flag-atomicity  
is not topology-atomicity, and no amount of the former buys the latter.

### The argument reaches `prev` and `next` too

This is the step that makes the conclusion general rather than a verdict on one  
field.

`is_linked` today reads `node.node.prev` and `node.node.next`. Those are written  
under whichever mutex the current list sits behind — exactly like the proposed  
bool. In the buggy scenario above, `prev` and `next` race, `is_linked` reads  
unsynchronized state, and it is undefined behaviour in Debug **today**.

The bool introduces no new race class. It inherits the one already there.

So the argument does not say a bool is worse than pointers. It says something  
stronger:

> No state stored in the item can detect cross-Master misuse, because reading  
> that state requires the very exclusivity whose absence is the bug.

That rules out the bool, the owner pointer, and any later variant — a generation  
counter included, since reading a counter is the same unsynchronized read.

### What survives

| proposal | survives | why |
|---|---|---|
| Q26 link mark, any shape | no | the argument above |
| Q28 `concat(self, self)` assert | yes | compares two arguments the caller already holds. No shared state, no cross-thread read |
| Q31 `appendFromSlot` | yes | touches only the caller's own slot and the caller's own list, both already exclusively theirs |
| Q34 the walk | yes | added in 004. Writes nothing, and reads only the container's own chain plus an address. See "The walk" |

Prevention was always immune to this line of argument, because it reads nothing.  
Q31 needs no invariant beyond the Slot Rule the toolkit already documents.

The walk, added in 004, is the one form of *detection* that survives, and it is  
worth being precise about why the argument does not touch it. The argument is  
about state kept **in the item**, read by a thread with no synchronization  
against the item's current holder. The walk keeps no state and reads no item. It  
asks the container a question about the container.

That changes the shape of the conclusion. "Detection is not implementable" was  
too strong; the correct statement is narrower:

> Detection that requires knowing a fact about an item is not implementable.  
> Detection answerable from a container's own contents is.

The ordering proposed in Q32 — prevention before detection — survives as a  
preference about sequencing rather than a statement about what is possible.

### What this is not

- Not an argument that `ItemList` is unsafe to use. A program following the Slot
  Rule has no race, and API 8 as shipped is unaffected.
- Not an argument against asserts. Asserts local to one container, comparing
  arguments the caller holds, are fine — that is Q28.
- Not a claim that the misuse is undetectable by any means. It is detectable
  from outside the data: ThreadSanitizer sees the racing writes to `prev` and  
  `next` without any help from a field. What is ruled out is detecting it from  
  state kept *in* the item.

This is why intrusive libraries generally avoid mutable debug fields, and lean  
on transfer rules, container-local assertions, and external sanitizers instead.

---

## Questions

Each question gives the options and a recommendation.

Write answers on the `Answer:` line under each question.

**Decided — Q1-Q24, Q29, Q30.** Shipped as API 8a-8d. These are closed;  
the reasoning is in "Reasoning — the agreed decisions" at the end. Do not reopen  
them to read this document.

**Open — Q25, Q26, Q27, Q28, Q31, Q32, Q33.** Q25 is postponed by choice, not  
undecided. Q26 is recommended D, which is what creates Q33. Q28, Q31, and Q32  
depend on nothing.

Only the seven open ones need attention. Read "Why no state on `PolyNode`"  
first — it is what changed between 002 and 003.

---

### Group A — the fork

Everything else depends on Q1.

#### Q1 — `ItemList`, or the additive fallback?

- A. `ItemList`. Five public signatures change. User code stops naming
  `std.DoublyLinkedList` at all.
- B. Free functions only — `polynode.fromListNode`, `toListNode`, `popItem`.
  No signature changes. User code keeps declaring `std.DoublyLinkedList`, keeps  
  holding raw nodes, and `reset` stays opt-in.

Recommendation: A. B fixes the two-step call site but leaves the cause.

**Answer:** A.

#### Q2 — if A, is the break acceptable in one release?

Every caller of the five signatures changes. There is no deprecation path,  
because the element type changes, not just the name.

Recommendation: yes. The toolkit has no external users yet, and a half-migrated  
tree is worse than a clean break.

**Answer:** yes

---

### Group B — the type

#### Q3 — name?

`ItemList` matches `ItemHandle`. Alternatives: `HandleList`, `PolyList`, `Items`.

Recommendation: `ItemList`.

**Answer:** ItemList

#### Q4 — location?

`src/polynode.zig`, beside `ItemHandle`, `Slot`, `reset`, `is_linked`.  
Alternative: its own file, `src/itemlist.zig`.

Recommendation: `src/polynode.zig`. It is the same vocabulary, and the file is  
still small.

**Answer:** src/polynode.zig

#### Q5 — is `.list` a public field?

You answered: Zig does not have built-in public/private visibility for individual  
struct fields.

Correct, and it settles half the question. `il.list` is reachable from anywhere,  
whatever we intend. So the question is not "can we hide it" but "what do we  
name it and what do we say about it".

- A. Stays `list`. Documented as a supported escape hatch.
- B. Renamed `_list`, matching the `_Mailbox` / `_Pool` / `_concat` convention
  already used in `src/` for "not your business".

Recommendation: A. The field has real callers — `tests/layer1_polynode.zig`  
scenarios 6, 7, 8 manipulate raw links on a list they still hold, and a move does  
not help them. A name that says "private" while the tests use it is a lie.

**Answer:** B. Test can use, user doesn't

#### Q6 — what rule governs `.list`?

`ItemList.popFirst` promises the handle it returns is unlinked. It calls  
`polynode.reset` for you. That is the whole point of Q7.

Reaching through the field skips that:

```zig
const ih = il.popFirst().?;          // reset called. Handle is clean.
const node = il._list.popFirst().?;  // no reset. prev/next are stale.
```

Same list, two ways in, one of them without the guarantee. The failure is the  
`_add_returned_item` bug again — a stale `next` pointer read after the item was  
already removed.

Proposed rule, named "one view at a time": while a caller uses `._list`, the  
`ItemList` guarantees are suspended and `polynode.reset` is theirs to call. Not  
a compiler rule. A sentence in the field's doc comment.

- A. State it in the doc comment. Do not try to enforce it.
- B. Do not state it. The field is raw std, and that is self-evident.

Recommendation: A. The whole reason `ItemList` exists is that "you must remember  
to call `reset`" was written down and still cost a bug. If we leave one door  
where that is true again, the door gets a sign.

**Answer:** A. but write human text

---

### Group C — methods

#### Q7 — does `popFirst` call `reset`?

- A. Yes. The trap becomes a guarantee. A popped `ItemHandle` is never linked.
- B. No. Keep it a thin forward, leave `reset` to the caller.

Recommendation: A. This is the single biggest reason the type is worth having.

**Answer:** A.

#### Q8 — `insertAfter`?

One caller — `mailbox.zig:117`, the OOB send. Internal only. No user-code caller.

- A. Include it.
- B. Leave it out. `mailbox.zig` reaches through `._list` for that one line.

Recommendation: A, so `_Mailbox` holds no raw node at all.

**Answer:** A.

#### Q9 — `len`?

`std`'s `len()` walks the list. O(n).

- A. Forward it.
- B. Leave it out — nothing should be tempted to call it under a lock.

Recommendation: A, with the cost stated in the doc comment. Two test sites count  
this way already.

**Answer:** A. without cost stated in the doc comment

#### Q10 — do `_Mailbox.len` and `_Pool.counts` stay?

They exist because `len()` is an O(n) walk under a lock.

Recommendation: they stay, unchanged. `ItemList.len` never replaces them, and  
the doc comment should say so.

**Answer:** they stay, unchanged

#### Q11 — `iterate`?

Non-destructive walk, yielding `ItemHandle`, no `reset`.

Callers: `pool.zig:314-318` (tag validation under one lock),  
`tests/layer4_cancel.zig:289,529` (counting — `len` would also cover those).

Recommendation: include it. The `pool.zig` caller is real and is not a count.

**Answer:** include it

#### Q12 — `concat`?

`_concat` at `pool.zig:415` is hand-written and empties its source — the same  
operation as `std`'s `concatByMoving`.

- A. `ItemList.concat`, and delete `_concat`.
- B. Keep `_concat` private in `pool.zig`.

Recommendation: A.

**Answer:** A.

#### Q13 — omit `pop` and `remove`?

Neither has a caller anywhere in the repo.

Recommendation: omit both. Add on first real caller.

**Answer:** omit both

#### Q14 — omit tag-aware operations?

`popFirstOf(TAG)`, `splitByTag`, `countOf(TAG)`. `std` structurally cannot offer  
these, so they are the one place `ItemList` could add reach rather than safety.

No caller needs them: `items.freeList` dispatches to a *destructor*, which is  
application knowledge, and per-item dispatch is already `Helper.fromNode(ih)`.

Recommendation: omit. Revisit on a real case.

**Answer:** omit

#### Q15 — a slot-filling pop?

Five internal sites do `popFirst` then `slot.* = poly` —  
`mailbox.zig:194`, `mailbox.zig:230`, `pool.zig:206`, `pool.zig:443`,  
`pool.zig:492`.

- A. `popFirstToSlot(self, slot: *Slot) bool`.
- B. Leave the two lines.

No recommendation. A removes a repeated pair; B keeps the surface smaller and  
keeps the `Slot` assignment visible at the point it happens.

**Answer:** Leave the two lines.

---

### Group D — moving between the two vocabularies

#### Q16 — move only, never copy?

A `{first, last}` copy does not borrow. It aliases. Two headers over the same  
items, and the first `popFirst` on either corrupts the other.

Proposed: no `fromList`/`toList`. Only `moveFromList` and `moveToList`, both  
emptying the source.

Recommendation: yes. It matches the API 6 rule — `fromSlot` inspects and takes  
`*const`, `moveFromSlot` extracts and empties.

**Answer:** move only

#### Q17 — does `moveFromList` return fresh, or fill an existing list?

- A. `moveFromList(list: *std.DoublyLinkedList) ItemList` — returns fresh.
- B. `moveInFrom(self: *ItemList, list: *std.DoublyLinkedList) void` — fills.

Recommendation: A. B needs a Slot-Rule-style "destination is empty" assert, and  
no caller wants merge-into.

**Answer:** A

#### Q18 — is `moveToList` worth having at all?

After migration nothing in the toolkit hands out or takes a std list. Its callers  
would be application code arriving from outside, and the raw-link tests.

- A. Include it, for symmetry with `moveFromList`.
- B. Leave it out. `._list` already reaches the same place.

Recommendation: A. Two lines, and it is the honest answer to "how do I get out".

**Answer:** A

#### Q19 — `moveOut`?

`mailbox.zig:252-253` and `280-281` hand-roll `const result = mbx.list;  
mbx.list = .{};` — a self-move. Two sites today.

- A. `moveOut(self: *ItemList) ItemList`.
- B. Leave the two lines.

No recommendation. The pair is small, but it is the exact operation  
`receive_batch` and `close` both perform.

**Answer:** Leave the two lines.

---

### Group E — reach inside the toolkit

#### Q20 — do `_Mailbox` and `_Pool` use `ItemList` internally?

- `_Mailbox.list` → `ItemList`.
- `_Mailbox.oob_last` → `?ItemHandle`, was `?*std.DoublyLinkedList.Node`.
- `_Pool.lists` → map of `ItemList`.

This is where the builtin actually disappears: seven of the eight  
`@fieldParentPtr` sites in `src/` are the same `popFirst` + `reset` triple.

Recommendation: yes. Afterwards `@fieldParentPtr` survives in exactly two places,  
`ItemList.popFirst` and `PolyHelper.fromNode`, both in `src/polynode.zig`.

**Answer:** yes

#### Q21 — do `PoolHooks.on_put` and `on_close` move to `ItemList`?

They are the hook author's surface, not the caller's.

- A. Both move. One vocabulary everywhere.
- B. Both stay on `std.DoublyLinkedList`.
- C. Split — whichever you prefer, stated per hook.

Recommendation: A. A hook author walks `on_close`'s list item by item and hits  
the same two-step conversion as everyone else.

**Answer:** A.

---

### Group F — scope and order

#### Q22 — is API 7e closed as superseded?

`ItemList.append` takes an `ItemHandle`, so the 5 `list.append` sites 7e targeted  
disappear without a `toListNode` accessor.

- A. Closed as superseded. Not implemented.
- B. Still wanted as its own stage.

Recommendation: A.

**Answer:** A.

#### Q23 — one atomic migration stage, or split?

The element type change forces `src/` and every call site to compile together.

Recommendation: one stage. A tree with some APIs on `ItemList` and some on the  
std type is the confusing state.

**Answer:** one stage

#### Q24 — is the closing gate right?

Proposed: `grep -rn "fieldParentPtr" examples/ stories/` returns nothing.

Given Q20, a stronger gate is possible: the only hits anywhere are the two in  
`src/polynode.zig`, plus the deliberate raw-link tests in  
`tests/layer1_polynode.zig`.

Recommendation: the stronger gate.

**Answer:** the strong gate

#### Q25 — anything that must NOT change?

This is a protection list.

The migration stage touches roughly 80 call sites in one compile. It is the  
stage most likely to change something by accident, on the way to changing  
something deliberately. So: what do I leave alone?

Three proposed, with the reason each is protected.

| protected | reason |
|---|---|
| `tests/layer1_polynode.zig` scenarios 6, 7, 8 | They poke `prev`/`next` by hand. The raw layout **is** the thing under test. Converting them to `ItemList` would test the wrapper instead. They stay on `std.DoublyLinkedList` |
| `polynode.reset`, `polynode.is_linked` | Stay public, same signature. `ItemList` calls them internally. It does not replace them, and a test that asserts `is_linked(ih) == false` after a pop is how Q7 gets verified |
| test count | 171 today. It goes up when 8b adds scenarios. It never goes down. A migration that "simplifies" a test out of existence has removed coverage, not complexity |

Two questions:

- Do you agree with these three?
- Is anything else off-limits that I would not think to ask about?

**Answer:** postpone decision 

### The closing gate

**Decision.** Q24, the strong gate. After migration, the only `@fieldParentPtr`  
in the repo is in `src/polynode.zig` and in the raw-link tests.

```
grep -rn "fieldParentPtr" src/ tests/ examples/ stories/
```

Allowed hits, and nothing else:

| file | why |
|---|---|
| `src/polynode.zig` | `ItemList.popFirst` and `PolyHelper.fromNode`. Plus the `//!` header line that names the builtin to promise you will not meet it |
| `tests/layer1_polynode.zig` | Scenarios 6, 7, 8. The layout is the thing under test |

**Why not the weak gate.** The proposed weak form checked only `examples/` and  
`stories/`. Given Q20 and Q21, that gate would pass with all seven pop-cast-reset  
triples still sitting in `src/mailbox.zig` and `src/pool.zig` — it cannot detect  
the failure of the decision it is meant to protect.

**What this gate costs, measured now.** `@fieldParentPtr` appears in five test  
files today, not one.

| file | sites | after migration |
|---|---|---|
| `tests/layer1_polynode.zig` | 4 | stay. Scenarios 6, 7, 8 |
| `tests/layer2_mailbox.zig` | 5 | convert |
| `tests/layer3_pool.zig` | 1 | convert |
| `tests/layer4_infra.zig` | 1 | convert |
| `tests/layer4_cancel.zig` | 1 | convert |

So the strong gate pulls eight test-side conversions into the migration stage  
that the weak gate would have left alone. They are the ordinary kind — a  
`popFirst` walk over a list handed back by `receive_batch` or `close` — and they  
change for the same reason application code does, because the signature changed.  
Three of them are `freeItem(@fieldParentPtr("node", node), alloc)`, which becomes  
`freeItem(ih, alloc)`.

Stated here because it was not visible when Q24 was written. It does not change  
the answer. It changes the size of stage 8c.

**What it does not promise.** The gate is a grep. It proves the builtin is  
absent, not that `ItemList` is used well.


---

### Group G — validation (new in 002, revised in 003 and 004)

Five separate subjects, deliberately not one:

| | subject | questions | ships alone |
|---|---|---|---|
| in-item state | whether `PolyNode` gains a debug field | Q26 | recommended D — no |
| container-local detection | asking a list about its own contents | Q34 | yes |
| what is left of `is_linked` | its meaning, and the asserts on it | Q27, Q33 | yes |
| container-local asserts | checks needing no shared state | Q28 | yes |
| slot ergonomics | `ItemList`'s API shape | Q31 | yes |
| stage shape | what API 9 is called and its order | Q29, Q30, Q32 | — |

Q26 is recommended D. That does not park the group — it moves the weight onto  
Q31, which needs nothing from Q26, onto Q33, which exists *because* Q26 is D,  
and now onto Q34, which recovers two of the cases D gives up. Q28 also survives  
D untouched, being a plain comparison of two arguments.

The row added in 004 is the one that matters for reading the group. Q26 and Q34  
sound like the same question and are not: Q26 asks the item, Q34 asks the  
container. Only the first is ruled out.

#### Q26 — how does `ItemList` validate its arguments?

Full explanation of the proposed shape: "The debug-only link mark" above.

The question's title is misleading and is kept only so the numbering does not  
move. This is not an `ItemList` problem. "Is this item already linked?" is a  
question about a `PolyNode`, and it is unanswerable today no matter who asks —  
`mailbox.send` asks it, `pool.zig` `_add_returned_item` asks it,  
`PolyHelper.destroy` asks it, and all three get the same wrong answer for a list  
of one. `ItemList` is not the source and is not the fix; it is one more caller.

That matters for where the fix goes. The mark belongs on `PolyNode`, and  
`is_linked` stays the single place that reads it. Anything intrusive added later  
— a queue, a stack, a ring — then inherits a working check without knowing  
`ItemList` exists. If instead `ItemList` carried its own bookkeeping, the next  
container would start over.

- A. **`bool` link mark on `PolyNode`**, compiled to `void` outside safety
  builds. Catches three of the four misuses, repairs all six existing assert  
  sites, and every operation keeps its current complexity.
- B. **`?*const anyopaque` owner field** instead. Also catches `insertAfter`
  with a foreign `existing`, at the cost of making `concat`, `moveFromList`, and  
  `moveToList` O(n) under safety builds.
- C. **Cheap interim, no layout change.** Assert
  `!is_linked(ih) and self._list.first != &ih.node` on insert. Closes only the  
  sole-member-of-*this*-list hole. Does not repair the six existing asserts.  
  **Superseded in 004** — C is this check truncated to the head of the list, and  
  Q34's walk is its complete form. C is now a strictly weaker version of a real  
  option, not an interim, and should be read as "answer Q34 = B" instead.
- D. **Nothing.** `ItemList` forwards, and the sharp edges are documented.

**Recommendation: D. Reversed from A in 003, and unchanged in 004.**

Q34 does not change this answer. The walk is not in-item state, so it is not one  
of A/B/C — it is a separate mechanism, asked separately, and D stays the answer  
to *this* question whatever Q34 turns out to be.

Version 002 recommended A, twice, and the reasoning it gave for that is still  
in the document under "The debug-only link mark". What it never examined was  
concurrency, and concurrency decides the question. The full argument is in "Why  
no state on `PolyNode`" above; in one line:

> The field is written under whichever mutex the item's current list sits  
> behind, so in the buggy case it exists to catch, the field itself races —  
> sound exactly when unnecessary, undefined exactly when it would fire.

Atomics do not rescue it: they protect the flag, not the list topology, and two  
concurrent `append`s corrupt the list whatever the flag ends up saying.

And the argument generalizes past the field. `prev` and `next` are read by  
`is_linked` under the same absent synchronization, so the bool inherits a race  
that is already there rather than adding one. No state kept in the item can  
validate this class of mistake, which retires B and C along with A — and would  
retire a generation counter too, if one were proposed later.

What D costs, stated plainly rather than glossed:

- The six existing asserts stay wrong for a list of one. `PolyHelper.destroy`
  keeps guarding a use-after-free with a check that cannot see it. That is not  
  acceptable as a resting state, which is why D forces Q33.
- The misuse row of Q29's test plan cannot be written for cases 1, 3, 5, 6, 7 and
  8 of the coverage table. Those tests were contingent on A or B. Cases 2 and 4  
  become testable if Q34 is adopted — corrected in 004, where 003 said the whole  
  row was lost.
- The four `ItemList` insert methods keep forwarding without validation, unless
  Q34 is adopted. 003 stated this without the qualifier.

What D does not cost: Q28, Q31 and Q34 all survive untouched. See "What  
survives".

**Answer:**

#### Q27 — does `is_linked` change meaning?

Rewritten in 003. The 002 form of this question assumed Q26 was A or B and asked  
whether the mark or a new `is_held` carried the exact answer. With Q26 at D  
there is no mark, and the honest form of the question is narrower: `is_linked`  
**cannot** be made exact, so what should it say?

- A. Keep the name, fix the documentation. It answers "do I have neighbours",
  and the doc comment says exactly that — no more.
- B. Rename to what it measures — `has_neighbours` — so no caller can misread
  it. Breaking change on a public function.
- C. Leave it as is, including the doc comment that currently reads "True if the
  node is linked into a list" (`src/polynode.zig:67`), which is false for a list  
  of one.

Recommendation: A. C is the status quo and the status quo is a false statement in  
a public doc comment. B is honest but the name is used in a passing example  
(`examples/layer1/021-define_type.zig:48`) and eight test sites, and renaming it  
does not change what any caller can learn.

The larger question — whether the six asserts that call it should exist at all —  
is Q33, because it is not answerable by editing a doc comment.

**Answer:**

#### Q28 — does `concat` assert `other != self`?

Self-concat silently empties the list and leaks every item.

Recommendation: yes, under `runtime_safety`, regardless of Q26 — this one needs  
no link mark, only a pointer comparison.

**Answer:**

#### Q29 — the dedicated test file.

Proposed `tests/layer1_itemlist.zig`, registered in `matryoshka_tests.zig`.  
Scenarios 100-103 move there from `tests/layer1_polynode.zig`, which is about  
`PolyNode`, not `ItemList`.

Three groups:

| group | pins |
|---|---|
| contract | `popFirst` resets on sole member and on last member; every method on an empty list; `insertAfter` at tail vs middle; `len` against actual count after each mutation; `concat` for empty+empty / empty+full / full+empty with order preserved; `iterate` over 0/1/N and popping afterwards; both moves for empty and single-element sources |
| misuse | one test per row of the table above, asserting a panic. These only pass once Q26 is answered A or B |
| interop | `moveFromList` → `popFirst` → `moveToList` round-trip; taking an item out through `._list` leaves stale links — documented behaviour, pinned so it does not drift |

Recommendation: yes, and move 100-103 rather than duplicating them.

**Answer:** yes — `tests/layer1_itemlist.zig`

#### Q30 — does this reopen the closed stages?

If Q26 is A, `src/polynode.zig` changes shape and `src/mailbox.zig` /  
`src/pool.zig` maintain a new field. That is code, not docs.

- A. New stage API 9, its own 9a-9d. API 8 stays closed and DONE.
- B. Reopen API 8 as 8e.

Recommendation: A. API 8 shipped and its gate holds. This is a different  
problem — it was found through `ItemList` but it is not about the  
`std.DoublyLinkedList` boundary.

**Answer:** A. API 9

#### Q31 — does `ItemList` get a slot-taking append?

The user-facing half of the problem. See "Whose problem is it" above.

```zig
pub fn appendFromSlot(self: *ItemList, slot: *Slot) void
pub fn prependFromSlot(self: *ItemList, slot: *Slot) void
```

Takes the item out of the slot, links it, leaves the slot empty. Cannot fail —  
same as `append` today, plus the clear.

**No field. No build-mode condition. Independent of Q26.**

This is the part most likely to be misread, so it is stated plainly. Q31 and Q26  
solve different halves:

| | mechanism | when it acts | needs the link mark |
|---|---|---|---|
| Q31 `appendFromSlot` | the operation empties the slot | prevents | no |
| Q26 link mark | an assert catches a linked item later | detects | yes |

`appendFromSlot` is pure API shape. No new state on `PolyNode`, no  
`runtime_safety` branch, no size change, identical behaviour in ReleaseFast and  
ReleaseSmall. After it returns, the dangling slot cannot exist, so there is  
nothing left to detect.

Consequence: **Q31 can ship on its own.** It closes the user-facing hazard  
without waiting on the `PolyNode` layout decision. With Q26 recommended D, this  
is no longer the lesser half of API 9 — it is the implementable half.

The precedent it copies is already in the tree — `mailbox.send`,  
`src/mailbox.zig:72`:

```zig
std.debug.assert(slot.* != null);
std.debug.assert(!polynode.is_linked(slot.*.?));
// ...
const handle: polynode.ItemHandle = slot.*.?;
mbx.*.list.append(handle);
slot.* = null;
```

`appendFromSlot` is that, minus the mailbox:

```zig
pub fn appendFromSlot(self: *ItemList, slot: *Slot) void {
    std.debug.assert(slot.* != null);
    std.debug.assert(!is_linked(slot.*.?));
    self.append(slot.*.?);
    slot.* = null;
}
```

Two notes on that sketch.

- The `is_linked` assert in it is the unsound one — the same check `send` and
  `put` already carry. Q31 does not depend on it; `slot.* = null` is what does  
  the work. The line is inherited habit, not mechanism. If Q26 lands the field  
  later, this assert starts working for free, exactly like the six existing  
  sites. Q26 is recommended D in this version, so it will not — which changes  
  nothing about Q31.
- `send` asserts non-null, `put` returns silently on null. Both conventions
  already exist. `appendFromSlot` should follow `send`: a null slot passed to an  
  append is a programming error, not a no-op. `put` is tolerant because it is the  
  standard `defer` target, where an already-cleared slot is the normal case.  
  An append is not a `defer` target.

- A. Both, and the four call sites migrate. `append`/`prepend` stay for the
  stack-item case (`EventPolyHelper.toNode(&ev)`), which has no slot.
- B. `appendFromSlot` only. `prepend` from a slot has no caller today.
- C. Neither. The hand-written `slot = null` stays.

Naming follows the API 6 rule: a `move`-or-`from`-prefixed operation that  
empties its source. `moveFromSlot` was the precedent — it extracts and empties,  
where `fromSlot` inspects and does not.

Recommendation: A. B saves one method and leaves the pair asymmetric, which is  
the kind of gap that gets noticed later and reopened. C keeps a hazard the  
toolkit closes everywhere else.

Worth stating: this is the item on the API 9 list with a real user-visible  
payoff. Q26-Q28 harden `src/` against mistakes only `src/` can make.

**Answer:**

#### Q32 — what is API 9, and in what order does it ship?

Q30 answered "A. API 9" — a new stage. It did not say what that stage *is*.  
Two readings, and they produce different stages.

- A. **API 9 = "Intrusive safety".** The subject is `PolyNode` and every
  intrusive container over it, present and future. `ItemList` is one caller.  
  Contents, as of 003: `appendFromSlot` (Q31), the `concat` identity assert  
  (Q28), `is_linked`'s disposition (Q27, Q33), and the dedicated test file  
  (Q29). The link mark is no longer in it — Q26 is recommended D.

  Note the stage is *smaller* than 002 described, not empty. Q26 was the  
  largest item in it, and the argument in "Why no state on `PolyNode`" removed  
  that item without removing the stage's reason to exist.
- B. **API 9 = "ItemList round 2".** The subject is the type added by API 8, and
  the stage is its follow-up.

Recommendation: A. B is how the work arrived, not what it is. Q26's own  
reasoning is that the payoff is four *existing* asserts in `mailbox.zig`,  
`pool.zig`, and `PolyHelper` — none of them `ItemList`. A stage named after  
`ItemList` would make those look incidental, and would make the next intrusive  
container look like new work rather than a beneficiary.

Ship order inside the stage, if A:

1. `appendFromSlot` / `prependFromSlot` (Q31). Prevention. No layout change, no
   dependency, and the only item with a user-visible payoff.
2. The dedicated test file (Q29), pinning current behaviour before it changes.
3. The link mark and `is_linked` (Q26, Q27). Detection.
4. The extra asserts (Q28), which only work once 3 lands.
5. Docs.

The order is deliberate: prevention before detection. A bug that cannot happen  
needs no assert, and step 1 removes the hazard for the four real call sites  
whether or not steps 3-4 are ever approved. If the `PolyNode` layout question  
stalls, the user-facing half has already shipped.

**Answer:**

#### Q33 — what becomes of the six asserts on `is_linked`?

New in 003. Forced by Q26 = D: if nothing can repair `is_linked`, the six  
production asserts that call it are promising a guarantee they do not deliver.

The count first, because 002 said four and 002 was wrong. Grepped from `src/`:

| site | API | what it means to reject |
|---|---|---|
| `src/mailbox.zig:74` | `mailbox.send` | an item already queued elsewhere |
| `src/mailbox.zig:102` | `mailbox.send_oob` | same, OOB path |
| `src/pool.zig:240` | `pool.put` | double-put of a still-linked item |
| `src/pool.zig:287` | `_add_returned_item` | internal, last guard before `prepend` |
| `src/polynode.zig:275`, `:392` | `PolyHelper.moveFromSlot` | extracting from under a live list. Two sites — the helper is generated twice |
| `src/polynode.zig:315` | `PolyHelper.destroy` | **freeing memory a list still points at** |

`send_oob` and `pool.put` were never counted in 002. All seven lines are  
`std.debug.assert`, so Debug and ReleaseSafe only.

Every one of them is false-negative for a list of one, and `destroy`'s is the  
one that turns into a use-after-free.

- A. **Keep all six, document the hole.** They catch the multi-element case,
  which is most real double-sends. A partial guard is better than none.
- B. **Keep them, and add what actually works.** Nothing in-item, but the
  *container* knows its own contents: `pool.put` can assert the item is not in  
  the pool's own free-list, `mailbox.send` that it is not in that mailbox's own  
  list. O(n) under safety builds, and it closes the sole-member case for  
  same-container misuse, which is the common mistake. Cross-container misuse  
  stays undetectable.
- C. **Remove them.** A check that is wrong in the single-item case and
  undefined in the concurrent case is worse than nothing, because three tests  
  currently read as though it works.

Recommendation: A now, B as Q34, never C.

**Corrected in 004.** 003 cited the three `polynode.zig` sites by their function  
declaration lines — `:271`, `:311`, `:388` — not the assert lines. The table  
above now cites the asserts, matching "Coverage — case by case". The count is  
unchanged: six APIs, seven lines.

**Also corrected in 004.** 003 said "B as a separate question later". That  
question is now written: **Q34**. Q33 and Q34 are no longer the same discussion,  
and the division between them is worth stating, because it is not obvious:

- **Q34** is about the four `ItemList` insert methods. The list is in hand — it
  is `self` — so the walk is a private method away.
- **Q33 option B** is about `mailbox.send`, `pool.put`, `PolyHelper.destroy` and
  `moveFromSlot`. Only the first two hold a list at all; `destroy` and  
  `moveFromSlot` are handed a `Slot` and have no list to interrogate, so B  
  cannot reach the site that matters most — the use-after-free.

That asymmetry is the reason to answer them separately. Q34 closes cases  
outright. Q33 = B closes the same-container case for two of six APIs and leaves  
`destroy` exactly as broken as it is today.

A is not satisfying, and it is honest. The asserts do catch something, and the  
cost of A is one doc-comment fix plus a rules entry saying what the check is  
worth.

B is the only mechanism this whole round has turned up that survives the  
concurrency argument — a container asking about its *own* contents, under its  
*own* lock, needs no exclusivity it does not already hold. It also costs O(n) on  
`send` and `put` under safety builds, which is a real decision and not one to  
smuggle in under Q33.

C would delete a partial guard on a use-after-free and gain nothing. The three  
tests that encode the broken semantics — `layer1_polynode.zig:71`,  
`layer2_mailbox.zig:598`, `layer3_pool.zig:808` — need their comments corrected  
under any answer here. Scenario 88's comment already documents the hole  
(*"single-node list has prev==next==null"*); it was written around the defect  
rather than reporting it.

**Answer:**

#### Q34 — how far does the walk go?

New in 004, from the owner: *insert an item already in this list — may be fixed  
walking before insert.*

Correct. The full explanation is in "The walk" under "Coverage — case by case".  
In short:

```zig
// compiled only under std.debug.runtime_safety
fn _holds(self: *const ItemList, ih: ItemHandle) bool {
    var it = self._list.first;
    while (it) |n| : (it = n.next) if (n == &ih.node) return true;
    return false;
}
```

It closes coverage case 2 completely, including the sole-member hole no other  
surviving proposal reaches. Applied to `insertAfter`'s `existing` it also closes  
case 4, which only the rejected pointer field ever covered.

The question is scope, because the cost is not where the complexity notation  
puts it.

- A. **Not at all.** The coverage table stands as written. `append` stays a pure
  forward.
- B. **`append` and `prepend` only.** `assert(!_holds(ih))`. Closes case 2. This
  is Q26 option C done properly.
- C. **All four inserts, both directions.** B, plus `insertAfter` asserting
  `!_holds(ih)` and `_holds(existing)`. Closes cases 2 and 4.
- D. **C behind a length cap.** Walk only while the list is short — say 64 — and
  skip the check above it. Bounds the worst case at the price of a guarantee that  
  holds only for small lists.

**Recommendation: C.** It closes a case nothing else surviving can close, and  
`append`, `prepend` and `insertAfter` promise no complexity in their doc comments  
(`src/polynode.zig:97`, `:102`, `:107`) — unlike `moveFromList` and `moveToList`,  
whose O(1) this document does promise, and whose promise is what defeated the  
pointer field in "Why a bool and not a pointer".

The argument against C, stated as strongly as it deserves, because it is not an  
asymptotic argument:

Every internal insert happens **while a mutex is held** —  
`src/mailbox.zig:87` (`send`), `:117` and `:119` (`send_oob`),  
`src/pool.zig:291` (`_add_returned_item`), `:322` (`close`). Under Debug, C makes  
every send walk the entire queue with the mailbox locked, and every pool return  
walk the free list. A deep queue turns an O(1) operation under a lock into an  
O(n) one under the same lock. That does not corrupt anything and does not affect  
shipping builds, but it changes the timing of the builds the tests run in, and  
timing is exactly what concurrency tests probe.

D exists for that reason and is the fallback: if Debug throughput on mailbox or  
pool measurably suffers, cap the walk. Recording D as the fallback rather than  
the recommendation is deliberate — a cap makes the assert's guarantee  
conditional on list length, which is a worse thing to document than an honest  
O(n).

**What C does not fix.** Six of the eight cases. Case 1 in particular: an item  
in *another* list is not reachable from `self`, so `!is_linked(ih)` keeps both  
its ≥2 coverage and its sole-member blind spot. The walk narrows the hole; it  
does not close it.

**Answer:**

---

## What API 8 is

The toolkit already documents the outcome. `src/polynode.zig:14`:

> You don't need to deal with @fieldParentPtr.

API 8 does not add an abstraction. It makes that sentence true.

---

## Reasoning — the agreed decisions

One section per answered decision.

Every question is answered except Q25, which is postponed by choice — the  
protection list is decided before the migration stage runs, not now.

### `*Node` is not `*PolyNode`

**Decision.** `@fieldParentPtr` is the only defined conversion from a list node  
to the item holding it. The toolkit performs it, or the application does.

**Why there was no third option.** The langref quote above is the whole argument.  
Field order is compiler-determined, so `node` being written first in `PolyNode`  
says nothing about its offset. `@ptrCast` between the two pointer types is  
unsound even though it compiles and, in practice today, works.

That is what made Q1 a fork with two branches and not three. There is no clever  
representation that makes the conversion disappear. There is only a choice about  
who writes it.

**The failure this prevents.** A `@ptrCast` that passes every test on the current  
compiler and breaks silently when a field is added to `PolyNode`, or when the  
optimizer reorders. No test can catch it, because the layout it depends on was  
never promised.

**What it does not promise.** `ItemList` does not make the conversion cheaper.  
It is the same builtin, in the same shape. It makes it happen once, in a named  
place, instead of thirty times in application code.

### The field is named `_list`

**Decision.** Q5 B. The field is `_list`, not `list`. Tests may use it.  
Application code does not.

Zig has no per-field visibility. Every field of a public struct is reachable.  
So the name is the only signal available, and `src/` already uses a leading  
underscore for exactly this — `_Mailbox`, `_Pool`, `_concat`, `_add_returned_item`  
are all "not yours". `ItemList._list` joins them.

**Why the recommendation was refused.** I argued for `list` on the grounds that  
`tests/layer1_polynode.zig` scenarios 6, 7, 8 use the field, so a private-looking  
name would be a lie. The answer draws the line differently: a test and an  
application are not the same reader. A test may reach into a type it is testing.  
That is what tests are for. The name speaks to the application, and to the  
application the answer is no.

**The failure this prevents.** `il.list.append(...)` written in an example, then  
copied into user code, then into the docs, until the escape hatch is the normal  
path and `ItemList` guarantees nothing. A leading underscore does not stop that.  
It makes it visible in review.

**What it does not promise.** Nothing is enforced. `_list` is reachable and  
mutable from anywhere. It is a convention, backed by a doc comment — which is  
what Q6 covers.

### One view at a time

**Decision.** Q6 A. The rule is stated on the field's doc comment. It is not  
enforced.

**The failure this prevents.** `popFirst` promises the handle it returns is  
unlinked, because it calls `reset`. Reaching through `_list` gets the same items  
without that call, and a stale `next` pointer read after removal is the  
`_add_returned_item` panic all over again.

**Alternative rejected.** Q6 B — say nothing, on the grounds that a raw std field  
is self-evidently raw. Rejected because the same reasoning failed once already.  
"You must call `reset` after every pop" was written into the rules document, and  
34 pop sites produced 13 `reset` calls. Self-evident is not a mechanism.

**The doc comment, as shipped.** The answer asked for human text. The first  
draft was prose — three sentences, no jargon, and still wrong for the file it  
sits in: `src/` comments are staccato and bulleted, and the draft leaned on  
"the promises ItemList makes are off" instead of naming what breaks. Rewritten  
on the owner's instruction:

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

It says what to use instead, what breaks, and what to call. "One view at a time"  
is the name for the rule in this document — it does not appear in the comment,  
because a caller reading a field needs to know what to call, not what to call it.

The wording moved once more when rules-030 banned "underneath" and "on purpose".  
The block above is the shipped text; `src/polynode.zig` is the authority.

**What it does not promise.** The comment is advice. Nothing checks it.

### `popFirst` calls `reset`

**Decision.** Q7 A. A handle returned by `ItemList.popFirst` is never linked.

**The failure this prevents.** `std.DoublyLinkedList` leaves `prev` and `next`  
stale on removal. A later read of `next` on a popped item follows a pointer into  
a list the item is no longer part of.

This is not hypothetical. `_add_returned_item` panicked on composite lists of  
three or more items — the API 5 follow-up. The fix was a `reset` call. The rule  
"call `reset` after every pop" was then written into the rules document.

Counted today: 34 pop sites in user code, 13 `reset` calls. The written rule is  
obeyed 38% of the time. A rule with that hit rate is a trap, not a guard.

**Alternative rejected.** Q7 B — a thin forward, `reset` left to the caller.  
Rejected because it produces a type that renames the problem. Every argument for  
`ItemList` is an argument for this one line inside it.

**What it does not promise.** `reset` clears links. It does not clear the item's  
payload, and it does not say the item is free to reuse. That is the pool's  
business, not the list's.

### Move, never copy

**Decision.** Q16. `moveFromList` and `moveToList` only. No `fromList`, no  
`toList`.

**Why.** A `std.DoublyLinkedList` header is `{first, last}`. Copying it produces  
a second header pointing at the same nodes. That is not a borrow — it is an  
alias. The first `popFirst` on either header advances only that header's `first`,  
and the two disagree from then on. The second `popFirst` on the other header  
returns an item that is already gone.

There is no `*const` form that avoids this, because there is no way to inspect a  
list header without holding something that can walk it.

**The precedent.** This is the API 6 accessor rule, applied to a container.  
`fromSlot` inspects, takes `*const`, and leaves the Slot full. `moveFromSlot`  
extracts and empties. A Slot can be inspected safely because it holds one  
pointer. A list header cannot, so it only ever gets the `move` form.

**Cost.** O(1). A two-word value copy. No walk, and no `reset` — the nodes stay  
correctly linked to each other, only the header changes hands.

**What it does not promise.** Neither move can fail. No optional, no `must`  
variant. An empty source moves an empty list.

### `moveFromList` returns fresh

**Decision.** Q17 A. `moveFromList(list: *std.DoublyLinkedList) ItemList`.

**Alternative rejected.** `moveInFrom(self: *ItemList, list: *...) void`, filling  
an existing list. It needs a "destination is empty" precondition — the same shape  
as the Slot Rule — or it silently becomes a merge. Neither is wanted: no measured  
caller merges two lists from outside the toolkit.

**What it does not promise.** It is not a merge. If merge-into is ever needed,  
`concat` is the operation, and Q12 covers whether that lands on `ItemList`.

### The omitted surface

**Decision.** Q13 and Q14. `pop`, `remove`, and every tag-aware operation are  
left out.

| omitted | reason |
|---|---|
| `pop` | Zero callers in the repo. `popFirst` is 31 |
| `remove` | Zero callers. Removal always happens through a pop today |
| `popFirstOf(TAG)`, `splitByTag`, `countOf(TAG)` | Zero callers |

The tag-aware group is the interesting one, because it is the only place  
`ItemList` could offer reach that `std` structurally cannot — `std` does not know  
what a `PolyTag` is.

Rejected anyway. The two candidate callers do not want it. `items.freeList`  
dispatches to a *destructor*, which is application knowledge and not a tag test.  
Per-item dispatch is already `Helper.fromNode(ih)` on each popped handle, which  
returns null on a tag mismatch — the filter is already there, one item at a time.

**Rule for adding them back.** First real call site. Not before.

### `concat` replaces `_concat`

**Decision.** Q12 A. `ItemList.concat`, and `_concat` at `src/pool.zig:415` is  
deleted.

**Why it is not a reuse argument.** Q20 already turned `_Pool.lists` into a map  
of `ItemList`. `_concat` takes `(*std.DoublyLinkedList, *std.DoublyLinkedList)`,  
and its one caller — `src/pool.zig:355`, inside `pool.close` — will be holding  
`ItemList` on both sides. So `_concat` cannot survive Q20 with its current  
signature no matter what is decided here.

The real choice was between a method on the type and a private  
`_concat(dst: *ItemList, src: *ItemList)` that reaches through `._list` twice to  
get at the std operation. The second form is the same code with two escape-hatch  
reaches added, in a file that just named that field to discourage them.

**Stated plainly.** This is the one method on the surface with a single caller  
and no application-side demand. It is there because Q20 put it there. The  
evidence table records `concatByMoving` at 0 sites, and that stays true — the  
caller is `src/`, not user code.

**Implementation note for 8b.** `std.DoublyLinkedList.concatByMoving` is the same  
operation. `ItemList.concat` forwards to it. The hand-written link surgery at  
`pool.zig:415` — ten lines of `prev`/`next` assignment — is deleted rather than  
moved, which is the kind of code this stage exists to remove.

**What it does not promise.** `concat` empties `other`. It does not `reset`  
anything, and it does not need to: the items stay correctly linked to each other  
throughout, only the two headers change.

### `len` does not replace the counters

**Decision.** Q9 A and Q10. `len` forwards `std`'s walk. `_Mailbox.len` and  
`_Pool.counts` stay exactly as they are.

Those counters exist because the walk is O(n) and the toolkit holds a lock while  
it would run. They are not a duplicate of `len`. They are the reason `len` is  
never called inside `src/`.

Per Q9, the doc comment does not carry the cost note. The two existing callers  
are tests counting a short list, and the note would read as a warning against  
the only use the method has.

**What it does not promise.** `len` is a walk. It is not O(1), and nothing in  
`src/` calls it.

### `_Mailbox` and `_Pool` adopt `ItemList`

**Decision.** Q20 and Q21. Internal fields and both hook signatures move.

- `_Mailbox.list` → `ItemList`
- `_Mailbox.oob_last` → `?ItemHandle`, was `?*std.DoublyLinkedList.Node`
- `_Pool.lists` → map of `ItemList`
- `PoolHooks.on_put`, `PoolHooks.on_close` → `ItemList`

**Why this is where the builtin disappears.** Seven of the eight  
`@fieldParentPtr` sites in `src/` are the same pop-cast-reset triple, listed in  
the evidence section above. They are not seven decisions. They are one line  
written seven times.

**Why the hooks move too.** A hook author is not toolkit infrastructure. They  
write application code that happens to be called back. Leaving `on_close` on the  
std type means the one caller most likely to walk a list item by item is the one  
caller still writing the builtin by hand.

**End state.** `@fieldParentPtr` survives in exactly two places, both in  
`src/polynode.zig`: `ItemList.popFirst` and `PolyHelper.fromNode`  
(`src/polynode.zig:120`, `:237`). Everything else in the repo stops naming it,  
except the raw-link tests that exist to test the layout.

---

## Next round

- Q26, Q27, Q28, Q31, Q32, Q33, Q34 answered. Nothing here gates anything else
  now that Q26 is recommended D — each can be answered in any order. Q34 is the  
  one with a measurement attached: if C is chosen, Debug throughput on mailbox  
  and pool should be looked at before it is called done, since that is the  
  argument for falling back to D.
- A reasoning section per newly answered decision, same shape as the ones above.
- The synchronization invariant from "Why no state on `PolyNode`" written into
  `rules-0NN.md` and `matryoshka-model-0NN.md`. This is owed regardless of how  
  Q26 is answered: six existing asserts already depend on it, and only half of  
  it is written down today.
- `src/polynode.zig:67` — the `is_linked` doc comment says "True if the node is
  linked into a list", which is false for a list of one. Fixed under Q27 A.
- Q25's protection list, still postponed from 001. The 8c migration ran with the
  three proposed protections applied as written.

API 8a-8d are complete and shipped. Nothing added in this version is  
implemented — no code changes until the open questions are answered and the  
stage is separately approved.

---

## Coverage — case by case

Concentrated for deciding Q26, Q28, Q31, Q33, Q34. New in 003, revised in 004.

Two columns, and the difference between them is the whole of Q34:

- **today** — what the shipped code catches, with Q26 = D. Nothing added to
  `PolyNode`.
- **+ walk** — what it catches if Q34 is adopted at option C.

Rows 2 and 4 changed between 003 and 004. 003 had case 2 as *partial* and case 4  
as *no*, on the reasoning that answering "is this item already linked?" requires  
a fact about the item. That reasoning was wrong for these two rows: a list can  
answer both questions about *itself* without asking the item anything. The old  
values are kept in the table so the correction is visible.

### The cases

| # | misuse | paired APIs | what breaks | today | + walk |
|---|---|---|---|---|---|
| 1 | insert an item that is in another list | `ItemList.append` / `prepend` after any earlier insert | both lists' links cross; either list's walk leaves the list | **partial** — caught only if the old list held ≥2 | partial, unchanged |
| 2 | insert an item already in *this* list | `append` twice on the same handle | `_list.len` counts a cycle; `iterate` never ends | **partial** — same condition (003 said this and stopped here) | **fixed** |
| 3 | insert from a Slot and keep the Slot | `append(mustFromSlot(&slot))` then `destroy(&slot)` | free while linked; case 5 with a delay | **no** — nothing reads the Slot | no — Q31 closes it instead |
| 4 | `insertAfter` with a foreign `existing` | `insertAfter` | items splice into the wrong list silently | **no** — 003 said "needs which-list, not whether", which was the error | **fixed** — `_holds(existing)` |
| 5 | free a linked item | `PolyHelper.destroy` / `pool.put` / `mailbox.send` | the holding list keeps a pointer to freed memory | **partial** — condition below | partial — no list in hand at those sites |
| 6 | take out through the escape hatch | `_list.popFirst` without `polynode.reset` | stale `prev`/`next`; the next reader walks a list the item left | **no** — by construction | no |
| 7 | mutate during a walk | `iterate` + `append` / `popFirst` | the iterator's `_next` may already be freed or relinked | **no** — no version counter | no |
| 8 | copy an `ItemList` header | `const b = a;` | two headers alias one chain; the first `popFirst` corrupts the other | **no** — a copy is a language operation | no |

Cases 1 and 5 share one condition, and with Q34 adopted it is the whole of what  
is left:

> `is_linked` is `prev != null or next != null`. `std` leaves both null for a  
> list's sole member. So every check is exact for a list of ≥2 and blind for a  
> list of exactly 1.

Case 2 shared that condition until 004 and no longer does — the walk does not  
consult `is_linked` at all.

Which answer moves which case:

- **Q26 = A** (withdrawn) would have moved 1, 2 and 5.
- **Q34 = C** moves 2 and 4. Case 4 is the one worth noting: the *only* other
  proposal that ever covered it was the pointer field, rejected for making three  
  move operations O(n). The walk covers it for O(n) on one insert.
- **Q31** moves 3, by prevention rather than detection.
- Nothing on the table moves 6, 7 or 8. Those are the documented sharp edges.

Case 5 is the one that stays unfixed and matters most, because  
`PolyHelper.destroy` is where it becomes a use-after-free. Neither the walk nor  
Q33 = B reaches it: `destroy` is handed a `Slot` and holds no list to ask.

### The asserts that exist

Seven `!is_linked` lines across six APIs. All share the blind spot above.

| site | API | fires when |
|---|---|---|
| `src/mailbox.zig:74` | `mailbox.send` | sending an item still in a list of ≥2 |
| `src/mailbox.zig:102` | `mailbox.send_oob` | same |
| `src/pool.zig:240` | `pool.put` | returning an item still in a list of ≥2 |
| `src/pool.zig:287` | `_add_returned_item` | internal; same |
| `src/polynode.zig:275` | `PolyHelper.moveFromSlot` | generated variant with create/destroy |
| `src/polynode.zig:392` | `PolyHelper.moveFromSlot` | `no_create_destroy` variant |
| `src/polynode.zig:315` | `PolyHelper.destroy` | freeing an item in a list of ≥2 |

Four further asserts guard the destination instead, and are exact —  
they read a `Slot`, not an item:

| site | API | assert |
|---|---|---|
| `src/polynode.zig:297` | `PolyHelper.create` | `slot.* == null` |
| `src/mailbox.zig:148` | `mailbox.receive` | `slot.* == null` |
| `src/mailbox.zig:205` | `mailbox.receive_oob` | `slot.* == null` |
| `src/pool.zig:157`, `:181` | `pool.get*` | `slot.* == null` |

The split is the useful part. **Destination asserts are exact and need no shared  
state. Source asserts need to know a fact about an item, and that is the class  
Q26 could not repair.** Q28 and Q31 both live on the exact side; Q33 is about  
what to do with the inexact side.

004 adds a third kind, which is why the split needed restating rather than just  
extending: a **containment** assert asks neither the destination nor the item,  
but the container. It is exact — a walk cannot be wrong about what a list holds —  
and it needs no shared state, because the list is the caller's own. That is  
Q34, and it is available only where a list is in hand, which excludes all seven  
inexact sites above.

### The walk

New in 004. The mechanism behind the `+ walk` column, and the subject of Q34.

```zig
// compiled only under std.debug.runtime_safety
fn _holds(self: *const ItemList, ih: ItemHandle) bool {
    var it = self._list.first;
    while (it) |n| : (it = n.next) if (n == &ih.node) return true;
    return false;
}
```

`std.DoublyLinkedList` has no `contains`, so this is ours to write. It is  
private, and it is the only new code Q34 needs.

**Why it survives the argument that killed the field.** Stated in the same terms  
"Why no state on `PolyNode`" uses, because the resemblance is close enough to be  
misleading:

| | the withdrawn field | the walk |
|---|---|---|
| writes | `_linked`, on every insert and reset | nothing |
| reads | the item's own memory | `self._list`, plus one address |
| needs | exclusive access to an item another thread may hold | exclusive access to a list this caller already holds |
| in the buggy case | the field itself races — undefined | still reads only `self` — defined |

The third row is the one that decides it. `&ih.node` computes an address; it does  
not dereference the item. So even in the misuse the check exists to catch — the  
item concurrently held by another Master — the walk never touches the memory that  
other thread owns. It asks the container a question about the container, which is  
the pattern Q33 already identified as surviving, applied where the container is  
`self`.

**What it costs.** O(n) per insert under safety builds, zero outside them. The  
complexity is the easy half; the placement is the hard half. Every internal  
insert holds a mutex:

| site | API |
|---|---|
| `src/mailbox.zig:87` | `mailbox.send` |
| `src/mailbox.zig:117`, `:119` | `mailbox.send_oob` |
| `src/pool.zig:291` | `pool.put` via `_add_returned_item` |
| `src/pool.zig:322` | `pool.close` |

Under Debug, C makes every send walk the whole queue with the mailbox locked.  
Shipping builds pay nothing, but the tests run in Debug and ReleaseSafe, and  
concurrency tests are the ones whose timing this changes. Q34 option D caps the  
walk for that reason.

**Why this is not the O(n) that lost the earlier argument.** "Why a bool and not  
a pointer" rejected a proposal for costing O(n) under safety builds, and the  
distinction has to be stated or the two look identical:

- the pointer made `concat`, `moveFromList` and `moveToList` O(n) — three
  operations whose O(1) *this document promises*, in "Moving between the two  
  vocabularies", and whose O(1) is the reason they exist.
- `append`, `prepend` and `insertAfter` promise nothing about complexity
  (`src/polynode.zig:97`, `:102`, `:107`).

That is a real difference, and it is also not a licence. Breaking no written  
promise is the reason C is arguable; the locked-insert cost above is the reason  
it is still a question.

### What each open answer would move

| answer | moves |
|---|---|
| Q26 = A (withdrawn) | cases 1, 2, 5 → fixed; asserts become exact |
| Q26 = D | nothing on its own |
| Q34 = B | case 2 → fixed |
| Q34 = C | cases 2 and 4 → fixed |
| Q28 | adds destination-side asserts only — no case above |
| Q31 `appendFromSlot` | case 3 → fixed, by prevention: it empties the Slot, so no second holder exists |
| Q33 = B | no case above. Closes same-container misuse for `send` and `put` only, and cannot reach `destroy` |

Three of the eight cases are closable with what survives — 2 and 4 by the walk,  
3 by prevention. 003 said only case 3 was, and that is the substance of this  
version.

---

## Change log

| Version | Date | Change |
|---|---|---|
| 001 | 2026-07-29 | First version. API 8a, round 1. Tables for review, reasoning deferred. |
| 001 | 2026-07-29 | Editorial, round 1: evidence table moved above the questions, `ItemHandle` origin stated, closing "What API 8 is" section added. No decision changed. |
| 001 | 2026-07-29 | Round 2: Q5, Q6, Q25 rewritten with the failure each prevents made concrete — all three were unclear as first written. Reasoning sections added for the seven decisions answered in round 1. No agreed decision changed, so no version bump. |
| 001 | 2026-07-29 | Round 2 answers: Q5 is B — the field is `_list`, not `list`, and the design table follows. Q6 is A with the doc comment drafted in plain language. Q25 postponed to the migration stage. Reasoning sections added for both. Q5 was open, not agreed, so still no version bump. |
| 001 | 2026-07-29 | Q12 answered A: `ItemList.concat` forwards to `std`'s `concatByMoving`, `_concat` deleted. Reasoning section added. |
| 001 | 2026-07-29 | Q24 answered: the strong gate. Reasoning section added, with the measured cost — `@fieldParentPtr` is in five test files, not one, so the gate pulls eight test conversions into stage 8c. All questions answered except Q25, postponed. |
| 001 | 2026-07-29 | Implementation correction after 8b-8d shipped: the end-state `@fieldParentPtr` count is three, not two — `ItemList.Iterator.next` performs the same conversion, a consequence of Q11. Row and reasoning section updated. No decision changed. |
| 002 | 2026-07-29 | New version. The owner asked what `ItemList` inherits by forwarding to a container that validates nothing. Verified against the shipped `std`: four misuses pass silently, and `polynode.is_linked` is unsound for a sole list member — a defect older than API 8 that four existing asserts rest on, found and recorded once before at Stage 1.a and never acted on. New section "What forwarding inherits", new Group G (Q26-Q30). Everything from 001 unchanged and still agreed. |
| 002 | 2026-07-29 | Q29 answered: dedicated `tests/layer1_itemlist.zig`, scenarios 100-103 move there. Q30 answered A: new stage API 9, API 8 stays closed. |
| 002 | 2026-07-29 | Q31 expanded: it needs no field, no `runtime_safety` branch, and no `PolyNode` layout change, so it is independent of Q26 and can ship alone. Added the mechanism table (prevent vs. detect), the `mailbox.send` precedent it copies, the implementation sketch, and two notes — the inherited `is_linked` assert is habit rather than mechanism, and the null-slot convention follows `send` (assert) not `put` (tolerate). |
| 002 | 2026-07-29 | Owner asked whose problem API 9 solves. New section "Whose problem is it": `concat` and `insertAfter` have no application caller, so Q26-Q28 harden `src/` against mistakes only `src/` can make. The user-facing defect is that `ItemList.append` is the only transfer in the toolkit that does not follow the Slot Rule — all four call sites write `slot = null` by hand, and forgetting it produces a use-after-free that the broken `is_linked` cannot catch, in the most common case rather than an edge case. New Q31 proposes `appendFromSlot`/`prependFromSlot`. |
| 002 | 2026-07-29 | Q26 rewritten and its recommendation reversed. `@sizeOf` measured on the shipped compiler: a bool and a pointer both cost 32 bytes under `runtime_safety`, so the choice is time, not space — a pointer forces `concat`, `moveFromList`, and `moveToList` to re-stamp every item, breaking the O(1) promise this document already makes. Recommendation changed from the pointer to the bool. New section "The debug-only link mark" carries the full explanation: what it solves, why debug-only with the measured table, why a bool and not a pointer, and what it does not fix. Q27 and Q28 reworded to match the terminology. |
| 002 | 2026-07-30 | External review acted on. Four additions, no decision changed. (1) New "What `ItemList` is not" — intrusive forever, never allocates, never copies, gains no method because `std` has one. (2) New "Invariants" — the properties that hold independent of the method surface, including the three `concat` guarantees rather than only "empties `other`". (3) Q26 reframed: the defect is a `PolyNode` question, not an `ItemList` one, so the mark goes on `PolyNode` and every future intrusive container inherits a working `is_linked` for free. (4) New Q32 — is API 9 "intrusive safety" rather than "`ItemList` round 2", and does it ship prevention (Q31) before detection (Q26-Q28). Group G split into its three real subjects, and a decided/open summary added at the head of Questions. Review points declined: reformatting the reasoning sections into fixed subsections, and reordering "Why a bool and not a pointer" to lead with complexity — it already closes on complexity as the deciding argument. |
| 003 | 2026-07-30 | New version. **The link mark is withdrawn.** The owner's concurrency argument: `_linked` is written under whichever mutex the item's current list sits behind, and those mutexes do not synchronize with each other, so in the buggy case the field exists to catch, the field itself races — sound exactly when unnecessary, undefined exactly when it would fire. Atomics do not rescue it; they protect the flag, not the list topology, and two concurrent `append`s corrupt the list whatever the flag says. One step added on top of the owner's argument: it applies unchanged to `prev`/`next`, which `is_linked` already reads under the same absent synchronization, so the bool inherits a race rather than adding one — which generalizes the conclusion to *no state stored in an item can validate this class of mistake*, retiring B, C, and any later generation-counter variant with A. New section "Why no state on `PolyNode`" carries all of it, plus the invariant the argument forces into the open: legal transfers establish happens-before not through the mutexes but through the item's address, which travels only via a synchronized primitive. `rules-029.md:405` has half of that and `matryoshka-model-003.md:30` has the access half; the happens-before consequence is written down nowhere, and six existing asserts already rest on it. Q26's recommendation reversed A → D, with the reversal shown rather than edited away. "The debug-only link mark" kept, marked withdrawn, as the record of what was rejected. Q27 rewritten — with no mark, `is_linked` cannot be made exact, so the question is what it should say, not how to repair it. New Q33: what becomes of the asserts, with the corrected count — **six APIs, seven assert lines**, not the four 002 claimed; `mailbox.send_oob` and `pool.put` were never counted. Q33 also records the one mechanism this round turned up that survives the argument: a container asking about its *own* contents under its *own* lock. Q28 and Q31 survive D untouched, and Q31 is now the implementable half of API 9. |
| 003 | 2026-07-30 | New section "Coverage — case by case", requested by the owner as concentrated input for the open answers. Three tables: the eight misuse cases with the APIs each one pairs, the failure it produces, and whether D fixes it; the eleven asserts that exist today, split into the seven inexact `!is_linked` source checks and the four exact destination checks; and what each open answer moves. Two facts fall out of the split that the prose above stated only in passing — every source assert shares one blind spot (`std` leaves both links null for a list's sole member, so the checks are exact for ≥2 and blind for exactly 1), and only cases 1, 2 and 5 change answer between Q26 = A and Q26 = D. Cases 3, 4, 6, 7, 8 were never covered by the mark. No decision changed. |
| 004 | 2026-07-30 | New version. **Part of what 003's withdrawal gave up is recovered.** The owner observed that "insert an item already in this list" can be caught by walking the list before the insert. It survives the concurrency argument that killed the link mark, and the reason is exact rather than approximate: the walk writes nothing and reads only `self._list` plus the *address* `&ih.node`, which is computed and not dereferenced — so even in the misuse it exists to catch, an item concurrently held by another Master, the check never touches memory that thread owns. New subsection "The walk" carries the side-by-side against the withdrawn field. Two rows of the coverage table are corrected with the old values kept visible: case 2 (insert into *this* list) from partial to fixed, and case 4 (`insertAfter` with a foreign `existing`) from no to fixed. Case 4 matters most — the only other proposal that ever covered it was the pointer field, rejected in 002 for making three move operations O(n); the walk covers it for O(n) on one insert. That forces a restatement of 003's conclusion, which was too strong: not "detection is not implementable" but "detection requiring a fact about an *item* is not implementable; detection answerable from a *container's* own contents is". "What survives" gains the walk as its first surviving detection mechanism, and the assert split gains a third kind — containment asserts, which ask neither destination nor item. New Q34 on scope: none / `append`+`prepend` / all four inserts including `_holds(existing)` / capped by length. Recommended C, with D the fallback, and the argument against C stated as the placement rather than the complexity — every internal insert holds a mutex (`mailbox.zig:87`, `:117`, `:119`, `pool.zig:291`, `:322`), so under Debug C walks the whole queue with the mailbox locked. Q26 option C is marked superseded: it is the walk truncated to the list head, so it is a weaker form of Q34 = B rather than an interim. Q26's answer stays D — the walk is not in-item state and so is not one of A/B/C. Q33's promise of "B as a separate question later" is discharged as Q34, with the asymmetry between them written down: Q34 always has a list in hand, while `PolyHelper.destroy` and `moveFromSlot` are handed a `Slot` and hold no list, so Q33 = B cannot reach the site where case 5 becomes a use-after-free. Also corrected: 003's Q33 table cited the three `polynode.zig` sites by function-declaration line (`:271`, `:311`, `:388`) rather than assert line; now `:275`, `:315`, `:392`, matching the coverage section. Count unchanged — six APIs, seven lines. No code changes; nothing here is implemented. |
