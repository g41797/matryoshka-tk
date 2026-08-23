# The Matryoshka portable specification (001)

Stage 3TK-2 of [3tk-staging-plan-001.md](../../c3/backup/3tk-staging-plan-001.md).

This document says what Matryoshka is, without naming a language.

It is self-contained. A port is written from this file alone.

Zig appears only as one realization, in the lines marked *ztk*.

## How to read this

- Every element carries a conformance marking. Part 0 defines the four.
- Every part states the rule first. Evidence and background come after.
- The external references are `ztk-audit-001.md`, and behind it
  `src/polynode.zig`, `src/mailbox.zig`, `src/pool.zig`. Nothing else.
- Terminology: **inner** is the embedded structure. **outer** is the struct
  that embeds it. Never "parent".

## Sources

- [ztk-audit-001.md](../ztk-audit-001.md) — the read-only record of the Zig
  realization. Section numbers of the audit are cited as `audit 2.1`.
- Porting is not transpiling. This file says what a port preserves. How a port
  spells it is the port's business.

---

# Part 0 — Conformance markings

Four markings. Every element in Parts 1 to 20 carries one.

- **MUST** — remove it and the result is not Matryoshka. The semantics are
  fixed. The spelling is free.
- **SHOULD** — the shape is fixed. The spelling is the port's business. A port
  that skips it states why.
- **MAY** — convenience. A port skips it and loses nothing structural.
- **EXCLUDED** — present in ztk only because of Zig or of `std.Io`. A port
  starts by deleting it. Part 16 names every one.

A marking applies to the element, not to the sentence.

Where a marking is conditional, the condition is written next to it.

---

# Part 1 — What Matryoshka is, and what it is not

## 1.1 What it is — MUST

Matryoshka is a toolkit for passing items between long-lived threads.

- An item is application data with a small structure embedded in it.
- The embedded structure carries the list links and the type identity.
- Items travel between threads through two infrastructure objects.
- No allocation happens on a transfer.
- One holder at a time. The transfer is a move, never a copy.

The name is the shape: the inner sits inside the outer, and the outer is what
the application wrote.

## 1.2 What it is not — MUST

Matryoshka refuses these, and a port that adds them has changed the design.

- Not a scheduler. It starts no thread and owns no thread.
- Not an async runtime. There is no task, no future, no event loop.
- Not a serializer. An item never leaves the process.
- Not a copying channel. Nothing is copied into a queue.
- Not a garbage collector. Release is the application's, at a named point.
- Not a framework. The application calls it. It never calls back, except
  through the pool hooks of Part 12.

## 1.3 The absent type — MUST

There is no `Master` type.

- The concept exists: a component that creates the infrastructure, starts the
  threads and takes everything down.
- The toolkit ships no struct for it. The application writes it.
- A port that ships a `Master` struct has changed the design.
- *ztk*: `audit 3` row 44.

---

# Part 2 — Threads and waiting

The word "execution" in a heading is on the banned list of `rules-049.md`
Part 5. This part is that section.

## 2.1 Plain threads — MUST

- Participants run on plain OS threads, or on the language's nearest
  equivalent.
- Not fibers. Not green threads. Not an async runtime.
- The toolkit does not create them. The application does.
- The toolkit does not name them, count them, or keep a list of them.

## 2.2 Two primitives, and only two — MUST

The whole toolkit rests on two synchronization primitives.

- A mutex.
- A condition variable with a **timed** wait.

Nothing else is required. No atomics beyond the optional fast path of Part
15.4. No thread-local storage. No semaphore. No channel type from the standard
library.

This is why the toolkit is correct on more than one threading backend: every
wait goes through those two.

*ztk*: `audit 6.1`, `matryoshka-concepts-003.md:757-767`.

## 2.3 Blocking with a timeout is the primitive — MUST

- Every waiting call takes a timeout, or takes none and waits without end.
- A wait ends in exactly one of a small set of outcomes. Part 19 lists them.
- A polling call exists beside the blocking one, and never blocks.

## 2.4 A wakeup carries no meaning — MUST

- A return from a condition wait says only that the scheduler resumed the
  thread.
- It does not say that an item arrived.
- What the code finds after waking is the event.
- Every wait sits in a loop that re-evaluates the state from scratch.
- No single wakeup short-circuits the loop.

*ztk*: `audit 2.12`.

## 2.5 The deadline is anchored once — MUST

- A duration is converted to an absolute deadline **before** the retry loop.
- Converting inside the loop restarts the timeout on every spurious wakeup,
  and the call then never times out.
- This is a portable correctness point, not a detail of one language.

*ztk*: `audit 2.11`.

## 2.6 Signal hand-off on a lost race — MUST

- A waiter that leaves on timeout, or on interruption, checks the container
  before returning.
- If the container is not empty, the leaver signals or broadcasts.
- Without it, a pending signal is consumed by a waiter that then leaves, and a
  queued item sits with nobody woken.

*ztk*: `audit 2.14`.

## 2.7 Many producers, many consumers — MUST

- Any number of threads send to one mailbox.
- Any number of threads receive from one mailbox.
- Fan-in and fan-out on the same object.

## 2.8 Order among receivers is not defined — MUST

- Items leave a mailbox in order. Part 11.3 states which order.
- Which *receiver* gets the next item is the runtime's business, not the
  toolkit's.
- A port does not promise fairness among waiters. The underlying condition
  variable does not promise it either.

## 2.9 Interruption — SHOULD

- Where the language's waits can be interrupted or cancelled, a wait reports
  that as an outcome of its own.
- Interrupted is not closed. Distinct causes, distinct meanings, never
  remapped into each other.
