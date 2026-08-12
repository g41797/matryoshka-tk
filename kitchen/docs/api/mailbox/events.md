# Event source helpers

New to the concept? See [Tools — Mailbox](../../tools/mailbox.md) first.

Mailbox as event source for `Io.Select` and `Io.Future`.

Cancel and close in concurrent tasks:

- Mailbox closed — blocked receivers wake with `error.Closed`.
- Task canceled — the operation returns `error.Canceled`.

---

## Mbox.Result

```zig
// nested in Mbox
pub const Result = union(enum) {
    item: ItemHandle,
    closed: void,
    timeout: void,
    canceled: void,
    wakeup: void,
};
```

- The handle is inside the result, not behind a pointer. No `*Slot` is shared across threads.
- When you get `.item`, the handle is yours. The mailbox no longer holds it.

---

## receiveResult

```zig
pub fn receiveResult(mbx: *Mbox, timeout_ns: ?u64) Mbox.Result
```

- Blocking function. No error return — maps all outcomes to `Mbox.Result` variants.
- Primary building block for Select integration:
  ```zig
  try select.concurrent(.inbox, mailbox.receiveResult, .{mbx, null});
  ```

- Also usable with `io.concurrent` or `group.concurrent`.

---

## receive_future

```zig
pub fn receive_future(self: *Mbox, timeout_ns: ?u64) ConcurrentError!Io.Future(Mbox.Result)
```

- Thin wrapper: `return mbx.*.io.concurrent(receiveResult, .{mbx, timeout_ns})`.
- No heap allocation — args copied by the runtime before `concurrent` returns.
- Returns a Future for direct await or `Io.Group` use.
- Returns `error.ConcurrencyUnavailable` on single-threaded backends.

---

## Cancel behavior

- On `error.Canceled`, returns `.canceled` — the mailbox remains open.
- Closing is the Master's responsibility.

---

## When to use

**`select.concurrent` pattern** (primary):  
```zig
try select.concurrent(.inbox, mailbox.receiveResult, .{mbx, null});
const event = try select.await();
switch (event) {
    .inbox => |r| switch (r) { ... },
    ...
}
```

**`receive_future` pattern** (direct await or Group):  
```zig
const fut = try mbx.receive_future(null);
const result = try fut.await(io);
```

**Bridging to external Io**: one `Io.Select` loop combines mailbox, timers, sockets, pool availability.

- Matryoshka sources use `receiveResult` / `getWaitResult` via `select.concurrent`.
- External sources use their own blocking functions via `select.concurrent`.
- Direct push: `select.queue.putOneUncancelable(io, value)` for immediate events.

---

