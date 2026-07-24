# API Reference — Cooperative Cleanup — Pattern 2

---

## Pattern 2 — defer-destroy-early (heap item via PolyHelper)

```zig
var slot: Slot = null;
defer EventPolyHelper.destroy(allocator, &slot);   // no-op if slot == null
try EventPolyHelper.create(allocator, &slot);
// ... work ...
// on transfer: slot = null → defer runs as no-op
// on no transfer: defer frees item
```

Destroy before create — safe because PolyHelper.destroy is a no-op on null.

---

