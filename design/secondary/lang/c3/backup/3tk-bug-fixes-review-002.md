I reviewed the revision as a design/specification document, not as an implementation. The main direction is much stronger than -001, but there are several internal contradictions and a few places where the document claims more than its stated evidence supports.

The most important issue is that Q-A is presented as open, while several later sections already depend on Variant 1 (no hook serialization). Q-B/Q-D are genuinely unresolved, but Q-A is not completely neutral in the current text.

Here is the review in ready-to-copy Markdown.

I reviewed the revision as a **design/specification document**, not as an implementation. The main direction is much stronger than `-001`, but there are several internal contradictions and a few places where the document claims more than its stated evidence supports.

The most important issue is that **Q-A is presented as open, while several later sections already depend on Variant 1 (no hook serialization)**. Q-B/Q-D are genuinely unresolved, but Q-A is not completely neutral in the current text.

Here is the review in ready-to-copy Markdown.

# 3tk lifetime-fix-002 — review and advice

## Overall assessment

This revision is substantially better than `-001`.

The central lifetime model is now clear:

```text
OPEN -> CLOSED -> QUIET -> FREED
```

and the important invariant is correctly made explicit:

```text
free(self) is legal only when:

    _closed == true
    _active == 0
```

The strongest improvement is the separation between:

* **lifetime protection** — `_active`
* **hook serialization** — ordering of application callbacks

That distinction is important and should remain.

However, the document is **not yet internally clean enough to serve as the final implementation specification**.

There are four categories of problems:

1. contradictions between sections;
2. places where an "open question" is already implicitly decided;
3. terminology/protocol ambiguities around entering an operation;
4. evidence claims that are stronger than the described feasibility probe.

The implementation should not start from this document unchanged.

---

# 1. Major contradiction: Q-A is declared open, but Variant 1 is already assumed

The document says:

> **Q-A — hook serialization. The one that decides 53 and 54.**

and later:

> **Nothing outside 3tk changes.**

for Variant 1.

It also says:

> The current code is correct against the specification as written.

and section 11 repeatedly describes the implementation in terms of concurrent hooks.

More importantly, section 9 explicitly requires:

> `_active` must cover the whole call, hook window included.

and section 18 defines:

> `release_during_on_put`

with the expected behavior that release waits while `on_put` is running.

That is compatible with both serialization variants.

But section 18 also defines:

> `release_with_straggler_put.c3`

and says release waits for both calls.

That test **implicitly assumes that the straggler `on_close` model remains**.

Therefore Q-A is formally open, but the rest of the document is already written mostly as though:

```text
Q-A = Variant 1
```

### Advice

Either:

### Preferred

State explicitly:

```text
This document uses Variant 1 (no hook serialization) as the implementation
assumption for 3TK-53/54, subject to owner confirmation of Q-A.
```

Then clearly mark the implementation as **conditional on Q-A**.

Or, if the owner really wants Q-A completely open, remove the Variant-1-dependent statements from sections 9, 11, 17, 18 and 20 until the decision is made.

The current halfway state is confusing.

---

# 2. Q-D is also partly pre-decided

Q-D asks:

> Does the Matryoshka specification require `release` to wait until every operation already in flight has returned?

But section 2 already calls this:

> **The lifetime invariant**

and section 6 states:

> `release` transition to closed if necessary, wait for quiescence, destroy.

The whole document is consequently built around:

```text
release -> wait for _active == 0 -> destroy
```

So there are actually two different questions:

```text
Q-D.1
Is this the intended shared Matryoshka semantic contract?

Q-D.2
Does 3tk implement that contract?
```

The document asks Q-D.1, but almost every section already assumes the answer is yes.

### Advice

Make the distinction explicit.

For example:

```text
The proposed 3tk lifetime model is:

    release closes, waits for quiescence, then destroys.

This is the implementation/design assumption of this document.

Q-D asks whether this assumption is also a mandatory shared Matryoshka
specification rule.
```

That makes the dependency much clearer.

---

# 3. "Closed means no new call may enter" is too strong

Section 2 says:

> **closed | no new call may enter**

Section 14 correctly explains the stale-pointer race:

```text
thread A:  p.put()      // not yet inside p
thread B:  p.release()
thread A:  p.put()      // enters freed memory
```

These two statements are therefore not completely compatible.

The `_closed` flag can prevent a call that **successfully acquires the mutex before accessing the object further** from becoming active.

It cannot prevent arbitrary code from dereferencing a stale pointer after the object has been freed.

