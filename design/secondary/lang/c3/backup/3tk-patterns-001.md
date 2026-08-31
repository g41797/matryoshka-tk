# 3tk — the pattern catalog

**What a person assembles the toolkit into.** The reference says what each
declaration is. This says what the declarations are put together to do.

**It is descriptive.** The normative document is
[3tk-example-rules-001.md](3tk-example-rules-001.md), and a rule is changed
there and nowhere else.

**Written by 3TK-49**, from [../3tk-staging-plan-019.md](../3tk-staging-plan-019.md).
Its input is `../../../patterns-029.md`, the ztk catalog, **read as an input and
not used as a template.** Every one of that file's 75 entries is classified
below, and the classification is the work.

**Every ` ```c3 ` block here was compiled**, in one scratch module against
`3tk/src`, with `c3c` 0.8.3. A block with no ` ```c3 ` fence is a diagram and
compiles nothing.

**The word is Outer.** Never `Item`. **The one exception is a ztk entry
title quoted as a title** — *Cancellation keeps the item where it is* is that
document's heading and is quoted, not written.

## The classification, as a count

The ztk catalog has **75 entries** — every `###` and `####` heading, less
*Observable function shapes*, which is a container for the five headings under
it, plus *Graceful shutdown sequence*, which is a `##` with no `###` of its
own.

| what happened to it | how many |
|---|---|
| carries over in meaning | 38 |
| changes shape in C3 | 16 |
| inverts | 1 |
| drops | 20 |
| **total classified** | **75** |
| new, and 3tk-only | 7 |
| **in this catalog** | **62** |

**55 ztk entries survive the crossing, and 7 shapes are 3tk's own.** That is the
62 numbered below.

**What drops, and why.** Nine `Io.Select` entries, four `Io.Group` entries, two
`Future` entries and three cancellation entries rest on `std.Io`, which the
owner ruled out of scope on 2026-08-26. C3 has no `Future`, no `Io.Group`, no
`Io.Select` and no `error.Canceled`. The last two — *Coordinator with Select
event loop* and *Full Layer-4 architecture* — are whole-system shapes built on
the event loop. Nine and four and two and three and two is twenty, and they are
listed one by one at the end of this file.

**`ItemList` is not among them.** 3tk's batch type is `InnerQueue`, so every
entry that walked an `ItemList` changed shape rather than dropping.

**What inverts** is one entry, and it is named where it lands: *No switch on a
tag*.

## The index

An index row is a number, a name and a hook. **The description lives in the
entry.**

