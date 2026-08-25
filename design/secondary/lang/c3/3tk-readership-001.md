# 3tk — who reads the notes (001)

Stage 3TK-27 of [3tk-staging-plan-014.md](3tk-staging-plan-014.md), 2026-08-25.

Seven files, 1,945 lines: the six `*-notes-*` files at 1,483 and
[3tk-drafts-review-001.md](3tk-drafts-review-001.md) at 462. For each of them,
two lines — **who reads it, and when.**

**This stage retires nothing and moves no file.** Deciding a document is spent
is the owner's call; the plan says so and 3TK-19 and 3TK-23 set the precedent.
No file in this folder moved.

**It is not a duplication check.** Whether the content survives elsewhere is a
weaker question. A file can be unique and still dead, and it can be duplicated
and still be the place people look. The test is the owner's own — *retire what
is no longer read*.

---

## The seven, at a glance

| File | Lines | Who reads it | When |
|---|---|---|---|
| `3tk-toolkit-notes-001.md` | 322 | **A later port**, dtk by name | Its capability study |
| `3tk-containers-notes-001.md` | 299 | **A later port**, dtk by name | Its capability study |
| `3tk-sanitizer-notes-001.md` | 152 | **Whoever next runs a sanitizer here** | A sanitizer run, on this machine or one like it |
| `3tk-core-redesign-notes-001.md` | 269 | **Nobody, in normal work** | Reconstructing why the redesign landed as it did |
| `3tk-debts-notes-001.md` | 202 | **Nobody** | — |
| `3tk-helper-notes-001.md` | 239 | **One future editor of `helper.c3`** | Before changing the helper surface — §8 only |
| `3tk-drafts-review-001.md` | 462 | **Nobody** | — |

The rest of this file is the evidence for each row.

---

## 1. `3tk-toolkit-notes-001.md` — read

**Who.** A later port. [`../d/dtk-status.md:80`](../d/dtk-status.md) names it in
dtk's reading list, under *worth reading, and not normative*. Inside this folder
`3tk/src/mtk.c3:10` cites it for a decision in the code, `3tk-status.md:851`
quotes F1 as a standing fact, and `3tk-containers-notes-001.md:7` is written as
its continuation.

**When.** When a port asks the questions F1 to F9 answer — what a `-O` level
does to safe mode, how far `@private` reaches, how a generic module
instantiates. Those are C3 questions, so a non-C3 port reads it once for the
shape of the answers rather than the answers.

## 2. `3tk-containers-notes-001.md` — read

**Who.** The same reader. [`../d/dtk-status.md:81`](../d/dtk-status.md) names it
beside the toolkit notes. `3tk-status.md:853` quotes G2 as a standing fact, and
`3tk-porting-proposal-004.md:1826` points at its *What is not done* list rather
than reproducing it.

**When.** Same occasion as the toolkit notes; the two are one document in two
files, and the second names the first in its opening line.

## 3. `3tk-sanitizer-notes-001.md` — read, narrowly

**Who.** Whoever next runs a sanitizer in this repository. Nothing else cites it
except `3tk-status.md`, which lifts S1, S2 and S6 into its own standing-facts
list. It is **not** on dtk's reading list.

**When.** At a sanitizer run. S1 and S2 are the working route on a machine whose
sanitizer runtimes are not installed — `--cc clang`, no root — and S6 records
that `c3c test` tracks leaks by default. That is operational knowledge with no
other home, and `3tk/run-sanitizers.sh` is the thing it explains.

**Worth the owner's eye:** three of its seven findings are already quoted in
`3tk-status.md`. A reader who stops at the status file gets S1, S2 and S6 and
never learns that the first run's four races were all in the tests — S3 and S4,
which are the part another port would want.

## 4. `3tk-core-redesign-notes-001.md` — nobody, in normal work

**Who.** [`3tk-deviations-001.md:25`](3tk-deviations-001.md) lists it as an
*input* to the deviation audit — a record of what was read, not a live pointer.
`3tk-status.md` quotes it three times. No code cites it.

**When.** Only when someone reconstructs the redesign. Its subject is built and
its three **CORRECTION**s land on
[3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md), which is
itself a record of what was replaced rather than a design anyone works from.

**One thing in it has no other home**: *Renaming is not the work, and the
compiler proved it* — the trap 3TK-16 then paid for, which its own §3 says cost
it. That is a lesson about this codebase, not about the redesign.

## 5. `3tk-debts-notes-001.md` — nobody

**Who.** Nothing reads it. `3tk-status.md:524` describes it, `3tk-log.md` records
it, and `3tk-staging-plan-014.md:155` named it only as a file holding stale
citations — which 3TK-26 then repointed, seven of them.

**When.** No occasion. Both debts are paid and the document says so.

**And its one open item closed without it.** Its last section — *One thing this
stage did not do, and it is owed* — asks a later stage to mark P2 in the
deviation audit. **3TK-19 did that on 2026-08-24**: `3tk-deviations-001.md:158`
carries **FIXED**, and the audit's own change log at `:661` records it. The
section still reads as an open debt.

## 6. `3tk-helper-notes-001.md` — one section, one reader

**Who.** Only `3tk-status.md:520` points at it. Nothing else does.

**When.** Before anyone changes the helper surface, and for §8 alone — *The one
thing a later reader should not undo*, which exists to stop a future stage
"fixing" `helper.c3` to match a specification sentence that was itself the
defect. Sections 1 to 7 are the record of a finished stage.

**§8's own condition has arrived.** It says the guard sentence *can come out when
004 is cut*. 004 was cut by 3TK-17, and 3TK-19 rewrote the header: `helper.c3`
now names `matryoshka-specification-004.md` and ends *there is nothing left to
reconcile*. **So §8 quotes a sentence that is no longer in the file it guards.**
The warning behind it is still sound — a stage that adds a per-type struct would
un-rule a ruling — but the quotation is stale.

## 7. `3tk-drafts-review-001.md` — nobody

**Who.** Nothing reads the document. Two things read *out of* it, and both
reproduce what they took: `c3-capabilities-001.md:656` rules on its eleven
conflicts in a table of its own, and `3tk-porting-proposal-004.md:1697` closes
the same register in a table of its own.

**When.** No occasion. **All seven of its subjects are in `backup/`** —
`3tk-poc.md`, `ztk-to-3tk.md`, `3tk-design-notes.md`, `3tk-polyhelper.md`,
`3tk-additions.md`, `3tk-porting-notes.md`, `3tk-build-dist.md`. A review whose
subject is no longer read has readers only through the two documents that quote
its conclusions, and both of those stand without it.

---

## What this stage did not do

It retired nothing, moved nothing, and repaired neither of the two stale
passages it found — §5's closed debt and §6's stale quotation. Both are in a
finished stage's output, and a stage may not rewrite one of those without being
told to.

## Verification

`3tk/run-builds.sh` — **four builds green, 63 checks, 0 failed, 87 tests.**

## Change log

| Version | Date | Description |
|---|---|---|
| 001 | 2026-08-25 | First version. Stage 3TK-27. Seven files, who reads each and when. Retires nothing. |
