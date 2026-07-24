# Defining user types — manual step by step

New to the concepts? See [Building Blocks — PolyNode](../../building-blocks/polynode.md) first.

Every PolyNode-based type needs four things:

- A struct with an embedded `poly: PolyNode` field.
- A unique tag address for runtime type identity.
- A way to check the tag before casting.
- A way to cast from `*PolyNode` back to `*YourType`.

This section builds each piece manually. It is the foundation of Matryoshka.

Don't care about the manual steps? See [PolyHelper](../polyhelper.md) — it generates all  
four pieces for you. Come back here when you want to know what it generates and why.

---

## Step 1 — Define the struct

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
|   | tag: *const anyopaque| |
|   +---------------------+ |
| code: i32                 |
+---------------------------+
```

Why: Matryoshka never sees `Event`. It only sees `*PolyNode`.  
The `poly` field is the bridge between your type and the infrastructure.

---

## Step 2 — Create a unique tag

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

## Step 3 — Set the tag at construction

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
|   tag: undefined  |            |   tag: EVENT_TAG  |
| code: 42         |            | code: 42         |
+------------------+            +------------------+
```

Why: the tag is how you identify what type a `*PolyNode` points into.  
Without it, you cannot safely cast.

---

## Step 4 — Get a pointer to the embedded PolyNode

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

## Step 5 — Check the tag before casting

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

## Step 6 — Cast back to the outer type

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

## Step 7 — Two-level recovery (from list node)

Inside a mailbox or pool, items are linked via `std.DoublyLinkedList`.  
The list operates on `*DoublyLinkedList.Node`, not `*PolyNode`.

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
|   | tag: EVENT_TAG       | |
|   +---------------------+ |
| code: 42                 |
+---------------------------+
^           ^
|           |
|           poly: *PolyNode    (Step 1: @fieldParentPtr("node", dll_node_ptr))
|
ev: *Event                     (Step 2: @fieldParentPtr("poly", poly))
```

---

## Complete manual example

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

`PolyHelper` generates all four — see [API Reference — PolyHelper](../polyhelper.md).

---

