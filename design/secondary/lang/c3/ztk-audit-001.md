# ztk audit (001)

Stage 3TK-1 of [3tk-staging-plan-001.md](backup/3tk-staging-plan-001.md).

Read-only evidence. Every claim names a file and a line range.

Purpose: be the single input for the portable specification, so 3TK-2 never
reopens `src/`.

Inputs read, and nothing else:

- `src/matryoshka.zig`, `src/polynode.zig`, `src/mailbox.zig`, `src/pool.zig`,
  `src/internal/cond_timeout.zig` — in full, doc comments included.
- `design/matryoshka-concepts-003.md`,
  `design/matryoshka-architecture-foundation-4-006.md`,
  `design/language-of-matryoshka.md`, `design/matryoshka-api-reference-042.md`,
  `design/patterns-029.md`, `design/matryoshka-zig-0.16-notes-003.md`,
  `kitchen/docs/addendums/slot-idiom.md`, `design/rules-049.md` Part 3.

Not read, by the plan's firewall: the `c3/` drafts, `STATUS-LOG.md`, the `d/`
and `odin/` folders.

Line numbers are of the file as it stands today. A signature quoted below is
copied, not paraphrased.

---

# 1. The public surface, verbatim

## 1.1 The root module — `src/matryoshka.zig`

Three modules and two aliases. Nothing else.

```zig
pub const polynode = @import("polynode.zig");   // line 20
pub const mailbox  = @import("mailbox.zig");    // line 21
pub const pool     = @import("pool.zig");       // line 22

pub const Mbox = mailbox.Mbox;                  // line 25
pub const Pool = pool.Pool;                     // line 28
```

- `src/matryoshka.zig:20-22` — the three tools.
- `src/matryoshka.zig:25`, `:28` — the two types application code keeps a
  pointer to.
- The file is 30 lines. There is no `Master` type anywhere in `src/`.

## 1.2 polynode — the types

`src/polynode.zig:62-89`.

```zig
pub const PolyTag = struct {                    // line 62
    _: u8 = 0,
};

pub const ItemHandle = *PolyNode;               // line 67

pub const PolyNode = struct {                   // line 83
    node: std.DoublyLinkedList.Node = .{},
    tag: *const anyopaque = undefined,
};

pub const Slot = ?ItemHandle;                   // line 89
```

- `PolyTag` — a one-byte struct. Its *address* is the type ID, never its
  contents (`src/polynode.zig:58-64`).
- `PolyNode` — links plus tag. Two fields (`:83-86`).
- `ItemHandle` — an alias of `*PolyNode` (`:67`). Same type, different intent:
  the toolkit transports it, the application opens it (`:69-82`).
- `Slot` — an optional handle (`:89`). Named a "container" for an ItemHandle.

## 1.3 polynode — the free functions

```zig
pub inline fn reset(node: *PolyNode) void       // line 99
pub inline fn is_linked(node: *PolyNode) bool   // line 114
```

- `reset` clears `prev` and `next` (`:99-102`).
- `is_linked` is true when the node has neighbours (`:114-116`).

## 1.4 `PolyHelper(T)`

`src/polynode.zig:141-355`. Two variants, chosen at compile time.

- Full variant: `:144-269`. Selected when `T` has no `no_create_destroy` decl.
- Reduced variant: `:271-353`. Selected when it does.
- The only difference is `create` and `destroy`. Everything else is duplicated
  verbatim (`:141-144`, `:270-271`).

Shared surface, both variants:

```zig
pub const TAG: *const anyopaque                          // :151 / :277
pub inline fn isIt(tag: *const anyopaque) bool           // :154 / :280
pub inline fn fromPoly(node: *PolyNode) ?*T              // :162 / :288
pub inline fn mustFromPoly(node: *PolyNode) *T           // :172 / :298
pub inline fn toPoly(self: *T) *PolyNode                 // :181 / :307
pub inline fn fromSlot(slot: *const Slot) ?*T            // :189 / :315
pub inline fn mustFromSlot(slot: *const Slot) *T         // :197 / :323
pub inline fn moveFromSlot(slot: *Slot) ?*T              // :209 / :335
pub inline fn init(self: *T) void                        // :221 / :347
```

Full variant only:

```zig
pub fn create(allocator: std.mem.Allocator, slot: *Slot) !void   // :231
pub fn destroy(allocator: std.mem.Allocator, slot: *Slot) void   // :253
```

The tag itself:

```zig
var _tag: PolyTag = .{};                        // :148 / :274
pub const TAG: *const anyopaque = &_tag;        // :151 / :277
```

- One mutable global per instantiation. `var`, not `const` — a mutable global
  has a unique runtime address, a `const` may be merged by the linker
  (`design/matryoshka-zig-0.16-notes-003.md:381-383`).
- Uniqueness across types comes from comptime memoization: `PolyHelper(Foo)`
  and `PolyHelper(Bar)` are different types, each with its own `_tag`
  (`matryoshka-zig-0.16-notes-003.md:384-386`).

Compile-time validation:

```zig
fn validatePolyType(comptime T: type) void      // :357-363
```

- Rejects a `T` with no `poly` field (`:358-359`).
- Rejects a `poly` field of the wrong type (`:361-362`).
- Names `T` in the error message. Runs before either variant is built
  (`:142`).

## 1.5 `ItemList` and `ItemList.Iterator`

`src/polynode.zig:379-603`.

```zig
pub inline fn popFirst(self: *ItemList) ?ItemHandle                      // :384
pub inline fn popLast(self: *ItemList) ?ItemHandle                       // :395
pub inline fn remove(self: *ItemList, ih: ItemHandle) void               // :406
pub inline fn first(self: *const ItemList) ?ItemHandle                   // :415
pub inline fn last(self: *const ItemList) ?ItemHandle                    // :424
fn _holds(self: *const ItemList, ih: ItemHandle) bool                    // :433
inline fn _checkInsert(self: *const ItemList, ih: ItemHandle) void       // :445
pub inline fn append(self: *ItemList, ih: ItemHandle) void               // :453
pub inline fn prepend(self: *ItemList, ih: ItemHandle) void              // :459
pub fn appendFromSlot(self: *ItemList, slot: *Slot) void                 // :468
pub fn prependFromSlot(self: *ItemList, slot: *Slot) void                // :478
pub inline fn insertAfter(self, existing: ItemHandle, ih: ItemHandle)    // :488
pub inline fn insertBefore(self, existing: ItemHandle, ih: ItemHandle)   // :501
pub inline fn isEmpty(self: *const ItemList) bool                        // :511
pub inline fn len(self: *const ItemList) usize                           // :521
pub inline fn iterator(self: *const ItemList) Iterator                   // :528
pub inline fn concat(self: *ItemList, other: *ItemList) void             // :540
pub fn moveFromList(list: *std.DoublyLinkedList) ItemList                // :554
pub fn moveToList(self: *ItemList) std.DoublyLinkedList                  // :568

pub const Iterator = struct {                                            // :575
    _next: ?*std.DoublyLinkedList.Node,
    pub inline fn next(self: *Iterator) ?ItemHandle                      // :579
};

_list: std.DoublyLinkedList = .{},                                       // :602
```

