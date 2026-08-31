# matryoshka-tk STATUS

## PARKED WORK — read before naming a stage

INTR 8 was an unplanned insertion, an API revision ahead of everything on the  
menu below. It is closed, 2026-08-14. This work was parked at its start and is  
still parked:

- The API 13-4 close-out. Four Part 0 checklist steps are unrun — 6, 7, 9 and
  10. Steps 2 and 3 have since passed green twice. Detail: Next.
- 13-4b-3, 13-5 and the `polynode` audit. Candidates, unranked. Detail: Next.
- Three code-level findings, reported and not actioned. Detail:
  [the plan](matryoshka-tk-implementation-plan-072.md), "Reported, not actioned".
- The rendered autodoc page is unviewed. It is the verification for 13-4.
- `handle` vs `item` in `mailbox.zig` body text is undecided.

An audit follows INTR 8, which is now done. It ranks these, and the ruling goes  
into Next.

This block goes when that audit has ruled and Next carries the result. Not on a  
date. Nothing listed here is authorized, and this block authorizes nothing.

## Start here — every session, before anything else

1. Read this file in full. It is current state: what is done, what is in
   flight, what is authorized.
2. Read Part 0 of [rules-049.md](rules-049.md).
3. Read the plan, [matryoshka-tk-implementation-plan-072.md](matryoshka-tk-implementation-plan-072.md),
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
- No git directly, in this or any other repo. Owner does git. Exception: plain `git status` may be run without asking; every other git command still needs the owner or explicit one-off approval.
- No skipping stages. Each stage passes before the next.
- No real code before infrastructure (Stage 0) is verified.
- Show intent before code changes. Get owner approval.
- Plan approval is NOT code change approval.
- Architectural changes need explicit owner approval.
- Never overwrite any doc. New version with incremented suffix (-001, -002, etc.). Update cross-references. Applies to all docs, no exceptions.
- Where a doc lives. `design/` is the current picture of Matryoshka, present tense. Snapshots, superseded drafts, session logs and unstarted intentions go to `design/secondary/` and are frozen. `kitchen/defer/` is frozen too — deferred material, absent from mkdocs nav, its snippets predate API 12. Every file is listed in `context.md` or `secondary/context.md`. Full entry in rules-049.md.
- Post-stage cleanup: after all kitchen scripts pass, revise all code for obsolete parts, wrong comments, repeated code extractable to reusable sources. Fix, re-run all three scripts. Session log must have a "Post-stage cleanup" row — its absence means the rule was skipped.
- Plan versioning: after each completed stage, create new plan version. Collapse done stages to one-line summaries. Update context.md and STATUS.md to point to new version. Old plan versions stay as historical record — rules-049.md Part 0 says do not delete them, and they are listed in the Superseded versions section of context.md so the orphan gate passes. See Open Item 14.
- Tests before examples: examples cannot start until all tests pass all kitchen scripts. Stage N.a = impl + tests, Stage N.b = examples. No mixing.
- Status file ownership. A fact lives in exactly one file; the others get a pointer, not a copy. STATUS.md = current state only, no stage narrative. Plan = forward-looking work + one line per completed stage. STATUS-LOG.md = the narrative. context.md = one short line per doc, saying what it is. Full entry in rules-049.md.

## Constraints for Next Agent (MUST)
- Git disabled, in every repo, always. Do NOT run any git commands except plain `git status`, which is allowed on its own.
- Coding style: LE imports, explicit types, explicit dereference, stdlib first, errdefer/defer for resource cleanup.
- Doc style: short sentences, bullets, no AI-sh words. See plan Section 1.
- Run verification via kitchen scripts, not manual zig commands.
- A stage that changes design/ must end with kitchen/tools/check_design.sh at exit 0.
- Redirect kitchen script output to zig-out/ log files: `bash kitchen/script.sh > zig-out/script.log 2>&1`. Read the log file. Do NOT analyze shell stdout.
- AI-sh scan after every stage that changes *.md or *.zig.
- Run kitchen/tools/audit_edges.sh after any stage that changes transfer code (send/receive/close/put) or the api doc pages. Compare the four counts against the baseline in audit-recipe-002.md. DISCARDED or unmatched asserts above zero means a rule was skipped. It is not a gate — it always exits 0.

