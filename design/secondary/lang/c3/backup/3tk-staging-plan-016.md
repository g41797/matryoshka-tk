# 3tk — staging plan 016

Written 2026-08-25, after plan 015 was spent.

**Provenance.** Follows [3tk-staging-plan-015.md](backup/3tk-staging-plan-015.md).
015 declared 3TK-29, 3TK-30 and 3TK-31, and all three have run. This plan
declares **3TK-32 to 3TK-37**. **Declared, not authorized.** The owner names a
stage before it runs.

State is in [3tk-status.md](3tk-status.md). Narrative is in
[3tk-log.md](3tk-log.md). Neither is duplicated here.

---

## Why this plan exists

**3TK-31 was refused twice, and the second refusal named the cause.**

The owner's words: *it mostly description of implementation* — and then the
diagnosis: *in ztk we wrote api ref md and comments were moved from it, not
it's opposite.*

**The derivation ran backwards.** ztk wrote
[../../../matryoshka-api-reference-042.md](../../../matryoshka-api-reference-042.md)
first and moved comments out of it. 3tk has no document of that kind, so
3TK-31 had only the old comments to work from. Those comments are design
argument and implementation notes. Reworded design argument is still design
argument.

**A third careful attempt lands in the same place.** The order is the defect,
not the effort.

## The correction, in three moves

The owner's own list, and this plan is built on it.

1. **Strip the sources to descriptor and contracts.** Subtraction only.
2. **Write the 3tk reference in 042's shape.** A document, no source risk.
3. **Move the comments out of the reference into the sources.** ztk's
   direction.

**Only the second move requires invention**, and it is the one that costs
nothing to refuse — a markdown file, no rebuild.

## What is on the table

Measured live 2026-08-25, so no stage re-derives it.

| file | lines | doc lines | declarations | contracts |
|---|---|---|---|---|
| `mtk.c3` | 58 | 55 | 2 | 0 |
| `inner.c3` | 387 | 261 | 18 | 6 |
| `helper.c3` | 206 | 154 | 14 | 17 |
| `managed.c3` | 127 | 93 | 4 | 6 |
| `queue.c3` | 231 | 139 | 12 | 1 |
| `stack.c3` | 128 | 87 | 7 | 0 |
| `mailbox.c3` | 439 | 213 | 21 | 14 |
| `pool.c3` | 627 | 268 | 19 | 19 |
| **total** | **2,203** | **1,270** | **97** | **63** |

**Also outstanding.**

- **21 string literals cite a specification Part** — `pool.c3` 12,
  `mailbox.c3` 3, `queue.c3` 2, `inner.c3` 2, `managed.c3` 1, `stack.c3` 1.
- **1 ruling marker inside a string** — `R12`, `pool.c3:107`.
- **8 `.md` references in comments** — `mtk.c3` 5, `inner.c3` 3.
- **12 Part 4 ban hits** — `pool.c3` 5, `stack.c3` 4, `inner.c3` 2,
  `mailbox.c3` 1.

## The stages

Six, **declared and not authorized**. They run in number order.

```
3TK-32   the strings a user sees
   |
3TK-33   strip:  mtk.c3, inner.c3, helper.c3
3TK-34   strip:  managed.c3, queue.c3, stack.c3
3TK-35   strip:  mailbox.c3, pool.c3
   |
3TK-36   the reference, in 042's shape
   |
3TK-37   the comments, moved out of the reference  (exemplar only)
```

**Six stages means six clear points.** Each one ends with the clear advice and
the exact line to continue with, written into
[3tk-log.md](3tk-log.md) and [3tk-status.md](3tk-status.md).

**Why 3TK-32 runs first.** It is the only stage that edits a function body.
Doing it before the strip means 3TK-33 to 3TK-35 keep contracts verbatim
without preserving a Part number that is on its way out, and 3TK-36 quotes
final strings rather than strings it will have to revisit.

**The alternative was to run it last**, after the reference. That was not
taken, because [ref/3tk-api-001.md](ref/3tk-api-001.md) quotes all 21 strings
verbatim and would then be revised twice.

**Why the strip is three stages and not one.** 1,270 doc-comment lines across
eight files. Three stages give three clear points and three green builds. The
split is by size, and the files that carry the `.md` references go first.

---

## 3TK-32 — the strings a user sees

