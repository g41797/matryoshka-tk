# What the C3 port decided, and why (002)

Stage 3TK-22, 2026-08-25. **Description and reasoning. Not recommendations.**

Version 002 of the document stage 3TK-20 cut as
[`backup/3tk-port-findings-001.md`](backup/3tk-port-findings-001.md).

## What this is

The C3 port of Matryoshka — **3tk** — redesigned the core before it was
written, and the reasons are spread across seven documents in this folder and a
dozen doc comments in `3tk/src/`. This file gathers what another port would
find interesting, in one place, so nobody has to read the folder to find out
what this one did.

**It decides nothing for anyone.** Every ruling here was made by the owner for
3tk, is cited to where it was made, and is not reopened. Where this file names
what ztk does, that is description with a `file:line` beside it and no
conclusion drawn from the difference. **The owner rules; this document
informs.**

## Who it is for

- **dtk**, the D port, which has run no stage and starts from
  [`../common/matryoshka-specification-004.md`](../common/matryoshka-specification-004.md)
  alone — [`../d/dtk-status.md`](../d/dtk-status.md). It has no way to learn
  from the specification that a port deleted a field, deleted a walk and got a
  MUST weakened, because the specification records the outcome and not the
  argument.
- **ztk**, the Zig port and the published reference implementation, which
  predates all of this.

**The two ports are not in the same position and this document does not treat
them as if they were.** 3tk was free to redesign: it had no users and no
published surface. ztk has both, and several things below change promises it
makes in writing. Weighing that is what ztk's own plan is for, and cutting that
plan is the owner's.

## How to read it

**It is written for a reader who has read only 004.** Everything else is
defined here or cited to where it is defined. The vocabulary is the
specification's: *inner*, *outer*, *handle*, *Slot*, *identity*, *crossing*,
*helper*. Where 3tk's own name differs it is given once.

**The order is structural and means nothing else.** The item, then the
containers, then the mailbox, then the pool, then the checking, then the
helper. **No section is ranked by urgency, severity or cost**, and the late
close and the mailbox anchor appear as peers, because ranking them would be a
judgment about somebody else's schedule.

**The citations.** `R1` to `R15` are the rulings of
[3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md), §9. `D1`
to `D16` are the design decisions of
[3tk-porting-proposal-004.md](3tk-porting-proposal-004.md), §D. `V1` to `V19`
and `P1` to `P6` are the findings of
[3tk-deviations-001.md](3tk-deviations-001.md). Parts and invariants are 004's.

---

# 1. The item carries one link, and the last one points at itself

## What 3tk does

`Inner` is one field, and that field is a built-in pair — `inner.c3:75-78`:

```c3
struct Inner
{
    any link;
}
```

`any` is C3's type-erased pair of a `void*` and a `typeid`. **`link.ptr` is the
chain link and `link.type` is the identity**, which is Part 4.2's *linkage* and
*identity* exactly. The port carried the same two meanings as two named fields —
`Inner* link` and `typeid type` — until 2026-08-25, and §1a below describes the
move and what it cost.

**16 bytes on linux-x64, down from 24.** The observation is recorded in R6b's
own words and no code depends on it. The eight bytes are R6b's, won when it
deleted `prev`; the move into `any` was measured at 16 bytes before and 16
after.

**The last item of every chain points at itself.** A queue of one is
self-linked; the tail of a queue of ten points at itself; the bottom of the
pool's stack points at itself. So the link is **never null on a chain and always
null off one**, and the membership question becomes one load — `inner.c3:261`:

```c3
fn bool is_linked(Handle h) @inline => h != null && h.points_to() != null;
```

Every walk ends at `n.points_to() == n` rather than at null — the iterator at
`queue.c3:123` and `InnerStack.pop` at `stack.c3:124` spell that test.
`InnerQueue.pop_front` recognises the sole item by `head == tail` instead
(`queue.c3:187-194`), and `InnerStack.push` self-links the new bottom
(`stack.c3:108`). Those are the four sites the invariant touches.

## Why

**R6b, ruled 2026-08-23.** The chain of reasoning is §3 of the redesign
proposal and it starts from a problem rather than from an optimization.

The port began with two links, `prev` and `next`, and the link test
`h.prev != null || h.next != null`. 002's Part 8.7 documented that test's blind
spot as inherent: **an item alone on a list has no neighbours and reports
false.** D12 accepted the hole; 002's Part 8.6 covered it with an O(n) walk in
checking builds.

**Deleting `prev` naively would have made the edge case the common case.** §3.1:

> The **last item of every queue** would have `next == null`. In a queue of ten,
> one item is invisible. In the pool's stack, the bottom item is. The guard
> would fail exactly where a double insert is most likely — a worker giving back
> an item it most recently touched.

The walk does not rescue it, and §3.1 says why in one line: `contains` answers
*is it on this container*, and **only the link test can see a different one.**

So the self-link was ruled, and §3.2 records what it bought:

> - `is_linked(h) => h != null && h.next != null`, and it is **exact.**
> - **Part 8.7's blind spot closes, with no field.**
> - **`contains` and the O(n) walk on every insert are deleted.**
> - **Inserts are O(1) in every build mode**, not only fast ones.
> - **The guard becomes tier 2** rather than tier 3, so it aborts in a fast
>   build.

**A membership field was proposed and refused — R6.** 001 of the proposal
wanted a third field, `void* chain`, at the same 24 bytes `prev` cost, giving
`chain == container` in O(1). §3.3 refused it:

> **It bought exactly one query beyond what the self-link gives: *is it on
> __this__ container*. `remove` was that query's only caller, and `remove` is
> deleted.**

§3.4 tables the five mechanisms considered — lose the check, self-link, shared
terminator, membership field, circular through a header sentinel — with the
reason each was refused. The shared terminator lost on a public name: it needs
`mtk::END_OF_CHAIN` visible to every module that can see the containers, and a
mistaken read lands on a dummy node, where the self-link's mistaken read lands
on the item itself, which is valid memory.

**What it costs, stated in the ruling rather than discovered later.** §3.4:

> `next` has two meanings instead of one, and a walk that forgets `n.next == n`
> loops forever rather than aborting.

That price is why the field was later renamed: **3TK-18 made it `Inner.link`**,
after the owner rejected three shapes of a type-erased alternative —
[3tk-any-options-001.md](backup/3tk-any-options-001.md). `next` asserts *the following
item*, which the field is not when it points at itself. **The name survived the
change of 2026-08-25 and the rejection did not**: the owner ruled one of those
shapes in a day later, and §1a is what that produced.

**What the exactness does not cover, stated so nobody claims more** — a chain
corrupted by code that reached around the container surface. It is exact for
every path through the public surface.

## Where the specification stands

**V4 and V5, in 003.** Part 8.6 — *every insert checks twice, one of them an
O(n) walk* — is **deleted and tombstoned in place**. Part 8.7 no longer
documents the blind spot: **it forbids it.** The link test MUST be exact, and
004's Part 8.7 names the three prices a port can pay for exactness — a
terminator, a field, or the O(n) walk. **A port that does not make the test
exact carries the walk.**

Invariant row 16 was retired in place and replaced by row 16b, the exact link
test — V12, R10. **Rows do not renumber**, assumption A1 of 003.

## What ztk does

`PolyNode` is `std.DoublyLinkedList.Node` plus the tag — `polynode.zig:53-56` —
so two links and an identity. The link test is `polynode.zig:84`:

```zig
pub inline fn is_linked(node: *PolyNode) bool {
    return node.node.prev != null or node.node.next != null;
}
```

Its doc comment, `polynode.zig:74-83`, names the blind spot in the port's own
words — *the only member of a list has no neighbours, so this returns false for
it*, and *every `!is_linked` assert in the toolkit inherits that blind spot*.

`ItemList._checkInsert`, `polynode.zig:415-420`, pairs the inexact test with an
O(n) same-list walk `_holds`, `polynode.zig:403-408`, and its comment states the
pairing exactly as 002's Part 8.6 did: *Neither is complete. Together they cover
more.* Both run under `std.debug.runtime_safety`.

---

# 1a. The identity and the chain link are stored as one built-in pair

## What 3tk does

The inner's two parts are not two fields. They are one `any` — C3's built-in
pair of a `void*` and a `typeid` — and the port reads them by name: `link.ptr`
is the chain link, `link.type` is the identity. **Nothing about the two meanings
moved.** R6b's self-link is the same invariant, Part 5's stored identity is the
same identity, and the public surface — `Handle`, `Slot`, `InnerQueue`,
`InnerStack`, `inner_offset`, the faults, `Inner.to`, `Inner.as` — is unchanged.
**16 bytes before and 16 after, measured.**

**The halves are read-only, and that is what the shape costs.** C3's stdlib
never assigns one half of an `any`; it rebuilds the whole value with `any_make`.
So every link write is a rebuild that has to carry the identity through by hand,
and a site that hands over the wrong identity compiles, runs and passes the
tests while silently destroying an item's type. The identity is written once at
initialization and read at every crossing, so the damage would surface later and
elsewhere, as a wrong-type refusal on an item that was never wrong. **The
two-field shape did not have that hazard**: there, a link write touched the link
and could not reach the identity.

