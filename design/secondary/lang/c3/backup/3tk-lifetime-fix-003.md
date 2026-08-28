# 3tk — the lifetime fix

**Third version, 2026-08-28, written by INTR 5.** It supersedes
`3tk-lifetime-fix-002.md`, which is in `backup/` with `-001`.

**The one input to this version is a thirty-three-point review of `-002`** — a
second round, by the reviewer who read `-001`. **Its findings are incorporated
into the sections listed in *What changed from `-002`***, and **five of them are
deliberately not acted on**; the five and the reason are in *What this version
did not do*.

**Both reviews are in `backup/`** — `3tk-bug-fixes-review-002.md` for this
round, `3tk-bug-fixes-review.md` for the one that made `-002`. **Neither needs to
be read again**; the first round's findings are in *What changed from `-001`*,
which is kept below.

**[3tk-staging-plan-020.md](3tk-staging-plan-020.md) names `-001` in three
places.** The plan is published and is not edited in place, so those lines stand
as written; **where it says `3tk-lifetime-fix-001.md`, this file is meant.**

**No question is answered by this version.** The review recommends; the owner
rules. Where a recommendation is recorded it is labelled as the reviewer's, and
the question stays open in section 19.

**`Q-A` is not ruled, and this document is written against one of its two
variants.** The second review's §1 found that `-002` declared `Q-A` open and then
wrote six sections as though Variant 1 already held. **That is now stated instead
of leaked** — see *The working assumptions* below — and every section that
depends on it carries the tag `[Variant 1]`.

**No byte of `3tk/src`, `test/` or `negative/` was touched by the stage that
wrote this**, or by either of the two before it.

**Inputs of `-001`, unchanged and not re-read here:**
[3tk-staging-plan-020.md](3tk-staging-plan-020.md),
[3tk-bugs- mailbox.md](<3tk-bugs- mailbox.md>),
[3tk-bugs-pool.md](3tk-bugs-pool.md),
[3tk-release-while-busy-001.md](3tk-release-while-busy-001.md),
[3tk-on-close-policy-001.md](3tk-on-close-policy-001.md), `3tk/src/mailbox.c3`
and `3tk/src/pool.c3`.

**Every line number below was printed live on 2026-08-28.** Re-print before
trusting them: every fix in 3TK-53 and 3TK-54 moves them.

**This document is versioned.** Every answer the owner gives to section 19 makes
`004`, `005`, and the superseded version moves to `backup/`. **A question and its
answer live here**, never only in a conversation.

---

## 0. The working assumptions

**Three things this document assumes, none of them ruled.** They are here, at the
top, because `-002` assumed all three silently and the second review's §1, §2 and
§8 found each of them written into a later section as though it were decided.

| assumption | the question it pre-empts | what carries it |
|---|---|---|
| **Variant 1 — no hook serialization.** `_active` is a lifetime mechanism and never orders one hook against another. A straggler `put` still produces a second `on_close`. | **`Q-A`** | sections 9, 11, 17, 18 and 20, each tagged `[Variant 1]` |
| **`release` waits for quiescence** — it closes if it must, waits for `_active == 0`, then destroys. | **`Q-D.1`**, which asks whether that is also a *shared* Matryoshka rule | the whole document, from section 2 down |
| **`Mailbox.release` takes `InnerQueue* out`** in the one worked example of the pattern. | **`Q-B`** | section 10's `defer` block, tagged `[Q-B]` |

**If `Q-A` is ruled Variant 2**, the tagged sections are the ones that change and
no others: the straggler branch at `pool.c3:425-436` goes, `close` waits for the
calls in flight before its hook, and `release_with_straggler_put.c3` is not
written. **If `Q-B` is refused**, section 10's example goes and the mailbox needs
another destination for what it still holds.

**Nothing outside those tags depends on either answer.**

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
| **closed** | **no call that has not yet reached the entry protocol may become active** | `_closed`, `_closed_fast` |
| **quiet** | no call is still inside | **nobody** |
| **freed** | the memory is gone | the allocator |

**`_close` establishes the first** — the private primitive of section 7, which
both `close` and `release` invoke, and which is the only writer of the
transition. `release` acts as though it had also established the second. Between them sits every call that entered before the close and has not
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

