# 3tk — staging plan 020

Written 2026-08-27, after the implementation review interrupted the flow.

**Provenance.** Follows [3tk-staging-plan-019.md](3tk-staging-plan-019.md). 019
declared **3TK-48 to 3TK-50**; 48 and 49 have run and **3TK-50 has not**. This
plan carries 3TK-50 forward unchanged and declares **3TK-51 to 3TK-55**.
**Declared, not authorized.** The owner names a stage before it runs.

State is in [3tk-status.md](3tk-status.md). Narrative is in
[3tk-log.md](3tk-log.md). Neither is duplicated here.

---

## Why this plan exists

**The port can free memory another thread is still using, and it is the only
defect left that the port knows about and does not stop.**

It is tracked as `Q5` in [3tk-open-defects.md](3tk-open-defects.md), ruled on
2026-08-27 — **the port enforces it** — and built out in
[3tk-release-while-busy-001.md](3tk-release-while-busy-001.md). It was deferred
the same day because nothing downstream waited on it.

**Two advice files arrived after that**, and they are what makes a plan
necessary rather than a single stage:

- [3tk-bugs- mailbox.md](<3tk-bugs- mailbox.md>) — the mailbox, in 17 sections.
- [3tk-bugs-pool.md](3tk-bugs-pool.md) — the pool, in 30 sections, plus a second
  independent analysis appended under *Second advice*.

**They describe one defect on two objects.** `Mailbox.release` at
`mailbox.c3:106` and `Pool.release` at `pool.c3:231` both open with

```c3
always_assert(self._closed, "releasing an open ...");
```

and that assertion answers the wrong question. **`_closed` is state. It is not
lifetime.** A call that entered before the close is still inside the object when
release frees it.

**The pool is the worse of the two, by design and not by accident.**
`Part 12.3` MUST forbids holding the mutex across a call into application code,
so `Pool.put` opens it itself:

```
pool.c3:421:    self._mu.unlock();
pool.c3:422:    self._hooks.on_put(in_pool, &mine, &extra);
pool.c3:423:    self._mu.lock();
```

The window is wide, deliberate, and specified. `:423` relocks a mutex that a
concurrent release may already have destroyed and freed.

**The two advices agree on the mechanism and disagree on one rule.** That
disagreement is the reason 3TK-51 exists and is a document rather than a patch.

## The stages

Five, **declared and not authorized**. 3TK-50 is unaffected and can run before,
after or between them — see *What this plan leaves to the owner*.

```
3TK-51   the accumulated description        a document, and one live probe
   |
3TK-52   the shared-specification clause    ../common/ + the finding
   |
3TK-53   Mailbox, in code                   src/ + test/ + negative/ + ref/
   |
3TK-54   Pool, in code                      src/ + test/ + negative/ + ref/
   |
3TK-55   close the books                    the three edited-in-place files
```

**The order is forced, not chosen.**

- 51 states the choice; 53 and 54 cannot be written until it is made.
- 52 is a promise every port owes, and 3tk must not make it alone.
- 53 before 54 because the mailbox has no hook, so it is the same mechanism
  without the hard part. If it does not work there it will not work in the pool.
- 55 cannot record numbers that do not exist yet.

**Five stages means five clear points.** Each ends with the clear advice and the
exact line to continue with, written into [3tk-log.md](3tk-log.md) and
[3tk-status.md](3tk-status.md).

---

## 3TK-51 — the accumulated description

**Output: `3tk-lifetime-fix-001.md`.** One document, merging both advices. **No
byte of `3tk/src`, `test/` or `negative/` is touched.**

**Inputs, and nothing else is needed:** this plan, the two advice files,
[3tk-release-while-busy-001.md](3tk-release-while-busy-001.md),
[3tk-on-close-policy-001.md](3tk-on-close-policy-001.md), `3tk/src/mailbox.c3`
and `3tk/src/pool.c3`.

### What the document holds

**1. The one defect, on two objects.** Three states, not two: *closed*, *nobody
inside*, *freed*. Today the port checks the first and acts as though it had
checked the second.

