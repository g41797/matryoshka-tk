# 3tk — staging plan 034

Written 2026-09-09.

**Provenance.** Follows [3tk-staging-plan-033.md](backup/3tk-staging-plan-033.md),
which follows `032`, `031`, `030`, `029`, `028`, `027` and `026`. **Those
earlier ones are named, not linked as sources: `backup/` is transient — the
owner empties it — and it is never cited as a source of truth.**

**`033` is spent.** `3TK-72` was its only stage and it closed on 2026-09-09.
**Only `3TK-50` remains from any earlier plan, and it waits on the owner.**

State is in [3tk-status.md](3tk-status.md). Narrative is in
[3tk-log.md](3tk-log.md).

**The rules every stage is written against are in
[matryoshka-3tk/design/3tk-rules-004.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-rules-004.md)**
— two parts, the port rules and the stage rules. This plan cites that file; it
does not re-argue it.

---

## Why this plan exists

**Sixteen documents sit in `design/secondary/lang/c3/`, and three of them are
session state. The other thirteen have never been classified since the day they
were written.**

The published documents left one at a time, each carried by the stage that
happened to touch it: the reference, the rules, the example rules, the catalog,
the api table, the decisions record. **Nothing ever asked what should happen to
the rest.** What remains is a folder where a spent charter, a live language
study and a working log sit side by side with nothing marking which is which.

Measured 2026-09-09:

| lines | file |
|---|---|
| 10,994 | `3tk-log.md` |
| 2,102 | `3tk-bugs-pool.md` |
| 1,461 | `3tk-status.md` |
| 1,050 | `3tk-port-findings-004.md` |
| 990 | `3tk-lifetime-fix-005.md` |
| 865 | `c3-capabilities-002.md` |
| 814 | `3tk-bugs- mailbox.md` |
| 679 | `3tk-deviations-001.md` |
| 427 | `3tk-build-dist.md` |
| 354 | `3tk-open-defects.md` |
| 291 | `3tk-staging-plan-034.md` |
| 202 | `3tk-debts-notes-001.md` |
| 180 | `3tk-release-while-busy-001.md` |
| 152 | `3tk-sanitizer-notes-001.md` |
| 141 | `3tk-on-close-policy-001.md` |
| 112 | `3tk-on-close-handoff-001.md` |

Plus `ref/3tk-doc-loop-004.md`.

**The immediate cause was a question the owner asked**: is it worth moving
`c3-capabilities-002.md` into `matryoshka-3tk/design/`? The answer is yes and
the answer is not the point — **one file is not the problem, and moving it alone
leaves the folder exactly as confusing as it is now.**

---

## What the sitting of 2026-09-09 ruled

Written as ids. **A later stage cites an id; it does not re-argue the point.**

### A-1 — two questions decide every file, in this order

**One: is it still true?** A document whose subject is built, fixed, closed or
superseded goes to `backup/` — however well written, however recently. What it
recorded is in the log, which is the thing that keeps history.

**Two: who is its reader?** `matryoshka-3tk` is where a reader of the port
lands: someone who wants to know what C3 does, what the toolkit decided, and how
to use it. `matryoshka-tk` is where a session works. **A document only a session
reads does not move**, even when it is live and good.

**The order matters.** A spent document is never asked the second question.

### A-2 — three buckets, and every file lands in exactly one

- **Stays** — session state, and procedures for tools that live here.
- **Moves** — to `matryoshka-3tk/design/`, for the port's reader.
- **Retires** — to this folder's `backup/`, with a plain `mv`. No git.

**A file that cannot be classified is read until it can be.** There is no fourth
bucket and no "leave it for now": the whole point of the stage is that
"for now" is what produced the current folder.

### A-3 — the first pass, and it is a starting point, not a ruling

From the headers alone, before any file is read in full:

| file | first reading |
|---|---|
| `3tk-log.md`, `3tk-status.md`, `3tk-staging-plan-034.md` | **stays** — session state by definition |
| `ref/3tk-doc-loop-004.md` | **stays** — `A-5` |
| `3tk-open-defects.md` | **retires** — "eight fixed, zero open, two closed" |
| `3tk-lifetime-fix-005.md` | **retires** — built by 3TK-53/54/55, and the status says so |
| `3tk-on-close-policy-001.md` | **retires** — "fixed the same day" |
| `3tk-on-close-handoff-001.md` | **retires** — `P6`'s charter, and `P6` is built |
| `3tk-debts-notes-001.md` | **retires** — 3TK-15's two debts, both discharged |
| `3tk-deviations-001.md` | **retires** — 3TK-12's measurement, and it recommends; `A-6` |
| `c3-capabilities-002.md` | **moves**, after `A-4`'s trim |
| `3tk-port-findings-004.md` | **moves**, after `A-7`'s overlap check |
| `3tk-build-dist.md` | **moves or folds** — `A-8` |
| `3tk-sanitizer-notes-001.md` | **undecided** — `A-6` |
| `3tk-release-while-busy-001.md` | **undecided** — `A-14` |
| `3tk-bugs-pool.md`, `3tk-bugs- mailbox.md` | **undecided** — `A-9`, and most of the stage's cost |