### Advice

Define "enter" precisely.

For example:

```text
closed
    A call that acquires the tool's synchronization state after closure
    cannot become an active operation.

This does not protect a stale pointer that has not yet reached the tool's
entry protocol.
```

Then section 14 becomes the formal explanation of that rule.

---

# 4. Section 5 contains a real protocol contradiction

The protocol says:

```text
enter    lock; if closed -> leave with CLOSED; _active++
```

That is good.

But the "call that exits closed" diagram says:

```text
lock
if closed:
    unlock
    return CLOSED
_active++
...
```

This is correct.

The problem is the sentence immediately before it:

> Every raise and every lower of `_active` is under the same mutex, and the raise happens before the operation can execute outside that mutex.

For a call that discovers `_closed`, there is **no `_active` raise**.

That is fine, but the document should explicitly distinguish:

```text
successful entry:
    lock
    check closed
    increment active
    unlock
    execute

rejected entry:
    lock
    check closed
    unlock
    return CLOSED
```

### Advice

Replace the generic phrase "Every operation raises `_active`" with:

> Every operation that is accepted after the closed check raises `_active`
> before it can execute outside the mutex.

This also aligns better with the definition in section 3.

---

# 5. "Every operation raises _active" conflicts with the definition of active operation

Section 2 says:

> Every operation raises `_active` before it can leave the mutex.

Section 3 defines active as:

> any execution path that has acquired a valid reference to the tool and may
> still access its memory.

But `close` is special, because it must become active before publishing closed.

And a rejected operation never becomes active.

Therefore the actual rule is not:

```text
every operation -> active
```

It is:

```text
every operation that may access self after leaving the entry mutex
    -> active
```

### Advice

Use this as the single normative rule throughout the document.

---

# 6. Section 7 has an important unresolved API ambiguity

It says `_close()`:

> empties what the tool holds into the caller's storage

and:

> If the tool is already closed, `_close` performs no transfer and leaves
> `out` exactly as it found it.

This is good.

But `_close()` is described as a private primitive shared by:

```text
close
release
```

The caller-owned `out` therefore becomes part of the lifetime operation.

For Mailbox this is understandable.

For Pool, however, section 7 says the pool's `_close()` empties buckets into the caller's queue, while Q-C later asks whether `Pool.release` has an `out` parameter at all.

This means the document is mixing:

```text
_close(out)
```

with:

```text
public Pool.release(...)
```

without fully separating the private primitive's needs from the public API.

### Advice

Specify separately:

```text
Mailbox._close(out)
Pool._close(out)
```

and then state for each public operation which storage receives the transferred contents.

That will make Q-B and Q-C much easier to resolve.

---

# 7. The mailbox release API question is correctly identified, but the argument is slightly overstated

Section 10 says:

> An open mailbox cannot be released safely without transferring the items it
> still holds to somewhere the caller owns.

This is true **under the current mailbox ownership model**, but it is not a universal lifetime requirement.

Another valid design could be:

```text
release()
    close
    discard remaining messages
    destroy
```

or:

```text
release()
    close
    transfer contents to an internally defined owner
    destroy
```

The real requirement is therefore not:

> cannot be released safely

but:

> cannot be released without defining what happens to its remaining contents.

### Advice

Use:

> An open mailbox cannot be released safely **without defining the ownership
> transition of the items it still holds.**

Then `Mailbox.release(&out)` becomes the review's recommended solution, rather than being presented as logically forced by lifetime safety itself.

---

# 8. The `defer` example depends entirely on Q-B

Section 10 presents:

```c3
InnerQueue iq;

defer queue_outers_release(&iq);
defer mbox.release(&iq);
```

as the intended pattern.

But Q-B is still open.

Therefore this should not appear as though it is already part of the API.

### Advice

Label it:

```text
If Q-B is accepted, the intended usage is:
```

This is a small documentation issue, but important because this document repeatedly says that questions remain open.

---

# 9. Section 8 is correctly cautious, but its sequence contains a hidden dependency

The conceptual sequence is:

```text
lock
_close(out)

while _active != 0:
    wait

destroy whatever does not need _mu
unlock _mu
destroy _mu
destroy _cv
free
```

This is deliberately called a sketch.

Good.

However, `_close()` broadcasts while the release thread is holding the mutex.

That is normally fine because waiters cannot proceed until the mutex becomes available.

But the document should make the invariant explicit:

```text
broadcast does not mean that waiters execute immediately.
They become eligible to continue after the releasing thread unlocks.
```

