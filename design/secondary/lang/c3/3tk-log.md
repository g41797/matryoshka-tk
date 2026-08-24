# 3tk — log

Narrative of the 3tk line of work. Append-only, newest first.

Not read by default. Read it for history: what was decided, when, and why.  
Current state is in [3tk-status.md](3tk-status.md).

---

## 2026-08-24 — 3TK-18: the field is called `link`

**`Inner.next` is `Inner.link`.** Two words before, two words after. Four builds
green at **63 checks**, **87 tests**, unchanged in every mode; sanitizers thread
and address clean at 87. No new document — the ruling in
[3tk-any-options-001.md](3tk-any-options-001.md) was already written, and the
diff says the rest.

**The permitted citation was taken.** `inner.c3:5` now names
[`../common/matryoshka-specification-004.md`](../common/matryoshka-specification-004.md).
**3TK-19 has two debts of the first kind left, not three** — `mtk.c3:48` and
`helper.c3:51`, and `helper.c3:51` is still the one that matters.

**What the sweep taught, and it is why the row exists:**

- **The measurement was high.** The plan said 59 mentions, 35 of them field
  accesses, 18 of those in `queue.c3` and `stack.c3`. Counted after the fact:
  **23 field accesses** — 2 in `inner.c3`, 12 in `queue.c3` and `stack.c3`, 9 in
  the tests and `helper.c3` — out of 53 mentions of the word. The trap the plan
  named was real and the arithmetic naming it was not. **Nothing followed from
  the gap** except that a stage sized for 35 sites did 23.
- **`run-builds.sh` held a field access, and it is not one of the fourteen
  files.** Line 199 greps `src/mailbox.c3` and `src/pool.c3` for
  `\.next[[:space:]]*=` to enforce Part 17.2 — *no container reaches around the
  InnerQueue/InnerStack surface*. A rename that swept only `.c3` files would
  have left that check hunting a field that no longer exists, **and it would
  have gone on printing `ok` for ever.** Repointed to `.link`, and the line now
  says which name it used to carry.
- **`unlink` does not exist.** The plan promised the sentence to `is_linked` and
  `unlink`; the repair of Part 8.8 is named `reset`. Both got it —
  `h.link != null` reads in `is_linked`, and `reset` clears the link.
- **The iterator keeps its name.** `InnerQueueIterator.next()` is Part 8.4's
  walker and has nothing to do with the field. The stage renames one field and
  may not touch the surface, so **verification 4's literal claim — zero `.next`
  anywhere — is not reachable and was not attempted.** What is true is the
  claim it was written for: **zero `.next` field accesses in `src/`, `test/`,
  `negative/` and the scripts.**
- **One comment described the design that is gone.**
  `negative/insert_twice_same_queue.c3:6` explains the old Part 8.6 pair with
  `prev == null && next == null` — two fields, neither of them current. A blind
  rename there would have made the retired design read as though it had a
  `link`. Reworded to name no field at all. The same file's *next* paragraph is
  about the design that is here, and it says `link == this`.

**The four walk sites, each read against its own body:**
`InnerQueueIterator.next` — comment `n.link == n`, code `n.link == n`.
`InnerQueue.pop_front` — comment says the sole item is recognised by
`head == tail` and not by a null link, code tests `self.head == self.tail`.
`InnerQueue.append_queue` — comment says `other.tail` is already self-linked and
needs no repair, code joins and does none. `InnerStack.pop` — the file header
says the sole item is recognised by `h.link == h`, code tests `h.link == h`.

**`inner.c3` was rewritten by hand and read in full before the mechanical pass
ran** — the folder's rule, and the one 3TK-11 paid for. Three mentions of
`next` survive in it, all three in the paragraph that argues for the new name:
the price of R6b is that the link carries two meanings, and `link` is the name
that does not assert the wrong one. **No paragraph apologises for a name the
file no longer uses.**

**No `any`, in any shape. No layout change, no behaviour change, no edit to
`../common/`.** R6b, the exact link test and Part 8.6's deletion are untouched.

---

## 2026-08-24 — plan 010: the `any` ruling gets a stage, and so do the three debts

**Written: [3tk-staging-plan-010.md](3tk-staging-plan-010.md).** 009 moved to
`backup/`, and every link that named it was repointed — the status file, this
file's own 009 row, and specification 004's provenance line in `../common/`.
**Provenance keeps the name 009; only the link target moved.**

**009 was spent.** 3TK-0 to 3TK-17 had all run, `3tk/` was green at 63 checks
and four builds, and nothing in the line was declared and unstarted. Two things
were owed with no stage to run under, and 010 is exactly those two.

**3TK-18 — `Inner.next` becomes `Inner.link`.** The owner ruled `any` within
`Inner` on 2026-08-24: **rejected in all three shapes, the rename accepted.**
[3tk-any-options-001.md](3tk-any-options-001.md) carries the ruling and is the
stage's specification. The stage is the same shape as 3TK-11 and 3TK-16 — a
ruled document, built — and it re-argues nothing. **The plan names the trap
rather than leaving it to be discovered:** `queue.c3` and `stack.c3` hold 18 of
the 35 field accesses, the four walk sites each state the end test in their own
body, and `next` is a common English word that appears in prose which is not
about this field. **Rewrite the exemplar first, then sweep** — the rule 3TK-11
paid for. It writes no new document; the ruling is already written.

**3TK-19 — the three debts.** Stale 003 citations in `3tk/src/`, the stale P2
row in the deviations audit, and otk never having been told the specification
exists. **One stage because each alone is too small for a cold start**, and it
runs after 3TK-18, which is permitted to take `inner.c3`'s citation on the way
past since it rewrites that file's prose anyway. **`helper.c3:51` is the one
that matters** — its guard tells the next reader not to "fix" the file to match
Part 7.1, and 004 reworded Part 7.1 so the file now matches. That paragraph is
rewritten, not repointed.

**Nothing in 010 touches `../common/`, and 004 stands as cut.** Part 4.2/V1
already leaves the field count to the realization and 004's *3tk* line already
reads *one link field plus the identity*, so the rename needs no specification
change. **Neither stage blocks dtk**, which was freed by 3TK-17 and starts under
its own plan in `../d/`.

---

## 2026-08-24 — 3TK-17: Part 7.1 states the promise, and 004 is cut for one Part

**Written: [`../common/matryoshka-specification-004.md`](../common/matryoshka-specification-004.md).**
003 is in `../common/backup/`. **The first stage in this line permitted to edit
`../common/`, and it edited one Part.**

**What was wrong.** Part 7.1 said *for each outer type there is a helper bound
to that one type*. That is Zig's per-type comptime struct, written up as though
it were the requirement. Of its three clauses only that one failed under the C3
port: macro expansion is compile-time generation from the type, and the identity
and the crossings still arrive together. **And Part 7.1's own closing sentence
already set the floor lower** — a port with no compile-time generation writes
the block by hand and *loses only the typing*. A port that generates but names
no object sits above that floor on the thing the sentence says matters.

**004 states the promise**: for each outer type the members of Part 7.2 exist,
specialized to that type, generated rather than hand-written, with the identity
and the crossings from the one act of generation. Both realizations are shown,
marked *ztk* and *3tk*, exactly as 003 did for the other fourteen. **A named
per-type object is one spelling of it and not the rule.** One sentence was added
that 003 never needed: *helper* is the document's word for the per-type surface,
whatever a port calls it and wherever the generated code lives — because 7.2,
7.3, 7.4 and 7.5 go on using the noun and none of them was touched.

**This is the fifteenth instance of 003's own theme, and 003 walked past it.**
002 stated ztk's mechanism where the design has a promise in fourteen places and
3TK-13 fixed all fourteen. Part 7.1 reads like a requirement, and nothing
exposed it until a port answered the question a different way. **It is the first
specification defect found since 003, and it was found by building, not by
auditing** — 3TK-16 filed V19 against the Part while obeying neither it nor
fixing it, and this stage is the one that could.

**The deciding argument was dtk, and dtk has been told.**
[`../d/dtk-status.md`](../d/dtk-status.md) gains a paragraph under its normative
inputs: D's idiomatic answer to *generate code per type* is templates and
mixins — call-site expansion, the same shape as the C3 macro, not a per-type
struct — so Part 7.1 as written would have set dtk the identical trap, and a
second port would have re-derived this argument from cold. `d/inputs/README.md`
and `../common/README.md` were repointed too.

**otk was not told, and that is recorded rather than closed.** `../odin/` holds
one backport document, no status file and no reference to the specification.
3TK-13 did not tell it either and said so. The question is still open and this
stage does not close it silently.

**Nothing else was pending, and that was checked before the cut.** V1 to V18 are
consumed by 003; V7b is recorded-not-fixed deliberately; A3's debt was code and
3TK-15 paid it. No second defect was found, and the rule that produced V19 —
*report it, do not fix it* — did not have to fire twice.

**`3tk/` was not touched**, and the paragraph in `src/helper.c3` telling the
next reader not to "fix" the file to match Part 7.1 **is now stale and still
stands**. So do `mtk.c3`'s and `inner.c3`'s citations of 003. Three doc
comments, and this stage may write no code. Named here and in the status file's
open questions.

---

## 2026-08-24 — 3TK-15: two debts paid, and one of them was misfiled

**Written: [3tk-debts-notes-001.md](3tk-debts-notes-001.md).** The last stage
3TK-13 left owing. Both halves were decided before it started and neither was
re-argued.

**A3 — the port broke a MUST in its own specification, and now does not.**
`Pool.get` returned `NOT_AVAILABLE` for an identity the pool was not created
with, from all three modes, where Part 19.3 reserves not-available for the
available-only mode. A `@check` caught it in a checking build and expanded to
nothing under `--safe=no` — D6 — so the fault was the observable behaviour of a
fast build. The port now reports `UNKNOWN_IDENTITY`, a fault of its own,
**deliberately not a Part 19 outcome**: Part 11.7 makes an identity outside the
pool's set a caller defect rather than a runtime condition, which is the
sentence the rest of that faultdef opens with. Part 19.2's sets are untouched.

**`get_wait` changed too, and it did not have to.** Its old fallthrough timed
out, which Part 19.2 allows, so this half is a quality change and the notes mark
it as one. Two reasons: the two gets must not disagree about one mistake, and a
defect that costs the caller a full timeout to discover gets diagnosed as a
performance problem instead of being fixed. One consequence — the early return
made the loop's two `if (b)` guards unreachable, and they are removed rather
than left as a reader's trap.

**The test is a runtime negative and could not have been a test-suite test.**
A checking build aborts on the `@check` before any assertion runs, and
`run-builds.sh` runs the suite in all four builds. The negative shape expects
exactly that: abort where the checks are live, clean run where they are not.
`negative/pool_unknown_identity.c3` asserts all three get modes plus `get_wait`,
because *all three* was the whole of the defect. **It was measured to fail with
the fix removed**, not asserted to. It also found that `@catch_is` belongs to
the test runner and is unreachable from a negative program, which cost the first
draft a compile.

**A5 was filed under the wrong noun, and that is the finding.** 003's own
assumption A5 said the port *cites 002 in roughly forty doc comments*. **There
was one** — `inner.c3:4` — because 3TK-16 had already repointed `mtk.c3` when it
rewrote the header. What the port actually had was roughly ninety `Part N.N`
citations, about sixty of them in Parts 003 changed. The debt was real and the
grep was never going to find it. **The half A5 called *not mechanical* was all
of the work**, and a `sed` would have found one line and declared victory.

**Twelve comments changed a claim rather than a path**, in five files, each one
right about 002 and wrong about 003. Two are worth reading twice. `pool.c3:511`
said Part 12.2's *called once* was *the one clause this bends* — 003 weakened
12.2 for exactly this case and added Part 12.3 as a new MUST, so **the code now
obeys the rule it was written to deviate from**, and the same comment still
promised an answer *until 003 rules the shape*, written before 003 existed and
left standing after it did. `pool.c3:233` cited Part 8.6 in the present tense
for a technique it still uses correctly; the Part is a tombstone and the comment
now says the technique has no Part left to cite.

**One thing left undone and named rather than done.** `3tk-deviations-001.md`'s
P2 row is now stale — it records the defect A3 just fixed, and its section ends
*the audit takes none* of the three answers. The stage's *may not* list does not
forbid the edit, but 3TK-14's forbade it in the general form and **3TK-16 was
granted its two rows explicitly rather than by inference**. A permission granted
to the previous stage is not one this stage assumes. It wants a stage the owner
names, and V19's treatment: additive, in the audit's own vocabulary.

**Green: `run-builds.sh` 63 checks — up from 59, the new negative adds one per
build — `run-sanitizers.sh` 3 checks, 87 tests over four builds.** No occurrence
of `matryoshka-specification-002` remains in `src/`, `test/` or `negative/`.
Part 19.3 read against `pool.c3` clause by clause and reported conforming.

**`../common/` was not touched.** A3's whole point is that the specification is
right and the port was wrong.

**Next: 3TK-17**, the last one, and it is the only stage that may touch
`../common/`.

---

## 2026-08-24 — 3TK-16: the helper surface, in code

**Written: [3tk-helper-notes-001.md](3tk-helper-notes-001.md).** The mirror of
3TK-11 — a ruled proposal, built, with no ruling of its own.

**The four accepted items landed.** H0 and H0b: `mtk::helper` and `mtk::owned`
stop being generic modules and become ordinary ones carrying macros over
`$Type`, plus `to`/`as`/`must`/`move` as methods on `Handle` and `Slot`. H5: the
crossings are `to_handle`, `from_handle`, `must_from_handle`, `is_mine`, and the
word *inner* keeps `Inner`, `inner_offset`, `src/inner.c3` and every line of
prose. H10: `mtk::owned` is `mtk::managed`, `owned.c3` is `managed.c3`,
`t_owned.c3` is `t_managed.c3`, and the fixture `struct Owned` is
`struct Holder`.

**The number that says whether H0 worked is 35 to 0.** Thirty-five `alias`
lines named the helper — twenty in `test/common.c3`, seven in
`negative/common.c3`, eight across `mailbox.c3` and `pool.c3`. **There are none
left, anywhere in `src/`, `test/` or `negative/`.** `test/common.c3` is now four
struct declarations and a doc comment, and a new outer type costs nothing at all
before it can be used.

**Green, and the counts are stated rather than inherited.** `run-builds.sh`: 59
checks, 0 failed, four builds. **87 tests**, up from 85 — the stage added two,
for M12's method surface, which is five new declarations doing address
arithmetic and was exercised by nothing. `run-sanitizers.sh`: 3 checks, thread
and address clean. All three `nocompile_*` negatives still refuse in every
build and their messages still name the type.

**One line of `run-builds.sh` changed**, the `nocompile_managed_no_allocator`
array key, exactly as the proposal measured: the expectation string is
`mtk::helper`, the *alternative* the message names, so the rename left it
untouched.

**Three edits to a finished stage's output, all additive.**
[3tk-deviations-001.md](3tk-deviations-001.md) gains **V19** — Part 7.1 is a
**specification** defect, scope `every port`, and the only verdict this stage
changed, from C to S. Part 7.3's evidence moves from *two generic modules* to
*two modules*. Parts 6.3 and 7.2 are repointed at the names H0 and H5 left.

**The named trap held.** Part 7.1 was wrong while the stage ran and the stage
neither obeyed it nor fixed it. `../common/` is untouched; 3TK-17 rewords it.
`src/helper.c3`'s header now carries a sentence telling the next reader not to
"fix" the file to match a Part this folder has ruled defective — the guard
comes out when 004 is cut.

**Three C3 spellings the proposal's scratch runs did not carry, found again
here**: `$Type::typeid` and not `$Type.typeid`; `$Typeof(x)::typeid` and not
`$typeof(x)::typeid`; and `to_handle(null)` is no longer writable at all,
because the outbound crossing infers its type — it is `to_handle((Msg*)null)`,
which is what the test always meant.

**And 3TK-11's warning earned its keep.** The rename ran on three axes and
`inner` was never renamed — `to_inner`, `from_inner` and `must_from_inner` were
rewritten one shape at a time so that `Inner` and `inner_offset` were
untouchable by construction. **Four stale words survived the mechanical pass and
were caught only by reading**, none of them a compiler error. Prose does not
compile.

