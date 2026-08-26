# 3tk — staging plan 014

Written 2026-08-25, after plan 013 was spent. **013 is in `backup/` and this
document does not reproduce it.**

## What changed about how a plan is written

**A plan holds only what has not run.** Every version through 013 reproduced
every earlier stage verbatim, which is why 013 reached 2,775 lines to declare
three. **The owner ruled that practice out on 2026-08-25.** Finished stages live
in [3tk-log.md](3tk-log.md), briefly, and that is the whole record.

**`backup/` is a holding area and the owner empties it periodically.** Nothing
here points into it for anything it needs. Where a fact matters, this document
states the fact.

## The stages

Five, all small, **declared and not authorized**. They are numbered in the order
they should run.

```
3TK-24  (findings 003)   3TK-25  (the status file)   3TK-26  (stale citations)
3TK-27  (who reads the notes)                        3TK-28  (a README)
```

Only 3TK-28 depends on another: it names the folder as 3TK-25 and 3TK-27 leave
it. The rest are independent.

---

## 3TK-24 — the pool difference, written where another port will find it

**Start after clear:**

```
Run 3TK-24 from design/secondary/lang/c3/3tk-status.md
```

### Why it exists

**3tk and ztk do different things on the most ordinary pool path there is, and
no document says so.** In available-or-new mode 3tk pops a stored item and
returns without calling the hook — `pool.c3:337-345`. ztk pops it and calls
`on_get` anyway, with the Slot **full**, so the hook can reinitialize what came
back — `pool.zig:565-586`.

**The specification sides with 3tk twice.** Part 11.7 words the mode as *take a
stored item, else ask the hook*; Part 12.2 opens `on get` with *The Slot is
empty on entry*. **It marks neither as a ztk deviation**, though
`ztk-audit-001.md` 2.7 describes ztk's behaviour correctly and
`matryoshka-api-reference-042.md` documents it as the contract. So a shared
normative document and the audit behind it disagree.

Found 2026-08-25 while confirming a separate claim of the owner's — that
`Pool.get_wait` calls no creation hook on purpose, which every source agrees on
and which needed no change anywhere.

### What it does

Writes **`3tk-port-findings-003.md`**, adding one section and changing nothing
else of substance.

- **§5a**, a peer of §5, the other pool section. Numbered `5a` rather than `11`
  because 3TK-22 set that precedent with §1a, and because §1 to §10 keep their
  numbers.
- The document's four-heading shape, unbent: **What 3tk does / Why / Where the
  specification stands / What ztk does.**
- Every `file:line` printed and read, both sides, before it is written down.
- A change log row.

### What it may not do

- **It recommends nothing and names no fix.** The word *should* appears nowhere,
  as in 001 and 002. Any repair belongs to ztk's plan or dtk's, not to 3tk.
- **It does not tell dtk.** The owner ruled on 2026-08-25 that dtk can wait.
- No edit to `../common/`, to `design/matryoshka-api-reference-042.md`, or to
  002 — which is cited and may not change under the citation.
- No code, no `3tk/`, no `git`.

### Output and verification

`3tk-port-findings-003.md`; 002 to `backup/` and its live links repointed; the
`3tk-status.md` open question shrinks to one line pointing at §5a. Every
citation in the new section resolves, checked by printing it. Builds green.

---

## 3TK-25 — the status file becomes an entry point again

**Start after clear:**

```
Run 3TK-25 from design/secondary/lang/c3/3tk-status.md
```

### Why it exists

**It says *One screen* on line 3 and runs to 1,708 lines.** Lines 310 to 1102 —
**793 of them, 46%** — are seven retrospective sections: *What 3TK-17 did*,
*What 3TK-15 paid*, *What 3TK-16 built*, *What 3TK-14 decided*, *What the owner
ruled, 2026-08-24*, *What is owed* (a stale 3TK-14-era table), and *The state
before 3TK-14*. **That is narrative, and narrative is the log's job.** *The gap
between the port and the specification* is 79 more restating the deviations
audit.

A cold session pays for all of it before reaching anything current.

### What it does

1. **Reads each of the eight sections against [3tk-log.md](3tk-log.md)** and
   sorts every claim into: already in the log, or not.
2. **Writes one dated log entry, short**, carrying only what the log is missing.
   The log is append-only and newest-first, so nothing is inserted into its past.
3. **Removes the eight sections from the status file**, leaving one line where
   each stood.
4. **Folds the open-questions review in** — for each open question, says whether
   it belongs in this file at all, and moves the ones that belong to the
   findings document or another line. **It moves nothing it cannot place.**
5. **Closes the forty-broken-links question.** They point at files the owner
   removed from `backup/` in the ordinary course. **Routine housekeeping, not a
   defect**, and filing it as an open question was a mistake of 3TK-23's report.

### What it may not do

- **It does not shorten the existing log.** The owner ruled on 2026-08-25 that
  the log's past is left alone as the record.
- **It does not delete a claim it cannot find a home for.** Anything that is
  neither in the log nor carried into the new entry stays in the status file and
  is named in the report.
- No code, no `git`, no `../common/`.

### Output and verification

`3tk-status.md` near 800 lines; one short log entry. **Every removed section is
accounted for**, and the report gives the count both ways. Builds green.

---

## 3TK-26 — the stale `inner.c3` citations

**Start after clear:**

```
Run 3TK-26 from design/secondary/lang/c3/3tk-status.md
```

### Why it exists

**3TK-21 rewrote `inner.c3` end to end, so every line citation into it moved.**
It is the one open item that makes a current document say something false.

