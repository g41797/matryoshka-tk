# 3tk — staging plan 018

Written 2026-08-26, after plan 017 was spent.

**Provenance.** Follows [3tk-staging-plan-017.md](3tk-staging-plan-017.md). 017
declared **3TK-38 to 3TK-42** and all five have run. This plan declares
**3TK-43 to 3TK-47**. **Declared, not authorized.** The owner names a stage
before it runs.

State is in [3tk-status.md](3tk-status.md). Narrative is in
[3tk-log.md](3tk-log.md). Neither is duplicated here.

---

## Why this plan exists

**Plan 017 finished the sentences and left the pages empty.**

Every file in `3tk/src` has now been written from
[ref/3tk-reference-001.md](ref/3tk-reference-001.md), and the invariant holds:
328 descriptor sentences of 335 found, the remainder the owner's probe and one
open question. **What a client reads is still three lines.** `c3c docgen` gives
a module one description, and `mtk`'s says the toolkit exists. Part 1 of the
reference says what it is, what it is for, who it is for and what it is not,
and none of that reaches the page.

**The owner named the shape, 2026-08-26.** The reference is the toolkit as
**one page for plain reading**. The doc comments are the same content as **many
pages**, one per module. Not two documents — two renderings of one.

**That turns a module description into a block move, not a sentence move.** A
declaration's descriptor is judged: it may be true, be in the reference, and
still not belong in a `<* *>` block. A module description is copied, whole, and
the check over it is a `diff` rather than a search. **The loop document says
neither direction is automated and neither should be** — written before this
distinction existed, and this plan revises it for module blocks only.

**And four modules cannot hold a description at all.** `mtk.c3`, `inner.c3`,
`queue.c3` and `stack.c3` all declare `module mtk`. C3 gives that module one
description, `mtk.c3` holds it, and `inner`, `queue` and `stack` have nowhere
to put theirs. 3TK-41 closed the resulting defect by merging their headers onto
their structs, **because there was no second description to give them.**

## What the owner ruled, 2026-08-26

Named here so no stage re-opens them.

- **The rules of the crossing live in the flow document**, not in
  [3tk-status.md](3tk-status.md). Status holds state. The register section and
  everything 3TK-42 appended to it is not state and comes out.
- **A module description is exempt** from *a `<* *>` block holds the descriptor
  and the contracts, nothing else*. That rule is a declaration's.
- **The stack is public.** It is no longer described as the pool's private
  storage.
- **The core splits into modules**, so each part can hold a description.
- **No aliases in `mtk` for the split types.** Measured: an alias works and
  keeps the same `typeid`, and it makes the unqualified name ambiguous. The
  unqualified spelling is what the port and its tests already use.
- **ztk is not this plan's concern.** Its flow is different. Combining comes
  after 3tk's flow has been run, if ever, and nothing here generalizes first.
- **Structs, methods and macros are not in this plan.** Module descriptions
  only. The rest is later.

## What is on the table

Measured live 2026-08-26, so no stage re-derives it.

| file | module today | module after 3TK-44 | lines |
|---|---|---|---|
| `mtk.c3` | `mtk` | `mtk` | 25 |
| `inner.c3` | `mtk` | `mtk::inner` | 217 |
| `queue.c3` | `mtk` | `mtk::queue` | 165 |
| `stack.c3` | `mtk` | `mtk::stack` | 86 |
| `helper.c3` | `mtk::helper` | unchanged | 151 |
| `managed.c3` | `mtk::managed` | unchanged | 73 |
| `mailbox.c3` | `mtk::mailbox` | unchanged | 343 |
| `pool.c3` | `mtk::pool` | unchanged | 496 |

**Four modules today, eight after.** Eight files, eight modules, eight
descriptions, eight labelled blocks in the reference.

**What C3 0.8.3 does across a submodule boundary**, probed live rather than
argued.

- **A parent import brings its submodules.** `import mtk;` alone reaches them.
- **Types and methods resolve unqualified.** `Inner`, `Slot`, `InnerQueue`,
  `p.reset()`, `q.push_back(h)` are untouched by the split.
- **Free functions and macros do not.** *Functions from other modules must be
  prefixed with the module name.*
- **An alias keeps the type.** `mtk::Inner::typeid == mtk::inner::Inner::typeid`
  is true — and declaring it makes bare `Inner` ambiguous, which is why there
  are none.
- **`module x @private;` compiles and hides the module from its own parent**, so
  it cannot be used to publish a name under the parent only.

**The call sites the split moves.** Counted, not estimated.