**Next: 3TK-15 — the two debts of 3TK-13, A3 and A5.** Then 3TK-17.

---

## 2026-08-24 — plan 009: 3TK-16 and 3TK-17 declared

**Written: [3tk-staging-plan-009.md](backup/3tk-staging-plan-009.md).** 008 moved to
`backup/` and every link naming it was corrected in place, both directions: the
live pointers in `3tk-status.md` name 009; the provenance lines in
`3tk-helper-proposal-001.md` and this log keep naming 008 and now find it at
`backup/`.

**Neither stage is authorized.** Both exist because 3TK-14 ended at a proposal
and the owner ruled all twelve of its items the same day, and nothing carried
those rulings anywhere.

**3TK-16 — the helper surface, in code.** The mirror of 3TK-11: a ruled proposal,
built. It carries the four accepted items that change code — H0 and H0b, the
helper becomes macros; H5, the crossings named for the *handle*; H10,
`mtk::owned` becomes `mtk::managed` and the fixture becomes `struct Holder` —
plus the **V19** row in `3tk-deviations-001.md` and one line of
`run-builds.sh`. **They are one stage and not four because they land in the same
two files**; splitting them means rewriting `helper.c3` and `owned.c3` three more
times.

**Its named trap is unusual and worth recording: Part 7.1 will be wrong while
the stage runs, and the stage must neither obey it nor fix it.** E6 ruled it a
specification defect; 3TK-17 rewords it; 3TK-16 records V19 and leaves
`../common/` alone. **A stage that "conforms" to a Part its own folder has ruled
defective has un-ruled a ruling.**

**3TK-17 — Part 7.1 reworded, and specification 004.** The first stage in this
line permitted to edit `../common/`, scoped to one Part. **V19 is the first
specification defect found since 003 carried V1 to V18 — and it was found by
building, not by auditing.** 003's fourteen came from an audit reading the
specification against the port; this one came from a port answering a question
a way the specification had not imagined. That is a different instrument and it
is worth a paragraph in 004's change log.

**Its cost is named in the stage rather than discovered later: a whole
specification version for one Part**, because the folder's rule is that every
change makes a new file and the specification is on that list. 004 is therefore
the cheap moment to batch any other specification change — and none is known.
V1 to V18 are consumed by 003 and V7b was recorded-not-fixed deliberately. The
stage re-checks that before cutting 004.

**The order is not the numbering, and plan 009 says so three times because it is
the one thing to get wrong:**

```
3TK-16  (code)   →   3TK-15  (the debts)   →   3TK-17  (the specification)
```

**3TK-15 was declared first and runs third.** Plan 008 ordered it after 3TK-14
because A5 repoints doc comments in the files 3TK-14 might rewrite. 3TK-14 ran
and rewrote nothing — it proposed — so that ordering sentence is now satisfied on
its face and **misleading**. Its own *What this stage may not do* already carried
the right clause: *"if 3TK-14's proposal has been ruled and built by then, this
stage runs on top of the result."* **The proposal is ruled and not built.** 009
amends the section with a note above it and leaves the body unaltered, which is
this folder's tombstone-in-place habit.

**3TK-17 has a constraint that points outside this folder: before dtk's first
stage.** dtk has a prepared folder and no stage has run. D's idiomatic answer to
*generate code per type* is templates and mixins — call-site expansion, the same
shape as a C3 macro — so Part 7.1 as written sets dtk the identical trap it set
3tk. Fixing it afterwards means a second port re-deriving this argument cold.

**One stale line was corrected while the plan was open.** The versioning section
read *"this plan — `3tk-staging-plan-NNN.md`, currently 007"* — in 008, and in
007 before it. It now reads 009, and says it was stale in both.

**Nothing is authorized.** Plan approval is not stage approval; that is a
standing rule and it has not moved.

---

## 2026-08-24 — 3TK-14: the helper surface, measured then proposed, then re-measured against the stdlib

**Written: [3tk-helper-proposal-001.md](3tk-helper-proposal-001.md).** A
proposal. **No file under `3tk/` was changed**, and no item is ruled.
`run-builds.sh` 59 checks and `run-sanitizers.sh` 3 checks are green, trivially.

**The stage was written around one property of its input and that property paid
off immediately.** [3tk-helper-alternatives.md](3tk-helper-alternatives.md)
ranks three shapes and then withdraws its own favourite. Measuring first meant
finding out that **both** of its non-fallback shapes are unavailable in C3
0.8.3, not just the one it doubted:

- A generic module cannot declare a method on its type parameter.
  `fn void Type.init(Type* self)` inside `module mtk::helper <Type>` gives
  *`'Type' could not be found, did you spell it right?`* — the receiver name is
  resolved as an ordinary type and a module parameter is not one. The note's
  correction guessed this.
- An instantiated generic module cannot be aliased as a namespace.
  `alias MsgHelper = mtk::helper{Msg};` gives
  *`'mtk::helper' could not be found`*, and so do three other spellings.
  **A generic module is not a value and not a type.** It can be named only
  through one of its declarations — which is the whole reason `test/common.c3`
  carries one alias per operation, and no alias discipline was ever going to fix
  it.

**The shape that survived is not in the note.** A generic module may declare a
*struct*; that struct is generic over the module's parameter; methods hang on it
normally and their bodies see `Type`. One alias to a `const` of it gives an
application the entire surface in one line — `alias MSG = mtk::helper::OF{Msg};`
and then `MSG.init(&m)`, `MSG.to_handle(&m)`, `MSG.from_handle(h)`. It was built
against a scratch copy of the real `src/`, containers included, and sixteen
behavioural assertions ran true in a checked build and under `-O3 --safe=no`.

C3 charged two small tolls and both are recorded: a zero-sized struct is not
permitted, so the helper carries one unused byte in a compile-time constant; and
an alias to a constant must be ALL-CAPS, so the call site is `MSG.init(&m)` and
cannot be `msg.init(&m)`.

**Two of the note's opinions did not survive contact with the port.**

The note says keep `TYPE` private, because `is_mine(h)` is the public form of
the test. True of the crossing, false of the port: **the pool is keyed on the
identity.** `Pool.create(a, typeid[] tags, ...)`, `Pool.get(typeid want, ...)`,
`Pool.count_of(typeid)` are all application API, `OWNED_TYPE` is read at 46 call
sites in `test/`, and two negative tests are built out of `MSG_TYPE` and
`JOB_TYPE`. An application that cannot name its type's identity cannot create a
pool. Part 7.2's first member is a *value*, not a predicate.

The note's `OFF` argument — the one the plan flagged as the item touching
conformance rather than taste — is right in direction and overstated in effect.
**`mtk::inner_offset` is public at `src/inner.c3:238` and application code can
do the arithmetic through it today.** That was compiled; it compiles. And it
cannot be closed, because C3's `@private` is module-scoped and `mtk::helper` is
a submodule — the same property `run-builds.sh`'s layering checks already rely
on. So **Part 7.5's MUST is held by convention, review and the layering checks,
not by visibility, and it always was.** Hiding `OFF` is still proposed, on the
narrower claim that it removes two alias lines and leaves one file naming an
offset, with the limit written into the doc comment.

**One check the stage was told to run came back *conforms*.** The note says
`move_from_slot` should validate before it consumes. It already does —
`helper.c3:122-126` peeks, tests, and only then takes, so Part 9.2 rule 4 holds
on the mismatch path. What is left is smaller: the returned pointer is computed
from `take()`'s result rather than from the handle `peek` saw, an invisible
dependency on `Slot.take`. One extra line removes it.

**And one was decided against the note by Part 15.5.** Splitting
`must_from_handle`'s single `@check` into null and wrong-type buys a message and
costs a branch, and both cases are the same kind of wrong — a contract
violation, compiled out together in a fast build. Rejected, with the reason to
go in the doc comment so it does not come back.

**A number in the plan was wrong and is corrected here.** `test/common.c3`
carries **twenty** alias lines, not seventeen. Under the proposal it carries
eight — and the figure that matters is the slope, not the total: a new outer
type costs one line instead of nine, an owning type two.

**`owned` is answered and D10 is not reopened.** `mtk::owned` takes the same
shape and composes the helper through the instance. Two generic modules stay two
generic modules; `owned` simply stops re-declaring `OFF`, which it already never
read.

**One question is left open and named as one.** Whether `mtk::inner_offset`
should be harder to reach at all is a question about the port's *module
structure* — `mtk::helper` inside `mtk` rather than beside it — and that touches
the Part 17.2 layering checks. The stage did not answer it.

## The second input, and it changed the answer

**Mid-stage the owner said: read `std::collections::interfacelist`,
`std::collections::anylist`, and possibly another sources in std.** That advice
is why this proposal has an H0.

C3's core already carries Part 6.3's two crossings, for its own type-erased
value, and it does **not** generate a helper object per type for them.
`core/builtin.c3:111-134`:

```c3
macro anycast(any v, $Type) { if (v.type != $Type) return TYPE_MISMATCH~; return ($Type*)v.ptr; }
macro any.to(self, $Type)   // the checking crossing
macro any.as(self, $Type)   // the asserting crossing, as a @require contract
```

Read against Part 7.2 it is the same design: a stored `typeid` compared against
a type name — that is `is_mine` — and two crossings named apart, `to` and `as`.
**The type is an argument at the call site. There is no instantiation and no
alias.** `interfacelist.c3:7-29` and `anylist.c3:21` show the other half of the
lesson: the stdlib *does* reach for a generic struct inside a generic module,
with `typedef AnyList = inline InterfaceList {any};` naming one instantiation —
but it reaches for it for a **container**, which has state. **The helper has no
state.** Its `Helper` struct under H1 exists only to hang methods on, carries
one unused byte, and forces an ALL-CAPS alias per type.

So the stage proposes H0: `mtk::helper` becomes an ordinary module of macros
over `$Type`, with `to`, `as`, `must` and `move` as methods on `Handle` and
`Slot`.

```c3
mtk::helper::init(&m);                 // type inferred, no argument
Handle h = mtk::helper::handle_of(&m); // type inferred

Msg* p = h.to(Msg);
Msg* q = h.as(Msg);
Msg* c = s.move(Msg);
```

**No application writes an alias for any type, ever.** Measured against the real
`src/` with the containers in place: zero errors, seventeen behavioural
assertions true including a live mailbox round trip, identical under
`-O3 --safe=no`, and the eight file-local alias lines in `mailbox.c3` and
`pool.c3` deleted rather than repointed. `test/common.c3` goes from twenty alias
lines to none and keeps only its four structs.

**`@require` turned out to be D6's tier 2, natively.** The asserting crossing as
a doc-comment contract aborts in a safe build — naming the violated condition
*and the caller's line*, which `mtk::@check` does not — and compiles out
entirely under `--safe=no`. It also repairs the macro shape's one real weakness:
an untyped boundary. Passing an `int*` to `handle_of` gives
*`@require "$defined($Typeof(*item)::members)" violated: 'handle_of wants a
pointer to a struct that embeds an Inner'`*, at the caller's line, in the port's
own words.

**One measurement in this stage was wrong and is recorded rather than quietly
fixed.** That guard was first written `$Typeof(*item).members`, with a dot. It
compiled, and it rejected *every* type, valid ones included — and because only
the negative case was run, it read exactly like a guard that worked. `::`, not
`.`. Both directions are verified now. A guard that always fires is
indistinguishable from a guard that works until you test the happy path.

**H0's cost is one sentence in the specification and the stage will not spend
it.** Part 7.1 SHOULD says *for each outer type there is a helper bound to that
one type, generated at compile time from the type.* Under H0 there is no
per-type helper object; the code is generated per call site. Every Part 7.2
member is present, every crossing is still in one file, and Part 7.1's own next
line says the shape is fixed and generation is the convenience — but the
sentence stops describing the port. **Accepting H0 means either recording a
deviation or rewording Part 7.1 in `../common/`, and 3TK-14 was allowed to touch
neither.** H0b carries a second, smaller one: today a type declares itself
owning by being instantiated as `mtk::owned{Type}`; under H0b any caller may
call `mtk::owned::create` on any type with an `Allocator` field. Part 7.3
permits *a separate name* as the means, so the rule holds — whether the port
wants the weaker guarantee is a ruling, and D10's *spelling* moves with it.

**H1 to H3 stand as the alternative** if H0 is rejected. They were measured
first, against the same `src/`, and they are the best shape available without
macros.

## Ruled the same day, and one item added

**The owner accepted H0 and H0b.** The helper becomes macros; `mtk::owned`
follows and carries D10's spelling with it. H1 to H3 are withdrawn — they are
kept unedited in the proposal as the record of what the port would have looked
like without macros. H4, H6, H8 and H9 turned out to be settled or forced by H0
rather than separate decisions, and H7 stands as recommended.

**H5 was accepted the same day, and the evidence for it was better than the
proposal's first draft of it.** The stage had argued H5 as a close call against
R1, which had renamed `to_any` → `to_inner` one day earlier. Reading what R1
actually ruled dissolved the objection. Its table,
`3tk-core-redesign-proposal-002.md:174` and `:182`:

```
| `AnyHandle`           | **`Handle`**   | Still a transparent alias for `Inner*`. D4 stands |
| `mtk::helper::to_any` | **`to_inner`** | An inherited name, and it now says the direction  |
```

**The stated reason is the direction prefix, not the noun — and the same pass,
in the same table, kept *handle* for the type.** The noun was picked
mechanically to match `Inner` while de-`Any`-ing the port. `inner` against
`handle` was never the question that day. **So H5 finishes R1 rather than
reversing it**, and the *this was ruled yesterday* objection does not survive
reading the ruling. *inner* keeps `Inner`, `inner_offset`, `src/inner.c3` and
the prose; it stops naming a handle, which is a `Handle` in every signature that
returns or takes one.

**And the stage had to correct its own spelling to accept it.** M11 to M13 were
measured with `handle_of(&m)` — this stage's invention, in neither the note nor
R1 — which drops the direction prefix that was R1's entire stated reason and
breaks the symmetry with `from_handle`. The accepted member is `to_handle`.

**The probes were re-run rather than the document edited.** Renaming a thing
inside your own quoted compiler output is no longer quoting, and this line of
work has one rule it inherited from 3TK-4: every claim about the language is a
program that ran. Seventeen assertions true under the new spelling, zero errors,
identical under `-O3 --safe=no`, and both quoted diagnostics re-verified.

Two lessons are worth keeping, and they are the same lesson twice. **A
measurement made under an unruled assumption carries the assumption into the
ruling** — H0 was measured with names H5 had not yet decided. And **a guard that
always fires is indistinguishable from a guard that works, if you only run the
negative case** — the `$Typeof(*item).members` slip earlier in this stage. Both
were caught by running the other half.

**H10 was added on the owner's question — is it time to replace `owned` with
`managed`?** The specification never uses either word, so nothing constrains it.
The argument for `managed`: `owned` is passive and invites *owned by whom?*,
where the answer is nobody — D3 has the item keep **its own** allocator. The
port's own prose already draws the contrast, at `owned.c3:13`: *takes
`mtk::helper` and manages its own lifetime.* And the family argument — the only
place the vocabulary appears in the whole corpus is Zig's, at
`ztk-audit-001.md:264`, where `Unmanaged` means precisely *does not keep its
allocator*, which is Part 13.1 inverted.

**The argument against is a cross-port one and it does not go away:** `managed`
carries garbage-collector baggage, and **dtk is scoped `@nogc`**, so the word
misfires for exactly one of the four ports. The stage recommends `managed`
anyway, with one sentence of doc comment aimed at the D and C# reader — cheaper
than choosing a weaker word to prevent a misreading that a sentence prevents.

**The fixture is a separate question and H10 says so.** `struct Owned` is a test
type, declared twice and read at 34 sites, and it exists to prove one property —
*carries an Allocator*. Its three siblings are named for what they prove, not
for what they use. Recommended: `struct Holder`, which stays true whatever the
module is called.