- `_list` is public in the Zig sense but documented as not-for-use
  (`:587-602`). Tests reach it; application code does not.
- There is no error set. No `ItemList` function can fail.

## 1.6 mailbox

`src/mailbox.zig`. The struct and its fields:

```zig
pub const Mbox = struct {                       // :40
    const no_create_destroy = void{};           // :41
    poly: polynode.PolyNode,                    // :43
    mutex: Io.Mutex,                            // :44
    cond: Io.Condition,                         // :45
    list: polynode.ItemList,                    // :46
    len: usize,                                 // :47
    closed: std.atomic.Value(bool),             // :48
    oob_count: usize,                           // :49
    oob_last: ?polynode.ItemHandle,             // :50
    wake_epoch: u64,                            // :51
    io: Io,                                     // :52
    alloc: std.mem.Allocator,                   // :53
```

The fields are reachable. The doc comment says they are internal
(`:38-39`). This matters for the port — see section 5.3.

Companion type:

```zig
pub const Result = union(enum) {                // :56
    item: polynode.ItemHandle,
    closed: void,
    timeout: void,
    canceled: void,
    wakeup: void,
};
```

Border crossings, all forwarding to `helper`:

```zig
pub const TAG: *const anyopaque = helper.TAG;                        // :65
pub inline fn toPoly(self: *Mbox) *polynode.PolyNode                 // :70
pub inline fn fromPoly(node: *polynode.PolyNode) ?*Mbox              // :77
pub inline fn mustFromPoly(node: *polynode.PolyNode) *Mbox           // :84
pub inline fn is_it_you(tag: *const anyopaque) bool                  // :89
pub inline fn fromSlot(slot: *const polynode.Slot) ?*Mbox            // :97
pub inline fn mustFromSlot(slot: *const polynode.Slot) *Mbox         // :104
pub inline fn moveFromSlot(slot: *polynode.Slot) ?*Mbox              // :113
```

Operations:

```zig
pub fn send(self: *Mbox, slot: *polynode.Slot) error{Closed}!void            // :129
pub fn send_oob(self: *Mbox, slot: *polynode.Slot) error{Closed}!void        // :174
pub fn receive(self: *Mbox, slot: *polynode.Slot, timeout_ns: ?u64)
    (error{ Closed, Timeout, Wakeup } || Io.Cancelable)!void                 // :232
pub fn try_receive(self: *Mbox, slot: *polynode.Slot) error{Closed}!bool     // :294
pub fn receive_batch(self: *Mbox) error{Closed}!polynode.ItemList            // :332
pub fn close(self: *Mbox) polynode.ItemList                                  // :382
pub fn wakeUpAll(self: *Mbox) error{Closed}!void                             // :419
pub fn receive_future(self: *Mbox, timeout_ns: ?u64)
    Io.ConcurrentError!Io.Future(Result)                                     // :433
```

Module-level free functions:

```zig
pub fn new(io: Io, alloc: std.mem.Allocator, slot: *polynode.Slot) !void     // :445
pub inline fn is_it_you(tag: *const anyopaque) bool                          // :468
pub fn destroy(mbx: *Mbox, alloc: std.mem.Allocator) void                    // :479
pub fn destroy_slot(slot: *polynode.Slot, alloc: std.mem.Allocator) void     // :496
pub fn receiveResult(mbx: *Mbox, timeout_ns: ?u64) Mbox.Result               // :514
const helper = polynode.PolyHelper(Mbox);                                    // :525
```

Error set of the whole module: `Closed`, `Timeout`, `Wakeup`, plus
`Io.Cancelable` (which supplies `Canceled`) and the allocator's error from
`new`.

## 1.7 pool

`src/pool.zig`. The struct and its fields:

```zig
pub const Pool = struct {                                            // :36
    const no_create_destroy = void{};                                // :37
    poly: polynode.PolyNode,                                         // :39
    mutex: Io.Mutex,                                                 // :40
    cond: Io.Condition,                                              // :41
    lists: std.AutoHashMapUnmanaged(*const anyopaque, ItemList),     // :42
    counts: std.AutoHashMapUnmanaged(*const anyopaque, usize),       // :43
    hooks: Hooks,                                                    // :44
    closed: std.atomic.Value(bool),                                  // :45
    io: Io,                                                          // :46
    alloc: std.mem.Allocator,                                        // :47
```

Companion types:

```zig
pub const GetMode = enum {                      // :50
    available_or_new,                           // :52
    new_only,                                   // :54
    available_only,                             // :56
};

pub const GetError = error{ Closed, NotAvailable, NotCreated };      // :60

pub const Hooks = struct {                                           // :90
    ctx: *anyopaque,                                                 // :91
    tags: []const *const anyopaque,                                  // :92
    on_get: *const fn (ctx: *anyopaque, tag: *const anyopaque,
                       in_pool_count: usize, slot: *Slot) void,      // :104
    on_put: *const fn (ctx: *anyopaque, in_pool_count: usize,
                       slot: *Slot) ?polynode.ItemList,              // :120
    on_close: *const fn (ctx: *anyopaque, list: *ItemList) void,     // :127
};

pub const Result = union(enum) {                // :138
    item: polynode.ItemHandle,
    closed: void,
    timeout: void,
    canceled: void,
    not_created: void,
};
```

Border crossings — the same eight names as `Mbox`, same order:
`TAG` `:147`, `toPoly` `:152`, `fromPoly` `:159`, `mustFromPoly` `:166`,
`is_it_you` `:171`, `fromSlot` `:179`, `mustFromSlot` `:186`,
`moveFromSlot` `:195`.

Operations:

```zig
fn init(self: *Pool) !void                                                   // :206
pub fn get(self: *Pool, tag: *const anyopaque, mode: GetMode,
           slot: *polynode.Slot) GetError!void                               // :226
pub fn get_wait(self: *Pool, tag: *const anyopaque, slot: *polynode.Slot,
    timeout_ns: ?u64) (GetError || Io.Cancelable || error{Timeout})!void     // :252
pub fn put(self: *Pool, slot: *polynode.Slot) void                           // :329
pub fn put_all(self: *Pool, list: *polynode.ItemList) void                   // :394
pub fn close(self: *Pool) void                                               // :428
pub fn get_wait_future(self: *Pool, tag: *const anyopaque, timeout_ns: ?u64)
    Io.ConcurrentError!Io.Future(Result)                                     // :459
```

Module-level free functions:

