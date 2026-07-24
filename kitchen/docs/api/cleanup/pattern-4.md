# API Reference — Cooperative Cleanup — Pattern 4

---

## Pattern 4 — transfer clears the slot

```zig
var slot: Slot = null;
defer pool.put(ph, &slot);
try pool.get(ph, TAG, .new_only, &slot);
// fill item ...
try mailbox.send(mbh, &slot);   // send sets slot.* = null
// defer runs: pool.put sees null → no-op
// result: item is in mailbox, not recycled to pool
```

Transfer and cleanup are not in conflict — transfer pre-empts cleanup by clearing the slot.

---

