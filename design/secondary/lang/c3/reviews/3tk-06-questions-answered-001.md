# 3tk — the five questions, answered

**INTR 2, 2026-08-26.** INTR 1 ended with five questions and, for each one,
named the check that answers it. This file runs those five checks and reports
what each one says. It changes no code and no contract: where a question turns
out to be a ruling rather than a reading, it says so and leaves the ruling to
the owner.

**Read this file and [3tk-05-review-analysis-001.md](3tk-05-review-analysis-001.md)
to start the next stage.** Nothing else is needed. Every quotation below was
printed from the live file, and `./3tk/run-builds.sh` was run for this report:
**four builds green, 63 checks, 0 failures.** No byte of `3tk/src`, `test/` or
`negative/` was touched.

## The five answers, in one table

| # | Question | Answered by the source? | Answer |
|---|---|---|---|
| **Q1** | `Pool.put`: does the contract move, or the code? | **Yes** | The **wording** is the defect. The code is ruled and coherent |
| **Q2** | Is `UNKNOWN_IDENTITY` a fault or a defect? | **Yes** | Both, deliberately. Design, not accident |
| **Q3** | The empty-Slot no-op: defect, or answer? | **Yes** | The same rule as the negatives, not an exception |
| **Q4** | Should P5's checks survive a fast build? | **Yes, against promotion** | Tier 2 is what the specification allows. Tier 1 is closed |
| **Q5** | What does `release` owe against a call in flight? | **Yes** | The promise was never made. It is a caller precondition, and it is undocumented |

Four of the five are readings and are now closed. **Q5 leaves one thing for the
owner**, and it is a sentence, not a design.

## Q1 — the wording is the defect

*The check INTR 1 named:* `pool.c3:376-441` against the `P1` and `V11` entries
in `ref/3tk-decisions-002.md`, and against the four outcomes `on_put` is given
at `pool.c3:72-75`.

**The four outcomes were written knowing the Slot is already taken.** The hook
is handed `mine`, not the caller's Slot, and `pool.c3:70` states its precondition
outright — `@param slot : "full on entry"`. The four it may choose from are
*freed with nothing kept*, *kept as it is*, *kept after a reset*, and *freed with
a different item put back*. **None of them is give it back.** The specification
says the same at Part 12.2: *Four outcomes, none mandated* — and refusal is not
among them there either. A hook that empties `mine` has not refused the item; it
has freed it, which is outcome one.

**The closed-window disposal is already ruled.** `ref/3tk-decisions-002.md`
carries it at `pool.c3:397`, dated:

> **One rule for that window, and it is the pool's own: what the pool holds when
> it discovers it is closed goes to `on_close`.** Invariant 34 holds — nothing
> lands in a bucket after the flag is set. `Part 11.8` holds — nothing comes back
> to the caller. `P1`, `V11`.

and it records why the alternative was rejected:

> **The alternative, restoring the caller's Slot, cannot carry `extra`**, whose
> items the caller never had.

Specification invariant 35 says it as the port's law: *After a hook returns, the
pool re-reads the closed flag; what a closed pool's put is holding goes to the
close hook.*

**So the fork is not open.** Taking the item before the answer is known is the
ruled design, ruled 2026-08-24, and both of the sentences review 4 §7.2 weighed
against each other have already been decided in the code's favour. What survives
is exactly what INTR 1 suspected: **the contract sentence at `pool.c3:381`
covers a case it does not have.**

> Cleared: the pool took it.
> Unchanged: it was refused, and you still have the item.

*Unchanged* is reachable, and on four paths — an empty Slot at `:393`, the fast
closed read at `:395`, the closed flag under the mutex at `:399`, an unknown
identity at `:404`. Every one of them is **before the hook**. The sentence reads
as though refusal is a live outcome of the give-back, and refusal is something
only the pool does, and only before it has asked anyone. This is a wording
defect and it is the only defect Q1 has.

Two smaller points fall out of the same reading, and both are wording:

- `pool.c3:384` — *A close that arrives while `on_put` runs is handled. The item
  goes to `on_close`, and your Slot stays cleared* — is correct and is the
  clearest sentence in the block. It also silently contradicts the *unchanged*
  sentence two lines above, which is what made the block look self-inconsistent
  to two reviewers.
- `Part 9.4` — *Cleared means it was taken. Unchanged means it was not* — is the
  general law and is untouched. The port keeps it. Only `Pool.put`'s gloss on it
  overreaches.

**Q1 does not block P5, P6 or Q5.** INTR 1 ranked it first on the theory that it
might move code; it does not.

## Q2 — the split is the design

*The check INTR 1 named:* `negative/pool_unknown_identity.c3`.

**The negative was written to assert the split, and it says so.** Its own header:

> This is the A3 negative, and it is the test that fails if the A3 fix is taken
> out. It carries both halves of D6 tier 2 and a Part 19.3 assertion on top:
>
> Safe build: `bucket_for` returns null, the `@check` in `Pool.get` fires and
> the program aborts.
>
> Fast build: the check is gone, and what escapes must be `UNKNOWN_IDENTITY`.

That is not a test written around an accident. The fast half carries four
`always_assert`s of its own — the three get modes and `get_wait` — and each one
names the specification clause it defends. `Part 19.3` MUST says *not-available*
comes only from the available-only mode, so a fast build needs **some** fault to
escape, and `NOT_AVAILABLE` was the one that used to escape and broke the
specification doing it. `UNKNOWN_IDENTITY` exists to be the fault that a fast
build can honestly return for a defect a checking build aborts on.

`mtk.c3:47` already discloses it — *`UNKNOWN_IDENTITY` is the one that is also a
defect* — and `mtk.c3:48` bounds it to the two gets.

**Answer: keep both halves.** Review 4 §2.2's *one or the other* would break
either `Part 19.3` (by returning `NOT_AVAILABLE` again) or `D6` (by aborting in a
fast build, which only `Part 11.12` may do — see Q4). **No defect. No open item.**

One optional clarity note, and it is wording only: `mtk.c3:47` says the fault is
also a defect but not that **which of the two you get depends on the build**. The
negative knows this; the header does not say it.

## Q3 — the same rule, and the proof is a null pointer

*The check INTR 1 named:* `negative/create_into_full_slot.c3` and
`negative/overwrite_slot.c3`.

Those two negatives state what a fast build does with a Slot misuse, and both
say the same thing: **it proceeds into a defined wrong outcome.** `overwrite_slot`
— *the second fill wins, silently. Exits 0.* `create_into_full_slot` — *the
created item replaces the one in the Slot. Exits 0, having leaked — which is what
a compiled-out contract costs, and why the check exists.* A leak and an overwrite.
Neither is undefined behaviour.

**The two lines in question are what keeps the third case in that same category.**
Take `queue.c3:127-129` with the check compiled out:

```c3
self.push_back(s.take());        // s.take() is null
```

`InnerQueue.push_back` at `queue.c3:109` reaches `h.repoint_to(h)` on its second
line, and `h` is a null `Inner*`. That is a null dereference — undefined
behaviour, not a leak — and it happens under `--safe=no -O3`, where it is not a
trap but an assumption the optimiser is entitled to build on. `mailbox.c3:174` is
the same: `enqueue(null, oob)` reaches the same `push_back`.

`ref/3tk-decisions-002.md` names this exact technique under **Checking**, and it
is `D6`'s third clause:

> **A compiled-out check is paired with ordinary code where a hole would
> otherwise open.** `Part 8.9`. `../3tk/src/queue.c3:159`.

The cited site is `append_queue`'s self-move guard, which has the identical
shape: `@check` then `if (other == self) return;`. **These two lines are the same
construction as a decision the port already took, at a site the decisions file
already points to.**