Every operation ACCEPTED AFTER THE CLOSED CHECK raises _active before
it can execute outside the entry mutex, and lowers it only after its
last access to self is complete.
```

**The qualifier is not decoration.** The second review's §4 and §5 found that
`-002`'s *every operation raises `_active`* contradicted two things `-002` itself
said: the rejected-entry path, which finds the tool closed and returns `CLOSED`
**without ever becoming active**, and section 3's own definition, which is about
what may still touch the memory rather than about what was called. **The sentence
above is the normative one, and it is the only form used from here down.**

The life cycle it describes:

```text
                 ┌──────────────┐
                 │     OPEN     │
                 └──┬────────┬──┘
              close │        │ release
                    ▼        │
                 ┌──────────────┐
                 │    CLOSED    │   no call that has not yet reached the
                 └──────┬───────┘   entry protocol may become active
                        │
                release │  the calls already accepted finish
                        ▼
                 ┌──────────────┐
                 │    QUIET     │   _active == 0
                 └──────┬───────┘
                        │
                        ▼
                 ┌──────────────┐
                 │    FREED     │
                 └──────────────┘

close     OPEN -> CLOSED, and returns.
release   OPEN or CLOSED -> CLOSED -> QUIET -> FREED, in one call.
```

**`release` is one arrow and not three.** The second review's §22: drawing
*close / release* on the first arrow alone suggests `release` merely closes.
The two lines under the diagram are the API, and section 6 is the same statement
in prose.

**Where the protection begins, stated with the invariant and not two hundred
lines below it.** The second review's §16 asked for this, because a reader who
meets `_active` without it will read it as a reference count on the pointer:

> **Lifetime protection begins at the successful entry of an operation. It is
> not a claim on the pointer itself.** A thread that still holds a pointer but has
> not reached the entry protocol is outside everything this mechanism can do.

**Section 14 is the full statement of that boundary**, with the two races drawn.

**3TK-53 and 3TK-54 implement against this, not against the prose.** The first
review's §1 and its closing architecture asked for exactly that, and its point
holds: a mechanism section is not a specification until the invariant it serves
is written above it.

## 3. What counts as active

**The first review's §6, and it corrects `-001`.** `-001` said *every call raises
the count on entry*, which is too vague — it invites an implementer to count the
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

**Stated as a general rule, at the first review's §5, rather than as a pool
detail.**

`-001` made this point only about `Pool.close`'s hook. It is broader: `close`
holds a reference and keeps touching `self` after it has published the closed
flag, so `close` must be counted for its whole body or a concurrent `release`
frees the tool under it.

**But the two tools are not equally exposed, and the second review's §11 asks
for the difference to be visible:**

| | why it is active | how long |
|---|---|---|
| `Mailbox.close` | its own body reaches `self` until it returns | short, and entirely inside the port |
| `Pool.close` | **it runs application code after publishing CLOSED** — `on_close` at `pool.c3:493` | as long as the hook runs, which the port does not bound |

**The pool is the motivating case.** The rule covers both, and a reader should
not come away thinking every `close` carries a long window.

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

**This is why `release` vs `close` can be supported at all** — see section 13.
For the mailbox the counted region is short. For the pool it runs to the end of
`on_close`.

## 5. The mechanism both advices land on

**A plain `usz _active`, under the mutex the two tools already own.**

**No atomic.** Both structs already carry a `Mutex` and a `ConditionVariable`,
and almost every call already takes the mutex. The pool advice's *Second advice*
§13 gives the reason, and the second review's §19 sharpens it — the argument is
not that the field is free:

> **The mutex already protects `_closed` and the buckets, so `_active` joins the
> synchronization domain that exists rather than introducing a second one.**

`-002` said *at no measurable cost*, which was never measured and which the
design does not need. A field under a mutex can move cache layout, contention
and the length of a critical section. **None of that changes the argument**, and
claiming zero cost only gave the argument a weakness it did not have.

The protocol:

```text
enter    lock; if closed -> leave with CLOSED; _active++
leave    lock; _active--; if _active == 0 -> broadcast
release  lock; _close(); while _active != 0 -> wait; destroy; free
```

**The ordering, not the cost, is the requirement.** The first review's §10
corrects `-001`'s emphasis: *almost every call already holds the mutex* is a cost
argument, and it was standing where a rule belonged. The rule, in the form the
second review's §4 and §5 corrected it to:

> **Every operation accepted after the closed check raises `_active` before it
> can execute outside the entry mutex, and every raise and every lower is under
> that same mutex.**

**A rejected entry never becomes active**, and the rule must not read as though
it did:

```text
accepted entry              rejected entry

