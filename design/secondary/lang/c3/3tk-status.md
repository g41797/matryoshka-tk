# 3tk — status

Current state of the 3tk line of work. One screen. Updated after every stage.

This file is the entry point for a cold session. Read it, then the stage named  
by the owner in [3tk-staging-plan-014.md](3tk-staging-plan-014.md).  
For what else is in this folder and who reads it, see [README.md](README.md).

## Scope

The Matryoshka port family: **otk** (Odin), **ztk** (Zig, this repo), **3tk**  
(C3), **dtk** (D). 3tk is the active target. otk needs refactoring, later. ztk  
needs tuning, later. dtk has a prepared folder and no stage has run —  
[../d/dtk-status.md](../d/dtk-status.md).

The first deliverable is not C3 code. It is a portable specification of  
Matryoshka, language-neutral and self-contained, usable as the sole input for  
any port.

## Where the work lives

Everything for these stages lives in this folder,  
`design/secondary/lang/c3/` — plans, status, log, reviews, notes, and the code  
at `3tk/`.

**Two of them left on 2026-08-23.** The portable specification and the ztk audit  
now live in [`../common/`](../common/README.md), because they bind every port  
and never bound only this one. The specification always said so of itself — *a  
port is written from this file alone* — while sitting in a consumer's folder,  
and the revision of that day sent the bill: two of the twenty-seven review items  
were *specification* defects, and fixing them here alone would have left the  
same trap set for D and Odin. A shared input inside one consumer's folder is a  
fork waiting to happen. `common/` also contains  
[port-flow-001.md](../common/port-flow-001.md), the 3tk process written as  
process. Every link that named a moved file was corrected in place, both  
directions.

`c3/backup/` contains what is no longer read: the seven raw drafts, superseded by  
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
| 3TK-8 | the design review answered, the hiding question measured | `3tk-porting-proposal-004.md` + `3tk/` | DONE 2026-08-23 |
| 3TK-9 | the sanitizer run | `3tk-sanitizer-notes-001.md` + `3tk/` | DONE 2026-08-23 |
| 3TK-10 | the core redesign, as a proposal | `3tk-core-redesign-proposal-001.md` | DONE 2026-08-23 |
| 3TK-11 | the core redesign, in code | `3tk/` + [3tk-core-redesign-notes-001.md](3tk-core-redesign-notes-001.md) | DONE 2026-08-23 |
| 3TK-12 | the deviation audit — the port measured against the specification | [3tk-deviations-001.md](3tk-deviations-001.md) | DONE 2026-08-24 |
| 3TK-13 | specification 003 | [matryoshka-specification-003.md](../common/backup/matryoshka-specification-003.md) | DONE 2026-08-24 — superseded by 004 |
| 3TK-14 | the helper surface, re-thought | [3tk-helper-proposal-001.md](3tk-helper-proposal-001.md) | DONE 2026-08-24 — twelve items + E6, E7. **All ruled** |
| 3TK-15 | the two debts of 3TK-13 — A3 and A5 | `3tk/` + [3tk-debts-notes-001.md](3tk-debts-notes-001.md) | DONE 2026-08-24 — `UNKNOWN_IDENTITY`, and twelve comments that changed a claim |
| 3TK-16 | the helper surface, in code — H0, H0b, H5, H10 | `3tk/` + [3tk-helper-notes-001.md](3tk-helper-notes-001.md) | DONE 2026-08-24 — 35 aliases to 0. **V19 filed** |
| 3TK-17 | Part 7.1 reworded — E6, V19 | [matryoshka-specification-004.md](../common/matryoshka-specification-004.md) | DONE 2026-08-24 — one Part, and **before dtk's first stage**. dtk told |
| 3TK-18 | `Inner.next` becomes `Inner.link` | `3tk/` | DONE 2026-08-24 — two words, no layout or behaviour change. No new document |
| 3TK-19 | the three debts of 3TK-15 and 3TK-17 | `3tk/` + [3tk-deviations-001.md](3tk-deviations-001.md) + [`../odin/`](../odin/odin-to-zig-backport-001.md) | DONE 2026-08-24 — **neither citation was a repointing**. P2 marked fixed, otk told |
| 3TK-20 | what 3tk learned, for another port to read | [3tk-port-findings-001.md](backup/3tk-port-findings-001.md) | DONE 2026-08-24 — ten sections, **recommends nothing**. ztk read, never written |
| 3TK-21 | `struct Inner { any link; }` | `3tk/` | DONE 2026-08-25 — 16 bytes before and after. **`@private` does not apply to a C3 method**, so the two are public. No new document |
| 3TK-22 | the findings document, against the new shape | [3tk-port-findings-002.md](backup/3tk-port-findings-002.md) | DONE 2026-08-25 — §1 re-cut, every citation re-read, **new §1a**. 001 in `backup/`. Recommends nothing |
| 3TK-23 | retire what is no longer read | `backup/` + every link | DONE 2026-08-25 — four files moved, **18 links repointed**, nothing deleted. Two things found and reported, not done |
| 3TK-24 | the pool difference, for another port | [3tk-port-findings-003.md](3tk-port-findings-003.md) | DONE 2026-08-25 — **new §5a**, the `on_get` difference. Every citation printed and read. 002 in `backup/`. Recommends nothing |
| 3TK-25 | the status file becomes an entry point | this file + [3tk-log.md](3tk-log.md) | DONE 2026-08-25 — 1,733 lines to 938. Eight sections out, **nine closed open questions out**, and a false R4 row found |
| 3TK-26 | the stale `inner.c3` citations | [3tk-deviations-001.md](3tk-deviations-001.md) + two | DONE 2026-08-25 — **21 repointed** across three files. Three quoted-transcript numbers left standing, and V1 named as understating itself |
| 3TK-27 | who reads the notes | [3tk-readership-001.md](3tk-readership-001.md) | DONE 2026-08-25 — **three of seven are read**. Retired nothing, moved nothing |
| 3TK-28 | a README for the folder | [README.md](README.md) | DONE 2026-08-25 — **19 live documents indexed**, one line each. Every link printed and checked |

## How to continue after a clear

**Every stage of plan 009 has run.** 3TK-0 to 3TK-17, and 009 is in `backup/`.

```
3TK-16  (code, DONE)   →   3TK-15  (the debts, DONE)   →   3TK-17  (the specification, DONE)
```

**[3tk-staging-plan-014.md](3tk-staging-plan-014.md) is the plan of record**,
written 2026-08-25 after 013 was spent. **Everything 3TK-0 to 3TK-23 has run.**
014 declares **3TK-24 to 3TK-28**, and **all five have run.** The plan is
spent; there is no declared stage.

**014 does not reproduce 013, and that is a change of practice the owner ruled
on 2026-08-25.** A plan holds only what has not run; finished stages live in
[3tk-log.md](3tk-log.md), briefly. Every version through 013 reproduced every
earlier stage, which is why 013 reached 2,775 lines to declare three. 014 is
301 to declare five.