## Sources of Truth
- Doc index: context.md — one line per doc. Start here.
- Concepts and thinking model: matryoshka-concepts-003.md
- API: matryoshka-api-reference-042.md
- Zig details: matryoshka-zig-0.16-notes-003.md
- Architecture: matryoshka-architecture-foundation-4-006.md
- Vocabulary: language-of-matryoshka.md
- Tests: task1-tests-008.md (Layers 1-3), task2-tests-004.md (Layer 4)
- Examples: task1-examples-006.md, task2-examples-007.md (index only; full description lives in each source file's `///` doc comment)
- Legacy mailbox: /home/g41797/dev/root/github.com/g41797/mailbox/
- Odin proto: /home/g41797/dev/root/github.com/g41797/matryoshka/
- tofu (build infra): /home/g41797/dev/root/github.com/g41797/tofu/
- Plan: matryoshka-tk-implementation-plan-072.md (slim, state-only)
- Rules: rules-049.md
- API 13 (the book) design note: api-13-book-002.md
- API 13 carry-over note: api-13-carryover-004.md — what left the book, input for 13-2
- Receive router design note: receive-router-002.md
- Table dispatch design note: table-dispatch-002.md
- API 12 (real pointers for Mbox/Pool) design note: api-12-real-pointers-005.md
- ItemList / intrusive safety design: item-list-011.md
- Patterns: patterns-029.md
- Diagram style: matryoshka-Tk-diagram-style-guide-003.md
- Session narrative: STATUS-LOG.md
- Frozen material: secondary/context.md — snapshots, drafts, session logs, unstarted intentions. Includes the Odin idiom mapping and the pointer-switch compiler bug.
- Markdown hard-break tooling: kitchen/tools/fix_md_hardbreaks.sh, rule documented in rules-049.md
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
- Superseded doc versions are kept and listed. Owner's ruling, 2026-08-14,
  closing Open Item 14. A superseded version stays on disk and gets one line in  
  the **Superseded versions** section of [context.md](context.md), naming what  
  replaced it. Nothing in `design/` is deleted to satisfy the orphan gate.  
  Part 0's "do not delete" and `check_design.sh` both hold. The section grows by  
  one line per superseded doc, and that cost is accepted.

## Open Items
- 5  condition_waitTimeout workaround
- 6  Io.Evented backend not tested
- 10 which Layer 2-3 examples need real threads
- 11 panic test style in Zig
- 12 real-Io examples are integration tests, gate by platform
- 13 rare ReleaseSmall race in pool_fan_in (053) — see Session Log 2026-07-03 for full trace. Suspected upstream Zig 0.16 `Io.Threaded` bug, not app code. Not reproducible outside stress loop.

## Current state

**INTR 8-3 has landed, and INTR 8 is closed.** The documents speak Slot-based  
creation. `check_design.sh` exits 0.

**The tree is green in every gate.** All four optimization modes 195/195,  
`build_cross_debug.sh` green for x86_64-macos, aarch64-macos and  
x86_64-windows, `zig build stories` green, `kitchen/build_core_debug.sh` green.  
`zig fmt --check` is clean across `tests/`, `examples/` and `stories/`.

Six new versions carry the change: matryoshka-api-reference-042.md,  
patterns-029.md, task1-tests-008.md, task2-tests-004.md, rules-049.md and  
intr-8-slot-based-creation-003.md. matryoshka-concepts-003.md carries the new  
vocabulary; `language-of-matryoshka.md` was edited in place, owner's ruling,  
2026-08-14.

Both tools now read the same four steps. The pool's `Usual flow` lost its  
`init` step, because the hooks are a parameter of `new` and there is no second  
call that arms a pool.

`context.md` has a **Superseded versions** section. Every kept old version is  
listed there, so the orphan gate passes and nothing is deleted. See Open  
Item 14.

The two classes of item are named in three places: Chapter 4 of the concepts  
doc, the glossary, and the design note that found them. Application items flow  
constantly and get the full `PolyHelper` surface. Infrastructure items are  
`Mbox` and `Pool`, they travel rarely, and they declare `no_create_destroy`.

Part 1 of rules-049.md now says how a Master acquires a mailbox or a pool: one  
Slot per resource, local to `init`, the detach on the next line, the  
`errdefer` after it, the field non-optional.

`mailbox.new` and `pool.new` fill a Slot everywhere. 186 call sites in 70 files,  
and the 39 separate `pl.init(hooks)` lines are gone — a pool is one call.

A Master acquires into a local Slot and detaches on the next line. The field  
stays `*Mbox` / `*Pool`; the unwrap is once, at creation. Owner's ruling,  
2026-08-14, against the design note's `?*Mbox`, which would have edited 202  
field reads to encode a state that never occurs. `examples/layer4/018-master_with_pool.zig`  
is the exemplar and was approved before the other Masters were touched, because  
Part 1 of [rules-049.md](rules-049.md) names it as the canonical Master.

`destroy_slot` has callers: scenarios 93 and 94 in `tests/layer4_infra.zig`  
close the received item, then release it through the Slot. Before, `destroy`  
left the Slot pointing at freed memory.

A pool can no longer exist without hooks. Six sites created one; five got a  
hook set, and the sixth — scenario 8 in `tests/layer4_cancel.zig` — changed  
meaning by the owner's ruling, because a pool closed before it was initialized  
is no longer constructible.

Reported, not fixed: `src/pool.zig` fails `zig fmt --check` on a stray blank  
line at 342. It is 8-1's file and carries owner edits, so it was left alone.

`src/`, `tests/`, `examples/`, `stories/`, `kitchen/docs/` and `design/` all  
speak the pointer API. API 12 is closed.

The mailbox keeps items, it never touches them — so everything it keeps goes  
back to a caller, and releasing it is the caller's job. That statement now sits in  
`src/mailbox.zig`, the concept and api pages, and the API reference, with  
the mirror statements for Pool. `_ = mbx.close()` appears nowhere.

The give-back audit is repeatable: `kitchen/tools/audit_edges.sh` for the  
inventory, audit-recipe-002.md for the method.

The banned-word list is enforced across every live file, not only changed  
ones. Part 5 of rules-049.md carries the scan scope: `STATUS-LOG.md`,  
`design/secondary/` and `kitchen/defer/` are out, and a new changelog row may  
not name the word it removed — `check_design.sh` rejects it.

The usual flow of both containers is written down. `Usual flow` in the api  
reference is the canonical text. Close before destroy, always; `destroy` is not  
optional. It is stale in one respect: a pool no longer has an `init(hooks)`  
caller step. 8-3 fixes the text.

The api reference is a book. matryoshka-api-reference-042.md, seven parts,  
2024 lines against the old 2066. 22 flat `##` headings became 8. Parts 3, 4  
and 5 carry the same five pieces in the same order: what this is,  
participants, usual flow, the API in named groups, where to go deeper.

Part 1 states what Matryoshka is and what it is not. Part 2 gives the three  
Zig mechanisms the toolkit is built out of — intrusion, type erasure, and the  
`*Node`-plus-`@fieldParentPtr` handle the book calls `ParentHandle`.

Every snippet in Parts 2 through 5 is extracted from a file a kitchen script  
already builds, and names its source. Part 2's specimen is a permanent test,  
`tests/zig_mechanisms.zig`. Ten snippets in Parts 4 and 5 are now stale against  
`src/`; 8-3 fixes them.

Part 6 holds the cross-tool material in four sections: identity across the  
tools, the slot rule, concurrency and cancel, what the toolkit assumes.

The detail is in the code, and only there. All 43 carry-over rows are `///` or  
`//!` comments in `src/polynode.zig`, `src/mailbox.zig` and `src/pool.zig`.  
The book kept the preconditions and shed the mechanism.

api-13-carryover-004.md is the record of the move. Section 2 is discharged from  
both ends. Section 3 — the slogan register and the `lifecycle` footprint — is  
still live, so the note stays in `design/`.

Each of the four `src/` files points at its own examples root on the docs site,  
and every one of them also points at `/examples/flow/`. No snippet lives in `src/`.

The four `//!` headers are modelled on `std.Io`'s: identity, bullets, links,  
no `#` sections. Every public declaration in `src/` opens with a line saying  
what it does.

`hands` and `holds` in the custody sense are gone from `src/` and from the  
documents that contradicted it. The Hold vocabulary in the architecture doc is  
out of scope by the owner's ruling.

Last completed stage: INTR 8-3, 2026-08-14.  
Current plan: matryoshka-tk-implementation-plan-072.md.

## Next

**INTR 8 is closed. 8-1, 8-2 and 8-3 are all done, 2026-08-14.** `src/`, then  
every caller, then the documents.

**Nothing is authorized.** The owner names the stage.

**The audit that ranks the parked work is the recommended next step.** Its input  
is the PARKED WORK block at the top of this file. Its output is a ruling, which  
goes into this section and lets that block be deleted. It changes no code.

The candidates, what each costs, and the recommendation on record are in  
[the plan](matryoshka-tk-implementation-plan-072.md) under "Next". They are a  
menu, not a queue. Finishing one does not roll into the next — stop and ask. A  
heading that reads like an ordering is not an instruction to start.

**OWNER EDITS IN `src/*.zig` DOC COMMENTS — leave them alone.** The comment  
edits in `src/polynode.zig`, `src/mailbox.zig` and `src/pool.zig`, and the edits  
in [matryoshka-api-reference-042.md](matryoshka-api-reference-042.md), are the  
owner's own and stay as they are. Ask before rewording anything in either.

**FLOW is postponed.** FLOW 1-2 and FLOW 1-3 are not the next work. Owner's  
call, 2026-08-13. Their scope is unchanged and in the plan.

## History

- One line per completed stage: the plan's "Completed stages" list.
- Full narrative, by date: [STATUS-LOG.md](STATUS-LOG.md).

This file carries neither.
