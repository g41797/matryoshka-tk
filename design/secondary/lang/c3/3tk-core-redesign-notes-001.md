# 3tk core redesign notes (001)

Stage 3TK-11 of [3tk-staging-plan-006.md](3tk-staging-plan-006.md).

What writing the redesign taught, beyond
[3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md), which
is this stage's specification. Every decision here was ruled before the stage
started: R1 to R15, and the owner's five directions of 2026-08-23.

Nothing in this document reopens a ruling. Where the code disagreed with the
proposal it is marked **CORRECTION** and the proposal is the one that was
wrong, in a detail rather than in a decision.

## The result

**All four builds green. 59 checks, 0 failures. Both sanitizers clean.**

```
== c3c 0.8.3, git 1d155ee, linux-x64 ==

  safe -O0 (--safe=yes -O0)    85 tests, 7 negatives, 2 tier 1, 3 refusals
  safe -O3 (--safe=yes -O3)    85 tests, 7 negatives, 2 tier 1, 3 refusals
  fast -O0 (--safe=no  -O0)    85 tests, 7 negatives, 2 tier 1, 3 refusals
  fast -O3 (--safe=no  -O3)    85 tests, 7 negatives, 2 tier 1, 3 refusals

== Part 17.2: the layering ==   3 checks

passed 59, failed 0
all four builds green
```

```
  thread  safe -O0 — clean (85 tests run)
  thread  fast -O3 — clean (85 tests run)
  address safe -O0 — clean (85 tests run)

passed 3, failed 0
sanitizers clean
```

**77 tests before the stage, 85 now.** The check count is unchanged at 59: the
redesign renamed one negative and rewrote another, and added none.

Reproduce with `3tk/run-builds.sh` and `3tk/run-sanitizers.sh`.

## What moved

| Before | After |
|---|---|
| `src/any.c3`, 207 lines | `src/inner.c3`, 276 |
| `src/list.c3`, 339 lines | `src/queue.c3` 213 + `src/stack.c3` 129 |
| `src/mailbox.c3`, 395 | 416 |
| `src/pool.c3`, 502 | 520 |
| `src/mtk.c3`, 40 | 51 |
| `src/helper.c3` 127, `src/owned.c3` 85 | 126, 85 |
| `test/t_list.c3`, 15 tests | `test/t_queue.c3` 15 + `test/t_stack.c3` 7 |
| `negative/insert_twice_same_list.c3` | `negative/insert_twice_same_queue.c3` |

**The line counts are not the measurement, and §10.1 of the proposal predicted
the wrong number by using them.** It said 339 lines would become "perhaps 170
across two files"; they became 342. The prediction was right about the code and
wrong about the file: `queue.c3` and `stack.c3` hold **104 lines of code**
between them, and the rest is doc comment,
because the self-link needs its invariant stated in four places and the stack
needs the owner's defect-surfacing argument carried where a later reader will
meet it. A container this small is nearly all contract.

## The four things the stage had to get right

### 1. The self-link, in four places and not three

R6b, §3.2. The proposal counted "about four sites" that touch `next` — `pop`,
`push`, `append_queue`, `iter`. That count was for the queue. With the stack
there are **six**: `InnerQueue.push_back`, `InnerQueue.pop_front`,
`InnerQueue.append_queue`, `InnerQueueIterator.next`, `InnerStack.push`,
`InnerStack.pop`. All six are three lines or fewer, so the objection 001 raised
against mechanism B — that a terminator spreads meaning across eleven sites —
stays answered.

Two of the six are worth naming, because a translation of the old code gets
both wrong:

- **`pop_front` recognises the sole item by `head == tail`, not by a null
  `next`.** With the self-link there is no null `next` anywhere on a chain, so
  the old `if (h.next)` test would have read the item's self-pointer as a real
  successor and left `head` pointing at a removed item.
- **`InnerQueueIterator.next` ends at `n.next == n`.** A walker written for a
  null-terminated chain does not terminate here — it yields the last item
  for ever. `t_queue.c3` bounds every walk it runs with a count assertion for
  exactly this reason: a hang is a worse test failure than a wrong answer,
  because it reports nothing.

`append_queue` needed no repair at the join, as §3.2 said: `other.tail` is
already self-linked and stays the new tail.

### 2. Invariant 5, in the mailbox with two queues

§4.4 called the leaver's signal *the easiest thing in this redesign to
half-fix*, and it was right to. `receive`'s timeout path used to read
`if (!self._queue.is_empty()) self._cv.signal();`, and the mechanical rewrite
of that line is `_regular` — which would leave a queued out-of-band item with
nobody woken.

