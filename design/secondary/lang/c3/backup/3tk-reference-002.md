# 3tk — the book

Matryoshka in C3.

Read it to learn 3tk. Read it to use 3tk.

Seven parts. Parts 3, 4 and 5 have the same shape, in the same order.

- **What this is** — high level, short.
- **Participants** — the types, and the role each one plays.
- **Usual flow** — the regular usage.
- **The API, in named groups** — one named group per act.
- **Where to go deeper** — `3tk/src`, a test, a document.

A part learned once is a part learned everywhere.

Deep dive is not this book's job. For that the reader goes to `3tk/src` or to a
test under `3tk/test`.

**This is 002, written by 3TK-46.** It carries all of `001`, and adds Part 7's
*The modules, one by one* — the eight labelled module blocks — and corrects
Part 7's module layout for the eight-module split 3TK-44 made. `001` is in
`backup/`.

---

## Part 1 — Introduction

### What 3tk is

An item-transfer and item-reuse toolkit for concurrent C3 programs.

Three small tools. Each one usable on its own.

- **the core** — type identity for an item, and two containers that never
  allocate.
- **mailbox** — transfer of an item between threads.
- **pool** — reuse of an item, decided by your hooks.

Mailbox and pool are both optional. The core alone is a valid use.

### What it is for

One idea runs through all three.

- Share by communicating.
- Do not share access to an item. Move the item.
- One place has the item at a time.

That gives a concurrent program with no lock around application data.

- The mailbox is shared. The items passing through it are not.
- The pool is shared. The items it gives out are not.

### Who it is for

- A C3 programmer building a concurrent subsystem.
- Someone who wants transfer and reuse without a framework around them.
- Someone who wants to read the whole toolkit in an afternoon.

### What it is not

Plain scope limits.

- Not a container library. The queue and the stack exist because the mailbox
  and the pool need them, and a caller may use either one directly.
- Not an allocator. Every item is allocated and freed by your code, or by your
  hooks.
- Not a garbage collector. The toolkit never frees an item you gave it, except
  through a hook you wrote.
- Not a storage container. The pool answers whether a reusable item is free
  right now.
- Not a coordinator. There is no `Master` type. Part 7 says why.

### What the reader needs before starting

- C3, and the `c3c` compiler.
- `any` — the built-in pair of a pointer and a `typeid`. Part 2 gives it.
- Compile-time members reflection, `$Type::members`. Part 2 gives it.
- A fault, and the `!` and `?` in a signature. Part 2 gives it.
- `std::thread`, for mailbox and pool. Only the basics.

---

## Part 2 — C3, interesting parts

### Why this part exists

The toolkit stands on four C3 features.

A reader who knows them reads Parts 3 to 5 without stopping.

- `any` — a pointer and a `typeid`, as one built-in value.
- Compile-time reflection over a struct's members.
- The fault, and the optional return.
- The contract, `@require`, and what the compiler does with it.

### Intrusion — your struct is the node

A container that allocates a node per item pays twice: once for your struct,
once for the node.

3tk does not allocate a node. Your struct carries it.

```c3
struct Msg
{
    int   id;
    Inner node;
    char  body;
}
```

- `Inner` is one field. Sixteen bytes.
- That field is the chain link and the identity, together.
- The container writes the link. It never allocates.

### `any` — the pointer and the type, in one value

C3's `any` is a built-in fat pointer.

- `.ptr` — where the value is.
- `.type` — the `typeid` of the value.

3tk uses both halves for two different jobs.

- `.ptr` carries the chain link — the next item, or the item itself at the end
  of a chain.
- `.type` carries the identity — which outer type this item really is.

One field does the work of two, and the `typeid` is written once.

```c3
struct Inner
{
    any link;
}
```

### Compile-time reflection — finding the embedded field

The toolkit never asks you to name the field's offset.

It reads the offset out of your type at compile time.

```c3
macro usz inner_offset($Type)
```

- It walks `$Type::members` and looks for the one of type `Inner`.
- A type with no `Inner` field does not compile.
- A type with two `Inner` fields does not compile.
- The message names your type.

That is why there is no helper type to declare and no registration step.

### Faults — the outcomes that are not defects

A 3tk call that can fail returns `void?`.

The faults are outcomes a correct program reaches.

```c3
faultdef CLOSED, TIMEOUT, NOT_AVAILABLE, NOT_CREATED, EMPTY, WOKEN, UNKNOWN_IDENTITY;
```

- `!` propagates the fault to the caller.
- `catch f = ...` names the fault and handles it.
- A defect is not a fault. A defect aborts.

### Contracts, and the two kinds of check

C3 contracts sit in the doc comment, above the declaration.

```c3
<*
 @require is_mine(h, $Type) : "the handle is not of this type"
*>
```

- A contract is checked in a safe build.
- Under `--safe=no` it is gone, and the condition is not evaluated.

The toolkit adds one macro of its own for the same reason.

```c3
macro @check(#cond, $msg)
const bool CHECKED
```

- `@check` aborts in a safe build and names the message.
- Under `--safe=no` it expands to nothing.
- `CHECKED` is true where those checks are live. Guard an expensive check with
  it.

Two checks never go away. Releasing an open mailbox and releasing an open pool
abort in every build mode.

### Where to go deeper

- `3tk/src/inner.c3` — `any`, the offset macros, `@check`.
- `3tk/negative/nocompile_no_inner.c3` — the type that does not compile.
- `3tk/negative/nocompile_two_inners.c3` — the other one.

---

## Part 3 — the core

---

### What this is

Type identity for an item, and two containers that never allocate.

Part 2 ended on a struct that carries its own node. The core is what reads and
writes that node.

- The identity sits in the same field as the chain link.
- The identity says what the outer type is.
- The check happens on the handle, not in your head.

### Participants

```c3
struct Inner { any link; }

alias   Handle = Inner*;
typedef Slot   = Handle;

struct InnerQueue { ... }
struct InnerStack { ... }
struct InnerQueueIterator { ... }
```

- `Inner` — the field you embed. The chain link and the identity, in one.
- `Handle` — a pointer to an embedded `Inner`. One item, with the type
  forgotten.
  - Everything 3tk transports is a `Handle`.
  - It is an alias, so it converts freely with `Inner*` and costs nothing.