- An interrupted wait leaves the Slot unchanged and the container untouched.
- Only waits are interruptible. Signal, broadcast and unlock are not.
- On a port with no such mechanism, this outcome is dropped and the timeout
  outcome stays.

*ztk*: `audit 2.10`.

## 2.10 Cleanup paths run to the end — MUST where 2.9 applies

- A path that gives an item back, or that takes a container down, is not
  interruptible.
- Concretely: the pool's give-back call cannot fail and cannot be interrupted.
- A worker interrupted while receiving must be able to give its item back. If
  the give-back could itself fail, the item is lost with nothing keeping it.

*ztk*: `audit 2.10`, `pool.zig:329`.

---

# Part 3 — Participants are long-lived heap objects

## 3.1 The rule — MUST

- A participant is allocated once, on the heap.
- It lives for the duration of the run.
- It is not copied. It is not moved in memory. Its address is its identity.
- Pointers to it are kept by other participants for the whole run.

## 3.2 Why the address is fixed — MUST

- The inner structure carries list links that point into other items.
- A moved item leaves those links pointing at the old address.
- So the language must offer a value that does not move: a heap allocation, or
  the equivalent.

## 3.3 Items versus participants — SHOULD

- A participant is a mailbox, a pool, or a thread's own state.
- An item is anything that travels.
- The two overlap. Part 11.1 states that the infrastructure objects are
  themselves items.
- A short-lived item is allowed. It is created, sent, received and released.
  Only the *participants* are required to be long-lived.

---

# Part 4 — Intrusion

## 4.1 The rule — MUST

- The outer struct embeds an inner structure as a field.
- The inner carries the list links and the type identity. Nothing else.
- An item threads onto a list by its inner. Nothing is allocated.
- The list has no knowledge of the outer type.

## 4.2 The inner — MUST

The inner has exactly two parts.

- The links of a doubly-linked list.
- The type identity of the outer. Part 5.

A port adds a third field only with a reason written down. Every item pays for
it.

*ztk*: `polynode.zig:83-86`, `audit 1.2`.

## 4.3 The field may sit anywhere — SHOULD

- The inner field is at any offset in the outer.
- The way back from inner to outer is address arithmetic: subtract the field's
  offset.
- A port whose cast needs offset zero fixes the field at offset zero instead,
  and loses nothing except freedom of layout.

*ztk*: `audit 3` rows 4 and 5.

## 4.4 One inner per outer — MUST

- An outer embeds exactly one inner.
- An item is therefore on at most one list at any moment.
- Part 9.6 states the invariant that follows.

## 4.5 What intrusion buys — background

- No allocation per enqueue. The item *is* the node.
- No wrapper object with its own lifetime.
- A heterogeneous list, because the list sees only inners.

Remove intrusion and a wrapper allocation returns on every transfer. That is
the reason it is a MUST.

---

# Part 5 — Identity

## 5.1 The rule — MUST

- The inner carries a value that identifies the *type* of the outer.
- The value is unique at runtime across all outer types in the program.
- Two items of the same outer type carry the same value.
- Two items of different outer types never do.
- Comparing two of them is O(1).

## 5.2 What it is not — MUST

- It is not the item's own identity. It does not distinguish two items of one
  type.
- It is not a string, and it is never compared by content.
- It is not an index into a table the application maintains.

## 5.3 Spelling is free — SHOULD

The shape is fixed. The spelling is the port's business.

- A language with a native runtime type identifier uses it.
- A language without one uses the address of a per-type value.
- *ztk*: a mutable one-byte global per instantiation. Mutable, because a
  constant may be merged by the linker with another constant of the same
  contents, and merged addresses are not unique.
- Uniqueness in ztk comes from the compile-time generator: one instantiation
  per type, one global per instantiation.

*ztk*: `polynode.zig:148-151`, `audit 1.4`, `audit 3` row 3.

## 5.4 The identity is stored, not computed — MUST

- The inner keeps the identity in a field.
- A walker of a type-erased list reads the field. It does not consult a
  registry and it does not ask the allocator.

## 5.5 The uninitialized identity — SHOULD

- An inner with no identity written is a defect.
- A port with a required constructor closes this at compile time.
- A port without one calls the initializer at every creation site, including
  the ones that do not allocate.
- *ztk*: the field defaults to an undefined value, and only the initializer
  writes it. A stack item whose initializer is not called carries garbage.

*ztk*: `audit 5.5`.

---

# Part 6 — Self-identification

## 6.1 The rule — MUST

- Any struct compares its own type identity against the identity in an inner.
- Equal means the inner belongs to an outer of that struct's type.
- Not equal means it does not, and the crossing is refused.

## 6.2 Where the check runs — MUST

The check runs at three places, and at no others.

- Crossing from a type-erased handle to a typed pointer.
- Crossing from a Slot to a typed pointer.
- Walking a heterogeneous list and deciding which items to claim.

## 6.3 Two forms of the crossing — MUST

Every crossing comes in two forms. Both are required.

- The **checking** form. Returns nothing when the identity does not match. The
  caller decides what to do.
- The **asserting** form. The mismatch is a defect of the program, not a
  runtime condition. It stops the program, or it is checked only in a build
  mode that checks.

A port names them apart so a reader sees at the call site which one is meant.

*ztk*: `fromPoly` and `mustFromPoly`; `fromSlot` and `mustFromSlot`.
`audit 1.4`.

## 6.4 What it makes safe — background

- A type-erased list is safe to walk, because every item answers what it is.
- A received item is safe to claim, because the receiver checks before it
  reads a single application field.

## 6.5 Dispatch on the identity — SHOULD

- One handler per pair of receiver and identity. A table, keyed on the
  identity.
