# Matryoshka Architecture Foundation

The four-layer contract: what each layer solves, what it refuses to solve, and  
why each boundary sits where it does.

Read [matryoshka-concepts-001.md](matryoshka-concepts-001.md) first. It covers  
what Matryoshka is, why it exists, and the four concepts. This document assumes  
all of that and starts at the layer contracts.

Companion: [matryoshka-api-reference-033.md](matryoshka-api-reference-033.md) — the shipped surface.\  
Companion: [matryoshka-zig-0.16-notes-002.md](matryoshka-zig-0.16-notes-002.md) — the Zig 0.16 constraints.

---

# 1. Hold States and Transfers

An item can exist in four conceptual states.

### FREE

The item exists but is not currently held by any Matryoshka subsystem.

Examples:

* newly created
* about to be destroyed

---

### HELD

The item is held by infrastructure.

Examples:

* mailbox queue
* pool free list

User code does not hold the item.

---

### IN_FLIGHT

The item is held by user code.

The user must eventually:

* transfer it
* recycle it
* destroy it

This is the state where application logic runs.

---

### INVALID

Bug state.

Examples:

* use after free
* corrupted tag
* double insertion
* invalid handle

INVALID is not a normal runtime condition.

It represents a programming error.

---

## Transfers

Hold changes through operations.

Example:

```text
pool_get
```

Before:

```text
Pool holds item
```

After:

```text
Caller holds item
```

Example:

```text
mailbox_send
```

Before:

```text
Caller holds item
```

After:

```text
Mailbox holds item
```

Hold always moves.

It never duplicates.

That single rule removes an entire category of shared-state problems.

---

# 2. Layer 1 — Hold

Layer 1 consists of:

```text
PolyNode
Tag
Slot
```

Nothing more.

This is the smallest useful Matryoshka system.

Its purpose is to make hold visible.

---

## What Layer 1 Solves

Without Layer 1, hold often exists only in comments and conventions.

Example:

```text
create
fill
send
destroy
```

Questions quickly appear:

```text
Who destroys it?

Can I still use it?

Did hold transfer?
```

The answers may exist somewhere in documentation.

They are rarely visible at the call site.

Layer 1 makes hold explicit.

---

## What Layer 1 Does Not Solve

Layer 1 does not provide:

* concurrency
* messaging
* pooling
* coordination

It only provides vocabulary for where an item is.

That is intentional.

Hold must be understood before movement.

---

## Why Stop Here?

Many programs never need more.

If hold is visible and the application is simple, Layer 1 may be enough.

Matryoshka does not require adopting all layers.

The next layer is added only when a new problem appears.

---

# 3. Layer 2 — Movement (Mailbox)

Once hold is visible, the next problem appears:

> How do we move hold between tasks?

Layer 2 introduces Mailbox.

Mailbox transfers hold.

It does not share memory.

---

## What Mailbox Is

Mailbox is an transport.

Examples of tasks:

* threads
* workers
* masters
* subsystems

Instead of sharing memory:

```text
Thread A ---> shared object <--- Thread B
```

Matryoshka prefers:

```text
Thread A
    |
    v
 Mailbox
    |
    v
Thread B
```

Hold moves.

Memory does not become shared.

---

## Mailbox Responsibilities

Mailbox provides:

```text
send
receive
interrupt
close
```

Nothing more.

Mailbox is not:

* actor framework
* scheduler
* service bus
* workflow engine

Its only purpose is moving hold.

---

## Hold Through Mailbox

Sending:

```text
Caller
    |
    v
Mailbox
```

Receiving:

```text
Mailbox
    |
    v
Caller
```

The rule set from Layer 1 remains unchanged.

Mailbox simply adds movement.

---

## No Silent Data Loss

Items in a mailbox at shutdown are never silently discarded.

Every item ends up in exactly one holder's hands.

Two implementation models satisfy this invariant:

**Receive-empties model**:

- `mailbox_close` sets the closed flag only.
- Receivers continue consuming items until the queue is empty.
- Only then do they get the closed signal.
- Inside the receive loop, data has priority — a queued item is returned before any closed or interrupted signal is checked.

**Close-snapshots model**:

- `mailbox_close` removes all items from the queue atomically under the lock, then signals closed.
- Receivers that arrive after close find an empty queue and get the closed signal.
- Items go to `mailbox_close`'s caller.

