# 3tk — the lifetime fix

**Second version, 2026-08-28, written by INTR 4.** It supersedes
`3tk-lifetime-fix-001.md`, which is in `backup/`. **The one input to this
version is `3tk-bug-fixes-review.md`**, a review of `-001`. **All twenty of its
points are absorbed here** — nineteen into the sections named in *What changed
from `-001`*, and its recommendation table into *What the review recommended*.
**The review file has gone to `backup/` with `-001`**, and nothing needs to be
read out of it again.

**[3tk-staging-plan-020.md](3tk-staging-plan-020.md) names `-001` in three
places.** The plan is published and is not edited in place, so those lines stand
as written; **where it says `3tk-lifetime-fix-001.md`, this file is meant.**

**No question is answered by this version.** The review recommends; the owner
rules. Where the review's recommendation is recorded it is labelled as the
reviewer's, and the question stays open in section 16.

**No byte of `3tk/src`, `test/` or `negative/` was touched by the stage that
wrote this**, or by the stage that wrote `-001`.

**Inputs of `-001`, unchanged and not re-read here:**
[3tk-staging-plan-020.md](3tk-staging-plan-020.md),
[3tk-bugs- mailbox.md](<3tk-bugs- mailbox.md>),
[3tk-bugs-pool.md](3tk-bugs-pool.md),
[3tk-release-while-busy-001.md](3tk-release-while-busy-001.md),
[3tk-on-close-policy-001.md](3tk-on-close-policy-001.md), `3tk/src/mailbox.c3`
and `3tk/src/pool.c3`.

**Every line number below was printed live on 2026-08-28.** Re-print before
trusting them: every fix in 3TK-53 and 3TK-54 moves them.

**This document is versioned.** Every answer the owner gives to section 16 makes
`003`, `004`, and the superseded version moves to `backup/`. **A question and its
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

## 2. The lifetime invariant

**The review's first request, and the one everything else derives from.** It is
stated here, once, before any mechanism:

```text
Lifetime invariant

free(self) is legal only when:

    _closed == true
    _active == 0

Every operation raises _active before it can leave the mutex, and
lowers it only after its last access to self is complete.
```

The life cycle it describes:

```text
      ┌──────────────┐
      │     OPEN     │
      └──────┬───────┘
             │  close / release
             ▼
      ┌──────────────┐
      │    CLOSED    │   no new call may enter
      └──────┬───────┘
             │  the calls already inside finish
             ▼
      ┌──────────────┐
      │    QUIET     │   _active == 0
      └──────┬───────┘
             │  release
             ▼
      ┌──────────────┐
      │    FREED     │
      └──────────────┘
```

**3TK-53 and 3TK-54 implement against this, not against the prose.** The review's
§1 and its closing architecture asked for exactly that, and its point holds: a
mechanism section is not a specification until the invariant it serves is
written above it.

## 3. What counts as active

**The review's §6, and it corrects `-001`.** `-001` said *every call raises the
count on entry*, which is too vague — it invites an implementer to count the
operations that look like work.

The definition:

> **An active operation is any execution path that has acquired a valid
> reference to the tool and may still access its memory.**

Whether it is a public call, a hook window, or the tail of a `close` does not
enter into it. What enters into it is whether the memory can still be touched.

**Enumerated, so no site is missed:**

| Mailbox | active |
|---|---|
| `send` and every sending path | yes |
| `receive` | yes |
| the parked receiver in `wait_until` at `mailbox.c3:255` | yes |
| `close` | **yes — see section 4** |
| `release` | **no** |

| Pool | active |
|---|---|
| `get`, including its `on_get` hook at `pool.c3:321` | yes |
| `get_wait`, including the park at `pool.c3:368` | yes |
| `put`, including `on_put` at `pool.c3:422` and any straggler `on_close` at `pool.c3:434` | yes |
| `close`, including its own `on_close` at `pool.c3:493` | yes |
| queries that take the mutex — `count_of` at `pool.c3:511` and its neighbours | yes |
| `release` | **no** |

**`release` is never counted as active.** It would then wait for itself for ever.
Both advices say this in the same words — mailbox §8, pool *Second advice* §8.

## 4. `close` is itself an active operation

**Stated as a general rule, at the review's §5, rather than as a pool detail.**

`-001` made this point only about `Pool.close`'s hook. It is broader: `close`
holds a reference and keeps touching `self` after it has published the closed
flag, so `close` must be counted for its whole body or a concurrent `release`
frees the tool under it.

