# 3tk deviations (001) — the port measured against the specification

Stage 3TK-12 of [3tk-staging-plan-007.md](backup/3tk-staging-plan-007.md).

This document **recommends**. It rules nothing. It edits nothing. `3tk/src/`,
`3tk/test/`, `3tk/negative/` and `../common/` were read and not written.

## What this is

`../common/backup/matryoshka-specification-002.md` says of itself: *a port is written
from this file alone*. Since 3TK-11 ended, that claim is false for 3tk — the
core redesign replaced the mechanism 002 describes and 002 was not cut again.
This is the measurement of the difference, Part by Part, against the code as
3TK-11 left it.

**The code is the authority.** Where the code and any document disagree, what is
recorded here is the code.

## Inputs

- `../common/backup/matryoshka-specification-002.md`, Parts 1 to 22, all of it.
- `3tk/src/` — eight files, as 3TK-11 left them.
- [3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md) — R1 to
  R15, and §8.1 as a forecast to be checked rather than copied.
- [3tk-core-redesign-notes-001.md](3tk-core-redesign-notes-001.md) — 3TK-11's
  three corrections and its Part 18 re-walk.
- [3tk-porting-proposal-004.md](3tk-porting-proposal-004.md) — D1 to D16.

## Verification, run at the start of this stage

```
3tk/run-builds.sh        passed 59, failed 0, all four builds green
3tk/run-sanitizers.sh    passed 3, failed 0, sanitizers clean
```

Nothing was touched, so this is the trivial result the plan expected. It is
recorded because a stage that measures code should say which code it measured:
c3c 0.8.3, linux-x64, 85 tests over four builds.

**Re-run twice more the same day, as the owner ruled on what the audit found.**

| After | builds | sanitizers | tests |
|---|---|---|---|
| P6 — `InnerStack.push_slot` and its test deleted | 59 / 0 | 3 / 0 | 84 |
| P1 — the late close fixed, one test added | 59 / 0 | 3 / 0 | 85 |

**The P1 test was checked both ways.** With the fix removed it fails on
`Violated assert 'p.count_of(OWNED_TYPE) == 0': invariant 34: an item is in a
closed pool`. The audit found P1 by reading, so a test that passed either way
would have proved nothing — the failure mode `run-builds.sh` already records for
`release_open_pool`.

---

# 1. The table — every Part, with a verdict

Four verdicts, as the plan defines them: **C** conforms; **S** deviates and the
*specification* should move; **P** deviates and the *port* should move; **N/A**
excluded, or a MAY the port skipped.

