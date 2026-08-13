# Matryoshka API Reference — Zig 0.16



> Function descriptions in this reference serve as the source for `///` Zig doc comments in the implementation.

Matryoshka is a small infrastructure toolkit.  
It provides three independent tools:

- **polynode** — type identity
- **mailbox** — message passing
- **pool** — reuse of items, through hooks

Applications combine these blocks to create:
- coordinators
- workers
- services
- pipelines
- other higher-level architectures

Every object follows the same rule: one place, one state, at any moment.

Matryoshka moves handles from one place to another.  
Everything transported is a `ItemHandle` (`*PolyNode`):
- events
- requests
- mailboxes
- pools

A `Slot` (`?ItemHandle`) is where a handle lives while it is yours.

---

## One place, one state

```text
Slot (holds a handle)            Empty Slot

+-------------------+            +-------------------+
|                   |            |                   |
|    ItemHandle     |            |       null        |
|                   |            |                   |
+-------------------+            +-------------------+

  Slot = ?ItemHandle               Slot = null
```

### What is an ItemHandle?

`ItemHandle` is a pointer to an embedded `PolyNode`.
- Every user type embeds a `PolyNode`.
- `ItemHandle` points to that embedded node.
- Matryoshka only sees the handle — not the surrounding type.

Why `ItemHandle`, not `NodeHandle`:
- `ItemHandle` describes what the caller holds — a matryoshka item, not how it's built.
- `NodeHandle` leaked an implementation detail — the intrusive list node inside `PolyNode` — into a name meant for callers who never touch that detail.
- Bare `handle` is fine as shorthand once the type is clear from context — most of this reference uses it that way already. Short variable name: `ih` (was `nh`).

```text
User object                      Infrastructure object

+------------------+             +------------------+
|      Event       |             |     Mailbox      |
|------------------|             |------------------|
| poly: PolyNode   |             | poly: PolyNode   |
| code: i32        |             | ...              |
+------------------+             +------------------+
        |                                |
        v                                v
   ItemHandle                     *Mbox
   (*PolyNode)                    (= ItemHandle)
```

All handles are `ItemHandle`. Specialized names are aliases:

```text
ItemHandle = *PolyNode
    ├── *Mbox = ItemHandle
    ├── *Pool    = ItemHandle
    └── (any user handle)

Slot = ?ItemHandle
```

---

## polynode

Types and functions for type identity.

```zig
const polynode = @import("matryoshka").polynode;

// typical usage:
var slot: polynode.Slot = &event.poly;   // slot holds the node
slot = null;                              // slot is empty
```

### Types

```zig
pub const PolyTag = struct { _: u8 = 0 };

pub const PolyNode = struct {
    node: std.DoublyLinkedList.Node,
    tag:  *const anyopaque,
};

pub const ItemHandle = *PolyNode;
pub const Slot = ?ItemHandle;
pub const ItemList = struct { ... };
```

One item, zero-or-one, many:

- `ItemHandle` — one item.
- `Slot` — zero or one item.
- `ItemList` — many items.

### Functions

```zig
pub fn reset(n: *PolyNode) void
```
- Clears intrusive link pointers (`prev`, `next` to null).
- `ItemList.popFirst` calls it for you. Needed by hand only for `ItemList._list`.

```zig
pub fn is_linked(n: *PolyNode) bool
```
- Returns true if the node has neighbours (`prev` or `next` is set).
- Not a membership test. `std.DoublyLinkedList` never sets the links of a
  list's only member, so a list of exactly one reports false.
- The `!is_linked` asserts in `Mbox.send`, `Pool.put`, `PolyHelper.destroy`,
  `PolyHelper.moveFromSlot` and every `ItemList` insert catch the multi-element  
  case and are blind for a list of one.
- A false result means nothing about whether the item is held somewhere.

### ItemList

The toolkit's list type. Holds a `std.DoublyLinkedList` inside, speaks  
`ItemHandle` outside.

Returned by `Mbox.receive_batch` and `Mbox.close`. Taken by  
`Pool.put_all`. Carried by `Pool.Hooks.on_put` and `Pool.Hooks.on_close`.

```zig
pub fn append(self: *ItemList, ih: ItemHandle) void
pub fn prepend(self: *ItemList, ih: ItemHandle) void
pub fn appendFromSlot(self: *ItemList, slot: *Slot) void
pub fn prependFromSlot(self: *ItemList, slot: *Slot) void
pub fn insertAfter(self: *ItemList, existing: ItemHandle, ih: ItemHandle) void
pub fn insertBefore(self: *ItemList, existing: ItemHandle, ih: ItemHandle) void
pub fn popFirst(self: *ItemList) ?ItemHandle
pub fn popLast(self: *ItemList) ?ItemHandle
pub fn remove(self: *ItemList, ih: ItemHandle) void
pub fn first(self: *const ItemList) ?ItemHandle
pub fn last(self: *const ItemList) ?ItemHandle
pub fn isEmpty(self: *const ItemList) bool
pub fn len(self: *const ItemList) usize
pub fn iterator(self: *const ItemList) Iterator
pub fn concat(self: *ItemList, other: *ItemList) void
pub fn moveFromList(list: *std.DoublyLinkedList) ItemList
pub fn moveToList(self: *ItemList) std.DoublyLinkedList
```

- `popFirst` returns `?ItemHandle` and calls `polynode.reset` before returning.
  A popped handle is never linked.
- `popLast` is the same at the other end.
- `remove` takes one item out wherever it sits, and calls `polynode.reset` too.
  Use it instead of reaching into `_list`. This list must hold the item.
- `first` / `last` return `?ItemHandle` and remove nothing. A list of one
  returns the same item from both.
- `append`, `prepend`, `insertAfter`, `insertBefore` take `ItemHandle` — no
  `&x.poly.node`.
- `appendFromSlot` / `prependFromSlot` take the item out of a `Slot` and leave
  it empty. Use them whenever the item is in a Slot; `append` and `prepend`  
  stay for a stack item, which has no Slot to empty.
- Both assert the Slot holds an item. An insert is not a `defer` target, so it
  follows `Mbox.send` rather than `Pool.put`.
- Under runtime safety every insert asserts twice on the new item: the list does
  not already hold it, and `!is_linked`. `_holds` walks this list and sees the  
  list of one that `is_linked` cannot; `is_linked` reads the item and sees a  
  *different* list that the walk cannot. Neither is complete. Together they  
  cover more. `insertAfter` / `insertBefore` also assert `existing` is in the  
  list and is not the item being inserted.
- O(n) per insert under safety builds. Nothing outside them.
- `remove` asserts the list holds the item.
- `moveFromList` asserts the std header it is handed is consistent — `first` and
  `last` are both null or both set.
- `concat` asserts `other != self`, and returns early on the same list twice.
  The assert is `unreachable` outside safety builds, and `concatByMoving` would  
  ring the items and clear the header, losing every one of them.
- `len` forwards std's walk. O(n). The mailbox and pool keep their own counters
  for this reason; `len` never replaces them.
- `iterator` walks without removing. Items stay linked, no `reset`.
- `concat` moves every item of `other` in and leaves `other` empty.
- `moveFromList` / `moveToList` cross to a plain std list. Both empty the
  source, both O(1). There is no copy form — a header copy aliases.

```zig
while (batch.popFirst()) |ih| {
    const ev: *Event = EventPolyHelper.fromPoly(ih) orelse return error.WrongTag;
}
```

#### ItemList.Iterator

```zig
pub fn next(self: *Iterator) ?ItemHandle
```
- Non-destructive. Yields each `ItemHandle` in order, removes nothing.

#### ItemList._list

The plain std list this `ItemList` holds.

- Use the `ItemList` methods instead. Tests that manipulate raw links use this
  field.
- An item taken out this way keeps its old `prev`/`next`. `popFirst` did not
  run, so `polynode.reset` did not either — call it yourself.

### One place, one state — read-only ops

These operations never move a handle:
- tag checks
- typed casts
- `@fieldParentPtr` recovery

Read-only inspections of an existing node.

### Defining user types — manual step by step

Every PolyNode-based type needs four things:
- A struct with an embedded `poly: PolyNode` field.
- A unique tag address for runtime type identity.
- A way to check the tag before casting.
- A way to cast from `*PolyNode` back to `*YourType`.

This section builds each piece manually. Understanding this is the foundation  
for everything in Matryoshka.

---

#### Step 1 — Define the struct

Embed `poly: PolyNode`. This is the hook that lets Matryoshka see your type.

```zig
pub const Event = struct {
    poly: PolyNode,
    code: i32,
};
```

What the memory looks like:

```text
Event instance
+---------------------------+
| poly: PolyNode            |
|   +---------------------+ |
|   | node: List.Node     | |
|   |   prev: ?*List.Node | |
|   |   next: ?*List.Node | |
|   |tag: *const anyopaque| |
|   +---------------------+ |
| code: i32                 |
+---------------------------+
```

Why: Matryoshka never sees `Event`. It only sees `*PolyNode`.  
The `poly` field is the bridge between your type and the infrastructure.

---

#### Step 2 — Create a unique tag

A tag is just an address. Two different variables have two different addresses.  
Same variable always has the same address.

```zig
var _event_tag: PolyTag = .{};
pub const EVENT_TAG: *const anyopaque = &_event_tag;
```

