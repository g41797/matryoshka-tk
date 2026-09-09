# 3tk — the lifetime fix

**Fifth version, 2026-08-28, written by INTR 7.** It supersedes
`3tk-lifetime-fix-004.md`, which is in `backup/` with `-001` to `-003`.

**`-005` changes no decision.** A third review read `-004`, endorsed the ruling,
and said to proceed to 3TK-53 and 3TK-54 rather than reopen the architecture.
**This version is its ten clarifications and nothing else** — sentences added,
two sentences corrected, the shape untouched. *What changed from `-004`* lists
them.

**This document carries an owner ruling, and it is the reason it is shorter than
`-003` was.**

> **Release while a call is in flight is not prevented. It is written down as a
> thing the caller must not do, and it is checked. It is not waited for.**

**Ruled 2026-08-28.** Everything about the hazard is still here — the race, the
hook window, the parked receiver, why taking the mutex proves nothing. What
changed is the ending: **the port names the rule and checks it, rather than
absorbing the cost of it.**

**Three questions closed as a consequence** — `Q-A`, `Q-B`, `Q-C` — and with them
the contradiction the second review called the largest problem in `-002`.
Section 15 shows each one and why it no longer arises. **`Q-D` and `P6` stay
open.**

**The shape is INTR 6's**, and the third review asked for none of it to change:
contract first, then mechanism, then the two tools, then the tests, then what is
open, with the review history at the end.

**No byte of `3tk/src`, `test/` or `negative/` has been touched by any of the
five stages that wrote this document.**

**Inputs**, and nothing else was read for this version: `-004` and the third
review. **The three reviews and the two advice files are in `backup/`**; their
findings are in the sections below and in *Review history*.

**Reviewing stops here.** Three rounds have read this document — twenty points,
thirty-three, ten — each smaller than the last, and the third ends by saying the
remaining work is verification in C3 rather than another architectural round.
**Further review goes into 3TK-53's own record, not into a sixth version of this
file.**

**Every line number was printed live on 2026-08-28.** Re-print before trusting
them: every fix in 3TK-53 and 3TK-54 moves them.

**This document is versioned.** An answer to section 14 makes `006`, and the
superseded version goes to `backup/`. **A question and its answer live here**,
never only in a conversation.

---

# Part I — The contract

## 1. The one defect, on two tools

`Mailbox.release` at `mailbox.c3:106` and `Pool.release` at `pool.c3:231` both
open with the same line:

```c3
always_assert(self._closed, "releasing an open mailbox");   // mailbox.c3:114
always_assert(self._closed, "releasing an open pool");      // pool.c3:240
```

**That assertion answers the wrong question, and it answers it reassuringly.**
A caller who passes it believes something has been checked. Something has — just
not the thing that matters.

There are **three states, not two**:

| state | what it means | who knows it today |
|---|---|---|
| **closed** | no call that has not yet reached the entry protocol may become active | `_closed`, `_closed_fast` |
| **quiet** | no call is still inside | **nobody** |
| **freed** | the memory is gone | the allocator |

`_close` establishes the first. `release` acts as though it had established the
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
worth acting on. **What the ruling changes is what "acting on" means** — see
section 4.

## 2. The lifetime contract

```text
Lifetime contract

A mailbox or a pool passes through four conditions:

    OPEN -> CLOSED -> QUIET -> FREED

_close() performs the transition to CLOSED. Both close and release
invoke it, and nothing else writes it.

QUIET IS A PREDICATE, NOT A FIELD:

    quiet  ==  _closed == true && _active == 0

An operation is ACTIVE while it may still access the tool's memory.

An operation accepted after the closed check raises _active before it
can execute outside the entry mutex, and lowers it before it returns
to its caller.

    free(self) is legal only when quiet

close     invokes _close, leaves the active set, and returns.
release   invokes _close if the tool is still open, REQUIRES quiet,
          destroys, and frees.
```

**`_quiet` is not a field and must not become one.** The third review's §13:
CLOSED is stored, and quiet is what the two stored values say together. A stage
that adds a third flag has added a fourth thing to keep consistent for no gain.

**Every public operation, including `close`, leaves the active set before it
returns.** The third review's §3, and it is the sentence an implementer needs
most. `-004` said *lowers it after its last access*, which is true and does not
say what a caller needs to hear:

```text
close();      // returns having already lowered the count
release();    // sees quiet, in the same thread, with no coordination
```

**Close-then-release in one thread is the ordinary shape, and it works.** Rule 1
is about the *other* threads.

