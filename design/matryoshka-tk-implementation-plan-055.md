# Matryoshka Zig — Implementation Plan (055)

Change from -054: WEB 1 ledger line.

## Status

192/192 tests across Debug, ReleaseSafe, ReleaseFast and ReleaseSmall.  
Cross-compile to x86_64-windows clean. `mkdocs build --strict` clean.

Last completed stage: WEB 1, 2026-08-02. The last seven stages changed nothing  
in `src/` — they document what the existing blocks already do.

---

## Completed stages

One line each. Full account: `STATUS-LOG.md`, by date.

- Stage 0 — infrastructure. DONE.
- Stage 0.5 — scenarios re-partitioned into tests + examples. DONE.
- Stage 1.a/1.b — PolyNode impl + tests, then examples. DONE.
- Stage 2.a/2.b/2.5 — Mailbox impl + tests, examples, pre-Stage-3 fixes. DONE.
- Stage 3 — Pool impl + tests + examples. DONE.
- Stage 4 — DONE (97/97).
- Stage 5.a/5.b — DONE (107/107).
- INTR 1 — DONE (107/107).
- Stage 6 — DONE (121/121).
- INTR 2 — DONE (121/121).
- Stage 7.a — `receiveResult`/`receive_future`/`getWaitResult`/`get_wait_future`. DONE (121/121).
- INTR 3 — ASCII ownership diagrams in all 29 examples. DONE (121/121).
- Stage 7.b — 22 new example files + test wrappers. DONE (143/143).
- INTR 4 — bug fixes + doc corrections. DONE (145/145).
- Stage 8 — 15 examples: cross-layer 32-41, mailbox-less 57-61. DONE (160/160).
- INTR 5 — stories infrastructure + doc quality overhaul. DONE (161/161).
- STORY 1, STORY 2, Story Rhythm — video-transcoder and print-server narratives. DONE.
- EXMPL 1-3e — example completeness audit, Master pattern, NNN- renaming, Observable-by-human rule and its structural signals. DONE.
- API 2 — PolyHelper Slot-aware identification API. DONE (161/161).
- API 3 — `mailbox.wakeUpAll()`. DONE (167/167).
- API 4/4b — `NodeHandle` → `ItemHandle`, propagated to kitchen docs. DONE (167/167).
- EXMPL 4/4b/4c — description as code, descriptive entry-point names, `drain` eliminated. DONE.
- Stage 9 — Layer 4 infrastructure: pool, mailbox, select, group. DONE.
- DOC 1-8 — tofu audit, kitchen doc infra, site skeleton, first Concepts story, Tools topics. DONE.
- DOC 9/10 — API reference re-partitioned then dependency-ordered. DONE (167/167).
- DOC 11/12 — manifesto written, then de-smarted to plain language. DONE.
- DOC 13/14 — unified pattern catalog, then 7 entries from the Odin-docs audit. DONE.
- DOC 15/16/16b — `///`/`//!` comments across `src/`, then two polish passes. DONE.
- DOC 17/17b/17c — snake_case entry points, file-level `//!`, fenced diagrams. DONE.
- DOC 18/18b/18c — API reference humanized; autodoc container-page bug root-caused via headless Chrome, fixed with a `_doc_stub` first declaration. DONE.
- DOC 19 — generated site moved from `kitchen/output/` to root `docs/`. DONE.
- INTR 6 — standalone `helpers/` split into `examples/items|hooks|helpers`. DONE (167/167).
- DOC 20 + follow-up — example autodoc targets replaced by `gen_examples_docs.sh`; the 76 mirrored pages added to `mkdocs.yml` nav, plus a nav-sync rule. DONE.
- DOC 21 — "The Shape of a Real System" page + Graphviz diagram tooling. DONE.
- INTR 7 — pool `on_put` reset convention, "Pool is not storage" fix, `put` semantics documented, 5 wrong-assumption bugs fixed. DONE.
- Staccato scan + "thread" audit — prose-paragraph and stale thread-join language fixed repo-wide. DONE (167/167).
- New Mindset — banned words, `Thread.spawn` → `io.concurrent()`, terminology pass. DONE.
- LANDING 1 — `src/` LOC counter + badge on the docs index. DONE.
- REBRAND — repo renamed to matryoshka-tk, deferred items verified. DONE 2026-07-24 (167/167).
- MDFIX — markdown hard-break rule + `kitchen/tools/fix_md_hardbreaks.sh`. DONE.
- API 5a-5d + follow-up — Composite Items: `PoolHooks.on_put` returns `?std.DoublyLinkedList`; scenario 89; a `popFirst` stale-link bug found and fixed. DONE 2026-07-25 (168/168).
- EXMPL 5a-5e — receive router: design note, example + test, pattern docs, catalog and nav, `cancelDiscard` audit over 15 sites with no defects. DONE 2026-07-27 (169/169). Design: [receive-router-001.md](receive-router-001.md).
- API 6 — `identifyNodeAs`/`identifySlotAs` → `fromNode`/`fromSlot` (+ `must`), new `moveFromSlot`, ~222 call sites. DONE 2026-07-28 (170/170).
- API 7a-7d — `toNode`, the outbound accessor; three `src/` hand-rolls self-hosted; `src/polynode.zig` doc comments fixed. DONE 2026-07-29 (171/171).
- API 7e — closed as superseded: `ItemList.append` takes an `ItemHandle`, so the sites `toListNode` targeted are gone. See [item-list-009.md](item-list-009.md) Q22.
- API 8a-8d — `ItemList` closes the `std.DoublyLinkedList` boundary; five public signatures moved; `popFirst` turns the reset trap into a type guarantee. DONE 2026-07-29 (175/175). Design: [item-list-009.md](item-list-009.md).
- API 9 — intrusive safety: `appendFromSlot`/`prependFromSlot`, `tests/layer1_itemlist.zig`, the `_holds` walk, `concat` self-check. Misuse cases 1 and 5 stay open by decision (Q26 = D). DONE 2026-07-30 (177/177).
- API 10 — `ItemList` completion: `remove`, `popLast`, `first`, `last`, `insertBefore`; `iterate` → `iterator`; `concat` self-concat leak fixed. DONE 2026-07-31 (182/182).
- API 11 — `fromNode`/`mustFromNode`/`toNode` → `fromPoly`/`mustFromPoly`/`toPoly`, 164 call sites. Slot accessors keep their names. DONE 2026-07-31 (182/182).
- DISPATCH 1 — tag-first dispatch documented; `switch (tag)` proven not to compile, recorded in [llvm-pointer-switch-bug-001.md](secondary/llvm-pointer-switch-bug-001.md) with a repro and a build matrix. DONE 2026-07-31 (185/185).
- DISPATCH 2 — table dispatch documented; the handler belongs to the pair (receiver, tag), so the choice moves into data. `examples/helpers/TagTable.zig`, scenarios 113-117. No `src/` change. DONE 2026-07-31 (192/192). Working doc: [table-dispatch-001.md](table-dispatch-001.md).
- CMPCT 1 — STATUS/plan/log/context de-duplicated; rules-038 "Status file ownership". DONE 2026-08-01 (192/192, doc-only).
- CMPCT 2 — rules regrouped into rules-039.md: gates first, one topic in one place, dated rationale moved to the log, six stale links fixed. No rule changed meaning. DONE 2026-08-01 (192/192, doc-only).
- DOC 22 — `design/` compacted to the current picture. Five concept docs merged into [matryoshka-concepts-001.md](matryoshka-concepts-001.md); nine files moved to `design/secondary/` (frozen, indexed by its own `context.md`); eight deleted; `context.md` rewritten; every dead cross-reference repaired. New in [rules-041.md](rules-041.md): where a doc lives, present tense in `design/`, story file layout. DONE 2026-08-02 (192/192, doc-only).
- DOC 23 — the two large docs split by audience. `matryoshka-tk-0.16-implementation-guide-001.md` retired: its Odin idiom mapping to [secondary/odin-to-zig-backport-001.md](secondary/odin-to-zig-backport-001.md), its still-binding material to [matryoshka-zig-0.16-notes-002.md](matryoshka-zig-0.16-notes-002.md), its walkthroughs of shipped code deleted with owner approval. [matryoshka-architecture-foundation-4-005.md](matryoshka-architecture-foundation-4-005.md) drops the four sections `matryoshka-concepts-001.md` already owns and renames `MayItem` to `Slot`. New gate `kitchen/tools/check_design.sh`. DONE 2026-08-02 (192/192, doc-only).
- WEB 1 — the landing page reaches the API docs. `kitchen/docs/index.md`: the `XYZ Lines Of Code` badge is now the link to `apidocs/`, opening in a new tab; the API button above it, hidden by CSS since it was added, is deleted. `kitchen/docs/stylesheets/extra.css`: the badge gains link styling and a per-scheme hover, and the button styling it made dead — `.hero-button`, both `-primary` and `-secondary` scheme pairs, the `display: none` rule, the unused `.hero-buttons` selector — is removed. DONE 2026-08-02 (doc-only, no `src/` change).