```
3TK-21  (Inner becomes one any)  →  3TK-22  (the findings document)
        HAS RUN                             HAS RUN
3TK-23  (retire what is no longer read) — HAS RUN
```

**3TK-21 has run, 2026-08-25. `struct Inner { any link; }` is the shape.**
`link.ptr` is R6b's chain link, `link.type` is Part 5's identity, and **the two
meanings did not move**. **16 bytes before and 16 after — measured**, and the
eight bytes were R6b's when it deleted `prev`. Nine link writes go through
`Inner.repoint_to`; `helper::init` is the one place the identity is written, and
that is one grep. Four builds green, 63 checks and 0 failed, 87 tests in every
mode; **`run-sanitizers.sh` 3 runs, 0 findings** — thread safe -O0, thread
fast -O3, address safe -O0, each clean at 87. No public struct or signature changed, no
edit to `../common/`, and no new document — the row is in
[3tk-log.md](3tk-log.md).

**One thing came out wider than the plan wanted, and the language decided it.**
The plan asked for `repoint_to` and `points_to` to be `@private` if the
containers were in module `mtk` proper. They are, but **C3 ignores `@private` on
a method declaration and warns that it does**, so the two sit on the public
surface beside `Inner.to` and `Inner.as`. The probe measured it before the sweep
rather than after, and `inner.c3` says so where a reader will meet it.

**One debt was created and it is paid.** The rewrite of `inner.c3` moved every
line in the file, so `3tk-deviations-001.md`'s nine `inner.c3:NNN` citations
went stale — V1, V5 and V12 among them, the three rows that describe the inner's
shape. 3TK-21's plan named its outputs as `3tk/`, the log and this file, and a
stage may not rewrite a finished stage's output, so the stage reported the debt
rather than paying it. **3TK-26 paid it on 2026-08-25** — 21 citations across
`3tk-deviations-001.md`, `3tk-debts-notes-001.md` and
`3tk-helper-proposal-001.md`, each printed and read on both sides.
`3tk-any-options-001.md` was retired to `backup/` the same day and was not
touched.

**What the shape was, as the plan declared it.** The identity and the chain link
move into one built-in pair: `link.type` is the identity, `link.ptr` is R6b's chain
link. **The meanings do not move, R6b does not move, and the size does not
move** — 16 bytes before and after, since R6b won those eight when it deleted
`prev`. **Internals only**: no public surface change, no behaviour change, no
edit to `../common/`.

**It adds two methods to `Inner` and they exist for one reason.** `any`'s halves
are read-only — the stdlib never assigns one, it rebuilds the whole value — so
every link write must carry the identity through by hand, and a site that passes
the wrong one destroys an item's type silently. `Inner.repoint_to` keeps the
type and swaps the pointer, which is the corner `any.retype_to` does not cover;
`Inner.points_to` is the reader, and it makes the walk sites read as the
design's own sentence: *the last item of a chain points at itself*. **Methods on
`Inner`, not an extension of `any`** — the owner's ruling, because extending a
builtin widens the surface past what this change may touch.

**The owner rejected `any` within `Inner` on 2026-08-24 in all three shapes then
offered, and has now ruled this shape in.** The plan records that it is a
reversal, and **instructs the stage not to read
[3tk-any-options-001.md](backup/3tk-any-options-001.md)**: everything the stage needs
was given directly and is written into the plan.

**3TK-22 has run, 2026-08-25**, and 3TK-24 has since made its output a 003 —
[3tk-port-findings-003.md](3tk-port-findings-003.md) is the findings document
and **[002](backup/3tk-port-findings-002.md) and
[001](backup/3tk-port-findings-001.md) are both in `backup/`**. What 3TK-22 did:
every live link that named 001 was repointed. §1's `struct Inner` block was re-cut from `inner.c3` — pasted,
not typed — and so were `is_linked`, the four walk sites, tier 2's `@check`, the
tier 3 flag and its one reader, §8's `is_mine`, which said `h.type` and now says
`h.link.type`, and the helper's span. **Every `file:line` in the document was
printed and read, both sides; not one ztk citation had moved.** `3tk/` untouched
and `run-builds.sh` green — four builds, 63 checks, 0 failed, 87 tests, the
layering grep `ok`.

**The new material is §1a**, and it is why the stage was not merely a repair:
*the identity and the chain link stored as one built-in pair*, with its cost
named where the shape is described — `any`'s halves are read-only, so a link
write rebuilds the whole value and carries the identity by hand, which the
two-field shape could not get wrong, and which is why `Inner.repoint_to` exists.
It records what the language decided rather than the port, and what ztk does
instead: `PolyNode` keeps the identity in its own `tag` field, where a link
write cannot reach it. **The 3TK-20 ruling held** — the word *should* appears
nowhere in 002, nothing is ranked, and nothing is concluded from the difference
with ztk. §1a is numbered as a peer of §1 and **§2 to §10 keep their numbers**.

**The debt 3TK-21 left was outside this stage's outputs and 3TK-22 did not touch
it**: `3tk-deviations-001.md`'s nine `inner.c3:NNN` citations, and the same kind
of citation in `3tk-debts-notes-001.md` and `3tk-helper-proposal-001.md`.
**3TK-26 paid all of it, 2026-08-25.**

**And a second pass the same day paid what 3TK-26 did not reach.** 3TK-26
repointed `inner.c3` and only `inner.c3`, so the audit's `pool.c3`,
`mailbox.c3`, `queue.c3`, `stack.c3` and `helper.c3` citations were still where
3TK-12 measured them — **including the evidence under P3 and P4, the two
findings that are still open.** Twenty-two are repointed, each printed and read
on both sides; `t_owned.c3:63` became `t_managed.c3:63`, the name that file took
at the module rename. **P4's quoted code block is re-cut** from today's code and
says so where it stands: 3TK-15 deleted the `if (b)` guard it sat inside, which
moved the lines and left the defect exactly where it was. **What quotes code a
ruling has since changed is left as measured** — P1's and P2's blocks, and P6's
citations of the deleted `InnerStack.push_slot` — because repointing a
measurement falsifies it. No verdict, no scope, no finding text, no version.

**3TK-23 has run, 2026-08-25. Four finished inputs are in `backup/` and 18
links are repointed.** [3tk-naming-001.md](backup/3tk-naming-001.md) and
[3tk-to-fifo-lifo-single-001.md](backup/3tk-to-fifo-lifo-single-001.md), which
this file already called *history now*;
[3tk-helper-alternatives.md](backup/3tk-helper-alternatives.md), advice that
3TK-14 consumed and whose two shapes the compiler refused; and
[3tk-any-revision.md](backup/3tk-any-revision.md), consumed by the `any` ruling.
**Nothing was deleted, no document's content was edited beyond link targets, and
provenance kept the name** — the backtick mentions in the redesign proposal and
elsewhere are citations of what a document said, not links to where it sits.
**[3tk-who-supports-slot.md](3tk-who-supports-slot.md) stays**, because it is
open and ruled on by nothing. Four builds green, 63 checks, 87 tests — a
formality, run rather than assumed.

