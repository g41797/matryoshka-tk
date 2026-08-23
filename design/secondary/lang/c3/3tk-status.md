# 3tk — status

Current state of the 3tk line of work. One screen. Updated after every stage.

This file is the entry point for a cold session. Read it, then the stage named  
by the owner in [3tk-staging-plan-003.md](3tk-staging-plan-003.md).

## Scope

The Matryoshka port family: **otk** (Odin), **ztk** (Zig, this repo), **3tk**  
(C3), **dtk** (D). 3tk is the active target. otk needs refactoring, later. ztk  
needs tuning, later. dtk is thinking only.

The first deliverable is not C3 code. It is a portable specification of  
Matryoshka, language-neutral and self-contained, usable as the sole input for  
any port.

## Where the work lives

Everything for these stages lives in this folder,  
`design/secondary/lang/c3/` — plans, status, log, audits, specification,  
reviews, notes.

`c3/backup/` holds what is no longer read: the seven raw drafts, superseded by  
`3tk-drafts-review-001.md`, the review that retired proposal 002, and **every  
superseded version** — of the plan, the proposal and the specification. The  
live folder is what is current; `backup/` is the record. Moved 2026-08-23, and  
every link that names a moved file was corrected to `backup/...` in place.

`design/STATUS.md` and `design/STATUS-LOG.md` are not touched by this work and  
show no trace of it.

## Rules that hold across every stage

- Each stage starts cold. Its named inputs plus this file are enough.
- Each stage ends with advice: clear the context, or do not, and why.
- Finishing a stage does not start the next. The owner names it.
- **inner** = the embedded structure. **outer** = the struct that embeds it.
  Never "parent".
- Porting is not transpiling. The specification says what to preserve; each
  port decides how to spell it.

## Stages

| Stage | What | Output | State |
|---|---|---|---|
| 3TK-0 | staging plan, status, log | this folder | DONE 2026-08-23 |
| 3TK-1 | ztk audit — sources and docs | `ztk-audit-001.md` | DONE 2026-08-23 |
| 3TK-2 | the portable specification | `matryoshka-specification-001.md` | DONE 2026-08-23 |
| 3TK-3 | review of the seven c3 drafts | `3tk-drafts-review-001.md` | DONE 2026-08-23 |
| 3TK-4 | C3 capability study | `c3-capabilities-001.md` | DONE 2026-08-23 |
| 3TK-5 | the 3tk porting proposal | `3tk-porting-proposal-001.md` | DONE 2026-08-23 |
| 3TK-6 | the toolkit, in C3 | `3tk/` + `3tk-toolkit-notes-001.md` | DONE 2026-08-23 |
| 3TK-7 | the two containers, in C3 | `3tk/` + `3tk-containers-notes-001.md` | DONE 2026-08-23 |

## How to continue after a clear

Nothing is pending and nothing is authorized. A cold session reads this file
and stops here until the owner types one of the lines below.

### If there is a stage to run

The plan ends at 3TK-7 and every row above says DONE, so **there is no stage to
run right now**. Adding one is a single line, and the agent does the versioning
— it writes a new plan version, moves the pointer in this file, lists the old
version as superseded, and then runs the stage:

```
Add 3TK-8 to the plan and run it
```

To bump the plan without running anything yet, add `Do not run it.`

Once a stage exists in the plan, the shape for starting it cold is the standing
one. The command names **this file**, never the plan, because the plan is
versioned and its filename moves. This file does not:

```
Run 3TK-8 from design/secondary/lang/c3/3tk-status.md
```

Whatever the stage, the agent's first three actions are: read this file, read
the plan's section for that stage, read that stage's named inputs. Nothing
outside them. A stage whose row above reads DONE is not re-run without being
told.

### The candidates for a 3TK-8, and what each is worth

None is authorized. They are listed so the owner can name one without
re-deriving the list, and in the order this file would recommend them.

