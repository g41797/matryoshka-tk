# API Reference — Cancel Model and Item Lifecycle

## Cancel model

Only functions that wait on a condition can be canceled.  
Everything else runs to completion.

- A waiting function blocks until a handle becomes available or a timeout expires.
- While waiting, the runtime can cancel the operation. The function returns `error.Canceled`.
- All other functions do their work and return. They cannot be canceled.

A function is cancelable if and only if its return type includes `Cancelable` in the error union.  
The signature is the single source of truth.

## Cancel contract summary

| Function | Cancelable | Notes |
|----------|-----------|-------|
| `Mbox.send` | no | non-blocking |
| `Mbox.send_oob` | no | non-blocking |
| `Mbox.receive` | **yes** | waits for a handle |
| `Mbox.try_receive` | no | non-blocking |
| `Mbox.receive_batch` | no | non-blocking |
| `Mbox.close` | no | non-blocking |
| `Pool.get` | no | non-blocking |
| `Pool.get_wait` | **yes** | waits for a handle |
| `Pool.put` | no | non-blocking |
| `Pool.put_all` | no | non-blocking |
| `Pool.close` | no | non-blocking |
| `mailbox.receiveResult` | **yes** | blocking; cancelable via task cancel |
| `Mbox.receive_future` | **yes** | thin wrapper around `io.concurrent(receiveResult, ...)` |
| `pool.getWaitResult` | **yes** | blocking; cancelable via task cancel |
| `Pool.get_wait_future` | **yes** | thin wrapper around `io.concurrent(getWaitResult, ...)` |

## What cancellation leaves behind

When a cancellable operation returns `error.Canceled`:

- `Mbox.receive`: slot is unchanged — `slot.*` was `null` on entry and remains `null`. The mailbox retains any queued items.
- `Pool.get_wait`: slot is unchanged — `slot.*` was `null` on entry and remains `null`. The pool retains all free-list items.

Cancellation never closes the mailbox or pool. Closing is the caller's responsibility.

---

## Item lifecycle

```
FREE       — allocated, not in any system
IN_FLIGHT  — with user code (Slot non-null)
HELD       — with infrastructure (in mailbox queue or pool free-list)
```

| Operation | Before → After |
|-----------|---------------|
| `Mbox.send` | IN_FLIGHT → HELD |
| `Mbox.receive` | HELD → IN_FLIGHT |
| `Pool.get` | HELD → IN_FLIGHT |
| `Pool.put` (keep) | IN_FLIGHT → HELD |
| `Pool.put` (destroy) | IN_FLIGHT → FREE |
| `Mbox.close` | HELD → returned to caller |
| `Pool.close` | HELD → passed to on_close |

---

