# Staging plan — the Matryoshka portable specification and the 3tk port

This file is the plan of record for the 3tk line of work.

Approved by the owner, 2026-08-23.

**Version 002.** It supersedes `3tk-staging-plan-001.md`, which stays on disk.
The only change is the addition of 3TK-6, on the owner's instruction of
2026-08-23. Stages 3TK-0 to 3TK-5 are reproduced unaltered — they are done, and
a plan version does not rewrite history.

The stage outputs of 3TK-1 to 3TK-5 each name `3tk-staging-plan-001.md` in
their opening line. Those references are **provenance, not pointers**: they say
which plan version the stage ran under, and that was 001. They are not
repointed. The live pointers — the ones in `3tk-status.md` — are.

## Context

Matryoshka is becoming a family of ports, named by language initial + `tk`:  
**otk** (Odin, refactor later), **ztk** (Zig, the current repo, tuning later),  
**3tk** (C3, the active target), **dtk** (D, thinking only).

`design/secondary/lang/c3/` already holds seven `.md` drafts written in separate  
sessions by different AIs. They overlap, they contradict each other, and some  
predate API 12, API 13 and INTR 8. They are raw input, never source of truth.

The gap: there is no statement of what Matryoshka *is* independent of Zig. The  
drafts each invented one. So the first deliverable is a **portable
specification** — self-contained, language-neutral, complete enough that D or  
any other language can be ported from it alone, with `src/polynode.zig`,  
`src/mailbox.zig` and `src/pool.zig` as the only external reference.

Porting is not transpiling. The specification says what a port must preserve;  
each port decides how to spell it idiomatically. ztk's hand-rolled tag is the  
example — in C3 that identifier is native to the language.

## Storage rule — owner's instruction, no exceptions

Every file these stages produce goes under `design/secondary/lang/c3/`: plans,  
status, log, audits, specification, reviews, notes. `design/STATUS.md` and  
`design/STATUS-LOG.md` are not touched. Nothing of substance lives only in  
Claude memory.

## Standing rules for every stage

- **Cold start.** Each stage is self-contained. Its named inputs plus
  [3tk-status.md](../3tk-status.md) are enough to run it. No stage depends  
  on conversation carried from the previous one.
- **Clear advice.** Each stage ends with an explicit recommendation — *clear* or
  *do not clear* — and the reason. Clear when the next stage's inputs are  
  disjoint. Do not clear when the reasoning still in context is needed, and say  
  what would be lost.
- **No rolling.** Finishing a stage does not start the next. The owner names it.
- **Every stage carries its start command.** The exact line the owner types to
  run it after a context clear is printed under the stage heading, and repeated
  in [3tk-status.md](../3tk-status.md). A stage closes by naming the command for
  the next one. The command names the status file, never a versioned file, so it
  survives every version bump.
- **Nothing authorized by this plan.** Plan approval is not stage approval.
- Terminology: **inner** = the embedded structure, **outer** = the struct that
  embeds it. Never "parent". Applies to all prose in every port.

## How a stage is started

The owner types one line. The agent reads
[3tk-status.md](../3tk-status.md) and this file, finds the named stage,
and runs it. Nothing else is needed — that is what cold start means.

The command for each stage is printed under its heading below.

The agent's first three actions in every stage, in order:

1. Read [3tk-status.md](../3tk-status.md).
2. Read this file, and the section of the named stage.
3. Read the stage's named inputs. Nothing outside them.

If the stage's row in the status table already reads DONE, stop and say so.
Do not re-run a finished stage without being told.

## The stages

### 3TK-0 — this plan

Write this document. Create [3tk-status.md](../3tk-status.md) (current  
state, one screen) and [3tk-log.md](../3tk-log.md) (append-only narrative,  
newest first). *Advice on clear: yes, after.*

### 3TK-1 — ztk audit

**Start after clear** — type this, nothing else:

```
Run 3TK-1 from design/secondary/lang/c3/3tk-status.md
```

Read-only evidence gathering. Every claim names a file and a line range.

Inputs: `src/matryoshka.zig`, `src/polynode.zig`, `src/mailbox.zig`,  
`src/pool.zig`, `src/internal/cond_timeout.zig` in full including `///` and  
`//!` comments; then `matryoshka-concepts-003.md`,  
`matryoshka-architecture-foundation-4-006.md`, `language-of-matryoshka.md`,  
`matryoshka-api-reference-042.md`, `patterns-029.md`,  
`matryoshka-zig-0.16-notes-003.md`, `kitchen/docs/addendums/slot-idiom.md`,  
`rules-049.md` Part 3 (the Slot Rule).

Not read: the `c3/` drafts, `STATUS-LOG.md`, the `d/` and `odin/` folders. The  
firewall against the drafts is deliberate — the specification must not inherit  
their contradictions.

Output `ztk-audit-001.md`:

1. The public surface, verbatim: `PolyTag`, `PolyNode`, `ItemHandle`, `Slot`,
   `PolyHelper(T)`, `ItemList` + `Iterator`, `Mbox`, `Pool`, companion types,  
   every signature and error set.
