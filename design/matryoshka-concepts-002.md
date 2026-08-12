# Matryoshka Concepts (002)


Change from -001: API 12-4 — the doc speaks the pointer API. Methods on  
`*Mbox` / `*Pool`; `new`, `destroy`, `receiveResult`, `getWaitResult` stay  
free functions on the module.


What Matryoshka is, why it exists, and how to think in it.

Merges five earlier docs: the manifesto, the architecture introduction, the  
thinking model, the New Matryoshka reference, and the unversioned model sketch.  
They said overlapping things about the same four concepts. This document  
replaces all of them. Their names are in the DOC 22 entry in `STATUS-LOG.md`.

Companions:
- [matryoshka-architecture-foundation-4-006.md](matryoshka-architecture-foundation-4-006.md) — the four-layer contract in full.
- [language-of-matryoshka.md](language-of-matryoshka.md) — vocabulary. Where a term here differs, the glossary wins.
- [rules-043.md](rules-043.md) — coding, doc, and process rules.
- [patterns-027.md](patterns-027.md) — the pattern and idiom catalog.

---

## Chapter 1 — Why Matryoshka exists

### The problem

We know how to write Zig libraries.

We are still learning how to build Zig systems.

Zig Io answers one question well: *when does work run?*

It does not answer:

- Where are the system boundaries?
- Who owns which state?
- How do parts talk to each other?
- Who controls shared resources?
- How do parts combine into a system?

Without answers, concurrent systems drift:

- nobody knows which code runs in parallel
- parts depend on each other in hidden ways
- the structure just happens — nobody chose it

Io does not prevent any of that. It just runs it faster.

Matryoshka's promise: make building Zig systems a little more ***boring***.

### The concrete shape of the problem

Concurrent systems are built from independent components. These components  
exchange work items.

- A sensor produces readings.
- A processor transforms them.
- A logger writes them to disk.
- A monitor watches for anomalies.

Each component runs in its own task. They must communicate without stepping on  
each other.

```text
┌──────────┐     ┌───────────┐     ┌──────────┐     ┌──────────┐
│  Sensor  │ ──► │ Processor │ ──► │  Logger  │     │ Monitor  │
└──────────┘     └───────────┘     └──────────┘     └──────────┘
                                         ▲               ▲
                                         │               │
                                    How do items    How does Monitor
                                    move safely?    see the same items?
```

Real systems impose hard constraints:

- No shared mutable state between components.
- No allocations on the hot path — the allocator is too slow.
- Components should not know each other's concrete types.
- Each item's place must be clear — who holds it, at every moment.

### Ad-hoc solutions and why they break

**Raw pointers, no place discipline.**

```text
Component A                    Component B
     │                              │
     ├── creates item ──────────►   │ uses item
     │                              │
     ├── frees item                 │ uses item ← use-after-free
     │                              │
```

- No rule about who frees.
- No rule about when.
- Bugs appear under load, not in tests.

**Allocator-per-message.**

```text
     send:    allocate → fill → enqueue
     receive: dequeue → use → free

     Every message = one allocation + one free.
```

- Allocation pressure under high throughput.
- Allocator contention between tasks.

**Type-specific queues.**

```text
     Queue<Event>
     Queue<Request>
     Queue<Response>
     ...
```

- One queue type per message type.
- Every new type = new queue, new synchronization, new bugs.
- Cannot mix types in a single pipeline stage.

**Manual lifecycle.**

```text
     create → use → ... → forget to return → leak
     create → use → ... → return twice → double-free
```

- No enforcement of acquire/release discipline.
- Pool exhaustion under sustained load.

### What was needed

One mechanism that solves all four problems:

- **Universal transfer.** Works for any item type, any pattern.
- **Zero allocations after initialization.** Items are pre-allocated, then
  moved — never copied.
- **Type-safe recovery without generics pollution.** One queue carries all
  types. The receiver recovers the concrete type safely.
- **Each item in exactly one place, always.** The system enforces it.

### Before and after

**Before — ad-hoc connections:**

