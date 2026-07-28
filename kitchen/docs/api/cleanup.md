# API Reference — Cooperative Cleanup

---

These patterns follow from the slot rule.  
Place cleanup before acquisition.  
The defer becomes a no-op when the slot is null — either because acquisition failed, or because the item was transferred.

---


## Pattern 1 — defer-put-early (pool item)

```zig
var slot: Slot = null;
defer pool.put(ph, &slot);              // no-op if slot == null
try pool.get(ph, TAG, .new_only, &slot);
// ... work ...
// on transfer: slot = null → defer runs as no-op
// on no transfer: defer recycles item
```

Put before get — safe because pool.put is a no-op on null.

If the pool may be closed while the item is held, pool.put leaves slot non-null (caller retains  
held). Add a fallback destroy to avoid a leak:

```zig
var slot: Slot = null;
defer EventPolyHelper.destroy(alloc, &slot); // fallback: frees if pool.put left slot non-null
defer pool.put(ph, &slot);                   // primary: recycles to pool (clears slot on success)
// defers run LIFO: pool.put first, then destroy (no-op if pool.put cleared slot)
```

---


## Pattern 2 — defer-destroy-early (heap item via PolyHelper)

```zig
var slot: Slot = null;
defer EventPolyHelper.destroy(allocator, &slot);   // no-op if slot == null
try EventPolyHelper.create(allocator, &slot);
// ... work ...
// on transfer: slot = null → defer runs as no-op
// on no transfer: defer frees item
```

Destroy before create — safe because PolyHelper.destroy is a no-op on null.

---


## Pattern 3 — defer for received mailbox item

```zig
var slot: Slot = null;
defer if (slot) |poly| helpers.freeItem(poly, allocator);
try mailbox.receive(mbh, &slot, null);
// dispatch on slot.?.*.tag, process item
// item stays non-null until explicitly transferred or freed
```

Cleanup covers both the error path (receive failed) and the normal path (item processed and freed).

---


## Pattern 4 — transfer clears the slot

```zig
var slot: Slot = null;
defer pool.put(ph, &slot);
try pool.get(ph, TAG, .new_only, &slot);
// fill item ...
try mailbox.send(mbh, &slot);   // send sets slot.* = null
// defer runs: pool.put sees null → no-op
// result: item is in mailbox, not recycled to pool
```

Transfer and cleanup are not in conflict — transfer pre-empts cleanup by clearing the slot.

---


## Pattern summary

```text
Pattern 1 (pool item)            Pattern 2 (heap item)

  null ──► get ──► non-null        null ──► create ──► non-null
    ▲                │               ▲                   │
    │    put (defer) │               │  destroy (defer)  │
    └────────────────┘               └───────────────────┘
         (recycle)                          (free)

         transfer →                         transfer →
         slot = null                           slot = null
         defer: no-op                       defer: no-op
```

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
alloc.destroy(EventPolyHelper.mustFromSlot(&slot));
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

