# What the C3 port decided, and why (005)

**Description and reasoning. Not recommendations.**

Written by 3TK-20 on 2026-08-24 and grown by 3TK-22, 3TK-24 and 3TK-56.
**3TK-73 crossed it into this repository on 2026-09-09** — this is where a
reader of the port lands. `001` to `004` are in `matryoshka-tk`'s
`design/secondary/lang/c3/backup/`, which is transient and is not a source of
truth.

**Every `file:line` into 3tk was re-resolved by 3TK-73 against the built tree**,
because 3TK-63, 3TK-64 and 3TK-70 rewrote four files between 2026-08-30 and
2026-09-09 and every number here had moved. Quoted 3tk code was re-cut from the
same tree in the same pass, which is why the blocks below say `Inner*` where
earlier versions said `Handle`: the port retired that word. **The ztk citations
are left exactly as measured** — none of them was re-read, and re-pointing a
measurement would falsify it.

**Three claims changed with the code and are marked where they appear**: the
mailbox's Part 2.6 hand-off, §9's `P4`, and §8's Part 7.4 sentence.

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

- **dtk**, the D port, which has run no stage and starts from the shared
  specification alone — `matryoshka-specification-005.md`, in `matryoshka-tk`'s
  `design/secondary/lang/common/`. It has no way to learn
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
judgment about somebody else's schedule. **§1a, §4a and §5a are peers of §1,
§4 and §5**, numbered that way because §1 to §10 keep the numbers they were
first read under.

**The citations, and what they are.** `R1` to `R15`, `D1` to `D16`, `V1` to
`V19`, `H0` and `P1` to `P6` are **historical markers, not live links.** They
name the 2026-08 sitting that ruled each point — the core redesign proposal,
the porting proposal, and the port's own audit against the specification — and
those three documents are spent and in `matryoshka-tk`'s `backup/`, which is
transient. **A marker says who ruled it; the sentence beside it says what
stands, and where the two would differ the source is what stands.** Parts and
invariants are the specification's.

---

# 1. The item carries one link, and the last one points at itself

## What 3tk does

`Inner` is one field, and that field is a built-in pair — `inner.c3:90`:

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
null off one**, and the membership question becomes one load —
`inner.c3:346`:

```c3
fn bool is_linked(Inner* inner) @inline => inner != null && inner.points_to() != null;
```

Every walk ends at `n.points_to() == n` rather than at null — the iterator at
`queue.c3:71` and `InnerStack.pop` at `pool.c3:802` spell that test.
`InnerQueue.pop_front` recognises the sole item by `head == tail` instead
(`queue.c3:115`), and `InnerStack.push` self-links the new bottom
(`pool.c3:787`). Those are the four sites the invariant touches. **The stack
has no file of its own**: it lives at the foot of `pool.c3`, in
`mtk::pool::internal`, because the pool is the only thing that has one.

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
after the owner rejected three shapes of a type-erased alternative, in a
document that is spent and no longer cited. `next` asserts *the following
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
same identity, and the public surface — the handle type, `Slot`, `InnerQueue`,
`InnerStack`, `inner_offset`, the faults, `Inner.to`, `Inner.as` — is unchanged.
**The port has since retired the word `Handle`**, and the type is spelled
`Inner*` throughout; the sentence is left in its own terms because it records
what was measured then.
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

**Two methods on `Inner` are the answer to it** — `inner.c3:335` and
`inner.c3:341`:

```c3
fn void Inner.repoint_to(&self, Inner* to) @inline
    => self.link = any_make(to, self.link.type);

fn Inner* Inner.points_to(&self) @inline => (Inner*)self.link.ptr;
```

`repoint_to` keeps the identity and swaps the pointer, which is the fourth
corner of a table the stdlib leaves open: `any_make` replaces both halves,
`any.retype_to` keeps the pointer and swaps the type, `any.as_inner` keeps the
pointer and derives the type. **Nine link writes exist in the port and eight go
through `repoint_to`**; the ninth is `inner::internal::stamp` at
`inner.c3:263`, the one place the identity is supposed to change. **It was
`helper::init` when this was written**; 3TK-64 refilled `helper.c3` and the
write moved to `inner.c3`, where the helper's `stamp` member now forwards to
it. `points_to` is the reader, and it
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