```text
┌──────────┐         ┌──────────┐         ┌──────────┐
│ Sensor   │         │Processor │         │  Logger  │
│ alloc ──►├─ ptr ──►│ copy ──► ├─ ptr ──►│ free     │
│          │         │ alloc    │         │          │
└──────────┘         └──────────┘         └──────────┘

  • Each link uses a different mechanism.
  • Each type needs its own queue.
  • Where an item is stays implicit — bugs hide.
```

**After — matryoshka:**

```text
┌──────────┐         ┌──────────┐         ┌──────────┐
│ Sensor   │         │Processor │         │  Logger  │
│  Slot ──►├─ mbox ─►│  Slot ──►├─ mbox ─►│  Slot    │
│          │         │          │         │          │
└──────────┘         └──────────┘         └──────────┘

  • Every link uses the same mechanism.
  • One queue carries all types.
  • Where an item is stays explicit — Slot is full or empty.
```

---

## Chapter 2 — The constraint

Matryoshka asks you to accept one constraint.

> Everything is a Master communicating via Mailboxes.

Pools add a second one.

> Shared resources are explicit and controlled.

Two constraints. In return you get:

- you always know who owns what
- parts talk in one way only: messages
- you know what runs in parallel
- you can swap one Master for another
- you can understand one Master without reading the whole system

---

## Chapter 3 — A Master is an Io task

Io creates tasks. Matryoshka lives inside that task world, not beside it.

```text
Application
    |
Io tasks
    |
    +-- ordinary task
    +-- ordinary task
    +-- matryoshka task
    |
Io
    |
OS
```

- `io.concurrent()` is the only way a task starts.
- A Master is an Io task that follows the Matryoshka rules.
- Io answers: how do tasks run?
- Matryoshka answers: how do tasks cooperate?

Master is **not**:

- a type
- an interface
- a runtime

A task becomes a Master when it:

- owns application state
- owns one or more Mailboxes
- owns one or more Pools
- exchanges PolyNode-based items instead of sharing them

Not every task is a Master. Every Master is a task.

```text
Io tasks
    │
    ├── ordinary task
    ├── ordinary task
    └── Master
             │
    ┌────────┼────────┐
    │        │        │
Single-job Coordinator Resource owner
 Master      Master       Master
```

- Some Masters do one job.
- Some Masters coordinate other Masters.
- Some Masters own shared resources.

A *worker* is simply a Master with one job.

### `std.Thread.spawn` is banned

- Matryoshka code, examples, tests, and stories create tasks one way:
  `io.concurrent()`.
- `std.Thread.spawn` must not appear anywhere in this codebase.

### Down to earth

The whole model fits in a few lines.

- A Master has one input mailbox.
- A Master processes one message at a time.
- A Master may send a message to any mailbox. Including its own.
- Multiple Masters may share one mailbox.
- A Master may borrow items from one or more pools.
- Pools may be shared by many Masters.
- Mailboxes and Pools may hold typed or type-erased items.

Nothing else is required.

| Capability          | Primitive                  |
| ------------------- | -------------------------- |
| Receive             | Mailbox                    |
| Send                | Mailbox                    |
| Share communication | Shared Mailbox             |
| Borrow resources    | Pool                       |
| Share resources     | Shared Pool                |
| Heterogeneous data  | Type-erased Mailbox / Pool |

Everything else is a Master, or a composition of Masters:

- dispatchers
- routers
- schedulers
- timers
- services
- actors
- pipelines
- reactors

---

## Chapter 4 — Four fundamental concepts

```text
PolyNode
    Everything exchanged.

Mailbox
    Everything communicates.

Pool
    Everything reusable lives here.

Master
    Everything runs inside one.
```

Master is an Io task. The other three are code.

Each concept below answers the question the previous one creates.

### Step 1 — Intrusive node

Concurrent components process items in order. The natural structure is a queue.  
A queue is a linked list.

A non-intrusive list allocates a wrapper node per item. Each enqueue is an  
allocation; each dequeue is a free.

An intrusive list embeds the link pointers inside the item itself:

```text
  ┌────────────┐     ┌────────────┐     ┌────────────┐
  │ UserItem   │     │ UserItem   │     │ UserItem   │
  │ ┌────────┐ │     │ ┌────────┐ │     │ ┌────────┐ │
  │ │  next ─┼─┼────►│ │  next ─┼─┼────►│ │  next  │ │
  │ │  prev  │ │     │ │  prev  │ │     │ │  prev  │ │
  │ └────────┘ │     │ └────────┘ │     │ └────────┘ │
  │  payload   │     │  payload   │     │  payload   │
  └────────────┘     └────────────┘     └────────────┘

  Zero allocations for list operations.
  The item IS the node.
```

In Zig the intrusive node comes from the standard library: `std.DoublyLinkedList.Node`.  
`prev` and `next` pointers. Nothing else.

### Step 2 — Runtime identity (Tag)

> I have a `*Node`. How do I know what type of item it belongs to?

Different item types live in the same list. The node carries no type  
information. Attach a tag.

```text
┌─────────────────┐
│    PolyNode     │
│ ┌─────────────┐ │
│ │    Node     │ │    Node = list links (prev, next)
│ │ (prev/next) │ │
│ └─────────────┘ │
│ ┌─────────────┐ │
│ │     Tag     │ │    Tag = pointer to a unique address
│ └─────────────┘ │
└─────────────────┘

  PolyNode = Node + Tag
```

Each type gets a unique tag — a pointer to a distinct static variable:

```zig
var _event_tag: PolyTag = .{};
pub const EVENT_TAG: *const anyopaque = &_event_tag;
```

Check identity with `node.tag == EVENT_TAG`. Recover the concrete type with  
`@fieldParentPtr(Event, "poly", node)`.

**Tag identifies class, not instance or role.**

- Every instance of `Event` carries the same `EVENT_TAG`. It says "this is an
  Event", not "which Event" or "what kind of Event".
- For user-defined types, add a `kind` or `role` field for per-instance
  discrimination.
- For infra handles (`*Mbox`, `*Pool`) the internal structs are
  private. No fields can be added. Tag identifies the class only.
  - Instance identity is resolved by pointer comparison against known handles.
  - Role is established by protocol: the channel the handle arrived on, message
    ordering, or prior agreement.
- See [matryoshka-api-reference-036.md](matryoshka-api-reference-036.md),
  "Tag identity — class, not instance".

`switch` over tags does not compile. The reason and the repro live in
[table-dispatch-002.md](table-dispatch-002.md).

### Step 3 — Place (Slot)

> I have a `*PolyNode`. Where is it right now?

Raw pointers leave the item's place implicit. Two components might both think  
they hold the same item.

```zig
pub const ItemHandle = *PolyNode;
pub const Slot = ?ItemHandle;
```

```text
┌─────────────────┐          ┌─────────────────┐
│   Full Slot     │          │   Empty Slot    │
│   ItemHandle    │          │      null       │
└─────────────────┘          └─────────────────┘
     You hold it.              You don't hold it.
```

Transfer has a simple rule:

```text
  send:     Full  →  Empty     (you gave it away)
  receive:  Empty →  Full      (you got one)
```

- After send, your slot is null. You cannot use the item.
- After receive, your slot holds a handle. You hold it.
- No ambiguity. No double hold.

### Step 4 — Transport (Mailbox)

> How do I move an item from one component to another?

`Mailbox`:

- transfers `PolyNode` items between Masters
- transfers the object, not a reference to it
- does not know or care about the concrete object type

```text
  Producer                   Mailbox                   Consumer
  ┌──────────┐              ┌──────────┐              ┌──────────┐
  │  Slot ───┼── send() ───►│  queue   │◄── recv() ───┼── Slot   │
  │  (→null) │              │          │              │  (→full) │
  └──────────┘              └──────────┘              └──────────┘
```

- One handle, one place, always.
- The mailbox is temporary storage during transit.
- Send and receive are the only ways to move an item.

### Step 5 — Lifecycle (Pool)

> Items are pre-allocated. After the consumer is done, how do I reuse them?

`Pool`:

- reuses `PolyNode`-based items
- returns items for reuse instead of destroying them
- does not know or care about the concrete object type

```text
                    ┌─────────────────────────────────────┐
                    │                                     │
                    V                                     │
  ┌──────────┐   get()   ┌──────────┐  work   ┌──────────┐
  │   Pool   │ ────────► │  Slot    │ ──────► │   done   │
  │          │           │  (full)  │         │          │
  └──────────┘           └──────────┘         └──────────┘
                                                   │
                                                put()
                                                   │
                                              back to Pool
```

