# 3tk — the four implementation reviews, analysed

**INTR 1, 2026-08-26.** An analysis of the four review files in this folder.
It says what is actually wrong with `3tk/src` and why each one bites. It does
not say how to fix anything.

**Read this file and nothing else to start the next stage.** Every claim below
was verified against `3tk/src` at the moment it was written, and every
`file:line` was printed from the live file. The four reviews do not need to be
reopened.

## What was read, and why it needed triage

| File | Covers | Sections |
|---|---|---|
| [3tk-01-inner-helper-review.md](3tk-01-inner-helper-review.md) | `inner.c3`, `helper.c3` | 12 |
| [3tk-02-mtk-managed-review.md](3tk-02-mtk-managed-review.md) | `mtk.c3`, `managed.c3` | 17 |
| [3tk-03-queue-mailbox-review.md](3tk-03-queue-mailbox-review.md) | `queue.c3`, `mailbox.c3` | 25 |
| [3tk-04-several-modules-review.md](3tk-04-several-modules-review.md) | all six, plus cross-file | ~30 |

4,350 lines. The reviewer was given the sources with comments and documents
excluded, and worked from the code alone.

**Two things make the four files unusable as they stand.**

**Most of their length is confirmation.** Whole sections say a thing is
correct — the queue representation, the receive loop, the rollback chain, the
generation counter. Useful as an independent second opinion, but it buries the
defects.

**The exclusion of comments cost the reviewer his headline finding.** In C3 a
`<* @require ... *>` block is a **compiled contract**, not documentation. The
review's single most emphasized *required* fix — that `must_from_handle`
performs no identity check — is a false alarm, and the check it asks for is
already there, on the line the reviewer was told to skip. That is refuted
below, with the live evidence.

**Seven real problems survived.** Six were the reviewer's; the seventh was
found while verifying his and is marked as such.

## The problem list

| # | Where | What |
|---|---|---|
| **P1** | `inner.c3:195` | `required_alloc_offset` silently takes the last of several `Allocator` fields |
| **P2** | `inner.c3:195`, `managed.c3:69` | `required_alloc_offset` is defined twice, and the copy in `managed.c3` is dead |
| **P3** | `mailbox.c3:276`, `:321` | `receive_all` and `close` state an empty-`out` precondition and enforce nothing |
| **P4** | `mailbox.c3:260`, `pool.c3:370` | A branch that can never be taken, in both waiting paths |
| **P5** | `pool.c3:318`, `:453` | The hook identity checks are `@check`, so they leave a fast build |
| **P6** | `pool.c3:429`, `:487` | What a close hook leaves behind is abandoned with no trace |
| **P7** | `mailbox.c3:252`, `pool.c3:363` | A fault outside the declared set escapes to the caller |

P1 to P6 are the reviewer's. **P7 is mine** — no review claimed it.

## `inner.c3` and `managed.c3`

### P1 — `required_alloc_offset` takes the last of several `Allocator` fields

`inner.c3:195` walks the outer's members and overwrites `$off` on every match:

```c3
macro usz required_alloc_offset($Type)
{
    var $off = -1;
    $foreach $m : $Type::members:
        $if $m.type == Allocator:
            $off = $m.offset;
        $endif
    $endforeach
    $assert $off >= 0 : "type " +++ $Type::name +++ " has no Allocator field; use mtk::helper instead of mtk::managed";
    return $off;
}
```

**Why it is a real problem.** Its sibling twenty-five lines above,
`inner_offset` at `inner.c3:170`, does the opposite: it counts, and it refuses
a type with two `Inner` fields with a message that names the type. Two
compile-time discovery macros in one file, both answering *where is the field*,
and only one of them has a rule. An outer carrying two allocators compiles, and
which one `mtk::managed` writes at creation and reads back at release is
decided by declaration order and stated nowhere. The failure is silent and it
is at the far end: `create` stores into the second field, `release` reads the
second field, and the two agree — so nothing breaks until an outer is written
whose two allocators are not interchangeable, at which point memory is returned
to the wrong one.

`negative/nocompile_managed_no_allocator.c3` covers the zero case. There is no
negative for the two case, because there is no rule for it to prove.

### P2 — `required_alloc_offset` is defined twice, and one copy is dead

