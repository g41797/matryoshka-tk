# 3tk — using the toolkit

**For the person calling it.** What each thing is for, when to reach for it,
and what it refuses to do.

**It is a skeleton.** The shape is right; the depth grows.

**It argues nothing and cites nothing.** No decision numbers, no specification
clauses, no design documents. If a sentence here needs a reason to be believed,
the sentence is wrong and should be fixed rather than footnoted.

**Its two neighbours, for a different reader.**

- [3tk-api-003.md](3tk-api-003.md) — the same surface as a verification table:
  every assert and contract copied from the source with its `file:line`. Read
  it to check that this page is telling the truth. Do not read it to learn the
  toolkit.
- [3tk-decisions-002.md](3tk-decisions-002.md) — why any of it is the way it
  is.

---

## What it is

**A toolkit for moving your own structs between containers, without the
containers ever allocating.**

You declare a struct. You embed one `Inner` in it. From then on that struct can
sit in a queue, wait in a mailbox, or rest in a pool, and none of those
containers allocates a node for it — **your struct is the node.**

    struct Msg { int id; Inner node; char[8] body; }

That is the entire cost of joining: one field, sixteen bytes, and one call to
`init` before first use.

**The memory stays yours.** The toolkit never frees your item. It never copies
it. It moves a pointer to it, and it tells you — every time — whether the item
is now its problem or still yours.

## What it is not

**It is not a container library.** The queue and the stack exist because the
mailbox and the pool need them. If you want a general list, use the standard
library.

**It is not a memory manager.** One helper will allocate and free for you, and
only if your struct carries the allocator itself.

**It does not know what your items are.** A mailbox handing you a batch cannot
tell you whether to free them or return them to a pool. It never knew.

## The five words

**Outer** — your struct. The one that embeds an `Inner`. It is a category, not
a type: there is no `Outer` in the source and you never name one.

**Inner** — the field you embed. Sixteen bytes. Every item in your program pays
for it, which is why there is exactly one and why nothing else was added to it.

**Handle** — a pointer to an inner, with the type forgotten. This is what
containers hold. It is `Inner*` under an alias, so it costs nothing.

**Identity** — which type an item really is. Written once by `init`, stored in
the item, never computed. This is what lets a container hold three different
types at once and lets you get the right pointer back.

**Slot** — a box that holds one handle, or nothing. **This is the part worth
slowing down for**, and it has its own section below.

---

## Your first item

    import mtk;
    import mtk::helper;

    struct Msg { int id; Inner node; char[8] body; }

    Msg m;
    m.id = 7;
    mtk::helper::init(&m);              // once, before anything else

    Handle h = mtk::helper::to_handle(&m);

    InnerQueue q;
    q.push_back(h);
    ...
    Msg* back = q.pop_front().to(Msg);  // null if it was not a Msg

**`init` before first use, always.** An item that was never initialized carries
no identity, and every crossing refuses it rather than guessing. That refusal
is the whole point: a struct you forgot to initialize does not silently become
whatever type you asked for.

**A new struct type costs no setup.** No alias to declare, no instantiation, no
registration. Declare it, embed an `Inner`, cross with it.

**The build catches the two mistakes it can catch.** A struct with no `Inner`
field, or with two, does not compile — and the message names your type.

---

## The Slot idiom

**A Slot is how the toolkit tells you where an item went.** Not the return
value. Not an error code. **The Slot.**

    empty  →  the item is somewhere else, and not your problem
    full   →  the item is here, and it is yours to deal with

**Every call that gives you an item takes an empty Slot and fills it. Every
call that takes an item from you takes a full Slot and empties it.**

    Slot s;
    s.fill(mtk::helper::to_handle(&m));

    mb.send(&s)!;                       // s is empty now — the mailbox has it

If a send is refused, **the Slot is untouched and the item is still yours.**
That is the property to build on:

    Slot s;
    s.fill(h);
    if (catch f = mb.send(&s))
    {
        // f == mtk::CLOSED, and s is still full.
        // You still have the item. Free it, or send it elsewhere.
    }

**Reading a Slot.**

- `is_empty` / `is_full` — the question, either way round.
- `peek` — look at the handle, change nothing.
- `take` — remove the handle and clear the Slot.
- `fill` — put a handle in. **A full Slot is never overwritten**; in a checking
  build that aborts.