- `Slot` — a box that holds one handle, or nothing.
  - Zero or one item.
  - A Slot starts empty.
- `InnerQueue` — many items, first-in first-out. The transfer container.
- `InnerStack` — many items, last-in first-out. The storage container.
- `InnerQueueIterator` — a walker over a queue.

Two words name the two sides.

- **Outer** — your struct, the one that embeds an `Inner`. It is a category,
  not a type. There is no `Outer` in the source.
- **Inner** — the field it embeds.

A Slot holds a handle, or it is empty.

```text
Slot (holds a handle)            Empty Slot

+-------------------+            +-------------------+
|                   |            |                   |
|      Handle       |            |       null        |
|                   |            |                   |
+-------------------+            +-------------------+

  the item is here                 the item is elsewhere
```

Everything transported is a `Handle`.

- your items
- mailboxes
- pools

A mailbox and a pool are items too. Part 4 and Part 5 say how.

### Usual flow

Three steps. Define a type, transport it, recover it.

```c3
import mtk;
import mtk::helper;

// 1. Define. One embedded field. Nothing else.
struct Msg
{
    int   id;
    Inner node;
    char  body;
}

// 2. Transport. init writes the identity, to_handle reaches the field.
Msg m;
m.id = 7;
helper::init(&m);

Handle h = helper::to_handle(&m);

InnerQueue q;
q.push_back(h);

// 3. Recover. The crossing checks the identity first, and returns null on a
// mismatch.
Msg* back = q.pop_front().to(Msg);
```

1. **Define.**

   - Embed one `Inner` field. Name it what you like.
   - Nothing else is required of the struct.
   - No alias to declare, no instantiation, no registration.

2. **Transport.**

   - `init` writes the identity. On a stack value, with no allocator.
   - `to_handle` gives the `Handle`.
   - The handle travels. The identity travels with it.

3. **Recover.**

   - The crossing checks the identity, then casts.
   - It returns null when the identity names another type.
   - You decide what a mismatch means.

`init` before first use, always.

- An item that was never initialized carries no identity.
- Every crossing refuses it rather than guessing.

Recovery from a mixed queue is the same call, once per candidate type.

```c3
while (Handle h = q.pop_front())
{
    if (Msg* m = h.to(Msg))
    {
        // a Msg
    }
    else if (Sensor* s = h.to(Sensor))
    {
        // a Sensor
    }
    else
    {
        // an identity this loop does not know
    }
}
```

### The API — identity

The identity is written once and never computed.

```c3
macro void init(item)
macro bool is_mine(Handle h, $Type)
```

- `init` — writes the identity into the embedded `Inner`. Call it once, before
  first use.
- `is_mine` — true when the handle names `$Type`.
  - False for a null handle.
  - False for an item whose `init` was never called.

The identity answers one question: **is this a `$Type`?**

- It does not answer "which instance?".
- It does not answer "what role does this item play?".
- Part 6 says what to do when the role matters.

An identity comparison reads the `typeid` already in the item. Nothing is
computed and nothing is allocated.

### The API — crossing

Every crossing between a typed pointer and a `Handle` lives in one file.

```c3
macro Handle to_handle(item)
macro from_handle(Handle h, $Type)
macro must_from_handle(Handle h, $Type)
```

- `to_handle` — from your pointer to a `Handle`. Null in, null out.
- `from_handle` — from a `Handle` to `$Type*`.
  - Null on an identity mismatch.
  - A mismatch is an answer, not a failure.
- `must_from_handle` — the same, and it aborts on a mismatch.
  - Use it where a mismatch would be your own defect.
  - The abort names your line.

The same three, taking the item from a Slot.

```c3
macro from_slot(Slot* s, $Type)
macro must_from_slot(Slot* s, $Type)
macro move_from_slot(Slot* s, $Type)
```

- `from_slot` — looks. The Slot is unchanged.
- `must_from_slot` — looks, and aborts on failure.
- `move_from_slot` — takes.
  - On success the Slot is left empty.
  - On failure it is unchanged.

Five of them again, as methods, for the call site that reads better that way.

```c3
macro Inner.to(&self, $Type)
macro Inner.as(&self, $Type)
macro Slot.to(&self, $Type)
macro Slot.must(&self, $Type)
macro Slot.move(&self, $Type)
```

- `h.to(Msg)` is `from_handle(h, Msg)`.
- `h.as(Msg)` is `must_from_handle(h, Msg)`.
- `s.to(Msg)`, `s.must(Msg)`, `s.move(Msg)` are the three Slot forms.

Each is the same crossing, as a method on the handle or as a method on the
Slot.

None of these moves an item. Reading an identity and casting a pointer leave
every container alone.

### The API — the Slot

The Slot is how the toolkit tells you where an item went.

```c3
fn bool   Slot.is_empty(&self)
fn bool   Slot.is_full(&self)
fn Handle Slot.peek(&self)
fn Handle Slot.take(&self)
fn void   Slot.fill(&self, Handle h)
```

- `is_empty` / `is_full` — which of the two states it is in.
- `peek` — look without taking. Null on an empty Slot.
- `take` — take the handle out and clear the Slot. Null on an empty Slot.
- `fill` — put a handle in.
  - A null handle is a defect.
  - Overwriting a full Slot is a defect.

Read the Slot after every call that gives or takes an item. Part 6 makes that a
rule.

### The API — the link

The chain link is the other half of `Inner`.

```c3
fn void   Inner.repoint_to(&self, Handle to)
fn Handle Inner.points_to(&self)
fn bool   is_linked(Handle h)
fn void   reset(Handle h)
```

- `repoint_to` — keeps the identity, swaps the chain link. The containers call
  it.
- `points_to` — the item this one links to. Null if it is on no chain.
- `is_linked` — true when the handle is on some chain. Exact, and O(1).
  - False for a null handle.
- `reset` — clears the chain link so the item can be inserted again.
  - It clears the link and not the identity.
  - Every removal in the queue and the stack calls it for you.

Every chain ends at an item pointing at itself, never at null. That is what
makes `is_linked` exact.

### The API — the queue

The intrusive queue. First-in first-out. Nothing here allocates, and every
operation is O(1).

