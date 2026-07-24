# API Reference — Pool


---

**HARDEST PART OF MATRYOSHKA** 

- not because Pool per-se
- because your code will be part of ... 

---

New to the concept? See [Building Blocks — Pool](../building-blocks/pool.md) first.

Lifecycle management with _user supplied hooks_.

Pool is not storage.

- It answers one question: is a reusable item available right now.
- It signals backpressure through that answer.
- What happens to an item on `put` is entirely up to the hooks.

```zig
const pool = @import("matryoshka").pool;

// typical usage:
var slot: polynode.Slot = null;
try pool.get(ph, EVENT_TAG, .available_or_new, &slot);   // slot is now non-null
pool.put(ph, &slot);                                      // slot is now null (if kept)
```

## Lifecycle flow

```text
new()
  ↓
EMPTY pool

get() [available_or_new, pool empty]     get() [available_or_new, pool has items]
  ↓ on_get creates item                    ↓ item moved from free-list
IN_FLIGHT (with caller)                  IN_FLIGHT (with caller)

put() [on_put keeps]                     put() [on_put destroys]
  ↓                                             ↓
HELD (pool free-list)                    FREE (caller frees)

get() [available_only or available_or_new]
  ↓
IN_FLIGHT (with caller)

close()
  ↓ on_close receives full list of HELD items → caller frees each
FREE
```

## Types

```zig
pub const PoolHandle = ItemHandle;
```

PoolHandle is itself a *PolyNode.  
A pool can be:

- sent through a mailbox
- embedded into larger structures

Same rules as application items.

```zig
pub const GetMode = enum {
    available_or_new,    // use stored handle if available, otherwise call on_get to create
    new_only,            // always call on_get with slot.* == null to create fresh
    available_only,      // use stored handle only; if empty, return error.NotAvailable
};

pub const GetError = error{
    Closed,
    NotAvailable,
    NotCreated,
};
```

## PoolHooks

```zig
pub const PoolHooks = struct {
    ctx:      *anyopaque,
    tags:     []const *const anyopaque,
    on_get:   *const fn (ctx: *anyopaque, tag: *const anyopaque, in_pool_count: usize, slot: *Slot) void,
    on_put:   *const fn (ctx: *anyopaque, in_pool_count: usize, slot: *Slot) void,
    on_close: *const fn (ctx: *anyopaque, list: *std.DoublyLinkedList) void,
};
```

**`in_pool_count` semantics**

- `on_get`: count **after** removal — items remaining with this tag.
- `on_put`: count **before** addition — items already stored with this tag.
- Both values are **hints**.
- Read under lock, passed to a hook running without lock.
- The pool may have changed by the time the hook reads the value.

**Hook concurrency**

- Hooks are called **outside the pool mutex**.
- Multiple threads may invoke hooks simultaneously — the pool does not serialize them.

**Advice for hook implementers**

- If your hook touches shared state, protect it.
- Example: use `Io.Mutex` and call `lockUncancelable` to acquire it.
  Hooks return `void` — `lock` (cancelable) is not an option here.

- Obtain `io` from the surrounding context that holds the pool; do not acquire it inside the hook.
- `CappedPoolHooks` in `examples/hooks/CappedPoolHooks.zig` is the reference implementation of these rules.

## Functions

```zig
pub fn new(io: Io, alloc: std.mem.Allocator) !PoolHandle
```

- Creates a new pool.
- Stores `io` internally.

```zig
pub fn destroy(ph: PoolHandle, alloc: std.mem.Allocator) void
```

- Frees the pool.
- Must be closed first.
- Calling destroy on an open pool is a programming error (panic).
- Assert:
  - `pool.is_it_you(ph.*.tag)`

```zig
pub fn init(ph: PoolHandle, hooks: PoolHooks) !void
```

- Registers hooks.
- Called once after `new`.
- Assert:
  - `pool.is_it_you(ph.*.tag)`
  - Hooks tags not empty, each tag not null.
  - Pool not already closed.

```zig
pub fn get(ph: PoolHandle, tag: *const anyopaque, mode: GetMode, slot: *Slot) GetError!void
```

- Non-blocking acquisition.
- Calls `on_get` hook.
- Moves the handle — `slot.*` set to non-null on success.
- Assert:
  - `pool.is_it_you(ph.*.tag)`
  - `slot.* == null`
  - Pool initialized.
  - Tag registered.

```zig
pub fn get_wait(ph: PoolHandle, tag: *const anyopaque, slot: *Slot, timeout_ns: ?u64) (GetError || Cancelable || error{Timeout})!void
```

- Blocking acquisition.
- `null` timeout = wait forever.
- `timeout_ns = 0` returns `error.Timeout` immediately.
- Logically equivalent to `get(.available_only)`, but a different error (`error.Timeout` vs `error.NotAvailable`).
- Intentional: `get_wait` always uses the timeout error set, regardless of the timeout value.
- Calls `on_get` hook.
- Assert:
  - `pool.is_it_you(ph.*.tag)`
  - `slot.* == null`
  - Pool initialized.
  - Tag registered.

```zig
pub fn put(ph: PoolHandle, slot: *Slot) void
```