In both models, no item is lost. The close caller recovers remaining items:
- receive-empties: by consuming them via receive
- close-snapshots: by walking the list returned by close

**Data priority over interrupt** applies in both models.

- Inside the receive loop, when the queue is non-empty, items are dequeued before checking interrupt signals.
- An interrupt does not preempt an already-queued item.

---

## Communication Patterns

Mailbox supports several hold movement patterns.

### Fan-in

Many senders. One receiver.

```text
Sender A ──┐
Sender B ──┼──→ Mailbox ──→ Receiver
Sender C ──┘
```

Each sender transfers hold of its item.

The receiver gets items one at a time.

Tag dispatch tells the receiver what each item is.

This is the most common Matryoshka pattern.

---

### Fan-out

One sender. Many workers share a mailbox.

```text
                ┌──→ Worker A
Sender ──→ Mailbox ──→ Worker B
                └──→ Worker C
```

Each item goes to exactly one worker.

Hold moves to whichever worker receives it.

No item is shared. No item is duplicated.

---

### Pipeline

Items flow through a chain of mailboxes.

```text
Mbox A ──→ Worker ──→ Mbox B ──→ Worker ──→ Mbox C
```

Each worker receives from one mailbox.

Each worker sends to the next.

Hold moves forward. Never backward.

---

## When Mailbox Is Not Needed

Mailbox is optional.

Some runtimes already provide coordination:

* futures deliver results directly
* select waits on multiple sources
* groups manage worker sets

When these handle the coordination, adding a mailbox duplicates transport.

Mailbox is the right choice when:

* items flow from many independent senders
* the receiver does not know the senders in advance
* items arrive at unpredictable times
* fan-in or pipeline patterns are needed

Mailbox is not needed when:

* a worker returns one result via a future
* coordination uses select with external event sources
* no queued hold transfer happens

---

## Why Stop Here?

Many systems only need:

```text
hold
+
movement
```

A mailbox may be enough.

The next layer appears when allocation and destruction become expensive.

---

# 4. Layer 3 — Lifecycle (Pool)

Layer 1 makes hold visible.

Layer 2 moves hold.

Layer 3 introduces reuse.

The question changes from:

> Who holds this item?

to:

> Should this item be reused or destroyed?

Pool exists to answer that question.

---

## Why Pool Exists

Many systems repeatedly create and destroy the same kinds of items:

* request buffers
* events
* messages
* work items
* temporary structures

Creating and destroying them every time may become expensive.

The obvious solution is a pool.

Unfortunately, many pools mix together several responsibilities:

* backpressure
* allocation
* construction
* destruction
* reuse policy

Eventually the pool becomes a second memory manager.

Matryoshka separates these concerns.

Pool is not storage — it is a backpressure signal for reuse.

Hooks decide what happens to items.

---

## Pool Responsibilities

Pool provides three capabilities:

```text
get
put
close
```

Nothing more.

Pool is not:

* an allocator
* a garbage collector
* an object manager
* a dependency container

Pool is simply a backpressure signal for reusable hold.

---

## Pool Hold Rule

Getting an item transfers hold from Pool to the caller.

```text
Pool
    ↓ get
Caller
```

Putting an item transfers hold from the caller back to Pool.

```text
Caller
    ↓ put
Pool
```

The caller never shares hold with Pool.

Hold always moves.

---

## Pool Is Intentionally Asymmetric

Most APIs look symmetrical:

```text
acquire
release
```

Pool is different.

### Get

Get always attempts to produce hold.

Conceptually:

```text
stored item
    or
new item
```

After success:

```text
Caller holds item
```

---

### Put

Put does not guarantee reuse.

Put asks a policy question:

> Should this item remain available for reuse?

Possible outcomes:

```text
keep
```

or

```text
destroy
```

The answer comes from hooks.

This asymmetry is intentional.

---

## Hooks

Pool is not storage.

Hooks contain policy.

Without hooks, Pool would not know:

* how to create an item
* how to reset an item
* when to destroy an item

Hooks provide that knowledge.

---

## on_get

`on_get` prepares an item for use.

Possible situations:

### No stored item exists

Create a new item.

Conceptually:

```text
m == null
    create
```

---

### Stored item exists

Reuse it.

Conceptually:

```text
m != null
    reset
```

Examples:

```text
Chunk
    len = 0

Progress
    percent = 0
```

The caller receives a ready-to-use item.

---

## on_put

