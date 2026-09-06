# 3tk — staging plan 024

Written 2026-09-04.

**Provenance.** Follows [3tk-staging-plan-023.md](backup/3tk-staging-plan-023.md).
023 declared one stage, **3TK-59**, and it has since run and closed
(2026-09-04, the `Handle` alias removed, the word kept). **023 is fully spent.**
This plan declares two stages: **3TK-60** and **3TK-61.**

State is in [3tk-status.md](3tk-status.md). Narrative is in
[3tk-log.md](3tk-log.md). Neither is duplicated here.

---

## Context

3TK-59 removed `alias Handle = Inner*` and ruled: *a concept gets a C3 type
when the type system can express useful semantics for it; otherwise it stays
vocabulary.* It kept **handle** as an English word in the books.

The owner has since ruled further, and the ruling goes past that stage:

**3tk has exactly two terms.**

- **`Inner`** — a real C3 type. `struct Inner { any link; }`. The field you
  embed. Chain link and identity in one. A pointer to an embedded one is
  `Inner*`.
- **`Outer`** — not a type, a role. The user's struct that embeds an `Inner`
  so it can be carried intrusively with its type erased.

Two claims follow, both the owner's:

1. **The source still speaks the old vocabulary.** `to_handle(item)` should
   read `to_inner(outer)`. *Handle* was kept as a word in 3TK-59, but under the
   two-term ruling it is a third term that names nothing the two terms do not
   already name. The debt is wide: 150 identifier sites plus prose across
   `src/`, `test/`, `negative/`, `examples/`, and five books.
2. **`managed.c3` pushes an `Allocator` field onto every Outer.** Not by force
   — `required_alloc_offset($Type)` refuses at compile time, and the module
   block says "No type declares itself managed." But `create`/`release` are the
   only allocating helpers on offer, so any Outer that wants them pays the
   field in **every instance**, to store a value identical across all of them.
   It is worst where it is least needed: an Outer allocated through a pool hook
   duplicates per item what the hook already holds once. There are further
   issues the owner has not yet enumerated.

**Order.** The vocabulary first, managed second, and never together — the
rename must prove itself by leaving the build numbers *identical*, and a
semantics change in the same stage would destroy that proof. The rename is
fully specified today; managed is not.

---

## 3TK-60 — the two terms

One stage, with an owner checkpoint in the middle. The terminology document and
the sweep are the same act: the document is the rule, the sweep applies it.

### Step 1 — the terminology document

**`matryoshka-3tk/design/3tk-terms-001.md`** — new, short, single-subject,
versioned, in the same folder as the books. It follows the established shape of
`3tk-on-close-handoff-001.md` and `3tk-lifetime-fix-005.md`: it holds one design
decision while it is live, the stages cite it, its content later dissolves into
code, doc comments and the permanent books, and when spent it moves to
`matryoshka-3tk/design/backup/` with a plain `mv`. It is scaffolding, not a
book. It states:

- the pair: `Inner` is a type, `Outer` is a role, and there is no third term
- the operation set, which is **one addition, one subtraction, one `typeid`
  compare** — everything in `helper.c3` is a spelling of those three
- the naming rule that follows from the pair
- the two managed claims, recorded as **open items, not decisions**, so 3TK-61
  finds them written down without 60 pretending to rule on them

### Step 2 — `helper.c3` by hand, as the exemplar

`src/helper.c3` (167 lines) is where the wrong names are densest: 26 identifier
sites, 8 prose *handle* sites, 17 *item* sites. Rewritten by hand, not
mechanically, so the rule is proven against the hardest file first.

The renames, as currently understood:

| now | after |
|---|---|
| `to_handle(item)` | `to_inner(outer)` |
| `from_handle(Inner* h, $Type)` | `from_inner(Inner* n, $Type)` |
| `must_from_handle(...)` | `must_from_inner(...)` |
| `init(item)`, `@param item` | `init(outer)`, `@param outer` |

**The word *item* does not survive either** — owner's ruling. It becomes
**outer / Outer / Outers**, in parameter names *and* in prose: "one item, with
the type forgotten" → "one outer, with the type forgotten"; "the item keeps the
allocator for life" → "the outer keeps the allocator for life". The sweep is
unconditional: a mailbox message is an Outer, a pool entry is an Outer, and
*item* was only ever the old word for one.

