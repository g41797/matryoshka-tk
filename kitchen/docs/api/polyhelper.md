# PolyHelper

Want the manual walkthrough first? See [PolyNode, ItemHandle, Slot](polynode/index.md).

`PolyHelper` generates the tag, check, identification functions, and init for any PolyNode type.  
One call replaces all the manual boilerplate.

```zig
pub fn PolyHelper(comptime T: type) type
```

- `T` must have a field `poly: PolyNode`. Compile error otherwise.
- Returns a namespace of generated declarations.

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


Two directions, and two kinds of access.

- In — `toPoly`. Your type to the toolkit. Cannot fail.
- Out — `fromPoly`, `fromSlot`, `moveFromSlot`. The toolkit to your type.
  Each checks the tag.

Within the outbound direction the names say what happens to the Slot.

- Inspection — `fromPoly`, `fromSlot`. Leaves the Slot full.
- Extraction — `moveFromSlot`. Leaves the Slot empty.

---


```zig
pub fn toPoly(self: *T) *PolyNode
```

- Returns `&self.poly`.
- The inverse of `fromPoly`.
- Cannot fail. `T` is known at compile time, so there is no tag to check.
- No `must` variant and no optional return, for the same reason.
- Never modifies the item.
- Use it wherever the toolkit wants an `ItemHandle`: `Mbox.send`, `Pool.put`, a Slot assignment.
- `Slot` is `?ItemHandle`, so the result coerces into a Slot with no separate accessor.
- Prefer it to a hand-written `&x.poly`. The field name stays inside `PolyHelper`.

---


```zig
pub fn fromPoly(node: *PolyNode) ?*T
```

- Returns `null` if the runtime tag does not match.
- Returns `@fieldParentPtr("poly", node)` if it does.
- Never modifies the node.
- For infrastructure code that works with `*PolyNode` directly (mailbox, pool, list walks).
- Needs a node whose type is not known statically. If the static type is already `*T`, there is nothing to recover.

---


```zig
pub fn mustFromPoly(node: *PolyNode) *T
```

- Same as `fromPoly`, but panics (`orelse unreachable`) if the tag does not match.

---


```zig
pub fn fromSlot(slot: *const Slot) ?*T
```

- Returns `null` if the Slot is empty or the tag does not match.
- Does not empty the Slot.
- Takes `*const Slot` — it cannot clear the Slot even by mistake.
- Returns a mutable `*T`. Most callers set or read a field through it.
- For application code that works with Slots (examples, tests, stories).

---


```zig
pub fn mustFromSlot(slot: *const Slot) *T
```

- Same as `fromSlot`, but panics if the Slot is empty or the tag does not match.

---


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

// Get PolyNode pointer (Step 4, no hand-written field access)
const poly: *PolyNode = EventPolyHelper.toPoly(&ev);

// Identify and recover (Steps 5+6 combined, returns null on wrong tag)
const recovered: *Event = EventPolyHelper.mustFromPoly(poly);
// recovered.code == 42
```

---


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

---


Same operations. Same runtime cost. Less boilerplate. Compile-time validation.

See `examples/items/items.zig` for the pattern.

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
    EventPolyHelper.mustFromSlot(&slot));  // null-safe, clears slot
  slot.* = null;
```

---


### comptime selection — no_create_destroy

---


Some types must not expose `create`/`destroy`.

```zig
const no_create_destroy = void{};
```

If `T` declares this field, `PolyHelper(T)` generates only: `TAG`, `isIt`, `toPoly`, `fromPoly`, `mustFromPoly`, `fromSlot`, `mustFromSlot`, `moveFromSlot`, `init`.

Infrastructure types (`_Mailbox`, `_Pool`) declare `no_create_destroy`.  
They manage their own lifecycle.  
Generating `create`/`destroy` for them would be wrong.

---


```text
PolyHelper(T)
  │
  ├── @hasDecl(T, "no_create_destroy") == false
  │     → TAG, isIt, toPoly, fromPoly, mustFromPoly, fromSlot, mustFromSlot, moveFromSlot, init, create, destroy
  │
  └── @hasDecl(T, "no_create_destroy") == true
        → TAG, isIt, toPoly, fromPoly, mustFromPoly, fromSlot, mustFromSlot, moveFromSlot, init
```

---

