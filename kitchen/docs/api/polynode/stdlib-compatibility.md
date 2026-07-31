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
    const ev: *Event = Event.EventPolyHelper.fromPoly(ih) orelse return error.WrongTag;
    // ...
}
```

One step. `popFirst` hands back an `ItemHandle`, not a list node, so  
`@fieldParentPtr` never appears in your code.

## What ItemList adds

`std.DoublyLinkedList` checks nothing. `ItemList` is where it is checked.

```zig
pub fn append(self: *ItemList, ih: ItemHandle) void
pub fn prepend(self: *ItemList, ih: ItemHandle) void
pub fn appendFromSlot(self: *ItemList, slot: *Slot) void
pub fn prependFromSlot(self: *ItemList, slot: *Slot) void
pub fn insertAfter(self: *ItemList, existing: ItemHandle, ih: ItemHandle) void
pub fn insertBefore(self: *ItemList, existing: ItemHandle, ih: ItemHandle) void
pub fn popFirst(self: *ItemList) ?ItemHandle
pub fn popLast(self: *ItemList) ?ItemHandle
pub fn remove(self: *ItemList, ih: ItemHandle) void
pub fn first(self: *const ItemList) ?ItemHandle
pub fn last(self: *const ItemList) ?ItemHandle
pub fn isEmpty(self: *const ItemList) bool
pub fn len(self: *const ItemList) usize
pub fn iterator(self: *const ItemList) Iterator
pub fn concat(self: *ItemList, other: *ItemList) void
pub fn moveFromList(list: *std.DoublyLinkedList) ItemList
pub fn moveToList(self: *ItemList) std.DoublyLinkedList
```

- `popFirst`, `popLast` and `remove` all call `polynode.reset`. The item comes
  back unlinked, ready for a `Slot` or another list.

- `first` and `last` look without taking. A list of one returns the same item
  from both.

- `len` forwards std's walk. O(n) — the mailbox and pool keep their own counters
  for that reason.

## Taking one item out

`remove` takes an item from anywhere in the list — head, middle, or tail:

```zig
list.remove(ih);   // ih comes back unlinked
```

This list must hold the item. Use it instead of reaching through `_list`.

## Inserting from a Slot

`append` takes an `ItemHandle`, so it has no Slot to clear. `appendFromSlot`  
does:

```zig
list.appendFromSlot(&slot);   // slot == null
```

- `prependFromSlot` is the same at the front.
- Both assert the Slot holds an item. An insert is not a `defer` target.
- Use `append`/`prepend` for a stack item, which has no Slot to empty.

Every other transfer in the toolkit empties its source. Now `ItemList` does  
too, so you write no `slot = null` line after an insert.

## The inserts check twice

Under a safety build every insert asserts twice on the item going in: the list  
does not already hold it, and `polynode.is_linked` is false. `insertAfter` and  
`insertBefore` also assert `existing` is in the list.

Neither check is complete, and they are blind to opposite cases:

| check | sees | blind to |
|---|---|---|
| the list walk | this list, including a list of one | any other list |
| `is_linked` | any list | the list holding the item alone |

- O(n) per insert under safety builds. Nothing outside them.
- An item alone in a *different* list still passes both.

`concat` asserts its two arguments are different lists, and returns early if  
they are the same one. The assert is `unreachable` outside safety builds, and  
`std.DoublyLinkedList.concatByMoving` would ring the items and then clear the  
header they are reachable through — the list would come back empty with every  
item in it lost.

`moveFromList` asserts the std header it is handed is consistent: `first` and  
`last` both null, or both set.

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

Use the `ItemList` methods instead. To take one item out, `remove` is the  
method — it calls `polynode.reset` for you. Take an item out through the field  
and it still points at the list it left, and `polynode.reset` becomes yours to  
call.

---

