# Staging plan — the Matryoshka portable specification and the 3tk port

This file is the plan of record for the 3tk line of work.

Approved by the owner, 2026-08-23.

**Version 009.** It supersedes `3tk-staging-plan-008.md`, and that one 007, 006,
005, 004, 003, 002 and 001. All stay on disk, in `backup/`. The only change in
009 is the addition of **3TK-16 and 3TK-17**, on the owner's instruction of
2026-08-24, and an amendment note on 3TK-15's ordering. Stages 3TK-0 to 3TK-15
are reproduced unaltered — they are done or declared, and a plan version does
not rewrite history. **3TK-14 ran on 2026-08-24**; its section below is left
exactly as 008 wrote it, including the words *declared, not authorized*, because
that is what the plan said at the time. `3tk-status.md` is the live record of
what is done.

**Why these two, and why now. 3TK-14 ended at a proposal and the owner ruled all
twelve of its items on the same day.** Nothing carries those rulings into the
code, and one of them is not 3tk's to carry at all.

- **The rulings are not built.** H0 and H0b replace the generic helper with
  macros; H5 renames the crossings for the *handle*; H10 renames `mtk::owned` to
  `mtk::managed`. All four land in the same files. That is **3TK-16**, and it is
  the mirror of 3TK-11 — a ruled proposal, built.
- **One ruling is a specification change and no stage may make it.** E6 ruled
  Part 7.1 a specification defect rather than a port deviation — **V19**, the
  first found since 003 carried V1 to V18. Rewording it touches `../common/`,
  which every stage in plan 008 is forbidden. That is **3TK-17**.

**The order is not the numbering, and this is the one thing to get right.**

```
3TK-16  (code)   →   3TK-15  (the debts)   →   3TK-17  (the specification)
```

**3TK-15 is declared with a lower number and runs third from here.** Plan 008
put it after 3TK-14 because *"A5 repoints doc comments in the files 3TK-14 may
rewrite"*, and its own section already anticipates this exactly: *"if 3TK-14's
proposal has been ruled and built by then, this stage runs on top of the
result."* The proposal has been ruled and **not built**, so the condition is
half-met and the ordering reason is now stronger, not weaker: 3TK-16 **deletes
and rewrites** `helper.c3` and `owned.c3`, and A5's forty doc comments live in
those files. **3TK-15 must not run before 3TK-16.**

**3TK-17 is independent of both** and may run at any point after 3TK-14. It has
one hard scheduling constraint of its own, and it points outside this folder:
**it wants to run before dtk's first stage.** D's idiomatic answer to *generate
code per type* is templates and mixins — call-site expansion, the same shape as
a C3 macro — so Part 7.1 as written sets the identical trap for dtk that it set
for 3tk. Fixing it after dtk starts means a second port re-deriving the same
argument.

**Why the specification was not in 3TK-14, and is now.** Plan 008 said neither
stage may touch `../common/`, and that *if 3TK-14 finds it is about more than
spelling, that is a finding it reports and does not act on.* **It found exactly
that, and reported it.** 3TK-17 is the stage that acts on it. The rule was not
bent; it worked.

Each stage output names the plan version it ran under in its opening line.
Those references are **provenance, not pointers**, and they are not repointed.
The live pointers — the ones in `3tk-status.md` — are.
## Context

Matryoshka is becoming a family of ports, named by language initial + `tk`:  
**otk** (Odin, refactor later), **ztk** (Zig, the current repo, tuning later),  
**3tk** (C3, the active target), **dtk** (D, thinking only).

`design/secondary/lang/c3/` already holds seven `.md` drafts written in separate  
sessions by different AIs. They overlap, they contradict each other, and some  
predate API 12, API 13 and INTR 8. They are raw input, never source of truth.

The gap: there is no statement of what Matryoshka *is* independent of Zig. The  
drafts each invented one. So the first deliverable is a **portable
specification** — self-contained, language-neutral, complete enough that D or  
any other language can be ported from it alone, with `src/polynode.zig`,  
`src/mailbox.zig` and `src/pool.zig` as the only external reference.

Porting is not transpiling. The specification says what a port must preserve;  
each port decides how to spell it idiomatically. ztk's hand-rolled tag is the  
example — in C3 that identifier is native to the language.

## Storage rule — owner's instruction, no exceptions

Every file these stages produce goes under `design/secondary/lang/c3/`: plans,  
status, log, audits, specification, reviews, notes. `design/STATUS.md` and  
`design/STATUS-LOG.md` are not touched. Nothing of substance lives only in  
Claude memory.

## Standing rules for every stage

- **Cold start.** Each stage is self-contained. Its named inputs plus
  [3tk-status.md](3tk-status.md) are enough to run it. No stage depends  
  on conversation carried from the previous one.
- **Clear advice.** Each stage ends with an explicit recommendation — *clear* or
  *do not clear* — and the reason. Clear when the next stage's inputs are  
  disjoint. Do not clear when the reasoning still in context is needed, and say  
  what would be lost.
- **No rolling.** Finishing a stage does not start the next. The owner names it.
- **Every stage carries its start command.** The exact line the owner types to
  run it after a context clear is printed under the stage heading, and repeated
  in [3tk-status.md](3tk-status.md). A stage closes by naming the command for
  the next one. The command names the status file, never a versioned file, so it
  survives every version bump.
- **Nothing authorized by this plan.** Plan approval is not stage approval.
- Terminology: **inner** = the embedded structure, **outer** = the struct that
  embeds it. Never "parent". Applies to all prose in every port.

## How a stage is started

The owner types one line. The agent reads
[3tk-status.md](3tk-status.md) and this file, finds the named stage,
and runs it. Nothing else is needed — that is what cold start means.

The command for each stage is printed under its heading below.

The agent's first three actions in every stage, in order:

1. Read [3tk-status.md](3tk-status.md).
2. Read this file, and the section of the named stage.
3. Read the stage's named inputs. Nothing outside them.

If the stage's row in the status table already reads DONE, stop and say so.
Do not re-run a finished stage without being told.

## The stages

### 3TK-0 — this plan

Write this document. Create [3tk-status.md](3tk-status.md) (current  
state, one screen) and [3tk-log.md](3tk-log.md) (append-only narrative,  
newest first). *Advice on clear: yes, after.*

### 3TK-1 — ztk audit

**Start after clear** — type this, nothing else:

```
Run 3TK-1 from design/secondary/lang/c3/3tk-status.md
```

Read-only evidence gathering. Every claim names a file and a line range.

Inputs: `src/matryoshka.zig`, `src/polynode.zig`, `src/mailbox.zig`,  
`src/pool.zig`, `src/internal/cond_timeout.zig` in full including `///` and  
`//!` comments; then `matryoshka-concepts-003.md`,  
`matryoshka-architecture-foundation-4-006.md`, `language-of-matryoshka.md`,  
`matryoshka-api-reference-042.md`, `patterns-029.md`,  
`matryoshka-zig-0.16-notes-003.md`, `kitchen/docs/addendums/slot-idiom.md`,  
`rules-049.md` Part 3 (the Slot Rule).

Not read: the `c3/` drafts, `STATUS-LOG.md`, the `d/` and `odin/` folders. The  
firewall against the drafts is deliberate — the specification must not inherit  
their contradictions.

Output `ztk-audit-001.md`:

1. The public surface, verbatim: `PolyTag`, `PolyNode`, `ItemHandle`, `Slot`,
   `PolyHelper(T)`, `ItemList` + `Iterator`, `Mbox`, `Pool`, companion types,  
   every signature and error set.
2. The invariants, from the asserts and doc comments: `is_linked`, `reset`, the
   Slot Rule, close-before-destroy, the give-back rule, hook contracts.
3. Essential vs incidental, one row per feature, with a reason. `comptime`,
   `@fieldParentPtr`, error sets, `std.Io`, `defer`/`errdefer`,  
   `std.DoublyLinkedList`.
4. **The excluded surface** — the named declarations that exist only to bridge
   `std.Io`. Enumerated once here so no port re-derives it.
5. **Intended vs actual** — where the owner's direction differs from today's
   code. The allocator is the known case: objects should take an allocator at  
   creation and hold it for life; ztk is not exactly there. Flagged, not fixed.
6. Open questions for any port.
7. Drift noted, not fixed: `design/secondary/context.md` does not list the
   `lang/` subfolders.

*Advice on clear: yes — the specification works from this file, not from the  
reading.*

### 3TK-2 — the portable specification

**Start after clear** — type this, nothing else:

```
Run 3TK-2 from design/secondary/lang/c3/3tk-status.md
```

Output `matryoshka-specification-001.md`. Language-neutral. Zig appears only as  
one realization. Self-contained: the audit and the three `src/` files are the  
only external references. Expected 600-900 lines, one file, numbered parts.

The owner's points are the spine, one section each:

- **Execution model.** Plain OS threads or equivalent. Not fibers, not
  goroutines, not an async runtime. Blocking with timeout is the primitive.
- **Participants are long-lived heap objects**, allocated once, living for the
  duration.
- **Intrusion.** The outer embeds an inner holding the list links, so items
  thread onto type-erased lists with no allocation and no knowledge of the  
  outer type.
- **Identity.** The inner carries a unique identifier of the outer.
- **Self-identification.** Any struct compares its own identity against that
  identifier to decide who is who. This is what makes a type-erased list safe  
  to walk and a received item safe to claim.
- **The per-type helper**, generated at compile time, bound to one outer type:
  the initializer, and the conversions across the type-erased border in both  
  directions, with the identity check.
- **The intrusive list**, holding heterogeneous items on one list.
- **The Slot idiom** — a container of a pointer whose emptiness is the transfer
  signal. Covers transfer and creation both.
- **Deliberate synonyms** — handle, slot, item name one thing under different
  usage stress. Preserved, not collapsed.
- **The two infrastructure objects**, Mbox and Pool, on one internal base, both
  themselves items that can travel, both with hidden implementation where the  
  language allows.
- **Hooks as an interface** — user-supplied callbacks behind a hidden
  implementation, in the language's own interface mechanism.
- **Allocators** — taken at creation, held for the object's life.

Then, from the audit: what Matryoshka is and is not; the three tools and why two  
are optional; the transfer model, one owner at a time; the concurrency contract  
stated without `std.Io`; the excluded surface.

Two devices make the specification usable rather than descriptive:

- **Conformance markings** on every element — **MUST** (remove it and it is not
  Matryoshka), **SHOULD** (shape fixed, spelling is the port's business),  
  **MAY** (convenience, skippable), **EXCLUDED** (exists only because of Zig).
- **The capability questionnaire**, closing the document: the questions a
  language must answer before it can host Matryoshka — compile-time generation  
  over a type; opaque types; interfaces or vtables; embedding and inner-outer  
  address arithmetic; a unique per-type identifier; scope-exit cleanup; threads  
  with condition variable and timeout; an allocator an object can hold for life.  
  Each port answers the same list.

Style: `design/` rules — short sentences, bullets, staccato, the banned-word  
list of `rules-049.md` Part 5.

*Advice on clear: yes, after.*

### 3TK-3 — drafts review

**Start after clear** — type this, nothing else:

```
Run 3TK-3 from design/secondary/lang/c3/3tk-status.md
```

The first stage that opens the seven `c3/` drafts. Each claim is measured  
against the specification and the audit.

Output `3tk-drafts-review-001.md`: one row per claim — which draft, what it  
asserts, whether it holds against current ztk, which other draft it contradicts,  
and a recommendation. Conflicts are reported, not resolved. The owner rules.

*Advice on clear: no — the ruling needs this reasoning in context.*

### 3TK-4 — C3 study

**Start after clear** — type this, nothing else:

```
Run 3TK-4 from design/secondary/lang/c3/3tk-status.md
```

C3 is installed: `c3c` at `/usr/bin/c3c`, stdlib sources at  
`/home/g41797/dev/langs/c3/lib/std/`. No install step.

Read `collections/`, `threads/`, `io/`, `core/`, `os/`, `atomic.c3` and answer  
the capability questionnaire for C3, with a citation per answer. Output  
`c3-capabilities-001.md`.

*Advice on clear: yes, after.*

### 3TK-5 — the 3tk porting proposal

**Start after clear** — type this, nothing else:

```
Run 3TK-5 from design/secondary/lang/c3/3tk-status.md
```

From the specification, the ruled review and the questionnaire answers. Output  
`3tk-porting-proposal-001.md`: the C3 shape of every MUST and SHOULD, the  
mapping table, what is dropped and why, and the build and test approach.  
Idiomatic C3, not transliterated Zig.

*Advice on clear: decided at the time.*

### 3TK-6 — the toolkit, in C3

**Start after clear** — type this, nothing else:

```
Run 3TK-6 from design/secondary/lang/c3/3tk-status.md
```

Added in plan version 002, 2026-08-23, on the owner's instruction.

**The first stage that writes C3.** Steps 2 to 5 of Part 22: the inner and the
identity, the per-type helper with the crossings, the Slot and its six rules,
the list with both insert checks. That is the toolkit of Part 17.1 — the one
required tool, the thing without which there is nothing to port.

The two containers are **not** in this stage. Part 17.2 makes them optional and
Part 22 makes them steps 6 and 7. A separate stage, if the owner names one.

Inputs: `3tk-porting-proposal-001.md` and `matryoshka-specification-001.md`.
The capability study for a spelling that the proposal does not give. The seven
drafts are not reopened; `src/` is not reopened.

**On the sixteen decisions.** The owner instructed this stage to run in the same
breath as adding it, without ruling on them separately. That instruction is read
as acceptance of `3tk-porting-proposal-001.md` as written. The stage implements
the sixteen as ruled, and records in `3tk-log.md` any place where writing the
code contradicted a decision. A decision that survives compilation is a
decision; one that does not is a finding for the owner.

Output, under `design/secondary/lang/c3/3tk/`:

- `project.json` — section 7.1 of the proposal, as written.
- `src/any.c3` — `AnyNode`, `AnyHandle`, `Slot`, the `@check` macro, the fault
  set. D5, D6, D15.
- `src/helper.c3` — `mtk::helper <Type>`, Part 7.2's members, Part 7.4's
  build-time validation.
- `src/owned.c3` — `mtk::owned <Type>`. D3, D10.
- `src/list.c3` — `NodeList` and its iterator, the sixteen operations of the
  proposal's 5.5, both insert checks, the repair, the self-move pair.
- `src/mtk.c3` — the front door.
- `test/` — the tests of the proposal's 7.3 that apply to steps 2 to 5.

**Verification, and it is the stage's spine.** The four builds of the
proposal's 7.2, every one of them, green:

| Build | Flags |
|---|---|
| Safe, unoptimized | default |
| Safe, optimized | `-O3` |
| Fast, unoptimized | `--safe=no -O0` |
| Fast, optimized | `--safe=no -O3` |

The fourth is the one that segfaulted in 3TK-4's Q11 probe. Running it green is
what proves D6 was applied. A stage that reports three builds has not run.

The stage also writes `3tk-toolkit-notes-001.md`: what the code taught that the
proposal did not know, per-decision, and the state of every Part 18 invariant
the toolkit reaches.

*Advice on clear: decided at the time.*

### 3TK-7 — the two containers, in C3

**Start after clear** — type this, nothing else:

```
Run 3TK-7 from design/secondary/lang/c3/3tk-status.md
```

Added in plan version 003, 2026-08-23, on the owner's instruction.

Steps 6 and 7 of Part 22: the mailbox, then the pool with its hooks. Parts
11.3 to 11.12, Part 12, and the waiting rules of Part 2 that the toolkit stage
never reached.

**Both containers, in one stage.** The owner was offered the split — mailbox as
3TK-7, pool as 3TK-8 — and did not take it. The seam stays available: if the
stage runs long, the mailbox is finished and green before the pool is started,
so a stop between them loses nothing.

Inputs: `3tk-porting-proposal-001.md` sections 5.8 to 5.11, `3tk-toolkit-notes-001.md`,
and `matryoshka-specification-001.md` Parts 2, 11, 12, 14, 15 and 19. The
capability study for a spelling the proposal does not give. The drafts are not
reopened; ztk's `src/` is not reopened.

Built on `3tk/` as it stands. **Part 17.2 is a constraint on this stage, not a
remark:** the containers use only the public surface of the core four, and
`run-builds.sh` already treats that as a testable claim.

Output, added to `3tk/`:

- `src/mailbox.c3` — `Mailbox`. Part 11.3 to 11.6, and Part 19.1's outcomes.
- `src/pool.c3` — `Pool`, `PoolHooks`, `GetMode`. Part 11.7 to 11.10, Part 12,
  Part 19.2.
- tests for both, and the concurrency tests of the proposal's 7.3.
- negative programs for the contract violations the containers add.

**The three things this stage must get right**, named here because each is a
MUST that no earlier stage exercised:

1. **D7's wait loop.** The deadline is anchored ONCE, before the loop, and
   every wait is `wait_until` on it. `wait_timeout` recomputes the deadline on
   every call and must not appear anywhere in the port. Part 2.5, invariant 4.
   A test that merely times out will pass on the wrong code; the test must
   provoke repeated spurious wakeups and still time out on schedule.
2. **D6 tier 1 gets its first site.** Part 11.12 — releasing an open container
   — is `always_assert` and aborts in **every** build mode, including
   `--safe=no -O3`. Every existing negative asserts the opposite behaviour in
   fast builds, so this one is a new shape in `run-builds.sh`: abort in all
   four.
3. **Part 12.3.** No lock is held across a call into application code. The pool
   unlocks, calls the hook, and relocks — and the state it read before
   unlocking is stale when it returns.

**Verification.** The same four builds, every one of them, plus the concurrency
tests under whatever sanitizer the toolchain offers. `run-builds.sh` extends by
adding rows to its two arrays; it was written for that.

The stage writes `3tk-containers-notes-001.md` in the same shape as the toolkit
notes: what the code taught, the state of the decisions it exercised, and the
Part 18 invariants it reaches.

*Advice on clear: decided at the time.*

### 3TK-8 — the design review answered, and the hiding question measured

**Start after clear** — type this, nothing else:

```
Run 3TK-8 from design/secondary/lang/c3/3tk-status.md
```

Added in plan version 004, 2026-08-23, on the owner's instruction.

#### Why this is a stage and not a revision

`3tk-porting-proposal-003.md` was produced by a **revision**: a review was
answered, no plan version was cut, and no stage row appeared. This work has the
same input shape and a different output shape. It touches `3tk/src/`, it adds
tests, and it needs one **measured** answer from `c3c` before its central
paragraph can be written. Measurement plus code is stage-shaped, and the
alternative is an unrecorded revision that quietly rewrites the port. So it
gets a row.

The rule the status file states — *a revision that moves a decision has
consequences in `3tk/`; the agent names the source files and stops there* —
is not being bypassed. It is being satisfied in the open: the code work is
named below, it is authorized by this stage, and the four builds have to be
green before the stage closes.

#### Inputs

- [3tk-porting-proposal-addendum-001.md](backup/3tk-porting-proposal-addendum-001.md)
  — five measured facts: four on C3 method binding, one on what C3 refuses to
  hide. Written outside any stage.
  **Folded into proposal 004 by this stage**, after which it moves to `backup/`.
- `3tk-porting-proposal-003-review.md` — the input. 28 numbered items, and
  unlike the previous review it is explicitly about **design and
  implementation**, not prose.
- `3tk-porting-proposal-003.md` — the document under review.
- `3tk/src/` — **read in full.** The previous review was written against the
  proposal text alone and never opened the source, which is why most of its
  findings were text drift rather than defects. This one makes claims about the
  code. Every claim is checked against the code before it is accepted.
- `../common/backup/matryoshka-specification-002.md` Parts 4, 7, 11, 12, 15 — for the
  MUSTs the review's central argument turns on.
- `c3-capabilities-001.md` — Q4 is the measurement D1 was built on, and the
  review's charge is that Q4 asked too few questions.

The drafts are not reopened. ztk's `src/` is not reopened. The specification is
not rewritten — see *What this stage may not do*.

#### What the review claims, and what the code says back

The audit below was performed while this plan version was written, so the stage
starts from evidence rather than from the review's assertions. It is recorded
here because it is the reason the stage's scope is what it is.

**The headline finding is real.** Review §1 and §27: D1 argues that hiding the
container internals necessarily costs Part 11.1's MUST, having weighed only two
shapes — public fields, or `typedef Pool = void`. A third exists:

```
struct Pool { AnyNode node; PoolImpl* impl; }
```

`Pool` is still the type the application names, still embeds `AnyNode`, still
crosses through `mtk::helper{Pool}`, still sits on a `NodeList`. Part 11.1 is
satisfied literally. Only the operational state moves. The review separates two
requirements D1 collapses: **A**, the container is itself an item — which is
what Part 11.1 requires; and **B**, every byte of its state is physically in the
public struct — which is what D1 assumes A implies. The implication is
unproven.

The review does **not** ask for the ruling to be reversed, and neither does this
stage. It asks for the argument to be corrected: public direct representation
chosen as a deliberate tradeoff, not as a limitation imposed by C3 or by
Matryoshka.

**Live, and text-only:**

| Review § | Finding | Where | Verdict |
|---|---|---|---|
| §11 | The Part 4.2 mapping row still reads *"D3 part 2 refuses a third"* | `3tk-porting-proposal-003.md:815` | Live. Section 1 (`:165`–`:174`) already states two-parts-three-fields correctly; only the row kept the old wording |
| §12 | D12 still reads *"D3 already refused a third field in the inner"* | `:710` | Live, same cause |
| §13 | `24 bytes` reads as an invariant in the table row | `:169`, `:815` | Live at `:815` only. `:169` already says "on linux-x64". **No code asserts `sizeof(AnyNode) == 24`** — checked |
| §16 | *"No path takes two locks, so there is no ordering to state"* is timeless where it should be current | `:1171` | Live. True of the code today, over-general as written |

**Already satisfied by the code — these become documented invariants, not
changes.** Each was checked, and the finding is that the port is right and the
document is silent:

| Review § | Claim | What the code does |
|---|---|---|
| §17 | The pre-lock atomic must be a hint only | Already so. `Pool.@closed_fast` and `Mailbox.@closed_fast` are pure early rejections, and every path re-reads `_closed` under the mutex — `pool.c3:233`, `:344` |
| §19 | Never retain a `PoolBucket*` across a hook | Already so, and better than the review assumed. `Pool.put` re-looks-up by identity in `take_back_handle` (`pool.c3:378`) rather than carrying `b` across the unlock; `Pool.get` never uses `b` after unlocking |
| §21 | `close` must not be `destroy` | Already the design. `close` sets the flag and drains; `release` ends the object and tier-1 asserts the close came first — `pool.c3:180`, `mailbox.c3:96` |
| §18 | The hook boundary needs an explicit state contract | Half satisfied. `Pool.put`'s two-Slot design is the caller-side half; the *implementation* contract across unlock/relock is nowhere written down |
| §14 | A stricter `AnyHandle` / `Slot` signature rule | No violation found on a first pass. The stage audits every public signature against the rule and records the result |

One place **does** hold a `PoolBucket*` across a mutex release —
`Pool.get_wait` across `wait_until`, `pool.c3:300`. It is safe: the bucket slice
is allocated once at creation and never reallocated. It is undocumented, which
is the whole of the gap.

**A real defect the review could not see.** Review §20 asks for `Pool.create` to
be transactional, reasoning about a design it thought might exist. Checked
against the code, the defect is real and broader than its framing — **neither**
creation path cleans up after a partial failure:

- `Pool.create`, `pool.c3:158`–`:170`. After `alloc::new_try(a, Pool)!`
  succeeds, a failure in `_mu.init()!`, `_cv.init()!` or `new_array_try(...)!`
  propagates out and **leaks the `Pool` allocation**, plus the mutex and/or the
  condition variable already initialized.
- `Mailbox.create`, `mailbox.c3:78`–`:85`. Identical shape. A failure in
  `_cv.init()!` leaks the `Mailbox` and the initialized mutex.

The duplicate-identity check 003 added runs *before* any allocation, so that
part is already transactional. The allocation sequence is not. This is the
stage's code work.

**Deferred or rejected, with the reason written down:**

- §15, a private `link_front` / `link_back` / `unlink` mutation core.
  **Deferred, not rejected.** Removal is already centralized —
  `unlink_no_repair`, `list.c3:251`, used by `pop_front`, `pop_back` and
  `remove`. The four insert sites (`list.c3:147`, `:160`, `:176`, `:196`) are
  genuinely different shapes, and collapsing them buys less than it costs while
  every test is green. Recorded so a later stage can take it.
- §10, grouping container fields by role. The *comments* are free and the stage
  writes them. The structural grouping waits.
- §7, fixed opaque `char[N]` storage. **Rejected**, for the reasons the review
  itself gives: size and alignment become the public contract.
- §20's appendix restructure and §24's finding classes — deferred by 003
  already, and still deferred. Large edits to arrangement, not to content.

#### Step 1 — the capability measurement, and it runs first

Review §25 asks a question no document in this folder has answered, and D1's
replacement paragraph must not be written on an inference while the compiler is
on the path. Against `c3c` 0.8.3 — the version 3TK-4 measured, and the one every
capability answer in this folder is stated against — answer four questions:

1. Can a **public** struct hold a field whose type is `@private` to the defining
   module?
2. Can external code name that type, assign the field, take its address?
3. Does an incomplete `struct PoolImpl;` embedded **by value** compile with the
   definition private? *Expected no — measure it, do not assume.*
4. Does the fallback of review §26 — `typedef PoolState = void;` plus a private
   cast inside the module — compile and work?

Write the probe as a scratch module, not under `3tk/negative/`: it is a
measurement, not a negative test, and the negative harness judges compile
failure as a result. Keep it out of `run-builds.sh`.

**Four more answers are already measured**, on the owner's question of
2026-08-23, and they are in
[3tk-porting-proposal-addendum-001.md](backup/3tk-porting-proposal-addendum-001.md) —
how C3 binds methods to types. **3TK-8 folds that addendum into proposal 004**
and the addendum then moves to `backup/`. The two that bear on this stage:

- **M3** — a method may be declared on a type from *another* module. So an
  argument that the split representation would force every method into the
  declaring module is wrong, and D1's replacement text must not lean on one.
- **M4** — methods attach to named types and **never to a pointer alias**.
  `alias AnyHandle = AnyNode*` can therefore carry no methods at all, while
  `typedef Slot` can. The asymmetry between handle and Slot in every signature
  in the port is **partly forced by the language**, which is a second leg under
  D5 and the fact the §14 signature rule should be stated with.
- **M5** — **there is no field-level privacy in C3 0.8.3, and `inline` does not
  create one.** A `@private` struct inlined into a public one hides the type
  *name* and nothing else: another module still reads, writes and takes the
  address of every field inside it. `@private` on a field is refused outright.
  Measured on the owner's question of 2026-08-23, six probes.

M5 is the one that changes what D1's replacement text can say. It removes the
last shape that would have hidden the state *without* moving it out of the
object, so the review's dichotomy is now measured rather than assumed: hiding
costs an indirection, and it does **not** cost Part 11.1. D1's rewrite says
that, and says it on a floor of evidence.

**This measurement cannot change the ruling.** D1 stays *public direct
representation*. It decides only which sentence 004 carries: *"a split
representation is possible and is rejected on cost"* if 1 and 2 pass, or
*"possible only through an opaque `void*` and a private cast, and rejected on
cost and on type safety"* if only 4 passes.

#### Step 2 — `3tk-porting-proposal-004.md`

New file, 003's structure exactly. A `What changed in 004` table replaces
`What changed in 003`, which is kept below it — as 003 kept 002's.

**Rewritten:**

- **D1.** The ruling stands. The two-options-therefore-impossible argument is
  replaced by the review §27 form: the split representation preserves Part 11.1
  literally, and it is rejected for the extra pointer, the extra allocation, the
  two-level destruction, the partial-creation state and the indirection. The
  four measured answers from step 1 go in as a subsection. The split shape joins
  the rejected-alternatives list with its real cost — 003's own rule is that a
  rejected alternative stays in the text, *because the reason a thing was chosen
  outlives the choosing*.
- **D1's closing claim.** *"In C3 0.8.3 the only mechanism that delivers it
  costs Part 11.1"* is deleted. Part 11.11 is still skipped; the stated reason
  becomes cost.

  What replaces it, and it is now the owner's ruling rather than a proposal:
  Part 11.11 is skipped because **C3 0.8.3 enforces no field privacy at any
  price** (M5), and the shapes that would hide the state all move it out of the
  object at the cost of an allocation and a lifetime rule per container. The
  port declines to fight the language for a boundary the language will not
  keep. Reachable fields plus a documented convention is the trade, made with
  the price visible.
- **The section 0 / D1 tension, review §9.** The helper border protects the
  *polymorphic representation* boundary. It does not hide container operational
  state. Two different problems, and 003's *"the helper border does the work"*
  overstates what the border does.

**Corrected** — the four text-only rows of the table above.

**Added — a section of implementation invariants.** The highest-value part of
this review, and it costs no code: things the port already does that no document
states, so that a later "improvement" cannot undo them silently. The pre-lock
atomic as a hint that may reject but never authorize; the unlock/relock contract
around hooks and the staleness of everything read before it; the
re-look-up-by-identity rule with `Pool.get_wait` named as the one deliberate
exception and why it is safe; creation as a transaction; `close` is not
`destroy`; and the `AnyHandle` / `Slot` signature rule with the audit result.

**Section 9** records what this stage found in the code, the way 003's section 9
recorded the tier 1 negative that had never compiled.

#### Step 3 — the code

Two files, one defect class. **No decision moves, so no signature moves.**

- `3tk/src/mailbox.c3` — `create` becomes transactional: on any failure after
  the allocation, tear down exactly what succeeded, in reverse order, and free
  the object before propagating. `defer catch` is the natural spelling, and it
  is the mechanism 003 already credits for deleting hand-written cleanup
  (section 3, *"Hand-written cleanup at every exit → `defer`. Q6"*). This is
  003's own tool applied at the one site that forgot it.
- `3tk/src/pool.c3` — the same, plus the bucket array: a failure in
  `new_array_try` frees the `Pool`, the mutex and the condition variable.
- Both — the review §10 field-role comments: item identity, lifetime,
  synchronization, container state. Owner's instruction of 2026-08-23, *"add a
  comment and update the docs"*: since the language will not enforce the
  boundary, the comment **is** the boundary, and it is the one place an
  application author looks. It also makes a future split representation legible
  at no cost.
- `3tk/src/pool.c3` — one comment at `Pool.get_wait`'s `PoolBucket* b`, saying
  why holding it across the wait is safe.

Nothing else in `src/` changes.

#### Step 4 — the tests

The new failure paths need an allocator that fails, which the port does not
have.

**Owner's advice, 2026-08-23: a dedicated test file for the allocators, not an
addition to `common.c3`.** So:

- **`3tk/test/t_alloc.c3`** — new file, and the home for every allocator the
  tests need, now and later. The first two are a **counting** allocator, which
  tracks outstanding blocks, and a **failing** one, which succeeds N times and
  then refuses. Both wrap a real allocator rather than implementing allocation
  themselves.
- The creation-failure tests live there too, beside the allocators they drive:
  `Pool.create` and `Mailbox.create` forced to fail at each allocation point,
  asserting the outstanding count returns to zero.

Why the separate file is right, beyond tidiness. `common.c3` is the shared
fixture — four outer types and their helper instantiations — and **every** test
file reads it. An allocator that fails on purpose does not belong in the fixture
every other test compiles against. And the allocators will outlive this stage:
an arena, a tracking allocator for the concurrency tests, whatever a later
sanitizer stage wants. A file named for the subject is where the second one goes
without a discussion.

**It costs the harness nothing.** `project.json` declares
`"test-sources": [ "test" ]`, so a new file in that folder is picked up with no
edit to `run-builds.sh` and no edit to the project file. Verified.

**The risk, stated before the work starts:** whether
`std::core::mem::allocator` in c3c 0.8.3 can be implemented cleanly by a test
type is unmeasured. Fallback: a fixed-size arena sized to fail at a chosen
allocation, which implements no interface. If neither works, **the fix still
lands** and the untested path is named in section 9 rather than hidden. A stage
that reports a green build over an untested fix has not run.

#### Step 5 — the documents

- `3tk-status.md`, in place: Superseded rows for plan 003 and proposal 003, the
  live pointers moved, the 3TK-8 row added, *Current state* rewritten, and the
  3TK-9 candidate table re-derived — the sanitizer run and the cross-target
  builds are still the top two and are untouched by this stage.
- `3tk-log.md`, appended at the top: what the review claimed, what the code said
  back, the D1 correction, the creation-leak defect, and the four measured
  answers.
- `3tk-porting-proposal-003.md`, `3tk-staging-plan-003.md` and
  `3tk-porting-proposal-003-review.md` move to `backup/` once answered, matching
  what was done with `backup/3tk-porting-proposal-review.md`. Every link naming
  a moved file is corrected to `backup/...` in place, in both directions. **A
  path is not a pointer:** that changes where a file is, never which version is
  named.

#### What this stage may not do

- **It may not move a decision.** D1 to D16 stand as the owner accepted them on
  2026-08-23. This stage corrects an argument. If the measurement or the code
  turns up a reason a decision should move, the stage **stops and says so**.
- **It may not touch `../common/`.** Nothing in this review is a specification
  defect — unlike the last one, which produced specification 002. If the D1 work
  turns one up, that is a separate revision in `common/`, and it is named rather
  than folded in silently.
- **It may not rewrite a finished stage's output.** `3tk-toolkit-notes-001.md`,
  `3tk-containers-notes-001.md`, `c3-capabilities-001.md` and
  `3tk-drafts-review-001.md` record what was true when their stages ran.
- **It may not repoint provenance.** Only the live pointers in `3tk-status.md`
  move.
- **It runs no `git` command.** Moves to `backup/` are file moves. If the owner
  wants them as `git mv`, that is the owner's to run.

#### Verification

1. `3tk/run-builds.sh` — four builds green, exits non-zero on any failure. The
   check count rises by the new tests, and 004's section 7.4 is updated to match
   the new numbers rather than left claiming 59.
2. The capability probe's four answers are quoted in 004 with the `c3c` version
   they were measured against.
3. Every link naming a moved file resolves — each basename resolved against
   where the file actually lives, both directions, as the 2026-08-23
   reorganization did. Zero dangling links after.
4. `kitchen/tools/check_design.sh` is expected to still exit 1, with a slightly
   higher orphan count, for the pre-existing reason in the status file's open
   questions: `design/secondary/context.md` does not list the `lang/`
   subfolders. Not a regression, and not fixed here.

#### Open questions for the owner — all four closed, 2026-08-23

All four were ruled on before the stage started, so 3TK-8 begins with no
question outstanding. They are kept with their answers because the reasons are
part of the design record.

1. ~~**Does the D1 ruling stand?**~~ **Closed by the owner, 2026-08-23:**
   *"I don't like wars with language. If it does not support the feature and I
   need an additional allocation — better not change code, add a comment and
   update the docs."*

   So: **D1's ruling stands, public direct representation, and no code changes
   for the sake of hiding.** The stage corrects D1's *argument* only, adds the
   comment at the boundary, and updates the documents. The `Impl*` split is
   **rejected on the record** — not because it would break Part 11.1, which M5
   and the review both show it would not, but because it buys a feature the
   language will not enforce anyway at the price of an allocation and a lifetime
   rule per container. That reasoning goes into 004's D1 as the ruling's second
   leg, and it is a stronger argument than the one it replaces.
2. **Where do the capability answers live?** Inside 004's D1 is the default.
   Also cutting `c3-capabilities-002.md` would supersede a finished stage output
   and is the more invasive of the two.
3. ~~**Is the failing-allocator test worth building?**~~ **Closed by the owner,
   2026-08-23: build it, in a dedicated file** — `3tk/test/t_alloc.c3`, the home
   for the test allocators rather than an addition to the shared fixture. Step 4
   says why and confirms the harness needs no change.
4. ~~**Does the 003 review move to `backup/`?**~~ **Closed by the owner,
   2026-08-23: yes, move it**, once proposal 004 answers it. Same as the first
   review, which sits at `backup/3tk-porting-proposal-review.md`.

   The condition matters and the stage may not shortcut it: the review moves
   **after** 004 carries everything a current reader needs from it — what it
   claimed, what the code said back, what was accepted, deferred and rejected.
   Until then it is input and it stays live. Nothing is deleted either way.

*Advice on clear: decided at the time.*

### 3TK-9 — the sanitizer run

**Start after clear** — type this, nothing else:

```
Run 3TK-9 from design/secondary/lang/c3/3tk-status.md
```

Added in plan version 005, 2026-08-23, on the owner's instruction.

The gap plan 003 opened and 3TK-7 did not close. It asked for the concurrency
tests "under whatever sanitizer the toolchain offers" and nobody measured what
that was. Three stages later it is the last item on the candidate list that
could still find a defect in the port rather than in a document.

#### Inputs

- `3tk-porting-proposal-004.md` sections 6 and 8.3 — the invariants a sanitizer
  is capable of contradicting, and what the suite already covers.
- `3tk/test/t_concurrency.c3` — the tests that would carry a sanitizer.
- `3tk/run-builds.sh` — the harness, and the question of whether it gains a row.
- `../common/backup/matryoshka-specification-002.md` Parts 12, 14, 15 — the memory and
  locking rules any finding is judged against.

#### What was measured while this plan version was cut

The stage's first step was *measure whether c3c 0.8.3 offers a sanitizer at
all*. It was performed before this plan was written, because the answer decides
whether the stage exists. It does, and it found something.

**c3c 0.8.3 has `--sanitize=address|memory|thread`.** It also has
`--test-noleak`, which discloses that `c3c test` runs a tracking allocator with
leak detection **on by default** — a fact no document in this folder records,
and one that bears on 3TK-8's leak.

**The system's sanitizer runtimes are missing.** `--sanitize=thread` fails at
link: `cannot find /usr/lib64/libtsan.so.2.0.0`. This is **not** a c3c defect —
plain `cc -fsanitize=thread` on a two-line C file fails identically. Fedora
ships the runtimes in separate packages that are not installed.

**clang carries its own, and c3c can be pointed at it.** `--cc <path>` sets the
compiler used as system linker, so:

```
c3c test --safe=yes -O0 --sanitize=thread --cc clang
```

links and runs. **No installation, no root, no change to the machine** — which
is why this route is the stage's, and why the stage does not ask the owner to
install anything.

**And the first run was not clean: ThreadSanitizer reported 4 data races.**

#### The four races, and where they are

**All four are in the test's own hooks. None is in the port.** The frames that
appear in `src/` are `pool.c3:284` and `pool.c3:396` — the two hook call sites,
where the pool has *already unlocked*, exactly as Part 12.3 requires. The
racing writes are `TestHooks.on_get`'s and `TestHooks.on_put`'s counters:

```
t_pool.c3:37   self.gets++
t_pool.c3:38   self.last_get_count = in_pool
t_pool.c3:45   self.puts++
t_pool.c3:46   self.last_put_count = in_pool
```

driven by `t_concurrency.c3`'s three producers and three consumers on one pool.

**The port is right and the test is wrong**, and the contract that says so is
the port's own. Part 12.3, written into `pool.c3`'s `PoolHooks` doc comment as
a contract rather than a warning: *hooks run OUTSIDE the pool's mutex, several
at once on different threads. **A hook that touches shared state protects it
itself.*** `TestHooks` does not. It has been racing since 3TK-7 and every build
was green, because a data race is exactly the defect a test suite cannot see.

That is the finding, and it is worth more than a clean report would have been:
the sanitizer's first act was to prove the hook contract is real by catching
the toolkit's own tests breaking it.

#### The work

1. **Fix `TestHooks`.** The counters become synchronized — an atomic per
   counter, or one mutex in the hook object. The hook is the application in
   these tests, and the fix is what the specification tells an application to
   do. **Do not** "fix" it by holding the pool's lock across the hook: that
   would break Part 12.3 and invert the finding.
2. **Re-run thread.** Expect zero warnings. If any survive, it is a port
   finding and gets the 3TK-8 treatment: audited against the code before it is
   believed.
3. **Run address**, and read what its leak detector says about the whole suite,
   not only the concurrency tests.
4. **Decide the harness question, and record the reasoning.** A sanitizer row
   in `run-builds.sh` costs a hard dependency on clang for a script whose only
   stated requirement is `c3c`. The options are: leave it manual and documented;
   add it conditionally on clang being present; or make it a separate script.
   **Whichever is chosen, `run-builds.sh` must still pass with `c3c` alone.**
5. **Write `3tk-sanitizer-notes-001.md`** in the shape of the toolkit and
   container notes: what was measured, what was found, what it cost, and what a
   later port should copy. `c3c test`'s default leak tracking goes in it.

#### What this stage may not do

- **It may not install anything**, change the system, or require root. The
  clang route exists precisely so it does not have to.
- **It may not relax Part 12.3** to quiet a warning. A hook races because the
  hook is unsynchronized, and that is the application's job.
- **It may not rewrite a finished stage's output**, and it does not touch
  `../common/`.
- It runs no `git` command.

#### Verification

1. `3tk/run-builds.sh` green with `c3c` alone — four builds, 59 checks. The
   stage changes test code, so this is the gate that says it changed nothing
   else.
2. `--sanitize=thread --cc clang`: **zero** warnings, 77 tests passed.
3. `--sanitize=address --cc clang`: clean, and its leak report quoted.
4. Every claim in the notes carries the command that produced it.

*Advice on clear: decided at the time.*

### 3TK-10 — the core redesign, as a proposal

**Start after clear** — type this, nothing else:

```
Run 3TK-10 from design/secondary/lang/c3/3tk-status.md
```

Added in plan version 006, 2026-08-23, on the owner's instruction.

**This stage ends at a document. It does not touch `3tk/src/`.** The change is
larger than 3TK-8 and 3TK-9 together, it removes things the specification
requires, and this folder's habit is that the design is agreed before the code
moves.

**The code is 3TK-11, and the owner confirmed the sequence on 2026-08-23:
proposal first, then code.** 3TK-11 is written into this plan below so the
order is on disk rather than in anyone's memory. It is **declared, not
authorized** — it runs after the owner has ruled on this stage's proposal, not
automatically when this stage ends. *Finishing a stage does not start the next*
applies here as everywhere.

#### The owner's direction, 2026-08-23

Five rulings. They are the input, not a suggestion, and the stage's job is to
work out what they cost and what they change — not to relitigate them.

1. **Drop `Any*` and every inherited ztk name.** The vocabulary becomes
   **Outer / Inner**. `AnyNode` → `Inner`, `AnyHandle` → a handle to one, and
   the `Any` prefix disappears from the port.
2. **Stop reproducing Zig's `DoublyLinkedList`.** No general-purpose list type.
3. **Minimal intrusive containers instead: FIFO for the mailbox, LIFO for the
   pool.**
4. **The mailbox has two FIFOs** — one ordinary, one out-of-band — instead of
   one list with an anchor.
5. **One link, not two.** `next` only. `prev` goes.

The two documents that argued for this arrived in the folder from the owner and
are the stage's reading:

- [3tk-naming-001.md](3tk-naming-001.md) — the Outer/Inner naming proposal, 476
  lines.
- [3tk-to-fifo-lifo-single-001.md](3tk-to-fifo-lifo-single-001.md) — *"Stop
  treating `NodeList` as the center of the design"*, 1058 lines. Eighteen
  sections, and its §7 is the one that asks why `Inner` needs `prev` at all.

**Read them the way 3TK-8 read its review: against `3tk/src/`, not on trust.**
That discipline is what let 3TK-8 confirm five items and reject none blindly,
and it is what will separate what these two get right from what they assume.

#### Inputs

- The two proposals above.
- `../common/backup/matryoshka-specification-002.md` **Parts 4, 8, 11** — the inner,
  the list, the containers. These are what the direction changes.
- `3tk-porting-proposal-004.md` — the design of record. D2, D4, D5, D12, D14 and
  section 6 are the parts most affected.
- `3tk/src/` — `any.c3`, `list.c3`, `mailbox.c3`, `pool.c3`.

#### The four consequences the stage must answer

Named here so a cold session does not have to rediscover them. Each is a real
cost of the direction, not an argument against it.

1. **`NodeList` disappears and most of Part 8 goes with it.** `remove`,
   `insert_after`, `insert_before` and `pop_back` have no home in a FIFO or a
   LIFO. Part 8 is sixteen operations; the stage says which survive, and what
   happens to the Part 18 invariants that only exist to guard the ones that do
   not.
2. **The double-insert guard weakens, and this is the sharp one.** Today
   `is_linked` asks `prev != null || next != null`. With a single link the
   **last item in a queue has `next == null`** and is indistinguishable from an
   item on no queue at all — so the check that catches inserting the same item
   twice fails exactly where it matters. Part 8.9's guard and D12's documented
   blind spot both rest on it. **The stage must choose a mechanism**: a
   self-link, a non-null terminator sentinel, a membership bit, or an explicit
   decision to lose the check and say so. It may not leave this open.
3. **Two FIFOs delete D14's anchor and invariant 22 outright** — a real
   simplification rather than a translation. It raises one question the current
   design never had to answer: **what order `close` hands the two queues back
   in**, since Part 11.6 says the mailbox gives everything back.
4. **This is a specification change, not a port change.** Parts 4, 8 and 11 live
   in `../common/` and **dtk and otk read them**. Either the specification moves
   and every port follows, or 3tk declares a deviation and states why. The stage
   **recommends** and the owner rules; it does not edit `../common/` on its own
   authority.

#### Output

`3tk-core-redesign-proposal-001.md`, in the shape of the porting proposal: the
decisions, the rejected alternatives with their reasons, and a mapping of what
each specification Part becomes. It must contain, at minimum:

- The full name mapping, old to new, every public symbol.
- Which of Part 8's operations survive, and what replaces the rest.
- The answer to consequence 2, with the mechanism chosen and priced.
- The close-order rule for the two FIFOs.
- A recommendation on consequence 4, framed as a question for the owner.
- What it costs: the files that change, and roughly how much of the test suite
  and how many of the negatives are invalidated.

#### What this stage may not do

- **No code.** `3tk/src/`, `3tk/test/` and `3tk/negative/` are read, never
  written. `run-builds.sh` and `run-sanitizers.sh` must still be green
  afterwards, trivially, because nothing was touched.
- **No edits to `../common/`.** It recommends; the owner rules.
- **It may not rewrite a finished stage's output**, and it does not repoint
  provenance.
- It runs no `git` command.

#### Verification

1. Both scripts still green — nothing in `3tk/` changed.
2. Every claim about the current code carries a file and line, as 3TK-8's audit
   did.
3. Every specification Part the direction touches is named, with its marking
   (MUST or SHOULD), so the owner can see what is being given up.

*Advice on clear: clear before starting. Its inputs are disjoint from 3TK-9's.*

### 3TK-11 — the core redesign, in code

**Declared here, not authorized here.** It runs only after the owner has ruled
on 3TK-10's proposal. That is not a formality: 3TK-10 must answer the
double-insert guard and the close-order question, and the shape of this stage
depends on which answers are chosen.

**Start after clear** — type this, nothing else, and only after the ruling:

```
Run 3TK-11 from design/secondary/lang/c3/3tk-status.md
```

**The sequence is fixed and was agreed with the owner on 2026-08-23: the
proposal first, then the code.** 3TK-10 writes no `.c3`; 3TK-11 writes nothing
that 3TK-10 did not rule.

#### Inputs

- `3tk-core-redesign-proposal-001.md` — the 3TK-10 output, **as ruled by the
  owner**. Its decisions are this stage's specification.
- `3tk-porting-proposal-004.md` — still the design of record for everything the
  redesign does not touch. D6's assert tiers, D3's allocators, D7's wait loop,
  D15's faults and section 6's invariants are unaffected by the direction and
  are not reopened.
- `3tk/` as it stands, green.

#### What it does

Rewrites the core in the ruled shape: **Outer / Inner** naming throughout, the
single link, the FIFO and the LIFO, and the mailbox's two queues. Then follows
the consequences out through every file that names what changed — the helper,
the containers, the tests and the negatives.

**It is a rewrite of the core, not a rename pass.** The tests and the negative
programs are written against operations that will not exist, and the honest
expectation is that a good part of both is rewritten rather than adjusted. The
stage says how much when it is done.

#### What it must preserve

The direction changes the core's shape, not the toolkit's promises. Unless
3TK-10 rules otherwise, these still hold and the stage proves it:

- **Part 11.1** — both containers are still items, still embed an inner, still
  travel.
- **Part 12.3** — hooks still run outside the mutex, and 3TK-9's four races stay
  fixed. `run-sanitizers.sh` is part of this stage's gate, not an optional
  extra.
- **Section 6 of proposal 004** — the six implementation invariants, including
  creation as a transaction. A rewrite is exactly where a transactional
  `create` gets quietly lost.
- **The three build-mode rules** — D6's tiers, the four builds, and negatives
  judged compile-separately-from-run.

#### Verification

1. `3tk/run-builds.sh` — four builds green. The check and test counts will move;
   the stage states the new numbers rather than inheriting the old sentence.
2. `3tk/run-sanitizers.sh` — thread and address clean, on the rewritten core.
3. Part 18 re-walked: which invariants survive, which are retired by the
   redesign, and which are new. A redesign that quietly drops an invariant has
   not been finished.
4. `3tk-core-redesign-notes-001.md` — what the code taught, in the shape of the
   toolkit, container and sanitizer notes.

*Advice on clear: clear between 3TK-10 and 3TK-11. The proposal is the input;
the argument that produced it is not.*

### 3TK-12 — the deviation audit

Added in plan version 007, 2026-08-24, on the owner's instruction.

**Declared, not authorized.**

**Start after clear** — type this, nothing else:

```
Run 3TK-12 from design/secondary/lang/c3/3tk-status.md
```

**This stage ends at a document. It touches no code and it does not edit
`../common/`.**

#### Why it exists, stated once so it is not re-derived

`../common/backup/matryoshka-specification-002.md` says of itself: *This document says
what Matryoshka is, without naming a language. It is self-contained. A port is
written from this file alone.* That claim is currently false for 3tk, and it has
been since 3TK-11 ended.

Three facts, and together they are the whole argument:

1. **The specification was written from ztk.** 3TK-2 produced it from
   `../common/ztk-audit-001.md` and the three Zig sources, and 68 of its lines
   are marked *ztk*. Where it describes a mechanism rather than a promise, the
   mechanism it describes is the Zig one — the doubly-linked list, `prev`, the
   out-of-band anchor.
2. **3tk no longer has that mechanism.** R1 to R15 replaced it, and the code is
   green.
3. **dtk and otk read this file and nothing else.** A port started from 002
   today reproduces `prev`, the general list and the anchor, and then needs
   3TK-10 and 3TK-11 run again against it.

**The gap is not recorded anywhere in a form the code can be checked against.**
Proposal 002 §8.1 lists nine Parts, and it is a *forecast* written before the
code existed. 3TK-11 found three of its statements wrong — the stack has five
operations and not six, tier 2 does not reach a fast build, and two `put_all`
tests were converted rather than deleted. **None of those three is a decision;
all three are the kind of detail a specification states as a rule.** That is the
whole reason this stage runs before 3TK-13 rather than inside it.

#### Inputs

- `../common/backup/matryoshka-specification-002.md` — **all of it**, Parts 1 to 22.
  Not the nine Parts §8.1 predicted; the audit's job is to find the ones it did
  not predict.
- `3tk/src/` — the code as 3TK-11 left it, green. **This is the authority.**
  Where the code and any document disagree, the code is what the audit records.
- `3tk-core-redesign-proposal-002.md` — the rulings R1 to R15, and §8.1 as the
  forecast to be checked rather than copied.
- `3tk-core-redesign-notes-001.md` — 3TK-11's three corrections, and its Part 18
  re-walk.
- `3tk-porting-proposal-004.md` — D1 to D16, for the deviations that predate the
  redesign and have nothing to do with it.

#### What it does

Walks the specification Part by Part and records, for each, one of four verdicts
against `3tk/src/`:

- **Conforms.** The port does what the Part says.
- **Deviates, and the specification should move.** The port is right and 002 is
  describing ztk's mechanism as though it were the rule. Names the replacement
  wording.
- **Deviates, and the port should move.** The port drifted, and the fix belongs
  in `3tk/`, not in `../common/`. **A stage that finds none of these has
  probably not looked**, and it says so plainly if that is the honest answer.
- **Not applicable.** EXCLUDED by Part 16, or a MAY the port skipped, with the
  reason.

Every deviation carries: the Part and its **marking**, a file and line in
`3tk/src/`, which ruling caused it — R-number, D-number, or *neither, and it
drifted* — and whether it is **3tk-only** or **every port**.

That last column is the one the next stage consumes, and it is the one a careless
audit collapses. A deviation that is 3tk-only belongs in this folder for ever. A
deviation that binds every port is a specification defect, and 003 carries it.

#### The four traps, named in advance

1. **Copying §8.1 instead of auditing.** The forecast is an input to be checked.
   An audit whose nine rows are §8.1's nine rows has measured nothing, and the
   three corrections 3TK-11 already found are the proof that copying is not
   safe.
2. **Missing the Parts the redesign did not aim at.** `put_all` went, so Part
   11.7's *put a list* and Part 11.8's list-put clause went with it — those were
   forecast. Part 12.5's composite mechanism, Part 9's Slot rules and Part 17.2's
   layering were *not* aimed at and all three are touched by a container surface
   that changed. Walk all 22 Parts.
3. **Reading a promise as a mechanism, or the reverse.** This is the mistake
   that produced the redesign in the first place. Invariant 22 survived because
   the anchor was the mechanism and the ordering was the promise; Part 11.7's
   *one free list per identity* is a mechanism and the pool's silence on order
   is the promise. **Every row states which it is.**
4. **Deciding.** The audit **recommends** and the owner rules. It does not edit
   `../common/`, it does not edit `3tk/src/`, and where it finds a genuine
   question it asks it rather than answering it — the shape 3TK-10 used, and
   the reason eleven questions came back as rulings.

#### Output

`3tk-deviations-001.md`. A table first, so the owner can read the shape in one
screen, then a section per deviation with the evidence.

It must contain, at minimum:

- **Every Part of 1 to 22, with a verdict.** A Part with nothing to say is one
  row saying *conforms*. Completeness is the deliverable; a partial audit is
  worth less than none, because the next reader trusts it.
- **The 3tk-only / every-port split**, for every deviation.
- **A recommendation for 3TK-13's scope**: which Parts 003 rewrites, and which
  stay.
- **What it disagrees with §8.1 about**, listed separately and plainly, as
  3TK-11's notes listed their three corrections.
- **The open questions it will not answer**, including
  [3tk-who-supports-slot.md](3tk-who-supports-slot.md) if the audit finds it
  touches a Part.

#### What this stage may not do

- **No code.** `3tk/src/`, `3tk/test/` and `3tk/negative/` are read, never
  written.
- **No edits to `../common/`.** It measures; 3TK-13 cuts.
- **It may not rewrite a finished stage's output**, and it does not repoint
  provenance.
- It runs no `git` command.

#### Verification

1. `3tk/run-builds.sh` and `3tk/run-sanitizers.sh` still green, trivially,
   because nothing was touched.
2. **Every claim about the code carries a file and line**, as 3TK-8's audit and
   3TK-10's did.
3. **Every one of Parts 1 to 22 appears in the table.** A missing Part is a
   failed stage, not an omission.
4. Every deviation names its marking, so the owner sees whether a MUST or a
   SHOULD is being moved.

*Advice on clear: clear before starting. Its inputs are the specification and
the code, and the argument that produced the redesign is not one of them.*

### 3TK-13 — specification 003

Added in plan version 007, 2026-08-24, on the owner's instruction.

**Declared, not authorized.** It runs only after the owner has ruled on 3TK-12's
audit. That is not a formality: the audit's 3tk-only / every-port split is
exactly what decides this stage's scope, and a cut made before the split is
ruled is a cut made from a forecast.

**Start after clear** — type this, nothing else, and only after the ruling:

```
Run 3TK-13 from design/secondary/lang/c3/3tk-status.md
```

#### Inputs

- `3tk-deviations-001.md` — the 3TK-12 output, **as ruled by the owner**. Its
  every-port rows are this stage's scope, and its 3tk-only rows are explicitly
  out of it.
- `../common/backup/matryoshka-specification-002.md` — the document being revised.
- `3tk-core-redesign-proposal-002.md` §8 — R14, and the forecast, as background
  rather than as scope.

#### What it does

Writes `../common/matryoshka-specification-003.md`. **This is the first stage of
this plan that writes into `../common/`**, and that is the whole of its risk:
the file binds dtk and otk, and neither has a stage running to catch a mistake.

R14 is already ruled — this is a specification move, not a 3tk deviation — so
the stage does not relitigate it. What it decides is only the wording.

#### What it must preserve

- **The document's own claim about itself.** *A port is written from this file
  alone.* If 003 leaves any Part describing a mechanism that only ztk has, the
  claim is still false and the stage has not finished.
- **The ztk lines stay marked ztk.** 68 lines carry that marker. A Part whose
  rule moves keeps its *ztk* line, because the realization did not change — ztk
  still has `prev`. **Part 11.11 already has the shape for this**: it says in
  its own words that a port can be *better* than ztk, not merely different.
- **The conformance markings.** A MUST that becomes a SHOULD, or the reverse, is
  a decision and needs a ruling, not a stage's judgment.
- **Part 18's row count is not a target.** 3TK-11 retired one invariant and added
  one; the stage records what is true, not what keeps the number.
- **The change log at the end**, in the shape 002 used: what moved and why, so
  the next port can see what a reader of 002 would have got wrong.

#### What this stage may not do

- **No code.** `3tk/` is not touched.
- **It does not touch `../d/` or the Odin folder.** Telling dtk and otk that
  their input moved is a separate piece of work and the owner names it.
- **It may not carry a 3tk-only deviation into `../common/`.** That is the
  failure mode the audit's split exists to prevent.
- It runs no `git` command.

#### Verification

1. Every Part the audit marked *every port* is rewritten, and no Part it marked
   *3tk-only* is.
2. `3tk/run-builds.sh` still green — nothing in `3tk/` changed.
3. **A reader can find every difference from 002 in the change log**, without
   diffing the two files.
4. 002 goes to `../common/backup/`, and every link naming it is corrected in
   place, both directions — the rule this folder already uses.

*Advice on clear: clear between 3TK-12 and 3TK-13. The audit is the input; the
walk that produced it is not.*

### 3TK-14 — the helper surface, re-thought

Added in plan version 008, 2026-08-24, on the owner's instruction.

**Declared, not authorized.**

**Start after clear** — type this, nothing else:

```
Run 3TK-14 from design/secondary/lang/c3/3tk-status.md
```

#### Why it exists

`3tk/src/helper.c3` is a generic module parameterized on the outer type. It
carries eight functions and two constants, and **an application reaches them
through one alias per operation**. `3tk/test/common.c3` carries **seventeen
alias lines** to use four types. Every new application type repeats the bundle
before it can call anything.

The shape is conformant — Part 7.2 asks for the members and Part 7.1 says the
spelling is the port's business — so **this is not a defect and no rule requires
the change.** It is the first stage in this line whose subject is the *surface*
rather than the semantics, and the owner named it.

**A second question rides along**: `mtk::owned` is a second generic module over
the same type, carrying `create` and `release` — Part 7.3's optional half. If
the helper's shape changes, `owned`'s relationship to it is the obvious next
question, and the stage answers it or says plainly why not.

#### Inputs

- [3tk-helper-alternatives.md](3tk-helper-alternatives.md) — **from the owner.
  Not produced by any stage, not versioned by this folder, and it is advice, not
  a ruling** — the same standing as `3tk-naming-001.md` had for 3TK-10. **Read
  the whole of it, including its own correction near the end**, which withdraws
  its first and favourite proposal. See the traps below.
- `3tk/src/helper.c3` and `3tk/src/owned.c3` — the code as it stands.
- `3tk/test/common.c3` — the alias bundle, and the measurement of what the
  surface actually costs a caller.
- `../common/matryoshka-specification-003.md` **Part 7** in full, and Parts 6.3,
  9.9 and 10.1 — what the helper must carry, and which names are load-bearing.
- `3tk-porting-proposal-004.md` — D4's one-handle ruling and D10's two-generic-
  modules ruling. **Both are rulings and this stage does not reopen them without
  saying so.**
- `c3-capabilities-001.md` — 3TK-4's measurements. Q1 and Q12 are the relevant
  ones and **they were measured, so they are evidence, not opinion.**

#### What it does

**Measure first, design second.** That order is the stage.

1. **Measure what C3 actually allows**, with the compiler, on this machine —
   c3c 0.8.3, `/usr/bin/c3c`, stdlib at `/home/g41797/dev/langs/c3/lib/std/`.
   The alternatives note asks three questions it could not answer itself:
   - Can a generic module declare a method on its own type parameter —
     `fn void Type.init()` inside `module mtk::helper <Type>`? **The note
     proposes this, then corrects itself and says it probably does not work.**
   - Can an instantiated generic module be aliased as a namespace —
     `alias MsgHelper = mtk::helper{Msg}` — so one declaration replaces eight?
   - What does the diagnostic look like when each fails?

   **Each answer is a compiled program that ran, with its output quoted.** A
   scratch directory outside `3tk/`, and it is deleted or left unbuilt; the
   stage adds no file to `3tk/` that `run-builds.sh` does not know about.
2. **Then propose a surface**, from what compiled rather than from the note's
   ranking. The note's own order is 1) methods on `Type`, 2) one namespace
   alias, 3) many aliases as today — and its correction says option 1 is
   probably unavailable, which would make option 2 the real proposal.