**2. The mechanism both advices land on.** A plain `usz _active` under the
existing mutex — **no atomic**, because both objects already own a `Mutex` and a
`ConditionVariable`, and almost every call already holds the mutex. `release`
waits on the condition variable until `_active` is zero. **`release` is never
counted as active**, or it waits for itself.

**3. The API change.** The `always_assert` disappears from both. `release`
closes if it must, waits, then destroys. `close` stays what it is: the
non-destructive client call.

**4. The private primitive.** `_close()` runs with the mutex **already held**:
marks closed, publishes `_closed_fast`, drains, broadcasts, hands back the
remainder. It never locks, never unlocks, never calls a hook, never destroys,
never frees. Both public paths go through it, so **`release` never calls public
`close`** and no lock nests.

**5. Mailbox specifics.** `_close(InnerQueue* out)` writes into caller-owned
storage, so the mailbox still never allocates for the outers it gives back.
`release` takes the same `out` argument. The reverse-order `defer` pattern from
the advice's §11 and §12 is documented — and, in 3TK-53, run rather than
reasoned about.

**6. Pool specifics, and the detail that decides the implementation.** `_active`
must cover the **whole** operation, hook window included: raised before the
unlock at `pool.c3:421`, lowered only after the relock **and** after any
straggler `on_close` at `:434`. `Pool.close` must stay active through its own
`on_close` at `:493`, or a release frees the pool while close's hook is running.
`get_wait` counts as active and leaves on the close broadcast. **Locking the
mutex is not a lifetime mechanism** — the mutex is free while a hook runs, which
is exactly the window.

**7. The contradiction, stated and not resolved by the stage.** The pool advice's
first half (§4, §8, §17 *Contract 2*) recommends that `on_close` not start until
in-flight operations have finished — **hook serialization**. Its second half
(*Second advice* §5 and §15) says the opposite: do not turn the lifetime counter
into a hook serializer, and keep the `Part 12.2` behaviour where a late put calls
`on_close` again. **They cannot both hold.** The document states both, with what
each costs, and files it as an open question.

**8. The ownership rule.** What replaces *We never guard simultaneous releases -
by design* in
[3tk-release-while-busy-001.md](3tk-release-while-busy-001.md): concurrent
operations are supported, concurrent `release` is not. **Single-owner
destruction, written down** rather than left standing as an unguarded race.

**9. The boundary the fix cannot cross.** A caller holding a pointer who has not
yet entered cannot be protected by anything inside the object. The clause says
**release waits for calls already in flight**, and not one word more.

**10. What stays unchanged**, from both advices, so no stage widens the work:
the flat bucket lookup, `broadcast` after put, `count_of` answering 0 for an
unknown identity, `take_back_handle` as a hard failure (ruled 2026-08-27), the
stale `in_pool` hint, no `put_all`.

**11. What it costs.** **`release` stops being a call that cannot block.** That
is the design change, and it is what the other ports would inherit.

**12. The `P6` interaction.** `P6`'s option 1 — count what went out, count what
came back — needs this work first, because a count means nothing until there is a
moment when no further `on_close` can arrive.

**13. The negatives the fix owes**, named here and built in 53 and 54. **None of
them has to be a flaky race**: a hook that parks until the main thread has called
release is a deterministic trigger for exactly the window.

**14. Open questions, with the variants.** Every question this work raises, each
with the answers the two advices offer and what each one costs. **They are not
asked outside this document.** See *Versioning* below for how an answer lands.

### The feasibility probe

**One C3 fact the whole mechanism rests on, measured and not argued.** A scratch
module compiled against `3tk/src` in **all four builds**: a counter under a
mutex, a waiter blocking on the condition variable until it reaches zero, the
condition variable and mutex destroyed afterwards, and `wait_until` behaving as
the port already relies on.

**What it prints is recorded in the document.** **If the probe refuses, the
design changes in 3TK-51 and not in 3TK-53.** The scratch output is removed
afterwards, and `3tk/` is left clean.

**Verification:** `run-builds.sh` green with the counts stated, even though no
source changed. `check-doc-loop.sh` unchanged. Ban scan 0 over the new file.
Every link printed and read.

---

## 3TK-52 — the shared-specification clause

