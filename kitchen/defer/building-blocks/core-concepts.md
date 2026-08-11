# Core Concepts

Four ideas. Every Matryoshka design is built from these.

```text
PolyNode           who owns this item?
  +
Mailbox            how does ownership move?
  +
Pool               should this item be reused or destroyed?
  +
Master             who coordinates startup, shutdown, cancellation, policy?
```

Each layer adds exactly one capability.

- Need ownership and movement only: use PolyNode + Mailbox, stop there.
- Need backpressure and reuse: add Pool.
- Need coordination: add Master.
- The ownership model never changes — only capabilities are added.

## PolyNode — the ownership atom

Every design starts with one question: **who owns this item right now?**

- Not what data it holds, not which thread touches it — just who owns it.
- Ownership must be visible at the call site.
- If you need to read the implementation to know who owns an item, the design is wrong.

- An item has exactly one owner at any moment.
- Owners: user code (in flight), a mailbox (held), a pool (held).
- When ownership transfers, the slot becomes `null`.
- `slot.* = null` is the ownership protocol, not bookkeeping — the null is
  the proof of transfer.

## Mailbox — how ownership moves

A mailbox routes state, not data: an object that carries state moves between  
owners, rather than a copy of its bytes being handed around.

- One owner at a time means no mutex during processing.
- Not a lock-free algorithm — just one owner at a time.
- The routing itself is what gives the lock-freedom.

## Pool — reuse and backpressure

`pool.get` returns a resource: an empty, reusable container. Whatever the  
previous owner wrote has already been consumed or reset — the container  
carries no work intent on its own.

- A pool resource alone never defines a complete pattern. To do useful work
  a worker also needs at least one other input: a mailbox message, a  
  network read, a timer tick, shared state.

- An empty pool is not just an error condition — it is a backpressure
  signal. `pool.getWaitResult` inside `Io.Select` makes availability a  
  first-class event source.

- One loop handles data and buffer availability together. No sleep, no
  poll, no explicit backpressure code — when a worker returns an item, the  
  pool wakes the waiter.

## Master — an Io task, not a struct you must define

- Io creates tasks through `io.concurrent()`.
- A Master is an Io task that follows the Matryoshka rules.
- Not a struct you must define.

A worker is simply a Master with one dedicated responsibility — it  
owns its mailbox, its private state, its execution, and it may coordinate  
nobody and own no shared resources. It is still a Master.

- Any `Io.Select` loop is a Master. It is where startup order, shutdown
  order, cancellation policy, and resource ownership live.

- There is no required Master struct and no required interface — the
  responsibility matters, the structure does not.

Two tiers for how much structure a Master needs:

- **Flat** — one loop, one action per iteration, all state in local
  variables, short lifecycle. A plain function is enough.

- **Allocated struct** — multiple phases with shared state between them, a
  distinct init/work/shutdown lifecycle, or a `run` method that needs named  
  private steps to stay readable. Allocate the Master on the heap.

Cancel and close are different signals a Master must tell apart:

- `error.Canceled` — the Io scheduler says stop now. External signal.
- `mailbox.close` / `pool.close` — the Master itself says this subsystem is
  shutting down.

- Cancel does not trigger close. A worker that gets `error.Canceled`
  reports it; the Master decides what happens next.

## See it working

- `design/matryoshka-model-003.md` — the full Core Principles section this
  page distills.

- [Observable by Human](observable-by-human.md) — the coordinator/step shape
  a Master's `run` method follows once it grows past the flat tier.

## Next

Further Tools topics — Select event loops, spawn/await  
coordination, Master composition, pool patterns, API reference — are  
planned for later stages.
