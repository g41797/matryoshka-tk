# 3tk — the lifetime fix

**3TK-51's output. First version, 2026-08-28.** One document, merging the two
advice files into the description the code stages work from.

**No byte of `3tk/src`, `test/` or `negative/` was touched by the stage that
wrote this.**

**Inputs, and nothing else was read:**
[3tk-staging-plan-020.md](3tk-staging-plan-020.md),
[3tk-bugs- mailbox.md](<3tk-bugs- mailbox.md>),
[3tk-bugs-pool.md](3tk-bugs-pool.md),
[3tk-release-while-busy-001.md](3tk-release-while-busy-001.md),
[3tk-on-close-policy-001.md](3tk-on-close-policy-001.md), `3tk/src/mailbox.c3`
and `3tk/src/pool.c3`.

**Every line number below was re-printed live on 2026-08-28.** Re-print before
trusting them: every fix in 3TK-53 and 3TK-54 moves them.

**This document is versioned.** Every answer the owner gives to section 14 makes
`002`, `003`, and the superseded version moves to `backup/`. **A question and its
answer live here**, never only in a conversation.

---

## 1. The one defect, on two tools

`Mailbox.release` at `mailbox.c3:106` and `Pool.release` at `pool.c3:231` both
open with the same line:

```c3
always_assert(self._closed, "releasing an open mailbox");   // mailbox.c3:114
always_assert(self._closed, "releasing an open pool");      // pool.c3:240
```

**That assertion answers the wrong question.**

There are **three states, not two**:

| state | what it means | who knows it today |
|---|---|---|
| **closed** | no new call may enter | `_closed`, `_closed_fast` |
| **quiet** | no call is still inside | **nobody** |
| **freed** | the memory is gone | the allocator |

`close` establishes the first. `release` acts as though it had established the
second. Between them sits every call that entered before the close and has not
yet returned.

The shape, from the mailbox advice §1:

```text
Thread A                         Thread B

receive()
    lock
    ...
                                 release()
                                     lock
                                     closed = true
                                     ...
                                     free(self)
    ...
                                 <- A is inside freed memory
```

**A caller who reads `Part 11.12`, closes, and then releases has obeyed every
clause the toolkit states, and can still land here.** That is what makes this
worth fixing rather than tolerating.

## 2. The mechanism both advices land on

**A plain `usz _active`, under the mutex the two tools already own.**

**No atomic.** Both structs already carry a `Mutex` and a `ConditionVariable`,
and almost every call already takes the mutex. The pool advice's *Second advice*
§13 states it directly: the mutex already protects `_closed` and the buckets, so
it can protect one more field at no measurable cost, and the condition variable
already exists to wait on.

The protocol:

```text
enter    lock; if closed -> leave with CLOSED; _active++
leave    lock; _active--; if _active == 0 -> broadcast
release  lock; _close(); while _active != 0 -> wait; ... ; destroy; free
```

**`release` is never counted as active.** It would then wait for itself for ever.
Both advices say this in the same words — mailbox §8, pool *Second advice* §8.

**The wait terminates.** The precise statement is the pool advice's own
correction to the `Q5` document, and it is the one this port adopts:

> The closed flag prevents a call that acquires the mutex **after** closure from
> becoming active, so once closure is established the active count can only fall.

## 3. The API change

**The `always_assert` disappears from both.** `release` closes if it must, waits
until quiet, then destroys.

```text
close      the non-destructive client call. Unchanged in meaning.
release    close if still open, wait for the calls in flight, destroy, free.
```

**`close` is not required before `release` any more.** The two negative programs
that prove today's rule therefore **invert** — see section 13.

**What `Part 11.12` says today** is *closed before released*, and it is a tier 1
MUST that aborts in every build mode. What replaces it is section 9's clause, and
**it is not 3tk's to write** — that is 3TK-52.

## 4. The private primitive

`_close()` runs **with the mutex already held**. It is the state change both
public paths share, and nothing else.

| it does | it never does |
|---|---|
| returns at once if already closed | take the mutex |
| sets `_closed` | release the mutex |
| publishes `_closed_fast` with RELEASE | call a hook |
| empties what the tool holds into the caller's storage | destroy anything |
| broadcasts on the condition variable | free anything |