**`Part 11.12` is not 3tk's.** It lives in
[../common/matryoshka-specification-004.md](../common/matryoshka-specification-004.md),
its whole content today is *closed before released*, and it binds otk, ztk and
dtk as well. **Adding *quiet before released* is a clause every port owes.**

**So 3tk is discovering the clause, not implementing one.** The port must not
grow a promise the other three do not make, or the ports disagree about what a
release means.

**Output**, whichever the owner rules:

- **`../common/matryoshka-specification-005.md`**, `-004` moved to
  `common/backup/`, every cross-reference in every port's folder repointed; or
- **a written ruling that 3tk runs ahead under a stated assumption**, recorded in
  the lifetime document's next version, so 53 and 54 say which way they assumed.

**The finding goes to `3tk-port-findings-004.md`**, `-003` to `backup/` — the
port's existing channel for what it learned, and it recommends nothing.

**Tests: none.** No code changes. `run-builds.sh` is run anyway, as this folder
does for a document stage.

---

## 3TK-53 — Mailbox, in code

`_active`, `_close(InnerQueue* out)`, `release(InnerQueue* out)`, the
`always_assert` removed, the `2DO` block at `mailbox.c3:108-112` written out.

**The tests, and the stage does not close without them green.**

| file | what it proves |
|---|---|
| `negative/release_open_mailbox.c3` | **rewritten.** Releasing an open mailbox stops being an abort and becomes the normal path, so what this program proves **inverts**: it now runs to the end where it used to abort |
| `negative/release_while_receiving.c3` | **new.** A receiver parked in `receive`, the owner releasing. Deterministic — the receiver holds the mutex through `wait_until` |
| `test/t_mailbox.c3` | the reverse-order `defer` case from advice §11 and §12, **run rather than reasoned**: `defer queue_outers_release(&iq);` declared before `defer mbox.release(&iq);`, asserting the client function received the queue full |
| `test/t_concurrency.c3` | release racing a sender, repeated, under `run-sanitizers.sh` as well as `run-builds.sh` |

**Each new negative is added to `run-builds.sh`**, so the check count moves. The
new number is printed, not assumed.

**`ref/` is revised in the same stage** — the reference becomes
**`3tk-reference-005.md`** and the decisions **`3tk-decisions-004.md`**, the
superseded pair to `backup/`, every citation re-anchored. **The doc loop is
owed** and runs before the stage closes. **`W3`'s warning is written out** where
it was owed, because enforcement has landed for the mailbox.

---

## 3TK-54 — Pool, in code

The same mechanism, with the hook window and the straggler path handled
explicitly, and the `2DO` block at `pool.c3:233-238` written out.

**The tests, and the stage does not close without them green.**

| file | what it proves |
|---|---|
| `negative/release_open_pool.c3` | **rewritten**, the same inversion as the mailbox one |
| `negative/release_during_on_put.c3` | **Test A.** An `on_put` hook that parks until the main thread has called `release`, then returns. Without the fix, undefined behaviour; with it, release waits and the program finishes |
| `negative/release_during_on_close.c3` | **Test B.** `_active` covers `close`'s own hook |
| `negative/release_with_straggler_put.c3` | **Test C**, the most valuable pool-specific one: a concurrent put produces the second `on_close`, and release waits for both operations |
| `test/t_pool.c3` | `get_wait` parked when release runs — the close broadcast wakes it, it reports `CLOSED`, the count falls, release completes |

**Each new negative is added to `run-builds.sh`** and the moved check count is
printed.

**`ref/` is revised in the same stage**, reference and decisions each taking the
next version with the superseded pair to `backup/`. **The doc loop is owed** and
runs before the stage closes. **`W3` is written out** at `pool.c3` too, and
[3tk-release-while-busy-001.md](3tk-release-while-busy-001.md) is marked spent.

---

## 3TK-55 — close the books

- **[3tk-open-defects.md](3tk-open-defects.md)**: `Q5` moves from DEFERRED to
  fixed, its section left standing as the record. **`P6` is re-stated**, because
  its option 1 is no longer blocked. *Order* is rewritten in the same edit.