The same macro body exists at `inner.c3:195` and again at `managed.c3:69`,
inside `module mtk::managed`. Both call sites reach for the first one:

```
managed.c3:35:    *(Allocator*)((char*)item + mtk::inner::required_alloc_offset($Type)) = a;
managed.c3:55:    Allocator a = *(Allocator*)((char*)item + mtk::inner::required_alloc_offset($Type));
```

Scanned live across `src`, `test` and `negative`: **no caller anywhere names
`mtk::managed::required_alloc_offset`, and no caller uses the unqualified
form.** The copy in `managed.c3` has no reader.

**Why it is a real problem.** It is not a compile error — review 2 §16 read it
as one, and it is not; both modules are in scope and the qualified name
resolves. The problem is what it does to the next person. `managed.c3` is where
someone looking for allocator discovery goes, because that is the only module
that uses it, and the definition sitting there is the one they will read and
the one they will edit. A rule added to it — P1's rule, for instance — changes
nothing at all, compiles clean, and passes every build, while the macro that
actually runs is untouched in another file. A dead duplicate of a live macro is
a trap set for whoever fixes P1.

## `mailbox.c3`

### P3 — `receive_all` and `close` do not enforce their `out` precondition

Both take a caller's queue and both state what it must be:

```
mailbox.c3:272:  @param out : "an empty queue; every queued item is moved onto it, in receive order"
mailbox.c3:318:  @param out : "an empty queue; the remainder is moved onto it, in receive order"
```

Neither checks it. Both go straight to `out.append_queue(&self._oob)` and
`out.append_queue(&self._regular)`, and `append_queue` at `queue.c3:170`
appends — it neither requires nor restores an empty destination.

**Why it is a real problem.** The port has one convention for an acquisition
and it is enforced everywhere else. `Mailbox.poll` at `:200`, `Mailbox.receive`
at `:229`, `Pool.get` at `:280`, `Pool.get_wait` at `:339` and
`managed::create` at `managed.c3:33` all open with the same line — *an
acquisition asserts the Slot is empty on entry* — and `Slot.fill` at
`inner.c3:153` refuses to overwrite a full Slot on its own account. Two
acquisitions in the port take a queue instead of a Slot, and those two check
nothing.

The consequence is not a crash, which is what makes it worth reporting: a
caller who reuses a queue gets a silently longer chain, with items the mailbox
never held at the front of it and no way afterwards to tell where the boundary
was. `close` is the sharper of the two, because the items it gives back are the
caller's to release and the queue is the only record of which ones they are.
A defect the port detects for a Slot goes undetected for a queue.

### P4 — a branch that can never be taken

`mailbox.c3:260`, in the timeout arm of `receive`:

```c3
h = self.dequeue();
if (h) { slot.fill(h); return; }
if (self._wake_gen != gen) return mtk::WOKEN~;

// [3tk: Part 2.6]
if (self.has_queued()) self._cv.signal();
return mtk::TIMEOUT~;
```

`pool.c3:370` is the same shape in `get_wait`:

```c3
h = b.free.pop();
if (h) { slot.fill(h); return; }
// [3tk: Part 2.6]
if (!b.free.is_empty()) self._cv.signal();
```

**Both conditions are provably false wherever they are evaluated, and the proof
is three lines.** `Mailbox.dequeue` at `:136` returns
`_oob.pop_front()` or else `_regular.pop_front()`; `pop_front` at
`queue.c3:141` returns null exactly when `head` is null, and `is_empty` at
`queue.c3:76` is `count == 0` — the two agree by construction, every push and
pop moving both together. So reaching line 260 means both queues are empty,
which is exactly what `has_queued` at `:143` tests. The mutex is held across
the whole arm, so nothing can arrive in between. The pool case is the same with
one stack instead of two queues: `InnerStack.pop` at `stack.c3:101` returns
null exactly when `top` is null, and `is_empty` at `stack.c3:68` is `count == 0`.

**Why it is a real problem.** Whatever the branch was meant to prevent, it does
not prevent it, and it reads as though it does. Both reviews flagged it, both
said they could not prove it either way, and both concluded it should be left
alone until someone checks — which is exactly the cost: a guard nobody can
account for is a guard nobody dares touch. It carries a marker, `Part 2.6`, so
a specification clause is resting on it.