Why `var` not `const`: a mutable global has a guaranteed unique runtime address.  
`const` may be deduplicated by the linker.

Why it's unique: each `var` declaration occupies its own memory location.  
`&_event_tag` is that location's address. No two `var` declarations share an address.

```text
Memory layout (two types):

_event_tag:  [address 0x1000]  PolyTag
_sensor_tag: [address 0x1008]  PolyTag

EVENT_TAG  = 0x1000   (unique)
SENSOR_TAG = 0x1008   (unique, different from EVENT_TAG)
```

---

#### Step 3 — Set the tag at construction

When you create an instance, store the tag in `poly.tag`.

```zig
var ev: Event = .{ .code = 42 };
ev.poly = .{ .node = .{}, .tag = EVENT_TAG };
```

What happened:

```text
Before                          After

Event                           Event
+------------------+            +------------------+
| poly: PolyNode   |            | poly: PolyNode   |
|   node: {null}   |            |   node: {null}   |
|   tag: undefined |            |   tag: EVENT_TAG |
| code: 42         |            | code: 42         |
+------------------+            +------------------+
```

Why: the tag is how you identify what type a `*PolyNode` points into.  
Without it, you cannot safely cast.

---

#### Step 4 — Get a pointer to the embedded PolyNode

This is how your type enters the Matryoshka world.

```zig
const poly: *PolyNode = &ev.poly;
```

Now Matryoshka can work with `poly`. It does not know about `Event`.

```text
ev: Event                        poly: *PolyNode
+------------------+                    |
| poly: PolyNode   | <-----------------+
|   node: {null}   |
|   tag: EVENT_TAG |
| code: 42         |
+------------------+
```

---

#### Step 5 — Check the tag before casting

You have a `*PolyNode`. You need to know what it points into.  
Compare the tag:

```zig
if (poly.tag == EVENT_TAG) {
    // safe to cast to *Event
}
```

Why check first: `@fieldParentPtr` does not validate anything.  
If you cast a Sensor's PolyNode to `*Event`, you get garbage.  
The tag check is the only runtime safety you have.

```text
poly.tag == EVENT_TAG ?

  YES → this PolyNode is inside an Event → safe to cast
  NO  → this PolyNode is inside something else → do not cast
```

---

#### Step 6 — Cast back to the outer type

`@fieldParentPtr` recovers the containing struct from a pointer to its field.

```zig
const recovered: *Event = @fieldParentPtr("poly", poly);
```

What `@fieldParentPtr` does:

```text
poly: *PolyNode
      |
      v
+------------------+
| poly: PolyNode   |  <-- poly points here
|   ...            |
| code: 42         |
+------------------+
^
|
recovered: *Event      <-- @fieldParentPtr subtracts the field offset
```

The field name `"poly"` is validated at compile time.  
The offset calculation is done at compile time.  
Runtime cost: one pointer subtraction.

---

#### Step 7 — Two-level recovery (from list node)

Inside a mailbox or pool, items are linked via `std.DoublyLinkedList`.  
The list operates on `*DoublyLinkedList.Node`, not `*PolyNode`.  
`ItemList.popFirst` performs this conversion, so user code never does.

Recovery is two steps:

```zig
// Step 1: List.Node → PolyNode (done inside mailbox/pool)
const poly: *PolyNode = @fieldParentPtr("node", list_node_ptr);

// Step 2: PolyNode → user type (done in user code, after tag check)
const ev: *Event = @fieldParentPtr("poly", poly);
```

```text
list_node_ptr: *List.Node
      |
      v
+---------------------------+
| poly: PolyNode            |
|   +---------------------+ |
|   | node: List.Node     | | <-- list_node_ptr points here
|   |   prev, next        | |
|   | tag: EVENT_TAG      | |
|   +---------------------+ |
| code: 42                  |
+---------------------------+
^           ^
|           |
|           poly: *PolyNode    (Step 1: @fieldParentPtr("node", list_node_ptr))
|
ev: *Event                     (Step 2: @fieldParentPtr("poly", poly))
```

---

#### Complete manual example

All steps together:

```zig
// Define type
pub const Event = struct {
    poly: PolyNode,
    code: i32,
};

// Create unique tag
var _event_tag: PolyTag = .{};
pub const EVENT_TAG: *const anyopaque = &_event_tag;

// Create and initialize
var ev: Event = .{ .code = 42 };
ev.poly = .{ .node = .{}, .tag = EVENT_TAG };

// Get PolyNode pointer
const poly: *PolyNode = &ev.poly;

// Check tag
if (poly.tag == EVENT_TAG) {
    // Cast back
    const recovered: *Event = @fieldParentPtr("poly", poly);
    // recovered.code == 42
}
```

This works. But every type needs the same boilerplate:
- A `var _xxx_tag` declaration.
- A `const XXX_TAG` pointer.
- A tag check before every cast.
- An init that sets the tag.

---

### PolyHelper — all of the above, generated

`PolyHelper` generates the tag, check, identification functions, and init for any PolyNode type.  
One call replaces all the manual boilerplate.

```zig
pub fn PolyHelper(comptime T: type) type
```

- `T` must have a field `poly: PolyNode`. Compile error otherwise.
- Returns a namespace of generated declarations.

#### What PolyHelper generates

```zig
pub const TAG: *const anyopaque
```
- Unique runtime address for type `T`.
- Same as the manual `var _tag: PolyTag = .{}; const TAG = &_tag;` pattern.

```zig
pub fn isIt(tag: *const anyopaque) bool
```
- Returns `tag == TAG`.
- Same as the manual `poly.tag == EVENT_TAG` check.

Two directions, and two kinds of access.

- In — `toPoly`. Your type to the toolkit. Cannot fail.
- Out — `fromPoly`, `fromSlot`, `moveFromSlot`. The toolkit to your type.
  Each checks the tag.

Within the outbound direction the names say what happens to the Slot.

- Inspection — `fromPoly`, `fromSlot`. Leaves the Slot full.
- Extraction — `moveFromSlot`. Leaves the Slot empty.

```zig
pub fn toPoly(self: *T) *PolyNode
```
- Returns `&self.poly`.
- The inverse of `fromPoly`.
- Cannot fail. `T` is known at compile time, so there is no tag to check.
- No `must` variant and no optional return, for the same reason.
- Never modifies the item.
- Use it wherever the toolkit wants an `ItemHandle`: `Mbox.send`,
  `Pool.put`, a Slot assignment.
- `Slot` is `?ItemHandle`, so the result coerces into a Slot with no
  separate accessor.
- Prefer it to a hand-written `&x.poly`. The field name stays inside
  `PolyHelper`, where `validatePolyType` and `@fieldParentPtr` already keep it.

```zig
pub fn fromPoly(node: *PolyNode) ?*T
```
- Returns `null` if the runtime tag does not match.
- Returns `@fieldParentPtr("poly", node)` if it does.
- Never modifies the node.
- For infrastructure code that works with `*PolyNode` directly (mailbox, pool, list walks).
- Needs a node whose type is not known statically. If the static type is
  already `*T`, there is nothing to recover and no reason to call it.

```zig
pub fn mustFromPoly(node: *PolyNode) *T
```
- Same as `fromPoly`, but panics (`orelse unreachable`) if the tag does not match.

```zig
pub fn fromSlot(slot: *const Slot) ?*T
```
- Returns `null` if the Slot is empty or the tag does not match.
- Does not empty the Slot.
- Takes `*const Slot` — it cannot clear the Slot even by mistake.
- Returns a mutable `*T`. Most callers set or read a field through it.
- For application code that works with Slots (examples, tests, stories).

```zig
pub fn mustFromSlot(slot: *const Slot) *T
```
- Same as `fromSlot`, but panics if the Slot is empty or the tag does not match.

```zig
pub fn moveFromSlot(slot: *Slot) ?*T
```
- Takes the item out of the Slot.
- Returns `null` if the Slot is empty or the tag does not match.
- On success the Slot is left empty.
- On failure the Slot is unchanged.
- Asserts the item is not linked into a list, like every other consuming
  operation (`Mbox.send`, `Mbox.receive`, `Pool.put`, `destroy`).
- No `must` variant. It mutates its argument, and hiding failure behind
  `unreachable` would make the state change less obvious.
- Use it instead of hand-written `slot.?` + `slot = null`. That form skips the
  tag check.

```zig
pub fn init(self: *T) void
```
- Sets `self.poly = .{ .node = .{}, .tag = TAG }`.
- Same as the manual init in Step 3.

#### Usage

```zig
pub const Event = struct {
    poly: PolyNode,
    code: i32,
};

pub const EventPolyHelper = polynode.PolyHelper(Event);
```

Naming convention: `XxxPolyHelper = polynode.PolyHelper(Xxx)`.

#### The same example, now with PolyHelper

```zig
// Create and initialize (Step 3 is now one call)
var ev: Event = .{ .code = 42 };
EventPolyHelper.init(&ev);

// Get PolyNode pointer (Step 4, no hand-written field access)
const poly: *PolyNode = EventPolyHelper.toPoly(&ev);

// Identify and recover (Steps 5+6 combined, returns null on wrong tag)
const recovered: *Event = EventPolyHelper.mustFromPoly(poly);
// recovered.code == 42
```