```zig
pub fn new(io: Io, alloc: std.mem.Allocator, hooks: Pool.Hooks,
           slot: *polynode.Slot) !void                                       // :471
pub inline fn is_it_you(tag: *const anyopaque) bool                          // :496
pub fn destroy(p: *Pool, alloc: std.mem.Allocator) void                      // :507
pub fn destroy_slot(slot: *polynode.Slot, alloc: std.mem.Allocator) void     // :526
pub fn getWaitResult(p: *Pool, tag: *const anyopaque,
                     timeout_ns: ?u64) Pool.Result                           // :543
```

Private helpers, not surface but needed by any port:

```zig
inline fn _add_returned_item(p: *Pool, item: polynode.ItemHandle) void       // :556
inline fn _get_available_or_new(p, tag, slot) Pool.GetError!void             // :565
inline fn _get_new_only(p, tag, slot) Pool.GetError!void                     // :592
inline fn _get_available_only(p, tag, slot) Pool.GetError!void               // :612
const helper = polynode.PolyHelper(Pool);                                    // :631
```

## 1.8 The internal timed wait

`src/internal/cond_timeout.zig`.

```zig
pub const WaitTimeoutError = Io.Cancelable || Io.Timeout.Error;   // :6
pub fn condition_waitTimeout(cond: *Condition, io: Io, mutex: *Mutex,
                             timeout: Io.Timeout) WaitTimeoutError!void   // :14
```

- Not exported from the root module. `src/matryoshka.zig:20-28` lists three
  modules and this is not one of them.
- Both `Mbox.receive` (`src/mailbox.zig:257`) and `Pool.get_wait`
  (`src/pool.zig:283`) call it.
- It exists because Zig 0.16 has no `Io.Condition.waitTimeout`
  (`src/internal/cond_timeout.zig:1`, `matryoshka-zig-0.16-notes-003.md:168-172`).

---

# 2. The invariants

Each one is stated where the code asserts it, or where a doc comment binds it.

## 2.1 The Slot Rule

The rule, in full: `design/rules-049.md:449-469`.

- Never overwrite a non-null Slot.
- A Slot starts as `null`.
- Acquisition asserts `slot.* == null` on entry.
- An acquisition that fails leaves the Slot unchanged.
- Transfer clears the Slot.
- Cleanup is a no-op on a null Slot.

Where the code asserts it — acquisition side:

| assert | file:line |
|---|---|
| `create` asserts empty | `src/polynode.zig:235` |
| `Mbox.receive` asserts empty | `src/mailbox.zig:233` |
| `Mbox.try_receive` asserts empty | `src/mailbox.zig:295` |
| `mailbox.new` asserts empty | `src/mailbox.zig:446` |
| `Pool.get` asserts empty | `src/pool.zig:227` |
| `Pool.get_wait` asserts empty | `src/pool.zig:253` |
| `pool.new` asserts empty | `src/pool.zig:472` |

Transfer side — a non-empty Slot is required, and cleared on success:

| assert / clear | file:line |
|---|---|
| `Mbox.send` asserts non-empty, clears at `:144` | `src/mailbox.zig:130` |
| `Mbox.send_oob` asserts non-empty, clears at `:196` | `src/mailbox.zig:175` |
| `appendFromSlot` asserts non-empty, clears at `:471` | `src/polynode.zig:469` |
| `prependFromSlot` asserts non-empty, clears at `:481` | `src/polynode.zig:479` |
| `moveFromSlot` clears on success only | `src/polynode.zig:215` |

Cleanup side — null is accepted and returns early:

| no-op on null | file:line |
|---|---|
| `PolyHelper.destroy` | `src/polynode.zig:257` |
| `Pool.put` | `src/pool.zig:330` |
| `mailbox.destroy_slot` | `src/mailbox.zig:497` |
| `pool.destroy_slot` | `src/pool.zig:527` |

The failure-leaves-it-unchanged half:

- `mailbox.new` — `errdefer alloc.destroy(mbx)` at `src/mailbox.zig:449`, and
  the Slot is written on the last line, `:464`.
- `pool.new` — three `errdefer` lines at `src/pool.zig:487-488` plus `:475`,
  the Slot written last at `:492`.
- `Mbox.send` on `error.Closed` returns before `slot.* = null`
  (`src/mailbox.zig:133`, `:139`).
- `moveFromSlot` returns `null` before clearing on a tag mismatch
  (`src/polynode.zig:211`).

The one documented exception: `receiveResult` and `getWaitResult` move the item
through the returned union, not through a `*Slot`
(`src/mailbox.zig:514-523`, `src/pool.zig:543-553`, `rules-049.md:466-469`).

## 2.2 `is_linked` and `reset`

- `is_linked` asks whether the node has neighbours. It is **not** a membership
  test (`src/polynode.zig:104-116`).
- The blind spot is stated in the code: a list of exactly one member reports
  false, and every `!is_linked` assert in the toolkit inherits that
  (`src/polynode.zig:107-113`).
- `reset` is the repair. `popFirst`, `popLast` and `remove` call it for the
  caller (`src/polynode.zig:387`, `:398`, `:409`). Reaching through `_list`
  does not, and the caller must call it by hand (`src/polynode.zig:91-98`,
  `:592-601`).

Every `!is_linked` assert:

| site | file:line |
|---|---|
| `moveFromSlot`, full variant | `src/polynode.zig:213` |
| `moveFromSlot`, reduced variant | `src/polynode.zig:339` |
| `PolyHelper.destroy` | `src/polynode.zig:259` |
| `ItemList._checkInsert` | `src/polynode.zig:448` |
| `Mbox.send` | `src/mailbox.zig:131` |
| `Mbox.send_oob` | `src/mailbox.zig:176` |
| `Pool.put` | `src/pool.zig:332` |
| `Pool._add_returned_item` | `src/pool.zig:557` |

## 2.3 The double check on insert

`src/polynode.zig:365-378`, `:439-450`.

- Every insert checks twice, under runtime safety only.
  - `_holds` — a walk of this list comparing node addresses
    (`src/polynode.zig:433-437`).
  - `is_linked` — a read of the item.
- Neither alone is enough. The walk sees the list-of-one that `is_linked`
  cannot; `is_linked` sees a *different* list that the walk cannot
  (`src/polynode.zig:370-376`).
- The walk makes an insert O(n) under safety builds, and nothing outside them
  (`src/polynode.zig:378`, `:446`).
- `std.DoublyLinkedList` checks nothing. `ItemList` is where it is checked
  (`src/polynode.zig:444`).

## 2.4 Table dispatch — the Slot, not the error, says where the item went

`design/patterns-029.md:566-613`, `rules-049.md` Part 7.

- A handler returns with the Slot null if it took the item, full if it did not.
- `error.NoHandler` on a table miss is not a defect: nothing was called and the
  item never left the Slot, so the caller frees it
  (`patterns-029.md:600-602`).