**Start after clear:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-32.
```

### Why it exists

**Owed since 2026-08-25.** The design vocabulary does not stop at the
comments. It is inside string literals, in two places a user meets it.

- **A runtime abort message.** A user whose program aborts is shown a clause
  number and has no document for it. The fact they can act on is in the same
  string, after the colon.
- **A contract clause `c3c docgen` renders.** A ruling marker printed on a
  generated documentation page.

### What it does

**Rewrites the 21 Part-citing string literals and the one `R12`**, so that what
is left is the fact a user can act on.

- The clause number comes out. The fact stays.
- `"Part 9.2 rule 3: an acquisition asserts the Slot is empty on entry"`
  becomes the half after the colon.
- **Where a call site loses information by the edit, it does not lose it** —
  the marker moves to a `// [3tk: ...]` mark on the line above.

**Revises [ref/3tk-api-001.md](ref/3tk-api-001.md) in the same stage**, because
it quotes all of them verbatim and Part 4's MUST requires the quote to match.
The revision makes `ref/3tk-api-003.md`; 001 moves to `backup/`.

### What it may not do

- **It changes no logic.** A message is a message. No condition, no branch, no
  signature.
- **It does not touch a comment.** That is 3TK-33 to 3TK-35.
- **It does not rule on wording it cannot derive.** A string whose whole
  content is a clause number, with no actionable fact behind it, is
  **reported, not invented**.
- No `git`. No edit to `../common/`. Nothing said to dtk.

### Output and verification

- **Zero Part citations and zero ruling markers in any string literal in
  `3tk/src`** — by grep, run live, both before and after, both counts stated.
- **`3tk/run-builds.sh` green, and this is a verification item.** Bodies
  changed. Four builds, 63 checks, 87 tests.
- **The negative tests still name what they check.** Several assert on an
  abort message. A stage that changes a message and not its test is broken.
- **`c3c docgen` run and the rendered contract clauses read.**
- `ref/3tk-api-003.md` written, 001 to `backup/`, every link repointed and
  printed.
- Status row, log entry, **the clear advice and the exact continue line**.

---

## 3TK-33 — strip: `mtk.c3`, `inner.c3`, `helper.c3`

**Start after clear:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-33.
```

### Why it exists

**The essays come out before anything is written to replace them.** They are
the thing the owner refused, twice, and they are not load-bearing: the argument
is already in [ref/3tk-decisions-001.md](ref/3tk-decisions-001.md).

**It is subtraction, and that is the point.** It does not depend on writing a
good descriptor, which is the part that failed. It depends on deleting prose
and preserving contracts, which is checkable by count and by diff.

### What it does

**Reduces every doc comment to a descriptor and its contracts.**

**The model is the C3 stdlib**, measured 2026-08-25 in
`/home/g41797/dev/langs/c3/lib/std/collections/list.c3`. Its doc comments are
overwhelmingly contracts alone, with an occasional one-line descriptor:

```c3
<*
 Reverse the elements in a list.
*>
```

**What a doc comment keeps.**

- **One descriptor line.** What the thing is. Two short lines where the call
  has a usage rule a caller must know, as `init` does.
- **Every `@require`, `@ensure`, `@param` and `@return?`, character-identical.**
  They are compiled. They never move.
- **The `// [3tk: ...]` mark**, outside the block, on the line above the
  declaration.

**What comes out.**

- Every line describing how it is implemented.
- Every line stating a port invariant rather than a caller's fact.
- Every argument, every alternative refused, every clause number in prose.
- The 8 `.md` references and the 12 Part 4 ban hits, in the files where they
  fall.

**Descriptors are not invented where one already exists.** The first line of
today's comment is usually the descriptor. Keep it, delete the rest.

### What it may not do

- **It changes no code.** No declaration, no signature, no body, no string.
- **It does not delete a claim that has no home.** Every claim removed is
  already in `ref/3tk-decisions-001.md` or `ref/3tk-api-002.md`. A claim in
  neither is **reported and left in place**, one line long.
- **It does not write new prose.** If a declaration has no descriptor and none
  can be taken from what is there, it gets its contracts and no text, and the
  stage says so. 3TK-36 gives it one.
- **It does not touch the other five files.**
- No `git`. No edit to `../common/`. Nothing said to dtk.

### Output and verification

- **The contract count is identical before and after, per file and in total** —
  `mtk.c3` 0, `inner.c3` 6, `helper.c3` 17. Counted live on both sides, both
  stated, and the contract text compared as sorted lines.
