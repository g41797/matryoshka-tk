# Patterns — Slot and PolyNode Idioms

Concepts: [Building Blocks — PolyNode](../building-blocks/polynode.md).  
API: [API Reference — PolyNode, ItemHandle, Slot](../api/polynode/index.md).

The slot rule in full: [API Reference — Tag Identity and Slot Programming](../api/tags-and-slots/index.md).

## Slot idioms

### Empty Slot initialization

When to use.

- Every acquisition.

Code shape.  
```zig
var slot: Slot = null;
```

Why.

- Every acquisition API requires an empty slot.
- Passing a non-null slot is a programming error.

### Slot overwrite prevention

When to use.

- Before every receive/get/create operation.

Code shape.  
```zig
std.debug.assert(slot.* == null);
```

Why.

- A slot always owns exactly one item.
- Overwriting a non-null slot loses the item it holds.
- Every acquisition API contains this assert. Wrong use panics immediately.

### Transfer clears the slot

When to use.

- Every transfer.

Code shape.  
```zig
try mailbox.send(mbh, &slot);
// slot == null
```

or

```zig
pool.put(ph, &slot);
// slot == null if accepted by pool
```

Why.

- Sender no longer owns the item.
- Cleanup code becomes naturally safe.
- Transfer pre-empts cleanup: a later `defer` sees null and does nothing.

### Null-safe cleanup

When to use.

- Every deferred cleanup.

Code shape.  
```zig
defer pool.put(ph, &slot);
```

or

```zig
defer EventPolyHelper.destroy(allocator, &slot);
```

Why.

- Cleanup helpers ignore null slots.
- Cleanup may safely execute after transfer.

### Defer-put-early (pool item)

When to use.

- Acquiring a pool item. The defer goes before the get.

Code shape.  
```zig
var slot: Slot = null;
defer pool.put(ph, &slot);              // no-op if slot == null
try pool.get(ph, TAG, .available_or_new, &slot);
// ... work ...
// on transfer: slot = null → defer runs as no-op
// on no transfer: defer recycles item
```

Why.

- Failure path, success path, and transfer path all become correct automatically.
- If the get fails, the defer sees null — nothing lost.

Example: `examples/layer4/018-master_with_pool.zig`.

### Defer-destroy-early (heap item via PolyHelper)

When to use.

- Creating a heap item. The defer goes before the create.

Code shape.  
```zig
var slot: Slot = null;
defer EventPolyHelper.destroy(allocator, &slot);   // no-op if slot == null
try EventPolyHelper.create(allocator, &slot);
// ... work ...
// on transfer: slot = null → defer runs as no-op
// on no transfer: defer frees item
```

Example: `examples/layer2/097-wake_up_all.zig`.

### Defer for received mailbox item

When to use.

- Receiving into a slot. Cleanup must cover both the error path and the normal path.

Code shape.  
```zig
var slot: Slot = null;
defer if (slot) |poly| helpers.freeItem(poly, allocator);
try mailbox.receive(mbh, &slot, null);
// dispatch on slot.?.*.tag, process item
// item stays non-null until explicitly transferred or freed
```

Example: `examples/layer4/031-select_graceful_shutdown.zig`.

### Fallback destroy after pool.put

When to use.

- Pool may already be closed when the item comes back.

Code shape.  
```zig
defer EventPolyHelper.destroy(allocator, &slot);   // fallback: frees if pool.put left slot non-null
defer pool.put(ph, &slot);                          // primary: recycles to pool (clears slot on success)
// defers run LIFO: pool.put first, then destroy (no-op if pool.put cleared slot)
```

Why.

- Pool receives the item if open.
- A closed pool leaves the slot non-null — the caller keeps the item.
- Destroy executes only if the item stayed with the caller.

Example: `stories/video_transcoder/video_transcoder.zig`.

### No raw allocator calls on PolyNode-based types

When to use.

- Every PolyNode-based user type (Event, Sensor, Timer, ShutdownCommand).

Code shape.  
```zig
// WRONG — raw allocator on PolyNode-based type
const ev = try alloc.create(Event);

// CORRECT — PolyHelper.create/destroy
var slot: Slot = null;
defer EventPolyHelper.destroy(alloc, &slot);
try EventPolyHelper.create(alloc, &slot);
```

Why.

- `PolyHelper.create` sets the tag and initializes the node.
- Raw `allocator.create` skips both. The item is unusable for dispatch.

Exempt: `mailbox.zig` / `pool.zig` internals, PolyHelper implementations, pool hook bodies, non-PolyNode structs.  
Full list: [API Reference — Cooperative Cleanup](../api/cleanup/index.md).

---

## PolyNode idioms

### Intrusive node embedding

When to use.

- Every PolyNode-based user type, from first definition.

