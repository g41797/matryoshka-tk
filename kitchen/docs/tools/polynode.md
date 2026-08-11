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

## ItemList — where many handles live at once

An ItemList is a place that holds any number of handles, in order.

- One handle, one Item. One Slot, one place for one Item. One ItemList, many.
- The three together cover every shape the toolkit passes around. Nothing else
  is needed to describe an API that carries items.

- Anything moving more than one item at a time speaks ItemList — receiving a
  whole queue, returning a batch to a pool, handing back what a pool held when  
  it closes.

- Taking an item out of a list gives you a handle, the same kind you already
  hold anywhere else. The list's own links are cleared as it leaves.

- The list is a container, not a holder. The items in it belong to whoever
  holds the list.

## Why this matters

Given a handle, you can identify the Item it came from and cast back to it:

- without interfaces
- without virtual dispatch
- with one runtime check (a tag comparison), not a chain of them

---

See also: [API Reference — PolyNode, ItemHandle, Slot](../api/polynode/index.md) for the actual  
Zig types and functions.
