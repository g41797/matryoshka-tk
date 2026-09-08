# 3tk — staging plan 029

Written 2026-09-08.

**Provenance.** Follows [3tk-staging-plan-028.md](backup/3tk-staging-plan-028.md),
which follows `027` and `026`. **Those two are named, not linked: `backup/` is
transient — the owner empties it — and it is never cited as a source of truth.**
`026` is already gone; `027` and `028` are there today.

**028 ran one stage — `3TK-pre-65`, on 2026-09-07 — and is superseded by an
owner sitting on 2026-09-08 that ran no stage and changed no code.** That sitting
ruled six things. Three of them are rules that bind every later stage, one moves
a module, one inserts two stages at the end of the line, and one **inverts the
order 028 assumed**. That is a different charter, not an edit to one, and a plan
version is not rewritten in place.

State is in [3tk-status.md](3tk-status.md). Narrative is in
[3tk-log.md](3tk-log.md). **The rulings, the surface, the structure and the
invariants are in
[matryoshka-3tk/design/3tk-boundaries-001.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-boundaries-001.md)**,
cited below by part number and not duplicated here — **except `Part 4.4a`, which
this plan supersedes** and which 3TK-67 migrates rather than retires.

**No stage is renumbered.** `3TK-65` and `3TK-66` keep the numbers they have had
since 026, so `3tk-decisions-007.md`'s citations are left alone. The three new
stages take `3TK-67`, `3TK-68` and `3TK-69`.

**So execution order and numeric order differ, deliberately: 67, 65, 66, 68, 69.**
A later stage does not "correct" this. The reason is in *The order, and why it
inverted* below.

---

## Spent stages

**3TK-pre-65 — the readable surface — ran 2026-09-07.** Six module names again,
`inner.c3` in three parts, 34 declarations marked internal, the trim of *why*
out of `src/`, and `run-builds.sh` 81 → 89. Its charter is removed; what it did
is in [3tk-log.md](3tk-log.md) and the state it left is in
[3tk-status.md](3tk-status.md).

**Two of the three checks it added are superseded by this plan**, and 3TK-67
rewrites them. That is not a defect of `3TK-pre-65`: they were correct against
the rule as it stood, and the rule changed. See *Rule 2* below.

**Everything 028 recorded as spent stays spent** — 3TK-62, 3TK-63, 3TK-64 and the
INTR of 2026-09-07, with the five corrections 028 carried forward. None of them
is re-opened here.

---

## What the sitting of 2026-09-08 ruled

Six rulings, each with what backs it. **They are stated once, here, and 3TK-67
carries the three that are rules into `3tk-rules-001.md`.**

### Rule 1 — a contract lives inside the doc block, and an assert is not a substitute

In C3 the contract **is** the doc comment. `@require`, `@ensure`, `@param`,
`@return!` and `@pure` are directives parsed out of the `<* *>` block; there is
no separate attribute form. **Delete the block and the check is gone, silently**,
because a missing contract is not an error but an absence. `3TK-pre-65` proved
this by breaking it: stripping the block from `mtk::must_from_inner` stripped its
type check and `negative/wrong_type_must` stopped aborting in a checking build.

**The claim that `@require`/`@ensure` can be replaced by asserts in the body was
examined and is only one-sixth true.** The manual says *"In safe mode, pre- and
post-conditions are checked using runtime asserts"*, so for the runtime check
alone the two are equivalent. Five things do not survive the swap:

1. **The compile-time catch.** A constant argument violating a `@require` is a
   *compile-time* error. An assert in a body can never be. This is not academic:
   `must_from_inner`'s check is on a macro with a `$Type` argument, which is the
   case c3c is best at catching statically, and `negative/wrong_type_must` sits
   on it.
2. **Which side is named.** A violated contract is reported against the
   **caller**. An assert fires inside the callee and names 3tk's own file — for a
   library whose subject is a border crossing, that points the user at the wrong
   side of it.
3. **The optimizer, and an obligation.** The compiler *may assume a contract
   holds*, and violating one is **unspecified behaviour**. An assert grants no
   such licence. The swap removes an obligation from the caller, not only a
   check.