| # | pattern | |
|---|---|---|
| 1 | [Empty Slot](#1--empty-slot) | `Slot s;` and nothing else |
| 2 | [The Slot is never overwritten](#2--the-slot-is-never-overwritten) | the toolkit asserts it for you |
| 3 | [Transfer empties the Slot](#3--transfer-empties-the-slot) | four calls, one property |
| 4 | [Insert from a Slot](#4--insert-from-a-slot) | `push_back_slot` leaves no line to forget |
| 5 | [Null-safe cleanup](#5--null-safe-cleanup) | a release on an empty Slot does nothing |
| 6 | [Defer-put-early](#6--defer-put-early) | the defer goes before the get |
| 7 | [Defer-release-early](#7--defer-release-early) | the defer goes before the create |
| 8 | [Defer for a received outer](#8--defer-for-a-received-outer) | one shape covers the fault path and the normal one |
| 9 | [Fallback release after a refused put](#9--fallback-release-after-a-refused-put) | read the Slot; `put` returns nothing |
| 10 | [No raw allocator call on an outer](#10--no-raw-allocator-call-on-an-outer) | a raw `new` skips `init` |
| 11 | [Embedding the inner](#11--embedding-the-inner) | one field, any offset |
| 12 | [The `$Type` crossing](#12--the-type-crossing) | there is no helper type to declare |
| 13 | [Recovering the type](#13--recovering-the-type) | `to` asks, `as` asserts |
| 14 | [A stack outer into the toolkit](#14--a-stack-outer-into-the-toolkit) | `init`, then `to_handle` |
| 15 | [Walk a batch](#15--walk-a-batch) | the batch is an `InnerQueue` |
| 16 | [Reach into a full Slot](#16--reach-into-a-full-slot) | inspect without taking |
| 17 | [Dispatch — outer-first](#17--dispatch--outer-first) | you hold the outer |
| 18 | [Dispatch — identity-first](#18--dispatch--identity-first) | you hold an identity and no outer |
| 19 | [Dispatch — switch](#19--dispatch--switch) | the shape ztk cannot write |
| 20 | [Dispatch — table](#20--dispatch--table) | the handler belongs to the pair |
| 21 | [The last branch of a dispatch chain](#21--the-last-branch-of-a-dispatch-chain) | always write it, and it cannot release |
| 22 | [An identity names a type, not an instance](#22--an-identity-names-a-type-not-an-instance) | `kind` fields are yours |
| 23 | [A wrapper around an infrastructure pointer](#23--a-wrapper-around-an-infrastructure-pointer) | when the endpoint alone is not enough |
| 24 | [Mailbox as message](#24--mailbox-as-message) | a mailbox is an outer |
| 25 | [Worker-finish-signal](#25--worker-finish-signal) | the worker sends its own mailbox back |
| 26 | [Pool as message](#26--pool-as-message) | the same crossing, one type along |
| 27 | [Poll](#27--poll) | `EMPTY` is an answer |
| 28 | [Receive everything at once](#28--receive-everything-at-once) | one lock, one queue |
| 29 | [Out-of-band](#29--out-of-band) | one level, not a priority queue |
| 30 | [Close recovery](#30--close-recovery) | run the loop unconditionally |
| 31 | [Release a refused transfer](#31--release-a-refused-transfer) | a refusal leaves the outer with you |
| 32 | [Wake without a message](#32--wake-without-a-message) | `WOKEN`, and nothing queued |
| 33 | [Request-Response](#33--request-response) | two mailboxes, never one |
| 34 | [Pipeline](#34--pipeline) | one outer per stage at a time |
| 35 | [Fan-In](#35--fan-in) | the mailbox does the merging |
| 36 | [Fan-Out](#36--fan-out) | the mailbox does the distribution |
| 37 | [`AVAILABLE_OR_NEW`](#37--available_or_new) | the common case |
| 38 | [`NEW_ONLY`](#38--new_only) | seeding |
| 39 | [`AVAILABLE_ONLY`](#39--available_only) | consume what is kept |
| 40 | [Seeding a fixed-size pool](#40--seeding-a-fixed-size-pool) | the seed count is the limit |
| 41 | [The pool holds no policy](#41--the-pool-holds-no-policy) | the hooks are the policy |
| 42 | [The hook object is the context](#42--the-hook-object-is-the-context) | **new** — no `ctx` pointer anywhere |
| 43 | [A hook runs outside the lock](#43--a-hook-runs-outside-the-lock) | a plain counter is a data race |
| 44 | [The `on_close` hook](#44--the-on_close-hook) | nobody else will |
| 45 | [A pool of several identities](#45--a-pool-of-several-identities) | one policy, one free list per identity |
| 46 | [Reading the fault on a receive](#46--reading-the-fault-on-a-receive) | four outcomes, four meanings |
| 47 | [The shutdown order](#47--the-shutdown-order) | close upstream first, close the pool last |
| 48 | [Shutdown by message](#48--shutdown-by-message) | the mailbox stays open |
| 49 | [The coordinator](#49--the-coordinator) | a body of calls to named steps |
| 50 | [The step](#50--the-step) | one thing, and the name is the documentation |
| 51 | [Acquiring the resources](#51--acquiring-the-resources) | `create` gives a pointer, not a Slot |
| 52 | [Releasing the resources](#52--releasing-the-resources) | reverse order, and close before release |
| 53 | [The thread is given one pointer](#53--the-thread-is-given-one-pointer) | no thread-local bookkeeping |
| 54 | [Spawn and join in one step](#54--spawn-and-join-in-one-step) | the coordinator sees one call |
| 55 | [More than one coordinator](#55--more-than-one-coordinator) | each owns its own resources |
| 56 | [Pool and mailbox together](#56--pool-and-mailbox-together) | reuse below, transport above |
| 57 | [The allocator in the outer](#57--the-allocator-in-the-outer) | **new** — release takes no allocator |
| 58 | [An identity costs no registration](#58--an-identity-costs-no-registration) | **new** — declare the struct, cross with it |
| 59 | [The optional-declaration walk](#59--the-optional-declaration-walk) | **new** — `while (Handle h = ...)` |
| 60 | [Guarding an expensive check](#60--guarding-an-expensive-check) | **new** — `mtk::CHECKED` and `@check` |
| 61 | [A composite outer gives back its parts](#61--a-composite-outer-gives-back-its-parts) | **new** — the `extra` queue |
| 62 | [What a fast build stops checking](#62--what-a-fast-build-stops-checking) | **new** — two tiers |

## The outers used below

**Declared once, and every block after this one uses them.** Three outers, and
they are chosen the way `test/common.c3`'s four were: to prove something.

```c3
module pat;
import mtk;
import mtk::helper;
import mtk::managed;
import mtk::mailbox;
import mtk::pool;
import std::thread;
import std::time;
import std::core::mem::alloc;
import std::atomic::types;

struct Event  { Inner node; int code; Allocator alloc; }
struct Sensor { int reading; Inner node; Allocator alloc; }
struct Holder { int id; Inner node; Allocator alloc; }

faultdef PATTERN_FAILED;
```

- `Event` puts the inner at offset zero, `Sensor` does not. **Both cross**, and
  that is the first thing the pair is here to prove: 3tk computes the offset at
  the crossing, so an outer's layout is the application's business.
- **All three carry an `Allocator`**, so all three may take `mtk::managed`. That
  is not decoration. A shared release function is a dispatch chain, and the
  chain calls `mtk::managed::release` in every branch — so an outer with no
  `Allocator` field cannot appear in one at all. The build says so by name.

---

## Slot and transfer idioms

**These are in every pattern below, so they come first.**

### 1 — Empty Slot

*Carries over.*

**When to use.** Every time you are about to take an outer.

**Code shape.**

```c3
fn void p1_empty_slot()
{
    Slot s;
}
```

**Why.**

- A Slot starts empty on its own. There is no initializer to forget and no
  `= null` to write.
- Every acquisition wants an empty Slot, and gets one for free.

### 2 — The Slot is never overwritten

*Changes shape.* ztk wrote `std.debug.assert(slot.* == null)` at the call site.
**In 3tk the check is inside `Slot.fill`**, so there is nothing to write.

**When to use.** Nowhere. It is stated so no one writes the assert by hand.

**Why.**

- `fill` on a full Slot aborts in a checking build, and the abort names the
  Slot.
- A Slot holds one handle. Overwriting one loses the outer it held with no
  trace, which is why the check is in the toolkit and not in the caller.
- `negative/overwrite_slot.c3` is that abort, run in every checking build.

### 3 — Transfer empties the Slot

*Carries over.*

**When to use.** Every transfer.

**Code shape.**

```c3
fn void? p3_transfer(Mailbox* mb, Pool* p, InnerQueue* q, Slot* a, Slot* b, Slot* c, Slot* d)
{
    mb.send(a)!;                    // a is empty — the mailbox has it
    p.put(b);                       // b is empty if the pool kept it
    Event* e = c.move(Event);       // c is empty — you have it
    q.push_back_slot(d);            // d is empty — the queue has it
}
```

**Why.**

- After a transfer the outer is somewhere else, and the Slot says so.
- **A transfer pre-empts a cleanup.** A `defer` written earlier sees an empty
  Slot and does nothing.
- `put` is the one that needs reading rather than trusting — see entry 9.

### 4 — Insert from a Slot

*Changes shape.* ztk's `ItemList.appendFromSlot` is 3tk's
`InnerQueue.push_back_slot`.

**When to use.** Putting an outer that sits in a Slot onto a queue.

**Code shape.**

```c3
fn void? p4_insert_from_slot(Allocator a, InnerQueue* q)
{
    Slot s;
    defer mtk::managed::release(Holder, &s);
    mtk::managed::create(Holder, a, &s)!;
    s.must(Holder).id = 7;

    q.push_back_slot(&s);           // s is empty
}
```

**Why.**

- `push_back` takes a `Handle`, so it cannot empty a Slot. Every call site
  would write the clearing line by hand.
- Forget that line and the `defer` above releases an outer the queue still
  points at.
- `push_back_slot` empties the Slot itself, so there is no line to forget.

**Do not** reach for it for a stack outer. There is no Slot — use `push_back`
with `to_handle`, entry 14.

### 5 — Null-safe cleanup

*Carries over.*

**When to use.** Every deferred cleanup.

**Code shape.**

```c3
fn void p5_null_safe(Pool* p, Slot* pooled, Slot* heaped)
{
    defer p.put(pooled);
    defer mtk::managed::release(Holder, heaped);
}
```

**Why.**

- Releasing an empty Slot does nothing, and putting an empty Slot does nothing.
- So a cleanup may run after a transfer already took the outer.
- That is what makes the defer-first shapes below legal at all.

### 6 — Defer-put-early

*Carries over.*

**When to use.** Acquiring an outer from a pool. **The defer goes before the
get.**

**Code shape.**

```c3
fn void? p6_defer_put_early(Pool* p)
{
    Slot s;
    defer p.put(&s);                                    // nothing to do if the get failed
    p.get(Holder::typeid, AVAILABLE_OR_NEW, &s)!;
    s.must(Holder).id = 1;
}
```

**Why.**

- The failure path, the success path and the transfer path all become right at
  once.
- If the get fails the Slot stays empty and the defer does nothing.
- If the outer is sent on, the Slot is empty and the defer does nothing.
- Otherwise the outer goes back to the pool, which is what was wanted.

### 7 — Defer-release-early

*Changes shape.* ztk's `PolyHelper.destroy` is 3tk's `mtk::managed::release`,
and it takes no allocator.

**When to use.** Creating an outer on the heap. **The defer goes before the
create.**

**Code shape.**

```c3
fn void? p7_defer_release_early(Allocator a, Mailbox* mb)
{
    Slot s;
    defer mtk::managed::release(Holder, &s);
    mtk::managed::create(Holder, a, &s)!;
    s.must(Holder).id = 42;
    mb.send(&s)!;                                       // on success the defer does nothing
}
```

**Why.**

- **On a failed `create` the Slot is untouched**, so the defer above it is safe
  before the call that fills it.
- On a refused `send` the Slot is still full and the defer releases the outer.
  A bare `send` with no defer leaks there.

### 8 — Defer for a received outer

*Carries over.*

**When to use.** Receiving into a Slot, where cleanup has to cover both the
fault path and the normal one.

**Code shape.**

```c3
fn void p8_defer_received(Mailbox* mb, Allocator a)
{
    Slot s;
    defer free_outer(&s);
    if (catch mb.receive(&s, time::ms(100))) return;
    // dispatch on the identity, process the outer
}
```

**Why.**

- The outer stays with you until you transfer it or release it, and the fault
  paths in between are the ones that get forgotten.
- `free_outer` is the outer-first dispatch chain of entry 17, written once and
  reused. It is what the release has to be, because a Slot on a mixed mailbox
  can hold any of the identities the mailbox carries.

### 9 — Fallback release after a refused put

*Changes shape.* `Pool.put` in 3tk returns nothing at all, so there is no fault
to catch and no `try`. **Read the Slot.**

**When to use.** Whenever the pool may already be closed when the outer comes
back.

**Code shape.**

```c3
fn void p9_fallback(Pool* p, Slot* s)
{
    defer mtk::managed::release(Holder, s);   // fallback: runs only if the pool refused
    defer p.put(s);                           // primary: empties the Slot if the pool kept it
}
```

**Why.**

- Defers run last-registered-first, so the `put` is tried first and the release
  is second.
- A closed pool leaves the Slot full, and then the release has work to do.
- An open pool empties the Slot, and then the release does nothing.
- **A put can never fail and can never be interrupted**, so a worker that must
  give its outer back always can. This shape covers the one case where the
  pool does not take it.

### 10 — No raw allocator call on an outer

*Carries over.*

**When to use.** Every outer, every time.

**Code shape.**

```c3
fn void? p10_no_raw_alloc(Allocator a)
{
    // WRONG — a raw allocator call on an outer
    // Holder* h = a.new(Holder);

    // RIGHT — the allocator goes in, and the identity is written
    Slot s;
    defer mtk::managed::release(Holder, &s);
    mtk::managed::create(Holder, a, &s)!;
}
```

**Why.**

- `mtk::managed::create` allocates, writes the allocator into the outer, calls
  `init` and fills the Slot.
- A raw `a.new(Holder)` skips `init`, so the outer carries no identity and
  every crossing refuses it.
- **The refusal is the point.** A struct you forgot to initialize does not
  silently become whatever type you asked for.
- For an outer that carries no `Allocator` field, `mtk::helper::init` is the
  call, and the release is yours — entry 14.

---

## Crossing the border

### 11 — Embedding the inner

*Carries over.*

**When to use.** Every outer, from its first declaration.

**Code shape.**

```c3
struct Command
{
    int     kind;
    Inner   node;
    char[8] name;
}
```

**Why.**

- One field, sixteen bytes, and your struct is the node. No wrapper, no
  separate link object, one allocation.
- **The inner goes anywhere in the struct.** ztk's had to sit at offset zero;
  3tk computes the offset at the crossing, so `Event` and `Sensor` above both
  work.
- Exactly one. A struct with none, or with two, does not compile, and the
  message names your type.

### 12 — The `$Type` crossing

*Changes shape*, and this is the largest shape change in the port. **There is
no `PolyHelper` and there is nothing to declare.**

**When to use.** Every crossing.

**Code shape.**

```c3
fn void p12_type_crossing(Handle h)
{
    if (Event* e = mtk::helper::from_handle(h, Event)) { e.code++; }
    if (Event* e = h.to(Event))                        { e.code++; }
}
```

**Why.**

- `mtk::helper` and `mtk::managed` are macros over `$Type`. **The type is a
  parameter of the call, not of a generated helper.**
- So a new outer type costs no setup: no alias, no instantiation, no
  registration. Declare the struct, embed an `Inner`, cross with it.
- ztk needed `EventPolyHelper` because the tag had to be a global somewhere.
  3tk's identity is `Event::typeid`, which the compiler already has.
- **The method form and the free-function form are the same call.** `h.to(Event)`
  is `from_handle(h, Event)`. Pick one and stay with it inside a file.

### 13 — Recovering the type

*Carries over.*

**When to use.** You hold a `Handle` and want the typed pointer back.

**Code shape.**

```c3
fn void p13_recover(Handle h, Slot* s)
{
    if (Event* e = h.to(Event)) { e.code++; }       // null on a mismatch
    Event* known = h.as(Event);                     // asserts, and is gone in a fast build
    Event* peeked = s.to(Event);                    // null on a mismatch, Slot untouched
    Event* taken  = s.move(Event);                  // null on a mismatch, Slot emptied on a match
}
```

**Why.**

- **Use the checking form when a mismatch is normal.** Walking a queue that
  carries three identities, you meet the other two, and null is the answer.
- **Use the asserting form when a mismatch is your bug.** It costs nothing in a
  fast build, because it is not there.
- `move` is the acquisition idiom: the pointer and the empty Slot in one step,
  with no window where you hold both.
- `mtk::helper::is_mine(h, Event)` asks the question without crossing. A null
  handle is not yours, and an outer that was never initialized is not yours
  either.

### 14 — A stack outer into the toolkit

*Carries over.*

**When to use.** The outer lives on the stack, so there is no `create` and no
Slot to start from, and something wants a `Handle`.

**Code shape.**

```c3
fn void? p14_stack_outer(Mailbox* mb, InnerQueue* q)
{
    Event e = { .code = 42 };
    mtk::helper::init(&e);

    Handle h = mtk::helper::to_handle(&e);
    q.push_back(h);

    Event other = { .code = 7 };
    mtk::helper::init(&other);
    Slot s;
    s.fill(mtk::helper::to_handle(&other));
    mb.send(&s)!;
}
```

**Why.**

- `to_handle` cannot fail. The type is known where it is written, so there is
  nothing to check. Null in, null out.
- **The field name stays inside `mtk::helper`.** Application code never writes
  `&e.node`.
- `init` before first use, always. The heap path does not need this idiom —
  `mtk::managed::create` initializes and fills a Slot already.

**Do not** call `to` or `as` on an outer whose static type you already have.
That is a round trip that proves nothing. The crossings are for the way back,
where the static type is gone.

**And know what you took on.** A stack outer cannot be released, so every
pattern below that ends in a release is invisible from a stack outer. Use one
for a demonstration of the crossing itself, and `mtk::managed` for everything
that has a lifetime.

### 15 — Walk a batch

*Changes shape.* ztk's `ItemList` is 3tk's `InnerQueue`, which is the type the
toolkit already uses internally, so there is no second list type in the port.

**When to use.** Anything gives you many outers at once: `Mailbox.receive_all`,
`Mailbox.close`, the `on_close` hook, the `extra` queue of `on_put`.

**Code shape.**

```c3
fn void? p15_walk_batch(Mailbox* mb, Allocator a)
{
    InnerQueue batch;
    mb.receive_all(&batch)!;

    while (Handle h = batch.pop_front())
    {
        Slot s;
        s.fill(h);
        free_outer(&s);
    }
}
```

**Walk without consuming.**

```c3
fn usz p15_walk_without_consuming(InnerQueue* q)
{
    usz n;
    InnerQueueIterator it = q.iter();
    while (Handle h = it.next()) { n++; }
    return n;
}
```

**Why.**

- `pop_front` gives a `Handle`, not a node, and resets it before it returns.
  **A popped handle is never linked**, so it drops straight into a Slot or into
  `send`.
- Mixed identities in one batch are the normal case, and the crossing returns
  null on a mismatch, so the same loop dispatches — entry 17.
- `len` is kept, not counted, so it is free.
- **Do not remove the current outer while walking with an iterator.** That is
  not supported.
- `append_queue` moves a whole queue onto another in one step, leaving the
  source empty. Use it instead of a pop-push loop.

### 16 — Reach into a full Slot

*Carries over.*

**When to use.** After a `create` or a `get`, to set fields before the outer is
sent or given back.

**Code shape.**

```c3
fn void? p16_reach_in(Allocator a, Mailbox* mb)
{
    Slot s;
    defer mtk::managed::release(Holder, &s);
    mtk::managed::create(Holder, a, &s)!;
    s.must(Holder).id = 42;
    mb.send(&s)!;
}
```

**Why.**

- **Inspection leaves the Slot full.** The outer is still there for the `send`
  or the `put` on the next line.
- `must` asserts the identity and is gone in a fast build. `to` returns null
  instead, for when the identity is not guaranteed.
- To take the outer out rather than reach into it, `move` — entry 3.

---

## Dispatch

**Four shapes, and 3tk has one ztk does not.**

### 17 — Dispatch — outer-first

*Carries over.*

**When to use.** You hold the outer, there are two or three identities, and
every branch wants the typed pointer straight away.

**Code shape.**

```c3
fn void free_outer(Slot* s)
{
    if (s.is_empty()) return;
    if (s.to(Event))  { mtk::managed::release(Event, s);  return; }
    if (s.to(Sensor)) { mtk::managed::release(Sensor, s); return; }
    if (s.to(Holder)) { mtk::managed::release(Holder, s); return; }
    unreachable("free_outer met an identity it was not written for");
}
```

**Why.**

- One call does the identity check and the crossing.
- The crossing returns null on a mismatch, so the calls chain.
- **This is the shape the shared release function takes**, and every example
  that receives from a mixed mailbox calls it rather than writing the chain
  again.

### 18 — Dispatch — identity-first

*Carries over.*

**When to use.** You have an identity and no outer. **`PoolHooks.on_get` is the
case that forces it**: it is given a `typeid` and an empty Slot, so there is
nothing to cross with.

**Code shape.**

```c3
struct CreateByIdentityHooks (PoolHooks)
{
    Allocator alloc;
}

fn void CreateByIdentityHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic
{
    if (want == Event::typeid)  { if (catch mtk::managed::create(Event,  self.alloc, slot)) {} return; }
    if (want == Sensor::typeid) { if (catch mtk::managed::create(Sensor, self.alloc, slot)) {} return; }
    if (want == Holder::typeid) { if (catch mtk::managed::create(Holder, self.alloc, slot)) {} return; }
    // an identity the pool was not created with never reaches here
}

fn void CreateByIdentityHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic {}

fn void CreateByIdentityHooks.on_close(&self, InnerQueue* remaining) @dynamic
{
    while (Handle h = remaining.pop_front())
    {
        Slot s;
        s.fill(h);
        free_outer(&s);
    }
}
```

**Why.**

- A bare `typeid` compares with `==`, and that is all this shape needs.
- **Leaving the Slot empty is how the hook reports failure**, and the caller
  gets `NOT_CREATED`. It is not the pool failing; it is the pool reporting what
  your hook did.
- **Fill it with the identity that was asked for.** Anything else is your bug,
  and a checking build catches it.
- The chain has no final branch here, and that is deliberate: the pool refuses an identity
  it was not created with before the hook is ever called, so the branch would
  be unreachable in the ordinary sense as well as the keyword one. **That is a
  closed set the toolkit closed for you** — see entry 21 for the sets it does
  not.

### 19 — Dispatch — switch

***This entry is the inversion.*** ztk's `rules-049.md` makes *No switch over
tags* a MUST. **In 3tk the same shape is permitted**, and it is the one place
where the port can write something the reference implementation cannot.

**When to use.** Four or more identities, a closed set, and one place that
decides.

**Code shape.**

```c3
fn void p19_switch_dispatch(Handle h)
{
    switch (h.link.type)
    {
        case Event::typeid:
            h.as(Event).code++;
        case Sensor::typeid:
            h.as(Sensor).reading++;
        case Holder::typeid:
            h.as(Holder).id++;
        default:
            unreachable("closed set: every identity is a prong");
    }
}
```

**Why the prohibition does not cross.**

- A ztk tag is the address of a global, which the linker assigns. A `switch`
  prong must be known while compiling, so the compiler accepts the source and
  the backend then fails.
- **A C3 `typeid` has no such problem.** It is a compile-time constant, and a
  prong takes it.
- `c3-capabilities-001.md` lines 147 to 162 measured this before the port had a
  pool. **It was re-measured live for this file**, in all four builds, with the
  block above.

**Why you would still write a chain.**

- Two or three identities read better as a chain, and the chain gives you the
  typed pointer in the same call.
- A `switch` prong asserts the identity with `as` rather than asking with `to`,
  because the prong has already proved it. That is right, and it also means the
  crossing is gone in a fast build — so an identity written into the wrong
  prong is a bug the fast build will not catch.

### 20 — Dispatch — table

*Changes shape.* ztk shipped `TagTable` as an example helper because the
handler's first parameter is the application's own type. **The same is true in
C3**, so this is an example helper here too, not a toolkit declaration.

**When to use.** Two receivers do different work with the same identity. **An
identity says what an outer *is*, not what a receiver should *do* with it**, so
the handler belongs to the pair — not to the identity, and not to a chain.

**Code shape.**

```c3
struct Counter { usz logged; usz counted; }

alias Handler = fn void(Counter*, Slot*);

struct Row  { typeid id; Handler handler; }
struct Table { Row[] rows; }

fn void? Table.dispatch(&self, Counter* c, Slot* s)
{
    if (s.is_empty()) return;
    typeid have = s.peek().link.type;
    foreach (row : self.rows)
    {
        if (row.id == have) { row.handler(c, s); return; }
    }
    return PATTERN_FAILED~;
}

fn void log_event(Counter* c, Slot* s)   { c.logged++; }
fn void count_event(Counter* c, Slot* s) { c.counted++; }

fn void? p20_table(Slot* s)
{
    Row[2] log_rows = { { Event::typeid, &log_event }, { Sensor::typeid, &log_event } };
    Row[1] count_rows = { { Event::typeid, &count_event } };

    Table log_table = { .rows = log_rows[..] };
    Table count_table = { .rows = count_rows[..] };

    Counter c;
    log_table.dispatch(&c, s)!;
    count_table.dispatch(&c, s)!;
}
```

**Why.**

- The same identity is in both tables against different handlers. **No chain
  can express that**, and no `switch` can either.
- **No allocator.** The rows are a local array the receiver owns.
- A miss is a fault and not a defect. Nothing was called and the outer never
  left the Slot, so — unlike the last branch of a chain — **the caller releases
  it**, because the caller knows its own identity set.
- **The handler follows the transfer rule.** On return the Slot is empty if the
  handler took the outer, full if it did not.

### 21 — The last branch of a dispatch chain

*Carries over, unchanged.* **Always write it.**

- **Closed set**, every identity in the chain: the last branch is
  `unreachable`, with the reason beside it.
- **Open set**, a mailbox anyone may send to: count it, report it, or return a
  fault. Then move on.

**It cannot release the outer.** Releasing needs the size, the size needs the
type, and an unknown identity gives neither. **Unknown memory belongs to
whoever knows what it is.**

**The transfer rule, for a handler you write.** A convention, not a MUST.

> On return the Slot is empty if the handler took the outer, full if it did
> not.

- **The Slot says where the outer went. The fault says whether the work
  succeeded.** They are two questions.
- A handler may move the outer and then fail. A caller that releases on a fault
  without reading the Slot releases something it no longer has.

### 22 — An identity names a type, not an instance

*Carries over.*

```
identity
    |
    v
  type
```

not

```
identity
    |
    v
 instance
```

- **An identity answers *what is this*.** Two mailboxes have the same identity;
  they are not the same mailbox.
- **A pointer comparison answers *which one*.** `mailbox::of(h) == worker_mbx`
  is the instance question, and both sides are a real `Mailbox*` — see entry 25.
- **A field you declare answers *what role*.** `kind`, `role`, `priority` are
  application data. Do not make a second outer type to carry what a field
  carries.

---

## The infrastructure is an outer too

**A mailbox is an outer. A pool is an outer.** Each embeds an inner and carries
an identity, so either can be sent through a mailbox or kept on a queue.

### 23 — A wrapper around an infrastructure pointer

*Changes shape.* ztk wrapped a `*Mbox` to give it a distinct tag. **3tk's
`Mailbox` and `Pool` are already public structs with real pointers**, so a
wrapper is not a workaround here — it is what you write when the endpoint alone
is not enough.

**When to use.** The receiver needs more than the endpoint: a job id, a
deadline, a reply address beside it.

**Code shape.**

```c3
struct WorkerInbox
{
    Inner       node;
    Allocator   alloc;
    Mailbox*    mbx;
    int         job_id;
}

fn void? p23_wrapper(Allocator a, Mailbox* to, Mailbox* inbox, int job_id)
{
    Slot s;
    defer mtk::managed::release(WorkerInbox, &s);
    mtk::managed::create(WorkerInbox, a, &s)!;

    WorkerInbox* w = s.must(WorkerInbox);
    w.mbx = inbox;
    w.job_id = job_id;

    to.send(&s)!;
}
```

**Why.**

- The wrapper has its own identity, distinct from `mailbox::TYPE`, so it
  dispatches like any other outer.
- **Wrap only when there is something to carry.** A mailbox travels on its own
  — entry 24 — and a wrapper that adds nothing is one more allocation and one
  more identity for no gain.
- The receiver reaches the endpoint through the field. `w.mbx` is a real
  `Mailbox*`, not a handle to convert.

### 24 — Mailbox as message

*Carries over.*

**When to use.** Giving an endpoint back: a worker reporting in, a topology
built at run time, a channel handed on.

**Code shape.**

```c3
fn void? p24_mailbox_as_message(Mailbox* to, Mailbox* travelling)
{
    Slot s;
    s.fill(mtk::mailbox::to_handle(travelling));
    to.send(&s)!;
}

fn Mailbox* p24_receive_mailbox(Slot* s) => mtk::mailbox::of(s.peek());
```

**Why.**

- `mailbox::to_handle` crosses out and `mailbox::of` crosses back, the same as
  any outer. `mailbox::TYPE` is the identity if you want to ask first.
- **A mailbox that is travelling is not closed.** It is still a working
  endpoint; it is the pointer that moved, not the queue.

### 25 — Worker-finish-signal

*Changes shape.* ztk awaited a `Future`. **3tk joins a thread**, and the
mailbox coming back is what says the work is done — not the join.

**When to use.** A worker signals that it has finished by sending its own
mailbox back.

**Code shape.**

```c3
fn void? p25_finish_signal(Mailbox* inbox, Mailbox* worker_mbx)
{
    Slot s;
    inbox.receive(&s, time::ms(1000))!;

    Mailbox* got = mtk::mailbox::of(s.take());
    if (got != worker_mbx) return PATTERN_FAILED~;

    InnerQueue left;
    got.close(&left);
    while (Handle h = left.pop_front())
    {
        Slot each;
        each.fill(h);
        free_outer(&each);
    }
    got.release();
}
```

**Why.**

- **The instance check is a real pointer comparison.** Both sides are
  `Mailbox*`. Under a handle-only API it compared two look-alike handles, and
  only the identity stood between a match and a silent mistake — entry 22.
- It replaces both a separate shutdown message and relying on the join, by
  moving something instead of signalling about it.
- The master closes and releases the worker's mailbox, **then** joins the
  thread. `close` before `release` is the one rule the toolkit will not let you
  break: releasing an open mailbox aborts in every build, including the fastest.

### 26 — Pool as message

*Carries over.*

**When to use.** Sharing one reuse policy between coordinators.

**Code shape.**

```c3
fn void? p26_pool_as_message(Mailbox* to, Pool* p)
{
    Slot s;
    s.fill(mtk::pool::to_handle(p));
    to.send(&s)!;
}
```

**Why.**

- A pool is an outer, so it crosses exactly as a mailbox does:
  `pool::to_handle`, `pool::of`, `pool::TYPE`.
- **The pool that travels is the policy that travels.** The hooks went in at
  creation and go wherever the pointer goes.

---

## Mailbox patterns

### 27 — Poll

*Carries over.*

**When to use.** A work loop that must not block.

**Code shape.**

```c3
fn void p27_poll(Mailbox* mb)
{
    Slot s;
    if (catch f = mb.poll(&s))
    {
        if (f == mtk::EMPTY) return;        // nothing queued, and this call does not wait
        return;                             // CLOSED
    }
    free_outer(&s);
}
```

**Why.**

- `EMPTY` is an answer, not a failure. It is the fault that says *there was
  nothing there*, reported in every build.
- Blocking is `receive` with a timeout. Emptying it in one go is
  `receive_all`.

### 28 — Receive everything at once

*Carries over.*

**When to use.** Empty a whole mailbox in one call.

**Code shape.**

```c3
fn void? p28_receive_all(Mailbox* mb)
{
    InnerQueue batch;
    mb.receive_all(&batch)!;
    while (Handle h = batch.pop_front())
    {
        Slot s;
        s.fill(h);
        free_outer(&s);
    }
}
```

**Why.**

- One lock instead of one per outer.
- The order is the order `receive` would have given: out-of-band first, then
  ordinary.
- **The outers are yours from that moment.** The mailbox never knew whether to
  release them.

### 29 — Out-of-band

*Carries over.*

**When to use.** Shutdown, and urgent control messages.

**Code shape.**

```c3
fn void? p29_oob(Mailbox* mb, Slot* s) => mb.send_oob(s);
```

**Why.**

- An out-of-band outer goes before every ordinary one, and stays first-in
  first-out among the other out-of-band ones.
- **One level, not a priority queue.** There is no second level to reach for,
  and building one on top means a second mailbox.

### 30 — Close recovery

*Carries over.*

**When to use.** Every close. **Not only the ones you expect to find something
in.**

**Code shape.**

```c3
fn void p30_close_recovery(Mailbox* mb)
{
    InnerQueue left;
    mb.close(&left);
    while (Handle h = left.pop_front())
    {
        Slot s;
        s.fill(h);
        free_outer(&s);          // release it, or give it back to a pool
    }
    mb.release();
}
```

**Why.**

- The mailbox never touches an outer, so everything it kept comes back to
  someone. **At close that someone is you.**
- Which release applies — free it, or return it to a pool — is yours to know.
  The mailbox does not know and never did.
- **Run the loop unconditionally.** `close` may be called more than once and
  gives back an empty queue after the first, so the same three lines are right
  on a mailbox with outers in it, on an empty one, and on one closed twice.
  Nothing has to work out which it is looking at.

**Do not discard the queue.** Those outers keep their links, so a later attempt
to send one is refused — which means the mistake surfaces at the first reuse
rather than somewhere unrelated later.

### 31 — Release a refused transfer

*Carries over.*

**When to use.** Every `send` that may meet a closed mailbox, and every `put`
that may meet a closed pool.

**Code shape.**

```c3
fn void? p31_refused(Mailbox* mb, Pool* p, Slot* s)
{
    if (catch f = mb.send(s))
    {
        p.put(s);                // it came from the pool, it goes back there
        return f~;
    }
}
```

**Why.**

- **A refused transfer did not happen.** `send` returns `CLOSED` before it
  empties the Slot, and `put` on a closed pool leaves the Slot full. Either
  way the outer is still yours.
- The defer-first shapes of entries 6, 7 and 9 already cover this. A bare
  `send` with no defer and no catch does not.

### 32 — Wake without a message

*Carries over.*

**When to use.** A flag changed outside the mailbox and a blocked receiver has
to look at it again.

**Code shape.**

```c3
fn void? p32_wake(Mailbox* mb, Atomic{bool}* stopping)
{
    stopping.store(true, RELEASE);
    mb.wake_all()!;
}

fn void p32_receiver(Mailbox* mb, Atomic{bool}* stopping)
{
    while (true)
    {
        Slot s;
        if (catch f = mb.receive(&s, time::ms(500)))
        {
            if (f == mtk::WOKEN) { if (stopping.load(ACQUIRE)) return; continue; }
            return;
        }
        free_outer(&s);
    }
}
```

**Why.**

- **It is not a close.** The mailbox is not taken down, and sending still works
  afterwards.
- **It is not a send.** Nothing is queued, so there is no outer to release.
- **Only receivers already blocked when it is called report `WOKEN`.** A
  receiver that starts waiting afterwards is unaffected — the wake does not
  linger.

---

## Topology patterns

**Each is a composition of the mailbox patterns above, not a new mechanism.**
The diagrams are the pattern; the code is the mailbox calls already given.

### 33 — Request-Response

*Carries over.*

**When to use.** One side asks, the other answers, on two dedicated mailboxes.

```
main ---Event(request)---> req_mbx ---> worker
                                          | process
                                          v
main <--Event(response)--- resp_mbx <--- worker
```

**Why.**

- **Two mailboxes, never one.** On one mailbox the caller can receive its own
  request back.
- The caller blocks on `resp_mbx` with a timeout. The worker loops on `req_mbx`
  until it is closed.

### 34 — Pipeline

*Carries over.*

**When to use.** A chain of stages, each transforming and passing on.

```
producer --Event--> stage1 --> transform --Event--> stage2 --> consumer
```

**Why.**

- Each stage has one outer at a time, so the Slot idiom holds at every hop.
- **An end-of-stream marker travels the chain like anything else** — a `code`
  value, or an identity of its own. The last stage releases it.

### 35 — Fan-In

*Carries over.*

**When to use.** Several senders, one mailbox, one receiver.

```
sender A --->
sender B ---> mailbox --receive_all--> one receiver, dispatch by identity
sender C --->
```

**Why.**

- **The mailbox does the merging.** There is no separate synchronization to
  write.
- `receive_all` plus an outer-first chain empties it in one pass, mixed
  identities and all.

### 36 — Fan-Out

*Carries over.*

**When to use.** Several worker threads compete for the outers on one mailbox.

```
main --outers--> mailbox ---> worker A
                        |---> worker B      each outer goes to exactly one
                        '---> worker C
```

**Why.**

- **The mailbox does the distribution.** No round-robin in application code.
- `close` gives back whatever no worker claimed, and the closer releases it —
  every time. Entry 30.

---

## Pool patterns

### 37 — `AVAILABLE_OR_NEW`

*Carries over.*

**When to use.** The common case: reuse a kept outer if one is free, otherwise
ask the hook for a fresh one.

**Code shape.**

```c3
fn void? p37_available_or_new(Pool* p)
{
    Slot s;
    defer p.put(&s);
    p.get(Holder::typeid, AVAILABLE_OR_NEW, &s)!;
    s.must(Holder).id = 1;
}
```

**Why.**

- The hook runs only when nothing was kept.
- `NOT_CREATED` means your own `on_get` produced nothing. **It is not the pool
  failing; it is the pool reporting what your hook did.**

### 38 — `NEW_ONLY`

*Carries over.*

**When to use.** Seeding. You want a fresh outer every time, never a kept one.

**Code shape.**

```c3
fn void? p38_new_only(Pool* p)
{
    Slot s;
    p.get(Holder::typeid, NEW_ONLY, &s)!;
    s.must(Holder).id = 0;
    p.put(&s);
}
```

**Why.**

- The hook runs every time, so the pool grows by exactly the number of calls.
- This is how a fixed-size pool is filled at startup — entry 40.

### 39 — `AVAILABLE_ONLY`

*Carries over.*

**When to use.** Consume what is kept, and stop when there is none.

**Code shape.**

```c3
fn usz p39_available_only(Pool* p)
{
    usz taken;
    while (true)
    {
        Slot s;
        if (catch f = p.get(Holder::typeid, AVAILABLE_ONLY, &s))
        {
            if (f == mtk::NOT_AVAILABLE) break;      // a normal end, not a failure
            break;
        }
        taken++;
        mtk::managed::release(Holder, &s);
    }
    return taken;
}
```

**Why.**

- **`NOT_AVAILABLE` is the end condition**, and it is reported in every build.
- The hook is never called on this path, so nothing is created behind your
  back.
- `get_wait` is the other no-create path: it waits for someone to give an outer
  back, and says `TIMEOUT` where this says `NOT_AVAILABLE`. **Do not reach for
  it expecting creation under load.**

### 40 — Seeding a fixed-size pool

*Carries over.*

**When to use.** The size is decided once at startup and the pool never grows.

**Code shape.**

```c3
fn void? p40_seed(Pool* p, Allocator a, usz n)
{
    for (usz i = 0; i < n; i++)
    {
        Slot s;
        defer mtk::managed::release(Holder, &s);
        mtk::managed::create(Holder, a, &s)!;
        p.put(&s);                           // the defer releases it only if the pool refused
    }
}
```

**Why.**

- Pair it with an `on_get` that leaves the Slot empty. Then the pool never
  grows past the seed count, and `AVAILABLE_OR_NEW` reports `NOT_CREATED` when
  the seed is exhausted.
- **The seed count becomes the backpressure limit.** That is the whole
  mechanism; there is no separate one.

### 41 — The pool holds no policy

*Carries over.*

**When to use.** Always. It is not optional — **there is no pool without
hooks**, and they are a parameter of creation.

```
on_get
    |
    +-- the Slot comes in empty
    '-- fill it, or leave it empty and the caller gets NOT_CREATED

on_put
    |
    +-- leave the Slot full   -> the outer is kept
    '-- empty the Slot        -> the outer is not kept, and it is yours to release
```

**Why.**

- The pool does not know how to make an outer, how to clean one, or how to
  release one. **You supply that, and it stays out of the calling code.**
- **A full Slot on return from `on_put` means one thing: an outer is kept.**
  Original or replacement, the pool does not care which.
- The four outcomes of `on_put` — keep it, keep it cleaned, release it, keep a
  different one instead — are all just *what is in the Slot when you return*.

### 42 — The hook object is the context

***New, and 3tk-only.*** ztk threaded a `ctx: *anyopaque` through every hook and
cast it back at the top of each one. **3tk has no `ctx` parameter at all.**

**When to use.** Every hook object.

**Code shape.**

```c3
struct CappedHooks (PoolHooks)
{
    Allocator     alloc;
    usz           cap;
    Atomic{usz}   live;
}

fn void CappedHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic
{
    if (self.live.load(ACQUIRE) >= self.cap) return;      // empty Slot -> NOT_CREATED
    if (catch mtk::managed::create(Holder, self.alloc, slot)) return;
    self.live.add(1);
}

fn void CappedHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic
{
    Holder* h = slot.must(Holder);
    h.id = 0;                                             // cleaned, and kept
}

fn void CappedHooks.on_close(&self, InnerQueue* remaining) @dynamic
{
    while (Handle h = remaining.pop_front())
    {
        Slot s;
        s.fill(h);
        self.live.sub(1);
        mtk::managed::release(Holder, &s);
    }
}
```

**Why.**

- `PoolHooks` is an interface. **The struct implementing it is the context**,
  so its fields are reached as `self.alloc` with no cast and no way to get the
  cast wrong.
- The three methods are `@dynamic`, and that is the whole declaration cost.
- **This is also the shape the port's own tests and negative programs use**, so
  an example written this way matches everything else in the tree.

### 43 — A hook runs outside the lock

*Changes shape.* The reason is unchanged; the tool is not. There is no
`Io.Mutex` — use `std::thread`'s mutex, or an atomic.

**When to use.** Any hook that touches state shared between threads.

**Why, and this one is measured.**

- **A hook runs with no pool lock held, and several may run at once on
  different threads.** The pool does not serialize them.
- **A plain counter in a hook is a data race.** The port's own tests had
  exactly that bug: three producers and three consumers on plain `usz`
  counters, and a ThreadSanitizer run caught it.
- The fix belongs in the hook, not in the pool. Holding the pool's lock across
  a hook would silence the warning by breaking the contract that makes a hook
  safe to write at all — a hook may take as long as it likes.
- Entry 42's `Atomic{usz}` is that fix in its smallest form.

**A hook must not call back into the pool, and must not block or wait.**

### 44 — The `on_close` hook

*Carries over.*

**When to use.** Always. **Nobody else will.**

**Code shape.** Entry 42's `on_close`, and the two properties that shape it.

**Why.**

- **A pool gives its remainder to the hook. A mailbox gives its remainder to
  the caller.** That is the opposite way round, and it is worth holding in
  mind.
- Everything left comes as one flat queue, every identity mixed together, in no
  promised order. So the loop body is a dispatch chain — entry 17.
- `pop_front` resets the handle before it returns it, so it drops straight into
  a Slot. There is no separate unlink step.
- **It may be called more than once.** Once from `close`, and again with
  stragglers from a `put` whose hook was still running when the close happened.
  **So do not release your own context on the first call**, and write the loop
  so a second call with two outers in it is harmless. The loop above already
  is.

### 45 — A pool of several identities

*Carries over.*

**When to use.** One reuse policy over more than one kind of outer.

**Code shape.**

```c3
fn Pool*? p45_multi(Allocator a, CreateByIdentityHooks* hooks)
{
    typeid[3] ids = { Event::typeid, Sensor::typeid, Holder::typeid };
    return mtk::pool::create(a, &ids, hooks);
}
```

**Why.**

- One policy object, and **a separate free list per identity**.
- **The set is fixed at creation and cannot be empty.** Asking for an identity
  the pool was not created with is a bug, not a runtime condition: a checking
  build aborts, and a fast build gives `UNKNOWN_IDENTITY` so it says what is
  wrong instead of quietly waiting out your timeout.
- **Duplicates in the list are refused at creation**, in a checking build.
- This is what makes entry 18 necessary. With one identity `on_get` has nothing
  to decide; with three it does.

---

## Shutdown

**3tk has no cancellation.** ztk's *Cancellation boundary*, *Cancellation keeps
the item where it is* and *Close versus Cancel* have nothing to land on: there
is no `error.Canceled`, no cancel token and no cancelable wait. **A wait ends on
an outer, a close, a wake, or the timeout. Nothing else.** That absence is why
the three entries drop rather than change shape, and why nothing below has to
distinguish a close from a cancel.

### 46 — Reading the fault on a receive

*Changes shape.* Four outcomes in 3tk where ztk had four different ones.

**When to use.** A worker blocked on `receive` or `get_wait` that must react to
each outcome.

**Code shape.**

```c3
fn void? p46_receive_faults(Mailbox* mb)
{
    while (true)
    {
        Slot s;
        if (catch f = mb.receive(&s, time::ms(250)))
        {
            if (f == mtk::CLOSED)  return;            // end of stream — leave cleanly
            if (f == mtk::WOKEN)   continue;          // a poke — look at the state and keep waiting
            if (f == mtk::TIMEOUT) continue;          // the window passed — your domain decides
            return f~;
        }
        free_outer(&s);
    }
}
```

**The distinction.**

- **`CLOSED`** — someone closed the source. End of stream. Leave.
- **`WOKEN`** — a `wake_all`. No outer, nothing queued. Look at whatever
  changed and keep waiting.
- **`TIMEOUT`** — the wait window passed. It says nothing about the mailbox.
- **`EMPTY`** — only from `poll`, and only because `poll` never waits.

**Never treat `WOKEN` as `CLOSED`.** They mean different things, and a worker
that leaves on a poke leaves work behind.

### 47 — The shutdown order

*Changes shape.* ztk's nine steps had `group.await` in them. **The order is the
same and the reason is the same**; the wait is `Thread.join`.

**The order.**

1. Stop producing. Nothing new goes in.
2. Close the mailbox that feeds the workers. **That is the end-of-stream
   signal** — every blocked receiver reports `CLOSED`.
3. Walk what `close` gave back and release or recycle every outer — entry 30.
4. Join every worker thread.
5. Release the worker mailbox.
6. Close any downstream mailbox. Its thread leaves on `CLOSED`.
7. Join that thread, and release its mailbox.
8. Close the pool. `on_close` gets everything kept.
9. Release the pool.

**Why this order.**

- **Close upstream before joining, or the workers wait forever.**
- **Join before closing the pool, or a worker gives an outer back to a closed
  pool.** That is not a crash — the pool leaves the Slot full and the outer
  stays with the worker — but it is the fallback path of entry 9 running for a
  reason you could have avoided.
- **Close before release, both times.** Releasing an open mailbox or an open
  pool aborts **in every build mode, including the fastest**. They are the two
  places where a mistake loses outers with no trace, so they are checked even
  where nothing else is.

### 48 — Shutdown by message

*Carries over.*

**When to use.** The mailbox must stay open and reusable, and the worker still
has to leave cleanly.

```
main --Event x N--> mailbox --> worker, processing and releasing each
main --Command----> mailbox --> worker recognizes the identity, releases it, leaves
                                (the mailbox is still open)
```

**Why.**

- A marker outer travels the mailbox like anything else, and the worker
  recognizes it by identity.
- **Closing cannot be undone**, so this is the shape when the mailbox is to be
  used again afterwards.
- Use entry 47 instead when a pool has to empty in step with the mailbox. A
  marker alone coordinates nothing but the one worker that reads it.

---

## Coordinator patterns

**The shapes that carry the *Two levels* rule** of
[3tk-example-rules-001.md](3tk-example-rules-001.md).

### 49 — The coordinator

*Carries over.*

**When to use.** Any function that sequences discrete steps.

**Code shape.**

```c3
struct Master
{
    Allocator alloc;
    Mailbox*  mbx;
    Pool*     pool;
    usz       processed;
}

fn void? Master.run(&self)
{
    self.seed_the_work()!;
    self.process_the_work()!;
    self.shut_down();
    if (self.processed == 0) return PATTERN_FAILED~;
}
```

**Why.**

- **The body is calls to named steps.** The whole flow is visible without
  opening anything.
- A guard, one check and one log line stay inline. **A block with a purpose of
  its own is extracted and named.**
- A comment explaining a block is the signal the block wanted a name.

### 50 — The step

*Carries over.*

**When to use.** One discrete phase of a coordinator.

**Code shape.**

```c3
fn void? Master.process_the_work(&self) { return self.mbx.wake_all(); }

fn void? Master.seed_the_work(&self)
{
    for (int i = 1; i <= 4; i++)
    {
        Slot s;
        defer mtk::managed::release(Event, &s);
        mtk::managed::create(Event, self.alloc, &s)!;
        s.must(Event).code = i;
        self.mbx.send(&s)!;
    }
}
```

**Why.**

- One thing, and **the name is the documentation**.
- A loop is one unit at its level. Declarations are fine.
- Everything the step needs is on `self` or in its parameters. **A step reaches
  for no global.**

### 51 — Acquiring the resources

*Changes shape*, and this is the sharpest difference from ztk in the whole
section. **`mailbox::create` and `pool::create` return a pointer, not a Slot.**
There is no acquisition Slot, no detach line, and no window between them to
guard.

**When to use.** Building a coordinator and its resources.

**Code shape.**

```c3
fn Master*? master_create(Allocator a, PoolHooks hooks)
{
    Master* self = alloc::new_try(a, Master)!;
    self.alloc = a;
    self.processed = 0;

    typeid[1] ids = { Event::typeid };
    self.mbx = mtk::mailbox::create(a)!;
    self.pool = mtk::pool::create(a, &ids, hooks)!;
    return self;
}
```

**Why.**

- Each resource is a plain `Mailbox*` or `Pool*` field, **never an optional and
  never a Slot**. There is nothing to unwrap at every use.
- ztk needed a Slot per resource because its `new` filled one. 3tk's `create`
  hands back the pointer, so the Slot, the detach and the window all go away
  together.
- **What does not go away is the order.** If the pool's create fails, the
  mailbox above it is open and allocated, and this shape leaks it. **A
  coordinator with two resources acquires them in a step that can undo the
  first**, or acquires them in the caller where the release path is already
  written. That is the one thing the Slot shape used to give for free.

### 52 — Releasing the resources

*Changes shape.* `close` and `release` are two calls in 3tk, and the pool's
`close` gives nothing back.

**When to use.** Taking a coordinator down.

**Code shape.**

```c3
fn void Master.shut_down(&self)
{
    InnerQueue left;
    self.mbx.close(&left);
    while (Handle h = left.pop_front())
    {
        Slot s;
        s.fill(h);
        free_outer(&s);
    }
    self.mbx.release();

    self.pool.close();                 // on_close gets everything kept
    self.pool.release();
    alloc::free(self.alloc, self);
}
```

**Why.**

- **Reverse acquisition order**, and the allocation goes last.
- The mailbox's remainder is walked; the pool's remainder is the hook's.
- **Close before release, both times**, and see entry 47 for what happens if
  not.

### 53 — The thread is given one pointer

*Changes shape.* `io.concurrent` is `thread::create`, and the argument is a
`void*`.

**When to use.** Starting a worker.

**Code shape.**

```c3
struct WorkerCtx
{
    Mailbox*    mbx;
    Allocator   alloc;
    Atomic{usz} done;
}

fn int worker_main(void* arg)
{
    WorkerCtx* ctx = (WorkerCtx*)arg;
    while (true)
    {
        Slot s;
        if (catch mb_receive(ctx.mbx, &s)) break;
        free_outer(&s);
        ctx.done.add(1);
    }
    return 0;
}

fn void? mb_receive(Mailbox* mb, Slot* s) => mb.receive(s, time::ms(500));

fn void? p53_spawn(WorkerCtx* ctx)
{
    Thread t;
    t.create(&worker_main, ctx)!;
    t.join()!;
}
```

**Why.**

- **One pointer in, and no thread-local bookkeeping.** The context struct is
  the single source of truth, reachable through the one pointer the thread was
  given.
- The context outlives the spawn and is taken down only after the join. **The
  thread holds nothing the joiner cannot reach.**
- Anything the thread and the joiner both touch is atomic — entry 43's reason,
  in the coordinator instead of in a hook.

### 54 — Spawn and join in one step

*Changes shape.* Same rule, threads instead of a group.

**When to use.** The coordinator starts workers and waits for them.

**Why.**

- **The declarations, the spawns and the joins all live inside the named
  step**, not inline in the coordinator. The coordinator sees one call.
- **If nothing happens between spawn and join, they are one step.** If the
  coordinator does something in between — closing the source mailbox, for
  instance — they are two, and entry 47 says what goes in between.

### 55 — More than one coordinator

*Carries over.*

**When to use.** A program has more than one coordination boundary.

**Why.**

- **Each coordinator owns its resources and takes them down itself.**
- A coordinator is a struct plus a loop function. **It is not inlined into
  `run`.**
- `run` shows the start order and the shutdown order, and nothing else.

### 56 — Pool and mailbox together

*Carries over.*

```
pool
  | get
  v
work
  | send
  v
mailbox
```

**Why.**

- **The pool is where an outer comes from and goes back to. The mailbox is how
  it travels.** They answer different questions and neither substitutes for the
  other.
- The two shutdowns are ordered against each other, not independent — entry 47.
- **A pool outer is an empty container on acquisition.** The intent comes from
  outside the pool, always.

---

## New, and 3tk-only

**Seven shapes with no ztk entry behind them — six here, and entry 42**, which
sits with the pool patterns because that is where it is read.

### 57 — The allocator in the outer

**When to use.** Any outer with a lifetime, which is nearly all of them.

**Code shape.**

```c3
struct Buffer
{
    Inner     node;
    Allocator alloc;
    char[64]  bytes;
}

fn void? p57_allocator_in_outer(Allocator a)
{
    Slot s;
    defer mtk::managed::release(Buffer, &s);
    mtk::managed::create(Buffer, a, &s)!;
}
```

**Why.**

- **`release` takes no allocator.** The outer kept the one it was made with.
- That is what makes **cleanup-before-acquisition** possible at all. A release
  that needed an allocator would need one on the failure path too, where there
  may be nothing to hand it.
- **Taking the helper is the choice, and it is made at the call site, per
  call.** There is no marker to set and no type to declare.
- **The build refuses it if the field is not there**, and names your type and
  the helper to use instead. `negative/nocompile_managed_no_allocator.c3` is
  that refusal.
- *Managed* means one thing. Nothing collects, traces, or runs in the
  background.

### 58 — An identity costs no registration

**When to use.** Declaring a new outer type.

**Code shape.**

```c3
struct Ticket { Inner node; Allocator alloc; int seq; }

fn void? p58_new_type_costs_nothing(Allocator a, Mailbox* mb)
{
    Slot s;
    defer mtk::managed::release(Ticket, &s);
    mtk::managed::create(Ticket, a, &s)!;
    s.must(Ticket).seq = 1;
    mb.send(&s)!;
}
```

**Why.**

- **Two lines added a type to the program**: the struct, and the calls that use
  it. No alias, no helper instantiation, no registration list.
- The identity is `Ticket::typeid`, which the compiler already has. `init`
  writes it into the outer once, and nothing computes it again.
- **This is why a pool takes a `typeid[]` and not a set of declared helpers**,
  and why entry 18's chain is `==` on a plain value.

### 59 — The optional-declaration walk

**When to use.** Every loop over a queue, an iterator, or anything that gives
back a `Handle` and uses null to mean *no more*.

**Code shape.**

```c3
fn usz p59_walk(InnerQueue* q)
{
    usz n;
    while (Handle h = q.pop_front()) { n++; }
    return n;
}
```

**Why.**

- **The declaration is the condition.** The handle is in scope inside the body
  and nowhere else, so there is no variable left over to use by mistake after
  the loop.
- It is the same shape for `pop_front`, for `InnerQueueIterator.next`, and for
  `InnerStack.pop`. **One loop shape for every take in the toolkit.**
- The crossings compose with it: `if (Event* e = h.to(Event))` is the same
  construct one level in, which is what makes entry 17's chain read as a chain.

### 60 — Guarding an expensive check

**When to use.** An example or an application wants a check that is worth its
cost in a checking build and not worth it in a fast one.

**Code shape.**

```c3
fn void p60_guarded(InnerQueue* q, Handle h)
{
    mtk::@check(h != null, "this walk was given a handle");

    if (mtk::CHECKED)
    {
        usz n;
        InnerQueueIterator it = q.iter();
        while (Handle each = it.next()) { n++; }
        mtk::@check(n == q.len(), "the queue's kept count matches its chain");
    }
}
```

**Why.**

- **`@check` is the toolkit's own abort**, and under `--safe=no` it expands to
  nothing — argument and all. So the condition costs nothing there.
- **`CHECKED` is the same question as a value**, for a block that is too
  expensive to write inside the argument. An O(n) walk beside an O(1) counter
  is the case it exists for.
- The two together are how the port checks its own containers, and they are
  public because an application has the same problem.

### 61 — A composite outer gives back its parts

**When to use.** The outer being given back to a pool is made of parts that
should go back too.

**Code shape.**

```c3
struct PartHooks (PoolHooks) { Allocator alloc; }

fn void PartHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic
{
    if (catch mtk::managed::create(Holder, self.alloc, slot)) {}
}

fn void PartHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic
{
    Holder* h = slot.must(Holder);
    h.id = 0;
    // whatever this outer was carrying goes back the same way:
    // extra.push_back(mtk::helper::to_handle(part));
}

fn void PartHooks.on_close(&self, InnerQueue* remaining) @dynamic
{
    while (Handle h = remaining.pop_front())
    {
        Slot s;
        s.fill(h);
        free_outer(&s);
    }
}
```

**Why.**

- **`extra` is taken the same way the Slot is**, with the same checks, so a
  part goes back to its own free list without a second call.
- It is the pool's answer to a composite outer, and it exists because the
  alternative — a hook calling back into the pool — is refused: **a hook must
  not call back into the pool.**
- Leave it empty and nothing happens. It costs nothing when it is not used.

### 62 — What a fast build stops checking

**When to use.** Deciding which build to test in. **Test in a checking one.**

**Two tiers, and knowing which is which says what you are still protected
from.**

- **Gone under `--safe=no`** — every contract check. Filling a full Slot,
  inserting an outer already on a chain, sending from an empty Slot, asking a
  pool for an identity it does not hold, a hook returning the wrong identity.
  **These are your bugs, and a fast build stops looking for them.**
- **Never gone, in any build** — releasing an open mailbox, and releasing an
  open pool. Both abort. **They are the two places where a mistake loses outers
  with no trace**, so they are checked even where nothing else is.

**Why this is a pattern and not a footnote.**

- Every defer-first shape above depends on a check being live to catch the case
  it is protecting against. In a fast build the shape is still right; **the
  diagnosis is gone.**
- **The checks are the documentation of what you are not allowed to do**, and
  they are worth more than the speed while the code is still being written.
- `mtk::CHECKED` is how a program asks which build it is in — entry 60.

---

## The 18 that dropped

**Named so no later stage looks for them and concludes they were forgotten.**

| ztk entry | why it does not cross |
|---|---|
| Direct Future | C3 has no `Future` |
| Future cancellation | and no cancellation |
| Event loop — register, await, re-register | `Io.Select` |
| Mailbox as event source | `Io.Select` |
| Pool as event source | `Io.Select` |
| Mixed event sources | `Io.Select` |
| Backpressure via getWaitResult in Select | `Io.Select`. **The mechanism survives** — a seeded pool is the limit, entry 40 |
| Direct push — putOneUncancelable | `Io.Select` |
| Receive router — one registration, many events | `Io.Select` |
| Graceful cancel walk — recover in-flight items | `Io.Select`, and cancellation |
| cancelDiscard — timer-only or no-item sources | `Io.Select`, and cancellation |
| Worker set — concurrent then await | `Io.Group`. **The purpose survives** as threads, entries 53 and 54 |
| Reusable Group | `Io.Group` |
| Shutdown signal — close the source mailbox | `Io.Group`. **The purpose survives** as step 2 of entry 47 |
| Shutdown signal — group.cancel | `Io.Group`, and cancellation |
| Cancellation boundary | no cancelable wait exists |
| Cancellation keeps the item where it is | the same |
| Close versus Cancel | there is no cancel to distinguish close from |
| Coordinator with Select event loop (flat file) | `Io.Select` |
| Full Layer-4 architecture | `Io.Select` at the top of the diagram |

**Twenty rows, and the count is twenty.** Two of them lost their mechanism and
kept their purpose, and the row says where the purpose went: a worker set is
threads, and closing the source mailbox is step 2 of the shutdown order. **The
entry dropped; the thing it was for did not.**

## What this document does not do

- **It writes no code**, and it creates no `examples/` folder.
- **It does not assign a pattern to a file.** The mapping comes after the
  catalog, which is the owner's ruling of 2026-08-26.
- **It does not restate the reference.** A pattern is an assembly of the
  surface; [3tk-api-002.md](3tk-api-002.md) is the surface.
- **It does not invent a pattern 3tk cannot support.** Every shape here
  compiles.
- **It changed nothing in `3tk/src`.**
