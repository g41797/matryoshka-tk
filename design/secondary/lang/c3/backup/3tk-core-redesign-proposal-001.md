# The 3tk core redesign proposal (001)

Stage 3TK-10 of `3tk-staging-plan-006.md`. Written against
`../common/matryoshka-specification-002.md`, `3tk-porting-proposal-004.md`, and
`3tk/src/` as it stands green.

**This document ends at a decision register. It writes no C3.** The code is
3TK-11, and 3TK-11 runs only after the owner has ruled on what follows.

## Status

**Proposed. Nothing here is accepted.**

The owner's direction of 2026-08-23 — five rulings, reproduced in
`3tk-status.md` and in plan 006 — is the **input**, not the question. This stage
does not relitigate it. It works out what it costs, what it changes, and what
it breaks, and it answers the four consequences plan 006 named.

The two documents that argued for the direction are
[3tk-naming-001.md](3tk-naming-001.md) and
[3tk-to-fifo-lifo-single-001.md](3tk-to-fifo-lifo-single-001.md). They were read
the way 3TK-8 read its review: **against the code, not on trust.** Section 1 is
that reading, and it is where this document disagrees with them.

## What the reading found, in one screen

- **The required-operation audit passes.** Nothing in `3tk/src/` needs arbitrary
  removal, arbitrary insertion, backward traversal or `pop_back`. Section 1.1.
- **The out-of-band semantics are Meaning A** — absolute priority, FIFO within
  each class. `mailbox.c3:143-159`. Two queues reproduce it **exactly**, with no
  observable change anywhere, including `receive_all` and `close`. Section 1.2.
- **The pool is FIFO today, not LIFO.** `pool.c3:263`, `:337`, `:425`. The
  direction's ruling 3 is therefore a **behaviour change**, not a container
  swap. It is a legal one — Part 11.10 promises no order — and no test asserts
  the current order. Section 1.3.
- **Consequence 2 has a better answer than the four plan 006 listed.** A
  membership field replaces `prev` at **identical inner size**, closes the blind
  spot the current design documents and accepts (D12), and **deletes the O(n)
  walk from every insert**. The redesign is stronger than what it replaces, not
  weaker. Section 3.
- **Invariant 22 should not be deleted.** D14's *anchor* dies. The *ordering* it
  produced is observable, tested, and unchanged by two queues. Delete the
  mechanism clause of Part 11.3; keep invariant 22. Section 4.
- **This is a specification change and the recommendation is to move the
  specification**, not to declare a 3tk deviation. Section 8. The owner rules.

---

# 1. The audit, against the code

`3tk-to-fifo-lifo-single-001.md` §9 and §17 both say: do not remove `prev`
before the required-operation audit proves nothing needs it. This section is
that audit. It is a grep over `3tk/src/`, `3tk/test/` and `3tk/negative/`, and
every row names a file and a line.

## 1.1 Who actually calls what

`NodeList` has sixteen operations — proposal 004, section 5.5. This is every
call site of the eleven that are not `push_back`/`pop_front`/`is_empty`/`len`.

| Operation | Called from `src/` | Called from `test/` | Verdict |
|---|---|---|---|
| `insert_after` | `mailbox.c3:152` — the out-of-band insert, and **nowhere else** | `t_list.c3` ×4 | Dies with the anchor. Section 4 |
| `insert_before` | **nowhere**. Only `list.c3:196` declares it | `t_list.c3` ×3 | Never used. Drop |
| `remove` | **nowhere**. Only `list.c3:294` declares it | `t_list.c3` ×4 | Never used. Drop |
| `pop_back` | **nowhere**. Only `list.c3:276` declares it | `t_list.c3` ×7 | Never used. Drop |
| `back` | **nowhere** | `t_list.c3` ×6 | Never used. Drop |
| `front` | **nowhere** | `t_list.c3` ×6 | Never used. Drop |
| `push_front` | `mailbox.c3:155` — the out-of-band insert with no anchor | `t_list.c3` ×2 | Survives, for a different reason. Row below |
| `push_front_slot` | `pool.c3:451` — `put_all`'s refusal path | `t_list.c3` ×3 | **Survives. Part 11.8 MUST** |
| `append_list` | `mailbox.c3:326`, `:375`; `pool.c3:479` | `t_list.c3` ×8, `negative/self_move.c3` | Survives, changed. Section 5.3 |
| `iter` | **nowhere** | `t_list.c3` ×2, `t_identity.c3:139` | Survives. Section 5.2 |
| `contains` | `list.c3:101`, `:180`, `:298` — the tier 3 guards only | `t_list.c3:176`, `:193` | **Dies.** Section 3 removes its reason to exist |

**The audit passes.** No Matryoshka behaviour requires arbitrary removal,
arbitrary insertion or backward traversal. `prev` has exactly one job in
`3tk/src/` — `unlink_no_repair` at `list.c3:251-256`, which serves `remove` and
`pop_back`, and both are dead.