`Mailbox` holds `InnerQueue _oob` and `InnerQueue _regular` — `mailbox.c3:502-503`, inside `_Mbox`, the real struct behind the opaque `Mailbox`.
`send` pushes the back of `_regular`, `send_oob` pushes the back of `_oob`
(`mailbox.c3:412`), and every take tries `_oob` first (`mailbox.c3:422`).
Where the mailbox gives items back as a list — `close`, `receive_all` — it
appends `_oob` then `_regular`: `mailbox.c3:270-271` in `receive_all`, and `:453-454` in `_close`.

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
nobody woken.

**The code answered it a second way, and the first way is gone.** When this was
written, a timed-out waiter ran `if (self.has_queued()) self._cv.signal()`, and
`has_queued` — `mailbox.c3:432` — reads both queues, which was the half-fix
avoided. 3TK-70 removed that branch as one it could not reach: the waiter
reaches it only when the `dequeue` two lines above returned null, under the same
held mutex, so the condition cannot be true. **Part 2.6 is satisfied by the
stronger route instead** — a waiter that finds an outer does not leave at all,
so the wakeup it might have consumed, it consumed by taking the outer — and
`receive`'s Part 2.6 marker still stands. `mailbox.c3:195`. The two-queue
lesson is unchanged and is why `Mailbox.len` still adds both, `mailbox.c3:355`.

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
still holding is handed to the **close** hook — `pool.c3:476-494`:

```c3
    if (self._closed)
    {
        InnerQueue stragglers;
        if (mine.is_full()) stragglers.push_back(mine.take());
        stragglers.append_queue(&extra);

        // [3tk: Part 12.3]
        self._mu.unlock();
        if (!stragglers.is_empty()) self._hooks.on_close(stragglers.take());

        // Lowered after the straggler hook, not before it. A count that stopped
        // at `on_put` would leave application code running with pool-derived
        // outers while a release saw zero.
        // [3tk: Part 11.12]
        self._mu.lock();
        self._active--;
        self._mu.unlock();
        return;
    }
```

**The `_active` bookkeeping around it is not part of this finding** — it is the
lifetime fix of §9's neighbourhood, built later, and it is in the block because
re-cutting a quotation means quoting what is there.

**One rule, and it is the pool's own: what the pool holds when it discovers it
is closed goes to `on_close`** — `pool.c3:475-484`.

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
must not free its own context on the first call. `pool.c3:64-78` carries it.

## What ztk does

`Pool.put`, `pool.zig:329`, releases the mutex across `on_put`
(`pool.zig:350-352`) and relocks. The post-hook work is inside
`if (!self.*.closed.load(.monotonic))` at `pool.zig:354`, **with no else
branch** — `pool.zig:354-370`. `Pool.close`'s doc comment at `pool.zig:426-427`
reads *Safe to call more than once. Later calls collect nothing, and `on_close`
runs once.*

---

# 4a. `on_close` takes the queue by value, not by pointer

## What 3tk does

`PoolHooks.on_close` was `fn void on_close(InnerQueue* remaining);`. It is now

```c3
fn void on_close(InnerQueue remaining);
```

— `pool.c3:78`. Both call sites move a copy in with the new
`InnerQueue.take()` — `queue.c3:138`, O(1) and unable to fail: the straggler
path at `pool.c3:484`, `self._hooks.on_close(stragglers.take())`, and the main
close at `pool.c3:541`, `self._hooks.on_close(remaining.take())`.

## Why

**Ruled by the owner, 2026-08-28**, closing `P6`, the last open item on 3tk's
own defect list: *a pool can lose items and never
know*, because nothing checks that a close hook actually freed or filed what it
was handed. Three answers were on the table — count what came back, assert the
queue is empty in a checked build, or trust the hook and write it down. **The
owner ruled the third**, and **stronger than as first written**: instead of a
comment beside a pointer that invites a caller to keep reading through it, the
parameter is a value. *I do not care what you did* is now a fact about the
type, not a request in prose.

