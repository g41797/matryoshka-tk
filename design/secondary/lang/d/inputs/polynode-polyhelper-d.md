# PolyNode and PolyHelper in D

Intrusion and type erasure, continued.

The previous note described the mechanism in Zig:

- embed a `Node` in your struct
- the list works on `Node`, not on your type
- the caller reaches the parent struct with `@fieldParentPtr`

This note describes the same mechanism in D.

Two of those three steps need a different tool.

---

## D has no intrusive list to embed

Zig gives you `std.DoublyLinkedList` and its `Node`.

D gives you `std.container.dlist`.

It is not the same thing:

```text
std.DoublyLinkedList (Zig)     std.container.DList (D)

links live in your struct       links live in a wrapper
no allocation per element       allocates a wrapper per element
works on Node                   works on the element type
```

`DList` is a value container.

It copies elements into nodes it owns.

That is the opposite of intrusion.

So in D you write the node yourself:

```d
struct Node
{
    Node* prev;
    Node* next;
}
```

Six lines of list code, and you own the semantics.

This turns out to be an advantage — see *Links* below.

---

## The node alone is not enough

A list of `Node*` tells you where the elements are.

It does not tell you what they are.

```text
        list

   Node ──► Node ──► Node
    │        │        │
    ▼        ▼        ▼
   ???      ???      ???
```

If every element in the list has the same type, the caller already knows.

If they do not, the caller needs to ask.

So the node carries identity:

```d
struct PolyNode
{
    Node node;
    const(void)* tag;
}
```

Now:

```text
        list

  PolyNode ──► PolyNode ──► PolyNode
   │  tag       │  tag       │  tag
   ▼   │        ▼   │        ▼   │
Request│      Reply │     Request│
       ▼            ▼            ▼
     Request      Reply       Request
      type         type        type
```

The list still works on `PolyNode`.

The tag is what lets a caller ask "is this one mine?" before it casts.

Type erasure with a way back.

---

## The tag

The tag is not a name and not a number.

It is an address.

One address per type, unique for the lifetime of the program:

```d
struct PolyTag
{
    ubyte _;
}
```

Each type gets one variable of this type.

Its address is the type ID.

Nothing is ever read from it.

```text
PolyTag for Request     lives at 0x...A0
PolyTag for Reply       lives at 0x...A1

node.tag is 0x...A0  →  this is a Request
node.tag is 0x...A1  →  this is a Reply
```

Comparison is a pointer comparison:

```d
if (node.tag is requestTag) { ................ }
```

Use `is`, not `==`.

---

## The tag must be one per type, not one per thread

This is the trap.

In D, a module-level or template-level `static` variable is **thread-local**.

```d
private static    PolyTag _tag;   // WRONG
private __gshared PolyTag _tag;   // right
```

With `static`, every thread gets its own `PolyTag`.

Every thread therefore computes a different type ID for the same type.

An item created on thread A and received on thread B has a tag that matches
nothing on thread B.

`fromPoly` returns `null`.

The item looks like the wrong type.

```text
Thread A                     Thread B

create Request               receive PolyNode
tag := 0x...A0               compare against 0x...B7
send  ─────────────────────► mismatch → null
```

Nothing crashes.

Nothing warns.

It looks like memory corruption, and it is one keyword.

Write `__gshared`.

---

## One tag per type per binary

`PolyHelper!Request` is instantiated once per unique argument.

Separately compiled objects each emit the instance, and the linker merges them.

So there is one `_tag` for `Request` in the final binary.

If you ever observe two different tags for one type, you are looking at two
copies of the library in one process, not at a template problem.

---

## Reaching the parent struct

Zig has `@fieldParentPtr`.

D has no equivalent, and does not need one.

`.offsetof` is a compile-time constant:

```d
T.poly.offsetof
```

So the cast is arithmetic:

```d
T* fromPolyUnchecked(T)(PolyNode* n)
{
    return cast(T*)(cast(ubyte*) n - T.poly.offsetof);
}
```

The offset is resolved at compile time.

The generated code is one subtraction, or none at all if the offset is zero.

**Cast to `ubyte*`, not `void*`.**

D does not allow arithmetic on `void*`.

`void` has no size, so `cast(void*)n - 8` does not compile.

This is the second small thing that catches a Zig or C programmer.

---

## Offset zero

D lays out plain structs in declaration order.

So if `poly` is declared first, it is at offset zero, and you can rely on it:

```d
struct Request
{
    PolyNode poly;      // first
    uint id;
    ubyte[] data;
}

static assert(Request.poly.offsetof == 0);
```

