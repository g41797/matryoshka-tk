# 3tk — the doc loop

How a `<* *>` block in `3tk/src` and
[3tk-reference-004.md](3tk-reference-004.md) are kept saying the same thing.

**This is a procedure, not a stage.** It writes no status row and no log entry.
A named stage that uses it writes those. See *What this document is* below.

**Its inputs are fixed**: [../3tk-status.md](../3tk-status.md), this file,
[3tk-reference-004.md](3tk-reference-004.md), and the one source file named on
the command line. Not a transcript.

**Written by 3TK-39**, from what 3TK-37 did by hand over `helper.c3`.

**This is 003, written after 3TK-47.** It carries all of `002` and brings two
sections up to what is now true: **the checker script has three reports, not
two**, and **the module header rule was written when four files declared
`module mtk;`**, which stopped being the case at 3TK-44. `002` is in `backup/`,
and `001` before it.

**Nothing else changed.** The invariant, the three modes, the register and the
rules for moving a module description are `002`'s, word for word.

## The invariant

> Every descriptor line in `3tk/src` appears in
> [3tk-reference-004.md](3tk-reference-004.md).

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
  [3tk-decisions-004.md](3tk-decisions-004.md)**, and the `// [3tk: ...]` mark
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

**REVISED at 003. `002`'s rule was written for a layout that no longer exists**,
and left as it stood it reads as a prohibition 3TK-47 broke.

**What `002` said**, measured 2026-08-26 by 3TK-38: four files declare
`module mtk;`; C3 keeps one description per module and `c3c docgen` keeps
whichever file it reaches first; therefore no `<* *>` block may sit above
`module mtk;` in `inner.c3`, `queue.c3` or `stack.c3`.

**What is true now.**

- **The measurement stands. One module, one description.** That is C3's, not a
  choice of this port.
- **Its premise is gone.** 3TK-44 split the core: `inner.c3`, `queue.c3` and
  `stack.c3` declare `mtk::inner`, `mtk::queue` and `mtk::stack`. **Eight files,
  eight modules, one module per file**, so no two files can collide over one
  description.
- **Every one of the eight has a module block, and must.** 3TK-46 wrote them and
  3TK-47 moved them. **Read as a rule: one module block per file, above that
  file's own `module` line.**
- **`002`'s prohibition would come back the day two files declare one module
  again.** It is a consequence of C3's rule, not a rule of its own.

**Measured after 3TK-47, from a generated page and not from the source**: eight
modules, each with its own description, `mtk`'s the one Part 1 holds. The full
measurement is in [../3tk-status.md](../3tk-status.md), in 3TK-47's section.

## The register for a source comment is ztk's, not this folder's

**Ruled by the owner 2026-08-25**, after refusing 3TK-31's first version as
*aish prose, not descriptors*. **Moved here from
[../3tk-status.md](../3tk-status.md) by 3TK-43**, because it is a rule of the
flow and not a state of it.

**The model is `src/*.zig`** — ztk's own doc comments. Read them before writing
a comment in `3tk/src`.

- The first line is a descriptor. `Clears the intrusive list links.`
- No bold. Not one `**` in 1,771 lines of ztk source.
- One fact per line. `Never modifies the node.`
- A variant says `Same as X().` then only its difference.
- Rationale only where short and non-obvious. No argument, ever.

## What the two renderers do

**There are two renderers and they are not the same one.** The reference is
read as CommonMark. A `<* *>` block goes through `formatDocText` inside the
generated `docs.html`. `marked` is referenced there and never loaded, so every
doc comment goes through that one function.

**Every claim below was measured, never read out of the source.** The owner put
a probe into `mtk.c3`'s module header on 2026-08-26 — a heading, a subheading,
a link and a list — and ran it. The rest is `formatDocText` run under `node`
against each shape.

### What `formatDocText` renders

- **Paragraphs from blank lines.** A blank line closes the `<p>`. The next
  non-blank line opens a new one.
- **`#` to `######` headings**, `<h1>` to `<h6>` by the count of hashes.
- **`-`, `*` and `+` bullets.** Each becomes one `<div class="bullet-item">`
  with a literal bullet character.
