# The 3tk core redesign proposal (002)

Stage 3TK-10 of `3tk-staging-plan-006.md`, **as ruled by the owner on
2026-08-23**. Written against `../common/backup/matryoshka-specification-002.md`,
`3tk-porting-proposal-004.md`, and `3tk/src/` as it stands green.

It supersedes [3tk-core-redesign-proposal-001.md](backup/3tk-core-redesign-proposal-001.md),
which is in `backup/` and records what the stage proposed before the ruling.

**This document writes no C3.** The code is 3TK-11.

## Status

**Ruled. R1 to R15, all accepted or refused on the record, 2026-08-23.**

001 asked eleven questions; the owner answered them one at a time. Three answers
moved a decision, and each is marked **CHANGED IN 002** where it appears:

- **R6 was refused.** No membership field. The guard is the self-link. §3.
- **R11 now has its reason**, which 001 did not have and which is not
  performance. §1.3.
- **R4 is retired, because `put_all` is dropped.** §6, and it is a new decision,
  R15.

The owner's direction of 2026-08-23 — the five rulings — remains the input and
was never in question. This document works out what it costs.

## What the reading found

The two documents that argued for the direction,
[3tk-naming-001.md](backup/3tk-naming-001.md) and
[3tk-to-fifo-lifo-single-001.md](backup/3tk-to-fifo-lifo-single-001.md), were read
against the code rather than on trust, the way 3TK-8 read its review.

- **The required-operation audit passes.** Nothing in `3tk/src/` needs arbitrary
  removal, arbitrary insertion, backward traversal or `pop_back`. §1.1.
- **The out-of-band semantics are Meaning A** — absolute priority, first-in
  first-out within each class. `mailbox.c3:143-159`. Two queues reproduce it
  exactly, with no observable change anywhere. §1.2.
- **The pool is first-in first-out today, not last-in first-out.**
  `pool.c3:263`, `:337`, `:425`. Ruling 3 is a **behaviour change**, and the
  owner's reason for it is defect surfacing. §1.3.
- **Deleting `prev` costs the guard nothing.** The self-link makes the link test
  **exact**, closes the blind spot D12 accepted, and deletes the O(n) walk from
  every insert — at no per-item cost. §3.
- **Invariant 22 survives.** D14's anchor is deleted; the ordering it produced
  is a promise to callers and stands. §4.2.
- **`put_all` is dropped.** It is `Pool.put` in a loop, inherited from
  `pool.zig:394`, and it cost a container operation and a MUST clause. §6.
- **The specification moves to 003.** Nine Parts change. §8.

---

# 1. The audit, against the code

`3tk-to-fifo-lifo-single-001.md` §9 and §17 both say: do not remove `prev`
before the required-operation audit proves nothing needs it. This is that audit.

## 1.1 Who actually calls what

`NodeList` has sixteen operations — proposal 004, section 5.5. This is every
call site of the eleven that are not `push_back`, `pop_front`, `is_empty`,
`len`.

| Operation | Called from `src/` | Verdict |
|---|---|---|
| `insert_after` | `mailbox.c3:152` — the out-of-band insert, and nowhere else | Deleted with the anchor. §4.1 |
| `insert_before` | **nowhere**. Only `list.c3:196` declares it | Never used. Deleted |
| `remove` | **nowhere**. Only `list.c3:294` declares it | Never used. Deleted |
| `pop_back` | **nowhere**. Only `list.c3:276` declares it | Never used. Deleted |
| `back` | **nowhere** | Never used. Deleted |
| `front` | **nowhere** | Never used. Deleted |
| `push_front` | `mailbox.c3:155` — the out-of-band insert with no anchor | Deleted with the anchor |
| `push_front_slot` | `pool.c3:451` — `put_all`'s refusal path | **Deleted with `put_all`.** §6 |
| `append_list` | `mailbox.c3:326`, `:375`; `pool.c3:479` | Survives as `append_queue`. §5.3 |
| `iter` | **nowhere** in `src/`; `t_identity.c3:139` | Survives on the queue. §5.2 |
| `contains` | `list.c3:101`, `:180`, `:298` — the tier 3 guards only | **Deleted.** §3 removes its reason to exist |

**The audit passes.** `prev` has exactly one job in `3tk/src/` —
`unlink_no_repair` at `list.c3:251-256`, which serves `remove` and `pop_back`,
and both are dead.

