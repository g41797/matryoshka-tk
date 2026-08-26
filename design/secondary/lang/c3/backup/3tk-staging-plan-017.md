# 3tk — staging plan 017

Written 2026-08-26, after plan 016 was spent.

**Provenance.** Follows [3tk-staging-plan-016.md](3tk-staging-plan-016.md). 016
declared **3TK-32 to 3TK-37** and all six have run. This plan declares
**3TK-38 to 3TK-42**. **Declared, not authorized.** The owner names a stage
before it runs.

State is in [3tk-status.md](3tk-status.md). Narrative is in
[3tk-log.md](3tk-log.md). Neither is duplicated here.

---

## Why this plan exists

**3TK-37 worked, and that is the problem it leaves.**

The exemplar ran: 27 descriptor sentences, every one found in
[ref/3tk-reference-001.md](ref/3tk-reference-001.md) by grep, 17 contracts
identical as sorted lines, the real renderer run over all 14 doc blocks, four
builds green. The order plan 016 corrected — reference first, comments moved out
of it — held on the file that had been refused twice.

**But the method exists only in a log entry and in a conversation that was
cleared.** A cold session cannot repeat it. Seven source files still carry what
the three strip stages left them, and 016 declares no stage for any of them.

**And the owner named the larger fact: comment writing is iterative, in both
directions.**

- The reference is edited, and the comments follow.
- A comment is edited, and the reference follows.

**That is a loop, not a stage.** A stage runs once and is spent. This runs
whenever either side moves, which is why the method has to be a document in the
repo rather than a stage's transcript.

## What the owner ruled, 2026-08-26

Named here so no stage re-opens them.

- **The procedure lives under [ref/](ref/).** Not `../common/`. It is checked on
  3tk before it is offered to any other port, and a process document in
  `../common/` would be a recommendation to dtk and otk — which the standing
  rule forbids.
- **It is a document, not a skill file.** Nothing under `.claude/`. It is
  invoked the way a stage is invoked: one line, after a clear.
- **The preview script comes first**, standalone and small.

## What is on the table

Measured live 2026-08-26, so no stage re-derives it.

| file | lines | doc lines | doc blocks | contracts |
|---|---|---|---|---|
| `mtk.c3` | 10 | 6 | 1 | 0 |
| `inner.c3` | 199 | 89 | 18 | 6 |
| `helper.c3` | 151 | 99 | 14 | 17 |
| `managed.c3` | 76 | 37 | 4 | 6 |
| `queue.c3` | 170 | 64 | 12 | 1 |
| `stack.c3` | 87 | 38 | 7 | 0 |
| `mailbox.c3` | 346 | 128 | 20 | 14 |
| `pool.c3` | 487 | 174 | 22 | 19 |
| **total** | **1,526** | **635** | **98** | **63** |

**`helper.c3` is the only one rewritten from the reference.** The other seven
carry the descriptors 3TK-33 to 3TK-35 left them — true, and not moved out of
any document.

## The stages

Five, **declared and not authorized**. They run in number order.

```
3TK-38   the preview script                    (standalone)
   |
3TK-39   the doc loop, as a document
   |
3TK-40   from-reference:  mtk, inner, managed
3TK-41   from-reference:  queue, stack
3TK-42   from-reference:  mailbox, pool
```

**Five stages means five clear points.** Each one ends with the clear advice and
the exact line to continue with, written into [3tk-log.md](3tk-log.md) and
[3tk-status.md](3tk-status.md).

**Why 3TK-38 runs first.** It is the only stage that touches neither `3tk/src`
nor `ref/`, and it is what lets the owner *look* at a doc comment before ruling
on it. Nothing after it depends on it, so it can also be skipped without
disturbing the rest.

**Why the seven files are three stages and not one.** The same reasoning the
strip used: three clear points, three green builds, and the split matches
3TK-33 to 3TK-35 so a reader comparing before and after has one boundary, not
two.

**Why `mailbox.c3` and `pool.c3` are last.** They carry 33 of the 63 contracts
between them, and `pool.c3` is the file that decides whether the procedure is
fit to offer another port.

