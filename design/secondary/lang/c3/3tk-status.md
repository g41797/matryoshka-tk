# 3tk — status

Current state of the 3tk line of work. One screen. Updated after every stage.

This file is the entry point for a cold session. Read it, then the stage named  
by the owner. **[3tk-staging-plan-018.md](3tk-staging-plan-018.md) is spent** —  
all five of its stages have run, and so have all five of  
[3tk-staging-plan-017.md](3tk-staging-plan-017.md)'s and all six of  
[3tk-staging-plan-016.md](3tk-staging-plan-016.md)'s.  
For what else is in this folder and who reads it, see [README.md](README.md).

**For what was decided about the port and where it lives in the code, read  
[ref/3tk-decisions-002.md](ref/3tk-decisions-002.md).** One common section and  
one per source file, every entry with its marker and its `file:line`. It is  
read instead of travelling through the folder. This file stays the first read:  
it holds state, and the decisions file holds none.

**To learn the toolkit, read [ref/3tk-api-002.md](ref/3tk-api-002.md).** What
each thing is for, when to reach for it, and what it refuses to do — written
for the person calling it. No clause numbers, no markers, no `file:line`.

**To check that 002 is telling the truth, read
[ref/3tk-api-003.md](ref/3tk-api-003.md).** The same surface as a verification
table: every assert and every contract clause copied from `3tk/src` with its
`file:line`. **Not the page to learn from** — that is what 002 exists to fix.

**To read the toolkit as a book, read
[ref/3tk-reference-002.md](ref/3tk-reference-002.md).** Seven parts, in 042's
shape, with Parts 3 to 5 repeating one order. It covers the same surface as
[ref/3tk-api-002.md](ref/3tk-api-002.md) and says the same things in a
different arrangement. Whether that file stays is the owner's call.

**Part 7 of the reference also holds the eight labelled module blocks**, under
*The modules, one by one*, each between `<!-- 3tk:module X -->` and
`<!-- /3tk:module -->`. Written by 3TK-46, and **moved into `3tk/src` by 3TK-47**
— one leading space per line and no other change. **The two sides are equal
today**, and `./3tk/check-doc-loop.sh` diffs them on every run.

**`ref/` holds two kinds of document.** The four above are the toolkit's
content. **[ref/3tk-doc-loop-003.md](ref/3tk-doc-loop-003.md) is the procedure
that keeps that content and the `<* *>` blocks in `3tk/src` saying the same
thing.** Read it before editing either side. It is not a stage and writes no
row here.

## Scope

The Matryoshka port family: **otk** (Odin), **ztk** (Zig, this repo), **3tk**  
(C3), **dtk** (D). 3tk is the active target. otk needs refactoring, later. ztk  
needs tuning, later. dtk has a prepared folder and no stage has run —  
[../d/dtk-status.md](../d/dtk-status.md).

The first deliverable is not C3 code. It is a portable specification of  
Matryoshka, language-neutral and self-contained, usable as the sole input for  
any port.

## Where the work lives

Everything for these stages lives in this folder,  
`design/secondary/lang/c3/` — plans, status, log, reviews, notes, and the code  
at `3tk/`.

**Two of them left on 2026-08-23.** The portable specification and the ztk audit  
now live in [`../common/`](../common/README.md), because they bind every port  
and never bound only this one. The specification always said so of itself — *a  
port is written from this file alone* — while sitting in a consumer's folder,  
and the revision of that day sent the bill: two of the twenty-seven review items  
were *specification* defects, and fixing them here alone would have left the  
same trap set for D and Odin. A shared input inside one consumer's folder is a  
fork waiting to happen. `common/` also contains  
[port-flow-001.md](../common/port-flow-001.md), the 3tk process written as  
process. Every link that named a moved file was corrected in place, both  
directions.

`c3/backup/` contains what is no longer read: the seven raw drafts, superseded by  
`3tk-drafts-review-001.md`, the review that retired proposal 002, and **every  
superseded version** — of the plan, the proposal and the specification. The  
live folder is what is current; `backup/` is the record. Moved 2026-08-23, and  
every link that names a moved file was corrected to `backup/...` in place.

`design/STATUS.md` and `design/STATUS-LOG.md` are not touched by this work and  
show no trace of it.

## Rules that hold across every stage

- Each stage starts cold. Its named inputs plus this file are enough.
- Each stage ends with advice: clear the context, or do not, and why.
- Finishing a stage does not start the next. The owner names it.
- **inner** = the embedded structure. **outer** = the struct that embeds it.
  Never "parent".
- Porting is not transpiling. The specification says what to preserve; each
  port decides how to spell it.
- **A change to `3tk/src` revises `ref/` in the same stage.** Not later, and
  not as a debt for the next stage to pay. **A file under `ref/` that
  contradicts `3tk/src` is a defect of the stage that changed the source** —
  the owner's ruling, 2026-08-25. Everything else in this folder is a frozen
  stage output, so `ref/` is the only place staleness can hide.

## Stages

| Stage | What | Output | State |
|---|---|---|---|
| 3TK-0 | staging plan, status, log | this folder | DONE 2026-08-23 |
| 3TK-1 | ztk audit — sources and docs | `ztk-audit-001.md` | DONE 2026-08-23 |
| 3TK-2 | the portable specification | `matryoshka-specification-001.md` | DONE 2026-08-23 |
| 3TK-3 | review of the seven c3 drafts | `3tk-drafts-review-001.md` | DONE 2026-08-23 |
| 3TK-4 | C3 capability study | `c3-capabilities-001.md` | DONE 2026-08-23 |
| 3TK-5 | the 3tk porting proposal | `3tk-porting-proposal-001.md` | DONE 2026-08-23 |
| 3TK-6 | the toolkit, in C3 | `3tk/` + `3tk-toolkit-notes-001.md` | DONE 2026-08-23 |
| 3TK-7 | the two containers, in C3 | `3tk/` + `3tk-containers-notes-001.md` | DONE 2026-08-23 |
| 3TK-8 | the design review answered, the hiding question measured | `3tk-porting-proposal-004.md` + `3tk/` | DONE 2026-08-23 |
| 3TK-9 | the sanitizer run | `3tk-sanitizer-notes-001.md` + `3tk/` | DONE 2026-08-23 |
| 3TK-10 | the core redesign, as a proposal | `3tk-core-redesign-proposal-001.md` | DONE 2026-08-23 |
| 3TK-11 | the core redesign, in code | `3tk/` + [3tk-core-redesign-notes-001.md](3tk-core-redesign-notes-001.md) | DONE 2026-08-23 |
| 3TK-12 | the deviation audit — the port measured against the specification | [3tk-deviations-001.md](3tk-deviations-001.md) | DONE 2026-08-24 |
| 3TK-13 | specification 003 | [matryoshka-specification-003.md](../common/backup/matryoshka-specification-003.md) | DONE 2026-08-24 — superseded by 004 |
| 3TK-14 | the helper surface, re-thought | [3tk-helper-proposal-001.md](3tk-helper-proposal-001.md) | DONE 2026-08-24 — twelve items + E6, E7. **All ruled** |
| 3TK-15 | the two debts of 3TK-13 — A3 and A5 | `3tk/` + [3tk-debts-notes-001.md](3tk-debts-notes-001.md) | DONE 2026-08-24 — `UNKNOWN_IDENTITY`, and twelve comments that changed a claim |
| 3TK-16 | the helper surface, in code — H0, H0b, H5, H10 | `3tk/` + [3tk-helper-notes-001.md](3tk-helper-notes-001.md) | DONE 2026-08-24 — 35 aliases to 0. **V19 filed** |
| 3TK-17 | Part 7.1 reworded — E6, V19 | [matryoshka-specification-004.md](../common/matryoshka-specification-004.md) | DONE 2026-08-24 — one Part, and **before dtk's first stage**. dtk told |
| 3TK-18 | `Inner.next` becomes `Inner.link` | `3tk/` | DONE 2026-08-24 — two words, no layout or behaviour change. No new document |
| 3TK-19 | the three debts of 3TK-15 and 3TK-17 | `3tk/` + [3tk-deviations-001.md](3tk-deviations-001.md) + [`../odin/`](../odin/odin-to-zig-backport-001.md) | DONE 2026-08-24 — **neither citation was a repointing**. P2 marked fixed, otk told |
| 3TK-20 | what 3tk learned, for another port to read | [3tk-port-findings-001.md](backup/3tk-port-findings-001.md) | DONE 2026-08-24 — ten sections, **recommends nothing**. ztk read, never written |
| 3TK-21 | `struct Inner { any link; }` | `3tk/` | DONE 2026-08-25 — 16 bytes before and after. **`@private` does not apply to a C3 method**, so the two are public. No new document |
| 3TK-22 | the findings document, against the new shape | [3tk-port-findings-002.md](backup/3tk-port-findings-002.md) | DONE 2026-08-25 — §1 re-cut, every citation re-read, **new §1a**. 001 in `backup/`. Recommends nothing |
| 3TK-23 | retire what is no longer read | `backup/` + every link | DONE 2026-08-25 — four files moved, **18 links repointed**, nothing deleted. Two things found and reported, not done |
| 3TK-24 | the pool difference, for another port | [3tk-port-findings-003.md](3tk-port-findings-003.md) | DONE 2026-08-25 — **new §5a**, the `on_get` difference. Every citation printed and read. 002 in `backup/`. Recommends nothing |
| 3TK-25 | the status file becomes an entry point | this file + [3tk-log.md](3tk-log.md) | DONE 2026-08-25 — 1,733 lines to 938. Eight sections out, **nine closed open questions out**, and a false R4 row found |
| 3TK-26 | the stale `inner.c3` citations | [3tk-deviations-001.md](3tk-deviations-001.md) + two | DONE 2026-08-25 — **21 repointed** across three files. Three quoted-transcript numbers left standing, and V1 named as understating itself |
| 3TK-27 | who reads the notes | [3tk-readership-001.md](3tk-readership-001.md) | DONE 2026-08-25 — **three of seven are read**. Retired nothing, moved nothing |
| 3TK-28 | a README for the folder | [README.md](README.md) | DONE 2026-08-25 — **19 live documents indexed**, one line each. Every link printed and checked |
| 3TK-29 | the decisions, one section per source file | [ref/3tk-decisions-001.md](ref/3tk-decisions-001.md) | DONE 2026-08-25 — nine sections, **191 citations**, all 53 source markers and all 72 Parts covered. `3tk/src` untouched |
| 3TK-30 | the API reference skeleton | [backup/3tk-api-001.md](backup/3tk-api-001.md) | DONE 2026-08-25 — **83 public declarations** plus three hook methods. **92 citations, every one verified live**. `3tk/src` untouched |
| 3TK-30b | the caller's page, before 3TK-31 can use it | [ref/3tk-api-002.md](ref/3tk-api-002.md) | DONE 2026-08-25 — **all 83 declarations covered**, every example compiled. 001 stays as the verification table — 003 since 3TK-32. `3tk/src` untouched |
| 3TK-31 | the marks, and comments a human can read | `3tk/src/helper.c3` | DONE 2026-08-25 — the exemplar only. **First version refused as AI prose; rewritten in ztk's register**, then corrected against `c3c docgen`'s real renderer — no `\` break, fenced code, backticked identifiers. Nine marks, 17 contracts identical. The other seven outstanding |
| 3TK-32 | the strings a user actually sees | `3tk/src` + [ref/3tk-api-003.md](ref/3tk-api-003.md) | DONE 2026-08-25 — **21 strings and the one `R12` rewritten, 21 to 0 by grep**. 21 new `// [3tk: ...]` marks carry the removed markers. Four builds green, 63 checks, 87 tests. 003 written, **94 citations re-verified live**, 001 to `backup/` |
| 3TK-33 | strip to descriptor + contracts: `mtk.c3`, `inner.c3`, `helper.c3` | `3tk/src` + `ref/` | DONE 2026-08-26 — **470 doc lines to 194**, 23 contracts character-identical. 8 `.md` refs to 0, 2 ban hits to 0. Four builds green. **82 decisions citations repointed**, 94 api-003 citations re-verified |
| 3TK-34 | strip: `managed.c3`, `queue.c3`, `stack.c3` | `3tk/src` + `ref/` | DONE 2026-08-26 — **319 doc lines to 139**, 7 contracts character-identical. 5 ban hits to 0. Four builds green. **41 decisions citations repointed**, 18 in api-003, every citation re-verified |
| 3TK-35 | strip: `mailbox.c3`, `pool.c3` | `3tk/src` + `ref/` | DONE 2026-08-26 — **481 doc lines to 302**, 33 contracts character-identical. 6 ban hits to 0. Four builds green. **82 decisions citations repointed**, 46 in api-003, all 91 re-verified. **All eight files stripped** |
| 3TK-36 | the reference, in 042's shape | [ref/3tk-reference-001.md](ref/3tk-reference-001.md) | DONE 2026-08-26 — **seven parts, 1,375 lines**, Parts 3 to 5 in one repeated order. **All 88 declaration names present by grep**, every example compiled against `3tk/src`. Ban scan run live, 5 hits reworded. `3tk/src` untouched |
| 3TK-37 | the comments, moved out of the reference | `3tk/src/helper.c3` | DONE 2026-08-26 — the exemplar only. **14 doc blocks, 32 descriptor lines, every sentence found in the reference by grep**. 17 contracts identical. One missing sentence added to the reference, not invented here. `formatDocText` run over all 14 blocks. Four builds green. The other seven outstanding |
| 3TK-38 | the preview script | [`3tk/preview-docs.sh`](3tk/preview-docs.sh) | DONE 2026-08-26 — **the data is embedded, so `fetch` is never reached and `marked` is never loaded**. Three `c3-lang.org` URLs remain and no server can help them. Generates into `mktemp -d`, so `3tk/` stays clean and `.gitignore` needed no line. Four builds green, 63 checks, 87 tests. No source touched |
| 3TK-39 | the doc loop, as a document | `ref/3tk-doc-loop-001.md` + [`3tk/check-doc-loop.sh`](3tk/check-doc-loop.sh) | DONE 2026-08-26 — one invariant, three modes. **The checker reproduces 3TK-37 over `helper.c3`: 33 sentences, 0 missing.** Over all eight, **161 of 317 missing** — the drift 3TK-40 to 3TK-42 close. Three ban hits in doc comments, reported. Four builds green, 63 checks, 87 tests. No source touched |
| 3TK-40 | `from-reference`: `mtk.c3`, `inner.c3`, `managed.c3` | `3tk/src` + [ref/3tk-reference-001.md](ref/3tk-reference-001.md) | DONE 2026-08-26 — **47 missing sentences to 1**. `mtk.c3` 0, `managed.c3` 0, `inner.c3` 1 — the merged file header, which the owner rules on. **Contracts character-identical**, 6 in `inner.c3` and 6 in `managed.c3`. Two reference defects repaired at source. **No `<* *>` above `module mtk;` in `inner.c3`.** `formatDocText` run over all 21 blocks. Ban scan 0. Four builds green, 63 checks, 87 tests |
| 3TK-41 | `from-reference`: `queue.c3`, `stack.c3` | `3tk/src` + [ref/3tk-reference-001.md](ref/3tk-reference-001.md) | DONE 2026-08-26 — **32 missing sentences to 0**, both files. **`c3c docgen` now gives `mtk.c3`'s description over a bare `src/` and again with `stack.c3` passed first** — 3TK-38's defect closed. Six reference defects repaired at source, one of them worth a second look. Contracts character-identical. `formatDocText` run over 19 blocks. Ban scan 0. Four builds green, 63 checks, 87 tests |
| 3TK-42 | `from-reference`: `mailbox.c3`, `pool.c3` | `3tk/src` + [ref/3tk-reference-001.md](ref/3tk-reference-001.md) | DONE 2026-08-26 — **83 missing sentences to 0**, both files. **Across all eight, every remaining gap is outside these two.** The three known ban hits are gone, and the whole-tree ban scan is 0. Two reference defects repaired at source. **Five private helpers moved from `<* *>` to `//`** — reported, and the one ruling this stage asks for. 33 contracts character-identical. `formatDocText` run over all 33 blocks, 125 lines. Four builds green, 63 checks, 87 tests |
| 3TK-43 | the flow document | [ref/3tk-doc-loop-002.md](ref/3tk-doc-loop-002.md) | DONE 2026-08-26 — **`001` carried forward whole, plus the register, both renderers measured, and the rules for moving a module description.** `001` moved to `backup/`. **This file 1,592 lines to 1,506** by the move, one pointer line where the register was; 1,556 with this stage's own record written. Ban scan run live: 5 in `002`, all carried from `001` and all in rule text or a record row. Trailing `\` 0 in both. Four builds green, 63 checks, 87 tests. No source touched |
| 3TK-45 | the stack is public | `3tk/src/stack.c3` + [ref/3tk-reference-001.md](ref/3tk-reference-001.md) + [ref/3tk-decisions-002.md](ref/3tk-decisions-002.md) | DONE 2026-08-26 — **the owner ruled the stack available to an external caller, and the definitions that said otherwise were fixed in the stage**: `R13`'s middle clause and §5.4's *out of the application's surface entirely*, both in `3tk-core-redesign-proposal-002.md`. Four prose places rewritten, **the stack given its own reason — the storage container** — in the reference first and moved to the source. `3tk-deviations-001.md`'s `push_slot` grounds corrected — `R15` stands, the deletion is not reopened. Decisions `001` to `002`. `check-doc-loop.sh stack.c3` 25 of 25, 0 missing; whole tree 7 of 337, unchanged. Ban scan 0. Four builds green, 63 checks |
| 3TK-46 | eight sections, eight labels | [ref/3tk-reference-002.md](ref/3tk-reference-002.md) | DONE 2026-08-26 — **reference `001` to `002`, `001` to `backup/`.** Part 7 has a new *The modules, one by one*: **eight labelled blocks, eight open, eight close, eight distinct names**, counted by a fence-aware script. Five modules that had no section of their own have one. **Parts 3 to 5 untouched.** Part 7's module layout corrected to the eight-module split 3TK-44 left standing. *Usual flow* answered per module: six had none, and `mtk::mailbox` and `mtk::pool` carry the one-line summary while the numbered list stays out. **`formatDocText` run under `node` over all eight — one rendered line per source line**; the same eight rendered as CommonMark — flowing paragraphs, 0 hard breaks, labels invisible. `check-doc-loop.sh` 330 of 337, the same 7. Ban scan 0. **Four builds green, 63 checks, 87 tests each**, re-run after a first run read `mtk.c3` mid-save |

