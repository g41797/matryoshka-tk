# matryoshka-tk STATUS

## Start here — every session, before anything else

1. Read this file in full. It is current state: what is done, what is in
   flight, what is authorized.
2. Read Part 0 of [rules-047.md](rules-047.md).
3. Read the plan, [matryoshka-tk-implementation-plan-070.md](matryoshka-tk-implementation-plan-070.md),
   for the stage the owner names. Not before they name it.

These two files are the entry point. This repo has no auto-loading agent
instruction file at its root, and will not get one — owner's decision,
2026-08-13. Do not propose adding one, and do not put session instructions
anywhere outside this file and the plan. If a session starts with no
instruction, read this file and ask what to work on.

**No stage starts because a document says "Next".** The owner names the stage.

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
- Where a doc lives. `design/` is the current picture of Matryoshka, present tense. Snapshots, superseded drafts, session logs and unstarted intentions go to `design/secondary/` and are frozen. `kitchen/defer/` is frozen too — deferred material, absent from mkdocs nav, its snippets predate API 12. Every file is listed in `context.md` or `secondary/context.md`. Full entry in rules-047.md.
- Post-stage cleanup: after all kitchen scripts pass, revise all code for obsolete parts, wrong comments, repeated code extractable to reusable sources. Fix, re-run all three scripts. Session log must have a "Post-stage cleanup" row — its absence means the rule was skipped.
- Plan versioning: after each completed stage, create new plan version. Collapse done stages to one-line summaries. Update context.md and STATUS.md to point to new version. Old plan versions stay as historical record — rules-047.md Part 0 says do not delete them. See Open Items 14 for the conflict this creates with the orphan gate.
- Tests before examples: examples cannot start until all tests pass all kitchen scripts. Stage N.a = impl + tests, Stage N.b = examples. No mixing.
- Status file ownership. A fact lives in exactly one file; the others get a pointer, not a copy. STATUS.md = current state only, no stage narrative. Plan = forward-looking work + one ledger line per completed stage. STATUS-LOG.md = the narrative. context.md = one short line per doc, saying what it is. Full entry in rules-047.md.

## Constraints for Next Agent (MUST)
- Git disabled. Do NOT run any git commands.
- Coding style: LE imports, explicit types, explicit dereference, stdlib first, errdefer/defer for resource cleanup.
- Doc style: short sentences, bullets, no AI-sh words. See plan Section 1.
- Run verification via kitchen scripts, not manual zig commands.
- A stage that changes design/ must end with kitchen/tools/check_design.sh at exit 0.
- Redirect kitchen script output to zig-out/ log files: `bash kitchen/script.sh > zig-out/script.log 2>&1`. Read the log file. Do NOT analyze shell stdout.
- AI-sh scan after every stage that changes *.md or *.zig.
- Run kitchen/tools/audit_edges.sh after any stage that changes transfer code (send/receive/close/put) or the api doc pages. Compare the four counts against the baseline in audit-recipe-002.md. DISCARDED or unmatched asserts above zero means a rule was skipped. It is not a gate — it always exits 0.