**`REQUIRES` is the whole of the ruling.** An earlier draft of this document had
`release` *wait for* quiet. It now **checks** for it and aborts if it does not
hold. Section 4 is the rule that makes the check the caller's business, and
section 11 is what that choice costs.

**`release` stands outside the protocol.** It is not counted, it is not
concurrent with anything, and it observes the predicate under the mutex — never
before taking it.

**Where the protection begins**, stated with the contract so that `_active` is
not mistaken for a count on the pointer:

> **A tool is protected from the moment an operation is accepted at the entry
> protocol.** A thread that still holds a pointer but has not reached that point
> is outside anything the port can do for it.

**So `_active == 0` does not mean *nobody can touch this*.** The third review's
§2 asks for the safe form, because the unsafe reading is the one an implementer
drifts into:

> **`_active == 0` means no accepted operation is still inside.** It says nothing
> about a thread that has the pointer and has not entered yet — that is Rule 3,
> and no counter inside the memory can ever speak to it.

## 3. What counts as active

> **An active operation is any execution path that has acquired a valid
> reference to the tool and may still access its memory.**

Whether it is a public call, a hook window, or the tail of a `close` does not
enter into it. What enters into it is whether the memory can still be touched.

**A rejected entry never becomes active.** A call that takes the mutex, finds the
tool closed and returns `CLOSED` raises nothing.

```text
accepted entry              rejected entry

lock                        lock
check closed  -> open       check closed  -> closed
_active++                   unlock
unlock                      return CLOSED
execute
```

**A thread may leave the mutex and remain active.** `_active` stays raised while
the call runs outside the mutex, application code included. **This is the whole
reason the mutex is not the mechanism**, and it is the sentence 3TK-54 is most
likely to get wrong.

**And it is not the syntactic call that bounds it.** The third review's §7:

> **`_active` covers the whole of an operation's access to the tool, including
> every application hook that operation invokes** — not the body of one function.

A later refactor that moves a hook call into a helper changes nothing: what
decides is whether application code can still be running with a reference
derived from the tool.

**Enumerated, so no site is missed:**

| Mailbox | active |
|---|---|
| `send` and every sending path | yes |
| `receive` | yes |
| a receiver parked in `wait_until` at `mailbox.c3:255` | **yes — see section 4** |
| `close` | yes, for its whole body |
| `release` | **no** |

| Pool | active |
|---|---|
| `get`, including its `on_get` hook at `pool.c3:321` | yes |
| `get_wait`, including the park at `pool.c3:368` | yes |
| `put`, including `on_put` at `pool.c3:422` and any straggler `on_close` at `pool.c3:434` | yes |
| `close`, including its own `on_close` at `pool.c3:493` | yes |
| queries that take the mutex — `count_of` at `pool.c3:511` and its neighbours | yes |
| `release` | **no** |

**`release` is never counted.** It would then be waiting on, or asserting
against, itself. Both advices say this in the same words — mailbox §8, pool
*Second advice* §8.

**`close` is active for its whole body, and the two tools are not equally
exposed:**

| | why it is active | how long |
|---|---|---|
| `Mailbox.close` | its own body reaches `self` until it returns | short, and entirely inside the port |
| `Pool.close` | **it runs application code after publishing CLOSED** — `on_close` at `pool.c3:493` | as long as the hook runs, which the port does not bound |

## 4. The three rules the port states and does not enforce

**This section is the ruling.** Three hazards are real, none of them is prevented,
and each one is a sentence the caller is answerable for.

### Rule 1 — closed **and quiet** before released. **New.**

> **Do not release a mailbox or a pool while any call on it may still be
> running.** Close it, let every thread that touches it finish, and release it
> after that. **The usual way to get quiet is to join the threads.**

**Why it is not waited for.** A `release` that waited would block on application
code the port does not control — an `on_put` or an `on_close` that never returns
would be a release that never returns — and an application could close the cycle
by writing a hook that waits on the release that waits for it. **That trades a
use-after-free for a deadlock**, adds a promise every other port would then owe,
and puts the port in the business of managing application execution.

**Why it is not merely a comment.** `release` **checks it**:

```c3
always_assert(self._closed && self._active == 0,
              "releasing a mailbox that is not quiet");
```

**In all four builds.** `release` is not a hot path; a comparison against a field
already in the cache line costs nothing worth measuring, and a caller who breaks
the rule gets a stop with a message rather than corruption an hour later.

**What the check catches, and what it does not.** It catches a violation **on the
schedule it happens to see**. A program that breaks the rule and interleaves
harmlessly today passes today. **A wait would have been correct on every
schedule; a check is not**, and that is the cost of the ruling, stated plainly.

