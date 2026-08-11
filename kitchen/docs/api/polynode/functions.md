# Control group

New to the concepts? See [Tools — PolyNode](../../tools/polynode.md) first.

---

## reset

```zig
pub fn reset(n: *PolyNode) void
```

- Clears intrusive link pointers (`prev`, `next` to null). Intrusive means the
  list pointers live inside your struct, not in a separate list node.

---

## is_linked

```zig
pub fn is_linked(n: *PolyNode) bool
```

- Returns true if the node has neighbours — `prev` or `next` is set.
- Not a membership test. `std.DoublyLinkedList` never sets the links of a
  list's only member, so a list of exactly one reports false.

- The `!is_linked` asserts inside `mailbox.send`, `pool.put`,
  `PolyHelper.destroy` and `PolyHelper.moveFromSlot` catch the multi-element  
  case and are blind for a list of one.

- To find out whether a list holds an item, ask the list. The insert asserts
  do — see [Std compatibility](stdlib-compatibility.md).

---

## One place, one state — read-only ops

These operations never move a handle:

- tag checks
- typed casts
- `@fieldParentPtr` recovery

Read-only inspections of an existing node.

---
