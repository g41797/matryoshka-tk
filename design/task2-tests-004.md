# Task 2 — Test Scenarios for Layer 4 and Cross-Layer (004)


Change from -003: INTR 8 — scenario 8 changed meaning. Owner's ruling,  
2026-08-14. A pool closed before its hooks were registered is no longer a  
state that can be built, because the hooks go in at `new`. The scenario keeps  
the closed-pool `put` check and drops the ordering claim.

Change from -002: API 12 — mailbox and pool operations read as methods on the  
receiver (`mbx.receive`, `pl.put`). Numbers and meanings unchanged.

Change from -001: banned-word pass. `fires` removed from three scenarios.

Extracted from the original task2 scenario list. Scenario numbers preserved.

Tests check implementation: correctness, error paths, state transitions, contract violations.  
All tests use real `Io.Threaded.init(gpa, .{})` — concurrency, cancellation, real I/O.

---

## Layer 4 — Worker Lifecycle

1. **Single worker spawn and join** — Master spawns worker via `io.concurrent()`, worker receives one item, exits. Master awaits Future. `[io.concurrent, Future.await]`
2. **Worker group spawn and join** — Master spawns 3 workers via `Io.Group.concurrent()`, all process items, Master calls `group.await()`. `[Io.Group, group.concurrent, group.await]`

---

## Layer 4 — Shutdown Ordering

6. **Broadcast shutdown: mbx.close before join** — Master closes mailbox (broadcasts), worker wakes with `error.Closed`, exits. Master joins, then closes pool, walks remaining items. `[mbx.close broadcast, error.Closed, lockUncancelable]`
7. **Cancel shutdown: future.cancel before close** — Master calls `future.cancel(io)`, worker exits. Then Master calls `pl.close` and `mbx.close` to reclaim items. No race — worker already exited. `[Future.cancel, pl.close, mbx.close after join]`
8. **pl.put on closed pool** — Pool is closed before the worker runs. Worker receives an item and calls `pl.put`; the closed pool refuses it and the Slot stays non-null, so the item is still the worker's. Worker releases it. `[pl.put cancel-protected, closed pool rejection]`
9. **mbx.close returns remaining items** — Send 10 items, close after 3 consumed. Walk returned `std.DoublyLinkedList` via `popFirst()`, verify 7 items recovered. `[mbx.close snapshot, batch cleanup]`
10. **pl.close calls on_close with all items** — Put 5 items, `pl.close`. on_close receives `*std.DoublyLinkedList` with 5 items. Hook walks via `popFirst()` and frees. `[pl.close, on_close hook]`

---

## Layer 4 — Cancellation Mechanics

3. **Future.cancel stops blocked worker** — Worker blocked in `mbx.receive`, Master calls `future.cancel(io)`. Worker receives `error.Canceled`, exits. Future.cancel returns after worker exits. `[Future.cancel, error.Canceled propagation through mbx.receive]`
4. **Group.cancel stops all workers** — 3 workers blocked in `mbx.receive`, Master calls `group.cancel(io)`. All workers exit. `[Io.Group, group.cancel, error.Canceled broadcast]`
5. **Worker not blocked when cancel arrives** — Worker is between `mbx.receive` and `pl.put`. Cancel takes effect at next Io wait (`pl.put` is cancel-protected, so at next `mbx.receive`). `[error.Canceled deferred to next cancellation point]`
11. **error.Canceled distinct from error.Closed in mbx.receive** — Cancel worker task while mailbox is open. Worker sees `error.Canceled`, not `error.Closed`. Then close mailbox separately. `[error.Canceled vs error.Closed distinction]`
12. **error.Canceled distinct from error.Closed in pl.get_wait** — Same test for pool. Cancel task while pool is open. `[error.Canceled vs error.Closed in pool]`
13. **pl.put is cancel-protected** — Worker receives `error.Canceled` from `mbx.receive`, then calls `pl.put` to return item. `pl.put` must succeed (uses `lockUncancelable`). Item not lost. `[pl.put lockUncancelable, cleanup after cancel]`
14. **mbx.close uses lockUncancelable** — Close mailbox from a canceled task. Close must complete — `std.DoublyLinkedList` returned, broadcast sent. `[mbx.close lockUncancelable]`
15. **recancel propagation** — Worker catches `error.Canceled`, does cleanup, calls `io.recancel()`, next Io call returns `error.Canceled` again. `[recancel]`
16. **checkCancel in CPU-bound work** — Worker does long computation between `mbx.receive` calls. Calls `io.checkCancel()` periodically. Cancel takes effect at checkCancel. `[checkCancel]`

---

## Notes

- Scenarios 3-5 are listed under Cancellation Mechanics in the source but numbered in the Shutdown section. Numbers preserved from the original scenario list.
- All 16 scenarios are done: Stage 5.a (1-2), Stage 6 (3-16). 121/121 tests passing.
- Remaining task2 scenarios (17-61) are all examples — see `task2-examples-007.md`.