The round trip above is there to line the two columns up. Real code calls  
`toPoly` to hand an item to a Mailbox or a Pool, and `fromPoly` on the way  
back out, where the static type is gone.

```text
Manual                              With PolyHelper

var _event_tag: PolyTag = .{};      (generated inside PolyHelper)
const EVENT_TAG = &_event_tag;      EventPolyHelper.TAG

poly.tag == EVENT_TAG               EventPolyHelper.isIt(poly.tag)

&ev.poly                            EventPolyHelper.toPoly(&ev)
                                       → *PolyNode (cannot fail)

if (poly.tag == EVENT_TAG)          EventPolyHelper.fromPoly(poly)
  @fieldParentPtr("poly", poly)       → ?*Event (null if wrong tag)

// slot: ?*PolyNode                 EventPolyHelper.fromSlot(&slot)
                                       → ?*Event (null if slot empty or wrong tag)

ev.poly = .{.node=.{},.tag=TAG};    EventPolyHelper.init(&ev)
```

Same operations. Same runtime cost. Less boilerplate. Compile-time validation.

See `examples/items/` for the pattern.

### PolyHelper — create and destroy

These two functions exist only when `T` does not declare `no_create_destroy`.  
They collapse the three-step alloc+init+slot pattern into one call.

```zig
pub fn create(allocator: std.mem.Allocator, slot: *Slot) !void
```
- Asserts `slot.* == null`.
- Allocates `T`.
- Zero-initializes.
- Calls `init`.
- Sets `slot.*` to point to the new node.

```zig
pub fn destroy(allocator: std.mem.Allocator, slot: *Slot) void
```
- If `slot.* == null`: returns immediately (no-op).
- Asserts node is not linked.
- Sets `slot.*` to null before freeing — prevents use-after-free.
- Frees the memory.

#### Old pattern vs new

```text
Old (manual):                        New (PolyHelper.create):

  const ev = try alloc.create(T);     try EventPolyHelper.create(alloc, &slot);
  ev.* = .{};
  EventPolyHelper.init(ev);
  slot.* = &ev.poly;
```

```text
Old (manual):                        New (PolyHelper.destroy):

  alloc.destroy(                       EventPolyHelper.destroy(alloc, &slot);
    EventPolyHelper.mustFromSlot(&slot));  // null-safe, clears slot
  slot.* = null;
```

#### comptime selection — no_create_destroy

Some types must not expose `create`/`destroy`.

```zig
const no_create_destroy = void{};
```

If `T` declares this field, `PolyHelper(T)` generates only: `TAG`, `isIt`, `toPoly`, `fromPoly`, `mustFromPoly`, `fromSlot`, `mustFromSlot`, `moveFromSlot`, `init`.

Infrastructure types (`_Mailbox`, `_Pool`) declare `no_create_destroy`.  
They create and destroy themselves.  
Generating `create`/`destroy` for them would be wrong.

```text
PolyHelper(T)
  │
  ├── @hasDecl(T, "no_create_destroy") == false
  │     → TAG, isIt, toPoly, fromPoly, mustFromPoly, fromSlot, mustFromSlot, moveFromSlot, init, create, destroy
  │
  └── @hasDecl(T, "no_create_destroy") == true
        → TAG, isIt, toPoly, fromPoly, mustFromPoly, fromSlot, mustFromSlot, moveFromSlot, init
```

### stdlib compatibility

PolyNode embeds `std.DoublyLinkedList.Node`.
- No custom list type.
- No adapter.
- Every PolyNode-based item carries the standard intrusive links.

Batch operations use `polynode.ItemList`:
- `mailbox.close()`
- `mailbox.receive_batch()`
- `pool.put_all()`

Walk results with `popFirst()` — standard Zig, nothing Matryoshka-specific.

**Warning**:
- `std.DoublyLinkedList.popFirst()` does NOT clear the node's `prev`/`next` links.
- `ItemList.popFirst()` does — it calls `polynode.reset` before returning.
- Call `polynode.reset(poly)` after popping, before re-sending the item or checking `polynode.is_linked`.
- Skipping reset causes false positives from `is_linked` and assert failures in pool/mailbox assert guards.


---

## mailbox

Sends handles between tasks.

The mailbox holds. It never touches.

- No inspection, no copy, no free.
- Internally a list of handles. It allocates and frees exactly one thing —
  itself.

So every item it holds goes back to a caller:

| edge | who ends up holding the item |
|------|------------------------------|
| `receive`, `try_receive` | the receiver |
| `send`, `send_oob` returning `error.Closed` | the sender — the slot is unchanged |
| `receive_batch` | the caller, as a list |
| `close` | the caller, as a list |

Releasing them is the caller's job. Free them, or put them back into a pool —  
which one is knowledge the mailbox does not have and never had.

The mailbox does not care whether you closed it, except `destroy`. Every  
other method returns `error.Closed` and stays a valid object. `destroy`  
makes closedness a precondition and panics on an open mailbox.

Contrast with `pool`, which does touch items, through your hooks.

```zig
const mailbox = @import("matryoshka").mailbox;

// typical usage:
var slot: polynode.Slot = &event.poly;
try inbox.send(&slot);              // slot is now null
try inbox.receive(&slot, null);     // slot is now non-null
```

### Usual flow

Four steps. Two set up, two take down.

```zig
const mbx = try mailbox.new(io, alloc);   // 1. create
defer mailbox.destroy(mbx, alloc);        // 4. free the mailbox itself

// 2. use it: send and receive, from any number of tasks
try mbx.send(&slot);
try mbx.receive(&slot, null);

// 3. close it, and release what comes back
var left = mbx.close();
items.freeList(&left, alloc);
```

1. **Create.**
   - `mailbox.new(io, alloc)` returns a `*Mbox`.
   - Internally the mailbox uses `Io` synchronisation objects.
   - `Io` should be Threaded.
2. **Use.**
   - Any task may send.
   - Any task may receive.
   - The mailbox is the only shared thing.
   - The items passing through it are never shared.
3. **Close.**
   - `close` returns an `ItemList`.
     - Everything still queued.
     - Regular and OOB together.
   - The list is yours. Release it.
     - Free the items.
     - Or put them back into a pool.
   - After `close`:
     - Every other method returns `error.Closed`.
     - The mailbox stays a valid object.
4. **Destroy.**
   - `mailbox.destroy(mbx, alloc)` frees the mailbox itself.

Close before destroy.

- Always.
- `destroy` makes closedness a precondition.
- It panics on an open mailbox.

`destroy` is not optional.

- The items are one allocation. The mailbox is another.
- Releasing the list from `close` frees the items.
- Skipping `destroy` leaks the mailbox.

Teardown is the sharpest difference between the two.

- A mailbox returns its items to the caller.
- A pool passes them to `on_close`.

### send — the handle moves out

```text
Before                           After

sender Slot                      sender Slot
+-------------------+            +-------------------+
|    ItemHandle     |            |       null        |
+-------------------+            +-------------------+

mbx.send(&slot)  ───►      Mailbox holds ItemHandle
```

### receive — the handle moves in

```text
Before                           After

receiver Slot                    receiver Slot
+-------------------+            +-------------------+
|       null        |            |    ItemHandle     |
+-------------------+            +-------------------+

mbx.receive(&slot, null)   Receiver holds ItemHandle
```


### Types

```zig
pub const Mbox = struct { ... };
```

Application code holds `*Mbox` and calls methods on it. The struct fields are  
internal.

A mailbox is also a PolyNode — `toPoly`/`fromPoly` cross the border. A mailbox  
can be:
- sent through another mailbox
- stored in pools
- embedded into larger structures

Same rules as application items.

### Functions

```zig
pub fn new(io: Io, alloc: std.mem.Allocator) !*Mbox
```
- Creates a new mailbox.
- Stores `io` internally.

```zig
pub fn send(self: *Mbox, slot: *Slot) error{Closed}!void
```
- Appends handle to tail.
- Moves the handle — `slot.*` set to null.
- On `error.Closed` the slot is unchanged — the sender still holds the item.
- Assert:
  - `slot.* != null`
  - `!polynode.is_linked(slot.*)`

```zig
pub fn receive(self: *Mbox, slot: *Slot, timeout_ns: ?u64) (error{ Closed, Timeout, Wakeup } || Cancelable)!void
```
- Blocks until handle available.
- `null` timeout = wait forever.
- `timeout_ns = 0` returns `error.Timeout` immediately — equivalent to `try_receive`.
- Moves the handle — `slot.*` set to non-null.
- OOB handles arrive first (front of queue).
- `wakeUpAll()` called while blocked here — returns `error.Wakeup`, `slot.*` stays null.
- Multiple concurrent receivers compete for each handle.
- One receiver gets it.
- Order among waiters depends on the Io runtime — not guaranteed FIFO.
- Assert:
  - `slot.* == null`

```zig
pub fn try_receive(self: *Mbox, slot: *Slot) error{Closed}!bool
```
- Non-blocking.
- Returns true if handle received, false if queue empty.
- Assert:
  - `slot.* == null`

```zig
pub fn receive_batch(self: *Mbox) error{Closed}!polynode.ItemList
```
- Non-blocking.
- Takes everything from the queue at once.
- Returns an empty `ItemList` if queue is currently empty.
- Does not wait. Does not return error for empty.
- The caller holds every item in the list — same duty as after `close()`.