**On timing, which is what was actually asked: inside the code stage that
carries H0b, not before it and not alone.** H0b rewrites `owned.c3` from
scratch, 3TK-15's A5 repoints doc comments in the same files, and the file's
25-line header is prose about D3 and D10 that a rename touches anyway. One pass
instead of three. Every one of the ~93 sites is compiler-caught, with 3TK-11's
warning still standing: rename on word boundaries and read the diff.

**H10 was accepted the same day, recommendation and sub-question together.**
`mtk::owned` becomes `mtk::managed`; the test fixture `struct Owned` becomes
`struct Holder`. The fixture was the part the stage argued separately — it is a
test type that exists to prove one property, *carries an Allocator*, and its
three siblings are named for what they prove rather than for what they use.
`Holder` stays true whatever the module is called.

**The GC connotation is paid for with one sentence, not with a weaker word.**
`managed` reads .NET to some readers, and **dtk is scoped `@nogc`** — it is the
port that would meet the word wrong. The module's doc comment will say that
*managed* here is Zig's sense: the item keeps its allocator and releases itself
with the kept one, Part 13.1, with no collector and no runtime anywhere in the
toolkit. Choosing a weaker word to prevent a misreading that a sentence prevents
is the worse trade.

**The rename was measured after the ruling, not assumed, and it turned up one
thing worth having checked.** `run-builds.sh:71` keys the compile-time negative
for an allocator-less type on a literal string. The message at
`src/inner.c3:274` names **both** modules — *use `mtk::helper` instead of
`mtk::owned`* — so the rename moves only its second half and **the expectation
string `mtk::helper` survives untouched**. The harness check passes without
being edited.

**Filenames were the only live edge, and they are small.** `test/t_owned.c3` is
free — `c3c test` discovers the suite, and no script names the file.
`negative/nocompile_owned_no_allocator.c3` is not free: it is a hard-coded key
at `run-builds.sh:71`, driven from `:161`. Renaming it costs exactly one line,
and the word in it names the module you tried to use, so leaving it stale is
worse. **That one line is the whole of what the harness needs for H0, H0b, H5
and H10 together** — and Part D's earlier flat claim that `run-builds.sh` does
not change was written before H10 existed and is corrected in place.

## E6 and E7, ruled — and they came out asymmetrically

**E6 — Part 7.1 is a specification defect, not a port deviation.** Of its three
clauses, only *"for each outer type there is a helper bound to that one type"*
fails under H0. The other two — *generated at compile time from the type*, and
*carries the identity and the crossings* — are true. And Part 7.1's own closing
sentence sets the floor **below** where H0 sits: *a port with no compile-time
generation writes the same block by hand for each type, and loses only the
typing.* Hand-written blocks are conformant. H0 generates; what it lacks is a
**named per-type object**, which is a mechanism and not a promise.

**That failing clause is ztk's mechanism, and this is exactly the disease 3TK-13
was created to cure.** 002 was written from ztk and stated Zig's mechanism where
the design has only a promise, in fourteen places. 003 fixed fourteen. **Part
7.1 is the fifteenth and 3TK-13 missed it.** Worth recording plainly, because
the audit that produced 003 was thorough and still walked past this one — the
sentence *reads* like a requirement, and only a port that answers the question
differently exposes it as a mechanism. **3tk is that port. The gap did not show
until something tried to fill it another way.**

**The deciding argument was dtk, and it is the argument that moved the
specification into `../common/` on 2026-08-23.** No stage has run there. D's
idiomatic answer to *generate code per type* is templates and mixins —
call-site expansion, the same shape as a C3 macro, not a per-type struct.
Rewording Part 7.1 inside this consumer's folder would leave the identical trap
set for D and for Odin behind it.

So it is an **S**, scope `every port`, in the vocabulary
`3tk-deviations-001.md` already uses — V1, V2 and V3 are the precedent and 003's
change log shows how a V is consumed. **Not a P.** A P would record the port as
wrong where the specification overreached, and keeping those apart is the whole
value of that audit.

**E7 — nothing is lost, and the stage's own premise was wrong.** It had raised
E7 as *the owning distinction stops being a property of the type*. It was never
a property of the type in 3tk. `struct Owned` carries no marker, and
`src/owned.c3:5` says why: *"ztk spells this distinction with a marker constant
and pays 110 duplicated lines; C3 has no property to branch on and needs
neither."* **D10 had already moved the decision off the type** — an
instantiation is a declaration the *application* writes, not a permission the
type grants. H0b moves it from the alias line to the call line; both are on the
application's side of the fence. The build-time gate survives, measured under
the H10 rename: *type Plain has no Allocator field; use mtk::helper instead of
mtk::managed.* **No change to anything.**

A small lesson, and it is the third of its kind in this stage: **a question
raised as a risk is still a claim, and it has to be checked like one.** E7 read
as a real loss until the fixture was actually opened and found to declare
nothing.

## What is owed, and the one gap

**3TK-14 could write none of the following and did not.** The code stage owes:
the S/V row for Part 7.1 and the updated Part 7.3 row in
`3tk-deviations-001.md` — which is 3TK-12's output, and a stage may not rewrite
a finished stage's output; one line of `run-builds.sh` for the renamed
`nocompile_` file; the GC sentence in `managed.c3`; and E7's call-site sentence.

**The gap: rewording Part 7.1 in `../common/` has no stage.** Plan 008 declares
3TK-14 and 3TK-15 and nothing else, and no stage may touch `../common/`. The
edit is small — state the promise, show both realizations marked *ztk* and
*3tk*, as 003 did for the other fourteen — but it needs to be declared, and it
wants to run **before dtk's first stage**, not after.

**Every H item is ruled, E6 and E7 are ruled, and nothing is authorized.** H0,
H0b, H5 and H10 all land in one code stage alongside 3TK-15's A5 — one pass
instead of five. No code stage has been named.

---

## 2026-08-24 — plan 008: 3TK-14 and 3TK-15 declared

**Written: [3tk-staging-plan-008.md](backup/3tk-staging-plan-008.md).** 007 moved to
`backup/` and every link naming it was corrected in place, both directions: the
live pointers in `3tk-status.md` name 008; the provenance lines in
`3tk-deviations-001.md`, `../common/matryoshka-specification-003.md` and this
log keep naming 007 and now find it at `backup/`.

**Neither stage is authorized.** Both were named by the owner after 3TK-13
reported.

**3TK-14 — the helper surface, re-thought.** The first stage in this line whose
subject is the *surface* and not the semantics. `helper.c3` was written in 3TK-6
and has not been questioned since; an application reaches it through one alias
per operation, and `3tk/test/common.c3` carries **seventeen alias lines** to use
four types. The shape is conformant — Part 7.1 leaves the spelling to the port —
so nothing requires this and the owner named it anyway. `owned` rides along as a
second question.

**Its input is the owner's `3tk-helper-alternatives.md`, and the stage is written
around one property of that file: it withdraws its own favourite.** The note
ranks three shapes, calls methods-on-the-generic-type-parameter its clear
favourite, and then a later *Important correction* section says that is probably
not legal C3 and must not be relied on without a compiler test. A stage that
implements the ranking without reading to the end implements something that does
not compile. **So 3TK-14 measures with c3c first and designs second** — the
3TK-4 shape, where every claim about the language is a program that ran with its
output quoted. It ends at a proposal and touches no code.

**One item in that note is about conformance and not taste, and it is called out
separately**: exporting `OFF` hands application code the address arithmetic Part
7.5 MUST confines to the helper, and `MSG_OFF` is aliased in `test/common.c3`
today.

**3TK-15 — the two debts of 3TK-13.** A3 and A5, both already ruled, gathered so
they are paid rather than drifting. **It runs after 14**, because A5 repoints doc
comments in the files 14 may rewrite — running it first would repoint comments
that 14 then rewrites.

**A3 is a real defect and worth naming plainly**: `Pool.get` answers
`NOT_AVAILABLE` for an identity the pool was not created with, from every mode,
where Part 19.3 says that outcome comes only from the available-only mode. The
`@check` above it expands to nothing under `--safe=no`, so this is the observable
behaviour of a fast build. **The port currently breaks a MUST in its own source
of truth, knowingly, and has since 3TK-13 chose to leave 003 untouched.** A5 is
bookkeeping by comparison, with one part that is not mechanical: where 003
changed the rule a comment cites, the comment's claim changes too, and a comment
citing Part 8.6 is citing a deleted Part.

---

## 2026-08-24 — the two scripts take an optional directory

**Not a stage.** A tooling change on the owner's instruction, after 3TK-13
reported. No document of record changed and nothing in `3tk/src/`,
`3tk/test/` or `3tk/negative/` was touched.

Both `run-builds.sh` and `run-sanitizers.sh` opened with `cd "$(dirname "$0")"`,
so each always ran against the directory it lived in. Each now takes an optional
first argument naming the directory to run against. **Absent or empty falls
through to `$(dirname "$0")` — the same expression that was already there** — so
every existing invocation, every line of `3tk-status.md` and the cold-session
gate behave identically. One site changed per script.

**The `cd` is now guarded, and that is the part worth recording.** Neither script
sets `-e`. A failed `cd` therefore did not stop them: the body would have run in
whatever directory the caller happened to be in, and `run-builds.sh` removes its
temporary directory with `rm -rf` at exit. While the target was always
`dirname "$0"` that was unreachable in practice; a caller-supplied path makes it
reachable, so it had to become fatal. A bad path prints one line and exits 2
with nothing else run.

**Verified, all four cases on both scripts**: no argument from an unrelated
working directory, an empty argument, an explicit directory, and a path that
does not exist. `run-builds.sh` 59 checks 0 failures on each of the first three,
`run-sanitizers.sh` 3 clean runs on each, and exit 2 with no work done on the
fourth.

**A note on how it was verified, because the first attempt was wrong.** Three
full passes of `run-builds.sh` cost roughly ten minutes and mostly proved that
c3c works; the three cases differ only in which directory the script lands in.
The cheap check written to replace it piped the script's prologue into `bash -s`
and was **invalid**, because that changes `$0` — the one variable under test —
and it reported the no-argument case landing in the caller's directory. The full
runs were the honest evidence and they passed. **A test that alters `$0` cannot
test `dirname "$0"`.**

---

## 2026-08-24 — 3TK-13: specification 003, and the gap closes

**Written: `../common/matryoshka-specification-003.md`.** The first stage of
this plan to write into `../common/`, and the whole of its risk was that the
file binds dtk and otk with no stage running on either to catch a mistake.

**Eighteen changes, and fourteen of them are one mistake made repeatedly.** 002
was written from ztk, and where it described a *mechanism* it described Zig's as
though it were the rule. Those Parts now state the promise and show both
realizations side by side, marked *ztk* and *3tk* — 4.2, 8.1, 8.2, 8.7, 11.2,
11.3, 11.7, 11.8, 12.2, 12.5 and the four Parts the forecast said were
untouched, 19.1, 19.2, 20, 21 and 22. A reader of 003 cannot mistake either
realization for the rule, which is the failure 002 could not prevent because it
had only one.

**Four changes are not that**, and each is worth naming:

- **Part 12.3 gains a MUST that did not exist.** What the pool does with a
  hook's result if the pool closed while the hook ran: re-read the flag, and
  send what the call is holding to the close hook. This is the rule P1 fell
  through, and every port has the same window because every port unlocks across
  the hook. Invariant 35.
- **Part 12.2's *called once* is weakened** to *called once by close, and once
  more per straggling put*. **The only thing 003 weakens**, and the alternative
  — handing the items back to the caller — has no channel for the parts the
  caller never had. It is named twice in the change log so nobody meets it by
  accident.
- **The pool's *put a list* is deleted**, from Part 11.7 and from Part 19.2's
  table. Its mid-batch failure mode was the one case with no clean answer.
- **Part 8.6 is deleted and tombstoned in place.** An exact link test makes the
  O(n) walk catch nothing. A port that does not reach an exact test still writes
  the walk — under 8.7, where the price is now stated, not under a Part that no
  longer exists.

**Nothing renumbered.** Assumption A1 held all the way through: Part 8.6 is a
tombstone, invariant row 16 says it was retired and 16b replaces it, row 35 is
new. Roughly forty doc comments in `3tk/src/` cite Part numbers by hand and none
of them broke.

**No 3tk-only finding reached `../common/`.** That was the split's whole
purpose. Parts 2.6 and 19.3 are unchanged and the port fails both — P4 and P2 —
because moving a rule to accommodate a port's defect is how a specification
stops being one.

**Filing, assumption A5.** 002 moved to a new `../common/backup/`, beside 001,
and its own two outbound links were fixed for the new depth. Every document that
named 002 was repointed: the live pointers — `common/README.md`,
`../d/dtk-status.md`, `../d/inputs/README.md`, this folder's status — now name
003; the provenance mentions in stage outputs, logs and backups keep naming 002
and now find it at `backup/`. Both directions, in place.

**dtk was told.** One paragraph in `../d/dtk-status.md` says its input changed
and why it matters to a port that has not started: a dtk written from 002 would
have reproduced `prev`, the anchor, the general list and an inexact link test,
and then needed 3TK-10 and 3TK-11 run again against it. **otk was not told** —
it has no stage and 3TK-13 was not permitted to touch it.

**Two debts, both recorded rather than paid.** A3: the P2 code change is not
made, so Part 19.3's MUST is currently unmet by the port. A5: `3tk/src/` still
cites 002 in its doc comments. Both are in 003's change log and in the status
file, so neither is a surprise.

`3tk/run-builds.sh` 59 checks, green — nothing in `3tk/` was touched.

---

## 2026-08-24 — five questions before the cut, five defaults recorded

**No code, no documents rewritten.** `3tk-status.md` gains *The assumptions
3TK-13 starts from*, and the audit's four open questions close.

The owner was asked, before clearing for 3TK-13, whether any question would help
the stage, and answered five with *take all recommendations, record them as
assumptions*. **The distinction is the point**: a ruling is the owner's
judgment, an assumption is a default the stage proceeds on, and 003's change log
will mark each as the second so a later reader can overturn one without working
out whether they are contradicting a decision.

**A1 — Parts do not renumber; a deleted Part becomes a tombstone.** The largest
of the five, and the reason is arithmetic rather than taste: Part numbers are
cited by hand in the D-register, the R-register, the notes, the audit and around
forty doc comments in `3tk/src/`. Renumbering after 8.6's deletion would
silently invalidate every one of them. Part 18's invariant table already works
this way — row 16 is retired, not removed — so the convention exists and is
being extended rather than invented.

**A2 — the *ztk* lines stay and *3tk* lines join them where the ports differ.**
The audit's central finding is that a Zig mechanism was read as the rule. Two
realizations side by side is what stops the next reader making that mistake in
either direction, and it is cheap while both ports are fresh. The cost is
length.

**A3 — P2 is answered in the port, and it is the only default that leaves work
behind.** `Pool.get` should report a distinct outcome for an identity the pool
was not created with, rather than `NOT_AVAILABLE`, so Part 19.3's *only* keeps
its MUST and 003 stays untouched. **3TK-13 does not make that change** — it is a
document stage — so it wants its own small stage or folding into the next code
one. Recorded so it is not lost.

**A4 — Part 6.5's dispatch table is the application's**, said in one sentence.
Every clause in 6.5 describes application code. On that reading 3tk had nothing
to ship, so P5 stops being a skipped SHOULD with no written why and closes with
V18.

**A5 — filing and scope.** 002 goes to a new `../common/backup/`, because the
specification lives in `common/` now and `c3/backup/` is the C3 line's own
record. **The port's doc comments are not repointed** from 002 to 003: forty
edits would bury a document stage, so it becomes a later stage's work and 003's
change log states it as a known debt rather than leaving it to surprise someone.
One line goes into `../d/dtk-status.md`, because dtk has run no stage and 003 is
what it has been waiting for.

**3TK-13 now has nothing left to wait on.** All eighteen every-port rows have
their replacement named, V11's three clauses included.

*Advice on clear: clear now, then run 3TK-13. Its inputs are the audit, the
specification and this file.*

---

## 2026-08-24 — P1 fixed: the pool no longer loses items to a close

**The audit's most serious finding, ruled and repaired the same day.** Changed:
`3tk/src/pool.c3`, `3tk/test/t_concurrency.c3`. All four builds green, 59
checks, all three sanitizer runs clean, **85 tests**.

