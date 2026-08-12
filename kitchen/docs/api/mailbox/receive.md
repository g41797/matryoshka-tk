# Receive group

New to the concept? See [Tools — Mailbox](../../tools/mailbox.md) first.

---

## receive

```text
Before                           After

receiver Slot                    receiver Slot
+-------------------+            +-------------------+
|       null        |            |    ItemHandle     |
+-------------------+            +-------------------+

mbx.receive(&slot, null)   Receiver holds ItemHandle
```

```zig
pub fn receive(self: *Mbox, slot: *Slot, timeout_ns: ?u64) (error{ Closed, Timeout, Wakeup } || Cancelable)!void
```

- Blocks until handle available.
- `null` timeout = wait forever.
- `timeout_ns = 0` returns `error.Timeout` immediately — equivalent to `try_receive`.
- Moves the handle — `slot.*` set to non-null.
- OOB handles arrive first (front of queue).
- `wakeUpAll()` called while blocked here — returns `error.Wakeup`, `slot.*` stays null.
- Multiple concurrent receivers compete for each handle.
- One receiver gets it.
- Order among waiters depends on the Io runtime — not guaranteed FIFO.
- Assert:
  - `slot.* == null`

---

## try_receive

```zig
pub fn try_receive(self: *Mbox, slot: *Slot) error{Closed}!bool
```

- Non-blocking.
- Returns true if handle received, false if queue empty.
- Assert:
  - `slot.* == null`

---

## receive_batch

```zig
pub fn receive_batch(self: *Mbox) error{Closed}!polynode.ItemList
```

- Non-blocking.
- Takes everything from the queue at once.
- Returns an empty `ItemList` if queue is currently empty.
- Does not wait. Does not return error for empty.

**The caller holds every item in that list** — same duty as after `close()`.  
Free them, or put them back into a pool.

---