```c3
fn bool   InnerQueue.is_empty(&self)
fn usz    InnerQueue.len(&self)
fn void   InnerQueue.push_back(&self, Handle h)
fn void   InnerQueue.push_back_slot(&self, Slot* s)
fn Handle InnerQueue.pop_front(&self)
fn void   InnerQueue.append_queue(&self, InnerQueue* other)
fn InnerQueueIterator InnerQueue.iter(&self)
fn Handle InnerQueueIterator.next(&self)
```

- `is_empty` — true if the queue holds nothing.
- `len` — how many items the queue holds. O(1).
  - The count is kept, so `len` is O(1).
- `push_back` — adds at the back. There is no front insert.
- `push_back_slot` — the same, taking the item from a Slot.
  - The Slot is empty afterwards.
  - An empty Slot is a defect, not a no-op.
- `pop_front` — takes the item at the front.
  - Null on an empty queue, which is an answer and not a fault.
  - The returned item's chain link is cleared.
- `append_queue` — moves every item of another queue onto the back of this one,
  in O(1).
  - That queue is empty afterwards.
  - A queue moved onto itself is a defect.
- `iter` / `next` — a walker, taken from the queue.
  - `next` — the next handle, or null when the walk is exhausted.
  - Exhausted when `next` returns null.
  - Removing the current item during a walk is not supported.

```c3
InnerQueueIterator it = q.iter();
while (Handle h = it.next())
{
    Msg* m = h.to(Msg);
    if (m) { }
}
```

Nothing in the queue can fail.

### The API — the stack

The intrusive stack. Last-in first-out. Four operations: no walker, and no
splice.

Where the queue carries items across, the stack holds them still.

```c3
fn bool   InnerStack.is_empty(&self)
fn usz    InnerStack.len(&self)
fn void   InnerStack.push(&self, Handle h)
fn Handle InnerStack.pop(&self)
```

- `is_empty` — true if the stack holds nothing.
- `len` — how many items the stack holds. O(1).
  - The count is kept, so `len` is O(1).
  - There is no tail, so flattening the stack is O(n).
- `push` — adds on top. There is no Slot-shaped insert.
- `pop` — takes the item on top.
  - Null on an empty stack.
  - The returned item's chain link is cleared.

The order is not promised. No caller is entitled to which item comes back.

Nothing in the stack can fail.

The stack is the storage container. Items rest in it until they are wanted
again, and the newest is the one that comes back first.

The pool keeps one per identity, and it is the only stack 3tk owns. No 3tk
signature passes one: the four that take a container take an `InnerQueue*`. A
caller who wants a stack declares one.

### The API — the insert guards

Both containers refuse a bad insert, where checks are live.

```c3
macro InnerQueue.@guard_insert(&self, Handle h)
macro InnerStack.@guard_insert(&self, Handle h)
```

- A null handle is a defect.
- An item already on any chain is a defect.
- Both are gone from a fast build.

### The API — allocating an item for you

One helper allocates and frees, and only if your struct carries the allocator
itself.

```c3
macro void? create($Type, Allocator a, Slot* slot)
macro void  release($Type, Slot* slot)
macro usz   required_alloc_offset($Type)
```

- `create` — allocates the outer, initializes it, and fills the Slot.
  - The item keeps the allocator for life.
  - On an allocation failure the Slot is untouched and the fault is returned.
- `release` — frees the item with the allocator it kept.
  - It takes no allocator.
  - A no-op on an empty Slot, so a `defer` registered before the acquisition is
    safe.
- `required_alloc_offset` — finds the `Allocator` field at compile time.
  - A type with no `Allocator` field does not compile.
  - The message tells you to take the plain helper instead.

No type declares itself managed. The choice is made at the call site.

```c3
Slot s;
managed::create(Msg, a, &s)!;
defer managed::release(Msg, &s);

Msg* m = s.must(Msg);
m.id = 1;
```

### The API — the version

```c3
const String VERSION
```

- The toolkit's version string.

### Where to go deeper

- `3tk/src/inner.c3` — `Inner`, `Handle`, `Slot`, the link, `@check`.
- `3tk/src/helper.c3` — every crossing.
- `3tk/src/managed.c3` — `create` and `release`.
- `3tk/src/queue.c3` and `3tk/src/stack.c3` — the two containers.
- `3tk/test/t_identity.c3` — identity across types.
- `3tk/test/t_slot.c3` — the Slot's states.
- `3tk/test/t_queue.c3` and `3tk/test/t_stack.c3` — the containers.
- `3tk/test/t_managed.c3` — create and release.

---

## Part 4 — mailbox

---

### What this is

Transfer of an item between threads.

A queue of items, with waiting.

- Many producers, many consumers, on one mailbox.
- The mailbox keeps items. It never touches them.
- A mailbox is itself an item: it can travel through another mailbox.

### Participants

```c3
struct Mailbox { ... }

const typeid TYPE;
```

- `Mailbox` — the tool itself. Created on the heap, with an allocator it keeps
  for life.
- `TYPE` — the identity of a `Mailbox` as an item.
- `Slot` — how you give an item and how you take one.
- `InnerQueue` — how you take many at once.

Inside it are two queues.

- One for out-of-band items.
- One for ordinary items.

The fields named with a leading underscore are internal. Do not read them.

### Usual flow

Create, send, receive, close, release.

```c3
Mailbox* mb = mailbox::create(a)!;

Slot s;
managed::create(Msg, a, &s)!;
mb.send(&s)!;                       // s is empty now — the mailbox has it

Slot got;
if (catch f = mb.receive(&got, time::sec(1)))
{
    if (f == mtk::TIMEOUT) { }
}
else
{
    managed::release(Msg, &got);
}

InnerQueue left;
mb.close(&left);
while (Handle h = left.pop_front())
{
    Slot one;
    one.fill(h);
    managed::release(Msg, &one);
}
mb.release();
```

1. **Create.**

   - The allocator is kept for life.
   - Nothing partially constructed is ever returned.

2. **Send.**

   - The Slot is the answer. Cleared means the mailbox has the item.
   - Untouched means the mailbox is closed and you still have the item.

