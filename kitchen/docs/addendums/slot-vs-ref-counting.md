# Slot vs Reference Counting

---

## Two different questions

A Slot answers one question:

> Who holds this item right now?

Reference counting answers a different question:

> How many holders exist?

```text
Slot                              Reference count

  +------+                          refcount = 3
  | ITEM | ◄── exactly one holder
  +------+                           Owner A ─┐
                                     Owner B ─┼─► ITEM
                                     Owner C ─┘
```

Different questions, different guarantees.

## What a Slot guarantees

```zig
const Item = *PolyNode;
const Slot = ?Item;
```

- A Slot either holds an item or it's empty.
- A handle moves from one Slot to another — never copied, never shared.
- After the move: the source Slot is empty, the destination Slot holds it.
- Exactly one holder exists, always.

```text
Slot A          Slot B

+------+        +------+
| ITEM | ─────► |      |
+------+        +------+

after the move:

+------+        +------+
|      |        | ITEM |
+------+        +------+
```

## What reference counting guarantees

- Multiple holders can exist at the same time.
- The item is freed only when the count reaches zero.
- The count tells you *how many* — never *who*, *why*, or *for how long*.

```text
refcount = 3

  Thread A ?
  Thread B ?
  Mailbox  ?
  Pool     ?
  Forgotten global ?
  Reference cycle  ?
```

A count of 3 is consistent with any of those. The number alone answers nothing about  
who is actually responsible.

## Why Matryoshka uses Slots

Matryoshka is built around one thing: an item moving from place to place.

```text
Producer → Mailbox → Worker → Pool
```

Every step is a move, never a share.

- No count field on the item.
- No atomic increment or decrement.
- No cycles — a cycle needs two holders pointing at each other; a Slot only ever holds one.
- The current holder is always visible by inspecting one Slot, not by auditing the
  whole system.

## Pool and Mailbox never need to count

Pool does not ask "is anyone still using this?" — it already knows:

- Handle inside the Pool's free list → the Pool holds it.
- Handle returned by `Pool.get` → the caller holds it.

Mailbox does not ask "how many threads reference this?" — it already knows:

- `send` moves a handle into the Mailbox.
- `receive` moves a handle out.
- Exactly one holder at every moment.

## A useful way to remember it

```text
Reference counting answers:

    "Can I free it?"

Slot answers:

    "Do I have it?"
```
