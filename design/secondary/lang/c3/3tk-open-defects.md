# 3tk — open defects

**The working list for fixing the port.** Ten items — **six fixed, one open,
two closed, one deferred**. One table, one section each: where it is, what is wrong, what the
fix is, how to know it worked, and what state it is in.

**Everything known about the port is on this list, including what is not being
worked on.** A closed item and a deferred one stay in the table with their state,
so nothing has to be remembered from prose or found in another file.

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

**Line numbers were printed live on 2026-08-27**, after the `2DO` comments went
into `mailbox.c3` and `pool.c3`. **The numbers in the two review files are older
than those comments and are off by five in `mailbox.c3` and six in `pool.c3`
below the insertion points.** The numbers here are the good ones. Re-print
before trusting them again — every fix moves them.

## The list

| # | Where | What | Fix is | State |
|---|---|---|---|---|
| **P2** | was `managed.c3:69` | A dead duplicate of a live macro | Mechanical | **FIXED 2026-08-27** |
| **P1** | `inner.c3:186` | Two allocator fields: takes the last, silently | Mechanical | **FIXED 2026-08-27** |
| **P3** | `mailbox.c3:284`, `:329` | A stated precondition nothing enforces | Mechanical | **FIXED 2026-08-27** |
| **P4** | was `mailbox.c3:265`, `pool.c3:376` | A branch that can never be taken | Mechanical, touches a MUST | **FIXED 2026-08-27** |
| **W1** | `pool.c3:384` | The contract describes a case it does not have | Wording | **FIXED 2026-08-27** |
| **W2** | `pool.c3:60` | The rule is stated, the cost of breaking it is not | Wording | **FIXED 2026-08-27** |
| **P6** | `pool.c3:434`, `:492` | The pool can lose items and never know | **Needs your decision** | **open, third site ruled 2026-08-27** |
| **P7** | `mailbox.c3:257`, `pool.c3:370` | A branch that can never be taken, kept with its reason | Comment only | **CLOSED 2026-08-27** |
| **P5** | `pool.c3:325`, `:458` | The hook identity checks leave a fast build | Nothing — it split in two | CLOSED 2026-08-26 |
| **Q5** | `mailbox.c3:106`, `pool.c3:231` | A release racing a call still in flight | Ruled: the port will enforce it | DEFERRED 2026-08-27 |

**Six of the ten are done, on 2026-08-27, in one stage.** Every mechanical and
wording item is fixed and verified: four builds green, 67 checks (63 before,
plus the new compile-time negative once per build), 87 tests, 0 failures; the
doc loop 0 differing blocks and 0 banned words.

**One remains open, and it is waiting on you.** `P6` needs one small ruling
before code can be written. The ruling is stated in the section.

**`P7` no longer needs one.** Reading `std::thread` showed the fault it warned
about cannot occur. The branch is dead, it stays, and a plain `//` comment at
each line says why. Its section carries the evidence.

**The ones that were never open are here for a reason.** `P5` and `P7` were
real findings and neither survived as one — its section says why, so nobody re-raises it.
`Q5` is real, is ruled, and is simply not scheduled.

## Order

Only the open and deferred items have an order. The fixed ones are done.

**Runs now, waiting on nothing.**

- Nothing. The close-hook wording fix ran on 2026-08-27 —
  [3tk-on-close-policy-001.md](3tk-on-close-policy-001.md) is its record.

**Waiting on you.**

- `P6` — one ruling, three answers, written out in its section. INTR 1 ranked it
  High, and it is the last of the three it put there.

**Waiting on a stage that is not scheduled.**

- `Q5` — ruled 2026-08-27, built by
  [3tk-release-while-busy-001.md](3tk-release-while-busy-001.md).

**The dependency that is not obvious.**

- `P6`'s option 1 — count what was handed over, count what came back — needs
  `Q5`'s stage first. A count means nothing until there is a moment when no
  further `on_close` can arrive. `Part 12.2` lets a late put call the hook again
  and names no end point. `Q5`'s release-waits-for-zero is that end point.
  Options 2 and 3 do not need it, and either would put `P6` in front of
  everything else here.

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

## P2 — a dead duplicate of a live macro