| Part | Marking | Verdict | Finding | Scope |
|---|---|---|---|---|
| 1.1 What it is | MUST | C | | |
| 1.2 What it is not | MUST | C | | |
| 1.3 The absent type | MUST | C | no `Master` is declared anywhere in `3tk/src/` | |
| 2.1 Plain threads | MUST | C | | |
| 2.2 Two primitives | MUST | C | mutex, `wait_until`, plus 15.4's permitted atomic | |
| 2.3 Blocking with a timeout | MUST | C | `receive`, `get_wait` take a `Duration`; `poll` never waits | |
| 2.4 A wakeup carries no meaning | MUST | C | | |
| 2.5 The deadline is anchored once | MUST | C | `mailbox.c3:294`, `pool.c3:400` | |
| 2.6 Signal hand-off | MUST | P | **P4** — the pool's leaver signals on one bucket, over a shared condition variable | 3tk-only |
| 2.7 Many producers, many consumers | MUST | C | | |
| 2.8 Order among receivers | MUST | C | nothing promises fairness | |
| 2.9 Interruption | SHOULD | N/A | dropped by D9, with the reason the SHOULD's own last bullet permits | |
| 2.10 Cleanup paths run to the end | MUST where 2.9 applies | N/A | 2.9 does not apply. `Pool.put` still cannot fail | |
| 3.1 Long-lived heap objects | MUST | C | | |
| 3.2 Why the address is fixed | MUST | C | | |
| 3.3 Items versus participants | SHOULD | C | | |
| 4.1 Intrusion | MUST | C | | |
| 4.2 The inner | MUST | S | **V1** — *two fields, a previous and a next* | every port |
| 4.3 The field may sit anywhere | SHOULD | C | `inner.c3:336`, any offset | |
| 4.4 One inner per outer | MUST | C | checked at build time, `inner.c3:360` | |
| 5.1 Identity | MUST | C | native `typeid` | |
| 5.2 What it is not | MUST | C | | |
| 5.3 Spelling is free | SHOULD | C | the ztk mutable-byte paragraph is a *ztk* line and reads correctly | |
| 5.4 Stored, not computed | MUST | C | `inner.c3:77` | |
| 5.5 The uninitialized identity | SHOULD | C | a zeroed `typeid` matches no type; `helper.c3:76` refuses it | |
| 6.1 Self-identification | MUST | C | | |
| 6.2 Where the check runs | MUST | C | all three sites exist | |
| 6.3 Two forms of the crossing | MUST | C | `from_handle` / `must_from_handle`, and `h.to` / `h.as` — H5, H0 | |
| 6.4 What it makes safe | background | C | | |
| 6.5 Dispatch on the identity | SHOULD | P | **P5** — the port ships no dispatch table and no document says why | 3tk-only, with an every-port clarification |
| 7.1 The per-type helper | SHOULD | **S** | **V19** — the Part states ztk's mechanism, not the design's promise | every port |
| 7.2 What the helper contains | MUST | C | all members present, `helper.c3`, as macros over `$Type` — H0 | |
| 7.3 Creation and release in the helper | SHOULD | C | D10, **two modules** — `mtk::helper` and `mtk::managed`, neither generic since H0b. Part 7.3's *a separate name* | |
| 7.4 Validation of the type | SHOULD | C | `inner.c3:359-360`, `:385`, at build time | |
| 7.5 The border, named once | MUST | C | enforced and tested by `run-builds.sh` | |
| 8.1 The rule | MUST | S | **V2** — *a doubly-linked list* | every port |
| 8.2 The surface | SHOULD | S+P | **V3** — sixteen operations become **eleven** across two containers; **P6** — the twelfth had no caller but its own test and was deleted 2026-08-24 | every port + 3tk-only |
| 8.3 The list speaks in handles | MUST | C | | |
| 8.4 The walk | SHOULD | C | on the queue; the stack's omission has a written reason | |
| 8.5 The checks live here | MUST | C | and it now applies to two layers | |
| 8.6 The double check on insert | SHOULD | S | **V4** — deleted; one exact check replaces two partial ones | every port |
| 8.7 The link test and its blind spot | MUST | S | **V5** — rewritten; the link test is exact | every port |
| 8.8 The repair | MUST | C | `inner.c3:277`, called by both removals | |
| 8.9 Moving a list onto itself | SHOULD | C | the pair survives, narrowed to the queue, `queue.c3:219-220` | |
| 8.10 Bridging to the language's own list | MAY | N/A | C3 has no intrusive list; there is no other side | |
| 8.11 Test access to the raw list | MAY | N/A | not needed | |
| 9.1 The Slot | MUST | C | | |
| 9.2 The six rules | MUST | C | all six, and rule 1 is written once, `inner.c3:329` | |
| 9.3 The signature shape | MUST | C | | |
| 9.4 The Slot is the answer | MUST | C | `Pool.put` returns nothing | |
| 9.5 The one exception | MAY | N/A | C3 has no select mechanism | |
| 9.6 One place at a time | MUST | C | better guarded than 002 assumed | |
| 9.7 Cleanup before acquisition | SHOULD | C | `defer`, used at every test site | |
| 9.8 Creation is an acquisition | SHOULD | C | `owned.c3:59` | |
| 9.9 The Slot's own type | MAY | C | D5, distinct, with the five readers `inner.c3:292-331` | |
| 10.1 Deliberate synonyms | SHOULD | C | | |
| 10.2 Why not collapsed | background | C | | |
| 10.3 The word "object" | SHOULD | C | | |
| 11.1 They are themselves items | MUST | C | `mailbox.c3:43`, `pool.c3:159` | |
| 11.2 One internal base | SHOULD | S | **V6** — the port repeats the five members and refuses a shared type | every port |
| 11.3 The mailbox | MUST | S | **V7** — the two anchor bullets. The three ordering guarantees stay | every port |
| 11.4 Out-of-band is one level | MAY | C | two queues are one level with a cleaner home | |
| 11.5 Waking every waiter | SHOULD | C | `mailbox.c3:386-387`, the generation counter | |
| 11.6 Give-back, mailbox side | MUST | C | including invariant 34 | |
| 11.7 The pool | MUST | S | **V8** — *one free list per identity*; **put a list** is deleted | every port |
| 11.8 Give-back, pool side | MUST | S+P | **V9** the list-put clause and the restored-order warning; **P1** the port loses items to a concurrent close | every port + 3tk-only |
| 11.9 Waiting get never creates | MUST | C | `pool.c3:396-460`, no hook on the path | |
| 11.10 No sequence guarantee | MUST | C | and R11 depends on it | |
| 11.11 Hidden implementation | SHOULD | S | **V7b** — D1 rejects hiding on cost; 002 states C3-style privacy as reachable | 3tk-only, recorded not fixed |
| 11.12 Close before release | MUST | C | two tier 1 sites, `mailbox.c3:146`, `pool.c3:275` | |
| 12.1 Hooks as an interface | MUST | C | a C3 `interface`; `ctx` disappears | |
| 12.2 The three hooks | MUST | S | **V10** — *list* on the give-back surfaces, and **V11**, the missing re-check clause | every port |
| 12.3 Hook concurrency | MUST | S | **V11** — nothing says what the pool re-reads when a hook returns. This is what P1 falls through | every port |
| 12.4 The count is a hint | MUST | C | `pool.c3:354`, `:477` | |
| 12.5 The extra list on put | SHOULD | C | present, and it is the **only** thing in the port that needs a Slot-shaped insert — §2, P6 | |
| 13.1 Allocators | SHOULD | C | D3; no release call takes one | |
| 13.2 Why | background | C | | |
| 13.3 The state of ztk | background | C | the port did what 13.3's last bullet asks | |
| 13.4 Application items | open | C | answered per type, `helper` against `owned` | |
| 13.5 No explicit allocator | SHOULD | N/A | C3 has one | |
| 14.1 One holder at a time | MUST | C | | |
| 14.2 The transfer orders memory | MUST | C | | |
| 14.3 The transfer circuit | SHOULD | C | | |
| 15.1 What the toolkit locks | MUST | C | | |
| 15.2 What it does not lock | MUST | C | no path takes two mutexes | |
| 15.3 The closed flag | MUST | C | | |
| 15.4 The pre-lock check | SHOULD | C | D16, kept with the re-check at every site | |
| 15.5 Asserts versus outcomes | SHOULD | C | D6's three tiers | |
| 16 The excluded surface | EXCLUDED | C | all twelve rows absent | |
| 17.1 One is required | MUST | C | | |
| 17.2 Two are optional | SHOULD | C | enforced by submodules and tested, three checks | |
| 17.3 Why that matters | background | C | | |
| 18 The invariants | — | S | **V12** — row 16 retired and replaced, row 13 strengthened | every port |
| 19.1 Mailbox outcomes | — | S+P | **V13** the `interrupted` outcome; **P3** an outcome outside the set can escape | every port + 3tk-only |
| 19.2 Pool outcomes | — | S | **V14** — the *put a list* row. §8.1 said Part 19 was untouched | every port |
| 19.3 The asymmetry in get | MUST | P | **P2** — NOT_AVAILABLE is returned from every mode on an unknown identity. **FIXED 2026-08-24, stage 3TK-15**: the port reports `UNKNOWN_IDENTITY` | 3tk-only |
| 19.4 The list layer | — | C | no fault type in `queue.c3` or `stack.c3` | |
| 20 What each port decides | open | S | **V15** — decisions 4 and 10 do not survive Part 8.6's deletion | every port |
| 21 The capability questionnaire | — | S | **V16** — Q11 points at Part 8.6 | every port |
| 22 The porting order | — | S | **V17** — step 5, *the list, with both insert checks* | every port |