| what | where | count |
|---|---|---|
| `mtk::@check` | `mailbox.c3`, `pool.c3`, `managed.c3` | 14 |
| bare `@check` | `queue.c3`, `stack.c3` | 7 |
| bare `is_linked` | `queue.c3`, `stack.c3` | 2 |
| `mtk::` fault names | `mailbox.c3`, `pool.c3` | 39 |
| `mtk::is_linked` | `t_queue.c3`, `t_stack.c3`, `t_mailbox.c3` | 13 |
| `mtk::inner_offset` | `helper.c3` | 6 |
| `mtk::required_alloc_offset` | `managed.c3` | 2 |

**Only the last two change spelling for a caller.** The faults, `@check` and
`CHECKED` move to `mtk.c3` precisely so the other five rows do not.

## The stages

Five, **declared and not authorized**. They run in number order.

```
3TK-43   the flow document                     ref/ only
   |
3TK-44   the split, and what moves to mtk      src/ only
   |
3TK-45   the stack is public                   ref/ + src/ wording
   |
3TK-46   eight sections, eight labels          ref/ only
   |
3TK-47   the move, and the checker             both, mechanically
```

**Five stages means five clear points.** Each one ends with the clear advice and
the exact line to continue with, written into [3tk-log.md](3tk-log.md) and
[3tk-status.md](3tk-status.md).

**The order is forced, not chosen.**

- 43 writes the format 46 has to obey.
- 44 decides how many blocks there are.
- 45 decides what one of them says.
- 46 writes them all.
- 47 cannot run before any of the four.

---

## 3TK-43 — the flow document

**Start after clear:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-43.
```

### Why it exists

**The rules of the crossing are in the wrong file.** `3tk-status.md` says of
itself *One screen* and holds state. It carries the register, the measured
renderer facts, and everything 3TK-42 appended about the two renderers. None of
it is state — it was true before the first stage and will be true after the
last.

**And the flow has rules this plan depends on that are written nowhere.** The
module-to-block correlation, the format that makes a copy byte-exact, and the
exemption for module blocks. They have no home yet.

### What it does

**Writes `ref/3tk-doc-loop-002.md`**, and moves `001` to `backup/`.

It carries forward all of `001`, and adds:

- **The measured markdown facts.** What `formatDocText` renders, established by
  the owner's probe in `mtk.c3` and by running each shape under `node`:
  paragraphs from blank lines, `#` to `######` headings, `-`/`*`/`+` bullets,
  `` `code` `` spans, `**bold**`, `*italic*`, `[text](url)`, ` ```c3 ` fences.
- **What it does not render**, where a reader would expect otherwise:
  **numbered lists are not implemented** and render as literal text, there are
  no tables, no blockquotes, and no nested bullets.
- **The intersection.** Text written inside what both renderers agree on means
  the same on both sides and may be copied either way.
- **The three restrictions that make a copy safe** — one sentence per line and
  never wrapped, every identifier in backticks, no trailing `\`. **The first is
  the one that bites**: CommonMark joins wrapped lines and `formatDocText` puts
  a `<br>` between them, and re-flowing is not reversible, which is why a
  block destined for a module is written unwrapped in the reference.
- **The correlation.** One module, one labelled block. The label carries the
  module's name; the source side is the `<* *>` directly above `module X;`.
  Nothing else is needed to move it either way.
- **The two kinds of move.** A declaration's descriptor is judged and checked as
  a subset. A module block is copied whole and checked with a `diff`. **This
  revises `001`'s *neither direction is automated, and neither should be*, and
  says so** — for module blocks only.
- **The exemption.** *Descriptor and contracts, nothing else* binds a
  declaration, not a module.

**Then it empties `3tk-status.md` of what it just took**, leaving one pointer
line where the register section was.

### What it may not do

- **It touches no source.** Not one byte of `3tk/src`.
- **It does not edit the reference.** 46 does that.
- **It does not invent a rule the owner has not ruled.** Every rule above was
  ruled 2026-08-26 and this stage writes it down.
- **It does not restate a rule that lives elsewhere.** `001`'s table of rules
  held by link stays a table of links.
- **It generalizes to no other port.** Nothing to `../common/`, nothing to dtk
  or otk.
- No `git`.

### Output and verification

- `ref/3tk-doc-loop-002.md`, and `001` in `backup/`.
- `3tk-status.md` shorter by what moved, with the pointer line in place, **and
  the line count before and after stated**.
- **The banned-word scan run live** over both files.
- **Part 6's markdown rules**, checked by script with fenced blocks skipped.
- `3tk/run-builds.sh` green — a formality here, run rather than assumed. Four
  builds, 63 checks, 87 tests.
- Status row, log entry, **the clear advice and the exact continue line**.

---

## 3TK-44 — the split, and what moves to `mtk`

**Start after clear:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-44.
```