**Where.** `managed.c3:69`, `macro usz required_alloc_offset($Type)`, inside
`module mtk::managed`. The live one is `inner.c3:195`.

**What is wrong.** The same body exists twice. Both call sites reach the one in
`inner.c3`, by its qualified name:

```
managed.c3:35:    ... + mtk::inner::required_alloc_offset($Type)) = a;
managed.c3:55:    ... + mtk::inner::required_alloc_offset($Type));
```

Nothing anywhere names `mtk::managed::required_alloc_offset`, and nothing uses
the unqualified form. **The copy has no reader.** It is not a compile error;
both modules are in scope.

The danger is `P1`. `managed.c3` is where someone looking for allocator
discovery goes, so the dead copy is the one they will read and edit. A rule added
to it compiles clean, passes every build, and changes nothing.

**The fix.** Delete `managed.c3:69` and its body. Leave `inner.c3:195` alone.

**How to know it worked.** `./run-builds.sh` — four builds green, 63 checks.
`negative/nocompile_managed_no_allocator.c3` must still be refused with a message
naming `mtk::helper`; that message comes from the surviving macro's `$assert`.

**State: FIXED 2026-08-27.** The macro and its doc block are gone from
`managed.c3`; `inner.c3:186` is the only declaration. Verified by the build.

## P1 — two allocator fields, and it takes the last

**Where.** `inner.c3:195`.

**What is wrong.** It walks the outer's members and overwrites on every match:

```c3
$foreach $m : $Type::members:
    $if $m.type == Allocator:
        $off = $m.offset;
    $endif
$endforeach
```

Its sibling twenty-five lines above, `inner_offset` at `inner.c3:170`, **counts**,
and refuses a type with two `Inner` fields with a message naming the type. Two
compile-time discovery macros in one file, both answering *where is the field*,
and only one has a rule.

An outer with two allocators compiles. Which one `create` writes and `release`
reads is decided by declaration order and stated nowhere. Nothing breaks until
the two allocators are not interchangeable — and then memory is returned to the
wrong one.

**The fix.** Give it `inner_offset`'s shape: count the matches, and `$assert` on
more than one with a message that names the type. Mirror the existing wording so
the two macros read alike.

Add `negative/nocompile_managed_two_allocators.c3`, alongside
`nocompile_two_inners.c3`, and add it to the nocompile list in `run-builds.sh`.

**How to know it worked.** The new negative is **refused at compile time** and
the message names the offending type — the same assertion
`nocompile_two_inners` makes. Check count goes 63 to 64. Four builds green.

**State: FIXED 2026-08-27.** It counts now, and refuses a second `Allocator`
with a message naming the type. `negative/nocompile_managed_two_allocators.c3`
is refused in all four modes — the check count went 63 to 67, one per mode.

## P3 — a stated precondition nothing enforces

**Where.** `mailbox.c3:277` and `mailbox.c3:323`, the `@param out` lines of
`receive_all` (`:281`) and `close` (`:326`).

**What is wrong.** Both say what the queue must be:

```
:277  @param out : "an empty queue; every queued item is moved onto it, in receive order"
:323  @param out : "an empty queue; the remainder is moved onto it, in receive order"
```

Neither checks it. Both call `append_queue`, which appends and neither requires
nor restores an empty destination.

Everywhere else, an acquisition asserts. `Mailbox.poll`, `Mailbox.receive`,
`Pool.get`, `Pool.get_wait` and `managed::create` all open with that check, and
`Slot.fill` refuses to overwrite on its own account. **Two acquisitions take a
queue instead of a Slot, and those two check nothing.**

No crash results — a caller who reuses a queue gets a silently longer chain, with
items the mailbox never held at the front and no way to tell where the boundary
was. `close` is the sharper of the two, because those items are the caller's to
release and the queue is the only record of which ones they are.

**The fix.** `mtk::@check(out.is_empty(), ...)` at the top of both, with a
message naming the call. **No paired `if` is needed** — unlike the `Part 8.9`
sites, a non-empty destination in a fast build appends, which is defined
behaviour and not a hole.

**How to know it worked.** Four builds green, 63 checks. The `@check` count in
the file rises by two. **Optional and not required by this item:** a tier-2
negative that passes a non-empty queue.

