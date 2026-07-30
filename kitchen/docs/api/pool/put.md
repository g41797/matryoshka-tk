# Put group

New to the concept? See [Building Blocks — Pool](../../building-blocks/pool.md) first.

---

## put

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
  - `on_put` also returns `?ItemList` — items to add alongside
    `slot`. `null` or empty: nothing extra. Non-empty: each item is added  
    the same way `slot`'s item is — same checks, same assert on foreign  
    tag. See [Composite Items](#composite-items) below.

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

---

## Composite Items

An item may hold other pooled items.

Before the parent item enters the pool, `on_put` can return them as an  
extra `ItemList` alongside `slot`. The pool adds every item in  
that list the same way it adds `slot`'s item.

The hook is responsible for handing back only valid, unlinked,  
correctly-tagged items — the pool does not validate that they form a  
real composite.

The pool does not distinguish between simple and composite items.

---

## put_all

```zig
pub fn put_all(ph: PoolHandle, list: *polynode.ItemList) void
```

- Returns batch of handles to pool.
- Pops from caller's list.
- Transfer is not atomic with respect to `close()`.
- If the pool closes mid-batch: items already transferred are passed to `on_close`; items not yet transferred stay in the caller's list.
- Restoration order when closed mid-batch may differ from original order.
- Assert:
  - `pool.is_it_you(ph.*.tag)`
  - Each node's tag registered in pool's tag set.

---