- A `switch` over tags does not compile, on any backend. A prong must be
  comptime-known; a tag is a linker-assigned address
  (`patterns-029.md:627-637`, `src/polynode.zig` has no switch on a tag).
- `isIt` and `==` work, because they need only to know which global the tag
  names (`patterns-029.md:635-637`).

This is a Zig-specific *obstacle*, not a Matryoshka invariant. A port whose
language can switch on a type ID may do so. The invariant it protects — one
handler per (receiver, tag) pair, the Slot carries the result — is portable.

## 2.5 Close before destroy

- `mailbox.destroy` panics on an open mailbox (`src/mailbox.zig:479-484`).
- `pool.destroy` panics on an open pool (`src/pool.zig:507-514`).
- Both are unconditional panics, in every build mode. Not asserts.
- Closedness is a precondition **here and nowhere else**: every other method
  returns `error.Closed`, or is a no-op, and stays a valid item
  (`src/mailbox.zig:476-478`, `src/pool.zig:505-506`).
- `close` may be called more than once, on both sides. The second call takes nothing and, for
  the pool, does not call `on_close` again (`src/mailbox.zig:387-390`,
  `src/pool.zig:433-436`).
- The check-and-set of `closed` is inside the mutex, so a preempted `close`
  caller cannot race a `destroy` (`src/mailbox.zig:386-391`,
  `src/pool.zig:432-437`).

## 2.6 The give-back rule

Every item a mailbox keeps goes back to a caller.

| edge | who ends up with the item | file:line |
|---|---|---|
| `receive`, `try_receive` | the receiver | `src/mailbox.zig:278`, `:314` |
| `send`/`send_oob` returning `error.Closed` | the sender, Slot unchanged | `:133`, `:178` |
| `receive_batch` | the caller, as a list | `:341-346` |
| `close` | the caller, as a list | `:393-402` |

- Releasing them is the caller's job. What the items are — heap items to free,
  pool items to give back — is knowledge the mailbox does not have and never had
  (`src/mailbox.zig:361-363`).
- Run the release unconditionally. An empty list costs nothing
  (`src/mailbox.zig:365-372`).
- `_ = mbx.close()` is named as the thing not to write. It drops items the
  mailbox gave back, and those items keep their list links, so `send` rejects
  them afterwards (`src/mailbox.zig:379-381`).

The pool is the mirror image, and this is the sharpest asymmetry in the toolkit:

- `Pool.close` collects everything and passes it to `on_close`. Nothing comes
  back to the caller (`src/pool.zig:419-452`).
- A closed pool refuses a `put` and leaves the Slot unchanged, so the caller
  still has the item (`src/pool.zig:337-340`, `:317-321`).
- `put_all` stops at the first refusal, puts the item back at the front of the
  caller's list, and returns. Check the list after the call
  (`src/pool.zig:408-416`, `:376-391`).
- The restored order after a mid-batch close may differ from the original
  (`src/pool.zig:387-388`).

## 2.7 The hook contract

`src/pool.zig:62-131`, and `matryoshka-api-reference-042.md:1420-1494`.

- The hooks *are* the pool's policy. A pool cannot exist without them — they
  are a parameter of `new`, not a later step (`src/pool.zig:471`, `:482`).
- The tag list must not be empty. Asserted in `init` (`src/pool.zig:208`).
- `init` grows both maps before writing either, so an out-of-memory fails
  cleanly (`src/pool.zig:210-218`).

`on_get` (`src/pool.zig:94-104`):

- Called on every `get`, in every mode. Not called by `get_wait`
  (`src/pool.zig:247`, `:565-610` vs `:252-294`).
- Slot non-null on entry: an item came from the free list — reinitialize it.
- Slot null on entry: create one, or leave it null to signal failure.
- Returning an item with a tag other than the requested one is a programming
  error. Asserted at `src/pool.zig:587` and `:607`.
- A null Slot after the hook becomes `error.NotCreated` (`:589`, `:609`).

`on_put` (`src/pool.zig:106-120`):

- Four outcomes, none mandated: deleted with nothing returned, given back
  as-is, given back after reset, deleted with a different item put in the Slot
  (`src/pool.zig:308-313`).
- A non-null Slot on return means one thing: an item is kept. Original or
  replacement (`src/pool.zig:314-315`).
- The return value is an optional extra `ItemList`. Each item in it is added
  the same way, with the same checks. This is how a composite item gives its
  parts back (`src/pool.zig:108-119`, `:363-368`).
- The pool does not check that they form a real composite, and does not
  distinguish composite from simple (`src/pool.zig:117-119`).
- No sequence guarantee. Put three times, then get three times — the count,
  the identity and the order are all hook policy
  (`src/pool.zig:324-328`).

`on_close` (`src/pool.zig:122-130`):

- Called once, with the full list of what remained.
- The hook is responsible for processing or destroying every item.
- Called **outside** the mutex, after `closed` is already set
  (`src/pool.zig:448-451`).

Hook concurrency (`src/pool.zig:75-89`):

- Hooks run outside the pool's mutex. `put` unlocks, calls `on_put`, relocks
  (`src/pool.zig:350-352`). Both `get` paths do the same (`:584-586`,
  `:604-606`).
- Several hooks may run at once, on different threads. The pool does not
  serialize them.
- A hook that touches shared state protects it itself.
- A hook must not call pool APIs, and must not block or wait. That is the
  contract, not a deadlock warning — the lock is not held while a hook runs
  (`src/pool.zig:82-85`).
- A hook returns void, so it has no way to report a cancelled lock. It must
  acquire one uncancelably (`src/pool.zig:86-89`).
- `in_pool_count` is a hint. It is read under the lock and used without it
  (`src/pool.zig:68-74`).
  - `on_get`: the count *after* removal.
  - `on_put`: the count *before* addition.

## 2.8 The transfer orders memory

`design/matryoshka-concepts-003.md:572-581`.

- Exclusive access has two halves. Possession is the visible one.
- The second half: the new holder sees every write the previous one made.
- Mailbox and pool publish through their own mutex. That is what carries it.
- So a holder reads the item's fields with plain loads. No atomics, no fences.
- This is why the library can assert on an item's internal state at all.
- It does not extend to an item two callers both believe they have. That
  mistake breaks the premise the guarantee is built on.

This is a **MUST** for any port. It is the reason the toolkit is safe without
locks around application data, and it is invisible in the signatures.

## 2.9 The atomic pre-lock fast path

Both types carry `closed: std.atomic.Value(bool)` and check it before taking
the mutex (`src/mailbox.zig:48`, `src/pool.zig:45`).

The shape, at every entry point:

```zig
if (self.*.closed.load(.acquire)) return error.Closed;   // no mutex taken
self.*.mutex.lockUncancelable(io);
defer self.*.mutex.unlock(io);
if (self.*.closed.load(.monotonic)) return error.Closed; // re-check under lock
```