Then the cast is a plain reinterpret and the subtraction disappears.

Zig cannot promise this.

Zig may reorder the fields of an ordinary struct, which is exactly why
`@fieldParentPtr` exists as a compiler intrinsic.

D's layout rule makes the offset-zero mandate enforceable with a `static
assert`, and the arithmetic form correct either way.

Mandate it or don't.

Just decide once, and assert it.

---

## PolyHelper

In Zig, `PolyHelper(T)` is a function that returns a type.

In D it is a template:

```d
template PolyHelper(T)
{
    ................
}
```

Used as:

```d
alias RequestHelper = PolyHelper!Request;

auto p = RequestHelper.fromPoly(node);
```

Same shape as the Zig call site.

No `comptime` keyword — a template argument is a compile-time argument by
construction.

---

## Validating T

Zig checks with `@hasField` and `@compileError`.

D checks with `__traits` and `static assert`:

```d
template PolyHelper(T)
{
    static assert(is(T == struct),
        T.stringof ~ ": must be a struct");

    static assert(__traits(hasMember, T, "poly"),
        T.stringof ~ ": missing field 'poly: PolyNode'");

    static assert(is(typeof(T.poly) == PolyNode),
        T.stringof ~ ": field 'poly' must have type PolyNode");

    ................
}
```

Same errors, same place, same message quality.

The check runs when the helper is instantiated, which is where you want it.

---

## Guaranteeing the field

D can go one step further than Zig here.

A `mixin template` can inject the field, so a type cannot forget it:

```d
mixin template PolyItem()
{
    PolyNode poly;
}
```

Used as the first declaration in the struct:

```d
struct Request
{
    mixin PolyItem;     // declares poly, at offset 0

    uint id;
    ubyte[] data;
}
```

Now the field is not something the author remembers to add.

It is something the author cannot spell wrong.

Keep the `static assert` on the offset in `PolyHelper`, not in the mixin.

Inside the mixin, the struct's layout is not finished yet, and asking for
`offsetof` there is asking too early.

---

## The generated functions

The full set, matching the Zig helper one for one:

```d
template PolyHelper(T)
{
    static assert(is(T == struct), T.stringof ~ ": must be a struct");
    static assert(__traits(hasMember, T, "poly"),
        T.stringof ~ ": missing field 'poly: PolyNode'");
    static assert(is(typeof(T.poly) == PolyNode),
        T.stringof ~ ": field 'poly' must have type PolyNode");

    private __gshared PolyTag _tag;

    /// Runtime type ID.
    pragma(inline, true)
    const(void)* TAG() @nogc nothrow @trusted
    {
        return cast(const(void)*) &_tag;
    }

    /// True if the tag identifies T.
    pragma(inline, true)
    bool isIt(const(void)* tag) @nogc nothrow
    {
        return tag is TAG();
    }

    /// Reach the PolyNode embedded in T.
    /// Cannot fail. T is known at compile time.
    pragma(inline, true)
    PolyNode* toPoly(T* self) @nogc nothrow @trusted
    {
        return &self.poly;
    }

    /// Cast to T through its embedded PolyNode.
    /// null on type mismatch. Never modifies the node.
    pragma(inline, true)
    T* fromPoly(PolyNode* n) @nogc nothrow @trusted
    {
        if (n is null) return null;
        if (n.tag !is TAG()) return null;
        return cast(T*)(cast(ubyte*) n - T.poly.offsetof);
    }

    /// The same, and asserts on mismatch.
    /// For a call site that has already established the type.
    pragma(inline, true)
    T* mustFromPoly(PolyNode* n) @nogc nothrow
    {
        auto p = fromPoly(n);
        assert(p !is null, T.stringof ~ ": wrong tag");
        return p;
    }

    /// Sets the tag. Call once, on a fresh item.
    pragma(inline, true)
    void initItem(T* self) @nogc nothrow
    {
        self.poly = PolyNode.init;
        self.poly.tag = TAG();
    }

    ................ // Slot forms, create, destroy — below
}
```

`init` is a reserved property name in D, so the initializer is `initItem`.

That is the only rename the port forces.

---

## The Slot forms

The Slot idiom is documented separately.

The helper's three Slot functions map directly:

```d
    /// null when the Slot is empty or holds another type.
    /// Does not empty the Slot.
    T* fromSlot(const scope ref Slot slot) @nogc nothrow
    {
        return fromPoly(cast(PolyNode*) slot.peek());
    }

    /// The same, and asserts on failure.
    T* mustFromSlot(const scope ref Slot slot) @nogc nothrow
    {
        auto p = fromSlot(slot);
        assert(p !is null, T.stringof ~ ": wrong tag or empty Slot");
        return p;
    }

    /// Takes T out. On success the Slot is left empty.
    /// On failure the Slot is unchanged.
    T* moveFromSlot(ref Slot slot) @nogc nothrow
    {
        auto p = fromSlot(slot);
        if (p is null) return null;
        assert(!isLinked(slot.peek()));
        slot.take();
        return p;
    }