```text
Thread A                         Thread B

close()
    _active++
    ...
    _close()
    ...
                                 release()
                                     lock
                                     _close()   // already closed, no transfer
                                     wait for _active == 0
                                     ...
    ...
    _active--
                                 destroy; free
```

**This is why `release` vs `close` can be supported at all** — see section 10.
For the mailbox the counted region is short. For the pool it runs to the end of
`on_close`.

## 5. The mechanism both advices land on

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
release  lock; _close(); while _active != 0 -> wait; destroy; free
```

**The ordering, not the cost, is the requirement.** The review's §10 corrects
`-001`'s emphasis: *almost every call already holds the mutex* is a cost
argument, and it was standing where a rule belonged. The rule is:

> **Every raise and every lower of `_active` is under the same mutex, and the
> raise happens before the operation can execute outside that mutex.**

The three shapes that follow from it:

```text
hook-bearing call            waiting call              call that exits closed

lock                         lock                      lock
_active++                    _active++                 if closed:
...                          wait_until(...)               unlock
unlock                       ...                           return CLOSED
application hook             _active--                 _active++
lock                         unlock                    ...
...
_active--
unlock
```

**The wait terminates.** The precise statement is the pool advice's own
correction to the `Q5` document, and it is the one this port adopts:

> The closed flag prevents a call that acquires the mutex **after** closure from
> becoming active, so once closure is established the active count can only fall.

## 6. The API change, in the review's words

**The `always_assert` disappears from both.**

`-001` said *release closes if it must*. The review's §20 calls that misleading,
and it is: `release` is the complete life-cycle operation, and the wording hid
two of its three parts.

```text
close      transition to closed, and return.

release    transition to closed if necessary,
           wait for quiescence,
           destroy.
```

**`close` is not required before `release` any more.** The two negative programs
that prove today's rule therefore **invert** — see section 15.

**What `Part 11.12` says today** is *closed before released*, and it is a tier 1
MUST that aborts in every build mode. What replaces it is section 11's clause,
and **it is not 3tk's to write** — that is 3TK-52.

## 7. The private primitive

`_close()` runs **with the mutex already held**. It is the state change both
public paths share, and nothing else.

| it does | it never does |
|---|---|
| returns at once if already closed | take the mutex |
| sets `_closed` | release the mutex |
| publishes `_closed_fast` with RELEASE | call a hook |
| empties what the tool holds into the caller's storage | destroy anything |
| broadcasts on the condition variable | free anything |

**Calling it twice is safe, and the second call transfers nothing.** The review's
§4, and it is a correction: `-001` said *returns at once if already closed*
without saying what happens to the caller's storage, and both public paths share
this primitive.

```text
close(&queue1)      // closes; the contents move to queue1
release(&queue2)    // already closed: no transfer, queue2 is left untouched
```

> **If the tool is already closed, `_close` performs no transfer and leaves
> `out` exactly as it found it.**

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

## 8. The destruction ordering, and what is not yet known

**The review's §11, and it is the one place where `-001` prescribed code it had
not earned.** `-001` wrote the release line as `... ; destroy; free`, which
leaves the question that decides whether the code compiles and runs:

> **When is the mutex unlocked, and can it be destroyed while it is held?**

The conceptual sequence:

```text
release:
    lock
    _close(out)

    while _active != 0:
        wait

    destroy whatever does not need _mu
    unlock _mu
    destroy _mu
    destroy _cv
    allocator.free(self)