**Counts.** 22 Parts, 96 numbered elements. **Conforms 74. Specification should
move 17. Port should move 6. Not applicable 8.** Three elements — 8.2, 11.8 and
19.1 — carry one of each, which is why the four columns sum past 96.

---

# 2. The port should move — five findings

The plan says a stage that finds none of these has probably not looked. These
are the six, most serious first. **None is a decision this stage takes.**

## P1 — `Pool.put` loses items to a concurrent close. Invariant 34.

> **RULED AND FIXED, 2026-08-24, after this document was first written.** The
> owner ruled the mechanism — *re-read the closed flag after the hook* — and then
> ruled the destination the mechanism left open: **the stragglers go to
> `on_close`, and a second call to the close hook is acceptable.** `pool.c3`'s
> `put` carries it, `t_concurrency.c3`'s
> `a_close_during_the_put_hook_loses_nothing` holds the window open
> deterministically and fails on invariant 34 without the fix, and all four
> builds and all three sanitizer runs are green. **V11 below is no longer an
> undetermined row**: 003 writes the rule this implements.

**Part 11.8 MUST, and Part 12.3. `pool.c3:401-440`, against `pool.c3:472-504`.**
Caused by neither an R nor a D: the shape predates the redesign and **it
drifted**.

`Pool.put` takes the item from the caller under the lock, unlocks for the hook —
which Part 12.3 MUST requires — and then relocks and stores whatever the hook
kept:

```c3
    Slot mine;
    mine.fill(slot.take());          // pool.c3:422 — the caller's Slot is now empty

    self._mu.unlock();               // pool.c3:426 — Part 12.3
    self._hooks.on_put(in_pool, &mine, &extra);
    self._mu.lock();                 // pool.c3:428 — and `_closed` is NOT re-read

    self.take_back(&mine);           // pool.c3:432
    while (Handle e = extra.pop_front()) self.take_back_handle(e);
```

Interleave `Pool.close` between lines 426 and 428. Close sets both flags and
drains every bucket into `remaining` — `pool.c3:478-497` — unlocks, and hands
`remaining` to `on_close`. `put` then relocks and pushes its item into a bucket
of a closed and already-drained pool.

The item is **stranded**. It is not with the caller: `slot.take()` at line 422
emptied the caller's Slot, and `put` returns nothing, so Part 9.4's rule —
*cleared means kept* — tells the caller truthfully that the pool has it. It is
not with the close hook: the hook ran before the push. Nobody releases it.

Three MUSTs are broken by the one window:

- **Invariant 34, Part 11.8** — *a closed pool is empty*. It is not.
- **Part 11.8** — *a pool's close collects everything and passes it to the
  hook*. It collected everything that existed at that instant.
- **Part 11.6's shape read across** — *every item goes back to somebody*.

`Mailbox` has no equivalent: `send` holds the mutex from the closed test to the
enqueue, `mailbox.c3:205-212`, so nothing runs between them.

**No test provokes it and none easily could** — it is the same class as the
missed leaver's signal that 3TK-11's notes recorded as untested at §2 of *the
four things the stage had to get right*.

**Two possible repairs. The audit did not choose; the owner did, and it was
the first.** Both are small.

1. **Re-read `_closed` after the relock.** If it is set, the items `put` is
   holding — `mine` and every member of `extra` — go somewhere. There is no
   caller Slot to give them back to, so the only two candidates are a second
   call to `on_close` with just those items, which Part 12.2's *called once*
   forbids, or returning them to the caller, which cannot carry `extra`: those
   parts the caller never had, so there is no Slot for them and they leak
   instead. **Neither is available without a specification change**, which is
   why this finding has a specification half — V11.

   > **TAKEN, 2026-08-24, and the owner ruled both halves.** The mechanism is
   > the re-read. The destination is `on_close`, with Part 12.2's *called once*
   > **deliberately bent**: what the pool holds when it discovers it is closed
   > goes to the close hook, so a hook may see a second call carrying
   > stragglers and **must not destroy its own state on the first**. The reason
   > is the plain one — two calls to cleanup beats leaked parts. Invariant 34
   > and Part 11.8 both hold: nothing lands in a bucket after the flag is set,
   > and nothing comes back to the caller.
