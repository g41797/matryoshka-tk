# 3tk — staging plan 031

Written 2026-09-09.

**Provenance.** Follows [3tk-staging-plan-030.md](backup/3tk-staging-plan-030.md),
which follows `029`, `028`, `027` and `026`. **Those are named, not linked as
sources: `backup/` is transient — the owner empties it — and it is never cited as
a source of truth.**

**030 is spent.** `3TK-69` ran and closed on 2026-09-08. The line that `026`
opened — `3TK-pre-65`, `3TK-67`, `3TK-65`, `3TK-66`, `3TK-68`, `3TK-69` — is
fully run. **Only `3TK-50` remains from any earlier plan, and it waits on the
owner, not on any stage here.**

State is in [3tk-status.md](3tk-status.md). Narrative is in
[3tk-log.md](3tk-log.md).

**The rules every stage is written against are in
[matryoshka-3tk/design/3tk-rules-001.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-rules-001.md)**
— two parts, the port rules and the stage rules. This plan cites that file; it
does not re-argue it. **`3TK-70` rewrites Rules 2, 3 and 4 of it, as
`3tk-rules-002.md`.**

**Two documents are gone and must not be cited.** `3tk-boundaries-001.md` and
`3tk-terms-001.md` are in `matryoshka-3tk/design/backup/`. This matters here more
than usual: **60 comments in `src/` still cite the first of them**, and `M-7`
below is what to do about that.

---

## Why this plan exists

**The problem is the docs site, not the code.**

`c3c docgen` groups by module and by nothing else, and **ignores visibility
entirely** — `@private` and `@local` declarations are published as public. So a
module page publishes its internals beside its user surface. `mtk::inner` is 26
entries on the generated page, of which **13 sit below the file's internal
banner**. The `For internal usage.` marker (Rule 2) *describes* those
declarations; nothing *separates* them.

**The mechanism is C3 module sections.** A `module` declaration opens a section;
several sections may sit in one file, for the same module or for different ones,
and each carries its own imports and attribute defaults. The standard library
uses this: `atomic.c3` carries `std::atomic::types` and `std::atomic`;
`cpu_detect.c3` carries five sections.

**And the standard library also answers the owner's question about intent.**
`std::core::cpudetect` is **public**, is called from `std::hash::blake3`, and is
kept off the main page purely by having a page of its own. That is the ruling
here too: **visibility, not preventing use.**

**`lib/std/core/private/` is a folder name and nothing else.** The compiler reads
the `module` line, not the directory. Two unrelated patterns are filed there — a
`@private` *section of an existing public module* (`allocators_heap.c3`, which
changes no page, and which `inner.c3:341` already does), and *separately named
modules* (`cpudetect`, `machoruntime`). **The second is this stage's mechanism;
the folder is not a third option and no stage proposes moving `src/` into one.**

---

## What the sitting of 2026-09-09 ruled

Written as ids. **A later stage cites an id; it does not re-argue the point.**

### M-1 — four `::internal` submodules, one per file