**So `release` never calls public `close`, and no lock nests.** That is the
mailbox advice's §14 and the pool advice's *Second advice* §7, and both give the
same reason: one copy of the state change, no nested locking.

The mailbox form, from the advice's §3:

```c3
fn void Mailbox._close(&self, InnerQueue* out) @private
{
    // _mu is already held

    if (self._closed) return;

    self._closed = true;
    self._closed_fast.store(true, RELEASE);

    out.append_queue(&self._oob);
    out.append_queue(&self._regular);

    self._cv.broadcast();
}
```

The pool form is the same shape over `_buckets`, emptying every bucket's free
stack into the caller's queue — the body that stands at `pool.c3:479-489` today.

## 5. Mailbox specifics

**The mailbox has no hook, so it is the mechanism without the hard part.** Its
waiting path holds the mutex across `wait_until` at `mailbox.c3:255`, so a parked
receiver is covered by the same field with no special handling.

**`_close(InnerQueue* out)` writes into caller-owned storage.** The mailbox still
never allocates for the outers it gives back — the property `close` has today at
`mailbox.c3:327`, kept.

**`release` takes the same `out` argument**, so both calls have one story:

```c3
fn void  Mailbox.close(&self, InnerQueue* out)      // today, unchanged
fn void  Mailbox.release(&self, InnerQueue* out)    // the change
```

Both assert `out.is_empty()` on entry, as `close` does today at
`mailbox.c3:330`. **Whether `release` gains the parameter at all is the owner's**
— section 14, `Q-B`.

**The `defer` pattern, from the advice's §11 and §12:**

```c3
InnerQueue iq;

defer queue_outers_release(&iq);   // declared first, runs second
defer mbox.release(&iq);           // declared second, runs first
```

C3 runs deferred statements in **reverse textual order**, so the mailbox fills
`iq` first and the client's function empties it second. Both refer to the same
local, which is still in scope when either runs.

**3TK-53 runs this rather than reasoning about it** — the advice's §12 asks for
exactly that, and it is a test in `test/t_mailbox.c3`.

## 6. Pool specifics, and the detail that decides the implementation

**`_active` must cover the whole call, hook window included.** This is the single
most important line in the document, and it is the pool advice's *Second advice*
§3.

The window is deliberate and specified. `Part 12.3` MUST forbids holding the
mutex across a call into application code, so `Pool.put` opens it itself:

```
pool.c3:421:    self._mu.unlock();
pool.c3:422:    self._hooks.on_put(in_pool, &mine, &extra);
pool.c3:423:    self._mu.lock();
```

**`:423` re-takes a mutex that a concurrent release may already have destroyed
and freed.** That is the whole defect, at its worst site.

So, for `put`:

- raised **before** the release of the mutex at `:421`;
- lowered only after the re-take at `:423` **and** after any straggler
  `on_close` at `:434`.

**A count that stops at `on_put` leaves the straggler hook uncovered**, and the
straggler path is application code holding pool-derived state:

```text
put:  _active--          <-- wrong
      on_close(...)      <-- still running
release: sees 0, frees
put:  still inside
```

**`Pool.close` stays active through its own hook** at `pool.c3:493`, which runs
after the mutex is released at `:490`. *Second advice* §4: a `close` counted only
to the release of the mutex lets a release free the pool while `on_close` is
running.

**`Pool.get`'s hook at `pool.c3:321`** runs after the mutex is released at
`:320`, and the call returns straight after it. Same rule: raised before `:320`,
lowered after the hook.

**`get_wait` counts as active** and leaves on the close broadcast. It holds the
mutex across `wait_until` at `pool.c3:368` and reports `CLOSED` when it wakes and
sees the flag — the path that already works at `pool.c3:351-352`. Its count then
falls, and release proceeds.

**Taking the mutex is not a lifetime mechanism.** The pool advice's §12 states
it and the code proves it: the mutex is free for the whole of `on_get` and
`on_put`, which is exactly the window. A release that merely locked would sail
straight through it.

## 7. The contradiction, stated and not resolved here