3. **Answer the questions the note raises that are not about syntax at all**,
   because these are the ones that outlive whichever spelling wins:
   - **Should `OFF` and `TYPE` be public?** The note argues that exporting `OFF`
     hands application code the address arithmetic Part 7.5 MUST confines to the
     helper — `(Msg*)((char*)h - MSG_OFF)` — and that `is_mine` is the public
     form of `TYPE`. `MSG_OFF` is aliased in `test/common.c3` today. **Part 7.5
     is a MUST and this is the one item in the note that touches conformance
     rather than taste.**
   - **`inner` or `handle` in public names?** The note prefers `to_handle` /
     `from_handle`, reserving *inner* for implementation. **Part 10.1 fixes
     four words and gives each a job**, and *handle* is already one of them —
     so this is a question about which of two defined words a signature should
     use, not an invention. Check it against Part 10.1 before agreeing.
   - **`move_from_slot` should validate before it consumes.** The note observes
     that peeking, checking and then calling `take()` is more auditable than
     taking and then subtracting, and that it does not depend on `take()`
     returning what `peek()` saw. **Check the current code before reporting
     this**: it may already do it, in which case the row is *conforms* and says
     so.
   - **`must_from_inner`'s two failure cases.** Null and wrong-type both fail
     one `@check` today. Separating them costs a check and buys a diagnostic.
     Part 15.5's tiers decide it.