**Two things it found and left for the owner**, which is 3TK-19's precedent.
**3TK-21 has run**, so by plan 013's own exception whether
[3tk-any-options-001.md](backup/3tk-any-options-001.md) is retired — a ruling 3TK-21
partly reversed — is the owner's call; it was left in the live folder. **The
owner made that call the same day and it is retired**, see below. And a
resolve pass over every live link found **forty broken targets that predate the
stage**: `backup/3tk-staging-plan-001.md` through `-011` and
`backup/3tk-porting-proposal-001.md` and `-002` are cited by this file, the log
and five notes documents, and are **not in `backup/`**. Not caused here and not
repaired here. See *Open questions*.

**The `any` ruling is retired, 2026-08-25, on the owner's instruction.**
[3tk-any-options-001.md](backup/3tk-any-options-001.md) is in `backup/` — the
answer to the one question 3TK-23 was told to ask rather than decide. Six links
repointed, and **one link inside the moved document**: its §1 named
[3tk-any-revision.md](backup/3tk-any-revision.md), which 3TK-23 had retired an
hour earlier, so the path it carried was written for the live folder and broke
on arrival. The two sit beside each other now. Nothing deleted, nothing
overwritten, content otherwise untouched. **The live folder holds 19
documents**: 17 after 3TK-23, 3TK-27 added one and 3TK-28 added
[README.md](README.md), the index.

**Plan 014 is spent: all five of its stages have run.** They ran in number
order, and only 3TK-28 depended on another — it names the folder as 3TK-25 and
3TK-27 left it.

```
3TK-24  (findings 003)  →  3TK-25  (the status file)  →  3TK-26  (stale citations)
      HAS RUN                      HAS RUN                      HAS RUN
3TK-27  (who reads the notes)  →  3TK-28  (a README)
        HAS RUN                          HAS RUN
```

**3TK-25 has run, 2026-08-25, and it is why this file is short.** The owner
named it before 3TK-24, which the plan permits — the five are independent bar
3TK-28. **1,733 lines to 938.** Seven retrospective sections and *The gap
between the port and the specification* were removed, one line left where each
stood pointing at the log entry that already held it; nine closed open questions
went with them. **Nothing was deleted that the log did not already carry**, and
the two things the removed text held that the log did not — how a stage or a
revision is asked for, and how to verify the port without an agent — are
sections of their own above. **One removed claim was false**: R4 was recorded
here as OUTSTANDING long after R15 retired it.

**3TK-27 has run, 2026-08-25, and it retired nothing.**
[3tk-readership-001.md](3tk-readership-001.md), 150 lines: seven files and 1,945
lines read against one test — who opens this, and when. **Three are read.** The
toolkit and container notes are on dtk's own reading list; the sanitizer notes
are the route through a machine with no sanitizer runtimes, and `3tk-status.md`
already quotes three of their seven findings. **Four are not**: the redesign
notes, the debts notes, the helper notes bar their §8, and the drafts review —
whose seven subjects are all in `backup/`, and whose conflict register is
reproduced in full by the two documents that rule on it. **No file moved.**
Deciding a document is spent is the owner's call.

**It found two stale passages and repaired neither**, both in a finished stage's
output. `3tk-debts-notes-001.md` still reads as owing the P2 mark that 3TK-19
made on 2026-08-24 — `3tk-deviations-001.md:158` carries **FIXED**. And
`3tk-helper-notes-001.md` §8 quotes a `helper.c3` header sentence that 3TK-19
rewrote; §8's own condition, *when 004 is cut*, has arrived.

**3TK-24 has run, 2026-08-25.** `3tk-port-findings-003.md`, one new section and
nothing else of substance: **§5a**, the `on_get` difference below. 002 moved to
`backup/` and its three live links were repointed.

**3TK-28 has run, 2026-08-25, and it is the last of plan 014.**
[README.md](README.md), 77 lines: one line per live file, what it is and who
reads it — entry points, then what is read from `../common/`, the design of
record, the port measured, the notes, the one open question, and the code. **It
is an index, not a summary**: it re-describes no document and rules on nothing.
Every live `*.md` appears exactly once and every link resolves, checked by
printing them rather than by eye, and it links nothing into `backup/`.

**There is no next stage.** Plan 014 is spent and 015 is not written. What the
owner left to themselves is under *Open questions* and in 014's closing
section.

**The intent behind all five is the owner's, 2026-08-25: clean this folder
before the next big stage.** 17 files, 16,079 lines, and three of them are 7,700
of it.

```
3TK-18  (the rename)  →  3TK-19  (the debts)  →  3TK-20  (what 3tk learned)
        HAS RUN                  HAS RUN                  HAS RUN
```

**3TK-18 has run, 2026-08-24.** `Inner.next` is `Inner.link` — the rename the
owner accepted when they rejected `any` in all three shapes. The ruling is
[3tk-any-options-001.md](backup/3tk-any-options-001.md); the owner's document behind it
is [3tk-any-revision.md](backup/3tk-any-revision.md). Two words before, two words
after: no layout change, no behaviour change, no edit to `../common/`. **It
wrote no new document**, as the plan said it would not, and what it learned is
the row in [3tk-log.md](3tk-log.md).

**It also took the one citation it was permitted.** `inner.c3:5` names 004 now,
so **3TK-19 inherited two stale citations and not three.**

**3TK-19 has run, 2026-08-24. All three debts paid, no new document.** The
citations in `mtk.c3` and `helper.c3`, the P2 row in the deviations audit, and
otk's pointer at the specification. **Neither citation turned out to be a
repointing**: both sentences said something 004 made false, and a `sed` over
`003` would have closed the debt and left them both wrong. `helper.c3:51` was
rewritten, and `mtk.c3:48` — which the plan called a repoint — moved to the past
tense because it claimed a live specification defect against the document that
closed it. P2 is marked fixed in the audit's own vocabulary, verdict **P**,
scope `3tk-only`, no version bump. otk's paragraph is a blockquote at the top of
its only file; **it did not get a status file, and the stage declined that
rather than deciding it.** The row is in [3tk-log.md](3tk-log.md).

**3TK-20 has run, 2026-08-24.
[3tk-port-findings-001.md](backup/3tk-port-findings-001.md) is written** — ten
sections describing what this port does and the reasoning that produced it,
selected down to what another port would find interesting. **ztk and dtk are
both strangers to all of it**: dtk has run no stage and starts from 004 alone,
and ztk predates the redesign.

**It describes and reasons. It recommends nothing** — the owner's ruling of
2026-08-24, and it is what the document is for rather than a matter of tone.
**The word *should* does not appear in it at all**, and sections are ordered by
structure with no severity and no ranking: the item, the containers, the
mailbox, the pool, the checking tiers, the helper, then what the port gets wrong
and knows it, then what did not move. Every claim about 3tk carries a ruling or
a `file:line`; **every claim about ztk carries a `file:line` that was printed and
read**, and the ruled decisions are quoted from their rulings rather than
restated.

