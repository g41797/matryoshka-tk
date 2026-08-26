# 3tk — staging plan 015

Written 2026-08-25, after plan 014 was spent. **014 is in `backup/` and this
document does not reproduce it.**

## Where this comes from

**The owner's input is [3tk-doc-split.md](3tk-doc-split.md)**, written the same
day and saved before this plan was cut. Read it first. It is advice and a
description of the problem; the rulings are in this document.

**The problem, measured.** `3tk/src` is 2,229 lines. **1,305 of them are
`<* *>` doc-comment lines — 58%** — plus 168 `//` lines, leaving 756 of code and
blank. `mtk.c3` is 58 lines of which 55 are doc comment. `helper.c3` is 189 of
232. Roughly two lines of prose for every line of code.

**What that prose is.** It argues. It says why a decision was taken and why the
alternative was refused, in the vocabulary of this folder: **270 `Part N.N`
references** across 72 distinct Parts, **about 130 ruling markers** — `R6b` 14
times, `H0` 7, `D3` 7, `D1` 6, `D6` 5, plus the `V`, `P`, `A`, `Q`, `E` and `S`
series — and **11 references to a design document by filename.**

**What it is not.** It is not user orientation. It does not say what a thing is
for or how to call it. **It cannot be used to generate documentation**, and
`c3c docgen` exists in 0.8.3, so the target is real and not hypothetical.

## What this plan builds

**Two new documents and one rewrite of the sources.**

- **`ref/3tk-decisions-001.md`** — the decisions, accumulated, one section per
  source file. **The source of truth for the owner and for an AI.** It is what
  gets read instead of travelling through ten documents.
- **`ref/3tk-api-001.md`** — the API reference **skeleton**. The source for the
  new source comments, and the start of a future API reference book. ztk's
  `matryoshka-api-reference-042.md` is the precedent; that is how the ztk mkdocs
  site is built.
- **The sources rewritten** — comments for a human reader, with a **mark** left
  behind where the argument used to be, so the connection to the design survives
  until 3tk matures.

## The `ref/` folder — the owner's ruling, 2026-08-25

**Both new documents live in `design/secondary/lang/c3/ref/`.**

**The reason is a difference in kind, not tidiness.** Every live document in
`c3/` today is a **finished stage output** — frozen, recording what was true
when a stage ran, never revised. These two are the opposite: **they are alive.**
They are revised whenever a decision changes, they are versioned, so they
multiply, and ztk's equivalent reached `-042`. **ztk also carries patterns and
other files used to build its documentation, and 3tk will likely carry the
same** — this is a family of files, not two.

**One `backup/`, not two.** A superseded version under `ref/` moves to the
existing `c3/backup/`. The owner empties one holding area; a second is a second
thing to remember.

## rules-049.md — what applies here

**The owner's instruction, 2026-08-25: follow `design/rules-049.md` in the part
relevant to 3tk, and especially in the API document.** The file is written for
the Zig port. What carries over, and every stage below is bound by it:

- **Part 4 — what a comment says.** Do not explain WHAT; names do that. WHY only
  if non-obvious. No multi-paragraph docstrings. No "used by X" comments.
  **No `.md` references inside source comments** — a reader of the source or of
  generated docs never sees the design folder. **Comments must be
  self-contained: explain the fact, do not point at a document.**
- **Part 4 — documented asserts must exist, MUST.** A document that lists an
  assert lists only asserts present in `src/`. **Copy them from the source; do
  not infer them from what a function ought to check.** ztk shipped 15
  documented asserts that could not have compiled, and they survived because
  nothing compiles a doc page. **The check is a grep of the documented assert
  against `src/`, run by whoever writes the page.** This governs 3TK-30.
- **Part 4 — exclusive access.** No "owner" or "ownership" language in source
  comments. Say what happens: an item sits in exactly one place, in exactly one
  state, at any moment.
- **Part 4 — live-scan rule.** A scan is done only when re-run live against
  current file contents at the moment of the claim. A previous pass's claim is
  not sufficient.