This matters because the document uses `broadcast` as both:

* wake-up mechanism for ordinary waiters;
* wake-up mechanism for the lifetime waiter.

### Advice

Do not over-specify C3 behavior here, but state the required protocol:

> The release wait must be performed as a predicate loop under the same mutex.
> A broadcast is only a wake-up; `_active == 0` is the condition.

This makes the design independent of scheduling behavior.

---

# 10. Potential deadlock scenario is not explicitly analyzed

The document says release may wait for application hooks.

That means:

```text
release()
    waits for on_put()
```

The document correctly accepts this.

But there is a potentially important application-level cycle:

```text
on_put()
    waits for something
        that waits for release()
```

Then:

```text
release -> on_put
on_put -> release
```

deadlocks.

This is not necessarily a toolkit defect. It is a consequence of making release wait for application code.

The document currently says:

> a slow `on_put` stalls every closer

but does not clearly state the stronger consequence:

> an application hook must not depend on completion of the release that is
> waiting for that hook.

### Advice

Add a short application constraint:

```text
Because release waits for active hooks, application hooks must not require
the completion of the release operation that is waiting for them.
```

Do not turn this into hook serialization or extra synchronization.

---

# 11. `close` being active is correct, but the reason should be stated more precisely

Section 4 says:

> close holds a reference and keeps touching self after it has published the
> closed flag.

Correct.

The important reason is actually:

```text
close()
    may execute application code after publishing CLOSED
```

for Pool.

For Mailbox, `close` may not have application hook code.

Thus:

```text
Mailbox.close
    active because its implementation accesses self until return

Pool.close
    active especially because its hook runs after CLOSED is published
```

### Advice

Keep the general rule, but explain the pool case as the motivating example rather than implying all `close` calls have the same long-lived window.

---

# 12. Section 9 correctly identifies the `put` hook window, but misses one explicit invariant

This is the strongest implementation section.

It correctly identifies:

```text
unlock
on_put
lock
```

and explains why `_active` must cover the entire interval.

However, the essential rule should be made explicit:

```text
A thread may unlock the pool mutex while remaining an active operation.
```

This is the key reason that:

```text
mutex ownership != lifetime ownership
```

### Advice

Add this as a normative sentence:

> `_active` remains held while the operation is outside the pool mutex and
> executing application code.

That would make section 11 almost unnecessary to infer.

---

# 13. The straggler `on_close` model is dependent on Q-A

Section 9 says:

> after any straggler `on_close` at `:434`.

Section 11 then uses the straggler model as the example proving that lifetime and serialization are separate.

This is logically valid **only if Q-A chooses no serialization**.

Therefore these sections should be explicitly tagged as:

```text
Variant 1 / no serialization
```

until Q-A is ruled.

Otherwise a future reader may incorrectly believe the document has already decided Q-A.

---

# 14. Section 13's "release may not be concurrent" needs a stronger ownership formulation

The document says:

> Calls on a mailbox or a pool may be concurrent. Release may not.

This is good, but slightly ambiguous.

Does it mean:

```text
release may not overlap another release
```

or:

```text
release may only be called by a unique owner
```

The subsequent explanation indicates the second.

### Advice

Make the actual rule:

> A Mailbox or Pool has exactly one destruction owner. That owner may call
> `release` once. Concurrent calls to `release` on the same object are not
> supported.

Then:

```text
release vs get        supported
release vs put        supported
release vs close      supported
release vs release    unsupported
```

becomes an immediate consequence.

---

# 15. The release-vs-release example is missing a race detail

The document gives:

```text
Thread A                    Thread B
release()                   release()
  _close()                    sees closed
  free(mb)                    free(mb)
```

This is directionally correct, but it suggests B necessarily sees `_closed`.

A different interleaving is:

```text
A: release
B: release

A and B both race toward the entry protocol
```

The deeper point is simply that there is no lifetime reference count protecting **two destruction owners**.

### Advice

Avoid presenting one exact interleaving as the reason.

Use:

> If two callers concurrently invoke `release`, there is no supported ownership
> protocol that assigns destruction to exactly one caller. The behavior is
> unsupported.

That is more precise.

---

# 16. Section 14's Race B is very important and should be elevated

This is one of the best parts of the document.

However, it currently appears as a limitation after a lot of implementation detail.

It is actually part of the fundamental lifetime contract.

The model is:

```text
entered operation
    protected by _active

not-yet-entered stale reference
    NOT protected
```

### Advice

