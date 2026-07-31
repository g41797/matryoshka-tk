# Task 1 — Test Scenarios for Layers 1–3 (004)

Versioned doc. Replaces [task1-tests-003.md](task1-tests-003.md).

Change from -003: API 10. Scenarios 104 and 105 registered — they shipped with  
API 9 and this list stopped at 103. Scenario 103 retitled for the  
`iterate` → `iterator` rename and given the self-`concat` case. Scenarios  
106–110 added for `remove`, `popLast`, `first`/`last`, `insertBefore` and the  
`moveFromList` header check.

Change from -002: banned-word pass. `ownership` and `idempotent` removed from  
section titles and scenario text. Scenarios 34, 43, 44, 75, 77, 85, 86, 87 are  
reworded to match the renamed tests in `tests/`. Numbers and meanings unchanged.

Change from task1-tests-001: API 8 — scenarios 100–103 added for `ItemList`. Scenario 10 marked as deliberately raw. Cross-layer note on batch returns updated.

Extracted from `task1-scenarios-001.md`. Scenario numbers preserved.

Tests check implementation: correctness, edge cases, error paths, state transitions, contract violations.

Master, Cancel, Futures, Io.Group, and subsystem coordination  
are intentionally excluded. Layers 1–3 must be fully testable without them.

---

## Layer 1 — Holding and transfer (PolyNode + Slot + Tags)

1. **Tag uniqueness** — two different types produce different TAG addresses; same type always returns same TAG
2. **Tag init** — after setting `foo.poly.tag = EVENT_TAG`, verify `foo.poly.tag == EVENT_TAG`
3. **Tag identity check** — `tag == EVENT_TAG` is true; `tag == SENSOR_TAG` is false
4. **@fieldParentPtr cast success** — given a `*PolyNode` with correct tag, `@fieldParentPtr("poly", poly)` recovers `*Event`
5. **@fieldParentPtr cast wrong tag** — given a `*PolyNode` with wrong tag, tag check fails before cast (user code responsibility)
6. **Two-level @fieldParentPtr chain** — DoublyLinkedList.Node → PolyNode → UserType, verify field values survive the roundtrip
7. **polynode.reset clears links** — after reset, `node.prev == null` and `node.next == null`
8. **polynode.is_linked detection** — linked node returns true; reset node returns false
9. **Slot null semantics** — `null` means the caller holds nothing; non-null means it holds the item; assignment to null lets the item go
10. **Multiple types in one list** — push Event and Sensor into the same `std.DoublyLinkedList`, pop and dispatch on tag, verify correct recovery via `@fieldParentPtr`. Demonstrates stdlib compatibility: PolyNode-based items participate in standard lists with no adapter. Deliberately raw — this scenario tests the layout itself (API 8 protection list)

### Tests — Holding-state transitions

11. **FREE → IN_FLIGHT** — allocate item, set tag; Slot is non-null; item is not linked; this is IN_FLIGHT
12. **IN_FLIGHT → HELD (list)** — push item to intrusive list, nil-out Slot; item is linked; this is HELD
13. **HELD → IN_FLIGHT (list)** — pop from list; Slot is non-null; item is unlinked after reset; this is IN_FLIGHT
14. **IN_FLIGHT → FREE** — free item, set Slot to null; the caller holds nothing

### Tests — Misuse detection

15. **Send linked item panics** — item is in a list (polynode_is_linked == true); attempt to push again; expect panic or assertion failure
16. **Double list insertion** — push same item twice without popping; expect panic or assertion failure
17. **Use after nil-out** — set Slot to null (the caller holds nothing); verify the handle is null; attempting to use it is a bug (document this invariant)

### Tests — Infrastructure as Items (Layer 1 level)

18. **MailboxHandle is a PolyNode** — `MailboxHandle = *PolyNode`; verify `mailbox.is_it_you(mbh.tag)` returns true
19. **PoolHandle is a PolyNode** — `PoolHandle = *PolyNode`; verify `pool.is_it_you(ph.tag)` returns true
20. **Per-module destroy** — `mailbox.destroy(mbh, alloc)` frees a closed mailbox. `pool.destroy(ph, alloc)` frees a closed pool

### Tests — ItemList (API 8)

100. **ItemList append, prepend, insertAfter, popFirst** — build a list from `ItemHandle`, pop it back in order, recover each item with `PolyHelper.fromNode`; empty-list behaviour for `isEmpty`, `len`, and `popFirst`
101. **ItemList popFirst returns an unlinked item** — `polynode.is_linked` is false on every popped handle, including the last; the handle drops straight into a `Slot`
102. **ItemList moveFromList and moveToList** — both directions empty their source, never alias; empty lists move cleanly
103. **ItemList iterator walks, concat empties the source** — `iterator` yields handles in order and removes nothing, items stay linked; `concat` moves every item over and leaves the source empty; the same list twice is a no-op, checked only where runtime safety is off, because the assert catches it everywhere else