**CHANGED IN 002.** 001 had a row here saying `push_front_slot` survives, for
Part 11.8 MUST alone, and called it the one place the minimal container is not
the minimum. With `put_all` dropped that row is gone and the queue is minimal
after all.

## 1.2 The out-of-band semantics, measured

`3tk-to-fifo-lifo-single-001.md` §4 refuses to choose two queues before the
exact ordering is written down, and offers three meanings. The code answers it.

`mailbox.c3:143-159`, `enqueue`:

- An ordinary item goes to the back of the whole queue.
- An out-of-band item goes after `_oob_anchor`, the **last out-of-band item**,
  and then becomes the anchor.
- With no anchor it goes to the **front**.
- `dequeue`, `:168-173`, clears the anchor when the anchor itself is taken.

Every out-of-band item is ahead of every ordinary item, and the two classes are
first-in first-out within themselves. **That is Meaning A.** Meanings B and C
are not implemented and are not specified.

`t_mailbox.c3:139-162` asserts it: send ordinary 0, oob 1, ordinary 2, oob 3,
ordinary 4; receive 1, 3, 0, 2, 4.

**Two queues reproduce Meaning A exactly.** `_oob.pop_front()` first, then
`_regular.pop_front()`, gives 1, 3, 0, 2, 4 on the same input. The test does not
change.

## 1.3 The pool order, and the owner's reason

The code is first-in first-out — `pool.c3:425` pushes at the back, `:263` and
`:337` take from the front. Least recently returned comes back first. Ruling 3
reverses it.

**The reversal is legal.** Part 11.10 MUST — *the count, the identity and the
order are all hook policy; the pool promises nothing about which item comes
back*. No test in `t_pool.c3` asserts the current order.

**CHANGED IN 002 — the reason, from the owner, 2026-08-23.** 001 recorded the
reversal as legal-but-arbitrary and gave no reason for it. It has one, and it is
**not** cache locality and **not** performance. It is defect surfacing:

> Under first-in first-out the item just given back goes to the *back* of the
> free list. Code still keeping a pointer to it after `put` writes to an item
> nobody has re-taken, so nothing conflicts. If the put hook did not reset the
> contents, the stale writer reads data that still looks plausible and never
> trips. The item is given out again much later, and the damage appears far from
> its cause.
>
> Under last-in first-out the item is on top and the **next `get` gives it
> straight to a new owner.** The stale writer and the new owner write the same
> item at the same moment, so the defect appears next to its cause.

Same reasoning as not quarantining freed memory: reuse the hottest item so a
stale pointer meets a live second owner immediately, rather than delaying reuse
and letting the defect hide.

**This belongs in the doc comment on `PoolBucket`'s stack**, because a later
reader who takes the stack for an arbitrary choice will change it back to a
queue. It also explains why §8 leaves the order unpromised: what makes the
property useful is that no caller is entitled to it.

## 1.4 Where this document disagrees with its inputs

- **`3tk-to-fifo-lifo-single-001.md` §8 keeps `contains` implicitly**, by
  keeping the walk as the surviving check. §3 shows the walk catches nothing the
  link test misses once the link test is exact.
- **§13 gives `PoolBucket` a `top` and a `len`.** `PoolBucket` already keeps no
  count — `pool.c3:94-98` — because `NodeList.len` is O(1) and Part 11.7 asks
  for a separate count only where it is not. `InnerStack` keeps its own count
  for the same reason. The bucket gains nothing.
- **§14 says a single link makes an item's one-container-at-a-time property
  self-enforcing.** It does not, by itself. A single link with a null terminator
  makes the violation *undetectable*. §3 is what makes §14 true.

---

# 2. The name mapping

Ruling 1. `3tk-naming-001.md` is accepted as written, with the additions the
code forces.

**`Outer` is a category, never a type.** No `Outer` is declared. It is what the
prose calls the application's struct, and `3tk-naming-001.md`'s *Important
restriction* is carried into the doc comments: the generic boundary is spelled
Outer/Inner, application prose says *the request*.