3. **Receive.**

   - An empty Slot goes in. A full Slot comes back on success.
   - Every other outcome is a fault, and the Slot stays empty.

4. **Close.**

   - What was left comes back to you, as one queue.
   - Releasing those items is your work. The mailbox never knew what they were.

5. **Release.**

   - Close it first. Releasing an open mailbox aborts in every build mode.

### The API — create and destroy

```c3
fn Mailbox*? create(Allocator a)
fn void Mailbox.release(&self)
```

- `create` — allocates a mailbox and returns it.
  - Every step undoes what succeeded before it.
- `release` — frees the mailbox, with the allocator it kept.
  - It takes no allocator.
  - The mailbox must be closed.

### The API — send

```c3
fn void? Mailbox.send(&self, Slot* slot)
fn void? Mailbox.send_oob(&self, Slot* slot)
```

- `send` — puts the item on the ordinary queue.
- `send_oob` — puts it ahead of every ordinary item.
  - First-in first-out among out-of-band items themselves.
  - One priority level. This is not a priority queue.

Both take a full Slot.

- Cleared on success.
- Untouched on `CLOSED`, and the sender still has the item.
- An empty Slot is a defect.

### The API — receive

```c3
fn void? Mailbox.poll(&self, Slot* slot)
fn void? Mailbox.receive(&self, Slot* slot, Duration timeout)
fn void? Mailbox.receive_all(&self, InnerQueue* out)
```

- `poll` — takes an item if one is queued. Never waits.
  - Reports `EMPTY` where `receive` with a zero timeout would report `TIMEOUT`.
- `receive` — takes an item, waiting up to the timeout.
  - The deadline is anchored once. A spurious wakeup does not restart it.
  - There is no interruption. C3 has no interruptible condition wait.
- `receive_all` — moves every queued item onto your queue.
  - The queue is in the order `receive` would have taken them out.
  - Releasing the items is your work.

Out-of-band first, then ordinary, first-in first-out within each.

`poll` and `receive` take an empty Slot and fill it on success.

### The API — control

```c3
fn void? Mailbox.wake_all(&self)
fn void  Mailbox.close(&self, InnerQueue* out)
fn bool  Mailbox.is_closed(&self)
fn usz   Mailbox.len(&self)
```

- `wake_all` — wakes every current waiter. Each one reports `WOKEN`.
  - The mailbox stays open.
  - A thread that starts waiting afterwards is unaffected.
- `close` — closes the mailbox and gives back what was left. Cannot fail.
  - Callable more than once. The second call takes nothing.
  - Discarding that queue drops the items, and a later send refuses them.
- `is_closed` — true when it is closed.
- `len` — how many items are queued.
  - A hint. It is stale by the time you read it.

### The API — the mailbox as an item

```c3
macro Handle to_handle(Mailbox* p)
macro Mailbox* of(Handle h)
```

- `to_handle` — from a `Mailbox*` to a `Handle`. Cannot fail.
- `of` — the checking crossing back. Null when the handle names another type.

That is what lets a mailbox travel through another mailbox.

### The API — outcomes

| fault | when |
|---|---|
| `CLOSED` | the mailbox is closed |
| `EMPTY` | `poll` found nothing queued |
| `TIMEOUT` | `receive` waited the whole timeout |
| `WOKEN` | `wake_all` reached this waiter |

None of them is a defect. A correct program reaches all four.

### Where to go deeper

- `3tk/src/mailbox.c3` — the whole tool, in one file.
- `3tk/test/t_mailbox.c3` — send, receive, close.
- `3tk/test/t_concurrency.c3` — many producers and many consumers.
- `3tk/negative/release_open_mailbox.c3` — the abort that never goes away.

---

## Part 5 — pool

---

### What this is

Reuse of an item, decided by your hooks.

A keeper of free items, grouped by type identity.

- Policy is not in the pool. Policy is in the hooks.
- The pool answers whether a reusable item is free right now.
- A pool is itself an item: it can travel through a mailbox.

The mailbox gives everything back to a caller. The pool's close gives nothing
back at all.

### Participants

```c3
interface PoolHooks { ... }

enum GetMode
{
    AVAILABLE_OR_NEW,
    NEW_ONLY,
    AVAILABLE_ONLY,
}

struct PoolBucket { ... }
struct Pool { ... }

const typeid TYPE;
```

- `Pool` — the tool itself. Created on the heap, with an allocator it keeps for
  life.
- `PoolHooks` — your policy. Three methods. Part 5's last group says what each
  one may do.
- `GetMode` — the three modes of a plain get.
- `PoolBucket` — the free items of one identity, as an `InnerStack`.
- `TYPE` — the identity of a `Pool` as an item.

One bucket per identity, in a flat slice allocated once at creation.

```text
Pool
 |
 +-- bucket[0]  tag = Msg::typeid      free: InnerStack
 +-- bucket[1]  tag = Sensor::typeid   free: InnerStack
 +-- bucket[2]  tag = Frame::typeid    free: InnerStack
```

- The identity set is fixed at creation.
- It is not empty, and it has no duplicate. Both are checked.

A stack and not a queue, and the reason is defect surfacing. The item just
given back is on top, so a caller still writing through a stale pointer
collides with the next owner at once instead of much later.

### Usual flow

Write the hooks, create, get, put, close, release.

```c3
struct MsgPolicy (PoolHooks)
{
    Allocator alloc;
}

fn void MsgPolicy.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic
{
    if (want != Msg::typeid) return;
    if (catch managed::create(Msg, self.alloc, slot)) return;
}

fn void MsgPolicy.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic
{
    if (in_pool >= 8) { managed::release(Msg, slot); return; }
    Msg* m = slot.must(Msg);
    m.id = 0;
}

fn void MsgPolicy.on_close(&self, InnerQueue* remaining) @dynamic
{
    while (Handle h = remaining.pop_front())
    {
        Slot one;
        one.fill(h);
        managed::release(Msg, &one);
    }
}

MsgPolicy policy = { .alloc = a };
typeid[1] tags = { Msg::typeid };

Pool* p = pool::create(a, tags[..], &policy)!;

Slot s;
p.get(Msg::typeid, AVAILABLE_OR_NEW, &s)!;

Msg* m = s.must(Msg);
m.id = 42;

p.put(&s);
if (s.is_full()) { managed::release(Msg, &s); }

p.close();
p.release();
```