4. **`@ensure` binds `return`.** In a body it becomes a local plus an assert
   before every exit; a macro with several exits multiplies the sites and one
   missed path is a silent hole.
5. **`@param [in]`, `[&in]`, `[out]`, `[own]`, `[drop]`, `[init]`** have no
   assert form at all.

**Precedent, measured in the C3 stdlib at `/home/g41797/dev/langs/c3/lib/std`:**
`@require` 1456 uses, `@ensure` 56, `assert(` 92. And
`collections/list.c3:77-80` is already the contract-only block shape
`3TK-pre-65` arrived at independently.

### Rule 2 — the internal doc block: a marker, then only directives that work

**This supersedes `3TK-pre-65`'s rule and `Part 4.4a`.** An internal declaration
no longer loses its `<* *>` block. It carries one:

```c3
<*
 For internal usage.

 @param [&in] inner
 @require inner.link.type != null : "unstamped inner"
*>
```

- **The marker is the exact string `For internal usage.`** — a sentence, with the
  period, always the **first line** of the block. Verbatim, so it is checkable the
  way `run-builds.sh` already checks `// Part 2 of 3: public, and not yours` and
  `pool.c3`'s stack banner. **The doc loop excludes it by exact match on that
  string**, not by reasoning about punctuation.
- **After it, only directives that do work.** No prose, no argument, no *why* —
  the trim `3TK-pre-65` performed is not carried back.
- **`@param` is kept when it carries a ref annotation** — `[in]`, `[&in]`,
  `[out]`, `[own]`, `[drop]`, `[init]` — because that is static analysis and a
  null check. **It is dropped when it would be the bare name**, which merely
  restates the signature. A description-less `@param` is legal — the manual marks
  the description optional and the stdlib does it 18 times — but a bare one
  carries nothing.
- **Every internal declaration gets the block, including those with no directives
  at all.** One shape, no exceptions.

**Why the block and not the `//` line `3TK-pre-65` used.** Because the argument
that produced `//` was *the docs site shows a bare signature, which is the only
"not for you" signal C3 offers* — and a marker sentence is a **stronger** signal
than absence, since docgen publishes the description. And because it ends the
case where obeying the visibility rule deletes a check, so no stage is tempted to
strip a block again.

**Why no exception for a declaration with no directives.** Two shapes means two
checks, and the branch between them is *does this declaration have a contract* —
precisely the fact that broke `wrong_type_must`. Adding a `@require` later would
otherwise turn a routine edit into a formatting migration. And a declaration with
no contract is exactly the one whose docs page would otherwise be a naked
signature with no explanation.

### Rule 3 — internal declarations are grouped, and the partition is checked both ways

All internal declarations sit **below one banner per file**, with the reason for
their being public stated once under that banner — extending the decision
`3TK-pre-65` already made for the *"public because C3 cannot hide a method"*
paragraphs.

**The marker stays anyway, and the reason is docgen.** `c3c docgen` ignores
visibility and groups by module alone (Boundaries probe 3), and it publishes no
file structure and no `//` comment. A reader on the generated page sees a flat
list with no sections in it. **The banner organises the source; the marker is the
only thing that crosses to the site.**

**Position is the truth, the marker is its consequence.** A per-declaration
marker fails by omission and nothing looks wrong; a declaration cannot fail to be
somewhere. So the check is two-directional and total: **every declaration below
the banner opens with the marker, and none above it does.**

### Rule 4 — a module page is a subject, and the root holds only shared vocabulary

**Measured, not predicted:** `src/mtk.c3` is 132 lines and holds **four**
declarations — `VERSION`, the `faultdef` of seven, `@check` and `CHECKED`. The
**36** declarations on `mtk`'s docs page are those four plus **32 from
`inner.c3`**, which declares `module mtk;` at line 31.

**So `mtk` becomes a landing page by moving `inner.c3` out**, and nothing else
has to be invented.

**All four remaining declarations are user surface and none takes a marker.**
`VERSION` and the faults are the vocabulary every submodule and every user shares
— `mtk::CLOSED` is written into the standing fact `return mtk::CLOSED~;`, and
burying it in a submodule would re-spell it at every user site. `@check` and
`CHECKED` were checked before assuming: **`examples/060-guarding_an_expensive_check.c3`
teaches them, four call sites**, and its whole subject is *guard an expensive
check with `CHECKED`*.

