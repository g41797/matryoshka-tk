# Pool

---

**HARDEST PART OF MATRYOSHKA** 

- not because Pool per-se
- because your code will be part of ... 

---

New to the concept? See [Building Blocks — Pool](../../building-blocks/pool.md) first.

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

---

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

---

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

---

## PoolHooks

```zig
pub const PoolHooks = struct {
    ctx:      *anyopaque,
    tags:     []const *const anyopaque,
    on_get:   *const fn (ctx: *anyopaque, tag: *const anyopaque, in_pool_count: usize, slot: *Slot) void,
    on_put:   *const fn (ctx: *anyopaque, in_pool_count: usize, slot: *Slot) void,
    on_close: *const fn (ctx: *anyopaque, list: *polynode.ItemList) void,
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

---