**The two halves of the pool advice disagree, and they cannot both hold.**

| | first half — §4, §8, §17 *Contract 2*, §29 item 12, §30 | second half — *Second advice* §5, §15 |
|---|---|---|
| **rule** | `on_close` MUST NOT start until the calls already in flight have finished | the lifetime counter MUST NOT become a hook serializer |
| **effect on `Part 12.2`** | the second `on_close` from a straggler `put` disappears | it stays, exactly as specified |
| **what it costs** | `close` blocks on application code it does not control; a slow `on_put` stalls every closer; `Part 12.2` and [3tk-on-close-policy-001.md](3tk-on-close-policy-001.md) are both reopened, and that file was ruled and closed on 2026-08-27 | a hook writer must still tolerate two concurrent `on_close` calls, which is what `Part 12.3` already tells them |
| **what it gains** | one closing phase, easy to explain; `put`'s straggler branch at `pool.c3:425-436` can go | no new promise, no new blocking, the spec unchanged |

**Filed as `Q-A` in section 14. It is the question that decides how 3TK-53 and
3TK-54 are written**, and no stage takes it.

**What the port can say without ruling it:** the current code is correct against
the specification as written. `Part 12.2` says `on_close` is *called once by
close — and once more for each put that discovers the pool closed while its own
hook was running*, and `Part 12.3` says several hooks run at once and the pool
does not serialize them. **Hook serialization would be a change to the shared
specification, not to 3tk.**

## 8. Who may release

**What this replaces:** *We never guard simmultaneous releases - by design*, in
[3tk-release-while-busy-001.md](3tk-release-while-busy-001.md) under *Owner
thinking - Mailbox*.

The mailbox advice's §5 refuses to accept that as stated, and gives the reason:

```text
Thread A                    Thread B
release()                   release()
  _close()                    sees closed
  free(mb)                    free(mb)      <- double free
```

**An unguarded concurrent release is a double free, not a design decision.** But
it does not need guarding — it needs a written rule:

> **Calls on a mailbox or a pool may be concurrent. Release may not.
> Exactly one owner destroys the tool.**

**Single-owner destruction, written down.** Both advices reach the same place —
mailbox §5 and §16, pool §14 — and both prefer the rule to the machinery. The
alternative is external reference counting, which neither recommends and which
the port has no need of.

The pool advice's §14 gives the matrix, and it is the clause's whole content:

| pair | supported |
|---|---|
| release vs `get` | yes |
| release vs `get_wait` | yes |
| release vs `put` | yes |
| release vs `close` | yes |
| release vs release | **no — the caller's responsibility** |

## 9. The boundary the fix cannot cross

**A caller holding a pointer who has not yet entered cannot be protected by
anything inside the tool.** The pool advice's *Second advice* §11:

```text
thread A: p.put(...)     <- has not entered yet
thread B: p.release()    <- closes, waits, frees

thread A now enters through a pointer to freed memory.
```

**No counter inside the freed memory can help.** The counter and the mutex
guarding it are in the memory being freed, which is the same defect one level
down — the `Q5` document said this first, under *A counter alone narrows the
race*.

So the clause says exactly this and not one word more:

> **Release waits for calls already in flight.**

It does **not** say that arbitrary later uses of an old pointer become safe.
That is an ordinary lifetime boundary and it belongs to the application.

## 10. What stays unchanged

Named here so no stage widens the work. From the pool advice's §18 to §24 and
§28, and from the rulings already taken:

- **the flat bucket lookup** at `pool.c3:260` — O(identities), and the identity
  set is fixed at creation. No hash table.
- **`broadcast` after a put** at `pool.c3:443` — conservative, and correct first.
- **`count_of` answering 0 for an unknown identity** at `pool.c3:511` — it is an
  informational query, not a defect site.
- **`take_back_handle` as a hard failure** at `pool.c3:455` — ruled 2026-08-27.
  A hook returning an identity the pool was not created with is an application
  defect.
- **`UNKNOWN_IDENTITY` as a checking-build defect** on `get` and `put`.
- **the stale `in_pool` hint** at `pool.c3:414` and `pool.c3:318` — necessarily
  approximate, and named a hint by the API.
