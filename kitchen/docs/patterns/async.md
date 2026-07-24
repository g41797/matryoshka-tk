# Patterns — Futures, Select, Group, Cancellation

New to `std.Io` concepts? See [Addendums — Io 101](../addendums/io-101.md) first.

## Future patterns

### Direct Future

When to use.

- Only one asynchronous operation. No Select loop needed.

Code shape.  
```zig
const future =
    try mailbox.receive_future(mbh, null);

const result =
    try future.await(io);
```

### Future cancellation

When to use.

- Abort one asynchronous operation.

Code shape.  
```zig
try future.cancel(io);
```

Why.

- The item stays in the mailbox/pool.
- Only the wait is canceled.

---

## Io.Select patterns

### Event loop — register, await, re-register

When to use.

- Wait on several sources at once: mailbox, pool, timer, external push.

Code shape.  
```zig
var buf: [8]MasterEvent = undefined;
var sel: std.Io.Select(MasterEvent) = std.Io.Select(MasterEvent).init(io, &buf);

try sel.concurrent(.inbox, mailbox.receiveResult, .{ mbh, null });
try sel.concurrent(.pool_ev, pool.getWaitResult, .{ ph, TAG, null });
try sel.concurrent(.timer, sleepFn, .{ sleep_t, io });

while (true) {
    const event: MasterEvent = try sel.await();
    switch (event) {
        .inbox => |r| switch (r) {
            .item => |handle| {
                // process, then re-register the source
                try sel.concurrent(.inbox, mailbox.receiveResult, .{ mbh, null });
            },
            .closed, .canceled, .timeout => break,
        },
        // ...
    }
}
```

Why.

- Each registration produces exactly one completion.
- Re-register the source after each item.

The rhythm.  
```
register
    ↓
await
    ↓
process
    ↓
register again
```

Example: `examples/layer4/031-select_graceful_shutdown.zig`, `examples/layer4/028-select_mixed_sources.zig`.

### Mailbox as event source

When to use.

- Event-driven Master.

Code shape.  
```zig
try select.concurrent(
    .mailbox,
    mailbox.receiveResult,
    .{ mbh, null },
);
```

### Pool as event source

When to use.

- Wait for reusable items.

Code shape.  
```zig
try select.concurrent(
    .pool,
    pool.getWaitResult,
    .{ ph, TAG, null },
);
```

### Mixed event sources

When to use.

- One loop coordinates everything.

Pattern.  
```
Mailbox
Pool
Timer
Socket
External callback
        │
        V
    Io.Select
```

Example: `examples/layer4/028-select_mixed_sources.zig`.

### Backpressure via getWaitResult in Select

When to use.

- A producer must slow down when no buffers are free.
- Pool availability becomes an event source in the same loop as data.

Code shape.  
```zig
try sel.concurrent(.buf_ev, pool.getWaitResult, .{ buf_ph, VideoBufferPolyHelper.TAG, null });
// ...
const ev = try sel.await();
switch (ev) {
    .buf_ev => |r| switch (r) {
        .item => |handle| {
            // fill buffer, route it, then re-register for the next free buffer
            try sel.concurrent(.buf_ev, pool.getWaitResult, .{ buf_ph, VideoBufferPolyHelper.TAG, null });
        },
        .closed, .canceled, .timeout, .not_created => break,
    },
}
```

- The loop blocks until a worker returns a buffer.
- No sleep. No poll. The pool wakes the waiter.

Example: `stories/video_transcoder/video_transcoder.zig`.

### Direct push — putOneUncancelable

When to use.

- A result is already available, or an external thread or callback must inject one without spawning.

Code shape.  
```zig
select.queue.putOneUncancelable(select.io, .{ .field = value }) catch {};
```

Example: `examples/layer4/043-select_direct_push.zig`.

### Graceful cancel walk — recover in-flight items

When to use.

- Shutting down a Select loop. Spawned sources may still hold items. None must leak.