**The defect, in one paragraph.** Part 12.3 MUST forbids holding the pool's
mutex across a call into application code, so `Pool.put` releases it around
`on_put`. A `Pool.close` can therefore run to completion inside that window: set
both flags, drain every bucket, hand everything to `on_close`. The old `put`
then relocked and pushed onto a shelf that had just been emptied, in a pool that
was already down. **The item was with nobody.** `slot.take()` cleared the
caller's Slot before the hook ran, so Part 9.4 told the caller truthfully that
the pool had it; the close hook had already run, so it never saw it. Invariant
34 and Part 11.8 both broke on the one window. The mailbox has no equivalent —
`send` holds the mutex from the closed test to the enqueue.

**The owner ruled the mechanism first: re-read the closed flag after the hook.**
That left the destination open, and the audit had already recorded why neither
candidate was legal under 002 — a second `on_close` is forbidden by Part 12.2's
*called once*, and handing the items back to the caller has no channel for the
`extra` parts, which the caller never had and which would leak instead.

**Then the owner ruled the destination: the stragglers go to `on_close`, and a
second call is acceptable.** So the pool's rule is now one line — *what the pool
holds when it discovers it is closed goes to the close hook* — and it keeps
invariant 34 and Part 11.8 intact while bending exactly one clause. **A hook
must not destroy its own state on the first `on_close`.** The owner's reason,
plainly: two calls to cleanup beats leaked parts.

**The test was checked both ways, and that is the part worth recording.** The
audit found P1 by reading, and a defect found by reading is one the suite does
not provoke — the same class as the missed leaver's signal that 3TK-11's notes
recorded as untested. `a_close_during_the_put_hook_loses_nothing` makes it
deterministic: the put hook parks until a second thread has closed the pool and
returned, so the window is held open rather than raced for. With the fix removed
it fails on `Violated assert 'p.count_of(OWNED_TYPE) == 0': invariant 34: an
item is in a closed pool`. A test that passed either way would have been the
failure mode `run-builds.sh` already records for `release_open_pool`.

The hook waits, which Part 12.3 tells a hook not to do. That is the test being a
test: it is the only way to hold the window open without calling back into the
pool from the hook, which is the other half of the same contract. Both the kept
item and two `extra` parts are asserted to reach the close hook.

**V11 stops being a question.** The audit's one undetermined row — *what the
pool does with a hook's result when the pool closed while the hook ran* — now
has three clauses for 003 to write, and the third is the only place 003 weakens
an existing MUST: Part 12.2's *called once* becomes *once by close, and once
more per straggling put*. It is every-port because clause 1 is forced by Part
12.3, which every port obeys, so every port has the same window. **All eighteen
every-port rows now have their replacement named, and 3TK-13 has nothing left to
wait on.**

*Advice on clear: clear before 3TK-13. The audit is its input; this repair is
recorded in it.*

---

## 2026-08-24 — 3TK-12: the audit found what a forecast could not

Written: [3tk-deviations-001.md](3tk-deviations-001.md). **No code touched, and
`../common/` untouched.** `3tk/run-builds.sh` and `3tk/run-sanitizers.sh` were
run at the start of the stage and are green — 59 checks, 3 sanitizer checks, 85
tests over four builds — which is the trivial result the plan expected and is
recorded so the document says which code it measured.

**96 elements across Parts 1 to 22. 74 conform, 17 specification-should-move, 5
port-should-move, 8 not applicable.**

**The stage exists because §8.1 was a forecast, and the forecast was
incomplete.** Nine of its ten rows stand as written. What it missed is one
pattern repeated five times: a Part that never mentions the list still *points*
at one. Part 19.2 carries a row for `put a list`. Part 20 carries two open
decisions that Part 8.6's deletion answers or voids. Part 21's Q11 points at the
deleted Part 8.6. Part 22's step 5 names two insert checks where there is one.
§8.1's closing line says Parts 19 to 22 are untouched; four of them are. Part
8.6 was deleted without a search for its referrers.

Two more the forecast could not have seen because they are words and not
operations: Part 11.2's *one internal base* reads as a shared type the port
refuses to build, and Parts 12.2 and 12.5 say *list* for a surface R13 retyped to
a queue. Both are the plan's third trap — a mechanism written as though it were
the rule.

**And the finding a forecast cannot make at all: `Pool.put` strands items.**
`pool.c3:426-428` unlocks for the hook, as Part 12.3 MUST requires, and relocks
without re-reading the closed flag. A `Pool.close` in that window drains every
bucket and runs the close hook; `put` then pushes into a closed and drained
pool. The item is with nobody — the caller's Slot was emptied at `:422`, so Part
9.4 tells the caller truthfully that the pool has it, and the close hook already
ran. Invariant 34 and Part 11.8 both break on the one window. The mailbox has no
equivalent: `send` holds the mutex from the closed test to the enqueue.

**Neither available repair is legal under 002**, and that is the finding's more
important half. Returning the items to the caller is forbidden by Part 11.8; a
second close hook is forbidden by Part 12.2's *called once*. So the audit splits
it: **P1**, a 3tk defect, and **V11**, a rule that does not exist in the
specification at all — *what the pool does with a hook's result when the pool
closed while the hook ran*. dtk and otk will write this same code from the same
silence. V11 is the one row of the eighteen whose replacement wording is not yet
determined, and it is the reason 3TK-13 wants a ruling before it cuts.

Four smaller port-side findings: `NOT_AVAILABLE` escapes from every get mode on
an unknown identity, against Part 19.3 MUST and observable in a fast build where
the `@check` above it is nothing; a condition variable's own fault can escape a
waiting call, dead code on posix and a contract statement in the port's two
most-copied loops; the pool's leaver signals on one bucket over a condition
variable shared by every identity, surviving on `broadcast` rather than on being
correct — the mailbox got that same line right and 3TK-11's notes named it as the
easiest one to half-fix; and Part 6.5 is a skipped SHOULD with no written why.

**The open question, and then the owner shrank it the same day.** The audit as
first written said [3tk-who-supports-slot.md](3tk-who-supports-slot.md) touches
Part 8.2 — *add at the back from a Slot* is listed there as a list operation —
and was therefore an every-port question. The owner's answer: it is advice, and
if 3tk's functionality needs the operation the port should not be made poorer
for a recommendation; measure whether the current APIs use it.

**Measured, and it splits in two — P6.** Neither container in `3tk/src/` calls a
Slot-shaped insert. §5.1's stated reason, *`send`, and the put hook's `extra`*,
is half wrong: `Mailbox.send_at` empties the Slot itself and calls
`push_back(Handle)`, `mailbox.c3:211` into `:150`, and `Pool.take_back` does the
same into `push(Handle)` at `:448`/`:456`. But the `extra` half is right and the
caller is the one that matters — a **hook**, application code, filling `extra`
from a Slot it just created, `t_pool.c3:70`. That is Part 12.5's composite
mechanism and it is a real requirement of the public surface. So
`InnerQueue.push_back_slot` **stays**, Part 8.2 does not change for it, and the
row leaves the every-port column.

What is left is `InnerStack.push_slot`: no caller in `src/`, one caller outside
it — `t_stack.c3:133`, the test of the operation itself — and R13 puts
`InnerStack` out of the application's reach entirely, so it has no caller it
could ever acquire.

**Ruled and done the same day.** `InnerStack.push_slot` and `t_stack.c3`'s
`push_from_a_slot` are deleted. **The stack has four operations**, and
`stack.c3`'s header carries the reason where the next reader will meet it —
including why the queue keeps its own, so nobody deletes that one by symmetry.
Part 8.2 loses one operation of the eleven, not of the every-port count: this is
3tk's own surface and 003 is not affected. It is the only code this line of work
touched between 3TK-11 and 3TK-13.

*Advice on clear: clear between 3TK-12 and 3TK-13. The audit is the input; the
walk that produced it is not.*

---

## 2026-08-24 — plan 007: an audit before the specification is cut

Written: [3tk-staging-plan-007.md](backup/3tk-staging-plan-007.md), adding **3TK-12**
and **3TK-13**. Plan 006 to `backup/`, links corrected. `3tk-status.md` gains a
section, *The gap between the port and the specification*. **No code touched.**

The owner asked for three things at once, and they turn out to be one thing:
save what should be done later, confirm what the specification is *for*, and
record where 3tk differs from it.

**Confirmed: the specification describes ztk.** 3TK-2 wrote
`../common/backup/matryoshka-specification-002.md` from `../common/ztk-audit-001.md`
and the three Zig sources; 68 of its lines are marked *ztk*. The document is
port-neutral **where it states a promise** and Zig-shaped **where it states a
mechanism** — the doubly-linked list, `prev`, the out-of-band anchor, one free
list per identity. That is not a fault of 3TK-2; it is what 3TK-10 discovered,
and R14 already rules it should be fixed.

**So its own claim is currently false for 3tk.** *A port is written from this
file alone.* A port started from 002 today reproduces `prev`, the general list
and the anchor, and then needs 3TK-10 and 3TK-11 run again against it. The gap
opened when 3TK-11 ended and `../common/` was deliberately left untouched.

**Why an audit was added rather than cutting 003 directly.** R14 rules the
move; it does not say what 003 says. The only list of changes on disk is
proposal 002 §8.1 — nine Parts — and it is a **forecast written before the code
existed**. 3TK-11 found three of 002's statements wrong: the stack has five
operations and not six, tier 2 does not reach a fast build, and two `put_all`
tests were converted rather than deleted. **None of the three is a decision;
all three are the kind of detail a specification states as a rule.** A
specification cut from a forecast carries the forecast's mistakes into dtk and
otk, which read that file and nothing else and have no stage running to catch
them.

**The audit's real deliverable is a split, not a list.** Every deviation is
marked **3tk-only** or **every port**. Only the second kind may reach
`../common/`. Getting that wrong in either direction is the expensive mistake:
a 3tk-only row in 003 sends a C3 decision to D and Odin, and an every-port row
left out of it leaves the same trap set that this whole line of work exists to
clear. It is why 3TK-13 is declared and not authorized — the split has to be
ruled before the cut is made.

**Two traps written into the plan in advance**, because they are the ones that
make an audit worthless: copying §8.1 instead of measuring, and missing the
Parts the redesign did not aim at. Parts 9, 12.5 and 17.2 were not aimed at and
all three are touched by a container surface that changed shape. The stage walks
all 22 Parts, and a missing Part is a failed stage rather than an omission.

**The status file carries the interim record.** Until 3TK-12 runs, *The gap
between the port and the specification* is the only place the difference is
written down, and it says of itself that it is a forecast and not an audit.
After 3TK-12 runs, `3tk-deviations-001.md` is the record and that section points
at it.

**`3tk-who-supports-slot.md` moved** from `3tk/src/` to the folder root, by the
owner. It is listed in the status file's *Files* as owner input, open and ruled
on by nothing, and it stays in *Open questions*.

**`3tk-porting-proposal-005.md` is recorded as a candidate**, on the owner's
instruction, so it is planned later rather than remembered. It is a **revision**
and not a stage: 004 is the design of record and it names `AnyNode`,
`NodeList` and `Pool.put_all`, so a reader of 004 today is reading the port as
it was before 3TK-11. **It waits on specification 003**, because nearly every
decision in 004 justifies itself by citing a Part that 003 rewrites.

The note carries one warning, and it is the reason a table row was not enough:
**do not renumber D1 to D16 and do not merge the D and R registers.** Every
notes file, every negative program comment, `3tk-log.md` and `3tk-status.md`
cite decisions by number. A renumber silently falsifies all of them, and with
`git` off there is no revert. Two registers side by side, with 005 saying which
R overtook which D — D14's anchor clause by R7, D12's blind spot by R6b, and
nothing else.

---

## 2026-08-23 — 3TK-11: the core redesign, in code

Written: [3tk-core-redesign-notes-001.md](3tk-core-redesign-notes-001.md), and
the port itself. `3tk-status.md` updated. `../common/` untouched, as plan 006
required. No `git` command run.

**All four builds green — 59 checks, 0 failures. Both sanitizers clean. 85
tests, up from 77.**

The stage had a specification and did not have a decision to make: R1 to R15,
ruled question by question the same day. What follows is what the code taught,
not what it chose.

**`AnyNode` → `Inner`, `AnyHandle` → `Handle`, `NodeList` → `InnerQueue` and a
new `InnerStack`.** `any.c3` became `inner.c3`; `list.c3` became `queue.c3` and
`stack.c3`; `t_list.c3` became `t_queue.c3` and `t_stack.c3`. The mechanical
half was a single pass and the compiler caught every survivor, because none of
these names is a string. **The real work was five files' worth of doc comments,
every one of which argued for a shape that no longer exists.**

**The self-link has six sites, not four.** 002 §3.2 counted four — `pop`,
`push`, `append_queue`, `iter` — and that count was for the queue alone. With
the stack: `InnerQueue.push_back`, `InnerQueue.pop_front`,
`InnerQueue.append_queue`, `InnerQueueIterator.next`, `InnerStack.push`,
`InnerStack.pop`. All six are three lines or fewer, so 001's objection to
mechanism B — three meanings across eleven sites — stays answered.

**Two of the six are where a translation of the old code goes wrong.**
`pop_front` has to recognise the sole item by `head == tail`, because with the
self-link there is no null `next` anywhere on a chain and the old `if (h.next)`
would read a self-pointer as a real successor. And the walker has to end at
`n.next == n`, or it yields the last item for ever. Every walk in `t_queue.c3`
carries a count assertion for that reason: **a hang is a worse test failure than
a wrong answer, because it reports nothing.**

**Invariant 5 was the one to get wrong, and 002 §4.4 said so in advance.** The
leaver's signal in `receive`'s timeout path used to read `self._queue`, and the
mechanical rewrite is `_regular` — which leaves a queued out-of-band item with
nobody woken. It is written as a named predicate, `Mailbox.has_queued()`, over
both queues. **No test catches this one**; a missed signal is a timing defect
and the suite does not provoke it. What protects it is the name and the comment,
and that is stated rather than papered over.

**Three corrections to 002, in details rather than in decisions.**

- **The stack has five operations, not six.** §5.1's own table lists exactly
  five — `push`, `push_slot`, `pop`, `is_empty`, `len` — and the sentence above
  it says six. Twelve operations replace Part 8.2's sixteen; eleven of the
  sixteen leave the port, not nine.
- **Tier 2 does not reach a fast build.** §10.3 says the rewritten negative
  "now aborts in a fast build too, because the check is tier 2". `@check` under
  `--safe=no` expands to nothing at all — the whole of D6, and of 3TK-4's Q11
  finding. What R6b bought is the exact check at O(1) in an ordinary safe build,
  where before it cost an O(n) walk per insert. The abort was always there where
  the checks are live.
- **Two `put_all` tests were converted rather than deleted.** §10.2 expected
  both gone. §6 had named the counter itself — *the caller now writes the loop,
  with a chance of getting the refusal case wrong and losing items quietly* —
  and deleting the only tests of the refusal path is the wrong answer to a risk
  the proposal raised in writing. `t_pool.c3` grew `put_batch`, the seven-line
  loop `Pool.put`'s doc comment now recommends, and both tests point at it. The
  behaviour under test did not change; the code under test moved from the port
  to the caller, so the test moved with it.

**The layering check had to be rewritten, not renamed.** `run-builds.sh`
guarded Part 17.2 by grepping the containers for `unlink_no_repair|@guard_insert`.
`unlink_no_repair` no longer exists — with no `remove` and no `pop_back` there
is no unrepaired removal to reach for. **Grepping for a symbol that cannot
appear is a check that passes for ever having proved nothing**, which is the
exact failure `run-builds.sh` already records for `release_open_pool`. It now
greps for `@guard_insert` and for any assignment to a `.next` field.

**Two tests were supposed to fail and did.** `t_identity.c3` and `t_owned.c3`
both assert the inner's size against `2 * uptr::size + typeid::size`. They exist
so a field cannot be added to the inner without someone deciding to, and they
were the first thing the stage had to change — to `uptr::size + typeid::size`,
16 bytes.