```zig
pub fn wakeUpAll(self: *Mbox) error{Closed}!void
```
- Wakes every receiver currently blocked in `receive()` — no item is sent, nothing is queued.
- Blocked receivers return `error.Wakeup`.
- Future receivers (those that call `receive()` after `wakeUpAll()` returns) are not affected.
- Distinct from `close()`: the mailbox is not torn down, and the effect does not persist for
  receivers that start later.

```zig
pub fn close(self: *Mbox) polynode.ItemList
```
- Can be called more than once.
- Returns remaining handles as list (empty list on second call).
- Collects all handles still in the queue.
- Wakes up any receivers waiting on the mailbox.
- The caller holds every item in the returned list, and must release them —
  free them, or put them back into a pool.

Run the release unconditionally:

```zig
var rem: polynode.ItemList = mbx.close();
// release every item in `rem`
```

`close` can be called more than once, and an empty list costs nothing, so no call site has to  
work out whether the mailbox was emptied first. Never write  
`_ = mbx.close()` — it drops items the mailbox handed back, and those items  
keep their list links, so `send` will reject them.

```zig
pub fn destroy(mbx: *Mbox, alloc: std.mem.Allocator) void
```
- Frees the mailbox.
- Must be closed first.
- Calling destroy on an open mailbox is a programming error (panic).

```zig
pub fn is_it_you(tag: *const anyopaque) bool
```
- Returns true if tag identifies a *Mbox.

### Error sets

| Error | Meaning |
|-------|---------|
| `error.Closed` | Mailbox was closed via `close()` |
| `error.Timeout` | `timeout_ns` expired (only when non-null) |
| `error.Canceled` | Waiting operation was canceled |
| `error.Wakeup` | `wakeUpAll()` woke this receiver — no item, mailbox stays open |

### Event source helpers

Mailbox as event source for `Io.Select` and `Io.Future`.

Cancel and close in concurrent tasks:
- Mailbox closed — blocked receivers wake with `error.Closed`.
- Task canceled — the operation returns `error.Canceled`.

#### Types

```zig
// nested in Mbox
pub const Result = union(enum) {
    item: ItemHandle,
    closed: void,
    timeout: void,
    canceled: void,
    wakeup: void,
};
```

- The handle is inside the result, not behind a pointer. No `*Slot` is shared across threads.
- When you get `.item`, the handle is yours. The mailbox no longer holds it.

#### Functions

```zig
pub fn receiveResult(mbx: *Mbox, timeout_ns: ?u64) Mbox.Result
```
- Blocking function. No error return — maps all outcomes to `Mbox.Result` variants.
- Primary building block for Select integration:
  ```zig
  try select.concurrent(.inbox, mailbox.receiveResult, .{mbx, null});
  ```
- Also usable with `io.concurrent` or `group.concurrent`.

```zig
pub fn receive_future(self: *Mbox, timeout_ns: ?u64) ConcurrentError!Io.Future(Mbox.Result)
```
- Thin wrapper: `return mbx.*.io.concurrent(receiveResult, .{mbx, timeout_ns})`.
- No heap allocation — args copied by the runtime before `concurrent` returns.
- Returns a Future for direct await or `Io.Group` use.
- Returns `error.ConcurrencyUnavailable` on single-threaded backends.

#### Cancel behavior

- On `error.Canceled`, returns `.canceled` — the mailbox remains open.
- Closing is the Master's responsibility.

#### When to use

**`select.concurrent` pattern** (primary):  
```zig
try select.concurrent(.inbox, mailbox.receiveResult, .{mbx, null});
const event = try select.await();
switch (event) {
    .inbox => |r| switch (r) { ... },
    ...
}
```

**`receive_future` pattern** (direct await or Group):  
```zig
const fut = try mbx.receive_future(null);
const result = try fut.await(io);
```

**Bridging to external Io**: one `Io.Select` loop combines mailbox, timers, sockets, pool availability.
- Matryoshka sources use `receiveResult` / `getWaitResult` via `select.concurrent`.
- External sources use their own blocking functions via `select.concurrent`.
- Direct push: `select.queue.putOneUncancelable(io, value)` for immediate events.

### Advanced: OOB (out of the box)

```zig
pub fn send_oob(self: *Mbox, slot: *Slot) error{Closed}!void
```
- Inserts handle after last OOB handle.
- FIFO among OOBs, all OOBs before regular handles.
- Moves the handle — `slot.*` set to null.
- Assert:
  - `slot.* != null`
  - `!polynode.is_linked(slot.*)`


OOB ordering:

```
send(R1), send(R2):       [R1, R2]                oob=0
send_oob(O1):             [O1, R1, R2]            oob=1
send(R3):                 [O1, R1, R2, R3]        oob=1
send_oob(O2):             [O1, O2, R1, R2, R3]   oob=2
receive → O1:             [O2, R1, R2, R3]        oob=1
receive → O2:             [R1, R2, R3]            oob=0
```

---

## pool

Reuse of items, decided by user supplied hooks.

Pool is not storage.

- It answers one question: is a reusable item available right now.
- It signals backpressure through that answer.
- What happens to an item on `put` is entirely up to the hooks.

The pool touches items — through your hooks. It creates, resets, keeps or  
destroys, but every one of those is a hook doing it, never the pool deciding.  
This is the difference from `mailbox`, which never touches an item at all.

A closed pool gives items back:

- `put` is a no-op and leaves the slot unchanged.
- `put_all` stops at the first refusal and leaves the rest in the list.

Either way the caller still holds those items and must release them. Check  
the slot after `put`, and check the list after `put_all`.

`close` is the other difference. It collects everything held and passes the  
list to `on_close`, so the hook releases it — where a mailbox returns the  
list to the caller and leaves the releasing to them.

The pool does not care whether you closed it, except `destroy`, which panics  
on an open pool.

```zig
const pool = @import("matryoshka").pool;

// typical usage:
var slot: polynode.Slot = null;
try pl.get(EVENT_TAG, .available_or_new, &slot);   // slot is now non-null
pl.put(&slot);                                      // slot is now null (if kept)
```

### Usual flow

Five steps. Three set up, two take down.

- The extra step is `init`.
- A pool without hooks cannot create anything.

```zig
const pl = try pool.new(io, alloc);   // 1. create
defer pool.destroy(pl, alloc);        // 5. free the pool itself
try pl.init(my_hooks);                // 2. register hooks

// 3. use it
try pl.get(EVENT_TAG, .available_or_new, &slot);
pl.put(&slot);

pl.close();                           // 4. on_close releases what is left
```

1. **Create.**
   - `pool.new(io, alloc)` returns a `*Pool` with no hooks.
   - Nothing works yet.
2. **Register hooks.**
   - `init(hooks)` once, right after `new`.
   - The hooks are the pool.
     - `on_get` creates.
     - `on_put` decides whether an item is kept.
     - `on_close` releases.
   - Skip this and the first `get` has no way to make an item.
3. **Use.**
   - `get` asks whether a reusable item is available right now.
   - `put` offers one back.
   - Check the slot after `put`.
     - A refusal leaves it non-null.
     - You still hold the item.
4. **Close.**
   - `close` collects everything the pool holds.
   - It passes the list to `on_close`.
   - Nothing comes back to you.
   - After `close`:
     - `put` is a no-op.
     - Your slot is left unchanged.
5. **Destroy.**
   - `pool.destroy(pl, alloc)` frees the pool itself.

Close before destroy.

- Always.
- `destroy` panics on an open pool.

`destroy` is not optional.

- `on_close` releases the items.
- The pool struct is a separate allocation.
- Only `destroy` frees it.

Teardown is the sharpest difference between the two.

- A pool passes its items to `on_close`.
- A mailbox returns them to the caller.

### Flow diagram

```text
new()
  ↓
pool with no hooks
  ↓ init(hooks)
EMPTY pool

get() [available_or_new, pool empty]     get() [available_or_new, pool has items]
  ↓ on_get creates item                    ↓ item moved from free-list
IN_FLIGHT (with caller)                  IN_FLIGHT (with caller)

put() [on_put keeps]      put() [on_put destroys]
  ↓                         ↓
HELD (pool free-list)     FREE (caller frees)

get() [available_only or available_or_new]
  ↓
IN_FLIGHT (with caller)

close()
  ↓ on_close receives full list of HELD items → caller frees each
FREE
  ↓ destroy(pl, alloc)
the pool itself is freed
```

### Types

```zig
pub const Pool = struct { ... };
```

Application code holds `*Pool` and calls methods on it. The struct fields are  
internal.

A pool is also a PolyNode — `toPoly`/`fromPoly` cross the border. A pool  
can be:
- sent through a mailbox
- embedded into larger structures

Same rules as application items.

```zig
pub const GetMode = enum {
    available_or_new,    // use stored handle if available, otherwise call on_get to create
    new_only,            // always call on_get with slot.* == null to create fresh
    available_only,      // use stored handle only; if empty, return error.NotAvailable
};

pub const GetError = error{
    Closed,
    NotAvailable,
    NotCreated,
};
```

### Pool.Hooks

