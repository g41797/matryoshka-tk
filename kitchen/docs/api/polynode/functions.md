# Control group

New to the concepts? See [Building Blocks — PolyNode](../../building-blocks/polynode.md) first.

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

- Returns true if node is currently linked into a list.

---

## One place, one state — read-only ops

These operations never move a handle:

- tag checks
- typed casts
- `@fieldParentPtr` recovery

Read-only inspections of an existing node.

---