2. **Hold a claim across the hook.** Close waits for in-flight puts, or `put`
   registers itself so close drains after it. That is a mechanism decision and it
   costs a counter. **Not taken.**

**Scope: 3tk-only for the defect; every-port for the rule that has no wording —
V11.** The rule 002 never wrote is *what the pool does with a hook's result when
the pool closed while the hook ran*. dtk and otk will write this same code from
the same silence.

## P2 — NOT_AVAILABLE escapes from every mode. Part 19.3 MUST.

> **RULED AND FIXED, 2026-08-24, after this document was first written.** The
> owner defaulted assumption **A3** — *a distinct outcome in the port* — and
> **stage 3TK-15 built it.** `Pool.get` reports `mtk::UNKNOWN_IDENTITY` for an
> identity the pool was not created with, from all three modes;
> `pool.c3:333-335`. It is **deliberately not a Part 19 outcome**: Part 11.7
> makes an identity outside the pool's set a caller defect, not a runtime
> condition. **Part 19.3 keeps its MUST and 004 is untouched** — this was a
> **port** defect and it moved the port. `get_wait` took the same fault at
> `pool.c3:415-417`, where the old fallthrough merely timed out and was
> therefore inside Part 19.2's set; 3TK-15 changed it as a quality change so
> that the two gets do not disagree about one mistake.
> `negative/pool_unknown_identity.c3` holds all four call shapes and was
> measured to fail with the fix removed. **The finding below is left as it was
> measured**, P6's precedent: the evidence is what makes the fix safe to read
> later. **The three answers it says the audit takes none of — the first one
> was taken.**

**`pool.c3:288-290`.** Neither an R nor a D; it drifted from D6's tier design.

```c3
    PoolBucket* b = self.bucket_for(want);
    mtk::@check(b != null, "Pool.get for an identity the pool was not created with");
    if (!b) { self._mu.unlock(); return mtk::NOT_AVAILABLE~; }
```

Part 19.3 MUST: *not-available comes only from the available-only mode*. Here it
comes from all three, including NEW_ONLY, whenever the identity is not one the
pool was created with. The `@check` above catches it in a checking build; in
`--safe=no` the check is nothing at all — D6, and 3TK-11's own second
correction — so the fault is the observable behaviour of a fast build.

`get_wait` has the same shape at `pool.c3:359-360`, and there the fallthrough is
benign: `b` stays null, the loop finds nothing and the call times out, which is
inside Part 19.2's set for that operation.

**The port has three answers available** and the audit takes none: report a
distinct outcome, make the site tier 1 like `release`, or accept it and write
down that Part 19.3's *only* is a checking-build promise. **3tk-only.**

## P3 — an outcome outside Part 19's set can escape a waiting call.

**`mailbox.c3:312-314` and `pool.c3:430-432`.** From D7's wait loop; it drifted.

```c3
    if (catch f = self._cv.wait_until(&self._mu, deadline))
    {
        if (f != thread::WAIT_TIMEOUT) return f~;
```

`f~` returns the condition variable's own fault to the application, and Part 19
fixes the outcome set of every operation. A caller matching on
`mtk::CLOSED`, `mtk::TIMEOUT`, `mtk::WOKEN` meets a value from
`std::thread`'s `faultdef` instead.

**It is unreachable on the current backend, and that is the whole of its
severity.** `NativeConditionVariable.wait_until` on posix returns `WAIT_TIMEOUT`
or `OK` and calls `abort` on anything else —
`/home/g41797/dev/langs/c3/lib/std/threads/os/thread_posix.c3:179-194`. So the
line is dead code today. It is recorded because it is a *contract* statement
sitting in the port's two most-copied loops, and the next port will copy the
shape before it checks its own backend. **3tk-only.**

## P4 — the pool's leaver signals on one bucket, over a shared condition variable.

**Part 2.6 MUST. `pool.c3:436-439`.** From D7's loop; it drifted.

```c3
            h = b.free.pop();
            if (h) { slot.fill(h); return; }
            // Part 2.6: the leaver hands the signal on.
            if (!b.free.is_empty()) self._cv.signal();
            return mtk::TIMEOUT~;
```

**The block above is re-cut from today's code, 2026-08-25, and the finding is
unchanged by the re-cut.** As measured on 2026-08-24 the leaver sat inside an
`if (b)` guard; 3TK-15 deleted that guard as unreachable when it built
`UNKNOWN_IDENTITY`, which moved the lines without touching what they do. **The
defect is the `signal` on one bucket and it is still here.**

Part 2.6 says a leaver checks **the container** and signals if it is not empty.
The pool has one condition variable and *n* buckets. A waiter for identity A,
leaving on a timeout, does not signal when bucket B is non-empty; and the
`signal` it does send may wake a waiter for a third identity, which finds
nothing and sleeps again.

**Nothing is lost today**, and the reason is worth stating so a repair does not
get argued as a bug fix: every path that makes an item available — `Pool.put` at
`pool.c3:545` and `Pool.close` at `:606` — calls `broadcast`, not `signal`. No
signal is ever consumed by one waiter at another's expense, which is the exact
failure 2.6 exists to prevent.

