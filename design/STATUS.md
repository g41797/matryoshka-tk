# matryoshka-tk STATUS

## Rules
- Read STATUS.md in full each session. It says where we are and what is next.
- Session Log lives in STATUS-LOG.md (append-only, newest entries at top). Do NOT read it by default — append new entries there without reading the rest. Read STATUS-LOG.md only when explicitly asked (history audit, "what did we do about X", resolving a specific past-decision question).
- No git directly. Owner does git.
- No skipping stages. Each stage passes before the next.
- No real code before infrastructure (Stage 0) is verified.
- Show intent before code changes. Get owner approval.
- Plan approval is NOT code change approval.
- Architectural changes need explicit owner approval.
- Never overwrite any doc. New version with incremented suffix (-001, -002, etc.). Update cross-references. Applies to all docs, no exceptions.
- Post-stage cleanup: after all kitchen scripts pass, revise all code for obsolete parts, wrong comments, repeated code extractable to reusable sources. Fix, re-run all three scripts. Session log must have a "Post-stage cleanup" row — its absence means the rule was skipped.
- Plan versioning: after each completed stage, create new plan version. Collapse done stages to one-line summaries. Update context.md and STATUS.md to point to new version.
- Tests before examples: examples cannot start until all tests pass all kitchen scripts. Stage N.a = impl + tests, Stage N.b = examples. No mixing.

## Constraints for Next Agent (MUST)
- Git disabled. Do NOT run any git commands.
- Coding style: LE imports, explicit types, explicit dereference, stdlib first, errdefer/defer for resource cleanup.
- Doc style: short sentences, bullets, no AI-sh words. See plan Section 1.
- Run verification via kitchen scripts, not manual zig commands.
- Redirect kitchen script output to zig-out/ log files: `bash kitchen/script.sh > zig-out/script.log 2>&1`. Read the log file. Do NOT analyze shell stdout.
- AI-sh scan after every stage that changes *.md or *.zig.