### 3TK-35 ran, and this is what it left

**Done 2026-08-26.** The last of the three strips, on the two largest files.
Subtraction again: no declaration, no signature, no body, no string changed,
and the code compared line for line with the doc comments stripped is identical
in both.

- **481 doc-comment lines to 302.** `mailbox.c3` 213 to 128, `pool.c3` 268 to
  174. Every doc comment is now a descriptor and its contracts.
- **33 contracts kept character-identical** — `mailbox.c3` 14, `pool.c3` 19 —
  compared as sorted lines on both sides, not counted. The three hook contracts
  inside `PoolHooks` are among them.
- **6 banned-word hits to 0.** No `.md` reference fell in these files, before
  or after.
- **No bold marker and no trailing backslash survives.**
- **Every prose `//` comment in a body came out.** Nothing in `3tk/src` is now
  a comment that is neither a descriptor, a contract, nor a mark.
- **53 new `// [3tk: ...]` marks**, 67 in these two files now, 14 before — the
  same judgment 3TK-33 and 3TK-34 took: no marker is lost.

**`put_all`'s worked example survives**, as the one fenced ` ```c3 ` block left
in the port's source. It is what a caller writes instead of the deleted call,
so it is a caller's fact rather than an argument.

**Four bare fault names were wrapped in backticks after the render check.**
`c3c docgen`'s own `formatDocText` ate the underscores in `NOT_AVAILABLE`,
`NOT_CREATED`, `AVAILABLE_ONLY` and `UNKNOWN_IDENTITY`. All 42 doc blocks were
run through the real renderer; after the fix there is no `<em>`, no literal
backslash and no stray `**`. The generated `docs.html` was deleted afterwards.

**Four builds green, 63 checks, 87 tests, 0 failures** — run after the strip
and again after the backticking.

**Both `ref/` files were revised in the same stage.**
`ref/3tk-api-003.md`: 46 citations into the two files repointed, and **all 91
citations re-verified live against the text they quote — 0 mismatches**.
`ref/3tk-decisions-001.md`: **all 82 citations into the two files repointed**,
all 208 checked to land on a non-blank line, and every repointed target printed
and read.

**The debt 3TK-34 reported is paid.** The two `hands` hits in
`ref/3tk-decisions-001.md` are reworded, and a third hit found in the same
scan went with them. `3tk-status.md`'s own `pool.c3:284` and `:396` were
repointed to `:293` and `:394`.

**All eight files are stripped.** 1,270 doc-comment lines are 635. The port has
descriptors and contracts and nothing else, and what was argued in the source is
argued in `ref/3tk-decisions-001.md`, once.

**Reported, not fixed:** `Pool.get`'s `@return? mtk::CLOSED,
mtk::NOT_AVAILABLE, mtk::NOT_CREATED, mtk::UNKNOWN_IDENTITY` renders as
italics, because the renderer eats the underscores in a run of bare names. It
is a compiled contract clause that has to stay character-identical, so the
strip may not touch it, and it pre-dates this stage.

### 3TK-36 ran, and this is what it left

**Done 2026-08-26.** The reference exists. `3tk/src` was not touched, not one
character.

**[ref/3tk-reference-001.md](ref/3tk-reference-001.md), seven parts, 1,375
lines.** Parts 3, 4 and 5 repeat one shape in one order — *What this is*,
*Participants*, *Usual flow*, *The API in named groups*, *Where to go deeper*.

```
Part 1   Introduction
Part 2   C3, interesting parts
Part 3   the core            <- the repeated shape
Part 4   mailbox             <- the repeated shape
Part 5   pool                <- the repeated shape
Part 6   Using them together
Part 7   Beyond the toolkit
```

**Part 3 is the port's answer to 042's Part 3.** 3tk has no `polynode` module,
so the part is called *the core* and carries `Inner`, `Handle`, `Slot`, every
crossing, both containers and the managing helper. Eight named API groups, one
per act.

**All 88 declaration names appear, checked by grep and not by reading.** The
list was cut out of `3tk/src` — 82 top-level declarations, plus the three hook
methods and the three `GetMode` members, which are indented and which a
top-level grep misses. **0 missing.**

- The last two to arrive were `Mailbox.@closed_fast` and `Pool.@closed_fast`.
  They are public because `@private` does not apply to a C3 method, and they
  are not for a caller. Part 6 names them and says to call `is_closed`
  instead.

**Every example compiled.** 3TK-30b's method: three scratch modules built
against `3tk/src` with `c3c static-lib`, every fenced ` ```c3 ` block in the
file drawn from them, and the scratch output removed afterwards. The generated
`headers/` directory was removed too.

**The banned-word scan was run live, over the finished file. 5 hits, all
reworded rather than reported**, because the file is this stage's own output
and nothing older is destroyed by changing it.

- One `unlock`, describing the pool's mutex. Now *before the mutex is
  released*.
- Four `object`, three of them naming a `Mailbox` or a `Pool` — which are
  items, so the scoped ban bites. Now *the tool itself*, *one mailbox*, and
  *the implementing struct*.

**Part 6's markdown rules hold.** 0 trailing backslashes. 0 lists without a
blank line before them, checked by a script over the file with fenced blocks
skipped.

**Four builds green, 63 checks, 87 tests, 0 failures** — a formality for a
stage that edits no code, run rather than assumed.

**The overlap with [ref/3tk-api-002.md](ref/3tk-api-002.md) is reported, not
acted on.** That is the owner's call.

- 002 is 624 lines and covers the same 83 top-level declarations, for the same
  reader.
- The new reference covers all of them and 5 more, in a shape 042 already
  proved.
- **Where 002 is still ahead**: its opening — *what it is*, *what it is not*,
  *the five words* — is sharper than Part 1, and its Slot section reads better
  than Part 6's.
- **Where the reference is ahead**: the repeated shape, the per-tool *Where to
  go deeper*, the hooks group, and Part 2 on the four C3 features.
- **Nothing was retired.** Both files stand, and the entry-point notes at the
  top of this file now name three `ref/` documents.

**Reported, not taken.** Three gaps that 3TK-37 met, and none of them was
invented here. 3TK-37 took none of the three: it moved `helper.c3`'s
descriptors and left every ruling to the owner.

- `helper.c3`'s deleted `struct Msg` example is back in the reference, in Part
  3's *Usual flow*. Whether it returns to the source is still the owner's.
- `stack.c3`'s last-in first-out reasoning is in Part 5's *Participants*, as
  the defect-surfacing sentence. It is not in the source.
- The mailbox's pre-lock re-read is described in Part 6. The source says only
  that the fields are internal.

### 3TK-37 ran, and this is what it left

**Done 2026-08-26.** The exemplar only — `3tk/src/helper.c3`. No other source
file was opened, and no declaration, signature or body changed.

- **14 doc blocks, 32 descriptor lines, 99 doc-comment lines.** The module
  block and 13 members.
- **Every descriptor sentence was shown to exist in
  [ref/3tk-reference-001.md](ref/3tk-reference-001.md), by grep.** 27 distinct
  sentences, 27 found. Three are wrapped across two lines there and needed a
  whitespace-normalised match — the miss was in the grep, not the document.
- **One sentence was missing and was added to the reference, not invented
  here.** The five method forms had no line of their own. Part 3's *crossing*
  group now ends: *Each is the same crossing, as a method on the handle or as a
  method on the Slot.* A defect of 3TK-36, repaired at its source.
- **17 contracts identical**, compared as sorted lines.
- **Three sentences of the old file did not return**, because the reference does
  not hold them: *the inverse of `from_handle()`*, *never modifies the item*,
  and *every creation site calls it*. The reference's own wording covers the
  same facts.
- **The `struct Msg` example was not put back.** It is in the reference. Whether
  a source file carries a worked example is still the owner's.
- **`formatDocText` was run, not read.** `c3c docgen`, then the real function
  lifted out of `docs.html` and run under `node` over all 14 blocks. One source
  line to one rendered line, every identifier as `<code>`, no backslash on the
  page. `docs.html` removed.
- **Banned-word scan run live** over the file and over the reference. 0 hits in
  each.
- **Four builds green, 63 checks, 87 tests, 0 failures.**

**The other seven files are outstanding.** `mtk.c3`, `inner.c3`, `managed.c3`,
`queue.c3`, `stack.c3`, `mailbox.c3`, `pool.c3` still carry the descriptors the
three strip stages left them. Plan 016 leaves that pass to the owner.

### 3TK-38 ran, and this is what it left

**Done 2026-08-26.** A script and this row. No source was touched — not
`3tk/src`, not `ref/`, not `../common/`.

**[`3tk/preview-docs.sh`](3tk/preview-docs.sh)**, beside `run-builds.sh`. It
runs `c3c docgen --emit-stdlib=no` over `3tk/src`, reports what the page does,
then opens it. `--no-open` generates and reports without opening.

**What the self-containedness check found, run live:**

- **The documentation data is embedded** — one `EMBEDDED_JSON_LIST.push`. The
  page's `fetch('docs.json')` is the `else` branch of that test and **is never
  reached here**.
