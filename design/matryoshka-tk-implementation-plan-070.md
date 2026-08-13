# Matryoshka Zig — Implementation Plan (070)

Change from -069: API 13-4a and 13-4b-1 done. `src/` reads as prose, the custody  
wording is reworded there and in the documents that contradicted it, and the  
module headers are modelled on `std.Io`'s. 13-4b-2 and 13-4b-3 carry the rest of  
the document pass. "The book governs" stays 13-5.

**Reconstructed 2026-08-12.** Versions -056 through -059 were lost: the agent  
deleted -059 while the command meant to create -060 had already failed, and  
-058 had never been committed. Rebuilt from -055 in HEAD, which carries the  
stage list through WEB 1 verbatim, plus `STATUS-LOG.md` for everything after it.  
Summary lines for the stages between WEB 1 and API 12-1 are written from the  
log, not the originals. Everything from API 12-1 on is exact.

## Status

Current state lives in [STATUS.md](STATUS.md), not here. This file carries
forward-looking work and one line per completed stage.

Version note: `-070` is kept rather than superseded. It was created for API 13-4
and no stage has completed since; the edits after its creation are that stage's
own close-out corrections. `-069` was deleted against Part 0 and is unrecoverable
— see STATUS-LOG.md, 2026-08-13, and Open Item 14 in STATUS.md.

Last completed stage: API 13-4b-1, 2026-08-13 — close-out incomplete.
`build_and_test_all.sh` and `build_cross_debug.sh` have not been run since
API 13-3, so the four-mode and cross-compile claims are unverified.

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
- EXMPL 5a-5e — receive router: design note, example + test, pattern docs, catalog and nav, `cancelDiscard` audit over 15 sites with no defects. DONE 2026-07-27 (169/169). Design: [receive-router-002.md](receive-router-002.md).
- API 6 — `identifyNodeAs`/`identifySlotAs` → `fromNode`/`fromSlot` (+ `must`), new `moveFromSlot`, ~222 call sites. DONE 2026-07-28 (170/170).
- API 7a-7d — `toNode`, the outbound accessor; three `src/` hand-rolls self-hosted; `src/polynode.zig` doc comments fixed. DONE 2026-07-29 (171/171).
- API 7e — closed as superseded: `ItemList.append` takes an `ItemHandle`, so the sites `toListNode` targeted are gone. See [item-list-011.md](item-list-011.md) Q22.
- API 8a-8d — `ItemList` closes the `std.DoublyLinkedList` boundary; five public signatures moved; `popFirst` turns the reset trap into a type guarantee. DONE 2026-07-29 (175/175). Design: [item-list-011.md](item-list-011.md).
- API 9 — intrusive safety: `appendFromSlot`/`prependFromSlot`, `tests/layer1_itemlist.zig`, the `_holds` walk, `concat` self-check. Misuse cases 1 and 5 stay open by decision (Q26 = D). DONE 2026-07-30 (177/177).
- API 10 — `ItemList` completion: `remove`, `popLast`, `first`, `last`, `insertBefore`; `iterate` → `iterator`; `concat` self-concat leak fixed. DONE 2026-07-31 (182/182).
- API 11 — `fromNode`/`mustFromNode`/`toNode` → `fromPoly`/`mustFromPoly`/`toPoly`, 164 call sites. Slot accessors keep their names. DONE 2026-07-31 (182/182).
- DISPATCH 1 — tag-first dispatch documented; `switch (tag)` proven not to compile, recorded in [llvm-pointer-switch-bug-001.md](secondary/llvm-pointer-switch-bug-001.md) with a repro and a build matrix. DONE 2026-07-31 (185/185).
- DISPATCH 2 — table dispatch documented; the handler belongs to the pair (receiver, tag), so the choice moves into data. `examples/helpers/TagTable.zig`, scenarios 113-117. No `src/` change. DONE 2026-07-31 (192/192). Working doc: [table-dispatch-002.md](table-dispatch-002.md).
- CMPCT 1 — STATUS/plan/log/context de-duplicated; rules-038 "Status file ownership". DONE 2026-08-01 (192/192, doc-only).
- CMPCT 2 — rules regrouped into rules-039.md: gates first, one topic in one place, dated rationale moved to the log, six stale links fixed. No rule changed meaning. DONE 2026-08-01 (192/192, doc-only).
- DOC 22 — `design/` compacted to the current picture. Five concept docs merged into [matryoshka-concepts-002.md](matryoshka-concepts-002.md); nine files moved to `design/secondary/` (frozen, indexed by its own `context.md`); eight deleted; `context.md` rewritten; every dead cross-reference repaired. New in [rules-047.md](rules-047.md): where a doc lives, present tense in `design/`, story file layout. DONE 2026-08-02 (192/192, doc-only).
- DOC 23 — the two large docs split by audience. `matryoshka-tk-0.16-implementation-guide-001.md` retired: its Odin idiom mapping to [secondary/odin-to-zig-backport-001.md](secondary/odin-to-zig-backport-001.md), its still-binding material to [matryoshka-zig-0.16-notes-003.md](matryoshka-zig-0.16-notes-003.md), its walkthroughs of shipped code deleted with owner approval. [matryoshka-architecture-foundation-4-006.md](matryoshka-architecture-foundation-4-006.md) drops the four sections `matryoshka-concepts-002.md` already owns and renames `MayItem` to `Slot`. New gate `kitchen/tools/check_design.sh`. DONE 2026-08-02 (192/192, doc-only).
- WEB 1 — the landing page reaches the API docs. `kitchen/docs/index.md`: the `XYZ Lines Of Code` badge is now the link to `apidocs/`, opening in a new tab; the API button above it, hidden by CSS since it was added, is deleted. `kitchen/docs/stylesheets/extra.css`: the badge gains link styling and a per-scheme hover, and the button styling it made dead — `.hero-button`, both `-primary` and `-secondary` scheme pairs, the `display: none` rule, the unused `.hero-buttons` selector — is removed. DONE 2026-08-02 (doc-only, no `src/` change).