**Measured before the ruling was written down, on c3c 0.8.3, 2026-08-28**: a
by-value struct parameter is an lvalue, so `&self` methods (`pop_front`,
`is_empty`, `len`) bind to it exactly as they did through the pointer — the
hook body is unchanged. What changes is the caller: after `self._hooks.on_close(remaining.take())`
returns, `remaining` is empty and there is no route back to whatever the hook
kept. **That is the point, not a side effect.** Two live copies of one chain
would violate the shape invariant that a chain has one owner, so the copy that
crosses into the hook has to be a real move, and `take()` is what makes it one.

**Not extended to the shared specification.** Part 12.2 says the hook is
handed the items, not through what — the pointer-vs-value choice is not a
promise `on_close` makes to a caller, so no ports need agree on it. Recorded
here instead, as a port finding, so a port that starts from the specification
alone still gets to read the argument. No `InnerStack` overload was added:
`Part 8.2`'s *provided if useful* is not met, because nothing in 3tk ever calls
one.

## Where the specification stands

**No change.** Part 12.2 is unchanged by this: *the hook is handed the items*
holds exactly as it did with a pointer parameter. This is a 3tk implementation
choice about how that hand-off is spelled in the type system, not a new rule.

## What ztk does

`Pool.Hooks.on_close` — `pool.zig:127-130` — still takes `list:
*polynode.ItemList`, by pointer: *the hook is responsible for processing or
destroying every item*, unchecked, the same way 3tk's own parameter read
before this stage. **The two ports diverge here, and it is not ruled which
should**: 3tk now states the trust in the type, ztk states it only in the doc
comment. Weighing whether ztk's own interface should change is ztk's plan to
cut, not this document's to argue.

---

# 5. The pool hands back the item it was given most recently

## What 3tk does

One free **stack** per identity — `pool.c3:634`, R11. The item just put is on
top, and the next `get` for that identity hands it straight out.

**Part 11.7 promises no order and Part 11.10 says so**, and the doc comment
turns that into the reason the property is useful: *what makes the property
useful is that no caller is entitled to it* — `pool.c3:744`, on the `InnerStack` block, and `pool.c3:630-633` on `PoolBucket`.

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
`pool.c3:75`, the `on_close` parameter.

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

# 5a. On the most ordinary pool path, one port calls the creation hook and the other does not

## What 3tk does

**A get that finds a stored item returns it without calling `on_get`.**
`Pool.get`, available-or-new mode — `pool.c3:311-321`:

```c3
    if (mode != NEW_ONLY)
    {
        Inner* inner = b.free.pop();
        if (inner)
        {
            self._active--;
            self._mu.unlock();
            slot.fill(inner);
            return;
        }
    }
```

The hook is below that block and is reached only when the pop found nothing —
`pool.c3:333-335`, with the count that Part 12.4 asks for:

```c3
    // [3tk: Part 12.3, Part 15.2]
    self._mu.unlock();
    self._hooks.on_get(want, in_pool, slot);
```

The three modes, as the code arranges them:

- **available or new** — pop; on a hit, return; on a miss, fall through to the
  hook. `pool.c3:311-321`, then `:330-335`.
- **available only** — the same pop, and on a miss `NOT_AVAILABLE` rather than
  the hook. `pool.c3:323-328`.
- **new only** — the `mode != NEW_ONLY` guard at `pool.c3:311` skips the pop
  entirely, so the hook is always called and the free stack is not read.

**So `on_get` sees an empty Slot on every call it ever gets**, and the only
thing the pool checks afterwards is the identity — `pool.c3:348`. Nothing in
`pool.c3` gives a hook a way to touch an item that came back from the stack.

## Why

**The port wrote what Part 12.2 says.** `3tk-porting-proposal-004.md:1240`,
where the three hooks were compiled from the specification for Q5, states the
signature's contract in one line: *`on_get` gets an empty Slot and the wanted
identity. Leaving it empty is the `NOT_CREATED` outcome.*

