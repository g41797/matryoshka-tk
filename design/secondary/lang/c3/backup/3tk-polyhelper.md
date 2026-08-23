**Understanding confirmed.**

Your Zig design:

- Every item embeds a `PolyNode` (intrusive list links + runtime type tag).
- `PolyHelper(T)` generates type-safe helpers for a concrete `T` that contains `poly: PolyNode`.
- The tag is a unique static address (`&_tag`).
- Core operations: `toPoly`, `fromPoly` / `mustFromPoly`, `init`, optional `create`/`destroy`, plus Slot helpers.
- `fromPoly` does a runtime tag check + `@fieldParentPtr`.

In C3 we already decided:
- `AnyNode` ≈ `PolyNode`
- Use built-in `typeid` instead of a pointer-to-static-tag (cleaner & zero extra storage for the tag value itself).

---

### Idiomatic C3 `PolyHelper`

```c3
import std::io;
import std::mem;

// ------------------------------------------------------------
// Base intrusive node  (≈ PolyNode)
// ------------------------------------------------------------
struct AnyNode
{
    AnyNode* prev;
    AnyNode* next;
    typeid   type;          // runtime type tag
}

typedef ItemHandle = AnyNode*;
typedef Slot       = ItemHandle?;   // optional handle

// ------------------------------------------------------------
// List helpers (same semantics as Zig)
// ------------------------------------------------------------
fn void AnyNode.reset(AnyNode* self)
{
    self.prev = null;
    self.next = null;
}

fn bool AnyNode.is_linked(AnyNode* self)
{
    return self.prev != null || self.next != null;
}

// ------------------------------------------------------------
// PolyHelper – generic helper for a type T that embeds AnyNode
// as its first field named `node` (or whatever you prefer).
// ------------------------------------------------------------
macro PolyHelper(Type)
{
    // Runtime type ID of Type
    const TAG = Type::typeid;

    // True if the tag identifies Type
    fn bool is_it(typeid tag)
    {
        return tag == TAG;
    }

    // Cast AnyNode* → Type*  (returns null on mismatch)
    fn Type*? from_poly(AnyNode* node)
    {
        if (node.type != TAG) return null;
        return (Type*)node;                 // node must be first field
    }

    // Same, but panics / unreachable on mismatch
    fn Type* must_from_poly(AnyNode* node)
        @require(node.type == TAG)
    {
        return (Type*)node;
    }

    // Inverse: Type* → AnyNode*
    fn AnyNode* to_poly(Type* self)
    {
        return &self.node;                  // adjust field name if needed
    }

    // Slot helpers
    fn Type*? from_slot(Slot* slot)
    {
        AnyNode*? node = *slot;
        if (!node) return null;
        return from_poly(node);
    }

    fn Type* must_from_slot(Slot* slot)
        @require(*slot != null)
    {
        return must_from_poly(*slot);
    }

    fn Type*? move_from_slot(Slot* slot)
    {
        AnyNode*? node = *slot;
        if (!node) return null;

        Type*? item = from_poly(node);
        if (!item) return null;

        assert(!node.is_linked());
        *slot = null;
        return item;
    }

    // Initialize the embedded node
    fn void init(Type* self)
    {
        self.node = {
            .prev = null,
            .next = null,
            .type = TAG,
        };
    }

    // Optional create / destroy (omit if you want the “no_create_destroy” variant)
    fn void!? create(Allocator allocator, Slot* slot)
        @require(*slot == null)
    {
        Type* item = allocator.alloc(Type)!;
        *item = {};
        init(item);
        *slot = to_poly(item);
    }

    fn void destroy(Allocator allocator, Slot* slot)
    {
        AnyNode*? poly = *slot;
        if (!poly) return;

        assert(!poly.is_linked());
        Type*? item = from_poly(poly);
        assert(item != null);

        *slot = null;
        allocator.free(item);
    }
}
```

### Usage example

