# 3tk — staging plan 019

Written 2026-08-26, after plan 018 was spent.

**Provenance.** Follows [3tk-staging-plan-018.md](3tk-staging-plan-018.md). 018
declared **3TK-43 to 3TK-47** and all five have run. This plan declares
**3TK-48 to 3TK-50**. **Declared, not authorized.** The owner names a stage
before it runs.

State is in [3tk-status.md](3tk-status.md). Narrative is in
[3tk-log.md](3tk-log.md). Neither is duplicated here.

---

## Why this plan exists

**The toolkit is written down and the way to use it is not.**

Eight source files, a reference in seven parts, an API page, a decisions file
and a doc loop that holds them together. What is missing is the layer between
all of that and a person writing an application: **3tk has no pattern catalog,
and its tests do not read as example code.**

**Three gaps, measured 2026-08-26.**

- **The tests teach the wrong lifetime.** A 3tk outer is allocated — that is
  what `mtk::managed` is for and what Part 9.7's cleanup-before-acquisition
  depends on. **33 declaration lines in six test files put an outer on the
  stack, 41 outers in all.** `managed::create` has 13 call sites, 10 of them in
  `test/`, across four files. A stack outer cannot be released, so the cleanup
  half of every pattern in [../../../patterns-029.md](../../../patterns-029.md)
  is invisible: no defer before the acquisition, no null-safe cleanup, no
  fallback release after a refused `put`. **A reader who copies a 3tk test
  copies a leak.**
- **Nothing dispatches on a type where it matters.** **`switch` occurs 0 times
  in `3tk/src`, `3tk/test` and `3tk/negative`**, though
  [c3-capabilities-001.md](c3-capabilities-001.md) lines 147 to 162 measured
  that C3 does what ztk cannot and the probe printed `switch: Job`. That probe
  predates 3TK-21, which moved the identity into `Inner.link` as an `any`.
  `patterns-029.md` names three dispatch shapes; 3tk has an `if` chain of one
  of them in three container walks and nothing else.
- **Every pool in `3tk/test` is built with exactly one identity.**
  `typeid[1] tags = { Holder::typeid }`, at all six sites. The only multi-tag
  array in the tree is `negative/duplicate_pool_tags.c3`, which exists to be
  refused. So `PoolHooks.on_get(typeid want, ...)` — the one place the port
  gives a caller a bare identity and no outer, and the whole reason a tag-first
  shape exists — **has never had to choose.** That is why the second gap is
  there: nothing in the suite forces a dispatch.

**ztk solved the same problem by separating examples from tests**, and the
reason is the one that settles it: a pattern has to be showable in
documentation, and a file carrying `@test` and `always_assert` cannot be shown.

## What the owner ruled, 2026-08-26

Named here so no stage re-opens them.

- **`std.Io` is out.** `Future`, `Io.Group`, `io.concurrent`, `Io.Select` and
  `error.Canceled` are Zig's. C3 has none of them. Roughly half of
  `patterns-029.md` goes with them, and `ItemList` with it. Every scenario in
  [../../../task2-tests-004.md](../../../task2-tests-004.md) is out of scope.
- **The existing tests are not touched.** All 87 stay as they are, stack outers
  and all. They probe the implementation; the examples demonstrate it.
  `test/common.c3` is not touched either.
- **The examples are separated from the tests.** A fourth tree beside `src/`,
  `test/` and `negative/`, supermodule `exm`.
- **A file name carries a numeric prefix**, as ztk's do — `054-worker_loop.zig`
  — so a file correlates with a numbered entry in a list.
- **3tk's rules for its own examples go under `ref/`**, as a document that can
  be edited, so a later stage follows them instead of re-deriving them.
- **The catalog comes before the mapping.** Which pattern lands in which file is
  decided after the catalog exists, not before.
- **Never `Item` or `Items`. Always `Outer` and `Outers`** — in everything these
  stages write. See *The word is Outer* below.
- **LE import order and the SPDX header bind `src/` and nothing else.** Neither
  reaches `test/`, `negative/` or `examples/`.
- **3tk has priority over the terminology drift.** The drift is written down,
  not fixed.

## The word is Outer

