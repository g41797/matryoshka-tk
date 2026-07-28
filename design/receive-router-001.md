# Receive router (001)

Working document for EXMPL 5.

Describes the use case and the chosen solution.

Written before the example. The example is built from this document.

---

## Settled design

Every row is decided. Sections below give the reasoning.

| decision | value |
|---|---|
| union shape | single field `inbox: mailbox.ReceiveResult` |
| spawn | `sel.concurrent(.inbox, ...)` — Select owns the router |
| `.item` / `.timeout` / `.wakeup` | put to queue, continue |
| `.closed` | terminal — return the last `ReceiveResult` |
| `.canceled` | terminal |
| queue closed | terminal, return `.canceled` (value unobservable) |
| in-loop put | `putOneUncancelable` |
| held item on failed put | `defer` → `pool.put`, then `items.freeSlot` |
| mailbox | router never closes it, never clears it |
| return value | never `.item` |
| shutdown | `sel.cancel()` + walk. Never `cancelDiscard` |
| pool | pre-filled, `get_wait` — bounds items in flight |
| buffer | `N >= P + T`, stated as precondition |

---

## The problem

`Io.Select` produces one completion per registration.

- A Master registers a source.
- The source runs once.
- Its result lands in the queue.
- The registration is spent.

So a Master must register the source again after every item.

```zig
.inbox => |r| switch (r) {
    .item => |handle| {
        // process
        try sel.concurrent(.inbox, mailbox.receiveResult, .{ mbh, null });
    },
    ...
}
```

That re-registration line is easy to forget.

It is also invisible as a cost until something removes it.

## The solution

A **receive router**.

An application function with one job:

- receive from a mailbox
- put the result in the Select queue
- repeat until the mailbox closes

One registration. Many events.

The Master stops re-registering.

## Why it is not part of Matryoshka

`U` is the application's event union.

- `Io.Select(U)` is instantiated by the application.
- `U` names the application's own sources.
- Matryoshka cannot name `U`.

A `src/` function taking `Queue(U)` would put a generic parameter into an API  
that is otherwise concrete: `MailboxHandle`, `Slot`, `ItemHandle`.

The existing code already stops at that line.

- `mailbox.receiveResult` returns `ReceiveResult`, a Matryoshka type.
- The wrapping into `U` is left to `select.concurrent`.

The router adds no mailbox behaviour. It wraps and forwards.

So it ships as an example plus pattern documentation.

Applications are free to write a different router, or none at all.

---

## Shape

```zig
const MasterEvent = union(enum) {
    inbox: mailbox.ReceiveResult,
    timer: void,
};
```

One field for the mailbox source.

The field type is pinned.

- `Select.concurrent` requires the function's return type to equal the field type.
- The router returns `mailbox.ReceiveResult`.
- So `.inbox` is `mailbox.ReceiveResult`.

This is what makes the single field work.

- In-loop puts land in `.inbox`.
- The terminal return also lands in `.inbox` — Select wraps it.
- `U` needs no extra field.

The Master's inner `switch` is unchanged from the plain  
`select.concurrent` version.

It simply never re-registers.

---

## Outcomes

`ReceiveResult` has five variants. They split three ways.

| variant | router action |
|---|---|
| `.item` | put to queue, continue |
| `.timeout` | put to queue, continue |
| `.wakeup` | put to queue, continue |
| `.closed` | finished — return the last `ReceiveResult` |
| `.canceled` | finished |

Notes.

- `.closed` is forced. The mailbox is gone. Nothing can arrive again.
- `.canceled` is forced by mechanics, not policy. Cancel is latched on the task.
  The next receive returns `.canceled` at once. Continuing would spin.
- `.timeout` is unreachable at the default `timeout_ns == null`.
- `.wakeup` stays a pass-through. The router does not interpret it.
  An application may instead use `wakeUpAll` as its own stop signal.

The router interprets nothing. It wraps four outcomes and stops on one.

---

## What the router may touch

The router is application code. Not toolkit code.

It took one item out of the mailbox. That item is now in the router, and  
nowhere else.

It must not stay there.

So the router places it:

- back to the pool
- freed, if the pool is gone

The router stops there.

- It does not close the mailbox.
- It does not clear what is still inside.

The mailbox was made elsewhere. It is closed elsewhere. `close` returns  
everything still queued, as a list, and the caller walks that list.

One item in hand — the router's job.

Everything else — the caller's job.

---

## Two rules

### The router never returns an item

Select wraps the return value and puts it in the queue with  
`putOneUncancelable(...) catch error.Closed => {}` (`std/Io.zig:1456`).

On a closed queue that value is thrown away. Silently. No log, no error.

The task has already returned by then. It cannot react even in principle.

So the router returns only the reason it stopped. An item never rides out on  
the return.

This is a property the router guarantees. It is not a rule `std.Io` imposes —  
`Select.concurrent` places no restriction on what a task returns.

The router satisfies it by construction: `.item` always continues the loop.

### Shutdown walks, never discards

`U` carries items. A `.{ .inbox = .{ .item = handle } }` sitting in the ring  
buffer is a live handle nobody is looking at.

