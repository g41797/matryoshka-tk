# Std compatibility

New to the concepts? See [Building Blocks — PolyNode](../../building-blocks/polynode.md) first.

---

PolyNode embeds `std.DoublyLinkedList.Node`.

- No custom node type.
- No adapter.
- The intrusive links are the standard ones.

## Batch operations speak `ItemList`

`ItemList` is the toolkit's list type. It holds the same std list inside and  
speaks `ItemHandle` on the outside.

- `mailbox.close()`
- `mailbox.receive_batch()`
- `pool.put_all()`
- `PoolHooks.on_put`, `PoolHooks.on_close`

Walk results with `popFirst()`:

```zig
var batch: polynode.ItemList = try mailbox.receive_batch(mbh);
while (batch.popFirst()) |ih| {
    const ev: *Event = Event.EventPolyHelper.fromNode(ih) orelse return error.WrongTag;
    // ...
}
```

One step. `popFirst` hands back an `ItemHandle`, not a list node, so  
`@fieldParentPtr` never appears in your code.

## Inserting from a Slot

`append` takes an `ItemHandle`, so it has no Slot to clear. `appendFromSlot`  
does:

```zig
list.appendFromSlot(&slot);   // slot == null
```

- `prependFromSlot` is the same at the front.
- Both assert the Slot holds an item. An insert is not a `defer` target.
- Use `append`/`prepend` for a stack item, which has no Slot to empty.

Every transfer in the toolkit empties its source. These two make `ItemList`  
the same, so the `slot = null` line is no longer yours to remember.

## The inserts check the list

Under a safety build, `append`, `prepend` and `insertAfter` walk the list  
first and assert the item is not already in it. `insertAfter` also asserts  
`existing` is.

- O(n) per insert under safety builds. Nothing outside them.
- The walk asks the container, not the item, so it sees the list of one that
  `polynode.is_linked` cannot.

- It says nothing about an item held by a *different* list.

`concat` asserts its two arguments are different lists — self-concat would  
empty the list and leak every item in it.

## popFirst clears the links

`std.DoublyLinkedList.popFirst()` leaves `prev`/`next` pointing at the old  
neighbours. `ItemList.popFirst()` calls `polynode.reset` before it returns.

- A popped `ItemHandle` is never linked.
- `polynode.is_linked` on it is false.
- It goes straight into a `Slot`, or into `mailbox.send`, with no extra step.

`polynode.reset` is still public. You need it only when you take items out  
through `ItemList._list` — see below.

## Crossing to a plain std list

Both directions are a move, never a copy. Copying a list header aliases it, and  
the first `popFirst` on either header corrupts the other.

```zig
var list = polynode.ItemList.moveFromList(&raw);  // raw is left empty
var raw_again = list.moveToList();                // list is left empty
```

Both are O(1) — a header value copy, no walk.

## The `_list` field

`ItemList._list` is the plain std list this `ItemList` holds. Tests that  
manipulate raw links use it — the layout is what those tests check.

Use the `ItemList` methods instead. Take an item out through the field, and it  
still points at the list it left: `popFirst` did not run, so `polynode.reset`  
did not either. Call it yourself.

---