- A miss on the table is not a defect. Nothing was called, so the item never
  left its Slot, and the caller releases it.
- The result of a handler is read from the Slot, not from the return value.
  Part 9.4.
- A port whose language can branch directly on a type identifier may do so.
  The table is one spelling.
- *ztk*: a branch is impossible, because the identity is an address assigned
  by the linker and a branch arm must be known at compile time. Equality still
  works, because equality needs only to know which global the value names.

*ztk*: `audit 2.4`.

---

# Part 7 — The per-type helper

## 7.1 The rule — SHOULD

- For each outer type there is a helper bound to that one type.
- The helper is generated at compile time from the type.
- It carries the type identity of Part 5, and the crossings of Part 6.

The *shape* is fixed. Generation is the convenience. A port with no
compile-time generation writes the same block by hand for each type, and loses
only the typing.

*ztk*: `polynode.zig:141-355`, `audit 3` row 6.

## 7.2 What the helper contains — MUST

Every helper carries these, whatever the spelling.

- The type identity value. Part 5.
- A predicate: does this identity name my type?
- Checking and asserting crossings from a type-erased handle to a typed
  pointer. Part 6.3.
- Checking and asserting crossings from a Slot to a typed pointer.
- A **moving** crossing from a Slot: on a match, the typed pointer is returned
  *and* the Slot is cleared. On a mismatch, nothing is returned and the Slot is
  untouched.
- A crossing the other way: from a typed pointer to a type-erased handle. This
  one cannot fail.
- An initializer that writes the identity into the inner.

## 7.3 Creation and release in the helper — SHOULD

- A helper may also carry a create and a release, both Slot-shaped. Part 9.
- Not every type wants them. A type that allocates itself, or that is
  allocated by something else, gets a helper without them.
- The *distinction* is real and portable. A port makes it by any means its
  language offers: two generators, an interface, a flag, a separate name.
- *ztk*: the type declares a marker constant, and the generator branches on
  its presence, producing one of two near-identical helpers. That spelling is
  Zig's, and it costs 110 duplicated lines.

*ztk*: `audit 3` row 8, `audit 5.6`.

## 7.4 Validation of the type — SHOULD

- The generator rejects a type with no inner field.
- It rejects an inner field of the wrong type.
- The message names the offending type.
- A port with compile-time reflection does this at build time. A port without
  it checks at first use.

*ztk*: `polynode.zig:357-363`.

## 7.5 The border, named once — MUST

- Application code never performs the address arithmetic of Part 4.3 by hand.
- Every crossing goes through the helper.
- That is what makes the arithmetic auditable: it appears in one file.

---

# Part 8 — The intrusive list

## 8.1 The rule — MUST

- A doubly-linked list whose nodes are the inners of Part 4.
- Items of different outer types sit on one list.
- Insert and remove are O(1).
- The list allocates nothing.

## 8.2 The surface — SHOULD

The operations a port provides. Names are the port's business.

- Take from the front. Take from the back. Both may find the list empty.
- Remove a named item from the middle.
- Look at the front. Look at the back. Neither removes.
- Add at the back. Add at the front.
- Add at the back from a Slot. Add at the front from a Slot. Part 9.
- Insert after a named item. Insert before a named item.
- Is it empty.
- How many.
- Walk it.
- Move every item of another list onto this one, leaving that one empty.

No operation on the list can fail. There is no error to report.

*ztk*: `polynode.zig:379-603`, `audit 1.5`.

## 8.3 The list speaks in handles — MUST

- Every entry point takes and returns a type-erased handle, never an inner
  pointer and never a typed pointer.
- The caller crosses the border itself, through the helper of Part 7.

## 8.4 The walk — SHOULD

- A separate walker value, taken from the list.
- It yields handles, one at a time, until it is exhausted.
- Removing the current item during a walk is not supported. A port that
  supports it says so.

## 8.5 The list is where the checks live — MUST

- A raw list primitive from a standard library checks nothing.
- The Matryoshka list is the layer that checks. Part 8.6.
- A port that uses the language's own list primitive still writes this layer over it.

*ztk*: `audit 3` row 17.

## 8.6 The double check on insert — SHOULD

Every insert checks twice. Both checks, under a build mode that checks.

- **The walk.** Walk this list, compare addresses, and refuse an item already
  on it.
- **The link test.** Read the item and refuse one that already has neighbours.

Neither alone is enough.

- The walk sees a list of exactly one member, which the link test cannot.
- The link test sees a *different* list, which the walk cannot.

The walk makes an insert O(n), in checking builds and nowhere else.

*ztk*: `audit 2.3`.

## 8.7 The link test and its blind spot — MUST

- The link test asks whether an item has neighbours. It is not a membership
  test.
- An item alone on a list has no neighbours, and reports false.
- Every assert built on the link test inherits that blind spot.
- A port whose list marks membership properly is strictly better here, and
  pays a field per item for it. That is a design call, not a porting one.

*ztk*: `audit 2.2`, `polynode.zig:104-116`.

## 8.8 The repair — MUST

- After a removal, the item's links are cleared.
- A cleared item passes the link test of Part 8.7 and can be inserted again.
- Every removal in the list surface does this for the caller.
- Any path that reaches around the list surface does it by hand.

## 8.9 Moving a list onto itself — SHOULD

- Moving a list onto itself is refused, twice: an assert, and an early return.
- The assert is compiled out where asserts are compiled out. The early return
  is not.
- Without the pair, the naive move rings the items into a cycle and clears the
  header, losing every one.
- Worth carrying into any port whose list primitive has the same flaw.

*ztk*: `audit 2.16`.

