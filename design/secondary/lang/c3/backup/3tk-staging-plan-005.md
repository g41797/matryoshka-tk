# Staging plan — the Matryoshka portable specification and the 3tk port

This file is the plan of record for the 3tk line of work.

Approved by the owner, 2026-08-23.

**Version 005.** It supersedes `3tk-staging-plan-004.md`, and that one 003,
002 and 001. All stay on disk, in `backup/`. The only change in 005 is the
addition of **3TK-9**, on the owner's instruction of 2026-08-23. Stages 3TK-0 to
3TK-8 are reproduced unaltered — they are done, and a plan version does not
rewrite history.

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
  [3tk-status.md](../3tk-status.md) are enough to run it. No stage depends  
  on conversation carried from the previous one.
- **Clear advice.** Each stage ends with an explicit recommendation — *clear* or
  *do not clear* — and the reason. Clear when the next stage's inputs are  
  disjoint. Do not clear when the reasoning still in context is needed, and say  
  what would be lost.
- **No rolling.** Finishing a stage does not start the next. The owner names it.
- **Every stage carries its start command.** The exact line the owner types to
  run it after a context clear is printed under the stage heading, and repeated
  in [3tk-status.md](../3tk-status.md). A stage closes by naming the command for
  the next one. The command names the status file, never a versioned file, so it
  survives every version bump.
- **Nothing authorized by this plan.** Plan approval is not stage approval.
- Terminology: **inner** = the embedded structure, **outer** = the struct that
  embeds it. Never "parent". Applies to all prose in every port.

## How a stage is started

The owner types one line. The agent reads
[3tk-status.md](../3tk-status.md) and this file, finds the named stage,
and runs it. Nothing else is needed — that is what cold start means.

The command for each stage is printed under its heading below.

The agent's first three actions in every stage, in order:

1. Read [3tk-status.md](../3tk-status.md).
2. Read this file, and the section of the named stage.
3. Read the stage's named inputs. Nothing outside them.

If the stage's row in the status table already reads DONE, stop and say so.
Do not re-run a finished stage without being told.

## The stages

### 3TK-0 — this plan

Write this document. Create [3tk-status.md](../3tk-status.md) (current  
state, one screen) and [3tk-log.md](../3tk-log.md) (append-only narrative,  
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

- [3tk-porting-proposal-addendum-001.md](3tk-porting-proposal-addendum-001.md)
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
[3tk-porting-proposal-addendum-001.md](3tk-porting-proposal-addendum-001.md) —
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

## Versioning of the files in this folder

Part 0 of `rules-049.md` forbids overwriting a doc. `design/` exempts two stable
entry points — `STATUS.md` and `context.md` — and edits them in place. This
folder uses the same three-way split. Owner's ruling, 2026-08-23.

Edited in place, no suffix. Entry points, not documents:

- [3tk-status.md](../3tk-status.md) — current state. Rewritten every stage.
- [3tk-log.md](../3tk-log.md) — the narrative. Append-only, newest first.

Versioned, suffix required. Every change makes a new file:

- this plan — `3tk-staging-plan-NNN.md`, currently 005
- `ztk-audit-NNN.md`
- `matryoshka-specification-NNN.md`
- `3tk-drafts-review-NNN.md`
- `c3-capabilities-NNN.md`
- `3tk-porting-proposal-NNN.md`

A superseded version stays on disk. It is listed in the Superseded section of
[3tk-status.md](../3tk-status.md), naming what replaced it, and every reference to
it is repointed. Nothing here is deleted.

The plan is versioned, so its filename moves. That is why the start command
names [3tk-status.md](../3tk-status.md) instead: the status file always says which
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
  [3tk-log.md](../3tk-log.md), [3tk-status.md](../3tk-status.md)  
  updated, a report to the owner, and the clear-or-not advice.
