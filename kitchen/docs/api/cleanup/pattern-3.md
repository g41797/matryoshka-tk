# API Reference — Cooperative Cleanup — Pattern 3

---

## Pattern 3 — defer for received mailbox item

```zig
var slot: Slot = null;
defer if (slot) |poly| helpers.freeItem(poly, allocator);
try mbx.receive(&slot, null);
// dispatch on slot.?.*.tag, process item
// item stays non-null until explicitly transferred or freed
```

Cleanup covers both the error path (receive failed) and the normal path (item processed and freed).

---

