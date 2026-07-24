# Troika - PolyNode, ItemHandle, Slot

New to the concepts? See [Building Blocks — PolyNode](../../building-blocks/polynode.md)  
first.

This page covers the actual Zig types and functions.

```zig
const polynode = @import("matryoshka").polynode;

// typical usage:
var slot: polynode.Slot = &event.poly;   // slot holds the node
slot = null;                              // slot is empty
```

---

## Types

```zig
pub const PolyTag = struct { _: u8 = 0 };

pub const PolyNode = struct {
    node: std.DoublyLinkedList.Node,
    tag:  *const anyopaque,
};

pub const ItemHandle = *PolyNode;
pub const Slot = ?ItemHandle;
```

- `PolyNode` is the type every Item embeds. Its `tag` is a unique
  address that identifies which type a node lives inside (see Step 2).

- `ItemHandle` is a pointer to that embedded field — the only thing Matryoshka moves.
- `Slot` is where a handle lives while it is yours.

---