**Two things the reading found that no document held.** `pool.zig` shows **ztk's
pool is already last-in first-out** — `_add_returned_item` prepends at
`pool.zig:561` and every get takes the head — which R11 reached for 3tk by
ruling, with a recorded reason, from a first-in first-out start; and **ztk's
`Pool.close` already has R12's shape.** Both are stated and neither is scored:
drawing a conclusion from a difference is the one thing the document may not do.

**It wrote no code in any language.** `3tk/` is untouched and `src/*.zig` at the
repository root was read and never written. **It is an input to ztk's own plan,
which is the owner's to cut, and it terminates there.**

```
Nothing is declared and unstarted. The next stage is the owner's to name.
```

**Neither blocks dtk, and dtk does not wait for either.** dtk has a prepared
folder and no stage has run — [../d/dtk-status.md](../d/dtk-status.md) — and
3TK-17's whole scheduling constraint was to land *before* that. It has landed.
dtk is free to start, and it starts from
[`../common/matryoshka-specification-004.md`](../common/matryoshka-specification-004.md).
**3TK-20 would give it a second input and is not a precondition for it.**

**Three small things were owed. 3TK-18 paid part of one and 3TK-19 paid the
rest**, and none of them blocked dtk. They are closed in the open questions
below, and **one thing is deliberately left open there**: whether otk gets a
status file of its own. The pointer at the specification is written; preparing
otk's folder is not this line's call.

**`3tk/` is green** — `run-builds.sh` **63 checks** and 0 failed, four builds
green, **87 tests in every mode**; `run-sanitizers.sh` thread and address clean
at 87. The counts are 3TK-15's, unchanged through 3TK-18, 3TK-19, 3TK-20 and now
3TK-21: **a rename, a doc comment, a document and a field reshuffle add and
remove no check and no test**, which is each stage's own verification and it
holds. The first three ran the builds and none of them ran the sanitizers, which
no plan of theirs asked for and which no doc comment can move. **3TK-20 touched
no code at all** — its build run was a formality, run rather than assumed, as
its plan required. **3TK-21 ran the sanitizers and its plan insisted on it**:
the change moves what sits at which offset inside every item in the toolkit, so
a green build alone would have proved less than it looked like.

---

## Where the narrative went

**Seven retrospective sections stood here and were removed by 3TK-25,
2026-08-25.** Each described a stage that has run, and
[3tk-log.md](3tk-log.md) already carries all of it, dated and in full. One line
each, with the log entry that holds it:

- *What 3TK-17 cut* — specification 004, Part 7.1 alone. Log, 2026-08-24,
  *3TK-17: Part 7.1 states the promise, and 004 is cut for one Part*.
- *What 3TK-15 paid* — `UNKNOWN_IDENTITY`, and A5 filed under the wrong noun.
  Log, 2026-08-24, *3TK-15: two debts paid, and one of them was misfiled*.
- *What 3TK-16 built* — the helper as macros, 35 aliases to 0. Log,
  2026-08-24, *3TK-16: the helper surface, in code*.
- *What 3TK-14 decided* — eleven items, fifteen measurements, and the stdlib
  that changed the answer. Log, 2026-08-24, *3TK-14: the helper surface,
  measured then proposed, then re-measured against the stdlib*.
- *What the owner ruled, 2026-08-24* — H0, H0b, H5, H10 accepted; E6 an S/V row
  scoped `every port`, E7 no change at all. Log, same entry, sections *Ruled the
  same day* and *E6 and E7, ruled*.
- *What is owed, and by which stage* — a 3TK-14-era table, every row of it since
  paid by 3TK-16 and 3TK-17. Log, same entry, section *What is owed, and the one
  gap*.
- *The state before 3TK-14 — 3TK-13 and the specification* — 003, the five
  assumptions, the P1 and P6 rulings, and the R-register as the owner ruled it.
  Log, 2026-08-24 *3TK-13: specification 003, and the gap closes*, *five
  questions before the cut, five defaults recorded*, *P1 fixed*, and 2026-08-23
  *the redesign is ruled, question by question*.

**One claim in the removed text was false and is not carried anywhere.** *The
state before 3TK-14* said **R4 — OUTSTANDING**, on the ground that Part 11.8's
MUST forces `InnerQueue` to keep a front insert. R15 dropped `Pool.put_all` and
**retired R4 with it** — `3tk-core-redesign-proposal-002.md:606` — and there is
no `push_front` in the port: `queue.c3:135` says so where the operation would
be. The paragraph was written before the ruling and outlived it.

## Asking for a stage or a revision

**To add a stage:** one line, and the agent does the versioning.

```
Add 3TK-NN to the plan and run it
```

To bump the plan without running anything, add `Do not run it.` Whatever the
stage, **the agent's first three actions are: read this file, read the plan's
section for that stage, read that stage's named inputs.** Nothing outside them.
A stage whose row above reads DONE is not re-run without being told.

**A revision is not a stage.** It needs no plan version and appears in no stage
table. Name what you want changed and which document:

```
Read design/secondary/lang/c3/3tk-status.md. Revise the porting proposal:
D5 should be a transparent alias, not a distinct Slot type.
```

The agent writes the next version number, leaves the old file on disk, adds a
row to *Superseded* naming what replaced it, repoints the live pointers in this
file, and appends to [3tk-log.md](3tk-log.md).

**A revision that moves a decision has consequences in `3tk/`.** The agent names
the source files that would change and **stops there**. Rewriting the code is a
separate instruction, and the four builds have to be green again before the
revision is finished:

```
...and apply it to the code.
```

**Two things a revision may not do quietly**, and they are the folder's standing
rules rather than a revision's own. It does not renumber or rewrite a finished
stage's output — those record what was true when the stage ran. And it does not
repoint the provenance lines inside stage outputs, which name the document
version each stage was written against; only the live pointers in this file
move.

**To know only where things stand:**

```
Read design/secondary/lang/c3/3tk-status.md and report where the 3tk work stands.
```

## To verify the port without an agent

```
design/secondary/lang/c3/3tk/run-builds.sh
```

Four builds, exits non-zero on any failure. It needs `c3c` on the path and
nothing else, and 3TK-9 deliberately kept it that way.

The sanitizers are a **second** script, because they need a C compiler that
ships their runtimes and `run-builds.sh` may not depend on one:

```
design/secondary/lang/c3/3tk/run-sanitizers.sh
```

Thread on two builds, address on one. It **skips and exits 2** if its compiler
is missing, saying so — a skip is not a pass. `SAN_CC=<compiler>` overrides the
default of `clang`.

**Both scripts take an optional directory**, added 2026-08-24 on the owner's
instruction. With no argument — or an empty one — each runs against its own
directory exactly as before:

```
./3tk/run-builds.sh              # the script's own directory, unchanged
./3tk/run-builds.sh /some/tree   # that tree instead
```

**A `cd` that fails is fatal, and that is not decoration.** Neither script sets
`-e`, so before this a failed `cd` would have let the whole body run in whatever
directory the caller happened to be in, and `run-builds.sh` does `rm -rf` on its
temporary directory at exit. A caller-supplied path made that reachable. A bad
path now prints one line and exits 2 with nothing else run.