Code shape.  
```zig
while (sel.cancel()) |event| {
    switch (event) {
        .inbox => |r| switch (r) {
            .item => |handle| {
                var slot: Slot = handle;
                helpers.freeSlot(&slot, allocator);   // recover the item
            },
            .canceled, .closed, .timeout => {},
        },
        .pool_ev => |r| switch (r) {
            .item => |handle| {
                var slot: Slot = handle;
                pool.put(ph, &slot);                   // recycle it
            },
            .canceled, .closed, .timeout, .not_created => {},
        },
        .timer => {},
    }
}
```

Example: `examples/layer4/031-select_graceful_shutdown.zig`.

### cancelDiscard — timer-only or no-item sources

When to use.

- The remaining spawned sources carry no owned item (e.g. a timer). Discard them.

Code shape.  
```zig
sel.cancelDiscard();
```

Example: `stories/video_transcoder/video_transcoder.zig`.

---

## Io.Group patterns

### Worker set — concurrent then await

When to use.

- Run several workers. Wait for all to finish.
- Spawn now, await later — the spawn does not block.

Code shape.  
```zig
var group: Io.Group = .init;
try group.concurrent(io, workerFn, .{&ctx0});
try group.concurrent(io, workerFn, .{&ctx1});
try group.await(io);
```

- Worker return type must coerce to `Cancelable!void`.

Example: `stories/video_transcoder/video_transcoder.zig`.

### Reusable Group

When to use.

- Multiple execution rounds.

Pattern.  
```
spawn
await

spawn
await
```

Why.

- Group may be reused after completion.

### Shutdown signal — close the source mailbox

When to use.

- Stop a Group of workers that block on `mailbox.receive`.

Code shape.  
```zig
// workers exit when receive returns error.Closed
var rem: std.DoublyLinkedList = mailbox.close(ready_queue);
// walk rem, recover any unreceived items
try group.await(io);
```

- Close is the end-of-stream signal. Workers return on `error.Closed`.

Example: `stories/video_transcoder/video_transcoder.zig`.

### Shutdown signal — group.cancel

When to use.

- Stop a Group of workers that block on `pool.get_wait`, with no mailbox to close.

Code shape.  
```zig
group.cancel(io);   // injects error.Canceled into all blocked workers, then waits
```

- Blocked workers return `error.Canceled`. A worker that already finished is unaffected.

Example: `examples/layer4/059-mailbox_less_pool_group_workers.zig`.

---

## Cancellation patterns

### Cancellation boundary

When to use.

- Designing APIs.

Rule.

Only waiting operations are cancelable.

Examples.

- mailbox.receive
- pool.get_wait
- receiveResult
- getWaitResult

Everything else completes normally.

### Cancellation keeps items in place

When to use.

- Recovering after cancellation.

Pattern.  
```
Canceled
    ↓
slot unchanged
    ↓
resource still owned by mailbox/pool
```

### Close versus Cancel

Pattern.  
```
Close
    ↓
end of stream

Cancel
    ↓
stop waiting
```

Never substitute one for the other.

### Error handling on receive

When to use.

- A worker blocks on `mailbox.receive` or `pool.get_wait` and must react to each outcome.

Code shape.  
```zig
mailbox.receive(ctx.mbh, &slot, null) catch |err| switch (err) {
    error.Canceled => return error.Canceled,   // report up — Master decides
    error.Closed, error.Timeout => return,      // end-of-stream — exit cleanly
    error.Wakeup => continue,                   // poke — re-check loop condition
};
```

The distinction.

- `error.Canceled` — external stop signal. Propagate it. Do not close anything.
- `error.Closed` — the Master closed the source. End of stream. Exit.
- `error.Timeout` — the wait window passed. Treat per domain.
- `error.Wakeup` — a `wakeUpAll` poke. No item. Re-check state and continue.
- Never remap `error.Canceled` to `error.Closed`. They mean different things.

Example: `stories/video_transcoder/video_transcoder.zig`, `examples/layer4/059-mailbox_less_pool_group_workers.zig`.

---