**Getting your typed pointer back out**, three ways, and the third is usually
the one you want:

    Msg* p = s.to(Msg);        // null if it is not a Msg. Slot untouched.
    Msg* q = s.must(Msg);      // asserts it is a Msg. Slot untouched.
    Msg* r = s.move(Msg);      // null if not a Msg; on a match, Slot cleared.

**`move` is the acquisition idiom.** It gives you the pointer and empties the
Slot in one step, so there is no window where you hold both.

**A Slot starts empty on its own.** `Slot s;` is ready to use. There is no
initializer to forget.

---

## Crossing the border — `mtk::helper`

**Every conversion between your typed pointer and a handle happens here.** That
is deliberate: the pointer arithmetic exists in one file, so there is one place
to audit and one place to be wrong.

**Going out never fails.**

    Handle h = mtk::helper::to_handle(&m);    // null in, null out

**Coming back names a type, and you pick how strict.**

| you write | on a type mismatch |
|---|---|
| `h.to(Msg)` / `from_handle(h, Msg)` | returns null |
| `h.as(Msg)` / `must_from_handle(h, Msg)` | asserts, and is gone in a fast build |
| `s.to(Msg)` / `from_slot(&s, Msg)` | returns null, Slot untouched |
| `s.must(Msg)` / `must_from_slot(&s, Msg)` | asserts, Slot untouched |
| `s.move(Msg)` / `move_from_slot(&s, Msg)` | returns null, Slot untouched |

**Use the checking form when a mismatch is normal.** Walking a queue that holds
three types, you will meet the other two, and null is the answer — not a
failure.

    while (Handle h = q.pop_front())
    {
        if (Msg* m = h.to(Msg))  { handle_msg(m);  continue; }
        if (Job* j = h.to(Job))  { handle_job(j);  continue; }
        // something else
    }

**Use the asserting form when a mismatch is your bug.** It costs nothing in a
fast build, because it is gone there.

**`is_mine(h, Msg)`** answers the question on its own, if you want to ask
before crossing. A null handle is not yours. An item that was never
initialized is not yours either.

---

## When the item keeps its own allocator — `mtk::managed`

**Reach for this when you want a release that does not make you remember which
allocator you used.**

**The condition: your struct carries an `Allocator` field.**

    struct Holder { int id; Inner node; Allocator alloc; }

    Slot s;
    mtk::managed::create(Holder, mem, &s)!;
    ...
    mtk::managed::release(Holder, &s);

**`create` allocates**, writes the allocator into the item, initializes it, and
fills your Slot. **If the allocation fails, the Slot is untouched** — so the
usual defer-first shape is safe:

    Slot s;
    defer mtk::managed::release(Holder, &s);   // harmless if create failed
    mtk::managed::create(Holder, mem, &s)!;

**`release` takes no allocator.** The item kept it. Releasing an empty Slot
does nothing, which is what makes the line above legal.

**If your struct has no `Allocator` field, the build stops and tells you to use
`mtk::helper` instead.** There is no marker to set and no type to declare —
taking this helper *is* the choice, and it is made at the call site, per call.

**Nothing here collects, traces, or runs in the background.** *Managed* means
one thing: the item keeps its allocator, so its release takes none.

---

## The two containers — `InnerQueue`, `InnerStack`

**Neither allocates. Everything is constant-time. Nothing here can fail** — a
take from an empty container returns null, and null is an answer.

**An item can be on one chain at a time.** Inserting an item that is already on
a chain — this one or any other — is a bug, and a checking build aborts on it.
The test for that is exact, so it catches the case of an item alone on a list,
which is where this kind of bug usually hides.

### `InnerQueue` — first in, first out

**This is the one you will see.** Every batch the toolkit gives back to you is
an `InnerQueue`.

    InnerQueue q;
    q.push_back(h);
    q.push_back_slot(&s);          // takes from a Slot, clears it

    Handle h = q.pop_front();      // null when empty
    usz n = q.len();               // kept, not counted

**Walking it:**

    InnerQueueIterator it = q.iter();
    while (Handle h = it.next()) { ... }