**Four public declarations, one a version and one a fault set, is what a root
module is for. No new file is created to hold them.**

### Rule 5 — generated content never edits a checked-in source

Ruled while deciding where a source-LOC number may go, and general. A number, a
date or a count that a build computes is **not** written into a file under `src/`.
It is injected downstream — into the generated site, or into a copy in a build
directory that docgen reads.

Three things it would break if done in place, and they are the test for any
future proposal of the same shape: **the doc loop** would carry a number that is
wrong the moment any line of `src/` changes, turning a clean 418-of-418 into a
permanent `DIFFERS`; **the two repos would diverge on a line that is not `ROOT`**,
because CI runs in `matryoshka-3tk`; and **the tree comes back dirty after a
build**, which is the noise that hides a real change.

### Rule 6 — `3tk-rules-001.md` is where 3tk's own rules live

**Confirmed by the owner, 2026-09-08:
`matryoshka-3tk/design/3tk-rules-001.md`.** Every rule that binds the C3 port and
is not already a rule in the common tk set. Not a source-file rules document — a
**port** rules document. If a rule holds for every port it stays where the shared
text holds it and 3tk links it; if it exists only because C3 is C3, it lives
here.

**The test for what belongs in it: a rule binds a future stage and can be
checked.** If it says *this is how 3tk is written, and here is what goes red when
it is not*, it is a rule. If it says what one stage does, when, or why we chose
it, it is not — that goes to this plan, to `3tk-status.md` or to `3tk-log.md`.
A decision filed as a rule binds stages that never agreed to it; a rule filed as
a decision is lost when the plan is spent.

**It has two parts, and they are kept apart.** **The port rules** — how 3tk
source is written; Rules 1 to 5 above. **The stage rules** — how a 3tk stage is
run; Rule 7 below. Two parts rather than one list, because a reader of the
published repo comes for the first and a session comes for the second, and mixing
them makes each harder to find.

**The discrimination was widened by the owner on the same day it was drawn.** The
first cut filed process rules to `3tk-status.md`, on the test *is this about how
C3 is written*. That was too narrow: the file's scope is **any rule specific to
3tk that is not in the common tk set**, and a rule that binds every stage is a
rule whatever it governs. The `binds a future stage and can be checked` test
stands; *how 3tk is written* was never the whole of it.

**Nothing is stated twice.** The rule's **statement** lives in
`3tk-rules-001.md`; `3tk-status.md` carries only the operational line a cold
session needs — which stage is next, which model, which prompt — and cites rather
than re-argues, the way it already treats `3tk-boundaries-001.md`.

**It is normative, like
[3tk-example-rules-004.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-example-rules-004.md).**
A rule is changed there and nowhere else, and where it and a descriptive document
disagree, it wins. **It does not bind `3tk/examples/`**, which the example rules
already govern; whether the two ever merge is not decided here.

**It describes 3tk and rules for 3tk only.** It recommends nothing to dtk, otk or
ztk — a finding for them goes to the consuming port's own folder.

**It is created by 3TK-67, not now.** Writing it today would put a normative
document in `matryoshka-3tk/design/` that contradicts `3tk/src`, which the
standing rule calls a defect of the stage that wrote it. Until then **Rules 1
through 5 above are the text**, and 3TK-67 moves them.

### Rule 7 — the stage rules: what the session says before and after a stage

**Both are the session's obligation, not the owner's to ask for.** They are stage
rules, and 3TK-67 puts them in `3tk-rules-001.md`'s second part.

**Before the first stage and after every stage: compact, clear, or nothing** —
said plainly, with the reason, and **when the answer is clear, with the exact
prompt to continue with.** Ruled 2026-09-08, strengthening the older *"each stage
ends with advice"*, which said it only at the end and did not require the prompt.

**Before every stage: which model is suitable for performing it, and why.** Ruled
2026-09-08. This turns the standing Opus pre-authorisation from a permission into
an obligation, and makes it two-way — **a stage that is a mechanical sweep against
a settled rule says so, rather than silently taking the strongest model.**