```

`*const Slot` becomes `const scope ref Slot`.

`*Slot` becomes `ref Slot`.

No `**` at any call site.

---

## Two variants

Zig switches on a declaration:

```zig
if (!@hasDecl(T, "no_create_destroy")) { ... } else { ... }
```

D switches on a trait:

```d
    static if (!__traits(compiles, T.no_create_destroy))
    {
        Status create(ref Slot slot) @nogc nothrow
        {
            assert(slot.empty);

            auto p = cast(T*) malloc(T.sizeof);
            if (p is null) return Status.noMemory;

            *p = T.init;
            initItem(p);

            slot.put(toPoly(p));
            return Status.ok;
        }

        void destroy(ref Slot slot) @nogc nothrow
        {
            auto n = slot.peek();
            if (n is null) return;              // no-op on empty

            assert(!isLinked(n));

            auto p = fromPoly(n);
            assert(p !is null);

            slot.take();                        // empty first
            free(p);
        }
    }
```

A type opts out by declaring anything with that name:

```d
struct Mbox
{
    PolyNode poly;
    enum no_create_destroy = true;   // allocates itself
    ................
}
```

Two details in `create` and `destroy` carry over from the Zig, and both matter:

- `*p = T.init` before `initItem`. D structs have no default constructor, so
  this is the D form of Zig's `item.* = .{}`. If `T` has a destructor or a
  postblit, use `core.lifetime.emplace` instead.
- `destroy` empties the Slot **before** it frees. A second `destroy` on the same
  Slot then does nothing, which is what makes release-before-acquisition safe.

---

## Links

Two small functions the list needs:

```d
/// Clears the intrusive links. Call after removing a node from a list.
pragma(inline, true)
void reset(PolyNode* n) @nogc nothrow
{
    n.node.prev = null;
    n.node.next = null;
}

/// True if the node has neighbours.
///
/// Not a membership test. The only member of a list has no neighbours,
/// so this returns false for it.
pragma(inline, true)
bool isLinked(const PolyNode* n) @nogc nothrow
{
    return n.node.prev !is null || n.node.next !is null;
}
```

`isLinked` catches the multi-element case.

That is where most double-sends land.

Nothing repairs the single-element blind spot.

State kept in an item cannot validate this.

Here is where writing your own list pays.

In Zig, `std.DoublyLinkedList.popFirst` leaves the removed node's links intact,
so `reset` has to be called by hand, and forgetting it produces false positives
from `isLinked` for the rest of the program's life.

Your own list calls `reset` inside `popFirst`, `popLast` and `remove`.

The hazard stops existing rather than being documented.

---

## Zig and D, side by side

| | Zig | D |
|---|---|---|
| intrusive list in std | `std.DoublyLinkedList` | none — write it |
| reach parent struct | `@fieldParentPtr("poly", n)` | `cast(ubyte*)n - T.poly.offsetof` |
| field order guaranteed | no — may reorder | yes — declaration order |
| offset-zero mandate | not expressible | `static assert(T.poly.offsetof == 0)` |
| helper generation | `fn PolyHelper(T) type` | `template PolyHelper(T)` |
| type validation | `@hasField`, `@compileError` | `__traits(hasMember)`, `static assert` |
| variant selection | `@hasDecl` + `if` | `__traits(compiles)` + `static if` |
| field cannot be forgotten | not expressible | `mixin template` |
| per-type tag storage | `var _tag` in the generated type | `__gshared PolyTag` — **not** `static` |
| tag comparison | `tag == TAG` | `tag is TAG()` |
| `init` as a name | fine | reserved — rename |

Two rows are the whole story.

D loses `@fieldParentPtr` and gains deterministic layout, so the intrinsic is
replaced by a constant and an assert.

D gains `mixin template`, so the one thing a user of the toolkit can get wrong
— forgetting the embedded node — stops being possible.

---

## The simple rule

Embed a `PolyNode` as the first field.

The list works on `PolyNode`.

The tag says what the parent is.

`offsetof` says where the parent starts.

`__gshared`, not `static`.

That is the whole mechanism, and it is still the basis of Matryoshka.
