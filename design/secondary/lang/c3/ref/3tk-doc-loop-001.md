# 3tk — the doc loop

How a `<* *>` block in `3tk/src` and
[3tk-reference-001.md](3tk-reference-001.md) are kept saying the same thing.

**This is a procedure, not a stage.** It writes no status row and no log entry.
A named stage that uses it writes those. See *What this document is* below.

**Its inputs are fixed**: [../3tk-status.md](../3tk-status.md), this file,
[3tk-reference-001.md](3tk-reference-001.md), and the one source file named on
the command line. Not a transcript.

**Written by 3TK-39**, from what 3TK-37 did by hand over `helper.c3`.

## The invariant

> Every descriptor line in `3tk/src` appears in
> [3tk-reference-001.md](3tk-reference-001.md).

**The check runs one way only.**

- The reference is allowed to say more. *Usual flow*, the diagrams, the whole
  of Part 6.
- The source is a subset of the reference. Never the reverse.
- The property that matters is that **no comment says anything the reference
  does not**.

**That one check drives both directions**, which is why there is one invariant
and not two procedures.

- The reference is edited, the comments are rewritten from it, the check
  passes.
- A comment is edited, the check **fails on that line**, and the failure is the
  trigger to fold it into the reference.

**Why the reference is the wider document.** It carries the argument, the
diagrams and the worked examples. A source file carries the descriptor and the
contracts. Subtracting one from the other is the whole method.

## The three modes

### `check`

**Reports drift. Changes nothing. Safe at any time.**

What it does.

- Runs [../3tk/check-doc-loop.sh](../3tk/check-doc-loop.sh) over one file, or
  over all eight.
- Prints every descriptor sentence, found and not found.
- Runs the live banned-word scan over the same files and over the reference.

What it may not do.

- It edits nothing. Not `3tk/src`, not the reference.
- It rules on nothing. A missing sentence is a report, not a verdict.

Output and verification.

- The script's report, and its exit status. 0 when nothing is missing and the
  ban scan is empty.
- Nothing else. There is nothing to verify, because nothing changed.

### `from-reference <file>`

**The reference was edited. The file's comments are rewritten from it.**

What it does.

- Reads the reference's sections for that file's declarations.
- Rewrites each `<* *>` block from those sentences, in the register named
  below.
- Runs `check` on the file afterwards. 0 missing, or the run is not done.
- Runs `3tk/preview-docs.sh` and reads the rendered page, not the source.
- Runs `3tk/run-builds.sh`.

What it may not do.

- **It writes no sentence that is not in the reference.** See *Moved, never
  composed*.
- **It touches no contract, no signature and no body.** Doc comments only.
- It does not delete a `// [3tk: ...]` mark. The marks are the decisions
  file's index into the source.

Output and verification.

- The rewritten file, and the `check` report over it.
- **Contracts compared as sorted lines, before and after.** Identical, or the
  run is not done. That comparison is what made 3TK-37's claim mean anything.
- Every block rendered, by `3tk/preview-docs.sh`.
- `3tk/run-builds.sh` green.

### `to-reference <file>`

**The comments were edited. They are folded into the reference.**

What it does.

- Runs `check` first, to get the list of sentences the reference does not hold.
- For each one, finds the group in the reference where it belongs, and adds it
  there.
- Runs `check` again. 0 missing.

What it may not do.

- **A sentence that fits no existing group is reported, not filed.** See below.
- It does not restructure the reference. Parts 3 to 5 repeat one order, and a
  fold does not change that order.
- It does not touch `3tk/src`. The source is the input in this direction.

Output and verification.

- The revised reference, and the `check` report over the file.
- The list of sentences reported rather than filed, if any.
- The live banned-word scan over the reference.
- **The source file byte-identical before and after.**

### How a mode is invoked

Like a stage, after a clear.

```
Read design/secondary/lang/c3/3tk-status.md.
Run doc-loop from-reference on pool.c3.
```

## The rules this document holds

**These are the part no script can apply.**

### A true sentence still may not belong in a `<* *>` block

**This is the reason this is a document and not only a script.**

- A sentence can be true, be in the reference, and still not belong in a
  source comment.
- **Design argument and implementation notes go to
  [3tk-decisions-001.md](3tk-decisions-001.md)**, and the `// [3tk: ...]` mark
  points at them.
- That is what 3TK-31 was refused twice for.
- A `<* *>` block holds the descriptor and the contracts. Nothing else.

### Moved, never composed

- **A sentence not in the reference is not written into the source.**
- `from-reference` moves. It does not compose.
- A gap is **a defect of the reference**, and is fixed there first.
- The run says that it did that. 3TK-37 added one sentence to Part 3 and
  recorded it as a defect of 3TK-36, repaired at its source.
- The rule is [../3tk-staging-plan-016.md](../3tk-staging-plan-016.md)'s.

### A sentence that fits no group is reported

- In `to-reference`, a sentence with no home in the reference is **reported to
  the owner**.
- It is not filed into a new group invented for it.
- Otherwise the reference becomes a place things are put, which is the failure
  mode of making the loop cheap.

### Contracts, signatures and bodies are never touched

- Doc comments only, in every mode.
- `@param`, `@require`, `@ensure` and the rest are not the loop's business.
- The proof is the sorted-line comparison, before and after.

### The direction is an argument, never a guess

- `from-reference` says the reference wins.
- `to-reference` says the source does.
- **The owner says which round it is.** A script cannot know, and neither can a
  session that reads only the files.