Put this directly next to the lifetime invariant.

Suggested terminology:

```text
Lifetime protection begins at the successful operation-entry point.
It does not provide ownership of the object pointer itself.
```

This prevents readers from interpreting `_active` as a reference-counting system.

---

# 17. The feasibility probe does not prove "release returned"

This is the largest evidence problem.

The probe demonstrates something like:

```text
workers
    enter
    work
    leave

waiter
    waits for active == 0

destroy synchronization objects
free memory
```

That is useful.

But the document reports:

> `release returned, cv and mutex destroyed, memory freed`

while explicitly saying:

> The probe says nothing about the correctness of the Mailbox or the Pool implementation.

If the scratch probe did not actually implement the real Mailbox/Pool release protocol, then it did **not** prove that `release` returned.

It proved that a synchronization pattern equivalent to release can wait and then destroy.

### Advice

Change the wording to:

> the release-shaped synchronization sequence completed, the CV and mutex
> were destroyed, and the memory was freed.

Then distinguish:

```text
probe proves:
    C3 synchronization/destruction pattern is feasible

3TK-53/54 must prove:
    actual Mailbox/Pool release implementation
```

This is much harder to challenge.

---

# 18. The probe's `WAIT_TIMEOUT` claim needs tighter wording

It says:

> `wait_until` with no signal returns a fault, and that fault is
> `thread::WAIT_TIMEOUT`.

That may be correct according to the actual C3 environment, but the described probe does not establish whether this is:

* the only possible return;
* the documented contract;
* or simply what happened in this test.

Since this document says the probe is only feasibility evidence, avoid making it a broader language/library specification.

### Advice

Use:

> In the tested four builds, `wait_until` with no signal returned
> `thread::WAIT_TIMEOUT`, matching the behavior relied upon by the current
> mailbox and pool code.

That is exactly what the evidence supports.

---

# 19. "No measurable cost" should be removed

Section 5 says:

> can protect one more field at no measurable cost

This is not needed and is weaker than the rest of the document.

A synchronization field can affect:

* cache layout;
* contention;
* generated code;
* critical-section duration.

The design does not depend on proving zero cost.

### Advice

Replace with:

> The existing mutex already protects the relevant state, so `_active` can use
> the same synchronization domain without introducing another synchronization
> primitive.

That is both stronger and easier to defend.

---

# 20. `_closed_fast` ordering is mentioned but not specified

Section 7 says:

```text
publishes `_closed_fast` with RELEASE
```

Section 8 explicitly says memory ordering is not settled.

This creates an inconsistency in presentation.

If `RELEASE` is already part of the required implementation, why is:

> the memory ordering around `_closed_fast`

listed under what remains to be established?

### Advice

Choose one:

### Option A — specification

State why the RELEASE store is required and what corresponding load/acquire rule
exists.

### Option B — implementation detail

Say:

> `_close` publishes the fast-path closed state using the ordering required by
> the existing fast-path protocol.

Then leave the exact ordering to 3TK-53.

The current text mixes the two levels.

---

# 21. The statement "close establishes the first" needs one qualification

Section 1 says:

> `close` establishes the first.

The first state is:

```text
closed | no new call may enter
```

But `release` can also establish closed.

Section 6 correctly says:

> release transition to closed if necessary

So the stronger invariant is:

```text
_close establishes CLOSED.
```

and:

```text
close and release both invoke _close.
```

### Advice

Use `_close` as the state-transition authority throughout.

Then:

```text
close
    invokes _close
    returns

release
    invokes _close
    waits for quiet
    destroys
```

This is cleaner.

---

# 22. "Close / release" in the state diagram is misleading

Section 2 shows:

```text
OPEN
  │ close / release
  ▼
CLOSED
```

That is acceptable visually, but release does not merely transition to CLOSED.

Its full operation is:

```text
OPEN
  -> CLOSED
  -> QUIET
  -> FREED
```

### Advice

Use two paths:

```text
OPEN --close--> CLOSED

OPEN --release--> CLOSED --> QUIET --> FREED
```

and also:

```text
CLOSED --release--> QUIET --> FREED
```

That better expresses the API semantics.

---

# 23. "Release stops being a call that cannot block" is good, but the contract should say why

Section 16 correctly identifies the cost.

However, it should connect the blocking directly to the invariant:

```text
release blocks because it must not free while _active != 0
```

This is better than making "release can block" sound like an incidental API property.

### Advice

State:

> `release` may block because quiescence is part of the destruction precondition.