- **the `extra` mechanism** and the `Slot` transfer in `put` at `pool.c3:417-419`.
- **no `put_all`.**
- **the stack behaviour of a bucket** — independent of this work.

## 11. What it costs

**`release` stops being a call that cannot block.**

That is the design change. Not the counter, not the field, not the assertion.

- A `release` now waits for application code it does not control — an `on_put`
  or an `on_close` that never returns is a release that never returns.
- **There is no timeout and no abort path.** Waiting is the sound answer;
  aborting cannot be implemented safely, because the abort would have to read
  the memory it is racing.
- **The other ports inherit it** if 3TK-52 is ruled that way. That is the real
  content of the clause and the reason 52 exists.

**What does not change:** a correct application sees no difference on the calling
path. `_active` is one field under a mutex the call already holds.

## 12. The `P6` interaction

`P6` — the pool cannot tell whether the close hook processed the items it was
given or dropped them — keeps its own question, unchanged.

**But its option 1 is unblocked by this work.** Counting what went out against
what came back means nothing while a further `on_close` may still arrive from a
straggler `put`. **After 3TK-54 there is a moment when no further `on_close` can
arrive**: release has waited, `_active` is zero, and the pool is quiet.

`P6` stays the owner's. This document only records that its blocker is removed.

## 13. The negatives this fix owes

Named here, built in 3TK-53 and 3TK-54. **None of them has to be a flaky race.**
A hook that parks until the main thread has called release is a deterministic
trigger for exactly the window, and the port already has that shape in
`test/t_concurrency.c3`.

| file | stage | what it proves |
|---|---|---|
| `negative/release_open_mailbox.c3` | 53 | **inverts.** Releasing an open mailbox becomes the normal path: the program now runs to its last line where it used to abort |
| `negative/release_while_receiving.c3` | 53 | a receiver parked in `receive`, the owner releasing. Deterministic: the receiver holds the mutex across `wait_until` |
| `negative/release_open_pool.c3` | 54 | **inverts**, the same way |
| `negative/release_during_on_put.c3` | 54 | **Test A.** `on_put` parks until the main thread has called release, then returns. Without the fix, undefined behaviour; with it, release waits and the program finishes |
| `negative/release_during_on_close.c3` | 54 | **Test B.** `_active` covers `close`'s own hook |
| `negative/release_with_straggler_put.c3` | 54 | **Test C**, the most valuable pool-specific one: a concurrent put produces the second `on_close`, and release waits for both calls |

**Both `release_open_*` programs are TIER 1 in `run-builds.sh`** — they must
abort in all four builds today. When they invert they stop being tier 1 and
become ordinary programs that run to the end in every build. **`run-builds.sh`
changes in the same stage**, and the moved check count is printed, not assumed.

Two test-suite cases go with them:

- `test/t_mailbox.c3` — the reverse-order `defer` case of section 5, run.
- `test/t_pool.c3` — `get_wait` parked when release runs: the close broadcast
  wakes it, it reports `CLOSED`, the count falls, release completes.
- `test/t_concurrency.c3` — release racing a sender, repeated, under
  `run-sanitizers.sh` as well as `run-builds.sh`.

## 14. Open questions

**Every question this work raises. They are not asked outside this document.**
An answer makes the next version of this file, with the answer written into the
section it belongs to.

### `Q-A` — hook serialization. **The one that decides 53 and 54.**

Does `on_close` wait for the `on_get` and `on_put` calls already in flight?

- **Variant 1 — no serialization.** The counter is a lifetime mechanism only.
  `Part 12.2` and `Part 12.3` stand; a straggler `put` still produces a second
  `on_close`; `put`'s branch at `pool.c3:425-436` stays. *Second advice* §5 and
  §15. **Nothing outside 3tk changes.**
- **Variant 2 — serialization.** One closing phase. `close` waits for in-flight
  calls before its hook, and the straggler branch goes. §4, §8, §17, §30.
  **Reopens a shared-specification clause ruled and closed on 2026-08-27.**

Section 7 holds the full comparison.

### `Q-B` — does `Mailbox.release` gain `InnerQueue* out`?

