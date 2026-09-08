# 3tk — staging plan 028

Written 2026-09-07.

**Provenance.** Follows [3tk-staging-plan-027.md](backup/3tk-staging-plan-027.md),
which follows [026](backup/3tk-staging-plan-026.md).

**027 ran no stage, and it is spent after a few hours.** It was written earlier
on 2026-09-07 and declared `3TK-pre-65` as a source-and-comments stage. Within
the same sitting the owner read the **generated docs site**, four probes were
run, and **`Part 4.2` was reopened and re-ruled** — so `3TK-pre-65` gained a
module split it did not have, its Step 1 was answered before it ran, and its
Step 5 nearly vanished. That is a different charter, not an edit to one.
**A plan version is not rewritten in place; it is superseded.**

**026 ran three stages** — 3TK-62, 3TK-63 and 3TK-64 — and its remaining two are
carried through unchanged in substance.

State is in [3tk-status.md](3tk-status.md). Narrative is in
[3tk-log.md](3tk-log.md). **The rulings, the surface, the structure and the
invariants are in
[matryoshka-3tk/design/3tk-boundaries-001.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-boundaries-001.md)**,
cited below by part number. None of it is duplicated here.

**No stage is renumbered.** The new stage is `3TK-pre-65`, which states both its
position and the fact that it was inserted. `3TK-65` and `3TK-66` keep the
numbers they have had since 026, so `3tk-decisions-007.md`'s citations are left
alone — and 3TK-63 already showed what a renumbering costs there.

---

## Spent stages

**3TK-62 — the stack goes into the pool — ran 2026-09-07.**
**3TK-63 — the merge into `mtk` — ran 2026-09-07.**
**3TK-64 — `OuterHelper`, and the end of *managed* — ran 2026-09-07.**
**INTR — the state came out of `OuterHelper` — ran 2026-09-07.** Owner-initiated,
between 3TK-64 and this plan, and not a stage: `typeid outer_tid` was deleted and
`OuterHelper` became `typedef OuterHelper = uptr;` with `const OuterHelper OF = {};`.
No call site changed.

Their charters are removed, as 026 removed the charters of what it spent. What
they did, what they found and where they departed from the documents is in
[3tk-log.md](3tk-log.md), and the state they left is in
[3tk-status.md](3tk-status.md).

**Five corrections 026 owed a later reader, carried here because they are still
owed:**

1. **3TK-63's *"`required_alloc_offset` is deleted here, not in 3TK-64"* was
   wrong about the date.** It had two callers until `managed.c3` went, which was
   3TK-64. It was moved into `managed.c3` as `@local` instead, and died with
   that file.
2. **`PL-10` was not *"the one still-missing doc-loop sentence"***. It was five
   missing lines and a differing block. It is closed.
3. **`Part 4.4`'s unhideable-method line does not go onto `Slot`'s methods.**
   The line says *"not part of the user surface"*, and `Slot` is user surface —
   `examples/` calls `.fill` 34 times. It went onto `repoint_to`, `points_to`
   and both `@guard_insert` macros, where it is true.
4. **3TK-64's "the negative program is retired or turned into a positive one"
   was two programs, not one.** `nocompile_managed_two_allocators` asserted the
   same deleted concept and had to go with it. Both became positive tests, and
   the check count fell by eight — two programs in four builds.
5. **Three things 026 left to the stage, and the stage had to rule them:** the
   macro under the helper is renamed `mtk::stamp`; an alias is per-module
   because c3c refuses an unprefixed cross-module alias; and the containers'
   `to_inner` keeps the read-only macro, because the helper's way out of an
   `Outer*` stamps and that direction is crossed concurrently. The log entry
   argues all three.

**And one correction carried from 027, from the INTR:** `struct OuterHelper {}` is not a
thing that compiles. **c3c 0.8.3 answers *"Zero sized structs are not
permitted."*** A zero-state carrier is spelled `typedef X = uptr;`, which is how
the standard library spells `LibcAllocator` and `NullAllocator`. **No stage
tries the empty struct again.**

---

## 3TK-pre-65 — the readable surface

**Reads:** Part 4.2, Part 4.3, Part 4.4, Part 4.6, and `MANUAL.md` §5_6_4 to
§5_6_6.