This makes the design easier to explain.

---

# 24. Section 17 contains a subtle wording problem about P6

It says:

> after 3TK-54 there is a moment when no further `on_close` can arrive —
> release has waited, `_active` is zero, and the pool is quiet.

That is correct **only while the pool cannot subsequently accept a new operation**.

Because the document's Race B explicitly says stale callers can still exist, this should not be interpreted as:

```text
no future call can ever attempt to use this pointer
```

It means:

```text
all operations that successfully entered the pool before release's closure
have finished.
```

### Advice

Use exactly that wording.

---

# 25. The negative tests have a naming problem

The document calls them:

> negatives this fix owes

but two of them are deliberately no longer negative:

```text
release_open_mailbox.c3
release_open_pool.c3
```

and section 18 itself says:

> inverts

That is conceptually awkward.

### Advice

Call the group:

```text
Lifetime regression programs
```

or:

```text
Lifetime negative/regression programs
```

Then classify each test:

```text
old-invalid -> new-valid
race regression
sanitizer regression
```

This makes the transition much clearer.

---

# 26. `release_vs_close` tests need an explicit expected winner

The document says:

> exactly one destruction

Good.

But there are two legitimate orderings:

```text
close wins:
    close -> closed
    release -> waits -> free
```

or:

```text
release wins:
    release -> closed -> waits
    close -> observes closed -> returns
    release -> free
```

The test should not assume one ordering.

### Advice

Specify the invariant:

```text
Either close or release may publish CLOSED first.
Exactly one call performs destruction.
The other operation returns safely.
```

This is a much better test oracle.

---

# 27. The document repeats the same conclusion too many times

The central rule appears in:

* section 2;
* section 4;
* section 5;
* section 6;
* section 9;
* section 11;
* section 13;
* section 14;
* section 16;
* section 17;
* section 20;
* the feasibility section.

Some repetition is justified in a design document, but this version is starting to become argumentative rather than normative.

### Advice

Make a strict hierarchy:

```text
Section 2
    normative lifetime invariant

Section 3
    definition of active

Section 4
    operation-entry/exit protocol

Section 5
    release protocol

Later sections
    Mailbox/Pool application of the protocol
```

Then remove repeated claims that simply restate the invariant.

This would make the document considerably shorter without losing information.

---

# 28. The document mixes specification, review history, and implementation plan

There are three different kinds of text:

### Specification

```text
free only when _closed && _active == 0
release waits for quiescence
release vs release unsupported
```

### Review history

```text
The review's §...
-001 said...
The reviewer recommends...
```

### Implementation planning

```text
3TK-53 does...
3TK-54 does...
test/... will...
```

All three are useful, but they are mixed throughout the same sections.

### Advice

For the final version, separate them:

```text
1. Contract
2. Mechanism
3. Mailbox
4. Pool
5. Concurrency boundaries
6. Tests
7. Open decisions
8. Review history
```

The review history can remain at the end.

This will make the document much easier to use during implementation.

---

# 29. "All twenty points are absorbed" is difficult to verify

The introduction says:

> All twenty of its points are absorbed here

but the change table does not provide a 1-to-20 mapping.

For future maintenance, this is fragile.

### Advice

If the review really has 20 numbered findings, add a compact mapping:

```text
review §1 -> §2
review §2 -> §12
...
review §20 -> §6
```

Otherwise change the claim to:

> The review findings are incorporated into the sections listed in
> "What changed from -001".

That is easier to maintain.

---

# 30. The "three of five are done" statement is questionable

At the end:

> Three of those five are done in this version — `_active` is defined in
> sections 3 and 4, the serialization distinction is drawn in section 11,
> and the destruction ordering is scoped and handed to 3TK-53 in section 8.

The first two are genuinely resolved at the **document level**.

The third is not "done" in the same sense.

Section 8 explicitly says:

> the exact order is whatever C3's Mutex and ConditionVariable require

and:

> 3TK-53 establishes it

Therefore destruction ordering is **identified/scoped**, not established.

### Advice

Change:

```text
Three of those five are done
```

to:

```text
Two are settled by this document.
One is narrowed to a concrete implementation check in 3TK-53.
Two remain owner decisions.
```

That accurately reflects the document.

---

# 31. Recommended decision state

The document currently has seven questions.

After review, they should be classified as:

| Question | Current state                                                        | Advice                                                     |
| -------- | -------------------------------------------------------------------- | ---------------------------------------------------------- |
| Q-A      | technically open, but document mostly assumes Variant 1              | **Make explicit implementation assumption**                |
| Q-B      | genuine API decision                                                 | **Owner decision required**                                |
| Q-C      | genuine API decision                                                 | **Owner decision required**                                |
| Q-D      | genuine shared-spec decision, but implementation already assumes yes | **Separate semantic assumption from conformance decision** |
| Q-E      | tracking                                                             | keep                                                       |
| Q-F      | tracking                                                             | keep                                                       |
| Q-G      | tracking                                                             | keep                                                       |

The actual implementation blockers are therefore primarily:

```text
Q-A
Q-B
Q-C
Q-D
```

not just Q-A and Q-B.

Q-C determines the Pool public release signature, and Q-D determines whether the
lifetime rule is a 3tk rule or a shared Matryoshka rule.

---

# 32. Recommended core specification

The document would be much stronger if the following became the central
normative contract.

```text
## Lifetime contract

A Mailbox or Pool has four lifetime states:

    OPEN
    CLOSED
    QUIET
    FREED

`_close()` performs the transition to CLOSED.

An operation is active while it may still access the tool's memory.

An operation accepted after the closed check increments `_active` before it
can execute outside the entry mutex.

An active operation decrements `_active` only after its final access to the
tool is complete.

`release`:

    1. acquires the mutex;
    2. invokes `_close()`;
    3. waits until `_active == 0`;
    4. destroys the tool;
    5. frees its memory.

`close`:

    1. acquires the mutex;
    2. invokes `_close()`;
    3. returns.

`release` may race `close` and any already-entered operation.

`release` may not race another `release`.

The lifetime mechanism does not protect a stale pointer whose operation has
not yet entered the tool's entry protocol.
```

Then the Mailbox and Pool sections only need to explain their differences.

---

# 33. Recommended answer to the review

The reviewer's central architectural recommendation is sound:

```text
_active != hook serialization
```

and, assuming the existing Part 12 behavior is intentional, **no hook
serialization is the cleaner design**.

The important reason is not merely performance.

It preserves the existing semantic distinction:

```text
Pool lifetime
    when may memory be destroyed?

Hook execution
    which application callbacks may execute concurrently?
```

Changing `_active` into a serializer would make the lifetime mechanism answer an
application-execution question that it does not need to answer.

So the preferred architecture is:

```text
             CLOSED
                |
       no new successful entry
                |
       existing active calls
          may continue
                |
          _active == 0
                |
             QUIET
                |
              free
```

with hooks remaining independently concurrent.

**But this should be recorded as an owner decision before 3TK-53/54, not left
implicitly decided by later sections.**

---

# 34. Final recommendation

I would **not start 3TK-53/54 from this document exactly as written**.

I would make one short revision first.

### Must fix before implementation

1. Make Q-A's implementation assumption explicit.
2. Separate the Q-D semantic assumption from the conformance decision.
3. Define "enter" precisely.
4. Change "every operation raises `_active`" to "every accepted operation".
5. Clarify `_close(out)` versus public `release(...)`.
6. Correct the feasibility-probe claim about what it actually proves.
7. State the application-level deadlock consequence of waiting for hooks.
8. Clarify that `release` has a unique destruction owner.
9. Mark the `defer` example as conditional on Q-B.
10. Change "three of five are done" to reflect that destruction ordering is
    still an implementation check.

### Strongly recommended

11. Move Race B next to the lifetime invariant.
12. Make the `close`/`release` state diagram show their different paths.
13. Explicitly state that `_active` survives the mutex-unlocked hook window.
14. Make the `release_vs_close` tests accept either operation winning the race.
15. Rename the "negatives" section to distinguish old-invalid/new-valid tests.
16. Reduce repeated review-history commentary in the normative sections.

---

# Bottom line

The **core lifetime design is now coherent**:

```text
             close
               |
OPEN ----------+
               v
             CLOSED
               |
        active operations
          finish
               |
          _active == 0
               |
             QUIET
               |
            release
               |
             FREED
```

The major remaining problem is **not the `_active` mechanism**.

It is that the document simultaneously tries to be:

```text
a decision record
+ a specification
+ a review response
+ an implementation plan
```

and therefore leaves some decisions formally open while already writing the
rest of the document as though they were decided.

The cleanest next step is a small **`-003` decision/cleanup revision**, not an
implementation revision: resolve Q-A/Q-B/Q-C/Q-D, normalize the lifetime
terminology, and then let 3TK-53/54 implement the resulting contract.
