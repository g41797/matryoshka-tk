# 3tk — status

**This file is read at the start of every stage and written at the end of one.
It is kept short for that reason.**

## The rule: what goes here, and what goes to the log

> **Status holds what has not happened, what is true now, and how to start.
> [3tk-log.md](3tk-log.md) holds what happened, when, and why.**

- **A stage ends by appending one entry to the log** — newest first — **and
  touching this file only where its state changed**: its own row, the measured
  numbers, the open questions.
- **If a sentence explains a decision, it is log.** If it tells the next session
  what to do, it is status.
- **A finished stage keeps a row here. It never keeps a section.** The narrative
  of what it found, argued and measured lives in the log entry and in whatever
  document the stage produced.
- **Nothing is duplicated between the two.** A fact that is in the log is not
  repeated here to be safe.
- **Ruled 2026-08-28**, after this file reached 2,358 lines by keeping a section
  per stage. It is now a list and a state, and the history it held was already
  in the log.

## What is live now

**The lifetime fix, half built.** **The mailbox is done — 3TK-53, 2026-08-28.**
`Pool.release` still checks `_closed`, which is state and not lifetime, so a
release racing a call still in flight frees memory that call is using. Tracked as
`Q5`, and **3TK-54 is the other half.**

**The owner ruled it on 2026-08-28:**

> **Release while a call is in flight is not prevented. It is written down as a
> thing the caller must not do, and it is checked. It is not waited for.**

**[3tk-lifetime-fix-005.md](3tk-lifetime-fix-005.md) binds 3TK-53 and 3TK-54, and
is the only document they read.** Three review rounds are absorbed into it and
**reviewing of it is closed.** Section 4 is the ruling and the text it owes;
section 15 is what the ruling closed.

**Where [3tk-staging-plan-020.md](3tk-staging-plan-020.md) disagrees with it, the
document wins.** The plan is published and is not edited in place, so its 3TK-53
charter still says `release(InnerQueue* out)` and *the `always_assert` removed*.
**Both are wrong**: no signature changes, and the assertion is **rewritten**, to
check `_closed && _active == 0`.

**And two places where the document loses, both settled by 3TK-53 and both
waiting for 3TK-54 in the same shape:**

- **`release` does not call `_close`.** Section 2 says it does *if the tool is
  still open*; section 13 says `negative/release_open_pool.c3` must still abort.
  Both cannot hold. **The check comes first, and nothing else runs when it
  fails** — so `_close` has one caller, not two.
- **`Part 11.12` belongs to 3TK-52, not to the code stages.** It is in
  [../common/matryoshka-specification-004.md](../common/matryoshka-specification-004.md)
  and binds four ports. **A code stage writes the rule into `ref/` and the
  descriptors and leaves the shared clause alone.** That is what lets 53 and 54
  run while `Q-D` is open.

## The stages that have not run

| stage | what it does | start it with |
|---|---|---|
| **3TK-54** | **Pool, in code.** What 3TK-53 did to the mailbox, plus the hook window and the straggler path, `Pool.get`'s added lock established and measured, the `2DO` block at `pool.c3:233-238`, four negatives. **`src/mailbox.c3` is the exemplar** | `Run 3TK-54.` |
| **3TK-52** | **The shared clause.** `Part 11.12` in [../common/matryoshka-specification-004.md](../common/matryoshka-specification-004.md), which binds otk, ztk and dtk. **Needs `Q-D`** | `Run 3TK-52.` |
| **3TK-50** | **The examples tree**, plan 019's leftover and the first code under `3tk/examples/`. Reads [ref/3tk-example-rules-001.md](ref/3tk-example-rules-001.md) and [ref/3tk-patterns-001.md](ref/3tk-patterns-001.md). **Independent of the fix** | `Run 3TK-50.` |
| **3TK-55** | **Close the books.** `Q5` to fixed in [3tk-open-defects.md](3tk-open-defects.md), `P6` re-stated, this file and the log brought up to date, every number re-measured | `Run 3TK-55.` |

**3TK-53 ran on 2026-08-28**, and the mailbox is now the worked example 3TK-54
copies: the hook window and the straggler path are the only parts of the
mechanism it did not meet. **3TK-50 is independent** of the fix and may run
before, after or between the rest.

## Open questions

| | what it asks | whose |
|---|---|---|
| **`Q-D.1`** | does the shared specification state *closed **and quiet** before released*, so every port states it? | owner |
| **`Q-D.2`** | if it does, does 3TK-52 run before 3tk's code, or does 3tk go first under a written assumption? | owner |
| **`P6` / `Q-F`** | what does the pool observe when a close hook is handed items and frees some, leaves some? Its lifetime blocker is gone; its own question is not | owner |

