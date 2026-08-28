# 3tk — the rules for an example

What an example under `3tk/examples/` must be, and what a stage that adds one
must do.

**This is a procedure, not a stage.** Like
[3tk-doc-loop-003.md](3tk-doc-loop-003.md), it writes no status row and no log
entry of its own. The named stage that follows it writes those.

**Written by 3TK-48**, from [../3tk-staging-plan-019.md](../3tk-staging-plan-019.md),
from the owner's rulings of 2026-08-26, and from `../../../rules-049.md` Parts
1, 2, 4, 5, 6 and 7 read the same day.

**It binds 3TK-49, 3TK-50 and every later stage that adds an example.** It does
not bind `3tk/src`, `3tk/test` or `3tk/negative`, none of which it changes.

**It is normative. The catalog is descriptive.** A rule is changed here and
nowhere else. [3tk-patterns-001.md](3tk-patterns-001.md), written by 3TK-49,
says what the shapes are; this file says how one is written down.

**Nothing here is inherited untested.** A rule with a ztk precedent is named as
ported, and the three ztk rules that do not survive the crossing are named as
not taken. Ported, never copied.

## The word is Outer — MUST

**An outer is the application struct that embeds an `Inner`.** The inner is the
embedded node; the outer is the embedding struct. Never *parent*.

**Every name and every sentence this document's scope covers says `Outer` or
`outer`.** Module names, struct names, function names, parameter names, doc
comments, the catalog, an index row, and the prose of any stage that writes
one.

**Never `Item` or `Items` in new work.**

### The scope of the rule, and why two words are in the port

**The rule binds new work only.** `3tk/examples/`, `ref/3tk-patterns-001.md`,
this file, and anything a later stage adds.

**The existing tree is not searched and replaced.** That is the owner's ruling
of 2026-08-26, and these are the counts that produced it. Re-measured live
2026-08-26 with `grep -roiwE 'items?'`, at the moment of this claim.

**The `ref/` row was 346 when 3TK-48 wrote it and is 360 now.** Fourteen of
those hits are in the two files this rule itself produced: **8 in this document**,
every one of them the rule naming the word in order to ban it, and **6 in
[3tk-patterns-001.md](3tk-patterns-001.md)** — one is that file restating the
rule, and five are ztk entry titles quoted as titles. **Nothing was added to the
old tree.** The row is the live number, not a target.

| where | `item` / `items` |
|---|---|
| `3tk/src` | 125 |
| `3tk/test` and `3tk/negative` | 219 |
| `ref/` | 365 |
| `../../common/matryoshka-specification-005.md` | 165 |

**The last row is why this is a ruling and not a stage.** That document is the
shared input binding otk, ztk and dtk. **3tk does not reword a `common/`
document on behalf of the other three ports.**

**So the port holds two words, and the line between them is *new work against
old*.** That line is a decision. An invisible line — `ref/` renamed and `src/`
not, or `src/` renamed and the specification not — is worse than today.
**If the debt is ever paid, it is paid whole.**

**The deadline is dtk's first stage.** [../../d/dtk-status.md](../../d/dtk-status.md)
has a prepared folder and no stage run, and dtk builds from the specification
alone, so the first dtk stage bakes whichever word the specification uses into a
fourth port. The secondary trigger is a specification `005` written for any
other reason.

**The debt is recorded in three places and this is one of them.** The other two
are [../3tk-status.md](../3tk-status.md) under *Open questions*, and
[../3tk-port-findings-003.md](../3tk-port-findings-003.md), which is the port's
channel to another port. **`../../common/` is not one of the three.**

## The four trees

| tree | supermodule | what it is |
|---|---|---|
| `src/` | `mtk`, `mtk::…` | the toolkit. Eight files, eight modules |
| `test/` | `mtk_test` | correctness. Ten files, 87 tests |
| `negative/` | `neg` | the compile-failure and abort cases |
| `examples/` | `exm`, `exm::…` | one pattern per file, shown to a reader |

**An example is not a test and a test is not an example.** A test probes the
implementation. An example demonstrates it, and is shown in documentation. A
file carrying `@test` and `always_assert` cannot be shown.

**One file per module — MUST.** C3 gives a module one description, and
`c3c docgen` keeps whichever file it reaches first. That is 3TK-38's defect, and
3TK-44 paid for it by splitting `module mtk` across four files into eight
one-file modules. **`examples/` does not re-incur it.**

**The demo outers are one file.** Zig's file-as-struct makes `Event.zig` a type;
C3 has no equivalent, so `exm::outers` is one `outers.c3` and not four files.

## The file name

**`NNN-name.c3`, declaring `module exm::name;`.**

- `NNN` is a three-digit number, and it is what correlates a file with a
  numbered row in the catalog.