```zig
// nested in Pool
pub const Hooks = struct {
    ctx:      *anyopaque,
    tags:     []const *const anyopaque,
    on_get:   *const fn (ctx: *anyopaque, tag: *const anyopaque, in_pool_count: usize, slot: *Slot) void,
    on_put:   *const fn (ctx: *anyopaque, in_pool_count: usize, slot: *Slot) ?polynode.ItemList,
    on_close: *const fn (ctx: *anyopaque, list: *polynode.ItemList) void,
};
```

**`in_pool_count` semantics**
- `on_get`: count **after** removal — items remaining with this tag.
- `on_put`: count **before** addition — items already stored with this tag.
- Both values are **hints** — read under lock, passed to a hook running without lock;
  the pool may have changed by the time the hook reads the value.

**Hook concurrency**
- Hooks are called **outside the pool mutex**.
- Multiple threads may invoke hooks simultaneously — the pool does not serialize them.

**Advice for hook implementers**
- If your hook touches shared state, protect it.
- Example: use `Io.Mutex` and call `lockUncancelable` to acquire it.
  Hooks return `void` — `lock` (cancelable) is not an option here.
- Obtain `io` from the surrounding context that holds the pool; do not acquire it inside the hook.
- `CappedPoolHooks` in `examples/hooks/CappedPoolHooks.zig` is the reference implementation of these rules.

### Functions

```zig
pub fn new(io: Io, alloc: std.mem.Allocator) !*Pool
```
- Creates a new pool.
- Stores `io` internally.

```zig
pub fn destroy(pl: *Pool, alloc: std.mem.Allocator) void
```
- Frees the pool.
- Must be closed first.
- Calling destroy on an open pool is a programming error (panic).

```zig
pub fn init(self: *Pool, hooks: Pool.Hooks) !void
```
- Registers hooks.
- Called once after `new`.
- Assert:
  - Hooks tags not empty, each tag not null.
  - Pool not already closed.

```zig
pub fn get(self: *Pool, tag: *const anyopaque, mode: GetMode, slot: *Slot) GetError!void
```
- Non-blocking acquisition.
- Calls `on_get` hook.
- Moves the handle — `slot.*` set to non-null on success.
- Assert:
  - `slot.* == null`
  - Pool initialized.
  - Tag registered.

```zig
pub fn get_wait(self: *Pool, tag: *const anyopaque, slot: *Slot, timeout_ns: ?u64) (GetError || Cancelable || error{Timeout})!void
```
- Blocking acquisition.
- `null` timeout = wait forever.
- `timeout_ns = 0` returns `error.Timeout` immediately.
- Logically equivalent to `get(.available_only)`, but a different error (`error.Timeout` vs `error.NotAvailable`).
- Intentional: `get_wait` always uses the timeout error set, regardless of the timeout value.
- Calls `on_get` hook.
- Assert:
  - `slot.* == null`
  - Pool initialized.
  - Tag registered.

```zig
pub fn put(self: *Pool, slot: *Slot) void
```
- Returns handle to pool.
- `slot.* == null` → returns immediately. No hook call. No assert on tag.
- **Open pool**:
  - Calls `on_put` hook.
  - `on_put` picks the outcome — matryoshka does not mandate any of them:
    - **deleted, nothing returned** — hook frees the item, `slot.*` set to null, nothing added to the pool.
    - **returned as-is** — hook leaves the item's data untouched, `slot.*` stays non-null, pool holds it.
    - **returned after reset** — hook resets the item's data before keeping it, `slot.*` stays non-null.
    - **deleted, a different item returned** — hook frees the original and puts a different item in `slot.*`.
  - `slot.*` stays non-null exactly when an item — original or replacement — is kept in the pool; it's null when nothing is kept.
  - `on_put` also returns `?ItemList` — items to add alongside
    `slot`. `null` or empty: nothing extra. Non-empty: each item is added  
    the same way `slot`'s item is — same checks, same assert on foreign  
    tag. See Composite Items below.
- **Closed pool**:
  - Returns immediately, no hook call.
  - `slot.*` stays non-null — caller keeps the handle.
- Assert (when slot.* != null):
  - `!polynode.is_linked(slot.*)`

**No sequence guarantee.**

- The outcome of `put` is entirely hook-policy-driven.
- A call pattern like "put three times, then get three times" carries no fixed count, identity, or ordering guarantee.
- What comes back — how many items, in what state, whether they're the same items that were put — depends on the hooks, not on the shape of the call sequence.
- This repo's own example hooks (`examples/hooks/`) follow one specific convention: reset to default values on `put`.
- That convention is our examples' choice, not a rule matryoshka imposes.

### Composite Items

An item may hold other pooled items.

Before the parent item enters the pool, `on_put` can return them as an  
extra `ItemList` alongside `slot`. The pool adds every item in  
that list the same way it adds `slot`'s item.

The hook is responsible for handing back only valid, unlinked,  
correctly-tagged items — the pool does not validate that they form a  
real composite.

The pool does not distinguish between simple and composite items.

```zig
pub fn put_all(self: *Pool, list: *polynode.ItemList) void
```
- Returns batch of handles to pool.
- Pops from caller's list.
- Transfer is not atomic with respect to `close()`.
- If the pool closes mid-batch: items already transferred are passed to `on_close`; items not yet transferred stay in the caller's list.
- Restoration order when closed mid-batch may differ from original order.
- Assert:
  - Each node's tag registered in pool's tag set.

```zig
pub fn close(self: *Pool) void
```
- Can be called more than once.
- Collects all handles from all per-tag free-lists.
- Calls `on_close` once with the full list.
- Broadcasts to wake blocked `get_wait` callers.

```zig
pub fn is_it_you(tag: *const anyopaque) bool
```
- Returns true if tag identifies a *Pool.

### Error sets

| Error | Meaning |
|-------|---------|
| `error.Closed` | Pool was closed via `close()` |
| `error.NotAvailable` | `available_only` mode, no stored handle |
| `error.NotCreated` | `on_get` was called but did not return a handle |
| `error.Timeout` | `timeout_ns` expired (only when non-null, `get_wait` only) |
| `error.Canceled` | Waiting operation was canceled (`get_wait` only) |

### Event source helpers

Pool as event source for `Io.Select` and `Io.Future`.

Cancel and close in concurrent tasks:
- Pool closed — blocked callers wake with `error.Closed`.
- Task canceled — the operation returns `error.Canceled`.

When a handle becomes available, the Master can react. This is the job-pool pattern:
- Worker returns a handle.
- Master is notified.
- Master submits new work.

#### Types

```zig
// nested in Pool
pub const Result = union(enum) {
    item: ItemHandle,
    closed: void,
    timeout: void,
    canceled: void,
    not_created: void,
};
```

- The handle is inside the result, not behind a pointer. No `*Slot` is shared across threads.
- When you get `.item`, the handle is yours. The pool no longer holds it.
- Re-spawn the event source after handling each result.

#### Functions

```zig
pub fn getWaitResult(pl: *Pool, tag: *const anyopaque, timeout_ns: ?u64) Pool.Result
```
- Blocking function. No error return — maps all outcomes to `Pool.Result` variants.
- Primary building block for Select integration:
  ```zig
  try select.concurrent(.pool, pool.getWaitResult, .{pl, TAG, null});
  ```
- Also usable with `io.concurrent` or `group.concurrent`.

```zig
pub fn get_wait_future(self: *Pool, tag: *const anyopaque, timeout_ns: ?u64) ConcurrentError!Io.Future(Pool.Result)
```
- Thin wrapper: `return p.*.io.concurrent(getWaitResult, .{pl, tag, timeout_ns})`.
- No heap allocation — args copied by the runtime before `concurrent` returns.
- Returns a Future for direct await or `Io.Group` use.
- Returns `error.ConcurrencyUnavailable` on single-threaded backends.

#### Cancel behavior

- On `error.Canceled`, returns `.canceled` — the pool remains open.
- Closing is the Master's responsibility.

### Hook discipline

- Hooks run outside the pool's internal lock.
- The pool updates its own state first, then releases the lock, then calls your hook.
- Your hook code does not block other pool operations.
- `on_get`:
  - Called for every `get` and `get_wait` call regardless of mode or whether an item was found in the free-list.
  - If `slot.*` is non-null on entry: the item was recycled from the free-list — reinitialize it.
  - If `slot.*` is null on entry: no item was available — create a new one or leave null (creation failed).
  - Must either leave `slot.* == null` (creation failed) OR set `slot.*` to a valid node with the same tag that was requested.
  - Returning an item with a different tag is a programming error (assert in Debug/ReleaseSafe).
- `on_put`:
  - Set `slot.*` to null = destroy.
  - Leave non-null = keep in pool.
  - Return value: `?ItemList` of extra items. `null`/empty =
    nothing extra. Non-empty = each item added like `slot`'s. See  
    Composite Items above.
- `on_close`:
  - Receives `*ItemList`.
  - Walks via `popFirst()`, frees each handle.
- Hook reentrancy is forbidden. From inside any hook, do not:
  - call `get`, `get_wait`, `put`, `put_all`, `close`, or `destroy` on the same pool
  - block or wait on any condition
  - allocate in a way that could recursively trigger pool operations
  - Not a deadlock — hooks run outside the lock.
  - Contract violation — the pool cannot manage what it holds if hooks change it concurrently.

---

## Tag identity — class, not instance

`PolyHelper(T)` generates one static `_tag: PolyTag` per type `T` at comptime.  
`TAG` is a pointer to that static — the same address for every instance of `T`.