**The parked receiver is the case worth reading twice.** A thread inside
`receive` or `get_wait` is parked in `wait_until` with the mutex released, so it
is invisible to anything but the count. `close` wakes it, but **`close` does not
wait for it to leave** — closed is not quiet. **The caller must close, then
observe that thread finish, and only then release.** This is where *join your
threads* is doing the real work rather than being advice.

### Rule 2 — exactly one destruction owner. **Already the rule today.**

> **A mailbox or a pool has exactly one owner that destroys it. That owner calls
> `release` once.** Calls on the tool may be concurrent with each other; a second
> concurrent `release` is not supported.

**Two concurrent releases have no protocol that assigns the destroying to one of
them.** No counter, no flag and no ordering inside the tool can decide it,
because whichever thread loses is reading memory the winner is freeing. The
mailbox advice's §5 gives one interleaving that ends in a double free; **that is
an illustration and not the argument.**

**The canonical statement**, at the third review's §4, which asked for the pieces
scattered across `-003` to become one table:

```text
ordinary operations   concurrent with each other
close                 concurrent with ordinary operations
release               concurrent with NOTHING —
                      not an operation, not close, not another release
```

Said as the pool advice's §14 matrix:

| pair | supported |
|---|---|
| `get` vs `put` vs `get_wait` vs `close` | yes, in any combination |
| release vs `get` | **no** — the call must have returned first |
| release vs `get_wait` | **no** |
| release vs `put` | **no** |
| release vs `close` | **no** |
| release vs release | **no** |

**The matrix reads differently under this ruling than it did in `-003`**, and the
difference is the ruling. A design that waits can say *yes* to the first four
release rows. **A design that checks says the caller must have arranged for the
question not to arise.** `release` is the owner acting, not a participant.

### Rule 3 — a stale pointer is not protected. **Already the rule today.**

```text
thread A:  p.put()      // has not entered yet
thread B:  p.release()  // closes, checks, frees
thread A:  p.put()      // enters freed memory
```

**No counter inside the freed memory can help.** The counter and the mutex
guarding it are in the memory being freed, which is the same defect one level
down — the `Q5` document said this first, under *A counter alone narrows the
race*.

> **The port's protection begins when an operation is accepted. It does not
> extend the life of a tool that a thread merely holds a pointer to.**

### The three together

**They are three rules and not one, and the third review's §2 asks for them not
to be blurred:**

```text
Rule 1   no release until every accepted operation has finished
Rule 2   exactly one owner destroys, and it does not race anything
Rule 3   no operation may START through the pointer after release
```

**`_active` speaks to Rule 1 alone.** Rule 2 has no mechanism and cannot have
one. Rule 3 is outside the memory entirely.

**Rule 3 is the one that matters for judging the ruling.** The port already lives
on a written rule for the stale pointer, and always has. **Rule 1 does not remove
a class of error; it moves a line** — from *do not release while anyone might be
inside* to *do not release while anyone might enter*.

**It is not less discipline than a waiting `release`. It is different
discipline**, and the third review's §14 states the real argument, which `-004`
got wrong:

| design | what the owner writes |
|---|---|
| waiting `release` | `close(); release();` — the toolkit blocks on application code |
| **this ruling** | `close(); join(workers); release();` |

> **The ruling puts the responsibility where the tool's life is actually decided,
> instead of making destruction wait on execution the port does not control.**

The owner already knows when its threads have finished. The port never can.

### The text this owes

**These are deliverables, not notes.** `W3` was drafted as a temporary warning
saying the port did not yet handle this. **Under the ruling it is permanent, and
it is the fix.**

- **`Part 11.12`** — today *closed before released*. It becomes **closed and
  quiet before released**, with *quiet* defined as in section 2 and the joining
  sentence beside it.
- **both `release` descriptors** — the rule, what the assertion checks, and the
  parked-receiver case.
- **both `close` descriptors** — one sentence: **closing does not make a tool
  quiet.** A caller who reads only `close` must not come away thinking it does.

---

# Part II — The mechanism

## 5. `_active`

**A plain `usz`, under the mutex the two tools already own.**

**No atomic.** Both structs already carry a `Mutex` and a `ConditionVariable`,
and almost every call already takes the mutex. **The mutex already protects
`_closed` and the buckets, so `_active` joins the synchronization domain that
exists rather than introducing a second one.**

**In all four builds, not only the checking ones.** A field that exists in one
build and not another makes the struct a different size per build, and nothing
about a `usz` under an already-held mutex justifies that risk.

The protocol:

```text
enter    lock; if closed -> leave with CLOSED; _active++
leave    lock; _active--
release  lock; assert(_closed && _active == 0); destroy; free
```