`on_put` decides whether an item should remain in the pool.

Examples:

```text
Pool contains 20 chunks
    keep
```

```text
Pool contains 500 chunks
    destroy
```

Pool itself does not know what is too many.

Policy decides.

---

## Pool Reuse vs Policy

This separation is important.

Pool answers:

```text
Is a reusable item available right now?
```

Hooks answer:

```text
Should this item exist?
```

Keeping those responsibilities separate prevents Pool from becoming a second allocator.

---

## Typical Lifecycle

A common flow looks like:

```text
Pool
    ↓ get
Caller
    ↓ fill
Mailbox
    ↓ receive
Worker
    ↓ process
Pool
```

Hold moves.

Reuse stays centralized.

Reuse remains explicit.

---

## Pool and Hold States

Pool primarily interacts with two states.

### HELD

The pool holds the item.

Examples:

```text
free lists
stored items
```

---

### IN_FLIGHT

User code holds the item.

Represented conceptually by:

```text
m != null
```

The caller may:

* fill it
* send it
* recycle it
* destroy it

Eventually hold returns somewhere.

---

## Pool and Mailbox

Mailbox and Pool solve different problems.

Mailbox answers:

> Where should hold move?

Pool answers:

> What should happen after hold returns?

A common pattern is:

```text
Pool
    ↓
Sender
    ↓
Mailbox
    ↓
Receiver
    ↓
Pool
```

The same item may travel through many tasks while remaining under one rule set.

---

## Pool Close

Closing a pool stops future reuse.

After close:

```text
get
    fails
```

Stored items are returned to the holder responsible for final cleanup.

Pool does not destroy items automatically.

The subsystem that holds the pool decides what final cleanup means.

This keeps lifecycle decisions visible.

---

## Communication Patterns

Pool supports several lifecycle movement patterns.

### Fan-in (many return)

Many workers return items. One holder acquires.

```text
Worker A ──put──┐
Worker B ──put──┼──→ Pool ──get──→ Master
Worker C ──put──┘
```

Workers finish with items and put them back.

Master gets items when it needs them.

Hold flows from many sources into one destination.

---

### Fan-out (many acquire)

One holder fills the pool. Many workers acquire.

```text
                    ┌──get──→ Worker A
Master ──→ Pool ────┼──get──→ Worker B
                    └──get──→ Worker C
```

Each worker gets its own item.

No item is shared. Each get transfers hold to one worker.

---

### Job pool (circular)

Items cycle between Master and workers through the pool.

```text
Master ──get──→ fill ──→ submit ──→ Worker
   ↑                                  │
   └────── get_wait ←── Pool ←── put ─┘
```

Worker finishes a job.

Worker returns the item to the pool.

Pool signals availability.

Master acquires the returned item.

Master fills it with new work.

Master submits it again.

Hold flows in a circle.

The pool controls the pace.

When the pool is empty, the Master waits.

When a worker returns an item, the Master can proceed.

This is the job pool pattern.

---

## Pool Without Mailbox

Pool can coordinate work without a mailbox.

When a runtime provides futures and event source waiting:

```text
Master ──get──→ Worker
   ↑               │
   │           process
   │               │
   └── get_wait ←── Pool ←── put ─┘
```

No mailbox is involved.

Pool provides what the runtime does not:

* object reuse
* capacity control
* lifecycle policy
* destruction policy

The runtime provides:

* task spawning
* result delivery
* cancellation
* waiting on multiple sources

Together they form a complete coordination model.

Pool + runtime coordination is sufficient for:

* job scheduling
* resource management
* capacity-controlled pipelines
* worker pools with reusable buffers

Add mailbox only when independent senders need to deliver items.

---

## Why Pool Is A Separate Layer

Pool is not required.

Many systems only need:

```text
PolyNode
Mailbox
```

and nothing more.

Pool exists because reuse eventually becomes useful.

Layer 3 is therefore optional.

Open the third doll only when allocation and destruction become painful enough to justify it.

The rule set does not change.

Only the lifecycle options grow.

# 5. Layer 4 — Coordination (Master)

Layer 1 introduces hold.

Layer 2 introduces movement.

Layer 3 introduces lifecycle.

Layer 4 introduces coordination.

This is where complete subsystems appear.

---

## Why Master Exists

Mailbox knows how to move hold.

Pool knows how to manage reusable hold.

Neither knows why the system exists.

Neither knows:

* startup order
* shutdown order
* cancellation rules
* who holds each resource
* subsystem policy

Those decisions must live somewhere.

Master is that place.

---

## Master Is A Concept

Master is different from PolyNode, Mailbox, and Pool.

PolyNode, Mailbox, and Pool are concrete building blocks.

Master is not.

Master is a design concept.

A Master represents:

> A bounded execution domain that coordinates hold movement, lifecycle management, and subsystem policy.

There is no required Master structure.

There is no required inheritance.

There is no required interface.

Different systems may implement Master differently.

---

## Typical Master Contents

A Master often contains:

```text
Mailbox
Pool
Hooks
Allocator
Configuration
Runtime State
Cancellation State
```

but this is only a common pattern.

## Valid Master Shapes

Every combination is valid:

```text
PolyNode only                    hold without infrastructure
PolyNode + Mailbox               hold + transport
PolyNode + Pool                  hold + lifecycle
PolyNode + Mailbox + Pool        hold + transport + lifecycle
PolyNode + Pool + Select         lifecycle + event sources (no mailbox)
PolyNode + Mailbox + Pool + Select   full stack
```

A mailbox-less Master:

```text
Pool + Select (no mailbox)

                ┌── Pool ────→ available items
Master ←── wait ┤
                ├── Timer ───→ periodic work
                └── Network ─→ external data
```

A mailbox-only Master:

```text
Mailbox only (no pool)

Sender A ──┐
Sender B ──┼──→ Mailbox ──→ Master
Sender C ──┘
```

A full-stack Master:

```text
Mailbox + Pool + Select

                ┌── Mailbox ─→ incoming commands
Master ←── wait ┤
                ├── Pool ────→ available workers
                └── Timer ───→ maintenance
```

Matryoshka does not impose a fixed shape.

---

## Master Is Not Required To Be A PolyNode

Many infrastructure items are represented as PolyNodes.

Master does not have to be.

This is an important distinction.

The following is valid:

```text
Master
 ├─ Mailbox
 ├─ Pool
 └─ State
```

without Master participating in transport.

---

## Master May Be A PolyNode

Some designs may choose to make Master transportable.

For example:

```text
Master
    contains PolyNode
```

This allows Masters to participate in the same rule set.

That can be useful.

But it is a design choice.

Not a requirement.

---

## Recommended View

Think of Master as:

```text
subsystem
```

not:

```text
object
```

The important part is the responsibility.

Not the structure.

---

## Master Responsibilities

A Master typically holds three domains.

### Transport Domain

Movement of hold.

Examples:

```text
Mailbox
Mailbox group
Routing
```

---

### Resource Domain

Lifecycle of reusable items.

Examples:

```text
Pool
Allocators
Caches
```

---

### Policy Domain

Subsystem-specific decisions.

Examples:

```text
Hooks
Configuration
Limits
Business rules
```

---

## Coordination Boundary

Master is where independent layers meet.

```text
          Hold
               │
               V
          Mailbox
               │
               V
            Pool
               │
               V
           Master
```

The layers themselves remain independent.

Master combines them into a working subsystem.

---

## Startup

Master decides how infrastructure is created.

Example:

```text
create mailbox
create pool
initialize hooks
start workers
```

Neither Mailbox nor Pool should know startup order.

---

## Shutdown

Master decides shutdown order.

Typical sequence:

```text
stop new work
close mailbox → recover remaining items
close pool    → recover remaining items
release resources
```

How items are recovered depends on the implementation model:

- **Mailbox**: `mailbox_close` returns the remaining list; caller walks and frees each item.
- **Pool**: `pool_close` either returns the remaining list for the caller to walk, or calls an `on_close` hook with the full list. The hook walks and frees. Which mechanism applies depends on whether the pool has registered hooks.

Neither Mailbox nor Pool should know global shutdown policy.

---

## Hold Flow

Master defines how hold moves through the subsystem.

Example:

```text
Pool
  ↓
Sender
  ↓
Mailbox
  ↓
Worker
  ↓
Pool
```

The hold rules themselves come from lower layers.

Master only coordinates them.

---

## Combined Patterns

A Master can combine Mailbox and Pool patterns.

### Producer → Consumer with recycling

```text
Pool ──get──→ Producer ──send──→ Mailbox ──receive──→ Consumer ──put──→ Pool
```

Items cycle: pool → producer → mailbox → consumer → pool.

