# The Matryoshka portable specification (005)

Stage 3TK-52 of [3tk-staging-plan-020.md](../c3/3tk-staging-plan-020.md),
written 2026-08-28. **005 changes one Part — 11.12 — and the three places that
cite it.** Release required the container to be **closed**. It now requires it
to be closed **and quiet**: closed, and with no call the application made still
running. The second is the one that was missing, and a caller who obeyed every
clause 004 stated could still release a container out from under a call in
flight. The change log at the end names the difference.

**Found by building, like 004.** The C3 port hit it in code — `Part 12.3`
forces the mutex open across every hook, so a close-and-release inside that
window makes the hook's relock touch freed memory — and fixed its own side
first. This version is the shared half of that work.

004 was stage 3TK-17 of
[3tk-staging-plan-009.md](../c3/backup/3tk-staging-plan-009.md), written
2026-08-24. **It changed one Part — 7.1 — and nothing else.** It was the first
specification defect found since 003, and it was found by building a port
rather than by auditing one: the C3 port answered *generate code per type*
with call-site expansion instead of a per-type object, and Part 7.1 as 003
worded it described the object rather than the promise.

003 was stage 3TK-13 of
[3tk-staging-plan-007.md](../c3/backup/3tk-staging-plan-007.md), written from
[3tk-deviations-001.md](../c3/3tk-deviations-001.md) — the audit that measured
the C3 port against version 002, Part by Part, and split what it found into
*this port only* and *every port*. **Only the every-port half is in this
document.** Versions 001, 002 and 003 are in [backup/](backup/).

This document says what Matryoshka is, without naming a language.

It is self-contained. A port is written from this file alone.

**Two realizations appear, and only as realizations.** Lines marked *ztk* are
Zig's. Lines marked *3tk* are C3's. Where the two differ, both are shown, so a
reader cannot mistake either one for the rule — the mistake that produced 003,
and the one 004 finishes in Part 7.1. Part 11.11 already said in its own words
that a port can be *better* than ztk, not merely different; 003 is the first
version where that is visible on the page.

## How to read this

- Every element carries a conformance marking. Part 0 defines the four.
- Every part states the rule first. Evidence and background come after.
- The external references are `ztk-audit-001.md`, and behind it
  `src/polynode.zig`, `src/mailbox.zig`, `src/pool.zig`; and for the *3tk*
  lines, `../c3/3tk/src/`. Nothing else.
- Terminology: **inner** is the embedded structure. **outer** is the struct
  that embeds it. Never "parent".
- **Part numbers do not move.** A Part deleted in this version stays in place
  as a tombstone that says it was deleted and why. Part numbers are cited by
  hand across four documents and roughly forty doc comments, and renumbering
  would silently invalidate every one. Part 18's invariant table already worked
  this way — assumption A1.

## Sources

- [ztk-audit-001.md](ztk-audit-001.md) — the read-only record of the Zig
  realization. Section numbers of the audit are cited as `audit 2.1`.
- [3tk-deviations-001.md](../c3/3tk-deviations-001.md) — the read-only record of
  the C3 realization measured against 002. Cited for the *3tk* lines.
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

The inner has exactly two conceptual parts.

- **Linkage** — enough to thread the item onto one ordering primitive of Part
  8, and to answer whether it is on one at all. Part 8.7.
- **Identity** — the type identity of the outer. One field. Part 5.

**Two parts. The field count is the realization's, not the specification's.**
Both known realizations are conformant and they do not agree on it:

- *ztk*: two link fields, a previous and a next, plus the identity. Three
  fields.
- *3tk*: one link field plus the identity. Two fields, 16 bytes on a 64-bit
  target against ztk's 24. The backward link is not needed because neither
  container removes from the middle — Part 8.2 — and the link test of Part 8.7
  is made exact by a terminator rather than by a second field.

A port that needs a previous link writes one. A port whose containers never
remove from the middle does not.

A port adds a further per-item field only with a reason written down. Every
item in the program pays for it, including the items that never use it. That
is the test the field has to pass, and an allocator is the one that most often
fails it — it serves the subset of items the toolkit allocates and is charged
to all of them. Part 13.4.

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

**This is a pattern the application writes. The toolkit ships nothing for it.**
Every clause below describes application code — the receiver is the
application's, the handlers are the application's, and the last clause hands the
release to the caller. A port that ships no dispatch table has skipped nothing
and owes no explanation; what it owes is that Parts 5 and 6 make the pattern
writable. 002 did not say whose element this was, and a port read the silence as
a skipped SHOULD — assumption A4.

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
- *3tk*: nothing shipped, on the reading above. The heterogeneous walk that
  claims by identity is in a test — `t_identity.c3:129-151` — as the
  demonstration that the pattern is writable, which is all this Part asks of a
  port.

*ztk*: `audit 2.4`.

---

# Part 7 — The per-type helper

## 7.1 The rule — SHOULD