`mtk::inner::internal`, `mtk::mailbox::internal`, `mtk::pool::internal`,
`mtk::queue::internal`. Each is a **section in its own file**, taking every
declaration below that file's `// For internal usage - everything below this
line.` banner.

**`queue.c3` is included** though it has exactly one such declaration
(`InnerQueue.@guard_insert`). A rule with an exception is a rule a later stage
has to remember.

### M-2 — `mtk::pool::hooks`

A section in `pool.c3` carrying `interface PoolHooks` and the four-clause hook
charter that is today prose in `mtk::pool`'s module block — *a hook runs outside
the pool's mutex, several at once on different threads; a hook that touches
shared state protects it itself; a hook does not call back into the pool; a hook
does not block and does not wait.*

**Why it is a page.** `PoolHooks` is the one place in `src/` where **the toolkit
is the caller and the user is the implementer**. Everything else on `mtk::pool`'s
page is what you call. The file says so itself — *"Policy is not in the pool.
Policy is in the hooks"* — and the charter is a contract on **user code**, which
today reads as a digression on a page about calling the pool. Both blocks get
better: `mtk::pool`'s becomes about the pool, and the charter becomes a page's
subject.

**And it states out loud what the toolkit has never said: user code runs inside
tk.** Today that is discoverable only by reading `create`'s third parameter.

### M-3 — the criterion, so a later stage does not overreach

**A submodule is warranted when the direction of the call inverts** — the toolkit
calls you.

**`GetMode` therefore stays on `mtk::pool`**: it is a value passed on a call the
user makes. Topic is not the test; direction is. Without this id, the next stage
argues for `mtk::pool::modes` on the same reasoning that produced `::hooks`.

### M-4 — "one section per module, several sections per file"

**Not "a second section per file."** `pool.c3` gets **three**. `cpu_detect.c3`
carries five, so three is unremarkable.

**Section order in `pool.c3`: `mtk::pool::hooks`, then `mtk::pool`, then
`mtk::pool::internal`** — the order the declarations already sit in (`PoolHooks`
52, `Pool` 121, the banner 572), so only module lines are added and nothing
moves. Same shape as `atomic.c3`, where the types module opens the file.

**Module count: 6 names become 11.** `mtk`, `mtk::helper`, `mtk::inner`,
`mtk::inner::internal`, `mtk::queue`, `mtk::queue::internal`, `mtk::mailbox`,
`mtk::mailbox::internal`, `mtk::pool`, `mtk::pool::hooks`, `mtk::pool::internal`.

**Sections per file:** `mtk.c3` 1, `helper.c3` 1, `inner.c3` **3 → 2**,
`queue.c3` 2, `mailbox.c3` 2, `pool.c3` 3.

### M-5 — visibility yields where it obstructs; the intent is the page

**Ruled by the owner: the intent is visibility on the docs site, not preventing
use.** Where an attribute and the split disagree, the split wins.

- **`inner.c3`'s Part 3 folds into `mtk::inner::internal` and loses `@private`.**
  It exists today as a second `module mtk::inner @private;` section holding
  `inner_offset`, and `@private` reaches the module and nothing else — so a
  submodule could not keep it and stay reachable from Part 1's crossings. It
  becomes an ordinary cross-module call with an `internal::` prefix.
- **`@private` on `struct _Mbox` and `struct _Pool` is kept**, and **`@local` on
  `InnerStack` is kept** — owner's ruling, *keep unless obstructed*. `@local` is
  file-scoped and survives a second section in the same file. Neither costs
  anything, and loosening them is a separate decision from this one.
- **No new attribute is added anywhere.**

**This also answers an outside criticism.** The review triaged as INTR 11 called
`inner.c3`'s two same-named sections *"work-arounds, not a clean design"* — and
it read that way **because both sections carried the same name**, so the split
had no visible purpose. Naming the second one fixes exactly that.

### M-6 — no helper hooks module, and why

`OuterHelper.create` and `.release` call user code — `$if $defined(outer.init)`
and `$defined(outer.destroy)` — so the inversion is real. **But the hooks are
declared nowhere**, being resolved structurally at compile time, and **a module
needs declarations.**

**Two shapes are refused, and no stage revisits them without new evidence:**

- **Moving `create`/`release` into a hooks module inverts the inversion.** They
  are the two most-called members in the toolkit — `release` 78, `create` 60
  across `examples/` by `MS-1` — and the user calls them. They are the pool's
  `get`, not the pool's `PoolHooks`.
- **Declaring an inert `interface OuterHooks` is worse than nothing.** Nothing
  would reference or check it, and a user meeting an interface on the docs site
  reasonably concludes it must be implemented — when **both hooks are optional**,
  and that optionality is load-bearing: `$if $defined` is what lets `Plain` exist
  with neither. Making it real instead would require dynamic dispatch, costing
  the standing promise that *the toolkit reads and writes no field of your outer
  except the `Inner`*.

**What happens instead:** `mtk::helper`'s module block gains a paragraph naming
both hooks, their exact signatures, their optionality, and **the
silent-misspelling hazard** — a wrong signature or return type is loud, a wrong
*name* is not. INTR 11 has the full account and the candidate guard; **this stage
documents, it does not guard.**

### M-7 — the marks are classified, not swept

**60 `[3tk: ...]` marks remain in `src/`** — `pool.c3` 37, `mailbox.c3` 10,
`helper.c3` 7, `queue.c3` 3, `inner.c3` 3 — measured 2026-09-09. The removal of
2026-09-08 took **103** marks and took them precisely: the `[3tk: D1 …]`
citations into `3tk-decisions-007.md`. The status file generalised that and was
corrected by INTR 11.

**Two kinds, and they are not treated alike.**

- **14 carry a non-`Part` id** — `Q-8` ×8, `R12` ×2, `V11` ×2, `A3` ×2, `D6`,
  `P1`. `Q-`, `R-` and `V-` are `3tk-boundaries-001.md` ids: a spent document in
  a transient `backup/`.
- **46 are a bare `Part N.M`, and those are ambiguous by construction.** The
  shared specification and Boundaries **both number Parts the same way**.

**Ruled: resolve each mark from the code it sits on, never from the number it
carries.** That is 3TK-66's method and it was already needed once here —
`[3tk: Q-8, Part 5.2]` sits on the `$Typeof` arms of `look`, `must_look` and
`take`; specification `5.2` is *"What it is not"*, about identity not being a
string or an index, which has nothing to do with those arms, while Boundaries
`5.2` is *"The safe-build identity check — at both boundaries"*, which is exactly
what they do.

**A mark that resolves to the live shared specification stays. A mark that
resolves to Boundaries goes.** Nothing is rewritten to point at a new document:
where the reason is worth keeping, it becomes plain words in the comment.

**Why here and not in a stage of its own:** the stage already has all four files
open, and comment noise and declaration noise are one problem with two symptoms.

---

## 3TK-70 — the module split, and the hooks page

**Model: Opus 5** (`claude-opus-5`). Rule 7's middle case — the stage **changes**
Rules 2, 3 and 4 and then **applies** them. Three things keep it there rather
than on the applying side: `M-8`'s probe is unrun, the per-section import
redistribution has **no check that would catch a wrong-but-compiling
arrangement**, and `M-7` is a judgment per mark.

### Step 0 — the probe (`M-8`)

**Does a non-generic submodule under the generic `mtk::helper` render sanely in
docgen?** Unrun, and **not assumed** — `mtk::helper` is `module mtk::helper
<Outer>;` and `<Outer>` is a per-section attribute, and `preview-docs.sh` reports
`mtk::helper` as the only page marked generic.

**It gates nothing in the current design** — `M-6` puts no submodule there — so
this is a probe against a future stage, run in a scratch directory with **nothing
under `3tk/` touched**, the way 3TK-61 ran its four. **Record the answer in the
log whichever way it goes.**

### Step 1 — the exemplar, before the sweep

**Rule 8, and it is not optional.** Rewrite `run-builds.sh`'s partition check to
key on **which module section a declaration is in**, rather than on position
relative to the `//` banner. Convert **`queue.c3` alone** — one internal
declaration — and **watch the check go red across the three files that have not
been swept.**