4. **Answer the `owned` question**, or record why it stays shut.

#### The traps, named in advance

1. **Treating the note as a specification.** It is one reader's opinion,
   written without running the compiler, and **it contradicts itself on
   purpose** — the *Important correction* section withdraws the design the
   *My ranking* section calls its clear favourite. A stage that implements the
   ranking without reading the correction has implemented something that does
   not compile.
2. **Designing before measuring.** Every one of the note's three shapes rests on
   a C3 capability question it did not test. 3TK-4 is the model: measure, quote
   the compiler, then argue.
3. **Confusing surface with semantics.** Part 7.2's seven members are a MUST.
   Renaming them is spelling; dropping one is a rule change and this stage does
   not make rule changes.
4. **Quietly reopening D4 or D10.** Both are the owner's rulings. If the best
   surface needs one of them moved, **the stage says so as a question** and does
   not answer it — the shape 3TK-10 used, and the reason eleven questions came
   back as rulings.
5. **Touching `../common/`.** Not this stage, and not the next one either.

#### Output

`3tk-helper-proposal-001.md`. A proposal, in the shape 3TK-10's was: numbered
items, each one accept-or-reject on its own, so the owner rules them one at a
time.

It must contain:

- **The compiler measurements first**, with the exact source, the exact command
  and the exact output. A claim about C3 without a quoted compiler run is an
  opinion and is marked as one.