| Today | Ruled | Note |
|---|---|---|
| `AnyNode` | **`Inner`** | Two fields now. §3 |
| `AnyHandle` | **`Handle`** | Still a transparent alias for `Inner*`. D4 stands |
| `Slot` | `Slot` | Unchanged. D5 stands |
| `NodeList` | **`InnerQueue`** | First-in first-out. Seven operations. §5.1 |
| — | **`InnerStack`** | Last-in first-out. New. Six operations |
| `NodeListIterator` | **`InnerQueueIterator`** | §5.2 |
| `is_linked(h)` | `is_linked(h)` | Kept, and it becomes **exact**. §3 |
| `reset(h)` | `reset(h)` | Kept. Clears `next` to null |
| `NodeList.contains` | — | **Deleted.** §3 |
| `mtk::helper::to_any` | **`to_inner`** | An inherited name, and it now says the direction |
| `mtk::helper::from_any` | **`from_inner`** | |
| `mtk::helper::must_from_any` | **`must_from_inner`** | |
| `mtk::helper::is_mine` | `is_mine` | Unchanged. Not an inherited name |
| `mtk::helper::init`, `OFF`, `TYPE` | unchanged | |
| `from_slot`, `must_from_slot`, `move_from_slot` | unchanged | |
| `mtk::owned::create`, `release` | unchanged | |
| `mtk::node_offset($Type)` | **`inner_offset($Type)`** | Its message names `Inner` |
| `Mailbox`, `Pool`, `PoolHooks`, `GetMode`, `PoolBucket` | unchanged | |
| `Mailbox._queue` | **`_regular`, `_oob`** | Two fields. §4 |
| `Mailbox._oob_anchor` | — | **Deleted.** §4 |
| `Pool.put_all` | — | **Deleted.** §6 |
| `PoolBucket.free` | `free`, retyped `InnerStack` | §5.4 |
| the file `list.c3` | **`queue.c3`, `stack.c3`** | |
| the file `any.c3` | **`inner.c3`** | |

**`Handle`, not `InnerHandle`.** `3tk-naming-001.md` writes `mtk::Handle` in its
recommendation and `Inner`-prefixed names only for the collections. The module
prefix already says whose handle it is, and D4's one-handle ruling reads better
with the short name.

**There is no `InnerList`.** `3tk-naming-001.md` offers that name only *if a
general list survives because a real requirement needs it*. Ruling 2 refuses a
general list and §1.1 found no requirement, so the name is not cut. One queue
type serves both the mailbox's internal queues and the transfer container that
crosses the public surface.

**One collision to check at 3TK-11, not now.** `Inner`, `Handle` and `Slot` are
short and live in `module mtk`. An application importing `mtk` and a second
library could collide, and would qualify as `mtk::Handle`. `Slot` has the same
exposure today and nothing has met it.

---

# 3. The guard — consequence 2, and the ruling that changed

**CHANGED IN 002. R6 was refused: no membership field. The guard is mechanism
B, the self-link.**

## 3.1 The problem

Today, `list.c3:58`:

```c3
fn bool is_linked(AnyHandle h) => h != null && (h.prev != null || h.next != null);
```

Part 8.7 MUST already documents its blind spot: an item **alone** on a list has
no neighbours and reports false. D12 accepted it; Part 8.6's O(n) walk covers it
in checking builds only.

Delete `prev` naively and the blind spot stops being an edge case. The **last
item of every queue** would have `next == null`. In a queue of ten, one item is
invisible. In the pool's stack, the bottom item is. The guard would fail exactly
where a double insert is most likely — a worker giving back an item it most
recently touched.

The walk does not rescue it. `contains` answers *is it on __this__ container*.
Only the link test sees a **different** one, and Part 8.6 says in so many words
that neither alone is enough.

## 3.2 The ruling

```
Inner
    Inner* next      the single link. Ruling 5
    typeid type      identity. Part 5, unchanged
```

**Two fields. 16 bytes on linux-x64, down from 24.** As always the number is an
observation and no code may depend on it.

**The last item of every chain points at itself.** Then:

- `is_linked(h) => h != null && h.next != null`, and it is **exact.** On a
  chain, `next` is never null. Off a chain, it is always null.
- **Part 8.7's blind spot closes, with no field.** An item alone on a queue is
  self-linked and reports linked.
- **`contains` and the O(n) walk on every insert are deleted.** An exact link
  test refuses an item on *any* chain, this container or another, so the walk
  catches nothing it misses. Part 8.6's double check becomes one check that is
  stronger than both halves together.
- **Inserts are O(1) in every build mode**, not only fast ones.
- **The guard becomes tier 2** rather than tier 3, so it aborts in a fast build.
- `reset(h)` clears `next` to null — Part 8.8 unchanged in wording.
- Every walk ends at `n.next == n`.

The shape, for the record:

```
push_back, empty queue     h.next = h;  head = tail = h
push_back, non-empty       h.next = h;  tail.next = h;  tail = h
pop_front, last item       head = tail = null;          reset(h)
pop_front, otherwise       head = h.next;               reset(h)
push  (stack), empty       h.next = h;  top = h
push  (stack), non-empty   h.next = top; top = h
pop   (stack)              top = (h.next == h) ? null : h.next;  reset(h)
append_queue               self.tail.next = other.head; self.tail = other.tail
```

`append_queue` needs no repair: `other.tail` is already self-linked and stays
the new tail.

## 3.3 Why the field was refused, and why 001 was wrong to want it

001 proposed a third field, `void* chain`, at the same 24 bytes `prev` cost. It
gave exact membership — `chain == container` in O(1) — and the same deletion of
`contains`.

**It bought exactly one query beyond what the self-link gives: *is it on __this__
container*. `remove` was that query's only caller, and `remove` is deleted.**

001 refused mechanism B on the ground that a terminator gives `next` three
meanings across **eleven sites** in `list.c3`. That count is from the container
ruling 2 abolishes. With `remove`, `pop_back`, `insert_after`, `insert_before`,
`front` and `back` deleted, about **four** sites touch `next` — `pop`, `push`,
`append_queue`, `iter`. The objection was priced against the old container.

## 3.4 The alternatives, and why not

| Mechanism | Inner | Guard | Refused because |
|---|---|---|---|
| Lose the check | 16 B | walk only, same-container, checking builds | Invariant 20 — *an item is in exactly one place*, Part 9.6 MUST — would have no runtime guard against the commonest way to break it, in any build mode |
| **Self-link** | **16 B** | `next != null`, exact | **Ruled** |
| Shared terminator | 16 B | `next != null`, exact | Needs a public `mtk::END_OF_CHAIN` visible to the container submodules and so to applications; the end test needs an external address; a mistaken read lands on a dummy node. The self-link adds no public name, tests against the loop variable, and a mistaken read lands on the item itself, which is valid memory |
| Membership field | 24 B | `chain == container`, exact | R6. Refused: one extra query, no caller, a field every item pays for |
| Circular through a header sentinel | 16 B | `next != null`, exact | The container header would embed an `Inner`, so a `Mailbox` would carry three of them and Part 4.4 stops making sense |

**What the self-link does not catch**, stated so no one claims more: a chain
corrupted by code reaching around the container surface. The guard is exact for
every path through the public surface.

**The cost, honestly.** `next` has two meanings instead of one, and a walk that
forgets `n.next == n` loops forever rather than aborting. Four sites carry it,
each of them short, and 3TK-11 states the walk shape once in `queue.c3` and once
in `stack.c3`.

---

# 4. The two queues — consequences 1 and 3

Ruling 4. `Mailbox` has `_regular` and `_oob`, both `InnerQueue`.

## 4.1 What is deleted

- **`_oob_anchor`**, `mailbox.c3:62`, and the four lines that maintain it —
  `:158`, `:171`, `:327`, `:376`.
- **`enqueue`'s branch**, `:143-159`. `send` pushes `_regular`, `send_oob`
  pushes `_oob`.
- **`dequeue`'s anchor repair**, `:171`. `dequeue` tries `_oob`, then
  `_regular`.
- **`insert_after`**, whose only caller was `:152`.
- **The mechanism clause of Part 11.3** — the anchor bullets. Two queues make
  the out-of-band insert O(1) with no anchor.

## 4.2 What is not deleted — invariant 22, R9 accepted

Plan 006 said two queues delete D14's anchor **and invariant 22**. The anchor,
yes. Invariant 22, no.

Invariant 22 is *out-of-band items are ahead of ordinary ones, first-in
first-out within each*. That is a promise to a caller about order. It is
asserted at `t_mailbox.c3:139-162`. Two queues are a cleaner implementation of
the same promise, which is what `3tk-to-fifo-lifo-single-001.md` §5 claims for
them.

**Delete the mechanism. Keep the guarantee.** An invariant table that loses row
22 tells a later reader the ordering is no longer promised, and it is.

**D14 survives with its second clause intact:** out-of-band is one priority
level, not a priority queue. Two queues is one level with a cleaner home. Part
11.4 MAY is unchanged.

## 4.3 The give-back order — R8 accepted

**Out-of-band first, then ordinary, first-in first-out within each. For `close`
and `receive_all` both.**