CANDIDATES was dropped, owner's decision. It carried from plan-043 through  
plan-046 without starting, and `design/candidates/` does not exist on disk.

---

## Next

No stage is chosen. Deferred below is the candidate pool.

---

## Deferred — owner's call on order

- Diagram-notation scan.
- Mailbox-focused equivalent of the INTR 7 pool audit.
- Showcase-post variants (Ziggit, Discord, Reddit).
- Editorial/conceptual prose pass from REBRAND (README intro, manifesto).
- DISPATCH 1: run the repro matrix on zig 0.15.2, get a real 0.17.0-dev
  diagnostic, file the bug upstream to ziglang/zig.
- API 8a Q25's protection list, answered "postpone decision". The migration ran
  with the three proposed protections applied as written. Worth a look before  
  the next stage that touches list code.

---

## Reported, not actioned

- `Io.Select.awaitMany` is used and documented nowhere in the repo. It is
  the natural pair for any batch-receive work.
- `src/pool.zig` carries an uncommitted owner edit made before API 6
  (`get_wait` doc comment now states "does not call on_get hook").
- **Closed by DOC 23.** The stale `helpers/`-path references reported outside
  INTR 6's scope are gone. Re-checked 2026-08-02: the only `helpers/` mentions  
  left under `kitchen/docs/` are `@import` lines inside generated example  
  pages, which are correct. The `design/` side was closed by DOC 22.
- **Closed by the 2026-07-30 banned-word pass.** The `patterns-017` section
  titles carried from `-016`/`-015` are reworded in `patterns-025.md`, and the  
  `022-ownership_transfer.zig` `//!` title and entry-point name are reworded  
  too. The **filename** still carries the word — owner's decision, since  
  renaming trips the examples-catalog nav-sync rule.
- Working tree carries uncommitted owner edits to `README.md` and
  `design/secondary/mtk-readme.md`, a deleted SPDX header in  
  `src/internal/cond_timeout.zig`, and a deleted  
  `design/stories/photo-archive-pipeline.png` alongside two untracked  
  `-001.png`/`-002.png`. Left alone. The story narrative references no image.