---

## 3TK-38 — the preview script

**Start after clear:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-38.
```

### Why it exists

**A doc comment cannot be judged from its source.** The renderer is
`formatDocText` inside the generated `docs.html`, it is not CommonMark, and
3TK-31 was corrected once already by running it rather than reading it. The
owner needs the page in a browser, not a claim about the page.

**ztk has one**: `kitchen/tools/preview_apidocs.sh`. 3tk has none.

### What it does

**Writes `3tk/preview-docs.sh`**, beside `run-builds.sh`.

- Removes any stale `docs.html`, runs `c3c docgen` over `3tk/src`, opens the
  result.
- **Checks first whether `docs.html` is self-contained.** It inlines its CSS and
  its JS, and it names `marked` without ever loading it. If nothing reaches an
  external host, `xdg-open` on the file is enough and the python server ztk
  needs drops out. If something does reach out, it follows ztk and serves the
  folder.
- **Leaves no `docs.html` behind in `3tk/`** — or the stage adds it to what the
  repository ignores, and says which it chose. 3TK-37 generated one into `3tk/`
  and had to delete it by hand.

### What it may not do

- **It touches no source.** Not `3tk/src`, not `ref/`, not `../common/`.
- **It writes no documentation.** It is a script and a status row.
- No `git`. Nothing said to dtk.

### Output and verification

- `3tk/preview-docs.sh`, run, and **what the self-containedness check found is
  reported** — not assumed.
- `3tk/` clean afterwards, shown by `ls`.
- `3tk/run-builds.sh` green — a formality here, run rather than assumed. Four
  builds, 63 checks, 87 tests.
- Status row, log entry, **the clear advice and the exact continue line**.

---

## 3TK-39 — the doc loop, as a document

**Start after clear:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-39.
```

### Why it exists

**To write down what 3TK-37 did, so it can be run again in either direction by
a session that was not there.**

### What it does

**Writes [ref/3tk-doc-loop-001.md](ref/3tk-doc-loop-001.md)**, and the checker
script that document names.

#### The invariant

> Every descriptor line in `3tk/src` appears in `ref/3tk-reference-001.md`.

**The check runs one way only.** The reference is allowed to say more — *Usual
flow*, the diagrams, the whole of Part 6. The source is a subset of it, never
the reverse. The property that matters is that **no comment says anything the
reference does not**.

**That one check drives both directions**, which is why there is one invariant
and not two procedures.

- The reference is edited, the comments are rewritten, the check passes.
- A comment is edited, the check **fails on that line**, and the failure is the
  trigger to fold it into the reference.

#### Three modes

One section each, in plan 016's stage shape — *what it does*, *what it may not
do*, *output and verification*.

- **`check`** — reports drift, changes nothing. Safe at any time.
- **`from-reference <file>`** — the reference was edited; the file's comments
  are rewritten from it.
- **`to-reference <file>`** — comments were edited; they are folded into the
  reference.

**Invoked like a stage, after a clear:**

```
Read design/secondary/lang/c3/3tk-status.md.
Run doc-loop from-reference on pool.c3.
```

#### The rules the document holds

**The first one is the reason this is a document and not only a script.**

- **A sentence can be true, be in the reference, and still not belong in a
  `<* *>` block.** Design argument and implementation notes go to
  [ref/3tk-decisions-001.md](ref/3tk-decisions-001.md). That is what 3TK-31 was
  refused twice for, and no script can apply it.
- **A sentence not in the reference is not written into the source.**
  `from-reference` moves. It does not compose. A gap is a defect of the
  reference and is fixed there first, and the run says it did that.
- **In `to-reference`, a sentence that fits no existing group is reported, not
  filed.** Otherwise the reference becomes a place things are put, which is the
  failure mode of making the loop cheap.
- **Contracts, signatures and bodies are never touched.** Doc comments only.
  The 17-contract sorted-line diff is what made 3TK-37's claim mean anything.
- **The direction is an argument, never a guess.** `from-reference` says the
  reference wins; `to-reference` says the source does. The owner says which
  round it is. A script cannot know.

