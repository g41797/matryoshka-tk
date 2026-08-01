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
- Status file ownership. A fact lives in exactly one file; the others get a pointer, not a copy. STATUS.md = current state only, no stage narrative. Plan = forward-looking work + one ledger line per completed stage. STATUS-LOG.md = the narrative. context.md = one short line per doc, saying what it is. Full entry in rules-039.md.

## Constraints for Next Agent (MUST)
- Git disabled. Do NOT run any git commands.
- Coding style: LE imports, explicit types, explicit dereference, stdlib first, errdefer/defer for resource cleanup.
- Doc style: short sentences, bullets, no AI-sh words. See plan Section 1.
- Run verification via kitchen scripts, not manual zig commands.
- Redirect kitchen script output to zig-out/ log files: `bash kitchen/script.sh > zig-out/script.log 2>&1`. Read the log file. Do NOT analyze shell stdout.
- AI-sh scan after every stage that changes *.md or *.zig.

## Sources of Truth
- API: matryoshka-api-reference-033.md
- Zig details: matryoshka-tk-0.16-implementation-guide-001.md
- Architecture: matryoshka-architecture-foundation-4-004.md
- Architecture introduction: matryoshka-architecture-004.md
- Tests: task1-tests-005.md (77 scenarios, Layers 1-3), task2-tests-002.md (16 scenarios, Layer 4)
- Examples: task1-examples-005.md, task2-examples-006.md (index only; full description lives in each source file's `///` doc comment)
- Scenarios (historical): task1-scenarios-001.md (92), task2-scenarios-001.md (61)
- Legacy mailbox: /home/g41797/dev/root/github.com/g41797/mailbox/
- Odin proto: /home/g41797/dev/root/github.com/g41797/matryoshka/
- tofu (build infra): /home/g41797/dev/root/github.com/g41797/tofu/
- Plan: matryoshka-tk-implementation-plan-052.md (slim, state-only)
- Rules: rules-039.md
- Receive router design note: receive-router-001.md
- Table dispatch design note: table-dispatch-001.md
- Pointer-switch compiler bug: llvm-pointer-switch-bug-001.md
- ItemList / intrusive safety design: item-list-009.md
- Session narrative: STATUS-LOG.md
- New Mindset reference: matryoshka-new-mindset-001.md
- Thinking model: matryoshka-model-007.md
- Patterns: patterns-025.md
- Docs plan: matryoshka-tk-docs-plan-015.md
- Manifesto: matryoshka-manifesto-005.md
- Latest context: collected-context-005.md
- Markdown hard-break tooling: kitchen/tools/fix_md_hardbreaks.sh, rule documented in rules-039.md

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

## Current state

192/192 tests across Debug, ReleaseSafe, ReleaseFast and ReleaseSmall.  
Cross-compile to x86_64-windows clean. `mkdocs build --strict` clean.

Last completed stage: CMPCT 2 — rules regrouped into rules-039.md, 2026-08-01.  
Current plan: matryoshka-tk-implementation-plan-052.md.

The last four stages changed nothing in `src/`. They are documentation and  
examples for what the existing blocks already do.

## Next

No stage is chosen. The deferred list is the candidate pool, owner's call on  
order.

- Diagram-notation scan.
- Mailbox-focused equivalent of the INTR 7 pool audit.
- Showcase-post variants (Ziggit, Discord, Reddit).
- Editorial/conceptual prose pass from REBRAND (README intro, manifesto).
- DISPATCH 1 leftover: run the repro matrix on zig 0.15.2, get a real
  0.17.0-dev diagnostic, file the bug upstream to ziglang/zig.

Live findings not yet actioned are in the plan's "Reported, not actioned".

## History

- One line per completed stage: the plan's "Completed stages" ledger.
- Full narrative, by date: [STATUS-LOG.md](STATUS-LOG.md).

This file carries neither.
