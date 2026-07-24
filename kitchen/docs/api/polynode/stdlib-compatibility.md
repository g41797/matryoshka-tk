# Std compatibility

New to the concepts? See [Building Blocks — PolyNode](../../building-blocks/polynode.md) first.

---

PolyNode embeds `std.DoublyLinkedList.Node`.

- No custom list type.
- No adapter.
- Every PolyNode-based item participates in standard `std.DoublyLinkedList` operations.

Batch operations use plain `std.DoublyLinkedList`:

- `mailbox.close()`
- `mailbox.receive_batch()`
- `pool.put_all()`

Walk results with `popFirst()` — standard Zig, nothing Matryoshka-specific.

**Warning**:

- `std.DoublyLinkedList.popFirst()` does NOT clear the node's `prev`/`next` links.
- Call `polynode.reset(poly)` after popping, before re-sending the item or checking `polynode.is_linked`.
- Skipping reset causes false positives from `is_linked` and assert failures in pool/mailbox assert guards.

---