### Tests — ItemList (API 9)

104. **ItemList appendFromSlot and prependFromSlot take the item** — both empty the Slot themselves, so no `slot = null` line is left for a caller to forget
105. **ItemList popFirst feeds appendFromSlot directly** — a popped handle is unlinked, so it is a legal Slot value and the round trip needs no `reset`

### Tests — ItemList (API 10)

106. **ItemList remove unlinks head, middle and tail** — `remove` takes one item out wherever it sits, including the last one; the removed item is unlinked and goes straight back into a list
107. **ItemList popLast returns an unlinked item** — mirror of `popFirst`; null on empty, and the sole member comes back unlinked because the pop calls `reset` itself
108. **ItemList first and last leave the item in place** — null on empty, the same item at both ends of a list of one, nothing removed
109. **ItemList insertBefore places the item ahead of an existing one** — mirror of `insertAfter`; before the only item is also a prepend
110. **ItemList moveFromList takes a consistent std list** — the header check accepts a well-formed std list and the source is left empty

---

## Layer 2 — Movement (Mailbox)

26. **mailbox.new and mailbox.destroy** — create mailbox, verify handle is non-null and `mailbox.is_it_you` returns true; close then destroy, verify freed
27. **Send and receive single item** — `mailbox.send` one PolyNode, `mailbox.receive` it, verify tag and data intact
28. **FIFO ordering** — send 3 items, receive 3, verify order preserved
29. **Send to closed mailbox returns error.Closed** — close first, then send, verify error
30. **Receive from closed mailbox returns error.Closed** — close first, then receive, verify error
31. **Receive timeout (non-null ?u64)** — `mailbox.receive` on empty open mailbox with `timeout_ns = 1000`, verify `error.Timeout`
32. **Receive wait forever (null ?u64)** — `mailbox.receive` with `timeout_ns = null` on a mailbox that gets an item sent from another context; verify item received, no `error.Timeout`
33. **Close returns remaining items as std.DoublyLinkedList** — send 3 items, `mailbox.close` without receiving, verify returned list has 3 items via `popFirst()` loop
34. **Close is repeatable** — second `mailbox.close` returns empty `std.DoublyLinkedList`
35. **send_oob delivers to front of queue** — send 3 normal items, then `mailbox.send_oob` 1 item; receive gets the OOB item first
36. **send_oob wakes blocked receiver** — receiver blocked on empty mailbox, `mailbox.send_oob` delivers item, receiver gets it
37. **Multiple send_oob items maintain FIFO among themselves** — `mailbox.send_oob` A then `mailbox.send_oob` B; receive gets A first, then B (OOBs inserted after previous OOBs)
38. **send_oob to closed mailbox returns error.Closed** — same as normal send
39. **Data priority over closed** — send item then close; receive gets the item first (or close returns it in remaining list)
40. **Batch receive (mailbox.receive_batch)** — send 5 items, `mailbox.receive_batch` gets all 5 as `std.DoublyLinkedList`, mailbox empty after
41. **Batch receive on empty returns empty list** — no items, `mailbox.receive_batch` returns empty `std.DoublyLinkedList` (not error)
42. **Batch items walkable via popFirst** — `mailbox.receive_batch` returns `std.DoublyLinkedList`; walk via `popFirst()`. `DoublyLinkedList` does NOT clear links on pop — caller must call `polynode.reset` before checking `is_linked`. Standard stdlib iteration pattern
43. **Send transfers the item** — after `mailbox.send`, caller's Slot is null
44. **Receive transfers the item** — after `mailbox.receive`, caller's Slot is non-null, mailbox no longer holds it
45. **try_receive on empty returns false** — `mailbox.try_receive` on open empty mailbox returns false, Slot stays null
46. **try_receive gets item** — send item, `mailbox.try_receive` returns true, Slot is non-null

### Tests — Holding-state transitions (Mailbox)

47. **IN_FLIGHT → HELD (mailbox.send)** — item owned by caller; `mailbox.send` transfers to mailbox; Slot is null; item is HELD
48. **HELD → IN_FLIGHT (mailbox.receive)** — item in mailbox; `mailbox.receive` transfers to caller; Slot is non-null; item is IN_FLIGHT
49. **Send linked item panics** — item already in a list; `mailbox.send` should detect `polynode.is_linked` and panic

### Tests — Multi-threaded Scenarios