lock                        lock
check closed  -> open       check closed  -> closed
_active++                   unlock
unlock                      return CLOSED
execute
```

**And one more, which the second review's §12 asks for as a normative sentence
because it is the whole reason the mutex is not the mechanism:**

> **A thread may leave the mutex and remain an active operation.** `_active`
> stays raised while the call executes outside the mutex, application code
> included.

The three shapes that follow:

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

`-001` said *release closes if it must*. The first review's §20 calls that
misleading,
and it is: `release` is the complete life-cycle operation, and the wording hid
two of its three parts.

```text
close      transition to closed, and return.

release    transition to closed if necessary,
           wait for quiescence,
           destroy.
```

**`close` is not required before `release` any more.** The two negative programs
that prove today's rule therefore **invert** — see section 18.

**What `Part 11.12` says today** is *closed before released*, and it is a tier 1
MUST that aborts in every build mode. What replaces it is section 14's clause,
and **it is not 3tk's to write** — that is 3TK-52.

## 7. The private primitive

`_close()` runs **with the mutex already held**. It is the state change both
public paths share, and nothing else.

| it does | it never does |
|---|---|
| returns at once if already closed | take the mutex |
| sets `_closed` | release the mutex |
| publishes the fast-path closed state | call a hook |
| empties what the tool holds into the caller's storage | destroy anything |
| broadcasts on the condition variable | free anything |

**Calling it twice is safe, and the second call transfers nothing.** The first
review's §4, and it is a correction: `-001` said *returns at once if already closed*
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

**The fast-path ordering is named and not specified here.** The second review's
§20 found `-002` stating `RELEASE` as a required store in this table while the
probe section listed the ordering around `_closed_fast` among the things still to
be established. **Both cannot be true**, so the level is fixed:

> `_close` publishes the fast-path closed state **using the ordering the existing
> fast-path protocol already requires**. That protocol is in the code today; **3TK-53
> states which ordering it is, and why, against the load that pairs with it.**

The store shown in the block below is the one standing in the port today, and it
is quoted, not specified.

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

**The two tools do not share one `_close`, and the second review's §6 asks for
them to be written apart.** The primitive is private and each tool has its own;
what `-002` blurred is which *public* call supplies the storage it fills.

```text
Mailbox._close(InnerQueue* out)
    empties _oob and _regular into out.

Pool._close(InnerQueue* out)
    empties every bucket's free stack into out.
    the body that stands at pool.c3:479-489 today.
