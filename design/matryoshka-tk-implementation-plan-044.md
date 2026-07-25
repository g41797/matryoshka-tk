# Matryoshka Zig — Implementation Plan (044)

Replaces [matryoshka-tk-implementation-plan-043.md](matryoshka-tk-implementation-plan-043.md).

## Status

API 5 (Composite Items — pool `on_put` returns a list) complete: 5a code  
change, 5b test coverage, 5c docs, 5d comment/doc restructure, all done.  
Follow-up bugfix (popFirst stale-link) also done.

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
  `io.concurrent()`, architecture-docs ownership-language pass): DONE.  
  167/167 tests unchanged throughout.
- LANDING 1: src/ LOC counter + badge next to API button on
  `kitchen/docs/index.md`; shared logic in `kitchen/tools/src_loc.py`. DONE  
  (doc/tooling-only, 167/167 tests unchanged).
- REBRAND — repo rename to matryoshka-tk. Mechanical pass + deferred-item
  verification. DONE (doc-only, 167/167 tests unchanged). Deferred  
  editorial/conceptual prose pass remains owner's call, not actioned.
- API 5a — Composite Items: `PoolHooks.on_put` returns
  `?std.DoublyLinkedList` (was `void`); `slot` behavior unchanged; new  
  `_add_returned_item` helper adds the slot item and every  
  returned-list node the same way, one broadcast per `put`; foreign tag  
  now a hard assert. All existing `on_put` hook implementations updated  
  to the new signature, returning `null`. DONE (167/167 tests unchanged).
- API 5b — new scenario 89 in `tests/layer3_pool.zig`: `on_put` keeps the
  Event via `slot` and hands back a fresh Sensor via the returned list;  
  verified both land in the correct per-tag free-lists and are  
  retrievable. DONE (168/168 tests, +1 new).
- API 5c — short doc update: `kitchen/docs/api/pool/put.md`,
  `hooks-discipline.md`, and orphaned `kitchen/docs/api/pool.md` document  
  `on_put`'s `?std.DoublyLinkedList` return value, stressing hook-author  
  responsibility. `matryoshka-api-reference-025.md` → `-026.md`  
  (no-overwrite rule), cross-references updated. DONE (168/168 tests  
  unchanged, `mkdocs build --strict` clean).
- API 5 follow-up — fixed a `put` returned-list bug: `popFirst` leaves the
  popped node's own `prev`/`next` stale, so `_add_returned_item`'s  
  `is_linked` assert panicked for composite lists of 3+ items. Reproduced  
  first (scenario 89 extended to 3 items), then fixed with  
  `polynode.reset(poly)` after `popFirst`. DONE (168/168 tests unchanged).
- API 5d — trimmed `on_put`/`put`'s `src/pool.zig` doc comments to the
  mechanical contract only; moved composite-items rationale into a  
  dedicated "Composite Items" doc section (`kitchen/docs/api/pool/put.md`,  
  orphaned `pool.md`, `matryoshka-api-reference-026.md`). Signature  
  unchanged (`?std.DoublyLinkedList` return value kept, out-param  
  alternative rejected). DONE (168/168 tests unchanged).

See `design/STATUS.md` Session Log for full per-stage detail — this plan file  
stays state-only per the slim-plan rule.

---

## Next

### CANDIDATES — composed docs from candidate audit (not started)

Owner wants central-understanding docs composed from the large, scattered  
`.md` corpus (old-mindset and new-mindset material mixed): `README.md`  
(repo root), doc-site landing pages (short + long variants). Showcase/post  
variants (Ziggit, Discord, Reddit) are deferred to a later stage — different  
audience/tone/timing concerns, premature to scope now.

Existing untracked drafts in `kitchen/docs/misc/` (`README-15-07-2026.md`,  
`readme-landing.md`, `how-matryoshka-system-works.md`, `matryoshka-tk-ads.md`,  
`what-is-matryoshka-tk.md`) are INPUT material for audit, not finished  
deliverables — same status as every other `.md` in the repo.

All new candidate/composed docs go in a new `design/candidates/` folder,  
each file versioned (no-overwrite rule applies).