- **`` `code` `` spans.**
- **Bold**, as `**text**` or `__text__`.
- **Italic**, as `*text*` or `_text_`.
- **`[text](url)` links.**
- **` ```c3 ` fences**, with C3 syntax highlighting. This is the C3 stdlib's
  own convention, 44 fence lines in `lib/std`. An indented block gets neither
  the `<pre><code>` nor the highlighting.

### What it does not render, where a reader would expect otherwise

- **Numbered lists are not implemented.** `1. one` falls through to the
  paragraph branch and renders as the literal text *1. one*. It is in the
  common markdown subset and it is not in this renderer.
- **No tables.** A `|` row renders as its own literal text.
- **No blockquotes.** `> quote` renders as `&gt; quote`.
- **No nested bullets.** An indented sub-bullet renders at the same level as
  its parent. There is no `<ul>` to nest inside.
- **No soft wrap.** Every non-blank line inside a paragraph already gets a
  `<br>`, so one source line is one rendered line. A sentence wrapped across
  two source lines renders broken in half.
- **A trailing `\` is not a hard break.** It renders as a literal backslash.
  The C3 stdlib uses it zero times in `lib/std`. ztk needs it because Zig
  autodoc is CommonMark. 3tk must not use it.
- **Two underscores in a bare word are eaten as italics.**
  `must_from_handle()` renders as *mustfromhandle()*. Inline code is extracted
  before the italic rule runs, so a backticked identifier is safe.

### The intersection

**Confirmed by measurement, 2026-08-26.** A sentence written inside what both
renderers agree on means the same thing on both sides. It may be moved either
way without rewording.

**The intersection is**: paragraphs from blank lines, `-` bullets,
`` `code` `` spans, `**bold**`, `*italic*`, `[text](url)` links, `#` headings,
and ` ```c3 ` fences.

**Two shapes are the reference's alone**: numbered lists and tables. Neither
survives the crossing, and neither belongs in a `<* *>` block anyway.

### The three restrictions that make a copy safe

**All three are already the register's.** They are restated here as one list
because a copy is where they bite.

- **One sentence per line, and never a wrapped one.** **This is the one that
  bites.** CommonMark joins wrapped lines into a paragraph. `formatDocText`
  puts a `<br>` between them. **Re-flowing is not reversible**, which is why a
  block destined for a module is written unwrapped in the reference.
- **Every identifier in backticks.** Bare, `must_from_handle()` loses its
  underscores here and keeps them under CommonMark. Backticked, both are right.
- **No trailing `\`.** A hard break in CommonMark, a literal backslash here.

**The checker already assumes the first of the three.** It collapses whitespace
on both sides before comparing, which is exactly the re-join above, and it is
why a wrapped reference sentence matches a one-line comment.

## Moving a module description

### The correlation

**One module, one labelled block.**

- The label carries the module's name.
- The source side is the `<* *>` block directly above `module X;`.
- **Nothing else is needed to move it in either direction.**

### The two kinds of move

**They are checked differently, and this is the difference.**

- **A declaration's descriptor is judged, then checked as a subset.** The
  invariant is one-way: every sentence in the source is in the reference. The
  reference is allowed to say more.
- **A module block is copied whole, then checked with a `diff`.** Both sides
  hold the same text. There is nothing for a judgement to add.

**This revises 001's *neither direction is automated, and neither should be*.**
It stands for a declaration's descriptor. **It does not stand for a module
block**, where the move is a copy and the check is a `diff`.

### The exemption

**The rule *descriptor and contracts, nothing else* binds a declaration, not a
module.**

- A declaration's `<* *>` block holds the descriptor and the contracts.
- A module block is the module's page. It carries what the reference's section
  for that module carries.
- **A sentence refused from a declaration is not thereby refused from a module
  block.** Design argument still goes to
  [3tk-decisions-004.md](3tk-decisions-004.md) either way.

## The rules that are elsewhere, by link

**Restating a rule makes a second source of truth that will drift from the
first. This folder has paid that bill before.**

**Two rows left this table at 3TK-43.** The register and the measured renderer
facts were held in [../3tk-status.md](../3tk-status.md) by link. They are in
this file now, above, because they are rules of the flow and that file holds
state.

| What | Where |
|---|---|
| The banned words, and the scoped bans | [../../../../rules-049.md](../../../../rules-049.md), Part 5 |
| Staccato, and the markdown rules | [../../../../rules-049.md](../../../../rules-049.md), Part 6 |
| Moved, never composed | [../3tk-staging-plan-016.md](../3tk-staging-plan-016.md) |
| What each decision was, and where it lives | [3tk-decisions-004.md](3tk-decisions-004.md) |

## The checker script

[../3tk/check-doc-loop.sh](../3tk/check-doc-loop.sh), beside `run-builds.sh`.

**Facts only, no opinions. It reports, and it rewrites nothing.**

```
./check-doc-loop.sh              # every file in src/
./check-doc-loop.sh pool.c3      # one file
```

Exit 0 when nothing is missing, no block differs and the ban scan is empty.
1 otherwise. 2 on a usage or environment failure.

### What it checks

**Three reports, and the exit status covers all three.** REVISED at 003: `002`
listed the first and the third, and the block check did not exist when it was
written. 3TK-47 added it and reported the gap rather than versioning this file.

- **Every module block**, transformed and `diff`ed against the reference's
  labelled block. **One leading space per line, and nothing else.** A difference
  is named by module and printed as a unified diff. This is the *copied whole*
  half of *The two kinds of move*.
- **Every descriptor line** of the named files, split into sentences, matched
  against the reference. This is the *judged, then checked as a subset* half.
- **The live banned-word scan**, over the files and over the reference.

**Blank lines, contract lines and fenced code blocks are dropped** from the
descriptor check. What is left is what the file claims. **Both sides are
printed** — found, and not found, each with its line number.

**The two reports are separate because they are read differently.** A block
that differs is a failed copy and is fixed by moving it. A missing sentence is
a judgement and is read before anything is done.

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

- It does not rewrite. **For a declaration's descriptor, neither direction is
  automated, and neither should be.** A module block is the exception: it is
  copied whole and checked with a `diff`. See *The two kinds of move*.
- It does not judge a hit. `object` is banned only for an item or a `Handle`.
- It does not wrap `c3c docgen`, `formatDocText` under `node`, or
  `run-builds.sh`. Those stay as they are. This document names them.
- **It does not move anything.** It reports that two sides differ.
  [../3tk/move-module-docs.sh](../3tk/move-module-docs.sh) is what moves a
  module block, and the direction is its first argument.

### The mover, and the one place the format lives

**[../3tk/move-module-docs.sh](../3tk/move-module-docs.sh)**, beside
`run-builds.sh`. Written by 3TK-47.

```
./move-module-docs.sh in  [module ...]   # reference -> src
./move-module-docs.sh out [module ...]   # src -> reference
./move-module-docs.sh roundtrip          # writes neither, compares bytes
```

- **`in` is `from-reference` and `out` is `to-reference`.** The direction is an
  argument here for the same reason it is one in a mode: a script cannot know
  which round it is.
- With no module named, all eight, **`mtk` first**.
- **`roundtrip` moves in and back out on a copy of both sides and diffs.** A
  block that does not come back byte-identical means the format is not
  byte-exact, and that is reported, not adjusted until it passes.
- **[../3tk/doc_blocks.py](../3tk/doc_blocks.py) holds the two sides and the one
  transformation**, and both scripts read it. There is one place where the
  format lives, so the checker and the mover cannot drift apart.

### The two it does not replace

- **`3tk/preview-docs.sh`** — a doc comment cannot be judged from its source.
  The renderer is `formatDocText` and it is not CommonMark. Look at the page.
- **`3tk/run-builds.sh`** — four builds. A doc comment cannot break one, and it
  is run anyway.

## What is waiting for a ruling

**Five private helpers carry `//` comments instead of `<* *>` blocks.**
`Mailbox.enqueue`, `Mailbox.dequeue`, `Mailbox.has_queued`, `Pool.bucket_for`
and `Pool.take_back`. 3TK-42 put them that way and asked for a ruling.