**State: FIXED 2026-08-27.** Both open with `mtk::@check(out.is_empty(), ...)`,
naming the call. No paired `if`, for the reason above.

## P4 — a branch that can never be taken

**Where.** `mailbox.c3:265`, in the timeout branch of `receive`:

```c3
if (self.has_queued()) self._cv.signal();
```

and `pool.c3:376`, the same shape in `get_wait`:

```c3
if (!b.free.is_empty()) self._cv.signal();
```

**What is wrong.** Both conditions are provably false where they are evaluated.
Reaching them means the `dequeue`/`pop` two lines above returned null;
`pop_front` returns null exactly when the queue is empty, and `is_empty` is
`count == 0` — they agree by construction. The mutex is held across the whole
branch, so nothing arrives in between. `InnerStack` is the same with one stack.

**The MUST it touches, and this is why the fix is not just a deletion.** Both
carry the marker `Part 2.6`, and `Part 2.6` is a MUST in the shared
specification:

> - A waiter that leaves on timeout, or on interruption, checks the container
>   before returning.
> - If the container is not empty, the leaver signals or broadcasts.

**The port satisfies it, and by a stronger route than the branch.** A waiter that
finds the container non-empty does not leave at all — the `dequeue` two lines
above returns the item and the call returns success rather than `TIMEOUT`. The
wakeup a timed-out waiter might have consumed is one it consumed by taking the
item. So deleting the branch does not break `Part 2.6`; it removes a second,
vacuous statement of it.

**The precedent is already in the decisions file**, at `pool.c3`'s get loop:

> **No `if (b)` guard on either pop in the loop.** The early return made `b`
> non-null, and **a live-looking branch that cannot be taken is a reader's
> trap.** `A3`.

**The fix.** Delete both branches and both `Part 2.6` markers. **Add a decisions
entry** recording that `Part 2.6` is satisfied by the dequeue that precedes the
timeout return, and citing `A3` for why the vacuous branch is removed rather than
kept. Without that entry the port looks like it dropped a MUST.

**How to know it worked.** Four builds green, 63 checks, 87 tests. **The
decisions file must gain the entry in the same stage** — it becomes `-003`.

**State: FIXED 2026-08-27.** Both branches deleted with their branch-level
markers. The FUNCTION-level `Part 2.6` markers stand — the port still owes and
still keeps the MUST, by the dequeue. The decisions entry is in
`ref/3tk-decisions-003.md`.

## W1 — the contract describes a case it does not have

**Where.** `pool.c3:387`, in `Pool.put`'s block:

```
 Cleared: the pool took it.
 Unchanged: it was refused, and you still have the item.
```

**What is wrong.** *Unchanged* is reachable on four paths — an empty Slot, the
fast closed read, the closed flag under the mutex, an unknown identity. **Every
one is before the hook runs.** The sentence reads as though a hook may refuse the
item and hand it back, and no such outcome exists: the four `on_put` outcomes at
`pool.c3:72-75` are free it, keep it, keep it after a reset, or swap it. Taking
the item before the answer is known is the ruled design, ruled 2026-08-24.

Three lines below, `pool.c3:390` already says the true thing — *A close that
arrives while `on_put` runs is handled. The item goes to `on_close`, and your
Slot stays cleared* — which is what made the block look self-contradictory to two
reviewers.

**The fix.** Reword the *unchanged* sentence so refusal is what the **pool** does
before it asks anyone. `Part 9.4`'s general law — cleared means taken, unchanged
means not — stays untouched; only `Pool.put`'s gloss on it overreaches.

**How to know it worked.** The doc loop: `check-doc-loop.sh` must return **0
differing blocks**, which means the matching sentence in
`ref/3tk-reference-003.md` was changed with it. The sentence count moves.

**State: FIXED 2026-08-27.** *Unchanged* now says the pool refused it before
any hook ran. `ref/3tk-reference-003.md` changed with it; 0 differing blocks.

## W2 — the rule is stated, the cost of breaking it is not

**Where.** `pool.c3:60`, in the `on_get` hook contract:

```
 An item of a different identity is a defect of your application.
```

**What is wrong.** Nothing — as far as it goes. `pool.c3:324` checks it with
`mtk::@check`, and INTR 2's `Q4` confirmed that tier is correct: `Part 11.12`
calls its own precondition *the one the toolkit refuses to soften*, and
`Part 12.2` files a hook's wrong identity as an ordinary defect of the
application.