**The basis, so the advice is a judgment and not a coin toss: how much of the
stage is deciding rather than applying.** A stage that rules, measures, probes, or
writes prose that binds later stages wants the strongest model. A stage that
applies a rule already written, across many files, with a build check that says
when it is wrong, does not. **The middle case is a stage that both changes a rule
and applies it** — the deciding part is small but load-bearing, so it takes the
stronger model and the sweep is cheap either way. That is `3TK-67` exactly.

**Each charter below carries its own recommendation, by name**, the way each
carries a *where to start*. **It is advice and not an action:** the session names
the model the stage wants; the choice stays the owner's.

**The names are pinned as of 2026-09-08, against this roster:** **Opus 5**
(`claude-opus-5`), **Sonnet 5** (`claude-sonnet-5`), **Haiku 4.5**
(`claude-haiku-4-5-20251001`), **Fable 5** (`claude-fable-5`). **If a name in a
charter no longer exists when the stage runs, the basis above governs and the
stage picks its nearest equivalent** — a pinned name that has gone stale is not a
reason to stall, and it is not a design question to bring back to the owner.

---

## The order, and why it inverted

028 put `3TK-65` next and `3TK-66` last, and assumed anything about the docs site
came afterwards. **The landing page ruling changes what kind of change that is.**

Moving `inner.c3` to `mtk::inner` is a **module-layout change** — the same family
as 3TK-63 and 3TK-pre-65 — and it re-spells the free crossings and `mtk::stamp`
at user sites. **It cannot come after 3TK-66**, which rewrites the books and all
52 examples: the layout would move under work just delivered and the examples
would be touched twice. The banner-and-marker pass has the same property by a
different route — it changes `src/` doc blocks, which changes what the reference
carries, which is 3TK-66's subject.

**And `3TK-65` moves behind both, because its sites are what 3TK-67 relocates.**
028's own start-instruction names them: `mtk::stamp` in part 2 of `inner.c3`, its
two callers `OuterHelper.stamp` and `.inner`, and `@guard_insert` in `mtk::queue`
and `pool.c3`'s stack section. 3TK-67 renames the first module and re-forms every
one of those blocks. Running 65 first writes them against names and a block shape
with a known expiry date — and 65 will touch `run-builds.sh`, two of whose checks
3TK-67 rewrites.

**A third reason, and the sharpest.** The status file warns *"a new declaration in
part 2 takes the marker, or the build says so"*. Anything 3TK-65 adds is governed
by a doc-block rule that is changing, and it carries contracts — the one category
where getting the block wrong deletes a check silently. Settle the shape, then
write into it.

**3TK-65's content does not change.** The guards, the `$if env::COMPILER_SAFE_MODE`
gating and `HR-5` are unaffected by where the declarations live. This is an
ordering, not a redesign.

**028's reasoning is preserved, not contradicted.** It deferred 65 behind
`3TK-pre-65` *"so that each site is written once and never moved"*. 3TK-67 is
another stage that moves those sites, so the same reason defers it again.

**And the inversion is what lets 3TK-66 keep its closing act.** A concern raised
on 2026-09-07 was that a later docs stage would need Boundaries `Parts 4.2` and
`4.2a` still live to re-rule against, forcing the retirement of
`3tk-boundaries-001.md` off 3TK-66 and onto a later stage. **With 3TK-67 before
3TK-66, those parts are live when 67 needs them, and 3TK-66 keeps the closing act
it already has.** One correction stands: `Part 4.4a` is **migrated into
`3tk-rules-001.md` by 3TK-67**, not retired with the rest — retiring it would
drop a live rule into an archive.

---

## 3TK-67 — the shape

**Next.** **Reads:** Boundaries `Part 4.2`, `4.2a`, `4.3`, `4.4`, `4.4a`, `4.5`,
and Rules 1 to 6 above.

**Model: Opus 5.** It is the middle case of Rule 7 — it
**changes a rule and applies it in the same stage**. Step 1 is two probes, a
module layout and a rewritten module block; step 2 rewrites two build checks
before sweeping 34 blocks; and it writes `3tk-rules-001.md`, prose that binds
every stage after it. The sweep itself is cheap on any model, but the stage is
not the sweep.

