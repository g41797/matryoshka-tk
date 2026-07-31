# Matryoshka Zig — Pattern and Idiom Catalog (024)

Versioned doc. Replaces [patterns-023.md](patterns-023.md).

Change from patterns-023: DISPATCH 1 — "Polymorphic dispatch" split into  
item-first and tag-first, with the `PoolHooks.on_get` case that has no item at  
all. Two new entries: the last branch of a dispatch chain, and why a `switch`  
over tags does not compile.

Change from patterns-022: API 11 — `fromNode`/`mustFromNode`/`toNode` renamed to  
`fromPoly`/`mustFromPoly`/`toPoly`. Every idiom that names them is updated.  
Companion cross-reference updated to matryoshka-api-reference-033.md.

Change from patterns-021: API 10 — `list.iterate()` becomes `list.iterator()`.  
"Walk a batch — ItemList" gains a "Take one item out" idiom for `remove` and  
the widened insert checks. Companion cross-reference updated to  
matryoshka-api-reference-032.md.

Change from patterns-020: API 9 — new "Insert from a Slot" idiom under Slot and  
transfer idioms. "Transfer clears the slot" gains `appendFromSlot` as a fourth  
shape. "Walk a batch — ItemList" gains the insert half and the neighbour-check  
note. Companion cross-references updated to rules-034.md,  
matryoshka-model-006.md and matryoshka-api-reference-032.md.

Change from patterns-019: banned-word pass. `ownership` removed from prose and  
from two section titles — "Slot and ownership idioms" → "Slot and transfer  
idioms", "Transfer clears ownership" → "Transfer clears the slot", "Cancellation  
preserves ownership" → "Cancellation keeps the item where it is". The  
replacement table is in rules-033.md. `escape hatch` also removed — banned in  
rules-033. Companion cross-references updated to rules-033.md and  
matryoshka-model-005.md.

Change from patterns-018: API 8 — `ItemList` closes the `std.DoublyLinkedList` boundary. New "Walk a batch — ItemList" entry. "Stack item into the toolkit" gained its list half. Hook and close examples now take `*polynode.ItemList`. Companion cross-references updated to rules-029.md and api-reference-029.md.

Change from patterns-017: API 7 — new `toNode` accessor. Added the "Stack item into the toolkit" idiom. "Slot identification" gained the in-and-out framing. Companion cross-reference updated to api-reference-028.md.

Change from patterns-016: API 6 — PolyHelper accessors renamed to `fromNode`/`fromSlot` (+ `must` variants). New `moveFromSlot` added to the transfer idiom. "Slot identification" gained the inspection-vs-extraction split and dropped "owned" from its title. Companion cross-references updated to rules-027.md and api-reference-027.md.

Change from patterns-015: EXMPL 5 — added "Receive router — one registration, many events" under Io.Select patterns. Companion cross-reference corrected from rules-024.md to rules-026.md.

Change from patterns-014: "thread" audit — worker-finish-signal pattern's stale "spawns a worker thread"/"joins the thread" language corrected to `io.concurrent`/future-await; stale api-reference-022.md cross-references updated to -025.md. No pattern content changed, wording only.

Change from patterns-013: staccato-style scan, prose paragraphs converted to bullets. No pattern content changed, wording only.

Change from patterns-012:
- `Thread.spawn` removed as an accepted task-creation option.
- `io.concurrent()` is the only way a task starts (New Mindset, `matryoshka-new-mindset-001.md`).

Change from patterns-011:
- API 4 renamed `NodeHandle` → `ItemHandle` — the old name leaked the intrusive-node implementation detail.
- No pattern content changed, wording only.

One unified catalog. Every pattern and idiom appears once, in logical order.  
Companion: [rules-034.md](rules-034.md) — what is mandatory.  
Companion: [matryoshka-model-006.md](matryoshka-model-006.md) — the thinking model.  
Companion: [matryoshka-api-reference-032.md](matryoshka-api-reference-032.md) — signatures and contracts.

How this doc differs from rules.
- Rules constrain. A rule says what you must or must not do.
- Patterns reuse. A pattern is a code shape that solves a recurring problem.
- An idiom is a one-line habit. A pattern is a code shape.
- Both are suggestions grounded in working code, not constraints.

How to use it.
- Find the topic. Read the "when to use" line.
- Copy the code shape. Adapt names to your domain.
- Open the referenced example for the full working version.

Each entry lists: name, when to use, code shape, example reference.  
Every example path is under `examples/` or `stories/`.

Order of this catalog.
- Slot and transfer idioms first — they appear in every pattern below.
- PolyNode, Mailbox, Pool next — the building blocks.
- Topology patterns after Mailbox — recurring shapes built from mailboxes and workers.
- Futures, Select, Group after — the Io integration.
- Cancellation, shutdown, Master patterns last — whole-system shapes.

---

## Slot and transfer idioms

The slot rule in full: [api-reference — Slot-based programming](matryoshka-api-reference-030.md).

### Empty Slot initialization

When to use.
- Every time the caller takes an item.

Code shape.  
```zig
var slot: Slot = null;
```

Why.
- Every acquisition API requires an empty slot.
- Passing a non-null slot is a programming error.

### Slot overwrite prevention

When to use.
- Before every receive/get/create operation.

Code shape.  
```zig
std.debug.assert(slot.* == null);
```

Why.
- A slot always owns exactly one object.
- Overwriting a non-null slot loses the item it held.
- Every acquisition API contains this assert. Wrong use panics immediately.

### Transfer clears the slot

When to use.
- Every transfer.

Code shape.  
```zig
try mailbox.send(mbh, &slot);
// slot == null
```

or

```zig
pool.put(ph, &slot);
// slot == null if accepted by pool
```

or, when the caller takes the item itself:

```zig
const ev: *Event = EventPolyHelper.moveFromSlot(&slot) orelse return error.WrongTag;
// slot == null, the caller holds ev
```

or, when a list takes the item:

```zig
list.appendFromSlot(&slot);
// slot == null
```

Why.
- Sender no longer owns the object.
- Cleanup code becomes naturally safe.
- Transfer pre-empts cleanup: a later `defer` sees null and does nothing.

### Insert from a Slot

When to use.
- Putting an item that sits in a Slot into an `ItemList`.

Code shape.  
```zig
var slot: Slot = null;
try EventPolyHelper.create(allocator, &slot);
EventPolyHelper.mustFromSlot(&slot).code = 7;

list.appendFromSlot(&slot);
// slot == null
```

`prependFromSlot` is the same at the front.