Unchanged: `is_mine`, `from_slot` / `must_from_slot` / `move_from_slot` (`Slot`
is a real type and keeps its name), and the five method spellings `Inner.to`,
`Inner.as`, `Slot.to`, `Slot.must`, `Slot.move`.

### Checkpoint — the owner rules

The owner reads the document and the rewritten `helper.c3` together and rules,
before anything mechanical runs. This is what makes one stage safe: the
vocabulary is approved before it multiplies across ~200 sites.

### Steps 3+ — the sweep

In this order, each verified before the next:

1. the rest of `src/` — `inner.c3` (13 prose sites), `pool.c3`, `mailbox.c3`,
   `queue.c3`, `stack.c3`, `managed.c3`, `mtk.c3`
2. `test/` — 136 identifier sites, heaviest in `t_queue.c3` (37),
   `t_identity.c3` (25), `t_stack.c3` (22), `t_slot.c3` (20), plus the
   *item* prose in each
3. `negative/` and `examples/`
4. the books, last — they are the **bulk** of this stage, not a tail, because
   *item* is far denser in prose than in code:
   - `matryoshka-3tk/design/3tk-reference-007.md` → **008** — the largest
     single file in the stage: **167 *item***, 42 *handle*, 18 identifier
     sites. Its Participants block was rewritten around the word *handle* in
     3TK-59 and is rewritten again here.
   - `ref/3tk-api-003.md` → **`matryoshka-3tk/design/3tk-api-004.md`** — 79
     *item*, **56 *handle***, the densest *handle* file anywhere; it also
     changes repo here
   - `matryoshka-3tk/design/3tk-patterns-003.md` → **004**
   - `matryoshka-3tk/design/3tk-example-rules-003.md` → **004**
   - `ref/3tk-decisions-005.md` → **`matryoshka-3tk/design/3tk-decisions-006.md`**,
     carrying the two-term ruling; it also changes repo here
   - superseded versions moved to the respective `backup/` with plain `mv`

**Lesson carried from 3TK-59:** a mechanical pass that skips `<* … *>` blocks
still breaks two classes of site — compiled `@require` contracts that live
*inside* doc comments (`helper.c3:143`), and fenced `c3` snippets in module
blocks that the reference mirrors verbatim (`pool.c3`). Every hit gets looked
at; no pass is trusted on its own output.

### Verification

- `run-builds.sh` returns **identical** numbers to 3TK-59: 87 checks, 0
  failures, four builds green, 140 tests each. A change with no semantics must
  move nothing.