- `name` is lowercase, words joined with `_`.
- **The file name and the module name necessarily differ.** A C3 module name
  takes no leading digit and no hyphen. That is a language constraint, not a
  choice, and it is written here so no stage reads the difference as a defect.
- The number is never reused, and it is never renumbered once written.

## What an example is

**Real C3, compiled by the ordinary build, and nothing from the test surface.**

- **No `@test`.** An example is a plain function.
- **No `always_assert`, and no `assert`.** A check goes through
  `exm::helpers::expect`.
- **Nothing from `mtk_test`.** Not the module, not its outers, not
  `test/common.c3`.
- **The outers are `exm::outers`'.** Shared, declared once, and reused by every
  example.
- **Diagnostic output is the standard library's.** No testing logger.

**The entry point is one public function per file.**

- A descriptive name, never `run`.
- Lowercase, words joined with `_`, derived from the example's one-line
  description.
- **It takes an `Allocator`.** An example never reaches for a global allocator.
- **It reports by returning.** A fault, or a value. It never aborts, and it
  never prints a verdict in place of returning one.

**Allocation goes through `mtk::managed`.**

- `mtk::managed::create($Type, a, &slot)` and `mtk::managed::release($Type,
  &slot)`.
- **Never a raw allocator call on an outer.** `a.new(Msg)` in an example
  teaches the lifetime the port does not want taught.
- The outer carries the `Allocator` it was made with. That is what makes
  cleanup-before-acquisition possible at all.

**Cleanup is registered before the acquisition — MUST.**

- The `defer` that releases comes before the call that may fill the Slot.
- The release is null-safe, so the `defer` needs no guard.
- A refused `put` leaves the outer with the caller, and the caller releases it.
- **A reader copies an example. An example that leaks teaches a leak.**

**A check is `exm::helpers::expect`.**

- It takes the fault to return, the condition, and the message.
- **It survives all four builds**, which `assert` does not — a fast build makes
  `assert` a no-op, and a suite built on it reports green without having
  checked.
- **Each example declares its own fault**, named for the example, so a failure
  says which one failed.

## Completeness

**A get-then-put example is not a pattern.**

- **Say where the work comes in.** A caller seeds it, a thread produces it, a
  timer raises it, or the coordinator accumulates it.
- **Say what is done with the outer** once it is in hand.
- **Say where the result goes.** Another mailbox, the caller, a counter the
  caller reads.
- **A pool outer is an empty container on acquisition.** The intent comes from
  outside the pool, always. An example that invents the work inside the pool
  outer is describing something the toolkit does not do.

## Two levels

**Ported from `rules-049.md` Part 1, *Observable by human*.** It applies to
every line of an example.

**Level 1 — the coordinator.** Its body reads as calls to named steps. A guard,
one `expect`, one log line stay inline. The whole flow is visible in a few
lines without opening anything.

**Level 2 — the steps.** One step each, named for what it does. The name is the
documentation.

**The signal.** A comment explaining a block is the signal the block wanted a
name. Extract it and delete the comment.

**One quality bar.** An example is production-quality code. It differs from
`src/` in its job, never in its quality.

## The description is written like the code

**A `<* *>` block at the top of the file, above the `module` line**, in the
shape [3tk-doc-loop-003.md](3tk-doc-loop-003.md) requires of a module block:
one module block per file, above that file's own `module` line.

**The shape of the description mirrors *Two levels*.**

- **One line of intent** — what this example demonstrates. That is the
  coordinator line.
- **Then one bullet per step**, in the order the steps run, each naming what the
  step does and not how.
- **Never one long sentence chaining facts with commas.** That is an
  unextracted block, the same defect in prose as in code.

**The register is the source register**, measured by the doc loop and restated
here because an example stage will not have read that file.

- One sentence per line, and never a wrapped one.
- Every identifier in backticks. `must_from_handle()` bare loses its
  underscores to the italic rule.