Why.
- `append` takes an `ItemHandle`, so it cannot clear a Slot. Every call site
  wrote `slot = null` on the next line by hand.
- Forget that line and the defer-destroy-early idiom frees an item the list
  still points at.
- `appendFromSlot` empties the Slot itself, so there is no line to forget.

Do not.
- Do not use these for a stack item. There is no Slot to empty — use `append`
  with `toPoly`, see "Stack item into the toolkit".

Asserts.
- The Slot must hold an item. An insert is not a `defer` target, so it follows
  `mailbox.send` rather than `pool.put` and rejects a null Slot.

### Null-safe cleanup

When to use.
- Every deferred cleanup.

Code shape.  
```zig
defer pool.put(ph, &slot);
```

or

```zig
defer EventPolyHelper.destroy(allocator, &slot);
```

Why.
- Cleanup helpers ignore null slots.
- Cleanup may safely execute after transfer.

### Defer-put-early (pool item)

When to use.
- Acquiring a pool item. The defer goes before the get.

Code shape.  
```zig
var slot: Slot = null;
defer pool.put(ph, &slot);              // no-op if slot == null
try pool.get(ph, TAG, .available_or_new, &slot);
// ... work ...
// on transfer: slot = null → defer runs as no-op
// on no transfer: defer recycles item
```

Why.
- Failure path, success path, and transfer path all become correct automatically.
- If the get fails, the defer sees null — nothing lost.

Example: `examples/layer4/018-master_with_pool.zig`.

### Defer-destroy-early (heap item via PolyHelper)

When to use.
- Creating a heap item. The defer goes before the create.

Code shape.  
```zig
var slot: Slot = null;
defer EventPolyHelper.destroy(allocator, &slot);   // no-op if slot == null
try EventPolyHelper.create(allocator, &slot);
// ... work ...
// on transfer: slot = null → defer runs as no-op
// on no transfer: defer frees item
```

Example: `examples/layer2/097-wake_up_all.zig`.

### Defer for received mailbox item

When to use.
- Receiving into a slot. Cleanup must cover both the error path and the normal path.

Code shape.  
```zig
var slot: Slot = null;
defer if (slot) |poly| helpers.freeItem(poly, allocator);
try mailbox.receive(mbh, &slot, null);
// dispatch on slot.?.*.tag, process item
// item stays non-null until explicitly transferred or freed
```

Example: `examples/layer4/031-select_graceful_shutdown.zig`.

### Fallback destroy after pool.put

When to use.
- Pool may already be closed when the item comes back.

Code shape.  
```zig
defer EventPolyHelper.destroy(allocator, &slot);   // fallback: frees if pool.put left slot non-null
defer pool.put(ph, &slot);                          // primary: recycles to pool (clears slot on success)
// defers run LIFO: pool.put first, then destroy (no-op if pool.put cleared slot)
```

Why.
- Pool receives the item if open.
- A closed pool leaves the slot non-null — the caller keeps the item.
- Destroy executes only if the item stayed with the caller.

Example: `stories/video_transcoder/video_transcoder.zig`.

### No raw allocator calls on PolyNode-based types

When to use.
- Every PolyNode-based user type (Event, Sensor, Timer, ShutdownCommand).

Code shape.  
```zig
// WRONG — raw allocator on PolyNode-based type
const ev = try alloc.create(Event);

// CORRECT — PolyHelper.create/destroy
var slot: Slot = null;
defer EventPolyHelper.destroy(alloc, &slot);
try EventPolyHelper.create(alloc, &slot);
```

Why.
- `PolyHelper.create` sets the tag and initializes the node.
- Raw `allocator.create` skips both. The object is unusable for dispatch.

Exempt: `mailbox.zig` / `pool.zig` internals, PolyHelper implementations, pool hook bodies, non-PolyNode structs.  
Full list: [api-reference — No raw allocator calls](matryoshka-api-reference-030.md).

---

## PolyNode idioms

### Intrusive node embedding

When to use.
- Every PolyNode-based user type, from first definition.

Code shape.  
```zig
pub const Message = struct {
    poly: polynode.PolyNode = .{},
    text: []const u8 = "",
    priority: u8 = 0,
};
pub const MessagePolyHelper = polynode.PolyHelper(Message);
```

Why.
- `PolyNode` sits at offset 0. One allocation, no wrapper struct.
- Safe cast both ways: `*Message` to `*PolyNode` and back, via `PolyHelper`.
- No separate link object to keep in sync with the payload.

Example: `examples/layer1/021-define_type.zig`.

### PolyHelper everywhere

When to use.
- Every PolyNode type.

Code shape.  
```zig
pub const EventPolyHelper =
    polynode.PolyHelper(Event);
```

Why.
- Eliminates manual tag management.
- Eliminates unsafe casts.
- Eliminates initialization boilerplate.

### Node identification

When to use.
- Recovering a concrete type from a `*PolyNode` handle (e.g. an `ItemHandle` received from a mailbox or returned by a pool event source).

Code shape.  
```zig
if (EventPolyHelper.fromPoly(handle)) |ev| {
    ...
}
```

Why.
- Tag check and recovery are combined.
- Wrong types return null.

### Stack item into the toolkit

When to use.
- An item lives on the stack, so there is no `create` and no Slot to start from.
- Something needs an `ItemHandle`: `mailbox.send`, `pool.put`, a list, a Slot.

Code shape.  
```zig
var ev: Event = .{ .code = 42 };
EventPolyHelper.init(&ev);

const handle: polynode.ItemHandle = EventPolyHelper.toPoly(&ev);
```

Straight into a Slot, no separate accessor.  
```zig
var slot: Slot = EventPolyHelper.toPoly(&ev);
```

Why.
- `toPoly` cannot fail. The type is known at compile time, so there is no tag to check.
- The field name stays inside `PolyHelper`. Application code never writes `&ev.poly`.
- `Slot` is `?ItemHandle`, so the result coerces with no conversion step.
- The heap path does not need this idiom. `create` fills a Slot already.

Do not.
- Do not call `fromPoly` on an item whose static type you already have. That is
  a round trip that proves nothing. `fromPoly` is for the way back, where the  
  static type is gone — see "Polymorphic dispatch — item-first".

Straight into a list, same shape.  
```zig
var list: polynode.ItemList = .{};
list.append(EventPolyHelper.toPoly(&ev));
```

### Walk a batch — ItemList

When to use.
- Anything hands back many items: `mailbox.receive_batch`, `mailbox.close`,
  `pool.close`'s `on_close` hook, `on_put`'s returned list.