**Ruled by the owner, 2026-09-07**, on reading `helper.c3` and `inner.c3`:
*"both are absolutely non-readable"*, *"I don't understand which
methods/functions/macros are public for client and which are not"*, *"grouping
of public should be before private/local"*, *"private should be without
comments"*, *"check also usage of `@private` and `@local`"*.

### What is actually wrong, measured

**Density.** `inner.c3` is 336 lines for 26 declarations; `helper.c3` is 223 for
11. That is 13 and 20 lines per declaration, of which about two are code. The
source carries the whole argument for every decision, and
`3tk-reference-008.md` carries it a second time, because the doc loop puts every
sentence in both.

**Visibility is prose, not syntax.** The census across `src/`:

| file | `@private` | `@local` |
|---|---|---|
| `helper.c3` | 0 | 0 |
| `inner.c3` | **1** (`inner_offset`) | 0 |
| `mailbox.c3` | 2 (`_Mbox`, `MBOX`) | 0 |
| `pool.c3` | 3 | 1 (`InnerStack`) |
| `queue.c3` | 0 | 0 |
| `mtk.c3` | 0 | 0 |

One declaration in 26 is hidden in `inner.c3`. Every other one is public and
carries a three-line paragraph saying whether the reader may call it — **seven
such paragraphs across `src/`**, and they disagree in otherwise identical
wording: `outer_tid` ends *"It **is** part of the user surface"*, `repoint_to`
and `points_to` end *"It is **not**"*. A one-bit fact costs three lines to
learn, and the three lines look the same either way.

**No grouping by audience.** Ordering is topical — the link, the Slot, the
crossings — and public and internal interleave inside every group.

### The mechanism exists and 3tk uses none of it

**A module section may set its own default visibility** (`MANUAL.md` §5_6_6,
grammar §12967), and `@public` on a declaration overrides it. That is *"public
before private"*, as a language feature rather than a convention. **It buys
source readability and nothing else** — see Step 3 for why it reaches neither
the reference nor the docs site.

### And the docs site is the third thing wrong — what made 027 spent

**This is what 027 did not know. Owner, 2026-09-07, having read the generated site: *"mtk is non-readable, lot
of methods functions macros — combining inner/helper created documentation
mess."*** Measured: `c3c docgen` groups by module and by nothing else, its whole
option list being `--json`, `--append`, `--target`, `--emit-stdlib`. `mtk` is
**59 declarations on one flat page**, with `is_empty`, `take`, `to` and `stamp`
each listed two or three times and nothing to tell them apart — and the page is
marked `is_generic: true, generic_parameters: ["Outer"]`, so **`Inner`, `Slot`
and `InnerQueue` are presented as parameterized by `Outer`.**

**That is 3TK-63's merge, and 4.2 has been reopened and re-ruled.** The stage
carries the split.

### Owner's rulings for this stage, 2026-09-07

- **One stage, not two.** The visibility restructure and the comment trim
  rewrite the same blocks; doing them apart means rewriting them twice.
- **The source says *what*. The reference says *why*.**
- **`helper.c3` and `queue.c3` go back to modules of their own** —
  `mtk::helper <Outer>` and `mtk::queue`. `OuterHelper` keeps its name.
  `InnerStack` stays private inside `mtk::pool`: *"it's private, that's all."*
- **A declaration that is not the user surface gets `//` comments and no
  `<* *>` block**, and the marker line is **`// For internal usage.`**
- **The undescribed-names gap is accepted** and written down as one.

### Step 1 — spent. What the four probes settled

**All four ran on 2026-09-07, before the stage.** Recorded in
`3tk-boundaries-001.md` 4.2a and 4.4a; repeated here only as the facts the
remaining steps stand on.

**One: methods cannot be hidden, by any attribute.** Not `@private`, and **not
`@local` either** — the compiler warns and accepts the call from another module:

```
Warning: '@private' modifiers are ignored for method declarations.
Warning: '@local' modifiers are ignored for method declarations.
pub=7  hidden=8  filelocal=9
```

`Part 4.4` was right as written. **The fourteen internal methods of `_Mbox`,
`_Pool` and `InnerStack` cannot become `@local`, and Step 5 shrinks to almost
nothing because of it.**

**Two: a separate module keeps `inner_offset` hidden.** `module core::helper
<Outer>;` calling `core::to_inner` compiles and runs; a third module reaching
for `core::inner_offset` is refused. **So the merge was never needed.**

