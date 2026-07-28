# Patterns — Shutdown and Master Patterns

Concepts: [Building Blocks — Master](../building-blocks/master.md).

## Graceful shutdown sequence

When to use.

- Tearing down a Master that owns workers, mailboxes, and a pool.

Mandatory order.

1. Stop the producer loop (the Select Master). Stop registering new work.
2. Close the mailbox that feeds the workers. This signals end-of-stream.
3. Walk the mailbox close list. Recover or recycle every item it returns.
4. `group.await(io)` — wait for all workers to finish their current item.
5. Destroy the worker mailbox.
6. Close any downstream mailbox (e.g. storage). Its task exits on `error.Closed`.
7. Await the downstream task. Destroy its mailbox.
8. `pool.close` — `on_close` frees all stored items.
9. `pool.destroy`.

Why this order.

- Close upstream before awaiting workers, or workers block forever.
- Await workers before closing the pool, or a worker returns an item to a closed pool.
- A pool returns the item to the caller when closed — the worker must free it as a fallback.

Code shape (worker fallback for closed pool).  
```zig
pool.put(ctx.buf_ph, &sc.buffer_slot);
if (sc.buffer_slot != null) {
    VideoBufferPolyHelper.destroy(ctx.alloc, &sc.buffer_slot);
}
```

Example: `stories/video_transcoder/video_transcoder.zig`, `examples/layer4/037-cross_layer_close_mailbox_then_pool.zig`.

### Alternative — shutdown via Exit message

When to use.

- The mailbox must stay open and reusable while the worker still needs to exit cleanly.
- Simpler than the close-based sequence above when there is only one worker and no pool to
  empty in lockstep.

Pattern.  
```
main ──Event×N──► mailbox ──► worker (processes, frees each)
main ──ShutdownCommand──► mailbox ──► worker (recognizes tag, exits, frees it)
(mailbox stays open — worker owns every item it ever received)
```

Why.

- A tagged sentinel item flows through the normal mailbox instead of `mailbox.close`.
- The mailbox can be reused for another worker afterward — closing it cannot be undone.
- Use the mandatory 9-step sequence instead when a pool must also empty in lockstep with the
  mailbox (the sentinel alone does not coordinate pool shutdown).

Example: `examples/layer2/062-shutdown_exit.zig`.

---

## Master patterns

Actually these patterns were written for usage by AI during generation of Examples.  

You can borrow several ideas here, but Matryoshka-Tk does not dictate how to proceed.    

It's your system.  

### Observable function shapes

#### Coordinator / run

When to use.

- Any function that sequences discrete steps: `pub fn run`, a Master's `run`, any sequencing method.

Code shape.  
```zig
fn run(self: *Master) !void {
    try self.seedResources();
    try self.eventLoop();
    self.gracefulShutdown();
    try helpers.expect(error.XFailed, self.count > 0, "expected items");
    std.log.info("done: {d} processed", .{self.count});
}
```

- Dominant structure: calls to named step functions.
- Simple glue (a guard, a `helpers.expect`, a `std.log.info`) stays inline.
- No inline logic blocks with distinct purpose — those are extracted to named steps.

Example: `examples/layer4/031-select_graceful_shutdown.zig`.

#### Step function

When to use.

- Any function that implements one discrete phase of the coordinator.

Code shape.  
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

- Each step implements one thing. Name = documentation.
- `var`/`const` declarations are fine.
- Loops are one unit at their scope level.

Example: `examples/layer4/031-select_graceful_shutdown.zig`.

#### Init

When to use.

- Allocating a Master struct and acquiring its resources.

Code shape.  
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

- Allocate first, guard with `errdefer allocator.destroy`.
- Acquire each resource, guard with `errdefer` for that resource.
- Return `self` last.

Example: `examples/layer4/018-master_with_pool.zig`.

#### Destroy

When to use.

- Releasing a Master struct and its resources.

Code shape.  
```zig
fn destroy(self: *Master) void {
    var rem: std.DoublyLinkedList = mailbox.close(self.mbh);
    helpers.freeList(&rem, self.allocator);
    mailbox.destroy(self.mbh, self.allocator);
    pool.close(self.ph);
    pool.destroy(self.ph, self.allocator);
    self.allocator.destroy(self);
}
```