- `src/mailbox.zig:133-139`, `:178-184`, `:235-251`, `:297-303`, `:333-339`,
  `:420-426`.
- `src/pool.zig:229`, `:255`, `:337`, `:569-572`, `:596-599`, `:617`.
- The double check closes a race: close may fire between the first check and
  the lock acquire (`matryoshka-zig-0.16-notes-003.md:415-417`).
- Ordering is not decoration. `.acquire` outside the lock, `.monotonic` inside
  it, `.release` on the store (`src/mailbox.zig:391`, `src/pool.zig:437`).

## 2.10 Cancel-protected versus cancelable

`matryoshka-zig-0.16-notes-003.md:264-309`.

- Only waits can be cancelled. Signal, broadcast and unlock never return
  `error.Canceled`.
- Cancelable, and only these two: `Mbox.receive` (`src/mailbox.zig:248`) and
  `Pool.get_wait` (`src/pool.zig:267`). Both take the lock with the cancelable
  `lock(io)`.
- Every other entry point takes it with `lockUncancelable(io)` — a cleanup path
  that must run to the end.
- `Pool.put` must be cancel-protected. A worker that gets `error.Canceled` from
  `receive` must give its item back reliably. If `put` could itself fail, the
  item would be lost with nothing keeping it. `put` returns `void`
  (`src/pool.zig:329`, `matryoshka-zig-0.16-notes-003.md:301-305`).
- `error.Canceled` is not `error.Closed`. Distinct causes, distinct meanings,
  never remapped (`matryoshka-zig-0.16-notes-003.md:310-322`).
- Cancellation leaves the Slot unchanged and the container untouched
  (`matryoshka-api-reference-042.md:1872-1879`).

## 2.11 The deadline is anchored once

`src/mailbox.zig:243-246`, `src/pool.zig:262-265`.

- The duration is converted to a deadline **before** the retry loop.
- Converting inside the loop would restart the timeout on every spurious
  wakeup.
- The comment says so at both sites, in the same words.

This is a portable correctness point, not a Zig detail. Any port with a timed
wait in a retry loop meets it.

## 2.12 A wakeup carries no meaning

`matryoshka-zig-0.16-notes-003.md:325-348`, `src/mailbox.zig:255-269`.

- A return from a condition wait says only that the scheduler resumed the task.
- What the code finds after waking is the event.
- The order in `receive`: closed? → any item? → dequeue, or loop.
- The loop re-evaluates state on every wakeup. No single wakeup short-circuits.

## 2.13 The wake epoch

`src/mailbox.zig:51`, `:253-269`, `:419-430`.

- `wakeUpAll` bumps `wake_epoch` and broadcasts (`:428-429`).
- A receiver captures the epoch before waiting (`:253`) and leaves the loop when
  it changes (`:255`).
- An empty mailbox after the loop means the wake came from `wakeUpAll`, so the
  receiver gets `error.Wakeup` (`:269`).
- Receivers that start waiting *later* are not affected. The effect does not
  persist past the call (`:412-414`).
- The mailbox stays open. This is not close (`:416-418`).

## 2.14 Signal hand-off on a lost race

`src/mailbox.zig:258-266`, `src/pool.zig:284-292`.

- On timeout or cancel, if the container is not empty, the leaver signals or
  broadcasts before returning.
- Without it a pending signal could be consumed by a waiter that then leaves,
  and a queued item would sit with nobody woken.

## 2.15 OOB ordering

`src/mailbox.zig:163-199`.

- FIFO among out-of-band items. Every OOB item sits ahead of every regular one.
- `oob_last` is the insert anchor; an empty anchor means prepend
  (`:188-192`).
- `oob_count` falls on every receive, and clears the anchor at zero
  (`:273-276`, `:309-312`).
- The doc comment carries a worked trace (`:166-173`).

## 2.16 `concat` on itself

`src/polynode.zig:532-544`.

- Asserts the two lists differ, then *also* returns early on the same list.
- Outside safety builds the assert is unreachable, and the plain
  `concatByMoving` would ring the items and clear the header, losing every one.
- A belt-and-braces pair, deliberate, and worth carrying into any port whose
  list primitive has the same flaw.

## 2.17 Every-node invariants

`matryoshka-api-reference-042.md:1889-1896`.

- A linked node belongs to exactly one container. Never two at once.
- A Slot has exactly one node, or nothing.
- A pool never keeps a linked node relative to other pools.
- Every node is in exactly one place at all times: with user code via a Slot,
  or with infrastructure in a queue or free list. Never both.
- Tag identity is pointer address alone. Never compare tag *contents*.

---

# 3. Essential versus incidental

One row per feature. The reason is the deciding half.

