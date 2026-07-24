# API Reference — Tag Identity and Slot Programming — Slot-based programming

The slot rule governs every acquisition and transfer.

---

## Slot-based programming

The slot rule:

- Never overwrite a non-null slot.
- Always start with `var slot: Slot = null`.
- All acquisition APIs assert `slot.* == null` on entry. Writing to a non-null slot panics.
- Transfer clears the slot: sender sets `slot.* = null`. After transfer, slot is null.
- Applies universally: pool get/put, mailbox receive, heap allocation — every combination.

**Exception — event-source helpers**: `receiveResult` and `getWaitResult` do not take a `*Slot`  
parameter. They move the handle via the returned union value (`ReceiveResult.item`,  
`PoolResult.item`) rather than a slot pointer. The caller extracts the handle from the union  
and holds it from that point. This is an intentional exception to the slot-pointer pattern.

---

## Why acquisition APIs assert null

Every acquisition API has this check:

```zig
std.debug.assert(slot.* == null);
```

Overwriting a non-null slot would lose the previous item with no error signal.  
The assert catches this immediately.

---

## Why cleanup operations accept null

`pool.put` and `PolyHelper.destroy` check null and return early:

```zig
if (slot.* == null) return;
```

This makes defer-before-acquisition safe.

---

## Slot lifecycle

```text
Slot lifecycle

  null ──── acquire ────► non-null
    ▲                        │
    │                        │
    ├──── transfer ──────────┘   (sender clears: slot.* = null)
    │
    └──── cleanup (no-op) ──────  (pool.put, PolyHelper.destroy: null → return)
```

---

## Moving a handle clears the slot

```text
Before transfer                  After transfer

  Slot (sender)                    Slot (sender)
  ┌─────────────┐                  ┌─────────────┐
  │ ItemHandle  │                  │    null     │
  └─────────────┘                  └─────────────┘
                                           │
  mailbox.send(mbh, &slot)                    │ slot.* = null
                                           │
                     Mailbox ◄─────────────┘
                     now holds ItemHandle
```

---

## Defer-before-acquisition is safe

```text
Code order:                      Execution when acquire fails:

  var slot: Slot = null;              slot = null
  defer pool.put(ph, &slot);          acquire fails
  try pool.get(..., &slot);           defer runs: pool.put sees null → no-op
  // work                          ✓ nothing lost

                                 Execution when item is transferred:

                                   slot = null (after acquire: slot is non-null)
                                   mailbox.send(mbh, &slot)  → slot = null
                                   defer runs: pool.put sees null → no-op
                                   ✓ item transferred, not double-recycled
```

---

