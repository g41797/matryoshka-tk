# API Reference — Cooperative Cleanup — Pattern 4

---

## Pattern 4 — transfer clears the slot

```zig
var slot: Slot = null;
defer pl.put(&slot);
try pl.get(TAG, .new_only, &slot);
// fill item ...
try mbx.send(&slot);   // send sets slot.* = null
// defer runs: Pool.put sees null → no-op
// result: item is in mailbox, not recycled to pool
```

Transfer and cleanup are not in conflict — transfer pre-empts cleanup by clearing the slot.

---