**Negative-test both directions before trusting it**: a marked declaration in the
public section, an unmarked one in the internal section. A check that has never
been seen to fail has not been tested.

**The banner stays as a section header for the human reader**, but it is no
longer the truth. **Position was the truth; the module is now.** That is strictly
stronger: a declaration cannot fail to be in a section.

### Step 2 — the sweep

`inner.c3`, then `mailbox.c3`, then `pool.c3`. Per file: add the section line,
fold `inner.c3`'s Part 3 per `M-5`, and **redistribute the imports.**

> **The silent hazard, and the reason Step 1 exists.** A section's imports are
> its own: *"a subsequent section, even of the same module in the same file, must
> re-declare any imports it needs."* `pool.c3` keeps a single import block at the
> **bottom** of the file; with three sections that block belongs to the **last
> one only**. Nothing in `run-builds.sh` would catch an arrangement that compiles
> but imports in the wrong section.

### Step 3 — `mtk::pool::hooks`

Per `M-2`. The four-clause charter **moves** out of `mtk::pool`'s module block
into the new module's block. **Nothing is deleted** — a clean doc loop proves it.

### Step 4 — the qualification sweep

Free functions and non-method macros now in `mtk::inner::internal` gain an
`internal::` prefix at every call site. **Imported ordinary and constant
identifiers must be qualified with at least the closest submodule path**;
**type identifiers may be used unqualified when unambiguous**; and a **method is
found through its receiver type**, not a module path.