## Files

Edited in place, no suffix — the entry points:

- `README.md` — **the index of this folder**, one line per live file: what it
  is and who reads it. The 3TK-28 output. It rules on nothing, so a reader who
  needs a fact reads the file it points at.
- `3tk-status.md` — this file.
- `3tk-log.md` — the narrative, append-only, newest first.

Versioned — a change makes a new file, the old one stays and is listed below:

- **Current plan: [3tk-staging-plan-014.md](3tk-staging-plan-014.md).** It
  declares **3TK-24 to 3TK-28** — findings 003, the status file, the stale
  citations, who reads the notes, a README — and **reproduces no stage that has
  run.** **All five have run, and 014 is spent.**
- [ztk-audit-001.md](../common/ztk-audit-001.md) — the 3TK-1 output.
- **[matryoshka-specification-004.md](../common/matryoshka-specification-004.md) — the
  portable specification, and the source of truth for every port.** The 3TK-2
  output, revised three times: by 3TK-2's own successor into 002, by **3TK-13**
  into 003 from the deviation audit, and by **3TK-17** into 004 for Part 7.1.
- [3tk-drafts-review-001.md](3tk-drafts-review-001.md) — the 3TK-3 output.
- [c3-capabilities-001.md](c3-capabilities-001.md) — the 3TK-4 output.
- **[3tk-porting-proposal-004.md](3tk-porting-proposal-004.md) — the design of
  record. The sixteen decisions accepted by the owner, 2026-08-23; D1's argument
  rewritten and its ruling reaffirmed by 3TK-8, same day.**
- [3tk-toolkit-notes-001.md](3tk-toolkit-notes-001.md) — the 3TK-6 output,
  beside the code at `3tk/`.
- [3tk-containers-notes-001.md](3tk-containers-notes-001.md) — the 3TK-7
  output.
- **[3tk-naming-001.md](backup/3tk-naming-001.md)** and
  **[3tk-to-fifo-lifo-single-001.md](backup/3tk-to-fifo-lifo-single-001.md)** —
  **retired to `backup/` by 3TK-23, 2026-08-25.** From
  the owner, 2026-08-23. Not produced by any stage and not versioned by this
  folder. **The input to 3TK-10.** The first proposes Outer/Inner naming; the
  second argues `NodeList` should not be the centre of the design. Both were
  carried out by 3TK-10 and 3TK-11 and are history now.
- **[3tk-who-supports-slot.md](3tk-who-supports-slot.md)** — from the owner.
  Not produced by any stage. **Open, and not ruled on by anything.** It argues
  the containers should not support the Slot idiom at all. It was at `3tk/src/`
  until the owner moved it here on 2026-08-23; it uses names the redesign
  refused, so it reads as older than it is. See *Open questions*.
- **[3tk-helper-alternatives.md](backup/3tk-helper-alternatives.md)** —
  **retired to `backup/` by 3TK-23, 2026-08-25.** From the
  owner, 2026-08-24. Not produced by any stage and not versioned by this
  folder. **The first input to 3TK-14.** It is advice, not a ruling, and it
  withdraws its own favourite proposal near the end. 3TK-14 measured both of its
  shapes and the compiler refused both. **Its second input was spoken, not
  written**: read the C3 stdlib. That is recorded in the log and in Part A2 of
  the proposal, and it is what produced H0.
- [3tk-helper-proposal-001.md](3tk-helper-proposal-001.md) — the 3TK-14 output.
  Fifteen compiler measurements, eleven numbered items, **all ruled 2026-08-24**.
  Its second input was the owner's mid-stage advice to read the C3 stdlib's
  `interfacelist`, `anylist` and `core/builtin.c3`, and that advice is what
  produced H0. **3TK-16 built it.**
- **[3tk-helper-notes-001.md](3tk-helper-notes-001.md) — the 3TK-16 output.**
  What building the ruled surface taught: three C3 spellings the proposal's
  scratch runs did not carry, the rename that was never a rename, and 35 aliases
  to 0.
- **[3tk-debts-notes-001.md](3tk-debts-notes-001.md) — the 3TK-15 output.**
  The two debts of 3TK-13, paid: `UNKNOWN_IDENTITY` and why it is deliberately
  not a Part 19 outcome, why `get_wait` changed when it did not have to, and the
  twelve doc comments that changed a claim rather than a path. **It also records
  that A5 was filed under the wrong noun** — one path citation existed, not
  forty, and the non-mechanical half was all of the work.
- **[3tk-port-findings-003.md](3tk-port-findings-003.md) — the 3TK-20 output as
  3TK-22 and 3TK-24 left it, and the only document in this folder written to be
  read by another port.** What 3tk does and the reasoning that produced it, in ten sections
  selected by *would another port care*. **It describes and recommends
  nothing**, which is the owner's ruling of 2026-08-24 and is what makes it
  serve dtk and ztk at once. It stays a 3tk document rather than moving to
  `../common/`: one port's record, read by others, not a shared normative
  input. **Versioned under this folder's rule** — it is a new family, and
  **`3tk-staging-plan-012.md` named it** — that addition was the whole of 012,
  and 011's list predated the document. **013 carried the entry forward, and
  3TK-22 made it a 002 on 2026-08-25**: §1 re-cut against `struct Inner { any
  link; }`, every `file:line` printed and read again, and a new §1a on storing
  the identity and the chain link as one built-in pair. **3TK-24 made it a 003
  the same day**, adding §5a on the `on_get` difference and changing nothing
  else of substance. **001 and 002 are in `backup/`** —
  [001](backup/3tk-port-findings-001.md), [002](backup/3tk-port-findings-002.md).
- [3tk-sanitizer-notes-001.md](3tk-sanitizer-notes-001.md) — the 3TK-9 output.
  Seven findings. The port is clean under thread and address; the four races the
  first run found were all in the tests.
- **[3tk-readership-001.md](3tk-readership-001.md) — the 3TK-27 output.** Who
  reads each of the six `*-notes-*` files and `3tk-drafts-review-001.md`, and
  when. **Three of the seven have a reader; four do not.** It retires nothing —
  the owner decides — and it moved no file.
- **[3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md) — the
  3TK-10 output as ruled, and 3TK-11's input. Executed 2026-08-23.** Sixteen
  decisions, R1 to R15 with R6b, every one accepted or refused on the record.
  Proposal 004 stays the design of record for everything the redesign does not
  touch, and it is **not edited** — it records what was built, and 002 records
  what replaced it.
- **[3tk-core-redesign-notes-001.md](3tk-core-redesign-notes-001.md) — the
  3TK-11 output.** What writing the redesign taught: the six self-link sites,
  invariant 5 in a mailbox with two queues, and three corrections to 002 in
  details rather than decisions — the stack has five operations and not six,
  tier 2 does not reach a fast build, and two `put_all` tests were converted
  rather than deleted.



### Superseded

**Every superseded version is in `backup/`.** Nothing is deleted, and the live
folder contains only what a current reader needs.