**Two methods on `Inner` are the answer to it** — `inner.c3:123-124` and
`inner.c3:133`:

```c3
fn void Inner.repoint_to(&self, Handle to) @inline
    => self.link = any_make(to, self.link.type);

fn Handle Inner.points_to(&self) @inline => (Handle)self.link.ptr;
```

`repoint_to` keeps the identity and swaps the pointer, which is the fourth
corner of a table the stdlib leaves open: `any_make` replaces both halves,
`any.retype_to` keeps the pointer and swaps the type, `any.as_inner` keeps the
pointer and derives the type. **Nine link writes exist in the port and eight go
through `repoint_to`**; the ninth is `helper::init` at `helper.c3:100-104`, the
one place the identity is supposed to change. `points_to` is the reader, and it
lets the walk sites state the design's own sentence — *the last item of a chain
points at itself* — as `n.points_to() == n`.

**Two things came out differently from what was intended, and the language
decided both.**

- **The methods are on `Inner`, not on `any`.** A `macro any.repoint_to(...)`
  is more faithful to the stdlib's own family, and it would add a method to a
  builtin type visible to every module that imports `mtk`.
- **Neither method is private.** C3 ignores `@private` on a method declaration
  and warns that it does, measured 2026-08-25. So they sit on the public surface
  beside `Inner.to` and `Inner.as`. What holds a container to the
  `InnerQueue`/`InnerStack` surface is Part 17.2's layering rule and
  `run-builds.sh`'s grep, not visibility — and that grep was widened for this
  shape, because a container maintaining chains by hand now writes
  `h.repoint_to(x)` or `any_make` and never assigns the field.

**Part 5.5's uninitialized inner still refuses to be claimed.** A zeroed `Inner`
is a zeroed `any`, whose typeid matches no type — not even `void` — and is
falsy, which is `any.as_inner`'s own contract `@require (bool)self.type`.
`helper::is_mine` reads that half directly and refuses an item whose `init` was
never called, exactly as it did with a bare `typeid` field.

## Why

**Ruled by the owner on 2026-08-25**, as a reversal: the same owner had rejected
`any` within `Inner` on 2026-08-24 in all three shapes then offered, and the
plan that ordered the change records that it is a reversal. The reason given for
the shape is that **the language ships the pair the port was otherwise building
by hand** — a `void*` and a `typeid`, side by side, in every item in the
program — and that R6b had already made the pointer half type-agnostic when it
replaced `Inner* next` with a link whose only job is to be followed or to
compare equal to its owner.

The bound the ruling put on it: **internals only.** No public surface change, no
behaviour change, no edit to `../common/`, and no new fault. The identity keeps
Part 5's meaning and the link keeps R6b's, or the change is not this change.

**The size is not the reason and the ruling does not claim it.** 16 bytes before
and 16 after; the eight bytes R6b won stayed won.

## Where the specification stands

**Nothing moved.** Part 4.2 asks an inner for exactly two parts, *Linkage* and
*Identity*, and does not say how many fields carry them; 004's *3tk* realization
line reads *one link field plus the identity*, which is still literally true,
nested rather than adjacent. Part 5 is untouched, Part 5.5 is untouched, Part
8.7's exactness requirement is untouched, and no invariant row changed. This is
why the change needed no edit to `../common/`.

## What ztk does

`PolyNode` carries the identity as its own field — `tag: *const anyopaque`,
`polynode.zig:55` — beside the `std.DoublyLinkedList.Node`, so the identity and
the links are separate storage and a link write cannot reach the identity. Zig
has no `any`, and the closest equivalent, a tagged union, is not what either
port wanted here. The tag is written at initialization inside the generated
helper — `polynode.zig:194` and `polynode.zig:320` — and compared by pointer
equality in `isIt`, `polynode.zig:124-126` and `polynode.zig:250-252`, against a
`*const anyopaque` taken from a per-type static. **The identity is a pointer to
a comptime-generated cell, where 3tk's is the language's own `typeid`.**

---

# 2. Nine of Part 8.2's sixteen container operations left the port

## What 3tk does

There is **no general list type.** There are two narrow containers — R2:

- **`InnerQueue`**, seven operations: `pop_front`, `push_back`,
  `push_back_slot`, `is_empty`, `len`, `iter`, `append_queue`. It keeps `head`,
  `tail`, `count`.
