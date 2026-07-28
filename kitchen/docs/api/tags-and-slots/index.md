# API Reference — Tag Identity and Slot Programming

Two rules run through the whole API. Tag identity: what a handle is. Slot rule: where it lives.

---

## Tag identity — class, not instance

`PolyHelper(T)` generates one static `_tag: PolyTag` per type `T` at comptime.  
`TAG` is a pointer to that static — the same address for every instance of `T`.

Tag dispatch (`is_it_you`, `isIt`, `fromNode`) answers one question: **"is this a T?"**  
It does not answer: "which T?" or "what role does this T play?"

For user-defined types (Event, Sensor, etc.):

- Tag identifies the class.
- Instance fields carry the role. The user adds a `kind` or `role` field to discriminate.

For infra handles (MailboxHandle, PoolHandle):

- `_Mailbox` and `_Pool` are private structs. The user cannot add fields.
- Tag identifies the class only. No per-instance role information is accessible.
- **Instance identity**: resolved by pointer comparison against known handles.
  E.g. `received == worker_mbh` identifies which specific mailbox arrived.

- **Role**: established by protocol — the channel the handle arrived on, message
  ordering, or prior agreement between sender and receiver.

---

## Transporting infra handles — valid patterns

### Worker-finish-signal pattern

Master creates `worker_mbh`, spawns a worker via `io.concurrent` and passes `worker_mbh` as parameter.  
Worker processes items until a shutdown signal, then:

- Sends `worker_mbh` back to master's inbox (unclosed) as the finish signal.
- Exits.

Master receives a PolyNode from its inbox:

- `mailbox.is_it_you(received.*.tag)` — confirms class (it is a mailbox).
- `received == worker_mbh` — confirms instance (it is the expected worker mailbox).
- Master closes and destroys `worker_mbh`.
- Master awaits the worker's future (cleanup only — the mailbox return was the logical finish signal).

This pattern replaces relying on the future await as a completion signal, or a separate shutdown message, with a handle handoff.

### Wrapper pattern (for tag-level role discrimination)

When tag dispatch must distinguish roles, wrap the handle in a user-defined PolyNode struct:

```zig
const WorkerInbox = struct {
    poly: PolyNode,
    handle: mailbox.MailboxHandle,
};
pub const WorkerInboxPolyHelper = polynode.PolyHelper(WorkerInbox);
```

`WorkerInboxPolyHelper.TAG` is distinct from `MailboxPolyHelper.TAG`.  
The receiver dispatches on `WorkerInboxPolyHelper.TAG` and finds the embedded handle.

---