**What is missing is the consequence.** `@check` compiles out under `--safe=no`.
A hook that returns the wrong identity in a fast build gives the caller a
handle whose recorded type is not the type asked for, and every crossing
downstream — `from_handle`, `is_mine`, `must_from_handle` — then answers
*correctly about the wrong type*. The port's one guarantee, defeated with no
abort and no trace. The contract says the hook must not do it; it does not say
that the port stops being able to notice.

**The fix.** One sentence in the same block, saying the check is a checking-build
check and that a fast build cannot catch it.

**How to know it worked.** Doc loop clean, 0 differing blocks. Banned words 0.

**State: FIXED 2026-08-27.** One sentence added: the check is a checking-build
check and a fast build cannot catch it. Reference and decisions changed with it.

## P6 — the pool can lose items and never know

**Three sites.**

```
pool.c3:434     the close hook, called with what was left after a race
pool.c3:492     the close hook, called with everything the pool held
pool.c3:458-460 one item with an identity the pool does not recognize  -- RULED 2026-08-27
```

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

**State: open, waiting on your decision.**

## P7 — closed, the claim did not survive reading the standard library

**Two sites.**

```c3
mailbox.c3:257   if (f != thread::WAIT_TIMEOUT) return f~; // dead today: ...
pool.c3:370      if (f != thread::WAIT_TIMEOUT) return f~; // dead today: ...
```

**What was claimed.** `Mailbox.receive` and `Pool.get_wait` wait with a deadline.
The wait can fail. The code passes that failure straight out. `f` belongs to
`std::thread`, not to this port, and neither `@return?` line names it. So a
caller who handles the listed outcomes and treats the rest as impossible is
following the documentation and is wrong.

**That claim needs one thing to be true.** `wait_until` has to be able to fail
with something other than `thread::WAIT_TIMEOUT`. If it cannot, the `if` is never
true, `return f~` never runs, and no unlisted fault ever reaches a caller.

**It cannot.** `thread.c3:102` is a macro and forwards. The real body is
`os/thread_posix.c3:179`:

```c3
switch (posix::pthread_cond_timedwait(cond, &mtx.mutex, &&time.to_timespec()))
{
    case ETIMEDOUT: return thread::WAIT_TIMEOUT~;
    case OK:        return;
    default:
        $if(env::OPENBSD): return thread::WAIT_TIMEOUT~;
        $else             abort("pthread_cond_timedwait failed, invalid value");
        $endif
}
```

**Three exits, and only three.** Timed out, so `WAIT_TIMEOUT`. Woke normally, so
success and no fault. Anything else, so `abort` inside the standard library —
control never comes back, `f` is never assigned, line 257 is never reached.

**No fourth exit.** OpenBSD folds even its odd case into `WAIT_TIMEOUT`. The
win32 file behaves the same way: every `?` exit in its condition-variable code is
`thread::WAIT_TIMEOUT~`, at `:329`, `:341` and `:348`.

**So `f` is only ever `WAIT_TIMEOUT`.** The comparison is always false. The
branch is dead.

**The `@return?` lines were never incomplete.** The sets they declare really are
closed. There is no missing eighth fault, so there was nothing to rule on — no
`mtk::WAIT_FAILED`, no folding into `TIMEOUT`.

### What was done, 2026-08-27

**The branch stays. A plain `//` comment was added on the right of each line**,
saying it is dead today and kept for a future wait failure.

**Why keep it rather than write it out.** Deleting it makes the port lean on a
promise that lives in another library's operating-system layer. The promise holds
today. If `wait_until` ever grows a second fault, a port without the guard would
quietly report it as a timeout. The guard costs a comparison that folds away and
buys the day that changes.

**Why a `//` comment and not a `<* *>` block.** The doc loop reads only `<* *>`
text. A `//` line is invisible to it, so this owes no reference change and no
`-004`. Verified after the edit: four builds green, 67 checks, 87 tests, 0
failures; doc loop 0 differing blocks, 0 banned words.

**Not the same as P4.** `P4` was a dead branch removed. This one is a dead branch
kept, deliberately, with the reason written at the line.