- [matryoshka-specification-003.md](../common/backup/matryoshka-specification-003.md),
  replaced by
  [matryoshka-specification-004.md](../common/matryoshka-specification-004.md)
  on 2026-08-24, by stage **3TK-17**. **One Part.** 7.1 stated ztk's mechanism
  — a helper object bound to one type — where the design has only the promise
  that Part 7.2's members exist per outer type and are generated. It was the
  fifteenth instance of the mistake 003 fixed fourteen times. Its own change log
  names the difference. **`../common/backup/`, not `backup/`** — the
  specification is every port's, and `c3/backup/` stays the C3 line's own.

- [3tk-core-redesign-proposal-001.md](backup/3tk-core-redesign-proposal-001.md),
  replaced by
  [3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md) on
  2026-08-23, when the owner ruled on it question by question. **Three decisions
  moved**, which is why a version was cut rather than a note appended: **R6 was
  refused** and the self-link replaced it, **R11 acquired its reason**, and
  **R15 dropped `put_all`**, retiring R4. 001 is the record of what the stage
  proposed; 002 is what was ruled, and 002 is 3TK-11's input.

- `3tk-staging-plan-001.md`, replaced by plan
  002 on 2026-08-23. The only change was the addition of 3TK-6.
- `3tk-staging-plan-002.md`, replaced by
  `3tk-staging-plan-003.md` on 2026-08-23. The only
  change is the addition of 3TK-7.
- `3tk-staging-plan-003.md`, replaced by
  `3tk-staging-plan-004.md` on 2026-08-23. The only
  change is the addition of 3TK-8.
- `3tk-porting-proposal-001.md`, replaced by
  proposal 002 on 2026-08-23, when the owner accepted all sixteen decisions.
- `3tk-porting-proposal-002.md`, replaced by
  [3tk-porting-proposal-003.md](backup/3tk-porting-proposal-003.md) on 2026-08-23, in
  answer to [3tk-porting-proposal-review.md](backup/3tk-porting-proposal-review.md).
  No decision moved.
- `3tk-staging-plan-009.md`, replaced by
  `3tk-staging-plan-010.md` on 2026-08-24. The
  only change is the addition of 3TK-18 and 3TK-19; 3TK-0 to 3TK-17 are
  reproduced unaltered.
- `3tk-staging-plan-010.md`, replaced by
  `3tk-staging-plan-011.md` on 2026-08-24. The
  only change is the addition of 3TK-20; 3TK-0 to 3TK-19 are reproduced
  unaltered, and 3TK-19 stood declared and unstarted exactly as 010 left it.
- [3tk-staging-plan-012.md](backup/3tk-staging-plan-012.md), replaced by
  `3tk-staging-plan-013.md` on 2026-08-25. **The change
  is three new stages** — 3TK-21, 3TK-22 and 3TK-23 — and nothing before them is
  altered, reordered or reworded.
- `3tk-staging-plan-011.md`, replaced by
  [3tk-staging-plan-012.md](backup/3tk-staging-plan-012.md) on 2026-08-24, at the
  owner's instruction. **The only change is one line in the versioned list** —
  `3tk-port-findings-NNN.md`, the family 3TK-20 started. **No stage is declared,
  added, reordered or reworded**; each stage header now names its outcome, and
  every stage of the line has run.
- `3tk-staging-plan-007.md`, replaced by
  `3tk-staging-plan-008.md` on 2026-08-24. The
  only change is the addition of 3TK-14 and 3TK-15.
- `3tk-staging-plan-008.md`, replaced by
  `3tk-staging-plan-009.md` on 2026-08-24. The changes
  are the addition of 3TK-16 and 3TK-17, an amendment note on 3TK-15's ordering,
  and one corrected stale line — 008 and 007 both said *currently 007* in the
  versioning section.
- `3tk-staging-plan-006.md`, replaced by
  `3tk-staging-plan-007.md` on 2026-08-24. The only
  change is the addition of 3TK-12 and 3TK-13.
- `3tk-staging-plan-005.md`, replaced by
  `3tk-staging-plan-006.md` on 2026-08-23. The
  only change is the addition of 3TK-10 and 3TK-11.
- `3tk-staging-plan-004.md`, replaced by
  `3tk-staging-plan-005.md` on 2026-08-23. The only
  change is the addition of 3TK-9.
- [3tk-porting-proposal-003.md](backup/3tk-porting-proposal-003.md), replaced by
  [3tk-porting-proposal-004.md](3tk-porting-proposal-004.md) on 2026-08-23, by
  stage 3TK-8, in answer to
  [3tk-porting-proposal-003-review.md](backup/3tk-porting-proposal-003-review.md).
  **No decision moved.** D1's *argument* was rewritten and its *ruling*
  reaffirmed by the owner.
- [3tk-porting-proposal-addendum-001.md](backup/3tk-porting-proposal-addendum-001.md),
  folded into proposal 004 on 2026-08-23. Its nine measured answers are D1's
  table; the addendum existed only until a proposal version could carry them.
- [3tk-porting-proposal-003-review.md](backup/3tk-porting-proposal-003-review.md),
  answered by proposal 004 on 2026-08-23 and moved here, as the first review
  was. It is history now: everything a current reader needs from it is in 004's
  *What changed in 004*, section 6 and section 10.
- [matryoshka-specification-001.md](../common/backup/matryoshka-specification-001.md),
  replaced by
  [matryoshka-specification-002.md](../common/backup/matryoshka-specification-002.md) on
  2026-08-23 — three imprecisions the C3 port found, and invariant 34, with no
  rule changed — and **002 replaced by
  [matryoshka-specification-003.md](../common/backup/matryoshka-specification-003.md)
  on 2026-08-24**, from the deviation audit, and **003 replaced by
  [matryoshka-specification-004.md](../common/matryoshka-specification-004.md)
  the same day**, from 3TK-17, for Part 7.1 alone. All three are in
  `../common/backup/`, which 3TK-13 created; `c3/backup/` stays the C3 line's
  own. **The other ports read 004.**

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

**The port is clean under ThreadSanitizer and AddressSanitizer**, and the run
that established it found four data races first — **all four in the toolkit's
own test hooks, none in `src/`.** Stage 3TK-9, `3tk-sanitizer-notes-001.md`.

- **What the races were.** `TestHooks`'s counters, incremented without
  synchronization while three producers and three consumers ran on one pool. The
  frames that appear in `src/` are `pool.c3:284` and `:396` — the hook call
  sites, where the pool has *already unlocked*. That is Part 12.3 being obeyed.
- **The contract they broke is the port's own**, in `PoolHooks`'s doc comment:
  *a hook that touches shared state protects it itself.* The tests had been
  racing since 3TK-7 with every build green in four modes, because a data race
  is exactly the defect a passing suite cannot see.
- **The fix is in the hook**, where the specification puts it: `Atomic{usz}`
  counters, the same mechanism the port uses for `_closed_fast`. The one-line
  wrong fix — hold the pool's mutex across the hook — would have silenced every
  warning and destroyed Part 12.3. A sanitizer says there is a race; it does not
  say which side is wrong.