It is written as `Mailbox.has_queued()`, a named private predicate over both
queues, rather than as `!self._oob.is_empty() || !self._regular.is_empty()`
inline. Naming it is the guard: the next reader who adds a third queue has one
place to change, and a reviewer can see the invariant rather than reconstruct
it from a boolean.

**No test catches this one.** A missed signal is a timing defect and the suite
does not provoke it. That is a real gap and it is stated rather than papered
over: what protects invariant 5 here is the name and the comment, not a check.

### 3. `Pool.close`, and the property the loop has that a splice lacks

R12. Every bucket empties into one `InnerQueue`, `pop` then `push_back`, O(n)
once on a pool going down.

The reason this is not a regret: every item passes through `pop`, which repairs
its link, and `push_back`, which sets it again for the new chain. A splice would
have had to walk the stack anyway to repair each item's `next` — the stack's
bottom is self-linked and would have become an interior node of the queue — so
the O(1) splice was never available in the first place, and not merely
unavailable for want of a `tail`.

### 4. `put_all`, and what a caller writes instead

R15. The call is deleted, and `push_front` and `push_front_slot` went with it —
so `InnerQueue` has **no front insert at all**, which is what makes it minimal.

The tests did not simply lose two cases. `test/t_pool.c3` grew `put_batch`, a
seven-line function that is the loop `Pool.put`'s doc comment now recommends,
and the two `put_all` tests became tests of **that loop**. That is deliberate,
and it is a small departure from §10.2, which expected both to be deleted:

> **CORRECTION, and the stage's own judgment.** §10.2 said two `put_all` tests
> are deleted and three others become explicit loops. Three became loops as
> predicted. The other two were **converted rather than deleted**, because §6
> named the counter itself — *the caller now writes the loop, with a chance of
> getting the refusal case wrong and losing items quietly* — and deleting the
> only tests of the refusal path is the wrong answer to a risk the proposal
> raised in writing. The behaviour under test is the same; the code under test
> moved from the port to the caller, so the test moved with it.

One clause is deliberately not reproduced and it is called out in the test's own
comment: **Part 11.8's restored-order guarantee is gone**, because the refused
item goes back at the *back* of the caller's queue. There is no front insert to
put it anywhere else, and no caller was ever entitled to the order — the
specification's own warning said the restored order might differ.

## Part 18, re-walked

Verification item 3. Thirty-four rows before, thirty-four after: one retired,
one added, one strengthened, one kept against an expectation that it would go.

| # | Part | What the redesign did |
|---|---|---|
| 13 | 8.1 | **Strengthened.** Heterogeneous, O(1), allocation-free — and O(1) now in *checking* builds too, because the O(n) insert walk is deleted. `t_queue.c3` and `t_stack.c3` both hold a three-type test |
| 14 | 8.3 | Unchanged. Both containers speak in `Handle` and `Slot*` |
| 15 | 8.5 | Unchanged in force, and it now applies to two layers rather than one. Both carry the same guard |
| 16 | 8.7 | **RETIRED.** *The link test is not a membership test* — with the self-link it is exactly that, for every path through the public surface |
| — | 8.7 | **NEW, in 16's place:** *An item on a chain has a non-null `next`; the last item of a chain points at itself. An item on no chain has `next == null`.* Stated in `inner.c3`, maintained at six sites, read by `is_linked`, and asserted directly by `the_last_item_points_at_itself` and `the_bottom_item_points_at_itself` |
| 17 | 8.8 | Unchanged. `reset` clears one field instead of two |
| 20 | 9.6 | **Better guarded.** *An item is in exactly one place* now has an exact runtime guard at every insert, in every checking build, where before it had a partial one plus an O(n) walk |
| 22 | 11.3 | **Kept — R9**, against plan 006's expectation that two queues would delete it. The anchor was the mechanism; the ordering is a promise to callers and it stands. `t_mailbox.c3`'s three order assertions pass untouched |
| 34 | 11.6, 11.8 | Unchanged, and `a_closed_pool_is_empty` still proves it through the rewritten `close` |

**Rows 1 to 12, 18, 19, 21, 23 to 33 are untouched.** No fault was added or
removed; D6's tiers, D7's wait loop, D3's allocators and section 6's seven
implementation invariants are as 3TK-8 and 3TK-9 left them.

**Section 6.2 — creation is a transaction — was the one a rewrite could have
lost quietly, and it did not.** `Mailbox.create` and `Pool.create` keep every
`defer catch` unchanged; the redesign touched their field lists and nothing
else. `t_alloc.c3`'s four tests still walk the failure ladder.