#### What the document says about itself

- **It is not a stage.** It writes no status row and no log entry. Its output is
  a report. A named stage that uses it writes those. Otherwise the log stops
  being history and becomes a transcript.
- **Its inputs are fixed**: [3tk-status.md](3tk-status.md), itself, the
  reference, and the one source file. Not a transcript.

#### Rules by link, never by copy

**The register for a source comment** and **the measured renderer facts** are in
[3tk-status.md](3tk-status.md). **The bans and staccato** are in
[../../../rules-049.md](../../../rules-049.md), Parts 4 to 6. **Moved, not
composed** is [3tk-staging-plan-016.md](3tk-staging-plan-016.md)'s.

**The document links them.** Restating them makes a second source of truth that
will drift from the first, and this folder has paid that bill before.

#### The checker script

Beside `run-builds.sh`. **Facts only, no opinions.**

- Every descriptor line of a named source file, matched against the reference.
- **Whitespace-normalised**, because the reference wraps sentences across source
  lines. 3TK-37 hit exactly this: a plain `grep -F` reported three misses that
  were defects of the grep, not of the document.
- **Both sides printed** — found, and not found.
- The live ban scan over the file and over the reference.

`c3c docgen` plus `formatDocText` under `node`, and `run-builds.sh`, stay as
they are. The document names them; it does not wrap them.

#### Two entry-point lines

**`ref/` now holds two kinds of document** — the toolkit's content, and the
procedure that keeps it true. One line saying so in [3tk-status.md](3tk-status.md)'s
entry-point notes, one in [README.md](README.md). Unstated, the next cold
session will not know why a procedure sits beside a reference.

### What it may not do

- **It touches no `3tk/src`.** Not one character. The loop's first real use is
  3TK-40.
- **It rules nothing.** A decision no document holds is reported.
- No `git`. No edit to `../common/`. Nothing said to dtk.

### Output and verification

- `ref/3tk-doc-loop-001.md`, and the checker script.
- **The checker run over `helper.c3` reproduces 3TK-37's result** — every
  descriptor sentence found, 0 missing. That is the stage's own proof that the
  script matches the hand method.
- **Banned-word scan run live.** Hits reported.
- **Part 6's markdown rules** — no trailing `\`, blank line before every list,
  checked by script with fenced blocks skipped.
- `3tk/run-builds.sh` green. Four builds, 63 checks, 87 tests.
- Status row, log entry, **the clear advice and the exact continue line**.

---

## 3TK-40, 3TK-41, 3TK-42 — the seven files

**Start after clear:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-40.
```

and the same line for 3TK-41 and 3TK-42.

### Why they exist

**The seven files still carry descriptors that were never moved out of a
document.** They are what subtraction left, not what the reference says.

### What they do

**Each runs `from-reference` per file, and nothing else.**

- **3TK-40** — `mtk.c3`, `inner.c3`, `managed.c3`
- **3TK-41** — `queue.c3`, `stack.c3`
- **3TK-42** — `mailbox.c3`, `pool.c3`

**No new method is invented in any of them.**
[ref/3tk-doc-loop-001.md](ref/3tk-doc-loop-001.md) is the method, and these
three are the first evidence that it survives a file it was not written
against.

**`pool.c3` decides it.** 19 of the 63 contracts, the three hook methods
documented inside the struct that declares them, and the late-close note the
owner named as the deletion worth refusing. Part 6 of the reference describes
the pre-lock re-read, so a short form has somewhere to be moved from —
**whether it goes back into the source is the owner's, and the stage reports
rather than rules.**

### The debt 3TK-38 left them

**Four files declare `module mtk;` — `mtk.c3`, `inner.c3`, `queue.c3` and
`stack.c3` — and each carries a file-header `<* *>` block. C3 gives a module
ONE description, and `c3c docgen` keeps whichever file it reaches first.**
Measured 2026-08-26 by probe: with a bare `src/` argument the page's `mtk`
description is `queue.c3`'s *The intrusive queue*; pass `stack.c3` first and it
becomes *The intrusive stack*; pass `mtk.c3` first and it is the intended
*Matryoshka, the C3 port*. **The order is c3c's traversal, not alphabetical,
and no source can control it.**

**The four submodules are unaffected** — `helper`, `managed`, `mailbox` and
`pool` are one file each, so their descriptions are theirs and always will be.

**3TK-40 owns `mtk.c3` and `inner.c3`. 3TK-41 owns `queue.c3` and
`stack.c3`.** Between them they open every file involved, which is why the fix
is theirs and not a stage of its own.

**The owner ruled it, 2026-08-26. Combine, do not demote.**

**The file header is merged with the doc block of the first declaration below
it, into ONE `<* *>` block on that declaration.** It does not become a `//`
comment and it is not deleted. What the fix rests on is that **no `<* *>` block
is left immediately above `module mtk;`** in those three files, so C3 has one
module description to find — `mtk.c3`'s — and the traversal order stops
mattering.

