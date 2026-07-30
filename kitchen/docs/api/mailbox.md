# API Reference — Mailbox

New to the concept? See [Building Blocks — Mailbox](../building-blocks/mailbox.md) first.

Moves handles between Masters.

```zig
const mailbox = @import("matryoshka").mailbox;

// typical usage:
var slot: polynode.Slot = &event.poly;
try mailbox.send(inbox, &slot);              // slot is now null
try mailbox.receive(inbox, &slot, null);     // slot is now non-null
```

## send — the handle moves out

```text
Before                           After

sender Slot                      sender Slot
+-------------------+            +-------------------+
|    ItemHandle     |            |       null        |
+-------------------+            +-------------------+

mailbox.send(mbh, &slot)  ───►      Mailbox holds ItemHandle
```

## receive — the handle moves in

```text
Before                           After

receiver Slot                    receiver Slot
+-------------------+            +-------------------+
|       null        |            |    ItemHandle     |
+-------------------+            +-------------------+

mailbox.receive(mbh, &slot, null)   Receiver holds ItemHandle
```

## Types

```zig
pub const MailboxHandle = ItemHandle;
```

MailboxHandle is itself a *PolyNode.  
A mailbox can be:

- sent through another mailbox
- stored in pools
- embedded into larger structures

Same rules as application items.

## Functions

```zig
pub fn new(io: Io, alloc: std.mem.Allocator) !MailboxHandle
```

- Creates a new mailbox.
- Stores `io` internally.

```zig
pub fn send(mbh: MailboxHandle, slot: *Slot) error{Closed}!void
```

- Appends handle to tail.
- Moves the handle — `slot.*` set to null.
- Assert:
  - `mailbox.is_it_you(mbh.*.tag)`
  - `slot.* != null`
  - `!polynode.is_linked(slot.*)`

```zig
pub fn receive(mbh: MailboxHandle, slot: *Slot, timeout_ns: ?u64) (error{ Closed, Timeout, Wakeup } || Cancelable)!void
```

- Blocks until handle available.
- `null` timeout = wait forever.
- `timeout_ns = 0` returns `error.Timeout` immediately — equivalent to `try_receive`.
- Moves the handle — `slot.*` set to non-null.
- OOB handles arrive first (front of queue).
- `wakeUpAll()` called while blocked here — returns `error.Wakeup`, `slot.*` stays null.
- Multiple concurrent receivers compete for each handle.
- One receiver gets it.
- Order among waiters depends on the Io runtime — not guaranteed FIFO.
- Assert:
  - `mailbox.is_it_you(mbh.*.tag)`
  - `slot.* == null`

```zig
pub fn try_receive(mbh: MailboxHandle, slot: *Slot) error{Closed}!bool
```

- Non-blocking.
- Returns true if handle received, false if queue empty.
- Assert:
  - `mailbox.is_it_you(mbh.*.tag)`
  - `slot.* == null`

```zig
pub fn receive_batch(mbh: MailboxHandle) error{Closed}!polynode.ItemList
```

- Non-blocking.
- Takes everything from the queue at once.
- Returns an empty `ItemList` if queue is currently empty.
- Does not wait. Does not return error for empty.
- Assert:
  - `mailbox.is_it_you(mbh.*.tag)`

```zig
pub fn wakeUpAll(mbh: MailboxHandle) error{Closed}!void
```

- Wakes every receiver currently blocked in `receive()` — no item is sent, nothing is queued.
- Blocked receivers return `error.Wakeup`.
- Future receivers (those that call `receive()` after `wakeUpAll()` returns) are not affected.
- Distinct from `close()`: the mailbox is not torn down, and the effect does not persist for
  receivers that start later.

- Assert:
  - `mailbox.is_it_you(mbh.*.tag)`

```zig
pub fn close(mbh: MailboxHandle) polynode.ItemList
```

- Can be called more than once.
- Returns remaining handles as list (empty list on second call).
- Collects all handles still in the queue.
- Wakes up any receivers waiting on the mailbox.
- Assert:
  - `mailbox.is_it_you(mbh.*.tag)`

