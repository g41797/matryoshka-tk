# Matryoshka Zig — Documentation Plan (015)

New version of `matryoshka-tk-docs-plan-014.md`. That version predates the DOC 20  
example-catalog session below. Superseded, not overwritten — see  
`matryoshka-tk-docs-plan-014.md` for the prior version.

---

## Session Log

### 2026-07-08 — DOC 20 session (remove example autodoc generation, add examples catalog)

**Participants**: human (owner) + Claude.

**Summary**: owner directed removing the 8 `zig build docs` example-autodoc targets  
(`layer1docs`..`layer4docs`, `itemsdocs`, `hooksdocs`, `helpersdocs`, `storiesdocs`) built up  
across DOC 17/INTR 6 — build cost for a page nobody needs, plus a `kitchen/docs/  
examples_reference.md` linking all 8. `apidocs` (the real `src/matryoshka.zig` API reference)  
stays untouched — different content, not an "example doc."

In its place: a hand-organized examples catalog. Discussion arc (owner + Claude, in-session):  
mirror `examples/`'s existing folder layout 1:1 under `kitchen/docs/examples/` via a new  
permanent script, with reader-facing grouping (how-to categories, not `layer1..4`) living  
entirely in hand-authored catalog/group pages that link into the mirrored tree — so regrouping  
later is a doc edit, never a script change. Owner confirmed each per-example generated page  
holds: title, the `//!` description + fenced diagram verbatim, the full embedded source (not a  
relative link — the deployed site only serves `kitchen/docs/`, so a relative link to  
`examples/*.zig` would 404 once published), then a GitHub-blob "Open source" new-tab link  
(`attr_list`, already enabled) as a secondary reference. First-pass grouping: Items/Hooks/  
Helpers intro, How-to groups (PolyNode, Mailbox, Pool, Io — Select/Group/Future), and a  
trailing Flow group for cross-layer Master compositions plus the video transcoder story —  
owner-flagged as likely to be reshuffled later.

**Changes**:
- `build.zig` — removed the 8 doc-target call sites and their supporting helpers
  (`addLayerDocTarget`, `stageDir`, `addDocTargetForModule`); `docs_step`/`apidocs_lib`/  
  `install_apidocs` untouched.
- `kitchen/tools/gen_examples_docs.sh` (new, permanent) — mirrors `examples/`+`stories/` into
  `kitchen/docs/examples/`, one `.md` per non-barrel `.zig` file (barrel = every non-comment  
  line is `pub const X = @import(...)`); only clears its own mirrored subdirs on each run, never  
  the hand-authored catalog/group pages living alongside them.
- `kitchen/tools/build_site.sh`, `kitchen/tools/preview_site.sh` — call the new script before
  `mkdocs build`/`serve`.
- `kitchen/docs/examples/index.md`, `polynode.md`, `mailbox.md`, `pool.md`, `io.md`, `flow.md`
  (new, hand-authored) — catalog + 5 group pages, covering all 76 mirrored pages exactly once  
  (68 across the 5 groups, 8 items/hooks/helpers referenced from the index).
- Deleted `kitchen/docs/examples_reference.md`.
- `kitchen/mkdocs.yml` — removed the `Examples Reference` nav entry; added an `Examples
  Catalog` nav section (Overview + 5 group pages).
- `.gitignore` — replaced the 8 generated-dir entries with `/kitchen/docs/examples/` (same
  gitignored-generated-output treatment as `/kitchen/docs/apidocs/`).
- `design/rules-019.md` → `-020.md` — "Doc-generation module size" rule updated: general
  principle kept, the multi-target staging workaround marked historical (targets removed).
- `design/context.md` — rules/plan/docs-plan pointers bumped.
- `design/matryoshka-tk-implementation-plan-039.md` → `-040.md` — DOC 20 summary bullet.
- `design/STATUS.md` — Sources of Truth pointers; DOC 20 stage line; mirrored session log entry.

**Verification**:

| Check | Result |
|---|---|
| `bash kitchen/build_and_test_debug.sh` | PASS (167/167), unchanged — build.zig doc-step-only |
| `zig build docs` | succeeds, installs only `kitchen/docs/apidocs/` |
| `bash kitchen/tools/gen_examples_docs.sh` (run twice, idempotency check) | 76 mirrored `.md` files, matching `examples/`+`stories/` structure 1:1; hand-authored catalog/group pages untouched across reruns |
| `bash kitchen/tools/build_site.sh` | mkdocs builds clean, zero warnings (fixed two found during this session: a relative-link 404 risk on deploy, fixed by switching to GitHub-blob links; and the mirror script wiping the hand-authored catalog pages, fixed by scoping its `rm -rf` to only the mirrored subdirs) |
| Headless-Chrome render + console check, catalog index + one example page + `apidocs` | clean, titles resolve, no console errors |
| Coverage check: every one of the 76 mirrored pages appears in exactly one group/index link | confirmed, no duplicates, no omissions |
| Grep scan for the 8 removed target names + `examples_reference` across `build.zig`, `.gitignore`, `kitchen/mkdocs.yml`, `kitchen/docs/` | zero hits except historical STATUS.md session-log entries (exempt) |

**Next**: Stage 9 continues. Examples-catalog grouping is a first pass — owner may reshuffle  
groups later (doc edit only, no script change). DOC 21+ TBD.

---

### 2026-07-06 — DOC 14 session (audit Odin docs, add missing patterns/idioms)

**Participants**: human (owner) + Claude.

**Summary**: owner directed an audit of the sibling Odin project's docs  
(`/home/g41797/dev/root/github.com/g41797/matryoshka/kitchen/docs`) — a separate  
language, same architecture — to find patterns/idioms not yet in our Zig  
`patterns-010.md` catalog. Rule: already-described patterns need no action; a new  
pattern with an existing Zig example gets a catalog entry only; a new pattern with  
no existing example needs both a new example and a catalog entry.

**Method**: an Explore agent inventoried every file under the Odin docs folder —  
31 named idioms/patterns across `advices.md`, `advice_catalog.md`,  
`block1..4_deepdive.md`/`_quickref.md`, `addendums/polytag.md`, `hard-rules.md`,  
`doctor-ordered.md`, `gotchas-of-pooling-items.md`, `forgotten_doll.md`,  
`dialogs.md`, `critical-issues.md`, and the two API-reference files. Cross-checked  
each against `patterns-010.md` and `examples/**/*.zig`.

**Bucket A — already described, no action**: explicit allocators (N/A — Zig has no  
ambient-context-allocator problem), Builder ctor/dtor by tag (= PolyHelper  
create/destroy), defer-cleanup/collection-drain, unknown-tag alloc-vs-free  
asymmetry, Maybe/MayItem ownership flag (= Slot), two-value unwrap (= Zig optional  
`if (x) |v|`), PolyTag pointer-identity tagging (= Tag identifies the class),  
two-mailbox interrupt+batch/OOB (= Out-of-band priority), defer-put-early,  
backpressure via on_put, belt-and-suspenders double pool_put (= Fallback destroy  
after pool.put), PoolHooks pattern (= Pool as lifecycle policy), drain-and-reset  
before shutdown (= on_close hook), dynamic topology (= Mailbox-as-message).  
Builder-to-Pool upgrade (Odin migration narrative), cond-var timeout fix and  
`container_of` idiom (internal implementation detail, not user-facing), and  
one-place-at-a-time/isolation (discipline, not a code shape) — no action.