- Errors as type IDs — owner's proposal tested and rejected. `@intFromError`
  is a real comptime `u16` and does work in a `switch`, so the DISPATCH 1 wall  
  is about pointers, not tags. Errors are interned by name globally with no  
  unique-name source, so the scheme cannot be made safe. Written down as
  [secondary/error-as-type-id-001.md](secondary/error-as-type-id-001.md).
  DONE 2026-08-02 (no `src/` change).
- API 12 chosen and designed — real pointers for Mbox/Pool. `_Mailbox`/`_Pool`
  become public `Mbox`/`Pool`, flattened onto `matryoshka.*`, hard break with  
  no alias, both keeping an embedded `PolyNode` so they still travel as  
  payload. Design: [api-12-real-pointers-005.md](api-12-real-pointers-005.md).  
  DONE 2026-08-12 (design only).
- API 12-1 — `src/` rewrite to real pointers. `Mbox`/`Pool` public, handles and
  PolyHelper aliases gone, methods on the pointer, companion types nested,  
  `Io.ConcurrentError` in place of two local copies. New `zig build core` step
  + `kitchen/build_core_debug.sh`. DONE 2026-08-12 (core green; 72 old call
  sites left for 12-2/12-3).
- API 12-2 — `tests/` moved to the pointer API. Five files, about 550 call
  sites. Scenarios 93 and 94 in `layer4_infra.zig` were the only  
  non-mechanical part: a pointer is no longer a `Slot`, so they cross the  
  border explicitly. Stories moved onto their own `zig build stories` step.  
  Scenario lists resynced as [task1-tests-007.md](task1-tests-007.md) and
  [task2-tests-003.md](task2-tests-003.md). DONE 2026-08-12 (120/120 with the
  example wrappers held out).
- API 12-3 — `examples/` and the story moved to the pointer API. 63 files:
  11 in layer2, 4 in layer3, 48 in layer4, plus `video_transcoder.zig`. The  
  two transport examples, `095-mailbox_as_item.zig` and  
  `096-pool_as_item.zig`, were the only non-mechanical work. Doc comments  
  swept including ASCII diagrams. DONE 2026-08-12 (191/191, release matrix and  
  cross builds green).
- API 12-4 — docs audit, the last sub-stage. `kitchen/docs/examples/**`
  regenerated from the migrated sources (88 pages). 34 hand-written site pages  
  swept, plus 11 design docs versioned up: api-reference -034, patterns -026,  
  item-list -010, zig-notes -003, receive-router -002, concepts -002,  
  table-dispatch -002, task1-tests -007, task2-examples -007,  
  print-server -003, video-transcoder -004. The two deferred write-ups,  
  Worker-finish-signal and Wrapper, rewritten around `Mbox.mustFromPoly`  
  rather than renamed. No code change. DONE 2026-08-12.
