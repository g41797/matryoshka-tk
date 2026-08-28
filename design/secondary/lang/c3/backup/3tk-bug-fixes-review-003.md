I agree with the **direction of the verdict**: the ruling is substantially better than the previous “`release` waits for quiet” design. It preserves the existing API, avoids making destruction responsible for application-controlled execution, and makes the caller's lifetime responsibility explicit.

But I would **not yet treat this document as implementation-ready**. There are a few important technical inconsistencies that should be fixed before 3TK-53/54 become code.

## Verdict

### 1. The central ruling is sound

This is the strongest part:

> **Release while a call is in flight is not prevented. It is written down as a thing the caller must not do, and it is checked. It is not waited for.**

I would keep this ruling.

The key distinction is correctly made:

```text
OPEN -> CLOSED -> QUIET -> FREED
```

and:

```text
closed != quiet
```

That is the essential lifetime model.

In particular, the document correctly rejects:

```text
release()
    close()
    wait until _active == 0
    free()
```

because the operation may contain application code:

```text
Pool.get()
    ...
    on_get(...)
    ...
```

or:

```text
Pool.put()
    ...
    on_put(...)
    ...
```

The toolkit should not turn `release()` into a synchronization operation over arbitrary application code.

For the Matryoshka design, this is a good boundary: **the owner is responsible for coordinating the lifetime of its threads/tasks; the pool/mailbox protects its internal concurrent state.**

---

# 2. The biggest problem: `_active` does NOT solve the stale-pointer race

The document knows this, and section 4 Rule 3 states it correctly:

> The port's protection begins when an operation is accepted.

But I think the document still gives `_active` slightly too much conceptual weight.

Consider:

```text
A                              B

p.put()                         p.release()

                                _closed = true
                                _active == 0
                                free(p)

A enters p.put()
```

`B` legitimately sees:

```text
_closed == true
_active == 0
```

and frees.

Then A dereferences `p`.

So `_active` protects:

```text
already accepted operations
```

but **cannot protect the lifetime of the pointer itself**.

This means the actual contract should be mentally separated into two independent rules:

```text
Rule A:
No new operation may enter after CLOSED.

Rule B:
Owner must not release until all previously accepted operations
have finished.

Rule C:
Owner must also ensure no thread can start a new operation
using the pointer after release.
```

The document has all three ideas, but I would make the distinction even sharper.

Otherwise someone implementing 3TK-54 may unconsciously think:

> `_active == 0` means nobody can touch the object.

It does not.

It means:

> **No currently accepted operation is still inside the object's lifetime domain.**

That's a much safer implementation statement.

---

# 3. There is an important inconsistency around `close`

The document says:

> `close` is active for its whole body

and later:

> `release` invokes `_close` if the tool is still open

while `_close()` itself:

> runs with the mutex already held.

This needs one precise definition.

Suppose:

```text
Thread A                     Thread B

close()
  lock
  _active++
  _close()
  ...
  unlock

                             release()
                               lock
                               assert(_active == 0)
```

Fine.

But now consider the caller doing:

```text
close();
release();
```

in one thread.

Should `close()` decrement `_active` before returning?

Obviously yes.

Therefore the invariant needs to be:

```text
when a public operation returns,
_active has already been decremented.
```

That should be stated explicitly.

Otherwise the phrase:

> close is active for its whole body

is correct but insufficiently precise for implementation.

I'd add:

> **Every public operation, including `close`, leaves the active set before it returns. `release` may only observe `_active == 0` after acquiring the mutex.**

That makes the lifecycle mechanically understandable.

---

# 4. `release` itself being outside `_active` is correct

I agree with:

> `release` is never counted.

Trying to count it creates nonsense:

```text
_active = 1       // release itself
wait for _active == 0
```

and introduces a self-dependency.

So this part should remain exactly as designed.

There is, however, a second ownership rule that deserves stronger wording:

```text
release is an owner operation, not an ordinary concurrent operation.
```

I would describe the supported concurrency as:

```text
ordinary operations:
    concurrent

close:
    concurrent with ordinary operations

release:
    NOT concurrent with any operation
    NOT concurrent with close
    NOT concurrent with another release
```

The document already says this in pieces. I think it should become the canonical concurrency table.

---