**The mailbox is not in the same position and got it right**: `has_queued()`
reads *both* queues, `mailbox.c3:194-195`, and 3TK-11's notes name that as the
easiest line in the redesign to half-fix. The pool is the same line, half-fixed,
and it survives on `broadcast` rather than on being correct.

Smallest repair: `broadcast`, or a predicate over every bucket in the shape
`has_queued` uses. **3tk-only.**

## P5 — Part 6.5 is a skipped SHOULD with no written why.

**`3tk/src/` has no dispatch table.** Part 0: *a port that skips a SHOULD states
why*. D1 to D16 and R1 to R15 are silent on 6.5, and so are the toolkit,
container, sanitizer and redesign notes. `grep` over `3tk/src/` finds no
`dispatch` and no `handler`.

What exists is `t_identity.c3:129-151`, the heterogeneous walk that claims by
identity — Part 6.2's third crossing site, and §5.2 of the redesign proposal
calls it *Part 6.5's demonstration*. A demonstration in a test is not the
element, and a test is not where a port states a decision.

**The honest reading is that 6.5 describes something the application writes, not
something the toolkit ships** — it is the only SHOULD in Parts 4 to 10 with that
character, and the port's silence is the silence of a rule aimed elsewhere.
**Two halves: 3tk writes the sentence; 003 says whose element it is — V18.**

## P6 — `InnerStack.push_slot` has no caller but its own test, and §5.1's reason for both Slot inserts is half wrong.

> **RULED AND DONE, 2026-08-24, after this document was first written.** The
> owner read the measurement and deleted `InnerStack.push_slot` and
> `t_stack.c3`'s `push_from_a_slot`. The stack has **four** operations, and
> `stack.c3`'s header carries the reason. `InnerQueue.push_back_slot` stays, on
> the ground below. The finding is left as it was measured, because the evidence
> is what makes the deletion safe to read later.

**Part 8.2 SHOULD. `stack.c3:107-112`, `queue.c3:147-152`.** Added by R3/§5.1 —
it kept both; the reason it gave does not survive contact with the code.

§5.1's row reads: *Add at the back from a Slot | `push_back_slot` | `push_slot`
| **`send`, and the put hook's `extra`***. Both halves were checked.

**`send` is wrong.** `Mailbox.send_at` takes the handle out of the Slot itself
and hands a `Handle` to the queue — `mailbox.c3:221` into `:139`, which is
`push_back`, not `push_back_slot`. Nothing in `mailbox.c3` calls a Slot-shaped
insert.

**The put hook's `extra` is right, and it justifies the queue's only.** The pool
does not use one either: `take_back` empties the Slot itself and calls
`push(Handle)` — `pool.c3:552` into `:105`. What uses `InnerQueue.push_back_slot`
is the **hook**, which is application code, filling `extra` from a Slot it just
created — `t_pool.c3:70`, inside `TestHooks.on_put`. That is Part 12.5's
composite mechanism, written the way Part 9.3 says an acquisition is written,
and it is a real requirement of the public surface.

**So the two operations are not in the same position:**

| | Callers in `3tk/src/` | Callers outside | Verdict |
|---|---|---|---|
| `InnerQueue.push_back_slot` | **none** | `t_pool.c3:70` — a hook filling `extra`, Part 12.5. Plus `t_managed.c3:63`, `t_slot.c3:42`, `:158`, `t_queue.c3:358`, `:362`, and the `put_batch` sites `t_pool.c3:121`, `:434`, `:468`, `:498`, `:527`, `:537`, `:579`, `:593` | **Keep.** The application needs it, and Part 12.5 is why |
| `InnerStack.push_slot` | **none** | `t_stack.c3:133-136`, and that test tests this operation. Nothing else | **DELETED 2026-08-24.** Its only caller was ever `put_all`, dropped by `R15` — see the note below |

The stack's was the sharper case, and the deletion rested on two grounds.
**The first is `R15`: `push_slot`'s only caller was ever `pool.c3:451`,
`put_all`'s refusal path**, and 002 dropped `put_all` — §5.1's row says so, and
the queue's `push_front_slot` went with it for the same reason. The second, from
`3tk-port-findings-004.md`, was that no application could reach an `InnerStack`
at all. **3tk-only, and it was two lines plus one test.**

**CLARIFIED 2026-08-26.** The owner's ruling that the stack is available to a
caller **retires the second ground and leaves the first untouched**. `R15` is
sufficient on its own: the caller is gone and is not coming back, so **the
deletion is not reopened by the ruling.** What a public stack raises instead is
a new question and not a reversal — whether the stack should carry a
Slot-shaped insert for **symmetry** with `InnerQueue.push_back_slot`. The
queue's has a concrete reason the stack has no equivalent of: Part 12.5 hands a
hook an `InnerQueue* extra`, and no 3tk surface hands anyone a stack. **Nothing
here is open unless the owner asks for that symmetry.**

---

---

# 3. The specification should move — the every-port half

Only these may reach `../common/`. Each names the replacement wording in
outline; 3TK-13 cuts the text.

## 3.1 What §8.1 forecast, and the audit confirms

Nine of §8.1's ten rows stand as written. They are **V1 to V9 and V12** and the
audit adds nothing to them beyond the file and line:

| # | Part | The change | Where the code proves it |
|---|---|---|---|
| V1 | 4.2 MUST | *Two fields, a previous and a next* becomes one link plus the self-link terminator. The two conceptual parts survive | `inner.c3:75-78` |
| V2 | 8.1 MUST | *A doubly-linked list* becomes *ordering primitives whose nodes are the inners of Part 4* | `queue.c3:41`, `stack.c3:59` |
| V3 | 8.2 SHOULD | Sixteen operations become **eleven**, seven on the queue and four on the stack | `queue.c3`, `stack.c3` |
| V4 | 8.6 SHOULD | **Deleted.** One exact check replaces two partial ones | `queue.c3:88-91`, `stack.c3:79-82` |
| V5 | 8.7 MUST | **Rewritten.** Its own last bullet becomes the rule; the self-link is how it is paid for | `inner.c3:261` |
| V7 | 11.3 MUST | The two anchor bullets go. The three ordering guarantees stay — R9 | `mailbox.c3:60-69` |
| V8 | 11.7 MUST | *One free list per identity* becomes *one stack per identity*; **put a list** is deleted | `pool.c3:125-129` |
| V9 | 11.8 MUST | The list-put clause and the restored-order warning are deleted | `pool.c3` has no `put_all` |
| V12 | 18 | Row 16 retired and replaced by the self-link invariant; row 13 strengthened to O(1) in checking builds too | `inner.c3:42-53` |

**Part 8.9 is the row §8.1 got exactly right and the audit is glad to confirm**:
unchanged in force, narrowed to the queue, `queue.c3:207-220`, and
`negative/self_move.c3` still aborts.

## 3.2 What §8.1 did not forecast — the audit's own eight

§8.1's closing line reads: *Parts 1, 2, 3, 5, 6, 7, 9, 10, 12 to 17 and 19 to 22
are untouched.* **Five of those Parts are touched**, and the reason is the same
in every case: a Part that never mentions the list still *points* at one.

| # | Part | Marking | What 002 says now | What 003 must say | Why §8.1 missed it |
|---|---|---|---|---|---|
| V14 | 19.2 | — | the pool table has a **put a list** row: *nothing. Read the list* | the row goes | §8.1 tracked Part 11.7's operation list and not Part 19's mirror of it |
| V15 | 20 dec. 10 | open | *Where does the O(n) insert check live on a port with no build modes?* | **the decision dies.** There is no O(n) insert check to place | Part 8.6 was deleted without a search for its referrers |
| V15b | 20 dec. 4 | open | *Is the link test's blind spot acceptable? A list that marks membership is strictly better and costs a field per item* | the question inverts. The blind spot is closed and costs **no** field. What a port now decides is whether it accepts `next` carrying two meanings at six sites | same |
| V16 | 21 Q11 | — | *If no: Part 15.5 still holds, and the port decides what the checks cost in production. Part 8.6* | the pointer dangles; Q11 keeps its force and loses its example | same |
| V17 | 22 step 5 | — | *The list, with both insert checks* | *the queue and the stack, with the link test* | same |
| V6 | 11.2 | SHOULD | *One internal base... Both are built on the same internal parts* | state the five **required parts**, not a shared type. `Mailbox` and `Pool` repeat them — `mailbox.c3:41-78`, `pool.c3:156-174` — and the port's written reason is Part 4.4 | Part 11.2 was never on §8.1's list because the redesign did not aim at it; the trap the plan named as number 3, a mechanism read as a promise |
| V10 | 12.2, 12.5 | MUST/SHOULD | *the hook may also return an extra **list*** and *called once, with the full **list** of what remained* | *queue*, and say which container. R13 made the transfer container a queue; there is no general list left for the word to name | the redesign changed the surface's *type*, and §8.1 tracked the surface's *operations* |
| V13 | 19.1 | — | `receive` lists **interrupted** | conditional on Part 2.9, and 2.9 is a SHOULD a port may drop. State the conditionality in the table, as Part 16 row 12 already does for the excluded half | not a redesign consequence at all — a D9 consequence 002 never absorbed |

**V11 is the one this audit would keep if it could keep only one**, because it is
the rule that does not exist rather than the rule that moved:

| # | Part | Marking | The gap |
|---|---|---|---|
| V11 | 12.3 MUST, with 11.8 and 12.2 | MUST | 002 says a hook runs outside the mutex and says a closed pool is empty. It never says **what the pool does with a hook's result if the pool closed while the hook ran.** P1 is 3tk falling through that silence, and every port writes this code from the same silence |

**RULED 2026-08-24, so 003 writes a rule rather than a question.** The shape, in
three clauses:

1. **After a hook returns, the pool re-reads the closed flag under the mutex.**
2. **If it is set, everything that call is holding goes to the close hook** —
   the item the hook kept and every part it added. Nothing lands in a container
   after the flag is set, so invariant 34 holds, and nothing goes back to the
   caller, so Part 11.8 holds.
3. **Part 12.2's *called once* becomes *called once by close, and once more per
   straggling put*.** A hook must not destroy its own state on the first call.
   This is the clause that changes, and it changes because the alternative —
   handing the items back to the caller — has no channel for the parts the
   caller never had, and leaks them.

The reason this is every-port and not 3tk's: clause 1 is forced by Part 12.3
MUST, which every port obeys, so every port has the same window.

## V19 — Part 7.1 states a mechanism where the design has only a promise

**Filed 2026-08-24 by 3TK-16**, the code stage that carried 3TK-14's H0. **It
is an S, scope `every port`, and it is not a P.** Filing a P here would record
the port as wrong where the specification overreached, and keeping those two
apart is the whole value of this document.