**Three: docgen ignores visibility.** `@private` and `@local` declarations are
published, `_Mbox`/`_Pool`/`InnerStack` among them, as public types. A
declaration with no doc block is still listed, with an empty description.

**Four: the short module prefix works.** `alias MSG = helper::OF{Msg};`
compiles and runs, so the binding line does not grow.

### Step 2 — the module split

`helper.c3` declares **`module mtk::helper <Outer>;`** and `queue.c3` declares
**`module mtk::queue;`**. `mtk.c3` and `inner.c3` keep `module mtk;`.

- **65 alias sites** go from `mtk::OF{Msg}` to `helper::OF{Msg}` — same length.
- **47 `InnerQueue` references outside `src/`** gain a `queue::` segment.
- `mailbox.c3` and `pool.c3` take `alias MBOX @private = helper::OF{_Mbox};`
  and the `POOL` equivalent.
- **`mtk` ends at 36 declarations.**

**`run-builds.sh:215` fails on this correct change** and moves in the same pass:
it asserts `^module mtk::$f;` for `mailbox` and `pool`, and the list is now six.
Part 4.5 warns about exactly this trap for the stack; it applies here.

### Step 3 — sections, and the marker

Public before private inside each file, using the section default:

```c3
module mtk;             // the client surface
// ...
module mtk @private;    // internals — hidden by default
```

The `// --- topic ---` banners stay **inside** a section: the header answers
*who may call this*, the banner answers *what it is about*.

**Then the marker, which is the centre of the stage.** Docgen carries two
signals only — the module, and whether a declaration has a doc block. So:

> **A declaration that is not the user surface gets `//` line comments and no
> `<* *>` block. Whether the compiler can hide it is irrelevant.**

```c3
// For internal usage.
fn void Inner.repoint_to(&self, Inner* to) @inline
    => self.link = any_make(to, self.link.type);
```

One line, identical everywhere. **It does not say "inner"** — `Inner` is a type,
and *"for inner usage"* on `Inner.points_to` reads as being about `Inner`.

**One lever, three artifacts:** the source loses seven paragraphs; the reference
never receives the declaration, since only `<* *>` blocks are descriptors; the
docs site shows a bare signature, which is the only *not for you* signal there
is.

**It sorts by audience, not by hideability.** `Inner.outer_tid` and every
`Slot.*` are unhideable **and** user surface, so they keep their blocks.
`Inner.repoint_to` is unhideable and not user surface, so it loses its.

**Where a maintainer needs the reason a thing could not be hidden, it is stated
once per file under the section banner** — never again per declaration. The
seven *"Public because C3 cannot hide a method"* paragraphs are withdrawn.

**`pool.c3`'s stack banner is load-bearing** — Part 17.2's grep cuts the file at
it. It survives, or the grep moves in this same pass and the log says so.

### Step 4 — the trim: what, not why

Applied to the public blocks that remain. The source keeps the description and
the call-site facts: what it does, what the parameters mean, what it returns,
what aborts. The argument goes to the reference.

**`OuterHelper.release` is the exemplar.** Four sentences today argue why it
returns `void` — the `defer` constraint, the absent recipient, the
already-unwinding path. The source keeps *"It returns `void`, so it needs no
`!` in a `defer`."* The reference keeps the argument.

**Per the standing rule, the exemplar is rewritten first and shown to the owner
before the mechanical pass.**

**Nothing is deleted outright.** Every trimmed sentence already exists in the
reference or is moved there in the same edit — which a clean doc loop proves.

### Step 5 — the `@local` audit

**Probe one nearly emptied this step.** Methods cannot be hidden, so `@local`
fits only non-method declarations, which in `src/` means `inner_offset` and
little else.

- `inner_offset` — `@private` today, all callers in `inner.c3`. **After the
  split, check it can stay `@private` and test whether `@local` also holds.**
- `_Mbox`, `_Pool`, `MBOX`, `POOL`, `InnerStack` keep what they have; each is
  already as hidden as it can be.
- **The fourteen internal methods stay public and take the marker instead.**

**`@local` is file-scoped, so it never fits a declaration two files share.**
That goes in the log entry so a later reader does not lose a build to it.

### The accepted gap