| # | Feature | Where | Verdict | Reason |
|---|---|---|---|---|
| 1 | Intrusive links inside the item | `polynode.zig:83-86` | **essential** | No allocation per enqueue. The item *is* the node. Removing it re-introduces a wrapper allocation on every transfer. |
| 2 | Runtime tag next to the links | `polynode.zig:62-64`, `:85` | **essential** | The only thing that makes a type-erased list safe to walk. |
| 3 | Tag identity by unique address | `polynode.zig:148-151` | **shape essential, spelling free** | What matters is a per-type value unique at runtime and comparable in O(1). Zig uses a mutable global's address. A language with a native type ID uses that. |
| 4 | Inner-to-outer address arithmetic (`@fieldParentPtr`) | `polynode.zig:166`, `:292`, `:386` | **essential** | The way back from a type-erased handle to the outer struct. It is what lets the `poly` field sit at any offset. |
| 5 | Offset-0 not required | `matryoshka-zig-0.16-notes-003.md:386-388` | **incidental** | A consequence of #4. A port whose cast needs offset 0 fixes the field position instead, and loses nothing. |
| 6 | `comptime` generation of the per-type helper | `polynode.zig:141-355` | **shape essential, spelling free** | The alternative is the same block hand-written per type — which is what the Odin port does. Generation is a convenience with a large payoff, not a semantic. |
| 7 | Compile-time field validation | `polynode.zig:357-363` | **should** | Turns a wrong `T` into a build error naming the type. Any port with compile-time reflection does it. One without checks at first use. |
| 8 | Two helper variants via `no_create_destroy` | `polynode.zig:144`, `:270` | **incidental mechanism, essential distinction** | The *distinction* — a type that allocates itself gets no generated `create`/`destroy` — is real and portable. The opt-in-by-declaring-a-const spelling is pure Zig. |
| 9 | The Slot as an optional pointer | `polynode.zig:89` | **essential** | The transfer signal. Any language with a nullable pointer has it. |
| 10 | `?T` specifically | `polynode.zig:89` | **incidental** | A struct with a bool, a tagged union, a nullable pointer — all work. |
| 11 | `Slot` as an *alias* rather than a distinct type | `polynode.zig:89` | **incidental** | Zig chose transparency. A port may make it opaque and gain compile-time protection. |
| 12 | `ItemHandle` and `*PolyNode` as two names for one type | `polynode.zig:66-82` | **should** | It carries intent, not type safety. Documented as "same type, different intent". A port may collapse it, and loses only the reading aid. |
| 13 | Error sets as return channel | throughout | **incidental** | `error{Closed}` versus a status enum versus an optional — the *set of outcomes* is essential, the mechanism is not. Section 6.2 lists the outcomes. |
| 14 | `!void` with a payload written through a pointer parameter | `mailbox.zig:129`, `pool.zig:226` | **shape essential** | The Slot is the out-parameter. This is the Slot idiom's own signature shape, not a Zig workaround. |
| 15 | `defer` / `errdefer` | `mailbox.zig:449`, `pool.zig:487-488`, everywhere | **shape essential, spelling free** | The null-safe-cleanup-registered-early pattern is the Slot idiom's other half (`slot-idiom.md:456-493`). A port without scope-exit cleanup writes the same shape by hand and must not skip it. |
| 16 | `std.DoublyLinkedList` as the list primitive | `polynode.zig:84`, `:602` | **incidental** | Any intrusive doubly-linked list works. `ItemList` exists mostly to fix what std's does not do — see #17. |
| 17 | `ItemList` wrapping the std list | `polynode.zig:379-603` | **essential** | It is where the checks live. std checks nothing (`:444`). It also converts every entry point to `ItemHandle`, so `@fieldParentPtr` never appears in application code. |
| 18 | `moveFromList` / `moveToList` | `polynode.zig:554`, `:568` | **may** | A bridge to the language's own list type. Only meaningful where such a type exists. |
| 19 | `_list` exposed for tests | `polynode.zig:587-602` | **incidental** | A test affordance. A port with better test access drops it. |
| 20 | O(n) walk on every insert under safety | `polynode.zig:433-450` | **should** | It catches real double-sends. Cost only in safety builds. A port with no build-mode distinction decides where to put it. |
| 21 | `std.Io` as the runtime | everywhere | **excluded** | See section 4. |
| 22 | `Io.Mutex` + `Io.Condition` | `mailbox.zig:44-45`, `pool.zig:40-41` | **essential as concepts** | The toolkit depends on exactly two primitives: a mutex and a condition with timed wait (`matryoshka-concepts-003.md:757-767`). Which library supplies them is free. |
| 23 | Timed condition wait | `internal/cond_timeout.zig:14` | **essential** | `receive(timeout)` and `get_wait(timeout)` are core surface. Without it they cannot exist. |
| 24 | The hand-written `condition_waitTimeout` | `internal/cond_timeout.zig` whole file | **excluded** | It exists because Zig 0.16 lacks the call. A language whose condition variable has a timed wait deletes this file. |
| 25 | Cancellation as a first-class outcome | `mailbox.zig:232`, `pool.zig:252` | **should** | It is Io's model. A port on plain threads with no cancellation token drops `Canceled` and keeps `Timeout`. The *shape* — a wait can end without an item and without close — survives either way. |
| 26 | `lockUncancelable` on every non-waiting path | `mailbox.zig:136` etc. | **conditional on #25** | Meaningless without cancellation. Where cancellation exists, it is a MUST on cleanup paths. |
| 27 | `Result` unions and `receiveResult` / `getWaitResult` | `mailbox.zig:56-62`, `:514`; `pool.zig:138-144`, `:543` | **may** | They exist to make a blocking call usable as an `Io.Select` event source. A port without a select mechanism skips them. The *idea* — one blocking function per source that maps every outcome to a value — is worth keeping. |
| 28 | `receive_future` / `get_wait_future` | `mailbox.zig:433`, `pool.zig:459` | **excluded** | Thin wrappers around `io.concurrent`. Pure Io. |
| 29 | Atomic `closed` flag with a pre-lock check | `mailbox.zig:48`, `pool.zig:45` | **should** | A performance shape with a correctness rule attached (the re-check under the lock). Portable to any language with atomics. |
| 30 | Two hash maps keyed on the tag pointer | `pool.zig:42-43` | **should** | The per-tag free list is the pool's whole structure. The map type is free; the keying on the type ID is not. |
| 31 | Separate `counts` map alongside `lists` | `pool.zig:43` | **incidental** | `ItemList.len` is O(n) (`polynode.zig:517-520`), so the pool keeps its own counter. A port with an O(1) list length drops the second map. |
| 32 | `Mbox.len` field beside `Mbox.list` | `mailbox.zig:46-47` | **incidental** | Same reason as #31. |
| 33 | Hooks as a struct of raw function pointers plus a `*anyopaque` ctx | `pool.zig:90-131` | **shape essential, spelling free** | The concept is a user-supplied policy interface. Zig has no interface keyword, so it is a vtable by hand. A language with interfaces uses its own. |
| 34 | `on_put` returning an optional extra list | `pool.zig:120` | **should** | It is the composite-item mechanism. Removing it means a composite has no way to give its parts back in one call. |
| 35 | `is_it_you` duplicated on the type and on the module | `mailbox.zig:89` and `:468`; `pool.zig:171` and `:496` | **incidental** | Convenience. One of the two suffices. |
| 36 | `new` filling a Slot instead of returning a pointer | `mailbox.zig:445`, `pool.zig:471` | **should** | It makes creation obey the same rule as every other acquisition. The immediate `moveFromSlot` on the next line is the documented shape (`api-reference:722-736`). A port may return a pointer and lose the uniformity. |
| 37 | `destroy_slot` beside `destroy` | `mailbox.zig:496`, `pool.zig:526` | **may** | Convenience for the Slot-shaped call site. |
| 38 | Panic on destroying an open container | `mailbox.zig:481`, `pool.zig:509` | **essential** | The one precondition the toolkit refuses to soften. |
| 39 | Asserts compiled out in fast builds | `polynode.zig:407`, `:446` and every `std.debug.assert` | **should** | The contract-violation-versus-runtime-error split is a real design line (`api-reference:1900-1920`). How a port spells it is free. |
| 40 | `Mbox` and `Pool` are themselves items | `mailbox.zig:43`, `pool.zig:39` | **essential** | One rule set for everything. It is the toolkit's stated reason for existing at all (`foundation:1824-1868`). |
| 41 | Struct fields public but documented internal | `mailbox.zig:38-53`, `pool.zig:34-47` | **incidental, and a known gap** | Zig has no private field. See section 5.3. |
| 42 | `std.Thread.spawn` ban | `rules-049.md`, `concepts:257-261` | **incidental** | A Zig-runtime rule. The portable statement is section 6.1: plain OS threads or equivalent, blocking with timeout as the primitive. |
| 43 | Import-last file layout, SPDX headers | `rules-049.md:396-412` | **incidental** | House style. |
| 44 | Master as a concept with no type | `api-reference:1987-2029` | **essential** | The absence is deliberate. A port that ships a `Master` struct has changed the design. |