- For each outer type, the members of Part 7.2 exist, specialized to that one
  type.
- They are generated from the type at compile time, rather than hand-written.
- The type identity of Part 5 and the crossings of Part 6 arrive together, from
  the one act of generation.

The *promise* is that a crossing is typed, and that the typing is not copied by
hand. **How a port spells the generation is the port's business.** A named
per-type object is one spelling of it and not the rule; expansion at each call
site is another. A port with no compile-time generation at all writes the same
block by hand for each type, and loses only the typing.

***Helper*** is this document's word for that per-type surface, whatever a port
calls it and wherever the generated code ends up living. Part 7.2 is its
content, and that is the MUST.

*ztk*: a per-type structure, produced by a comptime function from the type —
one named helper object per outer type, the members its declarations.
`polynode.zig:141-355`, `audit 3` row 6.

*3tk*: no per-type object and no instantiation, for any type, ever. The members
are macros over a type parameter, and the code is generated at each call site
from the type named there. A new outer type costs nothing before it can be
used. `../c3/3tk/src/helper.c3`, and `3tk-deviations-001.md` V19 for why the
two realizations part company here.

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

**Ordering primitives whose nodes are the inners of Part 4.** Not one shape: as
many as the containers of Part 11 need, and no more.

- Items of different outer types sit on one of them.
- Insert and removal are O(1).
- They allocate nothing.
- The layer is where the checks live. Part 8.5.

*Version 002 said "a doubly-linked list", singular, and that was ztk's
mechanism read as the rule.* What the design requires is first-in-first-out for
the mailbox and a give-back container for the pool. Whether one general list
serves both, or two narrow ones do, is the port's call.

- *ztk*: one doubly-linked list, used by both containers.
- *3tk*: two singly-linked primitives — a FIFO queue for the mailbox, a stack
  for the pool's per-identity storage. Neither removes from the middle, which
  is what pays for the single link field of Part 4.2.

## 8.2 The surface — SHOULD

**The rule is the requirement, not the count.** A port provides what the
containers of Part 11 and the application actually call, and nothing else.
Names are the port's business.

Required, because Part 11 cannot be built without them:

- Add at the back — or push, on a primitive with one end.
- Take from the front — or pop.
- Is it empty. How many.
- Move every item of another primitive onto this one, leaving that one empty.
  Part 11's close paths need it.

Required at the public surface, because application code needs it:

- **Add from a Slot**, on whichever primitive the application can reach. Part 9.
  This is not a convenience. Part 12.5's put hook fills the extra list from a
  Slot it just created, and that hook is application code; without a
  Slot-shaped insert the hook writes `take()` by hand and loses rule 1's
  compile-time ally at the one surface the toolkit hands to the application.
  A primitive the application cannot reach does not need one.

Provided if the port has a use for it:

- Walk it. Part 8.4.
- Look at the front, or at the back, without removing.
- Remove a named item from the middle; insert after or before a named item.
  **Both containers of Part 11 can be built without these**, and a port that
  builds them without also drops the backward link of Part 4.2.

No operation can fail. There is no error to report.

- *ztk*: sixteen operations on one list. `polynode.zig:379-603`, `audit 1.5`.
- *3tk*: eleven across two primitives — seven on the queue, four on the stack.
  Twelve of ztk's sixteen leave the port. The four middle-removal and
  named-insert operations went with the anchor of Part 11.3; the front-and-back
  lookers had no caller.

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

## 8.6 The double check on insert — DELETED in 003

**This Part is a tombstone. The number is kept because it is cited by hand; the
rule is gone.** Assumption A1.

002 required two checks on every insert — an O(n) walk of this list, and a link
test — on the ground that neither alone was enough: the walk saw a list of
exactly one member that the link test could not, and the link test saw a
*different* list that the walk could not.

**The first half of that argument was a consequence of Part 8.7's blind spot,
and 003 closes the blind spot.** Once the link test is exact it refuses an item
on *any* primitive, this one or another, so the walk catches nothing it misses.
One O(1) check replaces two, and the O(n) insert is gone from every build mode.

A port whose link test is not exact still needs the walk. It writes it under
Part 8.7, where the blind spot is now named as the thing to pay for, and not
here.

*3tk*: one guard per insert, `queue.c3:79-83`, `stack.c3:66-70`.

## 8.7 The link test — MUST

**The link test answers one question: is this item on some ordering primitive?
It MUST be exact.**

- Exact means it is true for every item on any primitive, including an item
  that is alone on one, and false for every item on none.
- It does not say *which* primitive, and it does not need to. Part 4.4 gives an
  item one inner, so being on one is being on at most one.
- Every insert refuses an item the test reports linked. Every removal clears
  the item, so the test reports it unlinked. Part 8.8.
- It is O(1).

**How exactness is paid for is the port's call, and there are three known
prices.**