1. **Write the hooks.**

   - The implementing struct is the context. There is no `ctx` parameter.

2. **Create.**

   - The hooks are a parameter of creation. A pool cannot exist without them.
   - The identity set is a parameter too, and it never changes.

3. **Get.**

   - An empty Slot goes in. A full Slot comes back on success.
   - A free item is taken, or `on_get` is asked to make one.

4. **Put.**

   - The Slot is the answer. Cleared means the pool took the item.
   - Unchanged means it was refused and you still have the item.

5. **Close.**

   - Nothing comes back to you. Everything goes to `on_close`.

6. **Release.**

   - Close it first. Releasing an open pool aborts in every build mode.

### The API — create and destroy

```c3
fn Pool*? create(Allocator a, typeid[] tags, PoolHooks hooks)
fn void Pool.release(&self)
```

- `create` — allocates a pool and returns it.
  - `tags` is the identity set. Not empty, and no duplicate.
  - `hooks` is the policy, and it cannot be null.
  - Every step undoes what succeeded before it.
- `release` — frees the pool, with the allocator it kept.
  - It takes no allocator.
  - The pool must be closed.

### The API — get

```c3
fn void? Pool.get(&self, typeid want, GetMode mode, Slot* slot)
fn void? Pool.get_wait(&self, typeid want, Slot* slot, Duration timeout)
```

- `get` — takes a free item, or has the hook make one. Never waits.
  - `AVAILABLE_OR_NEW` — take a free one, and ask the hook if there is none.
  - `NEW_ONLY` — do not take a free one. Ask the hook.
  - `AVAILABLE_ONLY` — take a free one, or report `NOT_AVAILABLE`.
- `get_wait` — takes a free item, waiting up to the timeout.
  - It never creates. No hook is called on this path.
  - The deadline is anchored once. A spurious wakeup does not restart it.

Both take an empty Slot and fill it on success.

Which fault comes from where:

- `NOT_AVAILABLE` comes only from `AVAILABLE_ONLY`.
- `NOT_CREATED` comes only from a hook that produced nothing.
- `TIMEOUT` comes only from `get_wait`, where `AVAILABLE_ONLY` would have said
  `NOT_AVAILABLE`.
- `UNKNOWN_IDENTITY` is your defect. A checking build aborts on it, and
  `get_wait` reports it at once rather than after the whole timeout.

`on_get` runs outside the pool's mutex. Everything read before the mutex is
released is stale when it returns.

### The API — put

```c3
fn void Pool.put(&self, Slot* slot)
```

- `put` — gives an item back. Returns nothing.
- The Slot is the answer.
  - Cleared: the pool took it.
  - Unchanged: it was refused, and you still have the item.
- It cannot fail and cannot be interrupted.
- An empty Slot is a no-op.

A close that arrives while `on_put` runs is handled. The item goes to
`on_close`, and your Slot stays cleared.

There is no `put_all`. A caller giving a batch back writes the loop.

```c3
while (Handle h = batch.pop_front())
{
    Slot s;
    s.fill(h);
    p.put(&s);
    if (s.is_full()) { batch.push_back(h); break; }
}
```

### The API — control

```c3
fn void Pool.close(&self)
fn bool Pool.is_closed(&self)
fn usz  Pool.count_of(&self, typeid t)
```

- `close` — closes the pool. Cannot fail.
  - Everything the pool held goes to `on_close`, as one flat queue.
  - Callable more than once. The second call takes nothing and does not run the
    hook again.
  - The hook is called once, outside the mutex, after the closed flag is set.
- `is_closed` — true when it is closed.
- `count_of` — how many of one identity are free.
  - A hint. It is stale by the time you read it.

### The API — the pool as an item

```c3
macro Handle to_handle(Pool* p)
macro Pool* of(Handle h)
```

- `to_handle` — from a `Pool*` to a `Handle`. Cannot fail.
- `of` — the checking crossing back. Null when the handle names another type.

### The API — hooks

Three methods. Implement them to give a pool its policy.

```c3
fn void on_get(typeid want, usz in_pool, Slot* slot);
fn void on_put(usz in_pool, Slot* slot, InnerQueue* extra);
fn void on_close(InnerQueue* remaining);
```

**`on_get` — make one, or refuse.**

- Asked for an item of a named identity.
- The Slot is empty on entry. Fill it, or leave it.
- An empty Slot afterwards becomes `NOT_CREATED`.
- An item of a different identity is a defect of your application.
- `in_pool` is how many of this identity remain, after the removal. A hint, and
  stale.

**`on_put` — keep it, reset it, replace it, or free it.**

- An item is being given back. Four outcomes, and none is mandated.
- Freed with nothing kept: empty the Slot.
- Kept as it is, or kept after a reset: leave it full.
- Freed with a different item put back: replace the contents.
- A full Slot on return means one thing — an item is kept, original or
  replacement.
- `extra` starts empty. Items added there are taken the same way, with the same
  checks.
- `in_pool` is how many of this identity are held, before the addition. A hint.

**`on_close` — take everything that is left.**

- Called with everything that remained, as one flat queue.
- Process or free every item in it.
- No order is promised.
- Called once by `close`, and possibly once more with stragglers from a
  concurrent `put`.
- So a hook must not free its own context on the first call.

**What a hook may not do.**

- A hook runs outside the pool's mutex, several at once on different threads.
- A hook that touches shared state protects it itself.
- A hook does not call back into the pool.
- A hook does not block and does not wait.

### The API — outcomes

| fault | when |
|---|---|
| `CLOSED` | the pool is closed |
| `NOT_AVAILABLE` | `AVAILABLE_ONLY` found no free item |
| `NOT_CREATED` | `on_get` produced nothing |
| `TIMEOUT` | `get_wait` waited the whole timeout |
| `UNKNOWN_IDENTITY` | the identity is not one the pool was created with |

`UNKNOWN_IDENTITY` is the one that is also a defect. It comes only from `Pool.get` and
`Pool.get_wait`.

### Where to go deeper