Code shape.  
```zig
var batch: polynode.ItemList = try mailbox.receive_batch(mbh);
while (batch.popFirst()) |ih| {
    const ev: *Event = EventPolyHelper.fromPoly(ih) orelse return error.WrongTag;
    // ...
}
```

Why.
- `popFirst` yields an `ItemHandle`, not a list node. One step, no
  `@fieldParentPtr`.
- `popFirst` calls `polynode.reset` before returning. A popped handle is never
  linked, so it drops straight into a `Slot` or into `mailbox.send`.
- Mixed types in one batch: `fromPoly` returns null on a tag mismatch, so the
  same loop dispatches — see "Polymorphic dispatch — item-first".

Walk without consuming.  
```zig
var it = list.iterator();
while (it.next()) |ih| {
    // items stay linked, nothing is removed
}
```

Insert side.  
```zig
list.appendFromSlot(&slot);            // from a Slot — see "Insert from a Slot"
list.append(EventPolyHelper.toPoly(&ev));   // from a stack item
```

- Under a safety build every insert asserts twice on the new item, and both
  asserts are partial.
- The list walk reads the list, not the item. It catches a double-insert into
  the same list, including the list of one that `polynode.is_linked` misses.  
  It says nothing about an item held by a *different* list.
- `!is_linked` reads the item. It catches that different list — except when the
  item is its only member.
- O(n) per insert under safety builds. Nothing outside them.

Take one item out.  
```zig
list.remove(ih);                  // wherever it sits — head, middle, tail
const head = list.first();        // look without taking
const tail = list.popLast();      // take from the other end
```

- `remove` calls `polynode.reset`, the same guarantee `popFirst` gives. The item
  comes back unlinked and goes straight into a `Slot` or another list.
- This is the reason not to reach through `list._list`.

Do not.
- Do not reach through `list._list` in application code. It is the raw field,
  there for tests that manipulate raw links. Items taken out that way keep stale  
  `prev`/`next`, and `polynode.reset` becomes yours to call. Use `remove`.
- Do not use `len()` under a lock in a hot path. It walks the list, O(n). The
  mailbox and pool keep their own counters for that reason.

### Slot identification — accessing items

When to use.
- After `create` or `get`, to access fields of the item in a Slot before sending or returning it.

Code shape (assert non-null, known type).  
```zig
var slot: Slot = null;
defer EventPolyHelper.destroy(allocator, &slot);
try EventPolyHelper.create(allocator, &slot);
EventPolyHelper.mustFromSlot(&slot).code = 42;
try mailbox.send(mbh, &slot);
```

Code shape (optional — type may vary).  
```zig
if (EventPolyHelper.fromSlot(&slot)) |ev| {
    ev.code = 42;
}
```

Why.
- Unwraps the optional internally — no `.?` in application code.
- `mustFromSlot` panics if the Slot is empty or the tag does not match.
- Use `fromSlot` (nullable) when the type is not guaranteed.
- Inspection leaves the Slot full. The item is still there for `send` or `put`.
- To take the item out instead, use `moveFromSlot` — see "Transfer clears the slot".
- To go the other way, from a typed item to a handle, use `toPoly` — see
  "Stack item into the toolkit".

### Polymorphic dispatch — item-first

When to use.
- You hold the item.
- Two or three types, and every branch wants the typed pointer straight away.

Code shape.  
```zig
if (EventPolyHelper.fromPoly(handle)) |ev| {
    // handle Event
} else if (ShutdownCommandPolyHelper.fromPoly(handle)) |_| {
    // handle ShutdownCommand
} else {
    // unknown tag
}
```

- One call does the tag check and the cast.
- `fromPoly` returns null on a tag mismatch. Chain calls for each known type.

Example: `examples/layer1/023-tag_dispatch.zig`,  
`examples/layer4/031-select_graceful_shutdown.zig`,  
`examples/layer4/033-cross_layer_mixed_types_mailbox.zig`.

### Polymorphic dispatch — tag-first

When to use.
- You have a tag and no item. `PoolHooks.on_get` is the clear case: it is
  handed `tag: *const anyopaque` and an empty Slot, so there is nothing to  
  cast.
- Four or more types.
- A branch that never reaches the item — count it, route it, log it.

Code shape.  
```zig
const tag: *const anyopaque = handle.*.tag;

if (EventPolyHelper.isIt(tag)) {
    const ev = EventPolyHelper.mustFromPoly(handle);
    // handle Event
} else if (SensorPolyHelper.isIt(tag)) {
    const sn = SensorPolyHelper.mustFromPoly(handle);
    // handle Sensor
} else {
    // unknown tag
}
```

- `isIt` asks about a tag, so it works where `fromPoly` cannot be called.
- Inside a confirmed branch the tag is proven — `mustFromPoly`, not `fromPoly`.
- `H.isIt(tag)` and `tag == H.TAG` compute the same thing. `isIt` is the
  toolkit's own API and keeps `TAG` out of application code.

Example: `examples/layer1/026-tag_first_dispatch.zig`,  
`examples/hooks/AlwaysCreateHooks.zig`, `examples/items/items.zig`.

### The last branch of a dispatch chain

Always write it. A chain's trailing `else` is optional, so an unrecognised item  
falls through in silence when it is missing. `items.freeItem` did exactly that  
until it was fixed.

- Closed set, every helper in the chain — `unreachable`.
- Open set, a mailbox anyone can send to — count it, log it, move on.

It cannot free. `alloc.destroy` takes `*T` and the allocator needs the size, so  
with no type there is no size. An unknown item can only be dropped or reported.  
Its memory belongs to whoever knows what it is.

### No switch on a tag

A `switch` over `Helper.TAG` values does not compile, on any zig version or  
backend available. A prong must be comptime-known; a tag is a global's address,  
assigned by the linker. Zig accepts the source and the backend then fails.  
`@intFromPtr` is refused wherever a compile-time value is required.

`isIt` and `==` need only to know which global the tag names, which the  
compiler does know.

Detail: `design/llvm-pointer-switch-bug-001.md`.

### Tag identifies the class

When to use.
- Runtime dispatch.

Pattern.  
```
tag
    ↓
type
```

Not

```
tag
    ↓
instance
```

Use.
- Pointer comparison for infrastructure handles.
- User fields (`kind`, `role`) for application roles.

Details: [api-reference — Tag identity](matryoshka-api-reference-030.md).

### Wrapper type for infrastructure handles

When to use.
- Mailbox or Pool must participate in polymorphic dispatch by tag.

Code shape.  
```zig
const WorkerInbox = struct {
    poly: PolyNode,
    handle: mailbox.MailboxHandle,
};
pub const WorkerInboxPolyHelper = polynode.PolyHelper(WorkerInbox);
```

