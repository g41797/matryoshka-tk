# 3tk container notes (001)

Stage 3TK-7 of [3tk-staging-plan-003.md](backup/3tk-staging-plan-003.md).

What writing the mailbox and the pool taught, beyond
[3tk-porting-proposal-001.md](backup/3tk-porting-proposal-001.md) and
[3tk-toolkit-notes-001.md](3tk-toolkit-notes-001.md).

Steps 6 and 7 of Part 22. The port is now complete against the specification:
Part 17.1's required tool and both of Part 17.2's optional ones.

## The result

**All four builds green. 55 checks, 0 failures.**

```
== c3c 0.8.3, git 1d155ee, LLVM 22.1.8, linux-x64 ==

  safe -O0 (--safe=yes -O0)    71 tests, 6 negatives, 2 tier 1, 3 refusals
  safe -O3 (--safe=yes -O3)    71 tests, 6 negatives, 2 tier 1, 3 refusals
  fast -O0 (--safe=no  -O0)    71 tests, 6 negatives, 2 tier 1, 3 refusals
  fast -O3 (--safe=no  -O3)    71 tests, 6 negatives, 2 tier 1, 3 refusals

== Part 17.2: the layering ==   3 checks

passed 55, failed 0
all four builds green
```

37 tests at the end of 3TK-6, 71 now. Reproduce with `3tk/run-builds.sh`.

## The three things the stage had to get right

Plan 003 named them in advance. All three landed.

### 1. D7's wait loop, and a test that can tell

Part 2.5 MUST, invariant 4. The deadline is anchored once, before the loop, and
every wait is `wait_until` on it. **`wait_timeout` does not appear anywhere in
the port**, because it recomputes `now() + ms` on every call.

The trouble with this MUST is that a wrong implementation passes every ordinary
timeout test. `the_deadline_is_anchored_once` is built to fail on it: a waiter
asks for 200ms while a second thread broadcasts on the condition variable every
20ms for a full second. Anchored, it returns at ~200ms. On `wait_timeout`, each
broadcast restarts the full timeout.

**The test was verified by sabotage.** `wait_until(deadline)` was swapped for
`wait_timeout(timeout)` in `Mailbox.receive`, and the suite reported:

```
Testing mtk_test::the_deadline_is_anchored_once .................. [FAIL]
ERROR: 'Violated assert 'elapsed < 600': Part 2.5: the deadline was NOT
        anchored once. A spurious wakeup restarted the timeout — this is
        the wait_timeout defect'
Test Result: FAILED: 70 passed, 1 failed
```

The sabotage was reverted. A test for an invariant of this shape is worth
nothing until it has been seen to fail, and this one has.

The same loop shape appears twice — `Mailbox.receive` and `Pool.get_wait` — and
carries four MUSTs each time: Part 2.4's re-check from scratch, Part 2.5's
anchor, Part 2.6's hand-off on the way out, and Part 15.3's flag read under the
mutex.

### 2. D6 tier 1 has its first two sites

Part 11.12 — releasing an open container — is the one contract the
specification refuses to soften: *"Both stop the program. In every build mode.
Not an assert that compiles out."*

`Mailbox.release` and `Pool.release` use `always_assert`, not `@check`. They are
the only two sites in the port that do.

`run-builds.sh` grew a third negative shape for them. Every other negative
asserts *opposite* behaviours across the builds — abort when checked, run to the
end when not. A tier 1 negative asserts the **same** behaviour in all four:

```
== build: fast -O3  (--safe=no -O3) ==
  ok    tier 1 release_open_mailbox aborts (as it must in every mode)
  ok    tier 1 release_open_pool aborts (as it must in every mode)
```

Both programs print `SOFTENED: ...` if they ever reach their last line, and the
script fails on that string specifically. A MUST that says *in every build mode*
deserves a test that says so in every build mode.

### 3. Part 12.3, and a test that would notice a held lock

Hooks run outside the mutex, several at once, on different threads, and the
pool does not serialize them.

`hooks_run_outside_the_mutex` has the hook count its own concurrent entries and
hold itself open for 20ms. Four threads call `get` at once. If the pool held its
lock across the call the maximum would be one, and the assertion says exactly
that. Measured: the whole test takes ~20ms rather than ~80ms, and `max_inside`
exceeds one.

## The findings

### G1 — the containers belong in submodules, and C3 makes Part 17.2 free

**The stage's one structural change to the proposal.**

Part 17.2 SHOULD says the two containers are built *on* the intrusive layer
*with no privileged access to it*, and Part 17.3 calls that the test of the
design: *"If the mailbox needed something the application cannot have, the
layering would be a fiction."*

The proposal put `Mailbox` and `Pool` in `module mtk`, alongside `AnyNode` and
`NodeList`. That makes the layering a promise the authors keep, checkable only
by review.

