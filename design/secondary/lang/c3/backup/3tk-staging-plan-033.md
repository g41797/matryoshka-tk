# 3tk — staging plan 033

Written 2026-09-09.

**Provenance.** Follows [3tk-staging-plan-032.md](backup/3tk-staging-plan-032.md),
which follows `031`, `030`, `029`, `028`, `027` and `026`. **Those earlier ones
are named, not linked as sources: `backup/` is transient — the owner empties it
— and it is never cited as a source of truth.**

**`031` and `032` are both spent.** `3TK-70` and `3TK-71` were their only stages
and both closed on 2026-09-09. **Only `3TK-50` remains from any earlier plan,
and it waits on the owner.**

State is in [3tk-status.md](3tk-status.md). Narrative is in
[3tk-log.md](3tk-log.md).

**The rules every stage is written against are in
[matryoshka-3tk/design/3tk-rules-004.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-rules-004.md)**
— two parts, the port rules and the stage rules. This plan cites that file; it
does not re-argue it.

---

## Why this plan exists

**The catalog has a structure and the docs site does not show it.**

`3tk/examples/` is 52 pattern files. Each declares a flat module of its own —
`module shc::transfer_empties_slot;` — beside `outers.c3`, `helpers.c3` and
`shc.c3`. **`c3c docgen` groups by module and by nothing else**, so what the
site shows is 52 sibling pages in alphabetical order: `available_only` next to
`close_recovery` next to `defer_put_early`. A reader who arrives at one of them
learns nothing about which patterns belong with it.

The structure already exists and is written down. It is the `## ` headings of
[3tk-patterns-004.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-patterns-004.md)
— *Slot and transfer idioms*, *Crossing the border*, *Dispatch*, *The
infrastructure is an outer too*, *Mailbox patterns*, *Topology patterns*, *Pool
patterns*, *Shutdown*, *Coordinator patterns*, *New, and 3tk-only*. **The
filenames already carry it too**, in the number that correlates each file with
its catalog row.

**This stage carries that structure into the module names, and nothing else.**
No file moves, no code moves, **no `src/` line is written.**

---

## What the sitting of 2026-09-09 ruled

Written as ids. **A later stage cites an id; it does not re-argue the point.**

### G-1 — a group is a module segment in the middle

An example's module gains one segment:

```
module shc::transfer_empties_slot;   ->   module shc::a_slot_and_transfer::transfer_empties_slot;
```

**The file is not moved and its code is not touched.** The `module` line is the
change, one line per file.

### G-2 — numbers live only in filenames

`003-transfer_empties_slot.c3` keeps its number. The number is what correlates
the file with its row in the catalog, and that is the whole of its job.
**A real module segment carries no number** — not the group's, not the leaf's.

### G-3 — only the group segment takes a letter prefix

A C3 module segment cannot start with a digit, and the eleven groups need to
appear on the docs page in catalog order rather than alphabetically. So the
group segment carries a letter: `a_`, `b_`, `c_` … in catalog order.

**The leaf keeps the plain name it already has.** `transfer_empties_slot` is
`transfer_empties_slot`. Ruled against prefixing the leaves as well: the number
is in the filename by `G-2`, and a reader who wants catalog order within a group
has the file list.

### G-4 — a group has a file of its own

Each group gets a new file `<group>.c3` in `examples/`, holding a `<* *>` block
with the group's description and then `module shc::<group>;`. **It declares
nothing.**

It is the group's doc carrier, and it is also what keeps the one-block-per-module
rule intact: **every example remains the sole carrier of its own leaf module's
block**, and the group's block sits in a file that carries nothing else. That is
the collision `3TK-63` met in `src/`, avoided by construction rather than by
care.

### G-5 — eleven groups, not the catalog's ten

The cleanup family — **5** null-safe cleanup, **6** defer-put-early, **7**
defer-release-early, **8** defer for a received outer, **9** fallback release
after a refused put, **10** no raw allocator call — leaves *Slot and transfer
idioms* and becomes a group of its own, `b_cleanup`.

The reason is that the catalog's first section is two subjects: three files of
Slot mechanics and six of cleanup. **The reference book already separates them**
— `3tk-reference-009.md` Part 6 has *Cleanup patterns* as a heading beside *The
Slot rule*.

**This is a change to the grouping, not to the catalog.** `3tk-patterns-004.md`
is not rewritten and does not gain an eleventh section.

### G-6 — the infrastructure stays at the top level

`outers.c3`, `helpers.c3` and `shc.c3` keep `module shc::outers;`,
`module shc::helpers;` and `module shc;`. **They are infrastructure, not
examples**, and they are imported by nearly every file in the tree.

### G-7 — `test/t_examples.c3` is probe-then-collapse

That file carries **52 leaf imports**, one per example, and it is edited in
lockstep with `examples/` every time a file is added.

C3 imports a module's submodules along with it — that is why `import mtk;`
still gives `InnerQueue` unqualified after `mtk::queue` split off. **If that
holds two levels deep, all 52 lines collapse to a single `import shc;`.**

**The answer is not assumed.** The probe runs after the exemplar group and
before the sweep, and **its result is recorded in the log either way**. If it is
no, the 52 lines are rewritten explicitly with their group segment, grouped
under a `//` comment per group.

### G-8 — the figures must not move, and that is the proof

No test is added or removed. `src/` is not touched. **107 checks, four builds,
145 tests each, doc loop 11 blocks and 443 of 443.** A moved number is a defect
of the sweep, not a result of it.