```

| public call | who receives what the tool still held |
|---|---|
| `Mailbox.close(out)` | the caller's `out`. **Today's behaviour, unchanged** |
| `Mailbox.release(...)` | **`Q-B`.** The caller's `out` if it gains one; otherwise undecided, and section 10 is the statement of the problem |
| `Pool.close()` | the `on_close` hook, at `pool.c3:493`. **Today's behaviour, unchanged** |
| `Pool.release(...)` | **`Q-C`.** The hook, as `close` does — or a caller's `out`, which would give the pool two ways to hand back the same items |

**`Pool._close` filling a caller's queue is an internal step, not a public
promise.** `Pool.close` gives that queue to the hook. Whether `Pool.release` does
the same, or gives it back to the caller, is `Q-C`, and nothing in this section
decides it.

## 8. The destruction ordering, and what is not yet known

**The first review's §11, and it is the one place where `-001` prescribed code it
had not earned.** `-001` wrote the release line as `... ; destroy; free`, which
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
feasibility probe settles it — see the probe section.

**One thing about the wait is not a sketch, and the second review's §9 is right
to ask for it.** `_close` broadcasts while the releasing thread still holds the
mutex, and the same broadcast serves two different readers — an ordinary waiter
in `receive` or `get_wait`, and the release that is waiting for quiet. So:

> **The release wait is a predicate loop on `_active == 0`, under the same mutex.
> A broadcast is a wake-up and never a statement that the condition holds.** A
> woken thread becomes eligible to continue only when the releasing thread has
> unlocked, and it re-reads `_active` before it does anything.

**That makes the design independent of scheduling**, and it is the difference
between a `while` and an `if` at the one site where an `if` would be a live bug.

## 9. Pool specifics, and the detail that decides the implementation

**`[Variant 1]` — the straggler paragraphs below assume `Q-A` is ruled with no
hook serialization.** Everything else in this section holds under either variant:
the hook window, the re-take at `:423`, `close` through its own hook, and
`get_wait`. Section 0 says what changes if `Q-A` goes the other way.

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
- lowered only after the re-take at `:423` **and** — **`[Variant 1]`** — after
  any straggler `on_close` at `:434`.

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
straight through it. **Section 5's normative sentence is the other half of the
same statement**: a thread may leave the mutex and remain active.

## 10. Mailbox specifics

**The mailbox has no hook, so it is the mechanism without the hard part.** Its
waiting path holds the mutex across `wait_until` at `mailbox.c3:255`, so a parked
receiver is covered by the same field with no special handling.

**`_close(InnerQueue* out)` writes into caller-owned storage.** The mailbox still
never allocates for the outers it gives back — the property `close` has today at
`mailbox.c3:327`, kept.

**A mailbox has no hook, and therefore no obvious destination for what it still
holds.** The first review's §3 promotes this from a matter of style to a
requirement. **The second review's §7 then corrects the requirement**, and the
corrected form is the one that stands here, because `-002`'s wording argued
`Q-B` on the owner's behalf:

> **An open mailbox cannot be released without defining what becomes of the
> items it still holds.**

**Not *cannot be released safely*.** Lifetime safety does not force a caller's
`out` parameter. At least three designs satisfy the invariant:

| design | what becomes of the remainder |
|---|---|
| **`release(InnerQueue* out)`** | the caller's storage. **The reviewer's recommendation, both rounds** |
| **discard** | the mailbox frees or drops what it holds |
| **an internally defined owner** | the port names a destination the client does not pass |

**The port does not discard anything silently anywhere else**, which is the
argument for the first — and it is an argument, not a proof. **`Q-B` is the
owner's**, section 19, and section 12 is why it blocks.

```c3
fn void  Mailbox.close(&self, InnerQueue* out)      // today, unchanged
fn void  Mailbox.release(&self, InnerQueue* out)    // the proposal, Q-B
```

Both would assert `out.is_empty()` on entry, as `close` does today at
`mailbox.c3:330`.

**`[Q-B]` — the `defer` pattern, from the advice's §11 and §12, and it is what
the API looks like *if `Q-B` is accepted*:**

```c3
// if Q-B is accepted:
InnerQueue iq;

defer queue_outers_release(&iq);   // declared first, runs second
defer mbox.release(&iq);           // declared second, runs first
```

C3 runs deferred statements in **reverse textual order**, so the mailbox fills
`iq` first and the client's function empties it second. Both refer to the same
local, which is still in scope when either runs.

**3TK-53 runs this rather than reasoning about it** — the advice's §12 asks for
exactly that, and it is a test in `test/t_mailbox.c3`. **If `Q-B` is refused,
that test is not written**, and neither is this block.

## 11. Lifetime waiting is not hook serialization

**The first review's §8, §9 and §13, and it is the sharpest thing that review
says.** `-001` stated the contradiction and left the reader to hold two
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

**`[Variant 1]` — the straggler path is the case that shows it**, and the
second review's §13 is right that the example depends on `Q-A`. The *distinction*
above does not: lifetime waiting and hook ordering are different questions
whichever way `Q-A` is ruled. Only this illustration needs Variant 1.

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
section 19 as blocking, alongside `Q-A`.

## 13. Who may release

**What this replaces:** *We never guard simmultaneous releases - by design*, in
[3tk-release-while-busy-001.md](3tk-release-while-busy-001.md) under *Owner
thinking - Mailbox*.

The mailbox advice's §5 refuses to accept that as stated. Its reason is one
interleaving:

```text
Thread A                    Thread B
release()                   release()
  _close()                    sees closed
  free(mb)                    free(mb)      <- double free