## Sources of Truth
- Doc index: context.md — one line per doc. Start here.
- Concepts and thinking model: matryoshka-concepts-002.md
- API: matryoshka-api-reference-041.md
- Zig details: matryoshka-zig-0.16-notes-003.md
- Architecture: matryoshka-architecture-foundation-4-006.md
- Vocabulary: language-of-matryoshka.md
- Tests: task1-tests-007.md (Layers 1-3), task2-tests-003.md (Layer 4)
- Examples: task1-examples-006.md, task2-examples-007.md (index only; full description lives in each source file's `///` doc comment)
- Legacy mailbox: /home/g41797/dev/root/github.com/g41797/mailbox/
- Odin proto: /home/g41797/dev/root/github.com/g41797/matryoshka/
- tofu (build infra): /home/g41797/dev/root/github.com/g41797/tofu/
- Plan: matryoshka-tk-implementation-plan-070.md (slim, state-only)
- Rules: rules-047.md
- API 13 (the book) design note: api-13-book-002.md
- API 13 carry-over note: api-13-carryover-004.md — what left the book, input for 13-2
- Receive router design note: receive-router-002.md
- Table dispatch design note: table-dispatch-002.md
- API 12 (real pointers for Mbox/Pool) design note: api-12-real-pointers-005.md
- ItemList / intrusive safety design: item-list-011.md
- Patterns: patterns-028.md
- Diagram style: matryoshka-Tk-diagram-style-guide-003.md
- Session narrative: STATUS-LOG.md
- Frozen material: secondary/context.md — snapshots, drafts, session logs, unstarted intentions. Includes the Odin idiom mapping and the pointer-switch compiler bug.
- Markdown hard-break tooling: kitchen/tools/fix_md_hardbreaks.sh, rule documented in rules-047.md
- design/ gate: kitchen/tools/check_design.sh — dead links in both syntaxes, orphans, forward-tense prose, glossary conformance. Run it after any stage that touches design/.
- Give-back audit: audit-recipe-002.md + kitchen/tools/audit_edges.sh. Reports, not a gate. Run it before auditing a layer.

## Participants
- Owner(g41797-human): design, decision-making
- Claude: implementation, tests

## Project
Item-transfer and lifecycle toolkit for Zig 0.16.  
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
│   ├── build_core_debug.sh    src + direct Mbox/Pool callers, fast
│   └── build_cross_debug.sh
└── design/
    ├── STATUS.md
    ├── context.md          doc index — start here
    ├── *.md                the current picture of Matryoshka
    ├── stories/            finished stories
    └── secondary/          frozen: snapshots, drafts, logs, intentions
```

## Decisions
- STATUS.md first, updated after every stage.
- Document rules apply to all markdown.
- condition_waitTimeout copied from legacy mailbox (Open Item 5).
- Tests check implementation. Examples show real usage patterns and stress-test.
- Examples have test wrappers. Examples come after tested code.
- Scenarios re-partitioned into tests + examples (Stage 0.5).
- Helper code (NodeMixin, Event, Sensor) developed in same stage as the code it supports.

## Open Items
- 14 Rules conflict, unresolved. `rules-047.md` Part 0 says "Old plan versions
  stay as historical record. Do not delete them." `check_design.sh` reports any
  unreferenced `design/` file as an ORPHAN and exits 1. A kept old plan version
  is unreferenced, so the two rules cannot both hold. Every past session resolved
  it by deleting, against the rule. Owner's call.
- 5  condition_waitTimeout workaround
- 6  Io.Evented backend not tested
- 10 which Layer 2-3 examples need real threads
- 11 panic test style in Zig
- 12 real-Io examples are integration tests, gate by platform
- 13 rare ReleaseSmall race in pool_fan_in (053) — see Session Log 2026-07-03 for full trace. Suspected upstream Zig 0.16 `Io.Threaded` bug, not app code. Not reproducible outside stress loop.

## Current state

Green across the board. `zig build test` passes **195/195**. `zig build  
stories` passes and runs the transcoder narrative end to end.  
`build_and_test_all.sh` passes in Debug, ReleaseSafe, ReleaseFast and  
ReleaseSmall; `build_cross_debug.sh` passes for x86_64-macos, aarch64-macos  
and x86_64-windows. `build_core_debug.sh` and `check_design.sh` exit 0.

`src/`, `tests/`, `examples/`, `stories/`, `kitchen/docs/` and `design/` all  
speak the pointer API. API 12 is closed.

The mailbox keeps items, it never touches them — so everything it keeps goes  
back to a caller, and releasing it is the caller's job. That statement now sits in  
`src/mailbox.zig`, the concept and api pages, and the API reference, with  
the mirror statements for Pool. `_ = mbx.close()` appears nowhere.

The give-back audit is repeatable: `kitchen/tools/audit_edges.sh` for the  
inventory, audit-recipe-002.md for the method.

The banned-word list is enforced across every live file, not only changed  
ones. Part 5 of rules-047.md carries the scan scope: `STATUS-LOG.md`,  
`design/secondary/` and `kitchen/defer/` are out, and a new changelog row may  
not name the word it removed — `check_design.sh` rejects it.

The usual flow of both containers is written down. `Usual flow` in the api  
reference is the canonical text: create, use, close, destroy for a mailbox,  
and the same with `init(hooks)` for a pool. Close before destroy, always;  
`destroy` is not optional. `lifecycle` is a banned word, and so are `hands`  
and `holds` in the custody sense.

The api reference is a book. matryoshka-api-reference-041.md, seven parts,  
2024 lines against the old 2066. 22 flat `##` headings became 8. Parts 3, 4  
and 5 carry the same five pieces in the same order: what this is,  
participants, usual flow, the API in named groups, where to go deeper.

Part 1 states what Matryoshka is and what it is not. Part 2 gives the three  
Zig mechanisms the toolkit is built out of — intrusion, type erasure, and the  
`*Node`-plus-`@fieldParentPtr` handle the book calls `ParentHandle`. Part 2  
comes first so Part 3 is cheap to read; `ItemHandle` is introduced in Part 3  
as the same idea with a tag added.

Every snippet in Parts 2 through 5 is extracted from a file a kitchen script  
already builds, and names its source. Part 2's specimen is a new permanent  
test, `tests/zig_mechanisms.zig`, whose header says it exists for the book.

`ParentHandle` has a glossary entry in language-of-matryoshka.md.

Part 6 holds the cross-tool material in four sections: identity across the  
tools, the slot rule, concurrency and cancel, what the toolkit assumes. The  
eleven sections it groups keep their text; they moved one level down and into  
their group.

The detail is in the code, and only there. All 43 carry-over rows are `///` or  
`//!` comments in `src/polynode.zig`, `src/mailbox.zig` and `src/pool.zig`.  
The book kept the preconditions and shed the mechanism: no `Assert:` block  
survives in it, and neither does the reasoning about which check is blind to  
what, what a safety build costs, or why hook reentrancy is banned. What a caller  
must satisfy before calling stays, as prose.

Three things stayed against their carry-over row, by the owner's ruling: the OOB  
ordering diagram, the two-`popFirst` warning, and the two contracts a reader  
designs around — waiter order is not FIFO, and put-then-get promises nothing.

api-13-carryover-004.md is the record of the move. Section 2 is discharged from  
both ends. Section 3 — the slogan register and the `lifecycle` footprint — is  
still live, so the note stays in `design/`.

Each of the four `src/` files points at its own examples root on the docs site,  
and every one of them also points at `/examples/flow/`. Roots only, never a file  
path. No snippet lives in `src/`.

The four `//!` headers are modelled on `std.Io`'s: identity, bullets, links,  
no `#` sections. `mailbox.zig` is 26 lines and `pool.zig` 25, down from 52 and  
49. The closedness and release rules moved onto `close`, `destroy`, `put` and  
`put_all`, where most of them already were.

Every public declaration in `src/` opens with a line saying what it does. Six  
mailbox functions used to open with the same sentence about `error.Closed`, so  
the autodoc module page showed six identical rows.

`hands` and `holds` in the custody sense are gone from `src/` and from the  
documents that contradicted it. The Hold vocabulary in the architecture doc is  
out of scope by the owner's ruling — it replaced a banned family of words and  
names sections and the `HELD` state.

Last completed stage: API 13-4b-1, 2026-08-13 — close-out incomplete, see Next.  
Current plan: matryoshka-tk-implementation-plan-070.md.

## Next

**OWNER WORK IN FLIGHT — do not touch `src/*.zig` doc comments.** The owner is
editing `src/` comments by hand, and possibly
[matryoshka-api-reference-041.md](matryoshka-api-reference-041.md). Ask before
rewording anything in either. Comment edits already landed by the owner in
`src/polynode.zig`, `src/mailbox.zig` and `src/pool.zig` are theirs and stay.

**13-1 through 13-4b-1 are done, but 13-4 is not closed to the letter.** Six
steps of the Part 0 finish checklist in [rules-047.md](rules-047.md) were not
run for this stage:

- 2 and 3 — `build_and_test_all.sh` (four optimization modes) and
  `build_cross_debug.sh`. Only `build_and_test_debug.sh` was run. Part 0 says a
  stage is complete only when all four modes pass.
- 6 — scan changed `.zig` files for patterns not yet in patterns-028.md.
- 7 — banned-word scan over changed `*.md` and `*.zig`.
- 9 — sync `README.md` and any touched per-module README.
- 10 — rules audit of every changed file against every rule.

Run these before starting new work. Steps 6, 7 and 10 report to the owner and
fix nothing without approval.

**13-4b-2 is dropped, not done.** It was defined from symmetry with 13-4a, and a
scan found no work in it: one long line in
`kitchen/docs/addendums/intrusion-type-erasure.md`, and one multi-fact sentence
in a generated page. The kitchen pages were written in staccato and never
accumulated the prose `src/` did. The one long line goes to 13-5.

**NO STAGE IS AUTHORIZED.** The candidates below are a menu, not a queue. The
owner names the next stage. Finishing the 13-4 close-out does not roll into
anything — stop and ask. A heading in this file that reads like an ordering is
not an instruction to start.

Candidates, with what each costs:

- **13-4b-3** — the prose pass over `design/`. The versioning rule makes it the
  expensive half: every doc touched needs a new version plus a link cascade, and
  a bulk repoint must name its files and exclude `STATUS-LOG.md`.
- **13-5 — the book governs** every other doc, and reconciles the kitchen pages
  against it. Also carries the one long line left by the dropped 13-4b-2.
- **`polynode` audit** — never audited, and the other two layers stand on it.
- The rest of the deferred pool, further down this section.

**Recommendation on record, 2026-08-13:** the `polynode` audit is worth more than
13-4b-3 or 13-5. Two audited layers stand on an unaudited one. That is a
correctness gap; 13-4b-3 is polish with a heavy versioning tax. The owner has not
ruled on this.

**Three code-level findings from the 13-4 cleanup are reported, not actioned.**
Two duplicated blocks in `src/pool.zig` and one shared `Io.Timeout` construction
in `src/mailbox.zig` and `src/pool.zig`. Each changes code, so each needs its own
approval. In the 2026-08-13 post-stage cleanup entry of STATUS-LOG.md.

**The rendered autodoc page has not been viewed.** The plan makes it the
verification for 13-4. Autodocs regenerate green and `sources.tar` carries the
edits, but nobody has looked at the page. `kitchen/tools/preview_apidocs.sh`.

**`handle` vs `item` in `mailbox.zig` body text is undecided.** The summary lines
say "item"; the bodies still run 29 to 18 for "handle", against a repo that runs
6:1 the other way.

**FLOW is postponed.** FLOW 1-2 and FLOW 1-3 are not the next work. Owner's  
call, 2026-08-13. Their scope is unchanged and still in the plan.

The list below is the remaining candidate pool, owner's call on order.

- Pool re-audit — 69 bare `pl.put(&slot)` statements, unaudited.
- `polynode` audit — never audited, and the other two layers stand on it.
- Diagram-notation scan.
- Showcase-post variants (Ziggit, Discord, Reddit).
- Editorial/conceptual prose pass from REBRAND (README intro, manifesto).
- Rename `examples/layer1/022-ownership_transfer.zig` — banned word in a file
  name. Needs `git mv` and cascades into the generated page and  
  `task1-examples`. Owner-only.
- DISPATCH 1 leftover: run the repro matrix on zig 0.15.2, get a real
  0.17.0-dev diagnostic, file the bug upstream to ziglang/zig.

Live findings not yet actioned are in the plan's "Reported, not actioned".

## History

- One line per completed stage: the plan's "Completed stages" list.
- Full narrative, by date: [STATUS-LOG.md](STATUS-LOG.md).

This file carries neither.
