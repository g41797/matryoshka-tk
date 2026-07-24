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
| `mailbox.send` | no | non-blocking |
| `mailbox.send_oob` | no | non-blocking |
| `mailbox.receive` | **yes** | waits for a handle |
| `mailbox.try_receive` | no | non-blocking |
| `mailbox.receive_batch` | no | non-blocking |
| `mailbox.close` | no | non-blocking |
| `pool.get` | no | non-blocking |
| `pool.get_wait` | **yes** | waits for a handle |
| `pool.put` | no | non-blocking |
| `pool.put_all` | no | non-blocking |
| `pool.close` | no | non-blocking |
| `mailbox.receiveResult` | **yes** | blocking; cancelable via task cancel |
| `mailbox.receive_future` | **yes** | thin wrapper around `io.concurrent(receiveResult, ...)` |
| `pool.getWaitResult` | **yes** | blocking; cancelable via task cancel |
| `pool.get_wait_future` | **yes** | thin wrapper around `io.concurrent(getWaitResult, ...)` |

## What cancellation leaves behind

When a cancellable operation returns `error.Canceled`:

- `mailbox.receive`: slot is unchanged — `slot.*` was `null` on entry and remains `null`. The mailbox retains any queued items.
- `pool.get_wait`: slot is unchanged — `slot.*` was `null` on entry and remains `null`. The pool retains all free-list items.

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
| `mailbox.send` | IN_FLIGHT → HELD |
| `mailbox.receive` | HELD → IN_FLIGHT |
| `pool.get` | HELD → IN_FLIGHT |
| `pool.put` (keep) | IN_FLIGHT → HELD |
| `pool.put` (destroy) | IN_FLIGHT → FREE |
| `mailbox.close` | HELD → returned to caller |
| `pool.close` | HELD → passed to on_close |

---