---

# 4. The excluded surface

The declarations that exist **only** to bridge `std.Io`. Enumerated once, here,
so no port re-derives the list.

A port on plain threads deletes every row and loses no Matryoshka semantics.

| Declaration | file:line | What it is |
|---|---|---|
| `Mbox.io` field | `mailbox.zig:52` | The `Io` value kept for every wait. |
| `Pool.io` field | `pool.zig:46` | Same. |
| `io` parameter of `mailbox.new` | `mailbox.zig:445` | Only reason: to fill the field above. |
| `io` parameter of `pool.new` | `pool.zig:471` | Same. |
| `Mbox.receive_future` | `mailbox.zig:432-435` | Wrapper over `io.concurrent`. |
| `Pool.get_wait_future` | `pool.zig:454-461` | Wrapper over `io.concurrent`. |
| `Io.ConcurrentError` in both signatures | `mailbox.zig:433`, `pool.zig:459` | Io's error for a single-threaded backend. |
| `Io.Future(Result)` in both signatures | `mailbox.zig:433`, `pool.zig:459` | Io's future type. |
| `Io.Timeout` construction | `mailbox.zig:238-246`, `pool.zig:258-265` | The `.raw.nanoseconds` / `.clock = .real` shape and `toDeadline`. A port passes a plain duration or deadline. |
| `Io.Cancelable` in the two waiting signatures | `mailbox.zig:232`, `pool.zig:252` | See #25 above. Conditionally excluded — a port with cancellation keeps the concept. |
| `lockUncancelable` at every non-waiting site | `mailbox.zig:136`, `:181`, `:300`, `:336`, `:384`, `:423`; `pool.zig:335`, `:352`, `:400`, `:430`, `:567`, `:597`, `:614` | Meaningless without cancellation. |
| The whole of `src/internal/cond_timeout.zig` | 71 lines | Supplies the timed condition wait Zig 0.16 does not have. |
| `WaitTimeoutError` | `internal/cond_timeout.zig:6` | Its error set. |
| `Mbox.Result` and `Pool.Result` | `mailbox.zig:56-62`, `pool.zig:138-144` | Only consumer is `Io.Select` integration. |
| `receiveResult` | `mailbox.zig:514-523` | Maps every outcome to `Mbox.Result` for `select.concurrent`. |
| `getWaitResult` | `pool.zig:543-553` | Same for the pool. |

Borderline, and deliberately not excluded:

- `Mbox.wakeUpAll` (`mailbox.zig:419`) is not an Io bridge. It is a mailbox
  operation with its own epoch mechanism. It stays.
- The `closed` atomic (`mailbox.zig:48`) uses `std.atomic`, not `std.Io`. It
  stays.

Counting: of the 16 rows above, 12 vanish outright in a port with a native
timed condition wait. The remaining four — the `io` fields and the two `new`
parameters — vanish or become the port's own runtime handle.

---

# 5. Intended versus actual

Where the owner's direction differs from today's code. Flagged, not fixed.

## 5.1 The allocator — the known case

**Intended.** An item takes an allocator at creation and keeps it for life.

**Actual.** Both infrastructure types already do. Application items do not.

Evidence for the infrastructure side:

- `Mbox.alloc` is a field (`mailbox.zig:53`), set in `new` (`:461`).
- `Pool.alloc` is a field (`pool.zig:47`), set in `new` (`:485`).

Evidence for the gap — the allocator is *also* passed in again at teardown:

- `mailbox.destroy(mbx, alloc)` takes an allocator (`mailbox.zig:479`) and uses
  the parameter, not `mbx.alloc` (`:483`).
- `mailbox.destroy_slot(slot, alloc)` — same (`:496`, `:501`).
- `pool.destroy(p, alloc)` takes one and uses it three times (`:507`,
  `:511-513`), never `p.alloc`.
- `pool.destroy_slot(slot, alloc)` — same (`:526`, `:531`).

So the kept allocator and the passed allocator can differ. Nothing checks that
they match. That is the gap.

Evidence on the application-item side:

- `PolyHelper.create(allocator, slot)` takes an allocator per call
  (`polynode.zig:231`).
- `PolyHelper.destroy(allocator, slot)` takes one per call (`:253`).
- `PolyNode` has no allocator field (`:83-86`). It cannot keep one.
- The two calls are usually far apart — create in a producer, destroy in a
  consumer, or in a pool hook. Nothing links them.

**What a port should do.** Take the allocator at creation, keep it, and use the
kept one at teardown. That removes the parameter from `destroy` and
`destroy_slot` on both infrastructure types, and it removes the mismatch.

For application items the question is open: an allocator field per item costs
one pointer per item, which is real on a small item. 3TK-5 decides. This audit
only records that ztk does not keep one today.

**Not fixed here.** 3TK-1 is read-only.

## 5.2 `Pool.get_wait` does not call `on_get`

- `get` calls `on_get` in all three modes (`pool.zig:586`, `:606`; mode
  `available_only` calls no hook, `:612-629`).
- `get_wait` calls no hook at all (`pool.zig:247`, `:272-293`).
- The doc comment states it plainly (`:247`).
- But `matryoshka-api-reference-042.md:1288` says "Calls `on_get` hook" under
  `get_wait`, and `:1449-1450` says `on_get` is "called for every `get` and
  `get_wait` call".

The code and the book disagree. The code is the truth. A port follows
`src/pool.zig:247`: `get_wait` takes a stored item or waits for one, and never
creates.

Correcting the book is not this stage's work. Recorded for the owner.

## 5.3 Fields are public because Zig has no private field

- The `Mbox` doc comment says "The fields below are internal. Don't touch."
  (`mailbox.zig:38-39`). They are still reachable.
- Same for `Pool` (`pool.zig:34-35`).
- The 2026 architecture note describes an older shape, `pub const Mailbox =
  *PolyNode` with a private implementation struct
  (`foundation:2388-2399`). API 12 replaced it with real pointers to public
  structs.
- So the hidden-implementation intent survived the change, but only as a
  comment.

**What a port should do.** Where the language has opaque types or private
fields, hide them. This is a case where the port is *better* than ztk, not
merely different.

## 5.4 `ItemList._list` is public for tests

`polynode.zig:587-602`. The doc comment says "Don't use it directly", then
"Using of this field allowed for tests". Same cause as 5.3.

## 5.5 `PolyNode.tag` defaults to `undefined`

`polynode.zig:85`. A `PolyNode` built with `.{}` and never passed to `init` has
a garbage tag. `init` is the only thing that sets it (`:221-226`), and nothing
forces a caller to run it.

`create` always calls it (`:239`). A stack item does not have to
(`api-reference:343-347` shows the manual call).