Worth recording alongside the proof: the hand-off it appears to be reaching for
cannot be lost anyway. If an item were queued when this waiter re-took the
mutex, the `dequeue` two lines above would have returned it and the waiter would
have returned success rather than `TIMEOUT`. The wakeup a timed-out waiter might
have consumed is one it consumed by taking the item.

## `pool.c3`

### P5 — the hook identity checks leave a fast build

Two of them, both `mtk::@check`:

```
pool.c3:318:    mtk::@check(slot.peek().link.type == want, "the get hook returned an item of a different identity");
pool.c3:453:    mtk::@check(b != null, "the put hook returned an identity the pool was not created with");
```

`@check` at `mtk.c3:62` expands to nothing under `--safe=no`, by design.

**Why it is a real problem.** The rest of what `@check` guards in this port is
a precondition the caller owes — a Slot in the right state, a handle that is
not already on a chain, a set of identities with no duplicate. A caller who
obeys the contract never trips them, which is what makes them safe to remove
from a fast build.

These two are not that. They guard the correctness of what the port gives
**back**, and they guard it against the hook rather than against the caller. At
`:318` the pool has just been given an item by `on_get` and is about to fill
the caller's Slot with it; if the identity is wrong and the check is gone, the
caller receives a handle whose recorded type is not the type it asked for, and
every crossing downstream — `from_handle`, `is_mine`, `must_from_handle` —
then answers correctly about the wrong type. The type-identity guarantee is the
one thing the whole port exists to provide, and here it is defeated with no
abort, no fault, and no trace. At `:453` the same for storage: an item goes to
whichever bucket its own identity names, and if no bucket names it, `:454`
returns and the item is dropped on the floor.

The asymmetry is inside the file. `Mailbox.release` at `mailbox.c3:109` and
`Pool.release` at `pool.c3:233` use `always_assert`, not `@check`, precisely
because their violation cannot be allowed to continue in any build. Whether
these two belong in that category is a judgment, not a reading, and it is
**Q4** below.

### P6 — what a close hook leaves behind is abandoned

Two paths hand a local queue to `on_close` and let it go out of scope:

```
pool.c3:429:        if (!stragglers.is_empty()) self._hooks.on_close(&stragglers);
pool.c3:487:    self._hooks.on_close(&remaining);
```

`InnerQueue` at `queue.c3:34` is three plain fields, so the local simply
disappears. The interface says what the hook owes — *Process or free every item
in it*, `pool.c3:89` — and nothing observes whether it did.

**Why it is a real problem.** This is the port's last sight of those items.
`Pool.close` gives nothing back to the caller by design — *On close nothing
comes back to you. Everything goes to `on_close`*, `pool.c3:21` — so a hook
that returns early, or handles one identity and not another, or mishandles the
straggler call it is warned about at `pool.c3:92`, leaks every remaining item
with no diagnostic in any build. Every other way an item can go missing in this
port is guarded: a Slot that would be overwritten, an item inserted twice, a
queue moved onto itself. This one is not, and it is the path where the most
items are in flight at once.

## Found while verifying — no review claimed this

### P7 — a fault outside the declared set escapes

Two waiting paths, both the same:

```
mailbox.c3:252:            if (f != thread::WAIT_TIMEOUT) return f~;
pool.c3:363:            if (f != thread::WAIT_TIMEOUT) return f~;
```

`f` here is whatever `ConditionVariable.wait_until` returned. Anything that is
not `thread::WAIT_TIMEOUT` is passed straight out to the caller. But the two
signatures declare what they can return:

```
mailbox.c3:223:  @return? mtk::CLOSED, mtk::TIMEOUT, mtk::WOKEN
pool.c3:333:     @return? mtk::CLOSED, mtk::TIMEOUT, mtk::UNKNOWN_IDENTITY
```

**Why it is a real problem.** `mtk.c3:42` states the rule the whole port is
built on: *The faults are outcomes a correct program reaches*, and the seven of
them are declared in one `faultdef` at `mtk.c3:51` so a caller can switch on a
closed set. These two calls widen that set at run time with a fault from
`std::thread` that the caller has no reason to have heard of, that appears in
no signature, and that arrives through the two calls most likely to be wrapped
in a loop. A caller who handles all three declared outcomes and treats anything
else as impossible is correct according to the contract and wrong according to
the code.