### Why it exists

**Three files have no description to give because they share a module.** C3
gives `mtk` one, `mtk.c3` holds it, and `inner.c3`, `queue.c3` and `stack.c3`
get none. **Until that changes, 46 and 47 have three fewer blocks to write.**

**It also retires 3TK-38's defect permanently.** *`c3c docgen` keeps whichever
file it reaches first* stops being true when no module has two files.

### What it does

**Three module lines change.**

- `inner.c3` — `module mtk;` becomes `module mtk::inner;`
- `queue.c3` — becomes `module mtk::queue;`
- `stack.c3` — becomes `module mtk::stack;`

**Nine declarations move from `inner.c3` into `mtk.c3`**, because they are free
names and the split would otherwise change how every caller spells them:

- the seven faults, as the one `faultdef` line — `CLOSED`, `TIMEOUT`,
  `NOT_AVAILABLE`, `NOT_CREATED`, `EMPTY`, `WOKEN`, `UNKNOWN_IDENTITY`
- `macro @check`
- `const CHECKED`

`VERSION` is already in `mtk.c3`.

**Nothing else moves.** `Inner`, `Handle`, `Slot` and their methods stay, and so
do `is_linked`, `reset`, `inner_offset` and `required_alloc_offset` — **free
functions over `Handle`, which is `inner`'s own type.** The owner ruled that
they belong at that level and the port already writes free functions qualified
by their area, as `mtk::helper::to_handle` shows.

**Then the call sites**, all of them counted in *What is on the table*.

- Bare `@check` and `is_linked` inside `queue.c3` and `stack.c3` become
  qualified.
- `mtk::inner_offset` and `mtk::required_alloc_offset` become
  `mtk::inner::…` in `helper.c3` and `managed.c3`.
- `mtk::is_linked` becomes `mtk::inner::is_linked` in three test files.
- **`mtk::@check` and every `mtk::` fault name are untouched**, which is the
  point of the move.

### What it may not do

- **It writes no documentation.** Not a sentence of it. The three files' `<* *>`
  blocks travel unchanged with their declarations, and the module headers that
  3TK-41 merged onto `struct InnerQueue` and `struct InnerStack` stay merged —
  **46 and 47 decide what a module description says, not this stage.**
- **It changes no signature, no body and no contract.** Module lines, the nine
  moved declarations, and qualification of call sites.
- **It adds no alias.** Measured and ruled against.
- **It renames nothing.** `InnerQueue` stays `InnerQueue` inside `mtk::queue`,
  however that reads. A rename is a separate ruling.
- No `git`.

### Output and verification

- The eight files, and **`c3c docgen` run**: eight modules on the page, each
  with the description its file carries.
- **Run again with a different file passed first.** The description must not
  move. That is 3TK-38's defect, checked once more and now structurally
  impossible.
- **Contracts compared as sorted lines across all eight files.** Identical.
- **`./3tk/check-doc-loop.sh` re-run**, and the count stated. It should not
  change: no descriptor was touched.
- `3tk/run-builds.sh` green. Four builds, 63 checks, 87 tests. **Part 17.2's
  layering checks are read, not assumed** — they assert that `mailbox.c3` and
  `pool.c3` are submodules so `mtk`'s private declarations are out of reach, and
  there is no `@private` left in the core to be out of reach of.
- Status row, log entry, **the clear advice and the exact continue line**.

---

## 3TK-45 — the stack is public