- **A terminator.** The last item of a chain points at itself instead of at
  nothing, so *linked* is *the link is not nothing* and it costs no field.
  The price is that the link carries two meanings, and every walk must end on
  *the item points at itself* rather than on nothing. A walk that forgets loops
  for ever.
  *3tk*: `inner.c3:155`, and four walk sites each state the end test.
- **A membership field.** One field per item, and the test reads it. Costs a
  field on every item in the program, including the items that never move.
  Part 4.2's test applies.
- **Neither.** A test on the neighbour fields alone is *not* exact — an item
  alone on a list has no neighbours and reports unlinked. A port that stops
  here has a blind spot, and it MUST then carry the O(n) walk that 002's Part
  8.6 required, because that walk is what covers the hole.
  *ztk*: this one. `audit 2.2`, `polynode.zig:104-116`.

**002 stated the blind spot as inherent and priced closing it at a field per
item.** Both halves were wrong: the blind spot is a property of one realization,
and the terminator closes it for free. What 002's own last bullet called
*strictly better* is now the rule, and the realization that does not reach it
pays the walk instead.

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

## 11.2 The parts both containers have — SHOULD

Each of the two carries these five, whatever it calls them.

- The inner of Part 4.
- A mutex.
- A condition variable.
- A closed flag.
- An allocator, kept for life. Part 13.

**This is a statement about what each contains, not a shared type.** A port may
factor them into one internal base and embed it twice; a port may repeat the
five members in both structs. Neither is more conformant, and the base — where
one exists — is not public and is not a type the application names.

*002 said "one internal base", and that is a mechanism.* A port that reads it as
the rule and factors a base out will find Part 4.4 in its way: the base carries
the inner, so a container embedding a base embeds one inner, and any second
embedding of the base breaks the one-inner rule. The requirement was always the
five parts.

- *ztk*: the members appear in both objects.
- *3tk*: the five are repeated in both structs, with Part 4.4 as the written
  reason. `mailbox.c3:38-72`, `pool.c3:138-156`.

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

**Those three are the promise, and they are the whole of the MUST.** Invariant
22. Every insert is O(1).

**The mechanism is the port's**, and 002 named only one of the two:

- *ztk*: one queue, with an anchor kept at the last out-of-band item so that an
  out-of-band insert stays O(1) — an empty anchor means insert at the front —
  and the anchor cleared when the last out-of-band item is taken. Four sites
  keep it honest. `audit 2.15`.
- *3tk*: two queues, out-of-band and ordinary, drained in that order. The
  ordering falls out of the structure instead of being maintained by hand, and
  the anchor, the front-insert and the insert-after-a-named-item are all gone
  with it. `mailbox.c3:66-67`, `:148-165`.

A port that keeps one queue writes the anchor. A port that keeps two does not,
and Part 11.4 already permitted the second queue as *one level with a cleaner
home*. **The ordering promise is identical either way, and a port that weakens
it has changed the design.**

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

**A closed mailbox is empty.** Close is the only drain, it takes the whole
queue in one step, and a send is refused after the closed flag is set — both
under the same mutex, Part 15.3. So no item can be in a closed mailbox, and no
acquisition ever has to choose between returning an item and reporting closed.
Invariant 34.

That is why Part 19.1 needs no precedence rule. A port that reads the outcome
table as a choice — item, or closed, when both seem to apply — has invented a
state this design does not have.

*ztk*: `audit 2.6`.

## 11.7 The pool — MUST

A keeper of reusable items, grouped by type identity.

- **One give-back container per identity.** A stack, a queue, or anything with
  O(1) insert and O(1) removal; Part 11.10 already refuses to promise which
  item comes back, so the choice is free and it is a port's to make on its own
  grounds.
  - *ztk*: a list per identity.
  - *3tk*: a stack per identity, chosen for defect surfacing rather than for
    speed — the item just given back is on top, so the next get hands it
    straight to a new owner and a caller still writing through a stale pointer
    collides at once instead of much later. `pool.c3:125-129`. **The property is
    only useful because Part 11.10 entitles no caller to it.**
- One count per identity, if the container's length is not O(1).
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
- **close** — take everything down through the hook.

**002 also listed a list put — give many back — and 003 deletes it.** It was the
one operation whose failure mode had no clean answer: a mid-batch refusal had to
restore the caller's list, could not restore its order, and 002 had to warn
about that in Part 11.8. A caller that wants to give many back calls put in a
loop and reads the Slot each time, which is Part 9.4 doing its ordinary work.
Part 12.5's extra list is not this operation and is unaffected: it flows from
the hook to the pool, not from the caller.

*3tk*: no `put_all`; the two tests that used one were converted to a loop.

## 11.8 The give-back rule, pool side — MUST

The mirror image of Part 11.6, and the sharpest asymmetry in the toolkit.

- A pool's close collects everything and passes it to the hook. Nothing comes
  back to the caller.
- A closed pool refuses a put and leaves the Slot unchanged, so the caller
  still has the item.