It is worth noting what this is not. It is not a leak on any path that runs in
practice, so no test would have caught it, and the reviewer did not reach it
because he had the code but not the `@return?` lines that contradict it. It is
a contradiction between two parts of the same file.

## Questions — each names the check that settles it

**Q1 — `Pool.put`: does the contract move, or does the code?**

`pool.c3:380` promises the Slot is the answer: *Cleared: the pool took it.
Unchanged: it was refused, and you still have the item.* The code clears the
caller's Slot at `:411`, **before** the hook runs at `:417`, and never restores
it. So "unchanged" can only ever mean refused before the hook — an empty Slot
at `:393`, a closed pool at `:395` or `:399`, an unknown identity at `:404`. A
hook that decides it does not want the item cannot give it back; if it empties
`mine`, the item is simply gone from the port's ownership.

Review 4 §7.2 called this the file's most significant problem and then argued
itself round to *the code is coherent, change the words instead*. It is a
genuine fork and it is yours: either the sentence at `:381` is wrong about a
case it appears to cover, or the code is wrong to take the item before the
answer is known.

*The check that settles it:* read `pool.c3:376-441` against
`ref/3tk-decisions-002.md`'s entry for `P1` and `V11`, which are the markers on
`Pool.put` at `:389`, and against the four outcomes `on_put` is given at
`pool.c3:72-75`. If those four were written knowing the Slot is already taken,
the contract sentence is the defect. **INTR 1 could not settle this from the
source alone, because the source is self-consistent and only the wording
disagrees.**

**Q2 — is `UNKNOWN_IDENTITY` a fault or a defect?**

`pool.c3:289` and `:348` check the bucket with `@check` and then return the
fault anyway at `:290` and `:350`. So a checking build aborts and a fast build
returns a recoverable fault — one name, two categories. `mtk.c3:47` already
records the oddity: *`UNKNOWN_IDENTITY` is the one that is also a defect.*
Review 4 §2.2 asks for one or the other.

*The check that settles it:* `negative/pool_unknown_identity.c3` exists and
passes in all four builds — it aborts in the two safe builds and runs to the
end in the two fast ones. Read it and decide whether that split is the intended
design or an accident that was then given a test.

**Q3 — the empty-Slot no-op: defect, or answer?**

Two places take a Slot that must be full, assert it, and then handle the case
they just asserted away:

```
queue.c3:127:    mtk::@check(s.is_full(), "push_back_slot from an empty Slot");
queue.c3:128:    if (s.is_empty()) return;
mailbox.c3:173:    mtk::@check(slot.is_full(), "Mailbox.send from an empty Slot");
mailbox.c3:174:    if (slot.is_empty()) return;
```

A checking build aborts; a fast build returns quietly. `Mailbox.send` returns
`void?`, so its quiet return is indistinguishable from a successful send. Both
reviews flagged it (review 3 §13, review 4 §6.3, §9) and neither would rule.

*The check that settles it:* `negative/create_into_full_slot.c3` and
`negative/overwrite_slot.c3` are the port's statement of what a fast build does
with a Slot misuse. Read those two, then decide whether these two lines are the
same rule or an exception to it.

**Q4 — should P5's two checks survive a fast build?**

This is the ruling P5 waits on, and it is narrower than review 4 §8's proposal
for a second checking mechanism. The question is only whether an identity the
**hook** got wrong belongs in the same category as a precondition the
**caller** got wrong.

*The check that settles it:* the port already has both categories in use —
`always_assert` at `mailbox.c3:109` and `pool.c3:233`, `@check` everywhere
else. Read `mtk.c3:41-51` and the `D6` entries in `ref/3tk-decisions-002.md`
and say which category a hook's mistake is in.

**Q5 — what does `release` owe against a call still in flight?**

`Pool.put` releases the mutex at `:416`, runs the hook, and takes it again at
`:418`. If another thread closes and releases the pool in that window, `:418`
takes a mutex in freed memory. `Mailbox` has the same window nowhere, but
`Mailbox.release` at `:106` has the same general exposure. Review 4 §7.4 raised
it and could not tell whether the port owes an enforcement or the caller owes a
precondition.

