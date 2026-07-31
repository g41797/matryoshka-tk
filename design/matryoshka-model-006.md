# Matryoshka Thinking Model (006)

Versioned doc. Replaces [matryoshka-model-005.md](matryoshka-model-005.md).

Change from -005: companion cross-references updated to rules-034.md and  
patterns-021.md. No model content changed — API 9's neighbour-check rule is a  
coding rule, not a model claim.

Change from -004: exclusive access gains its second half. The transfer moves  
possession *and* orders memory. -004 said "whoever holds it has exclusive  
access" and stopped there, which left the reason the library can assert on an  
item's fields without atomics unstated.

The mental model behind every Matryoshka design decision.  
Companion: [rules-034.md](rules-034.md) — the coding and process rules.  
Companion: [patterns-021.md](patterns-021.md) — reusable coding patterns.

---

## The Mantra

Every Matryoshka design starts with one question.

> Who owns this item right now?

- Not "what data does this item hold."
- Not "which thread processes it."
- Just: who owns it.

Who holds it is visible at the call site.
- If you must read the implementation to know who holds an item, the design is wrong.

---

## Core Principles

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
- See [rules-034.md](rules-034.md) for how to phrase this in `src/` comments.

### Pool availability = backpressure signal

- An empty pool is not just an error condition.
- It is a backpressure signal.
- `pool.getWaitResult` inside `Io.Select` makes availability a first-class event source.
- One loop handles data and buffer availability together.
- When a worker returns an item, the pool wakes the waiter and the waiter resumes.
- No sleep. No poll. No explicit backpressure code.

### Pool items are empty containers

- `pool.get` returns a resource — an empty, reusable container.
- The container carries no work intent on acquisition.
- "Empty" means: whatever the previous owner wrote has been consumed or reset.
- To do useful work, a worker needs at least one additional input:
  - External data: mailbox message, network read, timer tick, shared counter.
  - Worker's own accumulated state from previous cycles.
- A worker that only calls `pool.get` and `pool.put` with no other input source does nothing useful.
- This applies to examples and stories alike: a pool resource alone is never enough to define a complete pattern.

### Layers compose

- Each layer adds exactly one capability.
- No custom locks needed. No custom thread managers needed.

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

### Cancel is not close

- `error.Canceled` — the Io scheduler says stop now. External signal.
- `mailbox.close` / `pool.close` — the Master says this subsystem is shutting down.
- Cancel stops waiting.
- Close signals end-of-stream.
- Cancel does not trigger close.
- A worker that gets `error.Canceled` reports it. The Master decides what to do.

### Master is a concept, not a type

- Master is the coordination boundary.
- Any `Io.Select` loop is a Master.
- It is the place where startup order, shutdown order, cancellation policy, and resource lifetime live.
- There is no required Master struct. No required interface.
- The responsibility matters. The structure does not.
- Workers are also Masters when they grow beyond minimal functionality.

### When to allocate a Master

Two tiers. The rule applies to the top-level `run` function and to worker functions alike.

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

## Three-Category Model

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
- Shows a complete pattern: origin of work input, what the worker does, where results go.
- An example that shows only lifecycle or shutdown — without a work input source — cannot be used as a template.
- Small examples use a flat function. Big examples allocate a Master struct.
- See "When to allocate a Master" above and the Master pattern rule in [rules-034.md](rules-034.md).
- Part of the docs.

### Story

- Shows how to think with Matryoshka.
- Multiple layers composing into a real flow.
- Starts from a real domain problem. Translates to Matryoshka patterns. Implements.
- Reader learns how to reason about a new problem by asking who holds what.
- Pool resources in a story must have an explicit work input source — mailbox, network, timer, or worker state.
- Stories always use the Master pattern. A story is never a flat function.
- Part of the docs.

A story is not a large example. It is a different kind of artifact.

### What qualifies as a story

- Must show at least two layers composing.
- Must have a real domain problem.

---

## Story Structure

Each story is a mini-project with two artifacts plus one shared test file.

### Narrative — `design/stories/name-001.md`

Four parts.

**Part 1 — Arch Design**
- Domain problem statement.
- Architect dialogue: constraints, tradeoffs, decisions.
- Result: bounded scope, defined boundaries.

**Part 2 — SRS (Software Requirements Specification)**
- Numbered requirements. One per bullet.
- Domain language, not Matryoshka language.
- Example: "The system must reuse video buffers to prevent fragmentation."

**Part 3 — Matryoshka Translation**
- Map each requirement to a Matryoshka concept.
- Programmer dialogue preferred — shows the reasoning, not just the result.
- Example: "Requirement 3 maps to pool.getWaitResult inside Io.Select."

**Part 4 — Flow Diagram**
- Full system ASCII diagram.
- Shows all layers, all transfer flows, all event sources.
- Diagram only. No prose.

### Code — `stories/name/name.zig`

- Signature: `pub fn run(allocator: std.mem.Allocator, io: std.Io) !void`.
- Full implementation of the story.
- All actors, all layers, graceful shutdown.
- ASCII transfer circuit diagram at the top of the file.
- Code is structured around Masters. See [patterns-021.md](patterns-021.md) for the coding patterns and the Master composition pattern.

### Test wrapper — `tests/stories_test.zig`

- Single file. All story wrappers.
- Same pattern as `layer4_cross.zig` wrappers.
- Uses `std.Io.Threaded.init`.