### The module header, and the one description C3 gives

- Four files declare `module mtk;`. C3 keeps one description for the module,
  and `c3c docgen` keeps whichever file it reaches first.
- **No `<* *>` block may sit above `module mtk;`** in `inner.c3`, `queue.c3` or
  `stack.c3`. `mtk.c3` keeps its module header.
- Measured 2026-08-26. The full measurement is in
  [../3tk-status.md](../3tk-status.md), in 3TK-38's section.

## The rules that are elsewhere, by link

**Restating a rule makes a second source of truth that will drift from the
first. This folder has paid that bill before.**

| What | Where |
|---|---|
| The register for a source comment | [../3tk-status.md](../3tk-status.md), *The register for a source comment is ztk's, not this folder's* |
| The measured renderer facts — no `\`, one source line per rendered line, backticked identifiers, ` ```c3 ` fences | the same section |
| The banned words, and the scoped bans | [../../../../rules-049.md](../../../../rules-049.md), Part 5 |
| Staccato, and the markdown rules | [../../../../rules-049.md](../../../../rules-049.md), Part 6 |
| Moved, never composed | [../3tk-staging-plan-016.md](../3tk-staging-plan-016.md) |
| What each decision was, and where it lives | [3tk-decisions-001.md](3tk-decisions-001.md) |

## The checker script

[../3tk/check-doc-loop.sh](../3tk/check-doc-loop.sh), beside `run-builds.sh`.

**Facts only, no opinions.**

```
./check-doc-loop.sh              # every file in src/
./check-doc-loop.sh pool.c3      # one file
```

Exit 0 when nothing is missing and the ban scan is empty. 1 otherwise. 2 on a
usage or environment failure.

### What it checks

- **Every descriptor line** of the named files, split into sentences, matched
  against the reference.
- **Blank lines, contract lines and fenced code blocks are dropped.** What is
  left is what the file claims.
- **Both sides are printed** — found, and not found, each with its line number.
- **The live banned-word scan**, over the files and over the reference.

### Whitespace-normalised, and three named shapes

**Both sides are collapsed to single spaces before they are compared.** The
reference wraps a sentence across two source lines and a `<* *>` block never
does. 3TK-37 hit exactly this: a plain `grep -F` reported three misses that
were defects of the grep, not of the document.

**Three further shapes are normalised.** Each one is a form the register asks
for and the reference does not use. **The shape that carried a match is
printed with it**, so a reader can see which rule was used.

- `plain` — the sentence is in the reference as it stands.
- `pronoun` — the comment says *It looks.*; the reference says *`from_slot` —
  looks.* The subject is the declaration either way.
- `variant` — the register's *Same as `x()`.* A cross-reference is not a claim.
  What is checked is that `x` is declared in `src/`, and that the difference
  clause after the comma is in the reference.

**Terminal punctuation is dropped from the sentence being looked for**, because
the reference often continues a sentence the comment ends.

### What the ban scan reads

- In a `.c3` file, **only the `<* *>` text**. A mutex's `unlock()` is a stdlib
  name, and Part 5 says a stdlib name is not a hit.
- In the reference, the whole file.
- **The word list in the script is a copy for scanning.** Part 5 of
  [../../../../rules-049.md](../../../../rules-049.md) stays the source of
  truth, and a hit is read against the Part before anything is done about it.

### What it does not do

- It does not rewrite. Neither direction is automated, and neither should be.
- It does not judge a hit. `object` is banned only for an item or a `Handle`.
- It does not wrap `c3c docgen`, `formatDocText` under `node`, or
  `run-builds.sh`. Those stay as they are. This document names them.

### The two it does not replace

- **`3tk/preview-docs.sh`** — a doc comment cannot be judged from its source.
  The renderer is `formatDocText` and it is not CommonMark. Look at the page.
- **`3tk/run-builds.sh`** — four builds. A doc comment cannot break one, and it
  is run anyway.

## What this document is

- **It is not a stage.** It writes no status row and no log entry. Its output
  is a report.
- A named stage that uses it writes those. Otherwise the log stops being
  history and becomes a transcript.
- **Its inputs are fixed**: [../3tk-status.md](../3tk-status.md), this file,
  [3tk-reference-001.md](3tk-reference-001.md), and the one source file.

## Where it stood when this was written

**Measured 2026-08-26, by the script, over all eight files.**

| File | Sentences | Found | Missing |
|---|---|---|---|
| `helper.c3` | 33 | 33 | **0** |
| `inner.c3` | 42 | 11 | 31 |
| `mailbox.c3` | 65 | 35 | 30 |
| `managed.c3` | 17 | 4 | 13 |
| `mtk.c3` | 3 | 0 | 3 |
| `pool.c3` | 98 | 46 | 52 |
| `queue.c3` | 35 | 16 | 19 |
| `stack.c3` | 24 | 11 | 13 |
| **total** | **317** | **156** | **161** |

**`helper.c3` is 3TK-37's file** and is the only one written from the
reference. The other seven carry what the three strip stages left them, which
is why they read as drift.

**The ban scan found three hits, all in doc-comment text.**

- `mailbox.c3:4` — *Many producers, many consumers, on one object.*
- `pool.c3:33` — *The implementing object is the context.*
- `pool.c3:247` — *everything read before the unlock*.

**Reported, not fixed.** 3TK-39 may not touch `3tk/src`.
