# Hooks discipline

New to the concept? See [Building Blocks — Pool](../../building-blocks/pool.md) first.

---

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
  - Return value: `?std.DoublyLinkedList` of extra items. `null`/empty =
    nothing extra. Non-empty = each item added like `slot`'s. See
    [Composite Items](put.md#composite-items).

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

