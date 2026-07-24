# Patterns — Pool Patterns

Concepts: [Building Blocks — Pool](../building-blocks/pool.md).  
API: [API Reference — Pool](../api/pool/index.md).

### Pool mode — .available_or_new

When to use.

- The common case: reuse a stored item if one is free, otherwise create a fresh one.

Code shape.  
```zig
var slot: Slot = null;
defer pool.put(ph, &slot);
try pool.get(ph, EventPolyHelper.TAG, .available_or_new, &slot);
```

- `on_get` runs every call. If `slot.*` is non-null it was recycled — reinitialize. If null, create.

Example: `examples/layer4/018-master_with_pool.zig`.

### Pool mode — .new_only

When to use.

- Seeding. You want a fresh item every time, never a stored one.

Code shape.  
```zig
var slot: Slot = null;
try pool.get(ph, EventPolyHelper.TAG, .new_only, &slot);
// fill the new item
pool.put(ph, &slot);
```

Example: `examples/layer3/pool_seeding.zig`.

### Pool mode — .available_only

When to use.

- Consume what is stored. Stop when the pool is empty.
- Empty pool returns `error.NotAvailable` — a normal end condition, not a failure.

Code shape.  
```zig
var slot: Slot = null;
pool.get(ph, EventPolyHelper.TAG, .available_only, &slot) catch |err| switch (err) {
    error.NotAvailable => break,
    else => return err,
};
```

Example: `examples/layer3/pool_seeding.zig`.

### Seeding pattern

When to use.

- A fixed-size pool. Pool capacity is set once at startup, no on-demand creation.

Code shape.  
```zig
for (0..N_BUFFERS) |_| {
    var slot: Slot = null;
    try VideoBufferPolyHelper.create(allocator, &slot);
    pool.put(ph, &slot);
}
```

- Pair with `on_get` that does nothing — the pool never grows past the seed count.
- The fixed count becomes the backpressure limit.

Example: `stories/video_transcoder/video_transcoder.zig`.

### Pool as lifecycle policy — on_get and on_put hooks

When to use.

- `on_get`: decide how an item is created or reinitialized.
- `on_put`: decide whether a returned item is kept or destroyed (cap policy).

Pattern.  
```
on_get
    ↓
slot == null  → create
slot != null  → reuse

on_put
    ↓
keep or destroy
```

Code shape.  
```zig
fn onGet(_: *anyopaque, _: *const anyopaque, _: usize, _: *Slot) void {}        // fixed-size: never create
fn onPut(_: *anyopaque, _: usize, _: *Slot) void {}                              // keep all
```

- `on_put`: set `slot.* = null` to destroy; leave non-null to keep.
- Allocation policy stays outside business logic.

Example: `examples/layer3/capped_pool.zig` (cap policy), `examples/hooks/CappedPoolHooks.zig` (thread-safe reference).

### Hook outside lock

When to use.

- Shared hook state.

Code shape.  
```zig
lockUncancelable()

...modify shared state...

unlock()
```

Why.

- Hooks run outside the pool lock. Multiple threads may call them at once.
- Pool does not serialize hook execution.
- Protect shared state with `Io.Mutex.lockUncancelable`.

Example: `examples/hooks/CappedPoolHooks.zig`.

### on_close hook

When to use.

- Free all stored items when the pool shuts down.

Code shape.  
```zig
fn onClose(ctx: *anyopaque, list: *std.DoublyLinkedList) void {
    const self: *VideoBufCtx = @ptrCast(@alignCast(ctx));
    while (list.popFirst()) |node| {
        const poly: *polynode.PolyNode = @fieldParentPtr("node", node);
        polynode.reset(poly);
        var s: Slot = poly;
        VideoBufferPolyHelper.destroy(self.alloc, &s);
    }
}
```

- Always call `polynode.reset(poly)` after `popFirst` before destroy.

Example: `examples/layer3/pool_teardown.zig`, `stories/video_transcoder/video_transcoder.zig`.

### Multi-tag pool

When to use.

- Pool stores multiple item types.

Pattern.  
```
Pool
 ├── Event
 ├── Buffer
 └── Command
```

Why.

- One lifecycle manager.
- Separate free lists per tag.

---