- **A put that discovers the pool closed while its hook ran gives what it is
  holding to the close hook, not to the caller.** Part 12.3.

**A closed pool is empty**, for the same reason and by the same mechanism: the
close collects every bucket in one step under the mutex, and a put after the
flag is set is refused. The items go to the hook rather than to the caller, and
that is the only difference from Part 11.6. Invariant 34.

*002 also stated how a list put behaved on a mid-batch refusal, and warned that
the restored order might differ from the original.* Part 11.7 deleted the
operation, so both clauses go with it.

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

## 11.12 Closed and quiet before release — MUST

**Four words, and every port uses them.** A container is **open** until close.
It is **closed** once close has returned. It is **quiet** once it is closed
*and* no call the application made on it is still running. Release makes it
**freed**. Closed is a state of the container. Quiet is that state and an empty
set of in-flight calls together, and the two are not the same moment.

- Releasing an open mailbox is a defect. Releasing an open pool is a defect.
- **Releasing a closed container that is not yet quiet is a defect too.**
  Close ends no call that is already running. A waiting receive, a put that is
  inside its hook, a close that is inside its own close hook — each is still
  using the container's mutex, its condition variable and its memory, and
  release destroys all three.
- Both stop the program. In every build mode. Not an assert that compiles out.
- This is the one precondition the toolkit refuses to soften.

### What the port owes, and it is two different things

- **Every port states the precondition.** It is an obligation on the *caller*:
  close, wait for your own calls to return, then release. A port states it
  whether or not it can detect a caller who ignores it.
- **A port checks it where the language and the design make a check cheap.** A
  port that does not check says so, in its own documentation, so the silence is
  not read as a promise.
- **It is a check and not a wait.** A release that waited would block on
  application code the toolkit does not control, and Part 12.3 forbids holding
  the mutex across that code in the first place. What a check catches, it
  catches on the schedule it happens to see.

### Unchanged from 004

- Closedness is a precondition **here and nowhere else**. Every other call on
  a closed object reports closed, or is a no-op, and the object stays a valid
  item.
- Close is callable more than once. The second call takes nothing, and does
  not run the pool's close hook again.
- The test-and-set of the closed flag is inside the mutex, so a preempted
  closer cannot race a release.

*ztk*: `audit 2.5`. ztk states and enforces the closed half. It keeps no count
of calls in flight and does not detect the quiet half.

*3tk*: a count of accepted calls, raised and lowered under the container's own
mutex, read under that mutex by release. The count covers the *hook*, not the
function body: a call that leaves the mutex to run application code stays
counted until that code has returned.

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
- The hook may also fill an **extra container** the pool hands it. Each item in
  it is added the same way, with the same checks. This is how a composite item
  gives its parts back. Part 12.5.
- **The port names which container it is**, and it is one of the primitives of
  Part 8, not a general list. The hook is application code, so this type is on
  the public surface and Part 8.2's Slot-shaped insert is required on it.
  - *3tk*: a queue. `t_pool.c3:70` fills it from a Slot.
- The pool does not check that the parts form a real composite, and does not
  tell composite from simple.

**on close.** The pool is going down.

- Called with the full contents of what remained, as a container of the same
  kind Part 12.5 names.
- The hook is responsible for processing or releasing every item.
- Called **outside** the mutex, after the closed flag is already set.
- **Called once by close — and once more for each put that discovers the pool
  closed while its own hook was running.** Part 12.3 states when that happens
  and why there is nowhere else for those items to go. **A hook MUST therefore
  tolerate a later call and MUST NOT destroy its own state on the first one.**
  It is the same contract either way: process or release every item handed to
  it.

*002 said "called once", and that was true only because 002 had not noticed the
window Part 12.3 opens.* The clause is weakened deliberately, and it is the only
place 003 weakens a MUST: two calls to a cleanup hook is a smaller cost than
items with no holder.

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

**What the pool does when a hook returns — MUST.** This is the rule that follows
from unlocking across the hook, and 002 did not state it. Every port has the
same window, because every port obeys the first bullet above.

1. **After a hook returns, the pool re-reads the closed flag under the mutex**,
   before it does anything with what the hook produced. A close can run to
   completion inside the window: it sets the flag, drains every container, and
   calls the close hook, all while the pool is unlocked.
2. **If the flag is set, everything that call is holding goes to the close
   hook** — the item the hook kept and every item it added to the extra
   container of Part 12.5.
3. Nothing lands in a container after the flag is set, so **invariant 34
   holds**. Nothing goes back to the caller, so **Part 11.8 holds** and the
   caller's Slot stays cleared: the pool did take the item.

**Handing the items back to the caller instead is not available**, and the
reason is structural rather than a preference. The caller has one Slot and it
was emptied when the pool took the item; the extra container's items were never
the caller's at all, so there is no channel to return them through and they
leak. That is why Part 12.2's *called once* is the clause that gives way.