Why.
- Wrapper has its own PolyHelper tag, distinct from `MailboxPolyHelper.TAG`.
- Enables normal type dispatch. The receiver finds the embedded handle.

### Mailbox-as-message

When to use.
- Handing communication endpoints back.

Pattern.  
```
Worker
    │
returns MailboxHandle
    │
Master receives mailbox
```

Typical use.
- Worker completion notification.
- Dynamic topology construction.
- Channel migration.

### Worker-finish-signal

When to use.
- A worker signals completion by sending its own mailbox back to the Master.

Pattern.
- Master creates `worker_mbh`, spawns a worker via `io.concurrent`, passes `worker_mbh` as parameter.
- Worker processes items until a shutdown signal.
- Worker sends `worker_mbh` back to the Master's inbox (unclosed) as the finish signal, then exits.
- Master confirms class: `mailbox.is_it_you(received.*.tag)`.
- Master confirms instance: `received == worker_mbh` (pointer comparison).
- Master closes and destroys `worker_mbh`, then awaits the worker's future.

Why.
- Replaces relying on the future await as a completion signal, or a separate shutdown message, by transferring the item.

Details: [api-reference — Transporting infra handles](matryoshka-api-reference-030.md).

### Pool-as-message

When to use.
- Sharing lifecycle managers.

Pattern.  
```
PoolHandle
    ↓
mailbox.send()
```

Why.
- PoolHandle is itself a PolyNode.

---

## Mailbox patterns

### Try-receive polling

When to use.
- Non-blocking work loop.

Code shape.  
```zig
if (try mailbox.try_receive(mbh, &slot)) {
    ...
}
```

### Batch receive

When to use.
- Empty an entire mailbox in one call.

Code shape.  
```zig
var list = try mailbox.receive_batch(mbh);

while (list.popFirst()) |node| {
    ...
}
```

Why.
- Reduces synchronization overhead.
- Natural bulk processing.

### Out-of-band priority

When to use.
- Shutdown.
- Urgent control messages.

Code shape.  
```zig
try mailbox.send_oob(mbh, &slot);
```

Why.
- OOB messages always precede normal traffic.
- FIFO inside the OOB region.

### Mailbox close recovery

When to use.
- Shutdown. Recover every queued object.

Code shape.  
```zig
var list = mailbox.close(mbh);

while (list.popFirst()) |node| {
    ...
}
```

Why.
- Nothing leaks.
- Close is also the end-of-stream signal for blocked receivers (see Group shutdown below).

### Wake blocked receivers without a message

When to use.
- Re-check external state (a flag flipped outside the mailbox) without sending a real item.
- Poke a Master blocked in `receive()` so it re-evaluates its loop condition.

Code shape.  
```zig
shutdown.store(true, .release);
try mailbox.wakeUpAll(mbh);
```

```zig
mailbox.receive(mbh, &slot, null) catch |err| switch (err) {
    error.Wakeup => {
        if (shutdown.load(.acquire)) return;
        continue; // spurious poke, re-check and keep waiting
    },
    else => ...,
};
```

Why.
- Distinct from `close()`: the mailbox is not torn down, sending still works afterward.
- Distinct from `send()`: nothing is queued, no item to free.
- Only receivers already blocked at the time of the call return `error.Wakeup` — a receiver
  that starts `receive()` afterward is not affected.

Example: `examples/layer2/097-wake_up_all.zig`.

---

## Topology patterns

Recurring shapes for connecting mailboxes and workers. Each is a composition of the  
Mailbox patterns above, not a new mechanism.

### Request-Response

When to use.
- One side asks, the other answers, on two dedicated mailboxes.

Pattern.  
```
main ──Event(request)──► req_mbh ──► worker
                                        │ process
                                        V
main ◄──Event(response)── resp_mbh ◄── worker
```

Why.
- Request and response never share a mailbox — no risk of the caller receiving its own request back.
- Caller blocks on `resp_mbh` with a timeout; worker loops on `req_mbh` until closed.

Example: `examples/layer2/057-request_response.zig`, `examples/layer4/021-request_response.zig`.

### Pipeline

When to use.
- A chain of stages, each transforming and forwarding.

Pattern.  
```
producer ──Event──► stage1 ──► transformer ──Event──► stage2 ──► consumer
```

Why.
- Each stage owns one item at a time — the slot rule holds at every hop.
- A sentinel value (e.g. `code == -1`) signals end-of-stream down the chain; the last stage frees it.

Example: `examples/layer2/056-pipeline.zig`, `examples/layer4/020-pipeline_masters.zig`.

### Fan-In

When to use.
- Several concurrent senders, one shared mailbox, one receiver.

Pattern.  
```
sender A ──►
sender B ──► mailbox ──receive_batch──► one receiver, dispatch by tag
sender C ──►
```

Why.
- The mailbox itself does the merging — no separate synchronization needed.
- Batch receive plus polymorphic dispatch (mixed item types) empties it in one pass.

Example: `examples/layer2/058-fan_in.zig`, `examples/layer4/053-pool_fan_in.zig`.

### Fan-Out

When to use.
- Several worker threads compete for items on one shared mailbox.

Pattern.  
```
main ──items──► mailbox ──► worker A
                       ├──► worker B   (compete; each item goes to exactly one)
                       └──► worker C
```

Why.
- The mailbox does the load distribution. No round-robin logic in application code.
- `mailbox.close` returns any item left unclaimed — the closer must free it.

Example: `examples/layer2/061-fan_out.zig`, `examples/layer4/054-pool_fan_out.zig`.

---

## Pool patterns

### Pool mode — .available_or_new

When to use.
- The common case: reuse a stored item if one is free, otherwise create a fresh one.

Code shape.  
```zig
var slot: Slot = null;
defer pool.put(ph, &slot);
try pool.get(ph, EventPolyHelper.TAG, .available_or_new, &slot);
```

- `on_get` runs every call. If `slot.*` is non-null it was recycled — reinitialize. If null, create.

Example: `examples/layer4/018-master_with_pool.zig`.

### Pool mode — .new_only

When to use.
- Seeding. You want a fresh item every time, never a stored one.

Code shape.  
```zig
var slot: Slot = null;
try pool.get(ph, EventPolyHelper.TAG, .new_only, &slot);
// fill the new item
pool.put(ph, &slot);
```

Example: `examples/layer3/pool_seeding.zig`.

### Pool mode — .available_only

When to use.
- Consume what is stored. Stop when the pool is empty.
- Empty pool returns `error.NotAvailable` — a normal end condition, not a failure.