The mailbox advice's §4 and §13 recommend it, for one story across `close` and
`release`. **It is a signature change on a public call**, and the `Q5` ruling of
2026-08-27 rested on the client's code being unaffected either way. Without it,
a release of an open mailbox has nowhere to put the remainder and would have to
discard it silently — which the port does not do anywhere else.

### `Q-C` — does `Pool.release` gain one too?

Or does it keep giving everything to `on_close`, as `Pool.close` does today at
`pool.c3:493`? The pool has a hook and the mailbox does not, so the two answers
need not match. **A pool that grew an `out` parameter would have two ways to hand
back the same items.**

### `Q-D` — does 3TK-52 run before the code?

Or does 3tk go first under a written assumption naming which way it assumed?

### `Q-E` — where does 3TK-50 fall?

The examples tree does not depend on this fix and this fix does not depend on it.
But 3TK-50 writes example code that a changed `release` signature — `Q-B` — would
then have to be rewritten in.

### `Q-F` — `P6`'s ruling.

Unblocked by 3TK-54, still open, still the owner's. Section 12.

### `Q-G` — does `W3` go in at all?

[3tk-release-while-busy-001.md](3tk-release-while-busy-001.md) left this open: a
one-sentence warning on both `release` descriptors saying the port does not yet
stop a release that races a call in flight. **If 3TK-53 and 3TK-54 run, it is
written in and out again within days**, and it costs a doc loop and a reference
version each way.

**The seven questions plan 018 left and 019 carried are still open**, and are not
restated here.

---

## The feasibility probe

**One C3 fact the whole mechanism rests on, measured and not argued.** A scratch
module compiled against `3tk/src` in all four builds, run in each: a `usz`
counter under a `Mutex`, four worker threads that enter under the mutex, work
**outside** it — the pool's hook window — and leave under it; a waiter blocking
on the `ConditionVariable` until the counter reaches zero; the condition variable
and the mutex destroyed and the memory freed afterwards; and `wait_until`
behaving as the port already relies on.

**What it printed, in every one of the four builds:**

```
== probe: counter + condition variable + destroy ==
  workers entered: 4
  release returned, cv and mutex destroyed, memory freed
  wait_until with no signal: fault, WAIT_TIMEOUT=true
PROBE OK
```

| build | result |
|---|---|
| `--safe=yes -O0` | PROBE OK, exit 0 |
| `--safe=yes -O3` | PROBE OK, exit 0 |
| `--safe=no -O0` | PROBE OK, exit 0 |
| `--safe=no -O3` | PROBE OK, exit 0 |

**What each line proves.**

- **`workers entered: 4`** — all four were inside when the waiter began, so the
  wait was real and not a race the probe happened to win. The waiter read the
  count under the mutex after the last worker had left.
- **elapsed 0.10s** against a 40ms working window and a 60ms timeout probe —
  **the waiter blocked.** It did not return early.
- **`release returned, cv and mutex destroyed, memory freed`** — a
  `ConditionVariable` and a `Mutex` can be destroyed after the last waiter has
  left them, and the heap block holding them freed, with no fault in any build.
- **`WAIT_TIMEOUT=true`** — `wait_until` with no signal returns a fault, and that
  fault is `thread::WAIT_TIMEOUT`. That is exactly the assumption
  `mailbox.c3:255-257` and `pool.c3:368-370` already carry.

**The design does not change.** The probe did not refuse.

**The scratch module was written outside `3tk/`, run from there, and removed.
`3tk/` is clean.**

---

## Verification

Run live on 2026-08-28, after the document was written and with no source
changed.

| check | result |
|---|---|
| `run-builds.sh` | **passed 67, failed 0 — all four builds green** |
| test suite, each build | **87 tests run** |
| `check-doc-loop.sh` | **0 differing blocks, 440 sentences, 439 found, 1 missing** |
| the one miss | the pre-existing `inner.c3` module summary. Unchanged by this stage |
| banned words, `3tk/src` + reference | **0** |
| banned words, this file | 0 in prose. One hit remains: the quoted `pool.c3:421` source line, and Part 5 exempts a stdlib call name |
| links | every link in this file printed and read |
