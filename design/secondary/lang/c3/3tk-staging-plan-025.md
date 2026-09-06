# 3tk — staging plan 025

Written 2026-09-06.

**Provenance.** Follows [3tk-staging-plan-024.md](backup/3tk-staging-plan-024.md).
024 declared **3TK-60** and **3TK-61**. 3TK-60 ran and closed on 2026-09-04.
**3TK-61 ran on 2026-09-06 as an analysis stage** — 024 itself said *"a **62** if
it turns out structural"*, and it turned out structural. **024 is now fully
spent.** This plan declares the build stages: **3TK-62** through **3TK-66**.

State is in [3tk-status.md](3tk-status.md). Narrative is in
[3tk-log.md](3tk-log.md). **The rulings, the requirements, the measurement and
the parking lot are in
[matryoshka-3tk/design/3tk-rethinking-001.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-rethinking-001.md)**,
cited below by id. None of it is duplicated here.

---

## Context

3TK-61 did not change `src/`. It ruled, measured and recorded. What it settled,
in one paragraph:

**`OuterHelper` becomes a first-class citizen** — `struct OuterHelper { typeid
otrid; }`, in `helper.c3`, module `mtk::helper`, implemented by forwarding to the
crossing macros, which move into `inner.c3` alongside `Inner` and `Slot`.
**`stack.c3` becomes private** inside `pool.c3` and `t_stack.c3` is deleted.
**`managed.c3` leaves the core** into module `xtn` under `3tk/extensions/`, and
the word *managed* survives in no name: `create` and `release` take the allocator
per call, and the `Allocator` field in an Outer becomes optional, for the Outer's
own allocations. Governing all of it: **an Outer is a long-lived heap object,
and a user who does otherwise pays.**

**The measurement is what sizes these stages.** 52 example files use exactly six
spellings — `create` 61, `release` 78, `.must(` 26, `.to(` 25, `.move(` 4,
`.as(` 4 — and call `init` **zero** times. Users work in Slots and reach for the
**method** forms, 59 sites to 8. See `MS-1`.

---

## 3TK-62 — the stack goes private

**Reads:** `RT-4`, `MS-3`.

`src/stack.c3` moves to the **very end of `pool.c3`**; the file and module
`mtk::stack` go away; **`test/t_stack.c3` is deleted.**

Chosen first because it is self-contained and touches no other subject.

**Carries with it, and none of it is optional:**

- **The reversal of 3TK-45** ("stack is public") as a decisions entry.
- `stack.c3:11` — *"A caller who wants a stack declares one"* — and `mtk.c3:20` —
  *"a caller may use either one directly"* — both currently promise the opposite.
- `run-builds.sh:230`, the InnerQueue/InnerStack surface check.
- `project.json`, the doc-loop module list, and the reference's `mtk::stack`
  block.

**Verification.** `run-builds.sh` green, **with the test count down** — expected,
and the log entry states the new number and why. `check-doc-loop.sh` clean
against the new reference, one module block fewer.

## 3TK-63 — the macros move into `inner.c3`

**Reads:** `RT-2`, `PL-6`.

`Inner`, `Slot`, the link and Slot operations, and the crossing macros become one
file, module `mtk::inner`. `src/helper.c3` is emptied of its old content — it is
**not** deleted, because 3TK-65 refills it. The duplicated statement paragraph
(`inner.c3:10-14` ≡ `helper.c3:7-12`) collapses to one. Fourteen qualified
`mtk::inner::inner_offset` calls lose their qualification. Every
`mtk::helper::…` site in `src/`, `test/`, `negative/`, `examples/` is
requalified.

**The one still-missing doc-loop sentence — the `inner.c3` struct-descriptor
summary — closes here** (`PL-10`).

**`PL-6`, the `inner::to_inner` stutter, is the owner's to rule before this stage
runs**, because the sweep spells the names either way exactly once.

**Verification.** Pure relocation, no semantics: `run-builds.sh` must return
**identical** numbers to 3TK-62's. That is the whole proof, the same one 3TK-60
used.

## 3TK-64 — `xtn`, and the end of *managed*

**Reads:** `RT-5`, `RT-12`, `RT-13`, `RT-14`, `RT-15`, `MS-2`, `HR-10`.

Module **`xtn`** under `3tk/extensions/`. `create` and `release` **take the
allocator**. `required_alloc_offset` becomes an **optional** discovery and moves
here — "not found" is an answer, "found twice" is still an error. `create`
**accepts an optional initializer** and forwards it to `alloc::new_try`, which
already zeroes when none is given (`MS-2`). `create` and **the pool's create
hook** both state: **defaults only; the user fills every non-default value.**