**One row is a trap and it is the reason `push_front` survives.** Part 11.8 MUST
says a list put stops at the first refusal and puts that item back **at the
front** of the caller's list. `pool.c3:451` is that line. A FIFO primitive with
no front insert cannot obey Part 11.8, so `InnerQueue` keeps a front insert and
its Slot form. This is the one place the "minimal container" is not the minimum.

## 1.2 The out-of-band semantics, measured

`3tk-to-fifo-lifo-single-001.md` §4 refuses to choose two queues before the
exact ordering is written down, and offers three meanings. The code answers it.

`mailbox.c3:143-159`, `enqueue`:

- An ordinary item goes to the back of the whole queue.
- An out-of-band item goes after `_oob_anchor`, which is the **last out-of-band
  item**, and then becomes the anchor.
- With no anchor it goes to the **front**.
- `dequeue`, `:168-173`, clears the anchor when the anchor itself is taken.

So every out-of-band item is ahead of every ordinary item, and the two classes
are FIFO within themselves. **That is Meaning A**, absolute priority. Meanings B
and C are not implemented and are not specified.

`t_mailbox.c3:139-162` asserts it: send ordinary 0, oob 1, ordinary 2, oob 3,
ordinary 4; receive 1, 3, 0, 2, 4.

**Two queues reproduce Meaning A exactly.** `oob.pop_front()` first, then
`regular.pop_front()`, gives 1, 3, 0, 2, 4 on the same input. The test does not
change.

## 1.3 The pool is FIFO today

The direction's ruling 3 says LIFO — "get from last added". The code does not do
that.

- `pool.c3:425`, `take_back_handle`: `b.free.push_back(h)`.
- `pool.c3:263`, `get`: `b.free.pop_front()`.
- `pool.c3:337` and `:348`, `get_wait`: `b.free.pop_front()`.

Push at the back, pop at the front. **That is FIFO — least recently returned
first.** Ruling 3 reverses it.

**The reversal is legal and cheap.** Part 11.10 MUST — *put three items, then
get three; the count, the identity and the order are all hook policy; the pool
promises nothing about which item comes back*. Invariant 10 of Part 18 is not
about this. No test in `t_pool.c3` asserts which item returns; the one identity
assertion, `t_pool.c3:142`, has a single item in the bucket.

**But it is a behaviour change and this document says so out loud**, because the
direction is written as if it were a container choice. A user with two items in
a bucket gets the other one after 3TK-11. Nothing promised them otherwise.

## 1.4 Where this document disagrees with its inputs

Three places. Each is a claim in the owner's two documents that the code does
not support.

- **`3tk-to-fifo-lifo-single-001.md` §8 keeps `contains` implicitly**, by
  keeping the walk as the surviving check. Section 3 shows the walk is not
  needed at all once membership is a field, and that the field is free.
- **§13 gives `PoolBucket` a `top` and a `len` and calls the bucket the owner of
  the reuse policy.** `PoolBucket` already keeps no count — `pool.c3:94-98` —
  because `NodeList.len` is O(1) and Part 11.7 asks for a separate count only
  where it is not. `InnerStack` keeps its own count for the same reason. The
  bucket gains nothing.
- **§14 says a single link makes an item's one-list-at-a-time property
  self-enforcing.** It does not. A single link makes the *violation
  undetectable*, which is the opposite. Section 3 is the whole of that argument.

---

# 2. The name mapping

Ruling 1. `Any` goes, every inherited ztk name goes, the vocabulary becomes
**Outer / Inner**. `3tk-naming-001.md` is accepted as written, with the
additions the code forces.

**`Outer` is a category, never a type.** No `Outer` is declared. It is what the
prose calls the application's struct, and `3tk-naming-001.md`'s *Important
restriction* is carried into the doc comments: the generic boundary is spelled
Outer/Inner, application prose says *the request*.