**Do not remove the current item while walking.** That is not supported.

**`append_queue` moves an entire queue onto another in one step**, leaving the
source empty. Use it instead of a pop-push loop.

### `InnerStack` — last in, first out

**Four calls: `push`, `pop`, `len`, `is_empty`.** No walker, no splice, no
Slot-shaped insert.

This is what a pool keeps its free items in. **You are unlikely to need one
directly**, and it never appears in a signature the toolkit gives you.

---

## `mtk::mailbox` — sending items between threads

**A queue with waiting. Many senders, many receivers, one mailbox.**

**A mailbox is itself an item.** It embeds an inner and carries an identity, so
you can send a mailbox through another mailbox, or keep mailboxes on a queue.
`mailbox::to_handle(mb)` and `mailbox::of(h)` cross for it, and `mailbox::TYPE`
is its identity.

### Usual flow

    Mailbox* mb = mailbox::create(mem)!;     // allocates
    ...                                       // send and receive, any threads
    InnerQueue left;
    mb.close(&left);                          // returns what was still queued
    while (Handle h = left.pop_front()) { /* your items — deal with them */ }
    mb.release();

**You must close before you release.** This is the one rule the toolkit will
not let you break: releasing an open mailbox aborts **in every build mode**,
including the fastest one. An open mailbox may still hold items, and releasing
it would lose them silently.

### Sending

    Slot s;
    s.fill(h);
    mb.send(&s)!;             // ordinary
    mb.send_oob(&s)!;         // ahead of every ordinary item

Both fail only with `CLOSED`, and on that failure **the Slot is untouched and
you still have the item.**

**Out-of-band is one level, not a priority queue.** Out-of-band items go before
all ordinary ones and stay first-in-first-out among themselves. There is no
second level to reach for.

### Receiving

**Three ways, and they differ in what happens when there is nothing there.**

| call | when empty | blocks |
|---|---|---|
| `poll(&s)` | `EMPTY` | never |
| `receive(&s, timeout)` | `TIMEOUT` | yes |
| `receive_all(&q)` | gives you an empty queue | never |

    Slot r;
    if (catch f = mb.receive(&r, time::ms(500)))
    {
        if (f == mtk::TIMEOUT) { ... }
        if (f == mtk::CLOSED)  { ... }
        if (f == mtk::WOKEN)   { ... }   // someone called wake_all
    }
    Msg* m = r.move(Msg);

**`receive_all` gives you everything at once**, as a queue, in the order
`receive` would have produced it: out-of-band first, then ordinary. **The items
are yours from that moment.** The mailbox never knew whether to free them.

**`wake_all` releases every waiter without closing.** Each one reports `WOKEN`.
A thread that starts waiting afterwards is unaffected — the wake does not
linger.

### Closing

**`close` cannot fail and can be called more than once.** The second call takes
nothing.

**It gives you back everything still queued, and this is the mistake to avoid:
do not discard that queue.** Those items keep their links, so a later attempt
to send one is refused — which means the mistake surfaces at the first reuse
rather than at some unrelated place later.

### Questions

- `is_closed` — takes no lock. A hint, but an honest one.
- `len` — takes the lock, counts both queues, and is stale the moment it
  returns.

---

## `mtk::pool` — keeping items to reuse

**A pool keeps items you want to use again, grouped by type.**

**The pool holds no policy.** It does not know how to make an item, how to
clean one, or how to destroy one. **You supply that as hooks**, and they are a
parameter of creation — there is no pool without them.

**A pool is itself an item**, the same as a mailbox: `pool::to_handle`,
`pool::of`, `pool::TYPE`.

### Usual flow

    typeid[1] tags = { Holder::typeid };
    Pool* p = pool::create(mem, &tags, &my_hooks)!;   // allocates
    ...
    p.close();          // your on_close hook receives everything left
    p.release();

**The set of types is fixed at creation and cannot be empty.** Asking for a
type the pool was not created with is a bug, not a runtime condition: a
checking build aborts, and a fast build gives you `UNKNOWN_IDENTITY`.

**Duplicates in the list are refused at creation**, in a checking build.

**Close before release**, exactly as for a mailbox, and aborting in every build
mode for the same reason.