Code shape.  
```zig
var slot: Slot = null;
pool.get(ph, EventPolyHelper.TAG, .available_only, &slot) catch |err| switch (err) {
    error.NotAvailable => break,
    else => return err,
};
```

Example: `examples/layer3/pool_seeding.zig`.

### Seeding pattern

When to use.
- A fixed-size pool. Pool capacity is set once at startup, no on-demand creation.

Code shape.  
```zig
for (0..N_BUFFERS) |_| {
    var slot: Slot = null;
    try VideoBufferPolyHelper.create(allocator, &slot);
    pool.put(ph, &slot);
}
```

- Pair with `on_get` that does nothing — the pool never grows past the seed count.
- The fixed count becomes the backpressure limit.

Example: `stories/video_transcoder/video_transcoder.zig`.

### Pool as lifecycle policy — on_get and on_put hooks

When to use.
- `on_get`: decide how an item is created or reinitialized.
- `on_put`: decide whether a returned item is kept or destroyed (cap policy).

Pattern.  
```
on_get
    ↓
slot == null  → create
slot != null  → reuse

on_put
    ↓
keep or destroy
```

Code shape.  
```zig
fn onGet(_: *anyopaque, _: *const anyopaque, _: usize, _: *Slot) void {}        // fixed-size: never create
fn onPut(_: *anyopaque, _: usize, _: *Slot) void {}                              // keep all
```

- `on_put`: set `slot.* = null` to destroy; leave non-null to keep.
- Allocation policy stays outside business logic.

Example: `examples/layer3/capped_pool.zig` (cap policy), `examples/hooks/CappedPoolHooks.zig` (thread-safe reference).

### Hook outside lock

When to use.
- Shared hook state.

Code shape.  
```zig
lockUncancelable()

...modify shared state...

unlock()
```

Why.
- Hooks run outside the pool lock. Multiple threads may call them at once.
- Pool does not serialize hook execution.
- Protect shared state with `Io.Mutex.lockUncancelable`.

Example: `examples/hooks/CappedPoolHooks.zig`.

### on_close hook

When to use.
- Free all stored items when the pool shuts down.

Code shape.  
```zig
fn onClose(ctx: *anyopaque, list: *polynode.ItemList) void {
    const self: *VideoBufCtx = @ptrCast(@alignCast(ctx));
    while (list.popFirst()) |node| {
        const poly: *polynode.PolyNode = @fieldParentPtr("node", node);
        polynode.reset(poly);
        var s: Slot = poly;
        VideoBufferPolyHelper.destroy(self.alloc, &s);
    }
}
```

- Always call `polynode.reset(poly)` after `popFirst` before destroy.

Example: `examples/layer3/pool_teardown.zig`, `stories/video_transcoder/video_transcoder.zig`.

### Multi-tag pool

When to use.
- Pool stores multiple object types.

Pattern.  
```
Pool
 ├── Event
 ├── Buffer
 └── Command
```

Why.
- One lifecycle manager.
- Separate free lists per tag.

---

## Future patterns

### Direct Future

When to use.
- Only one asynchronous operation. No Select loop needed.

Code shape.  
```zig
const future =
    try mailbox.receive_future(mbh, null);

const result =
    try future.await(io);
```

### Future cancellation

When to use.
- Abort one asynchronous operation.

Code shape.  
```zig
try future.cancel(io);
```

Why.
- The item stays in the mailbox or pool.
- Only the wait is canceled.

---

## Io.Select patterns

### Event loop — register, await, re-register

When to use.
- Wait on several sources at once: mailbox, pool, timer, external push.

Code shape.  
```zig
var buf: [8]MasterEvent = undefined;
var sel: std.Io.Select(MasterEvent) = std.Io.Select(MasterEvent).init(io, &buf);

try sel.concurrent(.inbox, mailbox.receiveResult, .{ mbh, null });
try sel.concurrent(.pool_ev, pool.getWaitResult, .{ ph, TAG, null });
try sel.concurrent(.timer, sleepFn, .{ sleep_t, io });

while (true) {
    const event: MasterEvent = try sel.await();
    switch (event) {
        .inbox => |r| switch (r) {
            .item => |handle| {
                // process, then re-register the source
                try sel.concurrent(.inbox, mailbox.receiveResult, .{ mbh, null });
            },
            .closed, .canceled, .timeout => break,
        },
        // ...
    }
}
```

Why.
- Each registration produces exactly one completion.
- Re-register the source after each item.

The rhythm.  
```
register
    ↓
await
    ↓
process
    ↓
register again
```

Example: `examples/layer4/031-select_graceful_shutdown.zig`, `examples/layer4/028-select_mixed_sources.zig`.

### Mailbox as event source

When to use.
- Event-driven Master.

Code shape.  
```zig
try select.concurrent(
    .mailbox,
    mailbox.receiveResult,
    .{ mbh, null },
);
```

### Pool as event source

When to use.
- Wait for reusable items.

Code shape.  
```zig
try select.concurrent(
    .pool,
    pool.getWaitResult,
    .{ ph, TAG, null },
);
```

### Mixed event sources

When to use.
- One loop coordinates everything.

Pattern.  
```
Mailbox
Pool
Timer
Socket
External callback
        │
        V
    Io.Select
```

Example: `examples/layer4/028-select_mixed_sources.zig`.

### Backpressure via getWaitResult in Select

When to use.
- A producer must slow down when no buffers are free.
- Pool availability becomes an event source in the same loop as data.

Code shape.  
```zig
try sel.concurrent(.buf_ev, pool.getWaitResult, .{ buf_ph, VideoBufferPolyHelper.TAG, null });
// ...
const ev = try sel.await();
switch (ev) {
    .buf_ev => |r| switch (r) {
        .item => |handle| {
            // fill buffer, route it, then re-register for the next free buffer
            try sel.concurrent(.buf_ev, pool.getWaitResult, .{ buf_ph, VideoBufferPolyHelper.TAG, null });
        },
        .closed, .canceled, .timeout, .not_created => break,
    },
}
```

- The loop blocks until a worker returns a buffer.
- No sleep. No poll. The pool wakes the waiter.

Example: `stories/video_transcoder/video_transcoder.zig`.

### Direct push — putOneUncancelable

When to use.
- A result is already available, or an external thread or callback must inject one without spawning.

Code shape.  
```zig
select.queue.putOneUncancelable(select.io, .{ .field = value }) catch {};
```

Example: `examples/layer4/043-select_direct_push.zig`.

### Receive router — one registration, many events

