# Task 2 — Test Scenarios for Layer 4 and Cross-Layer (002)

Versioned doc. Replaces [task2-tests-001.md](task2-tests-001.md).

Change from -001: banned-word pass. `fires` removed from three scenarios.

Extracted from `task2-scenarios-001.md`. Scenario numbers preserved.

Tests check implementation: correctness, error paths, state transitions, contract violations.  
All tests use real `Io.Threaded.init(gpa, .{})` — concurrency, cancellation, real I/O.

---

## Layer 4 — Worker Lifecycle

1. **Single worker spawn and join** — Master spawns worker via `io.concurrent()`, worker receives one item, exits. Master awaits Future. `[io.concurrent, Future.await]`
2. **Worker group spawn and join** — Master spawns 3 workers via `Io.Group.concurrent()`, all process items, Master calls `group.await()`. `[Io.Group, group.concurrent, group.await]`

---

## Layer 4 — Shutdown Ordering

6. **Broadcast shutdown: mailbox.close before join** — Master closes mailbox (broadcasts), worker wakes with `error.Closed`, exits. Master joins, then closes pool, walks remaining items. `[mailbox.close broadcast, error.Closed, lockUncancelable]`
7. **Cancel shutdown: future.cancel before close** — Master calls `future.cancel(io)`, worker exits. Then Master calls `pool.close` and `mailbox.close` to reclaim items. No race — worker already exited. `[Future.cancel, pool.close, mailbox.close after join]`
8. **pool.put on closed pool** — Worker holds item when `pool.close` runs. `pool.put` returns item to caller (Slot stays non-null). Worker disposes item via on_close hook. `[pool.put cancel-protected, closed pool rejection]`
9. **mailbox.close returns remaining items** — Send 10 items, close after 3 consumed. Walk returned `std.DoublyLinkedList` via `popFirst()`, verify 7 items recovered. `[mailbox.close snapshot, batch cleanup]`
10. **pool.close calls on_close with all items** — Put 5 items, `pool.close`. on_close receives `*std.DoublyLinkedList` with 5 items. Hook walks via `popFirst()` and frees. `[pool.close, on_close hook]`

---

## Layer 4 — Cancellation Mechanics

3. **Future.cancel stops blocked worker** — Worker blocked in `mailbox.receive`, Master calls `future.cancel(io)`. Worker receives `error.Canceled`, exits. Future.cancel returns after worker exits. `[Future.cancel, error.Canceled propagation through mailbox.receive]`
4. **Group.cancel stops all workers** — 3 workers blocked in `mailbox.receive`, Master calls `group.cancel(io)`. All workers exit. `[Io.Group, group.cancel, error.Canceled broadcast]`
5. **Worker not blocked when cancel arrives** — Worker is between `mailbox.receive` and `pool.put`. Cancel takes effect at next Io wait (`pool.put` is cancel-protected, so at next `mailbox.receive`). `[error.Canceled deferred to next cancellation point]`
11. **error.Canceled distinct from error.Closed in mailbox.receive** — Cancel worker task while mailbox is open. Worker sees `error.Canceled`, not `error.Closed`. Then close mailbox separately. `[error.Canceled vs error.Closed distinction]`
12. **error.Canceled distinct from error.Closed in pool.get_wait** — Same test for pool. Cancel task while pool is open. `[error.Canceled vs error.Closed in pool]`
13. **pool.put is cancel-protected** — Worker receives `error.Canceled` from `mailbox.receive`, then calls `pool.put` to return item. `pool.put` must succeed (uses `lockUncancelable`). Item not lost. `[pool.put lockUncancelable, cleanup after cancel]`
14. **mailbox.close uses lockUncancelable** — Close mailbox from a canceled task. Close must complete — `std.DoublyLinkedList` returned, broadcast sent. `[mailbox.close lockUncancelable]`
15. **recancel propagation** — Worker catches `error.Canceled`, does cleanup, calls `io.recancel()`, next Io call returns `error.Canceled` again. `[recancel]`
16. **checkCancel in CPU-bound work** — Worker does long computation between `mailbox.receive` calls. Calls `io.checkCancel()` periodically. Cancel takes effect at checkCancel. `[checkCancel]`

---

## Notes

- Scenarios 3-5 are listed under Cancellation Mechanics in the source but numbered in the Shutdown section. Numbers preserved from `task2-scenarios-001.md`.
- All 16 scenarios are done: Stage 5.a (1-2), Stage 6 (3-16). 121/121 tests passing.
- Remaining task2 scenarios (17-61) are all examples — see `task2-examples-001.md`.