*3tk*: `pool.c3:445-480`, and `t_concurrency.c3` holds the window open
deterministically and fails on invariant 34 without the re-read.

## 12.4 The count is a hint — MUST

- The in-pool count passed to a hook is read under the lock and used without
  it.
- It is a hint. It is stale by the time the hook reads it.
- On get, it is the count *after* removal. On put, the count *before*
  addition.

## 12.5 The extra container on put — SHOULD

- It is the composite mechanism.
- Removing it means a composite item has no way to give its parts back in one
  call.
- **It is a Part 8 primitive named by the port**, and it is the one place a
  Part 8 primitive crosses the public surface into application code. Part 8.2's
  *add from a Slot* is required on it for that reason, and Part 12.3's rule
  covers what happens to its contents if the pool closed while the hook ran.
- It is not the deleted list put of Part 11.7. That one flowed from the caller
  to the pool; this one flows from the hook to the pool.

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
  full Slot. Inserting a linked item. Releasing an open or busy container.
  - It asserts, or it stops the program.
  - It may be compiled out where the language distinguishes build modes.
- A **runtime condition** is a legitimate state of a correct program. Closed.
  Timeout. Nothing available.
  - It is reported as an outcome, always, in every build mode.
- Releasing a container that is not closed and quiet is the one contract
  violation that never compiles out. Part 11.12.

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

**Row numbers do not move**, for the reason Part 0's reading notes give: a
retired row stays in place saying it was retired, and a replacement takes a new
number. Row 16 was retired in 003 and 16b replaces it; row 13 was strengthened;
row 35 is new. The count is not a target — assumption A1.

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
| 13 | The ordering primitives are heterogeneous, O(1) on insert and removal, and allocation-free. | 8.1 |
| 14 | They speak in type-erased handles. | 8.3 |
| 15 | Their layer is where the checks live. | 8.5 |
| 16 | *Retired in 003. Was: the link test is not a membership test.* | 8.7 |
| 16b | The link test is exact: linked is true for every item on a primitive and false for every item on none. | 8.7 |
| 17 | A removed item's links are cleared. | 8.8 |
| 18 | The six Slot rules. | 9.2 |
| 19 | The Slot, not the outcome, says where the item went. | 9.4 |
| 20 | An item is in exactly one place at all times. | 9.6 |
| 21 | The two containers are themselves items. | 11.1 |
| 22 | Out-of-band items are ahead of ordinary ones, FIFO within each. | 11.3 |
| 23 | Every item the mailbox keeps goes back to a caller. | 11.6 |
| 24 | The pool's close gives nothing back to the caller. | 11.8 |
| 25 | The waiting get never creates. | 11.9 |
| 26 | Closed and quiet before release. Unconditional. | 11.12 |
| 27 | Hooks are a parameter of creation. | 12.1 |
| 28 | Hooks run outside the mutex, in parallel, and do not call back. | 12.3 |
| 29 | The in-pool count is a hint. | 12.4 |
| 30 | One holder at a time. A transfer is a move. | 14.1 |
| 31 | The transfer orders memory. | 14.2 |
| 32 | One mutex per container, covering its own state only. | 15.1 |
| 33 | No lock is held across a call into application code. | 15.2 |
| 34 | A closed container is empty. Close is the only drain. | 11.6, 11.8 |
| 35 | After a hook returns, the pool re-reads the closed flag; what a closed pool's put is holding goes to the close hook. | 12.3 |

---

# Part 19 — The outcome sets

The outcomes of every operation, as values. A port picks its own mechanism:
errors, a status value, an optional, a union.

Two rows carry a conditional outcome, marked in place: *interrupted* exists only
where Part 2.9 is realized, and Part 2.9 is a SHOULD a port may drop with the
reason its own last bullet permits. A port that drops it drops the outcome, and
the timeout outcome stays. Part 16 row 12 already marked the excluded half of
this the same way; 003 marks the included half.

These are sets, not orderings. Where a row lists both an item and *closed*, the
two do not compete: invariant 34 makes a closed container empty, so the
acquiring operations below reach *closed* only on an empty container. No
precedence rule is needed and none is given.

## 19.1 Mailbox

| operation | outcomes |
|---|---|
| send | done; closed, Slot unchanged |
| send out-of-band | done; closed, Slot unchanged |
| receive | item; closed; timeout; woken; **interrupted, only on a port that models interruption** |
| poll | item; empty; closed |
| receive the batch | a list, possibly empty; closed |
| close | a list, possibly empty. Cannot fail. |
| wake every waiter | done; closed |

## 19.2 Pool

| operation | outcomes |
|---|---|
| get | item; closed; not-available; not-created |
| get with waiting | item; closed; timeout; **interrupted, only on a port that models interruption** |
| put | nothing. Read the Slot: cleared means kept, unchanged means refused. |
| close | nothing. Cannot fail. |