| Candidate | What it does | Why it might wait |
|---|---|---|
| **The sanitizer run** | Plan 003 asked for the concurrency tests under a sanitizer and 3TK-7 did not do it. First step is measuring whether c3c 0.8.3 offers one at all | The smallest real gap, and the only one that could still find a bug in the port |
| **Cross-target builds** | ztk is green on three cross targets; 3tk has been built for linux-x64 only | Mechanical, and `run-builds.sh` already has the shape for it |
| **A worked example** | An application using the port end to end — a producer, a consumer, a pool with real hooks — as documentation that compiles | The tests prove the invariants; nothing yet shows a reader how to *use* it |
| **Packaging** | `.c3l`, `c3c dist`, distribution. `backup/3tk-build-dist.md` B2 claims the tooling is early alpha, and that is still unverified | Outside the specification entirely, and it depends on the C3 toolchain rather than on this work |

The first three would each be one stage. Packaging may not be worth a stage
until B2 is checked, which is ten minutes of measurement.

### If you want a document revised, not a stage run

**A revision is not a stage.** It needs no plan version and it appears in no
stage table. `3tk-porting-proposal-002.md` was made this way — the owner
accepted the sixteen decisions and the amendments were folded in, with no stage
involved.

Type what you want changed, and name the document or just say which one:

```
Read design/secondary/lang/c3/3tk-status.md. Revise the porting proposal:
D5 should be a transparent alias, not a distinct Slot type.
```

```
Read design/secondary/lang/c3/3tk-status.md. Revise the specification:
Part 11.9's open question about the ztk book is settled — the book is being
fixed, so drop the note.
```

The versioning is the agent's work, not yours. It writes the next version
number, leaves the old file on disk, adds a row to *Superseded* naming what
replaced it, repoints the live pointers in this file, and appends to
`3tk-log.md`. The files that are edited in place instead — this one and the log
— are listed under *Files*.

**The rule that matters, and the agent applies it without being reminded:** a
revision that moves a decision has consequences in `3tk/`. The agent names the
source files that would change and **stops there**. Rewriting the code is a
separate instruction, and the four builds have to be green again before the
revision is finished:

```
...and apply it to the code.
```

Two things a revision is not allowed to do quietly. It does not renumber or
rewrite a finished stage's output — those record what was true when the stage
ran. And it does not repoint the provenance lines inside stage outputs, which
name the document version each stage was written against; only the live
pointers in this file move. The distinction is stated in *Superseded*.

### If the next work is not 3tk

The specification is the deliverable that outlives this line of work. Any of
these starts from `matryoshka-specification-002.md` and nothing else:

- **otk** (Odin) needs refactoring.
- **ztk** (Zig, this repo) needs tuning.
- **dtk** (D) is thinking only, and would start at its own capability study —
  the shape of `c3-capabilities-001.md`, answering Part 21 for D.

Those are separate lines of work with their own folders under
`design/secondary/lang/`, and none of them belongs in a 3TK stage.

### If you only want to know where things stand

```
Read design/secondary/lang/c3/3tk-status.md and report where the 3tk work stands.
```

### To verify the port without an agent

```
design/secondary/lang/c3/3tk/run-builds.sh
```

Four builds, exits non-zero on any failure. It needs `c3c` on the path and
nothing else.

## Files

Edited in place, no suffix — the entry points:

- `3tk-status.md` — this file.
- `3tk-log.md` — the narrative, append-only, newest first.

Versioned — a change makes a new file, the old one stays and is listed below:

- **Current plan: [3tk-staging-plan-003.md](3tk-staging-plan-003.md).**
- [ztk-audit-001.md](ztk-audit-001.md) — the 3TK-1 output.
- **[matryoshka-specification-002.md](matryoshka-specification-002.md) — the
  portable specification, and the source of truth for every port.** The 3TK-2
  output, revised.
- [3tk-drafts-review-001.md](3tk-drafts-review-001.md) — the 3TK-3 output.
- [c3-capabilities-001.md](c3-capabilities-001.md) — the 3TK-4 output.
- **[3tk-porting-proposal-003.md](3tk-porting-proposal-003.md) — the design of
  record. The sixteen decisions accepted by the owner, 2026-08-23.**
- [3tk-toolkit-notes-001.md](3tk-toolkit-notes-001.md) — the 3TK-6 output,
  beside the code at `3tk/`.
- [3tk-containers-notes-001.md](3tk-containers-notes-001.md) — the 3TK-7
  output.

### Superseded

**Every superseded version is in `backup/`.** Nothing is deleted, and the live
folder holds only what a current reader needs.