| stage | file | the header merges onto |
|---|---|---|
| 3TK-40 | `mtk.c3` | **nothing — it keeps its module header.** It is the only one describing `module mtk` rather than a file |
| 3TK-40 | `inner.c3` | `struct Inner` |
| 3TK-41 | `queue.c3` | `struct InnerQueue` |
| 3TK-41 | `stack.c3` | `struct InnerStack` |

Each target is the first declaration in its file.

**`inner.c3` is the awkward one and 3TK-40 reports rather than rules it.** Its
header — *The inner, the handle, the Slot, the link test, and the port's check
macro* — lists what the FILE holds; merged onto `struct Inner` unchanged it
would claim the struct is all five. **The stage prints the merged block and
asks**, and does not reword on its own initiative. `queue.c3` and `stack.c3` do
not have this problem: their headers describe the container the struct heads.

**The markers move with the sentences they mark.** Each header carries its own
`// [3tk: ...]` line, distinct from the declaration's. A clause that is about
the moved text moves into the merged block's marker line; a clause about
`module mtk` itself stays on the `module mtk;` line. **Both marker lines are
printed before and after**, so a lost clause is visible rather than silent. If
a clause is arguable, it stays where it is and the stage says so.

- **Nothing is deleted.** Every sentence in the three headers is in
  [ref/3tk-reference-001.md](ref/3tk-reference-001.md) or moves there first.
- **The invariant is not suspended by this ruling.** A merge that produces a
  sentence the reference does not hold is a defect of the reference, fixed
  there first, and the run says it did that.
- **No declaration, signature, body, string or contract changes.** This is
  doc-comment work, like the rest of the stage.

**Two checks, run rather than argued.**

- **After 3TK-40 and again after 3TK-41**: `grep` finds no `<* *>` block
  immediately above `module mtk;` in the file the stage touched.
- **After 3TK-41**: `c3c docgen` over a bare `src/` gives the `mtk` description
  of `mtk.c3` — **and the same is checked with the four files passed in a
  deliberately hostile order**, `stack.c3` first, which is the order that
  produced the wrong page before.

**A script-side fix exists and was not taken.** Passing `src/mtk.c3` ahead of
`src/` makes the preview deterministic — probed, 83 declarations either way, no
duplication. It fixes one script and not `c3c docgen`, so it is the owner's
call whether `3tk/preview-docs.sh` carries it as well.

### What they may not do

- **They change no code**, no string, and no contract.
- **They do not go past their own files.**
- **They do not invent.** A gap is a defect of the reference and is fixed there,
  and the stage says it did that.
- No `git`. No edit to `../common/`. Nothing said to dtk.

### Output and verification

Per stage, and per file inside it.

- **Every descriptor shown to exist in the reference**, by the checker, printed.
- **The contract count and text identical**, compared as sorted lines, both
  sides printed.
- **`c3c docgen` run, and `formatDocText` run over its output.**
- **`3tk/run-builds.sh` green** — four builds, 63 checks, 87 tests.
- Status row, log entry, **the clear advice and the exact continue line**.