```c3
struct Mbox
{
    AnyNode node;           // MUST be first field
    // ... mbox fields
}

// Instantiate the helper
def MboxHelper = PolyHelper(Mbox);

fn void example()
{
    Mbox box = {};
    MboxHelper.init(&box);

    ItemHandle h = MboxHelper.to_poly(&box);

    // Safe down-cast
    if (try m = MboxHelper.from_poly(h))
    {
        // m is Mbox*
    }

    // Or with contract / assert
    Mbox* m2 = MboxHelper.must_from_poly(h);
}
```

### Mapping summary

| Zig                    | C3 equivalent                          |
|------------------------|----------------------------------------|
| `PolyNode`             | `AnyNode`                              |
| `tag: *const anyopaque`| `type: typeid`                         |
| `PolyHelper(T).TAG`    | `Type::typeid`                         |
| `@fieldParentPtr`      | simple cast (node is first field)      |
| `fromPoly` → `?*T`     | `from_poly` → `Type*?`                 |
| `mustFromPoly`         | `must_from_poly` + `@require`          |
| `toPoly`               | `to_poly`                              |
| `init`                 | `init`                                 |
| `create` / `destroy`   | optional, same semantics               |



**Yes — that advice is solid for C3.**

Because C3 pointers are nullable, the idiomatic “slot” is simply a double pointer:

```c3
typedef ItemHandle = AnyNode*;     // *PolyNode
// Slot is just ItemHandle*  →  AnyNode**
```

### Why this is preferred in C3

| Zig                          | C3 recommendation              | Reason |
|------------------------------|--------------------------------|--------|
| `Slot = ?ItemHandle`         | `ItemHandle*` (i.e. `AnyNode**`) | Pointers are already nullable |
| Optional unwrapping needed   | Just check `*slot == null`     | Simpler, zero overhead |
| `moveFromSlot` clears slot   | `*slot = null`                 | Natural |

### Updated helpers (Slot = `ItemHandle*`)

```c3
// Slot is ItemHandle*  (== AnyNode**)

fn Type*? from_slot(ItemHandle* slot)
{
    if (*slot == null) return null;
    return from_poly(*slot);
}

fn Type* must_from_slot(ItemHandle* slot)
    @require(*slot != null)
{
    return must_from_poly(*slot);
}

fn Type*? move_from_slot(ItemHandle* slot)
{
    if (*slot == null) return null;

    Type*? item = from_poly(*slot);
    if (!item) return null;

    assert(!(*slot).is_linked());
    *slot = null;               // clear the slot
    return item;
}

fn void!? create(Allocator allocator, ItemHandle* slot)
    @require(*slot == null)
{
    Type* item = allocator.alloc(Type)!;
    *item = {};
    init(item);
    *slot = to_poly(item);
}

fn void destroy(Allocator allocator, ItemHandle* slot)
{
    if (*slot == null) return;

    assert(!(*slot).is_linked());
    Type*? item = from_poly(*slot);
    assert(item != null);

    *slot = null;
    allocator.free(item);
}
```

### Usage

```c3
ItemHandle slot = null;          // empty slot

MboxHelper.create(allocator, &slot)!;

if (try m = MboxHelper.from_slot(&slot))
{
    // use m
}

MboxHelper.destroy(allocator, &slot);
```

This matches common C-style “out-parameter / slot” patterns and avoids the extra optional layer that Zig needed because of its non-nullable pointers by default.

```c3
import std::io;
import std::mem;

// ------------------------------------------------------------
// Base intrusive node
// ------------------------------------------------------------
struct AnyNode
{
    AnyNode* prev;
    AnyNode* next;
    typeid   type;
}

typedef AnyHandle = AnyNode*;          // handle that travels through the system
// Slot is simply AnyHandle*  (i.e. AnyNode**)

// ------------------------------------------------------------
// Small list utilities
// ------------------------------------------------------------
fn void AnyNode.reset(AnyNode* self)
{
    self.prev = null;
    self.next = null;
}

fn bool AnyNode.is_linked(AnyNode* self)
{
    return self.prev != null || self.next != null;
}


Got it.  
`AnyHelper` should generate `create`/`destroy` by default (like Zig’s `PolyHelper`), and Mbox/Pool opt out.

Here’s the updated version with an opt-out mechanism:

```c3
import std::io;
import std::mem;