- **The proposed surface**, with a before-and-after of `test/common.c3`'s
  seventeen alias lines. That file is the honest measure of what the change
  buys.
- **The conformance check.** Every one of Part 7.2's members, present in the
  proposed surface, named. Plus Part 7.5 against the `OFF` question.
- **The cost.** How many call sites move, across `src/`, `test/` and
  `negative/`. `run-builds.sh`'s 59 checks include layering checks that read
  these names.
- **The questions it will not answer**, including anything that touches D4, D10
  or a Part 7 MUST.

#### What this stage may not do

- **No change to `3tk/src/`, `3tk/test/` or `3tk/negative/`.** It is a proposal.
  The code stage is separate and the owner names it.
- **No edits to `../common/`.**
- It may not rewrite a finished stage's output, and it does not repoint
  provenance.
- It runs no `git` command.

#### Verification

1. `3tk/run-builds.sh` and `3tk/run-sanitizers.sh` still green, trivially —
   nothing was touched. Both now take an optional directory; with no argument
   they behave as they always did.
2. **Every claim about C3 carries a compiled program and its output.**
3. **Every claim about the port carries a file and line**, as 3TK-8, 3TK-10 and
   3TK-12 did.
4. Every one of Part 7.2's members is accounted for in the proposed surface.

*Advice on clear: clear before starting. Its inputs are the note, the code and
Part 7, and none of the argument that produced 003 is one of them.*