When to use.
- A Master should stop re-registering its mailbox source after every item.

Code shape.  
```zig
fn receive_router(
    mbh: MailboxHandle,
    timeout_ns: ?u64,
    sel: *std.Io.Select(MasterEvent),
    ph: PoolHandle,
    alloc: std.mem.Allocator,
) mailbox.ReceiveResult {
    while (true) {
        const result: mailbox.ReceiveResult = mailbox.receiveResult(mbh, timeout_ns);

        var held: Slot = switch (result) {
            .item => |handle| handle,
            else => null,
        };
        defer {
            pool.put(ph, &held);            // back to the pool
            items.freeSlot(&held, alloc);   // pool closed — nowhere to put it back
        }

        switch (result) {
            .closed, .canceled => return result,
            .item, .timeout, .wakeup => {},
        }

        sel.queue.putOneUncancelable(sel.io, .{ .inbox = result }) catch return .canceled;

        held = null;   // the queue has it now
    }
}

try sel.concurrent(.inbox, receive_router, .{ mbh, null, &sel, ph, alloc });
```

Why.
- `select.concurrent` produces one completion per registration.
- The router loops. One registration covers every item.
- The Master's `switch` is unchanged. It simply never re-registers.

The return type is pinned.
- `Select.concurrent` requires the function's return type to equal the field type.
- The router returns `mailbox.ReceiveResult`, so `.inbox` is `mailbox.ReceiveResult`.
- In-loop puts and the final return land in the same field. `U` gains nothing.

The router is application code, not toolkit code.
- `U` is the application's union. Matryoshka cannot name it.
- The router disposes of the one item it holds.
- It does not close the mailbox. It does not clear what is still inside.

Two rules.
- The router never returns an item. Select puts the return value in the queue with `putOneUncancelable(...) catch error.Closed => {}` and throws it away if the queue is closed by then. Only the reason for stopping rides out.
- Shutdown walks, never discards. `U` carries items, so use `sel.cancel()`. `sel.cancelDiscard()` throws the buffer away.

Buffer size is a precondition.
- `N >= P + T` — buffer length, items in flight, registered tasks.
- Pre-fill a pool with `P` items and acquire with `pool.get_wait` to fix `P`.
- `pool.get_wait` never creates, so the population stays put.

Design note: [receive-router-001.md](receive-router-001.md).

Example: `examples/layer4/062-receive_router.zig`.

### Graceful cancel walk — recover in-flight items

When to use.
- Shutting down a Select loop. Spawned sources may still hold items. None must leak.

Code shape.  
```zig
while (sel.cancel()) |event| {
    switch (event) {
        .inbox => |r| switch (r) {
            .item => |handle| {
                var slot: Slot = handle;
                helpers.freeSlot(&slot, allocator);   // recover the item
            },
            .canceled, .closed, .timeout => {},
        },
        .pool_ev => |r| switch (r) {
            .item => |handle| {
                var slot: Slot = handle;
                pool.put(ph, &slot);                   // recycle it
            },
            .canceled, .closed, .timeout, .not_created => {},
        },
        .timer => {},
    }
}
```

Example: `examples/layer4/031-select_graceful_shutdown.zig`.

### cancelDiscard — timer-only or no-item sources

When to use.
- The remaining spawned sources carry no owned item (e.g. a timer). Discard them.

Code shape.  
```zig
sel.cancelDiscard();
```

Example: `stories/video_transcoder/video_transcoder.zig`.

---

## Io.Group patterns

### Worker set — concurrent then await

When to use.
- Run several workers. Wait for all to finish.
- Spawn now, await later — the spawn does not block.

Code shape.  
```zig
var group: Io.Group = .init;
try group.concurrent(io, workerFn, .{&ctx0});
try group.concurrent(io, workerFn, .{&ctx1});
try group.await(io);
```

- Worker return type must coerce to `Cancelable!void`.

Example: `stories/video_transcoder/video_transcoder.zig`.

### Reusable Group

When to use.
- Multiple execution rounds.

Pattern.  
```
spawn
await

spawn
await
```

Why.
- Group may be reused after completion.

### Shutdown signal — close the source mailbox

When to use.
- Stop a Group of workers that block on `mailbox.receive`.

Code shape.  
```zig
// workers exit when receive returns error.Closed
var rem: polynode.ItemList = mailbox.close(ready_queue);
// walk rem, recover any unreceived items
try group.await(io);
```

- Close is the end-of-stream signal. Workers return on `error.Closed`.

Example: `stories/video_transcoder/video_transcoder.zig`.

### Shutdown signal — group.cancel

When to use.
- Stop a Group of workers that block on `pool.get_wait`, with no mailbox to close.

Code shape.  
```zig
group.cancel(io);   // injects error.Canceled into all blocked workers, then waits
```

- Blocked workers return `error.Canceled`. A worker that already finished is unaffected.

Example: `examples/layer4/059-mailbox_less_pool_group_workers.zig`.

---

## Cancellation patterns

### Cancellation boundary

When to use.
- Designing APIs.

Rule.

Only waiting operations are cancelable.

Examples.
- mailbox.receive
- pool.get_wait
- receiveResult
- getWaitResult

Everything else completes normally.

### Cancellation keeps the item where it is

When to use.
- Recovering after cancellation.

Pattern.  
```
Canceled
    ↓
slot unchanged
    ↓
resource still owned by mailbox/pool
```

### Close versus Cancel

Pattern.  
```
Close
    ↓
end of stream

Cancel
    ↓
stop waiting
```

Never substitute one for the other.

### Error handling on receive

When to use.
- A worker blocks on `mailbox.receive` or `pool.get_wait` and must react to each outcome.

Code shape.  
```zig
mailbox.receive(ctx.mbh, &slot, null) catch |err| switch (err) {
    error.Canceled => return error.Canceled,   // report up — Master decides
    error.Closed, error.Timeout => return,      // end-of-stream — exit cleanly
    error.Wakeup => continue,                   // poke — re-check loop condition
};
```

The distinction.
- `error.Canceled` — external stop signal. Propagate it. Do not close anything.
- `error.Closed` — the Master closed the source. End of stream. Exit.
- `error.Timeout` — the wait window passed. Treat per domain.
- `error.Wakeup` — a `wakeUpAll` poke. No item. Re-check state and continue.
- Never remap `error.Canceled` to `error.Closed`. They mean different things.

Example: `stories/video_transcoder/video_transcoder.zig`, `examples/layer4/059-mailbox_less_pool_group_workers.zig`.

---

## Graceful shutdown sequence