50. **Fan-in (3+1)** — 3 sender threads (event sender, sensor sender, event sender), main receives all 3; heap alloc via `alloc.create`/`alloc.destroy`; mixed Event + Sensor types; tag dispatch via `EventPolyHelper.cast` / `SensorPolyHelper.cast`; verify received == 3
51. **Fan-out (1+2)** — main sends 1 Event + 1 Sensor then closes; 2 receiver threads each call `mailbox.receive(null)` until `error.Closed`; tag dispatch + `alloc.destroy`; verify `items_a + items_b + remaining == 2`
52. **Combined (3+2+main)** — 3 sender threads (event loop, sensor loop, alternating loop) + 2 receiver threads + main; senders loop `mailbox.send` until `error.Closed`; receivers loop `mailbox.receive(null)` until `error.Closed`; main sleeps 100ms via `Io.Timeout.sleep` then calls `mailbox.close`; main joins all 5 threads, walks close result; verify `total_sent == total_received + remaining_count`

---

## Layer 3 — Lifecycle (Pool)

63. **pool.new, pool.init, pool.destroy** — create pool, register hooks via `pool.init`, verify handle; close then destroy
64. **pool.get creates new item via on_get** — empty pool, `.available_or_new` mode, on_get called with `m.* == null`, returns new item
65. **pool.get reuses stored item** — put item back, get again, verify same pointer returned
66. **on_get reinitializes recycled item** — put item with data, get it back, verify fields were reset by on_get
67. **pool.put calls on_put** — verify on_put hook is invoked with correct in_pool_count
68. **on_put can destroy item** — on_put sets `m.* = null` (destroy policy), verify item not stored
69. **on_put can keep item** — on_put leaves `m.*` non-null (keep policy), verify item stored in pool
70. **GetMode.new_only always creates** — even with items available, `.new_only` calls on_get with null
71. **GetMode.available_only returns error.NotAvailable** — empty pool, `.available_only` mode, returns `error.NotAvailable`
72. **GetMode.available_only returns stored item** — pool has item, `.available_only` returns it
73. **Per-tag free lists** — pool stores Event and Sensor separately, `pool.get` with EVENT_TAG returns Event, not Sensor
74. **pool.close calls on_close with all items** — put 5 items, `pool.close`, on_close receives `*std.DoublyLinkedList` with 5 items
75. **pool.close is repeatable** — second close is a no-op
76. **pool.get on closed pool returns error.Closed** — close first, then get, verify error
77. **pool.put on closed pool returns item to caller** — put after close, Slot stays non-null (the caller still holds it)
78. **Backpressure policy** — on_put drops items when count exceeds threshold
79. **Pool seeding** — pre-allocate N items with `.new_only` + `pool.put`, verify N available with `.available_only`
80. **in_pool_count accuracy** — track count across get/put cycles, verify on_get and on_put receive correct counts
81. **Hooks run outside lock** — verify no deadlock when on_get/on_put call into pool (indirect test via successful operation)
82. **pool.put_all** — return a batch of items via `*std.DoublyLinkedList`; callee pops from caller's list. Accepts a standard stdlib list — no conversion needed from `mailbox.receive_batch` or `mailbox.close` results
83. **pool.get_wait timeout (non-null ?u64)** — `pool.get_wait` with `timeout_ns = 1000` on empty pool, verify `error.Timeout`
84. **pool.get_wait forever (null ?u64)** — `pool.get_wait` with `timeout_ns = null` on pool that gets an item put from another context; verify item received

### Tests — Holding-state transitions (Pool)

85. **HELD → IN_FLIGHT (pool.get)** — item in pool free-list; `pool.get` transfers to caller; Slot non-null; item is IN_FLIGHT
86. **IN_FLIGHT → HELD (pool.put, keep)** — item held by caller; `pool.put` with on_put that keeps; item back in pool; Slot null
87. **IN_FLIGHT → FREE (pool.put, destroy)** — item held by caller; `pool.put` with on_put that destroys; item freed; Slot null
88. **Double pool.put** — put same item twice without getting in between; expect panic or assertion failure

---

## Cross-Layer Notes

- All Layer 2-3 tests that need blocking use `Io.Threaded.global_single_threaded` — no cancellation
- Thread-based tests use `std.Thread.spawn` (still exists in 0.16), not `io.concurrent()`
- `io.concurrent()` / `Future` / `Io.Group` / `error.Canceled` reserved for Layer 4 (Task 2)
- Builder/types are shared test infrastructure, not part of any layer's public API
- Holding-state tests validate the architecture's core invariants, not implementation details
- API uses module-function style: `mailbox.send(mb, &item)` not `mailbox_send(mb, &item)`
- Handle types are already pointers: `mbh: MailboxHandle` (= `*PolyNode`), not `mbh: *MailboxHandle`
- Batch returns are `polynode.ItemList`, walked via `popFirst()` — `ItemList.popFirst` clears the links, so no caller-side `polynode.reset` (API 8)
- Timeout is `?u64`: null = wait forever, value = nanoseconds