- [3tk-staging-plan-001.md](backup/3tk-staging-plan-001.md), replaced by plan
  002 on 2026-08-23. The only change was the addition of 3TK-6.
- [3tk-staging-plan-002.md](backup/3tk-staging-plan-002.md), replaced by
  [3tk-staging-plan-003.md](3tk-staging-plan-003.md) on 2026-08-23. The only
  change is the addition of 3TK-7.
- [3tk-porting-proposal-001.md](backup/3tk-porting-proposal-001.md), replaced by
  proposal 002 on 2026-08-23, when the owner accepted all sixteen decisions.
- [3tk-porting-proposal-002.md](backup/3tk-porting-proposal-002.md), replaced by
  [3tk-porting-proposal-003.md](3tk-porting-proposal-003.md) on 2026-08-23, in
  answer to [3tk-porting-proposal-review.md](backup/3tk-porting-proposal-review.md).
  No decision moved.
- [matryoshka-specification-001.md](backup/matryoshka-specification-001.md),
  replaced by
  [matryoshka-specification-002.md](matryoshka-specification-002.md) on
  2026-08-23. Three imprecisions the C3 port found, and invariant 34. No rule
  changed. **The other ports read 002.**

The stage outputs name the document versions they were written against. Those
are provenance and are not repointed; the live pointers above are.

**A path is not a pointer.** When a superseded file moves to `backup/`, the
links naming it are corrected to `backup/...` in place, in every file that
names it. That changes where the file is, never which version is named — the
stage outputs of 3TK-1 to 3TK-5 still name plan 001, and the notes of 3TK-6 and
3TK-7 still name proposal 001. Repointing provenance at a *newer* version is
what the rule forbids, and none of it happened.

The stage outputs of 3TK-1 to 3TK-5 each name plan 001 in their opening line.
Those are **provenance, not pointers** — they record which plan version the
stage ran under — and they are not repointed. The live pointers are the ones in
this file.

## Current state

**The 3tk line of work is complete.** Eight stages, 3TK-0 through 3TK-7, and
the owner's ruling on top of them.

The port covers all of Part 22 — the inner and the identity, the per-type
helper, the Slot, the list, the mailbox, the pool and its hooks. Part 17.1's
required tool and both of Part 17.2's optional ones.

```
all four builds green — 59 checks, 0 failures
  safe -O0 (--safe=yes -O0)   safe -O3 (--safe=yes -O3)
  fast -O0 (--safe=no  -O0)   fast -O3 (--safe=no  -O3)
73 tests in each of 4 builds, 7 runtime negatives, 2 tier 1 negatives,
3 compile-time refusals, 3 layering checks
```

Reproduce with `3tk/run-builds.sh`. It exits non-zero on any failure. Section
7.4 of the proposal says what each number counts.

**Part 18 is complete: all thirty-four invariants are accounted for.**
Twenty-nine are tested or provoked, five are structural or documented, and each
says which.

**The owner ruled on 2026-08-23: all sixteen decisions accepted, and G1's
submodules accepted.** `3tk-porting-proposal-003.md` is the design of record and
nothing in it is marked PROPOSED. The sixteen had all survived contact with the
compiler by then, which was the evidence the ruling was waiting for. No decision
has moved across three versions.

**A revision on 2026-08-23 answered `3tk-porting-proposal-review.md`** — 27
items, read against the code rather than taken on trust. It produced
specification 002 and proposal 003, one code change, and one real defect: a
tier 1 negative that had never compiled, passing because the harness read its
compile failure as the abort it was meant to prove. Proposal 003, section 9.

The documents, in the order a cold session reads them:

- `matryoshka-specification-002.md` — the portable specification. Source of
  truth for **every** port, not just this one.
- `3tk-porting-proposal-003.md` — the C3 shape of it. D1 to D16, accepted.
- `3tk-toolkit-notes-001.md`, `3tk-containers-notes-001.md` — what the code
  taught. Fifteen findings between them.
- `c3-capabilities-001.md`, `3tk-drafts-review-001.md`, `ztk-audit-001.md` — the
  measurements the proposal was built on.

**Nothing is waiting on the owner.** Nothing is authorized either: a new stage
needs a plan version 004 and the owner naming it.