**MUST, and it binds every name and every sentence these three stages write** —
module names, struct names, function names, the catalog, the index, the rules
document and the doc comments.

**The existing tree is not swept, and this is the count that says why.**
Measured live 2026-08-26.

| where | `item` / `items` |
|---|---|
| `3tk/src` | 124 |
| `3tk/test` and `3tk/negative` | 203 |
| `ref/` | 346 |
| `../common/matryoshka-specification-004.md` | **164** |

The last row is the one that makes it a separate ruling. That document is the
shared input binding otk, ztk and dtk, and **3tk does not reword a `common/`
document on behalf of the other three ports.**

**Where the drift is recorded** — three places, each with a different job, and
`../common/` is not one of them.

- `ref/3tk-example-rules-001.md`, in the rule's own scope paragraph. New work
  says Outer; the existing tree is not swept; the reason both words are in the
  port is stated, so the split reads as a decision and not as carelessness.
- [3tk-status.md](3tk-status.md), under *Open questions*, carrying these four
  counts so a cold session finds them without re-deriving them.
- [3tk-port-findings-003.md](3tk-port-findings-003.md), because 164 of the hits
  are in the shared specification and this is the port's existing channel for
  exactly that: what 3tk learned, for another port to read, recommending
  nothing.

**The deadline is dtk's first stage.** [../d/dtk-status.md](../d/dtk-status.md)
has a prepared folder and no stage run, and dtk builds from the specification
alone — so the first dtk stage bakes whichever word the specification uses into
a fourth port. Before that the debt costs one paragraph. The secondary trigger
is a specification `005` written for any other reason, which is the cheap moment
to carry a rename.

**If it is ever paid, it is paid whole.** Renaming `ref/` but not `src/`, or
`src/` but not the specification, splits the two words along an invisible line —
worse than today, where the line is *new work versus old*.

## What is on the table

Measured live 2026-08-26 with `c3c` 0.8.3, so no stage re-derives it.

**The trees, before and after.**

| tree | module | today | after |
|---|---|---|---|
| `src/` | `mtk`, `mtk::…` | 8 files, 8 modules | unchanged |
| `test/` | `mtk_test` | 10 files, 87 tests | wrappers added |
| `negative/` | `neg` | 14 programs | unchanged, or one added |
| `examples/` | `exm::…` | **does not exist** | the new tree |

**What ztk puts beside its examples**, and what 3tk needs the counterpart of.
Read 2026-08-26.

| ztk | holds | 3tk |
|---|---|---|
| `examples/items/` | four demo types, and the shared dispatch functions over them | `exm::outers` |
| `examples/helpers/` | `expect`, the check that survives every build mode | `exm::helpers` |
| `examples/hooks/` | reusable pool hooks | `exm::hooks` |

**`items.zig` is not a bag of structs.** `freeItem` is the item-first chain,
`createByTag` and `destroyByTag` are the tag-first chains, and `freeItem`'s
closing `else` is `unreachable` with the reason beside it. **The dispatch chains
are written once there and reused by every example.** That is the shape
`exm::outers` copies.

**`hooks/` supplies two of this plan's gaps outright.** `AlwaysCreateHooks` is
the tag-first `on_get` written out. `CappedPoolHooks` is backpressure — ztk
scenario 78, which 3tk has no test for at all.

**What ztk's rules-049.md gives, and what it does not.** Read 2026-08-26 for
its tests, examples and Master material, so a 3tk rule with a ztk precedent is
inherited rather than re-derived. Ported, never copied.

- **Taken**: one quality bar; completeness; no testing API inside an example;
  the shared `expect`; *catalog docs are an index, not a copy*; observable by
  human; description as code; fenced diagrams; how a coordinator acquires a
  mailbox or a pool; the live-scan rule; present tense; the final branch of a
  dispatch chain; the handler transfer rule.
- **Inverted**: *No switch over tags — MUST* rests on a tag being a
  linker-assigned address. C3's `typeid` has no such problem. **In 3tk the
  prohibition becomes a permitted shape**, subject to 3TK-50's probes.