- **`InnerStack`**, five: `pop`, `push`, `is_empty`, `len`, and creation. It
  keeps `top`, `count`.

**Deleted: `insert_after`, `insert_before`, `remove`, `pop_back`, `back`,
`front`, `push_front`, `push_front_slot`, `contains`** — R3, and `InnerStack`
also lost `push_slot` later, 3TK-13, when the measurement found it had no caller
that could ever exist.

## Why

**§1.1 of the redesign proposal is a call-site audit, and it was run before
anything was deleted**, on the instruction of an earlier note that said in so
many words: *do not remove `prev` before the required-operation audit proves
nothing needs it.* The table lists every call site of the eleven operations that
are not `push_back`, `pop_front`, `is_empty`, `len`. Nine had **no caller in
`src/` at all** or had exactly one caller that the redesign was itself deleting.

The audit's verdict, §1.1:

> **The audit passes.** `prev` has exactly one job in `3tk/src/` —
> `unlink_no_repair` at `list.c3:251-256`, which serves `remove` and `pop_back`,
> and both are dead.

**`contains` is the one deleted for a reason other than disuse.** It had three
callers — the tier 3 insert guards — and §3 removed its reason to exist rather
than its callers.

**The principle the audit ran under**, ruling 2, quoted again in §6 when it was
applied a second time:

> *add an operation when a real Matryoshka behaviour requires it, not because
> the source library had one.*

## Where the specification stands

**V2 and V3, in 003.** Part 8.1 no longer says *a doubly-linked list*, singular;
it says *ordering primitives*, as many as Part 11 needs, and shows both
realizations — one general list, or two narrow ones. Part 8.2's sixteen
operations are split into **required**, **required at the public surface**, and
**provided if useful**: twelve of the sixteen are optional. **The Slot-shaped
insert was promoted into the required-at-the-surface group**, with Part 12.5 as
the reason — see §6 below.

## What ztk does

One `ItemList`, `polynode.zig:349`, wrapping `std.DoublyLinkedList`, used by
both the mailbox and the pool.

---

# 3. The mailbox has two queues and no anchor

## What 3tk does

`Mailbox` holds `InnerQueue _oob` and `InnerQueue _regular` — `mailbox.c3:72-73`.
`send` pushes the back of `_regular`, `send_oob` pushes the back of `_oob`
(`mailbox.c3:173`), and every take tries `_oob` first (`mailbox.c3:186-187`).
Where the mailbox gives items back as a list — `close`, `receive_all` — it
appends `_oob` then `_regular`: `mailbox.c3:364-365`, `:419-420`.

## Why

**R7, and it was not adopted on taste. §1.2 measured the behaviour first.**

The port's single-queue mailbox kept an out-of-band anchor pointing at the last
out-of-band item, inserted after it, and cleared it when the anchor itself was
taken. §1.2 read those four sites and wrote the semantics down:

> Every out-of-band item is ahead of every ordinary item, and the two classes
> are first-in first-out within themselves. **That is Meaning A.**

Then it proved the replacement equal rather than similar:

> **Two queues reproduce Meaning A exactly.** `_oob.pop_front()` first, then
> `_regular.pop_front()`, gives 1, 3, 0, 2, 4 on the same input. The test does
> not change.

What it deleted: the anchor field and the four lines that maintained it, and
`enqueue`'s branch — so **no send and no receive carries anchor bookkeeping any
more**, and the container's `insert_after` and `push_front` lost their only
caller.

**R9 is the half that is easy to get wrong, and it was ruled explicitly.** An
earlier plan said two queues delete the anchor *and* invariant 22. §4.2:

> **Delete the mechanism. Keep the guarantee.** An invariant table that loses
> row 22 tells a later reader the ordering is no longer promised, and it is.

**R8** then fixed the give-back order for `close` and `receive_all` both —
out-of-band first, ordinary second — on the ground that it changes nothing:
the single queue already handed the caller that order. §4.3 states the rule in
one sentence, and both doc comments carry it:

> Where the mailbox gives items back as a list, the list is in the order
> `receive` would have taken them out.

**§4.4 names the two lines a rewrite loses quietly**, and they are worth
repeating because neither is a container concern: `Mailbox.len` must add both
queues, and the Part 2.6 hand-off in `receive` must test **both** queues before
signalling. *Invariant 5 is the easiest thing in this redesign to half-fix* —
a leaver that checks only `_regular` leaves a queued out-of-band item with
nobody woken. The code carries the warning at `mailbox.c3:324` and the test at
`mailbox.c3:328` is `has_queued()`, which reads both.