- TESTSYNC 1 — test names resynced with the scenario docs. 23 names in
  `tests/layer3_pool.zig` and `tests/layer4_cancel.zig` still read  
  `pool.get` / `mailbox.close`; they now match the pointer form the scenario  
  lists already used. Three had drifted in wording as well (74, 75, 77) and  
  were aligned to [task1-tests-007.md](task1-tests-007.md). Also fixed in the  
  same pass: 15 `std.log.info` strings in `examples/layer4/`, left over from  
  12-3's doc-comment sweep. DONE 2026-08-12 (191/191).

- MBOX 1 — the mailbox audit, the deferred twin of INTR 7. The framing the
  docs were missing: the mailbox keeps items, it never touches them — no  
  inspection, no copy, no free — so everything it keeps goes back to a caller,  
  and releasing  
  it is the caller's job. Written into `src/mailbox.zig`, the concept and api  
  pages, and the API reference, with the mirror statements for Pool (it does  
  touch items, through hooks; a closed pool gives them back; `close`  
  releases through `on_close`). Code: 32 `_ = mbx.close()` sites replaced by  
  an unconditional release, a refused `send` of a pool item in  
  `056-job_pool_circular.zig`, unchecked `put_all` leftovers in 034 and 040,  
  and four `mbh` names API 12 missed. Found and fixed on the way: 15  
  documented asserts that never existed in `src/`, and  
  `kitchen/docs/tools/pool.md` claiming `Pool.close` gives items back to the  
  caller when it passes them to `on_close`. Follow-up in the same session:  
  every item `tests/layer2_mailbox.zig` sends is now allocated, closing its  
  own violation of Part 8's "never send a stack-allocated item" — 33 sites,  
  no rule exemption needed. No `src/` behaviour change.  
  DONE 2026-08-12 (191/191). Rules: [rules-047.md](rules-047.md).

- AUDIT 1 — the give-back audit made repeatable. MBOX 1 and INTR 7 did the
  same kind of work a month apart and shared no method, so the method is now  
  written down instead of re-derived. `kitchen/tools/audit_edges.sh` +  
  `audit_edges.py`: classifies every give-back edge as  
  COVERED / CATCH-FREES / DISCARDED / BARE, and checks every documented  
  `Assert:` entry against the asserts in `src/`. Reports, never edits; exits 0  
  always, deliberately not a gate. [audit-recipe-002.md](audit-recipe-002.md)  
  carries what the script cannot: the edge table, the four verdicts and why  
  there is no fifth, the read-only-then-report ordering, and the post-MBOX-1  
  baseline to diff against. No change to `src/`, `tests/`, `examples/`,  
  `stories/` or `kitchen/docs/`. DONE 2026-08-12 (191/191, tooling + doc).

- **PROSE 1** — full banned-word and prose pass, plus the first check of Zig
  snippets inside docs. Scanned 294 live files against Part 5. The raw count  
  was ~500; the live count was ~20, the gap being `STATUS-LOG.md`,  
  `design/secondary/` and `kitchen/defer/`, none of which may be rewritten.  
  Fixed in place: the slot-based-programming addendum (11 hold-language  
  rewrites, two section titles), the manifesto, `kitchen/notes.md`, the  
  polynode manual-definition page, and `tests/layer1_polynode.zig`  
  (`dll_node` → `list_node`). Five design docs  
  bumped for real prose defects: api-reference, architecture, api-12,  
  diagram-style, rules. `kitchen/defer/` declared frozen, and Part 5 gained a  
  scan scope so the next run does not re-derive what is off-limits. 475 Zig  
  snippets in 129 doc pages checked: no `_ = mbx.close()` anywhere, seven  
  pre-API-12 lines confined to the now-frozen `kitchen/defer/`.  
  DONE 2026-08-12 (191/191).

- **FLOW 1-1 / 1-1r** — the canonical `Usual flow` text for a mailbox (four
  steps) and a pool (five, the extra one being `init`), in staccato.  
  DONE 2026-08-13 (191/191, doc-only).