```

**That order is a sketch and not a ruling.** The exact order is whatever C3's
`Mutex` and `ConditionVariable` require, and **3TK-53 establishes it against the
real structs before either tool is changed.** Neither this document nor the
feasibility probe settles it — see section 17.

## 9. Pool specifics, and the detail that decides the implementation

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
after the mutex is released at `:490` — section 4's rule at its longest site.

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

## 10. Mailbox specifics

**The mailbox has no hook, so it is the mechanism without the hard part.** Its
waiting path holds the mutex across `wait_until` at `mailbox.c3:255`, so a parked
receiver is covered by the same field with no special handling.

**`_close(InnerQueue* out)` writes into caller-owned storage.** The mailbox still
never allocates for the outers it gives back — the property `close` has today at
`mailbox.c3:327`, kept.

**A mailbox has no hook, and therefore no destination for what it still holds.**
The review's §3 promotes this from a matter of style to a requirement, and the
promotion is adopted here as the *statement of the problem*, not as its answer:

> **An open mailbox cannot be released safely without transferring the items it
> still holds to somewhere the caller owns.**

`-001` presented the parameter as one story across `close` and `release`. It is
more than that: without it, releasing an open mailbox discards items silently,
which the port does nowhere else.

```c3
fn void  Mailbox.close(&self, InnerQueue* out)      // today, unchanged
fn void  Mailbox.release(&self, InnerQueue* out)    // the proposal
```

Both would assert `out.is_empty()` on entry, as `close` does today at
`mailbox.c3:330`. **Whether `release` gains the parameter is the owner's** —
section 16, `Q-B`, and section 12 is why that question is now a blocking one.

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

## 11. Lifetime waiting is not hook serialization

**The review's §8, §9 and §13, and it is the sharpest thing the review says.**
`-001` stated the contradiction in section 7 and left the reader to hold two
mechanisms in one word. They are two mechanisms:

```text
_active                          hook serialization

lifetime protection              application synchronization
"has everyone left?"             "may B start before A ends?"
```

The difference, drawn:

```text
serialization                    lifetime waiting

hook A                           hook A ────────┐
   ↓                                            ├── release waits
hook B                           hook B ────────┘
                                                ↓
                                              free
```

**A pool may run A and B concurrently and still guarantee that release waits for
both.** Nothing in the lifetime invariant asks for an order between hooks; it
asks only that none of them is still running when the memory goes.

The straggler path is the case that shows it:

```text
put                       close                     release
 ├── _active++             ├── _active++             ├── close state if needed
 ├── on_put                ├── close state           ├── wait _active == 0
 ├── discovers closed      ├── on_close(batch)       └── destroy, free
 ├── on_close(stragglers)  └── _active--
 └── _active--
```

**No hook serialization appears anywhere in it**, and the lifetime guarantee
holds all the same.

## 12. The contradiction the review found: `Q5` against `Q-B`

**The review's §2, and it calls this the biggest problem in `-001`. It is not a
subordinate question, and this section exists so it is not read as one.**

The `Q5` ruling of 2026-08-27 rests on:

> the client's code is unaffected either way

Section 10's proposal is:

```c3
mbox.release();          // today
mbox.release(&iq);       // proposed
```

**That is a client API change.** So `-001` carries two statements that cannot
both stand:

1. `Q5` was ruled on the basis that client code does not change.
2. `Q-B` proposes a public signature change that necessarily changes client code.

**The port cannot resolve this**, because one half of it is a ruling the owner
took. The review names the two ways out, and both are the owner's:

- **re-word the `Q5` ruling** to something like: *the lifetime fix must not
  require clients to change the lifetime protocol, but it may require a public
  signature change where the question of who owns the items demands it*; or
- **hold "no client code changes" as absolute**, in which case `Q-B` is rejected
  and a different destination for an open mailbox's items has to be designed.

**The review would not let 3TK-53 start until this is resolved**, and this
document records that as the reviewer's position. `Q-B` is therefore listed in
section 16 as blocking, alongside `Q-A`.

## 13. Who may release

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

**Why that last row is not arbitrary**, at the review's §16. It reads as a
concurrency rule and it is a rule about who owns the destroying:

> `get`, `put` and `close` are **operations on** the tool. `release` is the
> **destruction of** the tool.

An ordinary operation may race destruction because destruction waits for it.
Two destructions cannot both own the destroying.

## 14. The boundary the fix cannot cross

**Two races, and only one of them is the port's.** The review's §7 asks for them
to be named, because *release waits for calls* reads as a stronger promise than
it is.

**Race A — the operation has already entered. Protected.**

```text
put()
  ↓
_active++
  ↓
             release()
                ↓
              waits
