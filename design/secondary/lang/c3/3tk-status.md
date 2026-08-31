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

**`P6` is built.** **3TK-56 ran on 2026-08-30**: `on_close` takes the queue by
value, `InnerQueue.take()` is in `queue.c3`, both `pool.c3` call sites use it,
and `3tk-open-defects.md` has no open row left. Only **3TK-50** — the examples
tree, independent of the fix — has not run.

**Before 3TK-50 could start, the owner reviewed the pattern catalog and ruled
a defect in it: a stack outer is illegal, not only across a mailbox or thread
boundary.** 3tk computes an outer's address from its embedded `Inner` at every
crossing, and a stack address is valid for exactly one lexical instance of one
frame — a copy, or a use after the frame returns, reaches through a stale
address, and it can appear to work before it fails. **This closed a Stage A,
2026-08-31**, ahead of 3TK-50: the reference book, the pattern catalog and the
example rules were revised — the one stack-outer example in each was replaced
with a heap outer — and republished as new versions in a second local repo,
[`matryoshka-3tk/design/`](https://github.com/g41797/matryoshka-3tk/tree/main/design),
which the owner is also using for light builds and doc-site preview. The old
versions moved to `backup/` here, and every live cross-reference in this repo
now points at the new location. **3TK-50 starts from the corrected documents.**

**The lifetime fix is built, on both tools, and its books are closed.** **The
mailbox by 3TK-53 and the pool by 3TK-54, both 2026-08-28**; each `release` now
checks `_closed && _active == 0` under the mutex and aborts in all four builds
when it does not hold. **3TK-55 closed the defect row on 2026-08-28** and
re-measured everything against the built tree.

**And the shared half is written too.** **3TK-52 wrote
[../common/matryoshka-specification-005.md](../common/matryoshka-specification-005.md)
on 2026-08-28**, after the owner ruled `Q-D`. `Part 11.12` is now *Closed and
quiet before release*, `004` is in `common/backup/`, and every live link points
at `005`. **The lifetime fix is complete, in code and in text.**

**The owner ruled it on 2026-08-28:**

> **Release while a call is in flight is not prevented. It is written down as a
> thing the caller must not do, and it is checked. It is not waited for.**

**[3tk-lifetime-fix-005.md](3tk-lifetime-fix-005.md) bound 3TK-53 and 3TK-54 and
has now been built.** Three review rounds are absorbed into it and **reviewing of
it is closed.** Section 4 is the ruling and the text it owes; section 15 is what
the ruling closed. **The one thing it asked for and did not decide — what the
added lock in `Pool.get` costs — is measured in the log's 3TK-54 entry.**

**Where [3tk-staging-plan-020.md](3tk-staging-plan-020.md) disagrees with it, the
document wins.** The plan is published and is not edited in place, so its 3TK-53
charter still says `release(InnerQueue* out)` and *the `always_assert` removed*.
**Both are wrong**: no signature changes, and the assertion is **rewritten**, to
check `_closed && _active == 0`.

**And two places where the document lost, both settled by 3TK-53 and both
settled the same way by 3TK-54:**

- **`release` does not call `_close`.** Section 2 says it does *if the tool is
  still open*; section 13 says `negative/release_open_pool.c3` must still abort.
  Both cannot hold. **The check comes first, and nothing else runs when it
  fails** — so `_close` has one caller in each tool, not two.
- **`Part 11.12` belonged to 3TK-52, not to the code stages.** It is in
  [../common/matryoshka-specification-005.md](../common/matryoshka-specification-005.md)
  and binds four ports. **A code stage wrote the rule into `ref/` and the
  descriptors and left the shared clause alone.** That is what let 53 and 54 run
  while `Q-D` was open, and **3TK-52 has since written the clause itself.**

## The stages that have not run

| stage | what it does | start it with |
|---|---|---|
| **3TK-50** | **The examples tree**, plan 019's leftover and the first code under `3tk/examples/`, run in steps grouped by catalog section. Reads [3tk-example-rules-003.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-example-rules-003.md) and [3tk-patterns-002.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-patterns-002.md), both in `matryoshka-3tk/design/`. **Independent of the fix. Steps 1 through 7 ran 2026-08-31** | `Read design/secondary/lang/c3/3tk-status.md. Continue 3TK-50, step 8 (the next catalog section after "Topology patterns", "Pool patterns", entries 37-45).` |

**3TK-52, 3TK-53, 3TK-54, 3TK-55 and 3TK-56 all ran, 2026-08-28 to
2026-08-30**, and between them the two tools carry the mechanism, the defect
list agrees with them, the shared specification states the rule and `on_close`
is by value. **3TK-50 is the only stage left, and it does not block or get
blocked by anything above.**

**3TK-50 step 1 ran 2026-08-31**, catalog section "Slot and transfer idioms."
`3tk/examples/` now exists: `outers.c3` and `helpers.c3` are the shared
infrastructure, and nine files carry entries 1 and 3 through 10 (entry 2 has
no code shape). `test/t_examples.c3` wraps all nine, and `project.json`'s
`test-sources` gained `"examples"`. The log entry has the one finding worth
keeping: a leak in entry 3's own example, from discarding the queue
`Mailbox.close` gave back, which entry 30 itself warns against.

**3TK-50 step 2 ran 2026-08-31**, catalog section "Crossing the border."
Five more files carry entries 11, 12, 13, 15 and 16 (entry 14, "Stack outers
are illegal", has no code shape — its prohibition is why every outer in this
section and the last is heap-allocated). Two build errors surfaced only by
`run-builds.sh`: a standalone `!catch` is not legal c3c 0.8.3, and
`foreach (i : usz[3])` does not enumerate. Both are in the log entry.
`run-builds.sh` is green — 87 checks, four builds, 106 tests each. **Not yet
copied to `matryoshka-3tk` or pushed** — that is the owner's step.

**3TK-50 step 3 ran 2026-08-31**, catalog section "Dispatch". Four more files
carry entries 17 through 20 (entries 21 and 22 have no code shape — the last
branch rule and a diagram — so neither has a file). One build error surfaced
only by `run-builds.sh`: the catalog's entry 18 code shape still has
`on_close` taking `InnerQueue*`, the signature from before 3TK-56 made the
hook take the queue by value; the example was corrected, the catalog was not
— it lives in `matryoshka-3tk` and this stage only writes `examples/`.
`run-builds.sh` is green — 87 checks, four builds, 110 tests each. **Not yet
copied to `matryoshka-3tk` or pushed** — that is the owner's step.

**3TK-50 step 4 ran 2026-08-31**, catalog section "The infrastructure is an
outer too". Four more files carry entries 23 through 26 — every entry in this
section has a code shape, so all four got a file. One build error surfaced
only by `run-builds.sh`: entry 26's no-op hooks struct had no fields, and c3c
refuses a zero-sized struct; it was given one unused `bool` field. `run-builds.sh`
is green — 87 checks, four builds, 114 tests each. **Not yet copied to
`matryoshka-3tk` or pushed** — that is the owner's step.

**3TK-50 step 5 ran 2026-08-31**, catalog section "Mailbox patterns". Six
more files carry entries 27 through 32 — every entry in this section has a
code shape, so all six got a file. One defect found before any build ran:
entry 31's first draft called `send` on a mailbox already released, a
use-after-free, fixed by releasing only after the refused send is checked.
One build error surfaced only by `run-builds.sh`: entry 32's `Atomic{bool}`
needed `import std::atomic::types` written explicitly, since nothing else in
that file pulls it in the way `mtk` does elsewhere. Entry 32 is the section's
only example with a real second thread, following `t_concurrency.c3`'s
`Thread`/`thread::sleep` shape. `run-builds.sh` is green — 87 checks, four
builds, 120 tests each. **Not yet copied to `matryoshka-3tk` or pushed** —
that is the owner's step.

**3TK-50 step 6 ran 2026-08-31, out of catalog order: the wrapper rule made
explicit, and the two wrappers that already broke it.** The owner asked for
the "no logic of its own" rule for `test/t_examples.c3` wrappers to be
written down explicitly and for the tree to be checked against it before
going further. [3tk-example-rules-003.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-example-rules-003.md)
now spells out that a wrapper may create and tear down shared infrastructure
but must not touch a `Slot`, a `Handle` or an `InnerQueue` itself. Checked
against every wrapper written by steps 1 through 5: two violated it —
`test_example_insert_from_slot` drained and released a queue itself, and
`test_example_reach_into_a_full_slot` received and released a Slot itself.
Both moved into their example functions (`004-insert_from_slot.c3` and
`016-reach_into_a_full_slot.c3`), and both wrappers are now call-and-assert.
`run-builds.sh` is green — 87 checks, four builds, 120 tests each, unchanged
in count since no test was added or removed. **Not yet copied to
`matryoshka-3tk` or pushed** — that is the owner's step.

**3TK-50 step 7 ran 2026-08-31**, catalog section "Topology patterns", entries
33–36. Four more files carry entries 33 through 36 — none says *no code
shape*, so all four got a file, composing the mailbox calls entries 27–32
already established with real threads: `033-request_response.c3`,
`034-pipeline.c3`, `035-fan_in.c3`, `036-fan_out.c3`. No build error, the
first step since step 1 with none. `run-builds.sh` is green — 87 checks, four
builds, 124 tests each. **Not yet copied to `matryoshka-3tk` or pushed** —
that is the owner's step.

## Open questions

| | what it asks | whose |
|---|---|---|

**Nothing is open in the lifetime-fix / `P6` set.** `Q-A`, `Q-B`, `Q-C`, `Q-E`
and `Q-G` were closed by the ruling of 2026-08-28 —
[3tk-lifetime-fix-005.md](3tk-lifetime-fix-005.md) section 15 says how each
went. `Q-D.1` and `Q-D.2` were ruled on 2026-08-28 and 3TK-52 built both
answers, so section 14 of that document, which still lists `Q-D` as open, is
out of date and this file is what holds. **`P6` / `Q-F` was ruled on
2026-08-28 and built by 3TK-56 on 2026-08-30.**

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
  Written as a rule in [3tk-example-rules-003.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-example-rules-003.md).
- **A ztk/3tk behavioural difference: whether `on_get` runs when a get already
  found a stored item.** 3tk does not, ztk does; Parts 11.7 and 12.2 side with
  3tk, the ztk audit and book with ztk. **Recorded, not ruled** — whichever way
  it goes, one of three things moves.
  [3tk-port-findings-004.md](3tk-port-findings-004.md) §5a.
- **Two lines of the ztk book are wrong about `on_get`** — `042.md:1288` and
  `:1448-1449`. **The ztk line's work, not this one.** The port is right and
  everything else agrees with it.
- **Should the containers support the Slot idiom at all?**
  `backup/3tk-who-supports-slot.md` argues they should not.
  3TK-10 did not rule it and 3TK-11 did not act on it, so the code has it. Two
  methods and two tests.
- **ztk owes one sentence, and it is the ztk line's to write.** Specification
  `005` Part 11.12 says **every port states** the closed-and-quiet precondition,
  and that a port which does not check it says so. **`src/mailbox.zig` has a
  closed flag and no count of calls in flight**, so ztk states rather than
  checks — which the clause allows and which nobody has yet written into ztk's
  own documentation. **No ztk code change is implied.**
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
  against the real structs by 3TK-53, and the pool's `release` has the same
  shape; **section 7 of the fix document is a sketch and is not to be copied.**
- **The count covers the hook, not the function body.** A pool call that leaves
  the mutex to run application code stays active until that code has returned,
  and that includes the *second* `on_close` a straggling `put` performs. A
  refactor that lowers the count before the hook breaks the fix silently, and
  only `run-sanitizers.sh` and the four tier 1 programs would say so.
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
been run. Last measured 2026-08-31, by 3TK-50 step 7 (`examples/` and
`test/t_examples.c3` revised, `src/` untouched).

```
./3tk/run-builds.sh        87 checks, 0 failures, four builds green
                           124 tests in each build
./3tk/check-doc-loop.sh    not re-run this step — src/ did not change
                           (last run: 0 differing blocks, 457 sentences, 456
                           found, 1 missing — the pre-existing inner.c3 module
                           summary; 0 banned words. REF must point at
                           matryoshka-3tk's 3tk-reference-005.md; the in-repo
                           default path is stale since the reference moved
                           there)
./3tk/run-sanitizers.sh    not re-run this step — src/ did not change
grep -roiwE 'items?'       not re-run this step
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
- **A port may run ahead of the shared specification**, writing a rule into its
  own code and its own `ref/` while the shared clause is still open, **as long as
  it writes down which way it assumed the question would go.** The shared text
  catches up in a later stage. **Ruled 2026-08-28** as `Q-D.2`, after 3TK-53 and
  3TK-54 had done exactly that. **The boundary is dtk**: dtk builds from the
  specification alone, so the shared text is current before dtk's first stage.
  The `Item`/`Outer` wording has the same deadline for the same reason.
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
- **`ref/`** — the live reference: [ref/3tk-decisions-004.md](ref/3tk-decisions-004.md),
  [ref/3tk-doc-loop-004.md](ref/3tk-doc-loop-004.md). **The only place staleness
  can hide**, since everything else is a frozen stage output.
- **[`matryoshka-3tk/design/`](https://github.com/g41797/matryoshka-3tk/tree/main/design)**
  — a second, separate local repo, for light builds, doc-site preview, and the
  live copies pushed there after each verified step. **The reference book, the
  example rules and the pattern catalog live there now, not in this repo's
  `ref/`**: [3tk-reference-005.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-reference-005.md),
  [3tk-example-rules-003.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-example-rules-003.md),
  [3tk-patterns-002.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-patterns-002.md).
  Moved there because the owner is running builds and previews from that repo
  going forward. **Ask the owner exactly where before creating a new file
  there — every time**, even though `design/` is the default target.
- **`backup/`** — superseded versions. **Not a source of truth**, and the owner
  empties it. `3tk-patterns-001.md`, `3tk-example-rules-001.md`,
  `3tk-reference-004.md` and `3tk-doc-loop-003.md` moved here when their
  successors published to `matryoshka-3tk`.
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
Read design/secondary/lang/c3/3tk-status.md. Continue 3TK-50, step 8 (the next catalog section after "Topology patterns", "Pool patterns", entries 37-45).
```

**Nothing is waiting on a ruling.** Stage A closed the stack-outer defect on
2026-08-31. 3TK-50 runs in steps, grouped by the pattern catalog's own
sections — nine of them, in order — **except step 6, which ran out of
catalog order**: the wrapper rule made explicit and the tree checked against
it, after entries 27-32 exposed two wrappers that already broke it. A step
number and a catalog section no longer match one-to-one because of it; the
log entry for each step says which section, if any, it covers. Each step
writes its examples (or, for a rule step, revises what an earlier step
wrote), runs `3tk/run-builds.sh`, and only then is copied to `matryoshka-3tk`
and pushed and previewed there, by the owner. This file's *stages that have
not run* table names the next step; a later resume line names whichever step
follows that.

For orientation only:

```
Read design/secondary/lang/c3/3tk-status.md and report where the 3tk work stands.
```

## The stages that have run

**Fifty-six, and the log has an entry for every one.** This table is the list,
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
| **3TK-54** | pool, in code: the hook window, and one lock measured | 2026-08-28 |
| **3TK-52** | the shared clause: closed and quiet, and specification 005 | 2026-08-28 |
| **3TK-55** | the defect list catches up with the code | 2026-08-28 |
| **3TK-56** | the close hook takes the queue by value, and `P6` is closed | 2026-08-30 |

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
1–3 found: one table and one section per item, edited in place. **`P6` was the
last item open** and was ruled on 2026-08-28; **3TK-56 built it on 2026-08-30.
Nothing on that list is open any more.**