## 8.10 Bridging to the language's own list — MAY

- Two conversions: adopt a plain list, and hand one out.
- Only meaningful where the standard library has an intrusive list of the same
  node type.

*ztk*: `audit 3` row 18.

## 8.11 Test access to the raw list — MAY

- ztk exposes the underlying plain list so tests can reach it, and documents
  it as not for application use.
- A port with better test access drops it.

*ztk*: `audit 5.4`.

---

# Part 9 — The Slot idiom

## 9.1 The rule — MUST

A **Slot** is a container of one handle, or of nothing.

- Its emptiness is the transfer signal.
- Empty means: the item is elsewhere.
- Full means: the item is here, and this Slot's holder is responsible for it.

It covers both transfer and creation. Every acquisition and every release in
the toolkit is Slot-shaped.

## 9.2 The six rules — MUST

All six. A port that keeps five has not kept the idiom.

1. Never overwrite a full Slot.
2. A Slot starts empty.
3. An acquisition asserts the Slot is empty on entry.
4. An acquisition that fails leaves the Slot unchanged.
5. A transfer clears the Slot.
6. A release is a no-op on an empty Slot.

*ztk*: `audit 2.1`, with the assert site of every one.

## 9.3 The signature shape — MUST

- An operation that acquires takes a pointer to a Slot, and writes into it.
- It does not return the item.
- The return channel carries the *outcome*, not the item.
- On failure the Slot is untouched, so the caller's error path has nothing to
  undo.

This is the idiom's own shape. It is not a workaround for a missing return
type.

## 9.4 The Slot is the answer — MUST

- After a call that may or may not have taken the item, the caller reads the
  Slot.
- Cleared means it was taken. Unchanged means it was not.
- The outcome value does not say where the item went. The Slot says.
- This holds for the pool's give-back, for a dispatch handler, and for every
  transfer.

## 9.5 The one exception — MAY

- A call may instead move the item out through a returned value that carries
  every outcome as one of its cases.
- That form exists so a blocking call can be a source of events for a select
  mechanism.
- A port with no select mechanism does not provide it.
- Where it is provided, it is the documented exception to Part 9.3, and it is
  named apart from the Slot-shaped call.

*ztk*: `audit 2.1` closing paragraph, `audit 3` row 27.

## 9.6 One place at a time — MUST

The invariant the whole idiom protects.

- An item on a list belongs to exactly one list. Never two.
- A Slot has exactly one item, or nothing.
- An item is either with application code, in a Slot, or with infrastructure,
  in a queue or a free list. Never both.
- The identity of Part 5 is compared by value, never by content.

*ztk*: `audit 2.17`.

## 9.7 Cleanup registered before acquisition — SHOULD

- The release of a Slot is arranged *before* the acquisition that fills it.
- The release is a no-op on an empty Slot, which is what makes this legal.
- So every path out of the function releases the item, including the ones the
  author did not think about.
- A port with scope-exit cleanup writes one line. A port without it writes the
  same shape by hand at every exit, and must not skip it.

*ztk*: `audit 3` row 15.

## 9.8 Creation is an acquisition — SHOULD

- A create fills a Slot. It does not return a pointer.
- So creation obeys rules 3 and 4 of Part 9.2 like every other acquisition.
- The caller's next line moves the item out of the Slot into a typed pointer.
- A port may return a pointer instead, and loses the uniformity.

*ztk*: `audit 3` row 36.

## 9.9 The Slot's own type — MAY

- ztk makes the Slot a transparent alias for a nullable handle.
- A port may make it a distinct or opaque type, and catch misuse at compile
  time.
- The cost is the reading shape: a transparent Slot can be unwrapped with the
  language's own null test.
- Any two-state container works: a nullable pointer, a tagged union, a struct
  with a flag.

*ztk*: `audit 6.4`.

---

# Part 10 — Deliberate synonyms

## 10.1 The rule — SHOULD

Several names point at one thing. They are kept apart, not collapsed.

- **inner** — the embedded structure, as a field of the outer.
- **handle** — a pointer to an inner, seen by the toolkit, with no type
  knowledge.
- **Slot** — a container of one handle, whose emptiness is the signal.
- **item** — the outer struct, seen by the application.

## 10.2 Why they are not collapsed — background

- Each name marks a different usage stress on the same address.
- A reader of a signature learns from the name which side of the border they
  are on.
- The compiler learns nothing. This is a reading aid, and it is the only
  safety a transparent alias gives.
- A port may collapse them, and loses exactly that.

*ztk*: `audit 3` row 12.

## 10.3 The word "object" — SHOULD

- "object" is not used for an item or a handle. Say "item".
- Elsewhere in prose the word is free.

*ztk*: `rules-049.md` Part 5, scoped ban.

---

# Part 11 — The two infrastructure objects

## 11.1 They are themselves items — MUST

- The mailbox embeds an inner. The pool embeds an inner.
- Each has a type identity, and the crossings of Part 6.
- So a mailbox travels through a mailbox. A pool sits on a list.
- One rule set covers everything. This is the toolkit's stated reason for
  existing.

*ztk*: `audit 3` row 40.

## 11.2 One internal base — SHOULD

Both are built on the same internal parts.

- The inner of Part 4.
- A mutex.
- A condition variable.
- A closed flag.
- An allocator, kept for life. Part 13.

The base is not public. It is a statement about how the two are built, not a
type the application names.

## 11.3 The mailbox — MUST

A queue of items, with waiting.

Operations, by outcome rather than by signature. Part 19 has the outcome sets.