**Part 18 re-walked: still thirty-four rows.** Row 16 retired — *the link test
is not a membership test*, which it now is — and the self-link invariant took
its place. Row 22 **kept**, against plan 006's expectation that two queues would
delete it: the anchor was the mechanism, the ordering is a promise. Row 13
strengthened, because insert is O(1) in checking builds too. Rows 1 to 12, 18,
19, 21 and 23 to 33 untouched, and section 6.2 — creation is a transaction — is
the one a rewrite loses quietly and did not: both `create` functions keep every
`defer catch` unchanged.

**One warning for the next port.** A blind rename of `Any` inside identifiers
turned `remove_from_anywhere` into `remove_from_innerwhere`, in a test that was
about to be deleted anyway. Rename on word boundaries, and read the diff.

**What this stage did not do, and the plan is why:** `../common/` is
untouched, so **the port is now ahead of the specification it is written from**.
A port written from `matryoshka-specification-002.md` today would reproduce
`prev`, the general list and the anchor. R14 rules that 003 is cut; it is still
not scheduled, and it is the strongest candidate for what runs next.
`3tk-porting-proposal-004.md` is not edited either — §10.4 leaves it as the
record of what was built.

**One open question this stage found and did not answer.**
[3tk-who-supports-slot.md](3tk-who-supports-slot.md), a note from the owner —
at `3tk/src/` while the stage ran, moved up to the folder root by the owner
immediately after — argues the containers should not support the Slot idiom at
all: that
`push_back_slot` and `push_slot` belong on `Mailbox` and `Pool`. 3TK-10 did not
rule on it and 3TK-11 did not act on it. It is in the status file's open
questions now, because the note uses names the redesign refused and a reader who
finds it cannot tell whether it is current.

---

## 2026-08-23 — the redesign is ruled, question by question, and proposal 002 is cut

Written: [3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md).
001 to `backup/`, links corrected. `3tk-status.md` updated. **No code touched.**

The owner asked for the questions one at a time rather than as a list, and that
is why three decisions moved. A list would have been accepted or refused whole.

**R6 refused — no membership field.** 001 wanted a third field, `void* chain`,
at the same 24 bytes `prev` cost. The owner said: check what is possible with
`next` alone. It is. **The last item of every chain points at itself**, so
`is_linked` is `next != null` and it is **exact** — no blind spot, and it still
deletes `contains` and the O(n) walk on every insert. `Inner` drops to two
fields and 16 bytes.

**001's argument against the self-link was measured against the wrong
container.** It said a terminator gives `next` three meanings across eleven
sites in `list.c3`. Ruling 2 abolishes that container: with nine operations
deleted, about four sites touch `next`. The field bought one query — *is it on
__this__ container* — whose only caller, `remove`, is deleted.

**R11 has a reason now, and it is not performance.** 001 recorded the pool's
reversal to last-in first-out as legal-but-arbitrary under Part 11.10. The
owner's reason is **defect surfacing**: under first-in first-out, an item given
back sits at the back of the free list, so code still keeping a pointer to it
writes to an item nobody has re-taken and nothing conflicts — and if the put
hook did not reset the contents, the stale writer sees data that still looks
plausible. Under last-in first-out the **next `get` gives that item to a new
owner**, so the two writers meet immediately and the defect appears next to its
cause. Same reasoning as not quarantining freed memory. It goes in the doc
comment on the pool's stack, because a later reader will otherwise take the
stack for an arbitrary choice.

**R15 — `put_all` is dropped**, and it retires R4. The owner said it looked
cumbersome and asked for a real opinion rather than a defence. It is: `Pool.put`
in a loop, inherited from `pool.zig:394`, no batching and no atomicity. The
claim that it encodes a fiddly loop once does not survive checking — **it does
not spare the caller the difficult case, it gives the difficult case back in a
different shape**, because a caller whose pool closed mid-batch still keeps a
partly-emptied queue. Its price was a container operation nothing else needs, a
MUST clause in Part 11.8 and the most awkward contract in the toolkit. Ruling
2's own principle applies to it, and 001 had applied that principle to
`NodeList` and not to this. **`InnerQueue` reaches seven operations and is
genuinely minimal.**

**R8, R9, R12, R13, R14 accepted as proposed.** The give-back order is one
sentence for both containers. Invariant 22 is kept and only the anchor goes.
`Pool.close` empties every bucket into **one** `InnerQueue`, flattened — the
hook never sees buckets — and **no order is promised**, because the hook's loop
is the same either way. There is no `InnerList`. The specification moves to 003,
which is ruled and not scheduled.

**A banned word, and a scan scope nobody had noticed.** The owner caught one of
`rules-049.md` Part 5's banned words in 001. Part 5's own scan skips
`design/secondary/`, so **no scan has ever covered this folder** — every
document in it was written unchecked. A full scan against the whole list found
nine hits, all in 001: three of that word, four custody-sense uses of two
others, two AI-ish words. `3tk-status.md` and `3tk-log.md` were clean. 002 is
clean against the whole list. 001 was left as it is, being a record.

Four builds green and sanitizers clean throughout — nothing in `3tk/` moved.

**3TK-11 has no open question in front of it.**

---

## 2026-08-23 — 3TK-10: the core redesign, as a proposal

Written: [3tk-core-redesign-proposal-001.md](backup/3tk-core-redesign-proposal-001.md),
726 lines. **No code touched.** Four builds green, 59 checks, 0 failures, and
the sanitizers clean — trivially, because nothing in `3tk/` moved.

The stage read the owner's two documents against `3tk/src/` rather than on
trust, the way 3TK-8 read its review. That reading is the whole value of the
stage and it disagreed with its inputs in three places.

**The required-operation audit passes.** Every one of `NodeList`'s sixteen
operations was grepped for callers. `insert_before`, `remove`, `pop_back`,
`front` and `back` **have no caller in `src/` at all** — only `t_list.c3` uses
them. `insert_after` has exactly one, the out-of-band insert. `prev` has exactly
one job, `unlink_no_repair`, which serves two dead operations. Nothing needs
arbitrary removal, arbitrary insertion or backward traversal. Ruling 5 is safe.

**The out-of-band semantics are Meaning A**, absolute priority, FIFO within each
class — `mailbox.c3:143-159`. `3tk-to-fifo-lifo-single-001.md` §4 refused to
choose two queues before that was measured, and it was right to. Two queues
reproduce it exactly. `t_mailbox.c3:139-162` does not change.

**The pool is FIFO today, not LIFO** — `pool.c3:263`, `:337`, `:425`. Ruling 3
is therefore a **behaviour change**, not a container swap. It is legal: Part
11.10 promises no order, and no test asserts the current one. Recorded rather
than discovered later.

**Consequence 2 has a better answer than the four the plan listed.** With one
link the last item of every queue has `next == null`, so the double-insert guard
fails exactly where it matters. The plan named four mechanisms. The stage
proposes a fifth reading of the same choice: **`prev` is deleted and a `void*
chain` field takes its place.** The inner stays three words and 24 bytes, the
check becomes exact — no blind spot, and membership is `chain == container` in
O(1) — and **`contains` and the O(n) walk on every insert are deleted outright.**
Part 8.7's own last bullet says a port that marks membership properly is
strictly better and pays a field for it; ruling 5 is what makes the field free.
So the redesign ends up **stronger** than what it replaces, which is not how
consequence 2 was framed.

**Invariant 22 should not be deleted**, and the plan said it would be. The
*anchor* dies. The *ordering* is a promise to callers, is asserted by a test,
and is unchanged by two queues. Delete the mechanism clause of Part 11.3; keep
the row.

**The close order:** out-of-band first, then ordinary, FIFO within each — for
`close` and `receive_all` both, stated as one rule. It is the only order that
changes nothing, because the single queue already produces it.

The cost: every source file changes, about 20 of 77 tests are rewritten and the
rest renamed, and one negative — `insert_twice_same_list` — gains coverage
rather than losing it, since its check moves from tier 3 to tier 2 and fires in
a fast build too.

**Consequence 4: the recommendation is to move the specification to 003**, not
to declare a 3tk deviation. Nothing in the redesign turns on a C3 capability, so
it does not belong in a C3 document — and dtk has run no stage, so the cost
lands where nothing is built. Nine Parts would move; §8.1 names each with its
marking. `../common/` was not edited. The owner rules.

Fourteen decisions, R1 to R14. Seven are the stage's own. **R6, the `chain`
field, is the one 3TK-11 cannot start without.**

3TK-11 stays declared and not authorized.

---

## 2026-08-23 — the core redesign is ruled, and 3TK-10 will design it

Written: [3tk-staging-plan-006.md](backup/3tk-staging-plan-006.md), adding **3TK-10**.
Plan 005 to `backup/`, links corrected. `3tk-status.md` updated. **No code
touched and no stage run** — this entry exists so the direction survives a
context clear, because until now it lived only in a conversation.

Two documents arrived in the folder from the owner:
[3tk-naming-001.md](3tk-naming-001.md), 476 lines, proposing Outer/Inner naming,
and [3tk-to-fifo-lifo-single-001.md](3tk-to-fifo-lifo-single-001.md), 1058
lines, arguing that `NodeList` should not be the centre of the design. The owner
then gave the direction in five lines, and it is the input to 3TK-10 rather
than a suggestion to be weighed:

1. Drop `Any*` and every inherited ztk name — **Outer / Inner**.
2. Stop reproducing Zig's `DoublyLinkedList`. No general-purpose list.
3. **FIFO for the mailbox, LIFO for the pool.**
4. **Two FIFOs in the mailbox**, ordinary and out-of-band.
5. **One link, not two.** `next` only.

This is the largest change since the port existed, and it is bigger than 3TK-8
and 3TK-9 together. It deletes most of Part 8, retires `NodeList`, changes the
inner that Part 4.2 fixes, and removes D14's anchor. So **3TK-10 ends at a
proposal and does not touch `3tk/src/`** — the code is 3TK-11.

**The owner confirmed the sequence and asked for it on disk**, so plan 006
carries both: 3TK-10 authorized, **3TK-11 declared and not authorized**, running
only after the ruling on the proposal. Writing the second stage down now costs
nothing and fixes the order against anyone's memory of the conversation. That is this folder's habit and there is no reason to break it for
the one change most likely to need arguing about first.

Four consequences are written into the stage so a cold session does not have to
find them:

- **Most of Part 8 goes.** `remove`, `insert_after`, `insert_before`, `pop_back`
  have no home in a FIFO or a LIFO, and several Part 18 invariants exist only to
  guard them.
- **The double-insert guard weakens, and this is the sharp one.** `is_linked`
  asks `prev != null || next != null`. With one link, the last item in a queue
  has `next == null` and is **indistinguishable from an item on no queue at
  all** — so the check fails exactly where it matters. The stage must choose a
  mechanism rather than discover the problem later.
- **Two FIFOs delete the anchor and invariant 22** — a real simplification — but
  raise a question the current design never had: what order `close` returns the
  two queues in.
- **It is a specification change, not a port change.** Parts 4, 8 and 11 are in
  `../common/` and dtk and otk read them. The stage recommends; the owner rules.

The port as it stands is untouched and green — four builds, 59 checks, 77 tests,
sanitizers clean. Nothing above is stale yet. It is about to be.

---


## 2026-08-23 — 3TK-9: the sanitizer found the tests, not the port

Written: [3tk-sanitizer-notes-001.md](3tk-sanitizer-notes-001.md),
`3tk/run-sanitizers.sh`. Changed: `3tk/test/t_pool.c3`. Plan versioned to
[005](backup/3tk-staging-plan-005.md); 004 moved to `backup/` with links corrected.
Four builds green, 59 checks. Sanitizers clean, 3 runs, 0 findings.

The last item on the candidate list that could still find a defect in the port
rather than in a document. Plan 003 asked for the concurrency tests "under
whatever sanitizer the toolchain offers" and nobody had measured what that was.
Three stages later, it found something on the first run.

**The tool was there and the machine was not.** c3c 0.8.3 has
`--sanitize=address|memory|thread`. The first attempt failed at link — *cannot
find /usr/lib64/libtsan.so.2.0.0* — and the temptation was to write that down as
a c3c limitation. Two lines of C said otherwise: plain `cc -fsanitize=thread`
fails identically, so Fedora simply does not have the runtimes installed. clang
carries its own, and `c3c --cc clang` points the link at it. No install, no
root, nothing changed on the machine. A stage that needs the owner to install
packages is a stage that does not run on a fresh checkout.

**Then: `ThreadSanitizer: reported 4 warnings`.** All four in `TestHooks` —
`gets++`, `puts++` and the two `last_*_count` writes — with three producers and
three consumers on one pool. The frames that appear in `src/` are `pool.c3:284`
and `:396`, the hook call sites, where the pool has **already unlocked**. The
port put itself in the stack trace by obeying Part 12.3.

**The contract the tests broke is the port's own**, and it is written into
`PoolHooks`'s doc comment as a contract rather than a warning: *hooks run
outside the mutex, several at once, and a hook that touches shared state
protects it itself.* `TestHooks` did not. It had been racing since 3TK-7 while
every build reported green in four modes — because a data race is precisely the
defect a passing test suite cannot see. The stage justified itself on its first
run, and not in the way it expected: it did not find a bug in the toolkit, it
found the toolkit's own tests failing to keep the toolkit's own rule.

**The wrong fix was one line and would have passed.** Hold the pool's mutex
across the hook call and all four warnings vanish — along with Part 12.3, which
exists to keep application code from running under a toolkit lock. A sanitizer
says *there is a race*. It does not say *which side is wrong*, and that
judgement is not the tool's. The counters became `Atomic{usz}`, the same
mechanism the port uses for `_closed_fast`, in the hook where the specification
puts the responsibility.

After the fix: zero warnings on `thread safe -O0`, zero on `thread fast -O3` —
the mode where asserts are gone and the optimizer is most aggressive, and the
one a race would most likely survive into — and AddressSanitizer clean.

**The harness stayed honest.** `run-sanitizers.sh` is a second script, not a row
in `run-builds.sh`, because the gate requires `c3c` and nothing else and that
property is worth more than the coverage. It skips loudly and **exits 2** when
its compiler is absent — *a skip is not a pass* — and it separates *did not
build* from *found something*, which is 3TK-8's harness lesson applied before it
could cost anything twice.

**One fact nine stages had missed.** `c3c --help` carries `--test-noleak:
Disable tracking allocator and memory leak detection for tests.` Leak detection
has been **on by default** in every `c3c test` run this port has ever made, and
no document said so. It takes nothing from 3TK-8's `t_alloc.c3` — that finds
leaks on paths the tests cannot otherwise reach — but a port reading these notes
should know the default exists before building its own.

*Advice on clear: clear.* The stage is closed and the notes carry everything.

---

## 2026-08-23 — 3TK-8: the review answered, and a leak nobody could reach

Written: [3tk-porting-proposal-004.md](3tk-porting-proposal-004.md), the design
of record. `3tk/test/t_alloc.c3`, new. `3tk/src/mailbox.c3` and
`3tk/src/pool.c3`, changed. Proposal 003, the 003 review and addendum 001 moved
to `backup/`, links corrected in place. Four builds green, 59 checks, 0
failures, 77 tests.

The input was `3tk-porting-proposal-003-review.md`: 28 items, about design and
implementation rather than prose. It was read against `3tk/src/` before anything
was accepted, and that audit changed most of the verdicts — five of its items
were already true in the code, three of those in better shape than it assumed.

**D1's argument was wrong for three versions, and its ruling was right the whole
time.** That is why nobody checked it. D1 said hiding the container internals
must cost Part 11.1's MUST, having weighed two shapes; the review found a third
that keeps `Pool` an item and hides only the operational state. The review put
the confusion precisely: Part 11.1 requires *the container is itself an item*,
and D1 assumed that implies *every byte of its state is inside the public
struct*. It does not.

The owner ruled the same day, and the reason is better than the one it replaced:
*"I don't like wars with language. If it does not support the feature + I need
additional allocation — better not change code and add comment and update
docs."* Nine measurements now stand behind it. **M5 is the one that decides the
section** and it came from the owner asking the sharpest version of the
question — restrict fields, not functions, via a `@private` fields-only struct
inlined into the container. Six probes say C3 0.8.3 does not deliver it at any
price: `@private` on a field is refused outright, on a struct it hides the type
*name* only, and `inline` makes it worse by lifting the members into the outer's
namespace. So no shape hides container state while leaving it inside the object.
Hiding costs an allocation per container and buys a convention, not an
enforcement. The port declines, on the record, on cost — **not** on Part 11.1.