## Where the specification stands

**V7, in 003.** Part 11.3's three ordering guarantees are the MUST. **The anchor
is named as ztk's mechanism and two queues as 3tk's**, and 11.3 shows both.
Invariant 22 is unchanged. D14's second clause survives untouched: out-of-band
is one priority level, not a priority queue, and Part 11.4 MAY is unchanged.

## What ztk does

One `list`, plus `oob_count` and `oob_last` — `mailbox.zig:46-50`. `send_oob`
inserts after `oob_last` or prepends when there is none
(`mailbox.zig:188-194`), and the two receive paths decrement `oob_count` and
clear `oob_last` when it reaches zero — `mailbox.zig:273-275` and `:309-311`.
The doc comment at `mailbox.zig:167-172` writes out the same ordering by
example.

---

# 4. What a pool does with items a hook was holding when the pool closed

## What 3tk does

`Pool.put` takes the item from the caller's Slot under the mutex, **releases the
mutex across the hook** — which Part 12.3 requires — and re-reads the closed
flag when it relocks. If the pool closed in that window, everything the call is
still holding is handed to the **close** hook — `pool.c3:525-535`:

```c3
    if (self._closed)
    {
        InnerQueue stragglers;
        if (mine.is_full()) stragglers.push_back(mine.take());
        stragglers.append_queue(&extra);

        self._mu.unlock();                   // Part 12.3, as for every hook call
        if (!stragglers.is_empty()) self._hooks.on_close(&stragglers);
        return;
    }
```

**One rule, and it is the pool's own: what the pool holds when it discovers it
is closed goes to `on_close`** — `pool.c3:505-507`.

## Why

**P1 of the deviation audit, found by measuring rather than by reading.** The
shape predates the redesign and belongs to neither an R nor a D: the audit says
it **drifted**. Without the re-read, `Pool.close` can run to completion inside
the hook window — set the flags, drain every bucket, call `on_close` — and the
put then pushes into a bucket of a closed and already-drained pool. The item is
**with nobody**: the caller's Slot was emptied, so Part 9.4 truthfully tells the
caller the pool has it, and the close hook has already run.

The owner ruled the mechanism and then ruled the destination the mechanism left
open — **the stragglers go to `on_close`, and a second call to the close hook is
acceptable.** The alternative considered and refused was restoring the caller's
Slot, which **cannot carry `extra`** — the hook's extra container holds items
the caller never had.

**The test is what makes the finding a finding.**
`t_concurrency.c3:a_close_during_the_put_hook_loses_nothing` holds the window
open deterministically and **fails on invariant 34 without the fix.**

## Where the specification stands

**This is the one place where a port's defect turned out to be a rule the
specification had never written.** V11:

> **New MUST.** After a hook returns the pool re-reads the closed flag, and what
> a closed pool's put is holding goes to the close hook. Invariant 35.

And the consequence, which 004's change log names twice so that nobody finds it
by accident:

> The close hook is *called once* → **Called once by close, and once more per
> straggling put.** A hook must not destroy its own state on the first call.
> **The only MUST 003 weakens**, and V11 is why.

**The obligation this puts on a hook is small and it is not optional**: the
close hook writes the same loop either way — process or release every item — and
must not free its own context on the first call. `pool.c3:98-104` carries it.

## What ztk does

`Pool.put`, `pool.zig:329`, releases the mutex across `on_put`
(`pool.zig:350-352`) and relocks. The post-hook work is inside
`if (!self.*.closed.load(.monotonic))` at `pool.zig:354`, **with no else
branch** — `pool.zig:354-370`. `Pool.close`'s doc comment at `pool.zig:426-427`
reads *Safe to call more than once. Later calls collect nothing, and `on_close`
runs once.*

---

# 5. The pool hands back the item it was given most recently

## What 3tk does

One free **stack** per identity — `pool.c3:123`, R11. The item just put is on
top, and the next `get` for that identity hands it straight out.

**Part 11.7 promises no order and Part 11.10 says so**, and the doc comment
turns that into the reason the property is useful: *what makes the property
useful is that no caller is entitled to it* — `pool.c3:132-133`.

## Why

The port's code was first-in first-out and R11 reversed it. §1.3 records the
owner's reason, 2026-08-23, and records what the reason is **not**:

> It is **not** cache locality and **not** performance. It is defect surfacing:
>
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

§1.3 compares it to not quarantining freed memory, and adds the instruction that
put the argument in the source rather than in a document:

> **This belongs in the doc comment on `PoolBucket`'s stack**, because a later
> reader who takes the stack for an arbitrary choice will change it back to a
> queue.

**R12** is the other half of the pool's ordering story: `Pool.close` empties
every bucket into one `InnerQueue`, O(n) once, **and promises no order** —
`pool.c3:107`, the `on_close` parameter.

## Where the specification stands

**Unchanged, deliberately.** 004's change log, *what did not change*:

> **Part 11.7 still promises nothing about the pool's order**, and Part 11.10
> still says so. 003 names the container kind and stops. The C3 port's
> defect-surfacing argument for a stack works only while no caller is entitled
> to the order.

**V8** did change what a pool's give-back container is *called*: not *one free
list per identity* but *one give-back container per identity, kind free*.

## What ztk does

**Also last-in first-out, and this document read it rather than assuming it.**
`_add_returned_item` calls `list.prepend(item)` — `pool.zig:561` — and all three
get modes take the head with `popFirst`: `pool.zig:576`, `:621`, and the wait
loop at `pool.zig:276`. No doc comment in `pool.zig` states an order or a reason
for one.

`Pool.close`, `pool.zig:428-452`, concatenates every per-tag list into one
`ItemList`, clears the maps, broadcasts and calls `on_close` outside the lock —
the shape R12 describes, reached without R12.

---

# 6. `put_all` was dropped, and the Slot-shaped insert was kept

## What 3tk does

**There is no `Pool.put_all`** — R15. A caller returning a batch writes the
loop, and `Pool.put`'s doc comment shows it.

**`InnerQueue.push_back_slot` exists and has no caller inside `3tk/src/`.**

## Why

The two decisions come from the same audit and land in opposite directions,
which is the interesting part.

**`put_all` — R15, §6.** It was `Pool.put` in a loop: no lock kept across
iterations, the hook still running once per item, no batching and no atomicity.
It was inherited rather than designed — `pool.zig:394`. §6:

> **It does not spare the caller the difficult case; it gives the difficult case
> back in a different shape.** The easy part is the loop. The hard part is a
> pool closing mid-batch — and after `put_all` returns, the caller still keeps a
> partly-emptied queue and still has to decide what happens to the rest.

What it cost while it existed: a container operation nothing else needed
(`push_front_slot`), **a MUST clause in Part 11.8** — *stops at the first
refusal, puts that item back at the front, the caller checks the list after the
call* — and the restored-order warning with it.

**The counter is recorded in the ruling, not omitted from it:** an application
returning a batch from `Mailbox.close` to a pool is a common shape, and it now
writes the loop itself, with a chance of getting the refusal case wrong and
losing items quietly.

**`push_back_slot` — the opposite verdict on the same kind of evidence.** The
measurement, 3TK-13's §2 and P6, found no caller in `3tk/src/`: `Mailbox.send_at`
takes the handle out of the Slot itself and calls `push_back`. But the **put
hook** — application code — fills its `extra` container from a Slot it has just
created, and that is Part 12.5's composite mechanism written the way Part 9.3
says an acquisition is written. **A container that spoke only in handles would
make a hook write `extra.push_back(part.take())` and lose the Slot's
compile-time guarantee at the one surface the specification hands to application
code.** So the queue kept it, and `InnerStack.push_slot` — unreachable, because
R13 keeps `InnerStack` off every public signature — was deleted.

## Where the specification stands

**V8, V9, V14 delete *put a list* from Parts 11.7, 11.8 and 19.2**, with the
mid-batch failure mode named as the reason it had no clean answer. **V3 promotes
the Slot-shaped insert** into the required-at-the-public-surface group, and
**V10** renames what the hook returns: not an extra *list* but an extra
**container**, a Part 8 primitive the port names — *the one place a primitive
crosses into application code*.

## What ztk does

`Pool.put_all`, `pool.zig:394-417`: validates every tag under one lock, then
loops on `put`, and on a mid-batch close prepends the refused item back onto the
caller's list and stops. Its doc comment, `pool.zig:376-392`, carries the
restored-order warning — *The restored order after a mid-batch close may differ
from the original order* — and *So check the list after the call.*

---

# 7. Three checking tiers, because one language's `assert` is an assumption

## What 3tk does

**D6. Three tiers, and a plain `assert` never guards a contract violation.**

| Tier | Spelling | Where | In a fast build |
|---|---|---|---|
| 1 | `always_assert` | Part 11.12 only | Aborts, every build mode |
| 2 | `mtk::@check` | every other contract violation | **Compiled out entirely** |
| 3 | `$if env::COMPILER_SAFE_MODE:` block | was Part 8.6's walk | Not compiled at all |