Tag dispatch (`is_it_you`, `isIt`, `fromPoly`) answers one question: **"is this a T?"**  
It does not answer: "which T?" or "what role does this T play?"

For user-defined types (Event, Sensor, etc.):
- Tag identifies the class.
- Instance fields carry the role. The user adds a `kind` or `role` field to discriminate.

For infra handles (*Mbox, *Pool):
- `_Mailbox` and `_Pool` are private structs. The user cannot add fields.
- Tag identifies the class only. No per-instance role information is accessible.
- **Instance identity**: resolved by pointer comparison against known handles.
  E.g. `received == worker_mbx` identifies which specific mailbox arrived.
- **Role**: established by protocol — the channel the handle arrived on, message
  ordering, or prior agreement between sender and receiver.

### Transporting infra handles — valid patterns

**Worker-finish-signal pattern**

Master creates `worker_mbx`, spawns a worker via `io.concurrent` and passes `worker_mbx` as parameter.  
Worker processes items until a shutdown signal, then:
- Sends `worker_mbx` back to master's inbox (unclosed) as the finish signal.
- Exits.

Master receives a PolyNode from its inbox:
- `mailbox.is_it_you(received.*.tag)` — confirms class (it is a mailbox).
- `received == worker_mbx` — confirms instance (it is the expected worker mailbox).
- Master closes and destroys `worker_mbx`.
- Master awaits the worker's future (cleanup only — the mailbox return was the logical finish signal).

This pattern replaces relying on the future await as a completion signal, or a separate shutdown message, with a handle handoff.

**Wrapper pattern** (for tag-level role discrimination)

When tag dispatch must distinguish roles, wrap the handle in a user-defined PolyNode struct:

```zig
const WorkerInbox = struct {
    poly: PolyNode,
    handle: *Mbox,
};
pub const WorkerInboxPolyHelper = polynode.PolyHelper(WorkerInbox);
```

`WorkerInboxPolyHelper.TAG` is distinct from `Mbox.TAG`.  
The receiver dispatches on `WorkerInboxPolyHelper.TAG` and finds the embedded handle.

---

## Slot-based programming

The slot rule governs every acquisition and transfer.

The slot rule:
- Never overwrite a non-null slot.
- Always start with `var slot: Slot = null`.
- All acquisition APIs assert `slot.* == null` on entry. Writing to a non-null slot panics.
- Transfer clears the slot: sender sets `slot.* = null`. After transfer, slot is null.
- Applies universally: pool get/put, mailbox receive, heap allocation — every combination.

**Exception — event-source helpers**:

- `receiveResult` and `getWaitResult` do not take a `*Slot` parameter.
- They move the handle via the returned union value (`Mbox.Result.item`, `Pool.Result.item`) instead.
- The caller extracts the handle from the union and holds it from that point.
- This is an intentional exception to the slot-pointer pattern.

### Why acquisition APIs assert null

Every acquisition API has this check:

```zig
std.debug.assert(slot.* == null);
```

Overwriting a non-null slot would lose the previous item with no error signal.  
The assert catches this immediately.

### Why cleanup operations accept null

`Pool.put` and `PolyHelper.destroy` check null and return early:

```zig
if (slot.* == null) return;
```

This makes defer-before-acquisition safe.

### Slot states

```text
Slot states

  null ──── acquire ────► non-null
    ▲                        │
    │                        │
    ├──── transfer ──────────┘   (sender clears: slot.* = null)
    │
    └──── cleanup (no-op) ──────  (Pool.put, PolyHelper.destroy: null → return)
```

### Moving a handle clears the slot

```text
Before transfer                  After transfer

  Slot (sender)                    Slot (sender)
  ┌─────────────┐                  ┌─────────────┐
  │ ItemHandle  │                  │    null     │
  └─────────────┘                  └─────────────┘
                                           │
  mbx.send(&slot)                    │ slot.* = null
                                           │
                     Mailbox ◄─────────────┘
                     now holds ItemHandle
```

### Defer-before-acquisition is safe

```text
Code order:                      Execution when acquire fails:

  var slot: Slot = null;              slot = null
  defer pl.put(&slot);          acquire fails
  try pool.get(..., &slot);           defer runs: Pool.put sees null → no-op
  // work                          ✓ nothing lost

                                 Execution when item is transferred:

                                   slot = null (after acquire: slot is non-null)
                                   mbx.send(&slot)  → slot = null
                                   defer runs: Pool.put sees null → no-op
                                   ✓ item transferred, not double-recycled
```

---

## Cooperative cleanup patterns

These patterns follow from the slot rule.  
Place cleanup before acquisition.  
The defer becomes a no-op when the slot is null — either because acquisition failed, or because the item was transferred.

### Pattern 1 — defer-put-early (pool item)

```zig
var slot: Slot = null;
defer pl.put(&slot);              // no-op if slot == null
try pl.get(TAG, .new_only, &slot);
// ... work ...
// on transfer: slot = null → defer runs as no-op
// on no transfer: defer recycles item
```

Put before get — safe because Pool.put is a no-op on null.

If the pool may be closed while the item is held, Pool.put leaves slot non-null (caller retains  
held). Add a fallback destroy to avoid a leak:

```zig
var slot: Slot = null;
defer EventPolyHelper.destroy(alloc, &slot); // fallback: frees if Pool.put left slot non-null
defer pl.put(&slot);                   // primary: recycles to pool (clears slot on success)
// defers run LIFO: Pool.put first, then destroy (no-op if Pool.put cleared slot)
```

### Pattern 2 — defer-destroy-early (heap item via PolyHelper)

```zig
var slot: Slot = null;
defer EventPolyHelper.destroy(allocator, &slot);   // no-op if slot == null
try EventPolyHelper.create(allocator, &slot);
// ... work ...
// on transfer: slot = null → defer runs as no-op
// on no transfer: defer frees item
```

Destroy before create — safe because PolyHelper.destroy is a no-op on null.

### Pattern 3 — defer for received mailbox item

```zig
var slot: Slot = null;
defer if (slot) |poly| helpers.freeItem(poly, allocator);
try mbx.receive(&slot, null);
// dispatch on slot.?.*.tag, process item
// item stays non-null until explicitly transferred or freed
```

Cleanup covers both the error path (receive failed) and the normal path (item processed and freed).

### Pattern 4 — transfer clears the slot

```zig
var slot: Slot = null;
defer pl.put(&slot);
try pl.get(TAG, .new_only, &slot);
// fill item ...
try mbx.send(&slot);   // send sets slot.* = null
// defer runs: Pool.put sees null → no-op
// result: item is in mailbox, not recycled to pool
```

Transfer and cleanup are not in conflict — transfer pre-empts cleanup by clearing the slot.

### Pattern summary

```text
Pattern 1 (pool item)            Pattern 2 (heap item)

  null ──► get ──► non-null        null ──► create ──► non-null
    ▲                │               ▲                   │
    │    put (defer) │               │  destroy (defer)  │
    └────────────────┘               └───────────────────┘
         (recycle)                          (free)

         transfer →                         transfer →
         slot = null                           slot = null
         defer: no-op                       defer: no-op
```

### No raw allocator calls on PolyNode-based types

In examples and tests, never use `allocator.create` / `allocator.destroy` directly on  
PolyNode-based user types (Event, Sensor, Timer, ShutdownCommand).

Use `PolyHelper.create`, `PolyHelper.destroy`, or `helpers.freeSlot` instead.

#### Violation

```zig
// WRONG — raw allocator on PolyNode-based type
const ev = try alloc.create(Event);
ev.* = .{};
EventPolyHelper.init(ev);
slot.* = &ev.poly;
// ... later ...
alloc.destroy(EventPolyHelper.mustFromSlot(&slot));
slot.* = null;
```

#### Correct

```zig
// CORRECT — PolyHelper.create/destroy
var slot: Slot = null;
defer EventPolyHelper.destroy(alloc, &slot);
try EventPolyHelper.create(alloc, &slot);
// ... dispatch: use helpers.freeSlot(&slot, alloc) per branch ...
```

#### Exempt

- `mailbox.zig`, `pool.zig` — allocating/freeing their own internal structs.
- `PolyHelper.create` / `PolyHelper.destroy` implementations.
- Pool hook bodies (`on_get`, `on_close`) — manage raw memory on behalf of pool.
- Non-PolyNode structs: worker context, hook context, allocator wrappers.

---

## matryoshka (root)

```zig
pub const polynode = @import("polynode.zig");
pub const mailbox = @import("mailbox.zig");
pub const pool = @import("pool.zig");
```

---

## Master (Layer 4) — intentionally not part of the API

No `master` module.  
No `Master` struct.  
By design.

Io creates tasks through `io.concurrent()`.  
Master is an Io task that follows the Matryoshka rules — the coordination boundary.  
It holds and composes the lower layers.

Applications build Masters from:

| What | Where it comes from |
|------|-------------------|
| Transport | `*Mbox` — one or more mailboxes |
| Item reuse | `*Pool` + `Pool.Hooks` — reuse and policy |
| Memory | `std.mem.Allocator` — who allocates and frees |
| Scheduling | `std.Io` — passed to `mailbox.new` and `pool.new` |
| Worker coordination | `io.concurrent()` → `Future`, or `Io.Group` |
| Cancellation | `Future.cancel(io)` or `group.cancel(io)` |
| Application state | Domain-specific — whatever the subsystem needs |

