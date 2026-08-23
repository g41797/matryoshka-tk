# 3tk — status

Current state of the 3tk line of work. One screen. Updated after every stage.

This file is the entry point for a cold session. Read it, then the stage named  
by the owner in [3tk-staging-plan-006.md](3tk-staging-plan-006.md).

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

## How to continue after a clear

**3TK-11 has run. The core is rewritten and green.** The port now speaks
Outer/Inner, has no general-purpose list, and keeps an `InnerQueue` and an
`InnerStack` in its place. A cold session reads this file, then
[3tk-core-redesign-notes-001.md](3tk-core-redesign-notes-001.md) for what the
code taught and
[3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md) for why
it has the shape it has.

**Nothing is authorized. No stage is next until the owner names one.** The
candidates are below, and the one piece of ruled-but-unscheduled work is
specification 003 — R14. **The port is now ahead of the specification it is
written from**, and that is the single most important fact about the current
state.

### What the owner ruled, 2026-08-23

**Given in this order, one question at a time, after 3TK-10 reported.** These
are the rulings, not recommendations.

**They are folded into
[3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md), which is
3TK-11's input.** 001 is in `backup/` and records what the stage proposed before
the ruling. Plan 006's 3TK-11 section names 001 *as ruled by the owner*; the
ruling produced 002, and this file is the live pointer, as it is for every other
versioned document here.

**R6 — REJECTED. No membership field.** `Inner` is two fields, `next` and
`type`. 16 bytes on linux-x64, down from 24.

**The guard is mechanism B — the self-link.** The last item of every chain
points at itself. Then:

- `is_linked(h) => h.next != null`, and it is **exact**. On a chain, `next` is
  never null. Off a chain, it is always null.
- **Part 8.7's blind spot closes with no field.** Today an item alone on a list
  has `prev == null` and `next == null` and reports unlinked — the hole D12
  accepted. Self-linked, it reports linked.
- **`contains` and the O(n) walk on every insert are still deleted.** Once the
  link test is exact it refuses an item on *any* chain, this container or
  another, so the walk of Part 8.6 catches nothing it misses.
- The guard becomes tier 2, so it is live in a fast build.
- `reset(h)` clears `next` to null. Every walk ends at `n.next == n`.

**Corrected by 3TK-11, in a detail and not in the ruling.** The tier 2 bullet
above is left as it was said, because this section is the record of what was
ruled. What the code shows: tier 2 is `@check`, which under `--safe=no` expands
to nothing at all — that is the whole of D6 and of 3TK-4's Q11 finding — so the
guard does **not** abort in a fast build. What moving it from tier 3 to tier 2
actually bought is the exact check at O(1) in an ordinary safe build, where
before it cost an O(n) walk per insert. The ruling stands; the consequence was
described one step too far. `3tk-core-redesign-notes-001.md`.

**Why the field was refused, and 001 got this wrong.** 001 argued mechanism B
gave `next` three meanings across eleven sites in `list.c3`. That count is the
container ruling 2 abolishes: with `remove`, `pop_back`, `insert_after`,
`insert_before`, `front` and `back` deleted, about four sites touch `next`. The
objection was priced against the old container. The field bought exactly one
query — O(1) *is it on this container* — and `remove` was its only caller.

**R8 — ACCEPTED.** Out-of-band first, then ordinary, first-in first-out within
each, for `close` and `receive_all` both. One rule: *where the mailbox gives
items back as a list, the list is in the order `receive` would have taken them
out.* It changes nothing — the single queue already keeps out-of-band ahead of
ordinary, so the two order assertions at `t_mailbox.c3:225` and `:251` pass
untouched.

**R9 — ACCEPTED.** Invariant 22 is kept. Only D14's anchor and Part 11.3's two
anchor bullets are deleted. The ordering is a promise to callers and it stands.

**R14 — ACCEPTED. The specification moves to 003.** Not a 3tk deviation. Nine
Parts change and dtk and otk read them. **Not done by 3TK-11** — `../common/` is
untouched so far, and cutting 003 is its own piece of work.