**No broadcast is owed by `leave`.** Nothing waits on the count reaching zero,
which is the largest single simplification the ruling buys: the condition
variable keeps exactly the job it has today.

**Every raise and every lower is under the same mutex, and the raise happens
before the call can execute outside it.**

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

## 6. The private primitive

`_close()` runs **with the mutex already held**. It is the state change both
public paths share, and nothing else.

| it does | it never does |
|---|---|
| returns at once if already closed | take the mutex |
| sets `_closed` | release the mutex |
| publishes the fast-path closed state | call a hook |
| empties what the tool holds into the caller's storage | destroy anything |
| broadcasts on the condition variable, to wake parked callers | free anything |

**Calling it twice is safe, and the second call transfers nothing.**

```text
close(&queue1)      // closes; the contents move to queue1
release(&queue2)    // already closed: no transfer, queue2 is left untouched
```

**So `release` never calls public `close`, and no lock nests** — the mailbox
advice's §14 and the pool advice's *Second advice* §7.

**The fast-path ordering is named here and specified by 3TK-53.** `_close`
publishes the fast-path closed state using the ordering the existing fast-path
protocol requires. That protocol is in the code today; **3TK-53 states which
ordering it is, and why, against the load that pairs with it.** The store in the
block below is quoted from the port as it stands, not specified by this document.

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

**Each tool has its own**, and what matters publicly is which call supplies the
storage:

```text
Mailbox._close(InnerQueue* out)   empties _oob and _regular into out.
Pool._close(InnerQueue* out)      empties every bucket's free stack into out.
                                  the body standing at pool.c3:479-489 today.
```

| public call | who receives what the tool still held |
|---|---|
| `Mailbox.close(out)` | the caller's `out`. **Today's behaviour, unchanged** |
| `Pool.close()` | the `on_close` hook, at `pool.c3:493`. **Today's behaviour, unchanged** |
| **`Mailbox.release()`** | **nothing to receive.** Rule 1 requires the tool to be closed first, and `close` has already handed the items back |
| **`Pool.release()`** | **nothing to receive**, for the same reason |

**Neither `release` grows a parameter.** That is the whole of `Q-B` and `Q-C`,
closed by Rule 1 — section 15.

## 7. Destruction ordering — open, and 3TK-53's

`release` still destroys a `Mutex` and a `ConditionVariable` and frees the block
holding them, so one question survives the ruling untouched:

> **When is the mutex released, and can it be destroyed while it is held?**

```text
release:
    lock
    _close(out) if still open
    assert(_closed && _active == 0)

    destroy whatever does not need _mu
    unlock _mu
    destroy _mu
    destroy _cv
    allocator.free(self)
```

**That order is a sketch and not a ruling.** The exact order is whatever C3's
`Mutex` and `ConditionVariable` require, and **3TK-53 establishes it against the
real structs before either tool is changed.** Neither this document nor the
feasibility probe decides it.

> **No source is to be changed on the strength of the block above.** The third
> review's §10 asks for this in as many words, and it is the right guard: a
> sketch left in a document long enough starts being read as an instruction.

---

# Part III — The two tools

## 8. Mailbox

**The mailbox has no hook, so it is the mechanism without the hard part.**

- **Its waiting path holds the mutex across `wait_until` at `mailbox.c3:255`**, so
  a parked receiver is covered by the same field with no special handling. It is
  also the case Rule 1 exists for.
- **`close(InnerQueue* out)` writes into caller-owned storage**, and the mailbox
  still never allocates for the outers it gives back — the property `close` has
  today at `mailbox.c3:327`, kept.
- **`release` keeps its signature.** Under Rule 1 the tool is already closed, so
  there is nothing left inside it to hand anywhere.

**The `defer` shape a caller writes today still works, unchanged:**

```c3
InnerQueue iq;

defer queue_outers_release(&iq);   // declared first, runs second
defer mbox.close(&iq);             // declared second, runs first
```

C3 runs deferred statements in **reverse textual order**, so the mailbox fills
`iq` first and the client's function empties it second. **`release` is not part
of this shape**, and under Rule 1 it cannot be: a `defer` cannot know that the
other threads have finished.

## 9. Pool

**`_active` must cover the whole call, hook window included.** This is the single
most important implementation line in the document, and it is the pool advice's
*Second advice* §3.

The window is deliberate and specified. `Part 12.3` MUST forbids holding the
mutex across a call into application code, so `Pool.put` opens it itself:

```
pool.c3:421:    self._mu.unlock();
pool.c3:422:    self._hooks.on_put(in_pool, &mine, &extra);
pool.c3:423:    self._mu.lock();
```

**`:423` re-takes a mutex that a release breaking Rule 1 may already have
destroyed and freed.** That is the defect at its worst site, and the count is
what lets `release` see it.

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

**`Pool.close` stays counted through its own hook** at `pool.c3:493`, which runs
after the mutex is released at `:490`.

**`Pool.get`'s hook at `pool.c3:321`** runs after the mutex is released at
`:320`, and the call returns straight after it. Same rule: raised before `:320`,
lowered after the hook. **This is the one added lock in the design** — `get` does
not re-take the mutex today, and a count that covers its hook must.

**The requirement is the invariant, not a sequence.** The third review's §8: the
obvious shape below may not suit the result and state protocol `get` already has,
and this document has not read that protocol closely enough to prescribe one.

```text
required:   _active++   under _mu
            hook        outside _mu
            _active--   under _mu

not required: any particular arrangement of lock and unlock around them
```

**3TK-54 establishes the exact sequence against the real `get`, and reports what
the extra acquisition costs.** Neither is assumed here.

**`get_wait` counts as active** and leaves on the close broadcast. It holds the
mutex across `wait_until` at `pool.c3:368` and reports `CLOSED` when it wakes and
sees the flag — the path that already works at `pool.c3:351-352`.

**Taking the mutex is not a lifetime mechanism.** The pool advice's §12 states
it and the code proves it: the mutex is free for the whole of `on_get` and
`on_put`, which is exactly the window. A release that merely locked would sail
straight through it.

**Hook semantics are untouched by all of this.** `Part 12.2` — `on_close` called
once by close, and once more for each put that finds the pool closed while its
own hook ran — and `Part 12.3` — several hooks at once, unserialized — stand
exactly as written. **Nothing in this design orders one hook against another**,
and that is `Q-A`, closed in section 15.

---

# Part IV — Consequences

## 10. What stays unchanged

Named here so no stage widens the work. From the pool advice's §18 to §24 and
§28, and from the rulings already taken:

- **the flat bucket lookup** at `pool.c3:260` — O(identities), and the identity
  set is fixed at creation. No hash table.
- **`broadcast` after a put** at `pool.c3:443` — conservative, and correct first.
- **`count_of` answering 0 for an unknown identity** at `pool.c3:511` — it is an
  informational query, not a defect site.
- **`take_back_handle` as a hard failure** at `pool.c3:455` — ruled 2026-08-27.
- **`UNKNOWN_IDENTITY` as a checking-build defect** on `get` and `put`.
- **the stale `in_pool` hint** at `pool.c3:414` and `pool.c3:318`.
- **the `extra` mechanism** and the `Slot` transfer in `put` at `pool.c3:417-419`.
- **no `put_all`.**
- **the stack behaviour of a bucket.**
- **`Part 12.2` and `Part 12.3`**, and
  [3tk-on-close-policy-001.md](3tk-on-close-policy-001.md), which was ruled and
  closed on 2026-08-27 and is not reopened by this work.
- **both `release` signatures.**
- **the condition variable's job.** It wakes parked callers on close, as it does
  today, and nothing waits on the count.

## 11. What it costs, and what it no longer costs

**What the ruling costs:**

- **A violation is caught on the schedule it happens on, not on every schedule.**
  A program that breaks Rule 1 and interleaves harmlessly passes. This is the
  price, and it is the only real one. **The assertion is a contract check, not a
  race detector**, and section 13 says what that means for reading a green test
  run.
- **The caller carries a rule.** It is written in three places — section 4's list
  — and it is the sort of rule an application answers structurally, by joining
  its threads, rather than by writing code against it.

**What it no longer costs, all of which `-003` owed:**

- **`release` still cannot block.** No waiting on application code, no
  hook that can hold a release for ever, and **no deadlock clause** — the cycle
  where a hook waits on the release waiting for it cannot be built.
- **No new promise for the other ports.** `Q-D` shrinks to one word in an
  existing precondition, not a guarantee every port must implement.
- **No public signature change**, so no contradiction with the `Q5` ruling's
  *the client's code is unaffected either way*, and **3TK-50's examples are not
  affected**.
- **No question about hook ordering.** Nothing waits, so nothing can be read as
  serializing hooks.
- **The two `release_open_*` negatives stay tier 1** and `run-builds.sh` keeps
  its shape.

**What it costs on the calling path:** one increment and one decrement under a
mutex the call already holds, plus **one added lock in `Pool.get`** — section 9,
measured by 3TK-54 rather than assumed.

## 12. The `P6` interaction

