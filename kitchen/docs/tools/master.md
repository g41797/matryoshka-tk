# Master

---

Everything runs inside one.

---

## A Master is an Io task

- Io creates tasks through `concurrent()`.
- A Master is an Io task that follows the Matryoshka rules.
- Not a special runtime object.

Master is **not**:

- a type
- an interface
- a runtime

> A Master runs on its own, as an Io task.
> It owns its state.
> It talks through Mailboxes.

```text
Io tasks
    │
    ├── ordinary task
    ├── ordinary task
    └── Master
             │
    ┌────────┼────────┐
    │        │         │
Single-job Coordinator Resource owner
 Master      Master       Master
```

- Some Masters do one job. A *worker* is simply a Master with one job.
- Some Masters coordinate other Masters.
- Some Masters own shared resources — a Pool, a shared Mailbox.

There is no required Master struct, and no required interface.

- The responsibility defines a Master, not a particular shape of code.

---


## Two tiers of structure

- **Flat** — one loop, one action per step, all state fits in local variables, short
  lifecycle. A plain function is enough.

- **Coordinator** — multiple phases with shared state between them, a distinct
  startup / work / shutdown lifecycle. Worth its own struct once a flat function  
  would get hard to follow.

Both are Masters.   
The difference is 

- how much structure the job needs
- not a different concept

---


## Cancel vs close

Mailbox and Pool

- are participants in Io Cancellation flow
- may be closed

But they never close themselves on Cancel.

It's Master decision.


---


## Master is not in the API

There is no `Master` type to import.

- The task comes from `concurrent()`.
- Transport comes from Mailbox.
- Reuse comes from Pool.
- Identity comes from PolyNode.
- Everything else is the application's own design: 
    - startup order
    - shutdown order
    - cancellation policy
    - how many workers
    - what they coordinate

---