### G-9 — the stage decides, and does not come back

**The group names, the letter order and the eleven group descriptions are the
stage's to write.** `G-5` settled the one grouping question that was the
owner's. The rest is naming, and the stage has the catalog in front of it.

**The stage does not halt to ask.** Where a rule turns out under-specified,
Rule 11 governs — fix the definition in the stage and record what was fixed.
**Every decision taken under this id is named in the log entry.**

---

## The eleven groups

| group module | catalog section | entries | example files |
|---|---|---|---|
| `shc::a_slot_and_transfer` | Slot and transfer idioms | 1, 3, 4 | 001, 003, 004 |
| `shc::b_cleanup` | split out per `G-5` | 5–10 | 005, 006, 007, 008, 009, 010 |
| `shc::c_crossing` | Crossing the border | 11–16 | 011, 012, 013, 015, 016 |
| `shc::d_dispatch` | Dispatch | 17–22 | 017, 018, 019, 020 |
| `shc::e_infrastructure` | The infrastructure is an outer too | 23–26 | 023, 024, 025, 026 |
| `shc::f_mailbox` | Mailbox patterns | 27–32 | 027, 028, 029, 030, 031, 032 |
| `shc::g_topology` | Topology patterns | 33–36 | 033, 034, 035, 036 |
| `shc::h_pool` | Pool patterns | 37–45 | 037, 038, 039, 040, 042, 045 |
| `shc::i_shutdown` | Shutdown | 46–48 | 046 |
| `shc::j_coordinator` | Coordinator patterns | 49–56 | 049, 050, 051, 052, 053 |
| `shc::k_new_in_3tk` | New, and 3tk-only | 57–62 | 057, 058, 059, 060, 061 |

**52 example files.** A catalog entry with no code shape has no file and needs no
place here.

---

## The stage

| stage | what it does | model |
|---|---|---|
| **3TK-72** | **The example groups.** Eleven group modules, each with a carrier file of its own; 52 `module` lines gain a group segment; `test/t_examples.c3`'s import block collapses or is rewritten, on the probe. Then `3tk-example-rules-004.md` gains the rule. | **Opus 5** |

**Why Opus 5.** Rule 8's basis is how much of the stage is *deciding* rather
than *applying*. The 52 `module` lines are pure application, but **eleven group
descriptions have to be written rather than copied**, the probe of `G-7` changes
what step 4 is, and the module-doc carrier rule has already bitten twice in
`src/`. A mechanical sweep would produce eleven empty files and a broken import
block.

### Steps

**1. The exemplar comes before the sweep** — Rule 9. Group
`a_slot_and_transfer`: write `examples/a_slot_and_transfer.c3`, rewrite the
`module` line of `001`, `003` and `004`, correct those three imports in
`test/t_examples.c3`. Build. **This settles the carrier-file shape and the
description wording that the other ten copy.**

**2. The probe** — `G-7`. Replace the three rewritten leaf imports with a single
`import shc;` and build. **It decides step 4 and is logged either way.**

**3. The ten remaining groups.** Each: write `<group>.c3`, rewrite its examples'
`module` lines.

**4. `test/t_examples.c3`.** Probe yes → the 52 leaf imports become
`import shc;`; `import mtk;`, `mtk::mailbox`, `mtk::pool`, `shc::outers` and
`std::core::mem::alloc` stay. Probe no → all 52 gain their group segment,
grouped under a `//` comment per group in `a_` … `k_` order. **Either way its
`<* *>` block, which names nine catalog sections today, becomes the eleven
groups.** It stays `module mtk_test;` — it is a test, not an example.

**5. The two imports between example files.** `019-dispatch_switch.c3` and
`020-dispatch_table.c3` import `shc::dispatch_outer_first` and
`shc::dispatch_identity_first`; both targets are in `d_dispatch`. **These are
the only imports between example files** — measured, not assumed.

**6. `examples/shc.c3`'s own block.** It lists the catalog themes in prose;
rewrite as the eleven groups, and state that a group is a submodule with a
carrier file of its own.

**7. `3tk-example-rules-004.md`.** It gains the rule: an example declares
`module shc::<group>::<name>;`, and a new group gets a carrier file. **Versioned
as `005` if the change exceeds a sentence, edited in place if not** — the
stage's call. Written directly in `matryoshka-3tk/design/`; **ask the owner
before creating a file there.**

**8. Close.** `run-builds.sh`, `check-doc-loop.sh`,
`move-module-docs.sh roundtrip`, `run-sanitizers.sh`, the generated docs page
read by eye, the `matryoshka-3tk/scripts/` diff and the `.yml` review (Rule 10 —
**"none needed" is an answer that must be written into the log**). Then the log
entry and this file's row in the status.

**`run-builds.sh` is expected to need nothing.** It names `examples/` by
**filename** only — the `ALLOWED=` pair and the layering `grep` beside it — and
`G-2` keeps every filename. **Verify it; do not assume it.**

---

## What this plan does not do

- **It does not touch `src/`.** No production line moves, so the doc loop must
  read identically. `examples/` is outside the doc loop entirely.
- **It does not add or remove a test** — `G-8`.
- **It does not rewrite `3tk-patterns-004.md`** — `G-5`. The catalog keeps its
  ten sections.
- **It does not add a group page to `3tk-reference-009.md` Part 7**, which
  documents `mtk`'s own modules. `shc::` is not the library.
- **It does not rename a file** — `G-2`.
