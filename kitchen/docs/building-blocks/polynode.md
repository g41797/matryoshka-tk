# Item/ItemHandle/PolyNode

---

Everything is marked.

---

## Who holds it?

Every Matryoshka design starts with one question: **who holds this item right now?**

Not what data it holds. Not which thread touches it. Just who holds it.

The answer must be visible at the call site. If you need to read the implementation to  
know who holds an item, the design is wrong.

```text
Slot (holds a handle)            Empty Slot

+-------------------+            +-------------------+
|                   |            |                   |
|      Handle       |            |       empty       |
|                   |            |                   |
+-------------------+            +-------------------+
```

## PolyNode — the marker inside every Item

`PolyNode` is a small marker every exchangeable Item carries.

- Every user type embeds one `PolyNode`.
- Matryoshka never sees the user type — only the `PolyNode` inside it.
- The `PolyNode` is what lets Matryoshka move the Item, without knowing what it is.

```text
User Item                        Infrastructure sees
+------------------+
|      Event       |             a handle to the
|------------------|      →      embedded PolyNode
| PolyNode         |             — nothing else
| code: i32        |
+------------------+
```

## Handle — a pointer to the marker

A handle is what Matryoshka actually moves: a pointer to the embedded `PolyNode`, never  
the Item itself.

- One handle, one Item.
- Specialized names exist for handles to specific infrastructure items — a mailbox
  handle, a pool handle — but they are all the same kind of pointer.

## Slot — where a handle lives while it's yours

A Slot is a place that either holds a handle or is empty.

- An item has exactly one holder at any moment.
- Holders: user code (in flight), a mailbox (held), a pool (held).
- When the item moves, the slot becomes empty — that's the proof the move
  happened, not just bookkeeping.

## Why this matters

Given a handle, you can identify the Item it came from and cast back to it:

- without interfaces
- without virtual dispatch
- with one runtime check (a tag comparison), not a chain of them

---

See also: [API Reference — PolyNode, ItemHandle, Slot](../api/polynode/index.md) for the actual  
Zig types and functions.