**So the cost is asymmetric, and it was measured:**

| | |
|---|---|
| ~16 method declarations (`_Mbox`'s five, `_Pool`'s, `InnerStack`'s, `repoint_to`, `points_to`, both `@guard_insert`s) | **zero call sites change** |
| 12 free macros in `inner.c3` (`is_mine`, `stamp`, `check_stamped`, `to_inner`, `from_inner`, `must_from_inner`, `from_slot`, `must_from_slot`, `move_from_slot`, `is_linked`, `reset`, `inner_offset`) | every call gains `internal::` |
| `examples/` | **2 lines** — `010-no_raw_allocator_call.c3:26`, `012-type_crossing.c3:33`; both already the allow-listed layering pair |
| `test/` | ~15 in `t_slot.c3`, plus `t_identity.c3` |
| `negative/` | `create_into_full_slot.c3`, `insert_twice_same_queue.c3`, `self_move.c3` |
| `PoolHooks` | **zero** — eight example files declare `struct XHooks (PoolHooks)`, and a type identifier needs no prefix |

**Flagged, not taken:** those two example lines will read `inner::internal::`.
That arguably makes the layering point better, the path now saying what the prose
argues. **If the owner would rather `010` and `012` demonstrate layering
differently, that is a later stage** — this one does the mechanical prefix.

### Step 5 — the marks

Per `M-7`. Classify, drop the Boundaries ones, keep the specification ones.

### Step 6 — `mtk::helper`'s hooks paragraph

Per `M-6`.

### Step 7 — the books

- **`3tk-reference-009.md`**, `008` to `matryoshka-3tk/design/backup/` with a
  plain `mv`. Five new module sections, the hooks charter, the helper hooks
  paragraph, and the *not a container library* sentence corrected — it sits today
  beside a shipped public `InnerQueue` (INTR 11).
- **`3tk-rules-002.md`**, `001` to `backup/`. **Rule 3's truth moves from
  position to module**, and its rationale changes: it argues today from *C3
  ignores `@private` on a method*, and the answer is now *they are on their own
  page*. **Rule 4 gains `M-3`'s second criterion.** **Rule 2 keeps "no prose in
  an internal block" and states it as a ruling with its reason**, so a later
  stage knows it is amending a decision and not tidying a habit — with the
  consequence written down: **a declaration may carry an example if and only if
  it is not in an `::internal` module.**
- **`3tk-decisions-007.md` and `3tk-api-005.md` — every citation re-anchored**,
  each from its own entry's text, never from the number it carried. **This is not
  a debt for a later stage**: anything that moves a line in `../3tk/src`
  re-resolves them in the same stage, and this stage moves nearly every line of
  four files. 3TK-66 re-anchored 326 of them and none resolved from the number it
  carried.
- **`3tk-example-rules-004.md`** — only if the two example lines warrant one.

---

## Verification

Run from `3tk/`.

- **`./run-builds.sh`** — four builds green, **145 tests in each**, every
  per-build figure identical. **Two deliberate exceptions**, and both are
  expected to go red on a correct change before they are updated: the
  **module-list check moves 6 → 11** (the trap `3TK-pre-65` and `3TK-67` both
  hit), and the partition check is rewritten. **The check count moves; the log
  states the new number and why.**
- **The negatives still abort in the safe builds** — `unstamped_insert`,
  `unstamped_crossing`, `wrong_type_must`, `insert_linked_outer`.
- **`./check-doc-loop.sh`** — **5 labelled blocks → 11**, 0 differing, 0 banned
  words, `move-module-docs.sh roundtrip` byte-identical over all of them. The
  sentence total **moves deliberately**: sentences migrate from `mtk::pool`'s
  block into `mtk::pool::hooks`'s rather than being added, and the marker is
  excluded by exact match, so it is the per-module figures that prove it and not
  the total.
- **One carrier per block.** `move_module_docs.py` stops with an error on two
  carriers — the guard that caught 3TK-63 writing `mtk`'s block into `queue.c3`
  on alphabetical order. **Every one of the eleven modules carries a block**
  (Rule 4).
- **`./preview-docs.sh`** — read the entry counts **off the generated page**, not
  predicted, per `3TK-pre-65`'s precedent. Confirm `mtk::inner` falls from 26 and
  that each `::internal` page carries its own description.
- **Rule 9** — `diff` the four ported scripts against `matryoshka-3tk`'s copies
  and require the `ROOT` line to be the only difference. **`3TK-68` found one
  more** — `run-builds.sh:60`'s rename — which is the owner's to port.
- **The three `.yml` files** — reviewed, and **"none needed" is an answer that
  must be written into the log.**

---

## Versions written, and what moves to backup

**This plan.** `030` moves to `design/secondary/lang/c3/backup/` with a plain
`mv`, joining 019–029.

**Two documents are versioned in `matryoshka-3tk/design/`, ruled by the owner
2026-09-09:** `3tk-reference-009.md` and `3tk-rules-002.md`, with `008` and `001`
to that repo's `backup/` by plain `mv`.

**Edited in place, not versioned:** `3tk-status.md`, `3tk-log.md` (append-only,
newest first), `3tk-decisions-007.md`, `3tk-api-005.md`. Every `.c3` file is
edited in place — sources are not versioned.

**The ask-the-owner-first rule is satisfied for `3tk-rules-002.md` and
`3tk-reference-009.md` and for no other file.** A stage that finds it needs a
further new file in `matryoshka-3tk/design/` **asks first, every time.**

---

## Standing constraints

Carried unchanged, restated so this plan is enough on its own.

- **Git is disabled.** No stage runs `git`. Moves are plain `mv`; the owner
  saves.
- **3tk sources — `.c3` and the docs inside them — are edited only in
  `matryoshka-tk`'s copy.** The owner copies them across. **Scripts, the CI
  `.yml` files, and the design documents under `matryoshka-3tk/design/` are
  edited in `matryoshka-3tk` directly.**
- **`matryoshka-3tk` is a read/write working directory** for the paths above.
- **`backup/` is transient and is never a source of truth**, in either repo.
- **`c3c` is at `/usr/bin/c3c`**, 0.8.3, stdlib sources at
  `/home/g41797/dev/langs/c3/lib/std/`. No install step.
- **Never infer a build mode from `-O`.** Pass `--safe=yes` or `--safe=no`.
- **CI is the matrix and the matrix is enough.** The negatives and the layering
  greps stay hand-run. **No stage proposes moving `run-builds.sh` into CI.**
- **A change to `3tk/src` revises the reference in the same stage.**
- **Finishing a stage does not start the next. The owner names it.**
- **Before and after the stage: compact, clear, or nothing — unasked, with the
  reason, and with the exact prompt when it is clear** (Rule 6). **Before it:
  which model, by name, and why** (Rule 7).

---

## What the stage must be told before it runs

**Nothing is open.** `M-1` … `M-8` answer every question this sitting raised, and
`3tk-rules-001.md` holds the rest.

**Two things are flagged rather than ruled, and neither blocks:**

1. **`M-8`'s probe is unrun.** It gates nothing here. Record the answer.
2. **The two `examples/` lines will read `inner::internal::`.** Mechanical in
   this stage; whether `010` and `012` should demonstrate layering differently is
   the owner's, later.

**A stage that finds itself needing a design answer has found a gap in
`3tk-rules-001.md` or in this plan, and the gap is reported to the owner before
the stage continues.** It does not go to `backup/` for it.

---

## 3TK-50 — unchanged, and independent

Still open, still the owner's. It has no next step: every catalog section with a
code shape is covered. What remains is copying and pushing the last steps to
`matryoshka-3tk`. **Independent of everything above and blocking nothing.**