When to use.
- Tearing down a Master that owns workers, mailboxes, and a pool.

Mandatory order.
1. Stop the producer loop (the Select Master). Stop registering new work.
2. Close the mailbox that feeds the workers. This signals end-of-stream.
3. Walk the mailbox close list. Recover or recycle every item it returns.
4. `group.await(io)` — wait for all workers to finish their current item.
5. Destroy the worker mailbox.
6. Close any downstream mailbox (e.g. storage). Its task exits on `error.Closed`.
7. Await the downstream task. Destroy its mailbox.
8. `pool.close` — `on_close` frees all stored items.
9. `pool.destroy`.

Why this order.
- Close upstream before awaiting workers, or workers block forever.
- Await workers before closing the pool, or a worker returns an item to a closed pool.
- A pool returns the item to the caller when closed — the worker must free it as a fallback.

Code shape (worker fallback for closed pool).  
```zig
pool.put(ctx.buf_ph, &sc.buffer_slot);
if (sc.buffer_slot != null) {
    VideoBufferPolyHelper.destroy(ctx.alloc, &sc.buffer_slot);
}
```

Example: `stories/video_transcoder/video_transcoder.zig`, `examples/layer4/037-cross_layer_close_mailbox_then_pool.zig`.

### Alternative — shutdown via Exit message

When to use.
- The mailbox must stay open and reusable while the worker still needs to exit cleanly.
- Simpler than the close-based sequence above when there is only one worker and no pool to
  empty in lockstep.

Pattern.  
```
main ──Event×N──► mailbox ──► worker (processes, frees each)
main ──ShutdownCommand──► mailbox ──► worker (recognizes tag, exits, frees it)
(mailbox stays open — worker owns every item it ever received)
```

Why.
- A tagged sentinel item flows through the normal mailbox instead of `mailbox.close`.
- The mailbox can be reused for another worker afterward — closing it cannot be undone.
- Use the mandatory 9-step sequence instead when a pool must also empty in lockstep with the
  mailbox (the sentinel alone does not coordinate pool shutdown).

Example: `examples/layer2/062-shutdown_exit.zig`.

---

## Master patterns

### Observable function shapes

Concrete templates for the "Observable by human" MUST rule. See [rules-024.md](rules-024.md).

#### Coordinator / run

When to use.
- Any function that sequences discrete steps: `pub fn run`, a Master's `run`, any sequencing method.

Code shape.  
```zig
fn run(self: *Master) !void {
    try self.seedResources();
    try self.eventLoop();
    self.gracefulShutdown();
    try helpers.expect(error.XFailed, self.count > 0, "expected items");
    std.log.info("done: {d} processed", .{self.count});
}
```

- Dominant structure: calls to named step functions.
- Simple glue (a guard, a `helpers.expect`, a `std.log.info`) stays inline.
- No inline logic blocks with distinct purpose — those are extracted to named steps.

Example: `examples/layer4/031-select_graceful_shutdown.zig`.

#### Step function

When to use.
- Any function that implements one discrete phase of the coordinator.

Code shape.  
```zig
fn seedResources(self: *Master) !void {
    for (0..N) |i| {
        var slot: Slot = null;
        defer types.EventPolyHelper.destroy(self.allocator, &slot);
        try types.EventPolyHelper.create(self.allocator, &slot);
        types.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
        try mailbox.send(self.mbh, &slot);
    }
}
```

- Each step implements one thing. Name = documentation.
- `var`/`const` declarations are fine.
- Loops are one unit at their scope level.

Example: `examples/layer4/031-select_graceful_shutdown.zig`.

#### Init

When to use.
- Allocating a Master struct and acquiring its resources.

Code shape.  
```zig
fn init(allocator: std.mem.Allocator, io: std.Io) !*Master {
    const self = try allocator.create(Master);
    errdefer allocator.destroy(self);
    self.allocator = allocator;
    self.io = io;
    self.mbh = try mailbox.new(io, allocator);
    errdefer {
        var rem = mailbox.close(self.mbh);
        helpers.freeList(&rem, allocator);
        mailbox.destroy(self.mbh, allocator);
    }
    self.ph = try pool.new(io, allocator, &self.pool_ctx, pool_hooks);
    return self;
}
```

- Allocate first, guard with `errdefer allocator.destroy`.
- Acquire each resource, guard with `errdefer` for that resource.
- Return `self` last.

Example: `examples/layer4/018-master_with_pool.zig`.

#### Destroy

When to use.
- Releasing a Master struct and its resources.

Code shape.  
```zig
fn destroy(self: *Master) void {
    var rem: polynode.ItemList = mailbox.close(self.mbh);
    helpers.freeList(&rem, self.allocator);
    mailbox.destroy(self.mbh, self.allocator);
    pool.close(self.ph);
    pool.destroy(self.ph, self.allocator);
    self.allocator.destroy(self);
}
```

- Release resources in reverse acquisition order.
- Free the allocation last.

Example: `examples/layer4/018-master_with_pool.zig`.

#### Thread-is-container

When to use.
- Spawning an `io.concurrent` task for a Master.

Rule.
- The spawned function receives `*Master` (or a small `*Ctx`) directly as its argument.
- It keeps no other thread-local bookkeeping — the thread's own stack holds no separate
  ITC state to track and free later. The Master struct (heap-allocated, see Init above) is  
  the single source of truth, reachable through the one pointer the thread was given.

Code shape.  
```zig
var ctx: WorkerCtx = .{ .mbh = mbh, .alloc = allocator };
var fut = try io.concurrent(workerFn, .{&ctx});
...
fn workerFn(ctx: *WorkerCtx) anyerror!void {
    while (true) {
        var slot: Slot = null;
        defer helpers.freeSlot(&slot, ctx.alloc);
        mailbox.receive(ctx.mbh, &slot, null) catch return;
    }
}
```

Why.
- One pointer in, no hidden thread-local state to lose track of.
- Matches the heap-allocated-Master rule: the container the thread runs against outlives
  the spawn call and is destroyed only after the thread is joined/awaited.

Example: `examples/layer4/017-minimal_master.zig`, `examples/layer4/019-multi_worker_master.zig`.

### Coordinator with Select event loop (flat file)

When to use.
- A flat `pub fn run` (no Master struct) that owns an `Io.Select` event loop.
- `buf` and `sel` are declared at coordinator scope; passed as `*Sel` (transient) to step functions.
- Use when the file has 1-2 coordinator-scope params (explicit passing) or 3+ params (introduce a local Ctx struct).