- **send** — the item moves in, at the back. Slot-shaped.
- **send out-of-band** — the item moves in, ahead of every ordinary item.
- **receive** — wait for an item, with a timeout or without one.
- **poll** — take an item if one is there, and never wait.
- **receive the batch** — take every item at once, as a list.
- **close** — no more sends. Returns what was left, as a list.
- **wake every waiter** — Part 11.5.

Ordering.

- Ordinary items are first-in, first-out among themselves.
- Out-of-band items are first-in, first-out among themselves.
- Every out-of-band item sits ahead of every ordinary one.
- A port keeps an anchor at the last out-of-band item, so the insert stays
  O(1). An empty anchor means insert at the front.
- The anchor is cleared when the last out-of-band item is taken.

*ztk*: `audit 2.15`.

## 11.4 Out-of-band is one level, not a queue — MAY

- It is one priority level. It is not a priority queue.
- It exists because signals and data share one channel, as items marked at the
  front.
- A port that keeps signals on a separate channel does not need it.

*ztk*: `audit 6.4`.

## 11.5 Waking every waiter — SHOULD

- A call that releases every current waiter, without closing the mailbox and
  without giving anyone an item.
- Each released waiter reports "woken" as its outcome.
- The mailbox stays open.
- The effect does not persist. A thread that starts waiting afterwards is not
  affected.
- The mechanism: a counter bumped by the waker, captured by each waiter before
  it waits, and compared after every wakeup.

*ztk*: `audit 2.13`.

## 11.6 The give-back rule, mailbox side — MUST

Every item a mailbox keeps goes back to a caller.

- A receive gives it to the receiver.
- A send that is refused leaves it with the sender, Slot unchanged.
- A batch receive gives the whole list to the caller.
- A close gives the remainder to the caller, as a list.

And:

- Releasing them is the caller's work. What the items are — items to free,
  items to give back to a pool — is knowledge the mailbox never had.
- The release runs unconditionally. An empty list costs nothing.
- Discarding the list a close returns is the named mistake. It drops items,
  and those items keep their links, so a later send refuses them.

*ztk*: `audit 2.6`.

## 11.7 The pool — MUST

A keeper of reusable items, grouped by type identity.

- One free list per identity.
- One count per identity, if the list's length is not O(1).
- The set of identities is fixed at creation and is not empty.
- Policy is not in the pool. Policy is in the hooks of Part 12.

Operations.

- **get**, in three modes.
  - available or new — take a stored item, else ask the hook for one.
  - new only — always ask the hook.
  - available only — take a stored item, else report not-available. No hook.
- **get with waiting** — take a stored item, or wait for one, with a timeout.
  It never creates. Part 11.9.
- **put** — give an item back. Slot-shaped. Cannot fail.
- **put a list** — give many back.
- **close** — take everything down through the hook.

## 11.8 The give-back rule, pool side — MUST

The mirror image of Part 11.6, and the sharpest asymmetry in the toolkit.

- A pool's close collects everything and passes it to the hook. Nothing comes
  back to the caller.
- A closed pool refuses a put and leaves the Slot unchanged, so the caller
  still has the item.
- A list put stops at the first refusal, puts that item back at the front of
  the caller's list, and returns. The caller checks the list after the call.
- The restored order after a mid-batch close may differ from the original.

*ztk*: `audit 2.6`.

## 11.9 Waiting get never creates — MUST

- The waiting get takes a stored item or waits for one.
- It calls no creation hook.
- Where a plain get in available-only mode reports not-available, the waiting
  get reports a timeout. The divergence is deliberate.
- *ztk*: the book says twice that the waiting get calls the creation hook. The
  code says it does not. The code is the truth. A port follows the code.

*ztk*: `audit 5.2`, an open question of the ztk line, not of this
specification.

## 11.10 No sequence guarantee — MUST

- Put three items, then get three. The count, the identity and the order are
  all hook policy.
- The pool promises nothing about which item comes back.

## 11.11 Hidden implementation — SHOULD

- The internals of both objects are not part of the surface.
- Where the language has opaque types or private fields, they are hidden.
- *ztk*: the fields are reachable, and a comment says they are internal. Zig
  has no private field. This is a case where a port is *better* than ztk, not
  merely different.

*ztk*: `audit 5.3`.

## 11.12 Close before release — MUST

- Releasing an open mailbox is a defect. Releasing an open pool is a defect.
- Both stop the program. In every build mode. Not an assert that compiles out.
- This is the one precondition the toolkit refuses to soften.
- Closedness is a precondition **here and nowhere else**. Every other call on
  a closed object reports closed, or is a no-op, and the object stays a valid
  item.
- Close is callable more than once. The second call takes nothing, and does
  not run the pool's close hook again.
- The test-and-set of the closed flag is inside the mutex, so a preempted
  closer cannot race a release.

*ztk*: `audit 2.5`.

---

# Part 12 — Hooks as an interface

## 12.1 The rule — MUST

- The pool's policy is supplied by the application, as callbacks.
- They are a parameter of creation, not a later step. A pool cannot exist
  without them.
- The port spells them in the language's own interface mechanism.
- *ztk*: a struct of raw function pointers plus a type-erased context, because
  Zig has no interface keyword.

*ztk*: `audit 3` row 33.

## 12.2 The three hooks — MUST

**on get.** Asked for an item of a named identity.

- The Slot is empty on entry.
- Create one, or leave the Slot empty to report failure.
- Returning an item of a different identity is a defect of the application.
- An empty Slot afterwards becomes the not-created outcome.

**on put.** An item is being given back.

- Four outcomes, none mandated.
  - Released, with nothing kept.
  - Kept as it is.
  - Kept after a reset.
  - Released, with a different item put in the Slot.
- A full Slot on return means one thing: an item is kept. Original or
  replacement.