```

**Race B — the pointer is stale and the operation has not entered. Not
protected.**

```text
thread A:  p.put()      // not yet inside p
thread B:  p.release()  // closes, waits, frees
thread A:  p.put()      // enters freed memory
```

**No counter inside the freed memory can help.** The counter and the mutex
guarding it are in the memory being freed, which is the same defect one level
down — the `Q5` document said this first, under *A counter alone narrows the
race*.

So the clause says exactly this and not one word more:

> **`release` synchronizes with operations that have entered the tool. It does
> not extend the lifetime of a tool referenced by a thread that has not yet
> entered an operation.**

That is an ordinary lifetime boundary and it belongs to the application.

## 15. What stays unchanged

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

## 16. What it costs

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

## 17. The `P6` interaction

`P6` — the pool cannot tell whether the close hook processed the items it was
given or dropped them — keeps its own question, unchanged.

**`-001` said its option 1 is unblocked. The review's §14 narrows that, and the
narrowing is adopted:**

> **Q5 removes the lifetime blocker for `P6` option 1. It does not answer
> `P6`'s own question of who owns what, and of what is counted.**

What is removed is real: counting what went out against what came back means
nothing while a further `on_close` may still arrive from a straggler `put`, and
**after 3TK-54 there is a moment when no further `on_close` can arrive** —
release has waited, `_active` is zero, and the pool is quiet.

What is not removed is *what came back* means. The hook is handed an
`InnerQueue*` and may free items, leave items, or both:

```text
queue handed to hook
hook frees 3 items
hook leaves 2 items in the queue
```

Whether the pool observes *2 came back*, or whether the queue is the hook's from
that moment on, is the `InnerQueue` contract for who owns what, and it is not written
down. **`P6` stays the owner's, and it needs that contract before its option 1
can be called ready.**

## 18. The negatives this fix owes

Named here, built in 3TK-53 and 3TK-54. **None of them has to be a flaky race.**
A hook that parks until the main thread has called release is a deterministic
trigger for exactly the window, and the port already has that shape in
`test/t_concurrency.c3`.

| file | stage | what it proves |
|---|---|---|
| `negative/release_open_mailbox.c3` | 53 | **inverts.** Releasing an open mailbox becomes the normal path: the program now runs to its last line where it used to abort |
| `negative/release_while_receiving.c3` | 53 | a receiver parked in `receive`, the owner releasing. Deterministic: the receiver holds the mutex across `wait_until` |
| `negative/release_vs_close_mailbox.c3` | 53 | **new, at the review's §15.** One thread closes, another releases. Proves: no double close, no use after free, no deadlock, and exactly one destruction |
| `negative/release_open_pool.c3` | 54 | **inverts**, the same way |
| `negative/release_during_on_put.c3` | 54 | **Test A.** `on_put` parks until the main thread has called release, then returns. Without the fix, undefined behaviour; with it, release waits and the program finishes |
| `negative/release_during_on_close.c3` | 54 | **Test B.** `_active` covers `close`'s own hook — the hook side of section 4 |
| `negative/release_vs_close_pool.c3` | 54 | **new.** The pool's version of the §15 case: `close` racing `release` as *operations*, distinct from Test B, which parks inside the hook |
| `negative/release_with_straggler_put.c3` | 54 | **Test C**, the most valuable pool-specific one: a concurrent put produces the second `on_close`, and release waits for both calls |

**Both `release_open_*` programs are TIER 1 in `run-builds.sh`** — they must
abort in all four builds today. When they invert they stop being tier 1 and
become ordinary programs that run to the end in every build. **`run-builds.sh`
changes in the same stage**, and the moved check count is printed, not assumed.

Two test-suite cases go with them:

- `test/t_mailbox.c3` — the reverse-order `defer` case of section 10, run.
- `test/t_pool.c3` — `get_wait` parked when release runs: the close broadcast
  wakes it, it reports `CLOSED`, the count falls, release completes.
- `test/t_concurrency.c3` — release racing a sender, repeated, under
  `run-sanitizers.sh` as well as `run-builds.sh`.

## 19. Open questions

**Every question this work raises. They are not asked outside this document.**
An answer makes the next version of this file, with the answer written into the
section it belongs to.

**Split into two lists at the review's §17 and §18**, which found seven questions
of three different kinds sitting in one list and no way to see which of them
stops the code. **The split changes no question's content and rules none of
them.**

### Blocking — 3TK-53 and 3TK-54 cannot be written without these

#### `Q-A` — hook serialization. **The one that decides 53 and 54.**

Does `on_close` wait for the `on_get` and `on_put` calls already in flight?

- **Variant 1 — no serialization.** The counter is a lifetime mechanism only.
  `Part 12.2` and `Part 12.3` stand; a straggler `put` still produces a second
  `on_close`; `put`'s branch at `pool.c3:425-436` stays. *Second advice* §5 and
  §15. **Nothing outside 3tk changes.**
- **Variant 2 — serialization.** One closing phase. `close` waits for in-flight
  calls before its hook, and the straggler branch goes. §4, §8, §17, §30.
  **Reopens a shared-specification clause ruled and closed on 2026-08-27.**

Section 20 holds the full comparison, and section 11 is the distinction the
review says makes Variant 1 possible without loss.

**The reviewer recommends Variant 1**, on the grounds that making `_active`
serialize hooks turns a lifetime mechanism into an application-execution policy
and changes `Part 12.2` and `12.3`. **Not ruled.**

#### `Q-B` — does `Mailbox.release` gain `InnerQueue* out`?

The mailbox advice's §4 and §13 recommend it. **Section 12 is why this question
is blocking**: it contradicts the `Q5` ruling's *the client's code is unaffected
either way*, and the contradiction is the owner's to resolve — either by
re-wording that ruling or by rejecting `Q-B` and designing another destination
for an open mailbox's items.

**The reviewer recommends yes, and calls it required rather than stylistic**,
because otherwise an open mailbox's items have no owner after release. **Not
ruled.**

#### `Q-C` — does `Pool.release` gain one too?

Or does it keep giving everything to `on_close`, as `Pool.close` does today at
`pool.c3:493`? The pool has a hook and the mailbox does not, so the two answers
need not match. **A pool that grew an `out` parameter would have two ways to hand
back the same items.**

**The reviewer recommends no**, for that reason. **Not ruled.**

#### `Q-D` — the shared-specification rule.

`-001` asked *does 3TK-52 run before the code?*. The review's §19 says that is
the procedural half of a semantic question, and both halves are asked here:

1. **Does the Matryoshka specification require `release` to wait until every
   operation already in flight has returned?**
2. If it does, must every port implement it before claiming conformance — and
   therefore does 3TK-52 run before 3tk's code, or does 3tk go first under a
   written assumption naming which way it assumed?

The vocabulary **closed / quiet / freed** is useful across all ports and the
specification should carry it either way.

**The reviewer recommends yes to the first**, on the grounds that this is a
semantic contract and not a 3tk implementation detail. **Not ruled.**

### Tracking — real, and not design questions

#### `Q-E` — where does 3TK-50 fall?

The examples tree does not depend on this fix and this fix does not depend on it.
What this document owes it is one line, and nothing more:

> **3TK-50's examples must be rewritten if the public `release` signature
> changes — `Q-B`.**

The ordering itself is the owner's, in the status file.

#### `Q-F` — `P6`'s ruling.

Its lifetime blocker is removed by 3TK-54. Its question of who owns what
is untouched and stays the owner's. Section 17.

#### `Q-G` — does `W3` go in at all?

[3tk-release-while-busy-001.md](3tk-release-while-busy-001.md) left this open: a
one-sentence warning on both `release` descriptors saying the port does not yet
stop a release that races a call in flight. **If 3TK-53 and 3TK-54 run, it is
written in and out again within days**, and it costs a doc loop and a reference
version each way. **Documentation scheduling.**

**The seven questions plan 018 left and 019 carried are still open**, and are not
restated here.

## 20. The contradiction, stated and not resolved here

**The two halves of the pool advice disagree, and they cannot both hold.**

| | first half — §4, §8, §17 *Contract 2*, §29 item 12, §30 | second half — *Second advice* §5, §15 |
|---|---|---|
| **rule** | `on_close` MUST NOT start until the calls already in flight have finished | the lifetime counter MUST NOT become a hook serializer |
| **effect on `Part 12.2`** | the second `on_close` from a straggler `put` disappears | it stays, exactly as specified |
| **what it costs** | `close` blocks on application code it does not control; a slow `on_put` stalls every closer; `Part 12.2` and [3tk-on-close-policy-001.md](3tk-on-close-policy-001.md) are both reopened, and that file was ruled and closed on 2026-08-27 | a hook writer must still tolerate two concurrent `on_close` calls, which is what `Part 12.3` already tells them |
| **what it gains** | one closing phase, easy to explain; `put`'s straggler branch at `pool.c3:425-436` can go | no new promise, no new blocking, the spec unchanged |

**Filed as `Q-A` in section 19. It is the question that decides how 3TK-53 and
3TK-54 are written**, and no stage takes it.

**What the port can say without ruling it:** the current code is correct against
the specification as written. `Part 12.2` says `on_close` is *called once by
close — and once more for each put that discovers the pool closed while its own
hook was running*, and `Part 12.3` says several hooks run at once and the pool
does not serialize them. **Hook serialization would be a change to the shared
specification, not to 3tk.**

---

## The feasibility probe, and what it does not prove

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

**What it does not prove.** `-001` closed with *the design does not change; the
probe did not refuse*, and the review's §12 calls that broader than the evidence.
It is narrowed here:

> **The probe validates the synchronization pattern the mechanism needs. It says
> nothing about the correctness of the Mailbox or the Pool implementation.**

Outside its reach, and each one belonging to 3TK-53 or 3TK-54:

- the real mailbox and pool life cycles;
- hook lifetime at the real call sites;
- a concurrent `close`, and a concurrent `release`;
- **the destruction ordering inside the real structs** — section 8;
- the memory ordering around `_closed_fast`;
- where `_active` lands in the locking protocol each tool already has.

**The design does not change on the strength of the probe alone**, but nothing
in the probe asks it to.

**The scratch module was written outside `3tk/`, run from there, and removed.
`3tk/` is clean.**

---

## What the review recommended

**Recorded as input. None of it is ruled**, and the port's rule holds: a review
describes, the owner decides.

| question | the reviewer's recommendation | the reason given |
|---|---|---|
| `Q-A` hook serialization | **no serialization** | keeps `Part 12.2` and `12.3`, and keeps lifetime separate from hook synchronization |
| `Q-B` `Mailbox.release(out)` | **yes, probably required** | otherwise an open mailbox's items have no owner after release |
| `Q-C` `Pool.release(out)` | **no** | `on_close` already gives the pool a way to hand items back |
| `Q-D` shared spec first | **yes** | it is a semantic contract, not a 3tk implementation detail |
| `Q-E` scheduling | **track it, do not design it** | project ordering |
| `Q-F` `P6` | **keep separate** | the fix removes its blocker, not its own question |
| `Q-G` `W3` | **track it** | documentation scheduling |

**And its one blocking condition**, which the owner may take or refuse:

> 3TK-53 and 3TK-54 should not start until the `Q5`-against-`Q-B` contradiction
> is resolved, no-serialization is confirmed, `_active` is defined including
> `close`, the destruction ordering is established, and the shared-specification
> rule is decided.

**Three of those five are done in this version** — `_active` is defined in
sections 3 and 4, the serialization distinction is drawn in section 11, and the
destruction ordering is scoped and handed to 3TK-53 in section 8. **Two are the
owner's**: `Q-B` with section 12, and `Q-D`.

---

## What changed from `-001`

| section | change | from |
|---|---|---|
| 2 | **new.** The lifetime invariant and the state diagram, stated before any mechanism | review §1, closing architecture |
| 3 | **new.** *Active operation* defined, and every site enumerated for both tools | review §6 |
| 4 | **new.** `close` is itself an active operation, as a general rule | review §5 |
| 5 | the ordering rule replaces the cost claim as the requirement; the three call shapes drawn | review §10 |
| 6 | `release closes if it must` rewritten as the three-part life-cycle operation | review §20 |
| 7 | `_close` may be called twice, and the second call transfers nothing | review §4 |
| 8 | **new.** The destruction ordering, sketched and handed to 3TK-53 rather than prescribed | review §11 |
| 10 | the mailbox's `out` parameter restated as a requirement about who owns the items | review §3 |
| 11 | **new.** Lifetime waiting is not hook serialization | review §8, §9, §13 |
| 12 | **new.** The `Q5`-against-`Q-B` contradiction, raised to a section of its own | review §2 |
| 13 | why `release vs release` is about who owns the destroying, not about concurrency | review §16 |
| 14 | Race A and Race B named; the clause reworded to the narrower promise | review §7 |
| 17 | `P6`'s blocker removed, its own question explicitly not answered | review §14 |
| 18 | two new negatives: `release` racing `close`, on each tool | review §15 |
| 19 | the seven questions split into blocking and tracking; `Q-D` restated semantically | review §17, §18, §19 |
| the probe | what it does not prove, listed | review §12 |
| this table and *What the review recommended* | **new** | INTR 4 |

**Nothing was removed.** Every section of `-001` is here, renumbered where the
new sections landed above it.

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
| banned words, this file | **0 in prose.** Six hits remain, every one of them the word `unlock` inside a code block — the quoted `pool.c3:421` source line and five lines of pseudo-code. Part 5 exempts a stdlib call name |
| links | every link in this file printed and read |