F3 of the toolkit notes — *`@private` does not reach a submodule* — was recorded
there as an irritation. It is the solution here. `mailbox.c3` declares
`module mtk::mailbox` and `pool.c3` declares `module mtk::pool`, and a submodule
**cannot see its parent's private declarations**. The containers are therefore
structurally outside `mtk`, and Part 17.2 is enforced by the compiler.

The move was not free and the compiler said so at once — six errors of the form:

> `Faults from other modules must be prefixed with the module name, please use
> mtk::CLOSED instead.`

That message *is* the enforcement working. The containers now name
`mtk::CLOSED`, `mtk::TIMEOUT` and the rest explicitly, which is what a caller
from outside has to do.

The API reads better for it:

| Before | After |
|---|---|
| `mtk::mailbox_create(a)` | `mailbox::create(a)` |
| `mtk::pool_create(a, tags, hooks)` | `pool::create(a, tags, hooks)` |
| `mtk::MAILBOX_TYPE` | `mailbox::TYPE` |
| `mtk::pool_of(h)` | `pool::of(h)` |

**Recommended as an amendment to the proposal's section 1**, which lists the
files but not the modules they declare. The owner's to accept.

`run-builds.sh` now checks the module declarations directly, and separately
that no container names `unlink_no_repair` or `@guard_insert` — the two places
a caller could reach around the `NodeList` surface.

### G2 — the fault-return operator is `~`, not `?`

`return CLOSED?;` does not compile. The spelling is `return CLOSED~;`.

*Read*: `collections/list.c3:118` `return NO_MORE_ELEMENT~;`,
`threads/os/thread_posix.c3:184` `return thread::WAIT_TIMEOUT~;`.

`?` is the optional-type marker — `void?`, `Mailbox*?` — and `~` is the
fault-return. D15 chose faults as the outcome mechanism and did not spell the
return.

### G3 — Part 11.2's shared base cannot be a shared struct

Part 11.2 SHOULD says both containers are built on the same internal parts: the
inner, a mutex, a condition variable, a closed flag, an allocator.

A port cannot express that as a struct the two embed. **Part 4.4 allows one
inner per outer**, and a shared base carrying the inner, embedded in both, gives
each container an inner one level down — with the outer's helper computing the
wrong offset, or two inners if the container also declares its own.

So `Mailbox` and `Pool` repeat the five members. Part 11.2's own text permits
this: it calls the base *"a statement about how the two are built, not a type
the application names."* Recorded because a reader who takes 11.2 as a
factoring instruction will build the bug.

### G4 — a flat slice beats a hash map for the pool's buckets

Part 11.7: the set of identities is fixed at creation and is not empty. Fixed
and small.

The proposal's section 5.9 said `HashMap{typeid, Bucket}`. A `PoolBucket[]`
allocated once at creation and scanned linearly is simpler, allocates once
instead of per-insert, and needs no hash of a `typeid`. For a set that never
grows past a handful, the scan is faster than the hash.

An amendment to a spelling, not to a decision.

### G5 — `put` takes the item from the caller before the hook sees it

Part 9.4 says the caller reads their own Slot: cleared means kept, unchanged
means refused. Part 12.2 says the hook gets a Slot and its state on return says
what the hook decided. **These are two different Slots** and the proposal did
not say so.

`Pool.put` clears the caller's Slot at the moment it accepts the item, then
hands the hook a Slot of its own. A port that passes the caller's Slot straight
through would let a hook that releases the item leave the caller's Slot empty —
which happens to be right — and a hook that keeps it leave the caller's Slot
full, which reads as *refused* and is wrong.

Both are tested: `a_put_hook_may_release` and `get_creates_then_reuses`.

### G6 — small spellings, again

| Subject | Actual in 0.8.3 |
|---|---|
| Atomics | `import std::atomic::types` for `Atomic{bool}` |
| Allocator interface | `import std::core::mem::alloc`; `alloc::new_try`, `alloc::new_array_try`, `alloc::free` |
| An optional to a plain value | `mailbox::create(mem)!!`, not an implicit cast |
| Thread function | `alias ThreadFn = fn int(void* arg)` |
| Mutex lock | `void?` but `@maydiscard`, so `mu.lock();` is legal as written |

## The sixteen decisions, after both stages