**Bucket B — added, catalog entry only, Zig example already existed**: 7 entries  
added to `patterns-011.md` — Request-Response, Pipeline, Fan-In, Fan-Out (new  
"Topology patterns" section, right after Mailbox patterns), Shutdown via Exit  
message (alternative to the close-based Graceful shutdown sequence),  
Thread-is-container (folded into Master patterns' Observable function shapes),  
Intrusive node embedding (new first entry in PolyNode idioms). Each entry links to  
its existing example(s); each verified by reading the actual example file, not  
just matching a filename.

**Bucket C — skipped, owner confirmed**: self-send, function-pointer-as-tag,  
descriptor-struct-as-tag. Advanced/niche, flagged as rare even in the Odin source  
docs. No new Zig example, no catalog entry — noted here so a future audit does not  
re-surface them as "missing."

**Changes**:
- `design/patterns-010.md` → `design/patterns-011.md` — the 7 Bucket-B entries
  added in place; everything else carried over unchanged.
- `design/context.md` — patterns pointer → -011; docs plan → -012; plan → -038.
- `design/matryoshka-tk-docs-plan-011.md` → `-012.md` — this entry + Stages update.
- `design/matryoshka-tk-implementation-plan-037.md` → `-038.md` — DOC 14 bullet.
- `design/STATUS.md` — sources updated; DOC 14 stage line; mirrored session log entry.

**Verification**:

| Check | Result |
|---|---|
| Each of the 7 new example paths exists and demonstrates the named pattern | confirmed by reading all 7 files directly |
| No duplication with existing -010 content | grepped each of the 7 new names — one occurrence each |
| Banned-word + AI-sh scan on -011 | CLEAN after fixing 3 new "drain" occurrences (→ "empties"/"empty"); `unlock()` exempt as before |
| Staccato audit | new entries match existing entry format (when-to-use, pattern/code shape, why, example) |
| `.zig` / kitchen build files touched | none — doc-only stage; 167/167 tests unaffected |

**Next**: DOC 15+ — TBD, scoped with owner. Likely candidates unchanged: split  
api-reference-019 into mkdocs Reference pages; use manifesto-003 as source for the  
docs-site Concepts entry page.

---

### 2026-07-05 — DOC 13 session (unified pattern/idiom catalog: patterns-009 → -010)

**Participants**: human (owner) + Claude.

**Summary**: owner scoped DOC 13 to the pattern docs. `patterns-009.md` was two  
catalogs glued together: a full "(008)" catalog (when-to-use, code shape, example  
links) and an appended older "(002)" catalog of short idioms extracted from the API  
reference. The two halves repeated each other (pool hooks, Select sources, Group  
spawn/await, polymorphic dispatch, slot cleanup). More pattern material lived only  
in `matryoshka-api-reference-019.md` (Cooperative cleanup patterns 1–4, Transporting  
infra handles, no-raw-allocator rule). Owner directed: one new version holding all  
patterns/idioms without repetition, in logical order, per the doc rules. Result:  
`patterns-010.md`; `-009.md` untouched per the no-overwrite rule;  
`api-reference-019.md` untouched (the catalog links to it).

**Structure of -010** (simple ownership idioms first, composition last):
1. Slot and ownership idioms — empty init, overwrite prevention, transfer clears,
   null-safe cleanup, defer-put-early, defer-destroy-early, defer for received item,  
   fallback destroy, no raw allocator (from api-ref).
2. PolyNode idioms — PolyHelper everywhere, node/slot identification, polymorphic
   dispatch, tag = class, wrapper type, mailbox-as-message, worker-finish-signal  
   (from api-ref), pool-as-message.
3. Mailbox patterns — try-receive, batch, OOB, close recovery, wakeUpAll.
4. Pool patterns — three get modes, seeding, lifecycle policy (on_get/on_put merged
   with hook decision), hook outside lock, on_close, multi-tag.
5. Future patterns — direct future, cancellation.
6. Io.Select patterns — event loop (absorbs "one-shot registration"), mailbox/pool
   sources, mixed sources, backpressure, direct push, cancel walk, cancelDiscard.
7. Io.Group patterns — worker set (absorbs "fire-and-forget"), reusable Group,
   shutdown via close, shutdown via group.cancel.
8. Cancellation patterns — boundary, preserves ownership, close vs cancel, error
   handling on receive (gains the `error.Wakeup` branch — predated wakeUpAll).
9. Graceful shutdown sequence — 9-step mandatory order, unchanged.
10. Master patterns — Observable function shapes, Select-loop coordinator,
    spawn+await coordinator, Master composition, Mailbox+Pool integration,  
    full Layer-4 architecture.

**Dedup rule applied**: where the two source halves overlapped, the fuller (008)  
entry was kept and any extra fact from the (002) entry folded in. Nothing dropped —  
only repetition.

**Changes**:
- `design/patterns-010.md` (new) — the unified catalog per the structure above.
- `design/context.md` — patterns pointer → -010; docs plan → -011; plan → -037.
- `design/matryoshka-tk-docs-plan-010.md` → `-011.md` — this entry + Stages update.
- `design/matryoshka-tk-implementation-plan-036.md` → `-037.md` — DOC 13 bullet.
- `design/STATUS.md` — sources updated; DOC 13 stage line; mirrored session log entry.

**Verification**:

| Check | Result |
|---|---|
| Coverage: every heading in patterns-009 (both halves) + api-ref pattern material maps to -010 | all mapped, heading-list comparison — two entries absorbed by name ("one-shot registration", "fire-and-forget") |
| No repetition | one entry per concept in -010's heading list |
| Order check (nothing used before introduced) | ownership idioms → building blocks → Io integration → whole-system shapes |
| Banned-word + AI-sh scan on -010 | CLEAN (single `unlock()` hit is the `Io.Mutex` API call inside a code shape, carried from -009 — exempt) |
| `.zig` / kitchen build files touched | none — doc-only stage; 167/167 tests unaffected |

**Next**: DOC 14+ — TBD, scoped with owner. Likely candidates unchanged: split  
api-reference-019 into mkdocs Reference pages; use manifesto-003 as source for the  
docs-site Concepts entry page.

---

### 2026-07-05 — DOC 12 session (de-smart the manifesto: -002 → -003)

**Participants**: human (owner) + Claude.

**Summary**: owner reviewed `matryoshka-manifesto-002.md` and flagged its style as  
"AI-sh, too smart", using this example:

> Matryoshka defines the application model: how the system is structured.
> Io defines the execution model: when work becomes runnable.

The problem: abstract architect-speak ("application model", "execution model",  
"autonomous", "reason about locally"). Owner directed a rewrite into plain human  
language per the doc rules. Result: new `matryoshka-manifesto-003.md`; `-002.md`  
untouched per the no-overwrite rule. Structure, sections, diagrams, and tables  
unchanged — only the flagged wording.

**Rewrites** (full table in the DOC 12 plan; highlights):
- "defines the application model / execution model" → "Matryoshka answers: what is
  my system made of? / Io answers: when does my code run?"
- "concurrency becomes implicit" → "nobody knows which code runs in parallel".
- "explicit ownership boundaries" → "you always know who owns what".
- "systems you can reason about locally" → "you can understand one Master without
  reading the whole system".
- dense Master definition split into three short lines ("A Master runs on its own.
  It owns its state. It talks through mailboxes.").
- "Every component is autonomous..." → "Every part runs on its own. Some parts grow
  into coordinators."
- "Io is a hidden transport behind Mailboxes" → "Io just moves messages behind
  Mailboxes. You never see it."
- plus: "one dedicated responsibility" → "one job", "translates" → "turns",
  "provides immediate value" → "is useful right away", "executes it faster" →  
  "runs it faster", "An async operation completed" → "A background job finished".

**Changes**:
- `design/matryoshka-manifesto-003.md` (new) — -002 with the rewrites above.
- `design/context.md` — manifesto pointer → -003; docs plan → -010; plan → -036.
- `design/matryoshka-tk-docs-plan-009.md` → `-010.md` — this entry + Stages update.
- `design/matryoshka-tk-implementation-plan-035.md` → `-036.md` — DOC 12 bullet.
- `design/STATUS.md` — sources updated; DOC 12 stage line; mirrored session log entry.

**Verification**:

| Check | Result |
|---|---|
| diff -002 vs -003 | only the flagged lines changed; sections, diagrams, tables, facts intact |
| Banned-word + AI-sh scan on changed `.md` | CLEAN |
| Staccato audit | no new dense multi-fact sentences; the one dense sentence was split |
| Read-aloud test on changed lines | plain spoken English |
| `.zig` / kitchen build files touched | none — doc-only stage; 167/167 tests unaffected |

**Next**: DOC 13+ — TBD, scoped with owner. Likely candidates unchanged: split  
api-reference-019 into mkdocs Reference pages; use manifesto-003 as source for the  
docs-site Concepts entry page.

---

### 2026-07-05 — DOC 11 session (write matryoshka-manifesto-002.md)

**Participants**: human (owner) + Claude.

**Summary**: owner directed a new manifesto version. Sources of mindset: `README.md`  
(voice to match), `design/matryoshka-tk-model.md`, `design/matryoshka-manifesto.md`  
(original, stays untouched), `design/matryoshka-master.md` (Master as role, four  
fundamental concepts), `design/master-Tk.md` (Io hidden behind Mailboxes, bridge  
Masters, "why not just Io"). Target audience effect: after one read, understand the  
model and want to use matryoshka because it solves their problems. Style per  
rules-010.md: simple English, staccato rhythm, banned-word clean. Owner authorized  
auto mode; git stays disabled.

**Narrative arc of -002**: problem (libraries vs systems; Io says *when*, not *what  
the system is made of*) → one constraint (everything is a Master communicating via  
Mailboxes; shared resources explicit via Pools) → Master is a role (role tree:  
single-role / coordinator / resource owner; worker = Master with one responsibility) →  
down to earth (one input mailbox, one message at a time, capability→primitive table,  
everything else is a Master or composition) → four fundamental concepts (PolyNode /  
Mailbox / Pool / Master with the README troika bullets, 582 lines) → where Io fits  
(application model vs execution model; everything becomes a message in a mailbox;  
bridge diagram; design test: "if you must mention Io while designing, it is already  
too visible"; hybrid-car framing) → start small (PolyNode → Pool → Mailbox, each step  
useful) → the simple question + "Be Master of your systems."

**Source-coverage notes**: all concept-level ideas from the five sources carried over.  
Deliberately out of scope (per master-Tk.md's own guidance): sockets/files/epoll,  
specific event-source APIs, "schedule itself" Io capability list — implementation  
detail below manifesto level. Source wordings with banned words ("efficiently",  
"powerful", "delivered") reworded; "big-bang commitment" → "big-bang adoption".

**Changes**:
- `design/matryoshka-manifesto-002.md` (new) — the manifesto per the arc above.
- `design/context.md` — manifesto pointer added; docs plan → -009; plan → -035.
- `design/matryoshka-tk-docs-plan-008.md` → `-009.md` — this entry + Stages update.
- `design/matryoshka-tk-implementation-plan-034.md` → `-035.md` — DOC 11 bullet.
- `design/STATUS.md` — sources updated; DOC 11 stage line; mirrored session log entry.

**Verification**:

| Check | Result |
|---|---|
| Banned-word + AI-sh scan on all changed `.md` | CLEAN after two rewordings ("delivered", "delivery mechanism") |
| Staccato audit (short intro + bullets, no comma-list prose) | end-to-end read of -002 — conforms |
| Source coverage (5 files → -002) | all concept-level ideas present; low-level Io details deliberately out of scope |
| Cross-link check (context.md, STATUS.md pointers) | all targets exist |
| `.zig` / kitchen build files touched | none — doc-only stage; 167/167 tests unaffected |

**Next**: DOC 12+ — TBD, scoped when reached. Likely candidate: split  
`matryoshka-api-reference-019.md` into mkdocs Reference pages under  
`kitchen/docs/reference/`; manifesto-002 is a candidate source for the docs-site  
Concepts entry page.

---

### 2026-07-05 — DOC 10 session (dependency-order the API reference)

**Participants**: human (owner) + Claude.

**Summary**: owner reviewed the DOC 9 output (`matryoshka-api-reference-018.md`) and  
found it still not logically ordered: several paragraphs discuss functions and concepts  
introduced only later in the document. DOC 9 had moved whole top-level sections; the  
problems live one level deeper. Owner directed a deeper re-partition: preserve every  
piece of information, move blocks (including subsections inside sections) so nothing is  
used before it is introduced. New version `-019.md`; `-018.md` untouched per the  
no-overwrite rule.

**Forward references found in -018 (grep-verified)**:
- Ownership model's send/receive diagrams used `mailbox.send`/`mailbox.receive` ~800
  lines before mailbox is introduced.
- Slot-based programming's examples used `pool.put`, `pool.get`, `PolyHelper.destroy`,
  `mailbox.send`, `receiveResult`/`getWaitResult` — all introduced later.
- Cooperative cleanup patterns were built entirely on pool/mailbox/PolyHelper — all
  introduced later.
- polynode's "Tag identity" + "Transporting infra handles" discussed `_Mailbox`/`_Pool`
  privacy and MailboxHandle transport before mailbox/pool exist.
- polynode's "stdlib compatibility" names `mailbox.close()`/`receive_batch()`/
  `pool.put_all()` — name-level pointers only, kept (flagged to owner).

**New order in -019**: intro → Ownership model (diagrams moved out) → polynode (tag  
identity moved out) → mailbox (opens with the relocated send/receive ownership  
diagrams) → pool → Tag identity (own `##` section, incl. Transporting infra handles) →  
Slot-based programming → Cooperative cleanup patterns → root → Master → Cancel →  
contracts/invariants/thread-safety/complexity/violations/layer-deps → Change log (new  
019 row) → Addendums/Io 101.

**Method**: `sed` line-range extraction from -018 and reassembly (byte-exact content  
preservation, same technique as DOC 9). Only permitted edits: heading-level promotion  
of the two relocated blocks, one added `---` separator, the new Change-log row.

**Changes**:
- `design/matryoshka-api-reference-019.md` (new) — order per above.
- `design/context.md` — API pointer → -019; docs plan → -008; plan → -034.
- `design/matryoshka-tk-docs-plan-007.md` → `-008.md` — this entry + Stages update.
- `design/matryoshka-tk-implementation-plan-033.md` → `-034.md` — DOC 10 bullet.
- `design/STATUS.md` — sources updated; DOC 10 stage line; mirrored session log entry.

**Verification**:

| Check | Result |
|---|---|
| Line accounting -018 → -019 | 1848 → 1853 = +4 structural (separator, blank, heading levels) +1 Change-log row — nothing lost |
| Term-frequency diff (`PolyHelper`, `Cancelable`, `Io.Select`, `wakeUpAll`, `error.Wakeup`, `receiveResult`, `getWaitResult`, `MailboxHandle`, `PoolHandle`) | identical counts in -018 and -019 |
| Forward-reference scan (mailbox/pool/PolyHelper before their sections) | none in Ownership model; polynode retains only name-level pointers (list-node recovery note, batch-op name list) — flagged, accepted |
| Banned-word scan on -019 | CLEAN (same single historical Change-log meta-reference as -018) |
| `.zig` / kitchen build files touched | none — doc-only stage |

**Next**: DOC 11+ — TBD, scoped when reached. Likely candidate: split  
`matryoshka-api-reference-019.md` into mkdocs Reference pages under  
`kitchen/docs/reference/`. Open items carried unchanged from DOC 9.

---

### 2026-07-05 — DOC 9 session (re-partition and logically reorder the API reference)

**Participants**: human (owner) + Claude.

**Summary**: `design/matryoshka-api-reference-017.md` (2216 lines) is planned as the  
base for the docs site's mkdocs Reference pages (DOC 2 finding #3), but its shape  
reflects development history, not a learning path: sections landed wherever each API  
stage touched them, generic `std.Io` runtime material (Io, Future, Io.Select, Io.Group,  
`io.concurrent`, Cancelable) was interleaved with matryoshka-specific API, and the last  
third of the file was 16 `Change manifest (NNN)` sections — one per historical API  
stage — restating, as diffs, content already current in the main body above. Owner  
directed: read the whole doc, preserve every fact, delete only true repetitions,  
reorder the rest into a logical/teachable structure, and move all `std.Io`-generic  
material into a trailing `## Addendums` / `### Io 101` section. Owner also confirmed  
this stage is reorder/re-version only — splitting the result into mkdocs `.md` pages  
under `kitchen/docs/reference/` is deferred to a later stage. Owner authorized  
autonomous end-to-end execution (going OOF; git stays disabled) and Opus-level effort  
for the analysis, given the size and judgment required.

**Method**: full inline read of all 2216 lines (matching the DOC 1 precedent — owner  
prefers direct reading over subagent delegation for full traceability). Built a  
section-by-section content map classifying each section matryoshka-specific vs  
Io-generic. Verified all 16 `Change manifest` sections are downstream-propagation  
notes fully subsumed by current main-body content (each one documents a change that  
was, in fact, applied when it was written) — confirmed via term-frequency diff  
(`Cancelable`, `Io.Select`, `PolyHelper`, error names) between old and new file, with  
the deltas fully explained by the dropped manifest block. No residual fact found that  
needed folding back in before dropping the block.

**Changes**:
- `design/matryoshka-api-reference-018.md` (new) — reordered: intro, ownership model,
  slot-based programming, cooperative cleanup patterns, polynode, mailbox, pool,  
  matryoshka (root), Master (incl. the project-specific "Io backend for Layer 4 tests  
  and examples" convention, kept in the main body), Cancel model/contract, ownership  
  lifecycle/invariants/cancellation contract, thread-safety, complexity, contract  
  violations, layer dependencies, Change log (table only, with a new 018 row). New  
  trailing `## Addendums` / `### Io 101` section holds the `std.Io` basics, event  
  sources, Cancel, and the `io.concurrent`/`Io.Group`/`Io.Select` internals subsection  
  — all previously interleaved with matryoshka-specific content. The 16  
  `Change manifest (NNN)` sections dropped as repetition. No information lost, no new  
  API surface.
- `design/context.md` — API reference pointer → -018 (with a one-line note on the
  reorder); docs plan pointer → -007; plan pointer → -033.
- `design/matryoshka-tk-implementation-plan-032.md` → `-033.md` — DOC 9 summary bullet.
- `design/STATUS.md` — Sources of Truth (API pointer → -018), Stage 9 line (DOC 9
  entry), this session log mirrored.

**Verification**:

| Check | Result |
|---|---|
| Term-frequency diff (`Cancelable`, `Io.Select`, `PolyHelper`, `error.Timeout`, `error.Canceled`, `error.NotAvailable`, `ConcurrentError`) between -017 and -018 | deltas fully explained by the dropped Change-manifest block — no unaccounted loss |
| Banned-word scan (rules-010.md list: drain, dll, commit-as-save, AI-sh word list) on -018.md | CLEAN (one historical Change-log line references a past `fires`→`runs` fix — meta-reference, not a live violation, same precedent as EXMPL 4c) |
| Heading structure re-check (no orphaned/duplicate headings after the reorder) | confirmed, one duplicate empty heading found and fixed during assembly |
| `.zig` / kitchen build files touched | none — doc-only stage, `kitchen/build_and_test_*.sh` not required |

**Next**: DOC 10+ — TBD, scoped when reached. Open items carried: whether the mkdocs  
Reference-page split of `-018.md` is DOC 10 or later; storytelling-001/-003 duplicate  
H1; `test-example-story.md` split; `video-transcoder-003.md` as second Concepts story;  
further Building Blocks topics; Cookbook stub still unpopulated.

---

### 2026-07-04 — DOC 8 session (populate Building Blocks with the four core concepts)

**Participants**: human (owner) + Claude.

**Summary**: DOC 7 populated Building Blocks with its first topic (Observable by  
human). Owner picked the four core concepts — PolyNode / Mailbox / Pool / Master —  
as DOC 8's topic: the vocabulary the whole toolkit is built on. Unlike the Concepts  
doc-site section (DOC 6), which stays domain-first and defers these terms to a  
second page, Building Blocks is exactly where these four terms get defined directly.

**Key findings**:
- `design/matryoshka-model-003.md`'s "Core Principles" section already states all
  four concepts as one continuous idea, plus the "Layers compose" one-diagram  
  summary — needed only distillation, no new authoring.
- `design/matryoshka-master.md` (an informal dialogue) independently arrives at the
  same four-concept framing and supplied the Master-as-role wording.

**Changes**:
- `kitchen/docs/building-blocks/core-concepts.md` (new) — PolyNode, Mailbox, Pool,
  Master sub-sections plus the layering diagram, pointing back at  
  `matryoshka-model-003.md` and the Observable by Human page.
- `kitchen/docs/building-blocks/index.md` — added a link to the new page.
- `kitchen/mkdocs.yml` — "Building Blocks" nav entry gains the new page.
- `design/matryoshka-tk-docs-plan-005.md` → `-006.md` — this entry + Stages update.
- `design/context.md` — docs plan pointer → -006.
- `design/STATUS.md` — DOC 8 stage line; mirrored session log entry.

**Verification**:

| Check | Result |
|---|---|
| `bash kitchen/tools/build_site.sh` (output → `zig-out/docs_build_site.log`) | succeeded, no mkdocs warnings |
| New page renders in `kitchen/output/building-blocks/` | confirmed |
| Banned-word scan on new content | CLEAN |
| `.zig` files touched | none — doc-only stage |

**Next**: DOC 9+ — TBD, scoped when reached. Open items carried: storytelling-001/-003  
duplicate H1, `test-example-story.md` split, `video-transcoder-003.md` as a second  
Concepts story, further Building Blocks topics (Select loops, spawn/await, Master  
composition, pool patterns, API reference), Cookbook stub still unpopulated.

---

### 2026-07-04 — DOC 7 session (populate Building Blocks with one topic)

**Participants**: human (owner) + Claude.

**Summary**: DOC 6 populated Concepts with the print-server story. Owner confirmed no  
second story for now and picked Building Blocks as DOC 7's scope. `building-blocks/  
index.md` was a stub pointing at three dense sources (rules-010.md, patterns-008.md,  
matryoshka-api-reference-016.md). Per the established discipline  
(`docs-tooling-approach-001.md`): never dump a whole dense source into one page, scope  
one topic at a time. Chose "Observable by human" as the first topic — it is rules-010's  
headline MUST rule, and patterns-008's first pattern section ("Observable function  
shapes") is its concrete template; the two source docs already cross-reference each  
other as companions.

**Key findings**:
- Rule (rules-010.md) and pattern (patterns-008.md) are already paired 1:1 in the
  source docs — combining them into one topic page needed no new authoring, only  
  distillation and trimming (Select-loop and spawn/await pattern variants left for a  
  later Building Blocks topic).
- API reference (matryoshka-api-reference-016.md) is lookup content, not narrative —
  deferred to its own future DOC stage rather than folded into this one.

**Changes**:
- `kitchen/docs/building-blocks/observable-by-human.md` (new) — the rule (two-level
  coordinator/step structure, the comment-signal, structural extraction signals) plus  
  the pattern (Coordinator, Step, Init code shapes), pointing at  
  `031-select_graceful_shutdown.zig` and `018-master_with_pool.zig` as working examples.
- `kitchen/docs/building-blocks/index.md` — rewritten from stub to landing page.
- `kitchen/mkdocs.yml` — "Building Blocks" nav entry expanded to Overview + the new page.
- `design/matryoshka-tk-docs-plan-004.md` → `-005.md` — this entry + Stages update.
- `design/context.md` — docs plan pointer → -005.
- `design/STATUS.md` — DOC 7 stage line; mirrored session log entry.

**Verification**:

| Check | Result |
|---|---|
| `bash kitchen/tools/build_site.sh` (output → `zig-out/docs_build_site.log`) | succeeded, no mkdocs warnings |
| New pages render in `kitchen/output/building-blocks/` | confirmed |
| Banned-word scan on new content | CLEAN |
| `.zig` files touched | none — doc-only stage |

**Next**: DOC 8+ — TBD, scoped when reached. Open items carried: storytelling-001/-003  
duplicate H1, `test-example-story.md` split, `video-transcoder-003.md` as a second  
Concepts story, further Building Blocks topics (Select loops, spawn/await, Master  
composition, pool patterns, API reference), Cookbook stub still unpopulated.

---

### 2026-07-04 — DOC 6 session (populate Concepts with a story, top-down)

**Participants**: human (owner) + Claude.

**Summary**: DOC 5 left three open items for later DOC stages. Owner picked populating  
one stub section — Concepts — as DOC 6's scope, following the same top-down principle  
already used for DOC 5 (the entry-point page names PolyNode/Mailbox/Pool/Master next, so  
Concepts is the natural next layer down). Owner rejected a first draft of the plan that  
led with raw concept definitions ("system has no Masters, Mailboxes, and Pools — it's  
more suitable to a story; later we see how it's built using Matryoshka, without  
details"). Corrected direction: describe a real system first, in domain terms only, then  
show the same system built with Matryoshka, still without deep implementation detail.

**Key findings**:
- `design/stories/*.md` already use exactly this shape: Part 1 — Discussion (domain
  dialogue, zero Matryoshka vocabulary), Part 2 — SRS (numbered domain requirements),  
  Part 3 — Matryoshka Translation (requirements mapped to PolyNode/Mailbox/Pool/Master),  
  Part 4 — Flow Diagram (ASCII, no prose). Confirmed against `print-server-002.md` (read  
  in full) and `video-transcoder-003.md` (headings checked).
- `design/matryoshka-model-003.md`'s Three-Category Model already defines "Story" as this
  exact artifact type, distinct from Test and Example — confirms stories are the intended  
  docs-facing unit, not raw concept definitions.
- Two stories exist. `print-server-002.md` used this stage; `video-transcoder-003.md`
  deferred to a later DOC stage (one story at a time, per the narrow-scoping rule).

**Decision**: DOC 6 scoped to one story, split into two site pages (system, then  
Matryoshka), plus a rewritten Concepts landing page. No new domain material authored —  
adapted from the existing story. Building Blocks/Cookbook stubs, `design/*.md` content,  
and `.zig` files untouched.

**Changes**:
- `kitchen/docs/concepts/print-server-the-system.md` (new) — Parts 1-2 of
  `print-server-002.md`, adapted: domain roles, requirements, ownership reasoning.  
  No Matryoshka vocabulary (verified by grep).
- `kitchen/docs/concepts/print-server-with-matryoshka.md` (new) — Parts 3-4 of
  `print-server-002.md`, adapted: each requirement mapped to PolyNode/Mailbox/Pool/  
  Master, ending with the flow diagram.
- `kitchen/docs/concepts/index.md` — rewritten from one-line stub to a landing page
  linking the two new pages.
- `kitchen/mkdocs.yml` — nav: "Concepts" entry expanded from a bare `concepts/index.md`
  into an Overview + two-page subsection.
- `design/matryoshka-tk-docs-plan-003.md` → `-004.md` — this section; Stages updated.
- `design/context.md`, `design/STATUS.md` — docs plan pointer → -004; DOC 6 stage line;
  session log entry.

**Verification**:

| Check | Result |
|---|---|
| `bash kitchen/tools/build_site.sh` (output → `zig-out/docs_build_site.log`) | succeeded, no mkdocs warnings |
| New pages render in `kitchen/output/` | confirmed |
| Grep for Matryoshka vocabulary (PolyNode/Mailbox/Pool/Master/Slot/Tag) in the-system page | none found (only "spooler"/"Spool" prose matches) |
| Banned-word scan on new/changed content | CLEAN |
| `.zig` files touched | none — doc-only stage |

**Next**: DOC 7+ — TBD, scoped when reached. Open items carried: storytelling-001/-003  
duplicate H1, `test-example-story.md` split, `video-transcoder-003.md` as a second  
Concepts story, Building Blocks and Cookbook stub sections still unpopulated.

---

### 2026-07-04 — DOC 5 session (top-down entry point + nav skeleton)

**Participants**: human (owner) + Claude.

**Summary**: Owner asked for an audit of four candidate content sources before scoping  
DOC 5 — `design/*.md`, `kitchen/docs/*.md`, the Odin `matryoshka` repo's `kitchen/docs/`,  
and a 4255-line ChatGPT brainstorm transcript (`/home/g41797/Downloads/matryoshka-tk-long-session.md`).  
Owner's direction: don't design the whole site in one stage — start top-down, with one  
entry-point page answering "what is a Matryoshka-based system and why," then grow detail  
pages in later DOC stages.

**Audit findings**:
- `design/*.md` (current versions per `context.md`): rules-010, patterns-008,
  matryoshka-model-003, matryoshka-architecture-001, matryoshka-api-reference-016 are rich  
  site-content candidates but too dense for one page each — future stages must split them  
  into narrow topic pages, not dump them whole. `design/stories/` is cookbook material.  
  STATUS.md, docs-plan, implementation-plan, context.md itself are process-only, not site  
  content. Several files not in `context.md`'s current index are historical/superseded.
- `kitchen/docs/*.md`: already fully wired into `kitchen/mkdocs.yml`'s nav, but mostly raw
  chat logs and iterative storytelling drafts. `index.md` is a 3-line stub.  
  `matryoshka-storytelling-001.md` and `-003.md` share a duplicate H1 (likely copy-paste).  
  `test-example-story.md` (793 lines) covers three topics in one file. None of this fixed  
  this stage — flagged for a later content stage.
- Odin `matryoshka/kitchen/docs/`: confirmed as language-agnostic prose in large part
  (`design_hub.md`, `problem2solve.md`, `hard-rules.md`, `advices.md`, block1-4 deep dives)  
  — a legitimate future content source distinct from its Odin-specific API reference files  
  (`matryoshka-unified-api-reference.md`). Notably, `matryoshka-zig-api-reference.md`  
  already exists there as a Zig-ported counterpart — check before re-deriving anything.
- ChatGPT transcript: one continuous session, not separate topics — repeatedly redrafts the
  same doc set (PolyNode/Mailbox/Pool/patterns/nav tree) 3-4 times with increasing  
  refinement; only the last pass per topic is worth mining. Mostly duplicates material  
  already in `design/`. Two things are genuinely new and not found elsewhere: a concrete  
  mkdocs directory-tree proposal (`concepts/building-blocks/patterns/integration/  
  reference/appendix`) and a closing pitch — "most libraries document features; Matryoshka  
  should document architectures" — used verbatim as the opening line of the new overview  
  page this stage.

**Decision**: DOC 5 scoped narrowly — one new overview page plus a nav skeleton with stub  
placeholders for future sections. No deep content pages, no touching `design/*.md` content,  
no reorganizing or fixing the existing `kitchen/docs/*.md` files this stage (duplicate-H1  
fix and file-splitting deferred to a later DOC stage).

**Changes**:
- `kitchen/docs/matryoshka-based-systems.md` (new) — overview/pitch page, sourced from
  `README.md`, `design/matryoshka-master.md`, `design/matryoshka-architecture-001.md`, and  
  the ChatGPT transcript's closing pitch line.
- `kitchen/docs/concepts/index.md`, `kitchen/docs/building-blocks/index.md`,
  `kitchen/docs/cookbook/index.md` (new) — one/two-line stubs naming their future source  
  material.
- `kitchen/mkdocs.yml` — nav: added "Matryoshka Based Systems", "Concepts", "Building
  Blocks", "Cookbook" entries after Home, before Reference. Existing Storytelling/Concepts  
  (old)/Chat Logs entries left untouched.
- `design/matryoshka-tk-docs-plan-002.md` → `-003.md` — this section; Stages updated.
- `design/context.md`, `design/STATUS.md` — docs plan pointer → -003; Stage 9 line; session
  log entry.

**Verification**:

| Check | Result |
|---|---|
| `bash kitchen/tools/build_site.sh` (output → `zig-out/docs_build_site.log`) | succeeded, no mkdocs warnings |
| New pages render in `kitchen/output/` | confirmed: `matryoshka-based-systems/`, `concepts/`, `building-blocks/`, `cookbook/` each produced `index.html` |
| Banned-word scan on new content | CLEAN |
| `.zig` files touched | none — `build_and_test_*.sh`/`build_cross_debug.sh` not run, per doc-only-stage convention |

**Next**: DOC 6+ — TBD, scoped when reached. Open items carried: storytelling-001/-003  
duplicate H1, `test-example-story.md` three-topics-in-one-file split, `design/*.md` content  
still needs breaking into narrow topic pages before it fills the Concepts/Building  
Blocks/Cookbook stub sections.

---

### 2026-07-03 — DOC 1 session (docs plan created)
**Participants**: human + Claude

Full record of this session's decisions and findings, kept at the top of this doc per  
owner instruction: all session info goes at the very beginning of the doc plan.

**Decisions made this session**:
- Docs will not be planned as one big upfront effort — work proceeds iteratively, stage by
  stage (DOC 1, DOC 2, ...), scoped only when reached.
- Docs will mix mkdocs-generated pages (from markdown) with content generated from Zig
  sources (autodocs).
- Sibling repo `tofu` (`/home/g41797/dev/root/github.com/g41797/tofu`) is the prototype for
  this mkdocs + autodocs approach — read for reference, not yet borrowed from.
- `kitchen/` folder rule confirmed: tofu scatters its housekeeping files across many
  locations (root scripts, `docs_site/`, `docs/`, `.github/workflows/`), but matryoshka-tk  
  follows the Odin `matryoshka` repo's convention instead — all tools/scripts/configs live  
  under `kitchen/` and its subfolders only.
- Audit method: read files directly inline in this session (not delegated to a subagent),
  owner explicitly chose this over an Explore-agent delegation for full traceability.
- Audit paths confirmed by owner: tofu repo (whole repo, not just one folder — housekeeping
  is scattered there); Odin `matryoshka/kitchen/`; matryoshka-tk's own `kitchen/`.

**What was produced this session**:
- Full audit of tofu's doc-generation flow (scripts, `build.zig` docs step, mkdocs config,
  CI workflow, local-preview gap) — see "Stage DOC 1" section below for the tables and  
  flow diagram.
- Comparison note: Odin `matryoshka/kitchen/` has dedicated preview scripts that tofu lacks.
- Finding: matryoshka-tk already has `.github/workflows/docs.yml` (copied from tofu) with no
  supporting infra yet built — open item for a future DOC stage.
- This file (`matryoshka-tk-docs-plan-002.md`) created as the new version of
  `matryoshka-tk-docs-plan-001.md` (stale, frozen at INTR 5).
- `design/context.md` and `design/STATUS.md` updated to point at this version; a matching
  DOC 1 entry added to STATUS.md's own Session Log.

**Also confirmed/saved to Claude memory this session** (persists across future sessions,  
not just this doc): docs-tooling decision, tofu-as-prototype pointer, kitchen/ rule pointer.

---

## Background (read first)

- Docs will be a mix of mkdocs-generated pages (from markdown) and content generated from
  Zig sources (autodocs). Owner decision.
- Sibling Zig project `tofu` (`/home/g41797/dev/root/github.com/g41797/tofu`) is the working
  prototype for this approach. Its doc flow is audited below.
- `kitchen/` folder rule: all tools, scripts, configs, and other housekeeping infrastructure
  live under `kitchen/` and its subfolders — same purpose as the Odin `matryoshka` repo's  
  `kitchen/` (`/home/g41797/dev/root/github.com/g41797/matryoshka/kitchen`).
- Work proceeds iteratively, stage by stage (DOC 1, DOC 2, ...). No whole-project plan in
  advance — each stage is scoped and executed on its own.
- Current project state (see `STATUS.md`): 161/161 tests passing. Stage 9 (Docs) is next
  after EXMPL 4c. Two stories complete, 66 example files, sources of truth at rules-010,  
  patterns-008, plan-031, model-003, api-reference-016.

---

## Stage DOC 1 — tofu audit (this version)

Audit only. No borrowing, no implementation, no `kitchen/` or `.zig` changes this stage.

### Housekeeping layout in tofu

Unlike matryoshka/matryoshka-tk's single `kitchen/` folder, tofu's housekeeping is  
scattered: root scripts (`docs_zig.sh`, `docs_site.sh`), `docs_site/` (mkdocs project),  
`docs/` (generated output, committed), `.github/workflows/docs.yml` (CI), plus unrelated  
root scripts (`zbta_*.sh`) and editor config (`.idea`, `.vscode`, `.run`).

### Doc flow — scripts and responsibilities

| Script/file | Responsibility |
|---|---|
| `build.zig` `docs` step (`b.step("docs", ...)`) | `zig build docs` — builds two `addObject` targets (`tofu` lib, `cookbook` recipes) with `use_llvm`/`use_lld`, installs each `getEmittedDocs()` output via `addInstallDirectory` into `docs_site/docs/apidocs` and `docs_site/docs/recipes` respectively |
| `docs_zig.sh` | Thin wrapper: `zig build docs`, prints progress lines |
| `docs_site.sh` | Full local build: calls `docs_zig.sh`, then `cd docs_site && mkdocs build` — one-shot, no serve |
| `docs_site/mkdocs.yml` | mkdocs-material config: nav, theme, plugins (awesome-pages, minify, open-in-new-tab, git-revision-date-localized); `site_dir: ../docs` (output goes to repo-root `docs/`, the GitHub Pages source) |
| `docs_site/docs/mds/*.md` | Hand-written narrative doc pages (overview, mantra, installation, patterns, etc.) — the "from md" half |
| `docs_site/docs/index.md`, `blog/index.md` | Site home + blog stub |
| `docs_site/overrides/partials`, `docs_site/scripts` | Present but empty — no custom theme overrides or dedicated scripts actually in use yet |
| `.github/workflows/docs.yml` | CI: on push to `main` touching `docs_site/**`, `src/**`, `recipes/**`, `build.zig` → checkout, setup-zig, run `docs_zig.sh`, install mkdocs-material + plugins via pip, `mkdocs build`, upload+deploy to GitHub Pages |
| `docs/` (repo root) | Committed generated output (`mkdocs build` target dir) — apidocs, mds output, recipes wasm bundle, sitemap |

### Local preview — gap found

No dedicated script. `_notes.txt` records manual commands only — `mkdocs serve` (implied,  
standard mkdocs) is not used; instead notes show  
`python3 -m http.server 8080 --directory zig-out/docs_site/docs/recipes/` for the recipes  
wasm demo. tofu has no committed "regenerate + preview locally" single script; workflow is  
ad hoc.

### Flow diagram (as it exists in tofu today)

```
Local:
  zig build docs  ->  docs_site/docs/{apidocs,recipes}/   (autodoc, generated-from-source half)
  cd docs_site && mkdocs build  ->  ../docs/               (final site, md + autodoc merged)
  (no committed local-preview script; manual `python -m http.server` noted for one case)

CI (.github/workflows/docs.yml, push to main):
  checkout -> setup-zig 0.15.2 -> docs_zig.sh (zig build docs)
  -> pip install mkdocs-material + 4 plugins -> mkdocs build (in docs_site/)
  -> upload-pages-artifact (path: docs/) -> deploy-pages
```

### Cross-repo comparison

matryoshka-tk already has `.github/workflows/docs.yml` — an exact copy of tofu's (same  
paths, same pip plugins, same steps) — but none of the supporting infra exists yet: no  
`docs_zig.sh`, no `docs_site/`, no `build.zig` `docs` step, no committed `docs/` output.  
The CI workflow was pre-copied ahead of the infra it depends on. Open item for a future  
DOC stage: decide whether to keep it pre-copied or hold back until infra exists.

Odin matryoshka's approach differs: `kitchen/mkdocs.yml` + `kitchen/tools/build_site.sh`,  
`generate_apidocs.sh`, `preview_apidocs.sh`, `preview_site.sh` (dedicated preview scripts,  
unlike tofu) + `kitchen/docs/apidocs` (committed odin-doc output) — everything under one  
`kitchen/` folder, consistent with matryoshka-tk's own `kitchen/` convention. Its CI  
(`.github/workflows/docs.yml`) not read this pass — odin-language specific tooling  
(`odin-doc` binary instead of `zig build docs`); flag for later comparison only if useful,  
since matryoshka-tk is Zig, not Odin.

---

## Stage DOC 2 — confirm tofu + Odin "mix" decision

Decision + audit only, this version. Not yet implemented — DOC 3+ will build it.

### Odin `matryoshka/kitchen/` audit

Full contents read: `.github/workflows/docs.yml`, `kitchen/mkdocs.yml`,  
`kitchen/tools/build_site.sh`, `generate_apidocs.sh`, `preview_apidocs.sh`,  
`preview_site.sh`, `get_odin_doc.sh`.

What Odin's `kitchen/` already has, self-contained in one folder (matching  
matryoshka-tk's own `kitchen/` convention, unlike tofu's scattered layout):
- `kitchen/mkdocs.yml` — mkdocs-material config, `docs_dir: docs`, `site_dir: output`
  (both relative to `kitchen/`, not repo root like tofu).
- `kitchen/tools/build_site.sh` — one-shot: regenerate apidocs, then `mkdocs build`.
- `kitchen/tools/preview_apidocs.sh` — regenerate apidocs, `python3 -m http.server 8000`
  on `kitchen/docs/apidocs` only. tofu has no equivalent (its `_notes.txt` only notes a  
  manual one-off command for the recipes wasm demo).
- `kitchen/tools/preview_site.sh` — regenerate apidocs, `mkdocs serve` (full site, live
  reload). tofu has no equivalent either (`docs_site.sh` only does a one-shot build).
- `.github/workflows/docs.yml` — checkout, install libcmark, build the `odin-doc` renderer,
  install mkdocs-material, `build_site.sh`, upload+deploy — all paths scoped under  
  `kitchen/`.

The one piece Odin cannot provide: `generate_apidocs.sh` + `get_odin_doc.sh` clone and  
build an external HTML renderer (`pkg.odin-lang.org`'s `odin-doc` tool), because Odin has  
no built-in doc-emit mechanism, then apply extensive `sed` post-processing (relative-path  
rewriting, cache-busting, asset-copying, blank-nav-link fixes) — all workarounds for that  
specific renderer's quirks. None of this applies to Zig.

### Conclusion — mix confirmed

matryoshka-tk's doc infra should mix the two:
- Layout, organization, CI shape, local-preview scripts — borrow from Odin
  `matryoshka/kitchen/` (single-folder convention already required by matryoshka-tk's own  
  rules; preview scripts tofu lacks).
- Autodoc generation mechanism — borrow from tofu's `build.zig` `docs` step
  (Zig-native `getEmittedDocs()`), replacing Odin's external-renderer approach, which does  
  not apply to Zig at all.

### Additional audit (3 findings)

1. **Zig `getEmittedDocs()` output needs no post-processing, confirmed.** tofu's generated
   `docs_site/docs/apidocs/` is just 4 files — `index.html`, `main.js`, `main.wasm`,  
   `sources.tar` — a client-side WASM app that renders docs dynamically from the bundled  
   `sources.tar`. `grep` for absolute `href="/"` paths found zero matches. Architecturally  
   nothing like Odin's per-package static HTML tree — no analogous  
   relative-path/asset-copy/cache-busting problem to work around.
2. **matryoshka-tk needs 3 doc targets, not tofu's 2.** tofu's `docs` step builds 2
   `addObject` targets: `tofu` (lib) + `cookbook` (recipes, imports `tofu` + `mailbox`).  
   matryoshka-tk's `build.zig` already defines the equivalent shape but with three modules:  
   `matryoshka` (`src/matryoshka.zig`, the lib), `examples` (`examples/examples.zig`,  
   imports `matryoshka` + `helpers`), `stories` (`stories/stories.zig`, imports `matryoshka`
   + `helpers`) — plus an unexported `helpers` module used by both. A future `docs` step
   should add one `addObject`+`getEmittedDocs()`+`addInstallDirectory` target per module  
   (3, or 4 if `helpers` also gets its own docs page).
3. **mkdocs nav content needs fresh authoring, not a 1:1 borrow.** Odin's `mkdocs.yml` nav
   is one page-pair (quickref + deepdive) per architecture block, sourced from  
   `kitchen/docs/block*_{quickref,deepdive}.md`. matryoshka-tk's existing `kitchen/docs/*.md`  
   are a different shape — topical asides (storytelling docs, slot-vs-ref-counting,  
   tag-vs-tagged-union, typeErasedQueue-vs-mailbox, test-example-story), not a per-layer  
   quickref/deepdive pair — and matryoshka-tk's real narrative source of truth lives in  
   `design/` (rules, patterns, model, api-reference, stories), not `kitchen/docs/`. Neither  
   prototype's nav can be borrowed as-is; nav content and structure need fresh authoring in  
   a later DOC stage.

---

## Stage DOC 3 — kitchen/ doc folder layout proposal + "DOCS folder" claim check

Analysis + advice only, this version. No `.zig`, `build.zig`, `mkdocs.yml`, or actual  
`kitchen/` subfolders created this stage — DOC 4+ will build it.

### Must-rule re-confirmed

All doc housekeeping — mkdocs config, generation/preview scripts, hand-written narrative  
`.md` sources — must live under `kitchen/` and its subfolders. Matches Odin `matryoshka`  
convention (see `[[reference_odin_matryoshka]]` memory); no new evidence contradicts it.

### "DOCS folder" claim — checked against both prototypes, refuted as stated

matryoshka-tk's current pre-copied `.github/workflows/docs.yml` has:  
```yaml
- uses: actions/upload-pages-artifact@v3
  with:
    path: docs/
```
Copied verbatim from tofu, where it only makes sense because tofu's `docs_site/mkdocs.yml`  
sets `site_dir: ../docs` — mkdocs deliberately escapes `docs_site/` and writes the built  
site into a **top-level `docs/`** folder at repo root. That's a build artifact placed  
outside tofu's own housekeeping folder — the same scattered-layout problem DOC 1/DOC 2  
already flagged in tofu.

Odin `matryoshka` does **not** do this: `kitchen/mkdocs.yml` sets `site_dir: output`  
(i.e. `kitchen/output/`, relative to `kitchen/`), and its `.github/workflows/docs.yml`  
points `upload-pages-artifact` directly at `path: kitchen/output` — no top-level `docs/`  
folder exists or is needed. `actions/upload-pages-artifact` accepts any path, nested or  
not; there is no GitHub Pages requirement that the artifact source be named `docs/` or  
live at repo root — that naming only matters for the older, non-Actions "deploy from a  
branch" Pages mode, which neither tofu nor Odin nor matryoshka-tk uses.

**Conclusion**: matryoshka-tk does **not** need a new top-level `DOCS` folder. Keeping  
`site_dir` under `kitchen/` (Odin-style) satisfies GitHub Pages deployment identically  
while also satisfying the must-rule. matryoshka-tk's pre-copied `docs.yml` currently still  
points at the tofu-style top-level `path: docs/` — this needs fixing once `site_dir` is  
finalized in a build stage, or it will silently deploy an empty/missing artifact.

### Proposed folder/file layout (advice only, nothing created)

```
kitchen/
  mkdocs.yml                 # site_dir: output  (mkdocs config, Odin-style)
  docs/                      # hand-authored narrative source pages for mkdocs nav
    index.md                 # new: site landing page
    <existing *.md>           # matryoshka-storytelling-*.md, slot-vs-ref-counting.md,
                              # tag-vs-tagged-union.md, typeErasedQueue-vs-mailbox.md,
                              # test-example-story.md, matryoshka-readme-chat.md,
                              # matryoshka-tk-chat-prolog.md — kept as-is, added to nav
    apidocs/                  # generated: matryoshka (src) module's getEmittedDocs() output
    examplesdocs/             # generated: examples module's getEmittedDocs() output —
                              # stories folded in here too (examples imports it, just like
                              # tofu's single "cookbook" target already imports mailbox),
                              # so the split stays 2-way (src vs examples), matching tofu
  tools/
    docs_zig.sh                # new: `zig build docs` wrapper (replaces tofu's docs_zig.sh)
    build_site.sh               # new: docs_zig.sh + mkdocs build (Odin-style one-shot)
    preview_apidocs.sh           # new: regenerate + local http.server, Odin-style
    preview_site.sh               # new: regenerate + mkdocs serve, Odin-style
  _logo/                          # existing, unchanged
```

Key differences from both prototypes:
- **2 generated-doc subfolders — src vs examples — matching tofu's split exactly**
  (tofu: `apidocs` for the `tofu` lib, `recipes` for the combined `cookbook` target).  
  matryoshka-tk: `apidocs` for `matryoshka` (src), `examplesdocs` for `examples`, with  
  `stories` folded into the `examples` doc target rather than getting its own subfolder —  
  same way tofu's `cookbook` target already pulls in `mailbox` alongside its own recipes.  
  **This supersedes DOC 2 finding #2's "3 targets" note** — owner has directed a 2-way  
  split (src/examples), not 3.
- `kitchen/docs/*.md` narrative pages already exist — DOC 3 only proposes adding an
  `index.md` landing page and wiring existing files into `mkdocs.yml`'s `nav:`, not moving  
  or renaming them.
- `.github/workflows/docs.yml` needs updating: `path:` under `upload-pages-artifact`
  changes from `docs/` to `kitchen/output` (or whatever `site_dir` DOC 4+ finalizes), and  
  the "Regenerate Autodoc Artifacts" step's `./docs_zig.sh` becomes  
  `./kitchen/tools/docs_zig.sh` (or `zig build docs` directly — `build.zig` has no `docs`  
  step yet either; that's implementation, deferred to a later DOC stage).

### Open items carried forward

- matryoshka-tk's `.github/workflows/docs.yml` needs fixing: wrong `path:` (`docs/` should
  become `kitchen/output`), and references a non-existent `docs_zig.sh` and `build.zig`  
  `docs` step — flagged for the stage that actually builds the infra.
- mkdocs nav content still needs fresh authoring (DOC 2 finding #3, unchanged).

---

## Stage DOC 4 — build the kitchen/ doc infra, verify locally

Implementation stage: turned the DOC 3 proposal into working infra, exactly per that  
layout (2-way src/examples split, no top-level `DOCS` folder, everything under `kitchen/`).

### What was built
- `build.zig` — added a `docs` step: `addObject`+`getEmittedDocs()`+`addInstallDirectory`
  for `matryoshka` (src) → `kitchen/docs/apidocs`, and for a doc-only `edocsMod` (the  
  `examples/examples.zig` root source, importing `matryoshka` + `helpers` + `stories`) →  
  `kitchen/docs/examplesdocs`. `edocsMod` is separate from the runtime `emod` — folds  
  `stories` in for docs purposes only, mirroring tofu's `cookbookMod` importing `mailbox`,  
  without changing the existing `examples` module's public import graph.
- `kitchen/mkdocs.yml` (new) — Odin-style, `site_dir: output` (→ `kitchen/output/`),
  `docs_dir: docs`, material theme, nav wiring the 9 existing narrative `.md` files plus  
  the new `index.md`; only the `search` plugin (tofu's 4 extra plugins dropped — unused).
- `kitchen/docs/index.md` (new) — landing page linking to `apidocs/`, `examplesdocs/`, and
  the narrative docs.
- `kitchen/tools/docs_zig.sh`, `build_site.sh`, `preview_apidocs.sh`, `preview_site.sh`
  (new, executable) — Odin-style path resolution (`dirname "$(readlink -f "$0")"`), no  
  Odin-specific `odin-doc`/sed post-processing needed (Zig's autodoc is native).
- `.gitignore` — added `/kitchen/docs/apidocs/`, `/kitchen/docs/examplesdocs/`,
  `/kitchen/output/` (build artifacts).
- `.github/workflows/docs.yml` — fixed trigger `paths:` to match matryoshka-tk's actual
  layout (`src/**`, `helpers/**`, `examples/**`, `stories/**`, `kitchen/**`, `build.zig`),  
  fixed the autodoc step to `./kitchen/tools/docs_zig.sh`, fixed the mkdocs build step to  
  `cd kitchen && mkdocs build -f mkdocs.yml` with only `mkdocs-material` installed, fixed  
  `upload-pages-artifact` `path:` to `kitchen/output`.

### Local verification
- `zig build docs` — succeeded; `kitchen/docs/apidocs/` and `kitchen/docs/examplesdocs/`
  populated with Zig autodoc HTML/JS/WASM.
- `bash kitchen/tools/build_site.sh` — succeeded; `kitchen/output/index.html` built, with
  `apidocs/`, `examplesdocs/`, and all narrative pages present and linked in the nav.
- `zig build test -freference-trace --summary all` — 161/161 tests still pass; the new
  doc-only `edocsMod` doesn't disturb the existing build graph.
- All script output redirected to `zig-out/*.log` and inspected via `Read`/`grep`, per the
  kitchen-script-output rule — no raw stdout read.

### Deviations from the DOC 3 proposal
None — layout, script set, and 2-way target split matched the proposal exactly.

### Follow-up — reference-page nav/UX (still DOC 4 scope)
Odin's `kitchen/docs/api_reference.md` gives readers a choice ("Open here" vs "Open in new  
tab") before linking into its standalone generated API site. Owner directed matryoshka-tk  
to skip the choice: both `apidocs/` and `examplesdocs/` are standalone generated sites  
(Zig autodoc HTML/JS/WASM, not mkdocs pages), so both always open in a new tab, no prompt.  
Added `kitchen/docs/api_reference.md` and `kitchen/docs/examples_reference.md` (each a  
single `.md-button` with `target="_blank" rel="noopener"`), wired into a new `Reference`  
nav section in `kitchen/mkdocs.yml`, and updated `kitchen/docs/index.md`'s landing links to  
route through these pages instead of linking `apidocs/index.html`/`examplesdocs/index.html`  
directly. Verified in the built output: both buttons render with `target="_blank"  
rel="noopener"`. `zig build test` still 161/161.

---

## Stage DOC 5 — top-down entry point + nav skeleton

See Session Log entry above (2026-07-04) for full detail: four-source audit, decision to  
scope narrowly, changes, verification.

---

## Stage DOC 6 — populate Concepts with a story, top-down

See Session Log entry above (2026-07-04) for full detail: story-shape rationale,  
print-server adaptation, changes, verification.

---

## Stage DOC 7 — populate Building Blocks with one topic

See Session Log entry above (2026-07-04) for full detail: rule+pattern pairing  
rationale, Observable by human page, changes, verification.

---

## Stage DOC 8 — populate Building Blocks with the four core concepts

See Session Log entry above (2026-07-04) for full detail: core-concepts page,  
source distillation, changes, verification.

---

## Stage DOC 9 — re-partition and logically reorder the API reference

See Session Log entry above (2026-07-05) for full detail: content map, reorder  
rationale, Addendums/Io 101 split, changes, verification.

---

## Stage DOC 10 — dependency-order the API reference

See Session Log entry above (2026-07-05) for full detail: forward-reference findings,  
new order, method, verification.

---

## Stage DOC 11 — write matryoshka-manifesto-002.md

See Session Log entry above (2026-07-05) for full detail: sources, narrative arc,  
coverage notes, verification.

---

## Stage DOC 12 — de-smart the manifesto (-002 → -003)

See Session Log entry above (2026-07-05) for full detail: flagged style, rewrites,  
verification.

---

## Stage DOC 13 — unified pattern/idiom catalog (patterns-009 → -010)

See Session Log entry above (2026-07-05) for full detail: two-catalog problem,  
new structure, dedup rule, verification.

---

## Stage DOC 14 — audit Odin docs, add missing patterns/idioms

See Session Log entry above (2026-07-06) for full detail: bucket classification,  
7 added entries, verification.

---

## Stage DOC 18 — humanize the API reference (api-reference-019 → -020)

DOC 16/16b dropped "ownership" language from `src/*.zig` comments but explicitly  
deferred the api-reference doc itself as a separate future stage. This is that  
stage: `matryoshka-api-reference-019.md` still used "ownership-oriented  
infrastructure toolkit" / "Ownership model" / "Ownership flow" / "Ownership  
lifecycle" / "Cancellation ownership contract" framing (40+ hits) and mixed  
prose paragraphs into an otherwise staccato doc. Owner supplied 3 example files  
(`polynode.zig`, `mailbox.zig`, `pool.zig` under `/home/g41797/Downloads/`) —  
simplified doc-comment-only stubs — as a style model: plain send/place verbs,  
no academic framing.

**Changes**:
- `design/matryoshka-api-reference-019.md` → `-020.md` — dropped all
  "ownership" section titles/diagram captions/prose in favor of the  
  one-place-one-state phrasing already used in `src/`; converted 3 dense  
  run-on bullets (mailbox.receive waiter fairness, pool.get_wait zero-timeout,  
  pool.put_all mid-batch close) into one-fact-per-bullet staccato. Same  
  section order (DOC 9/10 dependency ordering untouched), same facts, same  
  diagrams (relabeled only). New Change-log row (020).
- `src/polynode.zig` — already matched the target style from a prior
  owner-applied edit (verified, no changes needed).
- `src/mailbox.zig` — a partial in-progress edit (wrong style: sentences split
  across blank-line-separated fragments; introduced a "FIFI" typo) was reverted  
  and rewritten from scratch in the polynode.zig staccato format. No  
  "ownership" language was present (DOC 16b already cleaned it) — this pass  
  was pure reformatting.
- `src/pool.zig` — file header was already updated by the owner; reworded the
  remaining function-level comments (get/get_wait/put/put_all/close/  
  PoolHooks/getWaitResult/get_wait_future) to the same staccato format. No  
  "ownership" language was present here either.
- `src/matryoshka.zig` — already matched the target style (owner-applied
  edit, verified, no changes needed).

**Verification**:

| Check | Result |
|---|---|
| `bash kitchen/build_and_test_debug.sh` (→ `zig-out/build_and_test_debug.log`) | PASS (167/167), re-run after each file |
| Live grep "ownership/owner/owns/owned" in the 4 `src/*.zig` files + `-020.md` | none (Change-log historical references in `-020.md` exempt, same precedent as DOC 9) |
| Banned-word scan | CLEAN — `unlock`/`ensureTotalCapacity` hits are real API names, not prose |
| Section/fact coverage `-019` vs `-020` | same structure, same tables/diagrams, wording-only diff |

**Next**: DOC 19+ — TBD, scoped with owner. Likely candidate unchanged: split  
api-reference-020.md into mkdocs Reference pages.

---

## Stages

DOC 1 — tofu audit. DONE.  
DOC 2 — confirm tofu + Odin mix decision (audit only). DONE.  
DOC 3 — kitchen/ doc folder layout proposal + DOCS-folder claim check. DONE (analysis only).  
DOC 4 — build kitchen/ doc infra (build.zig docs step, mkdocs.yml, tools/, docs.yml fix), verify locally. DONE.  
DOC 5 — top-down entry point (matryoshka-based-systems.md) + nav skeleton (Concepts/  
Building Blocks/Cookbook stubs). DONE.  
DOC 6 — populate Concepts with a story, top-down (print-server, system then  
Matryoshka). DONE.  
DOC 7 — populate Building Blocks with one topic (Observable by human: rule + pattern). DONE.  
DOC 8 — populate Building Blocks with the four core concepts (PolyNode/Mailbox/Pool/Master). DONE.  
DOC 9 — re-partition and logically reorder the API reference (api-reference-017 →  
-018); std.Io-generic material moved to Addendums/Io 101; Change-manifest repetition  
dropped. DONE.  
DOC 10 — dependency-order the API reference (api-reference-018 → -019): send/receive  
diagrams into mailbox, Tag identity after pool, Slot-based programming + Cooperative  
cleanup patterns after pool — nothing used before it is introduced. DONE.  
DOC 11 — write matryoshka-manifesto-002.md from README mindset + model/master/master-Tk  
sources; staccato, banned-word clean, persuasion-first. DONE.  
DOC 12 — de-smart the manifesto (manifesto-002 → -003): abstract architect-speak  
rewritten into plain human language, structure unchanged. DONE.  
DOC 13 — unified pattern/idiom catalog (patterns-009 → patterns-010): both halves  
merged, api-reference pattern material absorbed, no repetition, logical order. DONE.  
DOC 14 — audited Odin `matryoshka/kitchen/docs`, added 7 missing catalog entries  
(Request-Response, Pipeline, Fan-In, Fan-Out, Shutdown via Exit message,  
Thread-is-container, Intrusive node embedding) to patterns-011.md; 3 niche patterns  
explicitly skipped. DONE.  
DOC 15/15b — added `///`/`//!` doc comments to `src/*.zig` from api-reference-019;  
lifted the src/ `///` ban (rules-010 → rules-011). DONE. See STATUS.md session log.  
DOC 16/16b — terminology polish on `src/*.zig`: dropped "ownership" language,  
std.Io-style file headers (rules-011 → rules-013). DONE. See STATUS.md session log.  
DOC 17/17b/17c — snake_case entry points, autodoc fixes, example doc comments  
moved to file-level `//!` (rules-013 → rules-015). DONE. See STATUS.md session log.  
DOC 18 — humanized the API reference (api-reference-019 → -020): dropped  
"ownership" framing, staccato throughout; re-synced src/mailbox.zig and  
src/pool.zig comments to match. DONE.  
DOC 18b — new rule: `//!` block must end with bare `//!` + blank line.  
rules-015 → rules-016. SUPERSEDED by DOC 18c — hypothesis disproved against  
real rendered docs.  
DOC 18c — root-caused via headless-Chrome render of `zig build docs` output:  
Zig autodoc splices the first declaration's `///` comment onto the  
container page unconditionally (not a blank-line issue). Fix:  
`const _doc_stub = void;` as first declaration in mailbox.zig/pool.zig/  
polynode.zig. rules-016 → rules-017. DONE.  
DOC 19 — moved GitHub Pages generated site from `kitchen/output/` to  
root-level `docs/`. DONE. See STATUS.md session log.  
DOC 20 — removed the 8 example-autodoc `zig build docs` targets; added a  
hand-organized examples catalog under `kitchen/docs/examples/`, generated  
by new permanent `kitchen/tools/gen_examples_docs.sh`; 6 hand-authored  
catalog/group pages; rules-019 → rules-020. DONE.  
DOC 20 follow-up — wired all 76 mirrored example pages into  
`kitchen/mkdocs.yml`'s Examples Catalog `nav:` (were link-only orphans);  
new examples-catalog nav sync rule; rules-020 → rules-021. DONE.  
DOC 21+ — TBD. Planned iteratively, one stage at a time, not in advance. Likely  
candidate: split api-reference-020.md into mkdocs Reference pages.

---

## References

- [matryoshka-model-003.md](matryoshka-model-003.md) — thinking model
- [rules-017.md](rules-017.md) — coding, doc, and process rules
- [patterns-011.md](patterns-011.md) — unified pattern and idiom catalog, DOC 14 output
- [matryoshka-tk-docs-plan-013.md](matryoshka-tk-docs-plan-013.md) — prior version, superseded
- [matryoshka-api-reference-020.md](matryoshka-api-reference-020.md) — DOC 18 output, base for future Reference pages
- [matryoshka-manifesto-003.md](matryoshka-manifesto-003.md) — DOC 12 output, current manifesto
- tofu repo: `/home/g41797/dev/root/github.com/g41797/tofu`
- Odin matryoshka repo: `/home/g41797/dev/root/github.com/g41797/matryoshka`