**No R-ruling and no D-decision covers it**, and that is the finding rather
than an omission from this document: the redesign never treated it as a
question, because the specification the port was written from reads as settled
on the point. The doc comment on `Pool.get` cites Part 11.7 and Part 19 and
records no choice here — `pool.c3:271-287`.

The port's stated rule when its sources disagree is next to the one place it
knew they did — the waiting get, `3tk-porting-proposal-004.md:1220-1226`: *the
running code is the evidence, the specification is the authority, and prose
that contradicts both is superseded.* **That rule was never applied here,
because nothing showed the sources apart until 2026-08-25**, when this
difference was found while confirming a separate claim about `Pool.get_wait`.

## Where the specification stands

**004 words the mode as an either-or.** Part 11.7, `matryoshka-specification-004.md:962`:

> available or new — take a stored item, else ask the hook for one.

**And Part 12.2 opens `on get` with the state of the Slot.** `:1064`:

> - The Slot is empty on entry.

**Neither is marked as a place ztk differs**, though the file marks such places
elsewhere and Part 12.2 ends by pointing at the audit that describes the other
behaviour — `*ztk*: audit 2.7`, `:1106`. Part 11.7's own per-port notes,
`:949-954`, name the container kind for each port and say nothing about the
hook.

**The specification binds every port**, `../common/README.md`, and dtk starts
from it alone.

## What ztk does

**It pops the item and calls the hook anyway, with the Slot full.**
`_get_available_or_new` — `pool.zig:565-590`:

```zig
    if (p.*.lists.getPtr(tag)) |list| {
        if (list.popFirst()) |ih| {
            p.*.counts.getPtr(tag).?.* -= 1;
            slot.* = ih;
        }
    }

    const hooks: Pool.Hooks = p.*.hooks;
    const count: usize = p.*.counts.get(tag) orelse 0;
    p.*.mutex.unlock(io);

    hooks.on_get(hooks.ctx, tag, count, slot);
```

There is no early return between the pop and the call. A hook therefore sees a
full Slot whenever the free list had something, and `pool.zig:589` turns a Slot
that is null *after* the hook into `error.NotCreated` — which on this path can
only happen if the hook emptied one it was handed full.

**ztk's other two modes match 3tk's.** `_get_new_only` never reads the list and
always calls — `pool.zig:592-610`. `_get_available_only` pops and returns, and
calls no hook on either outcome — `pool.zig:612-629`.

**ztk's own doc comment does not describe the full-Slot case.**
`pool.zig:94-104` says *Called before an item is returned from the pool* and
gives `slot` as *receives the selected item, or stays empty if no item is
available* — which reads as the pool filling the Slot, not the hook finding it
filled.

**The audit does describe it, and correctly.** `ztk-audit-001.md:542-545`:

> - Called on every `get`, in every mode. Not called by `get_wait`
>   (`src/pool.zig:247`, `:565-610` vs `:252-294`).
> - Slot non-null on entry: an item came from the free list — reinitialize it.
> - Slot null on entry: create one, or leave it null to signal failure.

**And the published book documents it as the contract.**
`matryoshka-api-reference-042.md:1449-1452`:

> - Called for every `get` and `get_wait` call regardless of mode or whether an
>   item was found in the free-list.
> - If `slot.*` is non-null on entry: the item was recycled from the free-list —
>   reinitialize it.

**Two words in those two passages are wider than ztk's own code**, and both are
recorded elsewhere rather than here: *in every mode* and *regardless of mode*
do not hold for available-only, `pool.zig:612-629`, which calls no hook; and
*and `get_wait`* does not hold either, which the audit's own next clause
contradicts and which `3tk-status.md` already carries as ztk's to fix.

**So a shared normative document and the audit it was distilled from disagree
about the most ordinary pool path there is.** 004 sides with 3tk twice and
marks nothing; the audit and the book side with ztk and are exact about it.
**This section states that and stops.** Which of the three moves — 3tk's code,
ztk's code, or Part 12.2 — is the owner's, and belongs to whichever line owns
the file that changes.

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