- `check-doc-loop.sh` with `REF` pointed at reference **008**: the one
  pre-existing `managed.c3` `DIFFERS` block and the two pre-existing missing
  sentences may persist (they are 3TK-61's to close), and **0 banned words**.
- `grep -rEw 'to_handle|from_handle|must_from_handle' 3tk/` returns 0.
- `grep -riw handle 3tk/src` returns 0 in every `.c3` file, and so does
  `grep -riwE 'item|items' 3tk/src` apart from any site the owner ruled to keep.

---

## 3TK-61 — managed

**Discussion first, producing a decisions entry, before any `src/` change.**
The `src/` change lands in the same stage if it is small; if it turns out
structural it becomes a **62**. That cannot be sized yet, so no number is
pre-allocated.

Inputs: the two open items recorded by 3TK-60, plus the issues the owner has
not yet enumerated. It also happens to be where the standing doc-loop
`DIFFERS` gap lives (`managed.c3:5`, "Optional convenience API, not Matryoshka
core.", absent from the reference's `mtk::managed` block) — so it closes that
and one of the two missing sentences as a side effect.

---

## Versions written, and what moves to backup

**The plan itself.** This becomes
`design/secondary/lang/c3/3tk-staging-plan-024.md`. `023` is fully spent —
3TK-59 ran and closed on 2026-09-04 — so it moves to
`design/secondary/lang/c3/backup/`, joining `019` through `022`. Plain `mv`,
same as every prior plan.

**Written new by 3TK-60 — all of them under `matryoshka-3tk/design/`.** Owner's
ruling: every new document goes there, including the two whose current versions
live in `c3/ref/`. `ref/` stops taking new versions.

| new — all in `matryoshka-3tk/design/` | supersedes | superseded copy moves to |
|---|---|---|
| `3tk-terms-001.md` | — (new) | — |
| `3tk-reference-008.md` | `007`, same folder | `matryoshka-3tk/design/backup/` |
| `3tk-patterns-004.md` | `003`, same folder | `matryoshka-3tk/design/backup/` |
| `3tk-example-rules-004.md` | `003`, same folder | `matryoshka-3tk/design/backup/` |
| `3tk-api-004.md` | `ref/3tk-api-003.md` | `c3/backup/` |
| `3tk-decisions-006.md` | `ref/3tk-decisions-005.md` | `c3/backup/` |

The last two **cross repos**: the old version leaves `c3/ref/` for `c3/backup/`
and the new one is written in `matryoshka-3tk/design/`. The stray
`ref/3tk-api-002.md` goes to `c3/backup/` in the same move, leaving `ref/` with
only `3tk-doc-loop-004.md`.

Cross-references into the moved files are repointed in the same step — the
known citers are `ref/3tk-doc-loop-004.md`, `3tk-open-defects.md`,
`3tk-status.md`, and the books' own links.

**Edited in place, not versioned:** `3tk-status.md` (state) and `3tk-log.md`
(append-only, newest first, the 3TK-60 entry prepended). Every `.c3` file in
`3tk/src`, `test`, `negative`, `examples` is edited in place — sources are not
versioned.

**Not moved by this stage:** `3tk-terms-001.md` stays live through 3TK-61,
which reads its open managed items. It goes to
`matryoshka-3tk/design/backup/` only once its content has dissolved into the
code and the books — that is 3TK-61's closing act, not 3TK-60's.

**One consequence worth naming:** after this stage the api and decisions
documents live in a different repo than they did, so anything that cited them
by the `ref/` path is stale. The repointing above is not optional tidying — it
is part of the step that moves them.

---

## Standing constraints

- **Git is disabled.** No stage runs `git`. Moves are plain `mv`; the owner
  saves.
- **3tk sources are edited in `matryoshka-tk` only.** The owner copies to
  `matryoshka-3tk`. Design docs under `matryoshka-3tk/design/` are the one
  place edited directly.
- `3tk-log.md` is **append-only**, newest first.
- The banned-word scan skips `design/STATUS-LOG.md`, `design/secondary/` and
  `kitchen/defer/`; hits are reported, not fixed without approval.

---

## Owner rulings already given

1. **Two terms, no third.** `Inner` is a type, `Outer` is a role. *Handle* goes
   from the source and from the books — 3TK-59 kept it as a word; that is now
   superseded.
2. **The terms document is `matryoshka-3tk/design/3tk-terms-001.md`** — short,
   versioned, single-subject, spent to `backup/` when its content has dissolved
   into the code and the books.
3. **The word *item* does not survive** — it becomes outer / Outer / Outers, in
   parameter names and in prose alike.

4. **There is no third thing, so the sweep is unconditional.** A mailbox
   message *is* an Outer. A pool entry *is* an Outer. *item* was never naming
   something other than an Outer; it was the old word for one. Every site
   changes, and none is set aside for a ruling.

## The statement the books must make

3TK-60 is not only a rename. The model is currently left for the reader to
infer from offset arithmetic, and it must instead be said outright:

> **You send and receive your own struct.** To get that, you give the
> infrastructure one thing: an `Inner` embedded in it. From then on the
> infrastructure never sees your type — it moves `Inner*`, intrusively and
> type-erased. You get your struct back by crossing once, from `Inner*` to
> `Outer*`, and the identity in the `Inner` is what makes that crossing safe.

This is why there are exactly two terms: **the one you own (Outer)** and **the
one you lend to the infrastructure (Inner)**. It is also why the crossing
helpers are the only place the two meet.

The statement opens `3tk-terms-001.md`, and three places are rewritten to say
it plainly rather than imply it: the reference's **Participants** block, the
**`mtk::helper`** module block, and the **`mtk::inner`** module block.
