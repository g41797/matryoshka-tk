# Control group

New to the concept? See [Tools — Pool](../../tools/pool.md) first.

---

## init

```zig
pub fn init(self: *Pool, hooks: Pool.Hooks) !void
```

- Registers hooks.
- Called once after `new`.
- Assert:
  - Hooks tags not empty, each tag not null.
  - Pool not already closed.

---

## close

```zig
pub fn close(self: *Pool) void
```

- Can be called more than once.
- Collects all handles from all per-tag free-lists.
- Calls `on_close` once with the full list.
- Broadcasts to wake blocked `get_wait` callers.

---

## destroy

```zig
pub fn destroy(pl: *Pool, alloc: std.mem.Allocator) void
```

- Frees the pool.
- Must be closed first.
- Calling destroy on an open pool is a programming error (panic).

---

## is_it_you

```zig
pub fn is_it_you(tag: *const anyopaque) bool
```

- Returns true if tag identifies a *Pool.

---