# 5. The `release` check itself is inherently a contract check, not a race detector

This paragraph is excellent:

> It catches a violation on the schedule it happens to see. A program that breaks the rule and interleaves harmlessly today passes today. A wait would have been correct on every schedule; a check is not.

Keep this.

It is important because otherwise the negative tests could create a false impression:

```text
negative test passes
    =>
lifetime protocol is safe
```

No.

The negative tests prove:

> **When this particular violation is observed, the implementation detects it instead of proceeding to destruction.**

They do not prove that all bad programs are detected.

That distinction should perhaps be repeated once in the test section.

---

# 6. The parked receiver argument is good

This is one of the strongest concrete examples in the document.

The important sequence is:

```text
receive()
    _active++
    wait_until()
```

then:

```text
close()
    _closed = true
    broadcast()
```

The receiver wakes, but it is still an active operation.

Therefore:

```text
closed
```

does not imply:

```text
quiet
```

and:

```text
close()
release()
```

is not necessarily legal.

The caller needs:

```text
close()
join(receiver)
release()
```

This is exactly the kind of example that makes the lifetime contract understandable.

---

# 7. Pool hook handling is correct in principle, but implementation detail needs care

I agree strongly with this:

```text
_active++
unlock
on_put(...)
lock
...
_active--
```

and especially the observation that the counter must cover **the complete hook window**.

The same applies to:

```text
get -> on_get
```

and:

```text
close -> on_close
```

and the second `on_close` generated by a racing `put`.

This is the important invariant:

> **If application code can still execute with a reference derived from the pool, the pool operation remains active.**

That is better than trying to enumerate hook types.

However, I would change one conceptual sentence:

> “`_active` must cover the whole call, hook window included.”

to something closer to:

> **`_active` covers the whole lifetime of the operation's access to the pool, including every application hook invoked by that operation.**

Why?

Because “whole call” can become misleading if implementation later has helper functions, callbacks, or internal paths.

The lifetime property matters, not the syntactic function boundary.

---

# 8. One potentially dangerous statement: “one added lock in Pool.get”

This needs verification before being accepted as a design conclusion.

The document says:

> This is the one added lock in the design — `get` does not re-take the mutex today, and a count that covers its hook must.

That is probably correct **if `on_get` is currently called outside `_mu`** and the implementation needs to decrement `_active` under `_mu`.

But the exact implementation should not necessarily mean:

```text
lock
_active++
unlock

on_get()

lock
_active--
unlock
```

without checking whether the existing `get` result/state protocol allows that safely.

The key invariant is simply:

```text
_active++       under _mu
hook            outside _mu
_active--       under _mu
```

The actual lock placement should follow from the existing `get` implementation.

So I would retain the requirement but make 3TK-54 responsible for verifying the exact sequence.

---

# 9. `_close()` design is good

I agree with the private primitive:

```text
_close()
```

being:

* called with mutex already held
* idempotent
* responsible for `_closed`
* responsible for `_closed_fast`
* responsible for moving internal contents
* responsible for wakeup
* never responsible for destruction
* never responsible for unlocking

This is a clean separation.

Especially good:

```text
public close
    lock
    _active++
    _close(...)
    ...
    _active--
    unlock
```

versus:

```text
release
    lock
    _close(...)
    assert quiet
    ...
```

The document correctly avoids:

```text
release -> public close -> lock again
```

---

# 10. But Section 7 should remain explicitly unresolved

I agree with the document refusing to decide:

> can the mutex be destroyed while it is held?

That must be verified against the actual C3 synchronization implementation.

The feasibility probe does **not** establish the exact destruction order for the real Mailbox/Pool structures.

So this is correct:

```text
3TK-53 establishes the exact order
```

rather than this document prescribing one.

I would actually strengthen the wording:

> **No implementation should be changed based on the destruction-order sketch in section 7.**

That prevents the sketch from accidentally becoming an implementation instruction.

---

# 11. The `P6` analysis is correct

The lifetime ruling does remove the lifetime uncertainty:

```text
release
    only after _active == 0
```

means all operations accepted before closure have finished.

But it does **not** answer:

```text
what does the on_close hook own?
what does it return?
who owns items remaining in InnerQueue?
```

That is genuinely separate.

So keeping P6 open is correct.