- `sel.cancel()` returns each value in turn. The caller walks them.
- `sel.cancelDiscard()` throws the buffer away.

So this pattern uses `sel.cancel()`.

---

## The failure this prevents

`receiveResult` removes the handle from the mailbox — `popFirst`,  
`src/mailbox.zig:185`.

From that moment the router's local variable is the only reference.

If the router returns without placing it, the item is unreachable.  
`mailbox.close()` cannot recover it, because it is no longer linked.

How it is reached.

- `sel.cancelDiscard()` closes the queue first, then cancels tasks
  (`std/Io.zig:1534`).
- In that window the router still receives normally.
- Every put fails at once with `error.Closed`.
- No full buffer needed. No race to win.

`sel.cancel()` reverses the order — `group.cancel` blocks until every task  
finishes, and only then closes the queue. There is no such window.

`testing.allocator` catches this failure. It is not theoretical.

---

## Placing the held item

```zig
var held: polynode.Slot = if (result == .item) result.item else null;
defer {
    pool.put(ph, &held);            // back to the pool
    items.freeSlot(&held, alloc);   // pool closed — nowhere to put it back
}
```

Why `defer`.

- It sits inside the loop body. It runs at the end of every iteration.
- It runs on every `return` out of the loop.
- Terminal outcome: `held` is null. No-op.
- Failed put: `held` is live. The item goes back.
- Successful put: `held` was cleared.

Three paths. One line. No branch that can be forgotten later.

Why no `if`.

- `pool.put` is a no-op on an empty slot — `src/pool.zig:246`.
- `items.freeSlot` is a no-op on an empty slot — `examples/items/items.zig:20`.
- Functions taking a `*Slot` absorb the empty case. The caller does not test.

Why no assert.

- `std.debug.assert` is compiled out in ReleaseFast and ReleaseSmall.
- The kitchen scripts build all modes.
- An assert would turn this into a silent failure in two of them.
- `freeSlot` is correct in every mode and costs one line.

Why `held = null` sits directly after the successful put.

- Between the put and that line the handle is reachable twice.
- It is straight-line code, so nothing can observe the gap.
- The two lines must stay adjacent.

---

## Bounding items in flight

The Select buffer holds `U` values by value, in a fixed ring.

Precondition:

```
N >= P + T
```

- `N` — Select buffer length
- `P` — maximum items in flight
- `T` — number of tasks registered in the Select

The router can never put more than `P` item-events, because only `P` items  
exist. `T` reserves one slot per task for the terminal value that Select puts  
uncancelably.

### How `P` is fixed

Pre-fill the pool with exactly `P` items. Acquire with `pool.get_wait`.

- `get_wait` is `available_only`. It never creates.
- Population is fixed for the pool's life.
- A producer wanting item `P+1` waits until one comes back.

This is the existing backpressure pattern — see  
`kitchen/docs/patterns/async.md`, and `stories/video_transcoder`.

### Not `CappedPoolHooks`

`CappedPoolHooks` caps retention, not items in flight.

- `onGet` calls `items.createByTag` whenever the pool is empty —
  `examples/hooks/CappedPoolHooks.zig:18`.
- The cap is consulted only in `onPut`.
- Population is unbounded.

It would make an example look bounded while the precondition quietly fails.

### Why the precondition matters

The in-loop put is `putOneUncancelable`.

- A full buffer blocks the router with no way out.
- `group.cancel` waits for the router. The router waits for space.

Select's own terminal put was already uncancelable, so an undersized buffer  
could stall shutdown regardless. The router widens the window to normal  
running rather than creating it.

`.timeout` and `.wakeup` are not bounded by `P`. A router carrying a timeout  
must size `N` by its own reasoning. This is a second reason the default is  
`timeout_ns == null`.

State this as setup, not as a warning.

---

## Why `putOneUncancelable` in the loop

Chosen over `putOne`.

- The error set collapses to `error{Closed}`. One failure mode, one recovery.
- The router gets exactly one cancellation point: `mailbox.receiveResult`.
  Cancellation is observed in the receive or not at all.
- It matches Select's own wrapper (`std/Io.zig:1456`). The router does what
  `select.concurrent` does, repeatedly.

The cost is the buffer precondition above.

---

## Queue closed needs no variant in `U`

A `.queue_closed` field would report the condition through the queue.

The queue is closed. The value would be thrown away by the very condition it  
reports.

There is also no reader. Select closes its queue only in `cancel` and  
`cancelDiscard`. Whoever would receive the news is the one who caused it.

So the router returns `.canceled` on that path. Nothing can read the value, so  
any variant would do. `U` stays at two fields.

---

## Shutdown order

1. Walk the Select — `while (sel.cancel()) |event|`. Recover any item.
2. Close the pool.
3. Close the mailbox. Walk the returned list.

`sel.cancel()` runs `group.cancel` first, and that blocks until every task has  
finished (`std/Io.zig:1512`). So the router is finished before step 2 begins.

That is what lets the router place items in the pool: the pool outlives it.

The natural instinct is to close top-down. That would strand the router's last  
item.

---

## Change log

| Version | Date | Change |
|---|---|---|
| 001 | 2026-07-27 | First version. EXMPL 5a. |