Tier 2 is four lines — `mtk.c3:66`, and it moved there with the module split:

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
`mtk::CHECKED`, `mtk.c3:78`, and its one reader is the `$if mtk::CHECKED:` at
`pool.c3:193`.

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
type named there — `helper.c3:40`, the module line, and the nine members below
it. A new outer type costs nothing before it can be used.

```c3
macro bool is_mine(Inner* inner, $Type) => inner != null && inner.link.type == $Type::typeid;
```

— `inner.c3:247`. **The helper is a generic module, `module mtk::helper <Outer>;`,
and binding it is one line**: `alias MSG = helper::OF{Msg};`. `helper.c3:51` and
`helper.c3:59` are the carrier and the constant that line names.

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
than buried**: a type that is declared but never crossed with is never
validated, because there is no instantiation to force Part 7.4's check.
**Re-cut 2026-09-09** — the lines quoted here in earlier versions went with the
file that held them, and the live wording of the same hazard is on the helper's
module block, `helper.c3:40`. The two outer hooks are found structurally by
`$defined`, so *a hook with the wrong NAME is silent — `$defined` answers false,
the branch vanishes, and no stage reports it.* Same shape one level down: what
is never named is never checked.

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

**Two findings of 3tk's own audit were open when this section was written, and
they are here because a port that copies a shape copies its defects with it.**
Neither is a rule that moved; both were places where the specification is right
and the code was not. **Re-read against the built tree on 2026-09-09: one is
still live and one is closed** — and both are kept, because a port reading this
wants the shape and the reason as much as the verdict.

- **P3 — a condition variable's own fault can escape the outcome set. Still
  live.** `pool.c3:412` and `mailbox.c3:232` return `f~` — the C3 standard
  library's fault — to the application, where Part 19 fixes the outcome set of
  every operation. **It is unreachable on the current backend**, which is the
  whole of its severity: posix `wait_until` returns timeout or ok and aborts on
  anything else. The audit recorded it anyway, and gave the reason in a sentence
  that is the reason it appears here too: *it is a contract statement sitting in
  the port's two most-copied loops, and the next port will copy the shape before
  it checks its own backend.* **Both sites now carry that reason in the code**,
  as a trailing comment: *dead today: `wait_until` can only fail with
  `WAIT_TIMEOUT`, kept for future wait failures.*
- **P4 — the pool's leaver signalled on one bucket over a shared condition
  variable. Closed by the code, and this is the version that says so.** Part 2.6
  says a leaver checks the container and signals if it is not empty; the pool has
  one condition variable and *n* buckets, so a waiter for identity A leaving on a
  timeout did not signal for a non-empty bucket B. **The branch the finding names
  no longer exists.** Re-read 2026-09-09: there is no `signal()` anywhere in
  `pool.c3`. Every wake the pool performs is a `broadcast` — `pool.c3:502` in
  `put`, `pool.c3:684` in `_close` — and `Pool.get_wait`'s timeout path leaves
  without signalling at all. The audit's own reason why nothing was ever lost —
  *every path that makes an outer available calls broadcast* — is now the whole
  mechanism rather than the thing that covered for a half-fix. **004 left Part
  2.6 untouched** and said why in its change log: *the rule is right as written.
  Moving a rule to accommodate a port's defect is how a specification stops being
  one.* That reasoning is worth more now, not less: the rule did not move and the
  port came to it.

**One finding of the same audit is closed and is worth the line**, because the
question it asked belongs to every port: `Pool.get` used to return
*not-available* from all three modes for an identity the pool was never created
with, against Part 19.3's MUST. The port now reports `UNKNOWN_IDENTITY` —
`pool.c3:309` in `get` and `pool.c3:384` in `get_wait` — a fault **deliberately outside Part 19's sets**,
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
  `ztk-audit-001.md`, in `matryoshka-tk`'s `design/secondary/lang/common/`,
  which predates all of this, and any successor to it is ztk's own work.