- `3tk/src/pool.c3` — the whole tool, and the hooks interface.
- `3tk/test/t_pool.c3` — the three modes, put, close.
- `3tk/test/t_concurrency.c3` — the pool under many threads.
- `3tk/negative/duplicate_pool_tags.c3` — the identity set that is refused.
- `3tk/negative/pool_unknown_identity.c3` — the get that aborts.
- `3tk/negative/release_open_pool.c3` — the abort that never goes away.

---

## Part 6 — Using them together

Four things that only make sense once all three tools are in view.

- The Slot rule.
- Identity across the tools.
- Cleanup patterns.
- Concurrency, and what close leaves behind.

### The Slot rule

**The Slot is the answer. Not the return value.**

- Every call that gives you an item takes an empty Slot and fills it.
- Every call that takes an item from you takes a full Slot and empties it.

```text
    empty  ->  the item is somewhere else, and not your problem
    full   ->  the item is here, and it is yours to deal with
```

Read it after every such call.

- `send` cleared the Slot: the mailbox has the item.
- `send` left it full: the mailbox is closed, and the item is still yours.
- `put` cleared the Slot: the pool took the item.
- `put` left it full: the pool refused it, and you free it.

Why an acquisition asserts the Slot is empty on entry.

- A full Slot on entry means you are about to lose the handle already in it.
- That is a leak, and it is silent.
- So it is a defect, and a checking build aborts.

Why a cleanup accepts an empty Slot.

- `release` on an empty Slot is a no-op.
- That is what makes `defer` before the acquisition safe.

```c3
Slot s;
defer managed::release(Msg, &s);    // safe even if create fails
managed::create(Msg, a, &s)!;
```

Moving a handle clears the Slot.

- `take`, `move`, `push_back_slot`, a successful `send`, a successful `put`.
- After any of them the Slot is empty, and the item is elsewhere.

### Identity across the tools

The identity is the type, not the instance.

- Two mailboxes have the same identity. `of` cannot tell them apart.
- Two `Msg` items have the same identity.
- The identity answers "is this a `Msg`?" and nothing else.

When the role matters, put the role in your own struct.

```c3
struct Endpoint
{
    Inner    node;
    Mailbox* inbox;
    int      role;
}
```

- Now the role travels with the item.
- The identity still says `Endpoint`, and that is enough to recover it.

Transporting a mailbox or a pool.

- `mailbox::to_handle` and `pool::to_handle` give the handle.
- `mailbox::of` and `pool::of` check on the way back.
- `mailbox::TYPE` and `pool::TYPE` name the two identities.
- A pool created for `Endpoint` items holds `Endpoint` items only.

### Cleanup patterns

**Pattern 1 — defer-release-early, for a heap item.**

```c3
Slot s;
defer managed::release(Msg, &s);
managed::create(Msg, a, &s)!;
mb.send(&s)!;                       // s is empty; the defer is a no-op
```

The defer covers the failure path. A successful send makes it a no-op.

**Pattern 2 — defer-put-early, for a pool item.**

```c3
Slot s;
defer p.put(&s);
p.get(Msg::typeid, AVAILABLE_OR_NEW, &s)!;
```

The item goes back to the pool on every path out of the function.

**Pattern 3 — a received item.**

```c3
Slot got;
if (catch mb.receive(&got, time::sec(1))) return;
defer managed::release(Msg, &got);
```

Register the defer after the receive. Before it, there is nothing to free.

**Pattern 4 — a batch from close.**

```c3
InnerQueue left;
mb.close(&left);
while (Handle h = left.pop_front())
{
    Slot one;
    one.fill(h);
    managed::release(Msg, &one);
}
```

The mailbox never knew what the items were. This loop does.

**What you may not do.**

- Do not free an item that is on a chain. Take it out first.
- Do not free an item whose handle is in a Slot the toolkit still has.
- Do not put an item into two containers. The insert guard catches it where
  checks are live.

### Concurrency, and what close leaves behind

What is safe on many threads.

- Every `Mailbox` method.
- Every `Pool` method.

What is not.

- `InnerQueue`, `InnerStack` and `Slot` are plain values. They carry no lock.
- A queue you got from `receive_all` or from `close` is yours alone.
- An item you are holding is yours alone. That is the whole idea.

Close, on both tools.

- Close is callable more than once. The second call takes nothing.
- A closed mailbox refuses a send and reports `CLOSED`.
- A closed pool refuses a put silently, because `put` cannot fail.
- Every waiter is woken.

Where the items go.

| | the caller gets | the hook gets |
|---|---|---|
| `Mailbox.close` | everything left, as one queue | — |
| `Pool.close` | nothing | everything left, as one flat queue |

`wake_all` is not close.

- It wakes the current waiters and each one reports `WOKEN`.
- The mailbox stays open.

One macro on each tool is visible but not for you.

- `Mailbox.@closed_fast` and `Pool.@closed_fast` are the two. Each reads the
  closed flag before taking the lock.
- They are a hint. Every caller that gets false re-reads the flag under the
  lock.
- Call `is_closed` instead.

### Item states

An item is in exactly one of four states.

```text
  yours          you have the pointer, and nothing else does
  in a Slot      the handle is in a Slot; the Slot says whose it is
  on a chain     a queue, a stack, or a mailbox has it
  free in a pool the pool has it, and will give it out again
```

- `is_linked` distinguishes "on a chain" from the other three.
- The Slot's two states distinguish the second.
- Nothing distinguishes "yours" from "free in a pool" by reading the item. That
  is what the Slot rule is for.

---

## Part 7 — Beyond the toolkit

Four things outside the three tools.

- The module layout — what an import gives you.
- The modules, one by one — the eight module descriptions, labelled for the
  doc loop.
- Master — the coordination role, and why it is not a type.
- The build modes, and what changes between them.

### The module layout

One import gives the toolkit.

```c3
import mtk;
```

`module mtk` is declared by one file, and the rest are submodules of it.