- **API 13-1** — the api reference becomes a book. Seven parts from 22 flat
  `##` headings; Parts 3, 4 and 5 share one five-piece shape. New Part 1  
  (introduction) and Part 2 (intrusion, type erasure, `ParentHandle`), whose  
  snippets come from a new permanent test, `tests/zig_mechanisms.zig`. Every  
  snippet in Parts 2-5 is extracted from a file a kitchen script builds, and  
  names its source. Pool gains a `Hooks` section one level above Get and Put.  
  475 lines of manual definition and `PolyHelper` walkthrough replaced by  
  pointers to the two kitchen pages that already carry them; the complexity  
  table deleted; bare signature lists replaced by grouped signatures with  
  descriptions. The stale "this file is the source for `///` comments" note  
  and the dead `Addendums → Io 101` pointer both fixed. Part 6 groups  
  the eleven cross-tool sections into four, by the owner's ruling. Detail stays in  
  the book and is recorded in  
  [api-13-carryover-004.md](api-13-carryover-004.md) — 43 rows.  
  `ParentHandle` added to the glossary.  
  DONE 2026-08-13 (195/195).

CANDIDATES was dropped, owner's decision. It carried from plan-043 through  
plan-046 without starting, and `design/candidates/` does not exist on disk.

---

## Next

**No stage is authorized.** The owner names the next stage. What follows is a
menu with costs attached, not a queue, and no heading here is permission to
start.

Open first: the API 13-4 close-out. Six steps of the Part 0 finish checklist
were not run. Listed in [STATUS.md](STATUS.md) under Next.

Candidates: **13-4b-3** (the `design/` prose pass, heavy versioning tax),
**13-5 — the book governs**, and the **`polynode` audit**, which is a
correctness gap rather than polish. Recommendation on record favours the audit;
the owner has not ruled. Detail below, deferred pool further down.

---

## FLOW 1 — the usual flow of a mailbox and a pool

The gap FLOW 1 closed: every doc described the edges, none described the  
ordinary path. `new`, `init(hooks)`, `destroy` and close-before-destroy were  
documented only as hazards, or not at all.

- **FLOW 1-1** — the canonical text, written into the api reference.
  DONE 2026-08-12. Wording rejected by the owner on 2026-08-13.
- **FLOW 1-1r** — the same text in staccato, approved. DONE 2026-08-13.
  Every numbered step is a heading line with nested bullets under it.

The canonical text now lives in Parts 4 and 5 of
[matryoshka-api-reference-041.md](matryoshka-api-reference-041.md), carried
into the book unchanged by API 13-1.

**1-2 and 1-3 are postponed.** Owner's call, 2026-08-13. Their scope is below  
and unchanged.

Vocabulary, owner's ruling 2026-08-12: `lifecycle` is AI-sh, and the section is  
called **Usual flow** everywhere. `hands` and `holds` stay out of new text.

Superseded by the owner's ruling of 2026-08-13, in API 13-4: the custody sense of  
both words is reworded wherever it appears, and the MBOX 1 framing goes with it.  
`src/mailbox.zig` now reads "The mailbox keeps items. It never touches them."  
Scoped away from the Hold vocabulary in
[matryoshka-architecture-foundation-4-006.md](matryoshka-architecture-foundation-4-006.md),
which stays.

### FLOW 1-2 — propagate

Mechanical, once 1-1 is approved. Nothing here invents wording.

- `src/mailbox.zig` and `src/pool.zig` `//!` headers — a condensed Usual flow,
  roughly ten lines each, placed directly after the opening bullets and  
  before the edge rules. The ordinary path is read first by anyone who stops  
  after ten lines. Doc comments only, no behaviour change, so this stays  
  inside the report-only policy for `src/`.
- `kitchen/docs/api/mailbox/index.md` — new Usual flow section, the one it
  never had.
- `kitchen/docs/api/pool/index.md` — repair the existing diagram: add `init`
  and `destroy`, rename the heading to Usual flow.
- `kitchen/docs/tools/mailbox.md`, `kitchen/docs/tools/pool.md` — the reader-
  facing version, and the `hands` reword.

Kitchen pages are edited in place; they are not versioned.  
Gates: `build_and_test_debug.sh` 191/191, `check_design.sh`, `build_site.sh`.

### FLOW 1-3 — the whole picture

The page that does not exist anywhere: a mailbox and a pool in one  
application, and which one is the right choice for a given problem.

New page under `kitchen/docs/tools/`, plus a nav entry in `mkdocs.yml`.  
Scope it when 1-1 and 1-2 are done, not now.

### Out of scope

The pool re-audit, the `polynode` audit, and everything else on the deferred  
list. Renaming Layer 1 example 022 — still owner-only, still a `git mv`.

