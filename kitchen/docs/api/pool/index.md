# Pool

---

**HARDEST PART OF MATRYOSHKA** 

- not because Pool per-se
- because your code will be part of ... 

---

New to the concept? See [Tools — Pool](../../tools/pool.md) first.

Lifecycle management with _user supplied hooks_.

Pool is not storage.

- It answers one question: is a reusable item available right now.
- It signals backpressure through that answer.
- What happens to an item on `put` is entirely up to the hooks.

```zig
const pool = @import("matryoshka").pool;

// typical usage:
var slot: polynode.Slot = null;
try pl.get(EVENT_TAG, .available_or_new, &slot);   // slot is now non-null
pl.put(&slot);                                      // slot is now null (if kept)
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
pub const Pool = struct { ... };
```

Application code holds `*Pool` and calls methods on it.

A pool is also a PolyNode. `toPoly`/`fromPoly` carry it through a mailbox or  
another pool. A pool can be:

- sent through a mailbox
- embedded into larger structures

Same rules as application items.

The struct fields are internal. Use the methods.

```zig
// nested in Pool
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

## What a pool does that a mailbox does not

A pool touches items — it creates, resets, keeps or destroys them. Every one  
of those is your hook doing it, never the pool deciding on its own. A
[Mailbox](../mailbox/index.md) never touches an item at all.

A closed pool gives items back:

- `put` is a no-op and leaves the slot unchanged.
- `put_all` stops at the first refusal and leaves the rest in the list.

Either way the caller still holds those items and must release them.

`close` is the other difference. It collects everything held and passes the  
list to `on_close`, so the hook releases it — where a mailbox returns the  
list to the caller and leaves the releasing to them.

---

## Pool.Hooks

```zig
// nested in Pool
pub const Hooks = struct {
    ctx:      *anyopaque,
    tags:     []const *const anyopaque,
    on_get:   *const fn (ctx: *anyopaque, tag: *const anyopaque, in_pool_count: usize, slot: *Slot) void,
    on_put:   *const fn (ctx: *anyopaque, in_pool_count: usize, slot: *Slot) ?polynode.ItemList,
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