### Getting an item

    Slot s;
    p.get(Holder::typeid, AVAILABLE_OR_NEW, &s)!;
    Holder* h = s.move(Holder);

**Three modes:**

| mode | takes a kept item | asks your hook |
|---|---|---|
| `AVAILABLE_OR_NEW` | yes | only if none was kept |
| `AVAILABLE_ONLY` | yes | never — reports `NOT_AVAILABLE` |
| `NEW_ONLY` | never | always |

**`NOT_CREATED` means your own `on_get` hook produced nothing.** It is not the
pool failing; it is the pool reporting what your hook did.

**`get_wait` waits for a kept item instead of making one.**

    p.get_wait(Holder::typeid, &s, time::ms(200))!;

**It never calls your hooks.** Nothing is created on this path. Where
`AVAILABLE_ONLY` would say `NOT_AVAILABLE`, this says `TIMEOUT`. **Do not use
it expecting creation under load** — it waits for someone to give an item back.

### Giving an item back

**`put` returns nothing. Read the Slot.**

    Slot s;
    s.fill(h);
    p.put(&s);
    if (s.is_full())
    {
        // refused — the pool is closed. The item is still yours.
    }

**A put can never fail and can never be interrupted.** A worker that must give
its item back can always do so.

**There is no batch put.** Giving back a queue is a loop you write, and the
refusal case is the whole reason it is not written for you:

    while (Handle h = batch.pop_front())
    {
        Slot s;
        s.fill(h);
        p.put(&s);
        if (s.is_full()) { batch.push_back_slot(&s); break; }   // refused
    }

**Get that loop wrong and you lose items quietly.** Copy it.

### Closing

**`close` gives you nothing back. Everything goes to your `on_close` hook**, as
one flat queue with every type mixed together, in no promised order.

That is the opposite of a mailbox, and it is worth holding in mind: **a mailbox
gives its remainder to the caller; a pool gives its remainder to the hook.**

**Callable more than once**; the hook does not run twice from `close` itself.

### Questions

- `is_closed` — no lock.
- `count_of(t)` — takes the lock, and is a hint that is stale on return. Zero
  for a type the pool does not hold.

---

## Writing the hooks

**You implement three methods. The object you implement them on is your
context** — there is no separate context pointer to thread through.

    struct MyHooks (PoolHooks)
    {
        Allocator alloc;
        // whatever else your policy needs
    }

**Three rules, and the first is the one that bites.**

1. **A hook runs with no lock held, and several may run at once on different
   threads.** Anything shared inside your hook, you protect yourself. Plain
   counters here are a data race — this toolkit's own tests had that bug and a
   thread sanitizer found it.
2. **A hook must not call back into the pool.**
3. **A hook must not block or wait.**

### `on_get(typeid want, usz in_pool, Slot* slot)`

**Make an item, or do not.**

    fn void MyHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic
    {
        if (catch mtk::managed::create(Holder, self.alloc, slot)) return;
    }

**The Slot is empty when you get it.** Fill it, or leave it empty to report
failure — an empty Slot becomes `NOT_CREATED` for the caller.

**Fill it with the type that was asked for.** Anything else is your bug, and a
checking build catches it.

`in_pool` is how many of that type are left. **A hint, and already stale.**

### `on_put(usz in_pool, Slot* slot, InnerQueue* extra)`

**Decide what becomes of an item being given back. Four outcomes, none
required.**

| you want | you do |
|---|---|
| keep it as it is | leave the Slot full |
| keep it, cleaned | reset the contents, leave the Slot full |
| release it | empty the Slot |
| keep a different one instead | replace the contents |

**A full Slot on return means one thing: an item is kept.** Original or
replacement, the pool does not care which.

**`extra` is for composite items.** If the item you are given is made of parts
that should also go back, push them there and they are taken the same way, with
the same checks.

    fn void MyHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic
    {
        Holder* h = slot.must(Holder);
        h.id = 0;                       // cleaned, and kept
    }

### `on_close(InnerQueue* remaining)`

**Process or release every item in that queue.** Nobody else will.