The *put a list* row of 002 is gone with the operation. Part 11.7.

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
4. **How is the link test made exact?** A terminator costs no field and gives
   the link two meanings, so every walk must carry the end test. A membership
   field costs a field on every item in the program and keeps the meanings
   apart. Part 8.7 prices both, and a port that reaches neither carries the
   O(n) walk instead. *002 asked whether the blind spot was acceptable; 003
   closes it, so the question is how, not whether.*
5. **Both a blocking receive and a poll?** A receive with a zero timeout has
   the same reach. The two differ only in how the empty case is reported.
6. **Out-of-band, or a second channel?** Part 11.4.
7. **Errors, a status value, or an optional?** The outcome set is fixed. Part
   19.
8. **Is interruption modelled at all?** Part 2.9.
9. **Is the pre-lock fast path kept?** Part 15.4.
10. **Which ordering primitives does the port build?** One general list serving
    both containers, or one narrow primitive per container. The narrow route
    drops the backward link of Part 4.2 and most of Part 8.2's optional half;
    the general route is one body of code. Parts 8.1 and 8.2. *002 asked
    instead where the O(n) insert check lived on a port with no build modes.
    Part 8.6 is deleted and there is no such check to place, so the decision
    died and this one takes its number.*

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
  production. The checks in question are Part 8.5's, and the exact link test of
  Part 8.7 is O(1), so a port with no build modes carries it everywhere at a
  price it can afford. A port that did not reach an exact link test carries the
  O(n) walk instead, and that is the one this question is sharp for.

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
5. The ordering primitives, with the exact link test. Part 8.
6. The mailbox. Part 11.3 to 11.6.
7. The pool, with its hooks. Parts 11.7 to 11.10 and 12. **Read Part 12.3's
   what-the-pool-does-when-a-hook-returns before writing put**, not after: the
   window is easy to write wrong and it strands items rather than crashing.
8. Delete nothing from Part 16. It was never written.

Steps 2 to 5 are the toolkit. Steps 6 and 7 are built on it, with no
privileged access.

---

## Change log

| Version | Date | Description |
|---|---|---|
| 001 | 2026-08-23 | First version. Stage 3TK-2. |
| 002 | 2026-08-23 | Three corrections, all found by the C3 port. Part 4.2 separates two conceptual parts from three fields. Parts 11.6 and 11.8 state that a closed container is empty, and Part 19's preamble stops the outcome tables being read as a precedence question. Part 18 gains invariant 34. No rule changed; three were imprecise. |
| 003 | 2026-08-24 | **Eighteen changes, from the C3 port's deviation audit.** The theme is one mistake made repeatedly: 002 was written from ztk, and in fourteen places it wrote ztk's *mechanism* where the design has only a *promise*. Every such Part now states the promise and shows both realizations. One new rule, one deleted operation, one deleted Part, one weakened MUST. |
| 004 | 2026-08-24 | **One change, and it is the fifteenth of 003's own theme.** Part 7.1 stated ztk's mechanism — *a helper bound to that one type* — where the design has only a promise. It now states the promise and shows both realizations, as the other fourteen already did. Stage 3TK-17, from `3tk-deviations-001.md` V19. No conformance marking changed, no Part renumbered, no other Part touched. |
| 005 | 2026-08-28 | **One rule strengthened, and it is the first since 003 that adds a requirement rather than correcting a wording.** Part 11.12 required a container to be **closed** before release; it now requires **closed and quiet** — closed, and with no call the application made still running. The obligation is split: every port *states* the precondition, and a port *checks* it where a check is cheap. It is a check and never a wait. Parts 15.5 and 18 row 26 re-worded to match. Stage 3TK-52, from the C3 port's lifetime fix. No Part renumbered, no conformance marking changed. |

### What a reader of 004 would have got wrong

One rule, and it is the only one 005 touches.

| # | Part | What 001 to 004 said | What 005 says |
|---|---|---|---|
| Q5 | 11.12 | *Releasing an open mailbox is a defect. Releasing an open pool is a defect.* **Closed** is the whole precondition | **Closed and quiet.** A closed container with a call still in flight may not be released either. Four named states — open, closed, quiet, freed. Every port states the precondition; a port checks it where a check is cheap and says so when it does not. **A check, never a wait** |

**Why it survived four versions.** Every clause of 004 was true. The gap was
what it did not say: close ends no call that is already running, and nothing in
the document said the caller had to wait for its own calls before releasing. A
caller who read 11.12, closed, and released had obeyed the specification and
could still destroy a mutex a waiting receive was about to touch. **An omission,
not an error**, which is why an audit did not find it and building did.

**The pool is where it bites, and Part 12.3 is why.** 12.3's MUST forbids
holding the mutex across a call into application code, so a pool's put unlocks,
runs the hook, and relocks. That relock is a use of the container after the
application had a window to release it. The mailbox has no hook and so no
window of its own, but the same exposure through any waiting call.