- **Part 6 — staccato, the one definition.** It applies to documents and
  comments alike. Short sentences. Bullets. One fact per bullet. No long
  sentences, no dense multi-fact prose.
- **Part 6 — markdown hard breaks, and a blank line before every list.** These
  files may feed mkdocs later.
- **Part 5 — banned words.** Its own scope skips `design/secondary/`, because
  those files are frozen records. **`ref/` is not frozen, so the owner ruled it
  in scope on 2026-08-25.** Both new documents are scanned. Report hits; do not
  fix without approval.

**What `3tk/src` carries today, measured 2026-08-25 and to be removed by
3TK-31:** `owner`/`ownership` **9** — five in the exclusive-access sense, four
attributing a ruling to the owner, which is a process reference and does not
belong in source either. `drain` **2**, `sweep` **1**, `settle` **1**. Plus the
11 `.md` references.

## The stages

Three, **declared and not authorized**. They run in number order.

```
3TK-29  (the decisions file)  →  3TK-30  (the API skeleton)  →  3TK-31  (the sources)
```

**Each depends on the one before it.** 3TK-30 is written from the sources and
from 3TK-29's file. 3TK-31 writes the new comments from 3TK-30's file and puts
the marks where 3TK-29's sections say the argument went.

---

## 3TK-29 — the decisions, one section per source file

**Start after clear:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-29.
```

### Why it exists

**The decisions are spread across the folder and across the source comments, and
neither the owner nor an AI can reach one without travelling.** `R6b`'s reason
is in the redesign proposal, in `inner.c3`, in the log and in the findings
document. There is no place that says, in one line, what was decided about the
inner and why it stands.

**It is the source of truth after this stage.** Not a summary of the folder —
the thing that is read instead of it.

### What it does

**Writes `ref/3tk-decisions-001.md`. Nine sections.**

- **One common section** — what is true across the port and belongs to no single
  file.
- **Eight file sections**, in this order: `mtk.c3`, `inner.c3`, `helper.c3`,
  `managed.c3`, `queue.c3`, `stack.c3`, `mailbox.c3`, `pool.c3`.

**A decision is one short entry.** What was decided. Its marker, so the folder
can still be reached — `R6b`, `D1`, `H0`, `Part 8.7`. Where it lives in the code
as `file:line`. **Accumulated, not argued**: the entry says what stands, not the
case that was made for it or the alternative that was refused.

**Every decision in `3tk/src` and in the folder's rulings is accounted for.**
The markers are the checklist: the `R`, `D`, `H`, `V`, `P`, `A`, `E`, `S` and
`Q` series, and the 72 distinct Parts. A marker that appears in the sources and
in no section is a miss, and the stage greps for that rather than trusting its
reading.

**Every `file:line` is printed and read before it is written down**, both sides.
That is 3TK-22's method and 3TK-26's, and this folder has twice paid for
skipping it.

### What it may not do

- **It does not touch `3tk/src`.** Not one character. That is 3TK-31.
- **It does not rule.** A decision that was never taken is not taken here. If
  the stage finds a decision that no document holds, it **reports it** and
  writes nothing in its place — 3TK-19's precedent.
- **It does not describe state.** No dates, no stage numbers, no what-has-run.
  State lives in `3tk-status.md` and the two must never both describe it.
- **It does not become the entry point.** `3tk-status.md` stays the first read.
  It gains one line pointing here, and that line is written by this stage.
- No `git`. No edit to `../common/`. Nothing said to dtk.

### Output and verification

- `ref/3tk-decisions-001.md`, nine sections.
- **Every marker found in `3tk/src` appears in a section** — by grep, printed.
- **Every `file:line` resolves** — by printing it, not by eye.
- **Banned-word scan run live** over the new file. Hits reported, not fixed.
- **Staccato**: no long sentences, one fact per bullet.
- `3tk-status.md` gains the pointer line and the stage row. `3tk-log.md` gains
  the entry.
- `3tk/run-builds.sh` green, four builds, 63 checks, 87 tests — a formality, run
  rather than assumed.
- **The clear-or-not advice and the exact line to continue with**, in the log
  entry and in the status file, not only in the chat.

---

## 3TK-30 — the API reference skeleton

**Start after clear:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-30.
```