A relocation stage in two steps. **No semantics change**, so its proof is that
every figure stays identical, with the module-list check rewritten as the one
deliberate exception — the trap `Part 4.5` warns about, met for the third time.

### Step 1 — the landing page

- **`inner.c3` declares `module mtk::inner;`** in place of `module mtk;`.
- **`mtk` is left with its four declarations** and `mtk.c3`'s module block is
  **rewritten to orient** — it currently describes the whole toolkit, walkers and
  chain rules included, and the walker text goes where the walker is.
- **`inner_offset`'s hiding is re-spelled and re-probed.** It is hidden today by
  living in a separate `module mtk @private;` section at `inner.c3:275`. Part 3
  must remain a **different module** from part 1 for that to hold, and part 2's
  macros must still resolve it. **`@local` is not the lever** — it was probed and
  `inner.c3`'s own macros cannot resolve `inner_offset` under it.
- **Measure, do not assume, what the user sites cost.** The methods are safe:
  `Inner.to`, `Inner.as` and the Slot's five operations are methods, and a method
  needs no module prefix. The exposure is the **free** crossings and `mtk::stamp`.
  `import mtk;` pulls submodules with it, which is why the queue move cost
  nothing at `3TK-pre-65`, but **aliases did need `helper::`** and free macros
  were never measured. **`PL-6` / `Q-1` — the `inner::to_inner` stutter — is what
  this measurement decides**, and if the stutter is real the stage reports it
  before spelling it.

### Step 2 — the banner and the marker

- **One banner per file that has internal declarations**, with the reason stated
  once beneath it.
- **The marker in all 34 blocks**, per Rule 2, with the block restored and the
  directives that do work kept.
- **The checks are rewritten first, then the sweep runs.** This is the standing
  rule about the exemplar, and it is not optional here: 3TK-67 both changes a
  rule and applies it, which is the exact shape that produced the
  `wrong_type_must` defect — where the stage's own new check is what caught it.
  - The two `3TK-pre-65` checks that are superseded — *no declaration carries the
    marker and a describing block at once*, and *a contract-only block is every
    line a `@` line, no prose* — are **replaced**, because Rule 2 requires
    precisely the combination they forbid.
  - The new check is two-directional: every declaration below a banner opens with
    the marker, and none above one does.
  - `check-doc-loop.sh` learns that `For internal usage.` is a marker and not a
    sentence owed to the reference. **Without this the 418 climbs by 34 and the
    loop reports them missing.**
- **The banners are load-bearing**, as `3TK-pre-65` left them and `pool.c3`'s
  stack banner already was.

### What it must not undo

The three things `3TK-pre-65` left, restated because this stage edits every one
of the blocks they live in:

1. **A `@require` lives inside the `<* *>` block.** Rule 1.
2. **`run-builds.sh` asserts the module list.** It is rewritten for the new names,
   not deleted.
3. **The banners in `inner.c3` are what the partition check greps for.**

### Closing acts

- **Creates `matryoshka-3tk/design/3tk-rules-001.md`** and moves Rules 1 to 5 into
  it, with `Part 4.4a` migrated and marked superseded in
  `3tk-boundaries-001.md` rather than deleted — 3TK-66 spends that document.
- **Tunes `matryoshka-3tk/scripts/run-builds.sh`** and states in the log whether
  the `.yml` files needed a change. **`docs.yml` is read**, not grepped: a
  module rename changes what `c3c docgen` emits.

### Verification

`run-builds.sh` green with every figure identical but the module-list check and
the two replaced checks; four builds, 143 tests each. `check-doc-loop.sh` clean
at 418 of 418 with 0 differing — **the count does not move**, which is what proves
the marker was excluded correctly. `move-module-docs.sh roundtrip`
byte-identical. `preview-docs.sh` re-run, and **the new declaration count for
`mtk` read off the generated page** — expected four — the way `3TK-pre-65` read
36 rather than predicting it.

---

## 3TK-65 — the safe-build checks

**After 3TK-67.** **Reads:** Boundaries `Part 5.1`, `Part 5.2`, `Part 5.3`.

**Model: Opus 5.** Small and fully specified, so the temptation
is to spend less — but it writes new declarations **with contracts**, which is the
one category where a wrong doc block deletes a check silently and only a negative
program notices, and it designs two negative programs of its own. Judgment per
line is high even though the line count is low.