Code shape (explicit params, 1-2 shared values).  
```zig
const Sel = std.Io.Select(MasterEvent);

pub fn run(allocator: std.mem.Allocator, io: std.Io) !void {
    const ph: PoolHandle = try pool.new(io, allocator, &pool_ctx, pool_hooks);
    defer pool.destroy(ph, allocator);

    try seedPool(ph, allocator);

    var buf: [8]MasterEvent = undefined;
    var sel: Sel = Sel.init(io, &buf);
    try setupSelect(ph, io, &sel);
    try runEventLoop(ph, io, &sel);

    try helpers.expect(error.XFailed, ...);
    std.log.info("done", .{});
}

fn setupSelect(ph: PoolHandle, io: std.Io, sel: *Sel) !void {
    const sleep_t: std.Io.Timeout = .{ .ns = 100_000_000 };
    try sel.concurrent(.pool_ev, pool.getWaitResult, .{ ph, TAG, null });
    try sel.concurrent(.timer, sleepFn, .{ sleep_t, io });
}

fn runEventLoop(ph: PoolHandle, io: std.Io, sel: *Sel) !void {
    while (true) {
        const event: MasterEvent = try sel.await();
        switch (event) {
            .pool_ev => |r| switch (r) {
                .item => |handle| {
                    // process handle
                    pool.put(ph, &(var s: Slot = handle; &s));
                    try sel.concurrent(.pool_ev, pool.getWaitResult, .{ ph, TAG, null });
                },
                .closed, .canceled, .not_created => break,
                .timeout => {},
            },
            .timer => break,
        }
    }
    sel.cancelDiscard();
}
```

Code shape (3+ shared values — local Ctx struct, stack-allocated).  
```zig
const Ctx = struct {
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,
    io: std.Io,

    fn setupSelect(self: *Ctx, sel: *Sel) !void { ... }
    fn runEventLoop(self: *Ctx, sel: *Sel) !void { ... }
};

pub fn run(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbh: MailboxHandle = try mailbox.new(io, allocator);
    defer { ... }

    var ctx: Ctx = .{ .mbh = mbh, .alloc = allocator, .io = io };

    var buf: [8]MasterEvent = undefined;
    var sel: Sel = Sel.init(io, &buf);
    try ctx.setupSelect(&sel);
    try ctx.runEventLoop(&sel);
}
```

- `setupSelect` owns timeout construction and initial `concurrent` registrations.
- `runEventLoop` owns the loop body, re-registrations, and final `cancelDiscard`.
- `buf` and `sel` are declared at coordinator scope; passed as `*Sel` to steps.
- Ctx is stack-allocated (`var ctx: Ctx = .{...}`). No heap allocation.
- Methods declared inside the Ctx struct body (`fn setupSelect(self: *Ctx, ...) !void`).

Examples: `examples/layer4/046-select_pool_event.zig`, `examples/layer4/028-select_mixed_sources.zig`.

### Coordinator with spawn + await (flat file)

When to use.
- A flat `pub fn run` that spawns concurrent workers (`io.concurrent`, `group.concurrent`) and awaits them.
- The spawn block and the await block together form one named step.

Code shape (single spawn+await step).  
```zig
pub fn run(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbh: MailboxHandle = try mailbox.new(io, allocator);
    defer { ... }

    try seedMailbox(mbh, allocator);
    try spawnAndAwaitWorkers(mbh, allocator, io);

    try helpers.expect(error.XFailed, ...);
    std.log.info("done", .{});
}

fn spawnAndAwaitWorkers(mbh: MailboxHandle, alloc: std.mem.Allocator, io: std.Io) !void {
    var ctx1: WorkerCtx = .{ .mbh = mbh, .alloc = alloc };
    var ctx2: WorkerCtx = .{ .mbh = mbh, .alloc = alloc };
    var fut1 = try io.concurrent(workerFn, .{&ctx1});
    var fut2 = try io.concurrent(workerFn, .{&ctx2});
    try fut1.await(io);
    try fut2.await(io);
}
```

Code shape (separate spawn and await steps).  
```zig
fn spawnWorkers(mbh: MailboxHandle, alloc: std.mem.Allocator, io: std.Io, group: *std.Io.Group) !void {
    for (0..N_WORKERS) |i| {
        group.concurrent(io, workerFn, .{ &worker_ctxs[i] }) catch return error.SpawnFailed;
    }
}

fn awaitWorkers(mbh: MailboxHandle, alloc: std.mem.Allocator, io: std.Io, group: *std.Io.Group) !void {
    try group.await(io);
    // verify results
}
```

- ctx declarations, spawns, and awaits all live inside the named step — not inline in the coordinator.
- Coordinator sees one or two calls. Flow is visible without opening the step.
- If spawn and await are tightly coupled (no coordinator logic between them), merge into one step.
- If coordinator logic falls between spawn and await, use two steps.

Examples: `examples/layer4/017-minimal_master.zig`, `examples/layer4/054-pool_fan_out.zig`.

### Master composition

When to use.
- A story or service has more than one coordination boundary.

The shape.
- Each Master owns its resources and coordinates their lifecycle.
- A Master is a state struct plus a loop function — not inlined into `run`.
- `run` is thin: initialize resources, start Masters, await shutdown in order.

Two Masters in the pilot story.
- Network Master — an `Io.Select` loop. Owns the buffer pool as a backpressure source. Fills buffers, routes `StreamContext` to the ready queue.
- Worker set — an `Io.Group`. Each worker receives a `StreamContext`, encodes, returns the buffer to the pool, sends an `EncodedSegment` to storage.
- Storage task — a single-mailbox loop. Receives `EncodedSegment`, logs, frees.

Code shape (thin run).  
```zig
pub fn run(allocator: std.mem.Allocator, io: std.Io) !void {
    // 1. initialize shared resources: pool, mailboxes
    // 2. start Masters: storage task, worker group, network loop
    // 3. await shutdown in mandatory order
}
```

- The coordination logic of each Master lives in its own function.
- `run` shows the startup order and the shutdown order — nothing else.

Example: `stories/video_transcoder/video_transcoder.zig`.

### Mailbox + Pool integration

When to use.
- Separate lifecycle from transport.

Pattern.  
```
Pool
   │
 get
   │
 work
   │
send
   │
Mailbox
```

### Full Layer-4 architecture

Pattern.  
```
          Io.Select
               │
      ┌────────┴────────┐
      │                 │
  Mailbox          Pool events
      │                 │
      └────────┬────────┘
               │
            Master
               │
         Io.Group workers
```

Purpose.
- Event-driven coordination.
- Worker parallelism.
- Transport that never loses an item.
- Automatic backpressure.