### Why it exists

**It is the source for the new source comments.** 3TK-31 has to write 67 public
declarations' worth of human-facing comments, and writing them straight into the
source means the wording is invented eight times in eight files with nothing to
check it against. **The document comes first and the comments are written from
it.**

**It is also the start of the API reference book**, the way ztk's
`matryoshka-api-reference-042.md` is the start of ztk's mkdocs site.

### What it does

**Writes `ref/3tk-api-001.md`. A skeleton, not a finished book.** Enough
structure to improve on later. The owner's words: *you don't need full
description, just skeleton for further improvement.*

**Built from the sources and from the other documents** — the specification, the
porting proposal, and 3TK-29's decisions file.

**Per public declaration**: what it is, how it is called, what it promises, what
it costs. **67 public declarations** in `src/` today, and the stage counts them
live rather than trusting that number.

**Part 4's MUST is the rule of this stage.** Where the document lists an assert
or a contract, **it is copied from `src/` and never inferred**. Every one is
verified by grepping the documented text against the source. A contract in a C3
`<* *>` block — `@require`, `@ensure`, `@param`, `@return?` — is compiled
semantics, and the document reproduces it as written or not at all.

### What it may not do

- **It does not touch `3tk/src`.** That is 3TK-31.
- **It does not argue.** No `R`, `D` or `H` markers, no reasoning, no history.
  Those are 3TK-29's file. This one says what the thing does.
- **It does not invent an API.** A declaration that does not exist is not
  documented, and a promise the code does not make is not written down.
- No `git`. No edit to `../common/`. Nothing said to dtk.

### Output and verification

- `ref/3tk-api-001.md`, covering every public declaration.
- **Every documented assert and contract greps to a real line in `src/`** — run
  live, at the moment of the claim.
- **The public-declaration count is measured, not assumed**, and stated.
- **Banned-word scan run live.** Hits reported.
- **Staccato**, and Part 6's markdown rules — hard breaks, blank line before
  every list.
- Status row, log entry, builds green.
- **The clear-or-not advice and the exact line to continue with.**

---

## 3TK-31 — the marks, and the comments a human can read