- No trailing `\`. It is a literal backslash to `formatDocText`.
- **No numbered lists.** Not implemented; `1. one` renders as the literal text.
- **No tables.** A `|` row renders as itself.
- **No nested bullets.** An indented sub-bullet renders at the parent's level.
- Rationale only where it is short and non-obvious. No argument.

**Every diagram is fenced.** ` ``` ` on its own line, the diagram, ` ``` ` on
its own line. Unfenced box drawing collapses.

**No doc comment is not done.**

## The wrapper in `test/`

**Every example is called by a wrapper, and the wrapper is the only place
`always_assert` appears.**

- The wrapper lives in `test/`, carries the `@test`, supplies the allocator, and
  calls the example's entry point.
- **It checks the returned fault**, and names it when it reports.
- **It adds no logic of its own.** A wrapper that does work is a test wearing an
  example's name.
- The wrappers are the reason the examples are compiled and run at all. An
  example nothing calls is not verified.

## An index routes and never copies

**The description lives in the example's own `<* *>` block and nowhere else.**

- An index row is a number, a name, a one-line hook, and a link to the file.
- **Do not restate the description in the index.** The source is the single
  truth and the index routes to it.
- **The catalog's index is its own opening table**, not a second file. It earns
  a file of its own on the first of three triggers: a script has to read it, the
  catalog outgrows its own table, or the numbering has to be published to
  another port.

## Dispatch

**`switch` over an identity is permitted in 3tk — and this is an inversion.**

- ztk's `rules-049.md` Part 7 makes *No switch over tags* a MUST. That rests on
  a Zig tag being the address of a global, which the linker assigns, so a
  `switch` prong is not known while compiling.
- **A C3 `typeid` has no such problem.** `switch` over an identity is a shape
  3tk may write, and [c3-capabilities-001.md](../c3-capabilities-001.md) lines
  147 to 162 measured it.
- **The permission is subject to a live probe.** A stage writing the shape
  compiles it in all four builds before it writes it down.

**A dispatch chain ends with its final branch — MUST.** Ported unchanged.

- Closed set, every identity present in the chain: the last branch is
  `unreachable`, with the reason beside it.
- Open set, anything anyone may send: count it, report it, or return a fault.
  Then move on.
- **It cannot free the outer.** Releasing needs the size, the size needs the
  type, and an unknown identity gives neither. Unknown memory belongs to
  whoever knows what it is.

**The transfer rule for a handler — convention, not a MUST.** Ported unchanged.

> On return, the Slot is empty if the handler took the outer, full if it did
> not.

- **The Slot says where the outer went. The fault says whether the work
  succeeded.** They are two questions.
- A handler may move the outer and then fail. A caller that releases on fault
  without reading the Slot double-frees.

**The word for a `typeid` in an example is identity, not tag.** That is the
port's word, in `src/` and in the reference, and an example does not introduce a
second one.

## What binds `src/` and nothing else

**Named in a section of its own so no example stage mistakes these for its
own.**

- **LE import order** — imports at the bottom of the file. It binds `src/`. It
  does not reach `test/`, `negative/` or `examples/`.
- **The SPDX header** — the two `SPDX-` lines at the top. **The owner adds
  them.** They bind `src/` and nothing else.

**Neither is a defect when it is absent from an example.**

## What binds a stage that writes an example

**Every one of these is run, not assumed. The live-scan rule is ztk's Part 4
and it is taken whole: a scan is done only when it has been re-run against the
current file contents at the moment of the claim.**

- **Every fenced ` ```c3 ` block in a catalog or a rules document is
  compiled**, by 3TK-30b's method: a scratch module built against `3tk/src`,
  every block drawn from it, the scratch output and any generated `headers/`
  removed afterwards.
- **The banned-word scan is run live** over every file the stage wrote,
  including `Item` and `Items` over anything in this rule's scope.
- **`3tk/run-builds.sh` is green.** Four builds.
- **`3tk/check-doc-loop.sh` is unchanged** unless the stage touched a
  descriptor, and a stage that touches one follows
  [3tk-doc-loop-003.md](3tk-doc-loop-003.md) before it edits either side.
- **Every link is printed and read, both directions.**
- **No change to `3tk/src`.** Not one byte, unless the stage's own charter says
  otherwise.
- **No change to `test/common.c3`**, and no change to the 87 existing tests.
- **Nothing is written under `../../common/`**, and nothing is said to another
  port. A finding for another port goes in
  [../3tk-port-findings-003.md](../3tk-port-findings-003.md), which describes
  and recommends nothing.
- **No `git`.** The owner saves.
- **A stage revising the catalog versions it.** `001` to `002`, the old one to
  `backup/`, and a pointer line in [../README.md](../README.md) and
  [../3tk-status.md](../3tk-status.md).

## What is not taken from ztk

**Named so no stage re-derives them and adopts one by accident.**

- **The quoted-identifier ban.** It is a defect of Zig's autodoc viewer. C3
  ships through neither.
- **The `zig build docs` target-size rule**, and the mkdocs nav sync. Both are
  tooling defects of a pipeline 3tk does not have.
- **Stories.** 3tk has no story tree and no stage has declared one.
- **Every Master rule resting on `Io.Select`, `Io.Group` or `Future`.** The
  owner ruled `std.Io` out of scope on 2026-08-26. C3 has none of them, and
  `error.Canceled` with them.

## What this document does not do

- It writes no code, and it creates no folder.
- It does not decide which pattern lands in which file. The mapping comes after
  the catalog.
- It does not search and replace `Item` across the existing tree. It records the
  counts and the deadline.
- It rules on nothing the owner has not ruled, and it softens nothing the owner
  has.