- **Zero `.md` references** in the three files. 8 before.
- **Zero Part 4 ban hits** in the three files. 2 before.
- **Zero `**` and zero trailing `\`** — the renderer rules in
  [3tk-status.md](3tk-status.md).
- **`c3c docgen` run, and its own `formatDocText` run over the output.** Not
  read as source. Every declaration renders, every identifier keeps its
  underscores, no line is a broken half-sentence.
- **`3tk/run-builds.sh` green** — four builds, 63 checks, 87 tests.
- **The doc-line count before and after, stated.** The stage is a subtraction
  and the number is the evidence.
- Status row, log entry, **the clear advice and the exact continue line**.

---

## 3TK-34 — strip: `managed.c3`, `queue.c3`, `stack.c3`

**Start after clear:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-34.
```

**The same stage as 3TK-33, on three more files.** Everything in 3TK-33's
*What it does*, *What it may not do* and *Output and verification* holds here
without restatement.

**Its own numbers.** 319 doc lines, 23 declarations, 7 contracts —
`managed.c3` 6, `queue.c3` 1, `stack.c3` 0. **5 Part 4 ban hits**, 4 of them in
`stack.c3`. No `.md` references.

**It does not touch `mailbox.c3` or `pool.c3`.**

---

## 3TK-35 — strip: `mailbox.c3`, `pool.c3`

**Start after clear:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-35.
```

**The same stage again, on the two largest files.** 3TK-33's sections hold.

**Its own numbers.** 481 doc lines, 40 declarations, 33 contracts —
`mailbox.c3` 14, `pool.c3` 19. **6 Part 4 ban hits.** No `.md` references.

**The pool's hook contracts are the risk.** `pool.c3` carries 19 of the port's
63 contracts, and the three hook methods are documented in the struct that
declares them. **The contract text is compared as sorted lines, not counted**,
and both sides are printed.

**After this stage all eight files are stripped**, and the port has descriptors
and contracts and nothing else.

---

## 3TK-36 — the reference, in 042's shape

**Start after clear:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-36.
```

### Why it exists

**This is the stage the other five exist to make possible.** It is where the
wording is invented, once, in a document that can be refused without a
rebuild.

**Ruled by the owner 2026-08-25**: the 3tk reference should have 042's shape.

### What it does

**Writes `ref/3tk-reference-001.md`.**

**Seven parts, and Parts 3, 4 and 5 repeat one shape in one order**, the way
042 does:

- **What this is** — high level, short.
- **Participants** — the types, and the role each one plays.
- **Usual flow** — the regular usage.
- **The API, in named groups** — one named group per act.
- **Where to go deeper** — `3tk/src`, a test, a document.

**A part learned once is a part learned everywhere.**

**Deep dive is not its job.** 042 says so of itself, and this file says so of
itself.

**Built from**: `3tk/src` after the strip, `ref/3tk-decisions-001.md`,
`ref/3tk-api-002.md`, `ref/3tk-api-003.md`, and the specification in
`../common/`.

**Every example compiles.** 3TK-30b's method: a scratch file against `3tk/src`,
built, and the scratch output removed.

### What it may not do

- **It does not touch `3tk/src`.** Not one character. That is 3TK-37.
- **It argues nothing and cites nothing.** No decision numbers, no clause
  numbers, no `file:line`. Those readers have
  `ref/3tk-decisions-001.md` and `ref/3tk-api-003.md`.
- **It does not rule.** A decision no document holds is reported, not taken.
- **It does not describe state.** No dates, no stage numbers.
- **It does not replace `ref/3tk-api-002.md`** in this stage. Whether 002 is
  retired once this exists is the owner's, and 3TK-36 reports the overlap
  rather than acting on it.
- No `git`. No edit to `../common/`. Nothing said to dtk.

### Output and verification

- `ref/3tk-reference-001.md`, seven parts, Parts 3 to 5 in the same order.
- **Every public declaration appears** — by grepping the declaration names out
  of `3tk/src`, not by reading. The count is measured and stated.
- **Every example compiled**, and said to be.
- **Banned-word scan run live.** Hits reported.
- **Part 6's markdown rules** — hard breaks, blank line before every list.
- `3tk/run-builds.sh` green — a formality here, run rather than assumed.
- Status row, log entry, **the clear advice and the exact continue line**.

---

## 3TK-37 — the comments, moved out of the reference

