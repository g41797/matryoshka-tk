# API Reference — Cooperative Cleanup

---

These patterns follow from the slot rule.  
Place cleanup before acquisition.  
The defer becomes a no-op when the slot is null — either because acquisition failed, or because the item was transferred.

---

## Pattern 1 — defer-put-early (pool item)

```zig
var slot: Slot = null;
defer pool.put(ph, &slot);              // no-op if slot == null
try pool.get(ph, TAG, .new_only, &slot);
// ... work ...
// on transfer: slot = null → defer runs as no-op
// on no transfer: defer recycles item
```

Put before get — safe because pool.put is a no-op on null.

If the pool may be closed while the item is held, pool.put leaves slot non-null (caller retains  
held). Add a fallback destroy to avoid a leak:

```zig
var slot: Slot = null;
defer EventPolyHelper.destroy(alloc, &slot); // fallback: frees if pool.put left slot non-null
defer pool.put(ph, &slot);                   // primary: recycles to pool (clears slot on success)
// defers run LIFO: pool.put first, then destroy (no-op if pool.put cleared slot)
```

---

