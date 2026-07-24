# PolyHelper

Want the manual walkthrough first? See [PolyNode, ItemHandle, Slot](polynode/index.md).

`PolyHelper` generates the tag, check, identification functions, and init for any PolyNode type.  
One call replaces all the manual boilerplate.

```zig
pub fn PolyHelper(comptime T: type) type
```

- `T` must have a field `poly: PolyNode`. Compile error otherwise.
- Returns a namespace with four members.

---


## What PolyHelper generates

---


```zig
pub const TAG: *const anyopaque
```

- Unique runtime address for type `T`.
- Same as the manual `var _tag: PolyTag = .{}; const TAG = &_tag;` pattern.

---


```zig
pub fn isIt(tag: *const anyopaque) bool
```

- Returns `tag == TAG`.
- Same as the manual `poly.tag == EVENT_TAG` check.

---


```zig
pub fn identifyNodeAs(node: *PolyNode) ?*T
```

- Returns `null` if the runtime tag does not match.
- Returns `@fieldParentPtr("poly", node)` if it does.
- For infrastructure code that works with `*PolyNode` directly (mailbox, pool, list walks).

---


```zig
pub fn mustIdentifyNodeAs(node: *PolyNode) *T
```

- Same as `identifyNodeAs`, but panics (`orelse unreachable`) if the tag does not match.

---


```zig
pub fn identifySlotAs(slot: *const Slot) ?*T
```

- Returns `null` if the Slot is empty or the tag does not match.
- For application code that works with Slots (examples, tests, stories).

---


```zig
pub fn mustIdentifySlotAs(slot: *const Slot) *T
```

- Same as `identifySlotAs`, but panics if the Slot is empty or the tag does not match.

---


```zig
pub fn init(self: *T) void
```

- Sets `self.poly = .{ .node = .{}, .tag = TAG }`.
- Same as the manual init in Step 3.

---


## Usage

---


```zig
pub const Event = struct {
    poly: PolyNode,
    code: i32,
};

pub const EventPolyHelper = polynode.PolyHelper(Event);
```

Naming convention: `XxxPolyHelper = polynode.PolyHelper(Xxx)`.

---


## The same example, now with PolyHelper

---


```zig
// Create and initialize (Step 3 is now one call)
var ev: Event = .{ .code = 42 };
EventPolyHelper.init(&ev);

// Get PolyNode pointer (same as before)
const poly: *PolyNode = &ev.poly;

// Identify and recover (Steps 5+6 combined, returns null on wrong tag)
const recovered: *Event = EventPolyHelper.mustIdentifyNodeAs(poly);
// recovered.code == 42
```

---


```text
Manual                              With PolyHelper

var _event_tag: PolyTag = .{};      (generated inside PolyHelper)
const EVENT_TAG = &_event_tag;      EventPolyHelper.TAG

poly.tag == EVENT_TAG               EventPolyHelper.isIt(poly.tag)

if (poly.tag == EVENT_TAG)          EventPolyHelper.identifyNodeAs(poly)
  @fieldParentPtr("poly", poly)       → ?*Event (null if wrong tag)

// slot: ?*PolyNode                 EventPolyHelper.identifySlotAs(&slot)
                                       → ?*Event (null if slot empty or wrong tag)

ev.poly = .{.node=.{},.tag=TAG};    EventPolyHelper.init(&ev)
```

---


Same operations. Same runtime cost. Less boilerplate. Compile-time validation.

See `helpers/types.zig` for the pattern.

---


## PolyHelper — create and destroy

---


These two functions exist only when `T` does not declare `no_create_destroy`.  
They collapse the three-step alloc+init+slot pattern into one call.

---


```zig
pub fn create(allocator: std.mem.Allocator, slot: *Slot) !void
```

- Asserts `slot.* == null`.
- Allocates `T`.
- Zero-initializes.
- Calls `init`.
- Sets `slot.*` to point to the new node.

---


```zig
pub fn destroy(allocator: std.mem.Allocator, slot: *Slot) void
```

- If `slot.* == null`: returns immediately (no-op).
- Asserts node is not linked.
- Sets `slot.*` to null before freeing — prevents use-after-free.
- Frees the memory.

---


### Old pattern vs new

---


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
    EventPolyHelper.mustIdentifySlotAs(&slot));  // null-safe, clears slot
  slot.* = null;
```

---


### comptime selection — no_create_destroy

---


Some types must not expose `create`/`destroy`.

```zig
const no_create_destroy = void{};
```

If `T` declares this field, `PolyHelper(T)` generates only: `TAG`, `isIt`, `identifyNodeAs`, `mustIdentifyNodeAs`, `identifySlotAs`, `mustIdentifySlotAs`, `init`.

Infrastructure types (`_Mailbox`, `_Pool`) declare `no_create_destroy`.  
They manage their own lifecycle.  
Generating `create`/`destroy` for them would be wrong.

---


```text
PolyHelper(T)
  │
  ├── @hasDecl(T, "no_create_destroy") == false
  │     → TAG, isIt, identifyNodeAs, mustIdentifyNodeAs, identifySlotAs, mustIdentifySlotAs, init, create, destroy
  │
  └── @hasDecl(T, "no_create_destroy") == true
        → TAG, isIt, identifyNodeAs, mustIdentifyNodeAs, identifySlotAs, mustIdentifySlotAs, init
```

---

