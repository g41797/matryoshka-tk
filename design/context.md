# Matryoshka Zig — Context Entry Point

## Writing rules
- Short intro, then bullets. Like staccato music.
- One fact per bullet.
- No prose paragraphs with comma-separated lists.

## What this file is

One line per doc: the link, then what the doc is.

Not a changelog. How a doc reached its current version is narrative, and  
narrative lives in [STATUS-LOG.md](STATUS-LOG.md). See rules-039.md,  
"Status file ownership".

## State

- [STATUS.md](STATUS.md) — where we are and what is next. Read in full each session.
- [matryoshka-tk-implementation-plan-052.md](matryoshka-tk-implementation-plan-052.md) — forward-looking work + one-line ledger of completed stages.
- [STATUS-LOG.md](STATUS-LOG.md) — session narrative, by date. Do not read by default.
- [collected-context-005.md](collected-context-005.md) — project state snapshot.

## Sources of truth

- [matryoshka-api-reference-033.md](matryoshka-api-reference-033.md) — signatures, types, error sets, cancel contract, PolyHelper, ItemList, invariants, thread-safety, complexity. Dependency-ordered; generic `std.Io` material sits in a trailing Addendums/Io 101 section.
- [rules-039.md](rules-039.md) — coding, doc, and process rules. Includes the banned-word list.
- [patterns-025.md](patterns-025.md) — unified pattern and idiom catalog.
- [matryoshka-tk-0.16-implementation-guide-001.md](matryoshka-tk-0.16-implementation-guide-001.md) — Zig 0.16 details.

## Concepts

- [matryoshka-manifesto-005.md](matryoshka-manifesto-005.md) — persuasion-first mindset doc: one constraint, Master is a role, four fundamental concepts, Io hidden behind Mailboxes.
- [matryoshka-architecture-004.md](matryoshka-architecture-004.md) — why matryoshka exists, concept progression, flows, layers.
- [matryoshka-architecture-foundation-4-004.md](matryoshka-architecture-foundation-4-004.md) — four layers (Hold/Movement/Lifecycle/Coordination), concurrency contract, infrastructure as items, design decisions.
- [matryoshka-new-mindset-001.md](matryoshka-new-mindset-001.md) — Io creates tasks via `io.concurrent()`; a Master is an Io task that follows the Matryoshka rules.
- [matryoshka-model-007.md](matryoshka-model-007.md) — the who-holds-it mantra, three-category model, story structure, when to allocate a Master.
- [language-of-matryoshka.md](language-of-matryoshka.md) — vocabulary.

## Design notes

- [item-list-009.md](item-list-009.md) — `ItemList` and intrusive safety. The question record behind API 8, 9 and 10.
- [receive-router-001.md](receive-router-001.md) — receive-router use case and chosen solution.
- [table-dispatch-001.md](table-dispatch-001.md) — table dispatch: the handler belongs to the pair (receiver, tag).
- [llvm-pointer-switch-bug-001.md](llvm-pointer-switch-bug-001.md) — why `switch` over tags does not compile. Repro + build matrix.

## Tests and examples

- [task1-tests-005.md](task1-tests-005.md) — Layers 1-3, 84 scenarios.
- [task2-tests-002.md](task2-tests-002.md) — Layer 4, 16 scenarios: worker lifecycle, shutdown, cancellation.
- [task1-examples-005.md](task1-examples-005.md) — Layers 1-4, 29 scenarios. Index only; the description lives in each source file's doc comment.
- [task2-examples-006.md](task2-examples-006.md) — Layer 4 + cross-layer, 48 scenarios. Index only.
- [task1-scenarios-001.md](task1-scenarios-001.md), [task2-scenarios-001.md](task2-scenarios-001.md) — original unsplit sources, historical.

## Documentation

- [matryoshka-tk-docs-plan-015.md](matryoshka-tk-docs-plan-015.md) — documentation work plan: mkdocs + autodocs, site skeleton, DOC stages.
- [docs-tooling-approach-002.md](docs-tooling-approach-002.md) — content-authoring method for DOC stages.
- [../kitchen/docs/matryoshka-storytelling-001.md](../kitchen/docs/matryoshka-storytelling-001.md) — storytelling rhythm: Discussion, SRS, Translation, Central Insight.
- [matryoshka-Tk-diagram-style-guide-002.md](matryoshka-Tk-diagram-style-guide-002.md) — diagram notation and style.
- [../kitchen/notes.md](../kitchen/notes.md) — running notes on `kitchen/` tooling. Not versioned, edit in place.
