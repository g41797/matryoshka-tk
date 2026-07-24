# API Reference — Invariants and Contracts

---


## Invariants

These hold at all times, for every node in the system:

- A linked node belongs to exactly one container (mailbox queue or pool free-list). Never two at once.
- A Slot holds exactly one node. A null Slot holds nothing.
- A pool never holds a linked node — items in its free-lists are unlinked relative to other pools.
- A mailbox never holds a free node — only nodes currently in its queue.
- Every node is in exactly one place at all times: either with user code (via Slot) or with infrastructure (in queue or free-list). Never both.
- Tag identity is determined by pointer address alone. Never compare tag contents or names — compare only `==` on the pointer value.

## Thread-safety contract

| Function | Concurrent callers | Notes |
|----------|--------------------|-------|
| `mailbox.send` | yes | Multiple senders safe |
| `mailbox.send_oob` | yes | Multiple senders safe |
| `mailbox.receive` | yes | One handle per waiter; scheduling order is runtime-dependent |
| `mailbox.try_receive` | yes | |
| `mailbox.receive_batch` | yes | Transfers whole queue atomically |
| `mailbox.close` | yes — once | Second call returns empty list |
| `mailbox.destroy` | no | Must happen after all users have stopped |
| `pool.get` | yes | |
| `pool.get_wait` | yes | One handle per waiter; scheduling order is runtime-dependent |
| `pool.put` | yes | |
| `pool.put_all` | yes | Thread-safe per item; batch is NOT atomic wrt close() — items transferred before close go to on_close; items not yet transferred stay in caller's list |
| `pool.close` | yes — once | Second call is a no-op |
| `pool.destroy` | no | Must happen after all users have stopped |

## Complexity guarantees

| Function | Time complexity |
|----------|----------------|
| `mailbox.send` | O(1) |
| `mailbox.send_oob` | O(1) |
| `mailbox.receive` | O(1) |
| `mailbox.try_receive` | O(1) |
| `mailbox.receive_batch` | O(1) — transfers whole queue atomically |
| `mailbox.close` | O(n) — walks the queue |
| `pool.get` | O(1) |
| `pool.get_wait` | O(1) |
| `pool.put` | O(1) |
| `pool.put_all` | O(k) — k is the number of items in the list |
| `pool.close` | O(n) — walks all per-tag free-lists |

## Contract violations

Programming errors.  
Checked via `std.debug.assert`:

- Active in Debug and ReleaseSafe.
- Removed in ReleaseFast and ReleaseSmall.

- **Wrong handle type** — passing a PoolHandle where MailboxHandle is expected, or vice versa.
  - Checked via `is_it_you` on every API call.
- **Non-empty slot on receive/get** — slot must be null before receiving or getting a handle.
- **Linked node on send/put** — node must not be linked into a list before transfer.
- **Foreign tag** — pool operation with a tag not registered in the pool's tag set.
- **Uninitialized pool** — calling get/get_wait before init.
- **Double insertion** — pushing a linked node into a list.
- **Corrupted or invalid tag** — tag does not match any known type.

The following are unconditional panics (all build modes):

- **Destroying an open mailbox or pool** — must close first.
- **Use after free** — using a node after its memory was freed.

## Layer dependencies

```
             Layer 4
             Master
                |
      +---------+---------+
      |                   |
   Layer 2            Layer 3
   Mailbox              Pool
      |                   |
      +---------+---------+
                |
            Layer 1
          Type identity
```

Dependencies:

- Mailbox and Pool are independent — neither depends on the other.
- Both depend only on the one-place-one-state model.
- Master is where they are combined.

Valid combinations:

- Layer 1 only — type identity without infrastructure
- Layer 1 + Layer 2 — type identity + message passing, no lifecycle
- Layer 1 + Layer 3 — type identity + item lifecycle, no message passing
- Layer 1 + Layer 2 + Layer 3 + Io — full stack (Master)

---