**Start after clear:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-31.
```

### Why it exists

**This is the stage that makes the sources usable.** The other two build the
documents it writes from.

### What it does

**Replaces the source comments with comments for a human reader**, written from
`ref/3tk-api-001.md`, obeying rules-049 Part 4 and Part 6.

**Leaves a mark where the argument was.** The mark is **one line, outside the
`<* *>` block**, so `c3c docgen` never renders it:

```c3
// [3tk: R6b, Part 8.7]
```

**What a mark may contain**: ruling markers and Part numbers. **What it may not
contain**: a `.md` filename or a path — Part 4 forbids that outright, and the
whole point is that the mark is greppable and removable, not a link.

**The comment above a mark must stand without it.** Part 4's self-containment
rule: a reader who cannot see the design folder loses nothing. **The mark is for
the owner and for an AI, and it is temporary** — it exists until 3tk matures and
then comes out in one pass.

**Contracts are moved verbatim or not at all.** `@require`, `@ensure`, `@param`
and `@return?` inside a `<* *>` block are compiled, not prose. A rewrite that
drops one deletes a runtime check while looking like a text edit, **and a green
build does not always catch it.**

**Part 4's bans are applied in the same pass** — the owner's ruling of
2026-08-25. The 9 `owner`/`ownership` uses, the `drain`, `sweep` and `settle`
hits, and all 11 `.md` references come out.

**One file first, as the exemplar.** `helper.c3` — 189 of its 232 lines are
prose, it is the file a user meets first, and it is small. **The stage stops
after it and reports**, so the owner can accept or refuse the shape before it
reaches the other seven. That is the folder's own rule for a rewrite: the
exemplar before the mechanical pass.

### What it may not do

- **It changes no code.** No declaration, no signature, no body, no behaviour.
  Comments, marks and contract placement only.
- **It does not delete a claim it cannot find a home for.** Everything removed
  from a source comment is already in `ref/3tk-decisions-001.md` or
  `ref/3tk-api-001.md`, or it does not come out. **This is a move, not a
  delete**, and several source comments are today the only place something is
  written in that form — `@private` not applying to a C3 method, the correction
  to redesign proposal 002 §10.3 about tier 2 and fast builds.
- **It does not sweep past the exemplar without being told.**
- No `git`. No edit to `../common/`. Nothing said to dtk.

### Output and verification

- `3tk/src/helper.c3` rewritten. The other seven untouched and named as
  outstanding.
- **`3tk/run-builds.sh` green — and this is not a formality.** The sources
  changed. Four builds, 63 checks, 87 tests, and a stage that reports fewer has
  broken something.
- **The contract count is identical before and after** — every `@require`,
  `@ensure`, `@param` and `@return?` in `src/`, counted live on both sides and
  both counts stated.
- **Zero `.md` references in the rewritten file. Zero banned words. Zero "owner"
  language.** By grep, run live.
- **Every claim removed from the file is shown to exist in one of the two `ref/`
  documents.**
- **`c3c docgen` is run against the rewritten file** and the result read. Part 4
  again: a doc-comment fix is unverifiable without looking at what it renders.
- Status row, log entry.
- **The clear-or-not advice and the exact line to continue with.**

---

## Rules that hold for all three

- **Only 3TK-31 touches `3tk/src`, and it touches one file.** 3TK-29 and 3TK-30
  do not touch it at all. **Every stage ends with `3tk/run-builds.sh` green and
  the count stated** — four builds, 63 checks, 87 tests. A formality for the
  first two, a verification item for the third.
- **`src/` at the repository root is ztk's Zig source and is not touched.**
- **No stage writes under `../common/`.** Specification 004 stands.
- **No stage edits `design/matryoshka-api-reference-042.md`.** It is ztk's.
- **No stage runs `git`.** Moves are plain `mv`. The owner saves.
- **No stage tells dtk anything.**
- **Nothing cites `backup/` as a source of truth.** The owner empties it.
- **Every stage ends with the clear-or-not advice and the exact continue line**,
  written into [3tk-log.md](3tk-log.md) and [3tk-status.md](3tk-status.md).
  **The owner's requirement, 2026-08-25.** Advice that exists only in a
  conversation the owner is about to clear is worth nothing.
- **A stage that finds itself deciding reports instead.** 3TK-19's precedent.
- **rules-049.md Part 4 and Part 6 bind every stage**, and Part 4's live-scan
  rule means a scan is claimed only when it has just been run.

## Versioning

Two entry points are edited in place — `3tk-status.md` and `3tk-log.md`.
**Everything else is versioned, including both new documents**: the owner's
ruling of 2026-08-25. `ref/3tk-decisions-001.md` and `ref/3tk-api-001.md` are
the first versions; a change makes `-002` and the old file moves to
`c3/backup/`.

**`3tk-doc-split.md` is the owner's input and is not versioned by this folder**,
the same standing as `3tk-who-supports-slot.md`.

## What this plan deliberately leaves to the owner

Named so no stage picks them up by accident.

- **The other seven source files.** 3TK-31 does `helper.c3` and stops. Whether
  the pass continues, and as one stage or seven, is the owner's.
- **When the marks come out.** They exist until 3tk matures. Nothing here says
  when that is.
- **`design/secondary/context.md` lists no `lang/` subfolder**, so every file in
  `c3/`, `d/` and `odin/` is an orphan by `check_design.sh`'s count, and `ref/`
  adds more. **The owner ruled on 2026-08-25 to leave it as drift.** No stage
  fixes it.
- **`3tk-who-supports-slot.md`** — still open, still ruled on by nothing.
- **`3tk-porting-proposal-005.md`** — 004 is 1,839 lines and describes the port
  before the redesign replaced it. A revision, not a stage.
- **The ztk/3tk `on_get` difference.** Recorded in
  `3tk-port-findings-003.md` §5a. Whichever way it goes, one of three moves.
- **The seven documents whose provenance line links a plan that has left
  `backup/`.** One line each, the same repair, reported 2026-08-25 and not done.
