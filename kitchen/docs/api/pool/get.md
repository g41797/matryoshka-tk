# Get group

New to the concept? See [Tools — Pool](../../tools/pool.md) first.

---

## get

```zig
pub fn get(ph: PoolHandle, tag: *const anyopaque, mode: GetMode, slot: *Slot) GetError!void
```

- Non-blocking acquisition.
- Calls `on_get` hook.
- Moves the handle — `slot.*` set to non-null on success.
- Assert:
  - `pool.is_it_you(ph.*.tag)`
  - `slot.* == null`
  - Pool initialized.
  - Tag registered.

---

## get_wait

```zig
pub fn get_wait(ph: PoolHandle, tag: *const anyopaque, slot: *Slot, timeout_ns: ?u64) (GetError || Cancelable || error{Timeout})!void
```

- Blocking acquisition.
- `null` timeout = wait forever.
- `timeout_ns = 0` returns `error.Timeout` immediately.
- Logically equivalent to `get(.available_only)`, but a different error (`error.Timeout` vs `error.NotAvailable`).
- Intentional: `get_wait` always uses the timeout error set, regardless of the timeout value.
- Calls `on_get` hook.
- Assert:
  - `pool.is_it_you(ph.*.tag)`
  - `slot.* == null`
  - Pool initialized.
  - Tag registered.

---