**Why the obligation is split.** Requiring every port to *detect* this would
have made a finished, green port non-conforming for a behaviour it was never
asked for: ztk keeps no count of calls in flight and closed at 195/195 on
2026-08-14. Requiring every port to *state* it costs a sentence and gives the
next port the rule at its founding. **The ruling behind the split is the C3
port's owner's, 2026-08-28**: *release while a call is in flight is not
prevented; it is written down as a thing the caller must not do, and it is
checked; it is not waited for.*

**What this does not change.** No conformance marking moved. Part 12.2's close
hook, Part 12.3's no-lock-across-application-code, Part 15.1's mutex rules and
Part 19's outcome tables are untouched — release reports no outcome and never
did. **Part 11.12 was already the one precondition that never compiles out**,
and it still is; 005 widens what it covers, not how hard it bites.

### What 005 was written on

**One ruling, given 2026-08-28 by the owner of the C3 line**, and it is recorded
here because it governs more than one version:

> **A port may run ahead of this document**, writing a rule into its own code
> and its own reference while the shared clause is still open, **as long as it
> writes down which way it assumed the question would go.** The shared text
> catches up in a later stage.

**That is how 005 came after the code it describes.** The C3 port built the
quiet check in two stages on 2026-08-28 and recorded the assumption; this
version ratifies it.

**With one boundary, and it is dtk.** A port that already exists has its own
reference to record an assumption in and a maintainer who knows it. **dtk builds
from this file alone**, so anything this file has not caught up on does not
reach it. **The shared text is current before dtk's first stage** — the same
deadline, for the same reason, as the `Item`/`Outer` wording the C3 port carries.

### What a reader of 003 would have got wrong

One row. **V-numbers are
[3tk-deviations-001.md](../c3/3tk-deviations-001.md)'s.**

| # | Part | What 002 and 003 said | What 004 says |
|---|---|---|---|
| V19 | 7.1 | *For each outer type there is a helper bound to that one type. The helper is generated at compile time from the type* — and *the shape is fixed* | For each outer type the members of Part 7.2 exist, specialized to that type, generated rather than hand-written. **A named per-type object is one spelling of that, not the rule.** Both realizations shown: ztk's per-type structure, 3tk's macros over a type parameter with no per-type object at all |

**Why it survived 003.** 003's theme was exactly this mistake — 002 was written
from ztk and stated Zig's mechanism as the rule in fourteen places, all
fourteen corrected. **Part 7.1 was the fifteenth and 003 walked past it.** The
sentence reads like a requirement, and nothing exposed it as a mechanism until
a port answered *generate code per type* a different way. **This is the first
specification defect found since 003, and it was found by building, not by
auditing.**

Of Part 7.1's three clauses, two were already true of a call-site-expansion
port: the generation is at compile time and from the type, and the identity and
the crossings arrive together. Only *bound to that one type* failed — and Part
7.1's own closing sentence already set the floor lower, conceding that a port
with no generation at all writes the block by hand and *loses only the typing*.
A port that generates but names no object sits above that floor on the thing
the sentence says matters.

**Parts 7.2, 7.3, 7.4 and 7.5 are untouched.** 7.2's nine members are a MUST
and both realizations carry all nine; the validation and the border are
unaffected by where the generated code lives.

**What this cost, and it is worth stating.** A whole version for one Part. The
alternative was to leave the trap set for the next port: D's idiomatic answer
to *generate code per type* is templates and mixins — call-site expansion, the
same shape as a C3 macro, not a per-type struct — and dtk had not started when
this was cut. Fixing it afterwards means a second port re-deriving the same
argument from cold. No other specification change was pending at the cut: V1 to
V18 are consumed by 003, and V7b was recorded-not-fixed deliberately.

### What a reader of 002 would have got wrong

Every difference, so nobody has to diff the two files. **V-numbers are
[3tk-deviations-001.md](../c3/3tk-deviations-001.md)'s.**