`Q-A`, `Q-B`, `Q-C`, `Q-E` and `Q-G` were closed by the ruling —
[3tk-lifetime-fix-005.md](3tk-lifetime-fix-005.md) section 15 says how each went.

**And these, which are not about the lifetime fix.** One line each; the document
named holds the reasoning.

- **Two port defects, and they are the only ones.** **P3** — a waiting call can
  return the condition variable's own fault, outside Part 19's outcome set;
  unreachable on the current posix backend, recorded because the next port copies
  the shape. **P4** — Part 2.6 MUST: the pool's leaver signals on one bucket over
  a condition variable shared by *n*. Nothing is lost today, because every path
  that makes an item available calls `broadcast`. **Both `3tk-only`, neither
  ruled.** [3tk-deviations-001.md](3tk-deviations-001.md).
- **The port says `Item` where the owner's word is `Outer`.** Ruled 2026-08-26:
  **new work says Outer; the existing tree is not searched and replaced.** If it
  is ever repaired it is repaired whole — `src/`, `ref/` and the shared
  specification together. **The deadline is dtk's first stage**, because dtk
  builds from the specification alone and would bake the word into a fourth port.
  Written as a rule in [ref/3tk-example-rules-001.md](ref/3tk-example-rules-001.md).
- **A ztk/3tk behavioural difference: whether `on_get` runs when a get already
  found a stored item.** 3tk does not, ztk does; Parts 11.7 and 12.2 side with
  3tk, the ztk audit and book with ztk. **Recorded, not ruled** — whichever way
  it goes, one of three things moves.
  [3tk-port-findings-003.md](3tk-port-findings-003.md) §5a.
- **Two lines of the ztk book are wrong about `on_get`** — `042.md:1288` and
  `:1448-1449`. **The ztk line's work, not this one.** The port is right and
  everything else agrees with it.
- **Should the containers support the Slot idiom at all?**
  `backup/3tk-who-supports-slot.md` argues they should not.
  3TK-10 did not rule it and 3TK-11 did not act on it, so the code has it. Two
  methods and two tests.
- **Whether otk gets a status file.** The pointer at the specification is
  written; the folder is not prepared, and preparing it means saying what otk's
  line of work is. The owner's.
- **Whether the banned-word scan should cover this folder.** `rules-049.md`
  Part 5's scope skips `design/secondary/`. **The kitchen line's call, not 3tk's.**
- **`design/secondary/context.md` lists no `lang/` subfolder**, so every file
  under it counts as an orphan to `kitchen/tools/check_design.sh`. Drift, noted,
  not fixed. **The 14 dead links are the number that would signal a regression**,
  not the orphan count.

**The seven questions plans 018 and 019 left are still open** and are in those
plans.

## Standing facts

- **`Mutex.destroy` is `pthread_mutex_destroy` and it aborts on `EBUSY`**, so a
  held mutex cannot be destroyed. `release` takes the mutex, checks quiet,
  releases it, then destroys the condition variable and the mutex. Established
  against the real structs by 3TK-53; **section 7 of the fix document is a
  sketch and is not to be copied.**
- **`@private` on a method is ignored by c3c 0.8.3**, with a warning, and the
  port already lives with it: `Mailbox._close` and the pool's helpers are private
  by intent and reachable in fact. What keeps them out of reach is `module
  mtk::mailbox` being a submodule, which `run-builds.sh` checks.
- **C3 is installed.** `c3c` at `/usr/bin/c3c`, stdlib sources at
  `/home/g41797/dev/langs/c3/lib/std/`. **No install step in any stage.**
- The toolchain 3TK-4 measured is `c3c` 0.8.3, LLVM 22.1.8, linux-x64. **Every
  capability answer is against that version.**
- **Never infer a build mode from the `-O` level.** `-O2` and above set
  `SAFE_MODE=false`. Always pass `--safe=yes` or `--safe=no` explicitly.
- **The fault-return operator is `~`**, not `?`. `return mtk::CLOSED~;`
- **`c3c test` detects leaks by default.** `--test-noleak` turns it off.
- **A negative program is compiled as an ordinary program**, so the test
  runner's macros — `@catch_is` among them — are out of reach. A negative that
  wants a fault writes `if (catch f = ...)`.
- **C3 has no UFCS**, and a method cannot be attached to a pointer alias, so
  `Handle` carries none.
- **C3 0.8.3 has no field-level privacy**, and `inline` does not create one. A
  `@private` struct inlined into a public one hides the type *name*; its fields
  stay readable and writable from another module.