### 3TK-15 — the two debts of 3TK-13

Added in plan version 008, 2026-08-24, on the owner's instruction.

> **Amended in 009, 2026-08-24. The section below is unaltered; this note is the
> amendment.** 3TK-14 ran and ended at a proposal, so *"it runs after 3TK-14"* is
> satisfied on its face and **misleading**. This stage now runs **after
> 3TK-16**, which builds 3TK-14's ruled result. The section's own *What this
> stage may not do* already says the right thing — *"if 3TK-14's proposal has
> been ruled and built by then, this stage runs on top of the result"* — and
> that is the clause to read, not the ordering sentence below. **3TK-16 deletes
> and rewrites `helper.c3` and `owned.c3`; A5's forty doc comments live in those
> files.**

**Declared, not authorized. It runs after 3TK-14**, because A5 repoints doc
comments in the files 3TK-14 may rewrite.

**Start after clear** — type this, nothing else:

```
Run 3TK-15 from design/secondary/lang/c3/3tk-status.md
```

#### Why it exists

3TK-13 was a documents stage and recorded two things it could not do. Both were
**already decided**; neither is a question. They are gathered here so they are
paid explicitly rather than drifting.

#### A3 — the port breaks a MUST in its own specification

**`3tk/src/pool.c3:288-290`. Part 19.3 MUST, and 3TK-12's finding P2.**