Hold is always clear.

No item is ever shared.

---

### Fan-in with lifecycle

Multiple producers. One consumer. Pool manages reuse.

```text
Producer A ──send──┐
Producer B ──send──┼──→ Mailbox ──receive──→ Consumer ──put──→ Pool
Producer C ──send──┘                                           │
      ↑                                                        │
      └──────────────────── get ───────────────────────────────┘
```

Producers get items from the pool.

Consumer returns items to the pool.

The pool controls how many items exist.

---

### Job pool with event sources

Master waits on both mailbox and pool at once.

```text
                ┌── Mailbox ──→ commands
Master ←── wait ┤
                └── Pool ─────→ available workers

    Worker ──put──→ Pool
```

Commands arrive via mailbox.

Worker capacity arrives via pool.

Master reacts to whichever comes first.

This is the event source pattern from Layer 4.

---

## Cancellation

Cancellation belongs to Master.

Not Mailbox.

Not Pool.

A subsystem decides when it should stop.

That decision belongs to subsystem coordination.

Therefore it belongs to Master.

---

## Mailbox and Pool as Event Sources

A Master often waits on several things at once.

Examples:

```text
mailbox item
timer
network event
pool availability
shutdown signal
```

Mailbox and Pool already know how to wait.

They can participate in external coordination directly.

---

## How It Works

A blocking operation becomes an event source.

```text
mailbox receive → waits for item
pool get_wait   → waits for available item
```

The runtime waits on all event sources at once.

Whichever completes first delivers its result.

```text
Event Sources
    ├─ mailbox receive
    ├─ pool get_wait
    └─ timer

    ↓ whichever fires first

Master handles result
```

---

## Why This Matters

Without event sources:

```text
one worker loop
one mailbox
one wait
```

With event sources:

```text
one event loop
many sources
one handler
```

A Master can coordinate Matryoshka items alongside external operations.

---

## Pool Availability as an Event

Pool is not storage — it is a backpressure signal.

Pool availability can drive work.

```text
Worker finishes job
    ↓
pool put
    ↓
item becomes available
    ↓
Master notified
    ↓
Master submits new work
```

This is the job-pool pattern.

Pool availability becomes a reactive signal.

---

## Two Coordination Models

Inside Matryoshka:

```text
multiple senders
    ↓
one mailbox
    ↓
tag dispatch
```

When items carry hold, use fan-in to one mailbox.

One queue. One rule set. One shutdown model.

When items do not carry hold, other approaches may be simpler.

Bridging to external operations:

```text
mailbox + timer + network + pool
    ↓
wait on all sources at once
    ↓
one event loop
```

The two models are complementary.

---

## Cancel and Close Remain Separate

Cancel is an external signal.

Close is a Master decision.

An event source adapter reports cancel.

It does not act on it.

```text
cancel arrives
    ↓
adapter returns "canceled"
    ↓
Master decides what to do
```

Close belongs to Master.

Not to the adapter.

Not to the infrastructure.

---

## Why Master Is The Final Layer

Without Master:

```text
Mailbox
Pool
```

remain useful but isolated.

Master transforms building blocks into a subsystem.

This is the point where hold, movement, and lifecycle become a complete design.

---

# 6. Concurrency Contract

Matryoshka uses three independent communication channels.

They solve different problems.

They must remain separate.

---

## DATA Channel

The DATA channel carries hold.

Lives in:

```text
Mailbox queue
```

Purpose:

```text
hold transfer
```

Properties:

```text
FIFO
queued
persistent
```

Data remains available until consumed.

---

## DATA Example

```text
Sender
    ↓
Mailbox
    ↓
Receiver
```

Hold moves from sender to receiver.

Nothing else happens.

---

## INTERRUPT Channel

The INTERRUPT channel carries meaning.

Lives in:

```text
Mailbox interrupt state
```

Purpose:

```text
wake waiting code
```

Examples:

```text
reload
flush
reconnect
configuration changed
command received
```

Properties:

```text
temporary
consumed
latest wins
```

Interrupt is an event.

---

## INTERRUPT Example

```text
Worker waiting
    ↓
interrupt
    ↓
wake
    ↓
handle event
```

No hold transfer occurs.

---

## When INTERRUPT Becomes Unnecessary

The original design assumes a mailbox carries one kind of item.

Interrupt exists because the receiver needs a way to wake for a different reason.

But every Matryoshka item carries a tag.