## What the code taught that the proposal did not know

### The stack has five operations, not six

**CORRECTION.** §5.1 says *seven operations on the queue, six on the stack*.
The queue has seven — `push_back`, `push_back_slot`, `pop_front`, `is_empty`,
`len`, `iter`, `append_queue`. The stack has **five**: `push`, `push_slot`,
`pop`, `is_empty`, `len`. The table immediately above that sentence lists
exactly those five, so the count is an arithmetic slip in the ruled document
rather than a decision that was not carried out. Twelve operations replace Part
8.2's sixteen, and eleven of the sixteen leave the port rather than nine.

### The tier 2 check does not reach a fast build, and §10.3 says it does

**CORRECTION.** §10.3 says `insert_twice_same_queue` "now aborts in a **fast**
build too, because the check is tier 2". It does not. Tier 2 is `@check`, which
under `--safe=no` expands to nothing at all — that is the whole of D6 and the
whole point of 3TK-4's Q11 finding. The negative stays in `RUNTIME_NEGATIVES`
and behaves as every other one does: aborts where the checks are live, runs to
the end where they are not.

What R6b actually bought for that case is different and still worth having: the
check moved from **tier 3 to tier 2**, so an ordinary safe build catches an item
alone on its own container at O(1) instead of paying an O(n) walk per insert to
do it. The abort was always there in checking builds. What is gone is its price.

### The layering check had to be rewritten, not renamed

`run-builds.sh` guarded Part 17.2 by grepping `mailbox.c3` and `pool.c3` for
`unlink_no_repair|@guard_insert` — a container reaching around the container
surface. `unlink_no_repair` no longer exists: with no `remove` and no
`pop_back` there is no unrepaired removal to reach for, and the name went with
them.

Grepping for a symbol that cannot appear is a check that passes forever having
proved nothing — the exact failure mode `run-builds.sh` already records for
`release_open_pool`. It now greps for `@guard_insert` and for any assignment to
a `.next` field, which is what a container maintaining chains by hand would
have to write.

### The inner is 16 bytes, and two tests said 24

`t_identity.c3` and `t_owned.c3` both assert the inner's size against
`2 * uptr::size + typeid::size`. Both now read `uptr::size + typeid::size`, and
both were *supposed* to fail — they are the tests that exist so a field cannot
be added to the inner without someone deciding to. They did their job on the
first run of the stage.

### Renaming is not the work, and the compiler proved it

The mechanical half — `AnyNode` → `Inner`, `AnyHandle` → `Handle`, `to_any` →
`to_inner`, `node_offset` → `inner_offset` — was a single pass over `src/`,
`test/` and `negative/`, and C3 caught every survivor at compile time because
none of these names is a string. One accident is worth recording as a warning
for the next port: a blind rename of `Any` inside identifiers turned
`remove_from_anywhere` into `remove_from_innerwhere` in a test that was about to
be deleted anyway. **Rename on word boundaries, and read the diff.**

The real work was five files' worth of doc comments, because every one of them
argued for a shape that no longer exists.

## The open question this stage did not answer

[3tk-who-supports-slot.md](3tk-who-supports-slot.md) — from the owner, not
produced by any stage — argues that **the collection should not support the
Slot idiom at all**: that `push_back_slot` and `push_slot` belong on `Mailbox`
and `Pool`, and the queue and the stack should speak only in `Handle`.

It sat at `3tk/src/` while this stage ran; **the owner moved it up to the
folder root afterwards**, which answers half of what is written below — a
reader no longer finds it among the code and mistakes it for current design.
The question it asks is still open.

**3TK-10 did not rule on it and this stage did not act on it.** §5.1 keeps both
Slot inserts and R13 says nothing against them, so the code has them. It uses
names the redesign refused — `InnerList`, `push_front` — so it reads as older
than it is. It is a question for the owner, and it is small: two methods and
their two tests.

## What is next, and what this stage did not touch

- **`../common/` is untouched.** R14 rules that the specification moves to 003
  and nine Parts change; plan 006 says explicitly that cutting 003 is not this
  stage's work. **The port is now ahead of the specification it is written
  from**, and that is the one thing about the current state a cold session must
  know.
- **`3tk-porting-proposal-004.md` is not edited.** §10.4: it is the design of
  record for what was built, and proposal 002 is the record for what replaced
  it. Whether a proposal 005 folds them together is the owner's call. D1 to D16
  survive; only D14's anchor clause and D12's accepted blind spot were
  overtaken, both by rulings written down in 002.
- The finished stage outputs — the toolkit, container and sanitizer notes — are
  not rewritten. They record what was true when they ran.