### One thing on the record, and it is a different subject

**That `abort` is a tier-1 site.** A `pthread_cond_timedwait` failure kills the
process instead of returning through `void?`. The port did not add the site and
cannot avoid it, so **`Q4` is untouched** — `Q4` governs sites the port adds.
Noted here only so nobody discovers it later and reads it as a new finding.

**State: closed 2026-08-27. Nothing owed.**

## P5 — closed, and here so it is not re-raised

**Where.** `pool.c3:324` and `pool.c3:459`, the two hook identity checks. Both
are `mtk::@check`, which expands to nothing under `--safe=no`.

**What was claimed.** INTR 1 ranked this High: unlike the rest of what `@check`
guards, these two do not guard a precondition the *caller* owes. They guard what
the port gives **back**, against the *hook*. So the type-identity guarantee — the
one thing the port exists to provide — is defeated in a fast build with no abort
and no trace.

**Why it is closed.** INTR 2's `Q4` asked whether they should be promoted to the
tier that survives a fast build, and **the specification refuses it.**
`Part 11.12` has the port's only two such sites and calls its own precondition
*the one precondition the toolkit refuses to soften*; `Part 12.2` files a hook's
wrong identity as *a defect of the application*, the same words used for a
caller's defect, with no clause promoting it. Adding a third site would be a
change to the shared specification, not a fix to C3.

**So the checks stay as they are, and the finding split in two:**

- its first half — that the contract never states what a fast build cannot
  catch — became **`W2`**;
- its second half, `pool.c3:459` dropping an item on the floor, became the third
  site of **`P6`**. That site was ruled on 2026-08-27: the guard is written out,
  so the fast build fails at the line instead of dropping the item.

**Nothing to do. State: closed 2026-08-26 by INTR 2.**

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

**Where.** `Mailbox.release` at `mailbox.c3:106` and `Pool.release` at
`pool.c3:230`. Both carry a `2DO` comment marking it.

**What is wrong.** Both require the mailbox or the pool to be **closed**, and enforce it
hard — it aborts in every build mode. **Closed is not quiet.** `Part 12.3` MUST
forbids holding the mutex across a call into application code, so `Pool.put`
unlocks, runs `on_put`, and relocks at `pool.c3:424`. A close-and-release inside
that window makes the relock touch freed memory. `Mailbox` has no hook and so no
window of its own, but the same exposure: any call in flight when a release runs
is using memory that release frees.

A caller who reads `Part 11.12`, closes, and then releases has obeyed every
clause the toolkit states, and can still land here.

**The ruling, 2026-08-27.** **The port will enforce it** — not a documented
caller precondition. The owner's reason: the client's code is unaffected either
way, so the port may as well keep the rule itself.

**It is not scheduled**, and the gap is expected to be long: the examples and the
pattern catalog do not exercise edge cases, so nothing downstream waits on it.

**Everything needed to run it is in
[3tk-release-while-busy-001.md](3tk-release-while-busy-001.md)** — why a counter
alone does not close the race, why `release` must wait rather than abort, what it
costs, the shared-specification clause it would make every port owe, and the
deterministic negative that proves it. **That file is the stage; this row is the
tracking.**

**State: deferred 2026-08-27. Not blocking anything.**

## After a fix

**All four numbers below were re-measured on 2026-08-27, after the six fixes.**
The one missing descriptor sentence is the pre-existing `inner.c3` module
summary and is not new. `ref` moved 360 to 365 because the reference and the
decisions each took on new sentences that say *item*; `3tk/src` did not move.

**Every mechanical item touches `3tk/src`, so the doc loop is owed.**
`ref/3tk-doc-loop-003.md` is the procedure; `check-doc-loop.sh` says whether it
is still owed.

**`ref/3tk-decisions-003.md` is the current one**, and `-002` is in `backup/`.
`P6` will add an entry when it is ruled; `P7` closed without one.

**The numbers to re-measure**, all true on 2026-08-27 after the close-hook
wording fix:

```
./run-builds.sh        # four builds green, 67 checks, 87 tests, 0 failures
./check-doc-loop.sh    # 0 differing blocks, 440 sentences, 439 found, 1 missing, 0 banned
grep -roiwE 'items?' 3tk/src ref        # 124 and 365
```