Both mailbox and pool are optional. Valid combinations:

```text
PolyNode only                        type identity without infrastructure
PolyNode + Mailbox                   type identity + message passing
PolyNode + Pool                      type identity + item reuse
PolyNode + Pool + Io.Select          item reuse + event sources (no mailbox)
PolyNode + Mailbox + Pool            transport + item reuse
PolyNode + Mailbox + Pool + Io.Select   full stack
```

A Master may be:  
```zig
const Server = struct { inbox: *Mbox, pool: *Pool, ... };
const Scheduler = struct { pool: *Pool, ... };  // no mailbox
const Pipeline = struct { stages: [3]*Mbox, ... };
fn main(init: std.process.Init) !void { ... }
```

Matryoshka provides the tools.  
The application assembles them.

### Io backend for Layer 4 tests and examples

Layer 1-3 tests use `std.Io.Threaded.global_single_threaded.*.io()` — no concurrency needed.

Layer 4 tests and examples need real concurrency (`io.concurrent`, `Io.Group`):
- Use `std.Io.Threaded.init(allocator, .{})` to get a real backend.
- Call `.deinit()` when done.

```zig
// In a Layer 4 test:
var threaded = try std.Io.Threaded.init(std.testing.allocator, .{});
defer threaded.deinit();
const io: std.Io = threaded.io();
```

```zig
// In a Layer 4 example (run function):
pub fn run(allocator: std.mem.Allocator, io: std.Io) !void {
    // io is passed in — examples never create the backend themselves
}
```

```zig
// In the test wrapper for a Layer 4 example:
test "17 - minimal master" {
    std.testing.log_level = .debug;
    var threaded = try std.Io.Threaded.init(std.testing.allocator, .{});
    defer threaded.deinit();
    const io: std.Io = threaded.io();
    try layer4.minimal_master.run(std.testing.allocator, io);
}
```

Key rules:
- `std.testing.io` — not used in this project, even in test files.
- `global_single_threaded` — Layer 1-3 only. Returns `error.ConcurrencyUnavailable` for `io.concurrent`.
- `Io.Threaded.init` — Layer 4 tests and example wrappers.
- Examples receive `std.Io` as a parameter. They never import or reference `std.testing`.

### Event sources

See **Addendums → Io 101** for the general `Future` → `Io.Select` pattern.

Matryoshka plugs into the same pattern:

```text
  mailbox.receiveResult ──► select.concurrent(.inbox, ...)  ──┐
  pool.getWaitResult    ──► select.concurrent(.pool, ...)   ──┼──► Io.Select.queue ──► Master dispatch
  Io.sleep              ──► select.concurrent(.timer, ...)  ──┤
  direct push           ──► select.queue.putOneUncancelable ──┘
```

- `mailbox.receiveResult` + `select.concurrent` — mailbox as Select event source.
- `pool.getWaitResult` + `select.concurrent` — pool as Select event source.
- `Mbox.receive_future` / `Pool.get_wait_future` — Future wrappers for direct await or `Io.Group`.
- Master calls `select.await()`, handles the result, re-spawns the source.

---

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

---

## Item states

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

## Invariants

These hold at all times, for every node in the system:

- A linked node belongs to exactly one container (mailbox queue or pool free-list). Never two at once.
- A Slot holds exactly one node. A null Slot holds nothing.
- A pool never holds a linked node — items in its free-lists are unlinked relative to other pools.
- A mailbox never holds a free node — only nodes currently in its queue.
- Every node is in exactly one place at all times: either with user code (via Slot) or with infrastructure (in queue or free-list). Never both.
- Tag identity is determined by pointer address alone. Never compare tag contents or names — compare only `==` on the pointer value.

---

## What cancellation leaves behind

When a cancellable operation returns `error.Canceled`:

- `Mbox.receive`: slot is unchanged — `slot.*` was `null` on entry and remains `null`. The mailbox retains any queued items.
- `Pool.get_wait`: slot is unchanged — `slot.*` was `null` on entry and remains `null`. The pool retains all free-list items.

Cancellation never closes the mailbox or pool. Closing is the caller's responsibility.

---

## Thread-safety contract

| Function | Concurrent callers | Notes |
|----------|--------------------|-------|
| `Mbox.send` | yes | Multiple senders safe |
| `Mbox.send_oob` | yes | Multiple senders safe |
| `Mbox.receive` | yes | One handle per waiter; scheduling order is runtime-dependent |
| `Mbox.try_receive` | yes | |
| `Mbox.receive_batch` | yes | Transfers whole queue atomically |
| `Mbox.close` | yes — once | Second call returns empty list |
| `mailbox.destroy` | no | Must happen after all users have stopped |
| `Pool.get` | yes | |
| `Pool.get_wait` | yes | One handle per waiter; scheduling order is runtime-dependent |
| `Pool.put` | yes | |
| `Pool.put_all` | yes | Thread-safe per item; batch is NOT atomic wrt close() — items transferred before close go to on_close; items not yet transferred stay in caller's list |
| `Pool.close` | yes — once | Second call is a no-op |
| `pool.destroy` | no | Must happen after all users have stopped |

---

## Complexity guarantees

| Function | Time complexity |
|----------|----------------|
| `Mbox.send` | O(1) |
| `Mbox.send_oob` | O(1) |
| `Mbox.receive` | O(1) |
| `Mbox.try_receive` | O(1) |
| `Mbox.receive_batch` | O(1) — transfers whole queue atomically |
| `Mbox.close` | O(n) — walks the queue |
| `Pool.get` | O(1) |
| `Pool.get_wait` | O(1) |
| `Pool.put` | O(1) |
| `Pool.put_all` | O(k) — k is the number of items in the list |
| `Pool.close` | O(n) — walks all per-tag free-lists |

---

## Contract violations

Programming errors.  
Checked via `std.debug.assert`:
- Active in Debug and ReleaseSafe.
- Removed in ReleaseFast and ReleaseSmall.

- **Wrong handle type** — passing a *Pool where *Mbox is expected, or vice versa.
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

---

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
- Layer 1 + Layer 2 — type identity + message passing, no item reuse
- Layer 1 + Layer 3 — type identity + item reuse, no message passing
- Layer 1 + Layer 2 + Layer 3 + Io — full stack (Master)

---

## Change log

API 12 (real pointers): `MailboxHandle` and `PoolHandle` are gone. `Mbox`  
and `Pool` are public structs with internal fields; application code holds  
`*Mbox` / `*Pool` and calls methods on the pointer. Companion types nest —  
`Mbox.Result`, `Pool.Result`, `Pool.Hooks`, `Pool.GetMode`, `Pool.GetError`.  
`new`, `destroy`, `receiveResult`, `getWaitResult` and `is_it_you` stay  
free functions on the module. Both types remain PolyNodes: `toPoly` in,  
`fromPoly` / `mustFromPoly` out.

API 11 (accessor rename): `fromNode`, `mustFromNode` and `toNode` become `fromPoly`, `mustFromPoly` and `toPoly`. `PolyNode` embeds `node: std.DoublyLinkedList.Node`, so "node" named two things at once, and the field the helper reaches is `poly`. Hard rename, no aliases. The Slot accessors keep their names.

API 10 (ItemList completion): `remove`, `popLast`, `first`, `last` and `insertBefore` added. `iterate` renamed to `iterator`, the std name — breaking, no shim. `concat` returns early on the same list twice, because its assert is `unreachable` outside safety builds and `concatByMoving` would ring the items and clear the header. Every insert now also asserts `!is_linked` on the new item, which sees a different list where the container walk cannot. `moveFromList` asserts the std header it is handed is consistent. `std.DoublyLinkedList` checks nothing; `ItemList` is where it is checked.

API 9 (intrusive safety): `ItemList.appendFromSlot` and `ItemList.prependFromSlot` added — they take the item out of a `Slot` and leave it empty, so the caller writes no `slot = null` line. `append`, `prepend` and `insertAfter` assert against the container's own contents under runtime safety. `concat` asserts its two arguments are different lists. `is_linked` is documented for what it computes: whether the node has neighbours, which is false for a list's only member.

API 8 doc-comment sync (rules-030): `ItemList._list` reworded — "underneath" and "on purpose" are banned words, and the entry now matches the field's doc comment in `src/polynode.zig`.

API 8: `ItemList` — the toolkit's list type. `Mbox.receive_batch`, `Mbox.close`, `Pool.put_all`, `Pool.Hooks.on_put`, and `Pool.Hooks.on_close` speak it instead of `std.DoublyLinkedList`. `popFirst` yields `ItemHandle` and clears the links, so `@fieldParentPtr` no longer appears in application code.