**Charter unchanged from 028**, and reproduced so this plan is enough on its own:

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

**Where to start — as 3TK-67 will have left it, not as it is today.** `mtk::stamp`
is the macro to gate around, in part 2 of `inner.c3`, in **`mtk::inner`**;
`OuterHelper.stamp` and `OuterHelper.inner` are its two callers in `mtk::helper`;
the crossings to guard are the four `OuterHelper` members in `helper.c3`;
`@guard_insert` is in `mtk::queue` and in `pool.c3`'s stack section.

**Every declaration it adds obeys Rule 2** — marker first, directives after — and
`run-builds.sh` says so if one does not.

**Verification.** `run-builds.sh` green in both build modes; negative programs for
an unstamped insert and for a crossing with the wrong identity.

---

## 3TK-66 — the books and the examples

**After 3TK-65.** **Reads:** Boundaries `Part 2`, `Part 3`, `Part 6`.

**Model: Opus 5.** The bulk is prose across the books, the
catalog, the example rules and 52 example files, and every catalog section is a
judgment about what to teach and in what order. Volume here is not the same as
mechanism.

**Charter unchanged from 028.** The bulk, last, as in 3TK-60. The reference's
Participants block, the module blocks, the pattern catalog, the example rules and
the api table all **lead with the helper** and teach the macros as the layer
beneath. All 52 example files use the helper. **Part 6 is written into the books
as its own short section.**

**Told by this plan: the trim already happened.** `3TK-pre-65` moved argument out
of `src/` and into the reference, and **3TK-66 does not carry it back.** A part
that reads thin in the source is thin on purpose.

**And a second thing this plan tells it: the module names are `mtk`, `mtk::inner`,
`mtk::helper`, `mtk::queue`, `mtk::mailbox`, `mtk::pool`**, with `mtk` a landing
page of four declarations. Every worked example and every prose reference is
written against that, not against the six-name list `3TK-pre-65` left.

**Run in steps grouped by catalog section**, the shape 3TK-50 used, each verified
before the next.

**Its closing act is unchanged and it keeps it:** `3tk-boundaries-001.md` and
`3tk-terms-001.md` move to `matryoshka-3tk/design/backup/` with a plain `mv`, and
**Appendix B is deleted** — that deletion being the proof the `007` repair
finished.

---

## 3TK-68 — the names and the scripts

**After 3TK-66.** Genuinely last of the tidying, and small.

**Model: Sonnet 5, and this is the stage that proves Rule 7 cuts both ways.** A
rename, one line in `RUNTIME_NEGATIVES` in two repos, four `diff`s that must show
only the `ROOT` line, and a read of three `.yml` files. Every step is applying a
settled rule with a check that says when it is wrong. **Nothing here is decided**,
and the one judgment it does carry — whether a `.yml` needs a change — is
answered by reading three short files, not by reasoning about the design.

- **`negative/insert_linked_item.c3` is renamed.** It is the **one** filename
  still carrying a retired word. 3TK-60's scan was `grep` over file **contents**
  — *0 in every `.c3` file* — so a filename was never in its scope. Real gap,
  and the only one: `test/` and the rest of `negative/` are clean, checked
  2026-09-08.
- **`run-builds.sh:60` moves with it**, in `RUNTIME_NEGATIVES`, in **both**
  repos. That shared line is why the rename and the script audit are one stage
  and not two.
- **The `matryoshka-3tk/scripts/` audit**: all four ported scripts diffed against
  this repo's copies, with the `ROOT` line required to be the only difference.
- **The `.yml` review**, with `docs.yml` now in scope, and *"none needed"*
  written into the log if that is the answer.

---

## 3TK-69 — the source LOC

**Last, and separate on the owner's ruling of 2026-09-08.** Not folded into any
stage above.

**Model: Opus 5.** It is almost entirely deciding — a docgen
probe whose outcome is decisive, a trust-level trade paid by every downstream
consumer, and a choice about where generated content may live that Rule 5 governs
but does not settle in detail. The code it finally writes is a few lines.

**The goal:** a source line count computed at build time and shown with the
generated documentation.