**One real defect, and it is the kind that survives reviews.** Neither
`Pool.create` nor `Mailbox.create` cleaned up after a partial failure. The pool
allocated itself, a mutex, a condition variable, then the bucket array — and a
failure at the last leaked all four. Both are transactions now, `defer catch`,
in the shape `std::threads::channel` uses for the same problem.

Two stages and two reviews walked past it, and the reason is worth keeping: the
leak lives in an error path no ordinary test takes, because on Linux `new_try`
does not fail. The port had no way to make an allocator fail. So 3TK-8 built
one, in `test/t_alloc.c3` — its own file, on the owner's instruction, because
`common.c3` is the shared fixture every other test compiles against.

**The test was checked by sabotage, not by passing.** Removing the pool's
`defer catch` lines turns the suite red. Removing the mailbox's leaves it green
— its only acquisition through the caller's allocator is the object itself, so
that path cannot be provoked at all. Both facts are written at the test site.
A test whose failure is impossible is worse than no test, and the honest thing
is to say which is which rather than count four tests and call the fix covered.

**Section 6 is the durable half of this stage.** Six implementation invariants
the port already honoured and no document stated: the pre-lock atomic as a hint
that may reject but never authorize; creation as a transaction; `close` is not
`destroy`; the hook unlock/relock contract and the staleness of everything read
before it; no reference into bucket storage across a hook, with `Pool.get_wait`
named as the one safe exception and why; and the lock order as a statement about
today rather than a timeless property. Plus the `AnyHandle`/`Slot` signature
rule, audited against every public signature, with no violation found — and M4
under it, because a method cannot attach to a pointer alias, so C3 will only let
one of the two be an object.

Deferred with the reason written down rather than dropped: the `NodeList`
mutation core. Removal is already centralized in `unlink_no_repair`; the four
insert sites are different shapes and collapsing them buys less than it costs
while every test is green. Rejected: the opaque `char[N]` storage, for the
reasons the review itself gives against it.

Four text corrections closed the drift the review found: the Part 4.2 mapping
row and D12 still said "a third field" when the inner has three, the 24 bytes
read as an invariant in one row when it is an observation, and Part 15.2's lock
statement was timeless where it should be current.

**No decision moved.** Sixteen decisions, four versions, and D1 reaffirmed after
its argument was found defective — which is the distinction this folder keeps: a
ruling and the reason for it are not the same thing, and only one of them was
wrong.

*Advice on clear: clear.* The stage is closed, the documents carry everything,
and nothing in context is needed by the candidates for a 3TK-9.

---


## 2026-08-23 — 3TK-8's four questions, all ruled before the stage started

The owner answered every open question in the stage, one at a time, so 3TK-8
begins with nothing outstanding. The rulings, and what each changed:

**D1 stands, and the reason is replaced.** Public direct representation, and no
code changes for the sake of hiding. The owner's reason is better than the one
the document currently carries — *no wars with the language.* C3 0.8.3 enforces
no field privacy at any price (addendum 001, M5), so the port declines to buy an
allocation and a lifetime rule per container for a boundary the language will
not keep. A comment marks it instead. The `Impl*` split is rejected on cost, on
the record, and **not** on Part 11.1 — which is the correction `003-review`
asked for, reached from the other direction.

**The capability answers live in proposal 004 only.** `c3-capabilities-001.md`
is the 3TK-4 output and is not amended; no 002 is cut. One home for the
measurements, beside the decision they support.

**The failing-allocator test gets built, in a file of its own.** The owner's
advice, and it is better than the plan's first draft: `3tk/test/t_alloc.c3`
rather than an addition to `common.c3`. `common.c3` is the shared fixture every
test file compiles against, and an allocator that fails on purpose does not
belong in it. The allocators also outlive this stage — counting, failing, an
arena later — and a file named for the subject is where the second one goes
without a discussion. Verified while writing it down: `project.json` declares
`"test-sources": [ "test" ]`, so the harness needs no edit at all.

**The 003 review moves to `backup/`** once 004 answers it, as the first review
did — and only after 004 carries what a current reader needs from it. Until
then it is input and stays live.

Two of the four rulings changed the plan rather than confirming it: the
dedicated test file, and D1's replacement reasoning. Both are in
`3tk-staging-plan-004.md`, and the questions are kept with their answers because
the reasons are part of the design record.

Still no code touched. `3tk/run-builds.sh` last reported four builds green, 59
checks, 0 failures.

---

## 2026-08-23 — D1 ruled again, and the reason replaced

The owner closed the review's central question. D1's **ruling** stands — public
direct representation, `Mailbox` and `Pool` as public structs with their state
stored directly in them — and **no code changes for the sake of hiding.**

The owner's words, because the reason is better than the one D1 currently
gives: *"I don't like wars with language. If it does not support the feature and
I need an additional allocation — better not change code, add a comment and
update the docs."*

That is the whole argument, and it is stronger than what it replaces. 003 says
Part 11.11 is skipped because the only mechanism that delivers it costs Part
11.1's MUST. That was never true, and both `003-review` and addendum 001 M5 show
why. What is true is narrower and harder: **C3 0.8.3 enforces no field privacy
at any price.** Not through `@private` on a struct, which hides the type name
and leaves every field reachable. Not through `inline`, which lifts the fields
into the outer's namespace and makes it worse. Not through `@private` on a
field, which the compiler refuses outright. The shapes that *would* hide the
state — the `Impl*` pointer, the opaque `char[N]` — all work by moving it out
of the object, and they cost an allocation and a lifetime rule per container.

So the port pays nothing for a boundary the language will not keep, and marks
it with a comment instead. Reachable fields plus a documented convention, with
the price visible. The `Impl*` split is rejected **on the record and on cost**,
not on Part 11.1 — which is exactly the correction the review asked for, now
arrived at from the other direction.

3TK-8 carries it: D1's argument rewritten, the field-role comments written, the
documents updated, and no signature moved. One of the stage's four open
questions is closed; three remain and none blocks it.

---

## 2026-08-23 — how C3 binds methods, and what it will not hide

Written: [3tk-porting-proposal-addendum-001.md](backup/3tk-porting-proposal-addendum-001.md).
Not a stage and not a revision — an addendum. It moves no decision, changes no
code, and 3TK-8 folds it into proposal 004.

The owner asked whether C3 supports calling `functionCall(handle, ...)` as
`handle.functionCall(...)`. Four probes against `c3c` 0.8.3 answered it, and
the answer was worth keeping.

**No.** C3 has no UFCS: a free function called with dot syntax is a hard error.
What it has is method functions, `fn void Type.f(&self)`, where the receiver is
written into the declaration. Every dotted call in `3tk/src/` is one of those.
D is the language that does the rewrite, which is where the question came from.

Two things fell out that the folder had never written down. A method may be
declared on a type from **another** module — so no argument about the split
representation may claim it would force methods into one module. And methods
attach to named types and **never to a pointer alias**: `alias AnyHandle =
AnyNode*` can carry no methods, while `typedef Slot` can. The asymmetry between
handle and Slot in every signature in the port is therefore **partly forced by
the language**, not purely a design choice — which gives D5 a second leg and is
the fact the review's §14 signature rule should be stated with.

The probes also reproduced F2 of the toolkit notes from the compiler's own
mouth: *"'@public' modifiers are ignored for method declarations."*

**M5 came from a second question the same day, and it is the one that matters
to D1.** The owner wanted field access restricted without restricting
functions: a `@private` fields-only struct, `inline` inside the public
container, transparent to `mtk`'s own methods and closed to an application. Six
probes say C3 0.8.3 does not deliver it. `@private` on a struct is a
**type-name** rule — another module cannot *name* `MailboxInternals`, which is
real — but every field inside it stays readable, writable and addressable
through the outer, and the write lands. `@private` on a field is refused
outright: *"'@private' cannot be used here."* There is no field-level privacy in
the language.

`inline` makes it worse rather than better. It lifts the hidden fields into the
outer's namespace, so `mb.closed` needs no `.guts` at all. And `inline` must be
the **first** field, which puts it in competition with `AnyNode node` for
position — survivable, since D2 already lets the inner sit anywhere, and the
only part of the idea that was.

The consequence is that the review's central dichotomy is now standing on
measurement instead of inference. **No shape hides container state while
leaving it inside the object.** Hiding costs an indirection — and it does not
cost Part 11.1. That is exactly what `003-review` argued, and D1's rewrite in
proposal 004 can now say it with the probes behind it.

Nothing was touched but documents. `3tk/run-builds.sh` last reported four
builds green, 59 checks, 0 failures.

---

## 2026-08-23 — a second review, and the plan versioned to 004 for it

Written: [3tk-staging-plan-004.md](backup/3tk-staging-plan-004.md), adding **3TK-8**.
Plan 003 moved to `backup/` and every link naming it corrected in place.
`3tk-status.md` updated. Nothing of 3TK-8 has run — no measurement, no
document, no code.

The input is `3tk-porting-proposal-003-review.md`, which arrived in the folder
untracked. It reads proposal 003 for **design and implementation** and says so
in its own scope section: *not advice about improving the document structure or
prose*. That is a different instrument from the first review, and it earned a
different answer.

**Why a stage and not a revision.** Proposal 003 came out of a revision — the
owner accepted the decisions, the review was answered, no plan version was cut.
This one touches `3tk/src/`, adds tests, and needs a measured answer from `c3c`
before its central paragraph can be written. Measurement plus code is
stage-shaped, and the alternative is an unrecorded revision that quietly
rewrites the port. So it got a row, and the plan got a version.

**The audit came before the plan.** The previous review was written against the
proposal text and had never opened `3tk/src/`, which is why most of its findings
were text drift. This one makes claims about the code, so every claim was
checked against the code before the stage's scope was fixed. What that changed:

*The headline is real.* D1 weighs two shapes — public fields, or
`typedef Pool = void` — and concludes that hiding must cost Part 11.1's MUST. A
third shape exists: `struct Pool { AnyNode node; PoolImpl* impl; }`. `Pool` is
still the type the application names, still embeds `AnyNode`, still crosses
through `mtk::helper{Pool}`, still sits on a `NodeList`. The review separates
two requirements D1 collapses — *the container is itself an item*, which Part
11.1 requires, and *every byte of its state is in the public struct*, which D1
assumes follows. It does not follow. The ruling stays; the argument goes.

*Five items were already satisfied, and one better than the review assumed.*
The pre-lock atomic is already a hint with a mandatory re-read. `close` is
already not `destroy`. And §19 asks that no `PoolBucket*` be carried across a
hook call — `Pool.put` already re-looks-up by identity in `take_back_handle`
rather than holding `b` across the unlock. Those become documented invariants,
which is the cheapest and most durable part of the whole review: the code
honours them and no document states them, so a later improvement could undo
them in silence.

*One real defect, and the review could not see it.* §20 asks for `Pool.create`
to be transactional, reasoning about a design it thought might exist. Read
against the code, the defect is real and broader than its framing: **neither
creation path cleans up after a partial failure.** `Pool.create` (`pool.c3:158`)
allocates the `Pool`, then a failure in `_mu.init()!`, `_cv.init()!` or
`new_array_try(...)!` propagates out and leaks it, plus whatever was already
initialized. `Mailbox.create` (`mailbox.c3:78`) is the same shape. The
duplicate-identity check 003 added runs before any allocation, so that part was
already transactional — the allocation sequence never was. Two reviews and two
stages walked past it.

*Four drifts are text-only, and narrower than stated.* Section 1 of 003 already
states the two-parts/three-fields distinction correctly; only the Part 4.2
mapping row and D12 kept the old wording. Nothing in `3tk/src/` asserts
`sizeof(AnyNode) == 24` — checked, not assumed.

*One thing is deferred rather than rejected.* §15 wants a private mutation core
under `NodeList`. Removal is already centralized in `unlink_no_repair`; the four
insert sites are genuinely different shapes, and collapsing them buys less than
it costs while every test is green. Written down so a later stage can take it,
rather than dropped.

3TK-8's plan section carries the whole audit as a table — what the review
claimed, and what the code said back — so the stage starts from evidence rather
than from assertions. Four questions for the owner are in it, and none of them
blocks it from starting.

`3tk/run-builds.sh` still reports four builds green, 59 checks, 0 failures. No
code has been touched yet.

---

## 2026-08-23 — the specification left this folder

Moved: `matryoshka-specification-002.md` and `ztk-audit-001.md` to
[`../common/`](../common/README.md), and specification 001 to
`../common/backup/`. Created `../common/README.md` and
[`../common/port-flow-001.md`](../common/port-flow-001.md). Not a stage, and not
a revision either — nothing was rewritten. A reorganization.

The reason is the review answered earlier the same day. Twenty-seven items were
raised against the C3 proposal and **two of them were specification defects**.
The specification describes itself as language-neutral and self-contained — *a
port is written from this file alone* — yet it lived inside `c3/`, one
consumer's folder. Had those two been fixed only in the C3 document, the same
trap would have stayed set for dtk and otk. A shared input that lives in a
consumer's folder is a fork waiting to happen, so it now lives where it belongs
and every port links to it.

The ztk audit went with it for the same reason: it is read-only evidence about
**Zig**, the reference implementation, and there is nothing C3 in it.

`port-flow-001.md` is new, and it is the 3tk process with C3 removed. Three
tiers, because the failure mode of reusing a proven flow is inheriting the
previous language's answers along with its questions. Tier 1 transfers as
written — cold-start stages, *finishing a stage does not start the next*, the
provenance rule, the three shapes of negative test, **compile judged separately
from run**, and sabotage verification. The compile-versus-run rule carries the
`release_open_pool` story as its reason, because a rule with a corpse attached
is obeyed. Tier 2 transfers only as a question, and the sharpest entry is the
build matrix: **not four builds** — four is this port's `--safe` × `-O` axis, and
a port that copies the number has performed a ritual rather than a verification.

Fourteen links across nine files were rewritten, in both directions, by
resolving each link's basename against where the file actually lives. Zero
dangling links after. The two `.c3` headers naming `matryoshka-specification-001.md`
were left exactly as they are — they mention the file, they do not link to it,
and they are provenance. A path is not a pointer.

`3tk/run-builds.sh` still reports four builds green, 59 checks, 0 failures. The
move touched no code.

---

## 2026-08-23 — the review answered, and a test that never ran

Written: `matryoshka-specification-002.md`, `3tk-porting-proposal-003.md`.
Both predecessors stay on disk. Not a stage — a revision, so no plan version.

The input was `3tk-porting-proposal-review.md`: 27 items against proposal 002,
careful and mostly right. It had been written against the proposal text alone
and had never opened `3tk/src/`, so every item was re-audited against the
specification, the ztk reference, the C3 source and the tests before anything
was changed. That changed several verdicts.

**Two items were not proposal defects at all.** Part 4.2 says the inner has
"exactly two parts" and then warns against "a third field", when `prev`, `next`
and `type` are already three — the proposal had faithfully inherited the
specification's own imprecision. And the review asked which wins when a mailbox
is closed but still holds items, a question the specification leaves open and
its outcome tables invite. It cannot happen: `close` drains the queue in one
step under the mutex and a send after the flag is refused under that same
mutex. ztk agrees. Both went into the specification instead, where the other
three ports will find them, and the second became **invariant 34** — a closed
container is empty.

**One item was rejected.** The review suggested `wake_all` need not report
`CLOSED`. Part 19.1 fixes that outcome set, and the port is right; only the
reason was missing.

**One became code.** `Pool.create` accepted a duplicate identity, and
`bucket_for` returns the first match, so a second bucket for the same identity
would never be found — a pool quietly holding half of what its creator asked
for. It now refuses, tier 2, with a negative program. The owner ruled on this
one directly.