**Every row is the stage's to overturn from the file itself.** The table says
where to start reading, not what to conclude.

### A-4 — the capability study is trimmed before it crosses

`c3-capabilities-002.md` is evergreen where it answers Q1 … Q12, and stage-bound
where it does not. **Two sections are 2026-08 scaffolding**: *For 3TK-5*, which
instructs a stage that ran long ago, and *What this study rules on*, which
resolves eleven conflicts between seven drafts that no longer exist.

**Deleted, not carried.** What survives is the twelve questions, the verified
spellings table, the two naming hazards and the toolchain section. If *What this
study rules on* settled something still true, that sentence moves into the
question it belongs to.

**It crosses as `c3-capabilities-003.md`**, `002` to this folder's `backup/`.
**And its measurements are re-read against the installed toolchain first** — the
study names c3c 0.8.3 in its own *toolchain measured* section, and a moved
document that quietly describes an older compiler is worse than one that stayed.
**If the toolchain has not moved, that is a sentence in the log, not a silence.**

### A-5 — the doc loop stays, and this is the general rule

`ref/3tk-doc-loop-004.md` is the procedure for `check-doc-loop.sh` and
`move-module-docs.sh`, and **those two scripts exist only in `matryoshka-tk`** —
they were never ported, deliberately. **A procedure lives with the thing it
drives.**

**It also carries a stale citation** — `3tk-reference-005.md`, four versions
behind — which `A-10` fixes.

### A-6 — a document that recommends to another port does not cross as it stands

The standing rule is that **port docs describe and never recommend**; a finding
for another port goes to the consuming port's own folder, where that port rules
for itself.

`3tk-sanitizer-notes-001.md` says in its own header *"what a later port should
copy"*. **So it stays, or its recommending half is rewritten as description
before it moves.** The stage chooses, and says which in the log.

`3tk-deviations-001.md` recommends too, but `A-1`'s first question settles it
before the second is asked: it is 3TK-12's measurement of a port that has since
been rebuilt. **A spent recommendation is the most misleading kind of live
file**, because a reader cannot tell it is spent from inside it.

### A-7 — `3tk-port-findings-004.md` is checked against the decisions record

Both claim to hold what the port decided and why —
`3tk-port-findings-004.md` here, `3tk-decisions-007.md` in `matryoshka-3tk`.
**Two documents doing one job is a defect whichever repo they are in**, and
moving one beside the other without checking would publish it.

**The stage reads both and rules one of three ways:** it moves as it is because
the two are genuinely different subjects; it moves with the overlap removed; or
it retires because `007` already carries what it says. **Whichever, the reason
is in the log.**

### A-8 — `3tk-build-dist.md` is language material, not port material

It is C3 packaging and distribution with no 3tk in it. **That makes it a
capability, not a finding**, so the question is not only where it goes but
whether it is a document at all: it may belong **inside** the capability study as
a thirteenth section rather than beside it. The stage decides.

### A-9 — the two bugs files are read, and that is most of the work

`3tk-bugs-pool.md` and `3tk-bugs- mailbox.md` are 2,916 lines between them, one
an implementation review and one owner thinking, **both predating most of what
the port now is.** Neither can be classified from its header.

**They are read in full and ruled like everything else.** The expected finding
is that they are history — the defects they describe are in
`3tk-open-defects.md`'s closed table and in the log — but **that is an
expectation, not a ruling**, and a live defect found inside either is a finding
the stage reports and does not fix. **This stage writes no code.**

**Also: `3tk-bugs- mailbox.md` has a space in its name**, between the hyphen and
`mailbox`. Whatever bucket it lands in, the name is corrected on the way.

### A-14 — `3tk-release-while-busy-001.md` is the one that may still be owed

It says of itself: **"a deferred item, ruled 2026-08-27 and not yet scheduled"**,
and it is the only file in the folder that claims to be work not yet done.
**`A-1`'s first question cannot be answered from its header**, because the
lifetime fix that came out of the same `Q5` was built afterwards, by 3TK-53,
3TK-54 and 3TK-55, and the owner's ruling of 2026-08-28 — *release while a call
is in flight is not prevented; it is written down and checked, not waited for* —
may be the whole of what this file asked for.

**The stage reads it against that ruling and the built `release` in both tools.**
If the ruling covers it, it retires. If something in it is genuinely unbuilt,
**it stays and the stage says so in the status** — an unscheduled item is state,
and state does not cross to the published repo. **It is not built here.**