**Rule 5 governs it: the number is never written into a checked-in source.** The
recommended home is **`matryoshka-3tk/.github/workflows/docs.yml`**, which already
runs `c3c docgen` — downstream of the source, so nothing under `src/` moves, the
doc loop is untouched, and the number is regenerated whenever it is shown and so
cannot rot.

**The C3 mechanism exists and was checked against the manual on 2026-09-08**, so
the stage does not re-derive it:

- **`$include("path")`** splices a file's text at that point. Top level only; the
  included text may not contain a `module` statement; the path is relative to the
  including file. Requires **`--trust=include`** or higher.
- **`$exec("command", args?, stdin?)`** runs a program at compile time and
  splices its stdout as source. Requires **`--trust=full`**. For projects it runs
  from the **`/scripts`** directory.
- **`$embed`** is what the manual points at for pure **data** inclusion rather
  than source text, and is likely the better primitive if the number is wanted as
  a value.

**Four cautions, to be measured rather than assumed:**

1. **It collides with a recorded, deliberate property** — *"`run-builds.sh` needs
   `c3c` and nothing else, and that is deliberate."* `$exec` makes the build
   depend on an external program; `$include` moves that dependency into whatever
   wrote the file.
2. **Trust is paid by every consumer.** A `$exec` in shipped `src/` means every
   downstream build needs `--trust=full`, letting the compiler run arbitrary
   programs. **This alone probably disqualifies `$exec` from shipped source.**
   `$include` at level 2 is milder but is still a flag a user must pass.
3. **Whether `c3c docgen` expands them at all is unmeasured and decisive.** AST,
   and it works; text scan, and the number never reaches the site. **Probe.** The
   docgen probes so far have all come back surprising.
4. **The doc loop reads `src/*.c3`.** A block in an included file is invisible to
   `check-doc-loop.sh` and `move-module-docs.sh` — which is either the point or a
   hole where a descriptor stops being checked, and the stage must say which.

**And the definition is written down, not implied by whichever `wc` ran:** `src/`
only or the whole tree, blanks and comments in or out. `src/*.c3` is 2,073 lines
raw as of 2026-09-08, a figure that means nothing until that is settled. **One
script computes it, run identically by CI and by hand.**

---

## 3TK-50 — unchanged, and independent

**It has no next step** — every catalog section with a code shape is covered —
and it is not blocked by, and does not block, anything above. **It waits on the
owner** to say what closes it: copying and pushing the last steps to
`matryoshka-3tk`, and updating the status table.

---

## The repair of `3tk-decisions-007.md`

Not a stage of its own, and unchanged from 028.

222 lines carry `file:line` citations that 3TK-63's three-pass renumbering left
wrong, 21 of them naming the deleted `managed.c3`. **The restore was withdrawn on
the owner's ruling and is owed by nobody**; `reapply_decisions.py` is spent.
**3TK-66 re-anchors all 222 from the built tree in one pass**, and the file's
header already tells a reader to treat any citation older than 3TK-64 as naming a
file rather than a line.

**One thing this plan adds:** 3TK-67 moves `inner.c3` to `mtk::inner` and re-forms
34 blocks, so **the anchoring must happen after 3TK-67, not before** — which the
order already gives, since 3TK-66 runs third.

**Appendix B of `3tk-boundaries-001.md` is deleted by 3TK-66**, and its deletion
is the proof the repair finished.

---

## Versions written, and what moves to backup

**This plan.** `028` moves to `design/secondary/lang/c3/backup/` with a plain
`mv`, joining 019–027.

**Spent together, and not before their content has dissolved into the code and
the books:** `3tk-boundaries-001.md` and `3tk-terms-001.md`, both to
`matryoshka-3tk/design/backup/` with a plain `mv`. **That is 3TK-66's closing
act**, and the order inversion is what preserves it.

**Created by 3TK-67:** `matryoshka-3tk/design/3tk-rules-001.md`. **The owner has
already been asked and has confirmed the name and the location**, so 3TK-67 does
not ask again — the standing rule is satisfied for this one file and no other.

**Edited in place, not versioned:** `3tk-status.md`, `3tk-log.md` (append-only,
newest first), `3tk-decisions-007.md`. Every `.c3` file is edited in place —
sources are not versioned.