**And building that found something the review could not have seen.**
`negative/release_open_pool.c3` had never compiled. It spelled a type's
identity `Msg.typeid`, which c3c 0.8.3 rejects, and the harness ran
`compile-run` and read any non-zero exit as the abort it was looking for — a
compile failure is a non-zero exit. So the pool half of Part 11.12, *the one
precondition the specification refuses to soften*, the only site that aborts in
all four builds, had been resting on a program that never ran, reported green
the whole time.

The spelling is fixed and the harness now compiles and runs as separately
judged steps, failing loudly on a negative that will not build. The new
duplicate-tag check was sabotaged before being trusted, and the suite went red
in both checking builds as it should.

Four builds green: 59 checks, 73 tests. Part 18 is thirty-four invariants now,
twenty-nine of them tested.

The lesson is D7's, from the other side. D7 was proved by sabotaging a correct
implementation and watching the suite catch it. This was the same lesson unpaid:
a test nobody had ever seen fail, passing for a reason nobody had checked.

---

## 2026-08-23 — the owner's ruling, and the port closes

Written: `3tk-porting-proposal-002.md`. `3tk-porting-proposal-001.md` stays on
disk, superseded.

**The owner accepted all sixteen decisions, and accepted G1's submodules.**
Not a stage — a ruling, which is why it produced no plan version.

The decisions had been marked *PROPOSED — owner overridable* since 3TK-5, which
ran without the ruling it was waiting for. 3TK-6 and 3TK-7 then built them, and
all sixteen survived contact with the compiler. That was the evidence the ruling
had been waiting for, and it is the reason the ruling is one line rather than a
review of sixteen arguments.

Version 002 says *ruling* where 001 said *proposal*. The arguments are unchanged
— each decision still carries the alternative it rejects, because the reason a
thing was chosen outlives the choosing.

Nine amendments folded in, each marked with the finding that produced it, and
**none of them moves a decision**:

- **G1**, the one the owner ruled on separately: the containers are
  `module mtk::mailbox` and `module mtk::pool`, not `module mtk`. Section 1
  now carries the module names beside the file names and says why — a C3
  submodule cannot see its parent's `@private` declarations, so Part 17.2's
  layering is enforced by the compiler rather than promised.
- **F1**, the worst thing 001 got wrong: the safe optimized build is
  `--safe=yes -O3`, not `-O3`. Section 7.2 now says so and says never to infer
  the mode from the `-O` level.
- F3 and F5 on `@check`: not `@private`, and the message is compile-time.
- F4: one alias per declaration; there is no whole-module form.
- G2: `return mtk::CLOSED~;`, because `?` marks the optional type.
- G4: a flat `PoolBucket[]` instead of a `HashMap`.
- G5: `put` involves two Slots, and section 5.9 now says which is which.
- Section 9 became a record of what was built instead of a plan for what might
  be.

The conflict register's seven closures are marked accepted with it.

**The 3tk line of work is complete.** The port covers all of Part 22, all
thirty-three invariants of Part 18 are reached, and `3tk/run-builds.sh` is green
in four builds. What remains is outside the specification: a sanitizer run, a
cross-target build, and packaging.

Advice: **clear.** Nothing is pending.

---

## 2026-08-23 — 3TK-7, the two containers in C3

Written: `3tk/src/mailbox.c3`, `3tk/src/pool.c3`, three more test files, four
more negative programs, and `3tk-containers-notes-001.md`, 299 lines.

The plan was versioned to `3tk-staging-plan-003.md` first. Its only change is
the addition of 3TK-7.

Steps 6 and 7 of Part 22. **The port is now complete against the
specification** — Part 17.1's required tool and both of Part 17.2's optional
ones.

The owner was offered the mailbox/pool split when 3TK-7 was scoped and did not
take it, so both containers were done in one stage. The mailbox was finished
and green before the pool was started, so the seam stayed available throughout.

**Result: all four builds green, 55 checks, 0 failures.** 71 tests run four
times, 6 runtime negatives, 2 tier 1 negatives, 3 compile-time refusals, and 3
layering checks. 37 tests at the end of 3TK-6, 71 now.

The three things plan 003 named in advance all landed.

**D7's wait loop, and a test that can tell.** The trouble with Part 2.5 is that
a wrong implementation passes every ordinary timeout test.
`the_deadline_is_anchored_once` has a second thread broadcast every 20ms for a
second while a waiter asks for 200ms. Anchored, it returns at ~200ms; on
`wait_timeout` every broadcast restarts the timeout. **The test was verified by
sabotage** — `wait_until(deadline)` was swapped for `wait_timeout(timeout)` and
the suite reported `FAILED: 70 passed, 1 failed` with the intended message. The
sabotage was reverted. A test for an invariant of this shape is worth nothing
until it has been seen to fail.

**D6 tier 1 has its first two sites.** `Mailbox.release` and `Pool.release` use
`always_assert` and abort in every build mode, `--safe=no -O3` included.
`run-builds.sh` grew a third negative shape for them: every other negative
asserts opposite behaviours across builds, and a tier 1 negative asserts the
same behaviour in all four. Both programs print `SOFTENED:` if they ever reach
their last line and the script fails on that string.

**Part 12.3.** `hooks_run_outside_the_mutex` has the hook count its own
concurrent entries and hold itself open. Four threads, and if the pool held its
lock the maximum would be one.

Six findings. The first is a structural change and needs the owner:

- **G1. The containers belong in submodules, and C3 makes Part 17.2 free.** The
  proposal put `Mailbox` and `Pool` in `module mtk`, which makes the layering a
  promise checkable only by review. F3 of the toolkit notes — `@private` does
  not reach a submodule — was recorded there as an irritation and is the
  solution here. `module mtk::mailbox` and `module mtk::pool` are structurally
  outside `mtk`, so **Part 17.2 is enforced by the compiler**. The move was not
  free and the compiler said so at once, with six errors demanding
  `mtk::CLOSED` instead of `CLOSED` — which is the enforcement working. The API
  reads better too: `mailbox::create(a)`, `pool::of(h)`. **Recommended as an
  amendment to the proposal's section 1; the owner's to accept.**
- **G2.** The fault-return operator is `~`, not `?`. `return CLOSED~;`. D15
  chose faults and did not spell the return.
- **G3. Part 11.2's shared base cannot be a shared struct.** Part 4.4 allows one
  inner per outer, so a base carrying the inner and embedded in both containers
  gives each an inner one level down. The five members are repeated instead,
  which 11.2's own text permits. Recorded because a reader who takes 11.2 as a
  factoring instruction will build the bug.
- **G4.** A flat `PoolBucket[]` beats the proposal's `HashMap` for a set that is
  fixed at creation and small.
- **G5. `put` involves two Slots, and the proposal did not say so.** The pool
  takes the item from the caller's Slot before the hook sees anything, and
  hands the hook a Slot of its own. Passing the caller's through would make a
  hook that keeps the item read as *refused*.
- G6: small spellings again.

**Sixteen decisions, sixteen exercised, sixteen survived.** Across both code
stages the amendments are two spellings and one structural recommendation, and
none in substance.

**Part 18 is complete.** All thirty-three invariants reached: twenty-eight
tested or provoked, five structural or documented, and each says which.

What is not done, listed honestly in the notes: no sanitizer run — plan 003
asked for one and it was not done, nor was it measured whether c3c 0.8.3 offers
one; the signal hand-off test is a race run 20 times, which is evidence rather
than proof; and linux-x64 is the only target built, where ztk is green on three.

Advice: **clear.** The port is complete and the documents carry it. What is
waiting is the owner's ruling on the sixteen decisions — which now have the
evidence they were waiting for, since all sixteen have survived a compiler — and
G1 as an amendment.

---

## 2026-08-23 — 3TK-6, the toolkit in C3

Written: `3tk/` — 5 source files, 5 test files, 9 negative programs, a
`project.json` and `run-builds.sh` — and `3tk-toolkit-notes-001.md`, 322 lines.

The plan was versioned to `3tk-staging-plan-002.md` first. Its only change is
the addition of 3TK-6; stages 3TK-0 to 3TK-5 are reproduced unaltered. The
provenance lines in the 3TK-1 to 3TK-5 outputs still name plan 001, because
that is the version they ran under; the live pointers in `3tk-status.md` were
repointed.

**The first stage that writes C3.** Steps 2 to 5 of Part 22: the inner and the
identity, the per-type helper with the crossings, the Slot and its six rules,
the list with both insert checks. Part 17.1's one required tool. The two
containers are not here.

The owner named the stage and told it to run in the same breath, without ruling
separately on the sixteen decisions. That was read as acceptance of
`3tk-porting-proposal-001.md` as written, and the plan section says so.

**Result: all four builds green, 44 checks, 0 failures.** 37 tests run four
times, 6 runtime negative programs, 3 compile-time refusals. `run-builds.sh` is
the verification and exits non-zero on any failure.

The negatives are the part that carries weight. Each provokes one contract
violation and asserts **both** halves: it must abort in a checking build, and
it must run to the end and exit 0 in a fast one. A negative that aborted in a
fast build would mean a plain `assert` had survived somewhere.

Nine findings. The first is the one that matters:

- **F1. `-O2` and above turn safe mode off, silently.** The proposal's section
  7.2 spelled the "safe, optimized" build `-O3`. Measured: `-O3` reports
  `SAFE_MODE=false`. So that build was the fast build under another name, and a
  suite run under it tested nothing new. The first run of `run-builds.sh`
  caught it exactly as designed — five negatives reported *did NOT abort in a
  checking build*. The script was right and the proposal was wrong. Every build
  in the port is now explicit on both sides, `--safe=yes` or `--safe=no`, and
  the mode is never inferred from the `-O` level. 3TK-4's Q11 measured the
  default and `--safe=no -O3`; neither exposes the implicit switch. The study is
  short by one row, not wrong.
- **F2. `@private` is ignored on method declarations, entirely.** C3 0.8.3 can
  hide neither a field (Q4) nor a method. This lands on D1 and strengthens it:
  D1 chose the border over the opaque type, and the alternative it did not
  consider turns out not to exist either. `NodeList.contains` and
  `NodeList.unlink_no_repair` are public whether the port likes it or not, and
  the second is named for what it leaves undone.
- **F3. `@private` does not reach a submodule**, so `@check` cannot be private
  as D6's sample wrote it. The resolution is Part 17.2 rather than a
  workaround: an application writing its own Slot-shaped call is entitled to
  the same contract check, so `@check` is public on purpose.
- **F4. A generic module instantiates per declaration, not as a whole.** The
  proposal's section 1 showed `alias msg = mtk::helper{Msg};`. There is no such
  form — nine aliases, or inline instantiation. 3TK-4's Q1 said this and the
  proposal contradicted it.
- F5 to F9: `always_assert` takes a compile-time message; a module-scope
  `$assert` cannot see a generic module's type parameter; `alloc::new` aborts
  and `alloc::new_try` is what Part 9.2 rule 4 needs; eight small spellings the
  proposal guessed at; and there is no front door to write, because in C3 the
  module is the front door.

**The sixteen decisions: nine exercised, nine survived.** Nothing the code met
contradicted a decision. D3 and D6 were amended in spelling only, by F6/F7 and
F5. Seven are untouched because they belong to the containers — D7, D9, D13,
D14, D16 — or are barely reachable here, D15.

Part 18: the toolkit reaches twenty invariants and fifteen are tested or
provoked; rows 6 and 14 are structural and say so.

One thing worth keeping. D12 accepted the link test's blind spot, and an
accepted cost that is only documented gets "fixed" by the next reader.
`the_link_test_has_a_blind_spot` asserts that an item alone on a list reports
false, so closing the blind spot fails a test that names D12. Its mirror,
`the_walk_has_a_blind_spot_too`, states the other half of Part 8.6's argument.

Three places where the specification is silent and the code had to choose are
recorded in the notes as findings rather than taken quietly: inserting from an
empty Slot, removing an item that is not on this list, and null as the answer
from an empty list.

The stage created the tree at the repository root by mistake and moved it under
`c3/3tk/` before anything was committed. The storage rule holds.

Advice: **clear.** The container stage, if the owner names it, reads the
proposal, the specification and `3tk-toolkit-notes-001.md`. The notes carry
what the code taught; the code carries the rest. What must not be lost is F1,
and it is written in three places — the notes, this entry, and a comment block
in `run-builds.sh` itself.

---

## 2026-08-23 — 3TK-5, the 3tk porting proposal

Written: `3tk-porting-proposal-001.md`. 984 lines.

Inputs: `matryoshka-specification-001.md`, `3tk-drafts-review-001.md`,
`c3-capabilities-001.md`, and this folder's status file. The seven drafts were
not reopened. `src/` was not reopened. No C3 was compiled in this stage — 3TK-4
did the compiling, and this stage reads its results.

**The stage ran without the two owner rulings it was waiting on.** `3tk-status.md`
recorded 3TK-5 as blocked on the C1-to-C11 ruling and on Q4. Neither had been
given. A porting proposal is the document where such rulings are *proposed*, so
every open decision is decided in it, argued, and marked **PROPOSED — owner
overridable**. Nothing in the file is settled until the owner says so.

Sixteen decisions, D1 to D16. They absorb the eight items the capability study
carried forward, the eleven of the conflict register, and the ten of Part 20.

The four that carry weight:

- **D1, Q4.** Public struct, public fields, the helper border does the work.
  Part 11.11 SHOULD is skipped with the reason written down: the only C3
  mechanism that delivers it — `typedef Pool = void` — costs Part 11.1 MUST,
  the containers being themselves items. A SHOULD is not traded for a MUST.
- **D3, the allocators.** Answered per type rather than once for the port. The
  inner does not grow a third field (Part 4.2, every item pays). An item that
  wants a release with no allocator parameter keeps the allocator in its own
  *outer* and takes `mtk::owned <Type>`, whose build-time `$assert` finds the
  field and, when it is missing, names the other helper in the message. C7 and
  the status file's first open question are answered together, as the review
  required.
- **D6, the assert policy.** Q11's trap — a plain `assert` under `--safe=no -O3`
  is an assumption the optimizer may act on, not a removed check — is routed
  around rather than documented. One port macro, `mtk::@check`, expands to
  `always_assert` in a safe build and to *nothing* otherwise. Three tiers:
  `always_assert` for Part 11.12 alone, `@check` for every other contract
  violation, a `$if COMPILER_SAFE_MODE` block for Part 8.6's O(n) walk. No
  plain `assert` guards a contract anywhere in the port.
- **D5 with D4.** The Slot is a distinct `typedef`; the handle is a transparent
  alias and there is only one of it. The cast cost that sinks typed handles
  (C10) does not arise for the Slot, because every function that takes one takes
  `Slot*` by design. The two-star confusion four drafts fell into no longer
  typechecks.

