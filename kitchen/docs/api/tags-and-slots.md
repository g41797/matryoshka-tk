# API Reference — Tag Identity and Slot Programming

Two rules run through the whole API. Tag identity: what a handle is. Slot rule: where it lives.

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

### Transporting infra handles — valid patterns

**Worker-finish-signal pattern**

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

**Wrapper pattern** (for tag-level role discrimination)

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

## Slot-based programming

The slot rule governs every acquisition and transfer.

The slot rule:

- Never overwrite a non-null slot.
- Always start with `var slot: Slot = null`.
- All acquisition APIs assert `slot.* == null` on entry. Writing to a non-null slot panics.
- Transfer clears the slot: sender sets `slot.* = null`. After transfer, slot is null.
- Applies universally: pool get/put, mailbox receive, heap allocation — every combination.

**Exception — event-source helpers**: `receiveResult` and `getWaitResult` do not take a `*Slot`  
parameter. They move the handle via the returned union value (`ReceiveResult.item`,  
`PoolResult.item`) rather than a slot pointer. The caller extracts the handle from the union  
and holds it from that point. This is an intentional exception to the slot-pointer pattern.

### Why acquisition APIs assert null

Every acquisition API has this check:

```zig
std.debug.assert(slot.* == null);
```

Overwriting a non-null slot would lose the previous item with no error signal.  
The assert catches this immediately.

### Why cleanup operations accept null

`pool.put` and `PolyHelper.destroy` check null and return early:

```zig
if (slot.* == null) return;
```

This makes defer-before-acquisition safe.

### Slot lifecycle

```text
Slot lifecycle

  null ──── acquire ────► non-null
    ▲                        │
    │                        │
    ├──── transfer ──────────┘   (sender clears: slot.* = null)
    │
    └──── cleanup (no-op) ──────  (pool.put, PolyHelper.destroy: null → return)
```

### Moving a handle clears the slot

```text
Before transfer                  After transfer

  Slot (sender)                    Slot (sender)
  ┌─────────────┐                  ┌─────────────┐
  │ ItemHandle  │                  │    null     │
  └─────────────┘                  └─────────────┘
                                           │
  mailbox.send(mbh, &slot)                    │ slot.* = null
                                           │
                     Mailbox ◄─────────────┘
                     now holds ItemHandle
```

### Defer-before-acquisition is safe

```text
Code order:                      Execution when acquire fails:

  var slot: Slot = null;              slot = null
  defer pool.put(ph, &slot);          acquire fails
  try pool.get(..., &slot);           defer runs: pool.put sees null → no-op
  // work                          ✓ nothing lost

                                 Execution when item is transferred:

                                   slot = null (after acquire: slot is non-null)
                                   mailbox.send(mbh, &slot)  → slot = null
                                   defer runs: pool.put sees null → no-op
                                   ✓ item transferred, not double-recycled
```

---