**`HR-10` is ruled before this stage runs** — whether the allocating pair lives
in `xtn` alone (keeping "the core allocates nothing") or in the `mtk` helper.

**Semantics change here, deliberately and alone.** Nothing in this stage is
cosmetic, and nothing cosmetic joins it.

**Verification.** `run-builds.sh` green; the 61 `create` and 78 `release` example
sites and the 10/13 test sites are the blast radius, and every one is visited.
**`run-builds.sh` itself changes here**, and it is not optional: it currently
asserts *"nocompile_managed_no_allocator refused, message names `mtk::helper`"*
— a check that an Outer without an `Allocator` field **fails to compile**. RT-13
inverts exactly that: it must now compile and run. The negative program is
retired or turned into a positive one, the check is rewritten, and the message it
names is stale twice over (`mtk::helper` is being refilled, `mtk::managed` is
being retired).

## 3TK-65 — `OuterHelper`

**Reads:** `RT-3`, `RT-6` … `RT-11`, `RT-18`, `HR-1` … `HR-9`, `MS-1`.

`helper.c3` is refilled: `struct OuterHelper { typeid otrid; }`, module
`mtk::helper`, every member forwarding to an `inner.c3` macro with **no logic of
its own**, and **no member reading `self.otrid` to decide anything** — that rule
is written into the file with its reason, because the natural line for a later
maintainer is `if (inner.link.type == self.otrid)`.

**The member list is proposed by `MS-1` and ruled by the owner** before the stage
runs. The evidence points at: `create`, `release`, the three Slot crossings in
the method spelling users already chose, two `Inner*` crossings for dispatch, and
`init`/`to_inner` present but not prominent.

**`HR-5` — how `init` stops being forgettable — is decided in this stage**: the
candidate is `to_inner` stamping the identity idempotently, safe because its
argument is a typed `Outer*`, with a safe-build check at the first crossing as
the complement.

**Verification.** `run-builds.sh` green; new tests for the helper itself; the
macro tests keep their value, because the helper forwards to them (`RT-9`).

## 3TK-66 — the books and the examples

**Reads:** `RT-6`, `RT-11`, `MS-1`.

The bulk, last, as in 3TK-60. The reference's Participants block, the
`mtk::inner` and `mtk::helper` module blocks, the pattern catalog, the example
rules and the api table all **lead with the helper** and teach the macros as the
layer beneath. All 52 example files use the helper.

**Run in steps grouped by catalog section**, the shape 3TK-50 used, each verified
before the next.

---

## Versions written, and what moves to backup

**This plan.** `024` is fully spent and moves to
`design/secondary/lang/c3/backup/` with a plain `mv`, joining 019–023.

**Written by 3TK-61**, all in `matryoshka-3tk/design/`: `3tk-rethinking-001.md`
(new) and **`3tk-decisions-007.md`** (the owner named it), which supersedes
`006` — now in `matryoshka-3tk/design/backup/`. **007 carries a section that
runs ahead of the source**, *"Ruled by 3TK-61, decided and not yet built"*,
because these decisions have no `file:line` yet. **Every stage below folds its
own entries into the body with real `file:line` and deletes them from that
section.** That is not optional tidying; it is how the file stops running
ahead.

**Spent together, and not before their content has dissolved into the code and
the books:** `3tk-rethinking-001.md` and `3tk-terms-001.md`, both to
`matryoshka-3tk/design/backup/` with a plain `mv`. That is 3TK-66's closing act.

**Edited in place, not versioned:** `3tk-status.md`, `3tk-log.md`
(append-only, newest first). Every `.c3` file is edited in place — sources are
not versioned.

---

## Standing constraints

- **Git is disabled.** No stage runs `git`. Moves are plain `mv`; the owner
  saves.
- **3tk sources are edited in `matryoshka-tk` only.** The owner copies to
  `matryoshka-3tk`. Design documents under `matryoshka-3tk/design/` are the one
  place edited directly — **and the owner is asked where before any new file is
  created there, every time.**
- `3tk-log.md` is **append-only**, newest first.
- The banned-word scan skips `design/STATUS-LOG.md`, `design/secondary/` and
  `kitchen/defer/`; hits are reported, not fixed without approval.

## What each stage must be told before it runs

Three points are the owner's and are not a stage's to assume:

1. **`PL-6`** — the `inner::to_inner` stutter, before 3TK-63.
2. **`HR-10`** — where `create`/`release` live, before 3TK-64.
3. **`MS-1`'s proposed member list**, before 3TK-65.