| Version | Date | Changes |
|---------|------|---------|
| 038 | 2026-08-13 | FLOW 1-1r. Both `Usual flow` sections rewritten in staccato. The wording of 037 was prose. Each numbered step is now a heading line with nested bullets under it, one fact per line, split at every colon, "and" and semicolon. The counting introductions are gone: "Four steps. Two set up, two take down." for `mailbox`, "Five steps. Three set up, two take down." for `pool`. The three trailing paragraphs on each side — close before destroy, `destroy` is not optional, teardown is the sharpest difference — are now a short lead line plus a bullet list, the same shape on both sides. No statement changed meaning. Code blocks, diagrams and every other section are untouched. |
| 037 | 2026-08-12 | FLOW 1-1. The canonical `Usual flow` text. `mailbox` gains a four-step account — create, use, close and release the returned list, destroy — and `pool` a five-step one, with `init(hooks)` as the step that was documented nowhere. Both state that close comes before destroy always, that `destroy` is not optional because the container is an allocation separate from the items, and that teardown is the sharpest difference between the two: a mailbox returns items to the caller, a pool passes them to `on_close`. The pool flow diagram gains `init` at the top and `destroy` at the bottom; its heading, which used the same word as the section below, is now `Flow diagram`. The section describing item states was named for two things it should not have been named for and is now `Item states`. One reworded sentence in `pool`: a closed pool *gives* items back. The new ban applies to the whole file, so nine other live uses went with it — the pool's one-line summary, the layer-combination table and both combination lists now say "item reuse", the `no_create_destroy` note says the two types create and destroy themselves, and the Slot diagram is `Slot states`. Older changelog rows are left as they are. |
| 036 | 2026-08-12 | PROSE 1 banned-word pass. One live hit: the `@fieldParentPtr` walkthrough diagram said `dll_node_ptr` where the surrounding text and code already said `list_node_ptr`. `dll` is banned — it clashes with Windows DLL. Changelog rows that name a banned word to record its earlier removal are left as they are; rewriting them would erase the record. |
| 035 | 2026-08-12 | MBOX 1. `mailbox` section opens with "The mailbox holds. It never touches." and the four edges that hand an item back to a caller; `close` documents the caller's release duty and bans `_ = mbx.close()`; `send`/`send_oob` document that `error.Closed` leaves the slot unchanged; `receive_batch` gets the same release duty. `pool` section gains the mirror statements: the pool touches items through hooks, a closed pool hands items back via `put`/`put_all`, and `close` releases through `on_close` rather than through the caller. Removed 15 documented asserts of the form `mailbox.is_it_you(mbx.*.tag)` / `pool.is_it_you(pl.*.tag)` — no such assert exists in `src/`, and neither struct has a `.tag` field. |
| 027 | 2026-07-28 | API 6. Renamed `identifyNodeAs`→`fromNode`, `mustIdentifyNodeAs`→`mustFromNode`, `identifySlotAs`→`fromSlot`, `mustIdentifySlotAs`→`mustFromSlot` — the old names described the implementation, not the caller's action. Hard rename, no aliases. Added `moveFromSlot(slot: *Slot) ?*T`: checks the tag, returns the item, clears the Slot on success, leaves it unchanged on failure, asserts the item is not linked. No `must` variant — it mutates its argument. PolyHelper section gains the inspection-vs-extraction split; `no_create_destroy` lists and diagram updated. |
| 023 | 2026-07-09 | INTR 7. `pool` section: "Pool is not storage" stated up front; `put`'s four hook-driven outcomes documented (deleted/no-return, returned as-is, returned after reset, deleted-and-replaced); added the no-fixed-sequence-guarantee caveat for put/get call patterns. |
| 022 | 2026-07-09 | New Mindset. Master connected to `io.concurrent()` up front — "Master is an architectural role" replaced with "Master is an Io task that follows the Matryoshka rules." No other content change. |
| 021 | 2026-07-07 | API 4. Renamed `NodeHandle` → `ItemHandle` throughout — the old name leaked the intrusive-node implementation detail. `*Mbox`/`*Pool` aliases unchanged in meaning. `### What is a NodeHandle?` renamed to `### What is an ItemHandle?`, with a naming-rationale note and the `handle`/`ih` shorthand convention. Historical Change-log rows referencing `NodeHandle` left as-is. |
| 020 | 2026-07-06 | DOC 18. Humanized the reference: dropped "ownership" framing throughout (section titles, diagrams, prose) in favor of plain language — a handle sits in exactly one place, in exactly one state, at any moment. Converted remaining prose paragraphs to staccato bullets. No content removed, no reordering, no new API surface.
| 019 | 2026-07-05 | DOC 10. Dependency-ordered re-partition — no content change. send/receive ownership diagrams moved from Ownership model into mailbox. Tag identity (class, not instance) moved out of polynode to its own section after pool. Slot-based programming and Cooperative cleanup patterns moved after pool — every function they reference is now introduced first.
| 018 | 2026-07-05 | DOC 9. Re-partitioned and reordered into a logical, teachable structure (was development-order). Generic `std.Io` material (Prolog, io.concurrent/Io.Group/Io.Select internals) moved to new `## Addendums` / `### Io 101` section at the end. Dropped the `Change manifest (NNN)` blocks (16 sections) — downstream-propagation notes fully subsumed by current main-body content, kept only as this Change log table. No information removed; no new API surface.
| 017 | 2026-07-05 | API 3. Added `mailbox.wakeUpAll()` — wakes every receiver currently blocked in `receive()` with `error.Wakeup`, no item sent, future receivers unaffected. `receive()` error set gains `error.Wakeup`. `Mbox.Result` gains `wakeup: void`. |
| 016 | 2026-07-02 | API 2. Renamed `cast`→`identifyNodeAs`, `mustCast`→`mustIdentifyNodeAs`. Added `identifySlotAs` and `mustIdentifySlotAs` for application code that works with Slots directly. Updated `no_create_destroy` diagram. Updated violation example in "No raw allocator calls". |
| 015 | 2026-06-28 | INTR 4 fixes. Bug 3.1: Pool.put_all thread-safety table corrected (NOT atomic wrt close). Bug 1.2: Pattern 1 extended with double-defer for closed-pool fallback. Bug 1.3: get_wait zero-timeout documents intentional error divergence from available_only. Bug 1.4: Slot rule exception note for receiveResult/getWaitResult. Bug 2.3: stdlib compatibility section — polynode.reset warning after popFirst(). |
| 014 | 2026-06-28 | INTR 2 thread-safe hooks + hook concurrency contract. CappedPoolCtx io/mutex/count fields. in_pool_count semantics. |
| 013 | 2026-06-28 | `## Prolog: std.Io` — corrected `Io.Select` description (Queue(U)+Group, not Future container). Updated event source diagram and added direct push pattern. Added `receiveResult` and `getWaitResult` as primary blocking functions. Updated `receive_future` and `get_wait_future` as thin wrappers (no heap allocation). Updated cancel contract table. Updated Master event source diagram. Added `#### Io.Select — internals` subsection (verified fields, select.concurrent mechanics, direct push, ICE agent reference). Added args-copying note to `#### io.concurrent`. Fixed `fires` → `runs` ×5 in slot-based programming code comments. |
| 012 | 2026-06-27 | New rule `### No raw allocator calls on PolyNode-based types` in `## Cooperative cleanup patterns`. Violation/correct/exempt code examples. |
| 011 | 2026-06-27 | New `## Slot-based programming` section: slot rule, lifecycle diagram, ownership-transfer diagram, defer-before-acquisition diagram. New `## Cooperative cleanup patterns` section: four patterns with code + diagrams. New `### PolyHelper — create and destroy` subsection: create/destroy functions, old-vs-new comparison, no_create_destroy comptime selection. Updated Pool.put: null slot is now a no-op (no-op bullet added, assert clarified). |
| 010 | 2026-06-26 | New `### io.concurrent and Io.Group — verified call syntax` subsection in Master section. Covers exact call patterns (verified from std/Io.zig + ICE agent), no-io-injection rule, worker return type constraint, Future resource rules, Io backend selection for Layer 4 tests and examples. |
| 009 | 2026-06-26 | Tag identity section: class vs instance, infra handles have no user-visible fields, worker-finish-signal pattern, wrapper pattern for role discrimination. |
| 008 | 2026-06-26 | Pool ownership flow diagram. Ownership invariants section. Cancellation ownership contract section. Thread-safety contract table. Complexity guarantees table. Zero timeout semantics in receive and get_wait. Multiple waiter fairness note. Strengthened hook reentrancy rules. |
| 001 | 2026-06-20 | Initial API reference (Proposal 8) |
| 002 | 2026-06-23 | Proposal 27: `MayItem` → `Slot`, `*PolyNode` → `NodeHandle`. Visual ownership model added to intro. `*Mbox = NodeHandle`, `*Pool = NodeHandle`. All "item" language updated to "handle" in descriptions. |
| 003 | 2026-06-23 | Proposal 28: Validation/assert specifications. `std.debug.assert` on every API function. `AlreadyInUse` removed from `GetError` (contract violation, not runtime error). Contract Violations section expanded. |
| 004 | 2026-06-23 | Proposal 29: `Pool.put` open/closed behavior clarified. Proposal 30: `receive_select` and `get_wait_select` removed — `Future` composes directly with `Io.Select`, dedicated Select adapters are unnecessary API surface. |
| 005 | 2026-06-24 | Proposal 31: Reformat for readability and `///` doc comment use. Cancel indicator rule. Cancel table corrected. Event source concept added to Master with diagrams. Mailbox Integration section merged into Event source helpers. Informal terms cleaned up. |
| 006 | 2026-06-24 | Proposal 32: Staccato rhythm for all prose. Every non-function section reformatted: short intro then bullets. Comma-separated lists broken into bullet lists. |

---