**It can be called more than once.** Once from `close`, and possibly again with
stragglers — items from a `put` whose hook was still running when the close
happened. **So do not free your own context on the first call**, and write the
loop so a second call with a few items is harmless.

    fn void MyHooks.on_close(&self, InnerQueue* remaining) @dynamic
    {
        while (Handle h = remaining.pop_front())
        {
            Slot s;
            s.fill(h);
            mtk::managed::release(Holder, &s);
        }
    }

---

## What can be reported to you

**These are conditions, not defects.** A correct program meets them, and they
are reported in every build.

| fault | what it means | where from |
|---|---|---|
| `CLOSED` | the container is closed | mailbox and pool, most calls |
| `EMPTY` | nothing queued, and this call does not wait | `Mailbox.poll` |
| `TIMEOUT` | the wait ran out | `Mailbox.receive`, `Pool.get_wait` |
| `WOKEN` | someone called `wake_all` | `Mailbox.receive` |
| `NOT_AVAILABLE` | nothing kept, and you asked not to create | `Pool.get`, available-only |
| `NOT_CREATED` | your `on_get` hook produced nothing | `Pool.get` |

**One is different.** `UNKNOWN_IDENTITY` reports **your bug** — a type the pool
was not created with. A checking build aborts before you ever see it. It exists
so that a fast build says what is wrong instead of quietly waiting out your
timeout.

**There is no interruption.** A wait ends on an item, a close, a wake, or the
timeout. Nothing else.

---

## What disappears in a fast build

**Two tiers, and knowing which is which tells you what you are still protected
from.**

**Gone under `--safe=no`:** every contract check. Filling a full Slot, inserting
an item already on a chain, sending from an empty Slot, asking a pool for a type
it does not hold, a hook returning the wrong type. **These are your bugs, and a
fast build stops looking for them.**

**Never gone, in any build:** releasing an open mailbox, and releasing an open
pool. Both abort. They are the two places where a mistake loses items with no
trace, so they are checked even where nothing else is.

**Test in a checking build.** The checks are the documentation of what you are
not allowed to do, and they are worth more than the speed while you are still
writing.

---

## The public surface, in one list

**Core — `mtk`**

`Inner` · `Handle` · `Slot` · `VERSION` · `CHECKED` · `@check`
`Inner.repoint_to` · `Inner.points_to` · `is_linked` · `reset`
`Slot.is_empty` · `Slot.is_full` · `Slot.peek` · `Slot.take` · `Slot.fill`
`inner_offset` · `required_alloc_offset`
`CLOSED` `TIMEOUT` `NOT_AVAILABLE` `NOT_CREATED` `EMPTY` `WOKEN` `UNKNOWN_IDENTITY`

**Containers — `mtk`**

`InnerQueue` · `InnerQueueIterator` · `InnerStack`
`InnerQueue.is_empty` · `.len` · `.iter` · `.push_back` · `.push_back_slot` ·
`.pop_front` · `.append_queue` · `@guard_insert`
`InnerQueueIterator.next`
`InnerStack.is_empty` · `.len` · `.push` · `.pop` · `@guard_insert`

**Border — `mtk::helper`**

`is_mine` · `init` · `to_handle`
`from_handle` · `must_from_handle` · `from_slot` · `must_from_slot` ·
`move_from_slot`
`Inner.to` · `Inner.as` · `Slot.to` · `Slot.must` · `Slot.move`

**Allocating helper — `mtk::managed`**

`create` · `release` · `required_alloc_offset`

**Mailbox — `mtk::mailbox`**

`Mailbox` · `TYPE` · `to_handle` · `of` · `create`
`Mailbox.send` · `.send_oob` · `.poll` · `.receive` · `.receive_all` ·
`.wake_all` · `.close` · `.release` · `.is_closed` · `.len` · `@closed_fast`

**Pool — `mtk::pool`**

`Pool` · `PoolHooks` · `PoolBucket` · `GetMode` · `TYPE` · `to_handle` · `of` ·
`create`
`Pool.get` · `.get_wait` · `.put` · `.close` · `.release` · `.is_closed` ·
`.count_of` · `@closed_fast`
`PoolHooks.on_get` · `.on_put` · `.on_close`

**Two things on that list are not for you to call.** `Inner.repoint_to` and the
two `@guard_insert` macros are how the containers maintain their chains. They
are reachable because the language makes them reachable, not because they are
an offer.