`Pool.get` asked for an identity the pool was not created with returns
`NOT_AVAILABLE` — from **every** mode, including new-only. Part 19.3 says
not-available comes **only** from the available-only mode. The `@check` above
the return catches it in a checking build, but under `--safe=no` a `@check`
expands to nothing — that is D6 — so the fault is the observable behaviour of a
fast build.

**The ruling is assumption A3 of 3TK-13, and it is recorded in specification
003's change log**: *the port reports a distinct outcome*, Part 19.3 keeps its
MUST, and `../common/` is not touched. The three candidate answers were weighed
by 3TK-12 and this is the one taken; the stage implements it and does not
re-argue it.

What it does:

- A distinct outcome for *an identity this pool does not serve*, added to the
  port's fault set.
- **`get_wait` at `pool.c3:359-360` has the same shape and is benign today** —
  `b` stays null, the loop finds nothing, the call times out, and Part 19.2
  allows a timeout there. The stage decides whether it changes too, and says
  why either way.
- A test that fails without the change.
- Every Part 19 outcome the port can now produce, still inside 19.1 and 19.2.

#### A5 — about forty doc comments cite a superseded document

`3tk/src/` cites `matryoshka-specification-002.md` in roughly forty doc
comments. 002 was superseded on 2026-08-24 and moved to `../common/backup/`.
Nothing breaks and no rule those comments rely on changed meaning — they are
stale pointers to an old edition, and 3TK-13 deferred them deliberately so a
documents stage was not buried in forty comment edits.

What it does:

- Repoint every one to `../common/matryoshka-specification-003.md`.
- **Where 003 changed the rule the comment cites, fix the comment's claim too.**
  This is the part that is not mechanical, and it is the reason this is a stage
  rather than a `sed`. The Parts that moved are listed in 003's change log:
  4.2, 6.5, 8.1, 8.2, 8.6, 8.7, 11.2, 11.3, 11.7, 11.8, 12.2, 12.3, 12.5, 18,
  19.1, 19.2, 20, 21 and 22. **A comment citing Part 8.6 is citing a deleted
  Part** and must say what replaced it.
- Leave `3tk-status.md`'s and the log's historical mentions alone. Those are
  provenance.

#### What this stage may not do

- **No edits to `../common/`.** A3's whole point is that the specification is
  right and the port is wrong.
- No surface redesign. That was 3TK-14, and if 3TK-14's proposal has been ruled
  and built by then, this stage runs on top of the result.
- It runs no `git` command.

#### Output

`3tk/` changed, plus `3tk-debts-notes-001.md` — short. What the new outcome is
called, what `get_wait` does and why, and which doc comments changed a claim
rather than a path.

#### Verification

1. `3tk/run-builds.sh` green, and the count is **at least 59**; a new test
   raises it.
2. `3tk/run-sanitizers.sh` green, 3 checks.
3. **A test that fails with the A3 fix removed.** The same standard 3TK-12's P1
   repair was held to.
4. **No occurrence of `matryoshka-specification-002` remains in `3tk/src/`,
   `3tk/test/` or `3tk/negative/`.** One grep, and it is the whole of A5's
   check.
5. Part 19.3 read against `pool.c3` and reported as conforming.

*Advice on clear: clear before starting. Both halves are written down here and
in 003's change log; the conversation that produced them is not needed.*

### 3TK-16 — the helper surface, in code

Added in plan version 009, 2026-08-24, on the owner's instruction.

**Declared, not authorized.** It runs only on the rulings 3TK-14 already
carries, and it makes none of its own.

**Start after clear** — type this, nothing else:

```
Run 3TK-16 from design/secondary/lang/c3/3tk-status.md
```

#### Why it exists

3TK-14 ended at a proposal and the owner ruled every item on 2026-08-24. **Four
accepted items change code and nothing has carried them there.** This is the
mirror of 3TK-11, which built 3TK-10's ruled proposal — the same sequence, and
for the same reason: the proposal is the specification of this stage, and this
stage writes nothing the proposal did not rule.

**They are one stage and not four because they land in the same files.** H0
rewrites `helper.c3` entirely, H0b rewrites `owned.c3` entirely, H5 names their
members, H10 renames the file and the module. Splitting them means rewriting the
same two files three more times.

#### Inputs

- **[3tk-helper-proposal-001.md](3tk-helper-proposal-001.md) — the 3TK-14
  output, as ruled by the owner. Its accepted items are this stage's
  specification and are not re-argued.** Read Part B0 (H0, H0b), H5, H10 and
  **Part F** (E6 and E7, ruled). Parts A and A2 are the measurements behind
  them — read them for the working code, which is quoted, and for the traps.
- `3tk-porting-proposal-004.md` — still the design of record for everything the
  helper does not touch. **D4, D5, D6, D3 are unaffected.** D10 is touched in
  its *spelling only*, by H0b, and that is already ruled.
- `../common/matryoshka-specification-003.md` — **Part 7 in full**, and Parts
  6.3, 10.1, 15.5. Part 7.1 is the one E6 says is wrong; **this stage does not
  fix it and does not obey it either.** See *the trap* below.
- `3tk/` as it stands, green.
- `3tk-deviations-001.md` — for the row vocabulary only. **S/V = specification
  defect, `every port`. P = port defect, `3tk-only`.** V1 to V18 are consumed by
  003; E6's row is **V19**.

#### What it does

**Four accepted items, and three rows of bookkeeping.**

1. **H0 — `mtk::helper` becomes an ordinary module of macros.** Part 7.2's
   members as macros over `$Type`, plus `to`, `as`, `must` and `move` as macro
   methods on `Handle` and `Slot`. **No application writes an alias for any
   type.** The working source is quoted in the proposal's M11 and M12; it
   compiled and ran.
2. **H0b — `mtk::owned` follows**, as macros, composing the helper through the
   module rather than through an instantiation.
3. **H5 — the crossings are named for the handle.** `to_handle`,
   `from_handle`, `must_from_handle`, `is_mine`. `inner` keeps `Inner`,
   `inner_offset`, `src/inner.c3` and the prose, and stops naming a handle.