**The names still appear.** `_Mbox`, `_Pool` and `InnerStack` remain listed as
types on the docs site, undescribed, and so do the internal methods. Docgen has
no visibility filter and no exclude flag, and a curated file list does not help
because every file mixes surface and internals. **Undescribed, not absent.**
**Owner accepted it, 2026-09-07, and no stage goes looking for a way around
it** — the same shape as the CI gap.

### Verification

- **`run-builds.sh` green.** Every figure identical — **81 checks, four builds,
  143 tests each** — except the module-list check, which is rewritten for six
  names in this same stage.
- **Part 17.2's layering greps still pass.**
- **`check-doc-loop.sh` clean** — 0 differing blocks, 0 banned words, 0 missing
  sentences, `move-module-docs.sh roundtrip` byte-identical. **The descriptor
  count falls below 510** and the log entry states the new number and why it
  fell; a falling count is normally a defect and this is the one stage where it
  is the point.
- **No `<* *>` block sits on any declaration carrying `// For internal usage.`**
- **`preview-docs.sh` is read, not assumed** — `mtk` at 36 declarations,
  `mtk::helper` and `mtk::queue` as pages of their own, and **no page marked
  generic that is not.**

## 3TK-65 — the safe-build checks

**Reads:** Part 5.1, Part 5.2, Part 5.3.

Small, and deliberately after `3TK-pre-65` **for the same reason 026 put it
after 3TK-64**: so that each site is written once and never moved.
`3TK-pre-65` restructures `inner.c3`, `queue.c3` and `pool.c3`, which is where
every check below lands.

- **The stamp may be written any number of times.** Its argument is a typed
  `Outer*`, which is what makes it safe. This is how `init` stopped being
  forgettable (`HR-5`, discharged).
- **The identity check at both boundaries** (`Q-8`): at the crossing, where the
  user's own line is named in the abort; and at every insertion —
  `InnerQueue.@guard_insert` and `InnerStack.@guard_insert` — which catches an
  unstamped Inner *earlier*, where a message explaining the omission already has
  a home.
- Both are `$if env::COMPILER_SAFE_MODE`-gated. **Fast builds carry nothing**,
  and the log entry says so.

**Where to start, carried from the status file:** `mtk::stamp` is the macro to
gate around; `OuterHelper.stamp` and `OuterHelper.inner` are its two callers;
`@guard_insert` is in `queue.c3` and in `pool.c3`'s stack section.

**Verification.** `run-builds.sh` green in both build modes; negative programs
for an unstamped insert and for a crossing with the wrong identity.

## 3TK-66 — the books and the examples

**Reads:** Part 2, Part 3, Part 6.

The bulk, last, as in 3TK-60. The reference's Participants block, the module
blocks for the three that carry one — `mtk`, `mtk::mailbox`, `mtk::pool`; the
fourth went with `mtk::managed` — the pattern catalog, the example rules and the
api table all **lead with the helper** and teach the macros as the layer
beneath. All 52 example files use the helper.

**Part 6 is written into the books as its own short section** — what 3tk
deliberately does not have, and why. It is the part a reader most often asks for
twice.

**Told by this plan: the trim already happened.** `3TK-pre-65` moved argument out
of `src/` and into the reference. **3TK-66 does not carry it back.** A part that
reads thin in the source is thin on purpose.

**Run in steps grouped by catalog section**, the shape 3TK-50 used, each verified
before the next.

---

## The repair of `3tk-decisions-007.md`

Not a stage of its own, and not deferrable either.

**Its state has moved since 026 wrote this section.** 3TK-62, 3TK-63 and 3TK-64
each folded their entries into `007`'s body, and 3TK-64's fold left the parked
section holding no live ahead-of-the-source decision — only `RT-1`, the `MS-1`
measurements, and four entries marked RULED or DISCHARGED. The four false
citations 026 named are corrected.

**What remains is the anchoring.** 222 lines carry `file:line` citations that
3TK-63's three-pass renumbering left wrong, 21 of them naming the now-deleted
`managed.c3` and none naming `helper.c3`. **The restore was withdrawn on the
owner's ruling and is owed by nobody**; `reapply_decisions.py` is spent.
**3TK-66 re-anchors all 222 from the built tree in one pass**, and the file's
header already tells a reader to treat any citation older than 3TK-64 as naming
a file rather than a line.

**Appendix B of `3tk-boundaries-001.md` is deleted by 3TK-66**, and its deletion
is the proof the repair finished.

## Versions written, and what moves to backup