Scope:
- Search recursively across the **entire repo tree** for `.md` files, not
  just `design/` — includes `kitchen/docs/**`, `README.md`, everything.
- All `.md` files are audit input, no exceptions.
- Three-pass approach:
  1. **Audit** — per file: old/new-mindset/mixed/neutral tag, plus a short
     bullet list of extractable ideas/phrases worth reuse, plus which target  
     doc(s) each idea likely feeds. Produces a reusable idea index, not just  
     a filter.
     - Early-discard rule: triage fast (skim, not close-read). Old-mindset-
       only, superseded (per existing no-overwrite versioning), or  
       zero-extractable-idea files get marked DISCARDED with a one-line  
       reason — no further work on them. To be added as a formal rule in  
       `design/rules-024.md` → next version.
     - Also produces `design/candidates/corpus-index-001.md`: a durable,
       per-file content description (short paragraph + bullets, not a  
       table), for every file that passes triage. Separate purpose from the  
       audit's keep/discard verdict — meant to outlive this stage and feed  
       future doc work (including the deferred showcase-post stage).
  2. **Per-document requirements** — audience, length budget, tone,
     must-include points, "new-mindset only" constraint, for README +  
     landing-short + landing-long.
  3. **Composition** — draft each target doc in `design/candidates/`,
     pulling only from Pass-1-approved new-mindset ideas/sources.

Model choice:
- Pass 1 (audit + corpus index): Sonnet — mechanical skim/tag/extract.
- Pass 3 (composition): Opus subagent for drafting, same precedent as
  DOC 21's diagram+prose drafting.
- Regardless of drafting model: all output must follow existing repo
  documentation rules (rules-024.md) — staccato style, no banned/AI-sh  
  words, no "ownership" framing, versioned filenames, `context.md`/  
  `STATUS.md` cross-references updated. Model choice does not relax any  
  doc rule.

Open (blocking Pass 1 start): confirm whether Pass 1 runs as a background  
subagent sweep (repo-wide read + judgment), given corpus size.

### MDFIX — markdown hard-break rule + tooling (not started, sequenced after CANDIDATES)

Owner flagged a real Markdown rendering bug affecting the repo's staccato  
style (short sentence, then short sentence, CRLF between them):  
CommonMark collapses two lines separated only by a single newline into one  
rendered line (soft break → space) unless the first line ends with at least  
two trailing spaces (hard break), or the two sentences are separated by a  
blank line (separate paragraphs) instead. Same category as the earlier  
blank-line-before-list bug fixed by `kitchen/tools/fix_md_lists.sh`  
(rules-023). Likely widespread across the existing staccato-style doc  
corpus — not yet audited for how many files are affected.

Planned approach:
- Prefer blank-line-separated short paragraphs over same-paragraph line
  breaks wherever the intent is a readable separate line.
- Add an explicit rule to `design/rules-024.md` → next version stating the
  two-trailing-space requirement.
- New auto-fix script, fence-aware like `fix_md_lists.sh`
  (`kitchen/tools/fix_md_hardbreaks.sh`): scans for isolated short lines  
  lacking trailing spaces or a following blank line, converts to a hard  
  break or a blank-line paragraph split. Wire into `build_site.sh`/  
  `preview_site.sh`/CI, same position as the list-fix script.
- Needs its own audit pass first: how many existing files are affected,
  before deciding auto-fix-all vs. targeted fixes.

Open (surfaced by INTR 6 doc pass, still not actioned): stale `helpers/`-path  
references outside that task's scope — `design/patterns-012.md` (2 hits),  
`design/matryoshka-api-reference-021.md` (3 hits), `design/collected-context-005.md`  
(historical, 3 hits), `kitchen/docs/patterns/pool.md` (2 hits),  
`kitchen/docs/api/pool.md` (1 hit). Owner to decide whether/when to update —  
these reference already-superseded doc versions (api-reference-021 →  
current is -025, patterns-012 → current is -015), likely dead per the  
no-overwrite rule, but not yet confirmed dead by a live-pointer grep.