**R11 — ACCEPTED, and Part 11.7 stays silent on order.** The pool becomes a
stack. Specification 003 says the container is a stack and promises no order,
because Part 11.10 MUST already says the pool promises nothing about which item
comes back.

**The owner's reason for LIFO, which 001 did not have and which must not be
lost.** It is **not** cache locality and **not** performance. It is defect
surfacing:

> Under FIFO the item just given back goes to the *back* of the free list. Code
> still holding a pointer to it after `put` writes to an item nobody has
> re-taken, so nothing conflicts. If the put hook did not reset the contents,
> the stale holder reads data that still looks plausible and never trips. The
> item is reissued much later, and the damage appears far from its cause.
>
> Under LIFO the item is on top and the **next `get` gives it straight to a new
> owner**. The stale holder and the new owner write the same item at the same
> moment, so the defect appears next to its cause.

Same reasoning as not quarantining freed memory. **This belongs in the doc
comment on the pool's stack**, because a later reader who takes the stack for an
arbitrary choice will "improve" it back to a queue. It also explains why the
order is deliberately not promised: what makes the property useful is that
nobody is entitled to it.

**R12 — ACCEPTED, with the order left unstated.** `Pool.close` empties every
bucket into **one `InnerQueue`**, flattened — the close hook never sees buckets
or per-identity groups. One container, one loop, `pop_front` until empty,
release each item. The write is `pop` then `push_back` because it is the
simplest, **and no order is promised**, because the hook's loop is the same
whatever order the items arrive in. O(n), once, on a pool going down.

**R13 — ACCEPTED.** The five list-typed public signatures take `InnerQueue*`.
**There is no `InnerList`** — `3tk-naming-001.md` offers that name only if a
general list survives a real requirement, ruling 2 refuses one, and §1.1's audit
found no requirement. `InnerStack` stays behind `PoolBucket.free` and appears in
no public signature.

**R1, R2, R3, R5, R7 — the direction itself.** Ruled 2026-08-23, before the
stage ran.

**R4 — OUTSTANDING.** The last one. `InnerQueue` keeps a front insert
(`push_front`, `push_front_slot`) because Part 11.8 MUST requires a refused list
put to return the item to the **front** of the caller's list — `pool.c3:451`.
So the FIFO is not quite minimal, and it is a MUST that forces it.

**One more instruction, 2026-08-23:** a banned word of `rules-049.md` Part 5
that 001 used three times is not to be used. **Part 5's own scan scope skips
`design/secondary/`, so no scan had ever covered this folder.** A full scan of
the whole Part 5 list found nine hits, all of them in
`backup/3tk-core-redesign-proposal-001.md`: three of that word, four
custody-sense uses of two others, and two AI-ish words. `3tk-status.md` and
`3tk-log.md` were clean. **Proposal 002 is clean against the whole list**, and
001 was left as it was, being a record.

### The stage that produced it

```
Run 3TK-10 from design/secondary/lang/c3/3tk-status.md
```

**Done 2026-08-23. That row reads DONE and it is not re-run.**

**The sequence, confirmed by the owner 2026-08-23: proposal first, then code.**
It was followed: 3TK-10 wrote the proposal, the owner ruled R1 to R15 question
by question, and 3TK-11 wrote nothing 3TK-10 had not ruled. **Both are DONE.**

**The owner's direction of 2026-08-23 is now worked out in the proposal**, and
it is repeated here because a cold session should not have to open a second file
to know what was ruled:

1. **Drop `Any*` and every inherited ztk name.** The vocabulary becomes
   **Outer / Inner**. `AnyNode` → `Inner`, `AnyHandle` → `Handle`.
2. **Stop reproducing Zig's `DoublyLinkedList`.** No general-purpose list type.
3. **FIFO for the mailbox, LIFO for the pool** — the minimal intrusive
   containers, nothing more.
4. **The mailbox has two FIFOs**, ordinary and out-of-band, instead of one list
   with an anchor.