- **Not taken**: the quoted-identifier ban, the `zig build docs` size rule and
  the mkdocs nav sync — all three are tooling defects of Zig's autodoc or of
  mkdocs, and 3tk ships through neither. Stories, and every Master rule resting
  on `Io.Select`, `Io.Group` or `Future`.

**One C3 constraint the tree must respect, and this folder has already paid for
it.** 3TK-44 split `module mtk` across four files into eight one-file modules
because C3 gives a module one description and `c3c docgen` keeps whichever file
it reaches first — 3TK-38's defect. **So: one file per module under
`examples/`.** Zig's file-as-struct makes `Event.zig` a type; C3 has no
equivalent, so the demo outers are one `outers.c3` and not four files.

## The stages

Three, **declared and not authorized**. They run in number order.

```
3TK-48   the rules for an example              ref/ only
   |
3TK-49   the pattern catalog                   ref/ only
   |
3TK-50   the examples tree, and one pattern    examples/ + test/ + project.json
```

**The order is forced, not chosen.**

- 48 writes the rules 49 and 50 obey.
- 49 decides which patterns exist, and therefore how many files there are.
- 50 cannot run before either.

**Three stages means three clear points.** Each ends with the clear advice and
the exact line to continue with, written into [3tk-log.md](3tk-log.md) and
[3tk-status.md](3tk-status.md).

**The pattern groups are not in this plan.** How many stages they need depends
on how many patterns survive 3TK-49's classification, which is not knowable
before it runs. A plan 020 declares them.

---

## 3TK-48 — the rules for an example

**Start after clear:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-48.
```

### Why it exists

**The rules exist only in a conversation.** They were derived on 2026-08-26 by
reading ztk's `rules-049.md`, its `examples/` tree and 3tk's own measurements,
and they bind two stages that have not run and every later stage that adds an
example. A rule that lives in a plan gets re-derived; a rule that lives in
`ref/` gets read.

**They are normative where the catalog is descriptive.** Mixing them into the
catalog would mean editing the catalog to change a rule, and would leave a rule
to be found inside prose.

### What it does

**Writes `ref/3tk-example-rules-001.md`**, the sibling of
[ref/3tk-doc-loop-003.md](ref/3tk-doc-loop-003.md). Like it, it is a process
document and not a stage output that a later stage may contradict.

It states, at minimum:

- **The word is Outer.** MUST, first, with the scope paragraph and the four
  counts above.
- **The four trees**, and that `examples/` is `exm::`, one file per module.
- **The file name** — `NNN-name.c3` declaring `module exm::name;`, the two
  necessarily differing because a C3 module name takes no digit-first and no
  hyphen.
- **What an example is** — real C3 only, no `@test`, no `always_assert`,
  nothing from `mtk_test`; the outers shared in `exm::outers` and never
  `test/common.c3`'s; an `Allocator` parameter and `mtk::managed`, never a raw
  allocator call on an outer; cleanup registered before the acquisition;
  reporting by returning; a check through `exm::helpers::expect` with a fault
  the example declares itself.
- **Completeness** — where the work comes from and where the result goes. A
  get-then-put example with no source and no destination is not a pattern, and a
  pool outer is an empty container on acquisition.
- **Two levels** — a coordinator whose body reads as calls to named steps. A
  comment explaining a block is the signal the block wanted a name.
- **The description written like the code**, inside the register
  `ref/3tk-doc-loop-003.md` measured: no numbered lists, no tables, no nested
  bullets. Diagrams fenced.
- **The wrapper in `test/`** as the only place `always_assert` appears.
- **An index routes and never copies.** The description lives in the example's
  own block and nowhere else.
- **What binds a stage** — every catalog block compiled, the ban scan live, no
  change to `3tk/src`, `examples/` and `test/` outside the doc loop, and a stage
  revising the catalog versions it.
- **What binds `src/` and nothing else** — LE import order and the SPDX header,
  in a section of their own so no example stage mistakes them for its own rules.

### What it may not do

- **It writes no code.** No `examples/` folder, no `project.json` line.
- **It does not write the catalog.** 49 does that.
- **It does not invent a rule the owner has not ruled**, and it does not soften
  one that is ruled.
- **It does not search and replace `Item` across the existing tree.** It records the counts
  and the deadline.
- **It writes nothing under `../common/`**, and it tells no other port anything.
- No `git`.

### Output and verification

- `ref/3tk-example-rules-001.md`.
- **A pointer added in [README.md](README.md) and in `3tk-status.md`'s
  entry-point notes**, both of which index the live `ref/` documents.
- **The banned-word scan run live** over the finished file.
- **Every link printed and read**, both directions.
- **The four `Item` counts re-run live at the moment of the claim**, per the
  live-scan rule. They are stated in the document, so they must be true when it
  is written.
- `3tk/run-builds.sh` green — a formality here, run rather than assumed.
- `3tk/check-doc-loop.sh` unchanged: 0 differing blocks, 439 sentences, 438
  found, 1 missing.
- Status row, log entry, **the clear advice and the exact continue line**.

---

## 3TK-49 — the pattern catalog

**Start after clear:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-49.
```