## Sources of Truth
- API: matryoshka-api-reference-027.md
- Zig details: matryoshka-tk-0.16-implementation-guide-001.md
- Architecture: matryoshka-architecture-foundation-4-004.md
- Architecture introduction: matryoshka-architecture-003.md
- Tests: task1-tests-001.md (73 scenarios, Layers 1-3), task2-tests-001.md (16 scenarios, Layer 4)
- Examples: task1-examples-003.md, task2-examples-005.md (index only; full description lives in each source file's `///` doc comment)
- Scenarios (historical): task1-scenarios-001.md (92), task2-scenarios-001.md (61)
- Legacy mailbox: /home/g41797/dev/root/github.com/g41797/mailbox/
- Odin proto: /home/g41797/dev/root/github.com/g41797/matryoshka/
- tofu (build infra): /home/g41797/dev/root/github.com/g41797/tofu/
- Plan: matryoshka-tk-implementation-plan-046.md (slim, state-only)
- Rules: rules-027.md
- Receive router design note: receive-router-001.md
- New Mindset reference: matryoshka-new-mindset-001.md
- Thinking model: matryoshka-model-003.md
- Patterns: patterns-017.md
- Docs plan: matryoshka-tk-docs-plan-015.md
- Manifesto: matryoshka-manifesto-005.md
- Latest context: collected-context-005.md
- CANDIDATES (composed docs, pending owner review before promotion): design/candidates/readme-004.md, design/candidates/landing-short-002.md, design/candidates/landing-long-003.md
- Markdown hard-break tooling: kitchen/tools/fix_md_hardbreaks.sh, rule documented in rules-027.md

## Participants
- Owner(g41797-human): design, decision-making
- Claude: implementation, tests

## Project
Ownership-transfer and lifecycle toolkit for Zig 0.16.  
Three layers: polynode, mailbox, pool. Both mailbox and pool optional.

## Folder Structure
```
matryoshka-tk/
├── build.zig
├── build.zig.zon
├── README.md
├── src/
│   ├── matryoshka.zig
│   ├── polynode.zig
│   ├── mailbox.zig
│   ├── pool.zig
│   └── internal/
│       └── cond_timeout.zig
├── tests/
│   └── matryoshka_tests.zig
├── kitchen/
│   ├── build_and_test_debug.sh
│   ├── build_and_test_all.sh
│   └── build_cross_debug.sh
└── design/
    ├── STATUS.md
    └── *.md
```

## Decisions
- STATUS.md first, updated after every stage.
- Document rules apply to all markdown.
- condition_waitTimeout copied from legacy mailbox (Open Item 5).
- Tests check implementation. Examples show real usage patterns and stress-test.
- Examples have test wrappers. Examples come after tested code.
- Scenarios re-partitioned into tests + examples (Stage 0.5).
- Helper code (NodeMixin, Event, Sensor) developed in same stage as the code it supports.

## Open Items (carried from collected-context-001.md)
- 5  condition_waitTimeout workaround
- 6  Io.Evented backend not tested
- 10 which Layer 2-3 examples need real threads
- 11 panic test style in Zig
- 12 real-Io examples are integration tests, gate by platform
- 13 rare ReleaseSmall race in pool_fan_in (053) — see Session Log 2026-07-03 for full trace. Suspected upstream Zig 0.16 `Io.Threaded` bug, not app code. Not reproducible outside stress loop.

## Stages
Stage 0 — Infrastructure. DONE.  
Stage 0.5 — Re-partition scenarios. DONE.  
Stage 1.a — PolyNode (impl + tests). DONE.  
Stage 1.b — PolyNode examples. DONE.  
Stage 2.a — Mailbox (impl + tests). DONE.  
Stage 2.b — Mailbox examples. DONE.  
Stage 2.5 — Pre-Stage-3 fixes. DONE.  
Stage 3 — Pool (impl + tests + examples). DONE.  
Stage 4 — DONE (97/97 tests).  
Stage 5.a — DONE (99/99 tests).  
Stage 5.b — DONE (107/107 tests).  
INTR 1 — DONE (107/107 tests). Plan version 011 created.  
Stage 6 — DONE (121/121 tests). Plan version 013 created.  
INTR 2 — DONE (121/121 tests). Plan version 014 created.  
Stage 7.a — DONE (121/121 tests). receiveResult/receive_future/getWaitResult/get_wait_future added to src/.  
INTR 3 — DONE (121/121 tests). ASCII ownership diagrams added to all 29 existing examples. Plan version 015 created.  
Stage 7.b — DONE (143/143 tests). 22 new example files + test wrappers. Plan version 016 created.  
INTR 4 — DONE (145/145 tests). Bug fixes + doc corrections. api-reference-015 created.  
Stage 8 — DONE (160/160 tests). 15 new examples: cross-layer (32–41) + mailbox-less (57–61). layer4_cross.zig created.  
INTR 5 — DONE (161/161 tests). Stories infrastructure + doc quality overhaul complete. video_transcoder.zig refactored per Master composition rule. Plan version 018 created.  
STORY 2 — Print Server narrative. DONE.  
STORY 1 — Video Transcoder narrative rewrite. DONE.  
Story Rhythm — Both stories SRS+Translation+Insight rewritten. DONE.  
EXMPL 1 — Example completeness audit + rule addition. DONE. Plan version 022 created.  
EXMPL 2 — Master pattern: pilot (scenario 18) + doc update. DONE. Plan version 023 created.  
EXMPL 3a — 7 semantic rewrites (scenarios 46,47,53,56,57,58,59). DONE. Plan version 024 created.  
EXMPL 3b — Rename NNN- prefix + Master pattern (6 files). DONE. Plan version 025 created.  
EXMPL 3c — Observable by human rule + 3 Master fixes. DONE. Plan version 026 created.  
EXMPL 3d — Observable: extract steps in 31 flat examples. DONE. Plan version 027 created.  
EXMPL 3e — Observable: structural extraction signals + fix 24 violating examples. DONE. Plan version 028 created.  
API 2 — PolyHelper Slot-aware identification API. DONE. 161/161 tests.  
EXMPL 4 — Description as code: staccato descriptions moved into source `///` comments, layer1-3 NNN- renaming, catalog docs as index. DONE. Plan version 030 created.  
EXMPL 4b — Descriptive entry-point names: `pub fn run` renamed to `pub fn @"<description>"` in all 66 example files; test-wrapper call sites updated. DONE. Plan version 031 created.  
EXMPL 4c — Eliminated all remaining live `drain` occurrences (8 files: prose word-swaps + `batchDrainToPool`/`MasterBatchDrainFailed`/barrel-alias identifier renames). DONE.  
Stage 9 — Docs + README + autodocs. PLANNED.  
DOC 1 — tofu audit + docs plan skeleton. DONE. Plan version matryoshka-tk-docs-plan-002.md created.  
DOC 2 — confirm tofu + Odin mix decision. DONE (audit only, no implementation).  
DOC 3 — kitchen/ doc folder layout proposal + DOCS-folder claim check. DONE (analysis only).  
DOC 4 — build kitchen/ doc infra (build.zig docs step, mkdocs.yml, tools/, docs.yml fix), verify locally. DONE.  
DOC 5 — top-down entry point (matryoshka-based-systems.md) + nav skeleton (Concepts/Building Blocks/Cookbook stubs). DONE.  
DOC 6 — populate Concepts with a story, top-down: print-server system page + Matryoshka-mapping page. DONE.  
DOC 7 — populate Building Blocks with one topic: Observable by human (rule + pattern). DONE.  
DOC 8 — populate Building Blocks with the four core concepts: PolyNode/Mailbox/Pool/Master. DONE.  
API 3 — mailbox.wakeUpAll(). DONE (167/167 tests). Plan version 032 created.  
DOC 9 — re-partition and logically reorder the API reference (api-reference-017 →  
-018); std.Io-generic material moved to Addendums/Io 101; Change-manifest repetition  
dropped. DONE (doc-only, 167/167 tests unchanged). Plan version 033 created.  
DOC 10 — dependency-order the API reference (api-reference-018 → -019): send/receive  
diagrams into mailbox, Tag identity after pool, Slot-based programming + Cooperative  
cleanup patterns after pool — nothing used before it is introduced. DONE (doc-only,  
167/167 tests unchanged). Plan version 034 created.  
DOC 11 — write matryoshka-manifesto-002.md: consolidated README + matryoshka-tk-model +  
matryoshka-master + master-Tk mindset into one persuasion-first manifesto (one  
constraint, Master is a role, four fundamental concepts, Io as hidden transport behind  
Mailboxes, start small). DONE (doc-only, 167/167 tests unchanged). Plan version 035  
created.  
DOC 12 — de-smart the manifesto (manifesto-002 → -003): abstract architect-speak  
("application model", "execution model", "autonomous", "reason about locally")  
rewritten into plain human language; structure, diagrams, tables unchanged. DONE  
(doc-only, 167/167 tests unchanged). Plan version 036 created.  
DOC 13 — unified pattern/idiom catalog (patterns-009 → patterns-010): both halves  
merged, api-reference pattern material (cooperative cleanup, infra-handle transport,  
no-raw-allocator) absorbed, no repetition, logical order. DONE (doc-only, 167/167  
tests unchanged). Plan version 037 created.  
DOC 14 — audited Odin `matryoshka/kitchen/docs` for patterns/idioms missing from  
patterns-010; added 7 new catalog entries (Request-Response, Pipeline, Fan-In,  
Fan-Out, Shutdown via Exit message, Thread-is-container, Intrusive node embedding)  
to patterns-011.md, all pointing at existing Zig examples; 3 advanced/niche  
patterns with no example (self-send, function-pointer-as-tag,  
descriptor-struct-as-tag) explicitly skipped, owner confirmed. DONE (doc-only,  
167/167 tests unchanged). Plan version 038 created.  
DOC 15 — added `///`/`//!` doc comments to `src/polynode.zig`, `src/mailbox.zig`,  
`src/pool.zig`, `src/matryoshka.zig` (file headers + every `pub` declaration),  
sourced from matryoshka-api-reference-019.md; excluded `src/internal/cond_timeout.zig`  
(temporary workaround). Lifted the src/ `///` ban: rules-010.md → rules-011.md.  
DONE (167/167 tests unchanged, `zig build docs` clean). Plan version 039 pending.  
DOC 16 — polish pass on `src/*.zig` doc comments: fixed banned word "ensure"  
in `pool.zig`; dropped "ownership" language for send/place + one-place/one-state  
phrasing; split long comment lines into staccato bullets; new rule  
`rules-011.md` → `rules-012.md` (no ownership language, no `.md` refs in  
`src/` comments). DONE (167/167 tests unchanged, `zig build docs` clean).  
DOC 16b — gap-fix: 6 missed ownership hits reworded, `mailbox.zig`/`pool.zig`/  
`polynode.zig` file headers restructured to std.Io-style intro+bullets, stray  
line removed; new rule `rules-012.md` → `rules-013.md` (sweep-verification  
rule + header staccato standard). DONE (167/167 tests unchanged, `zig build  
docs` clean).  
DOC 17 — snake_case entry points, fix autodoc "Declaration not found" bug.  
DONE (167/167 tests unchanged). rules-013.md → rules-014.md.  
DOC 17b/17c — example doc comments moved to file-level `//!`; ASCII  
Ownership diagrams wrapped in fenced code blocks; fixed 056-pipeline's  
un-renamed `Pipeline` entry point. DONE (167/167 tests unchanged).  
rules-014.md → rules-015.md.  
DOC 18 — humanized the API reference (api-reference-019 → -020): dropped  
"ownership" framing throughout, staccato pass on remaining prose; re-synced  
src/mailbox.zig and src/pool.zig doc comments to match (src/polynode.zig and  
src/matryoshka.zig already matched). DONE (167/167 tests unchanged).  
DOC 18b — new rule: `//!` file-level block must end with a bare `//!` +  
blank line. rules-015.md → rules-016.md. SUPERSEDED by DOC 18c — the  
blank-line hypothesis was tested against real rendered docs and disproved.  
DOC 18c — root-caused via headless-Chrome render: Zig autodoc splices the  
first declaration's `///` comment onto the container page unconditionally.  
Fix: `const _doc_stub = void;` as first declaration in mailbox.zig/pool.zig/  
polynode.zig. rules-016.md → rules-017.md. DONE (167/167 tests unchanged).  
API 4 — Renamed `NodeHandle` → `ItemHandle` (src, examples, stories, design docs);  
documented `ih` short-form and `handle` shorthand convention. DONE (167/167  
tests unchanged). Plan version pending.  
API 4b — Propagated the rename to `kitchen/docs/` site pages and regenerated  
autodocs. DONE.  
DOC 19 — moved GitHub Pages generated site from `kitchen/output/` to  
root-level `docs/` (standard Pages folder name). DONE.  
INTR 6 — DONE (167/167 tests). Split standalone `helpers/` build module into  
`examples/items/` (4 item types + `items.zig` lifecycle helpers),  
`examples/hooks/` (`AlwaysCreateHooks.zig`, `CappedPoolHooks.zig`,  
`hooks.zig`), `examples/helpers/` (generic `expect`/`clearList` only).  
Updated `build.zig` to drop the standalone helpers module and wire `smod`  
to `examples`. ~68 call-site files updated. Old `helpers/` folder deleted.  
Plan version 039 created.  
DOC 20 — DONE (167/167 tests). Removed the 8 example-autodoc `zig build docs`  
targets (`layer1docs`..`layer4docs`, `itemsdocs`, `hooksdocs`, `helpersdocs`,  
`storiesdocs`) and their `build.zig` support code; `apidocs` untouched. New  
permanent `kitchen/tools/gen_examples_docs.sh` mirrors `examples/`+`stories/`  
into `kitchen/docs/examples/` as generated `.md` pages (description + diagram  
verbatim, embedded source, GitHub-blob link); 6 hand-authored catalog/group  
pages replace `examples_reference.md`. rules-019 → -020, docs-plan-014 → -015,  
plan-039 → -040.  
DOC 20 follow-up — DONE. Owner found the 76 mirrored example pages were  
link-only orphans (built by mkdocs but absent from `nav:`). Added every  
example to `kitchen/mkdocs.yml`'s Examples Catalog `nav:` under its group;  
new rule (rules-020 → -021): examples-catalog nav sync — any `examples/`/  
`stories/` file add/remove/rename must update `nav:` + group pages.  
Current: 167/167 tests. DOC 20 + follow-up DONE.  
DOC 21 — "The Shape of a Real System" page (kitchen/docs/the-shape.md): two  
Graphviz diagrams (real-system.dot / matryoshka-solution.dot) mapping three  
ownership/reuse/coupling pains onto PolyNode/Mailbox/Pool, wired into  
mkdocs nav after manifesto.md. New permanent kitchen/diagrams/src/ +  
kitchen/tools/gen_diagrams.sh (manual-run, committed output, not CI-wired).  
README insertion deferred by owner. DONE (doc-only, 167/167 tests  
unchanged). Plan version pending.  
INTR 7 — DONE (167/167 tests). Pool `on_put` reset convention added to every  
example/test hook; "Pool is not storage" correction in  
matryoshka-architecture-foundation-4-003.md; `put`'s four hook-driven  
outcomes + no-fixed-sequence-guarantee caveat documented in  
matryoshka-api-reference-023.md + kitchen/docs pool pages; audit of all  
32 pool-touching files found and fixed 5 wrong-assumption bugs the reset  
surfaced. Diagram-notation fixes (053's `mbh[0..2]`/`×3`, repo-wide sweep)  
and a mailbox-focused equivalent stage deferred, owner's call.  
Staccato sweep — DONE (167/167 tests). Repo-wide audit found 9 files with  
prose-paragraph violations of the staccato rule; fixed 8 (video-transcoder.md  
and a lower-confidence bucket left untouched, owner's call). Followed by a  
"thread" audit — DONE (167/167 tests): worker-finish-signal pattern's stale  
"spawns a worker thread"/"joins the thread" language corrected to  
`io.concurrent`/future-await across `matryoshka-api-reference-025.md`,  
`patterns-015.md`, and two `kitchen/docs` mirrors; 5 stale  
`matryoshka-api-reference-022.md` cross-references in patterns-015.md fixed.  
LANDING 1 — src/ LOC counter (non-recursive, excludes empty/comment/import  
lines; design/src-loc-counter-001.md) + badge next to API button on  
`kitchen/docs/index.md`, shared logic in `kitchen/tools/src_loc.py` used by  
both the mkdocs build-time hook (`kitchen/hooks/count_lines.py`) and a  
standalone script (`kitchen/tools/count_src_loc.sh`); API button hidden via  
CSS (`display: none`, markup kept). DONE (doc/tooling-only, 167/167 tests  
unchanged).  
REBRAND — repo renamed to matryoshka-tk. Mechanical pass (file renames,  
safe-regex text swap) done pre-clone; this session verified every deferred  
item in matryoshka-tk-rebrand-checklist-001.md: no stray matryoshka-io  
paths (outside the checklist itself and exempt STATUS-LOG.md history), no  
hardcoded repo-slug in .github/workflows/*.yml, no stray bare Io/io  
mentions. DONE (doc-only, 167/167 tests unchanged). Deferred editorial/  
conceptual prose pass (README intro, manifesto, landing candidates)  
remains owner's call, not actioned. Plan version 043 created.  
API 5a — Composite Items: `PoolHooks.on_put` returns `?std.DoublyLinkedList`  
(was `void`); `slot` behavior unchanged; new `_add_returned_item` helper  
adds the slot item and every returned-list node the same way, one  
broadcast per `put`; foreign tag now a hard assert. All existing `on_put`  
hook implementations updated to the new signature, returning `null`. DONE  
(167/167 tests unchanged). Plan version 044 created.  
API 5b — new scenario 89 in `tests/layer3_pool.zig`: `on_put` keeps the  
Event via `slot` and hands back a fresh Sensor via the returned list;  
verified both land in the correct per-tag free-lists and are retrievable.  
DONE (168/168 tests, +1 new).  
API 5c — short doc update: `kitchen/docs/api/pool/put.md`,  
`hooks-discipline.md`, and orphaned `kitchen/docs/api/pool.md` document  
`on_put`'s `?std.DoublyLinkedList` return value, stressing hook-author  
responsibility. `matryoshka-api-reference-025.md` → `-026.md`  
(no-overwrite rule), cross-references updated in `context.md`,  
`patterns-015.md`, `STATUS.md` Sources of Truth. DONE (168/168 tests  
unchanged, `mkdocs build --strict` clean). API 5 complete.  
API 5 follow-up — fixed a `put` returned-list bug: `popFirst` leaves the  
popped node's own `prev`/`next` stale, so `_add_returned_item`'s  
`is_linked` assert panicked for composite lists of 3+ items (invisible  
with 1 item). Reproduced first (scenario 89 extended to 3 items, panic  
confirmed), then fixed with `polynode.reset(poly)` after `popFirst`,  
mirroring the pool's own internal free-list pops. DONE (168/168 tests  
unchanged).  
API 5d — trimmed `on_put`/`put`'s `src/pool.zig` doc comments to the  
mechanical contract only; moved the composite-items rationale into a  
dedicated "Composite Items" section in `kitchen/docs/api/pool/put.md`  
(mirrored in orphaned `pool.md` and `matryoshka-api-reference-026.md`).  
`on_put`'s `?std.DoublyLinkedList` return-value signature unchanged — an  
out-param alternative was proposed and rejected. DONE (168/168 tests  
unchanged, `mkdocs build --strict` clean).

EXMPL 5a — `design/receive-router-001.md`: receive-router use case and chosen  
solution. Working document the example and pattern pages are written from.  
Not an example, not a pattern page. DONE (doc-only).  
EXMPL 5b — `examples/layer4/062-receive_router.zig`: a router receives from a  
mailbox in a loop and puts each `ReceiveResult` in the Select queue. One  
registration covers every item. The Master never re-registers the router; it  
does re-register the timer, in the same `switch`. Pre-filled pool bounds items  
in flight, so the `N >= P + T` buffer precondition is countable in the source.  
Barrel entry + test wrapper in `tests/layer4_select.zig`. DONE (169/169 tests,  
+1 new).  
EXMPL 5c — pattern docs: "Receive router — one registration, many events"  
added to `kitchen/docs/patterns/async.md` and `patterns-015.md` → `-016.md`;  
`kitchen/docs/addendums/io-101.md` gains the `std.Io` fact that a task's  
return value is discarded silently when the queue is already closed. DONE.  
EXMPL 5d — `gen_examples_docs.sh` regenerated, `kitchen/docs/examples/io.md`  
group page and `kitchen/mkdocs.yml` nav updated per the nav-sync rule. DONE  
(`mkdocs build --strict` clean).  
EXMPL 5e — cancelDiscard audit, 15 live call sites. No defects. Three sites  
are safe because a mailbox is provably empty rather than by structure —  
recorded as observations in plan-045, no code changed. DONE.

API 6 — PolyHelper accessor naming. `identifyNodeAs`/`identifySlotAs` →  
`fromNode`/`fromSlot` (+ `must` variants), hard rename, no aliases, ~222 call  
sites. New `moveFromSlot` takes the item out of a Slot: clears on success,  
leaves the Slot unchanged on failure, asserts the item is not linked. A  
call-site audit drove the shape — ~82 of 127 Slot sites are `create → set a  
field → send`, none consumed the Slot, so inspection stays and extraction is  
additive. Caller: `examples/layer1/022-ownership_transfer.zig`, which  
hand-rolled `list.append(&slot.?.node); slot = null;` with no tag check.  
Scenario 98 pins the contract. Docs: api-reference-027, patterns-017,  
rules-027 ("Accessor naming"), plan-046. DONE (170/170 tests, +1 new).

**Next stage**: CANDIDATES (composed README + landing docs from a repo-wide `.md` audit,  
`design/candidates/`) — requirements-gathering done, execution not started,  
blocked on owner confirming Pass 1 subagent-sweep approach. MDFIX is already  
done (rule in rules-026, `fix_md_hardbreaks.sh` in place) — plan-044 listed it  
as pending, which was stale. Deferred: diagram-notation sweep, mailbox-focused  
pool-audit equivalent, showcase-post variants (Ziggit/Discord/Reddit),  
REBRAND's editorial prose pass — all owner's call on order.


## Session Log

Moved to [STATUS-LOG.md](STATUS-LOG.md). Append new entries there (newest at top).