- The hook may also return an extra list. Each item in it is added the same
  way, with the same checks. This is how a composite item gives its parts
  back.
- The pool does not check that the parts form a real composite, and does not
  tell composite from simple.

**on close.** The pool is going down.

- Called once, with the full list of what remained.
- The hook is responsible for processing or releasing every item.
- Called **outside** the mutex, after the closed flag is already set.

*ztk*: `audit 2.7`.

## 12.3 Hook concurrency — MUST

- Hooks run outside the pool's mutex. The pool unlocks, calls, and relocks.
- Several hooks run at once, on different threads. The pool does not serialize
  them.
- A hook that touches shared state protects it itself.
- A hook does not call back into the pool, and does not block or wait. That is
  the contract, not a warning about deadlock — the lock is not held while a
  hook runs.
- A hook reports nothing, so it has no way to report an interrupted lock. It
  acquires locks uninterruptibly.

## 12.4 The count is a hint — MUST

- The in-pool count passed to a hook is read under the lock and used without
  it.
- It is a hint. It is stale by the time the hook reads it.
- On get, it is the count *after* removal. On put, the count *before*
  addition.

## 12.5 The extra list on put — SHOULD

- It is the composite mechanism.
- Removing it means a composite item has no way to give its parts back in one
  call.

*ztk*: `audit 3` row 34.

---

# Part 13 — Allocators

## 13.1 The rule — SHOULD

- An object takes an allocator at creation.
- It keeps it for life.
- It releases itself with the kept one.
- No release call takes an allocator as a parameter.

## 13.2 Why — background

- A create and a release are usually far apart: create in a producer, release
  in a consumer or in a pool hook.
- Nothing links the two call sites.
- Passing an allocator at release lets the kept one and the passed one differ,
  with nothing checking that they match.

## 13.3 The state of ztk — background

- Both infrastructure objects already keep an allocator.
- Both release calls also *take* one, and use the parameter, not the kept
  field.
- Application items keep none. Their inner has no allocator field.
- So a port that follows Part 13.1 removes the parameter from both release
  calls, and removes the mismatch.

*ztk*: `audit 5.1`.

## 13.4 Application items — open

- Whether an application item keeps its own allocator is a decision each port
  makes.
- The cost is one pointer per item, which is real on a small item.
- The benefit is a release that needs no second argument and cannot mismatch.
- This specification does not decide it. Part 20 lists it.

## 13.5 A language with no explicit allocator — SHOULD

- Where the language allocates without an allocator value, Parts 13.1 to 13.3
  collapse to nothing.
- The rule that survives: a release call takes no allocation argument.

---

# Part 14 — The transfer model

## 14.1 One holder at a time — MUST

- An item has exactly one holder.
- A transfer is a move. Nothing is copied.
- After a transfer the previous holder has no valid pointer to the item.
- The Slot idiom of Part 9 is how a transfer is spelled.

## 14.2 The transfer orders memory — MUST

Exclusive access has two halves. This is the half that is invisible in the
signatures.

- Possession is the visible half.
- The second half: the new holder sees every write the previous holder made.
- Mailbox and pool publish through their own mutex. That is what carries it.
- So a holder reads the item's fields with plain loads. No atomics. No fences.
- This is why the toolkit is safe with no locks around application data.
- This is also why the toolkit can assert on an item's internal state at all.
- It does not extend to an item two callers both believe they have. That
  mistake breaks the premise the guarantee rests on.

*ztk*: `audit 2.8`.

## 14.3 The transfer circuit — SHOULD

The shape of a full round trip.

```
    +-------------+                      +-------------+
    |  producer   |                      |  consumer   |
    +-------------+                      +-------------+
          |                                     |
          |  get(pool) -> Slot full             |
          |                                     |
          |  send(mailbox) -> Slot empty        |
          | ----------------------------------> |
          |                                     |  receive -> Slot full
          |                                     |
          |                                     |  use the item
          |                                     |
          |                                     |  put(pool) -> Slot empty
          |                                     |
    +-------------+                      +-------------+
    |    pool     | <------------------------------------
    +-------------+
```

- Every arrow is a Slot going from full to empty on one side and from empty to
  full on the other.
- No step allocates, once the item exists.
- The pool is what makes the circuit closed rather than a line ending in a
  release.

---

# Part 15 — The concurrency contract

Stated without naming any runtime library.

## 15.1 What the toolkit locks — MUST

- Each infrastructure object has one mutex.
- The mutex covers that object's own state, and nothing else.
- No application data is under it.
- No lock is held across a call into application code. Part 12.3.

## 15.2 What the toolkit does not lock — MUST

- The item's own fields. Part 14.2 explains why none is needed.
- Anything belonging to another infrastructure object. There is no lock
  ordering to respect, because no path takes two.

## 15.3 The closed flag — MUST

- Reading it, and setting it, happen under the mutex.
- Setting it is the whole of close's state change. What follows is giving
  items back.

## 15.4 The pre-lock check — SHOULD

An optimization with a correctness rule attached.

- Keep the closed flag as an atomic.
- Read it before taking the mutex. A closed object reports closed with no lock
  taken.
- **Re-read it under the lock.** Close may fire between the first read and the
  acquire.
- The memory ordering is not decoration: acquire outside the lock, relaxed
  inside it, release on the store.
- A port may drop the whole fast path, at a cost in contention. It may not
  drop the re-check while keeping the fast read.

*ztk*: `audit 2.9`, `audit 3` row 29.

## 15.5 Asserts versus reported outcomes — SHOULD

Two kinds of wrong, and the line between them is a design statement.