---

## Standing constraints

Carried from 028 unchanged, because none of them was touched. Restated in full so
this plan is enough on its own.

- **Git is disabled.** No stage runs `git`. Moves are plain `mv`; the owner
  saves.
- **No destructive command after a `cd`.** A failed `cd` aborts the `&&` chain
  but **not the next statement**. It has cost a plan file once and put two stray
  files in the repository root once. Absolute paths are the fix, and a stage that
  writes `mkdir … && cd …` checks that the target is a directory and not an
  existing file.
- **3tk sources are edited in `matryoshka-tk` only.** The owner copies to
  `matryoshka-3tk`. Design documents under `matryoshka-3tk/design/` are the one
  place edited directly — **and the owner is asked where before any new file is
  created there, every time.**
- **Every stage tunes `matryoshka-3tk/scripts/` and
  `matryoshka-3tk/.github/workflows/` to the changes it made in `matryoshka-tk`.**
  It is **part of the stage, not a follow-up.**
  - **The port is one line.** The four scripts are byte-identical except that
    `ROOT` gains `/..`. Copy, re-apply that line, `diff`, and require the ROOT
    line to be the only difference. **That diff is the verification.**
  - **The four are** `run-builds.sh`, `run-builds-light.sh`, `run-sanitizers.sh`,
    `preview-docs.sh`. `check-doc-loop.sh`, `move-module-docs.sh` and their two
    Python modules are **not** ported and are not to be.
  - **The `.yml` files are the one thing a stage may edit directly in
    `matryoshka-3tk`**, and a stage states in its log entry whether they needed a
    change — **"none needed" is an answer and must be written down.**
  - **Read the workflow files before saying they need no change.** A grep for
    renamed symbols is not the check: `linux.yml` and `sanitizers.yml` run `c3c`
    inline, and `docs.yml` runs `c3c docgen`.
  - **CI is the matrix, and the matrix is enough.** `run-builds.sh` is never moved
    into CI and no stage proposes it; the negatives, the tier 1 lifetime programs
    and the `Part 17.2` greps are verified when the owner runs the script by hand.
    An accepted gap, written down as one.
- **No claim about C3 syntax is built on without a compile.** A scratch probe
  costs thirty seconds.
- `3tk-log.md` is **append-only**, newest first. Every stage gets an entry,
  however short.
- The banned-word scan skips `design/STATUS-LOG.md`, `design/secondary/` and
  `kitchen/defer/`; hits are reported, not fixed without approval.
- **Before the first stage and after every stage, the session says whether to
  compact, clear, or do nothing — unasked, with the reason — and a clear comes
  with the exact prompt to continue with.** Ruled by the owner 2026-09-08,
  strengthening the older *"each stage ends with advice"*.
- **Before every stage, the session says which model is suitable for performing
  it, by name, and why.** Ruled by the owner 2026-09-08, and the names pinned on
  the owner's instruction the same day. Two-way: a mechanical stage says so
  rather than silently taking the strongest model — **`3TK-68` is Sonnet 5 and
  the other four are Opus 5.** **Advice, not an action** — the choice stays the
  owner's. **A pinned name that has gone stale is not a reason to stall:** the
  basis in `Rule 7` governs and the stage picks its nearest equivalent. Both of
  these are **stage rules** and move to `3tk-rules-001.md`'s second part with the
  rest; see `Rule 7`.

---

## What each stage must be told before it runs

**Nothing is owed by the owner.** Every question 026 held open was ruled by the
second sitting of 3TK-61, and the six rulings of 2026-09-08 are stated above in
full.

**Two things are probes, not owner questions, and 3TK-67 runs both before it
spells anything:**

1. **What an `inner::` prefix costs at user sites** — the free crossings and
   `mtk::stamp`, measured, since `import mtk;` behaves one way for submodule
   types and another for aliases and free macros were never measured. This is
   `PL-6` / `Q-1`.
2. **That `inner_offset` stays hidden** once part 1 is `mtk::inner` — the same
   shape of probe that found `@local` cannot be the lever.

**A stage that finds itself needing a design answer has found a gap in
`3tk-boundaries-001.md` or in `3tk-rules-001.md`, and the gap is reported before
the stage continues.**