- **A plan.** Nothing here declares a stage in any line.

**Where the arguments went.** The three documents that held them entire — the
core redesign proposal for `R1` to `R15`, the porting proposal for `D1` to
`D16`, and the 96-element audit that produced `V1` to `V19` and `P1` to `P6` —
were retired by 3TK-73 on 2026-09-09, spent. What each ruled that still stands
is in this file and in [3tk-decisions-007.md](3tk-decisions-007.md), which is
the registry of what the port decided and where it lives in the code. **What is
current, and what has not run, is `3tk-status.md` in `matryoshka-tk`.**

---

## Change log

| Version | Date | Description |
|---|---|---|
| 001 | 2026-08-24 | First version. Stage 3TK-20. Written from R1 to R15, D1 to D16, V1 to V19, P1 to P6, `3tk/src/`, `src/*.zig` at the repository root, and 004's change log. Describes; recommends nothing. Now in `backup/`. |
| 002 | 2026-08-25 | Stage 3TK-22, after 3TK-21 made `struct Inner` one `any`. §1's code block, its `is_linked` block and its four walk citations were re-cut from `inner.c3`, `queue.c3` and `stack.c3`; §7's tier 2 and tier 3 citations and §8's `is_mine` block were re-cut the same way; `helper.c3`'s span moved to `76-232`. **New: §1a**, the identity and the chain link stored as one built-in pair — the ruling, the read-only halves, `repoint_to` and `points_to`, the two outcomes the language decided, and what ztk does instead. Every `file:line` in the document, 3tk's and ztk's, was printed and read again; no ztk citation had moved. The word *should* appears **nowhere**, as in 001. Describes; recommends nothing. |
| 003 | 2026-08-25 | Stage 3TK-24. **New: §5a**, the creation hook on a get that found a stored item — 3tk returns without calling it (`pool.c3:337-345`), ztk calls it with the Slot full (`pool.zig:565-590`). All three modes of both ports read and set out, the specification's two passages quoted by line, and the disagreement named between 004 on one side and `ztk-audit-001.md` 2.7 and `matryoshka-api-reference-042.md` on the other. Every `file:line` in the new section, 3tk's and ztk's, was printed and read before it was written down; nothing outside §5a changed but this row, the version line and one sentence in *How to read it*. The word *should* appears **nowhere**, as in 001 and 002. Describes; recommends nothing. |
| 004 | 2026-08-30 | Stage 3TK-56. **New: §4a**, `on_close` takes the queue by value, not by pointer — `P6` ruled 2026-08-28, built by this stage. Both call sites and `InnerQueue.take()` cited, ztk's still-by-pointer `on_close` read at `pool.zig:127-130` and named as an open divergence, not a recommendation. Nothing outside §4a changed but this row and one sentence in *How to read it*. The word *should* appears **nowhere**, as in every earlier version. Describes; recommends nothing. |
| 005 | 2026-09-09 | Stage 3TK-73, the design-folder audit — `A-7` and `A-10` of staging plan 034. **Crossed from `matryoshka-tk` into this repository**, where the port's reader lands, after being read against [3tk-decisions-007.md](3tk-decisions-007.md) and ruled a different subject from it: that file is the registry of what stands, this one is the argument, and neither does the other's job. **Every 3tk `file:line` re-resolved against the built tree** and every quoted 3tk block re-cut, because 3TK-63, 3TK-64 and 3TK-70 had rewritten four files — `Handle` became `Inner*`, `stack.c3` and `managed.c3` are gone, `@check` moved to `mtk.c3`, and the identity write moved from `helper::init` to `inner::internal::stamp`. **ztk's citations were not re-read and were not touched.** **Three claims changed with the code**: the mailbox's Part 2.6 hand-off in §3, `P4` in §9 — **closed; the pool has no `signal()` left** — and §8's Part 7.4 sentence. `P3` re-read and still live. Six links into documents that retired the same day became historical markers — `A-10`. No section was added and none was removed. The word *should* appears **nowhere**, as in every earlier version. Describes; recommends nothing. |