- A **contract violation** is a defect of the calling program. Overwriting a
  full Slot. Inserting a linked item. Releasing an open container.
  - It asserts, or it stops the program.
  - It may be compiled out where the language distinguishes build modes.
- A **runtime condition** is a legitimate state of a correct program. Closed.
  Timeout. Nothing available.
  - It is reported as an outcome, always, in every build mode.
- Releasing an open container is the one contract violation that never
  compiles out. Part 11.12.

*ztk*: `audit 3` row 39.

---

# Part 16 — The excluded surface

Named once, so no port re-derives the list.

These exist in ztk only because of Zig 0.16 and its `std.Io`. A port on plain
threads deletes every row and loses no Matryoshka semantics.

| # | Excluded | What it is |
|---|---|---|
| 1 | The runtime handle field on both objects | A value kept only so every wait can be issued. |
| 2 | The runtime handle parameter on both creates | Its only work is to fill row 1. |
| 3 | The two future-returning calls | Thin wrappers over a concurrency primitive. |
| 4 | The concurrency error type in those signatures | The runtime's error for a single-threaded backend. |
| 5 | The future type in those signatures | The runtime's future type. |
| 6 | The timeout construction shape | A port passes a plain duration or a deadline. |
| 7 | The hand-written timed condition wait, whole file | Exists because Zig 0.16 has no timed wait on its condition variable. A language that has one deletes 71 lines. |
| 8 | Its error type | Same reason. |
| 9 | The two result unions | Their only consumer is the select mechanism. |
| 10 | The two result-returning calls | They map every outcome to a union case for select. |
| 11 | The uninterruptible lock call at every non-waiting site | Meaningless without interruption. Part 2.9. |
| 12 | The interruptible error in the two waiting signatures | Conditionally excluded. A port with interruption keeps the concept, not the spelling. |

Borderline, and deliberately **not** excluded.

- Waking every waiter. It is a mailbox operation with its own counter, not a
  bridge to a runtime. Part 11.5.
- The atomic closed flag. It uses the language's atomics, not the runtime.
  Part 15.4.

Two more spellings that are Zig's and not Matryoshka's.

- **Error sets as the return channel.** The *set of outcomes* is fixed. Part
  19. Errors, a status value, or an optional — the mechanism is free.
- **The compile-time marker constant** that selects the reduced helper. The
  distinction is real. The spelling is Zig's. Part 7.3.

*ztk*: `audit 4`, `audit 3` rows 13 and 8.

---

# Part 17 — The three tools

## 17.1 One is required — MUST

- The intrusive layer is the toolkit. The inner, the identity, the helper, the
  list, the Slot. Parts 4 to 10.
- Without it there is nothing to port.

## 17.2 Two are optional — SHOULD

- The mailbox is optional. An application that has its own queue keeps its own
  queue, and puts Matryoshka items on it.
- The pool is optional. An application that allocates every item afresh needs
  no pool.
- Both are built *on* the intrusive layer, with no privileged access to it.
  Every crossing they perform is a crossing an application could write.

## 17.3 Why that matters — background

- It is the test of the design. If the mailbox needed something the
  application cannot have, the layering would be a fiction.
- It is also the porting order. Part 4 to Part 10 first, and the two
  containers after.

---

# Part 18 — The invariants, in one table

Every MUST of Parts 2 to 15, in the order a port meets them.

| # | Invariant | Part |
|---|---|---|
| 1 | Plain threads. The toolkit starts none. | 2.1 |
| 2 | A mutex and a timed condition wait. Nothing else. | 2.2 |
| 3 | A wakeup carries no meaning. Re-check the state. | 2.4 |
| 4 | The deadline is anchored before the loop. | 2.5 |
| 5 | A leaver signals if the container is not empty. | 2.6 |
| 6 | Participants are long-lived and do not move. | 3.1 |
| 7 | The outer embeds the inner. The list allocates nothing. | 4.1 |
| 8 | One inner per outer. | 4.4 |
| 9 | A per-type identity, unique at runtime, O(1) to compare. | 5.1 |
| 10 | The identity is stored in the inner, never computed. | 5.4 |
| 11 | Self-identification at every border crossing. | 6.1 |
| 12 | Two crossing forms: checking and asserting. | 6.3 |
| 13 | The list is heterogeneous, O(1), allocation-free. | 8.1 |
| 14 | The list speaks in type-erased handles. | 8.3 |
| 15 | The list layer is where the checks live. | 8.5 |
| 16 | The link test is not a membership test. | 8.7 |
| 17 | A removed item's links are cleared. | 8.8 |
| 18 | The six Slot rules. | 9.2 |
| 19 | The Slot, not the outcome, says where the item went. | 9.4 |
| 20 | An item is in exactly one place at all times. | 9.6 |
| 21 | The two containers are themselves items. | 11.1 |
| 22 | Out-of-band items are ahead of ordinary ones, FIFO within each. | 11.3 |
| 23 | Every item the mailbox keeps goes back to a caller. | 11.6 |
| 24 | The pool's close gives nothing back to the caller. | 11.8 |
| 25 | The waiting get never creates. | 11.9 |
| 26 | Close before release. Unconditional. | 11.12 |
| 27 | Hooks are a parameter of creation. | 12.1 |
| 28 | Hooks run outside the mutex, in parallel, and do not call back. | 12.3 |
| 29 | The in-pool count is a hint. | 12.4 |
| 30 | One holder at a time. A transfer is a move. | 14.1 |
| 31 | The transfer orders memory. | 14.2 |
| 32 | One mutex per container, covering its own state only. | 15.1 |
| 33 | No lock is held across a call into application code. | 15.2 |

---

# Part 19 — The outcome sets