Also decided: no `inline` on the inner field (D2, for Part 7.5 and Part 10.1);
interruption dropped (D9, as Part 2.9's own text permits); two composing generic
modules instead of ztk's branching generator (D10); Part 22's order kept (D11);
`NodeList`, not `AnyList`, because `std::collections::anylist` exists and
copies (D8); faults as the outcome mechanism (D15); the pre-lock fast path kept
with its mandatory re-check (D16).

The mapping covers every MUST and SHOULD of Parts 1 to 17, part by part, with
the full sixteen-operation list surface (C6), the three hook signatures as the
specification requires them, and both container surfaces with their outcome
sets. `put` and `put_all` return `void`, not `void?` — Part 9.4, the Slot is the
answer.

Six things are dropped: two SHOULDs with written reasons, three MAYs whose
conditions are not met, and the `interrupted` outcome as a consequence of D9.

Build and test: one `project.json`, closing C9 with a third shape rather than
choosing between two that were never compiled, and **four builds, every time**.
The fourth — `--safe=no -O3` — is the one that segfaulted in Q11's probe, and
running it is what proves D6 was applied. The layering claim of Part 17.2 is
made a test: `mailbox.c3` and `pool.c3` reference no `@private` name of the core
four.

All eleven conflicts are now closed — four by 3TK-4, seven here, every one of
the seven overridable.

`kitchen/tools/check_design.sh` still exits 1, unchanged in cause. This file adds
one orphan row for the same `context.md` drift 3TK-2 hit. Not a regression, and
not fixed here.

Advice: **clear.** 3TK-6, if the owner names it, writes C3 from the proposal and
the specification. Nothing in this stage's reasoning is needed once the file is
on disk — the file *is* the reasoning. What must not be lost is the state of the
sixteen decisions, and that lives in `3tk-status.md`.

---

## 2026-08-23 — 3TK-4, the C3 capability study

Written: `c3-capabilities-001.md`. 740 lines.

Inputs: the C3 stdlib at `/home/g41797/dev/langs/c3/lib/std/`, Part 21 of the
specification, and the conflict register of `3tk-drafts-review-001.md`. The
drafts themselves were not reopened. `src/` was not reopened.

Toolchain measured: `c3c` 0.8.3, git `1d155ee`, LLVM 22.1.8, linux-x64.

Method. Twelve probes, compiled and run, three of them negative — written to
fail, with the compiler message as the evidence. Every answer is marked
*verified* (compiled) or *read* (stdlib source only). Probe sources are
reproduced inside the document rather than kept as files, so it is
self-contained.

Result: eleven of the twelve questions are a clean yes.

- Q1 generic modules. A full per-type helper, Part 7.2's seven members, was
  generated for two outer types and exercised, including the moving crossing on
  a mismatch.
- Q2 `typeid` satisfies every clause of Part 5.1. Two identically-shaped
  structs carry different values. This closes C1.
- Q3 both embeddings work. `inline` gives an implicit conversion; `::members`
  gives the offset, so the inner may sit anywhere. Part 4.3's offset-zero
  fallback is not needed.
- Q4 is the one real no. **C3 0.8.3 has no private struct fields**, and a
  public alias to a `@private` struct re-exports the layout. A
  `typedef Pool = void` does hide, at the cost that the container is no longer
  literally the struct embedding the inner. Two drafts build on private fields.
- Q5 interfaces with `@dynamic`. An interface value is nullable and carries the
  concrete typeid. The specification's own hook signatures compile; the three
  in `3tk-additions.md` were a misreading, not a C3 limit.
- Q7 threads, mutex, and **three** condition waits, one of them `wait_until` on
  an absolute deadline. Part 16 row 7 — ztk's 71 hand-written lines — is
  deleted. The relative `wait_timeout` recomputes the deadline on every call,
  so a loop built on it silently violates Part 2.5.
- Q11 has a trap. A plain `assert` is active in a safe build, a no-op at
  `--safe=no -O0`, and an optimizer assumption at `--safe=no -O3` — where a
  violated one is undefined behaviour, not a missed check. `always_assert`
  aborts in every mode, which is what Part 11.12 needs.
- Q12 `$Type::members` with `.name`, `.type`, `.offset`. Part 7.4's validation
  runs at build time and names the offending type, verified.

Also found, in no draft: `any` is reserved as a module name but `Any` is a
usable type name, which closes C3; a struct name that is all uppercase is
rejected; and `std::collections::anylist` already exists and shallow-copies
every element, which is the semantic opposite of the Matryoshka list under the
name the drafts chose for it.

Rulings delivered on the register: C1 and C3 closed, C5 closed on the
mechanism, C2 and C10 priced but left open, C7 narrowed, C4 C6 C8 C9 C11
untouched as not C3 questions. One question reopened that the drafts had
settled: Q4.

*Advice on clear: yes. 3TK-5 reads this document, not this reasoning.*

---

## 2026-08-23 — 3TK-3, the drafts review

Written: `3tk-drafts-review-001.md`. 462 lines.

Inputs: the seven `c3/` drafts, `matryoshka-specification-001.md`,
`ztk-audit-001.md`. Nothing else was opened. `src/` was not reopened.

Shape of the file:

- One table per draft. One row per claim, with a verdict, the conflicting
  draft where there is one, and a recommendation.
- Six verdicts: HOLDS, GAP, CONFLICT-S against the specification, CONFLICT-D
  against another draft, UNVERIFIED for a C3 language claim, OUT for anything
  outside the specification's subject.
- Section 8 lists what no draft covers: 22 parts, and 12 of the 33 invariants
  of Part 18.
- Section 9 is the conflict register, C1 to C11. Each names both sides and
  what the specification says.
- Section 10 is what to carry into 3TK-4 and 3TK-5.

What the review found.

- 117 claims measured across the seven files.
- `3tk-poc.md` is the outlier. Its node has no type identity field, so Parts 5,
  6 and 7 have nothing to stand on, and its pool has one free list instead of
  one per identity. It also ships a `Master`, which Part 1.3 forbids by name.
  Its wait loop restarts the timeout on every spurious wakeup, against Part
  2.5. It predates the other six by three days.
- `3tk-porting-notes.md` is the best of the seven. Its verification rule — what
  is confirmed architecture versus what needs a compilable prototype — is Part
  21 arrived at independently.
- Four drafts assume C3 `typeid` satisfies Part 5.1 and none of them checks it.
  `ztk-to-3tk.md` flagged it as the dangerous area and was ignored. That is
  conflict C1 and it is 3TK-4's first question.
- All four drafts that name the Slot attach the word to the pointer-to-Slot
  rather than to the Slot. The representation they propose is right. Conflict
  C4, and `3tk-porting-notes.md` has it in its *confirmed* column.
- The hooks interface of `3tk-additions.md` picks the mechanism the
  specification leans to, then gets all three signatures wrong against Part
  12.2, and drops `tags`, which Part 11.7 needs.
- `3tk-build-dist.md` and `3tk-poc.md` both describe a fourth layer — Master,
  Select, Group, Future — that Part 1.2, Part 1.3 and Part 16 all deny.

Nothing was resolved. Eleven conflicts are registered and the owner rules.

Recommended retirement: `3tk-poc.md` and `ztk-to-3tk.md`, kept on disk.

*Advice on clear: no. The ruling on C1 to C11 needs this reasoning in context.*

---

## 2026-08-23 — 3TK-2, the portable specification

Written: `matryoshka-specification-001.md`. 22 numbered parts, plus Part 0 for
the conformance markings and Part 21 for the questionnaire.

Inputs: `ztk-audit-001.md` and this plan. `src/` was not reopened, as the plan
required.

Shape of the file:

- Part 0 defines MUST, SHOULD, MAY, EXCLUDED. Every element in Parts 1 to 20
  carries one.
- Parts 1 to 15 are the owner's spine, one section each, in the owner's order.
- Part 16 is the excluded surface, twelve rows, from `audit 4`.
- Part 18 restates every MUST as a 33-row table, in the order a port meets
  them.
- Part 19 is the outcome set, as values, with no error sets.
- Part 20 is the ten decisions each port makes for itself.
- Part 21 is the questionnaire, twelve questions, each with a "if no" line
  naming what the port pays instead.
- Part 22 is a suggested porting order. Not conformance.

Decisions taken while writing, and why:

- **The heading "execution model" was not used.** Both words are on the banned
  list of `rules-049.md` Part 5. The plan names that section. Part 2 is called
  "Threads and waiting" and says so in its first line.
- **The word "idiomatic" was not used** either, for the same reason. The plan
  uses it. The specification says "the port's business" instead.
- **The questionnaire grew from ten questions to twelve.** The plan listed
  eight subjects. The audit's draft list had ten. Two more earned a place:
  build modes, because Part 8.6 and Part 15.5 both depend on whether an assert
  can be compiled out; and compile-time reflection on fields, which is separate
  from compile-time generation and a language can have one without the other.
- **The excluded surface was compressed from 16 rows to 12.** Four of the
  audit's rows are the same declaration counted on both containers. The
  specification is language-neutral, so it names the declaration once.
- **Two spellings were added to Part 16 that the audit did not call excluded**
  — error sets as the return channel, and the marker constant that selects the
  reduced helper. Both are `audit 3` rows marked incidental. Neither is a
  semantic, and a port that copies them has copied Zig.
- **The waiting-get contradiction was resolved toward the code.** Part 11.9
  says the waiting get never creates, and records that the book disagrees. The
  audit's ruling, carried forward.
- **The allocator was written as SHOULD, not MUST.** Part 13.1 states the
  intended shape. Part 13.3 records that ztk is not there. Part 13.4 leaves the
  application-item half open for 3TK-5, as the audit asked.

What the writing produced that the plan did not predict:

- The link-test blind spot (`audit 2.2`) is not a Zig detail. It is a design
  line that every port meets, and it costs a field per item to close. It became
  Part 8.7, a MUST, and a decision in Part 20.
- The memory-ordering half of a transfer (`audit 2.8`) is invisible in every
  signature and is the reason the toolkit needs no locks around application
  data. It became Part 14.2, and it is the invariant most likely to be lost in
  a port that reads only the signatures.
- Part 17 is not in the plan's list. The three tools with two optional is in
  the plan's second paragraph of the stage, and it turned out to be the test of
  the layering *and* the porting order. It earned its own part.

Length: 1366 lines against the plan's expected 600-900. The staccato rule of
`rules-049.md` Part 6 is one fact per line, and 33 invariants plus 12 questions
plus 22 parts do not compress below this without dropping facts. Flagged for
the owner. Nothing was padded; nothing was cut to fit.

Verification:

- Banned-word scan of the new file: four hits, two fixed ("holds" in the
  custody sense, "underneath"), two kept. `unlock` is the mutex operation.
  `holds` in "this holds for" is the truth sense, not custody.
- `kitchen/tools/check_design.sh` exits 1, not the 0 the plan expected. It
  exited 1 before this stage too. 43 problems: 14 dead links in `design/`, and
  29 orphans, every one of them under `design/secondary/lang/`. This stage
  added exactly one row — the new specification file — and it is the drift
  already recorded as `audit 7.1`: `design/secondary/context.md` does not list
  the `lang/` subfolders at all. Not fixed. Owner's call.

---

## 2026-08-23 — 3TK-1, the ztk audit

Read-only stage. Five `src/` files and eight documents, nothing else. The
firewall against the seven `c3/` drafts was kept.

Written: `ztk-audit-001.md`. Seven sections, as the plan named them.

What the reading produced that the plan did not predict:

- The excluded surface is 16 declarations, not a vague "the Io parts". Twelve
  of them vanish outright in a language whose condition variable has a timed
  wait. `src/internal/cond_timeout.zig` is 71 lines that exist for one missing
  standard-library call.
- The allocator gap is wider than "ztk is not exactly there". Both containers
  already keep an allocator at creation — and both `destroy` functions take
  another one as a parameter and use *that*, never the kept one. Nothing checks
  the two match. Application items keep none at all, and `PolyNode` has no field
  for one.
- Five more intended-versus-actual gaps beside the allocator. The largest:
  `Pool.get_wait` does not call `on_get`, and the book says twice that it does.
  The code is the truth.
- Four pieces of documentation drift, none of which touches `src/`. The
  architecture note still shows the pre-API-12 handle shape, and the Zig-0.16
  notes still say `_Mailbox` / `_Pool`.

Three invariants the plan did not list, found in the code and worth a section
each in the specification:

- The deadline is anchored once, before the retry loop. Converting a duration
  inside the loop restarts the timeout on every spurious wakeup. Both waiting
  functions say so in the same words.
- A waiter that leaves on timeout or cancel re-signals if the container is not
  empty. Without it a pending signal dies with the leaver.
- The transfer orders memory. The new holder sees every write the previous one
  made, because the container publishes through its own mutex. That is why the
  toolkit can assert on an item's internal state at all, and it appears in no
  signature.

Judgement calls recorded in the audit rather than made silently:

- `Mbox.wakeUpAll` is *not* an Io bridge and stays in scope. It has its own
  epoch mechanism.
- Table dispatch's "no switch over tags" is a Zig obstacle, not a Matryoshka
  invariant. The invariant it protects — one handler per (receiver, tag) pair,
  the Slot carries the result — is portable.
- Whether `send_oob` survives a port is left open. It is one priority level,
  and it exists because the two-channel model folds signals into the data
  channel as tagged items at the front.

44 features classified essential / should / may / incidental / excluded, one row
each with its reason. The recurring verdict is "shape essential, spelling free":
the tag, the compile-time helper, the hooks interface and scope-exit cleanup are
all required in shape and free in spelling.

Advice: clear. The specification works from `ztk-audit-001.md`, not from the
reading. Nothing in this session's context is needed by 3TK-2 that the audit
does not carry.

## 2026-08-23 — 3TK-0, the staging plan

The port family got its names: otk (Odin), ztk (Zig), 3tk (C3), dtk (D). 3tk is  
the active target. otk is refactored later, ztk tuned later, dtk is thinking  
only.

The owner set the storage rule first: every file for this work — plans, status,  
log, outputs — lives in `design/secondary/lang/c3/`. The main `design/STATUS.md`  
and `STATUS-LOG.md` stay untouched. Plans do not live in Claude memory.

The seven drafts already in this folder were written at different times by  
different AIs and contradict each other. That is what made a specification  
necessary rather than a porting note: without a yardstick, the contradictions  
propagate into whatever gets written next.

The owner gave the spine of the specification directly:

- plain threads, not fibers, not goroutines
- participants are long-lived heap objects
- intrusion — an embedded inner structure carrying the list links
- identity of the outer, carried in the inner
- self-identification by comparing against that identity
- a compile-time-generated per-type helper: initializer plus the conversions
  across the type-erased border
- an intrusive list for heterogeneous items
- the Slot idiom, a container of pointers
- deliberate synonyms — handle, slot, item — kept, not collapsed
- Mbox and Pool on one internal base, implementations hidden where the language
  allows, hooks as an interface
- allocators taken at creation and held for life — the direction, not yet
  exactly what ztk does

Two rulings on vocabulary. **inner** and **outer**, never "parent", because  
"parent" names a different relation in each language. And porting is not  
transpiling: idiomatic code per language, the tag being the example — hand-rolled  
in ztk, native in C3.

Two exclusions. Everything built for the `std.Io` bridge is out of scope for  
ports, and the specification must be self-contained, with only the three `src/`  
files as external reference — so it can serve dtk as well as 3tk.

Advice given and accepted on the shape of the specification: conformance  
markings (MUST / SHOULD / MAY / EXCLUDED) on every element, and a closing  
capability questionnaire that each language answers in turn. That questionnaire  
is what makes the later proposal stages mechanical without making them  
transliterations.

Two changes the owner made to the proposed staging: the review stage was named  
"ledger", which was rejected as unclear, and is now **3TK-3 drafts review**; and  
the C3 install step was dropped, because C3 is already installed —  
`/usr/bin/c3c`, stdlib at `/home/g41797/dev/langs/c3/lib/std/`.

The owner added the cold-start rule: every stage must be runnable after a  
context clear, and every stage must end by advising whether to clear.

Written: `3tk-staging-plan-001.md`, `3tk-status.md`, `3tk-log.md`.

Follow-up the same day, at the owner's instruction: the cold-start rule was
incomplete without a way to *invoke* a stage. Each stage now prints the exact
line the owner types to start it after a clear, and the status file repeats the
next one. A stage closes by naming the command for the next. Without that, cold
start meant "the agent could run it", not "the owner can start it".

## 2026-08-23 — versioning ruled

The three files created for 3TK-0 were inconsistent: all carried a `-001`
suffix, and all three were then edited in place, which Part 0 forbids.

Owner's ruling: the same three-way split `design/` already uses.

- `3tk-status.md` and `3tk-log.md` lose the suffix and are edited in place. They
  are entry points, not documents — the analogues of `STATUS.md` and
  `STATUS-LOG.md`.
- The plan keeps its suffix. A change makes `3tk-staging-plan-002.md`, and the
  superseded version stays on disk, listed in the status file.
- Every stage output is versioned the same way.

That created one problem and fixed it in the same move. The start command named
the plan by version, and a versioned filename moves, so every bump would have
broken the line the owner types. The command now names `3tk-status.md`, which
never moves and which says which plan version is current.

Renamed: `3tk-status-001.md` to `3tk-status.md`, `3tk-log-001.md` to
`3tk-log.md`. Both were created the same day and untracked, so no `git mv` was
involved. Every cross-reference repointed.

Owner's ruling on the same day: the plan stays `3tk-staging-plan-001.md`. The
edits made during 3TK-0 — the start commands, the versioning section — are part
of its initial version, not revisions of a published one. Nothing referenced it
yet. Versioning is strict from here: the next change makes `-002`.
