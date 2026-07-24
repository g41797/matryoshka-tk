# API Reference — Cooperative Cleanup — No raw allocator calls

---

## No raw allocator calls on PolyNode-based types

In examples and tests, never use `allocator.create` / `allocator.destroy` directly on  
PolyNode-based user types (Event, Sensor, Timer, ShutdownCommand).

Use `PolyHelper.create`, `PolyHelper.destroy`, or `helpers.freeSlot` instead.

### Violation

```zig
// WRONG — raw allocator on PolyNode-based type
const ev = try alloc.create(Event);
ev.* = .{};
EventPolyHelper.init(ev);
slot.* = &ev.poly;
// ... later ...
alloc.destroy(EventPolyHelper.mustIdentifySlotAs(&slot));
slot.* = null;
```

### Correct

```zig
// CORRECT — PolyHelper.create/destroy
var slot: Slot = null;
defer EventPolyHelper.destroy(alloc, &slot);
try EventPolyHelper.create(alloc, &slot);
// ... dispatch: use helpers.freeSlot(&slot, alloc) per branch ...
```

### Exempt

- `mailbox.zig`, `pool.zig` — allocating/freeing their own internal structs.
- `PolyHelper.create` / `PolyHelper.destroy` implementations.
- Pool hook bodies (`on_get`, `on_close`) — manage raw memory on behalf of pool.
- Non-PolyNode structs: worker context, hook context, allocator wrappers.

---

