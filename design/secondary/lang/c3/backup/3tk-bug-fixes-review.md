# Review of bug fixes proposal


Overall: **the lifetime diagnosis is strong, and the core `_active + condition variable + release waits for zero` mechanism is the right direction. But the document is not yet ready to become an implementation stage.** There are several important contradictions, especially around `release`'s API and what exactly is counted.

## 1. The central lifetime model is good

The strongest part is the explicit separation:

> closed → quiet → freed

That is much clearer than the previous "closed before release" rule.

The important invariant should be made even more explicit:

> **An object may be freed only after `_closed == true` and `_active == 0`.**

Everything else should derive from this.

The proposed mechanism is sound **provided every operation that can touch the object is covered by `_active` for its entire lifetime**.

In particular, the document correctly catches the pool hook window:

```text
_active++
lock
...
unlock
on_put()
lock
...
on_close()
...
_active--
```

That is the key issue. Counting only the mutex-protected portion would not solve the actual UAF.

### Improvement

I would promote this to a named invariant near the beginning:

```text
Lifetime invariant

release may destroy the object only when:

    _closed == true
    _active == 0

Every operation increments _active before it can leave the mutex
and decrements it only after its last access to self is complete.
```

That gives 3TK-53/54 something much more precise to implement against.

---

# 2. Major contradiction: Q5 said "no client code changes"

This is the biggest problem in the document.

The earlier ruling says:

> "the client's code is unaffected either way"

But section 5 proposes:

```c3
fn void Mailbox.close(&self, InnerQueue* out)
fn void Mailbox.release(&self, InnerQueue* out)
```

and explicitly calls this:

> "Whether `release` gains the parameter at all is the owner's"

That **is a client API change**.

Existing:

```c3
mbox.release();
```

becomes:

```c3
InnerQueue iq;
mbox.release(&iq);
```

Therefore the document currently contains two incompatible statements:

1. Q5 was ruled on the assumption that client code does not change.
2. Q-B proposes a public signature change that necessarily changes client code.

This should not remain as a subordinate question.

### Recommendation

Reopen the wording of the Q5 ruling itself.

The real ruling should be something like:

> The lifetime fix must not require clients to change the lifetime protocol, but it may require a public signature change if necessary to preserve ownership of items.

Or, if "no client code changes" was an absolute requirement, then **Q-B has to be rejected**, and another way of handling mailbox contents must be designed.

I would not let 3TK-53 start until this is resolved.

---

# 3. Q-B is actually more fundamental than presented

The mailbox has no `on_close` hook.

That creates a hard ownership question:

```text
release(open mailbox)
        ↓
_close()
        ↓
items remain in mailbox
        ↓
mailbox memory is freed
```

Who owns those items after release?

The document correctly recognizes this and proposes `InnerQueue* out`.

But then it should say explicitly:

> **An open mailbox cannot safely be released without transferring its queued items somewhere.**

That turns Q-B from a stylistic API question into an ownership requirement.

I would classify it as:

**Q-B — required ownership decision**, not merely "one story across close and release."

---

# 4. `_close()` semantics need one correction

The proposed primitive says:

> returns at once if already closed

and:

> empties what the tool holds into caller's storage

That's fine, but there is an important distinction:

```text
_close(out)
```

must be **idempotent with respect to state**, but it cannot necessarily be idempotent with respect to `out`.

Example:

```text
close(&queue1)
release(&queue2)
```

After the first call, the mailbox is closed and its contents have already moved to `queue1`.

The second `_close(&queue2)` must not somehow move anything again.

So I'd specify:

> If already closed, `_close` performs no transfer and leaves `out` unchanged.

This matters because the proposed implementation is being used by both `close` and `release`.

---

# 5. `release` vs `close` is under-specified

The document says:

> release vs close — yes

But this needs a precise lifetime sequence.

For example:

```text
Thread A                         Thread B

close()
    _active++
    ...
    _close()
    ...
                                 release()
                                     lock
                                     _close()   // already closed
                                     wait
                                     ...
    ...
    _active--
                                 free
```

That is safe **only if `close()` itself is active until its last access to `self` is finished.**

The document explicitly discusses this for Pool's hook, but it should be stated as a general rule:

> **`close` is itself an active operation.**

For Mailbox this is probably short and uncomplicated.