```

**That is an illustration and not the argument**, and the second review's §15 is
right to say so: it is only one of the ways two releases can interleave, and
reading it as *the* reason invites the answer *then make B not see closed*. The
argument is one level up:

> **Two concurrent releases have no protocol that assigns the destroying to
> exactly one of them.** No counter, no flag and no ordering inside the tool can
> decide it, because whichever thread loses is reading memory the winner is
> freeing.

**An unguarded concurrent release is a double free, not a design decision.** But
it does not need guarding — it needs a written rule, and the second review's §14
asks for the form that names the owner rather than the form that names the race:

> **A mailbox or a pool has exactly one destruction owner. That owner calls
> `release` once. Calls on the tool may be concurrent with it; a second
> concurrent `release` is not supported.**

`-002` said *release may not be concurrent*, which leaves open whether the rule
is about overlap or about who owns the tool. **It is about who owns it**, and the matrix
below is then a consequence rather than a list to memorize.

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

**Why that last row is not arbitrary**, at the first review's §16. It reads as a
concurrency rule and it is a rule about who owns the destroying:

> `get`, `put` and `close` are **operations on** the tool. `release` is the
> **destruction of** the tool.

An ordinary operation may race destruction because destruction waits for it.
Two destructions cannot both own the destroying.

## 14. The boundary the fix cannot cross

**Two races, and only one of them is the port's.** The first review's §7 asks for
them to be named, because *release waits for calls* reads as a stronger promise
than it is. **Section 2 states the boundary with the invariant**, at the second
review's §16; this section is where it is drawn.

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

**And it is not incidental**, at the second review's §23:

> **`release` may block because quiescence is part of the destruction
> precondition.** It is the invariant of section 2, not a property the
> implementation happened to acquire.

- A `release` now waits for application code it does not control — an `on_put`
  or an `on_close` that never returns is a release that never returns.
- **There is no timeout and no abort path.** Waiting is the sound answer;
  aborting cannot be implemented safely, because the abort would have to read
  the memory it is racing.
- **The other ports inherit it** if 3TK-52 is ruled that way. That is the real
  content of the clause and the reason 52 exists.

**And one clause the application owes back**, which `-002` did not state at all.
The second review's §10: because `release` waits for hooks, an application can
build a cycle out of it.

```text
release()  waits for  on_put()
on_put()   waits for  the release that is waiting for it
```

> **An application hook must not require the completion of the `release` that is
> waiting for it.** A hook that blocks on the destruction of its own tool
> deadlocks, and no counter, ordering or timeout inside the port can break it.

**This is not hook serialization and it adds no synchronization.** It is a
precondition on application code, and it belongs in whatever 3TK-52 writes —
`-002` said only that a slow `on_put` stalls every closer, which is the mild half
of the same fact.

**What does not change:** a correct application sees no difference on the calling
path. `_active` is one field under a mutex the call already holds.

## 17. The `P6` interaction

`P6` — the pool cannot tell whether the close hook processed the items it was
given or dropped them — keeps its own question, unchanged.

**`-001` said its option 1 is unblocked. The first review's §14 narrows that, and
the narrowing is adopted:**

> **Q5 removes the lifetime blocker for `P6` option 1. It does not answer
> `P6`'s own question of who owns what, and of what is counted.**

What is removed is real: **`[Variant 1]`** counting what went out against what
came back means nothing while a further `on_close` may still arrive from a
straggler `put`, and after 3TK-54 there is a moment where that can no longer
happen. **Said precisely**, at the second review's §24 — `-002`'s *no further
`on_close` can arrive* was too strong, because section 14's Race B says a stale
caller may still exist:

> **After release has waited, every operation that was accepted before the
> closure has finished.** That is what `_active == 0` means, and it is not a
> promise that no thread anywhere still holds the pointer.

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
| `negative/release_vs_close_mailbox.c3` | 53 | **new, at the first review's §15.** One thread closes, another releases. **Its oracle is below** |
| `negative/release_open_pool.c3` | 54 | **inverts**, the same way |
| `negative/release_during_on_put.c3` | 54 | **Test A.** `on_put` parks until the main thread has called release, then returns. Without the fix, undefined behaviour; with it, release waits and the program finishes |
| `negative/release_during_on_close.c3` | 54 | **Test B.** `_active` covers `close`'s own hook — the hook side of section 4 |
| `negative/release_vs_close_pool.c3` | 54 | **new.** The pool's version of the same case: `close` racing `release` as *operations*, distinct from Test B, which parks inside the hook |
| `negative/release_with_straggler_put.c3` | 54 | **`[Variant 1]` Test C**, the most valuable pool-specific one: a concurrent put produces the second `on_close`, and release waits for both calls. **Under Variant 2 there is no second `on_close` and this program is not written** |

**The two `release_vs_close_*` programs need an oracle, and it is not *close
wins*.** The second review's §26: both orderings are legal, and a test that
assumes one passes by luck.

```text
close first                       release first