**Start after clear:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-45.
```

### Why it exists

**The owner ruled it public, 2026-08-26.** Four places say otherwise, and one of
them is a recorded decision with markers behind it. **46 cannot write the
stack's block until this is ruled**, because the block would say the thing
that is no longer true.

### What it does

**Reads the markers first.** `ref/3tk-decisions-001.md` records *The pool keeps
one per identity, and it is the only `InnerStack` in the port. It never crosses
the public surface*, cited to `R2`, `R11`, `R13`. **The stage reads what those
markers actually say** before touching the entry.

- If they say only *where the pool keeps its free items*, that survives and the
  *never crosses the public surface* clause is what goes.
- If they say the container is private, **the stage reports that the ruling
  parts company with the specification and stops there.** It does not rewrite a
  marker.

**Then the three prose places**, none of which is a marker:

- `3tk/src/stack.c3` — *The pool's private storage.* and *It does not cross the
  pool's public surface.*
- `ref/3tk-reference-001.md`, the Participants bullet for `InnerStack`.
- `ref/3tk-reference-001.md`, the same two sentences closing *The API — the
  stack*.

**And it gives the stack a reason of its own.** Its whole *what this is* is
currently *the pool uses it*. The queue has one — *the transfer container*. The
stage writes the stack's in the reference first, and the source follows it,
which is the loop's order.

### What it may not do

- **It does not rewrite a marker**, and does not touch `../common/`.
- **It composes nothing.** The stack's new reason goes into the reference
  first, and moves to the source from there. Moved, never composed.
- **It does not make the stack public in code.** Nothing is `@private` today;
  this is a stage about what is written, not about visibility.
- No `git`.

### Output and verification

- What `R2`, `R11` and `R13` say, quoted, **and the decision the stage took
  because of it**.
- The four places, each shown before and after.
- **`./3tk/check-doc-loop.sh stack.c3`: 0 missing**, since the source follows
  the reference.
- **The banned-word scan run live** over the touched files.
- `3tk/run-builds.sh` green. Four builds, 63 checks, 87 tests.
- Status row, log entry, **the clear advice and the exact continue line**.

---

## 3TK-46 — eight sections, eight labels

**Start after clear:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-46.
```

### Why it exists

**Only three modules have a section a description could come from.** Part 1 is
`mtk`'s, Part 4's opening is the mailbox's, Part 5's is the pool's.
`mtk::inner`, `mtk::queue`, `mtk::stack`, `mtk::helper` and `mtk::managed` are
described inside Part 3 and Part 7, in groups that belong to the book's shape
rather than to a module.

**And no block is labelled or formatted for a move yet.**

### What it does

**Grows the reference by five module sections**, each written from what the
book already says about that module and nothing new.

**Labels all eight blocks**, so a script can find them:

```
<!-- 3tk:module mtk::mailbox -->
...
<!-- /3tk:module -->
```

An HTML comment is invisible in the rendered page and exact when parsed. **The
label carries the module name**, which is the whole correlation.

**Writes every labelled block in the format 43 fixed** — the intersection only,
one sentence per line, unwrapped, identifiers in backticks, no trailing `\`, no
numbered list, no table.

**And it decides how much of a tool's part belongs on its page.** *What this is*
and *Participants* are the intersection already. **A *Usual flow* is not** — it
is a numbered list with nested bullets under each step, and neither survives.
Either it is reshaped to flat bullets or it stays out of the block, and **the
stage reports which it did for each of the eight, rather than ruling once for
all.**

### What it may not do

- **It touches no source.** Not one byte of `3tk/src`. 47 moves.
- **It invents no fact.** A module section is written from what the reference
  already says. Where the book says nothing about a module, **the stage reports
  the gap rather than filling it.**
- **It does not restructure Parts 3 to 5.** They repeat one order, and a section
  added for a module does not disturb it.
- **It does not touch `../../../matryoshka-api-reference-042.md`.**
- No `git`.

### Output and verification

- `ref/3tk-reference-001.md`, revised in place — **a stage that revises it
  versions it**, so `002` and `001` to `backup/`.
- **Every labelled block rendered**, by copying it through `formatDocText` under
  `node`, and by GitHub's own rendering of the file. **One rendered line per
  source line on the doc side, and one flowing paragraph on the book side, both
  saying the same thing.**
- **The label pairs counted: eight open, eight close, eight distinct module
  names**, checked by script.
- Which of the eight kept a *Usual flow*, and in what shape.
- **The banned-word scan run live.**
- `3tk/run-builds.sh` green. Four builds, 63 checks, 87 tests.
- Status row, log entry, **the clear advice and the exact continue line**.

---

## 3TK-47 — the move, and the checker

**Start after clear:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-47.
```

### Why it exists

**Everything before it prepares a copy that nothing has yet made.** The blocks
are written, labelled and formatted; the modules exist to receive them; the
rules are in the flow document. **This stage is the first one where a module
description is moved by a script rather than by a reading.**

### What it does

**Teaches `3tk/check-doc-loop.sh` the second kind of check.**

- For a labelled block: **transform and `diff`.** Strip one leading space per
  line, or add one — that is the entire transformation — and compare bytes.
  Any difference is a failure, named by module.
- For everything else: **today's sentence-subset check, unchanged.**
- The two report separately, and the exit status covers both.