*The check that settles it:* `negative/release_open_pool.c3` and
`negative/release_open_mailbox.c3` are tier-1 negatives — they abort in every
build mode, including `--safe=no -O3`. They prove *closed before released*. The
question is whether the port also claims *quiet before released*, which is a
different promise and has no test. Read `Part 11.12` and `Part 13.1` in the
specification and say whether that promise was ever made.

## Refuted, and the reason

**Refuted, with live evidence:**

- **`must_from_handle` performs no check** — review 1 §1 (its headline and its
  first *required* fix), review 2 §10, review 2 required-fix 3. **False.**
  `helper.c3:89` carries `@require is_mine(h, $Type) : "the handle is not of
  this type"`, which C3 compiles into the macro. `negative/wrong_type_must.c3`
  exists to prove it, and `./run-builds.sh` run live for this report reports
  *negative wrong_type_must aborts* in both `--safe=yes -O0` and
  `--safe=yes -O3`, and *runs to the end* in both fast builds — which is the
  documented behaviour, not a gap. The fix the reviews ask for is already in the
  file, on a line they were instructed not to read.
- **`Inner.as` is an unchecked duplicate** — review 1 §10. Same reason:
  `helper.c3:143` carries its own `@require`.
- **`mtk::inner::required_alloc_offset` is a wrong qualification and a concrete
  problem** — review 2 §16, its *most important newly found contradiction*.
  The name resolves and the port compiles in all four builds. The real defect
  in that neighbourhood is **P2**, which is not what the review described.
- **The `Slot` casts can be dropped** — review 1 §5 and its optional cleanup.
  `Slot` is a C3 `typedef` at `inner.c3:79`, a distinct type and not an alias;
  `Handle` at `:70` is the alias. The shorter forms would not compile.
- **`helper::init` may overwrite the whole outer, losing the allocator write** —
  review 4 §3.4. `helper.c3:46-50` writes `n.link` and nothing else.

**No defect claimed, and none found** — sections that examined the code and
concluded it was correct. Recorded so the next stage knows they were read and
need not be re-read: review 1 §§2, 3, 4, 6, 7, 9, 11, 12; review 2 §§1–9, 11,
12, 14, 15, 17; review 3 §§1–7, 10, 11, 12, 14, 15, 16, 18, 19, 20, 21, 22, 23,
24, 25; review 4 §§2.1, 3.1, 4.1, 5, 6.1, 6.4, 7.1, 7.3, 7.6, 7.8, 10.

Two of those deserve a line because they agree with a decision already taken
and might otherwise look like open items: **no fast closed check on a waiting
path** (review 3 §11, review 4 §6.4 and §7.8 — the reviewer calls the current
shape correct and asks that it not be changed), and **`Mailbox.create` needs no
condition-variable rollback** (review 4 §10 — nothing fallible follows it).

## Priority — mine, and a ranking rather than a ruling

| # | Priority | Why it sits there |
|---|---|---|
| **P5** | High | Defeats the type-identity guarantee itself, silently, in shipped builds. Blocked on **Q4** |
| **P2** | High | Cheap to fix and it disarms a trap; and P1's fix is wrong unless P2 goes first |
| **P6** | High | The largest quiet item loss in the port, on the path with the most items in flight |
| **P1** | Medium | Silent, but it needs an outer with two allocators before it bites |
| **P7** | Medium | A real contract breach on a common path, but only reachable through a stdlib failure |
| **P3** | Medium | No corruption; a defect the port detects for a Slot and misses for a queue |
| **P4** | Low | Costs nothing at run time. It is confusion, and a marker resting on nothing |

**P2 before P1** is the only ordering constraint among them: a rule added to
the copy in `managed.c3` has no effect at all.

**Q1 is the one to answer first**, because it is the only question whose answer
might change code rather than words, and because `Pool.put` is where P5, P6 and
Q5 all meet.

## What was measured for this report, live

- `./3tk/run-builds.sh` — **four builds green, 63 checks, 87 tests, 0 failures.**
- `./3tk/check-doc-loop.sh` — **0 differing blocks, 439 sentences, 438 found, 1
  missing**, and the ban scan 0 over all eight files and the reference. The
  baseline 3TK-49 left is unchanged, so no INTR stage has moved the tree.
- Every `file:line` in this report printed from the live file.
- **No byte of `3tk/src`, `test/` or `negative/` was touched.**
