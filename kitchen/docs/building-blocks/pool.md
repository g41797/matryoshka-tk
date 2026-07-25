# Building Blocks — Pool

---

Everything reusable lives here.

A Pool hands out items for reuse, instead of allocating fresh ones in a hot loop.

## What a Pool does

A Pool hands out items for reuse instead of a fresh allocation every time.

```text
new()
  ↓
empty pool

get() [pool empty]                get() [pool has items]
  ↓ a fresh item is created          ↓ an item is reused
with caller                        with caller

put() [kept]                       put() [destroyed]
  ↓                                  ↓
back in the pool                   caller frees it

close()
  ↓ every stored item is handed back for the caller to free
```

- `get` hands a handle to the caller — reused if one is free, freshly made otherwise.
- `put` returns the handle — the Pool decides whether to keep it or let it go.
- `close` hands back everything still stored, so nothing leaks.

## A Pool resource is an empty container

A Pool is not storage.

- Getting an item back tells you nothing about what it holds — that's up to your hooks.
- `put` can keep the item as-is.
- `put` can keep it after resetting its data.
- `put` can delete it.
- `put` can delete it and hand back a different item instead.
- Nothing you `put` in is guaranteed to still be there on the next `get`.
- No fixed count/order/identity survives a put/get sequence unless your hooks guarantee it.
- See [API Reference — Pool](../api/pool/put.md) for the four `put` outcomes.

- A Pool resource alone never defines a complete pattern.
- Useful work always needs at least one other input too: a Mailbox message, a
  network read, a timer tick, some shared state.

## An empty Pool is a signal, not an error

- When nothing is free, the caller waits — that's backpressure, not a failure.
- No separate rate limiter, no manual throttling code.
- One event loop watches "a Mailbox message arrived" and "a Pool item became free"
  side by side. A worker returns an item — whoever was waiting resumes.

A worker pool, end to end, in [Matryoshka-Tk notation](../addendums/matryoshka-tk-notation.md):

```
[ Worker ]  >>> get() >>>  { Job Processor }

                                  | uses the Worker

[ Worker ]  <<< put() <<<  { Job Processor }
```

If `[ Worker ]` is empty when `get()` is called, `{ Job Processor }` waits.

That wait ends the moment some other `{ Job Processor }` calls `put()`.

---

See also: [API Reference — Pool](../api/pool/index.md) for the actual Zig functions.