For Pool it includes the `on_close` hook.

This also clarifies why:

```text
release vs close = supported
release vs release = unsupported
```

is possible.

---

# 6. `_active` must cover `close`, not only "calls"

The text repeatedly says:

> Every call raises the count on entry

That's slightly too vague.

The lifetime mechanism doesn't care whether something is called a "public API call." It cares whether code can still access `self`.

I recommend defining:

> **An active operation is any execution path that has acquired a valid object reference and may still access the object's memory.**

Then explicitly enumerate:

### Mailbox

* `close`
* `receive`
* relevant receive/wait paths
* other operations
* `release` is **not** active

### Pool

* `get`
* `get_wait`
* `put`
* `close`
* possibly queries if they can execute concurrently
* `release` is **not** active

This avoids an implementation mistake where someone counts only operations that "do useful work."

---

# 7. The fast-path lifetime boundary deserves stronger wording

Section 9 is correct and important:

> Release waits for calls already in flight.

But this is a particularly dangerous point and should be elevated into the API contract.

There are actually two different races:

### Race A — operation already entered

```text
put()
   ↓
_active++
   ↓
release()
   ↓
wait
```

**Protected.**

### Race B — stale pointer hasn't entered yet

```text
thread A:
    p.put()       // not yet executing inside p

thread B:
    p.release()
    free(p)

thread A:
    p.put()       // UAF
```

**Not protected.**

The document says this, but I would make the distinction a named rule because otherwise users will naturally read "release waits for calls" as a stronger guarantee than it is.

Suggested wording:

> `release` synchronizes with operations that have entered the object. It does not extend the lifetime of an object referenced by a thread that has not yet entered an operation.

That is a very important API boundary.

---

# 8. Q-A is presented as more complicated than necessary

The contradiction in section 7 is real, but I think the document can simplify the decision.

The lifetime counter should **not serialize hooks**.

The two mechanisms have different purposes:

```text
_active
    lifetime protection

hook serialization
    application synchronization
```

Making `_active` also serialize `on_close` would turn the lifetime mechanism into an application-execution policy.

That would be a substantial change to the already-established Part 12.2/12.3 semantics.

### My recommendation

**Q-A → Variant 1: no serialization.**

Keep:

```text
close
 └── on_close(batch)

put already in hook
 └── discovers closed
     └── on_close(stragglers)
```

and allow those hooks to overlap.

The `_active` counter simply ensures:

```text
release
    waits
       ↓
all on_close calls finished
       ↓
free
```

This gives the desired lifetime guarantee **without changing hook semantics**.

That is a much cleaner separation.

---

# 9. The document should explicitly distinguish "wait for hooks" from "serialize hooks"

This is currently the source of much of the confusion.

These are different:

### Serialization

```text
hook A
  ↓
hook B
```

### Lifetime waiting

```text
hook A ─────────┐
                ├── release waits
hook B ─────────┘
                         ↓
                       free
```

A pool can allow A and B concurrently while still guaranteeing that release waits for both.

I would add exactly this distinction to section 7.

---

# 10. Potential issue with the statement "almost every call already holds the mutex"

This is reasonable as a cost argument, but it risks hiding the actual implementation requirement.

The important statement isn't:

> almost every call holds the mutex

It is:

> **Every increment/decrement of `_active` is synchronized by the same mutex, and the increment must occur before the operation can execute outside that mutex.**

For Pool:

```text
lock
_active++
...
unlock
application hook
lock
...
_active--
unlock
```

For a waiting operation:

```text
lock
_active++
wait_until(...)
...
_active--
unlock
```

For an operation that exits because closed:

```text
lock
if closed:
    unlock
    return CLOSED
_active++
...
```

The ordering matters more than the performance claim.

---

# 11. The `release` algorithm needs to be written more precisely

Current:

```text
release  lock; _close(); while _active != 0 -> wait; ... ; destroy; free
```

I'd change the conceptual sequence to:

```text
release:
    lock
    _close(out)

    while _active != 0:
        wait

    destroy synchronization/state
    unlock
    free(self)
```

But there is one crucial question:

### When is the mutex unlocked?

You must ensure the mutex is not destroyed while still locked.

So the real final sequence must be something like:

```text
lock
_close(out)

while _active != 0:
    wait

destroy internal resources that do not require _mu

_mu.unlock()
_mu.destroy()
_cv.destroy()
allocator.free(self)
```

Or whatever exact ordering C3's synchronization objects require.

The document should not prescribe code until that destruction ordering is confirmed against the actual implementation.

The feasibility probe establishes that destruction after wait is possible, but it does **not by itself prove the exact destruction order of the real Mailbox/Pool objects**.

---

# 12. The feasibility probe is useful, but its conclusion is too broad

The probe proves:

* condition-variable waiting works;
* a counter can be protected by a mutex;
* the waiter can wait until zero;
* synchronization objects can subsequently be destroyed;
* the memory can then be freed.

Good.

But this sentence:

> "The design does not change. The probe did not refuse."

is weaker than it should be.

The probe does **not** validate:

* the actual Mailbox lifecycle;
* the actual Pool lifecycle;
* hook lifetime;
* concurrent `close`;
* concurrent `release`;
* destruction ordering in the real structs;
* C3 memory ordering around `_closed_fast`;
* the actual `_active` placement in the existing locking protocol.

I'd rename it:

> **Feasibility probe**

and say:

> The probe validates the required synchronization primitive pattern, not the correctness of the Mailbox/Pool implementation.

That prevents overclaiming.

---

# 13. The `on_close` straggler path is actually a strong argument for Variant 1

The document says:

> `put` ... lowered only after ... any straggler `on_close` at `:434`.

Correct.

That means the desired lifetime sequence becomes:

```text
put
 ├── active++
 ├── on_put
 ├── discovers closed
 ├── on_close(stragglers)
 └── active--

close
 ├── active++
 ├── close state
 ├── on_close(batch)
 └── active--

release
 ├── close state if necessary
 ├── wait active == 0
 └── free
```

This is elegant.

Notice that **no hook serialization is required**.

Both hooks can execute concurrently; `release` simply waits for both.

I think this should become the canonical model in the document.

---

# 14. P6 interaction needs one correction

The document says:

> P6's option 1 is unblocked by this work.

That is only true if the meaning of "what came back" is clearly defined.

The current text says:

> counts what it handed over and what came back

But the existing hook model apparently hands over an `InnerQueue*`, and the hook can process/free items.

What exactly constitutes "came back"?

For example:

```text
queue handed to hook
hook frees 3 items
hook leaves 2 items in queue
```

Does the pool observe:

```text
2 came back
```

or does the queue become inaccessible after the hook?

This needs to be tied to the actual `InnerQueue` ownership contract before P6 option 1 is called "unblocked."

I would change:

> P6's option 1 is unblocked

to:

> **Q5 removes the lifetime blocker for P6 option 1, but P6 still requires its own ownership/count semantics to be specified.**

That is safer.

---

# 15. The negative tests are good, but one important class is missing

The proposed tests are excellent, especially:

> `release_during_on_put`

and:

> `release_with_straggler_put`

Those are deterministic and much better than a sleep-based race.

I would add one explicit test for:

### release vs close

Because the document declares it supported.

Something like:

```text
thread A:
    close()

thread B:
    release()
```

The test should prove:

* no double close;
* no UAF;
* no deadlock;
* exactly one destruction.

Also add:

### close hook vs release

You already have `release_during_on_close`, so this is probably covered indirectly. Make the distinction explicit.

---

# 16. Concurrent `release` should not merely be "caller's responsibility"

The rule itself is reasonable:

> release vs release — no

But this should be presented as a **lifetime ownership rule**, not a concurrency rule.

Otherwise readers may wonder why:

```text
release vs put       yes
release vs close     yes
release vs release   no
```

The explanation is:

> `put` and `close` are operations on the object; `release` is destruction of the object.

Two ordinary operations can safely race with destruction because destruction waits for them. Two destruction operations cannot both own destruction.

I'd make that explicit.

---

# 17. Q-E should probably not remain in this document

Q-E:

> where does 3TK-50 fall?

This is project scheduling rather than a lifetime design question.

It weakens the document's role as the implementation specification.

I would move Q-E to the project tracking document and keep here only:

> 3TK-50 examples must be updated if the public `release` signature changes.

Likewise, Q-G is mostly scheduling/documentation.

The core lifetime document should ideally contain:

* semantic decisions;
* implementation invariants;
* API consequences;
* tests.

Not general project ordering.

---

# 18. The document has too many "question layers"

There are currently:

* Q-A through Q-G
* P6
* 3TK-52
* 3TK-53
* 3TK-54
* previous Q5
* previous P6
* previous on-close ruling

This makes it difficult to identify **what actually blocks implementation**.

I would reduce section 14 to three decisions:

### D1 — hook semantics

Keep existing concurrent hook semantics or serialize them.

**Recommendation: keep existing semantics.**

### D2 — mailbox release ownership

How does `release(open mailbox)` return queued items?

**Recommendation: `InnerQueue* out`.**

### D3 — shared specification

Does the new lifetime guarantee become a shared Matryoshka rule?

This is the real cross-port decision.

Everything else is implementation or tracking.

---

# 19. The shared-spec question should be phrased more precisely

Current:

> Does 3TK-52 run before the code?

That's procedural.

The real semantic question is:

> **Does the Matryoshka specification require `release` to wait until all operations already in flight have returned?**

Then separately:

> If yes, do all ports implement that guarantee before claiming conformance?

That's much cleaner.

And the specification should distinguish:

```text
closed
quiet
freed
```

because that vocabulary is now useful across all ports.

---

# 20. One terminology issue: "release closes if it must"

This is slightly misleading.

`release` doesn't merely "close if it must."

It should conceptually be:

> **release performs the close transition if necessary, waits for quiescence, then destroys the object.**

That is the complete lifecycle operation.

I'd use:

```text
close:
    transition to closed and return

release:
    transition to closed if necessary
    wait for quiescence
    destroy
```

This makes the relationship between the two APIs very clear.

---

# Recommended revised architecture

I think the document becomes much stronger if the implementation model is reduced to this:

```text
                 ┌──────────────┐
                 │    OPEN      │
                 └──────┬───────┘
                        │ close / release
                        ▼
                 ┌──────────────┐
                 │    CLOSED    │
                 │ no new entry │
                 └──────┬───────┘
                        │
                 existing operations
                    finish
                        │
                        ▼
                 ┌──────────────┐
                 │    QUIET     │
                 │ active == 0  │
                 └──────┬───────┘
                        │ release
                        ▼
                 ┌──────────────┐
                 │    FREED     │
                 └──────────────┘
```

With one invariant:

```text
free(self) is legal only when:

    _closed == true
    _active == 0
```

And one lifetime rule:

```text
_active covers the complete operation,
including every period in which application code
is executing with references derived from self.
```

And one API rule:

```text
release may race ordinary operations and close.

release may not race another release.
```

---

## My recommended decisions

| Question                   | Recommendation             | Reason                                                                            |
| -------------------------- | -------------------------- | --------------------------------------------------------------------------------- |
| Q-A hook serialization     | **No**                     | preserves Part 12.2/12.3 and keeps lifetime separate from hook synchronization    |
| Q-B Mailbox `release(out)` | **Yes, probably required** | otherwise an open mailbox has no ownership destination for queued items           |
| Q-C Pool `release(out)`    | **No**                     | existing `on_close` already provides the ownership transfer mechanism             |
| Q-D shared spec first      | **Yes**                    | this is a semantic contract, not merely a 3tk implementation detail               |
| Q-E scheduling             | **Move out**               | project ordering, not lifetime design                                             |
| Q-F P6                     | **Keep separate**          | lifetime fix removes its blocker but does not answer its ownership/count question |
| Q-G W3                     | **Move to tracking**       | documentation scheduling, not implementation design                               |

### Most important correction

I would **not let 3TK-53/54 start with the document in its current form**.

Resolve these first:

1. **Q5 vs Q-B contradiction** — the release signature change contradicts the earlier "client code is unaffected" statement.
2. **Confirm no hook serialization**.
3. **Define exactly what counts as `_active`**, especially `close`.
4. **Define the `release` destruction ordering**.
5. **Decide the shared-specification rule**.

After those five, the actual implementation is relatively straightforward.

The core idea itself is good. In fact, I think the strongest architectural result of this review is that **`_active` should be treated strictly as a lifetime/quiescence mechanism, not as a hook or concurrency serialization mechanism**. That separation resolves most of the apparent complexity in the document.
