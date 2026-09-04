# 3tk — open defects

**The working list for fixing the port.** Ten items — **eight fixed, zero open,
two closed**. One table, one section each: where it is, what is wrong, what the
fix is, how to know it worked, and what state it is in.

**Everything known about the port is on this list, including what is not being
worked on.** A fixed item and a closed one stay in the table with their state, so
nothing has to be remembered from prose or found in another file.

**This file is edited in place**, like `3tk-status.md` and `3tk-log.md` and
unlike everything under `ref/`. It carries no version suffix for that reason. A
fixed item is marked in the table and its section is left standing, so the file
is also the record of what was done.

**The reasoning lives here now.** The four implementation reviews and the two
analysis files under `reviews/` were removed on 2026-08-27. Everything that was
not already written down twice was absorbed: the refuted claims into *Refuted*
below, `Q4`'s ruling into `P5`'s section, `Q5`'s into
[3tk-release-while-busy-001.md](3tk-release-while-busy-001.md). **If a fix turns
out to be wrong, change this file and say so** — there is no longer a second
document to re-argue it from.

**What can run, and what is waiting, is in [Order](#order)**, straight after
the table.

**Line numbers were re-printed live on 2026-08-28**, by 3TK-55, against the code
3TK-53 and 3TK-54 built. **Every earlier set is now wrong** — the `2DO` comments
they were anchored to are gone, and both `release` bodies grew. The numbers here
are the good ones. Re-print before trusting them again — every fix moves them.

## The list

| # | Where | What | Fix is | State |
|---|---|---|---|---|
| **P6** | `pool.c3:494`, `:564` | The pool can lose items and never know | **Ruled 2026-08-28: option 3.** `on_close` takes the queue **by value** — *I do not care what you did* — plus the wording | **ruled, built by 3TK-56.** [3tk-on-close-handoff-001.md](3tk-on-close-handoff-001.md) |
| **Q5** | `mailbox.c3:124`, `pool.c3:253` | A release racing a call still in flight | Ruled 2026-08-28: stated, and checked | **fixed 2026-08-28, 3TK-53 + 3TK-54, closed by 3TK-55** |

**Six of the ten are done, on 2026-08-27, in one stage.** Every mechanical and
wording item is fixed and verified: four builds green, 67 checks (63 before,
plus the new compile-time negative once per build), 87 tests, 0 failures; the
doc loop 0 differing blocks and 0 banned words. **Those are that day's numbers
and they have been overtaken** — the live ones are in
[After a fix](#after-a-fix).

**`Q5` is the seventh, and it is done.** 3TK-53 built the mailbox and 3TK-54 the
pool, both 2026-08-28; 3TK-55 closed this row against the built code on the same
day, after re-running all three scripts.

**`P6` is the eighth, and it is done.** Ruled 2026-08-28, built 2026-08-30 by
3TK-56 — [3tk-on-close-handoff-001.md](3tk-on-close-handoff-001.md) is its
charter. Nothing remains open.

**`P7` no longer needs one.** Reading `std::thread` showed the fault it warned
about cannot occur. The branch is dead, it stays, and a plain `//` comment at
each line says why. Its section carries the evidence.

**The ones that were never open are here for a reason.** `P5` and `P7` were
real findings and neither survived as one — its section says why, so nobody re-raises it.
`Q5` is real, was ruled, and is built: 3TK-53 did the mailbox, 3TK-54 the pool,
and 3TK-55 closed the row.

## Order

Only the open and deferred items have an order. The fixed ones are done.

**Runs now, waiting on nothing.**

- Nothing. The close-hook wording fix ran on 2026-08-27 —
  [3tk-on-close-policy-001.md](3tk-on-close-policy-001.md) is its record.

**Waiting on you.**

- Nothing. `P6` was the last one, ruled 2026-08-28 and built 2026-08-30 by
  3TK-56.

**Nothing is waiting on a stage any more.** `Q5` and `P6` were the last two,
and both ran.

**The dependency that is not obvious, and it is now discharged.**

- `P6`'s option 1 — count what was handed over, count what came back — wanted a
  moment when no further `on_close` can arrive. `Part 12.2` lets a late put call
  the hook again and names no end point. **The ruling of 2026-08-28 gave the port
  a different end point from the one that was expected**: `release` does not wait
  for quiet, it *asserts* it, so the moment exists — a `release` that returns has
  proved the count was zero — but it is proved rather than waited for. **Option 1
  is therefore unblocked**, and so are 2 and 3, which never needed it. **All
  three options are available and `P6` is a free ruling.**

Rewritten whenever an item changes state, in the same edit. Each section still
holds its own dependency — this is an index, not the record.

**What the six fixes moved outside `3tk/src`:**

- `ref/3tk-reference-003.md` — W1 and W2's sentences, and `required_alloc_offset`
  moved out of the `mtk::managed` listing into the compile-time section, where it
  is actually declared. `-002` went to `backup/`.
- `ref/3tk-decisions-003.md` — new entries for `P1`, `P2`, `P3`, `P4`, `W1`, `W2`,
  and **every `file:line` citation re-anchored**, which they needed anyway: the
  `2DO` comments had already made them stale. `-002` went to `backup/`.
- `3tk/negative/nocompile_managed_two_allocators.c3` — new, and added to
  `run-builds.sh`.
- `check-doc-loop.sh`, `move-module-docs.sh`, `doc_blocks.py`, `README.md`,
  `3tk-status.md` and this file now name `-003`.

**Line numbers were re-printed after the fixes.** The ones in the table are live
as of 2026-08-27, after the stage. **Every number in the two review files, and
every number in an earlier version of this table, is now wrong.**


## P6 — the pool can lose items and never know

**Three sites.**

```
pool.c3:494     the close hook, called with what was left after a race
pool.c3:564     the close hook, called with everything the pool held
pool.c3:527-528 one item with an identity the pool does not recognize  -- RULED 2026-08-27
```

**Re-printed 2026-08-28**, after the lifetime fix moved every line below
`Pool.release`.

**A pool cannot free its items.** It never allocated them. It does not know how.

**So close gives them away.** Everything left goes into one queue. The queue goes
to the application's close hook. That is the application's chance to free them.

**The queue is a local.** It dies with the call.

**Nothing is checked on the way back.** The hook freed everything, or some, or
none. The pool sees one thing in all three cases: the call returned. The items
are still allocated. Nobody holds a pointer to them.

**The interface is not at fault.** It says plainly: process or free every item.
**The gap is that the pool cannot tell whether that happened, and cannot say
anything if it did not.** This is the port's last sight of those items.

**The two close sites are the big ones.** Everything the pool ever held can be
in that queue.

**Their locking and their count are not part of this.** Whether `on_close` runs
outside the mutex, and whether it is called once or once per batch, were both
already ruled by `Part 12.2` and `Part 12.3` of the shared specification. Three
3tk doc sites still carry the superseded wording. That is a separate finding, and
it is written up in
[3tk-on-close-policy-001.md](3tk-on-close-policy-001.md). `P6` is only the leak
question.

**The third site is smaller and different, and it is now ruled.** A put hook
returns an item of an identity the pool was never created with. The pool has
nowhere to file it. A checking build stopped with a message; a fast build used
to drop the item and return. **The owner removed the guard on 2026-08-27.**

```c3
    mtk::@check(b != null, "the put hook returned an identity the pool was not created with");
    // if (!b) return; <- Force failure instead of silent bug
    b.free.push(h);
```

**The guard is written out, and its text stays as a comment.** With no guard,
`b.free.push(h)` on a null `b` writes through a null pointer and the process
dies. A checking build still stops at the `@check` with the message. A fast
build no longer swallows the item — it fails at the line instead. **Loud in both
builds.** The commented line is there so nobody restores the guard as a fix.

**This closes the third site.** The two close-hook sites are what `P6` still asks
about.

### Why it stands out here

**Every other way to lose an item is guarded.** Filling a full Slot. Chaining an
item twice. Moving a queue onto itself.

**These three are not.** Not by decision. Nobody worked out what the port would
do.

### The decision

**Detecting it is trivial.** One comparison: did the queue come back empty.

**Saying something is the problem.** No logging in the port, by design. No
stopping the program — `Q4` barred any new always-on check. `Pool.close` returns
nothing, so there is no value to put an answer in.

**Three answers.**

**1. Count it. Let the application ask.** The pool counts what it handed over and
what came back. The application reads the number after close and judges for
itself. Honest. Invents nothing — no log, no fault, no abort. Costs a field and a
few lines. **Does nothing for anyone who never looks.**

**2. Check it. Accept that a fast build will not.** `mtk::@check` after the hook
returns, asserting the queue is empty. A forgetful hook stops the program at the
line. Fastest way to find that bug while writing code. **It compiles out under
`--safe=no`** — the build where the loss actually matters. A development tool,
not a guarantee. Worth saying which it is.

**3. Trust the hook. Write that down.** The application asked for the hook. The
interface said what it owes. Verifying is not the port's job. **The port no
longer answers this way for a wrong identity** — that site now fails rather than
stays quiet, so option 3 is the less consistent one after the 2026-08-27 ruling.
Documentation, not code — so that the silence is not read as a promise.

**None is obviously right.** 1 is the most honest. 2 is the most useful while
writing code. 3 is cheapest and defensible. **1 and 2 combine** — a check while
developing, a number afterwards.

**State: RULED 2026-08-28, BUILT 2026-08-30 by 3TK-56 — option 3, and it is
stronger than option 3 as written here.** `on_close` takes the queue **by
value**, so the pool physically cannot observe what the hook did and the type
says so; the comment and the reference say it in words. **Options 1 and 2 are
closed for good, not deferred.** The ruling, the five defaults that go with it
and the work list are in
[3tk-on-close-handoff-001.md](3tk-on-close-handoff-001.md), which was **3TK-56's
only input besides the status file.** The measurement behind it: a by-value
struct parameter is an lvalue on c3c 0.8.3, so the hook's ergonomics are
unchanged, and the caller's copy is untouched, so nothing is left to count.
`InnerQueue.take()` (`../3tk/src/queue.c3`) is the O(1) move both call sites
use.

**Superseded state: open, waiting on your decision.** Closed by 3TK-56.

**What 3TK-56 moved outside `3tk/src`:**

- `ref/3tk-decisions-005.md` — the `P6` entry, under `pool.c3` and `queue.c3`.
  `-003` went to `backup/`.
- `ref/3tk-reference-004.md` — the `on_close` signature and its doc block, and
  `InnerQueue.take()` added to the queue's operation list. Edited in place, not
  versioned: this stage's charter names the file directly.
- `3tk-port-findings-004.md` — new §4a, the argument for dtk and otk. `-003`
  went to `backup/`.
- `3tk/test/t_queue.c3` — one positive test, `take_empties_the_source`. No
  negative is possible: a hook that keeps items dereferences nothing, so no
  build can notice.


## Refuted — claims that did not survive the code

**Absorbed from `reviews/3tk-05-review-analysis-001.md` when the reviews folder
was removed, 2026-08-27.** Each was a *required fix* in one of the four reviews.
Each is answered by a line of the port, not by an argument. Kept so none of them
is filed again.

**`must_from_handle` performs no check.** False. `helper.c3:89` carries
`@require is_mine(h, $Type) : "the handle is not of this type"`, which C3
compiles into the macro. `negative/wrong_type_must.c3` proves it:
`run-builds.sh` reports *wrong_type_must aborts* in both checked builds and
*runs to the end* in both fast ones, which is the documented behaviour and not a
gap.

**`Inner.as` is an unchecked duplicate.** False, same reason. `helper.c3:143`
carries its own `@require`.

**`required_alloc_offset` is a wrong qualification.** False. The name resolves
and the port compiles in all four builds. The real defect in that neighbourhood
was `P2`, which is not what was described.

**The `Slot` casts can be dropped.** False. `Slot` is a C3 `typedef` at
`inner.c3:79` — a distinct type, not an alias. `Handle` at `:70` is the alias.
The shorter forms would not compile.

**`helper::init` may overwrite the whole outer, losing the allocator write.**
False. `helper.c3:46-50` writes `n.link` and nothing else.

**Two shapes that are correct and might look open.** A waiting path has no fast
closed check, and that is the shape the reviews asked to keep. `Mailbox.create`
needs no condition-variable rollback, because nothing fallible follows it.

## Q5 — a release racing a call still in flight

**Where.** `Mailbox.release` at `mailbox.c3:112` and `Pool.release` at
`pool.c3:237`; the two assertions are at `mailbox.c3:124` and `pool.c3:253`.
**Both `2DO` comments are gone** — 3TK-53 replaced the mailbox's, 3TK-54 the
pool's. `grep -n 2DO src/*.c3` returns nothing, re-run 2026-08-28.

**What is wrong.** Both require the mailbox or the pool to be **closed**, and enforce it
hard — it aborts in every build mode. **Closed is not quiet.** `Part 12.3` MUST
forbids holding the mutex across a call into application code, so `Pool.put`
unlocks, runs `on_put`, and relocks at `pool.c3:424`. A close-and-release inside
that window makes the relock touch freed memory. `Mailbox` has no hook and so no
window of its own, but the same exposure: any call in flight when a release runs
is using memory that release frees.

A caller who reads `Part 11.12`, closes, and then releases has obeyed every
clause the toolkit states, and can still land here.

**The ruling, 2026-08-28, and it replaced the one before it.** On 2026-08-27
the owner ruled that the port would *wait*. On 2026-08-28, after INTR 4 to 7,
the owner ruled instead:

> **Release while a call is in flight is not prevented. It is written down as a
> thing the caller must not do, and it is checked. It is not waited for.**

So `release` names the rule and checks it, rather than blocking on application
code the port does not control.

**[3tk-lifetime-fix-005.md](3tk-lifetime-fix-005.md) is the document that binds
the two stages**, and it is the only one they read.
**[3tk-release-while-busy-001.md](3tk-release-while-busy-001.md) is superseded**
by it — its analysis of the race stands, its conclusion that `release` must wait
does not.

**What 3TK-53 built, 2026-08-28.** A `usz _active` under the mutex the mailbox
already owns; every accepted call raises it before it can run outside that mutex
and lowers it before returning; the assertion at `mailbox.c3:124` rewritten to
`_closed && _active == 0`; a private `_close` holding the state change; the rule
in the reference and in the descriptors; `negative/release_while_receiving.c3`
as a tier 1 program; two positive tests. Verified: four builds green, 71 checks,
89 tests, sanitizers clean.

**What 3TK-54 built, 2026-08-28.** The same mechanism in the pool, where it is
harder: `Part 12.3` forces the mutex open across every hook, so taking the mutex
proves nothing and only `_active` sees a `put` that is inside `on_put`. **The
count covers the hook and not the function body**, including the second
`on_close` a straggling `put` performs. Four tier 1 negatives came with it —
`release_not_quiet_pool`, `release_during_on_put`, `release_during_on_close`,
`release_with_straggler_put` — and what the added lock in `Pool.get` costs is
measured in the log's 3TK-54 entry.

**State: fixed. Mailbox 3TK-53, pool 3TK-54, both 2026-08-28; row closed by
3TK-55 the same day.** What is not written is `Part 11.12` of the shared
specification, which is 3TK-52's and binds four ports — it is not part of this
row.

## After a fix

**All the numbers below were re-measured on 2026-08-30, by 3TK-56, after `P6`
was built.**
The one missing descriptor sentence is the pre-existing `inner.c3` module
summary and is not new. `ref` moved 365 to 366 with `take()`'s two new
sentences in the decisions entry. `3tk/src` is unchanged at 125 — `take()`'s
doc block does not say *item*.

**Every mechanical item touches `3tk/src`, so the doc loop is owed.**
`ref/3tk-doc-loop-003.md` is the procedure; `check-doc-loop.sh` says whether it
is still owed.

**`ref/3tk-decisions-005.md` is the current one**, and `-003` is in `backup/`.
`P6`'s entry is in it, under `pool.c3` and `queue.c3`; `P7` closed without one.

**The numbers to re-measure**, all true on 2026-08-30 after 3TK-56:

```
./run-builds.sh        # four builds green, 87 checks, 92 tests per build, 0 failures
./check-doc-loop.sh    # 0 differing blocks, 457 sentences, 456 found, 1 missing, 0 banned
./run-sanitizers.sh    # 3 passed, 0 failed — thread on two builds, address on one
grep -roiwE 'items?' 3tk/src ref        # 125 and 366
```

**`run-sanitizers.sh` joined the list here** because the lifetime fix is a
concurrency change and a green `run-builds.sh` does not speak for it. **A skip is
not a pass**: the script exits 2 when its compiler is missing.