- **The sanitizers need `--cc clang` on this machine.** Fedora's runtimes are not
  installed, so `cc` cannot link them — and plain `cc -fsanitize=thread` fails
  identically, so it is the machine and not c3c.
- **The seven raw drafts in `backup/` are input, never source of truth.** They
  contradict each other and some predate API 12 and 13.
  `3tk-drafts-review-001.md` is the measurement later stages read instead.
- **ztk is green** — 195/195 in four modes, three cross targets, closed
  2026-08-14.
- **[3tk-log.md](3tk-log.md) carries about a dozen older banned-word hits and is
  left as it is.** Owner's instruction: the log is append-only and rewriting it
  destroys the record.

## The measured numbers

**Re-measure before trusting any of these.** A scan counts only when it has just
been run. Last measured 2026-08-28, at the end of 3TK-53, with no source changed
since.

```
./3tk/run-builds.sh        71 checks, 0 failures, four builds green
                           89 tests in each build
./3tk/check-doc-loop.sh    0 differing blocks, 446 sentences, 445 found
                           1 missing — the pre-existing inner.c3 module summary
                           0 banned words
./3tk/run-sanitizers.sh    thread on two builds, address on one. Skips and
                           exits 2 if its compiler is missing; a skip is not a pass
```

`run-builds.sh` needs `c3c` and nothing else, and that is deliberate. Both
scripts take an optional directory and exit 2 on a bad one.

## Rules that hold across every stage

- **Each stage starts cold.** Its named inputs plus this file are enough.
- **Each stage ends with advice**: clear the context, or do not, and why.
- **Finishing a stage does not start the next.** The owner names it.
- **inner** = the embedded structure. **outer** = the struct that embeds it.
  Never "parent".
- **Porting is not transpiling.** The specification says what to preserve; each
  port decides how to spell it.
- **A change to `3tk/src` revises `ref/` in the same stage** — not later, and not
  as a debt for the next stage. A file under `ref/` that contradicts `3tk/src`
  is a defect of the stage that changed the source. Ruled 2026-08-25.
- **Every document is versioned.** A change makes the next number and the
  superseded version goes to `backup/`. `3tk-status.md` and `3tk-log.md` are the
  two exceptions and are edited in place.

## Where things live

- **`design/secondary/lang/c3/`** — this folder. Plans, status, log, notes, and
  the code at `3tk/`.
- **[`../common/`](../common/)** — what binds every port: the portable
  specification, the ztk audit, `port-flow-001.md`. Moved there 2026-08-23
  because a shared input inside one consumer's folder is a fork waiting to
  happen.
- **`ref/`** — the live reference: [ref/3tk-reference-004.md](ref/3tk-reference-004.md),
  [ref/3tk-decisions-003.md](ref/3tk-decisions-003.md),
  [ref/3tk-doc-loop-003.md](ref/3tk-doc-loop-003.md), the example rules and the
  pattern catalog. **The only place staleness can hide**, since everything else
  is a frozen stage output.
- **`backup/`** — superseded versions. **Not a source of truth**, and the owner
  empties it.
- **The port family:** otk (Odin), ztk (Zig, this repo), **3tk (C3, active)**,
  dtk (D — [../d/dtk-status.md](../d/dtk-status.md), no stage has run).
- `design/STATUS.md` and `design/STATUS-LOG.md` are untouched by this work.

**Unresolved, and it needs one word from the owner:** twelve documents and
`README.md` are in `backup/` while other files link to them at root. Are they
**archived** — in which case the links stop treating them as live — or
**displaced**, in which case they come back?

## How to start after a clear

Every line begins the same way, because every stage reads this file first:

```
Read design/secondary/lang/c3/3tk-status.md. Run 3TK-54.
```

For a ruling rather than a stage:

```
Read design/secondary/lang/c3/3tk-status.md and 3tk-lifetime-fix-005.md.
Q-D.1: <yes | no>. Q-D.2: <3TK-52 first | 3tk first>.
Write 3tk-lifetime-fix-006.md.
```

For orientation only:

```
Read design/secondary/lang/c3/3tk-status.md and report where the 3tk work stands.
```

## The stages that have run

**Fifty-three, and the log has an entry for every one.** This table is the list,
not the record.