**This plan.** `027` moves to `design/secondary/lang/c3/backup/` with a plain
`mv`, joining 019–026. **027 is spent without having run a stage**, the same way
025 was — the sitting that followed it overturned its charter.

**Spent together, and not before their content has dissolved into the code and
the books:** `3tk-boundaries-001.md` and `3tk-terms-001.md`, both to
`matryoshka-3tk/design/backup/` with a plain `mv`. That is 3TK-66's closing act.

**Edited in place, not versioned:** `3tk-status.md`, `3tk-log.md` (append-only,
newest first), `3tk-decisions-007.md`. Every `.c3` file is edited in place —
sources are not versioned.

---

## Standing constraints

- **Git is disabled.** No stage runs `git`. Moves are plain `mv`; the owner
  saves.
- **No destructive command after a `cd`.** A failed `cd` aborts the `&&` chain
  but **not the next statement**. It has now cost a plan file once and put two
  stray files in the repository root once, both in the same week. Absolute paths
  are the fix, and a stage that writes `mkdir … && cd …` checks that the target
  is a directory and not an existing file.
- **3tk sources are edited in `matryoshka-tk` only.** The owner copies to
  `matryoshka-3tk`. Design documents under `matryoshka-3tk/design/` are the one
  place edited directly — **and the owner is asked where before any new file is
  created there, every time.**
- **Every stage tunes `matryoshka-3tk/scripts/` and
  `matryoshka-3tk/.github/workflows/` to the changes it made in `matryoshka-tk`.**
  Owner's ruling, 2026-09-07, retroactive to 3TK-62. It is **part of the stage,
  not a follow-up**: a stage that changes a script here and does not carry it
  across leaves the other repo's CI red the moment the owner copies `src/`,
  which is the one moment they are not looking for it.
  - **The port is one line.** The four scripts in `matryoshka-3tk/scripts/` are
    byte-identical to `matryoshka-tk`'s copies except that `ROOT` gains `/..`.
    Copy the file, re-apply that line, `diff` the two, and require the ROOT line
    to be the only difference. **That diff is the verification.**
  - **The four are** `run-builds.sh`, `run-builds-light.sh`, `run-sanitizers.sh`,
    `preview-docs.sh`. `check-doc-loop.sh`, `move-module-docs.sh` and their two
    Python modules are **not** ported and are not to be: they read the reference
    book by a relative path out of `matryoshka-tk`, and the doc loop is run where
    the documents are edited.
  - **The `.yml` files are the one thing a stage may edit directly in
    `matryoshka-3tk`**, and a stage states in its log entry whether they needed a
    change and why — **"none needed" is an answer and must be written down**, so
    a later reader can tell a considered no-change from a forgotten one.
  - **Read the workflow files before saying they need no change.** A grep for
    renamed symbols is not the check: 3TK-64 grepped, wrote *"they invoke the
    scripts by name"*, and **none of them does** — `linux.yml` and
    `sanitizers.yml` run `c3c` inline, `docs.yml` runs `c3c docgen`.
  - **CI is the matrix, and the matrix is enough. Ruled by the owner,
    2026-09-07.** `linux.yml` builds and tests across `safe` x `opt` with
    `fail-fast: false`, so every failure is visible as its own leg.
    **`run-builds.sh` is never moved into CI and no stage proposes it**; the
    negatives, the tier 1 lifetime programs and the Part 17.2 greps are verified
    when the owner runs the script by hand. That is an accepted gap, written
    down as one.
- **No claim about C3 syntax is built on without a compile.** The INTR's
  recommendation to write `struct OuterHelper {}` came from a model that
  reasoned correctly about what the language lacks and guessed at what it has.
  A scratch probe costs thirty seconds.
- `3tk-log.md` is **append-only**, newest first. Every stage gets an entry,
  however short.
- The banned-word scan skips `design/STATUS-LOG.md`, `design/secondary/` and
  `kitchen/defer/`; hits are reported, not fixed without approval.

## What each stage must be told before it runs

**One thing, and only `3TK-pre-65` needs it:** whether c3c 0.8.3 can hide a
method. **That is a probe, not an owner question**, and Step 1 runs it before
anything else in the stage. Every other point 026 held open is ruled. A stage
that finds itself needing a design answer has found a gap in
`3tk-boundaries-001.md`, and the gap is reported before the stage continues.