| module | file | what is in it |
|---|---|---|
| `mtk` | `mtk.c3` | `VERSION`, the faults, `@check`, `CHECKED` |
| `mtk::inner` | `inner.c3` | `Inner`, `Handle`, `Slot`, and the link |
| `mtk::queue` | `queue.c3` | `InnerQueue` and `InnerQueueIterator` |
| `mtk::stack` | `stack.c3` | `InnerStack` |
| `mtk::helper` | `helper.c3` | every crossing between a typed pointer and a `Handle` |
| `mtk::managed` | `managed.c3` | `create` and `release`, for an outer that carries an allocator |
| `mtk::mailbox` | `mailbox.c3` | `Mailbox` |
| `mtk::pool` | `pool.c3` | `Pool` and `PoolHooks` |

- Eight files, eight modules, one module per file. **REVISED by 3TK-46.** `001`
  said the core was one module spread over `mtk.c3`, `inner.c3`, `queue.c3` and
  `stack.c3`, and that `module mtk` was declared by four files. 3TK-44 split it,
  and 3TK-44's own report named this sentence as one it left standing. The table
  above is the state after that split.
- The mailbox and the pool use only the public surface of the core, and
  `run-builds.sh` tests that.

Both are optional. Valid combinations:

```text
core only                       identity and containers, no infrastructure
core + mailbox                  identity + transfer between threads
core + pool                     identity + item reuse
core + mailbox + pool           transfer + item reuse
```

### The modules, one by one

**Eight modules, eight labelled blocks. Written by 3TK-46.**

Each block below is one module's description. It is delimited by an HTML
comment carrying the module's name, which is invisible in the rendered page and
exact when parsed.

```
<!-- 3tk:module mtk::NAME -->
...
<!-- /3tk:module -->
```

**A block is the whole correlation.** The source side is the `<* *>` block
directly above `module X;` in `3tk/src`. Moving one is a copy in either
direction — strip one leading space per line, or add one — and the check is a
`diff`. [3tk-doc-loop-003.md](3tk-doc-loop-003.md) says so under *Moving a
module description*.

**Every block is written in the intersection of the two renderers.** One
sentence per line, never wrapped, every identifier in backticks, no trailing
`\`, no numbered list, no table, no bold. The three restrictions are
[3tk-doc-loop-003.md](3tk-doc-loop-003.md)'s, and the no-bold is the register's.

**These eight are the only labelled blocks in this file.** A declaration's
descriptor is not labelled and is not copied — it is judged, and checked as a
subset. That is the other kind of move.

#### `mtk`

From Part 1. No *Usual flow* exists in Part 1, so there was none to decide
about.

<!-- 3tk:module mtk -->
An item-transfer and item-reuse toolkit for concurrent C3 programs.

Three small tools, each one usable on its own.
The core is type identity for an item, and two containers that never allocate.
`mtk::mailbox` is transfer of an item between threads.
`mtk::pool` is reuse of an item, decided by your hooks.
Mailbox and pool are both optional.
The core alone is a valid use.

Share by communicating.
Do not share access to an item, move the item.
One place has the item at a time.
That gives a concurrent program with no lock around application data.

Not a container library.
The queue and the stack exist because the mailbox and the pool need them, and a caller may use either one directly.
Not an allocator.
Every item is allocated and freed by your code, or by your hooks.
Not a garbage collector.
The toolkit never frees an item you gave it, except through a hook you wrote.
Not a coordinator.
There is no `Master` type.

One import gives the toolkit.
`module mtk` is declared by one file, and the rest are submodules of it.
This module holds `VERSION`, the faults, `@check` and `CHECKED`.
<!-- /3tk:module -->

#### `mtk::inner`

From Part 3's *What this is*, *Participants*, *The API — the Slot* and *The API
— the link*. Part 3's *Usual flow* is the core's, not this module's, and it is
a numbered list with nested bullets: **left out.**

<!-- 3tk:module mtk::inner -->
The inner, the handle, the Slot, and the link.

`Inner` is the field you embed.
The chain link and the identity, in one.
The identity sits in the same field as the chain link.
The identity says what the outer type is.
`Handle` is a pointer to an embedded `Inner`: one item, with the type forgotten.
Everything 3tk transports is a `Handle`.
It is an alias, so it converts freely with `Inner*` and costs nothing.
`Slot` is a box that holds one handle, or nothing.
A Slot starts empty.

The Slot is how the toolkit tells you where an item went.
Read the Slot after every call that gives or takes an item.

The chain link is the other half of `Inner`.
`reset` clears the chain link and not the identity.
Every chain ends at an item pointing at itself, never at null.
That is what makes `is_linked` exact.
<!-- /3tk:module -->

#### `mtk::queue`

From Part 3's *The API — the queue*. No *Usual flow* of its own: **none to
decide about.**

<!-- 3tk:module mtk::queue -->
The intrusive queue. First-in first-out.

The transfer container.
Nothing here allocates, and every operation is O(1).
The count is kept, so `len` is O(1).
`push_back` adds at the back.
There is no front insert.
`pop_front` takes the item at the front, and null on an empty queue is an answer and not a fault.
`append_queue` moves every item of another queue onto the back of this one, in O(1).
`iter` and `next` are a walker, taken from the queue.
Removing the current item during a walk is not supported.
Every chain ends at an item pointing at itself, never at null.
Nothing in the queue can fail.
<!-- /3tk:module -->

#### `mtk::stack`

From Part 3's *The API — the stack*, as 3TK-45 rewrote it. No *Usual flow* of
its own: **none to decide about.**

<!-- 3tk:module mtk::stack -->
The intrusive stack. Last-in first-out.

The storage container.
Where the queue carries items across, the stack holds them still.
The pool keeps one per identity, and it is the only stack 3tk owns.
No 3tk signature passes one: the four that take a container take an `InnerQueue*`.
A caller who wants a stack declares one.
Four operations: no walker, and no splice.
The order is not promised.
No caller is entitled to which item comes back.
Every chain ends at an item pointing at itself, never at null.
Nothing in the stack can fail.
The count is kept, so `len` is O(1).
There is no tail, so flattening the stack is O(n).
<!-- /3tk:module -->

#### `mtk::helper`

From Part 3's *The API — crossing*. No *Usual flow* of its own: **none to
decide about.**

<!-- 3tk:module mtk::helper -->
Every crossing between a typed pointer and a `Handle` lives in one file.

`to_handle` goes from your pointer to a `Handle`.
Null in, null out.
`from_handle` goes from a `Handle` to `$Type*`, and is null on an identity mismatch.
A mismatch is an answer, not a failure.
`must_from_handle` is the same, and it aborts on a mismatch.
The abort names your line.
The same three take the item from a Slot, and five of them appear again as methods.
`from_slot` looks, and the Slot is unchanged.
`move_from_slot` takes, and on success the Slot is left empty.
None of these moves an item.
Reading an identity and casting a pointer leave every container alone.
No alias to declare, no instantiation, no registration.
<!-- /3tk:module -->

#### `mtk::managed`

From Part 3's *The API — allocating an item for you*. No *Usual flow* of its
own: **none to decide about.** Its worked example is a ```c3 fence, which does
survive the crossing, and it is left in the reference because it belongs to a
group of declarations rather than to the module.