### A-10 — stale citations are fixed in passing, in whatever survives

A document that stays or moves has its live references re-anchored: the doc
loop's `3tk-reference-005.md` is four versions behind, and others will surface
when the files are read. **A citation into `backup/` from a live file is a
defect** — `backup/` is transient.

**A retired document is not re-anchored.** It records what was true when it was
written, exactly as a log entry does.

### A-11 — the figures must not move, and no code is touched

`src/`, `test/`, `negative/` and `examples/` are not opened. **107 checks, four
builds, 145 tests each, doc loop 11 blocks and 443 of 443, sanitizers 3 of 3.**
Run at the end to prove the stage stayed inside `design/`.

### A-12 — the crossing needs the owner once, not per file

**Rule 12 does not cover this.** It covers `NNN` becoming `NNN+1` for a document
already in `matryoshka-3tk/design/`. **A document crossing repos is a new
document in that folder**, and the standing *ask before creating a file there*
applies.

**So the stage asks once, with the finished list in hand** — every file it
proposes to move, with its one-line reason — and then executes without asking
again. It does not ask per file, and it does not ask before it has read.

### A-13 — the stage decides, and does not come back

Every classification `A-1` names is the stage's. `A-3` is a starting point,
`A-4`, `A-6`, `A-7` and `A-8` are named as the stage's calls, and where a
definition turns out under-specified **Rule 11 governs** — fix it in the stage
and record what was fixed. **Every decision taken under this id is named in the
log entry**, so the owner reads them afterwards rather than being asked for them
in advance. **The one exception is `A-12`.**

---

## The stage

| stage | what it does | model |
|---|---|---|
| **3TK-73** | **The design-folder audit.** Thirteen documents read and classified into stays / moves / retires; the capability study trimmed and re-measured; `3tk-port-findings-004.md` checked against `3tk-decisions-007.md`; stale citations re-anchored; the moves made in one approved batch. **No code is written.** | **Opus 5** |

**Why Opus 5.** Rule 8's basis is how much of the stage is deciding rather than
applying. **Almost all of it is deciding**, and about 5,000 lines of prose have
to be read to decide it — two of them documents nobody has opened in stage-months.
The mechanical half is a handful of `mv`s.

### Steps

**1. Read the four that are already classified with confidence**, and confirm or
overturn: `3tk-open-defects.md`, `3tk-on-close-policy-001.md`,
`3tk-on-close-handoff-001.md`, `3tk-debts-notes-001.md`. These are short, and
they calibrate the two questions of `A-1` before the long files.

**2. `3tk-lifetime-fix-005.md` and `3tk-deviations-001.md`.** Both are long and
both are expected to retire. `A-1`'s first question, answered from the status
and the log rather than from the documents' own claims about themselves.

**3. The two bugs files** — `A-9`. The stage's real cost. Read in full.

**4. `3tk-port-findings-004.md` against `3tk-decisions-007.md`** — `A-7`. Both
in full, and the ruling written before anything moves.

**5. `c3-capabilities-002.md`** — `A-4`. Re-measure the toolchain, trim the two
scaffolding sections, write `003`, `002` to `backup/`. **Then `3tk-build-dist.md`
— `A-8` — because whether it folds in decides what `003` contains**, and doing
it after `003` is written means writing `003` twice.

**6. `3tk-sanitizer-notes-001.md`** — `A-6`. Stay, or rewrite the recommending
half as description.

**7. `ref/3tk-doc-loop-004.md`** — stays; re-anchor its citation.

**8. Ask the owner once** — `A-12` — with the finished list: every file proposed
to move, one line of reason each, and the retire list beside it for information.
**Then execute: the moves, the retires, the re-anchoring.**

**9. Close.** `run-builds.sh`, `check-doc-loop.sh`, `move-module-docs.sh
roundtrip`, `run-sanitizers.sh` — all four to prove `A-11`. The
`matryoshka-3tk/scripts/` diff and the `.yml` review (Rule 10 — **"none needed"
is an answer that must be written into the log**), both expected to be nothing,
since no script or workflow names any of these documents. Then the log entry and
this file's row in the status.

---

## What this plan does not do

- **It does not write code.** No `src/`, `test/`, `negative/` or `examples/`
  line is opened — `A-11`.
- **It does not fix a defect it finds.** A live defect inside the bugs files is
  reported and scheduled, not repaired — `A-9`.
- **It does not touch `3tk-log.md` or `3tk-status.md` as subjects.** They are
  session state; the stage writes to them only as every stage does, at the end.
- **It does not re-anchor a retired document** — `A-10`.
- **It does not move anything before the owner has seen the list** — `A-12`.
- **It does not empty `backup/`.** That is the owner's, and `backup/` being
  transient is why nothing that must survive is put there.