- **The sanitizers needed no install and no root.** Fedora's runtimes are
  missing so `cc` cannot link them — and plain `cc -fsanitize=thread` fails
  identically, so it is the machine, not c3c. `--cc clang` links. S1, S2.

```
all four builds green — 59 checks, 0 failures     ./3tk/run-builds.sh
  safe -O0   safe -O3   fast -O0   fast -O3        (needs c3c alone)
85 tests in each, 7 runtime negatives, 2 tier 1, 3 refusals, 3 layering

sanitizers clean — 3 runs, 0 findings              ./3tk/run-sanitizers.sh
  thread safe -O0    thread fast -O3    address safe -O0
```

**77 tests before 3TK-11, 85 after.** The check count did not move: the redesign
renamed one negative and rewrote another, and added none.

The two scripts are separate for one reason: the gate depends on `c3c` and
nothing else, and 3TK-9 kept it that way rather than buying coverage with a
dependency.

**Part 18 is complete: still thirty-four invariants, all accounted for.** The
redesign retired row 16 — *the link test is not a membership test* — and put the
self-link invariant in its place, kept row 22 against plan 006's expectation
that two queues would delete it, and strengthened row 13. The re-walk is in
`3tk-core-redesign-notes-001.md`.

**No decision has moved across four proposal versions.** All sixteen accepted by
the owner 2026-08-23; D1 reaffirmed the same day after its *argument* was found
wrong, which is the distinction this folder keeps.

The documents, in the order a cold session reads them:

- `../common/matryoshka-specification-004.md` — the portable specification.
  Source of truth for **every** port, not just this one.
- `3tk-porting-proposal-004.md` — the C3 shape of it. D1 to D16, accepted.
  Section 6 is the implementation contract; section 10 is what the code taught.
- `3tk-toolkit-notes-001.md`, `3tk-containers-notes-001.md`,
  `3tk-sanitizer-notes-001.md` — what the code taught. Twenty-two findings.
- `c3-capabilities-001.md`, `3tk-drafts-review-001.md`,
  `../common/ztk-audit-001.md` — the measurements the proposal was built on.

**The core redesign is designed, ruled and built.**
[3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md) is the
3TK-10 output as ruled; 3TK-11 carried every one of its sixteen decisions into
`3tk/` and
[3tk-core-redesign-notes-001.md](3tk-core-redesign-notes-001.md) is what the
code taught doing it. Four things a reader should know:

- **The required-operation audit passes.** `insert_before`, `remove`,
  `pop_back`, `front` and `back` have **no caller in `src/` at all**;
  `insert_after` has one, the out-of-band insert. Deleting `prev` costs the
  port nothing it uses.
- **The guard got stronger, and cost nothing.** `prev` is deleted and the last
  item of every chain points at itself, so `is_linked` is **exact**. `Inner` is
  two fields and 16 bytes — the two size tests that asserted 24 were the first
  thing the stage had to change. Part 8.7's blind spot is closed, `contains` and
  the O(n) walk on every insert are deleted, and the check moved from tier 3 to
  **tier 2**. R6b, after R6's field was refused.

  **Correction to 002 §10.3, from the code:** tier 2 does **not** reach a fast
  build. `@check` under `--safe=no` expands to nothing, which is the whole of
  D6. What R6b bought is the O(1) check in an ordinary safe build, not an abort
  in a fast one. `3tk-core-redesign-notes-001.md`.
- **`put_all` is dropped.** It was `Pool.put` in a loop, inherited from
  `pool.zig:394`, and it cost a container operation and a MUST clause while
  giving the difficult case back to the caller in a different shape. R15.
- **The pool's order is a behaviour change with a reason**: last-in first-out
  so a use-after-release meets a live second owner at the next `get`, instead
  of rotting quietly at the back of a free list. **Not performance.**

## The gap between the port and the specification

**CLOSED 2026-08-24 by 3TK-13, and the section that described it was removed by
3TK-25, 2026-08-25.** It was proposal 002 §8.1's *forecast* of the difference —
ten Parts — plus what 3TK-11 corrected, kept after the thing it forecast had
been measured and fixed. **The measurement is
[3tk-deviations-001.md](3tk-deviations-001.md)**, which found five more Parts
the forecast said were untouched and five port-side deviations a forecast could
not have found; **the fix is
[`../common/matryoshka-specification-004.md`](../common/matryoshka-specification-004.md)**,
whose claim about itself — *a port is written from this file alone* — is true
again. The narrative is in [3tk-log.md](3tk-log.md), 2026-08-24: *3TK-12: the
audit found what a forecast could not* and *3TK-13: specification 003, and the
gap closes*.

## What is left, and none of it is Matryoshka

Everything below was **outside 3TK-8**, which was about the proposal and two
creation paths, and none of it moved. From `3tk-containers-notes-001.md`.
**Each is a candidate for a stage, and none is authorized.** They are listed so
the owner can name one without re-deriving the list.

- **`a_leaver_hands_the_signal_on` is a race test run 20 times.** It has now run
  20 times **under ThreadSanitizer**, which is much stronger than 20 times
  without. Still evidence, not proof.
- **MemorySanitizer was not run.** c3c offers it; it needs the whole dependency
  stack instrumented, including the C3 standard library, or it reports false
  positives. `3tk-sanitizer-notes-001.md`.
- **linux-x64 only.** ztk is green on three cross targets; 3tk has been built
  for one.
- **`Mailbox.create`'s cleanup is untested**, and the test file says so at the
  site. Its only acquisition through the caller's allocator is the object
  itself; `_mu.init()` and `_cv.init()` allocate through the platform, so a
  failing allocator cannot reach them. The fix is correct by construction and
  the pool's identical shape *is* provoked. Proposal 004, section 8.3.
- **Packaging.** `backup/3tk-build-dist.md` B2 claims C3 library packaging is early
  alpha and `c3c dist` incomplete. Still unverified, still a tooling stage's.
- **A worked example.** An application using the port end to end — a producer, a
  consumer, a pool with real hooks — as documentation that compiles. The tests
  prove the invariants; nothing yet shows a reader how to *use* it, and it would
  be the first honest test of whether the hook contract is easy to obey, which
  3TK-9 says the toolkit's own tests did not. **Carried here by 3TK-25** from a
  candidates table it removed; the table's other four rows are already above.

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
- 3tk is green: **87 tests** in four modes, plus 13 negative programs and 3
  layering checks. `3tk/run-builds.sh`, **63 checks**, 0 failures.
- **A negative program is compiled as an ordinary program, so the test runner's
  macros are out of reach.** `@catch_is` is one of them. A negative that wants a
  fault writes `if (catch f = ...)`. Found by 3TK-15, which lost a compile to
  it.
- **C3 has no UFCS.** A free function cannot be called as `handle.f(...)`;
  the receiver is written into the declaration, `fn void Type.f(&self)`. And a
  method cannot be attached to a pointer alias, so `Handle` carries none.
  Proposal 004, D1 — M1 and M4.