**Answer: not a defect, and not an exception.** Reviews 3 §13, 4 §6.3 and §9 read
the `if` as papering over the `@check`. It is not; it is stopping a defect from
becoming undefined behaviour, which is exactly what the port does everywhere
else. `Part 9.2` rule 6 — *a release is a no-op on an empty Slot* — is a
different clause and covers `Pool.put:392`, which correctly carries no `@check`
at all. The two lines here belong to `Part 8.9`, not rule 6, and the markers on
them say so.

**One residue, and it is real but small.** `Mailbox.send` returns `void?`, so in
a fast build its quiet return is indistinguishable from a successful send. But
the caller cannot distinguish them by the Slot either — `Part 9.4` says cleared
means taken, and the Slot is empty in both cases, because the caller handed it in
empty. There is no reading of the Slot that recovers the truth. This is only
reachable after the caller has already violated the entry contract, and the
port's answer to that is the checking build. **Recorded, not raised.**

## Q4 — tier 2 is what the specification allows

*The check INTR 1 named:* `mtk.c3:41-51` and the `D6` entries in
`ref/3tk-decisions-002.md`.

**Tier 1 is not a category. It is a clause.** `D6` in the decisions file:

> **Three tiers, one port macro.** `D6`. Tier 2 is `mtk::@check`; tier 3 is
> `mtk::CHECKED`; **tier 1 is `always_assert` and has two sites**,
> `mailbox.c3:96` and `pool.c3:215`.

Both sites are release-of-an-open-object, and both cite `Part 11.12` MUST, which
closes the door in its own words:

> - Releasing an open mailbox is a defect. Releasing an open pool is a defect.
> - Both stop the program. In every build mode. Not an assert that compiles out.
> - **This is the one precondition the toolkit refuses to soften.**
> - Closedness is a precondition **here and nowhere else**.

**And the specification already classifies a hook's mistake, at the same tier as
everything else.** `Part 12.2`, on get: *Returning an item of a different
identity is a defect of the application.* A defect of the application — the same
words the port uses for a caller's defect, with no clause promoting it.

**Answer: `@check` at `pool.c3:318` and `pool.c3:453` is correct, and P5's
proposed promotion is refused by the specification.** Making either one tier 1
would add a third site to a list `Part 11.12` calls *the one*, and would be a
specification change, not a code fix. Review 4 §8's second checking mechanism is
the larger version of the same and falls with it.

**This does not dismiss what P5 observed; it relocates it.** Two things remain
true after the ruling and neither needs a new tier:

- **`pool.c3:318`** — a wrong identity from `on_get` in a fast build reaches the
  caller and every crossing downstream then answers correctly about the wrong
  type. Nothing recovers this, and nothing can: the port's guarantee is
  conditional on the hook, and `Part 12.2` puts the obligation on the
  application. What is missing is that `pool.c3:52-58`'s hook contract states the
  rule but not the **consequence of breaking it in a fast build**. A sentence.
- **`pool.c3:453`** — `if (!b) return;` drops the item with no trace. This is not
  a checking question at all. **It is P6**, one item instead of a queue, and it
  should be handled with P6 rather than separately.

**P5 is therefore closed as a checking question**, and its two halves move: `:318`
to documentation, `:453` to P6. INTR 1 ranked P5 High on the strength of the
promotion; **the promotion is refused, and P6 inherits the priority.**

## Q5 — the promise was never made

*The check INTR 1 named:* `Part 11.12` and `Part 13.1` of
`../../common/matryoshka-specification-004.md`, against
`negative/release_open_pool.c3` and `negative/release_open_mailbox.c3`.

**`Part 11.12` promises closed-before-released and nothing more.** Its five
clauses are quoted in Q4 above. Every one is about the closed **flag**: that
releasing an open object stops the program, that closedness is a precondition
here and nowhere else, that close is idempotent, and that the test-and-set is
inside the mutex *so a preempted closer cannot race a release*. **That last
clause protects the closer, not the releaser.** Nothing in the Part says a
release must wait for calls in flight, and nothing says an object is quiet when
its flag is set.