- **`marked` is named and never loaded** — `window.marked ? marked.parse(...) :
  escapeHtml(...)`. The false arm is the arm that runs, which is why the
  renderer is `formatDocText`.
- **Three absolute `c3-lang.org` URLs remain**: favicon, logo, and a
  documentation link. Two are images.

**The plan expected one question and there were two.** A same-origin fetch is
refused by `file://` and fixed by a server; an absolute URL to another host is
**not brought closer by serving the folder**. Only the first is a reason to
serve, and it does not arise here — so `xdg-open` on the file is enough and the
python server ztk needs drops out. The server was written anyway, in ztk's
shape, and **the script chooses at run time** on the embedded-data test.

**Nothing is left in `3tk/`.** `c3c docgen` writes into the current directory,
so the script generates into a fresh `mktemp -d`. `ls -a` after the run is
clean, and **`.gitignore` needed no new line** — the second of the plan's two
options was not taken because the first held.

**`run-builds.sh` green — run, not assumed. Four builds, 63 checks, 87 tests.**

**One defect was found by looking at the page, and it is recorded as a debt on
3TK-40 and 3TK-41 rather than fixed here.** 3TK-38 may not touch source.

**Four files declare `module mtk;`** — `mtk.c3`, `inner.c3`, `queue.c3`,
`stack.c3` — **and each carries a file-header `<* *>` block. C3 gives a module
one description and `c3c docgen` keeps whichever file it reaches first.** On a
bare `src/` argument that is `queue.c3`, so the toolkit's front page reads *The
intrusive queue. First-in first-out.* Probed 2026-08-26: `stack.c3` first gives
the stack's, `mtk.c3` first gives the intended one. **The order is c3c's
traversal, not alphabetical.** The four submodules are one file each and are
unaffected.

**The fix is in [3tk-staging-plan-017.md](3tk-staging-plan-017.md)**, in the
3TK-40 to 3TK-42 section, and **the owner ruled what the three headers become
on 2026-08-26: combine, do not demote.** The file header is merged with the
doc block of the first declaration below it into **one `<* *>` block on that
declaration** — `inner.c3` onto `struct Inner` in 3TK-40, `queue.c3` onto
`struct InnerQueue` and `stack.c3` onto `struct InnerStack` in 3TK-41.
`mtk.c3` keeps its module header, being the only one that describes
`module mtk` rather than a file. **What the fix rests on is that no `<* *>`
block is left above `module mtk;`**, so C3 has one description to find and the
traversal order stops mattering.

**`inner.c3` is reported, not ruled.** Its header lists what the file holds,
not what `struct Inner` is, so 3TK-40 prints the merged block and asks rather
than rewording on its own.

**The script-side fix was offered and not taken.** Passing `src/mtk.c3` ahead
of `src/` makes the preview deterministic — 83 declarations either way — but it
fixes one script and not `c3c docgen`. `3tk/preview-docs.sh` does not carry it.

### 3TK-39 ran, and this is what it left

**Done 2026-08-26.** A document, a script, and this row. No source was touched
— not `3tk/src`, not `ref/3tk-reference-001.md`, not `../common/`.

**`ref/3tk-doc-loop-001.md`** — the procedure. One
invariant: *every descriptor line in `3tk/src` appears in the reference*. The
check runs one way only, and that one check drives both directions.

**Three modes**, each in plan 016's stage shape: `check`, `from-reference
<file>`, `to-reference <file>`. Invoked like a stage, after a clear:

```
Read design/secondary/lang/c3/3tk-status.md.
Run doc-loop from-reference on pool.c3.
```

**[`3tk/check-doc-loop.sh`](3tk/check-doc-loop.sh)** — facts only. Every
descriptor sentence with its line number, found and not found, plus the live
ban scan. It rewrites nothing and rules on nothing.

**The stage's own proof: the script reproduces 3TK-37 by hand.** Over
`helper.c3`, **33 sentences, 33 found, 0 missing**.

**Getting there took three normalisations, and each is named in the output so
a reader can see which one carried a match.** Whitespace collapsed on both
sides — the miss 3TK-37 hit. `plain`, `pronoun` (the comment says *It looks.*,
the reference says *`from_slot` — looks.*), and `variant` (the register's
*Same as `x()`.* is a cross-reference, so what is checked is that `x` is
declared and that the clause after the comma is in the reference).

**The drift over all eight files, measured 2026-08-26: 317 sentences, 156
found, 161 missing.** `helper.c3` is the only file at 0. `inner.c3` 31,
`mailbox.c3` 30, `managed.c3` 13, `mtk.c3` 3, `pool.c3` 52, `queue.c3` 19,
`stack.c3` 13. **That is what 3TK-40 to 3TK-42 close**, and it is a baseline,
not a verdict.

**Three ban hits, in doc-comment text, reported and not fixed** — 3TK-39 may
not touch source. `mailbox.c3:4` *on one object*, `pool.c3:33` *The
implementing object is the context*, `pool.c3:247` *before the unlock*. All
three are 3TK-42's files.

**The ban scan reads only the `<* *>` text of a `.c3` file.** A mutex's
`unlock()` is a stdlib name and Part 5 says a stdlib name is not a hit; the
first version of the script reported 21 of them.

**The document itself scans 6 hits, all of them the document naming a word in
order to state the rule, or quoting one of the three above. Reported, not
reworded** — the same carve-out Part 5 gives its own text.

**`run-builds.sh` green — run, not assumed. Four builds, 63 checks, 87 tests.**

### 3TK-40 ran, and this is what it left

**Done 2026-08-26.** `from-reference` over `mtk.c3`, `inner.c3` and
`managed.c3` — the loop's first use on files it was not written against.

**The drift closed.** 3TK-39 measured 47 missing across the three: `inner.c3`
31, `managed.c3` 13, `mtk.c3` 3. **After: `mtk.c3` 0 of 4, `managed.c3` 0 of
13, `inner.c3` 1 of 47.**

**The one that is left is the merged file header** — *The inner, the handle,
the Slot, the link test, and the port's check macro.* Plan 017 forbids
rewording it on the stage's own initiative, so it is carried verbatim and
reported. See *The merge, and the question it leaves* below.

**Two gaps, both defects of the reference, repaired at source before the
sentence was moved.**

- **`module mtk` is declared by four files, not three.** Part 7's *The module
  layout* said three and its own bullet two lines later named four —
  `mtk.c3`, `inner.c3`, `queue.c3`, `stack.c3`. Corrected in the reference,
  then moved into `mtk.c3`.
- **Where `UNKNOWN_IDENTITY` comes from.** `inner.c3` said it comes only from
  `Pool.get` and `Pool.get_wait`; Part 5's outcomes table scoped the fault but
  never said that. Added there, in the existing group, then moved.

**Nothing else was composed.** Every other sentence in the three files is the
reference's own wording, and the checker prints which shape carried each match
— all 60 are `plain`.

**Contracts character-identical.** `inner.c3`'s six `@param` lines diffed
before and after: no change. `managed.c3`'s six untouched by construction —
every replacement was on descriptor text only.

**`VERSION` gained a doc block.** It had none, and the reference holds *The
toolkit's version string.* Reported rather than assumed: it is an addition, not
a rewrite.

**Two register defects fixed on the way.** `managed.c3` wrapped two sentences
across source lines, which the renderer breaks in half, and it put two facts on
one line. One fact, one line, everywhere now.

**`formatDocText` run over all 21 blocks**, extracted from the generated page
rather than assumed. Every block renders one line per source line. No literal
backslash, no eaten underscore.

**Ban scan 0**, over the three files and over the reference.

**`run-builds.sh` green — run, not assumed. Four builds, 63 checks, 87 tests.**

#### The merge, and the question it leaves

**`inner.c3` no longer has a `<* *>` block above `module mtk;`.** Checked by
script over all four `module mtk;` files: `mtk.c3` **BLOCK ABOVE** — which is
the intended one — `inner.c3` **none**, `queue.c3` and `stack.c3` still have
theirs and are 3TK-41's.

**Combined, not demoted**, as the owner ruled. The header merged into
`struct Inner`'s block, and **both marker lines are kept, stacked**:

```
// [3tk: D1 to D16, R1 to R15, Part 4, Part 9, Part 10.1]
// [3tk: R5, R6, R6b, D3, V12, Part 4.2, Part 5]
struct Inner
```

**No clause was moved between them and none was lost.** Whether they should be
one line is the owner's call.

**The awkwardness plan 017 predicted is real.** The header lists what the FILE
holds — five things — and it now sits above a struct that is one of the five.
The block reads:

```
The inner, the handle, the Slot, the link test, and the port's check macro.

The field you embed.
The chain link and the identity, in one.
```

**The stage does not reword it.** Three ways out, and the owner picks:

1. **Leave it.** One sentence stays outside the reference, and the invariant is
   1 short across `3tk/src`.
2. **Reword to the struct.** Then the first line goes and the check reaches 0.
3. **Move it into the reference.** Part 3's *Where to go deeper* already says
   the same thing as a bullet — `3tk/src/inner.c3` — `Inner`, `Handle`,
   `Slot`, the link, `@check`. Filing the prose form is close to inventing a
   group, which the loop forbids.

#### The two signals plan 017 asked all three stages to record

- **A sentence with no home in the reference: 2 of 62.** Both were real defects
  of the reference and were repaired there. One more — the file header — is
  reported rather than filed.
- **A check that failed for a defect in the rules rather than the text: 0.**
  The checker's three shapes needed no fourth.

**On this evidence the approach holds.** 3TK-41 and 3TK-42 are the rest of it,
and `pool.c3` is still the file that decides.

### 3TK-41 ran, and this is what it left

**Done 2026-08-26.** `from-reference` over `queue.c3` and `stack.c3`.

**The drift closed, both files.** 3TK-39 measured 19 missing in `queue.c3` and
13 in `stack.c3`. **After: 0 and 0.** Across `3tk/src` the count is now **83 of
314 missing, and every one of them is in `mailbox.c3` or `pool.c3`** — 3TK-42's
two files.

**The module description is settled, and 3TK-38's defect is closed.** Both
headers merged onto the struct that heads the container, as the owner ruled:
`queue.c3` onto `struct InnerQueue`, `stack.c3` onto `struct InnerStack`, both
marker lines kept and stacked. **No `<* *>` block sits above `module mtk;` in
`inner.c3`, `queue.c3` or `stack.c3`** — `mtk.c3` alone keeps its module
header, checked by script over all four.

**`c3c docgen` run, twice.** Over a bare `src/` the `mtk` description is
`mtk.c3`'s *An item-transfer and item-reuse toolkit for concurrent C3
programs.* **Run again with `stack.c3` passed first** — the order that produced
*The intrusive queue. First-in first-out.* before — it is the same. 239
declarations either way. Neither header describes a file any more, so no
traversal order can pick the wrong one.

**Six defects of the reference, repaired at source before any sentence moved.**

- **Neither container's section said it was intrusive.** Both openings now do.
- **`is_empty` and `len` had no descriptor** — the queue had only the
  count-is-kept clause, the stack had no bullet at all. Four added.
- **`next` had no return described**, only when the walk ends.
- **The stack was never said to be unable to fail**, where the queue is.
- **The stack's missing tail was in
  [ref/3tk-decisions-001.md](ref/3tk-decisions-001.md) and nowhere in the
  reference.** *There is no tail, so flattening the stack is O(n)* is filed in
  the stack's `len` group. **This one is reported rather than defended** — it is
  close to an implementation note, and the loop says those stay in the
  decisions file. If the owner rules it out of the reference, it comes out of
  `stack.c3` with it.

**Three sentences now say what they said in the reference's words** — the
transfer container, the empty-container returns, and the fast-build guards. No
fact was dropped; the file-header restatements of what `pop_front` and `pop`
already say are kept once, on those blocks.

**`stack.c3`'s last-in first-out reasoning stayed out**, which plan 017 named
as this stage's to report and not rule.

**Contracts character-identical.** `queue.c3`'s one `@param` unchanged;
`stack.c3` has none.

**`formatDocText` run over 19 blocks**, extracted from the generated page. One
rendered line per source line, no literal backslash, no eaten underscore.

**Ban scan 0** over both files and the reference.

**`run-builds.sh` green — run, not assumed. Four builds, 63 checks, 87 tests.**

#### The two signals plan 017 asked all three stages to record

- **A sentence with no home in the reference: 6 of 54**, against 3TK-40's 2 of
  62. Higher, and for a visible reason: these two sections were the thinnest the
  strips left, missing whole descriptors rather than single facts. All six were
  real, and all six were repaired in the reference first.
- **A check that failed for a defect in the rules rather than the text: 0.**
  53 `plain`, one `variant`. No fourth shape was needed.

**The approach still holds after four files it was not written against.**
`pool.c3` is 3TK-42's and is still the file that decides.

### 3TK-42 ran, and this is what it left

**Done 2026-08-26.** `from-reference` over `mailbox.c3` and `pool.c3`, the last
two files of plan 017 and of the eight.

**The drift closed, both files.** 3TK-39 measured 30 missing in `mailbox.c3`
and 52 in `pool.c3`. **After: 0 and 0.** `mailbox.c3` is 67 sentences and
`pool.c3` is 111, every one of them found in the reference.

**The whole-tree ban scan is 0.** All three known hits are gone, and none of
them was fixed by deleting the fact.

- `mailbox.c3:4` now reads *on one mailbox*, the reference's own wording.
- `pool.c3:33` now reads *The implementing struct is the context*.
- `pool.c3:247` now reads *Everything read before the mutex is released is
  stale when it returns*.

**Named by `file:line` and not quoted**, per Part 5 — a row that repeats the
word it removed puts it back.

**Two defects of the reference, repaired at source before any sentence moved.**

- **`@closed_fast` had no descriptor of its own.** Part 6 named the two macros
  together in one plural sentence, so neither file could carry a first line.
  *Each reads the closed flag before taking the lock* was added there.
- **`Pool.close`'s ordering was nowhere in the reference.** *The hook is called
  once, outside the mutex, after the closed flag is set* is a promise a caller
  writing `on_close` depends on, and it was only in the source. Filed in Part
  5's control group.

**Contracts character-identical.** 33 lines across the two files, compared as
sorted lines against the pre-edit files, same fingerprint.

**`formatDocText` run over all 33 blocks**, 125 doc lines, extracted from the
generated page. One rendered line per source line, no literal backslash, no
eaten underscore.

**`run-builds.sh` green — run, not assumed. Four builds, 63 checks, 87 tests.**

#### The one thing this stage asks the owner to rule

**Five private helpers had `<* *>` blocks, and no reference sentence can cover
them.** `Mailbox.enqueue`, `Mailbox.dequeue`, `Mailbox.has_queued`,
`Pool.bucket_for` and `Pool.take_back`. They are internal machinery, and the
reference is a book for a caller: filing them there would be inventing groups,
which the loop forbids. Deleting their descriptors would lose facts that are
true.

**Taken: their text was kept, as plain `//` comments above the declaration.**
The checker reads only `<* *>` text, so the invariant holds and no fact was
dropped. `mailbox.c3`'s enqueue and dequeue carry a line naming this stage.