Tier 2 is four lines — `inner.c3:216-221`:

```c3
macro @check(#cond, $msg)
{
    $if env::COMPILER_SAFE_MODE:
        always_assert(#cond, $msg);
    $endif
}
```

## Why

**Q11 of the capability study found the trap by probing rather than by reading
the manual.** D6:

> at `--safe=no` with optimization, a plain C3 `assert` is not a removed check,
> it is an *assumption the optimizer may act on*. A violated contract then
> produces undefined behaviour rather than a missed diagnostic. The probe
> segfaulted having printed nothing.

**The transferable part is the distinction, not the macro:** *a removed check*
and *an assumption* are different things, and a language that spells them the
same way will silently give a port the second when it wanted the first. D6's
summary of what tier 2 restores:

> In a safe build it is `always_assert`, which aborts and names the message. In
> `--safe=no` it expands to nothing — the condition is not evaluated, and
> nothing is handed to the optimizer as a promise. That is ztk's model,
> restored, on a language whose `assert` does not provide it.

**The rule that follows binds every call site**, and D6 states it because the
mechanism can reintroduce the class of bug it exists to prevent: *an expression
passed to `mtk::@check` must have no required side effect.* A check that drains
a container drains it in a safe build only, and the program then behaves
differently in the two build families.

**Two corrections came from the code and are recorded as such:** the macro is
**not** private, because C3's `@private` does not reach a submodule and because
an application writing its own Slot-shaped call is entitled to the same check;
and the message is a **compile-time** string, because `always_assert` takes one.

**After R6b the port has almost no tier 3 left.** The insert walk was tier 3's
only container site and the exact link test deleted it; the last reader of the
tier 3 flag is the pool's duplicate-identity scan at creation — the flag is
`inner.c3:230` and its one reader is `pool.c3:235`.

## Where the specification stands

**Part 15.5 was already right and did not move.** V16 sharpened Q11 of Part 21:
it keeps its force, loses a pointer to the deleted Part 8.6, and **names the
O(n) walk as the case it is sharp for**.

## What ztk does

Contracts are guarded with `std.debug.assert` — for example `pool.zig:557` in
`_add_returned_item`, `pool.zig:345` for the tag check in `put`, and
`polynode.zig:416-419` inside `_checkInsert`, which additionally wraps them in
`if (std.debug.runtime_safety)`. In Zig's `ReleaseFast` and `ReleaseSmall`,
`std.debug.assert` is `unreachable`.

---

# 8. The per-type helper does not have to be an object

## What 3tk does

**No per-type object and no instantiation, for any type, ever.** The members of
Part 7.2 are macros over a type parameter, generated at each call site from the
type named there — `helper.c3:76-232`. A new outer type costs nothing before it
can be used.

```c3
macro bool is_mine(Handle h, $Type) => h != null && h.link.type == $Type::typeid;
```

## Why

It is what the language makes natural — H0 — and the port did it before anyone
noticed it conflicted with anything. **The interesting part is not the
mechanism; it is what the conflict turned out to be.**

The port's own doc comment recorded the deviation honestly: Part 7.1 asked for a
helper **object bound to one type**, this port had none, and the file said *this
is a SPECIFICATION defect, not a port defect* and told the next reader **not to
"fix" this file to match it.** That guard was filed as E6, then as **V19**, and
3TK-17 cut 004 to settle it.

**The one thing that lost against the per-type instantiation is named rather
than buried** — `helper.c3:47-49`: a type that is declared but never crossed with
is never validated, because there is no instantiation to force Part 7.4's check.

## Where the specification stands

**V19, and it is the whole of specification 004.** 002 and 003 said *for each
outer type there is a helper bound to that one type*. 004 says the members of
Part 7.2 exist, specialized to that type, generated rather than hand-written,
and:

> **How a port spells the generation is the port's business.** A named per-type
> object is one spelling of it and not the rule; expansion at each call site is
> another.

004's change log explains why it survived 003, whose entire theme was this same
mistake in fourteen other Parts:

> **Part 7.1 was the fifteenth and 003 walked past it.** The sentence reads like
> a requirement, and nothing exposed it as a mechanism until a port answered
> *generate code per type* a different way. **This is the first specification
> defect found since 003, and it was found by building, not by auditing.**

**And it was cut before dtk started, deliberately**, because D's idiomatic
answer to *generate code per type* — templates and mixins — is call-site
expansion, the same shape as a C3 macro.

## What ztk does