The tag says what kind of item it is.

A signal is just an item with a signal tag.

```text
regular item
    tag = DATA_TAG

signal item
    tag = RELOAD_TAG
```

Both arrive through the same queue.

Both follow the same hold rules.

The receiver checks the tag and knows what to do.

```text
receive
    ↓
check tag
    ↓
DATA_TAG     → process
RELOAD_TAG   → reload config
```

When items carry their own meaning:

* no separate interrupt state is needed
* no separate interrupt channel is needed
* signals become priority items at the front of the queue

```text
3-channel model
    DATA
    INTERRUPT
    CANCEL

2-channel model
    DATA (includes signals as tagged items)
    CANCEL
```

The 2-channel model works when:

* every item has a runtime type tag
* the mailbox supports priority insertion

Both conditions are met in Matryoshka.

The 3-channel model remains valid for systems where items do not carry type identity.

---

## CANCEL Channel

The CANCEL channel carries termination state.

Lives in:

```text
Master
```

Purpose:

```text
stop execution
```

Properties:

```text
persistent
monotonic
terminal
```

Cancel is state.

Not an event.

---

## CANCEL Example

```text
running
    ↓
cancel
    ↓
stopping
    ↓
stopped
```

Cancellation does not disappear after being observed.

---

## The Critical Rule

```text
Interrupt != Cancel
```

Interrupt means:

```text
Wake up and do something.
```

Cancel means:

```text
Stop.
```

These are fundamentally different concepts.

---

## Why Separation Matters

If interrupt and cancel are merged:

```text
interrupt
```

might accidentally stop a subsystem.

Or:

```text
cancel
```

might accidentally be consumed and forgotten.

Both outcomes are incorrect.

Keeping them separate makes behavior predictable.

---

## Layer Responsibilities

The channels belong to different layers.

```text
DATA
    Mailbox

INTERRUPT
    Mailbox

CANCEL
    Master
```

Pool is intentionally absent.

Pool manages lifecycle.

Not execution.

Not coordination.

---

## Summary

3-channel model:

```text
Mailbox
    DATA
    INTERRUPT

Master
    CANCEL
```

2-channel model (tagged items):

```text
Mailbox
    DATA (includes signals as tagged items)

Master
    CANCEL
```

Pool holds:

```text
lifecycle
```

These responsibilities should remain independent.


# 7. Infrastructure As Items

One of the more unusual ideas in Matryoshka is that infrastructure can participate in the same rule set as user items.

A mailbox can be an item.

A pool can be an item.

Potentially other infrastructure can be represented as items too.

The goal is not abstraction.

The goal is consistency.

---

## One Rule Set

Without this approach, systems often end up with multiple hold rules.

For example:

```text
Messages use one lifecycle.

Mailboxes use another lifecycle.

Pools use a third lifecycle.

Resources use a fourth lifecycle.
```

A developer must remember different rules for different items.

Matryoshka attempts to reduce that complexity.

Everything follows the same vocabulary for where an item is:

```text
acquire
transfer
recycle
dispose
```

---

## Infrastructure Can Move

Because infrastructure may be represented as items, hold can move through the same channels.

Conceptually:

```text
Mailbox
    ↓ send
Mailbox
    ↓ receive
Worker
```

or:

```text
Pool
    ↓ send
Mailbox
    ↓ receive
Master
```

The hold rules remain unchanged.

---

## Why This Matters

A system becomes easier to reason about when hold behaves consistently.

The developer should not need to ask:

```text
Does this object follow different rules?
```

Instead:

```text
Is this mine right now?
```

The answer comes from the same rule set.

---

## Infrastructure Is Different From User Data

Infrastructure may participate in hold transfer.

That does not mean infrastructure should be treated exactly like normal data.

Infrastructure often holds resources.

Examples:

```text
mutexes
condition variables
file descriptors
sockets
threads
memory pools
```

These resources usually require careful shutdown ordering.

Because of that, infrastructure should be transported carefully.

---

## Infrastructure Should Not Be Recycled

Normal items often benefit from reuse.

Infrastructure usually does not.

Examples:

```text
message
event
buffer
request
```

may be recycled.

Examples:

```text
mailbox
pool
```

usually should not be recycled.

The infrastructure itself is often the mechanism that makes recycling possible.

Recycling it rarely provides meaningful benefit.

---

## Avoid Hold Cycles

Hold should remain understandable.