`P6` — the pool cannot tell whether the close hook processed the items it was
given or dropped them — is untouched by the ruling and stays the owner's.

**Its lifetime blocker is removed either way.** Counting what went out against
what came back means nothing while a further `on_close` may still arrive from a
straggler `put`. **Said precisely:** after a release that obeys Rule 1, every
operation accepted before the closure has finished. That is what `_active == 0`
means, and it is not a promise that no thread anywhere still holds the pointer.

**What is not removed** is what *came back* means. The hook is handed an
`InnerQueue*` and may free items, leave items, or both:

```text
queue handed to hook
hook frees 3 items
hook leaves 2 items in the queue
```

Whether the pool observes *2 came back*, or whether the queue is the hook's from
that moment on, is the `InnerQueue` contract for who owns what, and it is not
written down. **`P6` needs that contract before its option 1 can be called
ready.**

---

# Part V — The programs this owes

## 13. Tests and negatives

Built in 3TK-53 and 3TK-54. **None of them has to be a flaky race.** A hook that
parks until the main thread has called release is a deterministic trigger for
exactly the window, and the port already has that shape in
`test/t_concurrency.c3`.

| file | stage | what it proves |
|---|---|---|
| `negative/release_open_mailbox.c3` | 53 | **unchanged, stays tier 1.** Rule 1 requires closed before released, so this must still abort in all four builds |
| `negative/release_open_pool.c3` | 54 | **unchanged, stays tier 1**, the same way |
| `negative/release_while_receiving.c3` | 53 | **new.** A receiver parked in `receive`, the owner releasing without waiting for it. **The assertion stops it.** Deterministic: the receiver is inside `wait_until` |
| `negative/release_during_on_put.c3` | 54 | **new.** `on_put` parks; the main thread releases. **The assertion stops it** where today the program corrupts memory quietly |
| `negative/release_during_on_close.c3` | 54 | **new.** The same for `close`'s own hook — proves the count covers `close`, not only the calls that look like work |
| `negative/release_with_straggler_put.c3` | 54 | **new.** A concurrent put produces the second `on_close`; the release sees a non-zero count and stops |
| `negative/release_not_quiet_pool.c3` | 54 | **new.** A `get_wait` parked when release runs — closed, woken, but not yet returned. **Closed is not quiet**, and this is the program that says so |

**All of them are ordinary tier-1 negatives**: they abort, in all four builds,
with a message naming the rule. **`run-builds.sh` gains rows and changes nothing
else**, and the moved check count is printed, not assumed.

**What a green run of these proves, and what it does not.** The third review's §5
asks for this next to the table, because the alternative reading is the dangerous
one:

> **Each program proves that when *that* violation is performed, the port stops
> instead of destroying.** Seven green programs do not prove that every program
> breaking Rule 1 is caught. **Nothing can prove that** — section 11 says why.

Test-suite cases:

- **`test/t_pool.c3` — the whole life cycle asserted, and it is the positive
  counterpart the third review's §12 asks for.** A worker parked in `get_wait`;
  `close` publishing CLOSED and waking it; the worker returning `CLOSED` and
  finishing; the count observed at zero; `release` succeeding. **CLOSED, then
  QUIET, then FREED, with an assertion at each step** — the negatives prove only
  that closed is not quiet, and this proves what the caller is supposed to do
  about it.
- `test/t_mailbox.c3` — close with `out`, then join, then release: the ordinary
  correct shape, run rather than reasoned about.
- `test/t_concurrency.c3` — the correct shape under load, repeated, under
  `run-sanitizers.sh` as well as `run-builds.sh`.

**One program the ruling means the port does not write:** anything proving that a
release *waits*. There is nothing to wait for.

---

# Part VI — What is open

## 14. Open questions

**Two, and neither blocks 3TK-53 or 3TK-54.**

### `Q-D` — the shared-specification clause. **The owner's.**

Two questions, not one:

> **`Q-D.1`** — does the Matryoshka specification state **closed and quiet before
> released** as a precondition on `release`, in the shared text, so that every
> port states it?
>
> **`Q-D.2`** — if it does, does 3TK-52 run before 3tk's code, or does 3tk go
> first under a written assumption naming which way it assumed?

**The ruling makes this much smaller than it was.** `-003` asked whether every
port must implement a waiting `release`. **This asks whether every port must
state a precondition** — one word in `Part 11.12` and a sentence beside it. A
port that cannot check it still states it.

**The vocabulary `closed / quiet / freed` is useful across all ports** and the
specification should carry it either way.

### `Q-F` — `P6`'s ruling. **The owner's.**