`PolyHelper(comptime T: type) type`, `polynode.zig:111`, a comptime function
returning a per-type structure whose declarations are the members of Part 7.2.
Each Matryoshka type instantiates it once: `pool.zig:631` is
`const helper = polynode.PolyHelper(Pool);`.

---

# 9. What this port gets wrong and knows it

**Two findings of 3tk's own audit are open, and they are here because a port
that copies a shape copies its defects with it.** Neither is a rule that moved;
both are places where the specification is right and the code is not.

- **P3 — a condition variable's own fault can escape the outcome set.**
  `pool.c3:432` and `mailbox.c3:314` return `f~` — the C3 standard library's
  fault — to the application, where Part 19 fixes the outcome set of every
  operation. **It is unreachable on the current backend**, which is the whole of
  its severity: posix `wait_until` returns timeout or ok and aborts on anything
  else. The audit recorded it anyway, and gave the reason in a sentence that is
  the reason it appears here too: *it is a contract statement sitting in the
  port's two most-copied loops, and the next port will copy the shape before it
  checks its own backend.*
- **P4 — the pool's leaver signals on one bucket over a shared condition
  variable.** `pool.c3:438-439`. Part 2.6 says a leaver checks the container and
  signals if it is not empty; the pool has one condition variable and *n*
  buckets, so a waiter for identity A leaving on a timeout does not signal for a
  non-empty bucket B. **004 left Part 2.6 untouched** and said why in its change
  log: *the rule is right as written. Moving a rule to accommodate a port's
  defect is how a specification stops being one.*

**One finding of the same audit is closed and is worth the line**, because the
question it asked belongs to every port: `Pool.get` used to return
*not-available* from all three modes for an identity the pool was never created
with, against Part 19.3's MUST. The port now reports `UNKNOWN_IDENTITY` —
`pool.c3:335`, `pool.c3:417` — a fault **deliberately outside Part 19's sets**,
because Part 11.7 makes an identity outside the pool's set a caller defect and
not a runtime condition. ztk answers the same question with
`std.debug.assert(self.*.lists.contains(tag))` — `pool.zig:345`, `:573`.

---

# 10. What did not move, and what this document is not

**Most of the port is the specification, built.** D1 to D16 minus D6 are answers
to language questions — public structs because C3 has no field privacy at any
price, one handle type, allocators taken at creation, C3 faults as the outcome
mechanism — and §7 of the redesign proposal lists what survived the redesign
untouched: **Parts 12, 13, 14, 15, 17 and 19 of the specification, and no fault
added or removed.**

**Three things this file deliberately does not contain.**

- **A recommendation to any port**, including this one. Everything above is what
  3tk decided and the reasoning that produced it. What another port does with
  that is that port's decision and its owner's ruling.
- **An audit of ztk.** Every ztk fact here was read from `src/*.zig` at the
  repository root and is cited to a line, and none of them is scored. The
  document that audits ztk against the specification is
  [`../common/ztk-audit-001.md`](../common/ztk-audit-001.md), which predates all
  of this, and any successor to it is ztk's own work.
- **A plan.** Nothing here declares a stage in any line.

**Where the full arguments live**, for a reader who wants one of them entire:
[3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md) for R1 to
R15, [3tk-porting-proposal-004.md](3tk-porting-proposal-004.md) for D1 to D16,
[3tk-deviations-001.md](3tk-deviations-001.md) for the 96-element audit that
produced V1 to V19 and P1 to P6, and
[3tk-status.md](3tk-status.md) for what is current.

---

## Change log

| Version | Date | Description |
|---|---|---|
| 001 | 2026-08-24 | First version. Stage 3TK-20. Written from R1 to R15, D1 to D16, V1 to V19, P1 to P6, `3tk/src/`, `src/*.zig` at the repository root, and 004's change log. Describes; recommends nothing. Now in `backup/`. |
| 002 | 2026-08-25 | Stage 3TK-22, after 3TK-21 made `struct Inner` one `any`. §1's code block, its `is_linked` block and its four walk citations were re-cut from `inner.c3`, `queue.c3` and `stack.c3`; §7's tier 2 and tier 3 citations and §8's `is_mine` block were re-cut the same way; `helper.c3`'s span moved to `76-232`. **New: §1a**, the identity and the chain link stored as one built-in pair — the ruling, the read-only halves, `repoint_to` and `points_to`, the two outcomes the language decided, and what ztk does instead. Every `file:line` in the document, 3tk's and ztk's, was printed and read again; no ztk citation had moved. The word *should* appears **nowhere**, as in 001. Describes; recommends nothing. |
