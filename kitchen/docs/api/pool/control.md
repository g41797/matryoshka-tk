# Control group

New to the concept? See [Building Blocks — Pool](../../building-blocks/pool.md) first.

---

## init

```zig
pub fn init(ph: PoolHandle, hooks: PoolHooks) !void
```

- Registers hooks.
- Called once after `new`.
- Assert:
  - `pool.is_it_you(ph.*.tag)`
  - Hooks tags not empty, each tag not null.
  - Pool not already closed.

---

## close

```zig
pub fn close(ph: PoolHandle) void
```

- Can be called more than once.
- Collects all handles from all per-tag free-lists.
- Calls `on_close` once with the full list.
- Broadcasts to wake blocked `get_wait` callers.
- Assert:
  - `pool.is_it_you(ph.*.tag)`

---

## destroy

```zig
pub fn destroy(ph: PoolHandle, alloc: std.mem.Allocator) void
```

- Frees the pool.
- Must be closed first.
- Calling destroy on an open pool is a programming error (panic).
- Assert:
  - `pool.is_it_you(ph.*.tag)`

---

## is_it_you

```zig
pub fn is_it_you(tag: *const anyopaque) bool
```

- Returns true if tag identifies a PoolHandle.

---