**The rule this implies, if the owner takes it**: the invariant binds the `<* *>`
blocks, which are the public page, and an internal helper is documented with
`//`. That is a rule of the doc loop and belongs in
`ref/3tk-doc-loop-001.md` — **which this stage did not
edit**, because the loop's rules are not a stage's to write.

#### What this stage moved and did not keep

- **`mailbox.c3`'s *including `--safe=no`*** on the release abort. The
  reference says *aborts in every build mode* and no more. The stronger form is
  in [ref/3tk-decisions-001.md](ref/3tk-decisions-001.md) and in `3tk/negative`.
- **`pool.c3`'s late-close note stayed out**, which plan 017 named as this
  stage's to report and not rule. Part 6 of the reference describes the
  pre-lock re-read, and `Pool.put` now carries the reference's own sentence: *A
  close that arrives while `on_put` runs is handled.* The thirty-line
  explanation is still only in the decisions file. **Still the owner's.**

#### `mtk.c3`'s block is the owner's probe, and it is not drift

**The owner put it there and ran it, 2026-08-26.** A `# First`, a `## Second`,
a bare repository link and a three-item list sit above the real module
description in `mtk.c3`, **and every one of them converted to correct HTML.**

**What it measures.** C3 doc comments carry a common markdown subset:
paragraphs from blank lines, `-` and `*` and `1.` lists, `` `code` `` spans,
and basic `*italic*` and `**bold**` in many renderers, though that last is not
formally specified.

**The checker counts its six lines as missing, and that count is an artifact.**
The invariant asks whether a descriptor sentence is in the reference. A probe
is not a descriptor and has no business being in the reference. **Nothing is
wrong with `mtk.c3`** — 3TK-42 read the checker's report as drift before the
owner corrected it, and this paragraph is the correction.

**Untouched by this stage**, and how long it stays is the owner's.

#### The two signals plan 017 asked all three stages to record

- **A sentence with no home in the reference: 2 of 178**, against 3TK-40's 2 of
  62 and 3TK-41's 6 of 54. **The lowest rate of the three, on the largest pair
  of files.** Both were real defects of the reference and were repaired there.
- **A check that failed for a defect in the rules rather than the text: 0.**
  177 `plain`, one `variant`. No fourth shape was needed across all eight
  files.

**`pool.c3` was named as the file that would decide the approach, and it did
not resist it.** 19 contracts, the three hook methods documented inside the
interface that declares them, and the largest doc surface in the port: 111
sentences, all of them already in the reference or repairable there in two
edits.

### 3TK-43 ran, and this is what it left

**Done 2026-08-26.** `ref/3tk-doc-loop-002.md` written, `001` moved to
`backup/`. **No source touched.**

**`002` carries all of `001`**, and adds four things that had no home.

- **The register for a source comment.** Moved out of this file. It was ruled
  2026-08-25 and it was never state.
- **What both renderers do, measured.** What `formatDocText` renders, and what
  it does not — numbered lists are not implemented, there are no tables, no
  blockquotes, and no nested bullets.
- **The intersection, and the three restrictions that make a copy safe.** One
  sentence per line is the one that bites: re-flowing is not reversible, so a
  block destined for a module is written unwrapped in the reference.
- **How a module description moves.** One module, one labelled block, the
  label carrying the module's name. A declaration's descriptor is judged and
  checked as a subset. **A module block is copied whole and checked with a
  `diff`** — which revises `001`'s *neither direction is automated*, for module
  blocks only. *Descriptor and contracts, nothing else* binds a declaration,
  not a module.

**Two rows left `002`'s table of rules held by link.** They pointed at this
file. They are in `002` now, and the table says so.

**The private-helper question is recorded in `002` and not answered.** 3TK-42
asked for the ruling and the owner has not given it, so `002` holds it under
*What is waiting for a ruling* rather than as a rule. **Still the owner's.**

#### What this stage measured rather than assumed

- **The checker, run live**: 335 sentences, 328 found, 7 missing. Six are the
  owner's probe in `mtk.c3` and the seventh is `inner.c3`'s merged file header.
  Unchanged, as it must be — no descriptor was touched.
- **The ban scan, run live over both files.** `002` has 5, every one carried
  from `001`: `unlock` twice as a stdlib name, `object` once in the rule text
  that names the ban, and the three rows recording 3TK-39's hits. This file has
  13, all in lines this stage did not write. **None fixed** — Part 5 says a
  scan is reported, and it exempts a row that names a word to record its
  removal.