Its lifetime blocker is removed. Its own question — what *came back* means — is
untouched. Section 12.

### `Q-E`, closed by the ruling

3TK-50 asked where it fell against this work, because a changed `release`
signature would have been carried into every example. **No signature changes**,
so the examples tree is unaffected and the two lines of work are independent.
The ordering is the owner's, in the status file, and nothing here constrains it.

### `Q-G`, answered by the ruling

`W3` was drafted as a temporary warning — *the port does not yet stop a release
that races a call in flight* — to be written in and out again within days.
**Under the ruling it is permanent and it is the deliverable.** Section 4's *The
text this owes* is what goes in, and it does not come out.

**The seven questions plan 018 left and 019 carried are still open**, and are not
restated here.

## 15. Closed by the ruling

**Three questions and one contradiction. None of them was answered; all of them
stopped arising.** They are kept here with their reasons, so that a later reader
does not reopen a question that no longer has content.

### `Q-A` — hook serialization. **Does not arise.**

The question was whether `on_close` should wait for the `on_get` and `on_put`
calls already in flight, which would have made the lifetime counter into a hook
serializer and reopened `Part 12.2` and `Part 12.3`.

**Nothing waits.** `_active` is read once, by `release`, in an assertion. It
cannot order one hook against another because it never blocks anything. **The two
halves of the pool advice that disagreed — its §4, §8, §17, §30 against its
*Second advice* §5 and §15 — were disagreeing about a wait that no longer
exists.**

### `Q-B` — does `Mailbox.release` gain `InnerQueue* out`? **Does not arise.**

The question existed because a `release` that closed on the caller's behalf had
nowhere to put the items an open mailbox still held.

**Rule 1 requires the tool to be closed before it is released**, and
`Mailbox.close(out)` has already given them back. **`release` never sees a mailbox
with anything in it.**

### `Q-C` — does `Pool.release` gain one? **Does not arise.** Same reason: `Pool.close` has already given everything to `on_close`.

### The `Q5` contradiction. **Dissolved with `Q-B`.**

The second review called this the largest problem in `-002`: the `Q5` ruling of
2026-08-27 rested on **the client's code is unaffected either way**, while `Q-B`
proposed a public signature change that necessarily changed client code.

**No signature changes**, so the `Q5` ruling stands as written and needs no
re-wording. **What `Q5` does gain is a precondition** — closed **and quiet** —
which is a rule on when a caller may act, not a change to what they write.

---

# Appendix

## The feasibility probe, and what is left of it

**Run at 3TK-51, before the ruling.** A scratch module compiled against `3tk/src`
in all four builds: a `usz` counter under a `Mutex`, four worker threads entering
under the mutex, working **outside** it — the pool's hook window — and leaving
under it; a waiter blocking on the `ConditionVariable` until the counter reached
zero; the condition variable and the mutex destroyed and the memory freed
afterwards; and `wait_until` with no signal.

**What it printed, in every one of the four builds:**

```
== probe: counter + condition variable + destroy ==
  workers entered: 4
  release returned, cv and mutex destroyed, memory freed
  wait_until with no signal: fault, WAIT_TIMEOUT=true
PROBE OK
```

**Most of it is no longer load-bearing.** The probe was built to answer *can a
release wait for a counter and then destroy what it waited on*. **Nothing waits
any more**, so the waiting half of it is now background. Two findings survive and
are still used:

- **A `ConditionVariable` and a `Mutex` can be destroyed, and the block holding
  them freed, with no fault in any build.** Section 7 still needs this, and still
  does not know the exact order — the probe's structs were not the port's.
- **In the four builds tested, `wait_until` with no signal returned a fault, and
  that fault was `thread::WAIT_TIMEOUT`** — matching what `mailbox.c3:255-257`
  and `pool.c3:368-370` already rely on. **What four runs showed**, not a
  statement about the only value the standard library may return.

**One correction carried forward.** The line reading `release returned` is the
probe's own wording; **no `release` of this port ran.** What the run establishes
is that the sequence completed in a scratch module.

**The scratch module was written outside `3tk/`, run from there, and removed.
`3tk/` is clean.**

## Review history

**Two reviews, both by the same reviewer, both in `backup/`.** Their findings are
in the sections above; this is the record of where they came from.

**Round 1, on `-001` — twenty points.** It asked for the lifetime invariant to be
stated before the mechanism; for *active operation* to be defined rather than
described; for `close` to be counted as active; for the destruction ordering not
to be prescribed; for Race A and Race B to be named; and for the probe not to
overclaim. **Its sharpest contribution was the separation of lifetime waiting
from hook serialization**, which is what made `Q-A` answerable — and, in the end,
what made it unnecessary.

