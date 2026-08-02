# Matryoshka Zig — Context Entry Point

## Writing rules
- Short intro, then bullets. Like staccato music.
- One fact per bullet.
- No prose paragraphs with comma-separated lists.

## What this file is

One line per doc: the link, then what the doc is.

Not a changelog. How a doc reached its current version is narrative, and  
narrative lives in [STATUS-LOG.md](STATUS-LOG.md). See rules-041.md,  
"Status file ownership".

`design/` holds the current picture of Matryoshka. Snapshots, superseded  
drafts, session logs and unstarted intentions live in  
[secondary/](secondary/context.md) and are frozen. See rules-041.md,  
"Where a doc lives".

## State

- [STATUS.md](STATUS.md) — where we are and what is next. Read in full each session.
- [matryoshka-tk-implementation-plan-055.md](matryoshka-tk-implementation-plan-055.md) — forward-looking work + one-line ledger of completed stages.
- [STATUS-LOG.md](STATUS-LOG.md) — session narrative, by date. Do not read by default.

## Sources of truth

- [matryoshka-api-reference-033.md](matryoshka-api-reference-033.md) — signatures, types, error sets, cancel contract, PolyHelper, ItemList, invariants, thread-safety, complexity. Dependency-ordered; generic `std.Io` material sits in a trailing Addendums/Io 101 section.
- [rules-041.md](rules-041.md) — coding, doc, and process rules. Includes the banned-word list.
- [patterns-025.md](patterns-025.md) — unified pattern and idiom catalog.
- [matryoshka-zig-0.16-notes-002.md](matryoshka-zig-0.16-notes-002.md) — Zig 0.16 constraints, the cancellation contract, and what comptime bought.

## Concepts

- [matryoshka-concepts-001.md](matryoshka-concepts-001.md) — what Matryoshka is: why it exists, the one constraint, Master as an Io task, the four concepts, the who-holds-it mantra, the three-category model, where Io fits.
- [matryoshka-architecture-foundation-4-005.md](matryoshka-architecture-foundation-4-005.md) — four layers (Hold/Movement/Lifecycle/Coordination), hold states, concurrency contract, infrastructure as items, design decisions, non-goals.
- [language-of-matryoshka.md](language-of-matryoshka.md) — vocabulary. Where another doc differs, this one wins.

## Design notes

- [item-list-009.md](item-list-009.md) — `ItemList` and intrusive safety. The question record behind API 8, 9 and 10.
- [receive-router-001.md](receive-router-001.md) — receive-router use case and chosen solution.
- [table-dispatch-001.md](table-dispatch-001.md) — table dispatch: the handler belongs to the pair (receiver, tag).

## Tests and examples

- [task1-tests-005.md](task1-tests-005.md) — Layers 1-3, 84 scenarios.
- [task2-tests-002.md](task2-tests-002.md) — Layer 4, 16 scenarios: worker lifecycle, shutdown, cancellation.
- [task1-examples-005.md](task1-examples-005.md) — Layers 1-4, 29 scenarios. Index only; the description lives in each source file's doc comment.
- [task2-examples-006.md](task2-examples-006.md) — Layer 4 + cross-layer, 48 scenarios. Index only.

## Stories

- [stories/video-transcoder-003.md](stories/video-transcoder-003.md) — massive-scale transcoder. Pool as backpressure signal, transfer routing.
- [stories/print-server-002.md](stories/print-server-002.md) — network print server. Client, spooler, device.
- [stories/photo-archive-pipeline.md](stories/photo-archive-pipeline.md) — photo archive: album, grid, search and full-size views. Diagrams: `stories/photo-archive-pipeline-001.png` and `stories/photo-archive-pipeline-002.png`.

## Documentation

- [matryoshka-Tk-diagram-style-guide-002.md](matryoshka-Tk-diagram-style-guide-002.md) — diagram notation and style.
- [../kitchen/defer/matryoshka-storytelling-003.md](../kitchen/defer/matryoshka-storytelling-003.md) — storytelling rhythm: Discussion, SRS, Translation, Central Insight.
- [../kitchen/notes.md](../kitchen/notes.md) — running notes on `kitchen/` tooling. Not versioned, edit in place.

## Secondary

- [secondary/context.md](secondary/context.md) — index of the frozen material: cookbook structure, the DOC-stage docs plan, docs tooling, the README draft, the Odin idiom mapping, the pointer-switch compiler bug and its repro, the two transcoder notation experiments, the print-server analysis.