- Returns handle to pool.
- `slot.* == null` → returns immediately. No hook call. No assert on tag.
- **Open pool**:
  - Calls `on_put` hook.
  - `on_put` picks the outcome — matryoshka does not mandate any of them:
    - **deleted, nothing returned** — hook frees the item, `slot.*` set to null.
    - **returned as-is** — hook leaves the item's data untouched, `slot.*` stays non-null.
    - **returned after reset** — hook resets the item's data before keeping it.
    - **deleted, a different item returned** — hook frees the original and puts a different item in `slot.*`.
  - `slot.*` stays non-null exactly when an item — original or replacement — is kept.
- **Closed pool**:
  - Returns immediately, no hook call.
  - `slot.*` stays non-null — caller keeps the handle.
- Assert (when slot.* != null):
  - `pool.is_it_you(ph.*.tag)`
  - `!polynode.is_linked(slot.*)`

**No sequence guarantee.** A call pattern like "put three times, then get  
three times" carries no fixed count, identity, or ordering guarantee — it  
depends entirely on hook policy. This repo's own example hooks  
(`examples/hooks/`) reset to default values on `put`, but that's our  
examples' convention, not a matryoshka rule.

```zig
pub fn put_all(ph: PoolHandle, list: *std.DoublyLinkedList) void
```

- Returns batch of handles to pool.
- Pops from caller's list.
- Transfer is not atomic with respect to `close()`.
- If the pool closes mid-batch: items already transferred are passed to `on_close`; items not yet transferred stay in the caller's list.
- Restoration order when closed mid-batch may differ from original order.
- Assert:
  - `pool.is_it_you(ph.*.tag)`
  - Each node's tag registered in pool's tag set.

```zig
pub fn close(ph: PoolHandle) void
```

- Can be called more than once.
- Collects all handles from all per-tag free-lists.
- Calls `on_close` once with the full list.
- Broadcasts to wake blocked `get_wait` callers.
- Assert:
  - `pool.is_it_you(ph.*.tag)`

```zig
pub fn is_it_you(tag: *const anyopaque) bool
```

- Returns true if tag identifies a PoolHandle.

## Error sets

| Error | Meaning |
|-------|---------|
| `error.Closed` | Pool was closed via `close()` |
| `error.NotAvailable` | `available_only` mode, no stored handle |
| `error.NotCreated` | `on_get` was called but did not return a handle |
| `error.Timeout` | `timeout_ns` expired (only when non-null, `get_wait` only) |
| `error.Canceled` | Waiting operation was canceled (`get_wait` only) |

## Event source helpers

Pool as event source for `Io.Select` and `Io.Future`.

Cancel and close in concurrent tasks:

- Pool closed — blocked callers wake with `error.Closed`.
- Task canceled — the operation returns `error.Canceled`.

When a handle becomes available, the Master can react. This is the job-pool pattern:

- Worker returns a handle.
- Master is notified.
- Master submits new work.

### Types

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

### Functions

```zig
pub fn getWaitResult(ph: PoolHandle, tag: *const anyopaque, timeout_ns: ?u64) PoolResult
```

- Blocking function. No error return — maps all outcomes to `PoolResult` variants.
- Primary building block for Select integration:
  ```zig
  try select.concurrent(.pool, pool.getWaitResult, .{ph, TAG, null});
  ```

- Also usable with `io.concurrent` or `group.concurrent`.

```zig
pub fn get_wait_future(ph: PoolHandle, tag: *const anyopaque, timeout_ns: ?u64) ConcurrentError!Io.Future(PoolResult)
```

- Thin wrapper: `return p.*.io.concurrent(getWaitResult, .{ph, tag, timeout_ns})`.
- No heap allocation — args copied by the runtime before `concurrent` returns.
- Returns a Future for direct await or `Io.Group` use.
- Returns `error.ConcurrencyUnavailable` on single-threaded backends.

### Cancel behavior

- On `error.Canceled`, returns `.canceled` — the pool remains open.
- Closing is the Master's responsibility.

## Hook discipline

- Hooks run outside the pool's internal lock.
- The pool updates its own state first, then releases the lock, then calls your hook.
- Your hook code does not block other pool operations.
- `on_get`:
  - Called for every `get` and `get_wait` call regardless of mode or whether an item was found in the free-list.
  - If `slot.*` is non-null on entry: the item was recycled from the free-list — reinitialize it.
  - If `slot.*` is null on entry: no item was available — create a new one or leave null (creation failed).
  - Must either leave `slot.* == null` (creation failed) OR set `slot.*` to a valid node with the same tag that was requested.
  - Returning an item with a different tag is a programming error (assert in Debug/ReleaseSafe).
- `on_put`:
  - Set `slot.*` to null = destroy (optionally after putting a different item there first — see the four `put` outcomes above).
  - Leave non-null = keep in pool, as-is or after resetting its data — your choice.
- `on_close`:
  - Receives `*std.DoublyLinkedList`.
  - Walks via `popFirst()`, frees each handle.
- Hook reentrancy is forbidden. From inside any hook, do not:
  - call `get`, `get_wait`, `put`, `put_all`, `close`, or `destroy` on the same pool
  - block or wait on any condition
  - allocate in a way that could recursively trigger pool operations
  - Not a deadlock — hooks run outside the lock.
  - Contract violation — the pool cannot manage what it holds if hooks change it concurrently.

---

## Starting point

Hooks can do a lot.  

Start from simplest - [Always Create](../examples/layer3/089-basic_recycler.md)

Next - [Limited capacity](../examples/layer3/090-capped_pool.md) 

Be careful - you inject your code to the heart of Matryoshka.

---