The outcomes of every operation, as values. A port picks its own mechanism:
errors, a status value, an optional, a union.

## 19.1 Mailbox

| operation | outcomes |
|---|---|
| send | done; closed, Slot unchanged |
| send out-of-band | done; closed, Slot unchanged |
| receive | item; closed; timeout; interrupted; woken |
| poll | item; empty; closed |
| receive the batch | a list, possibly empty; closed |
| close | a list, possibly empty. Cannot fail. |
| wake every waiter | done; closed |

## 19.2 Pool

| operation | outcomes |
|---|---|
| get | item; closed; not-available; not-created |
| get with waiting | item; closed; timeout; interrupted |
| put | nothing. Read the Slot: cleared means kept, unchanged means refused. |
| put a list | nothing. Read the list: non-empty means the rest was refused. |
| close | nothing. Cannot fail. |

## 19.3 The asymmetry in get — MUST

- not-available comes only from the available-only mode.
- not-created comes only from a hook that produced nothing.
- The waiting get reports a timeout where available-only reports
  not-available. Part 11.9.

## 19.4 The list layer

- No operation on the list can fail.
- There is no outcome to report, and no error type.

*ztk*: `audit 6.2`.

---

# Part 20 — What each port decides

Open. This specification does not rule on them. Each port answers, in writing.

1. **Is the Slot a distinct type?** Opaque catches misuse at compile time, and
   costs the language's own null-test reading shape. Part 9.9.
2. **Do application items keep an allocator?** One pointer per item against a
   release call that cannot mismatch. Part 13.4.
3. **One helper, or two variants?** The distinction is real. The mechanism is
   the port's. Part 7.3.
4. **Is the link test's blind spot acceptable?** A list that marks membership
   is strictly better and costs a field per item. Part 8.7.
5. **Both a blocking receive and a poll?** A receive with a zero timeout has
   the same reach. The two differ only in how the empty case is reported.
6. **Out-of-band, or a second channel?** Part 11.4.
7. **Errors, a status value, or an optional?** The outcome set is fixed. Part
   19.
8. **Is interruption modelled at all?** Part 2.9.
9. **Is the pre-lock fast path kept?** Part 15.4.
10. **Where does the O(n) insert check live** on a port with no build modes?
    Part 8.6.

---

# Part 21 — The capability questionnaire

The questions a language answers before it can host Matryoshka.

Every port answers this same list, with a citation per answer. A "no" is not a
refusal — it names what the port pays instead.

## Q1 — Compile-time generation over a type

- Can code be generated from a type at compile time?
- If no: the per-type helper is hand-written per type. Part 7.1.

## Q2 — A per-type identity

- Is there a value, one per type, unique at runtime, comparable in O(1)?
- Native type identifier, or the address of a per-type value?
- If the address: can a per-type value be forced to a unique address, not
  merged with another of the same contents? Part 5.3.

## Q3 — Embedding and inner-to-outer arithmetic

- Can one struct be embedded in another by value?
- Given a pointer to the inner and the outer's type, can the outer's address be
  computed?
- If no: the inner is fixed at offset zero and the crossing is a cast. Part
  4.3.

## Q4 — Opaque types or private fields

- Can a struct's fields be hidden from the application?
- If no: a comment says internal, and the port is no better than ztk here.
  Part 11.11.

## Q5 — Interfaces or vtables

- Is there an interface mechanism for the pool's hooks?
- If no: a struct of function pointers plus a type-erased context. Part 12.1.

## Q6 — Scope-exit cleanup

- Is there a defer, a destructor, or an equivalent that runs on every exit
  from a scope?
- If no: the release is written by hand at every exit, and none is skipped.
  Part 9.7.

## Q7 — Threads, a mutex, a condition variable with a timed wait

- Are there OS threads or an equivalent?
- Is there a mutex?
- Is there a condition variable?
- **Does its wait take a timeout?** If no, the port writes one. ztk paid 71
  lines for it. Part 2.2.

## Q8 — An allocator an object keeps for life

- Is allocation parameterized by an allocator value?
- Can an object keep one in a field and release itself with it?
- If allocation is not parameterized: Part 13.5.

## Q9 — A two-state container for the Slot

- Is there a nullable pointer, or an equivalent two-state container?
- Can it be made distinct or opaque, if the port wants that? Part 9.9.

## Q10 — Atomics

- Are there atomic loads and stores with acquire, release and relaxed
  ordering?
- If no: the pre-lock fast path is dropped, and the closed flag is read under
  the mutex only. Part 15.4.

## Q11 — Build modes

- Is there a distinction between a checking build and a fast one?
- Can an assert be compiled out?
- If no: Part 15.5 still holds, and the port decides what the checks cost in
  production. Part 8.6.

## Q12 — Compile-time reflection on a struct's fields

- Can the generator check that a type has an inner field of the right type?
- If no: the check happens at first use. Part 7.4.

---

# Part 22 — The porting order

Not conformance. A suggestion, from the layering of Part 17.

1. Answer Part 21. Every question. In writing.
2. The inner, and the identity. Parts 4 and 5.
3. The per-type helper, with the crossings. Parts 6 and 7.
4. The Slot, and its six rules. Part 9.
5. The list, with both insert checks. Part 8.
6. The mailbox. Part 11.3 to 11.6.
7. The pool, with its hooks. Parts 11.7 to 11.10 and 12.
8. Delete nothing from Part 16. It was never written.

Steps 2 to 5 are the toolkit. Steps 6 and 7 are built on it, with no
privileged access.

---

## Change log

| Version | Date | Description |
|---|---|---|
| 001 | 2026-08-23 | First version. Stage 3TK-2. |