// ------------------------------------------------------------
// Base intrusive node
// ------------------------------------------------------------
struct AnyNode
{
    AnyNode* prev;
    AnyNode* next;
    typeid   type;
}

typedef AnyHandle = AnyNode*;          // handle that travels through the system
// Slot is simply AnyHandle*  (i.e. AnyNode**)

// ------------------------------------------------------------
// Small list utilities
// ------------------------------------------------------------
fn void AnyNode.reset(AnyNode* self)
{
    self.prev = null;
    self.next = null;
}

fn bool AnyNode.is_linked(AnyNode* self)
{
    return self.prev != null || self.next != null;
}

// ------------------------------------------------------------
// AnyHelper
//
// By default generates create/destroy.
// Opt out by defining:  const no_create_destroy = true;
// inside the type (or pass a second parameter).
// ------------------------------------------------------------
macro AnyHelper(Type)
{
    const TAG = Type::typeid;

    // ---------- always generated ----------

    fn bool is_it(typeid tag)
    {
        return tag == TAG;
    }

    fn Type*? from_any(AnyNode* node)
    {
        if (node.type != TAG) return null;
        return (Type*)node;                 // node must be first field
    }

    fn Type* must_from_any(AnyNode* node)
        @require(node.type == TAG)
    {
        return (Type*)node;
    }

    fn AnyNode* to_any(Type* self)
    {
        return &self.node;
    }

    fn Type*? from_slot(AnyHandle* slot)
    {
        if (*slot == null) return null;
        return from_any(*slot);
    }

    fn Type* must_from_slot(AnyHandle* slot)
        @require(*slot != null)
    {
        return must_from_any(*slot);
    }

    fn Type*? move_from_slot(AnyHandle* slot)
    {
        if (*slot == null) return null;

        Type*? item = from_any(*slot);
        if (!item) return null;

        assert(!(*slot).is_linked());
        *slot = null;
        return item;
    }

    fn void init(Type* self)
    {
        self.node = {
            .prev = null,
            .next = null,
            .type = TAG,
        };
    }

    // ---------- create / destroy (generated only when not opted out) ----------

    $if !Type.has_tag("no_create_destroy"):

        fn void!? create(Allocator allocator, AnyHandle* slot)
            @require(*slot == null)
        {
            Type* item = allocator.alloc(Type)!;
            *item = {};
            init(item);
            *slot = to_any(item);
        }

        fn void destroy(Allocator allocator, AnyHandle* slot)
        {
            if (*slot == null) return;

            assert(!(*slot).is_linked());
            Type*? item = from_any(*slot);
            assert(item != null);

            *slot = null;
            allocator.free(item);
        }

    $endif
}
```

---

### Application item (gets create/destroy)

```c3
struct WorkItem
{
    AnyNode node;               // MUST be first field
    int     priority;
    String  payload;
}

def WorkItemHelper = AnyHelper(WorkItem);

// Usage
fn void example(Allocator allocator)
{
    AnyHandle slot = null;

    WorkItemHelper.create(allocator, &slot)!;

    WorkItem* job = WorkItemHelper.must_from_slot(&slot);
    job.priority = 10;
    job.payload  = "process batch";

    // … later
    WorkItemHelper.destroy(allocator, &slot);
}
```

---

### Infrastructure types (opt out)

```c3
struct Mbox
{
    AnyNode node;
    // …
}
@tag(no_create_destroy)            // or whatever attribute syntax you prefer

def MboxHelper = AnyHelper(Mbox);

// create / destroy are NOT generated
// Mbox keeps its own specialised construction
```

(If C3 attribute/`$if` syntax for “has tag” is slightly different in your version, the same idea can be expressed with a second macro parameter or a simple `const no_create_destroy = void{};` check.)

This mirrors the Zig `PolyHelper` behaviour: normal AnyItems get the convenience allocators, while Mbox/Pool stay in control of their own lifetime.