**Two signals recorded by all three**, because they are what says whether the
procedure is fit to offer another port.

- **How often a sentence has no home in the reference.** Often means the
  reference's shape is wrong, not the sentence.
- **How often the check fails for a defect in the rules** rather than in the
  text.

**If both stay low across seven files, the approach is checked.** If not,
`ref/3tk-doc-loop-002.md` is where the correction goes.

---

## Rules that hold for all five

- **Every stage ends with `3tk/run-builds.sh` green and the counts stated** —
  four builds, 63 checks, 87 tests.
- **Every stage ends with the clear advice and the exact continue line**,
  written into [3tk-log.md](3tk-log.md) and [3tk-status.md](3tk-status.md).
  **The owner's standing requirement.** Advice that exists only in a
  conversation about to be cleared is worth nothing.
- **A stage that finds itself deciding reports instead.** 3TK-19's precedent.
- **A stage that finds itself inventing prose reports instead.** Plan 016's
  addition, and the reason its order worked.
- **[../../../rules-049.md](../../../rules-049.md) Part 4 and Part 6 bind every
  stage**, and Part 4's live-scan rule means a scan is claimed only when it has
  just been run.
- **A rendering claim is made only after running the renderer**, never from
  reading the source.
- **`src/` at the repository root is ztk's Zig source and is not touched.**
- **No stage writes under `../common/`.** Specification 004 stands.
- **No stage edits `design/matryoshka-api-reference-042.md`.** It is ztk's.
- **No stage runs `git`.** Moves are plain `mv`. The owner saves.
- **No stage tells dtk anything.**
- **Nothing cites `backup/` as a source of truth.** The owner empties it.

## Versioning

Two entry points are edited in place — [3tk-status.md](3tk-status.md) and
[3tk-log.md](3tk-log.md). **Everything else is versioned.**
`ref/3tk-doc-loop-001.md` is a new file; a change to it makes the next number
and the old file moves to `backup/`.

**`ref/3tk-reference-001.md` is the exception this plan creates.** The loop
edits it in place, in both directions, and a new number per iteration would
bury `backup/` in near-identical copies. A **stage** that revises it still
versions it. A **loop run** does not. `ref/3tk-doc-loop-001.md` says so of
itself.

## What this plan deliberately leaves to the owner

Named so no stage picks them up by accident.

- **Whether [ref/3tk-api-002.md](ref/3tk-api-002.md) is retired** now that the
  reference exists. 3TK-36 reported the overlap and did nothing about it.
- **Whether `helper.c3` carries a worked example.** The `struct Msg` block is in
  Part 3 of the reference. 3TK-37 did not put it back.
- **Whether `stack.c3`'s last-in first-out reasoning and `pool.c3`'s late-close
  note return to the source.** Both are in the reference and in
  [ref/3tk-decisions-001.md](ref/3tk-decisions-001.md). 3TK-41 and 3TK-42 report
  them; neither rules.
- **Promotion to the other ports.** When the loop is checked, it reaches dtk and
  otk as a findings document that describes what 3tk did — the path
  [3tk-port-findings-003.md](3tk-port-findings-003.md) already takes. **Nothing
  moves to `../common/` unless the owner rules that the procedure binds every
  port**, and that is a separate ruling from *it worked here*.
- **When the `// [3tk: ...]` marks come out.** They exist until 3tk matures.
- **[3tk-who-supports-slot.md](3tk-who-supports-slot.md)** — still open, still
  ruled on by nothing.
- **`3tk-porting-proposal-005.md`** — 004 describes the port before the redesign
  replaced it. A revision, not a stage.
- **The ztk/3tk `on_get` difference**, recorded in
  [3tk-port-findings-003.md](3tk-port-findings-003.md) §5a.
- **`design/secondary/context.md` lists no `lang/` subfolder**, so every file
  here is an orphan by `check_design.sh`'s count. Left as drift by the owner's
  ruling of 2026-08-25.
- **The seven documents whose provenance line links a plan that has left
  `backup/`.** One line each, the same repair, reported and not done.