| stage | | |
|---|---|---|
| **3TK-0** | staging plan | 2026-08-23 |
| **3TK-1** | ztk audit | 2026-08-23 |
| **3TK-2** | portable specification | 2026-08-23 |
| **3TK-3** | drafts review | 2026-08-23 |
| **3TK-4** | C3 capability study | 2026-08-23 |
| **3TK-5** | 3tk porting proposal | 2026-08-23 |
| **3TK-6** | toolkit in C3 | 2026-08-23 |
| **3TK-7** | two containers in C3 | 2026-08-23 |
| **3TK-8** | review answered, and a leak nobody could reach | 2026-08-23 |
| **3TK-9** | sanitizer found the tests, not the port | 2026-08-23 |
| **3TK-10** | core redesign, as a proposal | 2026-08-23 |
| **3TK-11** | core redesign, in code | 2026-08-23 |
| **3TK-12** | audit found what a forecast could not | 2026-08-24 |
| **3TK-13** | specification 003, and gap closes | 2026-08-24 |
| **3TK-14** | helper surface, measured then proposed, then re-measured against the stdlib | 2026-08-24 |
| **3TK-15** | two debts paid, and one of them was misfiled | 2026-08-24 |
| **3TK-16** | helper surface, in code | 2026-08-24 |
| **3TK-17** | Part 7.1 states promise, and 004 is cut for one Part | 2026-08-24 |
| **3TK-18** | field is called `link` | 2026-08-24 |
| **3TK-19** | three debts, and two of them were not repointings | 2026-08-24 |
| **3TK-20** | what this port decided, written where another port can read it | 2026-08-24 |
| **3TK-21** | `Inner` is one `any` | 2026-08-25 |
| **3TK-22** | findings document, against the shape it now describes | 2026-08-25 |
| **3TK-23** | retire what is no longer read | 2026-08-25 |
| **3TK-24** | pool difference, written where another port will find it | 2026-08-25 |
| **3TK-25** | status file is an entry point again | 2026-08-25 |
| **3TK-26** | stale `inner.c3` citations | 2026-08-25 |
| **3TK-27** | who reads notes | 2026-08-25 |
| **3TK-28** | a README for folder | 2026-08-25 |
| **3TK-29** | decisions, in one file | 2026-08-25 |
| **3TK-30** | API skeleton | 2026-08-25 |
| **3TK-30b** | page a caller reads | 2026-08-25 |
| **3TK-31** | exemplar, refused once, then written from ztk | 2026-08-25 |
| **3TK-32** | strings a user sees | 2026-08-25 |
| **3TK-33** | strip: `mtk.c3`, `inner.c3`, `helper.c3` | 2026-08-26 |
| **3TK-34** | strip: `managed.c3`, `queue.c3`, `stack.c3` | 2026-08-26 |
| **3TK-35** | strip: `mailbox.c3`, `pool.c3` | 2026-08-26 |
| **3TK-36** | reference in 042's shape | 2026-08-26 |
| **3TK-37** | comments moved out of the reference | 2026-08-26 |
| **3TK-38** | preview script | 2026-08-26 |
| **3TK-39** | doc loop as a document | 2026-08-26 |
| **3TK-40** | loop's first use on files it was not written for | 2026-08-26 |
| **3TK-41** | two containers, and the module description ruled | 2026-08-26 |
| **3TK-42** | last two files, and the loop closed | 2026-08-26 |
| **3TK-43** | flow document | 2026-08-26 |
| **3TK-44** | split, and what moves to `mtk` | 2026-08-26 |
| **3TK-45** | stack is public | 2026-08-26 |
| **3TK-46** | eight sections, eight labels | 2026-08-26 |
| **3TK-47** | move, and the checker | 2026-08-26 |
| **3TK-48** | rules for an example | 2026-08-26 |
| **3TK-49** | pattern catalog | 2026-08-26 |
| **3TK-51** | accumulated description | 2026-08-28 |
| **3TK-53** | mailbox, in code: closed is not quiet | 2026-08-28 |

**3TK-50 is missing from the list because it has not run** — it is plan 019's
leftover and is in the table above.

## The interrupt stages

**An INTR stage is important work that is not part of the flow.** Seven have run;
the log has each one.

| | what it was | touched code |
|---|---|---|
| **INTR 1–3** | four implementation reviews triaged into seven problems and five questions; the questions answered; **six of the ten items fixed** | **INTR 3 did**, and paid the doc loop inside the stage |
| **INTR 4–5** | two reviews of the lifetime document absorbed, twenty points then thirty-three | no |
| **INTR 6** | **the owner's ruling on `Q5`**, and the document rewritten around it | no |
| **INTR 7** | the third review — ten clarifications, and **reviewing closed** | no |
| **INTR 8** | this file compacted, 2,358 lines to a list and a state | no |

**[3tk-open-defects.md](3tk-open-defects.md) is the working list** for what INTR
1–3 found: one table and one section per item, edited in place. **`P6` is the one
item still open.**