- **`3tk-deviations-001.md` — nine**, including V1, V5 and V12, the three rows
  that describe the inner's shape.
- `3tk-debts-notes-001.md` and `3tk-helper-proposal-001.md` — the same class,
  fewer.

3TK-21 reported the debt instead of paying it, because a stage may not rewrite a
finished stage's output. **This plan authorizes the write explicitly**, and that
authorization is the reason the stage exists.

### What it does

Repoints the citations, and **only** the citations. Every one is printed and
read on both sides before it is changed — 3TK-22's method, which is what found
that some citations were not repointings at all but sentences that had become
false.

**A citation that turns out to need more than a new number is named in the
report and left alone.** Changing what a finished audit *claims* is a different
act from fixing where it points, and it is the owner's.

### What it may not do

No verdict changes. No new version of the audit — a repointing is not a finding.
No code, no `git`, no `../common/`.

### Output and verification

The three files, citations current. **Every changed citation printed after the
change**, and the count stated. Builds green.

---

## 3TK-27 — who reads the notes

**Start after clear:**

```
Run 3TK-27 from design/secondary/lang/c3/3tk-status.md
```

### Why it exists

**Six `*-notes-*` files, 1,483 lines**, one per code stage — toolkit,
containers, core-redesign, sanitizer, debts, helper — plus
`3tk-drafts-review-001.md` at 462, whose subject was the seven drafts and whose
work is done. They are the largest group of candidates left, and a cold reader
cannot tell which of them anybody still opens.

### What it does

**For each of the seven, two lines: who reads it, and when.** That is the test,
and it is the owner's own — *retire what is no longer read*, which named 3TK-23.

**It is not a duplication check.** Whether the content survives elsewhere is a
weaker question: a file can be unique and still dead, and it can be duplicated
and still be the place people look. Where the answer is *nobody*, the file is
finished whatever else is true.

### What it may not do

**It retires nothing.** It reports and stops. Deciding a document is spent is
the owner's call — 3TK-19's precedent and 3TK-23's. The owner ruled this shape
explicitly on 2026-08-25.

No code, no `git`, no `../common/`, and it moves no file.

### Output and verification

A report to the owner and a short log row. **No file in the folder moves**, and
the report says so in one line. Builds green.

---

## 3TK-28 — a README for the folder

**Start after clear:**

```
Run 3TK-28 from design/secondary/lang/c3/3tk-status.md
```

### Why it exists

`../common/` has a README; `c3/` has none. **Seventeen files with no index is
most of why the folder reads as a heap.** It is also the cheapest of the five
and the one that makes the other four legible.

**It runs last** because it names the folder as 3TK-25 and 3TK-27 leave it.

### What it does

One line per live file: what it is, and who reads it. Entry points first, then
the design of record, then the rest. **It links nothing into `backup/`.**

### What it may not do

It is an index, not a summary. It re-describes no document's content and rules
on nothing. No code, no `git`, no `../common/`.

### Output and verification

`README.md` in this folder. **Every live file appears exactly once and every
link resolves**, checked by printing them. Builds green.

---

## Rules that hold for all five

- **No stage writes code in any language.** `3tk/` is untouched, and `src/` at
  the repository root is the ztk Zig source and is not touched either. **Every
  stage still ends with `3tk/run-builds.sh` green and the count stated** — four
  builds, 63 checks, 87 tests. A formality, run rather than assumed. A stage
  that reports three builds has not run.
- **No stage writes under `../common/`.** Specification 004 stands as written.
- **No stage edits `design/matryoshka-api-reference-042.md`.** Two of its lines
  are wrong about `get_wait` and `on_get`; correcting the book is the ztk line's
  work.
- **No stage runs `git`.** Moves are plain `mv`. The owner saves.
- **No stage tells dtk anything.** Ruled 2026-08-25.
- **Nothing cites `backup/` as a source of truth.** The owner empties it.
- **Each stage ends** with its file written under `c3/`, **a short row** in
  [3tk-log.md](3tk-log.md), [3tk-status.md](3tk-status.md) updated, a report to
  the owner, and the clear-or-not advice.
- **A stage that finds itself deciding reports instead.** 3TK-19's precedent,
  and it is why 3TK-27 retires nothing.

## Versioning

Unchanged from 013 and not reproduced here. Two entry points are edited in
place — `3tk-status.md` and `3tk-log.md`. Everything else is versioned, and a
new version means a new file. **`3tk-port-findings-003.md` becomes the live
version when 3TK-24 runs, and 002 moves to `backup/`.**

## What this plan deliberately leaves to the owner

Named so no stage picks them up by accident.

- **`3tk-who-supports-slot.md`** — open, ruled on by nothing, 190 lines. Two
  methods and two tests. Answering it either way retires the file.
- **`3tk-porting-proposal-005.md`** — 004 is 1,839 lines and describes the port
  before the redesign replaced it. The status file already calls it the first
  document a cold reader trips on. A revision, not a stage.
- **`design/secondary/context.md` lists no `lang/` subfolder**, so every file in
  `c3/`, `d/` and `odin/` counts as an orphan — the whole of the rise to 49, and
  why `check_design.sh` exits 1. One file, outside this folder, and the largest
  gate improvement available. Not 3tk's.
- **The ztk/3tk pool difference itself.** 3TK-24 records it. Whichever way it
  goes, one of three moves — 3tk's code, ztk's code, or Part 12.2 — and none of
  those is this plan's.
