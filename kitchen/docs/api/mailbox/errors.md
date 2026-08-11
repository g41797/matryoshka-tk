# Error sets

New to the concept? See [Tools — Mailbox](../../tools/mailbox.md) first.

---

| Error | Meaning |
|-------|---------|
| `error.Closed` | Mailbox was closed via `close()` |
| `error.Timeout` | `timeout_ns` expired (only when non-null) |
| `error.Canceled` | Waiting operation was canceled |
| `error.Wakeup` | `wakeUpAll()` woke this receiver — no item, mailbox stays open |

---