| # | Part | What 002 said | What 003 says |
|---|---|---|---|
| V1 | 4.2 | The linkage is *two fields, a previous and a next* | The linkage is whatever threads an item onto one primitive and answers Part 8.7. Two fields or one; both realizations shown |
| V2 | 8.1 | *A doubly-linked list*, singular | *Ordering primitives*, as many as Part 11 needs. One general list or two narrow ones |
| V3 | 8.2 | Sixteen operations, flat | Split into required, required-at-the-public-surface, and provided-if-useful. Twelve of the sixteen are optional; the Slot-shaped insert is promoted, with Part 12.5 as the reason |
| V4 | 8.6 | Every insert checks twice, one of them an O(n) walk | **Deleted, tombstoned in place.** An exact link test makes the walk catch nothing. A port without one carries the walk under 8.7 |
| V5 | 8.7 | The link test is not a membership test, and the blind spot is inherent | **The link test MUST be exact.** Three prices named: a terminator, a field, or the O(n) walk |
| V6 | 11.2 | *One internal base* | The five parts each container has. A shared base is one mechanism, and Part 4.4 is why a port may refuse it |
| V7 | 11.3 | The three ordering guarantees, plus an anchor at the last out-of-band item | The three guarantees are the MUST. The anchor is ztk's mechanism; two queues are 3tk's. Invariant 22 unchanged |
| V8 | 11.7 | *One free list per identity*; **put a list** among the operations | One give-back container per identity, kind free. **Put a list deleted** — its mid-batch failure mode had no clean answer |
| V9 | 11.8 | The list-put refusal rule and the restored-order warning | Both gone with the operation. Gains the late-close clause |
| V10 | 12.2, 12.5 | The hook returns an extra **list** | An extra **container**, a Part 8 primitive the port names. It is the one place a primitive crosses into application code |
| V11 | 12.3 | *Silence* | **New MUST.** After a hook returns the pool re-reads the closed flag, and what a closed pool's put is holding goes to the close hook. Invariant 35 |
| — | 12.2 | The close hook is *called once* | **Called once by close, and once more per straggling put.** A hook must not destroy its own state on the first call. **The only MUST 003 weakens**, and V11 is why |
| V12 | 18 | Rows 13 to 16 as written | Row 13 covers the primitives, row 16 retired, row 16b is the exact link test, row 35 is new. **Rows do not renumber** |
| V13 | 19.1, 19.2 | *interrupted* listed unconditionally | Marked conditional on Part 2.9, which is a SHOULD a port may drop |
| V14 | 19.2 | A **put a list** row | Gone with the operation |
| V15 | 20 | Decision 4 asks whether the blind spot is acceptable; decision 10 asks where the O(n) check lives | Decision 4 asks *how* the test is made exact. Decision 10 died with Part 8.6 and its number now asks which primitives the port builds |
| V16 | 21 Q11 | Points at Part 8.6 | Keeps its force, loses the dangling pointer, and names the O(n) walk as the case it is sharp for |
| V17 | 22 | Step 5 is *the list, with both insert checks* | *The ordering primitives, with the exact link test.* Step 7 gains a warning to read 12.3 before writing put |
| V18 | 6.5 | Reads as an element the toolkit ships | Says plainly it is a pattern the application writes, so a port that ships nothing has skipped nothing |

### The five assumptions this version was written on

The owner was asked before the cut and answered *take all recommendations,
record them as assumptions*. **These are defaults, not rulings.** A later reader
may overturn any of them without contradicting anyone.

| # | Assumption | Cost to overturn |
|---|---|---|
| A1 | **Parts and invariant rows do not renumber.** A deletion becomes a tombstone in place — Part 8.6, invariant row 16 | Cheap now, expensive once anything cites 003 |
| A2 | **The *ztk* lines stay, and *3tk* lines are added beside them where the two differ** | 003 is longer. Overturning deletes lines rather than writing them |
| A3 | **Part 19.3 is untouched.** The C3 port returns *not-available* from every get mode on an identity the pool was not created with; 19.3's MUST says it comes only from the available-only mode. **That is the port's defect and the port fixes it**, with a distinct outcome. It is a code change and this stage made none | The alternative is weakening 19.3's *only* to a checking-build promise. **This one leaves work behind: it is not yet done in `../c3/3tk/`** |
| A4 | **Part 6.5's dispatch table is the application's**, said in one sentence — V18 | One sentence either way |
| A5 | **Filing.** 002 goes to `backup/`; **the C3 port's doc comments are NOT repointed** from 002 to 003; one line goes into `../d/dtk-status.md` | **A known debt, stated here so it is not a surprise: `../c3/3tk/src/` cites 002 in roughly forty doc comments and will until a later stage repoints them.** Forty comment edits would have buried a document stage |

### What did not change, and deliberately

- **No conformance marking was changed.** A MUST that becomes a SHOULD is a
  decision, not a stage's judgment. The one clause that was weakened — Part
  12.2's *called once* — was weakened in its wording, under a ruling, and it is
  named twice above so nobody finds it by accident.
- **Part 11.7 still promises nothing about the pool's order**, and Part 11.10
  still says so. 003 names the container kind and stops. The C3 port's
  defect-surfacing argument for a stack works only while no caller is entitled
  to the order.
- **Part 2.6 is untouched.** The C3 port fails it — its pool's leaver signals on
  one bucket over a shared condition variable — and the rule is right as
  written. Moving a rule to accommodate a port's defect is how a specification
  stops being one.
- **Parts 0, 1, 2, 3, 5, 7, 9, 10, 13, 14, 15, 16, 17, 19.3 and 19.4 are
  unchanged.** Six further findings of the audit — its P1 to P6 — are ports
  failing rules that already said the right thing, and none of them reached
  this file. V11 is the single exception, and it is here because the rule
  genuinely did not exist.
