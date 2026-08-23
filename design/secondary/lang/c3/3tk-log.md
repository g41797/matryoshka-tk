# 3tk — log

Narrative of the 3tk line of work. Append-only, newest first.

Not read by default. Read it for history: what was decided, when, and why.  
Current state is in [3tk-status.md](3tk-status.md).

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