4. **H10 — `mtk::owned` becomes `mtk::managed`**, `owned.c3` becomes
   `managed.c3`, and the test fixture `struct Owned` becomes `struct Holder`.
   **The module's header carries one sentence disarming the GC reading**, aimed
   at the D and C# reader — the proposal gives the wording.
5. **E7's sentence**, in the same header: the owning distinction lives at the
   call site, and D10 is why.
6. **Two rows in `3tk-deviations-001.md`**: **V19** for Part 7.1, scope
   `every port`; and Part 7.3's row updated from *two generic modules* to *two
   modules*. **These are the only edits this stage makes to a finished stage's
   output, and they are additive rows in the audit's own vocabulary, not a
   rewrite of its findings.**
7. **One line of `run-builds.sh`** — the `nocompile_owned_no_allocator` key, if
   the file is renamed with the module, which the proposal advises. **Measured:
   the expectation *string* `mtk::helper` survives the rename untouched.**

#### The trap, named in advance

**Part 7.1 will be wrong while this stage runs, and the stage must not obey it
or fix it.** E6 ruled it a specification defect — V19 — and 3TK-17 is the stage
that rewords it. This stage builds the ruled surface, records V19 in the audit,
and leaves `../common/` alone. **A stage that "conforms" to a Part its own
folder has ruled defective has un-ruled a ruling.**

The second trap is the one 3TK-11 wrote down and paid for: **rename on word
boundaries, and read the diff.** A blind pass turned `remove_from_anywhere` into
`remove_from_innerwhere`. This stage renames on three axes at once — `owned` →
`managed`, `Owned` → `Holder`, `inner` → `handle` in member names only — and
`inner` is the dangerous one, because it must survive in `Inner`,
`inner_offset` and `src/inner.c3`.

#### What it may not do

- **No edits to `../common/`.** That is 3TK-17.
- **It re-opens no ruled item.** H1, H2 and H3 are withdrawn; H4, H6, H8 and H9
  are settled or forced by H0; H7 stands as recommended. If the code finds a
  ruling unbuildable, **it stops and reports** — it does not choose a different
  answer.
- **It does not do 3TK-15's work.** A5's doc-comment repointing is the next
  stage. This stage writes correct comments in the files it rewrites and leaves
  every other file's stale `002` citation alone.
- It runs no `git` command.

#### Output

`3tk/` changed, plus `3tk-helper-notes-001.md` — what the code taught, in the
shape of the toolkit, container, sanitizer and redesign notes. It says at
minimum: how many call sites actually moved against the proposal's estimate,
what the alias count fell to in each of `test/`, `negative/` and `src/`, and
anything the compiler refused that the proposal's scratch measurements did not
meet.

#### Verification

1. `3tk/run-builds.sh` — four builds green, and **the check count is stated, not
   inherited**. It was 59; a renamed negative keeps it at 59, and the stage says
   so explicitly rather than repeating the old sentence.
2. `3tk/run-sanitizers.sh` — thread and address clean, 3 checks.
3. **The test count is stated.** It was 85. H0 removes no test.
4. **Part 7.2 re-walked**: all nine members present in the new `helper.c3`, named.
5. **Zero `alias` lines naming `mtk::helper` or `mtk::managed`** anywhere in
   `src/`, `test/` or `negative/`. That is H0's whole claim and it is one grep.
6. The three `nocompile_*` negatives still refuse, and their messages still name
   the offending type.

*Advice on clear: clear between 3TK-14 and 3TK-16. The ruled proposal is the
input; the argument that produced it is not, and it is long.*

### 3TK-17 — Part 7.1 reworded, and specification 004

Added in plan version 009, 2026-08-24, on the owner's instruction.

**Declared, not authorized.** **It is the first stage in this line permitted to
edit `../common/`**, and it is scoped to one Part.

**Start after clear** — type this, nothing else:

```
Run 3TK-17 from design/secondary/lang/c3/3tk-status.md
```

#### Why it exists

**E6, ruled 2026-08-24: Part 7.1 states ztk's mechanism where the design has
only a promise.** Of its three clauses only *"for each outer type there is a
helper bound to that one type"* fails under a macro port, and Part 7.1's own
closing sentence already sets the floor lower — *a port with no compile-time
generation writes the same block by hand for each type, and loses only the
typing.*

**This is the disease 3TK-13 existed to cure.** 002 was written from ztk and
stated Zig's mechanism as the rule in fourteen places; 003 fixed fourteen and
carried V1 to V18. **Part 7.1 is the fifteenth, and 3TK-13 walked past it** —
the sentence reads like a requirement, and only a port that answers the question
a different way exposes it as a mechanism. 3tk is that port. **V19 is the first
specification defect found since 003, and it was found by building, not by
auditing.** That is worth one paragraph in the change log.

#### The scheduling constraint, and it points outside this folder

**Before dtk's first stage.** dtk has a prepared folder and no stage has run —
[../d/dtk-status.md](../d/dtk-status.md). D's idiomatic answer to *generate code
per type* is templates and mixins: call-site expansion, the same shape as a C3
macro, **not** a per-type struct. Part 7.1 as written sets dtk the identical
trap it set 3tk. Fixing it afterwards means a second port re-deriving this
argument from cold.

#### Inputs

- **[3tk-helper-proposal-001.md](3tk-helper-proposal-001.md) Part F — E6, ruled.**
  That is this stage's specification and it is not re-argued.
- `../common/matryoshka-specification-003.md` — **Part 7.1**, and its change log,
  which is the model for how a V is recorded.
- `3tk-deviations-001.md` — the **V19** row, written by 3TK-16.
- `3tk/src/helper.c3` **as 3TK-16 leaves it**, as the *3tk* realization to show.
  **If 3TK-16 has not run, this stage may still run** — the realization is
  quoted in the proposal's M11 and M12 and it compiled. The stage says which
  source it used.

#### What it does

- **Rewords Part 7.1 to state the promise**, and shows both realizations marked
  *ztk* and *3tk*, exactly as 003 did for the other fourteen. The promise, as
  E6 states it: for each outer type the crossings exist, specialized to that
  type, generated rather than hand-written, with the identity and the crossings
  together. **A named per-type object is one realization of that and not the
  rule.**
- **Part 7.2, 7.4 and 7.5 are not touched.** The members are a MUST and they are
  unaffected; H0 carries all nine.
- **A change-log entry in the shape 003 uses**, naming V19, what 002/003 said,
  and what 004 says instead.
- **Every link naming 003 is corrected in place, both directions**, and 003 goes
  to `../common/backup/`. The folder's rule, and 3TK-13's precedent.
- **Tells the other ports.** 003's precedent: 3TK-13 wrote one paragraph into
  `../d/dtk-status.md` and that was the whole of what it was permitted outside
  `../common/`. This stage does the same, and **says plainly whether otk was
  told** — 3TK-13 did not tell it, recorded that it did not, and left it to the
  owner. That question is still open and this stage does not close it silently.

#### What it may not do

- **One Part.** It is not a specification revision. If it finds a second defect,
  **it reports it and does not fix it** — that is the rule that produced V19 in
  the first place, and it worked.
- **No code.** `3tk/` is not touched. `run-builds.sh` and `run-sanitizers.sh` are
  green trivially and the stage says so.
- It runs no `git` command.

#### Output

`../common/matryoshka-specification-004.md`, with 003 in `../common/backup/`.

**The cost, stated so it is not a surprise: a whole specification version for one
Part.** The folder's versioning rule is *every change makes a new file*, and the
specification is on that list. If other specification changes are wanted, **004
is the cheap moment to batch them** — but none are known: V1 to V18 are consumed
by 003, and V7b was recorded-not-fixed deliberately. The stage checks that this
is still true before cutting 004, and reports what it found.

#### Verification

1. **Part 7.1 states a promise and no mechanism**, and a reader of it cannot
   tell which language the port is in until the *ztk* and *3tk* lines.
2. **Every difference from 003 is in the change log**, so nothing needs diffing.
   003's own standard.
3. **No Part renumbered and no invariant row renumbered.** 003's rule, and
   roughly forty doc comments depend on it.
4. Every link naming 003 corrected, both directions; nothing dangling.
5. `3tk/` untouched and green.

*Advice on clear: clear before starting. Its inputs are E6's ruling, Part 7.1 and
003's change log — none of the argument that produced the ruling is one of them.*

## Versioning of the files in this folder

Part 0 of `rules-049.md` forbids overwriting a doc. `design/` exempts two stable
entry points — `STATUS.md` and `context.md` — and edits them in place. This
folder uses the same three-way split. Owner's ruling, 2026-08-23.

Edited in place, no suffix. Entry points, not documents:

- [3tk-status.md](3tk-status.md) — current state. Rewritten every stage.
- [3tk-log.md](3tk-log.md) — the narrative. Append-only, newest first.

Versioned, suffix required. Every change makes a new file:

- this plan — `3tk-staging-plan-NNN.md`, currently **009**. *(008 and 007 both
  carried this line reading `currently 007`. It was stale in both; corrected
  here.)*
- `ztk-audit-NNN.md`
- `matryoshka-specification-NNN.md`
- `3tk-drafts-review-NNN.md`
- `c3-capabilities-NNN.md`
- `3tk-porting-proposal-NNN.md`
- `3tk-core-redesign-proposal-NNN.md`
- `3tk-deviations-NNN.md`

A superseded version stays on disk. It is listed in the Superseded section of
[3tk-status.md](3tk-status.md), naming what replaced it, and every reference to
it is repointed. Nothing here is deleted.

The plan is versioned, so its filename moves. That is why the start command
names [3tk-status.md](3tk-status.md) instead: the status file always says which
plan version is current, and the line the owner types never changes.

The seven pre-existing drafts keep their unsuffixed names. They are frozen
input, and renaming them is a `git mv`, which is owner-only.

## Verification

- Stages 1-5 modify nothing outside `c3/`. No kitchen gate applies.
- 3TK-6 to 3TK-9 write C3 under `c3/3tk/`. Still inside `c3/`, so the
  storage rule holds and no kitchen gate applies. `src/` at the repository root is the
  ztk Zig source and is not touched by any stage of this plan.
- Every stage from 3TK-6 on ends with `3tk/run-builds.sh` green. Four builds,
  no exceptions. A stage that reports three has not run.
- `kitchen/tools/check_design.sh` covers `design/`; run it once after 3TK-2 to
  confirm the additions under `secondary/` changed nothing. Expected exit 0 —
  and it exits 1, for a cause that predates this line of work. The status file's
  open questions carry it. Not a regression, and no stage of this plan fixes it.
- Each stage ends with its file written under `c3/`, a row appended to
  [3tk-log.md](3tk-log.md), [3tk-status.md](3tk-status.md)  
  updated, a report to the owner, and the clear-or-not advice.