No allocations. No frees. Items cycle through the system.

### Step 6 — Coordination (Master / Select)

> A component receives from a mailbox and gets items from a pool. How does it
> wait on both?

- Master registers mailboxes and pools as event sources.
- `Io.Select` waits on multiple sources simultaneously.
- When any source has an item, the component wakes and processes it.

The component does not poll. It reacts.

### The full picture

```text
  PolyNode         = identity      (what is it?)
  Tag              = type marker   (which kind?)
  Slot             = place         (who has it?)
  Mailbox          = transport     (move it)
  Pool             = lifecycle     (reuse it)
  Master / Select  = coordination  (wait for it)
```

### Together

`Mailbox` and `Pool` are containers on steroids. The steroids are simple:

- intrusion
- type erasure
- object transfer
- object reuse

Nothing else. No interfaces. No framework.

The whole troika is 582 lines of code.

---

## Chapter 5 — The thinking model

### The mantra

Every Matryoshka design starts with one question.

> Who owns this item right now?

- Not "what data does this item hold."
- Not "which task processes it."
- Just: who owns it.

Who holds it is visible at the call site. If you must read the implementation  
to know who holds an item, the design is wrong.

### Route state, not data

- Pass the item's pointer, not byte copies.
- The object that carries state moves between owners.
- Whoever holds it has exclusive access.
- Wrong: put raw data into a queue, process it, produce results.
- Right: route the object that carries the state machine.

### The item moves, it never duplicates

- An item has exactly one owner at any moment.
- Owners: user code (IN_FLIGHT), mailbox (HELD), pool (HELD).
- When the item moves, the slot becomes null.
- `slot.* = null` is the transfer protocol, not a bookkeeping detail.
- The null is the proof of transfer.

### Transfer = lock-free concurrency

- One owner at a time means no mutex during processing.
- Not a lock-free algorithm. Just: one owner at a time.
- The routing gives the lock-freedom.

### The transfer orders memory

- Exclusive access has two halves. Possession is the visible one.
- The second half: the new holder sees every write the previous holder made.
- Mailbox and pool publish through their own mutex. That is what carries it.
- So a holder reads the item's fields with plain loads. No atomics. No fences.
- This is why the library can assert on an item's internal state at all.
- It does not extend to an item two holders both believe they hold. That
  mistake breaks the premise the guarantee is built on.
- See [rules-043.md](rules-043.md) for how to phrase this in `src/` comments.

### Pool availability = backpressure signal

- An empty pool is not just an error condition.
- It is a backpressure signal.
- `pool.getWaitResult` inside `Io.Select` makes availability a first-class
  event source.
- One loop handles data and buffer availability together.
- When a worker returns an item, the pool wakes the waiter and the waiter
  resumes.
- No sleep. No poll. No explicit backpressure code.

### Pool items are empty containers

- `Pool.get` returns a resource — an empty, reusable container.
- The container carries no work intent on acquisition.
- "Empty" means: whatever the previous owner wrote has been consumed or reset.
- To do useful work, a worker needs at least one additional input:
  - External data: mailbox message, network read, timer tick, shared counter.
  - Worker's own accumulated state from previous cycles.
- A worker that only calls `Pool.get` and `Pool.put` with no other input source
  does nothing useful.
- This applies to examples and stories alike: a pool resource alone is never
  enough to define a complete pattern.

### Layers compose

```text
PolyNode           who owns this item?
  +
Mailbox            how does the item move?
  +
Pool               should this item be reused or destroyed?
  +
Master             who coordinates startup, shutdown, cancellation, policy?
```

- Need holding and movement only: use PolyNode + Mailbox. Stop there.
- Need backpressure and reuse: add Pool.
- Need coordination: add Master.
- The holding model never changes. Only capabilities are added.

The full four-layer contract — Hold, Movement, Lifecycle, Coordination — lives  
in [matryoshka-architecture-foundation-4-006.md](matryoshka-architecture-foundation-4-006.md).

### Cancel is not close

- `error.Canceled` — the Io scheduler says stop now. External signal.
- `Mbox.close` / `Pool.close` — the Master says this subsystem is shutting
  down.