| Today | Proposed | Note |
|---|---|---|
| `AnyNode` | **`Inner`** | Ruling 1 |
| `AnyHandle` | **`Handle`** | Still a transparent alias for `Inner*`. D4 stands |
| `Slot` | `Slot` | Unchanged. D5 stands |
| `NodeList` | **`InnerQueue`** | FIFO. Ruling 3 |
| — | **`InnerStack`** | LIFO. New. Ruling 3 |
| `NodeListIterator` | **`InnerQueueIterator`** | Section 5.2 |
| `is_linked(h)` | `is_linked(h)` | Kept, and it changes meaning. Section 3 |
| `reset(h)` | `reset(h)` | Kept |
| `NodeList.contains` | — | **Deleted.** Section 3 |
| `mtk::helper::to_any` | **`to_inner`** | The `any` in a name is an inherited name |
| `mtk::helper::from_any` | **`from_inner`** | |
| `mtk::helper::must_from_any` | **`must_from_inner`** | |
| `mtk::helper::is_mine` | `is_mine` | Unchanged. Not an inherited name |
| `mtk::helper::init`, `OFF`, `TYPE` | unchanged | |
| `from_slot`, `must_from_slot`, `move_from_slot` | unchanged | |
| `mtk::owned::create`, `release` | unchanged | |
| `mtk::node_offset($Type)` | **`inner_offset($Type)`** | Its message names `AnyNode`; it names `Inner` |
| `Mailbox`, `Pool`, `PoolHooks`, `GetMode`, `PoolBucket` | unchanged | |
| `Mailbox._queue` | **`_regular`, `_oob`** | Two fields. Section 4 |
| `Mailbox._oob_anchor` | — | **Deleted.** Section 4 |
| `PoolBucket.free` | `free`, retyped `InnerStack` | Section 5.4 |
| the file `list.c3` | **`queue.c3`, `stack.c3`** | Two containers, two files |
| the file `any.c3` | **`inner.c3`** | |

**`Handle`, not `InnerHandle`.** `3tk-naming-001.md` writes `mtk::Handle` in its
recommendation and `Inner`-prefixed names only for the collections. Agreed: the
module prefix already says whose handle it is, and D4's one-handle ruling is
easier to read with the short name.

**Three names in the toolkit still read `any` and must not survive.** They are
the helper's crossings, and Part 7.5 makes them the most-read signatures in the
port. `to_inner` and `from_inner` also say *which direction* — which `to_any`
never did.

**One collision to check at 3TK-11, not now.** `Inner`, `Handle` and `Slot` are
short and live in `module mtk`. C3 resolves an unqualified name against imported
modules; `Handle` is generic enough that an application importing `mtk` and a
second library could collide. The port cannot prevent it and the application
qualifies as `mtk::Handle`. Noted, not a blocker — `Slot` has the same exposure
today and nothing has hit it.

---

# 3. The double-insert guard — consequence 2

**This is the sharp one, and it has a better answer than losing the check.**

## 3.1 The problem, precisely

Today, `list.c3:58`:

```c3
fn bool is_linked(AnyHandle h) => h != null && (h.prev != null || h.next != null);
```

Part 8.7 MUST already documents its blind spot: an item **alone** on a list has
no neighbours and reports false. D12 accepted that, and Part 8.6's O(n) walk
covers it in checking builds only.

Delete `prev` and the blind spot stops being an edge case. The **last item of
every queue** has `next == null`. In a queue of ten, one item is invisible to
the check. In the pool's stack, the bottom item is. The guard fails exactly
where a double insert is most likely — a worker that gives an item back twice
gives back the one it most recently touched.

The walk does not rescue it. `contains` answers *is it on __this__ list*. The
link test is the only check that sees a **different** list, and Part 8.6 says in
so many words that neither alone is enough.

## 3.2 The four mechanisms, priced

Inner today: `prev`, `next`, `type` — 24 bytes on linux-x64. Proposal 004,
section 1, and it is careful that 24 is an observation, not a requirement.
Dropping `prev` frees one pointer. What that pointer is spent on is the whole of
this decision.

| # | Mechanism | Inner | Insert guard | Catches "different list" | Catches "alone on a list" | Cost |
|---|---|---|---|---|---|---|
| A | **Lose the check** | `next`, `type` — 16 B | walk only, O(n), checking builds only | **no** | yes | A MUST is downgraded to a documented hole. Section 3.4 |
| B | **Self-link the tail** | `next`, `type` — 16 B | `next != null`, O(1) | yes | yes | A sentinel value in every chain. Every traversal, pop and repair tests for it. A leaked self-link is an infinite loop |
| C | **Shared terminator sentinel** | `next`, `type` — 16 B | `next != null`, O(1) | yes | yes | As B, with one static address instead of a per-item one. Same traversal tax, same leak hazard |
| D | **A membership field** | `next`, `type`, `chain` — **24 B** | `chain == null`, O(1), **and** `chain == self` is exact | yes | yes | One store per insert, one per removal — the stores `prev` was already paying |

**D costs nothing that is not already being paid.** The inner stays 24 bytes,
the same three words it is today. `prev` was written on every insert and read on
every removal; `chain` is written on every insert and cleared on every removal.
The arithmetic is a wash and the check is strictly stronger.

## 3.3 The recommendation — mechanism D

**Add `void* chain` to `Inner`. Delete `prev`.**

```
Inner
    Inner* next      the single link. Ruling 5
    typeid type      identity. Part 5, unchanged
    void*  chain     the container this Inner is on, or null
```

- `is_linked(h)` becomes `h.chain != null`. **No blind spot.** An item alone on
  a queue has a chain. An item on no chain has none.
- **Membership becomes exact and O(1).** `h.chain == self` answers *is it on
  this container* — the question `contains` walks the whole list to answer.