The following design creates ambiguity:

```text
Mailbox
    holds item

Item
    holds mailbox
```

Now neither object can disappear independently.

A similar problem appears with pools:

```text
Pool
    holds item

Item
    holds pool
```

Eventually lifetime becomes difficult to reason about.

---

## Recommended Direction

Prefer hold trees.

Example:

```text
Master
 ├─ Mailbox
 ├─ Pool
 └─ Items
```

This structure has a clear shutdown path.

Hold cycles should be avoided whenever possible.

---

## Infrastructure Is Optional

A project does not need to transport infrastructure.

Many systems never will.

The important idea is not:

```text
Everything must be transported.
```

The important idea is:

```text
Everything can participate in the same rule set.
```

That consistency is the real benefit.

---

# 8. Design Decisions

This section summarizes the major architectural decisions and the reasoning behind them.

---

## Decision: Hold Is Explicit

Hold should be visible at the call site.

### Reason

Many lifecycle bugs come from unclear hold.

Examples:

```text
double free
forgotten cleanup
use-after-free
resource leaks
```

Visibility makes those bugs easier to find.

---

## Decision: An Item Has Exactly One Holder

An item belongs to one holder at a time.

### Reason

Shared hold increases complexity.

Hold transfer is easier to reason about than hold sharing.

---

## Decision: PolyNode Provides Runtime Identity

PolyNode contains a runtime type tag.

### Reason

Infrastructure must be able to identify item types after hold transfer.

---

## Decision: Tags Are Runtime Identity

Tags identify object kinds.

### Reason

Validation, dispatch, and lifecycle policy require runtime identity.

Tags provide that identity without inheritance or virtual methods.

---

## Decision: A Slot Represents Hold

Hold state is carried through the Slot.

### Reason

Hold becomes visible everywhere.

The programmer can immediately see whether an item is held or not.

---

## Decision: Mailbox Transfers Hold

Mailbox moves hold between tasks.

### Reason

Movement is safer than sharing.

The rule set remains simple.

---

## Decision: Mailbox Does Not Manage Lifecycle

Mailbox transports hold.

Nothing more.

### Reason

Combining transport and lifecycle creates coupling between unrelated concerns.

---

## Decision: Pool Manages Reuse

Pool signals when reusable hold is available. It is not storage.

### Reason

Reuse is useful.

But reuse should remain explicit and policy-driven.

---

## Decision: Pool Does Not Define Policy

Hooks define policy.

Pool provides the backpressure signal, not storage.

### Reason

Reuse and lifecycle decisions are different responsibilities.

Keeping them separate prevents Pool from becoming a second memory manager.

---

## Decision: Pool Is Asymmetric

Get and put have different meanings.

### Reason

Acquisition and lifecycle decisions are fundamentally different operations.

Treating them as symmetrical hides important behavior.

---

## Decision: Master Is The Coordination Boundary

Master combines movement, lifecycle, and policy.

### Reason

Some decisions require knowledge of the entire subsystem.

Those decisions do not belong in Mailbox or Pool.

---

## Decision: Master Is A Concept

Master is not a required structure.

Master is not a required base type.

Master is not a required PolyNode.

### Reason

The responsibility matters.

The implementation does not.

Different systems require different subsystem structures.

---

## Decision: Interrupt And Cancel Remain Separate

Interrupt is an event.

Cancel is state.

### Reason

They solve different problems.

Combining them introduces ambiguity and shutdown bugs.

---

## Decision: Infrastructure May Participate In Transfer

Infrastructure can follow the same rule set as user items.

### Reason

A single vocabulary for where an item is reduces conceptual overhead.

---

## Decision: Hold Comes First

Movement, lifecycle, and coordination are built on top of hold.

### Reason

Hold is the common foundation underneath all higher-level behavior.

---

# 9. Non-Goals

Matryoshka intentionally does not attempt to solve every problem.

The project remains small by focusing on hold, movement, lifecycle, and coordination.

---

## Not An Actor Framework

Matryoshka does not define actors.

It does not define actor hierarchies.

It does not define actor supervision.

---

## Not A Messaging Framework

Mailbox is transport.

It is not a complete messaging ecosystem.

---

## Not A Scheduler

Matryoshka does not decide when work runs.

It only defines hold movement and coordination.

---

## Not A Runtime

Matryoshka does not provide an execution runtime.

It can be used inside many different task systems.