Code shape.  
```zig
pub const Message = struct {
    poly: polynode.PolyNode = .{},
    text: []const u8 = "",
    priority: u8 = 0,
};
pub const MessagePolyHelper = polynode.PolyHelper(Message);
```

Why.

- `PolyNode` sits at offset 0. One allocation, no wrapper struct.
- Safe cast both ways: `*Message` to `*PolyNode` and back, via `PolyHelper`.
- No separate link object to keep in sync with the payload.

Example: `examples/layer1/021-define_type.zig`.

### PolyHelper everywhere

When to use.

- Every PolyNode type.

Code shape.  
```zig
pub const EventPolyHelper =
    polynode.PolyHelper(Event);
```

Why.

- Eliminates manual tag management.
- Eliminates unsafe casts.
- Eliminates initialization boilerplate.

### Node identification

When to use.

- Recovering a concrete type from a `*PolyNode` handle (e.g. an `ItemHandle` received from a mailbox or returned by a pool event source).

Code shape.  
```zig
if (EventPolyHelper.identifyNodeAs(handle)) |ev| {
    ...
}
```

Why.

- Tag check and recovery are combined.
- Wrong types return null.

### Slot identification — accessing owned items

When to use.

- After `create` or `get`, to access fields of the item in a Slot before sending or returning it.

Code shape (assert non-null, known type).  
```zig
var slot: Slot = null;
defer EventPolyHelper.destroy(allocator, &slot);
try EventPolyHelper.create(allocator, &slot);
EventPolyHelper.mustIdentifySlotAs(&slot).code = 42;
try mailbox.send(mbh, &slot);
```

Code shape (optional — type may vary).  
```zig
if (EventPolyHelper.identifySlotAs(&slot)) |ev| {
    ev.code = 42;
}
```

Why.

- Unwraps the optional internally — no `.?` in application code.
- `mustIdentifySlotAs` panics if the Slot is empty or the tag does not match.
- Use `identifySlotAs` (nullable) when the type is not guaranteed.

### Polymorphic dispatch

When to use.

- One mailbox or one list carries more than one item type. The receiver recovers the concrete type.

Code shape.  
```zig
if (EventPolyHelper.identifyNodeAs(handle)) |ev| {
    // handle Event
} else if (ShutdownCommandPolyHelper.identifyNodeAs(handle)) |_| {
    // handle ShutdownCommand
} else {
    // unknown — free and move on
}
```

- `identifyNodeAs` returns null on a tag mismatch. Chain calls for each known type.

Example: `examples/layer4/031-select_graceful_shutdown.zig`, `examples/layer4/033-cross_layer_mixed_types_mailbox.zig`.

### Tag identifies the class

When to use.

- Runtime dispatch.

Pattern.  
```
tag
    ↓
type
```

Not

```
tag
    ↓
instance
```

Use.

- Pointer comparison for infrastructure handles.
- User fields (`kind`, `role`) for application roles.

Details: [API Reference — Tag Identity](../api/tags-and-slots/index.md).

### Wrapper type for infrastructure handles

When to use.

- Mailbox or Pool must participate in polymorphic dispatch by tag.

Code shape.  
```zig
const WorkerInbox = struct {
    poly: PolyNode,
    handle: mailbox.MailboxHandle,
};
pub const WorkerInboxPolyHelper = polynode.PolyHelper(WorkerInbox);
```

Why.

- Wrapper has its own PolyHelper tag, distinct from `MailboxPolyHelper.TAG`.
- Enables normal type dispatch. The receiver finds the embedded handle.

### Mailbox-as-message

When to use.

- Handing a communication endpoint to another Master.

Pattern.  
```
Worker
    │
returns MailboxHandle
    │
Master receives mailbox
```

Typical use.

- Worker completion notification.
- Dynamic topology construction.
- Channel migration.

### Worker-finish-signal

When to use.

- A worker signals completion by sending its own mailbox back to the Master.

Pattern.

- Master creates `worker_mbh`, spawns a worker via `io.concurrent`, passes `worker_mbh` as parameter.
- Worker processes items until a shutdown signal.
- Worker sends `worker_mbh` back to the Master's inbox (unclosed) as the finish signal, then exits.
- Master confirms class: `mailbox.is_it_you(received.*.tag)`.
- Master confirms instance: `received == worker_mbh` (pointer comparison).
- Master closes and destroys `worker_mbh`, then awaits the worker's future.

Why.

- Replaces relying on the future await as a completion signal, or a separate shutdown message, with handing the mailbox back.

Details: [API Reference — Transporting infra handles](../api/tags-and-slots/index.md).

### Pool-as-message

When to use.

- Sharing lifecycle managers.

Pattern.  
```
PoolHandle
    ↓
mailbox.send()
```

Why.

- PoolHandle is itself a PolyNode.

---
