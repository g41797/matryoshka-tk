# 3tk — status

Current state of the 3tk line of work. One screen. Updated after every stage.

This file is the entry point for a cold session. Read it, then the stage named  
by the owner. [3tk-staging-plan-016.md](3tk-staging-plan-016.md) is spent — all  
six of its stages have run.  
For what else is in this folder and who reads it, see [README.md](README.md).

**For what was decided about the port and where it lives in the code, read  
[ref/3tk-decisions-001.md](ref/3tk-decisions-001.md).** One common section and  
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
[ref/3tk-reference-001.md](ref/3tk-reference-001.md).** Seven parts, in 042's
shape, with Parts 3 to 5 repeating one order. It covers the same surface as
002 and says the same things in a different arrangement. Whether 002 stays is
the owner's call.

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

## How to continue after a clear

**Plan 015 is spent. [3tk-staging-plan-016.md](3tk-staging-plan-016.md) declared
six stages and all six have run. Plan 016 is spent too.**

**3TK-37 has run, and nothing is authorized.** The next plan is the owner's to
declare. What plan 016 deliberately left is listed under *What is waiting for a
ruling* below, and the first item there is the biggest: seven source files still
carry the descriptors 3TK-33 to 3TK-35 left them, and only `helper.c3` has been
rewritten from the reference.

**When a stage is named, this is the shape of the line:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-NN.
```

**Clear the context before it.** A stage's inputs are this file, its plan's
section for that stage, and the `ref/` documents. Not a transcript.

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

### Why the plan is shaped this way

**3TK-31 was refused twice, and the second refusal named the cause**: *in ztk
we wrote api ref md and comments were moved from it, not it's opposite.*

**The derivation ran backwards.** 3tk has no 042-equivalent, so 3TK-31 had only
the old comments to work from, and those are design argument and implementation
notes.

**Three moves fix the order.** Strip the sources to descriptor and contracts.
Write the reference. Move the comments out of it. **Only the middle one invents
wording**, and it is a markdown file that can be refused without a rebuild.

### The register for a source comment is ztk's, not this folder's

**Ruled by the owner 2026-08-25**, after refusing 3TK-31's first version as
*aish prose, not descriptors*.

**The model is `src/*.zig`** - ztk's own doc comments. Read them before writing
a comment in `3tk/src`.

- The first line is a descriptor. `Clears the intrusive list links.`
- No bold. Not one `**` in 1,771 lines of ztk source.
- One fact per line. `Never modifies the node.`
- A variant says `Same as X().` then only its difference.
- Rationale only where short and non-obvious. No argument, ever.

**What does NOT port from ztk, measured against `c3c docgen` 2026-08-25.**
The renderer is `formatDocText` inside the generated `docs.html`. It is not
CommonMark and `marked` is referenced but never loaded, so every doc comment
goes through that function.

- **A trailing `\` is not a hard break.** It renders as a literal backslash.
  The C3 stdlib uses it zero times in `lib/std`. ztk needs it because Zig
  autodoc *is* CommonMark. 3tk must not use it.
- **It is not needed.** Every non-blank line inside a paragraph already gets a
  `<br>`. Consecutive lines break on their own.
- **So one source line is one rendered line.** There is no soft wrap. A
  sentence wrapped across two source lines renders broken in half. **Every
  line must stand alone** - which is what the register asks for anyway.
- **Code goes in a ` ```c3 ` fence**, the C3 stdlib's own convention, 44 fence
  lines in `lib/std`. The renderer gives it `<pre><code>` and C3 syntax
  highlighting. An indented block gets none of that.
- **Two underscores in a bare word are eaten as italics.**
  `must_from_handle()` renders as *mustfromhandle()*. **Wrap every identifier
  in backticks** - inline code is extracted before the italic rule runs.
- `-` bullets, `#` headings and `**bold**` are supported. The register bans the
  bold anyway.

**The argument goes in [ref/3tk-decisions-001.md](ref/3tk-decisions-001.md)**,
and the `// [3tk: ...]` mark points at it.

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

**Which stage runs.** Plan 016's six have all run. There is no declared stage
left, and the next plan is the owner's to write.

**The other seven source files.** 3TK-37 rewrote `helper.c3` from the reference
and stopped there, as the plan says. Whether the pass continues, and as one
stage or three, is the owner's.

**`helper.c3`'s example.** 3TK-33 deleted the fenced `struct Msg` block with
the rest of the prose. Whether a source file carries a worked example at all is
the owner's. 3TK-37 left it in the reference and did not put it back.

**`stack.c3`'s last-in first-out reasoning.** 3TK-34 deleted it from the
source, where it was written for the reader who would otherwise change the
stack back into a queue. `ref/3tk-decisions-001.md` now holds it alone, and so does Part 5 of the
reference. If it belongs in the source, the stage that rewrites `stack.c3` is
where it goes.

**`pool.c3`'s late-close comment.** Thirty source lines inside `Pool.put`
explained why the closed flag is re-read after the hook and what would break
without it — the port's longest implementation note, written for the reader who
would otherwise delete the re-read. 3TK-35 took it out with the rest;
`ref/3tk-decisions-001.md` holds it. It is the deletion of this stage worth
refusing. Part 6 of the reference describes it, so a short form has somewhere
to be moved from when `pool.c3` is rewritten.

**Whether `ref/3tk-api-002.md` is retired** once `3tk-reference-001.md` exists.
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

- **Current plan: [3tk-staging-plan-016.md](3tk-staging-plan-016.md).** It
  declares **3TK-32 to 3TK-37** — the strings, three strip stages, the
  reference in 042's shape, and the comments moved out of it — and
  **reproduces no stage that has run.** **None of the six has run.**
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
