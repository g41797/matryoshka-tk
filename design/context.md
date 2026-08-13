# Matryoshka Zig — Context Entry Point

## Writing rules
- Short intro, then bullets. Like staccato music.
- One fact per bullet.
- No prose paragraphs with comma-separated lists.

## What this file is

One line per doc: the link, then what the doc is.

Not a changelog. How a doc reached its current version is narrative, and  
narrative lives in [STATUS-LOG.md](STATUS-LOG.md). See rules-047.md,  
"Status file ownership".

`design/` holds the current picture of Matryoshka. Snapshots, superseded  
drafts, session logs and unstarted intentions live in  
[secondary/](secondary/context.md) and are frozen. See rules-047.md,  
"Where a doc lives".

## State

- [STATUS.md](STATUS.md) — where we are and what is next. Read in full each session.
- [matryoshka-tk-implementation-plan-070.md](matryoshka-tk-implementation-plan-070.md) — forward-looking work + one line per completed stage.
- [STATUS-LOG.md](STATUS-LOG.md) — session narrative, by date. Do not read by default.

## Sources of truth

- [matryoshka-api-reference-041.md](matryoshka-api-reference-041.md) — the book. Seven parts: introduction, the Zig mechanisms, then one part each for polynode, mailbox and pool in the same five-piece shape, the cross-tool material, and what sits beyond the toolkit. Signatures, types, error sets, preconditions and the cancel contract live in the three tool parts. The assert mechanism does not — that is in `src/` doc comments.
- [rules-047.md](rules-047.md) — coding, doc, and process rules. Includes the banned-word list.
- [patterns-028.md](patterns-028.md) — unified pattern and idiom catalog.
- [matryoshka-zig-0.16-notes-003.md](matryoshka-zig-0.16-notes-003.md) — Zig 0.16 constraints, the cancellation contract, and what comptime bought.

## Concepts

- [matryoshka-concepts-002.md](matryoshka-concepts-002.md) — what Matryoshka is: why it exists, the one constraint, Master as an Io task, the four concepts, the who-holds-it mantra, the three-category model, where Io fits.
- [matryoshka-architecture-foundation-4-006.md](matryoshka-architecture-foundation-4-006.md) — four layers (Hold/Movement/Lifecycle/Coordination), hold states, concurrency contract, infrastructure as items, design decisions, non-goals.
- [language-of-matryoshka.md](language-of-matryoshka.md) — vocabulary. Where another doc differs, this one wins.

## Design notes

- [item-list-011.md](item-list-011.md) — `ItemList` and intrusive safety. The question record behind API 8, 9 and 10.
- [receive-router-002.md](receive-router-002.md) — receive-router use case and chosen solution.
- [table-dispatch-002.md](table-dispatch-002.md) — table dispatch: the handler belongs to the pair (receiver, tag).
- [api-12-real-pointers-005.md](api-12-real-pointers-005.md) — API 12: Mbox/Pool as real pointers, replacing MailboxHandle/PoolHandle.
- [api-13-book-002.md](api-13-book-002.md) — API 13: the api reference becomes a standalone book for the user, and the detail moves into `src/` doc comments. Current version, with the owner's rulings on `-001` folded in.
- [api-13-carryover-004.md](api-13-carryover-004.md) — API 13: what left the book, and where it goes. Landed in `src/` by 13-2, still the input for 13-3. Carries the slogan register, the banned-word footprint, and what 13-2 found the code did not back.
- [audit-recipe-002.md](audit-recipe-002.md) — how to audit a layer for items the toolkit gives back. Method behind INTR 7 and MBOX 1, with the current baseline. Tool: `kitchen/tools/audit_edges.sh`.

## Tests and examples

- [task1-tests-007.md](task1-tests-007.md) — Layers 1-3, 84 scenarios.
- [task2-tests-003.md](task2-tests-003.md) — Layer 4, 16 scenarios: worker lifecycle, shutdown, cancellation.
- [task1-examples-006.md](task1-examples-006.md) — Layers 1-4, 29 scenarios. Index only; the description lives in each source file's doc comment.
- [task2-examples-007.md](task2-examples-007.md) — Layer 4 + cross-layer, 48 scenarios. Index only.

## Stories

- [stories/video-transcoder-004.md](stories/video-transcoder-004.md) — massive-scale transcoder. Pool as backpressure signal, transfer routing.
- [stories/print-server-003.md](stories/print-server-003.md) — network print server. Client, spooler, device.
- [stories/photo-archive-pipeline.md](stories/photo-archive-pipeline.md) — photo archive: album, grid, search and full-size views. Diagrams: `stories/photo-archive-pipeline-001.png` and `stories/photo-archive-pipeline-002.png`.

## Documentation

- [matryoshka-Tk-diagram-style-guide-003.md](matryoshka-Tk-diagram-style-guide-003.md) — diagram notation and style.
- [../kitchen/defer/matryoshka-storytelling-003.md](../kitchen/defer/matryoshka-storytelling-003.md) — storytelling rhythm: Discussion, SRS, Translation, Central Insight.
- [../kitchen/notes.md](../kitchen/notes.md) — running notes on `kitchen/` tooling. Not versioned, edit in place.

## Secondary

- [secondary/context.md](secondary/context.md) — index of the frozen material: cookbook structure, the DOC-stage docs plan, docs tooling, the README draft, the Odin idiom mapping, the pointer-switch compiler bug and its repro, the two transcoder notation experiments, the print-server analysis.