- **C3 0.8.3 has no field-level privacy, and `inline` does not create one.** A
  `@private` struct inlined into a public one hides the type *name*; every field
  in it stays readable, writable and addressable from another module.
  `@private` on a field is refused outright. Proposal 004, D1 — M5.
- **The sanitizers work, but not through `cc` on this machine.** c3c 0.8.3 has
  `--sanitize=address|memory|thread`; Fedora's sanitizer runtimes are not
  installed, so `cc` fails to link — and plain `cc -fsanitize=thread` fails the
  same way, so it is the machine and not c3c. `--cc clang` links, with no
  install and no root. `3tk-sanitizer-notes-001.md` S1 and S2.
- **`c3c test` detects leaks by default** — `--test-noleak` turns it off. Nine
  stages passed before any document said so. S6.
- **Never infer a C3 build mode from the `-O` level.** `-O2` and above set
  `SAFE_MODE=false`. Always pass `--safe=yes` or `--safe=no` explicitly.
  `3tk-toolkit-notes-001.md` F1.
- The fault-return operator is `~`, not `?`. `return mtk::CLOSED~;`.
  `3tk-containers-notes-001.md` G2.
- **[3tk-log.md](3tk-log.md) carries about a dozen older banned-word hits and is
  deliberately left as it is.** Owner's instruction, 2026-08-23: the log is
  append-only and rewriting it destroys the record, which is also why
  `rules-049.md` Part 5's scope skips it. Moved here from *Open questions* by
  3TK-25 — it is a standing fact, not a question.

## Open questions

**Reviewed by 3TK-25, 2026-08-25.** Nine questions that were closed and struck
through are gone from this list: a closed question is history, and every one of
them is recorded in [3tk-log.md](3tk-log.md) under the stage or the ruling that
closed it — the two doc comments citing 003 and the stale P2 row (3TK-19), the
`any` ruling's retirement, the three Part 5 words in this file, the allocator
direction, and 3TK-8's four questions, all ruled 2026-08-23 before that stage
started. What is left is what is genuinely open.

- **Two port defects are open, and they are the only ones.**
  [3tk-deviations-001.md](3tk-deviations-001.md) measured six; P1, P2, P5 and P6
  are ruled and fixed. **P3** — a waiting call can return the condition
  variable's own fault, outside Part 19's outcome set. It is **unreachable on
  the current posix backend**, which aborts instead, and it is recorded because
  it sits in the port's two most-copied wait loops and the next port copies the
  shape before checking its own backend. **P4** — Part 2.6 MUST: the pool's
  leaver signals on one bucket over a condition variable shared by *n* buckets.
  **Nothing is lost today** and the reason matters, so a repair is not argued as
  a bug fix: every path that makes an item available calls `broadcast`. The
  mailbox got the same line right. Smallest repair: `broadcast`, or a predicate
  over every bucket in the shape `has_queued` uses. **Both are `3tk-only` and
  neither is ruled.**

- **Whether otk gets a status file.** `../odin/` holds one backport document.
  **The pointer at the specification is written** — 3TK-19, 2026-08-24, one
  blockquote at the top of `odin-to-zig-backport-001.md` naming
  [`../common/matryoshka-specification-004.md`](../common/matryoshka-specification-004.md)
  as otk's normative input, in the shape `../d/dtk-status.md` uses. **The folder
  is not prepared**, and preparing it means answering what otk's line of work
  currently is. That is the owner's call, and 3TK-19 declined it rather than
  deciding it. Whether otk is brought to the specification is a separate
  question and no stage of this line has touched it.

- **Should the containers support the Slot idiom at all?** A note from the
  owner, [3tk-who-supports-slot.md](3tk-who-supports-slot.md), argues they
  should not: `push_back_slot` and `push_slot` would move to `Mailbox` and
  `Pool`, and `InnerQueue` and `InnerStack` would speak only in `Handle`.
  **3TK-10 did not rule on it and 3TK-11 did not act on it** — §5.1 keeps both
  Slot inserts and R13 says nothing against them, so the code has them. It uses
  names the redesign refused — `InnerList`, `push_front` — so it reads as older
  than it is. **The owner moved it out of `3tk/src/` to this folder on
  2026-08-23**, so it is no longer mistakable for current design. Small: two
  methods and their two tests.

- **A ztk/3tk behavioural difference, now written down: whether `on_get` runs
  when a get already found a stored item.** 3tk does not call it, ztk does, and
  specification Part 11.7 and Part 12.2 side with 3tk while `ztk-audit-001.md`
  2.7 and the ztk book side with ztk. **Recorded, not ruled** — it touches
  `../common/`, it changes what dtk would build, and whichever way it goes one
  of three moves: 3tk's code, ztk's code, or Part 12.2.
  [3tk-port-findings-003.md](3tk-port-findings-003.md) **§5a** has all of it,
  with every citation on both sides.

- **Two lines of the ztk book are wrong about `on_get`, and fixing them is the
  ztk line's work.** `matryoshka-api-reference-042.md:1288` says *Calls `on_get`
  hook* under `get_wait`, and `:1448-1449` says `on_get` is *called for every
  `get` and `get_wait` call regardless of mode*. Both were re-read 2026-08-25
  and neither has moved since the audit. **This is not a doubt about the port**:
  `Pool.get_wait` calls no creation hook on purpose, and the code, the doc
  comment, ztk's own source, the audit and specification Part 11.9's MUST all
  agree. The log's entry of 2026-08-25 — *the waiting get never creates* — has
  the whole of it.

- **The specification is 1366 lines against the plan's expected 600-900.** The
  staccato rule is one fact per line, and the content did not compress below
  this without dropping facts. Nothing was padded and nothing was cut to fit.
  Flagged for the owner.

- **The banned-word scan has never covered this folder.** `rules-049.md` Part
  5's own scope skips `design/secondary/`, so eleven stages of documents were
  written unchecked. Found 2026-08-23 when the owner caught one word in the
  redesign proposal; a full scan then found nine hits in that file alone, and the
  proposal was replaced by a clean 002. **Whether Part 5's scope should change
  is the owner's call and belongs to the kitchen line, not to 3tk.**

- `kitchen/tools/check_design.sh` exits 1, not the 0 the plan expected. **63
  problems after 3TK-8, up from 43**, and the whole rise is orphans — 29 to 49 —
  because `design/secondary/context.md` lists no `lang/` subfolder, so every
  file under it counts as one. 3TK-8 added two files and moved three to
  `backup/`; each is a new path and a new row. **The 14 dead links did not
  move**, and that is the number that would signal a regression. All 14 are in
  `design/context.md` and name documents older than this work. The cause is the
  next item.

- `design/secondary/context.md` does not list the `lang/` subfolders at all.
  Drift, noted, not fixed. Every file in `c3/`, `d/` and `odin/` is an orphan
  by the gate's count because of it.

- Three more documentation-drift items, all in `design/`, none touching `src/`.
  `ztk-audit-001.md` section 7.