2. The invariants, from the asserts and doc comments: `is_linked`, `reset`, the
   Slot Rule, close-before-destroy, the give-back rule, hook contracts.
3. Essential vs incidental, one row per feature, with a reason. `comptime`,
   `@fieldParentPtr`, error sets, `std.Io`, `defer`/`errdefer`,  
   `std.DoublyLinkedList`.
4. **The excluded surface** — the named declarations that exist only to bridge
   `std.Io`. Enumerated once here so no port re-derives it.
5. **Intended vs actual** — where the owner's direction differs from today's
   code. The allocator is the known case: objects should take an allocator at  
   creation and hold it for life; ztk is not exactly there. Flagged, not fixed.
6. Open questions for any port.
7. Drift noted, not fixed: `design/secondary/context.md` does not list the
   `lang/` subfolders.

*Advice on clear: yes — the specification works from this file, not from the  
reading.*

### 3TK-2 — the portable specification

**Start after clear** — type this, nothing else:

```
Run 3TK-2 from design/secondary/lang/c3/3tk-status.md
```

Output `matryoshka-specification-001.md`. Language-neutral. Zig appears only as  
one realization. Self-contained: the audit and the three `src/` files are the  
only external references. Expected 600-900 lines, one file, numbered parts.

The owner's points are the spine, one section each:

- **Execution model.** Plain OS threads or equivalent. Not fibers, not
  goroutines, not an async runtime. Blocking with timeout is the primitive.
- **Participants are long-lived heap objects**, allocated once, living for the
  duration.
- **Intrusion.** The outer embeds an inner holding the list links, so items
  thread onto type-erased lists with no allocation and no knowledge of the  
  outer type.
- **Identity.** The inner carries a unique identifier of the outer.
- **Self-identification.** Any struct compares its own identity against that
  identifier to decide who is who. This is what makes a type-erased list safe  
  to walk and a received item safe to claim.
- **The per-type helper**, generated at compile time, bound to one outer type:
  the initializer, and the conversions across the type-erased border in both  
  directions, with the identity check.
- **The intrusive list**, holding heterogeneous items on one list.
- **The Slot idiom** — a container of a pointer whose emptiness is the transfer
  signal. Covers transfer and creation both.
- **Deliberate synonyms** — handle, slot, item name one thing under different
  usage stress. Preserved, not collapsed.
- **The two infrastructure objects**, Mbox and Pool, on one internal base, both
  themselves items that can travel, both with hidden implementation where the  
  language allows.
- **Hooks as an interface** — user-supplied callbacks behind a hidden
  implementation, in the language's own interface mechanism.
- **Allocators** — taken at creation, held for the object's life.

Then, from the audit: what Matryoshka is and is not; the three tools and why two  
are optional; the transfer model, one owner at a time; the concurrency contract  
stated without `std.Io`; the excluded surface.

Two devices make the specification usable rather than descriptive:

- **Conformance markings** on every element — **MUST** (remove it and it is not
  Matryoshka), **SHOULD** (shape fixed, spelling is the port's business),  
  **MAY** (convenience, skippable), **EXCLUDED** (exists only because of Zig).
- **The capability questionnaire**, closing the document: the questions a
  language must answer before it can host Matryoshka — compile-time generation  
  over a type; opaque types; interfaces or vtables; embedding and inner-outer  
  address arithmetic; a unique per-type identifier; scope-exit cleanup; threads  
  with condition variable and timeout; an allocator an object can hold for life.  
  Each port answers the same list.

Style: `design/` rules — short sentences, bullets, staccato, the banned-word  
list of `rules-049.md` Part 5.

*Advice on clear: yes, after.*

### 3TK-3 — drafts review

**Start after clear** — type this, nothing else:

```
Run 3TK-3 from design/secondary/lang/c3/3tk-status.md
```

The first stage that opens the seven `c3/` drafts. Each claim is measured  
against the specification and the audit.

Output `3tk-drafts-review-001.md`: one row per claim — which draft, what it  
asserts, whether it holds against current ztk, which other draft it contradicts,  
and a recommendation. Conflicts are reported, not resolved. The owner rules.

*Advice on clear: no — the ruling needs this reasoning in context.*

### 3TK-4 — C3 study

**Start after clear** — type this, nothing else:

```
Run 3TK-4 from design/secondary/lang/c3/3tk-status.md
```

C3 is installed: `c3c` at `/usr/bin/c3c`, stdlib sources at  
`/home/g41797/dev/langs/c3/lib/std/`. No install step.

Read `collections/`, `threads/`, `io/`, `core/`, `os/`, `atomic.c3` and answer  
the capability questionnaire for C3, with a citation per answer. Output  
`c3-capabilities-001.md`.

*Advice on clear: yes, after.*

### 3TK-5 — the 3tk porting proposal

**Start after clear** — type this, nothing else:

```
Run 3TK-5 from design/secondary/lang/c3/3tk-status.md
```

From the specification, the ruled review and the questionnaire answers. Output  
`3tk-porting-proposal-001.md`: the C3 shape of every MUST and SHOULD, the  
mapping table, what is dropped and why, and the build and test approach.  
Idiomatic C3, not transliterated Zig.

*Advice on clear: decided at the time.*

### 3TK-6 — the toolkit, in C3

**Start after clear** — type this, nothing else:

```
Run 3TK-6 from design/secondary/lang/c3/3tk-status.md
```

Added in plan version 002, 2026-08-23, on the owner's instruction.

**The first stage that writes C3.** Steps 2 to 5 of Part 22: the inner and the
identity, the per-type helper with the crossings, the Slot and its six rules,
the list with both insert checks. That is the toolkit of Part 17.1 — the one
required tool, the thing without which there is nothing to port.

The two containers are **not** in this stage. Part 17.2 makes them optional and
Part 22 makes them steps 6 and 7. A separate stage, if the owner names one.

Inputs: `3tk-porting-proposal-001.md` and `matryoshka-specification-001.md`.
The capability study for a spelling that the proposal does not give. The seven
drafts are not reopened; `src/` is not reopened.

**On the sixteen decisions.** The owner instructed this stage to run in the same
breath as adding it, without ruling on them separately. That instruction is read
as acceptance of `3tk-porting-proposal-001.md` as written. The stage implements
the sixteen as ruled, and records in `3tk-log.md` any place where writing the
code contradicted a decision. A decision that survives compilation is a
decision; one that does not is a finding for the owner.

Output, under `design/secondary/lang/c3/3tk/`:

- `project.json` — section 7.1 of the proposal, as written.
- `src/any.c3` — `AnyNode`, `AnyHandle`, `Slot`, the `@check` macro, the fault
  set. D5, D6, D15.
- `src/helper.c3` — `mtk::helper <Type>`, Part 7.2's members, Part 7.4's
  build-time validation.
- `src/owned.c3` — `mtk::owned <Type>`. D3, D10.
- `src/list.c3` — `NodeList` and its iterator, the sixteen operations of the
  proposal's 5.5, both insert checks, the repair, the self-move pair.
- `src/mtk.c3` — the front door.
- `test/` — the tests of the proposal's 7.3 that apply to steps 2 to 5.

**Verification, and it is the stage's spine.** The four builds of the
proposal's 7.2, every one of them, green:

| Build | Flags |
|---|---|
| Safe, unoptimized | default |
| Safe, optimized | `-O3` |
| Fast, unoptimized | `--safe=no -O0` |
| Fast, optimized | `--safe=no -O3` |

The fourth is the one that segfaulted in 3TK-4's Q11 probe. Running it green is
what proves D6 was applied. A stage that reports three builds has not run.

The stage also writes `3tk-toolkit-notes-001.md`: what the code taught that the
proposal did not know, per-decision, and the state of every Part 18 invariant
the toolkit reaches.

*Advice on clear: decided at the time.*

## Versioning of the files in this folder

Part 0 of `rules-049.md` forbids overwriting a doc. `design/` exempts two stable
entry points — `STATUS.md` and `context.md` — and edits them in place. This
folder uses the same three-way split. Owner's ruling, 2026-08-23.

Edited in place, no suffix. Entry points, not documents:

- [3tk-status.md](../3tk-status.md) — current state. Rewritten every stage.
- [3tk-log.md](../3tk-log.md) — the narrative. Append-only, newest first.

Versioned, suffix required. Every change makes a new file:

- this plan — `3tk-staging-plan-NNN.md`, currently 002
- `ztk-audit-NNN.md`
- `matryoshka-specification-NNN.md`
- `3tk-drafts-review-NNN.md`
- `c3-capabilities-NNN.md`
- `3tk-porting-proposal-NNN.md`

A superseded version stays on disk. It is listed in the Superseded section of
[3tk-status.md](../3tk-status.md), naming what replaced it, and every reference to
it is repointed. Nothing here is deleted.

The plan is versioned, so its filename moves. That is why the start command
names [3tk-status.md](../3tk-status.md) instead: the status file always says which
plan version is current, and the line the owner types never changes.

The seven pre-existing drafts keep their unsuffixed names. They are frozen
input, and renaming them is a `git mv`, which is owner-only.

## Verification

- Stages 1-5 modify nothing outside `c3/`. No kitchen gate applies.
- 3TK-6 writes C3 under `c3/3tk/`. Still inside `c3/`, so the storage rule
  holds and no kitchen gate applies. `src/` at the repository root is the ztk
  Zig source and is not touched by any stage of this plan.
- `kitchen/tools/check_design.sh` covers `design/`; run it once after 3TK-2 to
  confirm the additions under `secondary/` changed nothing. Expected exit 0.
- Each stage ends with its file written under `c3/`, a row appended to
  [3tk-log.md](../3tk-log.md), [3tk-status.md](../3tk-status.md)  
  updated, a report to the owner, and the clear-or-not advice.