---

# 12. The tests are well chosen

The new negative tests are much better than trying to manufacture probabilistic races.

Especially:

```text
release_during_on_put
release_during_on_close
release_with_straggler_put
release_not_quiet_pool
```

These turn the lifetime violation into deterministic protocol violations.

I would keep the principle:

> **Tests should prove the contract boundary, not depend on winning a scheduler race.**

One addition I'd recommend is a positive test specifically proving:

```text
close
    -> operation wakes
    -> operation returns
    -> _active reaches 0
    -> release succeeds
```

because the negative parked-receiver test proves only:

```text
closed + active != quiet
```

The positive test proves the entire intended lifecycle:

```text
CLOSED -> QUIET -> FREED
```

The document already proposes something close to this in `t_concurrency.c3`; I'd make the assertion explicit.

---

# 13. One terminology issue

The four-state model is useful:

```text
OPEN
CLOSED
QUIET
FREED
```

But strictly speaking, **QUIET is not necessarily a persistent state**.

It is better understood as a predicate:

```text
_closed == true && _active == 0
```

because after:

```text
OPEN -> CLOSED
```

there can be no new accepted operations, so eventually:

```text
_active -> 0
```

and then the object is quiet.

I would therefore phrase it as:

```text
OPEN -> CLOSED
          |
          v
       QUIET
          |
          v
       FREED
```

but define:

> **QUIET is the condition `_closed == true && _active == 0`, not an independently stored state.**

This avoids someone later adding:

```c3
_quiet
```

which would be unnecessary.

---

# 14. The one thing I would change in the verdict itself

The document says:

> Rule 1 asks less discipline than the alternative

I don't think that's quite right.

It asks **different discipline**, and arguably discipline that is more natural for the owner.

Waiting design:

```text
owner:
    close
    release
```

with toolkit handling synchronization.

Ruling design:

```text
owner:
    close
    wait/join workers
    release
```

So the application has more explicit responsibility.

What is true is:

> **The ruling puts the responsibility at the correct ownership boundary instead of making the toolkit responsible for waiting on application-controlled execution.**

That's a stronger and more precise argument.

---

# Overall verdict

I'd rate this version **very strong as a design ruling**, with the following status:

| Area                                       | Verdict                                                |
| ------------------------------------------ | ------------------------------------------------------ |
| Reject waiting `release`                   | **Agree**                                              |
| `closed != quiet`                          | **Essential and correct**                              |
| `_active` under existing mutex             | **Agree**                                              |
| `_active` includes hooks                   | **Agree, critical**                                    |
| `_active` includes `close`                 | **Agree**                                              |
| `release` excluded from `_active`          | **Agree**                                              |
| caller must join/coordinate before release | **Agree**                                              |
| stale-pointer rule                         | **Correct, but emphasize independence from `_active`** |
| concurrent `release`                       | **Correctly unsupported**                              |
| `_close()` private/idempotent              | **Agree**                                              |
| no API change                              | **Strong consequence**                                 |
| parked receiver                            | **Correct and important**                              |
| deterministic negative tests               | **Good approach**                                      |
| P6 remains open                            | **Correct**                                            |
| mutex/CV destruction order                 | **Correctly left open**                                |
| exact `Pool.get` locking                   | **Must be verified by 3TK-54**                         |
| terminology `QUIET`                        | **Make it a predicate, not a stored state**            |

### My recommended final ruling

I would accept the architecture with **three small editorial/technical clarifications before implementation**:

```text
1. _active means "accepted operation still capable of accessing self".
   It does NOT protect a stale pointer before entry.

2. QUIET is a predicate:
       _closed && _active == 0
   not a fourth stored state.

3. Every public operation, including close, decrements _active
   before returning. release is outside the active protocol and
   requires the caller to have established quietness.
```

With those clarifications, I think the central decision is solid:

```text
                 toolkit responsibility
                         |
OPEN -> CLOSED ----------+---- reject new operations
          |
          | _active drains naturally
          v
        QUIET
          |
          | owner is responsible for getting here
          v
        FREED
```

**I would proceed with 3TK-53/54 on this basis rather than reopen the “should release wait?” question.** The remaining work is verification of the concrete C3 locking/destruction sequences, not another architectural debate.