- Release resources in reverse acquisition order.
- Free the allocation last.

Example: `examples/layer4/018-master_with_pool.zig`.

#### Thread-is-container

When to use.

- Spawning a worker thread or `io.concurrent` task for a Master.

Rule.

- The spawned function receives `*Master` (or a small `*Ctx`) directly as its argument.
- It keeps no other thread-local bookkeeping — the thread's own stack holds no separate
  ITC state to track and free later. The Master struct (heap-allocated, see Init above) is  
  the single source of truth, reachable through the one pointer the thread was given.

Code shape.  
```zig
var ctx: WorkerCtx = .{ .mbh = mbh, .alloc = allocator };
var fut = try io.concurrent(workerFn, .{&ctx});
...
fn workerFn(ctx: *WorkerCtx) anyerror!void {
    while (true) {
        var slot: Slot = null;
        defer helpers.freeSlot(&slot, ctx.alloc);
        mailbox.receive(ctx.mbh, &slot, null) catch return;
    }
}
```

Why.

- One pointer in, no hidden thread-local state to lose track of.
- Matches the heap-allocated-Master rule: the container the thread runs against outlives
  the spawn call and is destroyed only after the thread is joined/awaited.

Example: `examples/layer4/017-minimal_master.zig`, `examples/layer4/019-multi_worker_master.zig`.

### Coordinator with Select event loop (flat file)

When to use.

- A flat `pub fn run` (no Master struct) that owns an `Io.Select` event loop.
- `buf` and `sel` are declared at coordinator scope; passed as `*Sel` (transient) to step functions.
- Use when the file has 1-2 coordinator-scope params (explicit passing) or 3+ params (introduce a local Ctx struct).

Code shape (explicit params, 1-2 shared values).  
```zig
const Sel = std.Io.Select(MasterEvent);

pub fn run(allocator: std.mem.Allocator, io: std.Io) !void {
    const ph: PoolHandle = try pool.new(io, allocator, &pool_ctx, pool_hooks);
    defer pool.destroy(ph, allocator);

    try seedPool(ph, allocator);

    var buf: [8]MasterEvent = undefined;
    var sel: Sel = Sel.init(io, &buf);
    try setupSelect(ph, io, &sel);
    try runEventLoop(ph, io, &sel);

    try helpers.expect(error.XFailed, ...);
    std.log.info("done", .{});
}

fn setupSelect(ph: PoolHandle, io: std.Io, sel: *Sel) !void {
    const sleep_t: std.Io.Timeout = .{ .ns = 100_000_000 };
    try sel.concurrent(.pool_ev, pool.getWaitResult, .{ ph, TAG, null });
    try sel.concurrent(.timer, sleepFn, .{ sleep_t, io });
}

fn runEventLoop(ph: PoolHandle, io: std.Io, sel: *Sel) !void {
    while (true) {
        const event: MasterEvent = try sel.await();
        switch (event) {
            .pool_ev => |r| switch (r) {
                .item => |handle| {
                    // process handle
                    pool.put(ph, &(var s: Slot = handle; &s));
                    try sel.concurrent(.pool_ev, pool.getWaitResult, .{ ph, TAG, null });
                },
                .closed, .canceled, .not_created => break,
                .timeout => {},
            },
            .timer => break,
        }
    }
    sel.cancelDiscard();
}
```

Code shape (3+ shared values — local Ctx struct, stack-allocated).  
```zig
const Ctx = struct {
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,
    io: std.Io,

    fn setupSelect(self: *Ctx, sel: *Sel) !void { ... }
    fn runEventLoop(self: *Ctx, sel: *Sel) !void { ... }
};

pub fn run(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbh: MailboxHandle = try mailbox.new(io, allocator);
    defer { ... }

    var ctx: Ctx = .{ .mbh = mbh, .alloc = allocator, .io = io };

    var buf: [8]MasterEvent = undefined;
    var sel: Sel = Sel.init(io, &buf);
    try ctx.setupSelect(&sel);
    try ctx.runEventLoop(&sel);
}
```

- `setupSelect` owns timeout construction and initial `concurrent` registrations.
- `runEventLoop` owns the loop body, re-registrations, and final `cancelDiscard`.
- `buf` and `sel` are declared at coordinator scope; passed as `*Sel` to steps.
- Ctx is stack-allocated (`var ctx: Ctx = .{...}`). No heap allocation.
- Methods declared inside the Ctx struct body (`fn setupSelect(self: *Ctx, ...) !void`).

