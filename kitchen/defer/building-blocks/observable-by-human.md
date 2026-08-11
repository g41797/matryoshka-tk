# Observable by Human

Every function with distinct phases is written in two levels: a coordinator  
that sequences named steps, and the steps themselves.

## The rule

Level 1 — the coordinator (`run`, any sequencing function).

- Dominant structure: calls to named step functions.
- Simple glue stays inline: a guard, a `helpers.expect`, a `std.log.info` line.
- Inline logic blocks with distinct purpose are extracted to a named step.
- The full flow is visible in a few lines without opening anything.

Level 2 — the step functions.

- Each implements exactly one step.
- Named for what it does. The name is the documentation.
- `var`/`const` declarations are fine anywhere they are needed.

## The signal

If you feel the need to place a comment explaining a block of code: stop.

- That block must be a named step function instead.
- A comment marks a step you should have named before writing.

A 1-2 line guard or log between step calls stays inline.

- Only blocks with a distinct, nameable purpose are extracted.

Some patterns are always violations, comment or not:

- Any `while` loop with a `switch` body inside a coordinator — extract as
  `eventLoop` or a domain equivalent.

- Any `Io.Select` setup block inside a coordinator — extract as `setupSelect`.
- Any cluster of `io.concurrent` / `group.concurrent` calls
  inside a coordinator — extract as `spawnWorkers` or equivalent.

- Any for-loop that sends, fills, or seeds items inside a coordinator —
  extract as `sendItems`, `fillMailbox`, `seedPool`, or equivalent.

## The shape

### Coordinator

```zig
fn run(self: *Master) !void {
    try self.seedResources();
    try self.eventLoop();
    self.gracefulShutdown();
    try helpers.expect(error.XFailed, self.count > 0, "expected items");
    std.log.info("done: {d} processed", .{self.count});
}
```

Dominant structure is calls to named steps. Simple glue stays inline.

### Step

```zig
fn seedResources(self: *Master) !void {
    for (0..N) |i| {
        var slot: Slot = null;
        defer types.EventPolyHelper.destroy(self.allocator, &slot);
        try types.EventPolyHelper.create(self.allocator, &slot);
        types.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
        try mailbox.send(self.mbh, &slot);
    }
}
```

Each step implements one thing. A loop is one unit at its own scope level.

### Init

```zig
fn init(allocator: std.mem.Allocator, io: std.Io) !*Master {
    const self = try allocator.create(Master);
    errdefer allocator.destroy(self);
    self.allocator = allocator;
    self.io = io;
    self.mbh = try mailbox.new(io, allocator);
    errdefer {
        var rem = mailbox.close(self.mbh);
        helpers.freeList(&rem, allocator);
        mailbox.destroy(self.mbh, allocator);
    }
    self.ph = try pool.new(io, allocator, &self.pool_ctx, pool_hooks);
    return self;
}
```

Allocate first, guard with `errdefer allocator.destroy`. Acquire each  
resource, guard it with its own `errdefer`. Return `self` last.

## Development order

- Write the coordinator first. Name the steps before implementing them.
- Add stub step functions that compile but do nothing.
- Fill in steps one by one.
- The flow is known and visible from the start.

## See it working

- `examples/layer4/031-select_graceful_shutdown.zig` — coordinator + step shape.
- `examples/layer4/018-master_with_pool.zig` — init + destroy shape.

## Next

More Tools topics — Select event loops, spawn/await coordination,  
Master composition, pool patterns — are planned for later stages.