---

## API 13 — the reference becomes a book

Design note: [api-13-book-002.md](api-13-book-002.md). It carries the reason,  
the eight findings, the seven-part structure, the displacement table and the  
deliverables, with the owner's rulings on `-001` folded into the sections they  
govern.

The direction reversed. The reference was the source for `src/` doc comments;  
the code is working now, so the code takes the detail and the book keeps what a  
reader learning Matryoshka needs.

### API 13-1 — the restructure. DONE 2026-08-13

Summary in Completed stages. Verified with `check_design.sh` exit 0 and  
`build_and_test_debug.sh` 195/195.

### Part 6 — grouped, DONE 2026-08-13

The owner approved the four-section grouping: identity across the tools, the  
slot rule, concurrency and cancel, what the toolkit assumes. The eleven  
cross-tool sections dropped one heading level and moved into their group. No  
body text was rewritten. `build_and_test_debug.sh` 195/195.

### API 13-2 — the code takes the detail. DONE 2026-08-13

All 43 rows are `///` or `//!` comments in `src/polynode.zig`,  
`src/mailbox.zig` and `src/pool.zig`. Doc comments only, no behaviour change.  
Each of the four modules points at its own examples root plus `/examples/flow/`,  
roots only. No snippet in `src/`. `src/matryoshka.zig` lost its one banned word,  
and `polynode.zig`'s header says what the second helper variant omits instead of  
apologising for it. Three things the code did not back are in Section 5 of
[api-13-carryover-004.md](api-13-carryover-004.md). 195/195, docs target clean.

### API 13-3 — the book sheds the detail. DONE 2026-08-13

The book is now
[matryoshka-api-reference-041.md](matryoshka-api-reference-041.md), 2062 lines
down to 2022. The line it  
cut on: a precondition the caller satisfies stays, the assert mechanism goes.  
All nine `Assert:` blocks are gone. Also out: the two-checks-per-insert  
reasoning, the safety-build cost, the `concatByMoving` and header-consistency  
explanations, the `!is_linked` site list, the `in_pool_count` lock mechanics and  
the reentrancy reasoning. The `init` null-tag clause was deleted, not moved — no  
such assert exists. Kept against their row by the owner's ruling: the OOB  
diagram, the trimmed `popFirst` warning, and the two behavioural contracts.  
Parts 1, 2, 6 and 7 untouched.

### API 13-4 — the prose pass

**13-4a — `src/*.zig`. DONE 2026-08-13.** Three voice lines brought to the owner  
and all kept unchanged. Custody wording reworded across 29 sites, the MBOX 1  
statement with them. Six mailbox summary lines replaced, so the autodoc module  
page no longer shows six identical rows; "item" chosen over "handle". Headers  
modelled on `std.Io`'s — `mailbox.zig` 52 lines to 26, `pool.zig` 49 to 25, no  
`#` sections left, mostly by deleting what `close` and `destroy` already said.  
Thirteen multi-fact sentences split, and a set of render defects fixed.  
Autodocs regenerated; the rendered page was not viewed.

**13-4b-1 — the documents that contradicted `src/`. DONE 2026-08-13.** Six new  
versions, 11 kitchen pages, `STATUS.md` and `context.md` in place. The rules  
carve-out for the old mailbox statement retired. The carry-over note's finding  
discharged. Owner's ruling: the Hold vocabulary in
[matryoshka-architecture-foundation-4-006.md](matryoshka-architecture-foundation-4-006.md)
is out of scope — it replaced a banned family of words and names sections and the  
`HELD` state.

**Post-stage cleanup. DONE 2026-08-13.** Two comment-level fixes; three  
code-level findings reported, not actioned. See STATUS-LOG.md.

### 13-4b-2 — DROPPED 2026-08-13

Defined from symmetry with 13-4a, not from evidence. A scan of the 59
hand-maintained kitchen pages found one line over 180 characters
(`kitchen/docs/addendums/intrusion-type-erasure.md`) and one multi-fact sentence in a
generated page. Those pages were written in staccato and never accumulated the
prose `src/` did. The long line goes to 13-5.

### 13-4b-3 — the `design/` documents, prose

The versioning rule makes this the expensive half. Every doc touched needs a new  
suffixed version plus a link cascade, and a bulk repoint must name its files and  
exclude `STATUS-LOG.md`.

Two carried items, both the owner's:

- `handle` vs `item` in `mailbox.zig` body text. It runs 29 to 18 for `handle`
  while the rest of the repo runs 6:1 the other way. The summary lines already  
  say "item", so single comments now use both.
- `language-of-matryoshka.md` is unsuffixed, against "all docs require one". Its
  one custody-adjacent hit is mechanism sense. Left out of 13-4b-1 for both  
  reasons.

### API 13-5 — the book governs

### API 13-5 — the book governs, continued

- The book dictates the content of every other doc.
- Read the neighbours for material that belongs in the book:
  [matryoshka-concepts-002.md](matryoshka-concepts-002.md) and
  [patterns-028.md](patterns-028.md) overlap it most.
- Reconcile `kitchen/docs/api/pool/hooks-discipline.md`. The book's Hooks
  section states the same rules. Decide whether the page keeps its own text or  
  becomes a pointer.
- The carry-over note's "to remove later" section is discharged here or by an
  owner decision — the slogan register, and the banned word Section 3 of that  
  note counts.
- Move material in, move material out, record both.

---

## Deferred — owner's call on order

- Pool re-audit. `audit_edges.sh` reports 69 bare `pl.put(&slot)` statements —
  real give-back edges, unaudited, since INTR 7 predates this framing.
- `polynode` audit — the layer the other two stand on, never audited.
- Diagram-notation scan.
- Showcase-post variants (Ziggit, Discord, Reddit).
- Editorial/conceptual prose pass from REBRAND (README intro, manifesto).
- DISPATCH 1: run the repro matrix on zig 0.15.2, get a real 0.17.0-dev
  diagnostic, file the bug upstream to ziglang/zig.
- API 8a Q25's protection list, answered "postpone decision". The migration ran
  with the three proposed protections applied as written. Worth a look before  
  the next stage that touches list code.

---

## Reported, not actioned

- **From PROSE 1.** Layer 1 example 022 still carries a banned word in its
  file name, and the matching `pub const` in `examples/layer1/layer1.zig` and  
  the call in `tests/layer1_examples.zig` carry it with them. Renaming a file  
  is a `git mv` and cascades into the generated example page and the examples  
  index. Owner-only, and already on record there as unchanged by decision.
- **From PROSE 1.** `check_design.sh` glossary conformance rejects a changelog
  row that names a banned word, even one written to record that word's  
  removal. Older rows predate the gate and are grandfathered. Anything new  
  must describe the change without using the word.
- **From AUDIT 1.** The documented-assert check could be a hard gate in
  `check_design.sh`. It is report-only in `audit_edges.sh` today. Making it  
  block a stage is an owner decision and was not taken.
- **Closed by MBOX 1's follow-up.** The stack-frame items in
  `tests/layer2_mailbox.zig` are gone. Owner chose heap items over a rule  
  exemption, so Part 8 holds with no carve-out.
- **From MBOX 1.** The 101 `try mbx.send(&slot)` sites were left as they are.
  Each propagates `error.Closed` with the item still in the slot, and each is  
  covered today by a `defer` on the slot or by the mailbox being provably  
  open. Nothing to fix, but it is the shape that goes wrong first when an  
  example is copied into a real system.
- `Io.Select.awaitMany` is used and documented nowhere in the repo. It is
  the natural pair for any batch-receive work.
- `src/pool.zig` carries an uncommitted owner edit made before API 6
  (`get_wait` doc comment now states "does not call on_get hook").
- **Closed by DOC 23.** The stale `helpers/`-path references reported outside
  INTR 6's scope are gone. Re-checked 2026-08-02: the only `helpers/` mentions  
  left under `kitchen/docs/` are `@import` lines inside generated example  
  pages, which are correct. The `design/` side was closed by DOC 22.
- **Closed by the 2026-07-30 banned-word pass.** The `patterns-017` section
  titles carried from `-016`/`-015` are reworded in `patterns-028.md`, and the  
  `022-ownership_transfer.zig` `//!` title and entry-point name are reworded  
  too. The **filename** still carries the word — owner's decision, since  
  renaming trips the examples-catalog nav-sync rule.
- Working tree carries uncommitted owner edits to `README.md` and
  `design/secondary/mtk-readme.md`, a deleted SPDX header in  
  `src/internal/cond_timeout.zig`, and a deleted  
  `design/stories/photo-archive-pipeline.png` alongside two untracked  
  `-001.png`/`-002.png`. Left alone. The story narrative references no image.