### Why it exists

**`patterns-029.md` is ztk's, and half of it is about a runtime C3 does not
have.** A 3tk reader given that file would meet `Io.Select`, `Io.Group`,
`Future`, `ItemList` and a prohibition on `switch` that is false here.

**And the shapes 3tk does have are written nowhere.** The reference says what
each declaration is. It does not say what a person assembles them into.

### What it does

**Writes `ref/3tk-patterns-001.md`.** `patterns-029.md` is the input and **not**
the template. Every one of its patterns is classified, and the classification is
the work:

- **Carries over in meaning** — the Slot and transfer idioms, the defer shapes,
  the mailbox and pool patterns, the four topologies.
- **Changes shape in C3** — anything resting on a tag being a linker-assigned
  address. *PolyHelper everywhere* becomes the `$Type` macro surface. *Wrapper
  type for infrastructure handles* meets 3tk having no `@private`.
- **Inverts** — *No switch on a tag*, which is a ztk prohibition and a 3tk
  shape.
- **Drops** — every `Io.*`, `Future`, `Io.Group` and cancellation pattern, and
  `ItemList`.
- **New, and 3tk-only** — `managed`'s allocator-in-the-outer, the `typeid`
  switch, the `$Type` crossing, and whatever the classification turns up.

Each surviving pattern keeps `patterns-029.md`'s section shape — *When to use*,
*Code shape*, *Why* — with the code shape in C3.

**The index is the catalog's opening table**, one line per pattern, and not a
second file. The rules document already says an index routes and never copies.
**It earns its own file on the first of three triggers**, named in 3TK-48: a
script needs to read it, the catalog outgrows its own table, or the numbering
has to be published to another port.

### What it may not do

- **It writes no code**, and it creates no `examples/` folder.
- **It does not assign a pattern to a file.** The owner ruled that the mapping
  comes after the catalog.
- **It does not restate the reference.** A pattern is an assembly of the
  surface, not a second description of it.
- **It does not invent a pattern 3tk cannot support.** A shape with no C3
  spelling is reported, not written.
- **It does not touch `3tk/src`**, not one byte.
- No `git`.

### Output and verification

- `ref/3tk-patterns-001.md`, with its opening index.
- **Every fenced ` ```c3 ` block compiled**, by 3TK-30b's method: a scratch
  module built against `3tk/src`, every block drawn from it, the scratch output
  and any generated `headers/` removed afterwards.
- **The classification stated as a count** — how many carried over, changed
  shape, inverted, dropped, and are new.
- **The banned-word scan run live**, including `Item` and `Items` over this
  file.
- **Pointers added to `README.md` and `3tk-status.md`.**
- `3tk/run-builds.sh` green. `check-doc-loop.sh` unchanged.
- Status row, log entry, **the clear advice and the exact continue line**.

---

## 3TK-50 — the examples tree, and one worked pattern

**Start after clear:**

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-50.
```

### Why it exists

**The scaffold and the shape have to be got right once, cheaply, before they
are repeated thirty times.** 3TK-31 and 3TK-37 each did `helper.c3` alone and
left the other seven, and 3TK-31's first version was refused outright. That is
the habit this stage follows.

### What it does

**Creates `3tk/examples/`** and the three support modules, one file each:

- `outers.c3` — `module exm::outers;`. The demo outers, and the shared dispatch
  functions over them: `free_outer`, `free_slot`, `free_queue`,
  `create_by_identity`, `reset_on_put`, `destroy_by_identity`. **Identity, not
  tag** — that is 3tk's word for a `typeid`.
- `helpers.c3` — `module exm::helpers;`. `expect`, taking the fault, so a check
  survives all four builds where `assert` does not.
- `hooks.c3` — `module exm::hooks;`. Reusable `PoolHooks` implementations,
  structs implementing the interface with **no `ctx` pointer** — the
  implementing struct is the context, the shape `test/t_pool.c3` and
  `negative/common.c3` already use.

**Every support module says it is scaffolding in its own `<* *>`**, as ztk's do.
If `c3c docgen` is ever run over `examples/`, `exm::outers` lands on the
generated page beside `mtk::`, and that line is what keeps it honest.

**Adds the build.** `project.json` today is `"sources": ["src/**"]`,
`"test-sources": ["test"]`, targets `mtk` and `mtk-test`. The stage adds an
`exm` static-lib target over `examples/**` and `src/**`, so **an example is
proved to compile with no test wrapper present** — the whole point of moving it
out of `test/` — and puts `examples` into `test-sources` so a wrapper can call
it. `run-builds.sh` gains one build line per mode.

**Writes one pattern, end to end.** A pool with two identities, whose hooks must
choose: `on_get(typeid want, ...)` creating the outer `want` names, `on_put`
with a policy per identity, `on_close(InnerQueue* remaining)` releasing a mixed
remainder. It is ztk scenario 73, which 3tk has never covered, and it exercises
all three gaps at once.

**It carries a source and a destination**, because completeness requires it: a
get-then-put example shows a get and a put, and not a pattern. Work
arrives on a mailbox, is matched to an identity, the pool gives back an empty
outer of that identity, the work goes into it, and the result goes somewhere a
reader can see. **The pool outer arrives empty; the intent comes from the
mailbox.**

**Three probes first**, run and their output recorded, none assumed:

1. `switch (h.link.type) { case Msg.typeid: ... default: }` against today's
   `c3c` and today's `any`-shaped `Inner`. The 3TK-4 probe predates 3TK-21.
2. **Whether a C3 any-switch on `Inner.link` compiles** — `switch (inner.link)
   { case Msg: ... }`. **If it does it is a trap**: `link.type` is the outer's
   identity but `link.ptr` is the chain link, so the binding is a `Msg*`
   pointing at the inner. If it compiles it belongs in `negative/` as a named
   refusal, with `from_handle` named as the only crossing.
3. Whether a `case` takes a `typeid` held in a variable or only a literal
   `T::typeid`. **What a `switch` buys over an `if` chain is stated from this
   measurement**, not from ztk's experience.

### What it may not do

- **It does not touch `3tk/src`.** If a pattern needs a source change, the stage
  stops and reports — the sibling of the doc loop's rule.
- **It does not touch the 87 tests or `test/common.c3`**, beyond adding the one
  wrapper its own example needs.
- **It does not write the other patterns.** One exemplar, and the rest reported
  as outstanding.
- **It does not decide the numbering.** That is the owner's, and it is parked.
- **It does not run `c3c docgen` over `examples/` as a decision.** Whether the
  examples join the generated page is the owner's, and parked.
- **It writes nothing under `../common/`.**
- No `git`.

### Output and verification

- `3tk/examples/` with four files, `project.json` and `run-builds.sh` updated,
  one wrapper in `test/`.
- **The three probes, with their output printed.**
- **`3tk/run-builds.sh` green**, with the new `exm` build in all four modes, and
  **the build, check and test counts stated** — 63 checks and 87 tests before.
- **The separation grep at 0**: no `@test` and no `always_assert` anywhere under
  `examples/`.
- **The `Item` grep at 0** under `examples/` and in anything this stage writes.
- **A leak check** through the counting allocator already in `t_alloc.c3:41-51`.
- **`c3c` accepts a digit-first, hyphenated file name** — verified by building,
  not assumed.