5. **One link, not two.** `next` only. `prev` goes.

Its reading is [3tk-naming-001.md](3tk-naming-001.md) and
[3tk-to-fifo-lifo-single-001.md](3tk-to-fifo-lifo-single-001.md), both from the
owner, plus specification Parts 4, 8 and 11.

**The four consequences are answered**, in the proposal's sections 5, 3, 4 and
8 respectively. Two of them came out differently from the way plan 006 framed
them, and both are in the proposal's *What the reading found*: consequence 2
makes the port **stronger**, not weaker, and invariant 22 **survives**.

**3TK-11 has run and is not re-run.** To add the next stage, the shape is a
single line and the agent does the versioning:

```
Add 3TK-12 to the plan and run it
```

To bump the plan without running anything yet, add `Do not run it.`

Whatever the stage, the agent's first three actions are: read this file, read
the plan's section for that stage, read that stage's named inputs. Nothing
outside them. A stage whose row above reads DONE is not re-run without being
told.

### The candidates for a later stage, and what each is worth

None is authorized. They are listed so the owner can name one without
re-deriving the list, and in the order this file would recommend them.

**The sanitizer run is gone from this list — 3TK-9 did it**, and it found four
races in the tests and none in the port.

**The table was written to be read after 3TK-11, and 3TK-11 has run.** The core
has stopped moving, so the two candidates that were waiting on it — a worked
example and the cross-target builds — are both live now. A worked example
written today is written against `Inner`, `InnerQueue` and `InnerStack` and will
not be obsolete on arrival.

**Specification 003 is not in this table** because it is not a candidate: R14
ruled it, and it needs scheduling rather than choosing. It is the one thing that
belongs ahead of everything here, because the port is currently ahead of the
document every other port reads.

| Candidate | What it does | Why it might wait |
|---|---|---|
| **Cross-target builds** | ztk is green on three cross targets; 3tk has been built for linux-x64 only | Mechanical, and `run-builds.sh` already has the shape for it. Now the top of the list |
| **A worked example** | An application using the port end to end — a producer, a consumer, a pool with real hooks — as documentation that compiles | The tests prove the invariants; nothing yet shows a reader how to *use* it. It would also be the first honest test of whether the hook contract is easy to obey — 3TK-9 says the toolkit's own tests did not obey it |
| **Packaging** | `.c3l`, `c3c dist`, distribution. `backup/3tk-build-dist.md` B2 claims the tooling is early alpha, and that is still unverified | Outside the specification entirely, and it depends on the C3 toolchain rather than on this work |
| **MemorySanitizer** | The third sanitizer c3c offers, not run by 3TK-9 | Needs the whole dependency stack instrumented, including the C3 standard library, or it reports false positives. Low value for the effort |

The first two would each be one stage. Packaging may not be worth a stage until
B2 is checked, which is ten minutes of measurement.

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
Part 11.9's open question about the ztk book is decided — the book is being
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

The specification is the deliverable that outlives this line of work. It, the
ztk audit and `port-flow-001.md` are in [`../common/`](../common/README.md). Any
of these starts from the specification and nothing else:

- **otk** (Odin) needs refactoring.
- **ztk** (Zig, this repo) needs tuning.
- **dtk** (D) has a prepared folder as of 2026-08-23 —
  [../d/dtk-status.md](../d/dtk-status.md). Scope is ruled (Linux only, `@nogc`,
  not betterC yet), the eighteen inputs are mapped, and no stage has run. It
  starts by reading its own status file, not this one.

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
nothing else, and 3TK-9 deliberately kept it that way.

The sanitizers are a **second** script, because they need a C compiler that
ships their runtimes and `run-builds.sh` may not depend on one:

```
design/secondary/lang/c3/3tk/run-sanitizers.sh
```

Thread on two builds, address on one. It **skips and exits 2** if its compiler
is missing, saying so — a skip is not a pass. `SAN_CC=<compiler>` overrides the
default of `clang`.

## Files

Edited in place, no suffix — the entry points:

- `3tk-status.md` — this file.
- `3tk-log.md` — the narrative, append-only, newest first.

Versioned — a change makes a new file, the old one stays and is listed below:

- **Current plan: [3tk-staging-plan-006.md](3tk-staging-plan-006.md).**
- [ztk-audit-001.md](../common/ztk-audit-001.md) — the 3TK-1 output.
- **[matryoshka-specification-002.md](../common/matryoshka-specification-002.md) — the
  portable specification, and the source of truth for every port.** The 3TK-2
  output, revised.
- [3tk-drafts-review-001.md](3tk-drafts-review-001.md) — the 3TK-3 output.
- [c3-capabilities-001.md](c3-capabilities-001.md) — the 3TK-4 output.
- **[3tk-porting-proposal-004.md](3tk-porting-proposal-004.md) — the design of
  record. The sixteen decisions accepted by the owner, 2026-08-23; D1's argument
  rewritten and its ruling reaffirmed by 3TK-8, same day.**
- [3tk-toolkit-notes-001.md](3tk-toolkit-notes-001.md) — the 3TK-6 output,
  beside the code at `3tk/`.
- [3tk-containers-notes-001.md](3tk-containers-notes-001.md) — the 3TK-7
  output.
- **[3tk-naming-001.md](3tk-naming-001.md)** and
  **[3tk-to-fifo-lifo-single-001.md](3tk-to-fifo-lifo-single-001.md)** — from
  the owner, 2026-08-23. Not produced by any stage and not versioned by this
  folder. **The input to 3TK-10.** The first proposes Outer/Inner naming; the
  second argues `NodeList` should not be the centre of the design.
- [3tk-sanitizer-notes-001.md](3tk-sanitizer-notes-001.md) — the 3TK-9 output.
  Seven findings. The port is clean under thread and address; the four races the
  first run found were all in the tests.
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

- [3tk-core-redesign-proposal-001.md](backup/3tk-core-redesign-proposal-001.md),
  replaced by
  [3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md) on
  2026-08-23, when the owner ruled on it question by question. **Three decisions
  moved**, which is why a version was cut rather than a note appended: **R6 was
  refused** and the self-link replaced it, **R11 acquired its reason**, and
  **R15 dropped `put_all`**, retiring R4. 001 is the record of what the stage
  proposed; 002 is what was ruled, and 002 is 3TK-11's input.

- [3tk-staging-plan-001.md](backup/3tk-staging-plan-001.md), replaced by plan
  002 on 2026-08-23. The only change was the addition of 3TK-6.
- [3tk-staging-plan-002.md](backup/3tk-staging-plan-002.md), replaced by
  [3tk-staging-plan-003.md](backup/3tk-staging-plan-003.md) on 2026-08-23. The only
  change is the addition of 3TK-7.
- [3tk-staging-plan-003.md](backup/3tk-staging-plan-003.md), replaced by
  [3tk-staging-plan-004.md](backup/3tk-staging-plan-004.md) on 2026-08-23. The only
  change is the addition of 3TK-8.
- [3tk-porting-proposal-001.md](backup/3tk-porting-proposal-001.md), replaced by
  proposal 002 on 2026-08-23, when the owner accepted all sixteen decisions.
- [3tk-porting-proposal-002.md](backup/3tk-porting-proposal-002.md), replaced by
  [3tk-porting-proposal-003.md](backup/3tk-porting-proposal-003.md) on 2026-08-23, in
  answer to [3tk-porting-proposal-review.md](backup/3tk-porting-proposal-review.md).
  No decision moved.
- [3tk-staging-plan-005.md](backup/3tk-staging-plan-005.md), replaced by
  [3tk-staging-plan-006.md](3tk-staging-plan-006.md) on 2026-08-23. The only
  change is the addition of 3TK-10.
- [3tk-staging-plan-004.md](backup/3tk-staging-plan-004.md), replaced by
  [3tk-staging-plan-005.md](backup/3tk-staging-plan-005.md) on 2026-08-23. The only
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
  [matryoshka-specification-002.md](../common/matryoshka-specification-002.md) on
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