| # | Part | Marking | What 003 says now | What 004 must say | Scope |
|---|---|---|---|---|---|
| V19 | 7.1 | SHOULD | *For each outer type there is a helper bound to that one type. The helper is generated at compile time from the type* | state the **promise** — the members of 7.2 exist per type, generated rather than hand-written — and show **both realizations**, marked *ztk* and *3tk*, exactly as 003 did for the other fourteen | every port |

Part 7.1's three clauses against the port as this stage leaves it:

| Clause | 3tk after H0 |
|---|---|
| *generated at compile time from the type* | **true** — macro expansion is compile-time generation from the type |
| *carries the type identity of Part 5, and the crossings of Part 6* | **true** |
| *for each outer type there is a helper bound to that one type* | **the only one that fails** |

**Part 7.1's own closing sentence sets the floor below where this port sits.**
*"A port with no compile-time generation writes the same block by hand for each
type, and loses only the typing."* Hand-written per-type blocks are conformant.
H0 is *above* that floor on the thing that sentence says matters — it generates
— and below it only on having a **named per-type object**, which is a mechanism
and not a promise.

**That one failing clause is ztk's mechanism, and this is the disease 3TK-13
existed to cure.** 002 stated Zig's mechanism where the design has a promise in
fourteen places and 003 fixed all fourteen. Part 7.1 is the fifteenth and
3TK-13 missed it: a comptime-per-type-struct shape written up as though it were
the requirement.

**The deciding argument is dtk.** D's idiomatic answer to *generate code per
type* is templates and mixins — call-site expansion, the same shape as a C3
macro, not a per-type struct. Fixing Part 7.1 inside this consumer's folder
would leave the identical trap set for D, and for Odin after it.

**3TK-17 writes the rewording.** This stage records the row and touches nothing
in `../common/`. E6 and E7 in `3tk-helper-proposal-001.md` Part F are the
rulings behind both halves.

| # | Part | Marking | The gap |
|---|---|---|---|
| V18 | 6.5 | SHOULD | Say whether the dispatch table is an element the **toolkit** ships or a pattern the **application** writes. As written it reads as the first and every clause in it describes the second — *one handler per pair of receiver and identity*, *the caller releases it*. 3tk shipped nothing and said nothing; P5 is that silence |

---

# 4. Where this document disagrees with §8.1

Listed plainly, in the shape 3TK-11's notes listed their three corrections.
**None of these is a decision reopened.** §8.1 is a forecast written before the
code existed and these are the places the code came out differently.

### 1. "Parts 19 to 22 are untouched" is wrong, in four places

**V14, V15, V16, V17.** Part 19.2 carries a row for an operation that no longer
exists. Part 20 carries two open decisions that Part 8.6's deletion answers or
voids. Part 21's Q11 points at a deleted Part. Part 22's step 5 names two insert
checks where there is one. All four are consequences of §8.1's own row for Part
8.6, and §8.1 deleted the Part without following its referrers.

### 2. "Parts 12 to 17 are untouched" is wrong in Part 11.2 and Part 12.2

**V6 and V10.** Neither is a rule change. Both are the word for a thing whose
type changed — a shared *base*, and a *list* — and both are exactly the trap the
plan named third: a mechanism written as though it were the rule.

### 3. §8.1's Part 8.2 row says "seven and six"; the stack has five

Not a new finding — **3TK-11's notes already corrected it**, and this audit
confirms the count against the code: `push`, `push_slot`, `pop`, `is_empty`,
`len`, `stack.c3:79-128`. It is recorded here because 003's Part 8.2 will be
written from a count, and the count in the ruled document is wrong. **Eleven
operations, not thirteen** — twelve as 3TK-11 left them, and eleven after P6 was
ruled on 2026-08-24. **Twelve of the sixteen leave the port, not nine.**

### 4. §5.1 says the two Slot inserts serve `send` and the put hook's `extra`; `send` does not use one

**P6.** `Mailbox.send_at` empties the Slot itself and calls `push_back(Handle)`,
`mailbox.c3:221` into `:139`. The `extra` half is right and it justifies the
queue's operation — the caller is the **hook**, application code, at
`t_pool.c3:70`. It justifies nothing on the stack, which the application cannot
reach at all under R13.

### 5. §8.1 predicts no port-side deviation, because a forecast cannot

Six exist — P1 to P6 — and one of them, P1, strands items. A forecast written
before the code cannot find a defect in the code, which is the whole argument
for this stage running before 003 rather than inside it.

---

# 5. The recommendation for 3TK-13's scope

**Rewrite in 003 — the every-port half, and nothing else.**

| Parts 003 rewrites | Why |
|---|---|
| 4.2, 8.1, 8.2, 8.6, 8.7 | V1 to V5. The core mechanism |
| 11.3, 11.7, 11.8 | V7, V8, V9. The container surfaces |
| 18 | V12. Row 16 retired, row 13 strengthened |
| **19.1, 19.2** | V13, V14. §8.1 said untouched |
| **20, 21, 22** | V15, V16, V17. §8.1 said untouched |
| **11.2, 12.2, 12.5** | V6, V10. Wording that names a type that changed |
| **12.3, and 11.8's neighbourhood** | **V11.** A clause that does not exist yet. The owner rules its shape first |
| **6.5** | V18. One sentence saying whose element it is |

**Parts 003 does not touch:** 0, 1, 2 (all of it, including 2.6 — P4 is the port
failing an unchanged rule), 3, 5, 7, 9, 10, 13, 14, 15, 16, 17, 19.3, 19.4.

**Two rules for the cut, and they are the plan's traps in their positive form:**