- Cancel stops waiting.
- Close signals end-of-stream.
- Cancel does not trigger close.
- A worker that gets `error.Canceled` reports it. The Master decides what to do.

### When to allocate a Master

Two tiers. The rule applies to the top-level `run` function and to worker  
functions alike.

Flat (simple case).

- Minimal functionality: one loop, one action per iteration.
- All state fits in local variables.
- Short lifecycle: exits cleanly on close or cancel.
- No shared state between steps.

Allocate a Master struct on the heap (complex case).

- Multiple steps or phases with state shared between them.
- Complex lifecycle: distinct init / work / shutdown phases.
- `run` method needs named private steps to remain readable.
- Growing functionality that would make a flat function hard to follow.

---

## Chapter 6 — Three-category model

Tests, examples, and stories have different jobs.

### Test

- Checks correctness.
- One behavior at a time.
- Edge cases, error paths, state transitions, contract violations.
- Scope: one API call or one invariant.
- Internal artifact. Not user docs.

### Example

- Shows how to use one pattern.
- One API interaction. One layer.
- "How to seed a pool." "How to do fan-in."
- Reader learns what to call and in what order.
- Shows a complete pattern: origin of work input, what the worker does, where
  results go.
- An example that shows only lifecycle or shutdown — without a work input
  source — cannot be used as a template.
- Small examples use a flat function. Big examples allocate a Master struct.
- Part of the docs.

### Story

- Shows how to think with Matryoshka.
- Multiple layers composing into a real flow.
- Starts from a real domain problem. Translates to Matryoshka patterns.
  Implements.
- Reader learns how to reason about a new problem by asking who holds what.
- Pool resources in a story must have an explicit work input source — mailbox,
  network, timer, or worker state.
- Stories always use the Master pattern. A story is never a flat function.
- Part of the docs.

A story is not a large example. It is a different kind of artifact.

To qualify as a story it must show at least two layers composing, and it must  
have a real domain problem.

The file layout and signatures for a story are a process rule. They live in
[rules-043.md](rules-043.md), "Story structure".

---

## Chapter 7 — Where Io fits

Matryoshka and Io solve different problems.

- Matryoshka answers: what is my system made of?
- Io answers: when does my code run?

The bridge between them is one idea:

> Everything that happens in the system becomes a message in a Master's mailbox.

A timer expired. A socket became readable. A background job finished. Another  
Master sent a job.

Inside the system, all of these are the same thing: a message in a mailbox.

```text
           +----------------+
           |   Io runtime   |
           +----------------+
                  │
            wait for events
                  │
                  V
          +---------------+
          | Bridge        |
          | (a Master)    |
          +---------------+
                  │
             send message
                  │
                  V
             Master Mailbox
                  │
                  V
               Master
```

The bridge is just another Master. It waits on Io events and turns them into  
ordinary messages.

So for application developers:

- Io is not a concept.
- You do not think about Io while designing.
- Io just moves messages behind Mailboxes. You never see it.

A good design test:

> If you have to mention Io while designing your system, it is already too
> visible.

### Minimal dependency

Matryoshka depends on two Io primitives:

- `Io.Mutex`
- `Io.Condition`

Nothing else from Io is required to build the troika. Io may grow new  
schedulers, executors, or task styles; Matryoshka does not change. It needs  
only `io.concurrent()` to create tasks and the two primitives above to  
coordinate them.

### Not a framework

- Matryoshka does not own the application.
- Matryoshka does not provide a runtime. Io already does.
- Matryoshka does not replace `io.concurrent()`. It uses it.
- Matryoshka is a small set of rules for what a task does once Io has created
  it.

---

## Chapter 8 — Start small

There is no big-bang adoption.

- Start your first Master with the simplest building block: `PolyNode`.
- Add `Pool` when object reuse becomes useful.
- Add `Mailbox` when you need message passing.
- Or use your own type-erased queue.

Each step is useful right away. Each step remains useful after the next one.

### A simple question

Can you describe your application using only:

- Masters
- Mailboxes
- Pools

If the answer is **yes**, you're already thinking in Matryoshka.

Don't be afraid.

Go ahead.

**Be Master of your systems.**