close   -> publishes CLOSED       release -> publishes CLOSED, waits
release -> sees closed,           close   -> sees closed, returns
           waits, destroys        release -> destroys
```

> **Either `close` or `release` may publish CLOSED first. Exactly one call
> destroys the tool. The other returns safely, and neither aborts.**

**That is the oracle**, and it is what the two programs check — not an ordering.

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

**Split into two lists at the first review's §17 and §18**, which found seven
questions of three different kinds sitting in one list and no way to see which of
them stops the code. **The split changes no question's content and rules none of
them.** The second review's §31 arrives at the same four blocking questions and
the same three tracking ones.

**Each blocking question now says what this document assumes while it waits**,
at the second review's §1 and §2. Section 0 is the list of those assumptions.

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

Section 20 holds the full comparison, and section 11 is the distinction both
reviews say makes Variant 1 possible without loss.

**What this document assumes while it waits: Variant 1**, tagged at every site
that depends on it — sections 9, 11, 17, 18 and 20. **`-002` made the same
assumption and did not say so**, which the second review's §1 called the most
important problem in it. Section 0 names what changes under Variant 2.

**The reviewer recommends Variant 1 in both rounds**, on the grounds that making
`_active` serialize hooks turns a lifetime mechanism into an
application-execution policy and changes `Part 12.2` and `12.3`. **Not ruled.**

#### `Q-B` — does `Mailbox.release` gain `InnerQueue* out`?

The mailbox advice's §4 and §13 recommend it. **Section 12 is why this question
is blocking**: it contradicts the `Q5` ruling's *the client's code is unaffected
either way*, and the contradiction is the owner's to resolve — either by
re-wording that ruling or by rejecting `Q-B` and designing another destination
for an open mailbox's items.

**What this document assumes while it waits: the `out` parameter**, in section
10's `defer` block and nowhere else, tagged `[Q-B]`.

**The reviewer recommends yes in both rounds**, though the second round narrows
the argument: it is the best of three designs, not the only one lifetime safety
allows. Section 10 has the three. **Not ruled.**

#### `Q-C` — does `Pool.release` gain one too?

Or does it keep giving everything to `on_close`, as `Pool.close` does today at
`pool.c3:493`? The pool has a hook and the mailbox does not, so the two answers
need not match. **A pool that grew an `out` parameter would have two ways to hand
back the same items.**

**Not to be confused with `Pool._close(out)`**, which is private and internal —
section 7's table says which public call supplies the storage, and `Q-C` is the
one row of it that is undecided.

**What this document assumes while it waits: nothing.** No section depends on
this answer.

**The reviewer recommends no in both rounds**, for the reason above. **Not
ruled.**

#### `Q-D` — the shared-specification rule. **Two questions, not one.**

`-001` asked *does 3TK-52 run before the code?*. The first review's §19 says that
is the procedural half of a semantic question; the second review's §2 says the
semantic half is **already assumed by every section of this document**, and that
the two must therefore be asked apart:

> **`Q-D.1` — is *`release` closes, waits for quiescence, then destroys* the
> intended shared Matryoshka contract**, or is it 3tk's own design?
>
> **`Q-D.2` — if it is shared, must every port implement it before claiming
> conformance** — and so does 3TK-52 run before 3tk's code, or does 3tk go first
> under a written assumption naming which way it assumed?

**What this document assumes while it waits: the model itself.** Sections 2, 5, 6
and 8 are all built on `release` waiting for `_active == 0`. **That assumption is
3tk's design either way**; `Q-D.1` asks only whether the other ports owe it too.

The vocabulary **closed / quiet / freed** is useful across all ports and the
specification should carry it either way.

**The reviewer recommends yes to `Q-D.1` in both rounds**, on the grounds that
this is a semantic contract and not a 3tk implementation detail. **Not ruled.**

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

**`[Variant 1]` — this document is written against the second half of the table
below.** Section 0 says so; this section is why the choice is not obvious.

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
- **`release returned, cv and mutex destroyed, memory freed`** — **the line is
  the probe's own wording and no `release` of this port ran.** The second review's
  §17 is right that `-002` left it reading as though one had. What the run
  establishes: **the release-shaped sequence completed** — the waiter left the
  loop, the `ConditionVariable` and the `Mutex` were destroyed after the last
  waiter had left them, and the heap block holding them was freed, with no fault
  in any build.
- **`WAIT_TIMEOUT=true`** — **in the four builds tested**, `wait_until` with no
  signal returned a fault, and that fault was `thread::WAIT_TIMEOUT`. That
  matches what `mailbox.c3:255-257` and `pool.c3:368-370` already rely on. **It
  is what four runs showed, not a statement about the only value the standard
  library may return**, which this document has no evidence for and does not
  need.

**What it does not prove.** `-001` closed with *the design does not change; the
probe did not refuse*, and the first review's §12 calls that broader than the
evidence. It is narrowed here:

> **The probe validates that the synchronization and destruction pattern the
> mechanism needs is feasible in C3. It says nothing about the correctness of
> the Mailbox or the Pool implementation**, which 3TK-53 and 3TK-54 must
> establish for themselves.

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

## What the reviewer recommended

**Recorded as input. None of it is ruled**, and the port's rule holds: a review
describes, the owner decides. **Both rounds gave the same seven answers**, and
the second round's §31 reaches the same blocking/tracking split section 19
already had.

| question | the reviewer's recommendation | the reason given |
|---|---|---|
| `Q-A` hook serialization | **no serialization** | keeps `Part 12.2` and `12.3`, and keeps lifetime separate from hook synchronization |
| `Q-B` `Mailbox.release(out)` | **yes** — round 1 said *probably required*, round 2 narrowed it to *the best of three designs* | the port discards nothing silently anywhere else. **Lifetime safety alone does not force it** — section 10 |
| `Q-C` `Pool.release(out)` | **no** | `on_close` already gives the pool a way to hand items back |
| `Q-D` shared spec first | **yes** | it is a semantic contract, not a 3tk implementation detail |
| `Q-E` scheduling | **track it, do not design it** | project ordering |
| `Q-F` `P6` | **keep separate** | the fix removes its blocker, not its own question |
| `Q-G` `W3` | **track it** | documentation scheduling |

**And round 1's blocking condition**, which the owner may take or refuse:

> 3TK-53 and 3TK-54 should not start until the `Q5`-against-`Q-B` contradiction
> is resolved, no-serialization is confirmed, `_active` is defined including
> `close`, the destruction ordering is established, and the shared-specification
> rule is decided.

**Where those five now stand**, corrected at the second review's §30, which
found `-002`'s *three of five are done* counting a scoped question as a closed
one:

| | state |
|---|---|
| `_active` defined, `close` included | **done in this document** — sections 3 and 4 |
| no serialization confirmed | **not done. Assumed, and tagged** — `Q-A` is the owner's, and section 0 says what the assumption costs if it is wrong |
| destruction ordering | **narrowed to a concrete check in 3TK-53** — section 8. Not established, and this document cannot establish it |
| `Q5` against `Q-B` | **the owner's** — section 12 |
| the shared-specification rule | **the owner's** — `Q-D.1` and `Q-D.2` |

**One done, one narrowed, three open** — two of the three being owner
decisions and the third, `Q-A`, an owner decision this document has assumed an
answer to in the open.

---

## What changed from `-002`

**The second review has thirty-three numbered points. Twenty-eight are acted on
below; five are not, and *What this version did not do* says which and why.**

| section | change | from |
|---|---|---|
| 0 | **new.** The three working assumptions, at the top, with the question each one pre-empts and what changes if it is ruled the other way | §1, §2, §8 |
| 1 | *no new call may enter* made precise; **`_close`** named as the authority for the transition, since `release` establishes it too | §3, §21 |
| 2 | the invariant reworded to *every operation accepted after the closed check*; the diagram redrawn so `release` is one arrow to FREED and not one to CLOSED; **where lifetime protection begins** stated with the invariant | §4, §5, §16, §22 |
| 4 | the mailbox's and the pool's `close` separated — the pool's runs application code after CLOSED, the mailbox's does not | §11 |
| 5 | *no measurable cost* written out; the rejected-entry path drawn beside the accepted one; **a thread may leave the mutex and remain active** added as normative | §4, §5, §12, §19 |
| 7 | `Mailbox._close` and `Pool._close` written apart, with a table of which public call supplies the storage; the `_closed_fast` ordering levelled — named here, specified by 3TK-53 | §6, §20 |
| 8 | **the release wait is a predicate loop; a broadcast is only a wake-up** | §9 |
| 9, 11, 17, 18, 20 | every straggler-dependent statement tagged `[Variant 1]` | §1, §13 |
| 10 | *cannot be released safely* corrected to *cannot be released without defining what becomes of the items*; the three designs that satisfy the invariant listed; the `defer` block tagged `[Q-B]` | §7, §8 |
| 13 | the double-free interleaving demoted to an illustration, with the argument about who owns the destroying above it; the rule restated as **exactly one destruction owner** | §14, §15 |
| 16 | **new clause: an application hook must not require the completion of the release waiting for it**; blocking tied to the invariant rather than left incidental | §10, §23 |
| 17 | *no further `on_close` can arrive* corrected to *every operation accepted before the closure has finished* | §24 |
| 18 | **the `release_vs_close_*` oracle**: either call may publish CLOSED first, exactly one destroys, the other returns safely | §26 |
| 19 | `Q-D` split into `Q-D.1` semantic and `Q-D.2` conformance; each blocking question says what the document assumes while it waits; `Q-C` separated from the private `Pool._close(out)` | §2, §6, §31 |
| the probe | *release returned* corrected — no release of this port ran; `WAIT_TIMEOUT` narrowed to the four builds tested | §17, §18 |
| *What the reviewer recommended* | *three of five are done* corrected to one done, one narrowed, three open | §30 |
| the header | *all twenty points absorbed* replaced by the mapping tables, which is what the claim needed | §29 |

**Nothing was removed.** Section numbering is unchanged from `-002`; section 0
is new above section 1.

---

## What this version did not do

**Five of the second review's points are not acted on, four of them for one
reason.**

| point | what it asks | why not now |
|---|---|---|
| **§27** | remove the repetition — the central rule appears in a dozen sections | **wait for the rulings.** `Q-A`, `Q-B`, `Q-C` and `Q-D` rewrite sections 9, 10, 11, 17, 18 and 20, which is most of where the repetition is |
| **§28** | separate specification from review history from implementation plan | same. A reorganization is where content goes missing, and doing it twice doubles that risk for nothing |
| **§32** | promote a normative *Lifetime contract* block to the front | same, and it would be written against assumptions that may not survive `Q-A` |
| **§25** | rename *the negatives this fix owes*, since two of them stop being negatives | same stage as the reorganization, and the naming is the owner's |
| **§33** | the reviewer's answer to `Q-A` | **it is a recommendation, and recommendations are not absorbed as rulings.** It is in *What the reviewer recommended* |

**The reorganization is owed, and it runs once — in the version that carries the
owner's answers.** That version deletes the `[Variant 1]` and `[Q-B]` tags
instead of moving them, which is the only order in which the work is done a
single time.

---

## What changed from `-001`

**Kept from `-002`. The first review had twenty points.**

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
| this table and *What the reviewer recommended* | **new** | INTR 4 |

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
| banned words, this file | **0 in prose.** Eight hits remain, every one inside a code block and every one the same stdlib call name — the quoted `pool.c3:421` source line, and the pseudo-code of sections 5 and 8. Part 5 exempts a stdlib call name |
| links | every link in this file printed and read |