It changes nothing, which is the reason. The single queue already keeps
out-of-band ahead of ordinary, so `mailbox.c3:375` gives the caller exactly that
order today. Appending `_oob` then `_regular` reproduces it item for item.

**The rule, one sentence, for both doc comments:**

> Where the mailbox gives items back as a list, the list is in the order
> `receive` would have taken them out.

`t_mailbox.c3:225` and `:251` assert batch and remainder order and **neither
test changes.** The alternative — ordinary first — reorders a caller-visible
list to no purpose.

## 4.4 Two sites a rewrite loses quietly

- `Mailbox.len`, `:390-395`, returns `_oob.len() + _regular.len()`. One number
  to a caller, and it stays one.
- `receive`'s Part 2.6 hand-off, `:301`: `if (!self._queue.is_empty())
  self._cv.signal();` becomes a test of **both** queues. **Invariant 5 is the
  easiest thing in this redesign to half-fix**, and a leaver that checks only
  `_regular` leaves a queued out-of-band item with nobody woken.

---

# 5. What Part 8 becomes

Consequence 1. One list of sixteen operations becomes two containers of seven
and six.

## 5.1 The sixteen, ruled

| Part 8.2 operation | `InnerQueue` | `InnerStack` | Why |
|---|---|---|---|
| Take from the front | `pop_front` | `pop` | The primitive of both |
| Add at the back | `push_back` | — | First-in first-out |
| Add at the front | — | `push` | **CHANGED IN 002.** The queue's front insert goes with `put_all`. §6 |
| Add at the back from a Slot | `push_back_slot` | `push_slot` | `send`, and the put hook's `extra` |
| Add at the front from a Slot | — | — | **CHANGED IN 002.** Its only caller was `put_all` |
| Is it empty | `is_empty` | `is_empty` | |
| How many | `len` | `len` | O(1), kept count. Part 11.7 |
| Walk it | `iter` | — | §5.2 |
| Move another onto this one | `append_queue` | — | §5.3 |
| Look at the front, look at the back | — | — | No caller |
| Take from the back | — | — | No caller |
| Remove a named item | — | — | No caller |
| Insert after, insert before | — | — | No caller once the anchor is gone |
| Is it on this list | — | — | **Replaced by the exact link test.** §3 |

**Seven operations on the queue, six on the stack. Nine of the sixteen leave the
port.**

`InnerQueue` keeps `head`, `tail`, `count`. `InnerStack` keeps `top`, `count`.

## 5.2 The walk

`iter` has one caller outside `t_list.c3`: `t_identity.c3:139`, which walks a
heterogeneous list and dispatches on identity. That is **Part 6.5's
demonstration**, and the one place the toolkit shows what a type-erased
container is for. It stays, on the queue.

The stack gets none. Nothing walks a free list, and Part 8.4 is a SHOULD.

Its contract — removal during a walk is not supported — is unchanged, and it now
also carries the self-link end test.

## 5.3 Moving a chain onto another

`append_list` has three callers in `src/`: `mailbox.c3:326`, `:375`,
`pool.c3:479`. It survives as `InnerQueue.append_queue`, queue onto queue, O(1)
because the queue keeps a tail.

**Part 8.9's pair survives unchanged**: the tier 2 check and the early return
against moving a queue onto itself. `negative/self_move.c3` still compiles and
still aborts. The failure it guards — ringing the items into a cycle and
clearing the header — is identical with one link.

**R12, accepted, with the order left unstated.** `Pool.close` empties every
bucket into **one `InnerQueue`**, flattened. The close hook never sees buckets
or per-identity groups: one container, one loop, `pop_front` until empty,
release each item.

- The stack has no tail, so the O(1) splice is not available. The write is `pop`
  then `push_back`. **O(n) in the items kept, once, on a pool going down.**
- **No order is promised**, because the hook's loop is the same whatever order
  the items arrive in. `push_back` is chosen for being the simplest write, not
  for the order it happens to produce.
- The loop has a property a splice lacks: each item passes through `pop` and
  `push_back`, so every item's self-link is repaired on the way. A splice would
  have to walk and repair anyway.

## 5.4 The types on the container surfaces

**CHANGED IN 002: four public signatures, not five.** `Pool.put_all` is gone.

- `Mailbox.receive_all(InnerQueue* out)` — `mailbox.c3:317`
- `Mailbox.close(InnerQueue* out)` — `mailbox.c3:365`
- `PoolHooks.on_put(usz, Slot*, InnerQueue* extra)` — `pool.c3:62`
- `PoolHooks.on_close(InnerQueue* remaining)` — `pool.c3:73`

**A queue and not a stack in all four**, including the pool's. What a hook
receives is a batch to walk and release in order, not a store for reuse. The
queue is the port's **transfer** container; the stack is the port's **storage**
container, and keeping the split is what keeps `InnerStack` off every signature
3tk publishes.

**REVISED 2026-08-26, on the owner's ruling.** *Off every signature* is what
this section ever meant, and *out of the application's surface entirely* is what
it used to say. **Both containers are available to a caller**, exactly as the
queue always was: `Pool` is the only user of a stack inside the toolkit, and
that is a fact about the toolkit, not a restriction on the application. `R13`
is revised in the same move.

`PoolBucket.free` — `pool.c3:97` — is the only `InnerStack` in the port.

## 5.5 The invariants Part 8 was carrying

| Invariant | Part | What happens |
|---|---|---|
| 13 — heterogeneous, O(1), allocation-free | 8.1 | **Stronger.** Insert is O(1) in checking builds too |
| 14 — the container speaks in type-erased handles | 8.3 | Unchanged. Both take `Handle` and `Slot*` |
| 15 — the container layer is where the checks live | 8.5 | Unchanged. Two layers now, same rule |
| 16 — the link test is not a membership test | 8.7 | **Retired, and replaced.** With the self-link it is exact |
| 17 — a removed item's links are cleared | 8.8 | Unchanged. `reset` clears `next` to null |
| 20 — an item is in exactly one place | 9.6 | **Better guarded than today**, in every build mode |
| 22 — out-of-band ahead of ordinary | 11.3 | **Kept.** §4.2 |

**One invariant is new**, and it is the one the redesign turns on:

> **An item on a chain has a non-null `next`; the last item of a chain points at
> itself. An item on no chain has `next == null`.** Every insert and every
> removal maintains it, and `is_linked` reads it.

It takes retired 16's place. The table does not shrink.

---

# 6. `put_all` is dropped — R15

**CHANGED IN 002. New decision, and it retires R4.**

`Pool.put_all` — `pool.c3:440` — is **`Pool.put` in a loop.** No lock is kept
across iterations, the hook still runs once per item, there is no batching and
no atomicity. Every iteration is exactly what a caller would write. It is
inherited: `pool.zig:394`.

**It does not spare the caller the difficult case; it gives the difficult case
back in a different shape.** The easy part is the loop. The hard part is a pool
closing mid-batch — and after `put_all` returns, the caller still keeps a
partly-emptied queue and still has to decide what happens to the rest.

What it cost:

- **A container operation nothing else needs.** `push_front_slot`, for
  `pool.c3:451` alone once the anchor is gone.
- **A MUST clause in Part 11.8** — *stops at the first refusal, puts that item
  back at the front, the caller checks the list after the call* — and the
  restored-order warning with it.
- **The most awkward contract in the toolkit.** It returns nothing, completes
  partly, and is read by inspecting an out-parameter.

**Ruling 2's own principle applies to it unchanged:** *add an operation when a
real Matryoshka behaviour requires it, not because the source library had one.*
001 applied that to `NodeList` and not to `put_all`.

What dropping it gives: **`InnerQueue` reaches seven operations and is genuinely
minimal.** No front insert anywhere in the port. Part 11.7 loses *put a list*;
Part 11.8 loses its list-put clause and the restored-order warning rather than
gaining a justification for them.

The loop goes into `Pool.put`'s doc comment, three lines, and into the worked
example if that stage ever runs.

**The counter, recorded because it is real:** an application returning a batch
from `Mailbox.close` to a pool is a common shape, and it now writes the loop
itself, with a chance of getting the refusal case wrong and losing items
quietly.

---

# 7. What survives untouched

- **D1** — public direct representation, no fight with the language over hiding.
  `3tk-to-fifo-lifo-single-001.md` §15 says smaller containers make hiding
  easier. They do not: M5 is that C3 0.8.3 has no field privacy at all, and a
  smaller struct is as readable as a larger one.
- **D3** — allocators taken at creation, kept for life, no release parameter.
- **D5** — the distinct `Slot` and its five primitives.
- **D6** — the three assert tiers, unchanged. Every guard here is tier 2 or
  tier 3.
- **D7** — the wait loop, both copies. §4.4 is the one line inside it that moves.
- **D9, D13, D15, D16** — untouched.
- **Section 6 of proposal 004**, all seven implementation invariants. 6.2
  (creation is a transaction) and 6.5 (no bucket reference survives a hook call)
  are the two a rewrite most easily loses.
- **Parts 12, 13, 14, 15, 17, 19** of the specification. **No fault is added or
  removed by this redesign.**
- **Part 17.2's layering.** The containers use only the public surface of the
  core, now five types instead of four.

---

# 8. The specification moves to 003 — R14 accepted

**Not a 3tk deviation.** And **not done by 3TK-11** — `../common/` is untouched
by this stage, and cutting 003 is its own piece of work.

## 8.1 What moves

| Part | Marking | Change |
|---|---|---|
| 4.2 The inner | MUST | *the links of a doubly-linked list. Two fields* becomes one link plus the self-link terminator. Two conceptual parts survive: linkage, identity |
| 8.1 The rule | MUST | *a doubly-linked list* becomes *ordering primitives whose nodes are the inners of Part 4* |
| 8.2 The surface | SHOULD | Sixteen operations become seven and six. §5.1 |
| 8.6 The double check | SHOULD | **Deleted.** One exact check replaces two partial ones |
| 8.7 The link test and its blind spot | MUST | **Rewritten.** Its own last bullet — *a port whose list marks membership properly is strictly better here* — becomes the rule, and the self-link is how it is paid for |
| 8.9 Moving a list onto itself | SHOULD | Unchanged in force, narrowed to the queue |
| 11.3 The mailbox | MUST | The two anchor bullets go. The three ordering guarantees stay |
| 11.7 The pool | MUST | *One free list per identity* becomes *one stack per identity*. **Put a list is deleted.** §6 |
| 11.8 The give-back rule, pool side | MUST | The list-put clause and the restored-order warning are deleted. §6 |
| Part 18 | — | Row 16 retired and replaced, row 22 kept, row 13 strengthened. §5.5 |

Parts 1, 2, 3, 5, 6, 7, 9, 10, 12 to 17 and 19 to 22 are untouched.

**Part 11.7 stays silent on the pool's order — R11.** Say the container is a
stack. Do not promise most-recently-returned-first. Part 11.10 MUST already says
the pool promises nothing about which item comes back, and §1.3's reason works
only while no caller is entitled to it.

## 8.2 Why moving, and not a deviation

- **The specification's own claim is that a port is written from it alone.** A
  3tk deviation makes the C3 port the one that is not, and the next port written
  from 002 would reproduce `prev`, the general list and the anchor — and then
  need this same stage.
- **Nothing here turns on a C3 capability.** Ruling 5 is an argument about the
  model; the self-link is an argument about states. Neither is about `typeid` or
  `$foreach`.
- **The cost lands where nothing is built.** dtk has run no stage; otk needs
  refactoring anyway; ztk is a realization rather than the source of truth, and
  the specification already records places where a port is *better* than ztk —
  Part 11.11 in those words.

---

# 9. The register

R, for redesign, so nothing collides with proposal 004's D1 to D16.

| # | Decision | Status |
|---|---|---|
| R1 | `Any` goes. `Inner`, `Handle`, `Slot`. `to_inner` / `from_inner` / `must_from_inner`. `inner_offset` | Direction, ruling 1 |
| R2 | No general list. `InnerQueue` and `InnerStack` | Direction, rulings 2 and 3 |
| R3 | Nine of Part 8.2's sixteen operations are deleted | Follows. §5.1 |
| R4 | The queue keeps a front insert for Part 11.8 | **RETIRED by R15.** §6 |
| R5 | One link. `prev` is deleted | Direction, ruling 5 |
| R6 | A membership field in `Inner` | **REFUSED 2026-08-23.** §3.3 |
| R6b | **The guard is the self-link.** `Inner` is two fields, 16 bytes. `is_linked` is exact. `contains` and the O(n) insert walk are deleted. The check becomes tier 2 | **RULED.** §3.2 |
| R7 | The mailbox has `_regular` and `_oob`. The anchor is deleted | Direction, ruling 4 |
| R8 | Out-of-band first, then ordinary, for `close` and `receive_all` both | **ACCEPTED.** §4.3 |
| R9 | Invariant 22 is kept. Only the anchor mechanism is deleted | **ACCEPTED.** §4.2 |
| R10 | Invariant 16 is retired and replaced by the self-link invariant | **ACCEPTED.** §5.5 |
| R11 | Pool reuse becomes last-in first-out, **for defect surfacing**, and Part 11.7 stays silent on order | **ACCEPTED**, with the owner's reason. §1.3 |
| R12 | `Pool.close` empties every bucket into one `InnerQueue`, `pop` then `push_back`, O(n) once, **no order promised** | **ACCEPTED.** §5.3 |
| R13 | Four public signatures take `InnerQueue*`. `InnerStack` is on no signature 3tk publishes, and `Pool` is its only user inside the toolkit — **it is available to a caller like the queue**. There is no `InnerList` | **ACCEPTED**, and its middle clause **REVISED 2026-08-26** on the owner's ruling. §5.4 |
| R14 | The specification moves to 003. Part 11.7 stays silent on order | **ACCEPTED.** §8 |
| R15 | **`Pool.put_all` is dropped**, with `push_front` and `push_front_slot` | **RULED 2026-08-23.** §6 |

---

# 10. What it costs

## 10.1 Source

Every file changes. `3tk/src/` is 1655 lines.

| File | Change |
|---|---|
| `any.c3` → `inner.c3` | Renames, `prev` deleted, `is_linked` rewritten, the self-link invariant documented |
| `list.c3` → `queue.c3` + `stack.c3` | **Rewritten.** 339 lines become perhaps 170 across two files. Nine operations deleted, `contains` deleted, `unlink_no_repair` deleted |
| `helper.c3` | Three renames. Otherwise untouched |
| `owned.c3` | Renames only |
| `mailbox.c3` | Two fields for one, `enqueue`/`dequeue` rewritten, anchor deleted, `len` and the leaver's signal changed |
| `pool.c3` | `PoolBucket.free` retyped, `get`/`get_wait`/`take_back_handle` become stack calls, `close` becomes a loop, `put_all` deleted, four signatures retyped |
| `mtk.c3` | The reading order names the files. Rewritten |

## 10.2 Tests

77 tests today, 59 checks over four builds.

| File | Tests | Fate |
|---|---|---|
| `t_list.c3` | 15 | **Rewritten as `t_queue.c3` + `t_stack.c3`.** Seven test operations that will not exist. The two blind-spot tests **invert** — they become tests that the blind spot is gone |
| `t_pool.c3` | 18 | Renames; two `put_all` tests deleted and three others become explicit loops; a new test that reuse is last-in first-out |
| `t_mailbox.c3` | 13 | Renames. The order tests at `:139`, `:225`, `:251` **pass unchanged** |
| `t_identity.c3` | 8 | Renames. `:139`'s walk survives |
| `t_slot.c3`, `t_owned.c3`, `t_concurrency.c3`, `t_alloc.c3` | 23 | Renames only |

**Roughly 22 of 77 tests are rewritten or deleted; the rest are renamed.**
3TK-11 states the new number rather than inheriting this one.

## 10.3 The negatives

| Negative | Fate |
|---|---|
| `insert_linked_item.c3` | **Survives and gets stronger.** It provokes a link test with no blind spot |
| `insert_twice_same_list.c3` | **Rewritten.** It provoked the walk, and the walk is gone. It becomes a link-test provocation, and it now aborts in a **fast** build too, because the check is tier 2 |
| `self_move.c3` | Renames. `append_queue` keeps Part 8.9's pair |
| `nocompile_two_inners.c3`, `nocompile_no_inner.c3` | Renames. `inner_offset`'s messages name `Inner` |
| The other eight | Renames only |

## 10.4 Documents

`3tk-porting-proposal-004.md` names types that stop existing. **It is not
edited** — it is the design of record for what was built, and this document is
the record for what replaces it. Whether a proposal 005 folds the two together
is the owner's call.

The finished stage outputs — the toolkit, container and sanitizer notes — are
not rewritten.

---

# 11. What is next

**Everything is ruled. 3TK-11 has no open question in front of it.**

```
Run 3TK-11 from design/secondary/lang/c3/3tk-status.md
```

Two pieces of work exist beyond it and neither belongs to it:

- **Specification 003**, R14. It is authorized in direction and not scheduled.
  A revision or a stage; the owner names which.
- The candidate stages in `3tk-status.md`, none authorized.

*Advice on clear: clear before 3TK-11. This document is the input; the argument
that produced it is not.*