**Round 3, on `-004` — ten points, and a verdict.** It endorsed the ruling,
agreed with rejecting a waiting `release`, and closed by saying the remaining
work is verification of the C3 locking and destruction sequences **rather than
another architectural round**. Its ten clarifications are this version. **Two of
them corrected sentences INTR 6 wrote**: that `close` lowers the count before it
returns, which `-004` implied and never said, and that the ruling asks
*different* discipline rather than *less* — the argument being where the
responsibility sits, not how much of it there is.

**Round 2, on `-002` — thirty-three points.** Its central finding: the document
declared `Q-A` open and then wrote six sections as though one variant already
held. It also found three things missing — a hook must not wait on the release
waiting for it; the release wait must be a predicate loop and a broadcast is only
a wake-up; the `release_vs_close` programs had no oracle — and four claims
stronger than their evidence. **The first of the three missing items is now part
of why the ruling went the way it did.**

**Rounds 1 and 2 recommended the waiting design.** Neither was asked whether the
hazard should be absorbed by the port or stated as a rule; both were reviewing a
proposal that already assumed the first. **The ruling of 2026-08-28 answered the
question that was never put to them** — and round 3, which was asked, agreed with
it.

**Three rounds, twenty points then thirty-three then ten, and the third says
proceed.** That is convergence, and the port treats it as one: **reviewing of
this document stops here.**

## What changed from `-004`

**Ten clarifications from the third review. No decision changed, no section
moved.**

| | |
|---|---|
| **QUIET is a predicate** — `_closed && _active == 0`, never a stored field | §13 |
| **every public operation, `close` included, lowers the count before it returns** — so `close(); release();` in one thread is the ordinary shape and works | §3 |
| **`_active == 0` means no accepted operation is still inside** — not *nobody can touch this* | §2 |
| **the three rules stated as three**, with `_active` speaking only to the first | §2 |
| **`_active` covers an operation's access including the hooks it invokes**, not the body of one function | §7 |
| **the concurrency table made canonical** — `release` is concurrent with nothing, not even `close` | §4 |
| **the destruction sketch carries a guard**: no source is to be changed on the strength of it | §10 |
| **`Pool.get`'s locking is an invariant here and a sequence for 3TK-54**, which reads the existing protocol before arranging it | §8 |
| **what a green negative proves**, said beside the table: that violation is caught, not that all are | §5 |
| **a positive life-cycle test in `t_pool.c3`** — CLOSED, QUIET, FREED, asserted at each step | §12 |
| **corrected:** *asks less discipline* becomes *different discipline, at the boundary where the owner already has the answer* | §14 |

---

## What changed from `-003`

**Kept from `-004`.**

| | |
|---|---|
| **the ruling** | `release` **checks** for quiet instead of **waiting** for it. Everything below follows from that one word |
| **section 4 — new** | the three rules the port states and does not enforce, with the text they owe. Rule 1 is new; Rules 2 and 3 were scattered across `-003`'s sections 13 and 14 |
| **`Q-A`, `Q-B`, `Q-C`, the `Q5` contradiction** | moved to section 15, *closed by the ruling*, each with its reason. `-003` carried them as four blocking questions |
| **`Q-D`** | shrunk from *must every port implement a waiting release* to *must every port state a precondition* |
| **`Q-E`, `Q-G`** | closed and answered. `Q-G`'s warning is now permanent and is the deliverable |
| **section 0 of `-003`** | gone. It held working assumptions about questions that no longer exist |
| **the negatives** | no inversions. All seven abort, all four builds, `run-builds.sh` keeps its shape. `release_not_quiet_pool.c3` is new, for *closed is not quiet* |
| **the deadlock clause** | gone with the wait |
| **the predicate-loop rule** | gone with the wait |
| **the `release_vs_close` oracle** | gone with the wait — under Rule 1 the two do not race |
| **`_active`** | kept, in all four builds, maintained the same way. **The counter was never the expensive part** |
| **the probe** | narrowed to the two findings still used |
| **the whole document** | reorganized: contract, mechanism, tools, consequences, programs, open, appendix. The repetition the second review counted across a dozen sections is gone |

**One thing deliberately not removed:** every description of the hazard. The race,
the hook window, the parked receiver, why the mutex proves nothing. **A rule that
is not explained is a rule that gets deleted by someone who does not know why it
is there.**

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
| banned words, this file | **0 in prose.** The hits that remain are inside code blocks and are all the same stdlib call name, which Part 5 exempts |
| links | every link in this file printed and read |