A port with a stronger construction discipline — a required constructor, or a
tag written at declaration — closes this. Recorded, not fixed.

## 5.6 The two helper variants are copy-paste

`polynode.zig:144-269` and `:271-353` are byte-identical except for the two
missing functions. 110 duplicated lines.

Not a defect. It is what Zig's comptime branch on a struct's declarations
costs. A port with a different generation mechanism, or with real inheritance
between the two variants, writes it once.

---

# 6. Open questions for any port

## 6.1 The execution model, stated without Io

The specification must state the concurrency contract in language-neutral terms.
The facts, from the sources:

- Plain OS threads, or the language's nearest equivalent. Not fibers, not an
  async runtime (`matryoshka-zig-0.16-notes-003.md:85-92` names both backends,
  and the toolkit is correct on either — because everything goes through two
  primitives).
- The toolkit needs exactly two primitives: a mutex, and a condition variable
  with a timed wait (`matryoshka-concepts-003.md:757-767`,
  `foundation:2403-2421`).
- Blocking with a timeout is the primitive. Every wait either gets an item,
  times out, sees the container closed, or is interrupted.
- Multi-producer, multi-consumer. Fan-in and fan-out on one mailbox
  (`mailbox.zig:12-15`).
- Order among competing receivers is not FIFO. It is up to the runtime
  (`mailbox.zig:227-229`).

**Question for a port:** does the language's condition variable have a timed
wait? If not, the port pays what ztk paid — a 71-line hand-rolled one.

## 6.2 The outcome set, independent of error sets

Every operation's outcomes, listed as values rather than as Zig errors. A port
picks its own mechanism.

Mailbox:

| operation | outcomes |
|---|---|
| `send`, `send_oob` | done; closed (Slot unchanged) |
| `receive` | item; closed; timeout; interrupted; woken |
| `try_receive` | item; empty; closed |
| `receive_batch` | list (possibly empty); closed |
| `close` | list (possibly empty). Cannot fail. |
| `wakeUpAll` | done; closed |

Pool:

| operation | outcomes |
|---|---|
| `get` | item; closed; not-available; not-created |
| `get_wait` | item; closed; timeout; interrupted |
| `put` | nothing. Check the Slot: cleared means kept, unchanged means refused. |
| `put_all` | nothing. Check the list: non-empty means the rest was refused. |
| `close` | nothing. Cannot fail. |

Note the asymmetry in `get`: `not-available` comes only from
`available_only`, `not-created` only from a hook that produced nothing
(`pool.zig:589`, `:609`, `:628`). `get_wait` reports a timeout where
`get(.available_only)` reports not-available, and the divergence is deliberate
(`pool.zig:243-249`).

**Question for a port:** errors, a status enum, or an optional return? The
outcome set is fixed. The mechanism is not.

## 6.3 The capability list, in draft

3TK-2 turns this into the formal questionnaire. The raw list, from what the
code needs:

1. Compile-time generation of code parameterized by a type.
2. A per-type value, unique at runtime, comparable in O(1) — the tag.
3. Embedding one struct in another, and address arithmetic from the inner back
   to the outer.
4. Opaque types or private fields, for hiding the two containers' internals.
5. Interfaces or vtables, for the hooks.
6. Scope-exit cleanup, for the defer-before-acquisition shape.
7. Threads, a mutex, and a condition variable with a timed wait.
8. An allocator an item can take at creation and keep for life.
9. A nullable pointer, or an equivalent two-state container — the Slot.
10. Atomics, for the pre-lock closed check. Optional; the check can be dropped
    at a cost in contention.

## 6.4 Questions the audit cannot answer

- **Does the Slot become a distinct type?** Zig made it a transparent alias
  (`polynode.zig:89`). A port could make it opaque and catch misuse at compile
  time. Trade-off: opacity costs the `if (slot) |x|` reading shape.
- **Do application items keep an allocator?** See 5.1.
- **One helper, or two variants?** See 5.6. The `no_create_destroy` split is a
  Zig spelling of a real distinction.
- **Is `is_linked`'s blind spot acceptable?** It is documented and inherited by
  every assert that uses it (`polynode.zig:107-113`). A port whose list marks
  membership properly is strictly better. Whether to pay for that is a design
  call, not a porting one.
- **Does the port keep both `receive` and `try_receive`?** `receive` with a
  zero timeout has the same reach as `try_receive`, and the code says so
  (`mailbox.zig:211-213`). The two differ only in how the empty case is
  reported — an error versus a `false`.
- **Does the port keep `send_oob`?** It is one priority level, not a priority
  queue. It exists because the two-channel model folds signals into the data
  channel as tagged items at the front (`foundation:1612-1672`). A port that
  keeps the three-channel model does not need it.

---

# 7. Drift noted, not fixed

## 7.1 `design/secondary/context.md` does not list the `lang/` subfolders

Named in the plan (`3tk-staging-plan-001.md`, stage 3TK-1, point 7) and in
`3tk-status.md` under Open questions. Confirmed, not fixed. Fixing it is
outside this stage.

## 7.2 The `get_wait` hook contradiction

Section 5.2. `matryoshka-api-reference-042.md:1288` and `:1449-1450` say
`get_wait` calls `on_get`. `src/pool.zig:247` says it does not, and the code
agrees with the code.

## 7.3 The architecture note still shows the pre-API-12 shape

`matryoshka-architecture-foundation-4-006.md:2388-2399` shows
`pub const Mailbox = *PolyNode` with private implementation structs. API 12
replaced that with public structs and real pointers
(`api-reference:2094-2101`). The section is labelled "a common pattern", so it
is not strictly wrong, but a cold reader would take it for current.

## 7.4 `matryoshka-zig-0.16-notes-003.md` still says `_Mailbox` / `_Pool`

At `:52`, `:77`, `:91`, `:154`, `:178`, `:404`. Those names are gone from
`src/`. The types are `Mbox` and `Pool`. The file's own header says it was
updated for the pointer API (`:4-6`), so the underscore names are leftovers.

---

# Summary

- The public surface is small: 3 modules, 2 aliases, 4 types, 2 companion
  structs, 3 nested companion types, and about 60 functions.
- The five audited `src/` files are 1842 lines including doc comments. The
  three tools are the bulk.
- 16 declarations exist only to bridge `std.Io`. Section 4 names them all.
- The invariants that a port must preserve are in section 2, seventeen of them,
  with their assert sites.
- One known intended-versus-actual gap: the allocator (5.1). Five more found
  while reading (5.2 to 5.6).
- Four pieces of documentation drift (section 7). None affects `src/`.

The specification (3TK-2) works from this file. It does not need to reopen
`src/`.

---

## Change log

| Version | Date | Description |
|---|---|---|
| 001 | 2026-08-23 | First version. Stage 3TK-1. |