- **Trailing `\`: 0 in both files**, fenced blocks skipped.
- **The blank-line-before-a-list rule is mkdocs's**, and this folder does not
  ship through mkdocs. 99 lines of this file predate the stage and break it.
  Left as it stands.

### 3TK-44 ran, and this is what it left

**Done 2026-08-26.** `3tk/src`, and the callers in `3tk/test` and
`3tk/negative`. **No documentation written, not a sentence of it.**

**Four modules are eight.** `inner.c3` is `module mtk::inner;`, `queue.c3` is
`module mtk::queue;`, `stack.c3` is `module mtk::stack;`, and `mtk.c3` holds
`module mtk;` alone. Eight files, eight modules, and **three of them now have a
description to be given** that they could not hold before.

**3TK-38's defect is retired rather than fixed.** *`c3c docgen` keeps whichever
file it reaches first* needs a module with two files, and there is none.

**Nine declarations live in `mtk.c3` now**, moved from `inner.c3` with their
`<* *>` blocks and markers unchanged: the one `faultdef` line with the seven
faults, `macro @check`, and `const bool CHECKED`. `import std::core::env;` went
with them. **90 call sites did not move because of it** — 65 `mtk::` fault
names, 23 `mtk::@check`, 2 `mtk::CHECKED`, counted live.

**Two spellings changed for a caller**, both named in plan 018:
`mtk::inner::inner_offset` and `mtk::inner::required_alloc_offset`.
`mtk::is_linked` became `mtk::inner::is_linked` in three test files.

**Four call sites plan 018's table did not count**, found by compiling: bare
`reset` in `queue.c3` and `stack.c3`, and `@check` twice inside `inner.c3`'s
`Slot.fill`. All four are qualified now. **The table undercounted; it is not
re-derived, it is corrected here.**

**`mtk.c3`'s probe block says `module mtk` is declared by four files.** After
this stage it is declared by one. **The stage left the sentence standing** —
3TK-44 writes no documentation, and that block is the owner's markdown probe,
which **3TK-47 replaces wholesale with Part 1 of the reference.** Reported, not
repaired.

**`inner.c3`'s merged file header still names the check macro that has left the
file.** That is 3TK-40's open question, and this stage moved the block
unchanged rather than answering it. **Still the owner's.**

#### What this stage measured rather than assumed

- **`c3c docgen` run twice, the files passed in a different order the second
  time.** Eight modules both times, each with the same description.
  `mtk::inner`, `mtk::queue` and `mtk::stack` carry none — their headers are
  still merged onto their structs, which is the gap 3TK-46 and 3TK-47 fill.
- **Contracts as sorted lines across all eight files: identical.** 63 before,
  63 after.
- **`./3tk/check-doc-loop.sh`: 335 sentences, 328 found, 7 missing.**
  Unchanged, as it must be — no descriptor was touched. Ban scan 0 over all
  eight files and the reference.
- **`3tk/run-builds.sh` green.** Four builds, 63 checks, 87 tests.
- **Part 17.2's layering checks read, not assumed.** They grep that
  `mailbox.c3` and `pool.c3` say `module mtk::<name>;` and that neither writes
  a link by hand. Both pass, and neither file was touched. **Their stated
  reason is weaker than their wording** — there is no `@private` left in the
  core to be out of reach of — but the greps are the check, and rewording one
  is not this stage's to do.

### 3TK-45 ran, and this is what it left

**Done 2026-08-26.** It stopped once, on `R13`, and the owner lifted the stop
with a ruling: **the stack is available to an external client, not only to mtk's
own modules, and a definition that disables that is fixed by the stage.**

**What the three markers said, and what happened to each.**

- `R2` — *No general list. `InnerQueue` and `InnerStack`.* Names the two
  containers, rules nothing about visibility. **Untouched.**
- `R11` — *Pool reuse becomes last-in first-out, for defect surfacing, and Part
  11.7 stays silent on order.* About the pool's storage and its order, with
  §1.3's reason. **Untouched.**
- `R13` — *Four public signatures take `InnerQueue*`. **`InnerStack` is internal
  to the pool.** There is no `InnerList`.* Its middle clause is the one that
  disabled the stack, and **it was rewritten**: `InnerStack` is on no signature
  3tk publishes, `Pool` is its only user inside the toolkit, and it is available
  to a caller like the queue.

**§5.4 was rewritten with it.** *Keeping the split is what keeps `InnerStack`
out of the application's surface entirely* became *off every signature 3tk
publishes*, with a REVISED note saying which reading was ever meant. **`R13`'s
first clause never moved** — the four container-typed signatures still take an
`InnerQueue*`, and the ruling does not ask for one to take a stack.

**The stack has its own reason now, and it is not *the pool uses it*.** The
queue is the **transfer** container; the stack is the **storage** container.
*Where the queue carries items across, the stack holds them still.* Written in
`ref/3tk-reference-001.md` first, then moved to `stack.c3` — the loop's
direction, and nothing was composed in the source.

**The four places, before and after.**

- `stack.c3:8-9` — *The pool's private storage. / It does not cross the pool's
  public surface.* → *The storage container. / Where the queue carries items
  across, the stack holds them still. / The pool keeps one per identity, and it
  is the only stack 3tk owns. / No 3tk signature passes one: the four that take
  a container take an `InnerQueue*`.*
- `ref/3tk-reference-001.md`, Participants — *`InnerStack` — many items,
  last-in first-out. The pool's private storage.* → *… The storage container.*
- `ref/3tk-reference-001.md`, closing *The API — the stack* — the two private
  sentences → *The stack is the storage container. Items rest in it until they
  are wanted again, and the newest is the one that comes back first.* plus the
  pool-keeps-one and no-signature-passes-one pair, and *A caller who wants a
  stack declares one.*
- `ref/3tk-decisions-001.md:438` → **`ref/3tk-decisions-002.md`.** The entry
  keeps *the pool keeps one per identity, and it is the only `InnerStack` in the
  port*; *It never crosses the public surface* is gone. A new entry carries the
  stack's own reason. `001` is superseded.

**Two more places said it and were fixed.** *What it is not* in the reference
now ends *and a caller may use either one directly*. `3tk/test/t_stack.c3`'s
file header said *never crosses the public surface* and no longer does.

**One consequence was reported and then corrected the same day.**
`InnerStack.push_slot` was deleted 2026-08-24 on two grounds, and only the
weaker one fell. **`R15` is the ground that stands**: its only caller was ever
`pool.c3:451`, `put_all`'s refusal path, and 002 dropped `put_all` — the
queue's `push_front_slot` went with it. The ruling retires the second ground
only, that no application could reach a stack. **The deletion is not reopened.**
What a public stack raises instead is a new question: whether the stack should
carry a Slot-shaped insert for **symmetry** with `InnerQueue.push_back_slot`,
which is kept because Part 12.5 hands a hook an `InnerQueue* extra` and no 3tk
surface hands anyone a stack. `3tk-deviations-001.md` and
`ref/3tk-decisions-002.md` say this; **nothing is open unless the owner asks for
the symmetry.**

**What this stage did not do.** It changed no signature, no body and no
visibility keyword: nothing in the core is `@private`, and this was a stage
about what is written. It did not touch `../common/`, and it wrote no `git`.

**Verification.** `./3tk/check-doc-loop.sh stack.c3` — 25 sentences, 25 found,
0 missing. Whole tree 330 of 337, **the same 7 as before**: six are the owner's
markdown probe in `mtk.c3` and the seventh is `inner.c3`'s merged file header.
Ban scan 0 over all eight sources and the reference, and run live over the new
prose in the decisions file, the deviations file, the proposal and the test
header. **`./3tk/run-builds.sh` green — four builds, 63 checks, 0 failed.** The
per-build test tally scrolled out of the captured output and was not re-run;
the checks and the four-build verdict are what this stage read.

### 3TK-46 ran, and this is what it left

**Done 2026-08-26.** `ref/` only. **Not one byte of `3tk/src`.**

**`ref/3tk-reference-001.md` became `002`, and `001` is in `backup/`.** A stage
that revises the reference versions it; a loop run does not. Live pointers were
repointed and historical rows were not: `README.md`, all four links in
`ref/3tk-doc-loop-002.md`, this file's header pointer and its open question
about `ref/3tk-api-002.md`, and **`3tk/check-doc-loop.sh`'s `REF` default** —
the last one is outside `ref/` and was changed because a moved reference breaks
the checker for every later stage. It is a script beside `run-builds.sh`, not a
file in `3tk/src`.

**Part 7 has one new subsection: *The modules, one by one*.** Plan 018 said only
three modules have a section a description *could come from*. That is what the
word *from* was doing: **all eight blocks are derived text, none is a section
lifted whole**, so all eight were written into one new place rather than three
of them being labelled where they sit. Part 7 already holds the module layout,
and putting them there is what left **Parts 3 to 5 exactly as they were** —
their repeated order is untouched. Part 7's opening went from three things to
four.

**Eight open, eight close, eight distinct names.** Counted by a fence-aware
script. `mtk`, `mtk::inner`, `mtk::queue`, `mtk::stack`, `mtk::helper`,
`mtk::managed`, `mtk::mailbox`, `mtk::pool`. **The worked example in the prose
says `mtk::NAME`** so that a counter never finds a ninth.

**Where each block came from.**

| block | written from | *Usual flow* |
|---|---|---|
| `mtk` | Part 1 — *What 3tk is*, *What it is for*, *What it is not*, plus Part 7's module layout | Part 1 has none |
| `mtk::inner` | Part 3 — *What this is*, *Participants*, *The API — the Slot*, *The API — the link* | none of its own; Part 3's belongs to the core |
| `mtk::queue` | Part 3 — *The API — the queue* | none of its own |
| `mtk::stack` | Part 3 — *The API — the stack*, as 3TK-45 rewrote it | none of its own |
| `mtk::helper` | Part 3 — *The API — crossing* | none of its own |
| `mtk::managed` | Part 3 — *The API — allocating an item for you* | none of its own |
| `mtk::mailbox` | Part 4 — *What this is*, *Participants*, *Usual flow* | **list left out, summary carried** |
| `mtk::pool` | Part 5 — *What this is*, *Participants*, *Usual flow* | **list left out, summary carried** |

**The *Usual flow* ruling, per module and not once for all.** Six modules have
no *Usual flow* of their own, so there was nothing to decide about. For the two
that do, the flow is a numbered list with nested bullets and **neither shape
survives `formatDocText`**. **No list was reshaped into flat bullets.** Its
one-line summary is a single reference sentence that already survives — *Create,
send, receive, close, release.* and *Write the hooks, create, get, put, close,
release.* — and it was carried instead, together with the plain sentences that
sit under each step. Flattening as well would have put two spellings of one fact
on the same page.

**Two of Part 1's five groups were left out of `mtk`'s block, and this is
why.** *Who it is for* and *What the reader needs before starting* are about
reading the book, not about calling the module. The other three are on the
module's page.

**No bold in any block.** The intersection allows `**bold**`; the register
forbids it; the register is the narrower rule and it wins. The four module
blocks already in `3tk/src` carry none either.

**One divergence found by writing a block.** `pool.c3`'s module block opens its
`put_all` fence with `while (mtk::Handle h = ...)`. **There is no `mtk::Handle`**
— `Handle` is declared in `mtk::inner`, and that spelling is its only occurrence
across `3tk/src`, `3tk/test` and `3tk/negative`. Part 5 says `Handle`. The block
follows the reference, so **3TK-47's copy corrects the source.**

**One fact was corrected in the reference rather than copied out of it.** Part
7's module layout still said `module mtk` is declared by four files, listed five
modules, and put `InnerQueue` and `InnerStack` inside `mtk`. **3TK-44 made it
eight modules and reported that it left this sentence standing.** The table is
now eight rows — module, file, contents — with a REVISED note naming what `001`
said and which stage changed it. Nothing was invented: the split is recorded
state in this file.

#### What this stage measured rather than assumed

- **`formatDocText` extracted from a freshly generated `docs.html` and run
  under `node`** over all eight blocks in their source form, one leading space
  per line. **One rendered line per source line, eight for eight.**
  `mtk::pool`'s fence renders as a single highlighted `<pre><code>`.
- **The same eight rendered as CommonMark.** Flowing paragraphs, **zero hard
  breaks**, and every label invisible in the output.
- **`./3tk/check-doc-loop.sh`: 337 sentences, 330 found, 7 missing.** The same
  seven as 3TK-45 left, which is what touching no source has to mean.
- **Ban scan 0** over the eight sources and over `3tk-reference-002.md`, and 0
  over `README.md`. Run live over this file and `3tk-log.md` as well: every hit
  there is pre-existing prose that names a banned word or quotes the list.
- **`3tk/run-builds.sh` green. Four builds, 63 checks, 0 failed, and 87 tests
  in each of the four.** The tally was captured this time, not left to scroll.
  The first run of the stage read `mtk.c3` mid-save and reported 29 passed and
  34 failed; see *How to continue* below.

### 3TK-47 ran, and this is what it left

**Done 2026-08-26.** The first stage that moved a module description with a
script instead of a reading. **Plan 018 is spent.**

**Two new files beside `run-builds.sh`, and one revised.**

- **`3tk/doc_blocks.py`** — the two sides and the one transformation, in one
  place. A labelled block in the reference; the `<* *>` block directly above
  `module X;`; one leading space per line added going in, stripped coming out,
  and a blank line left blank. It parses and rules on nothing.
- **`3tk/move-module-docs.sh`** — the copy. `in` writes `src/*.c3`, `out`
  writes the reference, `roundtrip` writes neither and compares bytes.
- **`3tk/check-doc-loop.sh`** — now two checks. **A labelled block is
  transformed and `diff`ed**, any difference named by module and printed.
  **Everything else is the sentence-subset check, unchanged.** They report
  separately and the exit status covers both.

**The eight blocks are in `3tk/src`, `mtk` first.** Three of the eight were
insertions: `inner.c3`, `queue.c3` and `stack.c3` had no module block at all
and each has one now, above its `module` line. **No `// [3tk: ...]` mark was
touched, and no declaration's `<* *>` was read or written.**

**The round trip is byte-exact.** In and back out on a copy of both sides:
`diff` over the reference reports nothing. Run twice, before and after the real
move.

**Two changes the copy made to `3tk/src`, both intended.**

- **The owner's markdown probe in `mtk.c3` is gone.** Part 1's block replaces
  it, and six of the seven missing sentences went with it.
- **`pool.c3`'s `put_all` fence says `Handle`, not `mtk::Handle`.** That
  spelling now occurs nowhere in `3tk/src`, `3tk/test` or `3tk/negative`.

**`mtk.c3` was edited under the stage again.** The move wrote it at 17:47:28
and an editor wrote the probe back at 17:47:33. The move was re-run for `mtk`
alone and the builds re-run after it. **The `alias` experiment 3TK-46 reported
is no longer in the file**, and 47 neither removed it nor ruled on it.

#### The one thing this stage reports rather than fixes

**`ref/3tk-doc-loop-002.md` was behind the script in two places, and 47 reported
both rather than revising it** — plan 018 gave 47 no flow-document work.
**The owner ruled the same day: revise it to `003`.** *The checker script* said
two reports where there are three, and *The module header* held a rule written
when four files declared `module mtk;`. **`ref/3tk-doc-loop-003.md` is the live
file and `002` is in `backup/`.** See *The flow document is 003* below.

#### What this stage measured rather than assumed

- **`c3c docgen` run, and the eight module pages read out of the generated
  page**, not out of the source. **Eight modules with a description**, where
  three had none before. `mtk` carries 26 doc lines and its page opens with
  *An item-transfer and item-reuse toolkit for concurrent C3 programs.*
- **`formatDocText` extracted from that page and run under `node`** over all
  eight blocks in their source form. **One rendered line per source line, eight
  for eight**, and `mtk::pool`'s fence one `<pre><code>`.
- **`./3tk/check-doc-loop.sh`: 0 differing blocks over eight**, and **439
  sentences, 438 found, 1 missing.** The count rose because the blocks are
  longer. **The one missing is `inner.c3`'s merged file header**, 3TK-40's
  question — the six probe sentences are retired.
- **Ban scan 0**, run live over the eight sources and `3tk-reference-002.md`.
- **`3tk/run-builds.sh` green. Four builds, 63 checks, 0 failed, 87 tests in
  each of the four.**

#### The flow document is 003

**Revised the same day, on the owner's word, after 3TK-47 reported it.** Not a
stage: it writes no row of its own, and this is its record.
**`ref/3tk-doc-loop-002.md` is in `backup/`.**

**Two sections changed, and nothing else.** The invariant, the three modes, the
register and the rules for moving a module description are `002`'s word for
word.

- ***The checker script*** — it listed two reports and the script has three.
  **The module-block `diff` is named first now**, the descriptor check second,
  the ban scan third, and the exit status covers all three. The mover and
  `doc_blocks.py` have a subsection of their own: **`in` is `from-reference`,
  `out` is `to-reference`, and the direction is an argument for the same reason
  it is one in a mode.**
- ***The module header, and the one description C3 gives*** — `002` forbade a
  `<* *>` block above `module mtk;` in `inner.c3`, `queue.c3` and `stack.c3`.
  **3TK-44 removed the premise**: those three declare their own modules now, so
  no two files collide over one description. Left standing it read as a
  prohibition 3TK-47 broke. **The measurement is kept and the rule is rewritten:
  one module block per file, above that file's own `module` line**, with `002`'s
  prohibition named as what returns if two files ever declare one module again.

**Its *Where it stood* section now leads with the state after 3TK-47** — 0
differing blocks, 439 sentences, 438 found, 1 missing — and 3TK-43's numbers are
kept below it as what `002` was written against.

**Live pointers repointed, records left alone.** `README.md`, this file's header
pointer and its live guidance, `ref/3tk-reference-002.md`'s two links,
`3tk/check-doc-loop.sh`, `3tk/move-module-docs.sh` and `3tk/doc_blocks.py`.
**Rows recording what 3TK-39, 3TK-43 and 3TK-46 did keep the name they were
written with.**

**One judgement worth naming.** Repointing two links inside
`ref/3tk-reference-002.md` touched the reference, and the rule is that a stage
revising the reference versions it. **This was not a revision of its content** —
two link targets, no sentence changed, and the checker reports 0 differing
blocks and the same 438 of 439 afterwards. **The reference stays `002`.**

## How to continue after a clear

**3TK-47 has run, and plan 018 is spent.** Plan 016's six, plan 017's five and
plan 018's five have all run. **There is no declared stage waiting.** The next
thing that runs is either a loop round on a file, or a stage the owner declares
in a new plan.

**Nothing in plan 018 is unfinished.** What it deliberately left to the owner is
listed in [3tk-staging-plan-018.md](3tk-staging-plan-018.md) under *What this
plan deliberately leaves to the owner*, and the open questions are under
*What is waiting for a ruling* below.

**What a cold session should know before anything is named.**

- **Eight files, eight modules, since 3TK-44.** `mtk`, `mtk::inner`,
  `mtk::queue`, `mtk::stack`, `mtk::helper`, `mtk::managed`, `mtk::mailbox`,
  `mtk::pool`. The faults, `@check` and `CHECKED` are in `mtk.c3`.
- **Every one of the eight has a module description now, and all eight are
  copies of the reference.** 3TK-46 wrote them, 3TK-47 moved them, and
  `./3tk/check-doc-loop.sh` reports **0 differing blocks**. Three of them —
  `mtk::inner`, `mtk::queue`, `mtk::stack` — had no description at all before
  47.
- **A module block is copied and `diff`ed. A declaration's descriptor is judged
  and checked as a subset.** Two kinds of move, and
  [ref/3tk-doc-loop-003.md](ref/3tk-doc-loop-003.md) rules on both under
  *Moving a module description*. **The declaration direction is not automated
  and is not going to be.**
- **`3tk/move-module-docs.sh` is the mover**, `3tk/doc_blocks.py` is the format,
  and the round trip is byte-exact. Never hand-edit a module block on one side
  only: move it.
- **The invariant is 439 sentences, 438 found, 1 missing.** **The one missing is
  `inner.c3`'s merged file header**, 3TK-40's open question: leave it, reword it
  to the struct, or file it in the reference. It now names a macro that has left
  the file. **The owner's markdown probe is gone** — 47 replaced it with Part 1.
- **The ban scan is 0** over all eight files and over the reference.
- **Five private helpers carry `//` comments instead of `<* *>` blocks**, and
  whether that becomes a rule of the loop is the ruling 3TK-42 asked for.
  **3TK-43 recorded the question in
  [ref/3tk-doc-loop-003.md](ref/3tk-doc-loop-003.md) and did not answer it.**
- **The flow document is [ref/3tk-doc-loop-003.md](ref/3tk-doc-loop-003.md).**
  `002` is in `backup/`. Two sections were brought up to what is true: the
  checker's three reports, and the module header rule, whose premise 3TK-44
  removed. **Nothing else in it changed.**
- **`mtk.c3` has been edited under two stages running.** Check that it compiles
  before starting anything that verifies against the tree.

**The loop is the standing procedure now, not a stage.**
[ref/3tk-doc-loop-003.md](ref/3tk-doc-loop-003.md) says how a round is invoked:

```
Read design/secondary/lang/c3/3tk-status.md.
Run doc-loop from-reference on <file>.c3.
```

**Start with `./3tk/check-doc-loop.sh` and read what it prints.** No argument
now: every file has been written from the reference, so the whole tree is the
useful run.

**Moving a module description is a command, not a reading.**

```
./3tk/move-module-docs.sh in  [module ...]   # reference -> src
./3tk/move-module-docs.sh out [module ...]   # src -> reference
./3tk/move-module-docs.sh roundtrip          # writes neither, compares bytes
```

**Look at the page.** `3tk/preview-docs.sh` opens the rendered comments in a
browser, and all eight modules have a description in it.

**Clear first, always.** A stage's inputs are this file, its plan's section for
that stage, and the `ref/` documents. Not a transcript.

### The six, and where each one stops

```
3TK-32   the strings a user sees          -> DONE
3TK-33   strip: mtk, inner, helper        -> DONE
3TK-34   strip: managed, queue, stack     -> DONE
3TK-35   strip: mailbox, pool             -> DONE
3TK-36   the reference, in 042's shape    -> DONE
3TK-37   comments from the reference      -> DONE (exemplar only)
```

**Six stages, six clear points.** Every one ends with its own advice and its
own continue line, written here and into [3tk-log.md](3tk-log.md) before it
finishes.

### Plan 017's five, and where each one stops

```
3TK-38   the preview script                 -> DONE (no source touched)
3TK-39   the doc loop, as a document        -> DONE (no source touched)
3TK-40   from-reference: mtk, inner, managed-> DONE (1 sentence reported)
3TK-41   from-reference: queue, stack       -> DONE (0 missing, docgen fixed)
3TK-42   from-reference: mailbox, pool      -> DONE (0 missing, ban scan 0)
```

**All five have run, and plan 017 is spent.**

### Plan 018's five, and where each one stops

```
3TK-43   the flow document                  -> DONE (no source touched)
3TK-44   the split, and what moves to mtk   -> DONE (8 modules, builds green)
3TK-45   the stack is public                -> DONE (R13 revised, 0 missing)
3TK-46   eight sections, eight labels       -> DONE (8 labels, ref 001 to 002)
3TK-47   the move, and the checker          -> DONE (8 moved, 0 differing)
```

**All five have run, and plan 018 is spent.** **43 wrote the format 46 obeys.
44 answered how many blocks there are: eight.** 45 decided what one of them
says, **46 wrote all eight**, and **47 moved them and taught the checker to
diff them.**

### Why the plan is shaped this way

**3TK-31 was refused twice, and the second refusal named the cause**: *in ztk
we wrote api ref md and comments were moved from it, not it's opposite.*

**The derivation ran backwards.** 3tk has no 042-equivalent, so 3TK-31 had only
the old comments to work from, and those are design argument and implementation
notes.

**Three moves fix the order.** Strip the sources to descriptor and contracts.
Write the reference. Move the comments out of it. **Only the middle one invents
wording**, and it is a markdown file that can be refused without a rebuild.

### The register, and the two renderers, are in the flow document

**Moved out by 3TK-43.** Both were rules, not state, and this file holds state.
Read [ref/3tk-doc-loop-003.md](ref/3tk-doc-loop-003.md) — *The register for a
source comment is ztk's, not this folder's*, *What the two renderers do*, and
*Moving a module description*.


### The 3tk API reference should have 042's shape

**Ruled by the owner 2026-08-25**, in the same message.

**[../../../matryoshka-api-reference-042.md](../../../matryoshka-api-reference-042.md)
is ztk's book.** Seven parts, and Parts 3, 4 and 5 repeat one shape in one
order: *What this is* / *Participants* / *Usual flow* / *The API, in named
groups* / *Where to go deeper*.

**[ref/3tk-api-002.md](ref/3tk-api-002.md) is not that.** A flat page of
sections. No Participants block, no repeated per-tool shape, no *Where to go
deeper*.

**Declared as 3TK-36** by [3tk-staging-plan-016.md](3tk-staging-plan-016.md).
It writes `ref/3tk-reference-001.md`, and it is the stage the other five exist
to make possible.

### What is waiting for a ruling

**Which stage runs.** Plan 016's six have all run, and four of plan 017's five.
**Which stage runs.** Plan 018 declares five and authorizes none.

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-43.
```

**Whether an internal helper is documented with `//` rather than `<* *>`.**
3TK-42 took that reading over five private helpers so the invariant could reach
0. **3TK-43 recorded the question in
[ref/3tk-doc-loop-003.md](ref/3tk-doc-loop-003.md) and did not answer it.** If
the owner keeps it, it becomes a rule there and that file gets a new number.

**How long `mtk.c3`'s markdown probe stays.** The owner's own, and it renders
correctly. It costs six lines in the checker's count and nothing else.

**`helper.c3`'s example.** 3TK-33 deleted the fenced `struct Msg` block with
the rest of the prose. Whether a source file carries a worked example at all is
the owner's. 3TK-37 left it in the reference and did not put it back.

**`stack.c3`'s last-in first-out reasoning.** 3TK-34 deleted it from the
source, where it was written for the reader who would otherwise change the
stack back into a queue. `ref/3tk-decisions-001.md` holds it, and so does Part 3
of the reference. **3TK-41 rewrote `stack.c3` and left it out**, as plan 017
told it to report and not rule. Still the owner's.

**`pool.c3`'s late-close comment.** Thirty source lines inside `Pool.put`
explained why the closed flag is re-read after the hook and what would break
without it — the port's longest implementation note, written for the reader who
would otherwise delete the re-read. 3TK-35 took it out with the rest;
`ref/3tk-decisions-001.md` holds it. It is the deletion of this stage worth
refusing. **3TK-42 rewrote `pool.c3` and left it out**, as plan 017 told it to
report and not rule. `Pool.put` now carries the reference's own short form —
*A close that arrives while `on_put` runs is handled.* Whether the thirty lines
come back is the owner's.

**Whether `ref/3tk-api-002.md` is retired** once `3tk-reference-002.md` exists.
3TK-36 reports the overlap and does nothing about it.

**Every stage writes its own continue line here before it finishes** — the
standing requirement of 2026-08-25. Advice that exists only in a conversation
about to be cleared is worth nothing.

## Where the narrative went

**Seven retrospective sections stood here and were removed by 3TK-25,
2026-08-25.** Each described a stage that has run, and
[3tk-log.md](3tk-log.md) already carries all of it, dated and in full. One line
each, with the log entry that holds it:

- *What 3TK-17 cut* — specification 004, Part 7.1 alone. Log, 2026-08-24,
  *3TK-17: Part 7.1 states the promise, and 004 is cut for one Part*.
- *What 3TK-15 paid* — `UNKNOWN_IDENTITY`, and A5 filed under the wrong noun.
  Log, 2026-08-24, *3TK-15: two debts paid, and one of them was misfiled*.
- *What 3TK-16 built* — the helper as macros, 35 aliases to 0. Log,
  2026-08-24, *3TK-16: the helper surface, in code*.
- *What 3TK-14 decided* — eleven items, fifteen measurements, and the stdlib
  that changed the answer. Log, 2026-08-24, *3TK-14: the helper surface,
  measured then proposed, then re-measured against the stdlib*.
- *What the owner ruled, 2026-08-24* — H0, H0b, H5, H10 accepted; E6 an S/V row
  scoped `every port`, E7 no change at all. Log, same entry, sections *Ruled the
  same day* and *E6 and E7, ruled*.
- *What is owed, and by which stage* — a 3TK-14-era table, every row of it since
  paid by 3TK-16 and 3TK-17. Log, same entry, section *What is owed, and the one
  gap*.
- *The state before 3TK-14 — 3TK-13 and the specification* — 003, the five
  assumptions, the P1 and P6 rulings, and the R-register as the owner ruled it.
  Log, 2026-08-24 *3TK-13: specification 003, and the gap closes*, *five
  questions before the cut, five defaults recorded*, *P1 fixed*, and 2026-08-23
  *the redesign is ruled, question by question*.

**One claim in the removed text was false and is not carried anywhere.** *The
state before 3TK-14* said **R4 — OUTSTANDING**, on the ground that Part 11.8's
MUST forces `InnerQueue` to keep a front insert. R15 dropped `Pool.put_all` and
**retired R4 with it** — `3tk-core-redesign-proposal-002.md:606` — and there is
no `push_front` in the port: `queue.c3:91` says so where the operation would
be. The paragraph was written before the ruling and outlived it.

## Asking for a stage or a revision

**To add a stage:** one line, and the agent does the versioning.

```
Add 3TK-NN to the plan and run it
```

To bump the plan without running anything, add `Do not run it.` Whatever the
stage, **the agent's first three actions are: read this file, read the plan's
section for that stage, read that stage's named inputs.** Nothing outside them.
A stage whose row above reads DONE is not re-run without being told.

**A revision is not a stage.** It needs no plan version and appears in no stage
table. Name what you want changed and which document:

```
Read design/secondary/lang/c3/3tk-status.md. Revise the porting proposal:
D5 should be a transparent alias, not a distinct Slot type.
```

The agent writes the next version number, leaves the old file on disk, adds a
row to *Superseded* naming what replaced it, repoints the live pointers in this
file, and appends to [3tk-log.md](3tk-log.md).

**A revision that moves a decision has consequences in `3tk/`.** The agent names
the source files that would change and **stops there**. Rewriting the code is a
separate instruction, and the four builds have to be green again before the
revision is finished:

```
...and apply it to the code.
```

**Two things a revision may not do quietly**, and they are the folder's standing
rules rather than a revision's own. It does not renumber or rewrite a finished
stage's output — those record what was true when the stage ran. And it does not
repoint the provenance lines inside stage outputs, which name the document
version each stage was written against; only the live pointers in this file
move.

**To know only where things stand:**

```
Read design/secondary/lang/c3/3tk-status.md and report where the 3tk work stands.
```

## To verify the port without an agent

```
design/secondary/lang/c3/3tk/run-builds.sh
```

Four builds, exits non-zero on any failure. It needs `c3c` on the path and
nothing else, and 3TK-9 deliberately kept it that way.

The sanitizers are a **second** script, because they need a C compiler that
ships their runtimes and `run-builds.sh` may not depend on one:

```
design/secondary/lang/c3/3tk/run-sanitizers.sh
```

Thread on two builds, address on one. It **skips and exits 2** if its compiler
is missing, saying so — a skip is not a pass. `SAN_CC=<compiler>` overrides the
default of `clang`.

**Both scripts take an optional directory**, added 2026-08-24 on the owner's
instruction. With no argument — or an empty one — each runs against its own
directory exactly as before:

```
./3tk/run-builds.sh              # the script's own directory, unchanged
./3tk/run-builds.sh /some/tree   # that tree instead
```

**A `cd` that fails is fatal, and that is not decoration.** Neither script sets
`-e`, so before this a failed `cd` would have let the whole body run in whatever
directory the caller happened to be in, and `run-builds.sh` does `rm -rf` on its
temporary directory at exit. A caller-supplied path made that reachable. A bad
path now prints one line and exits 2 with nothing else run.

## Files

Edited in place, no suffix — the entry points:

- `README.md` — **the index of this folder**, one line per live file: what it
  is and who reads it. The 3TK-28 output. It rules on nothing, so a reader who
  needs a fact reads the file it points at.
- `3tk-status.md` — this file.
- `3tk-log.md` — the narrative, append-only, newest first.

Versioned — a change makes a new file, the old one stays and is listed below:

- **Current plan: [3tk-staging-plan-017.md](3tk-staging-plan-017.md).** It
  declares **3TK-38 to 3TK-42** — the preview script, the doc loop as a
  document, and the seven remaining source files as three stages — and
  **reproduces no stage that has run.** **None of the five has run.**
- [3tk-staging-plan-016.md](3tk-staging-plan-016.md) — spent. It declared
  **3TK-32 to 3TK-37** — the strings, three strip stages, the reference in
  042's shape, and the comments moved out of it. **All six have run.**
- [ztk-audit-001.md](../common/ztk-audit-001.md) — the 3TK-1 output.
- **[matryoshka-specification-004.md](../common/matryoshka-specification-004.md) — the
  portable specification, and the source of truth for every port.** The 3TK-2
  output, revised three times: by 3TK-2's own successor into 002, by **3TK-13**
  into 003 from the deviation audit, and by **3TK-17** into 004 for Part 7.1.
- [3tk-drafts-review-001.md](3tk-drafts-review-001.md) — the 3TK-3 output.
- [c3-capabilities-001.md](c3-capabilities-001.md) — the 3TK-4 output.
- **[3tk-porting-proposal-004.md](3tk-porting-proposal-004.md) — the design of
  record. The sixteen decisions accepted by the owner, 2026-08-23; D1's argument
  rewritten and its ruling reaffirmed by 3TK-8, same day.**
- [3tk-toolkit-notes-001.md](3tk-toolkit-notes-001.md) — the 3TK-6 output,
  beside the code at `3tk/`.
- [3tk-containers-notes-001.md](3tk-containers-notes-001.md) — the 3TK-7
  output.
- **[3tk-naming-001.md](backup/3tk-naming-001.md)** and
  **[3tk-to-fifo-lifo-single-001.md](backup/3tk-to-fifo-lifo-single-001.md)** —
  **retired to `backup/` by 3TK-23, 2026-08-25.** From
  the owner, 2026-08-23. Not produced by any stage and not versioned by this
  folder. **The input to 3TK-10.** The first proposes Outer/Inner naming; the
  second argues `NodeList` should not be the centre of the design. Both were
  carried out by 3TK-10 and 3TK-11 and are history now.
- **[3tk-doc-split.md](3tk-doc-split.md)** — from the owner, 2026-08-25. Not
  produced by any stage and not versioned by this folder. **The input to
  3TK-29, 3TK-30 and 3TK-31.** The source files are a mix of implementation and
  source of truth for an AI; there is very little user orientation, and the
  result cannot be used to build documentation. It asks for one file of
  accumulated decisions, comments rewritten for a human, and marks in the
  sources instead of links until 3tk matures. **Open** — it is input, not a
  ruling.
- **[3tk-who-supports-slot.md](3tk-who-supports-slot.md)** — from the owner.
  Not produced by any stage. **Open, and not ruled on by anything.** It argues
  the containers should not support the Slot idiom at all. It was at `3tk/src/`
  until the owner moved it here on 2026-08-23; it uses names the redesign
  refused, so it reads as older than it is. See *Open questions*.
- **[3tk-helper-alternatives.md](backup/3tk-helper-alternatives.md)** —
  **retired to `backup/` by 3TK-23, 2026-08-25.** From the
  owner, 2026-08-24. Not produced by any stage and not versioned by this
  folder. **The first input to 3TK-14.** It is advice, not a ruling, and it
  withdraws its own favourite proposal near the end. 3TK-14 measured both of its
  shapes and the compiler refused both. **Its second input was spoken, not
  written**: read the C3 stdlib. That is recorded in the log and in Part A2 of
  the proposal, and it is what produced H0.
- [3tk-helper-proposal-001.md](3tk-helper-proposal-001.md) — the 3TK-14 output.
  Fifteen compiler measurements, eleven numbered items, **all ruled 2026-08-24**.
  Its second input was the owner's mid-stage advice to read the C3 stdlib's
  `interfacelist`, `anylist` and `core/builtin.c3`, and that advice is what
  produced H0. **3TK-16 built it.**
- **[3tk-helper-notes-001.md](3tk-helper-notes-001.md) — the 3TK-16 output.**
  What building the ruled surface taught: three C3 spellings the proposal's
  scratch runs did not carry, the rename that was never a rename, and 35 aliases
  to 0.
- **[3tk-debts-notes-001.md](3tk-debts-notes-001.md) — the 3TK-15 output.**
  The two debts of 3TK-13, paid: `UNKNOWN_IDENTITY` and why it is deliberately
  not a Part 19 outcome, why `get_wait` changed when it did not have to, and the
  twelve doc comments that changed a claim rather than a path. **It also records
  that A5 was filed under the wrong noun** — one path citation existed, not
  forty, and the non-mechanical half was all of the work.
- **[3tk-port-findings-003.md](3tk-port-findings-003.md) — the 3TK-20 output as
  3TK-22 and 3TK-24 left it, and the only document in this folder written to be
  read by another port.** What 3tk does and the reasoning that produced it, in ten sections
  selected by *would another port care*. **It describes and recommends
  nothing**, which is the owner's ruling of 2026-08-24 and is what makes it
  serve dtk and ztk at once. It stays a 3tk document rather than moving to
  `../common/`: one port's record, read by others, not a shared normative
  input. **Versioned under this folder's rule** — it is a new family, and
  **`3tk-staging-plan-012.md` named it** — that addition was the whole of 012,
  and 011's list predated the document. **013 carried the entry forward, and
  3TK-22 made it a 002 on 2026-08-25**: §1 re-cut against `struct Inner { any
  link; }`, every `file:line` printed and read again, and a new §1a on storing
  the identity and the chain link as one built-in pair. **3TK-24 made it a 003
  the same day**, adding §5a on the `on_get` difference and changing nothing
  else of substance. **001 and 002 are in `backup/`** —
  [001](backup/3tk-port-findings-001.md), [002](backup/3tk-port-findings-002.md).
- [3tk-sanitizer-notes-001.md](3tk-sanitizer-notes-001.md) — the 3TK-9 output.
  Seven findings. The port is clean under thread and address; the four races the
  first run found were all in the tests.
- **[3tk-readership-001.md](3tk-readership-001.md) — the 3TK-27 output.** Who
  reads each of the six `*-notes-*` files and `3tk-drafts-review-001.md`, and
  when. **Three of the seven have a reader; four do not.** It retires nothing —
  the owner decides — and it moved no file.
- **[3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md) — the
  3TK-10 output as ruled, and 3TK-11's input. Executed 2026-08-23.** Sixteen
  decisions, R1 to R15 with R6b, every one accepted or refused on the record.
  Proposal 004 stays the design of record for everything the redesign does not
  touch, and it is **not edited** — it records what was built, and 002 records
  what replaced it.
- **[3tk-core-redesign-notes-001.md](3tk-core-redesign-notes-001.md) — the
  3TK-11 output.** What writing the redesign taught: the six self-link sites,
  invariant 5 in a mailbox with two queues, and three corrections to 002 in
  details rather than decisions — the stack has five operations and not six,
  tier 2 does not reach a fast build, and two `put_all` tests were converted
  rather than deleted.



### Superseded

**Every superseded version is in `backup/`.** Nothing is deleted, and the live
folder contains only what a current reader needs.

- `3tk-staging-plan-014.md`, replaced by `3tk-staging-plan-015.md` on
  2026-08-25, when 014's five stages had all run.

- `3tk-staging-plan-015.md`, replaced by
  [3tk-staging-plan-016.md](3tk-staging-plan-016.md) on 2026-08-25, when its
  three stages had all run. **016 reproduces none of them** — a plan holds only
  what has not run.

- [matryoshka-specification-003.md](../common/backup/matryoshka-specification-003.md),
  replaced by
  [matryoshka-specification-004.md](../common/matryoshka-specification-004.md)
  on 2026-08-24, by stage **3TK-17**. **One Part.** 7.1 stated ztk's mechanism
  — a helper object bound to one type — where the design has only the promise
  that Part 7.2's members exist per outer type and are generated. It was the
  fifteenth instance of the mistake 003 fixed fourteen times. Its own change log
  names the difference. **`../common/backup/`, not `backup/`** — the
  specification is every port's, and `c3/backup/` stays the C3 line's own.

- [3tk-core-redesign-proposal-001.md](backup/3tk-core-redesign-proposal-001.md),
  replaced by
  [3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md) on
  2026-08-23, when the owner ruled on it question by question. **Three decisions
  moved**, which is why a version was cut rather than a note appended: **R6 was
  refused** and the self-link replaced it, **R11 acquired its reason**, and
  **R15 dropped `put_all`**, retiring R4. 001 is the record of what the stage
  proposed; 002 is what was ruled, and 002 is 3TK-11's input.

- `3tk-staging-plan-001.md`, replaced by plan
  002 on 2026-08-23. The only change was the addition of 3TK-6.
- `3tk-staging-plan-002.md`, replaced by
  `3tk-staging-plan-003.md` on 2026-08-23. The only
  change is the addition of 3TK-7.
- `3tk-staging-plan-003.md`, replaced by
  `3tk-staging-plan-004.md` on 2026-08-23. The only
  change is the addition of 3TK-8.
- `3tk-porting-proposal-001.md`, replaced by
  proposal 002 on 2026-08-23, when the owner accepted all sixteen decisions.
- `3tk-porting-proposal-002.md`, replaced by
  [3tk-porting-proposal-003.md](backup/3tk-porting-proposal-003.md) on 2026-08-23, in
  answer to [3tk-porting-proposal-review.md](backup/3tk-porting-proposal-review.md).
  No decision moved.
- `3tk-staging-plan-009.md`, replaced by
  `3tk-staging-plan-010.md` on 2026-08-24. The
  only change is the addition of 3TK-18 and 3TK-19; 3TK-0 to 3TK-17 are
  reproduced unaltered.
- `3tk-staging-plan-010.md`, replaced by
  `3tk-staging-plan-011.md` on 2026-08-24. The
  only change is the addition of 3TK-20; 3TK-0 to 3TK-19 are reproduced
  unaltered, and 3TK-19 stood declared and unstarted exactly as 010 left it.
- [3tk-staging-plan-012.md](backup/3tk-staging-plan-012.md), replaced by
  `3tk-staging-plan-013.md` on 2026-08-25. **The change
  is three new stages** — 3TK-21, 3TK-22 and 3TK-23 — and nothing before them is
  altered, reordered or reworded.
- `3tk-staging-plan-011.md`, replaced by
  [3tk-staging-plan-012.md](backup/3tk-staging-plan-012.md) on 2026-08-24, at the
  owner's instruction. **The only change is one line in the versioned list** —
  `3tk-port-findings-NNN.md`, the family 3TK-20 started. **No stage is declared,
  added, reordered or reworded**; each stage header now names its outcome, and
  every stage of the line has run.
- `3tk-staging-plan-007.md`, replaced by
  `3tk-staging-plan-008.md` on 2026-08-24. The
  only change is the addition of 3TK-14 and 3TK-15.
- `3tk-staging-plan-008.md`, replaced by
  `3tk-staging-plan-009.md` on 2026-08-24. The changes
  are the addition of 3TK-16 and 3TK-17, an amendment note on 3TK-15's ordering,
  and one corrected stale line — 008 and 007 both said *currently 007* in the
  versioning section.
- `3tk-staging-plan-006.md`, replaced by
  `3tk-staging-plan-007.md` on 2026-08-24. The only
  change is the addition of 3TK-12 and 3TK-13.
- `3tk-staging-plan-005.md`, replaced by
  `3tk-staging-plan-006.md` on 2026-08-23. The
  only change is the addition of 3TK-10 and 3TK-11.
- `3tk-staging-plan-004.md`, replaced by
  `3tk-staging-plan-005.md` on 2026-08-23. The only
  change is the addition of 3TK-9.
- [3tk-porting-proposal-003.md](backup/3tk-porting-proposal-003.md), replaced by
  [3tk-porting-proposal-004.md](3tk-porting-proposal-004.md) on 2026-08-23, by
  stage 3TK-8, in answer to
  [3tk-porting-proposal-003-review.md](backup/3tk-porting-proposal-003-review.md).
  **No decision moved.** D1's *argument* was rewritten and its *ruling*
  reaffirmed by the owner.
- [3tk-porting-proposal-addendum-001.md](backup/3tk-porting-proposal-addendum-001.md),
  folded into proposal 004 on 2026-08-23. Its nine measured answers are D1's
  table; the addendum existed only until a proposal version could carry them.
- [3tk-porting-proposal-003-review.md](backup/3tk-porting-proposal-003-review.md),
  answered by proposal 004 on 2026-08-23 and moved here, as the first review
  was. It is history now: everything a current reader needs from it is in 004's
  *What changed in 004*, section 6 and section 10.
- [matryoshka-specification-001.md](../common/backup/matryoshka-specification-001.md),
  replaced by
  [matryoshka-specification-002.md](../common/backup/matryoshka-specification-002.md) on
  2026-08-23 — three imprecisions the C3 port found, and invariant 34, with no
  rule changed — and **002 replaced by
  [matryoshka-specification-003.md](../common/backup/matryoshka-specification-003.md)
  on 2026-08-24**, from the deviation audit, and **003 replaced by
  [matryoshka-specification-004.md](../common/matryoshka-specification-004.md)
  the same day**, from 3TK-17, for Part 7.1 alone. All three are in
  `../common/backup/`, which 3TK-13 created; `c3/backup/` stays the C3 line's
  own. **The other ports read 004.**

The stage outputs name the document versions they were written against. Those
are provenance and are not repointed; the live pointers above are.

**A path is not a pointer.** When a superseded file moves to `backup/`, the
links naming it are corrected to `backup/...` in place, in every file that
names it. That changes where the file is, never which version is named — the
stage outputs of 3TK-1 to 3TK-5 still name plan 001, and the notes of 3TK-6 and
3TK-7 still name proposal 001. Repointing provenance at a *newer* version is
what the rule forbids, and none of it happened.

The stage outputs of 3TK-1 to 3TK-5 each name plan 001 in their opening line.
Those are **provenance, not pointers** — they record which plan version the
stage ran under — and they are not repointed. The live pointers are the ones in
this file.

## Current state

**The port is clean under ThreadSanitizer and AddressSanitizer**, and the run
that established it found four data races first — **all four in the toolkit's
own test hooks, none in `src/`.** Stage 3TK-9, `3tk-sanitizer-notes-001.md`.

- **What the races were.** `TestHooks`'s counters, incremented without
  synchronization while three producers and three consumers ran on one pool. The
  frames that appear in `src/` are `pool.c3:293` and `:394` — the hook call
  sites, where the pool has *already unlocked*. That is Part 12.3 being obeyed.
- **The contract they broke is the port's own**, in `PoolHooks`'s doc comment:
  *a hook that touches shared state protects it itself.* The tests had been
  racing since 3TK-7 with every build green in four modes, because a data race
  is exactly the defect a passing suite cannot see.
- **The fix is in the hook**, where the specification puts it: `Atomic{usz}`
  counters, the same mechanism the port uses for `_closed_fast`. The one-line
  wrong fix — hold the pool's mutex across the hook — would have silenced every
  warning and destroyed Part 12.3. A sanitizer says there is a race; it does not
  say which side is wrong.
- **The sanitizers needed no install and no root.** Fedora's runtimes are
  missing so `cc` cannot link them — and plain `cc -fsanitize=thread` fails
  identically, so it is the machine, not c3c. `--cc clang` links. S1, S2.

```
all four builds green — 59 checks, 0 failures     ./3tk/run-builds.sh
  safe -O0   safe -O3   fast -O0   fast -O3        (needs c3c alone)
85 tests in each, 7 runtime negatives, 2 tier 1, 3 refusals, 3 layering

sanitizers clean — 3 runs, 0 findings              ./3tk/run-sanitizers.sh
  thread safe -O0    thread fast -O3    address safe -O0
```

**77 tests before 3TK-11, 85 after.** The check count did not move: the redesign
renamed one negative and rewrote another, and added none.

The two scripts are separate for one reason: the gate depends on `c3c` and
nothing else, and 3TK-9 kept it that way rather than buying coverage with a
dependency.

**Part 18 is complete: still thirty-four invariants, all accounted for.** The
redesign retired row 16 — *the link test is not a membership test* — and put the
self-link invariant in its place, kept row 22 against plan 006's expectation
that two queues would delete it, and strengthened row 13. The re-walk is in
`3tk-core-redesign-notes-001.md`.

**No decision has moved across four proposal versions.** All sixteen accepted by
the owner 2026-08-23; D1 reaffirmed the same day after its *argument* was found
wrong, which is the distinction this folder keeps.

The documents, in the order a cold session reads them:

- `../common/matryoshka-specification-004.md` — the portable specification.
  Source of truth for **every** port, not just this one.
- `3tk-porting-proposal-004.md` — the C3 shape of it. D1 to D16, accepted.
  Section 6 is the implementation contract; section 10 is what the code taught.
- `3tk-toolkit-notes-001.md`, `3tk-containers-notes-001.md`,
  `3tk-sanitizer-notes-001.md` — what the code taught. Twenty-two findings.
- `c3-capabilities-001.md`, `3tk-drafts-review-001.md`,
  `../common/ztk-audit-001.md` — the measurements the proposal was built on.

**The core redesign is designed, ruled and built.**
[3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md) is the
3TK-10 output as ruled; 3TK-11 carried every one of its sixteen decisions into
`3tk/` and
[3tk-core-redesign-notes-001.md](3tk-core-redesign-notes-001.md) is what the
code taught doing it. Four things a reader should know:

- **The required-operation audit passes.** `insert_before`, `remove`,
  `pop_back`, `front` and `back` have **no caller in `src/` at all**;
  `insert_after` has one, the out-of-band insert. Deleting `prev` costs the
  port nothing it uses.
- **The guard got stronger, and cost nothing.** `prev` is deleted and the last
  item of every chain points at itself, so `is_linked` is **exact**. `Inner` is
  two fields and 16 bytes — the two size tests that asserted 24 were the first
  thing the stage had to change. Part 8.7's blind spot is closed, `contains` and
  the O(n) walk on every insert are deleted, and the check moved from tier 3 to
  **tier 2**. R6b, after R6's field was refused.

  **Correction to 002 §10.3, from the code:** tier 2 does **not** reach a fast
  build. `@check` under `--safe=no` expands to nothing, which is the whole of
  D6. What R6b bought is the O(1) check in an ordinary safe build, not an abort
  in a fast one. `3tk-core-redesign-notes-001.md`.
- **`put_all` is dropped.** It was `Pool.put` in a loop, inherited from
  `pool.zig:394`, and it cost a container operation and a MUST clause while
  giving the difficult case back to the caller in a different shape. R15.
- **The pool's order is a behaviour change with a reason**: last-in first-out
  so a use-after-release meets a live second owner at the next `get`, instead
  of rotting quietly at the back of a free list. **Not performance.**

## The gap between the port and the specification

**CLOSED 2026-08-24 by 3TK-13, and the section that described it was removed by
3TK-25, 2026-08-25.** It was proposal 002 §8.1's *forecast* of the difference —
ten Parts — plus what 3TK-11 corrected, kept after the thing it forecast had
been measured and fixed. **The measurement is
[3tk-deviations-001.md](3tk-deviations-001.md)**, which found five more Parts
the forecast said were untouched and five port-side deviations a forecast could
not have found; **the fix is
[`../common/matryoshka-specification-004.md`](../common/matryoshka-specification-004.md)**,
whose claim about itself — *a port is written from this file alone* — is true
again. The narrative is in [3tk-log.md](3tk-log.md), 2026-08-24: *3TK-12: the
audit found what a forecast could not* and *3TK-13: specification 003, and the
gap closes*.

## What is left, and none of it is Matryoshka

Everything below was **outside 3TK-8**, which was about the proposal and two
creation paths, and none of it moved. From `3tk-containers-notes-001.md`.
**Each is a candidate for a stage, and none is authorized.** They are listed so
the owner can name one without re-deriving the list.

- **`a_leaver_hands_the_signal_on` is a race test run 20 times.** It has now run
  20 times **under ThreadSanitizer**, which is much stronger than 20 times
  without. Still evidence, not proof.
- **MemorySanitizer was not run.** c3c offers it; it needs the whole dependency
  stack instrumented, including the C3 standard library, or it reports false
  positives. `3tk-sanitizer-notes-001.md`.
- **linux-x64 only.** ztk is green on three cross targets; 3tk has been built
  for one.
- **`Mailbox.create`'s cleanup is untested**, and the test file says so at the
  site. Its only acquisition through the caller's allocator is the object
  itself; `_mu.init()` and `_cv.init()` allocate through the platform, so a
  failing allocator cannot reach them. The fix is correct by construction and
  the pool's identical shape *is* provoked. Proposal 004, section 8.3.
- **Packaging.** `backup/3tk-build-dist.md` B2 claims C3 library packaging is early
  alpha and `c3c dist` incomplete. Still unverified, still a tooling stage's.
- **A worked example.** An application using the port end to end — a producer, a
  consumer, a pool with real hooks — as documentation that compiles. The tests
  prove the invariants; nothing yet shows a reader how to *use* it, and it would
  be the first honest test of whether the hook contract is easy to obey, which
  3TK-9 says the toolkit's own tests did not. **Carried here by 3TK-25** from a
  candidates table it removed; the table's other four rows are already above.

The other three ports are untouched by this line of work: **otk** needs
refactoring, **ztk** needs tuning, **dtk** is thinking only. The specification
is what any of them would be written from.

## Standing facts

- C3 is installed. `c3c` at `/usr/bin/c3c`. Stdlib sources at
  `/home/g41797/dev/langs/c3/lib/std/`. No install step in any stage.
- The toolchain measured by 3TK-4 is `c3c` 0.8.3, git `1d155ee`, LLVM 22.1.8,
  target linux-x64. Every capability answer is against that version.
- The seven `3tk-*.md` and `ztk-to-3tk.md` drafts, **now in `backup/`**, were
  written in separate sessions by different AIs. They contradict each other and
  some predate API 12, API 13 and INTR 8. They are raw input, never source of
  truth. 3TK-3 read them and measured them; `3tk-drafts-review-001.md` is that
  measurement, and it is what later stages read instead of the drafts. Read the
  measurement, not the drafts — that is why they are in `backup/`.
- ztk itself is green: 195/195 in four modes, three cross targets, INTR 8 closed
  2026-08-14.
- 3tk is green: **87 tests** in four modes, plus 13 negative programs and 3
  layering checks. `3tk/run-builds.sh`, **63 checks**, 0 failures.
- **A negative program is compiled as an ordinary program, so the test runner's
  macros are out of reach.** `@catch_is` is one of them. A negative that wants a
  fault writes `if (catch f = ...)`. Found by 3TK-15, which lost a compile to
  it.
- **C3 has no UFCS.** A free function cannot be called as `handle.f(...)`;
  the receiver is written into the declaration, `fn void Type.f(&self)`. And a
  method cannot be attached to a pointer alias, so `Handle` carries none.
  Proposal 004, D1 — M1 and M4.
- **C3 0.8.3 has no field-level privacy, and `inline` does not create one.** A
  `@private` struct inlined into a public one hides the type *name*; every field
  in it stays readable, writable and addressable from another module.
  `@private` on a field is refused outright. Proposal 004, D1 — M5.
- **The sanitizers work, but not through `cc` on this machine.** c3c 0.8.3 has
  `--sanitize=address|memory|thread`; Fedora's sanitizer runtimes are not
  installed, so `cc` fails to link — and plain `cc -fsanitize=thread` fails the
  same way, so it is the machine and not c3c. `--cc clang` links, with no
  install and no root. `3tk-sanitizer-notes-001.md` S1 and S2.
- **`c3c test` detects leaks by default** — `--test-noleak` turns it off. Nine
  stages passed before any document said so. S6.
- **Never infer a C3 build mode from the `-O` level.** `-O2` and above set
  `SAFE_MODE=false`. Always pass `--safe=yes` or `--safe=no` explicitly.
  `3tk-toolkit-notes-001.md` F1.
- The fault-return operator is `~`, not `?`. `return mtk::CLOSED~;`.
  `3tk-containers-notes-001.md` G2.
- **[3tk-log.md](3tk-log.md) carries about a dozen older banned-word hits and is
  deliberately left as it is.** Owner's instruction, 2026-08-23: the log is
  append-only and rewriting it destroys the record, which is also why
  `rules-049.md` Part 5's scope skips it. Moved here from *Open questions* by
  3TK-25 — it is a standing fact, not a question.

## Open questions

**Reviewed by 3TK-25, 2026-08-25.** Nine questions that were closed and struck
through are gone from this list: a closed question is history, and every one of
them is recorded in [3tk-log.md](3tk-log.md) under the stage or the ruling that
closed it — the two doc comments citing 003 and the stale P2 row (3TK-19), the
`any` ruling's retirement, the three Part 5 words in this file, the allocator
direction, and 3TK-8's four questions, all ruled 2026-08-23 before that stage
started. What is left is what is genuinely open.

- **Two port defects are open, and they are the only ones.**
  [3tk-deviations-001.md](3tk-deviations-001.md) measured six; P1, P2, P5 and P6
  are ruled and fixed. **P3** — a waiting call can return the condition
  variable's own fault, outside Part 19's outcome set. It is **unreachable on
  the current posix backend**, which aborts instead, and it is recorded because
  it sits in the port's two most-copied wait loops and the next port copies the
  shape before checking its own backend. **P4** — Part 2.6 MUST: the pool's
  leaver signals on one bucket over a condition variable shared by *n* buckets.
  **Nothing is lost today** and the reason matters, so a repair is not argued as
  a bug fix: every path that makes an item available calls `broadcast`. The
  mailbox got the same line right. Smallest repair: `broadcast`, or a predicate
  over every bucket in the shape `has_queued` uses. **Both are `3tk-only` and
  neither is ruled.**

- **Whether otk gets a status file.** `../odin/` holds one backport document.
  **The pointer at the specification is written** — 3TK-19, 2026-08-24, one
  blockquote at the top of `odin-to-zig-backport-001.md` naming
  [`../common/matryoshka-specification-004.md`](../common/matryoshka-specification-004.md)
  as otk's normative input, in the shape `../d/dtk-status.md` uses. **The folder
  is not prepared**, and preparing it means answering what otk's line of work
  currently is. That is the owner's call, and 3TK-19 declined it rather than
  deciding it. Whether otk is brought to the specification is a separate
  question and no stage of this line has touched it.

- **Should the containers support the Slot idiom at all?** A note from the
  owner, [3tk-who-supports-slot.md](3tk-who-supports-slot.md), argues they
  should not: `push_back_slot` and `push_slot` would move to `Mailbox` and
  `Pool`, and `InnerQueue` and `InnerStack` would speak only in `Handle`.
  **3TK-10 did not rule on it and 3TK-11 did not act on it** — §5.1 keeps both
  Slot inserts and R13 says nothing against them, so the code has them. It uses
  names the redesign refused — `InnerList`, `push_front` — so it reads as older
  than it is. **The owner moved it out of `3tk/src/` to this folder on
  2026-08-23**, so it is no longer mistakable for current design. Small: two
  methods and their two tests.

- **A ztk/3tk behavioural difference, now written down: whether `on_get` runs
  when a get already found a stored item.** 3tk does not call it, ztk does, and
  specification Part 11.7 and Part 12.2 side with 3tk while `ztk-audit-001.md`
  2.7 and the ztk book side with ztk. **Recorded, not ruled** — it touches
  `../common/`, it changes what dtk would build, and whichever way it goes one
  of three moves: 3tk's code, ztk's code, or Part 12.2.
  [3tk-port-findings-003.md](3tk-port-findings-003.md) **§5a** has all of it,
  with every citation on both sides.

- **Two lines of the ztk book are wrong about `on_get`, and fixing them is the
  ztk line's work.** `matryoshka-api-reference-042.md:1288` says *Calls `on_get`
  hook* under `get_wait`, and `:1448-1449` says `on_get` is *called for every
  `get` and `get_wait` call regardless of mode*. Both were re-read 2026-08-25
  and neither has moved since the audit. **This is not a doubt about the port**:
  `Pool.get_wait` calls no creation hook on purpose, and the code, the doc
  comment, ztk's own source, the audit and specification Part 11.9's MUST all
  agree. The log's entry of 2026-08-25 — *the waiting get never creates* — has
  the whole of it.

- **The specification is 1366 lines against the plan's expected 600-900.** The
  staccato rule is one fact per line, and the content did not compress below
  this without dropping facts. Nothing was padded and nothing was cut to fit.
  Flagged for the owner.

- **The banned-word scan has never covered this folder.** `rules-049.md` Part
  5's own scope skips `design/secondary/`, so eleven stages of documents were
  written unchecked. Found 2026-08-23 when the owner caught one word in the
  redesign proposal; a full scan then found nine hits in that file alone, and the
  proposal was replaced by a clean 002. **Whether Part 5's scope should change
  is the owner's call and belongs to the kitchen line, not to 3tk.**

- `kitchen/tools/check_design.sh` exits 1, not the 0 the plan expected. **63
  problems after 3TK-8, up from 43**, and the whole rise is orphans — 29 to 49 —
  because `design/secondary/context.md` lists no `lang/` subfolder, so every
  file under it counts as one. 3TK-8 added two files and moved three to
  `backup/`; each is a new path and a new row. **The 14 dead links did not
  move**, and that is the number that would signal a regression. All 14 are in
  `design/context.md` and name documents older than this work. The cause is the
  next item.

- `design/secondary/context.md` does not list the `lang/` subfolders at all.
  Drift, noted, not fixed. Every file in `c3/`, `d/` and `odin/` is an orphan
  by the gate's count because of it.

- Three more documentation-drift items, all in `design/`, none touching `src/`.
  `ztk-audit-001.md` section 7.