**Start after clear:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-37.
```

### Why it exists

**ztk's direction, finally available.** The wording exists in a document before
it reaches a `<* *>` block.

### What it does

**Writes the descriptors of ONE file from `ref/3tk-reference-001.md`.**

**`helper.c3` again, as the exemplar.** It is the file the two refusals were
about, and it is the fair test of whether the new order fixed anything.

**A descriptor is moved, not composed.** If the sentence is not in the
reference, it is not written here — it is added to the reference first, and
the stage says it did that.

**Obeys the renderer rules**, measured 2026-08-25 and recorded in
[3tk-status.md](3tk-status.md): no trailing `\`, one source line per rendered
line, ` ```c3 ` fences, every identifier in backticks.

**The stage stops after the one file and reports.**

### What it may not do

- **It changes no code**, no string, and no contract.
- **It does not go past the exemplar without being told.**
- **It does not invent.** The reference is the source. A gap in the reference
  is a defect of 3TK-36 and is fixed there.
- No `git`. No edit to `../common/`. Nothing said to dtk.

### Output and verification

- `3tk/src/helper.c3` written. The other seven named as outstanding.
- **Every descriptor is shown to exist in `ref/3tk-reference-001.md`**, by
  grep, printed.
- **The contract count and text identical**, 17, compared as sorted lines.
- **`c3c docgen` run, and `formatDocText` run over its output.**
- **`3tk/run-builds.sh` green** — a verification item. Four builds, 63 checks,
  87 tests.
- Status row, log entry, **the clear advice and the exact continue line**.

---

## Rules that hold for all six

- **Every stage ends with `3tk/run-builds.sh` green and the counts stated** —
  four builds, 63 checks, 87 tests.
- **Every stage ends with the clear advice and the exact continue line**,
  written into [3tk-log.md](3tk-log.md) and [3tk-status.md](3tk-status.md).
  **The owner's standing requirement.** Advice that exists only in a
  conversation about to be cleared is worth nothing.
- **A stage that finds itself deciding reports instead.** 3TK-19's precedent.
- **A stage that finds itself inventing prose reports instead.** This plan's
  own addition, and the reason it exists.
- **rules-049.md Part 4 and Part 6 bind every stage**, and Part 4's live-scan
  rule means a scan is claimed only when it has just been run.
- **A rendering claim is made only after running the renderer**, never from
  reading the source. `c3c docgen` writes `docs.html`; `formatDocText` inside
  it is the renderer, and it is not CommonMark.
- **`src/` at the repository root is ztk's Zig source and is not touched.**
- **No stage writes under `../common/`.** Specification 004 stands.
- **No stage edits `design/matryoshka-api-reference-042.md`.** It is ztk's, and
  this plan reads it as a model only.
- **No stage runs `git`.** Moves are plain `mv`. The owner saves.
- **No stage tells dtk anything.**
- **Nothing cites `backup/` as a source of truth.** The owner empties it.

## Versioning

Two entry points are edited in place — `3tk-status.md` and `3tk-log.md`.
**Everything else is versioned.** `ref/3tk-api-003.md` and
`ref/3tk-reference-001.md` are new files; a change to either makes the next
number and the old file moves to `c3/backup/`.

## What this plan deliberately leaves to the owner

Named so no stage picks them up by accident.

- **The other seven files in 3TK-37.** The exemplar runs, then it stops.
  Whether the pass continues, and as one stage or three, is the owner's, and
  the plan that follows 016 declares it.
- **Whether `ref/3tk-api-002.md` is retired** once `3tk-reference-001.md`
  exists. 3TK-36 reports the overlap and does nothing about it.
- **When the `// [3tk: ...]` marks come out.** They exist until 3tk matures.
  Nothing here says when that is.
- **`3tk-who-supports-slot.md`** — still open, still ruled on by nothing.
- **`3tk-porting-proposal-005.md`** — 004 describes the port before the
  redesign replaced it. A revision, not a stage.
- **The ztk/3tk `on_get` difference**, recorded in
  [3tk-port-findings-003.md](3tk-port-findings-003.md) §5a.
- **`design/secondary/context.md` lists no `lang/` subfolder**, so every file
  here is an orphan by `check_design.sh`'s count. The owner ruled on
  2026-08-25 to leave it as drift.
- **The seven documents whose provenance line links a plan that has left
  `backup/`.** One line each, the same repair, reported and not done.