| # | Decision | State after 3TK-7 |
|---|---|---|
| D1 | Public struct, the border does the work | **Survived.** The reachable `_cv` is used by one test to provoke a spurious wakeup — there is no public way to do that, and no reason there should be |
| D2 | Plain inner field | Survived |
| D3 | Allocators per type | **Survived, both containers.** `release` takes no allocator on either |
| D4 | One handle type | Survived. No cast at any call site |
| D5 | A distinct Slot | Survived |
| D6 | Three assert tiers | **Survived, and tier 1 now has its two sites.** Proved in all four builds |
| D7 | Anchor the deadline | **Exercised, and the test was verified by sabotage** |
| D8 | The names | Survived. G1 adds the module names, which D8 did not cover |
| D9 | Interruption dropped | **Confirmed.** The outcome sets lose exactly one value in two rows and nothing else changed |
| D10 | Two composing generic modules | Survived |
| D11 | Part 22's order | Followed |
| D12 | The link test's blind spot | Survived |
| D13 | Poll beside receive | **Exercised.** `poll` reports EMPTY, a zero-timeout receive reports TIMEOUT, and both are tested |
| D14 | Out-of-band kept | **Exercised.** The anchor, the interleaved ordering, and the anchor being cleared |
| D15 | Faults as the outcome mechanism | **Exercised in full.** Amended by G2 |
| D16 | The pre-lock fast path | **Exercised.** Atomic flag, acquire outside, re-read under the lock, release on the store |

**Sixteen ruled, sixteen exercised, sixteen survived.** Two spelling amendments
across both stages (G2 and the toolkit's F5/F7) and one structural
recommendation (G1). None in substance.

## Part 18, complete

| # | Invariant | State |
|---|---|---|
| 1 | Plain threads; the toolkit starts none | **Structural.** Every test creates its own threads |
| 2 | A mutex and a timed condition wait, nothing else | **Structural.** No other primitive appears |
| 3 | A wakeup carries no meaning | **Tested.** `the_deadline_is_anchored_once` |
| 4 | The deadline is anchored before the loop | **Tested, and verified by sabotage** |
| 5 | A leaver signals if the container is not empty | **Tested.** `a_leaver_hands_the_signal_on`, 20 rounds |
| 6 | Participants are long-lived and do not move | Documented |
| 7-20 | The toolkit | **Done in 3TK-6.** See `3tk-toolkit-notes-001.md` |
| 21 | The containers are themselves items | **Tested.** `a_mailbox_is_an_item`, `a_pool_is_an_item` |
| 22 | Out-of-band ahead, FIFO within each | **Tested.** `out_of_band_ordering`, `the_anchor_is_cleared` |
| 23 | Every item the mailbox keeps goes back | **Tested.** `close_gives_the_remainder_back`, and the returned items have their links cleared |
| 24 | The pool's close gives nothing back | **Tested.** `close_gives_nothing_back` |
| 25 | The waiting get never creates | **Tested.** `the_waiting_get_never_creates`, on the hook counter |
| 26 | Close before release, unconditional | **Tier 1, all four builds** |
| 27 | Hooks are a parameter of creation | **Structural.** `pool::create` cannot be called without them |
| 28 | Hooks outside the mutex, in parallel, no callback | **Tested.** `hooks_run_outside_the_mutex` |
| 29 | The count is a hint | **Tested.** `the_count_is_read_from_the_right_side` — after removal on get, before addition on put |
| 30 | One holder at a time; a transfer is a move | **Tested** throughout |
| 31 | The transfer orders memory | **Tested.** `many_producers_many_consumers` sums plain reads of plain writes across three producers and three consumers |
| 32 | One mutex per container, its own state only | **Structural** |
| 33 | No lock held across a call into application code | **Tested.** Invariant 28's test is this one too |

**All thirty-three reached.** Twenty-eight tested or provoked; five structural
or documented, and each says which.

## What is not done

Honest list.

- **No sanitizer run.** Plan 003 asked for the concurrency tests *"under
  whatever sanitizer the toolchain offers"*. Not done, and not measured whether
  c3c 0.8.3 offers one. The concurrency tests pass repeatedly in four builds,
  which is not the same thing.
- **`a_leaver_hands_the_signal_on` is a race test run 20 times.** Passing is
  evidence, not proof.
- **No cross-target build.** ztk is green on three cross targets; 3tk has been
  built for linux-x64 only.
- **Part 8.10 and 8.11, and Part 9.5**, remain dropped. Their conditions are
  still not met.
- **The `.c3l` distribution question**, `3tk-build-dist.md` B2, is still
  unverified and still a tooling stage's.

## For whatever comes next

The port is complete against the specification. What remains is not more
Matryoshka.

1. **The owner's ruling on the sixteen decisions.** They are still marked
   PROPOSED in `3tk-porting-proposal-001.md`. All sixteen have now survived
   contact with a compiler, which is the evidence the ruling was waiting for.
2. **G1 as an amendment** to the proposal's section 1: the containers are
   submodules, and the module names belong beside the file names.
3. A sanitizer run and a cross-target build, if the toolchain offers them.
4. Packaging, which was never in this line of work.

---

## Change log

| Version | Date | Description |
|---|---|---|
| 001 | 2026-08-23 | First version. Stage 3TK-7. Four builds green, 55 checks. |
