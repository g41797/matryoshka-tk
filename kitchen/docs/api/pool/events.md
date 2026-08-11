# Event source helpers

New to the concept? See [Tools — Pool](../../tools/pool.md) first.

Pool as event source for `Io.Select` and `Io.Future`.

Cancel and close in concurrent tasks:

- Pool closed — blocked callers wake with `error.Closed`.
- Task canceled — the operation returns `error.Canceled`.

When a handle becomes available, the Master can react. This is the job-pool pattern:

- Worker returns a handle.
- Master is notified.
- Master submits new work.

---

## PoolResult

```zig
pub const PoolResult = union(enum) {
    item: ItemHandle,
    closed: void,
    timeout: void,
    canceled: void,
    not_created: void,
};
```

- The handle is inside the result, not behind a pointer. No `*Slot` is shared across threads.
- When you get `.item`, the handle is yours. The pool no longer holds it.

---

## getWaitResult

```zig
pub fn getWaitResult(ph: PoolHandle, tag: *const anyopaque, timeout_ns: ?u64) PoolResult
```

- Blocking function. No error return — maps all outcomes to `PoolResult` variants.
- Primary building block for Select integration:
  ```zig
  try select.concurrent(.pool, pool.getWaitResult, .{ph, TAG, null});
  ```

- Also usable with `io.concurrent` or `group.concurrent`.

---

## get_wait_future

```zig
pub fn get_wait_future(ph: PoolHandle, tag: *const anyopaque, timeout_ns: ?u64) ConcurrentError!Io.Future(PoolResult)
```

- Thin wrapper: `return p.*.io.concurrent(getWaitResult, .{ph, tag, timeout_ns})`.
- No heap allocation — args copied by the runtime before `concurrent` returns.
- Returns a Future for direct await or `Io.Group` use.
- Returns `error.ConcurrencyUnavailable` on single-threaded backends.

---

## Cancel behavior

- On `error.Canceled`, returns `.canceled` — the pool remains open.
- Closing is the Master's responsibility.

---

