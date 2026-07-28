# Matryoshka Zig — Implementation Plan (045)

Replaces [matryoshka-tk-implementation-plan-044.md](matryoshka-tk-implementation-plan-044.md).

## Status

EXMPL 5 (receive router — example + pattern docs) complete: 5a design note,  
5b example + test, 5c pattern docs, 5d catalog and nav, 5e cancelDiscard  
audit. 169/169 tests.

---

## Completed stages (summary)

- Stage 0–8: API, tests, examples layers 1–3 done.
- Stage 9 (Layer 4 infrastructure): pool, mailbox, select, group done.
- EXMPL 3a–4c, API 2–4b, DOC 9–20, INTR 6: see plan-040 for full detail.
- DOC 21: "The Shape of a Real System" page + Graphviz diagram tooling.
- INTR 7: pool `on_put` reset convention, "Pool is not storage" doc fix,
  put-semantics documented, 5 wrong-assumption bugs fixed.
- Staccato sweep + "thread" audit: prose-paragraph and stale thread-join
  language fixed repo-wide.
- New Mindset (banned words, Phase A/B/C, code migration `Thread.spawn` →
  `io.concurrent()`, architecture-docs terminology pass): DONE.
- LANDING 1: src/ LOC counter + badge on `kitchen/docs/index.md`.
- REBRAND: repo rename to matryoshka-tk, deferred-item verification. DONE.
  Deferred editorial/conceptual prose pass remains owner's call.
- API 5a–5d + follow-up: Composite Items — `PoolHooks.on_put` returns
  `?std.DoublyLinkedList`; scenario 89; docs to api-reference-026;  
  `popFirst` stale-link bug found and fixed. DONE (168/168 tests).
- MDFIX: markdown hard-break rule + `kitchen/tools/fix_md_hardbreaks.sh`.
  DONE — rule lives in rules-026, script connected to `build_site.sh` and  
  `preview_site.sh`. Listed as "not started" in plan-044; that was stale.
- EXMPL 5a — `design/receive-router-001.md`: use case, outcome table, the two
  rules, the `N >= P + T` precondition, why it is not `src/` API. DONE.
- EXMPL 5b — `examples/layer4/062-receive_router.zig` + barrel entry + test
  wrapper in `tests/layer4_select.zig`. DONE (169/169 tests, +1 new).
- EXMPL 5c — pattern docs: new "Receive router" entry in
  `kitchen/docs/patterns/async.md` and `design/patterns-016.md`;  
  silent-discard behaviour added to `kitchen/docs/addendums/io-101.md`.  
  DONE.
- EXMPL 5d — `gen_examples_docs.sh` regeneration, `kitchen/docs/examples/io.md`
  group page, `kitchen/mkdocs.yml` nav entry. DONE  
  (`mkdocs build --strict` clean).
- EXMPL 5e — cancelDiscard audit across 15 live call sites. No defects. Three
  observations recorded, no code changed. DONE.

See `design/STATUS.md` Session Log for full per-stage detail — this plan file  
stays state-only per the slim-plan rule.

---

## EXMPL 5 — settled design

Settled design and full reasoning: [receive-router-001.md](receive-router-001.md).

### EXMPL 5e — audit result

15 live `cancelDiscard()` call sites in `examples/` and `stories/`. Every one  
is safe at the moment it runs. Three mechanisms:

- Most sites guard re-registration on a target count, so no item-producing
  source is pending when the loop exits.
- `027-select_cancel_master_decides.zig` walks with `sel.cancel()` first. Its
  `defer sel.cancelDiscard()` is a no-op safety net after the walk.
- Three sites are safe because the mailbox is provably empty, not because of
  structure.

Observations, not defects. No code changed.

- `043-select_direct_push.zig:60` — `.inbox` is still pending at
  `cancelDiscard`. Safe only because nothing is ever sent to that mailbox.
- `025-select_two_mailboxes.zig:133` — `.inbox1` re-registers when
  `!got2`, so it can be pending at loop exit. Safe only because exactly one  
  item is sent to `mbh1`.
- `044-select_mailbox_close.zig` — the `.inbox .item` arm neither
  re-registers nor breaks, and the `.timer` arm does not re-register. If an  
  item ever arrived, the next `sel.await()` would have no pending source.  
  A stall, not a leak. Unreachable today because the mailbox is empty.

---

## Next

### CANDIDATES — composed docs from candidate audit (not started)

Owner wants central-understanding docs composed from the large, scattered  
`.md` corpus (old-mindset and new-mindset material mixed): `README.md`  
(repo root), doc-site landing pages (short + long variants). Showcase/post  
variants (Ziggit, Discord, Reddit) are deferred to a later stage.

Existing untracked drafts in `kitchen/docs/misc/` are INPUT material for  
audit, not finished deliverables — same status as every other `.md`.

All new candidate/composed docs go in `design/candidates/`, each file  
versioned (no-overwrite rule applies).

Scope:

- Search recursively across the **entire repo tree** for `.md` files.
- All `.md` files are audit input, no exceptions.
- Three-pass approach:
  1. **Audit** — per file: old/new-mindset/mixed/neutral tag, plus a short
     bullet list of extractable ideas worth reuse, plus which target doc(s)  
     each idea likely feeds.
     - Early-discard rule: triage fast. Old-mindset-only, superseded, or
       zero-extractable-idea files get marked DISCARDED with a one-line  
       reason. To be added as a formal rule in the next `rules-` version.
     - Also produces `design/candidates/corpus-index-001.md`: a durable
       per-file content description, meant to outlive this stage.
  2. **Per-document requirements** — audience, length budget, tone,
     must-include points, for README + landing-short + landing-long.
  3. **Composition** — draft each target doc in `design/candidates/`.

Open (blocking Pass 1 start): confirm whether Pass 1 runs as a background  
subagent sweep, given corpus size.

### Deferred — owner's call on order

- Diagram-notation sweep.
- Mailbox-focused equivalent of the INTR 7 pool audit.
- Showcase-post variants (Ziggit, Discord, Reddit).
- Editorial/conceptual prose pass from REBRAND (README intro, manifesto,
  landing candidates).

### Reported, not actioned

- `Io.Select.awaitMany` is used and documented nowhere in the repo. It is
  the natural pair for any batch-receive work.
- `src/pool.zig` carries an uncommitted owner edit made before this stage
  (`get_wait` doc comment now states "does not call on_get hook"). Not made  
  by this stage. Left alone.
- Stale `helpers/`-path references outside INTR 6's scope:
  `design/patterns-012.md` (2), `design/matryoshka-api-reference-021.md` (3),  
  `design/collected-context-005.md` (3, historical),  
  `kitchen/docs/patterns/pool.md` (2), `kitchen/docs/api/pool.md` (1).  
  These reference already-superseded doc versions.
- Pre-existing banned-word hits in `design/patterns-016.md` inherited from
  `-015` (section title "Slot and ownership idioms", and body uses).  
  Reported per the scan rule, not fixed without approval.