## What is left, and none of it is Matryoshka

From `3tk-containers-notes-001.md`. Each of these is a candidate stage, and
*How to continue after a clear* has them as a table with a recommendation.

- **No sanitizer run.** Plan 003 asked for one; it was not done, and it was not
  measured whether c3c 0.8.3 offers one.
- **`a_leaver_hands_the_signal_on` is a race test run 20 times.** Passing is
  evidence, not proof.
- **linux-x64 only.** ztk is green on three cross targets; 3tk has been built
  for one.
- **Packaging.** `backup/3tk-build-dist.md` B2 claims C3 library packaging is early
  alpha and `c3c dist` incomplete. Still unverified, still a tooling stage's.

The other three ports are untouched by this line of work: **otk** needs
refactoring, **ztk** needs tuning, **dtk** is thinking only. The specification
is what any of them would be written from.

## Standing facts

- C3 is installed. `c3c` at `/usr/bin/c3c`. Stdlib sources at
  `/home/g41797/dev/langs/c3/lib/std/`. No install step in any stage.
- The toolchain measured by 3TK-4 is `c3c` 0.8.3, git `1d155ee`, LLVM 22.1.8,
  target linux-x64. Every capability answer is against that version.
- The seven `3tk-*.md` and `ztk-to-3tk.md` drafts, **now in `backup/`**, were
  written in separate sessions by different AIs. They contradict each other and
  some predate API 12, API 13 and INTR 8. They are raw input, never source of
  truth. 3TK-3 read them and measured them; `3tk-drafts-review-001.md` is that
  measurement, and it is what later stages read instead of the drafts. Read the
  measurement, not the drafts — that is why they are in `backup/`.
- ztk itself is green: 195/195 in four modes, three cross targets, INTR 8 closed
  2026-08-14.
- 3tk is green: 71 tests in four modes, plus 11 negative programs and 3
  layering checks. `3tk/run-builds.sh`.
- **Never infer a C3 build mode from the `-O` level.** `-O2` and above set
  `SAFE_MODE=false`. Always pass `--safe=yes` or `--safe=no` explicitly.
  `3tk-toolkit-notes-001.md` F1.
- The fault-return operator is `~`, not `?`. `return mtk::CLOSED~;`.
  `3tk-containers-notes-001.md` G2.

## Open questions

- ~~The allocator direction.~~ **Closed by the owner's ruling of 2026-08-23**,
  which accepted D3 along with the other fifteen. The answer is per type, by
  which helper the type takes: `mtk::owned` finds the outer's `Allocator` field
  at build time and names `mtk::helper` when there is none, so no release call
  in the port takes an allocator parameter. Proposal 003, D3, states it as one
  principle rather than three rules. The ztk half of the gap that 3TK-1
  measured — `ztk-audit-001.md` section 5.1, `destroy` taking an allocator it
  did not keep — is untouched by this and belongs to the ztk line.
- `Pool.get_wait` does not call `on_get`. The book says twice that it does.
  `ztk-audit-001.md` section 5.2. The code is the truth. The specification
  follows the code, Part 11.9. The book still needs a fix that is not this line
  of work.
- The specification is 1366 lines against the plan's expected 600-900. The
  staccato rule is one fact per line, and the content did not compress below
  this without dropping facts. Nothing was padded and nothing was cut to fit.
  Flagged for the owner.
- `kitchen/tools/check_design.sh` exits 1, not the 0 the plan expected. 3TK-5
  through 3TK-7 add orphan rows, same cause, not a regression. 3TK-6 added the
  first non-markdown files under `design/`, at `3tk/`; whether the gate has an
  opinion about `.c3` files there is unmeasured. It
  exited 1 before 3TK-2 as well. 43 problems: 14 dead links in `design/`, and
  29 orphans, all under `design/secondary/lang/`. 3TK-2 added exactly one
  orphan row, the new specification file. The cause is the next item.
- `design/secondary/context.md` does not list the `lang/` subfolders at all.
  Drift, noted, not fixed. Every file in `c3/`, `d/` and `odin/` is an orphan
  by the gate's count because of it.
- Three more documentation-drift items, all in `design/`, none touching `src/`.
  `ztk-audit-001.md` section 7.