---

## Not A Dependency Injection Framework

Matryoshka does not manage object graphs.

It does not resolve dependencies.

---

## Not A Service Container

Subsystem construction remains the responsibility of the application.

---

## Not A Garbage Collector

Hold remains explicit.

Destruction remains explicit.

Reuse remains explicit.

---

## Not A Replacement For Application Architecture

Matryoshka provides building blocks.

Applications still need domain models, protocols, persistence, business logic, and operational decisions.

---

# Addendum — Zig Notes

This document describes architecture first.

Language-specific implementation details are intentionally isolated here.

The architecture should remain valid even if the implementation language changes.

---

## PolyNode

Typical Zig representation:

```zig
pub const PolyNode = struct {
    node: std.DoublyLinkedList.Node,
    tag: *const anyopaque,
};
```

---

## Slot

The shipped Zig representation, from `src/polynode.zig`:

```zig
pub const ItemHandle = *PolyNode;
pub const Slot = ?ItemHandle;
```

The hold meaning remains:

```text
non-null -> held
null     -> not held
```

---

## Runtime Type Identity

A common Zig approach is:

```zig
const chunk_tag = PolyTag{};
const CHUNK_TAG = &chunk_tag;
```

Unique address equals unique identity.

---

## Parent Recovery

User structures usually contain a PolyNode field.

Recovery is commonly performed with:

```zig
@fieldParentPtr(...)
```

This removes any requirement for offset-zero placement.

---

## Public / Private Layering

A common pattern is:

```zig
pub const Mailbox = *PolyNode;
pub const Pool = *PolyNode;
```

with private implementation structures hidden internally.

This preserves hold semantics while hiding implementation details.

---

## Synchronization

The exact synchronization mechanism is an implementation detail.

The waiting mechanism is an implementation choice:

- operating-system primitives
- Zig IO primitives
- other runtime facilities

None of these change the architecture.

Mailbox remains transport.

Pool remains lifecycle management.

Master remains subsystem coordination.

The architecture should not depend on a particular synchronization API.


# Architecture Summary

Matryoshka consists of four layers.

```text
Layer 1
Hold
    │
    V
PolyNode + Tag + Slot

Layer 2
Movement
    │
    V
Mailbox

Layer 3
Lifecycle
    │
    V
Pool + Hooks

Layer 4
Coordination
    │
    V
Master
```

Each layer introduces exactly one new capability.

```text
PolyNode
    hold identity

Mailbox
    hold movement

Pool
    hold reuse

Master
    subsystem coordination
```

A system may stop at any layer.

```text
PolyNode only
    simple hold

PolyNode + Mailbox
    hold + movement

PolyNode + Mailbox + Pool
    hold + movement + reuse

PolyNode + Mailbox + Pool + Master
    complete subsystem
```

The rule set never changes.

Only capabilities are added.

The same rules apply everywhere:

```text
acquire
transfer
recycle
dispose
```

Everything else is built on top of that foundation.

---


## Change log

| Version | Date       | Description |
|---------|------------|-------------|
| 005     | 2026-08-02 | DOC 23. Dropped sections 1-4 (What Matryoshka Is, Why It Exists, Problems It Solves, Core Concepts) — `matryoshka-concepts-001.md` owns that ground and says it in the current vocabulary. Kept the Hold States and Transfers subsections out of the old section 4, which existed nowhere else, as the new section 1. Remaining sections renumbered. `MayItem` renamed to `Slot` throughout, matching `src/polynode.zig` and every other doc. No change to any layer contract, decision or non-goal. |
| 004     | (undated)  | Fourth version. |
| 003     | 2026-07-09 | INTR 7: "Pool is storage"/"warehouse" framing replaced with "Pool is not storage — it is a backpressure signal for reuse" throughout (including the "Pool Storage vs Policy" heading → "Pool Reuse vs Policy"). No structural or technical changes. |
| 002     | 2026-07-09 | New Mindset hold-language pass: the ownership family of words replaced with "hold"/"holder"/"holds"/"held" throughout (including the layer/section name, matching the existing HELD state name); "execution context(s)"/"execution model(s)" replaced with "task(s)". No structural or technical changes. |
| 001     | (undated)  | First draft — twelve sections: what Matryoshka is, why it exists, problems solved, core concepts, four layers, concurrency contract, infrastructure as items, design decisions, non-goals, Zig addendum, architecture summary. |
