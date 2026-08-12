# Get group

New to the concept? See [Tools — Pool](../../tools/pool.md) first.

---

## get

```zig
pub fn get(self: *Pool, tag: *const anyopaque, mode: Pool.GetMode, slot: *Slot) Pool.GetError!void
```

- Non-blocking acquisition.
- Calls `on_get` hook.
- Moves the handle — `slot.*` set to non-null on success.
- Assert:
  - `slot.* == null`
  - Pool initialized.
  - Tag registered.

---

## get_wait

```zig
pub fn get_wait(self: *Pool, tag: *const anyopaque, slot: *Slot, timeout_ns: ?u64) (Pool.GetError || Cancelable || error{Timeout})!void
```

- Blocking acquisition.
- `null` timeout = wait forever.
- `timeout_ns = 0` returns `error.Timeout` immediately.
- Logically equivalent to `get(.available_only)`, but a different error (`error.Timeout` vs `error.NotAvailable`).
- Intentional: `get_wait` always uses the timeout error set, regardless of the timeout value.
- Calls `on_get` hook.
- Assert:
  - `slot.* == null`
  - Pool initialized.
  - Tag registered.

---

