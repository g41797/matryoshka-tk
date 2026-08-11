# Control group

New to the concept? See [Tools — Mailbox](../../tools/mailbox.md) first.

---

## wakeUpAll

```zig
pub fn wakeUpAll(mbh: MailboxHandle) error{Closed}!void
```

- Wakes every receiver currently blocked in `receive()` — no item is sent, nothing is queued.
- Blocked receivers return `error.Wakeup`.
- Future receivers (those that call `receive()` after `wakeUpAll()` returns) are not affected.
- Distinct from `close()`: the mailbox is not torn down, and the effect does not persist for
  receivers that start later.

- Assert:
  - `mailbox.is_it_you(mbh.*.tag)`

---

## close

```zig
pub fn close(mbh: MailboxHandle) polynode.ItemList
```

- Can be called more than once.
- Returns remaining handles as list (empty list on second call).
- Collects all handles still in the queue.
- Wakes up any receivers waiting on the mailbox.
- Assert:
  - `mailbox.is_it_you(mbh.*.tag)`

---

## destroy

```zig
pub fn destroy(mbh: MailboxHandle, alloc: std.mem.Allocator) void
```

- Frees the mailbox.
- Must be closed first.
- Calling destroy on an open mailbox is a programming error (panic).
- Assert:
  - `mailbox.is_it_you(mbh.*.tag)`

---

## is_it_you

```zig
pub fn is_it_you(tag: *const anyopaque) bool
```

- Returns true if tag identifies a MailboxHandle.

---