- **003 carries V1 to V18 and no P.** P1 to P6 are 3tk failing rules that already
  say the right thing. Moving a rule to accommodate a port's defect is how a
  specification stops being one. The single exception is **V11**, which is P1's
  *other* half and is in the list on its own merits: the rule genuinely does not
  exist.
- **Part 11.7 stays silent on the pool's order — R14 and R11.** Say the container
  is a stack. Do not promise most-recently-returned-first. §1.3's defect-surfacing
  argument works only while no caller is entitled to the order.

**And a sequencing note, now settled.** V11 was the only row whose *content* was
not determined. **The owner ruled it on 2026-08-24**, so all eighteen rows have
their replacement named and 003 writes the rule the repair implements rather
than stating a question. Its third clause is the only place 003 *weakens* an
existing MUST: Part 12.2's *called once* becomes *once by close, and once more
per straggling put*.

---

# 6. The open questions this stage does not answer

**None open.** All four were settled on 2026-08-24 — two by ruling, two by a
default the owner accepted as an assumption — and all four are kept below as the
record. The assumptions are listed in `3tk-status.md`, *The assumptions 3TK-13
starts from*.

1. ~~**P1's repair.**~~ **RULED AND FIXED 2026-08-24.** The mechanism is the
   re-read; the destination is the close hook; Part 12.2's *called once* is
   deliberately bent, because two calls to cleanup beats leaked parts. **003
   writes it — V11, whose three clauses are now spelled out in §3.2.** Nothing
   here is open.
2. **[3tk-who-supports-slot.md](3tk-who-supports-slot.md) — and the code answers
   most of it.** The owner's note is advice, not a ruling, and the measurement
   below is what it asked for. **Part 8.2's *add at the back from a Slot* is
   used, and by the party that matters**: a pool hook filling `extra` from a
   Slot it just created, `t_pool.c3:70`, which is Part 12.5's composite
   mechanism. Neither container in `3tk/src/` calls a Slot-shaped insert — §2,
   P6 — so the *port* does not need them, but the **application** does, on the
   queue, and a queue that spoke only in `Handle` would make a hook write
   `extra.push_back(part.take())` and lose rule 1's compile-time ally at the one
   surface Part 12.5 hands to application code. **The recommendation is to
   keep `InnerQueue.push_back_slot` on that ground and to change nothing in Part
   8.2 for it.** What is left of the question is `InnerStack.push_slot`, which
   is unreachable by anyone — P6 — and that is a 3tk deletion, not a
   specification question. **So this row leaves the every-port column.** 3TK-13
   need not wait on it. **Ruled and done the same day: the method and its test
   are deleted.** Nothing here is open.
3. ~~**P2's answer.**~~ **DEFAULTED 2026-08-24, assumption A3: a distinct
   outcome in the port.** Part 19.3 keeps its MUST and 003 stays untouched.
   **It is a code change and 3TK-13 does not make it** — it wants its own small
   stage. This is the only one of the four that leaves work behind. **That
   stage was 3TK-15 and it has run**: `UNKNOWN_IDENTITY`, in all three get
   modes and in `get_wait`. Nothing here is open.
4. ~~**P5's half.**~~ **DEFAULTED 2026-08-24, assumption A4: Part 6.5 is the
   application's**, and 003 says so in one sentence. On that reading 3tk had
   nothing to ship and no skipped SHOULD to explain, so P5 closes with V18.

---

## Change log

| Version | Date | Description |
|---|---|---|
| 001 | 2026-08-24 | First version. Stage 3TK-12. 96 elements measured against `3tk/src/`. 74 conform, 17 specification-should-move, 6 port-should-move, 8 not applicable. |
| 001, amended | 2026-08-24 | **Stage 3TK-16**, and the only edits it makes to a finished stage's output. Additive, in this document's own vocabulary, not a rewrite of its findings. **V19 filed** — Part 7.1, an **S**, scope `every port`, from E6. Part 7.3's evidence updated from *two generic modules* to *two modules*, from H0b and E7. Parts 6.3 and 7.2's evidence repointed at the names H0 and H5 left. **No verdict changed except 7.1's, from C to S.** |
| 001, amended | 2026-08-24 | **Stage 3TK-19**, and it is one row. **P2 is marked fixed** — assumption A3 defaulted, stage 3TK-15 built `UNKNOWN_IDENTITY`, and the row recorded a defect the port no longer has. Additive and in this document's own vocabulary: the verdict stays **P**, the scope stays `3tk-only`, and the finding is left as it was measured. **No other row touched, no finding re-argued, and V1 to V19 stand.** |
| 001, amended | 2026-08-25 | **Citations only, and no stage.** The `pool.c3`, `mailbox.c3`, `queue.c3`, `stack.c3` and `helper.c3` line citations that had drifted since 3TK-12 measured them are repointed — 3TK-26 paid the `inner.c3` ones and reached no further. **Twenty-two citations moved**: the conformance table's evidence, the S-row evidence, the two open findings **P3** and **P4**, and P6's two live claims about `send_at` and `take_back`. `t_owned.c3:63` became `t_managed.c3:63`, the file's name after the module rename. **P4's quoted block is re-cut** from today's code, with a sentence saying so and why the finding does not move. **What quotes code a ruling has since changed is left exactly as measured** — P1's and P2's blocks, and P6's citations of the deleted `InnerStack.push_slot` — because repointing a measurement would falsify it. No verdict, no scope, no finding text and no version changed. |