- `check-doc-loop.sh` unchanged: 0 differing blocks, 439 / 438 / 1.
- **The banned-word scan run live** over every file written.
- Status row, log entry, **the clear advice and the exact continue line**.

---

## Rules that hold for all three

- **Every stage ends with `3tk/run-builds.sh` green and the counts stated** —
  four builds, 63 checks, 87 tests before this plan starts.
- **Every stage ends with the clear advice and the exact continue line**,
  written into [3tk-log.md](3tk-log.md) and [3tk-status.md](3tk-status.md).
  **The owner's standing requirement.** Advice that exists only in a
  conversation about to be cleared is worth nothing.
- **A stage that finds itself deciding reports instead.** 3TK-19's precedent.
- **A stage that finds itself inventing prose reports instead.** Plan 016's
  addition.
- **A claim about C3 is measured with `c3c`**, never argued. Plan 018's
  addition, and the reason the alias question has an answer.
- **A rendering claim is made only after running the renderer.**
- **[../../../rules-049.md](../../../rules-049.md) Part 4 and Part 6 bind every
  stage**, and Part 4's live-scan rule means a scan is claimed only when it has
  just been run.
- **`ref/3tk-example-rules-001.md` binds 3TK-49 and 3TK-50** from the moment
  3TK-48 writes it.
- **`src/` at the repository root is ztk's Zig source and is not touched.**
- **No stage writes under `../common/`.** Specification 004 stands.
- **No stage edits `design/matryoshka-api-reference-042.md` or
  `design/patterns-029.md`.** Both are ztk's.
- **No stage runs `git`.** Moves are plain `mv`. The owner saves.
- **No stage tells dtk or otk anything, and no stage generalizes to a port.**
- **Nothing cites `backup/` as a source of truth.** The owner empties it.

## Versioning

Two entry points are edited in place — [3tk-status.md](3tk-status.md) and
[3tk-log.md](3tk-log.md). **Everything else is versioned.**

- `ref/3tk-example-rules-001.md` is new at 3TK-48. A stage that revises it makes
  `002` and moves `001` to `backup/`.
- `ref/3tk-patterns-001.md` is new at 3TK-49, and the same rule binds it.
- **`ref/3tk-reference-002.md` is not revised by this plan.** If a stage finds a
  defect in it, the doc loop's rule applies: it is repaired at source, and the
  stage that revises it versions it.
- `3tk-port-findings-003.md` becomes `004` if 3TK-48 files the `Item` finding
  there rather than as a section of an existing one.

## What this plan deliberately leaves to the owner

Named so no stage picks them up by accident.

- **The numbering.** Inherit ztk's scenario numbers where a pattern carries
  over — so one number means one pattern in both ports, accepting gaps where
  half of ztk's drop — or number 3tk's catalog fresh and dense, with each
  section naming its ztk counterpart in prose.
- **The grain.** One file per pattern is the largest count; one lifetime file
  and one dispatch file is the smallest. 3TK-49 proposes; the owner sets it.
- **What *show patterns in documentation* means.** The markdown catalog only, or
  also `c3c docgen` — which puts `exm::` modules on the generated page beside
  `mtk::` and changes `preview-docs.sh`.
- **Whether the index becomes its own file**, and which of the three triggers
  applies.
- **Whether `Outer` replaces `Item` outside these stages.** The counts and the
  deadline are above. Nothing is done without this ruling.
- **The seven questions plan 018 left**, all still open: `inner.c3`'s merged
  file header, the private-helper `//` rule 3TK-42 asked for, `pool.c3`'s
  late-close note, `helper.c3`'s worked example, whether
  [ref/3tk-api-002.md](ref/3tk-api-002.md) is retired, the two port defects P3
  and P4, and the Slot-idiom question in
  [3tk-who-supports-slot.md](3tk-who-supports-slot.md).
- **The `on_get` difference between 3tk and ztk**, recorded in
  [3tk-port-findings-003.md](3tk-port-findings-003.md) §5a and not ruled.
- **`design/secondary/context.md` lists no `lang/` subfolder**, so every file
  here is an orphan by `check_design.sh`'s count. Left as drift by the owner's
  ruling of 2026-08-25, and `examples/` will add four more.