- `../common/matryoshka-specification-002.md` — the portable specification.
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

**The specification moves to 003 — ruled, and still not scheduled.** Nine Parts
change, and dtk and otk read them. `../common/` is untouched: 3TK-11 wrote
nothing there, exactly as plan 006 required. **So the port is ahead of its own
specification**, and a port written from
`../common/matryoshka-specification-002.md` today would reproduce `prev`, the
general list and the out-of-band anchor. That is the strongest argument for
cutting 003 next.

**Nothing is waiting on the owner except the choice of what runs next.**
Specification 003 is authorized in direction and needs a stage or a revision
named; everything else in *The candidates for a later stage* is unauthorized and
listed only so the owner can pick without re-deriving the list.

## What is left, and none of it is Matryoshka

Everything below was **outside 3TK-8**, which was about the proposal and two
creation paths, and none of it moved. From `3tk-containers-notes-001.md`. Each
is a candidate for a 3TK-9, and *How to continue after a clear* has them as a
table with a recommendation.

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
- 3tk is green: **85 tests** in four modes, plus 12 negative programs and 3
  layering checks. `3tk/run-builds.sh`, 59 checks, 0 failures.
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

## Open questions

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
- **The banned-word scan has never covered this folder.** `rules-049.md` Part
  5's own scope skips `design/secondary/`, so eleven stages of documents were
  written unchecked. Found 2026-08-23 when the owner caught one word in the
  redesign proposal; a full scan then found nine hits in that file alone. The
  proposal was replaced by a clean 002. **Whether Part 5's scope should change
  is the owner's call and belongs to the kitchen line, not to 3tk.**
- ~~Three uses of a Part 5 word in this file, each describing a folder
  containing files rather than an item in custody.~~ **Closed by the owner,
  2026-08-23: fixed.** All three now read `contains`, which is one of Part 5's
  own named replacements and is more exact for a folder. Part 5 scopes that ban
  to the custody sense but names replacements "for a container"; the owner
  resolved the ambiguity toward fixing. One other word, the concrete noun for
  c3c's test runner, was judged not a hit and is untouched.
- **`3tk-log.md` carries about a dozen older hits and is deliberately left as
  it is.** Owner's instruction, 2026-08-23: the log is append-only and
  rewriting it destroys the record, which is also why Part 5's scope skips it.

- **3TK-8's four questions are all closed**, ruled on 2026-08-23 before the
  stage started. They are kept below with their answers, and in the stage's plan
  section, because the reasons are part of the design record.
- ~~Does the 003 review move to `backup/`?~~ **Closed by the owner, 2026-08-23:
  yes**, once proposal 004 answers it — as the first review did. It moves only
  **after** 004 carries what a current reader needs from it; until then it is
  input and stays live.
- ~~Is the failing-allocator test worth building?~~ **Closed by the owner,
  2026-08-23: build it, in a dedicated file.** `3tk/test/t_alloc.c3` becomes the
  home for the test allocators — counting, failing, and whatever a later stage
  needs — rather than an addition to `common.c3`, which is the shared fixture
  every test file reads. `project.json` declares `"test-sources": [ "test" ]`,
  so the harness needs no change. Verified.
- ~~Where do the capability answers live?~~ **Closed by the owner, 2026-08-23:
  inside proposal 004 only.** `c3-capabilities-001.md` is the 3TK-4 output and
  is not amended; no `c3-capabilities-002.md` is cut. The measurements have one
  home, beside the decision they support.
- ~~Does the D1 ruling stand?~~ **Closed by the owner, 2026-08-23.** Public
  direct representation, and **no code changes for the sake of hiding** — the
  port does not fight the language for a boundary the language will not enforce
  (M5). D1's *argument* is corrected in proposal 004, a comment marks the
  boundary, and the documents say so. The `Impl*` split is rejected on the
  record, on cost rather than on Part 11.1.
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