**`Part 13.1` is not about this at all.** Its four clauses are the allocator
rule — an object takes an allocator at creation, keeps it for life, releases
itself with the kept one, and no release call takes an allocator as a parameter.
INTR 1 named it as a place the promise might be, and it is not there.

**The two tier-1 negatives prove exactly the promise that was made.** Both abort
in all four build modes — confirmed live in this stage's run: *tier 1
release_open_mailbox aborts (as it must in every mode)*, *tier 1
release_open_pool aborts (as it must in every mode)*. They test the flag. There
is no test for calls still in flight because there is no clause for one.

**Answer: the port never claimed quiet-before-released. It is a caller
precondition, and it is written down nowhere.** Review 4 §7.4 could not tell
which side owed it; the specification says the caller, by omission.

**The one thing left for the owner, and it is the only open item in this file.**
The precondition is undocumented, and `Pool.put` is where it is easiest to
violate without knowing:

```
pool.c3:416:    self._mu.unlock();
pool.c3:417:    self._hooks.on_put(in_pool, &mine, &extra);
pool.c3:418:    self._mu.lock();
```

The window is opened by the port itself, under `Part 12.3` MUST — *no lock is
held across a call into application code* — and a concurrent close-and-release in
it makes `:418` lock a mutex in freed memory. A caller who reads `Part 11.12`,
closes, and then releases has satisfied every clause the toolkit states, and can
still land here.

Three ways to close it, and the choice is a ruling:

1. **Write the precondition down.** A sentence on `Pool.release` and
   `Mailbox.release`: a release requires that no other call is in flight, and
   closing does not make that true. Costs nothing, changes no code, and makes the
   existing contract honest. **This is the smallest thing that fixes what Q5
   found.**
2. **Enforce it.** An in-flight count, checked at release. Real cost on every
   call, and `Part 11.12` would have to grow a clause.
3. **Leave it.** Then `Part 11.12` continues to read as the whole of the release
   contract while it is not.

**INTR 2 does not choose.** Option 1 is the only one that does not touch the
specification, which is why it is first.

## What this changes in INTR 1's list

| # | INTR 1 said | After INTR 2 |
|---|---|---|
| **P5** | High, blocked on Q4 | **Closed as a checking question.** `:318` becomes a documentation item; `:453` merges into P6 |
| **P6** | High | **High, and now carries P5's `:453`** — it is the port's whole quiet-loss problem in one place |
| **P2** | High | Unchanged. Still first to fix, still before P1 |
| **P1** | Medium | Unchanged |
| **P7** | Medium | Unchanged |
| **P3** | Medium | Unchanged |
| **P4** | Low | Unchanged, and Q3 is **not** the same question — P4 is a branch that cannot be taken, Q3 is a branch that must be |

**Three new wording items**, all found by the questions rather than by the
reviews, and all small:

- **W1** — `pool.c3:381`, the *unchanged* sentence. Q1.
- **W2** — `pool.c3:52-58`, the get hook's identity rule states the obligation
  but not what a fast build does when it is broken. Q4.
- **W3** — the release precondition, on both release calls. Q5, and the owner's
  ruling gates it.

**Nothing here is blocked any more except W3.** P2, P1, P3, P4, P6 and P7 can be
fixed as they stand.

## What was measured for this report, live

- `./3tk/run-builds.sh` — **four builds green, 63 checks, 0 failures.**
- Every quotation printed from the live file: `3tk/src/pool.c3`,
  `3tk/src/mailbox.c3`, `3tk/src/queue.c3`, `3tk/src/inner.c3`, `3tk/src/mtk.c3`,
  `3tk/negative/pool_unknown_identity.c3`, `3tk/negative/overwrite_slot.c3`,
  `3tk/negative/create_into_full_slot.c3`, `ref/3tk-decisions-002.md`,
  `../../common/matryoshka-specification-004.md`.
- **No byte of `3tk/src`, `test/` or `negative/` was touched.**