**The rule it implies, unruled**: the invariant binds the `<* *>` blocks, which
are the public page, and an internal helper is documented with `//`.

**Not a rule of this document until the owner says so.** 3TK-43 records the
question here and does not answer it.

## What this document is

- **It is not a stage.** It writes no status row and no log entry. Its output
  is a report.
- A named stage that uses it writes those. Otherwise the log stops being
  history and becomes a transcript.
- **Its inputs are fixed**: [../3tk-status.md](../3tk-status.md), this file,
  [3tk-reference-004.md](3tk-reference-004.md), and the one source file.

## Where it stood when this was written

**Measured after 3TK-47, by the script, over all eight files.**

- **0 differing module blocks over eight.** Both sides equal, and the round
  trip byte-exact.
- **439 sentences, 438 found, 1 missing.** The count rose against 3TK-43's
  because the module blocks are longer, not because the source drifted.
- **The one missing is `inner.c3`'s merged file header**, 3TK-40's open
  question, still unanswered.
- **The owner's markdown probe is gone.** 3TK-47 replaced it with Part 1's
  block, which retired six of the seven 3TK-43 counted.
- **The ban scan is 0**, over all eight files and over the reference.

### What 3TK-43 measured, when `002` was written

**Measured 2026-08-26 by 3TK-43, by the script, over all eight files.**

- **335 sentences, 328 found, 7 missing.**
- **Six of the seven are the owner's markdown probe** in `mtk.c3`'s module
  header. A probe is not a descriptor, so the reference does not hold it and
  should not.
- **The seventh is `inner.c3`'s merged file header**, 3TK-40's open question.
- **The ban scan is 0**, over all eight files and over the reference.

### What 3TK-39 measured, before the loop had run

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