Examples: `examples/layer4/046-select_pool_event.zig`, `examples/layer4/028-select_mixed_sources.zig`.

### Coordinator with spawn + await (flat file)

When to use.

- A flat `pub fn run` that spawns concurrent workers (`io.concurrent`, `group.concurrent`, `Thread.spawn`) and awaits them.
- The spawn block and the await block together form one named step.

Code shape (single spawn+await step).  
```zig
pub fn run(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbh: MailboxHandle = try mailbox.new(io, allocator);
    defer { ... }

    try seedMailbox(mbh, allocator);
    try spawnAndAwaitWorkers(mbh, allocator, io);

    try helpers.expect(error.XFailed, ...);
    std.log.info("done", .{});
}

fn spawnAndAwaitWorkers(mbh: MailboxHandle, alloc: std.mem.Allocator, io: std.Io) !void {
    var ctx1: WorkerCtx = .{ .mbh = mbh, .alloc = alloc };
    var ctx2: WorkerCtx = .{ .mbh = mbh, .alloc = alloc };
    var fut1 = try io.concurrent(workerFn, .{&ctx1});
    var fut2 = try io.concurrent(workerFn, .{&ctx2});
    try fut1.await(io);
    try fut2.await(io);
}
```

Code shape (separate spawn and await steps).  
```zig
fn spawnWorkers(mbh: MailboxHandle, alloc: std.mem.Allocator, io: std.Io, group: *std.Io.Group) !void {
    for (0..N_WORKERS) |i| {
        group.concurrent(io, workerFn, .{ &worker_ctxs[i] }) catch return error.SpawnFailed;
    }
}

fn awaitWorkers(mbh: MailboxHandle, alloc: std.mem.Allocator, io: std.Io, group: *std.Io.Group) !void {
    try group.await(io);
    // verify results
}
```

- ctx declarations, spawns, and awaits all live inside the named step — not inline in the coordinator.
- Coordinator sees one or two calls. Flow is visible without opening the step.
- If spawn and await are tightly coupled (no coordinator logic between them), merge into one step.
- If coordinator logic falls between spawn and await, use two steps.

Examples: `examples/layer4/017-minimal_master.zig`, `examples/layer4/054-pool_fan_out.zig`.

### Master composition

When to use.

- A story or service has more than one coordination boundary.

The shape.

- Each Master owns its resources and coordinates their lifecycle.
- A Master is a state struct plus a loop function — not inlined into `run`.
- `run` is thin: initialize resources, start Masters, await shutdown in order.

Two Masters in the pilot story.

- Network Master — an `Io.Select` loop. Owns the buffer pool as a backpressure source. Fills buffers, routes `StreamContext` to the ready queue.
- Worker set — an `Io.Group`. Each worker receives a `StreamContext`, encodes, returns the buffer to the pool, sends an `EncodedSegment` to storage.
- Storage task — a single-mailbox loop. Receives `EncodedSegment`, logs, frees.

Code shape (thin run).  
```zig
pub fn run(allocator: std.mem.Allocator, io: std.Io) !void {
    // 1. initialize shared resources: pool, mailboxes
    // 2. start Masters: storage task, worker group, network loop
    // 3. await shutdown in mandatory order
}
```

- The coordination logic of each Master lives in its own function.
- `run` shows the startup order and the shutdown order — nothing else.

Example: `stories/video_transcoder/video_transcoder.zig`.  
<!-- Temporarily hidden — Deep Dive section commented out of mkdocs.yml nav.  
See the [Deep Dive](../deep-dive/video-transcoder.md) page. -->


### Mailbox + Pool integration

When to use.

- Separate lifecycle from transport.

Pattern.  
```
Pool
   │
 get
   │
 work
   │
send
   │
Mailbox
```

### Full Layer-4 architecture

Pattern.  
```
          Io.Select
               │
      ┌────────┴────────┐
      │                 │
  Mailbox          Pool events
      │                 │
      └────────┬────────┘
               │
            Master
               │
         Io.Group workers
```

Purpose.

- Event-driven coordination.
- Worker parallelism.
- Safe item transport.
- Automatic backpressure.

---

