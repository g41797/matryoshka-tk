# 3tk — quiet before released

**A deferred item, ruled 2026-08-27 and not yet scheduled.** It came out of
INTR 2's `Q5`. This file is the whole of it: what the hazard is, what the owner
ruled, how it should be built, what it costs, what it leaves for the shared
specification, and what a stage would have to do. **Read this file and nothing
else to run that stage.**

**Line numbers below were re-printed live on 2026-08-27**, after the `2DO`
comments went into the two files. Re-print before trusting them — every fix moves
them.

**Nothing here is urgent and nothing is blocked on it.** The port is green, no
test fails because of it, and no client code changes when it lands.

## The hazard

`Pool.release` and `Mailbox.release` require the object to be **closed** first,
and that is the port's hardest rule — `Part 11.12` MUST, tier 1, `always_assert`,
aborts in all four build modes, with a negative each.

**Closed is not quiet.** `Part 12.3` MUST forbids holding the mutex across a call
into application code, so `Pool.put` opens the mutex itself:

```
pool.c3:422:    self._mu.unlock();
pool.c3:423:    self._hooks.on_put(in_pool, &mine, &extra);
pool.c3:424:    self._mu.lock();
```

If another thread closes **and** releases inside that window, `:418` locks a mutex
in freed memory. `Mailbox` has no hook and so has no window of its own, but the
same general exposure: any call in flight when a release runs is touching freed
memory.

**A caller who reads `Part 11.12`, closes, and then releases has obeyed every
clause the toolkit states, and can still land here.** That is what makes it worth
fixing rather than tolerating.

## The ruling

**The owner ruled enforcement, 2026-08-27.** Not documentation of a caller
precondition — the port itself keeps the rule.

The reason given: **the client's code is not affected either way.** No signature
changes, no new parameter, no new call. A correct application sees no difference;
only an incorrect one does, and it currently sees undefined behaviour.

**A second ruling the same day: it does not run immediately.** The gap before it
runs may be long, because the examples and the pattern catalog do not exercise
edge cases, so nothing downstream is waiting on it.

## How it should be built

### A counter alone narrows the race. It does not close it.

The obvious shape — count calls in flight, abort at release if the count is not
zero — **has the hazard inside itself.** The counter lives in the object being
freed, and so does the mutex guarding the counter. `release` must read memory a
concurrent thread may already have freed, which is the same defect one level
down.

### Wait, do not abort.

`release` **blocks** until the count reaches zero:

- Every call raises the count on entry and lowers it on the way out, signalling
  when it reaches zero.
- `release` takes the mutex, waits on a condition variable until the count is
  zero, and only then tears down.
- The closed flag already stops **new** calls from starting, so the count is
  monotonically falling once `close` has run — the wait terminates.

**This changes what `release` is.** Today it is a call that cannot block. That is
the real cost of the ruling, and it is a design change rather than a check.

### Where the bump goes

**Almost every call already holds the mutex**, so the count is an ordinary field
under it — no atomics on the common path, and the cost is close to nothing.

**The one site that needs care is the hook window**, and it is the site the whole
item exists for: the count must be raised **before** the unlock at `pool.c3:422`
and lowered **after** the relock at `pool.c3:424`. A count raised inside the
window is a count that does not cover the window.

`Mailbox`'s waiting paths hold the mutex through `wait_until`, so they are covered
by the same field with no special handling.

## What it leaves for the shared specification

**`Part 11.12` lives in `../common/matryoshka-specification-004.md`, not in the
C3 folder.** Its entire content today is *closed before released*. Adding *quiet
before released* is a clause every port owes — ztk, otk and dtk included.

**So 3tk would be discovering the clause, not implementing one.** The finding
belongs in the C3 folder and the shared-specification change is a separate,
owner-level decision. **3tk must not grow a promise the other ports do not make
without that decision being taken first**, or the ports disagree about what a
release means.

Two sub-questions come with it, and both are the owner's:

- **Wait or abort?** Waiting is the one that is sound. Abort is cheaper and is what
  a defect normally gets in this port, but it cannot be implemented safely for the
  reason above.
- **Does `release` stop being a call that cannot block?** That is the clause's real
  content, and it is what the other ports would inherit.

## What a stage would have to do

1. Read this file. Nothing else is needed.
2. Rule the shared-specification question first, or run under an explicit
   assumption that says which way it was assumed.
3. Add the count to `Mailbox` and `Pool`, with the hook window handled explicitly.
4. Make `release` wait until the count is zero.
5. Write the negative — **and it does not have to be a flaky race.** An `on_put`
   hook that parks until the main thread has closed and released, then returns, is
   a deterministic trigger for exactly this window. Without the fix it is
   undefined behaviour; with it, `release` waits for the hook and the program
   finishes.
6. **The doc loop is owed**, because `3tk/src` changes. `ref/3tk-doc-loop-003.md`
   is the procedure and `check-doc-loop.sh` says whether it is still owed.
7. Add the decisions entries to `ref/3tk-decisions-002.md` — which becomes `-003`.

## The interim

Until the stage runs, the hazard is live and is named in no file a reader of the
port would reach. **The gap is expected to be long.**

`W3` in
[reviews/3tk-06-questions-answered-001.md](reviews/3tk-06-questions-answered-001.md)
is the one-sentence warning on both release calls. It is thrown away when
enforcement lands. **Whether it goes in now is the only part of this item that is
still open.**