- **[3tk-status.md](3tk-status.md)** and **[3tk-log.md](3tk-log.md)** updated,
  with the resume point rewritten for whatever comes next.
- **Every number re-measured live** — builds, checks, tests, the doc loop's four,
  and the two `item` counts. Nothing carried forward from an earlier stage's row.

---

## Rules that hold for all five

- **Every stage ends with `3tk/run-builds.sh` green and the counts stated** —
  four builds, 67 checks, 87 tests as this plan starts.
- **Every stage ends by saying whether the owner may clear or should compact,
  and prints the exact line to continue with**, written into
  [3tk-log.md](3tk-log.md) and [3tk-status.md](3tk-status.md). **The owner's
  standing requirement.** Advice that exists only in a conversation about to be
  cleared is worth nothing.
- **A stage that finds itself deciding reports instead.** 3TK-19's precedent.
- **A stage that finds itself inventing prose reports instead.**
- **A claim about C3 is measured with `c3c`**, never argued. That is what the
  3TK-51 probe is for.
- **A change to `3tk/src` revises `ref/` in the same stage.** Not later, and not
  as a debt. A `ref/` file that contradicts `3tk/src` is a defect of the stage
  that changed the source — the owner's ruling, 2026-08-25.
- **Line numbers are re-printed before they are trusted.** Every fix in 53 and 54
  moves them, and every number in the two advice files and in this plan is a
  measurement of 2026-08-27.
- **`ref/3tk-example-rules-001.md`'s first rule binds anything these stages
  write**: **Outer**, never `Item`.
- **No stage runs `git`.** Moves are plain `mv`. The owner saves.
- **No stage tells dtk or otk anything.** 3TK-52 writes a finding; it does not
  write to another port's folder.
- **Nothing cites `backup/` as a source of truth.** The owner empties it.

## Versioning

Three files are edited in place — [3tk-status.md](3tk-status.md),
[3tk-log.md](3tk-log.md) and [3tk-open-defects.md](3tk-open-defects.md).
**Everything else this plan produces is versioned.**

- **`3tk-lifetime-fix-001.md`** is new at 3TK-51. **Every answer the owner gives
  makes the next version** — `002`, `003` — with the superseded one moved to
  `backup/`. **A question and its answer live inside that document**, never only
  in a conversation, so a cold session finds both.
- `ref/3tk-reference-004.md` and `ref/3tk-decisions-003.md` are revised by 53 and
  by 54, each taking the next number, the superseded one to `backup/`.
- `3tk-port-findings-003.md` becomes `004` at 3TK-52.
- `../common/matryoshka-specification-004.md` becomes `005` if 3TK-52 is ruled
  that way, and the move is `common/backup/`.

## What this plan leaves to the owner

Named so no stage picks them up by accident. **All of them are written into
`3tk-lifetime-fix-001.md` as open questions with their variants; none is asked
outside it.**

- **Hook serialization.** Does `on_close` wait for in-flight `on_get` and
  `on_put`, as the pool advice's first half recommends, or do the hooks stay
  unserialized and `on_close` stay callable twice, as its second half and
  `Part 12.2` and [3tk-on-close-policy-001.md](3tk-on-close-policy-001.md) have
  it? **This is the one that decides how 53 and 54 are written.**
- **Whether `Mailbox.release` gains an `InnerQueue* out` parameter.** That is a
  signature change on a public call, and the `Q5` ruling of 2026-08-27 rested on
  the client's code being unaffected either way.
- **Whether `Pool.release` gains one too**, or keeps handing everything to
  `on_close`.
- **Whether 3TK-52 runs before the code**, or 3tk goes first under a written
  assumption.
- **Where 3TK-50 falls** — before this plan's stages, after them, or between.
  The examples tree does not depend on the lifetime fix, and the fix does not
  depend on the examples; but 50 writes example code that a changed `release`
  signature would then have to be rewritten in.
- **`P6`'s ruling**, still open and still the owner's — the pool cannot tell
  whether the close hook freed what it was given. Its option 1 is unblocked by
  3TK-54.
- **The seven questions plan 018 left and 019 carried**, all still open.
