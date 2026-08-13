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
- Where a doc lives. `design/` is the current picture of Matryoshka, present tense. Snapshots, superseded drafts, session logs and unstarted intentions go to `design/secondary/` and are frozen. `kitchen/defer/` is frozen too — deferred material, absent from mkdocs nav, its snippets predate API 12. Every file is listed in `context.md` or `secondary/context.md`. Full entry in rules-046.md.
- Post-stage cleanup: after all kitchen scripts pass, revise all code for obsolete parts, wrong comments, repeated code extractable to reusable sources. Fix, re-run all three scripts. Session log must have a "Post-stage cleanup" row — its absence means the rule was skipped.
- Plan versioning: after each completed stage, create new plan version. Collapse done stages to one-line summaries. Update context.md and STATUS.md to point to new version.
- Tests before examples: examples cannot start until all tests pass all kitchen scripts. Stage N.a = impl + tests, Stage N.b = examples. No mixing.
- Status file ownership. A fact lives in exactly one file; the others get a pointer, not a copy. STATUS.md = current state only, no stage narrative. Plan = forward-looking work + one ledger line per completed stage. STATUS-LOG.md = the narrative. context.md = one short line per doc, saying what it is. Full entry in rules-046.md.

## Constraints for Next Agent (MUST)
- Git disabled. Do NOT run any git commands.
- Coding style: LE imports, explicit types, explicit dereference, stdlib first, errdefer/defer for resource cleanup.
- Doc style: short sentences, bullets, no AI-sh words. See plan Section 1.
- Run verification via kitchen scripts, not manual zig commands.
- A stage that changes design/ must end with kitchen/tools/check_design.sh at exit 0.
- Redirect kitchen script output to zig-out/ log files: `bash kitchen/script.sh > zig-out/script.log 2>&1`. Read the log file. Do NOT analyze shell stdout.
- AI-sh scan after every stage that changes *.md or *.zig.
- Run kitchen/tools/audit_edges.sh after any stage that changes transfer code (send/receive/close/put) or the api doc pages. Compare the four counts against the baseline in audit-recipe-001.md. DISCARDED or unmatched asserts above zero means a rule was skipped. It is not a gate — it always exits 0.

## Sources of Truth
- Doc index: context.md — one line per doc. Start here.
- Concepts and thinking model: matryoshka-concepts-002.md
- API: matryoshka-api-reference-040.md
- Zig details: matryoshka-zig-0.16-notes-003.md
- Architecture: matryoshka-architecture-foundation-4-006.md
- Vocabulary: language-of-matryoshka.md
- Tests: task1-tests-007.md (Layers 1-3), task2-tests-003.md (Layer 4)
- Examples: task1-examples-006.md, task2-examples-007.md (index only; full description lives in each source file's `///` doc comment)
- Legacy mailbox: /home/g41797/dev/root/github.com/g41797/mailbox/
- Odin proto: /home/g41797/dev/root/github.com/g41797/matryoshka/
- tofu (build infra): /home/g41797/dev/root/github.com/g41797/tofu/
- Plan: matryoshka-tk-implementation-plan-069.md (slim, state-only)
- Rules: rules-046.md
- API 13 (the book) design note: api-13-book-002.md
- API 13 carry-over note: api-13-carryover-003.md — what left the book, input for 13-2
- Receive router design note: receive-router-002.md
- Table dispatch design note: table-dispatch-002.md
- API 12 (real pointers for Mbox/Pool) design note: api-12-real-pointers-005.md
- ItemList / intrusive safety design: item-list-010.md
- Patterns: patterns-027.md
- Diagram style: matryoshka-Tk-diagram-style-guide-003.md
- Session narrative: STATUS-LOG.md
- Frozen material: secondary/context.md — snapshots, drafts, session logs, unstarted intentions. Includes the Odin idiom mapping and the pointer-switch compiler bug.
- Markdown hard-break tooling: kitchen/tools/fix_md_hardbreaks.sh, rule documented in rules-046.md
- design/ gate: kitchen/tools/check_design.sh — dead links in both syntaxes, orphans, forward-tense prose, glossary conformance. Run it after any stage that touches design/.
- Give-back audit: audit-recipe-001.md + kitchen/tools/audit_edges.sh. Reports, not a gate. Run it before auditing a layer.

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

The mailbox holds, it never touches — so everything it holds goes back to a  
caller, and releasing it is the caller's job. That statement now sits in  
`src/mailbox.zig`, the concept and api pages, and the API reference, with  
the mirror statements for Pool. `_ = mbx.close()` appears nowhere.

The give-back audit is repeatable: `kitchen/tools/audit_edges.sh` for the  
inventory, audit-recipe-001.md for the method.

The banned-word list is enforced across every live file, not only changed  
ones. Part 5 of rules-046.md carries the scan scope: `STATUS-LOG.md`,  
`design/secondary/` and `kitchen/defer/` are out, and a new changelog row may  
not name the word it removed — `check_design.sh` rejects it.

The usual flow of both containers is written down. `Usual flow` in the api  
reference is the canonical text: create, use, close, destroy for a mailbox,  
and the same with `init(hooks)` for a pool. Close before destroy, always;  
`destroy` is not optional. `lifecycle` and `hands` are banned words.

The api reference is a book. matryoshka-api-reference-040.md, seven parts,  
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

api-13-carryover-003.md is the record of the move. Section 2 is discharged from  
both ends. Section 3 — the slogan register and the `lifecycle` footprint — is  
still live, so the note stays in `design/`.

Each of the four `src/` files points at its own examples root on the docs site,  
and every one of them also points at `/examples/flow/`. Roots only, never a file  
path. No snippet lives in `src/`.

Last completed stage: API 13-3, 2026-08-13.  
Current plan: matryoshka-tk-implementation-plan-069.md.

## Next

**API 13-1, 13-2 and 13-3 are done.** The book has all seven parts, the code
carries the detail, and the book no longer repeats it.

**Next is 13-4 — the prose pass.** Owner's decision, 2026-08-13: `src/*.zig` and
the documents both read as prose in places. Its own stage, not a post-stage
cleanup row. Scope in the plan: the four `//!` headers against the `std.Io`
model, `///` blocks that name more than one fact per sentence, and the voice
calls that are the owner's to make rather than the agent's. Verification is the
rendered autodoc page, not the source.

Then 13-5 — the book governs every other doc, and reconciles the kitchen pages
against it.

**Two findings are open, both the owner's.** The slogan register, five sites.
The `lifecycle` footprint, six sites left under `design/` and `src/` plus 17
under `kitchen/docs/`. Section 3 of api-13-carryover-003.md.

**Two counts in live documents are wrong.** `rules-046.md` Part 4 says seven
`!is_linked` asserts in `src/`; a live count on 2026-08-13 found eight textual
sites across seven distinct ones. Section 5 of the carry-over note.

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