<!-- 3tk:module mtk::managed -->
One helper allocates and frees, and only if your struct carries the allocator itself.

`create` allocates the outer, initializes it, and fills the Slot.
The item keeps the allocator for life.
On an allocation failure the Slot is untouched and the fault is returned.
`release` frees the item with the allocator it kept.
It takes no allocator.
It is a no-op on an empty Slot, so a `defer` registered before the acquisition is safe.
No type declares itself managed.
The choice is made at the call site.
<!-- /3tk:module -->

#### `mtk::mailbox`

From Part 4's *What this is*, *Participants* and *Usual flow*. Part 4's *Usual
flow* is a numbered list with nested bullets, and neither shape survives:
**the list is left out, and its one-line summary — *Create, send, receive,
close, release.* — is carried, together with the plain sentences under each
step.** The fence is left in the reference: it is the book's worked example and
it repeats what the sentences already say.

<!-- 3tk:module mtk::mailbox -->
The mailbox. A queue of items, with waiting.

Transfer of an item between threads.
Create, send, receive, close, release.
Many producers, many consumers, on one mailbox.
The mailbox keeps items. It never touches them.
A mailbox is itself an item: it can travel through another mailbox.

The allocator is kept for life.
Nothing partially constructed is ever returned.
On send the Slot is the answer: cleared means the mailbox has the item, untouched means the mailbox is closed and you still have the item.
On receive an empty Slot goes in, and a full Slot comes back on success.
Every other outcome is a fault, and the Slot stays empty.
On close what was left comes back to you, as one queue.
Releasing those items is your work.
The mailbox never knew what they were.
Close it first. Releasing an open mailbox aborts in every build mode.

The mailbox and the pool use only the public surface of the core, and `run-builds.sh` tests that.
The fields named with a leading underscore are internal. Do not read them.
<!-- /3tk:module -->

#### `mtk::pool`

From Part 5's *What this is*, *Participants* and *Usual flow*. Part 5's *Usual
flow* is a numbered list with nested bullets: **the list is left out, and its
one-line summary — *Write the hooks, create, get, put, close, release.* — is
carried, together with the plain sentences under each step.** The block keeps
one ```c3 fence, the `put_all` loop, which was already in the source and is
there because it replaces a call the toolkit does not have. The hooks example
stays in the reference.

**One divergence found and resolved toward the reference.** The fence in
`pool.c3`'s module block today opens `while (mtk::Handle h = ...)`. There is no
`mtk::Handle` — `Handle` is declared in `mtk::inner`, and `mtk::Handle` is the
only occurrence of that spelling anywhere in `3tk/src`, `3tk/test` or
`3tk/negative`. Part 5 says `Handle`, and the block above says `Handle`. **The
source's spelling is a defect that 3TK-47's move corrects by copying.**

<!-- 3tk:module mtk::pool -->
Reuse of an item, decided by your hooks. A keeper of free items, grouped by type identity.

Write the hooks, create, get, put, close, release.
Policy is not in the pool. Policy is in the hooks.
The pool answers whether a reusable item is free right now.
A pool is itself an item: it can travel through a mailbox.

One bucket per identity, in a flat slice allocated once at creation.
The identity set is fixed at creation.
It is not empty, and it has no duplicate. Both are checked.
A stack and not a queue, and the reason is defect surfacing.
The implementing struct is the context. There is no `ctx` parameter.
The hooks are a parameter of creation. A pool cannot exist without them.
On get an empty Slot goes in, and a full Slot comes back on success.
A free item is taken, or `on_get` is asked to make one.
On put the Slot is the answer: cleared means the pool took the item, unchanged means it was refused and you still have the item.
On close nothing comes back to you. Everything goes to `on_close`.
Close it first. Releasing an open pool aborts in every build mode.
The mailbox gives everything back to a caller.
The pool's close gives nothing back at all.

There is no `put_all`. A caller giving a batch back writes the loop.

```c3
while (Handle h = batch.pop_front())
{
    Slot s;
    s.fill(h);
    p.put(&s);
    if (s.is_full()) { batch.push_back(h); break; }
}
```

The mailbox and the pool use only the public surface of the core, and `run-builds.sh` tests that.
<!-- /3tk:module -->

### Master — not part of the API

No `master` module.

No `Master` struct.

A Master is the coordination boundary of your subsystem. It has the mailboxes,
it has the pool, and it decides what the items mean.

Applications build one from:

| what | where it comes from |
|---|---|
| transfer | `Mailbox*` — one or more |
| item reuse | `Pool*` and your `PoolHooks` |
| memory | `Allocator` — who allocates and frees |
| threads | `std::thread` |
| application state | whatever the subsystem needs |

3tk gives the tools. The application assembles them.

### The build modes

The toolkit behaves differently in a checked build and a fast one.

```c3
const bool CHECKED
```

- True where the checks are live.
- Guard an expensive check of your own with it.

What is live in a safe build and gone under `--safe=no`:

- every `@check`
- every C3 contract, including `must_from_handle`'s
- the insert guards on the queue and the stack
- the duplicate scan over a pool's identity set

What never goes away:

- releasing an open mailbox aborts
- releasing an open pool aborts

That difference is the point. A defect that a fast build would carry silently
is named and stopped in a checked one, and the tests run both.

### Where to go deeper

- `3tk/run-builds.sh` — the four builds, and what each one proves.
- `3tk/negative/` — one file per defect the toolkit refuses.
- `3tk/test/t_alloc.c3` — allocation failure, on every creation path.