- **`contains` is deleted, and with it the O(n) insert.** Part 8.6's double
  check collapses to one check that is stronger than both halves together.
  Inserts are O(1) in **every** build mode, not just fast ones.
- **D12's accepted blind spot is closed.** Part 8.7's "a port whose list marks
  membership properly is strictly better here, and pays a field per item for it"
  is exactly this, and the direction's own ruling 5 is what makes it free.
- `reset(h)` clears `next` and `chain`. Part 8.8 unchanged in wording.

**Part 4.2's test is met and the reason is written down here.** A further
per-item field is added only with a reason, because every item pays. This field
is not further — it replaces one — and the reason is that it is the only thing
standing between ruling 5 and an unguarded double insert.

**`void*` and not a typed pointer**, because `InnerQueue` and `InnerStack` are
different types and the field must hold either. The comparison is by address and
never dereferenced. It is never read as a container.

**The field exists in every build mode.** The *check* compiles out with D6's
tiers; the *store* does not. A field that exists only in safe builds changes
`sizeof(Inner)` between modes, and a toolkit whose item layout depends on the
build mode cannot be linked against. That is not negotiable and 3TK-11 must not
"optimize" it.

**What it does not catch**, stated so no one claims more: a chain corrupted by
code that reaches around the container surface, and two containers at the same
address that are not the same container — which cannot happen while both are
live. The guard is exact for every path through the public surface.

## 3.4 Why not A

A is the honest fallback and it is worth naming what it gives up. Part 8.6 is a
SHOULD, so a port may reduce the double check. But invariant 20 — *an item is in
exactly one place at all times*, Part 9.6 MUST — would then have no runtime
guard at all against the commonest way to break it, in any build mode. The port
would be trading a MUST's enforcement for a field it is not being asked to save.
**Refused.**

## 3.5 Why not B or C

Both work and both are cheaper in bytes. They are refused on the same ground
`3tk-to-fifo-lifo-single-001.md` §16 argues against a general list: **states
that a reader has to hold in their head.**

A sentinel means `next` has three meanings — a real successor, "end of chain",
and "not on a chain" — and every one of the port's traversals, pops and repairs
has to distinguish them. `list.c3` has eleven sites that touch `next` today. A
single missed comparison is an infinite loop or a dereference of the sentinel,
and neither is caught by an assert. D's field has one meaning and a null test.

Eight bytes per item is the price of a mechanism with one meaning. Given the
port already spends 24 and would keep spending 24, it is not a price at all.

---

# 4. The two FIFOs — consequences 1 and 3

Ruling 4. `Mailbox` holds `_regular` and `_oob`, both `InnerQueue`.

## 4.1 What dies

- **`_oob_anchor`**, `mailbox.c3:62`. Deleted. Three sites clear or maintain it —
  `:158`, `:171`, `:327`, `:376` — and all four lines go.
- **`enqueue`'s branch**, `mailbox.c3:143-159`. `send` pushes `_regular`,
  `send_oob` pushes `_oob`. No anchor, no `insert_after`, no `push_front`.
- **`dequeue`'s anchor repair**, `mailbox.c3:171`. `dequeue` becomes: try `_oob`,
  then `_regular`.
- **`insert_after` itself**, since `mailbox.c3:152` was its only caller.
- **The mechanism clause of Part 11.3** — *a port keeps an anchor at the last
  out-of-band item, so the insert stays O(1); an empty anchor means insert at the
  front; the anchor is cleared when the last out-of-band item is taken.* Three
  bullets, deleted. Two queues make the insert O(1) with no anchor at all.

## 4.2 What does not die — invariant 22

Plan 006 says two queues "delete D14's anchor and invariant 22 outright". **The
anchor, yes. Invariant 22, no, and this document recommends against deleting
it.**

Invariant 22 is *out-of-band items are ahead of ordinary ones, FIFO within
each*. That is a promise to a caller about delivery order. It is asserted at
`t_mailbox.c3:139-162`. Two queues do not weaken it — they are a **cleaner
implementation of the same promise**, which is what §5 of
`3tk-to-fifo-lifo-single-001.md` claims for them.

**Delete the mechanism, keep the guarantee.** An invariant table that loses row
22 tells a later reader the ordering is no longer promised, and it is.

**D14 survives too, with its second clause intact:** out-of-band is one priority
level, not a priority queue. Two queues is not two priority levels — it is one
level with a cleaner home. Part 11.4 MAY is unchanged.

## 4.3 The close order — the question plan 006 raised

Part 11.6 MUST: a close gives the remainder to the caller, as a list. With one
queue that was one `append_list`. With two, the order is a decision.

**Recommendation: out-of-band first, then ordinary, FIFO preserved within
each.**

The reason is not taste. It is the **only order that changes nothing.** Today
the single queue already holds out-of-band ahead of ordinary, so
`out.append_list(&self._queue)` at `mailbox.c3:375` hands the caller exactly
that order. Appending `_oob` and then `_regular` reproduces it item for item.