```zig
pub fn destroy(mbh: MailboxHandle, alloc: std.mem.Allocator) void
```

- Frees the mailbox.
- Must be closed first.
- Calling destroy on an open mailbox is a programming error (panic).
- Assert:
  - `mailbox.is_it_you(mbh.*.tag)`

```zig
pub fn is_it_you(tag: *const anyopaque) bool
```

- Returns true if tag identifies a MailboxHandle.

## Error sets

| Error | Meaning |
|-------|---------|
| `error.Closed` | Mailbox was closed via `close()` |
| `error.Timeout` | `timeout_ns` expired (only when non-null) |
| `error.Canceled` | Waiting operation was canceled |
| `error.Wakeup` | `wakeUpAll()` woke this receiver — no item, mailbox stays open |

## Event source helpers

Mailbox as event source for `Io.Select` and `Io.Future`.

Cancel and close in concurrent tasks:

- Mailbox closed — blocked receivers wake with `error.Closed`.
- Task canceled — the operation returns `error.Canceled`.

### Types

```zig
pub const ReceiveResult = union(enum) {
    item: ItemHandle,
    closed: void,
    timeout: void,
    canceled: void,
    wakeup: void,
};
```

- The handle is inside the result, not behind a pointer. No `*Slot` is shared across threads.
- When you get `.item`, the handle is yours. The mailbox no longer holds it.

### Functions

```zig
pub fn receiveResult(mbh: MailboxHandle, timeout_ns: ?u64) ReceiveResult
```

- Blocking function. No error return — maps all outcomes to `ReceiveResult` variants.
- Primary building block for Select integration:
  ```zig
  try select.concurrent(.inbox, mailbox.receiveResult, .{mbh, null});
  ```

- Also usable with `io.concurrent` or `group.concurrent`.

```zig
pub fn receive_future(mbh: MailboxHandle, timeout_ns: ?u64) ConcurrentError!Io.Future(ReceiveResult)
```

- Thin wrapper: `return mbx.*.io.concurrent(receiveResult, .{mbh, timeout_ns})`.
- No heap allocation — args copied by the runtime before `concurrent` returns.
- Returns a Future for direct await or `Io.Group` use.
- Returns `error.ConcurrencyUnavailable` on single-threaded backends.

### Cancel behavior

- On `error.Canceled`, returns `.canceled` — the mailbox remains open.
- Closing is the Master's responsibility.

### When to use

**`select.concurrent` pattern** (primary):  
```zig
try select.concurrent(.inbox, mailbox.receiveResult, .{mbh, null});
const event = try select.await();
switch (event) {
    .inbox => |r| switch (r) { ... },
    ...
}
```

**`receive_future` pattern** (direct await or Group):  
```zig
const fut = try mailbox.receive_future(mbh, null);
const result = try fut.await(io);
```

**Bridging to external Io**: one `Io.Select` loop combines mailbox, timers, sockets, pool availability.

- Matryoshka sources use `receiveResult` / `getWaitResult` via `select.concurrent`.
- External sources use their own blocking functions via `select.concurrent`.
- Direct push: `select.queue.putOneUncancelable(io, value)` for immediate events.

## Advanced: OOB (out of the box)

```zig
pub fn send_oob(mbh: MailboxHandle, slot: *Slot) error{Closed}!void
```

- Inserts handle after last OOB handle.
- FIFO among OOBs, all OOBs before regular handles.
- Moves the handle — `slot.*` set to null.
- Assert:
  - `mailbox.is_it_you(mbh.*.tag)`
  - `slot.* != null`
  - `!polynode.is_linked(slot.*)`

OOB ordering:

```
send(R1), send(R2):       [R1, R2]                oob=0
send_oob(O1):             [O1, R1, R2]            oob=1
send(R3):                 [O1, R1, R2, R3]        oob=1
send_oob(O2):             [O1, O2, R1, R2, R3]   oob=2
receive → O1:             [O2, R1, R2, R3]        oob=1
receive → O2:             [R1, R2, R3]            oob=0
```

---