**Moves the eight blocks**, reference to source, replacing each module's `<* *>`.

- **`mtk` first.** It is the one the owner's probe is sitting in, and Part 1 is
  what replaces the probe.
- **The `// [3tk: ...]` mark on each module line is not touched.** It sits below
  the block, and it is the decisions file's index into the source.

**Then it runs the move in the other direction, on a copy, and compares.**
A block moved out and back must be byte-identical, or the format is not
byte-exact and **the stage reports that rather than adjusting the file until it
passes.**

### What it may not do

- **It composes nothing and rewords nothing.** It is a copy. A block that does
  not fit is a defect of 46, reported back, not patched here.
- **It touches no declaration's `<* *>` block.** Module descriptions only.
- **It does not delete a `// [3tk: ...]` mark.**
- **It does not automate the declaration direction.** That stays judged, and the
  flow document says so.
- No `git`.

### Output and verification

- The revised checker, and **its two reports over all eight modules: 0 differing
  blocks, and the descriptor count unchanged.**
- **The round trip**, run and shown byte-identical.
- **`c3c docgen` run, and the eight module pages read** — not the source. The
  `mtk` page must now open with what Part 1 says.
- **`formatDocText` over all eight blocks**, one rendered line per source line.
- **The banned-word scan run live** over `3tk/src` and the reference.
- `3tk/run-builds.sh` green. Four builds, 63 checks, 87 tests.
- Status row, log entry, **the clear advice and the exact continue line**.

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
- **A rendering claim is made only after running the renderer**, never from
  reading the source.
- **A claim about C3 is measured with `c3c`**, never argued. Plan 018's own
  addition, and the reason the alias question has an answer.
- **[../../../rules-049.md](../../../rules-049.md) Part 4 and Part 6 bind every
  stage**, and Part 4's live-scan rule means a scan is claimed only when it has
  just been run.
- **`src/` at the repository root is ztk's Zig source and is not touched.**
- **No stage writes under `../common/`.** Specification 004 stands.
- **No stage edits `design/matryoshka-api-reference-042.md`.** It is ztk's.
- **No stage runs `git`.** Moves are plain `mv`. The owner saves.
- **No stage tells dtk anything, and no stage generalizes to a port.**
- **Nothing cites `backup/` as a source of truth.** The owner empties it.

## Versioning

Two entry points are edited in place — [3tk-status.md](3tk-status.md) and
[3tk-log.md](3tk-log.md). **Everything else is versioned.**

- `ref/3tk-doc-loop-001.md` becomes `002` at 3TK-43, and `001` moves to
  `backup/`.
- `ref/3tk-reference-001.md` becomes `002` at 3TK-46. **A stage that revises it
  versions it. A loop run does not** — 017's exception stands, and the flow
  document says so of itself.
- `ref/3tk-decisions-001.md` becomes `002` if 3TK-45 revises its stack entry.

## What this plan deliberately leaves to the owner

Named so no stage picks them up by accident.

- **Descriptions of structs, methods and macros.** This plan is module
  descriptions only. Whether the same correlation reaches a declaration is a
  later ruling, and the reference's named groups do not map one-to-one onto
  declarations the way a module section does.
- **The checking the owner named for later**, held from the conversation of
  2026-08-26 and not shaped into a stage here.
- **Whether `InnerQueue` and `InnerStack` get shorter names** inside
  `mtk::queue` and `mtk::stack`. Breaking, and separate.
- **Whether the register — no bold, one fact per line, *Same as `x()`* — stays
  where 3TK-43 puts it** or becomes its own document. 043 moves it with the
  rest; splitting it later costs nothing.
- **`inner.c3`'s merged file header**, 3TK-40's open question: leave it, reword
  it to the struct, or file it in the reference. **3TK-44 moves that block
  unchanged and does not answer it.**
- **`pool.c3`'s late-close note**, `helper.c3`'s worked example, and
  `stack.c3`'s last-in first-out reasoning. Three deletions the strip stages
  made, all reported by the stages that rewrote those files, none ruled on.
- **Whether [ref/3tk-api-002.md](ref/3tk-api-002.md) is retired** now that the
  reference exists.
- **Promotion to another port.** The owner ruled 2026-08-26 that ztk's flow is
  different and that nothing here generalizes before 3tk's flow has been run.
- **`design/secondary/context.md` lists no `lang/` subfolder**, so every file
  here is an orphan by `check_design.sh`'s count. Left as drift by the owner's
  ruling of 2026-08-25.