**The rule, stated once for all three drains:**

> Where the mailbox hands items out as a list — `receive_all` and `close` — the
> list is in the order `receive` would have delivered them. Out-of-band first,
> ordinary second, first-in first-out within each.

That covers `receive_all` at `mailbox.c3:317-328` as well, which has the same
question and the same answer. `t_mailbox.c3:225` and `:251` assert batch and
remainder order and **neither test changes**.

The alternative — ordinary first — would be a silent reordering of a
caller-visible list to no purpose. Refused.

## 4.4 What `len` and the leaver's signal become

Two small sites that a rewrite loses silently.

- `Mailbox.len`, `mailbox.c3:390-395`, returns `_oob.len() + _regular.len()`. It
  is one number to a caller and stays one.
- `receive`'s Part 2.6 hand-off, `mailbox.c3:301`: `if (!self._queue.is_empty())
  self._cv.signal();` becomes `if (!self._oob.is_empty() ||
  !self._regular.is_empty())`. **Invariant 5 is the easiest thing in this
  redesign to half-fix**, and a leaver that checks only `_regular` strands a
  queued out-of-band item with nobody woken. Named here so 3TK-11 does not
  rediscover it in a race test.

---

# 5. What Part 8 becomes

Consequence 1. Part 8 is one list with sixteen operations. It becomes two
containers with nine and six.

## 5.1 The sixteen, ruled

| Part 8.2 operation | `InnerQueue` | `InnerStack` | Why |
|---|---|---|---|
| Take from the front | `pop_front` | `pop` | The primitive of both |
| Add at the back | `push_back` | — | FIFO |
| Add at the front | `push_front` | `push` | Queue keeps it for Part 11.8 only. §1.1 |
| Add at the back from a Slot | `push_back_slot` | — | `send`, and the hook's `extra` |
| Add at the front from a Slot | `push_front_slot` | `push_slot` | `pool.c3:451` MUST |
| Is it empty | `is_empty` | `is_empty` | |
| How many | `len` | `len` | O(1), kept count. Part 11.7 |
| Walk it | `iter` | — | §5.2 |
| Move another onto this one | `append_queue` | — | §5.3 |
| Look at the front | — | — | No caller. §1.1 |
| Look at the back | — | — | No caller |
| Take from the back | — | — | No caller |
| Remove a named item | — | — | No caller |
| Insert after | — | — | Only caller was the anchor. §4.1 |
| Insert before | — | — | No caller, ever |
| Is it on this list | — | — | **Replaced by `chain`.** §3.3 |

Sixteen become nine on the queue and six on the stack, and **seven operations
disappear from the port entirely**.

**`InnerQueue` needs `head`, `tail`, `count`. `InnerStack` needs `top`,
`count`.** Both are the containers `3tk-to-fifo-lifo-single-001.md` §8 draws.

## 5.2 The walk

`iter` has one caller outside `t_list.c3`: `t_identity.c3:139`, which walks a
heterogeneous list and dispatches on identity. That is **Part 6.5's
demonstration** and it is the one place the toolkit shows what a type-erased
list is for. It stays, on the queue.

The stack gets none. Nothing walks a free list, and Part 8.4 is a SHOULD.

`NodeListIterator` becomes `InnerQueueIterator`. Its contract — removal during a
walk is not supported — is unchanged and still documented.

## 5.3 Moving a chain onto another

`append_list` has three callers in `src/`: `mailbox.c3:326`, `:375`, and
`pool.c3:479`. All three are drains. It survives as `InnerQueue.append_queue`,
queue onto queue, still O(1) — `InnerQueue` keeps a tail, so the splice is three
stores.

**Part 8.9's pair survives with it**, unchanged: the tier 2 check and the early
return against moving a queue onto itself. `negative/self_move.c3` still
compiles and still aborts. The failure mode it guards — ringing the items into a
cycle and clearing the header — is identical with one link.

**One thing gets more expensive, and it is priced here.** `Pool.close` at
`pool.c3:479` merges every bucket into one list. Today that is O(1) per bucket.
An `InnerStack` has no tail, so the merge becomes a **pop-and-push loop, O(n) in
the items held.** It runs once, at close, on a pool that is going down.

**Recommended: accept the O(n).** The alternatives are worse. Giving
`InnerStack` a tail makes it a queue with two names and reintroduces the state
ruling 3 removed. Splicing without a tail means walking anyway. And the loop has
a property the splice does not: it moves each item through `pop` and `push_back`,
so **`chain` is maintained per item** and the items arrive on the close list
correctly marked. A splice would have to fix up `chain` for every item — which is
the same walk, written less clearly.

## 5.4 The types on the container surfaces

Four public signatures name `NodeList` and all four become `InnerQueue*`:

- `Mailbox.receive_all(InnerQueue* out)` — `mailbox.c3:317`
- `Mailbox.close(InnerQueue* out)` — `mailbox.c3:365`
- `PoolHooks.on_put(usz, Slot*, InnerQueue* extra)` — `pool.c3:62`
- `PoolHooks.on_close(InnerQueue* remaining)` — `pool.c3:73`
- `Pool.put_all(InnerQueue* items)` — `pool.c3:440`

**A queue and not a stack in all five**, including the pool's. What the hook
receives is a batch to walk and release in order, not a reuse pool. `put_all`
needs `push_front_slot` for Part 11.8, which the stack has under another name
but with different order semantics for the caller. The queue is the port's
**transfer** container; the stack is the pool's **storage** container. Keeping
that split is what stops `InnerStack` leaking into the application's surface at
all.

`PoolBucket.free` — `pool.c3:97` — is the only `InnerStack` in the port.

## 5.5 The invariants Part 8 was carrying

| Invariant | Part | What happens |
|---|---|---|
| 13 — heterogeneous, O(1), allocation-free | 8.1 | **Stronger.** Insert becomes O(1) in checking builds too. §3.3 |
| 14 — the list speaks in type-erased handles | 8.3 | Unchanged. Both containers take `Handle` and `Slot*` |
| 15 — the list layer is where the checks live | 8.5 | Unchanged. Two layers now, same rule |
| 16 — the link test is not a membership test | 8.7 | **Retired, and replaced.** With `chain` the link test *is* a membership test. The invariant that replaces it is below |
| 17 — a removed item's links are cleared | 8.8 | Unchanged in force, wider in scope: `reset` clears `next` **and** `chain` |
| 20 — an item is in exactly one place | 9.6 | **Better guarded than today**, in every build mode |
| 22 — out-of-band ahead of ordinary | 11.3 | **Kept.** §4.2 |

**One invariant is proposed as new**, and it is the one the redesign turns on:

> **`Inner.chain` names the container the item is on, or null.** Every insert
> sets it, every removal clears it, and no path leaves it disagreeing with the
> links. `is_linked` reads it. Membership is `chain == container`.

It takes the retired 16's place. The table does not shrink.

---

# 6. What survives untouched

Named so 3TK-11 does not reopen them, and so a reader can see the blast radius
is the core and not the toolkit's promises.

- **D1** — public direct representation, no fight with the language over hiding.
  `3tk-to-fifo-lifo-single-001.md` §15 says smaller containers make hiding
  easier. They do not: M5 is that C3 0.8.3 has **no field privacy at all**, and
  a smaller struct is just as readable as a larger one. Nothing here reopens D1.
- **D3** — allocators taken at creation, kept for life, no release parameter.
- **D5** — the distinct `Slot` and its five primitives.
- **D6** — the three assert tiers. `@check` is unchanged and every guard in this
  document is tier 2 or tier 3 exactly as it is today.
- **D7** — the wait loop, both copies. §4.4 is the one line inside it that moves.
- **D9, D13, D15, D16** — untouched.
- **Section 6 of proposal 004**, all seven implementation invariants. 6.2
  (creation is a transaction) and 6.5 (no bucket reference survives a hook call)
  are the two a rewrite most easily loses, and plan 006's 3TK-11 section already
  names 6.2.
- **Parts 12, 13, 14, 15, 17, 19** of the specification. The hook contract, the
  allocator rules, the transfer model, the concurrency contract, the layering,
  and every outcome set. **No fault is added or removed by this redesign.**
- **Part 17.2's layering.** `mtk::mailbox` and `mtk::pool` use only the public
  surface of the core, which is now five types instead of four. The check
  `run-builds.sh` runs for it is unchanged.

---

# 7. What it costs

## 7.1 Source

Every file changes. `3tk/src/` is 1655 lines.

| File | Change |
|---|---|
| `any.c3` → `inner.c3` | Renames, plus `chain` in `Inner` and its doc. ~30 lines move |
| `list.c3` → `queue.c3` + `stack.c3` | **Rewritten.** 339 lines become perhaps 200 across two files. Seven operations deleted, `contains` deleted, `unlink_no_repair` deleted, `is_linked` rewritten |
| `helper.c3` | Three renames — `to_inner`, `from_inner`, `must_from_inner`. Otherwise untouched |
| `owned.c3` | Renames only |
| `mailbox.c3` | Two fields for one, `enqueue`/`dequeue` rewritten, anchor deleted, `len` and the leaver's signal changed. ~40 lines |
| `pool.c3` | `PoolBucket.free` retyped, `get`/`get_wait`/`take_back_handle` become stack calls, `close` becomes a loop, four signatures retyped. ~30 lines |
| `mtk.c3` | The reading order names the files. Rewritten |

## 7.2 Tests

77 tests today. `run-builds.sh` reports 59 checks over four builds.

| File | Tests | Fate |
|---|---|---|
| `t_list.c3` | 15 | **Rewritten as `t_queue.c3` + `t_stack.c3`.** Seven of the fifteen test operations that will not exist — `insert_in_the_middle`, `remove_from_anywhere`, `the_ends_of_the_list`, `the_link_test_has_a_blind_spot`, `the_walk_has_a_blind_spot_too`, and parts of two more. The blind-spot pair **inverts**: they become tests that the blind spot is gone |
| `t_mailbox.c3` | 13 | Renames. `out_of_band_ordering` at `:139` and the batch/remainder order tests at `:225`, `:251` **pass unchanged**, which is the evidence for §4.3 |
| `t_pool.c3` | 18 | Renames, plus a new test that reuse is LIFO. §1.3 |
| `t_slot.c3` | 9 | Renames only |
| `t_identity.c3` | 8 | Renames. `:139`'s walk survives |
| `t_owned.c3` | 5 | Renames only |
| `t_concurrency.c3` | 5 | Renames only |
| `t_alloc.c3` | 4 | Renames only |

**Roughly 20 of 77 tests are rewritten and the rest are renamed.** The count
will move and 3TK-11 states the new number rather than inheriting this one.

## 7.3 The negatives

Eleven runtime negatives and three compile-time ones. Three are affected.

| Negative | Fate |
|---|---|
| `insert_linked_item.c3` | **Survives, and gets stronger.** It provokes the link test, which now has no blind spot |
| `insert_twice_same_list.c3` | **Rewritten.** It provokes the walk, and the walk is gone. It becomes a `chain == self` provocation — and it now fires in a **fast** build too, because the check is tier 2 rather than tier 3 |
| `self_move.c3` | Renames. `append_queue` keeps Part 8.9's pair |
| `nocompile_two_inners.c3`, `nocompile_no_inner.c3` | Renames. `inner_offset`'s messages name `Inner` |
| The other eight | Renames only |

**One negative gains coverage rather than losing it.** That is a fair summary of
consequence 2 under mechanism D.

## 7.4 Documents

- `3tk-porting-proposal-004.md` — D2, D4, D5, D8, D11, D12, D14 and sections 1,
  5.4, 5.5, 5.8, 5.9, 6.7 all name types that stop existing. **It does not get
  edited.** It is the design of record for what was built, and this document
  plus its ruling is the record for what replaces it. Whether a proposal 005
  folds the two together is the owner's call and is not this stage's to make.
- `3tk-toolkit-notes-001.md`, `3tk-containers-notes-001.md`,
  `3tk-sanitizer-notes-001.md` — finished stage outputs. **Not rewritten**, by
  the standing rule.
- `3tk-status.md`, `3tk-log.md` — edited in place, as always.

---

# 8. Consequence 4 — the specification

**The recommendation: move the specification. Do not declare a 3tk deviation.**
The owner rules.

## 8.1 What would have to move

`../common/matryoshka-specification-002.md`, and **dtk and otk read it.**

| Part | Marking | Change |
|---|---|---|
| 4.2 The inner | MUST | *Linkage — the links of a doubly-linked list. Two fields.* Becomes one link plus a membership field. The "two conceptual parts" framing survives; the parts become **linkage, identity, membership** |
| 8.1 The rule | MUST | *A doubly-linked list* becomes *ordering primitives whose nodes are the inners of Part 4* |
| 8.2 The surface | SHOULD | Sixteen operations become the nine and six of §5.1 |
| 8.6 The double check | SHOULD | **Deleted.** One exact check replaces two partial ones |
| 8.7 The link test and its blind spot | MUST | **Rewritten.** Its own last bullet — *a port whose list marks membership properly is strictly better here* — becomes the rule instead of the alternative |
| 8.9 Moving a list onto itself | SHOULD | Unchanged in force, narrowed to the queue |
| 11.3 The mailbox | MUST | The five ordering bullets lose the two anchor bullets. The three ordering guarantees stay |
| 11.7 The pool | MUST | *One free list per identity* becomes *one stack per identity, most recently returned first*. **This is the only place the redesign adds a promise** — §1.3 — and it may be left as hook policy instead |
| Part 18 | — | Row 16 retired and replaced, row 22 kept, row 13 strengthened. §5.5 |

Parts 1, 2, 3, 5, 6, 7, 9, 10, 12 to 17 and 19 to 22 are untouched.

## 8.2 Why moving is the recommendation

- **The specification's own claim is that a port is written from it alone.**
  A 3tk deviation makes the C3 port the one that is not. The next port written
  from the specification would reproduce `prev`, the general list, and the
  anchor — and then need this same stage.
- **Two of the twenty-seven items in the last review were specification
  defects**, and `3tk-status.md` records what fixing them locally would have
  cost: the same trap set for D and Odin. That reasoning applies here with more
  force, because this is a larger change.
- **Nothing here is C3-specific.** No ruling in this document turns on a C3
  capability. Ruling 5 is an argument about the model, and mechanism D is an
  argument about states, not about `typeid` or `$foreach`. A change that is not
  about the host language belongs in the language-neutral document.
- **The cost lands where nothing is built.** dtk has run no stage —
  `../d/dtk-status.md`. otk needs refactoring anyway. ztk is the only port with
  code matching specification 002, and ztk is a **realization**, not the source
  of truth; the specification already records places where a port is *better*
  than ztk — Part 11.11 says so in those words.

## 8.3 What the owner is actually being asked

Three questions, and they are separable.

1. **Do rulings 1 to 5 become specification 003, or a 3tk deviation section?**
   Recommendation: specification 003.
2. **Does mechanism D — the membership field — go into the specification as the
   rule, or stay a 3tk decision?** Recommendation: into Part 8.7 as the rule,
   because Part 8.7 already names it as the better design and only the field
   cost stopped it. Ruling 5 removed the cost.
3. **Does Part 11.7 promise most-recently-returned-first, or stay silent?**
   Recommendation: **stay silent.** Part 11.10 promises no order and it is a
   MUST. Let 3tk implement a stack because a stack is the smaller container, and
   let the order stay hook policy. Promising LIFO in the specification binds
   every future port to a property no caller was told to rely on.

**None of the three is answered by this document.** `../common/` is not edited by
this stage, and the recommendation carries no authority.

---

# 9. The decisions, as a register

Numbered R, for redesign, so nothing collides with proposal 004's D1 to D16.

| # | Decision | Status |
|---|---|---|
| R1 | `Any` goes. `Inner`, `Handle`, `Slot`. `to_inner` / `from_inner` / `must_from_inner`. `inner_offset` | Direction, ruling 1 |
| R2 | No general list. `InnerQueue` and `InnerStack`, nine operations and six | Direction, rulings 2 and 3 |
| R3 | Seven of Part 8.2's operations are deleted outright | Follows from R2. §5.1 |
| R4 | `InnerQueue` keeps a front insert, for Part 11.8 MUST alone | **Proposed.** §1.1 |
| R5 | One link. `prev` is deleted | Direction, ruling 5 |
| R6 | **`Inner` gains `void* chain`.** Inner stays three words. `is_linked` becomes exact. `contains` and the O(n) insert walk are deleted | **Proposed.** §3.3 |
| R7 | The mailbox holds `_regular` and `_oob`. The anchor is deleted | Direction, ruling 4 |
| R8 | Every mailbox drain hands items out in receive order: out-of-band first, ordinary second, FIFO within each. `receive_all` and `close` both | **Proposed.** §4.3 |
| R9 | Invariant 22 is kept. Only the anchor mechanism is deleted | **Proposed.** §4.2 |
| R10 | Invariant 16 is retired and replaced by the `chain` invariant | **Proposed.** §5.5 |
| R11 | Pool reuse becomes LIFO, and this is recorded as a behaviour change | Direction, ruling 3, with §1.3 attached |
| R12 | `Pool.close` merges buckets by pop-and-push, O(n), once | **Proposed.** §5.3 |
| R13 | The five list-typed public signatures take `InnerQueue*`. `InnerStack` is internal to the pool | **Proposed.** §5.4 |
| R14 | The specification moves to 003. Part 11.7 stays silent on order | **Recommended, not decided.** §8 |

**R4, R6, R8, R9, R10, R12 and R13 are this stage's own**, and R6 is the one
that matters. The rest are the direction, worked out.

---

# 10. Verification of this stage

1. **No code was written.** `3tk/src/`, `3tk/test/` and `3tk/negative/` were
   read and not touched.
2. **`3tk/run-builds.sh` — four builds green, 59 checks, 0 failures.** Run at the
   end of the stage, and it is the same result as 3TK-9's because nothing moved.
3. **`../common/` was not edited.** Section 8 recommends; it does not act.
4. Every claim about the current code names a file and a line.
5. Every specification Part the direction touches is named with its marking, in
   §8.1.

---

# 11. What the owner is asked to rule

In the order they matter.

1. **R6 — the `chain` field.** This is the one that changes the shape of the
   inner and it is the answer to consequence 2. Accept, or name mechanism A, B
   or C instead. **3TK-11 cannot start without this.**
2. **R8 and R9 — the close order, and invariant 22.** Accept, or say which
   order.
3. **R14 — the specification.** Move it to 003, or declare a 3tk deviation. The
   answer decides whether dtk starts from a document that describes the port
   that exists.
4. **R11 — LIFO as a recorded behaviour change**, and whether Part 11.7 says so.
5. **R4, R12, R13** — accept as written, or ask.

After the ruling:

```
Run 3TK-11 from design/secondary/lang/c3/3tk-status.md
```

*Advice on clear: clear before 3TK-11. This document is the input; the argument
that produced it is not.*
