# The Slot idiom in D

Where a handle lives while it is yours.

A Slot holds one item, or it is empty. Nothing else. It is not storage, not a
container, and not an owner — it does not know how to release what it holds.

This document is the D form of `polynode.Slot`. The Zig original is
`?ItemHandle`; the Odin port is `Maybe(^T)`. D has neither, so the Slot is a
struct.

---

## Why a struct

D has no optional type and no non-nullable pointer.

| | non-nullable pointer | optional type | forced unwrap |
|---|---|---|---|
| Zig | `*T` | `?T`, in the language | `orelse`, `.?`, `if (x) \|v\|` |
| Odin | no — `^T` is nullable | `Maybe(T)` in core | `v, ok := m.?` |
| D | no | no — `Nullable!T` is a library struct | no |

`alias Slot = PolyNode*` compiles and works. It gives up both invariants the
idiom rests on:

- **one owner** — two `PolyNode*` can name one item, and a double send follows
- **empty at death** — a Slot that goes out of scope holding an item is a silent
  leak

The struct takes both back, and gets further than Zig or Odin can. Zig's `?*T`
is copyable. Odin's `Maybe(^T)` is copyable. A D struct is not, if you say so.

`Nullable!(PolyNode*)` is the wrong tool. It wraps a type that is already
nullable, costs a `bool` plus padding, and adds nothing over `is null`.

---

## The type

```d
module matryoshka.slot;

import core.attribute : mustuse;

alias ItemHandle = PolyNode*;

@mustuse struct Slot
{
    private PolyNode* h;

    // One owner. A Slot cannot be copied or assigned from another Slot.
    @disable this(this);
    @disable void opAssign(ref Slot);

    this(PolyNode* n) @nogc nothrow @safe
    {
        assert(n is null || !isLinked(n));
        h = n;
    }

    // A Slot must be empty when it dies.
    //
    // It does not release. It cannot: heap-owned, pool-owned and borrowed
    // items are indistinguishable from here, and that is the same knowledge
    // the mailbox does not have either.
    //
    // Assert. Do not guess.
    ~this() @nogc nothrow @safe
    {
        assert(h is null, "Slot destroyed non-empty - item leaked");
    }

    bool empty() const @nogc nothrow @safe
    {
        return h is null;
    }

    // Reads the handle. The Slot keeps it.
    PolyNode* peek() @nogc nothrow @safe
    {
        return h;
    }

    // The only way out. The Slot is left empty.
    PolyNode* take() @nogc nothrow @safe
    {
        assert(h is null || !isLinked(h));
        auto t = h;
        h = null;
        return t;
    }

    // The only way in. Asserts the Slot is empty and the item is unlinked.
    void put(PolyNode* n) @nogc nothrow @safe
    {
        assert(h is null, "Slot already holds an item");
        assert(n !is null);
        assert(!isLinked(n));
        h = n;
    }
}
```

Four rules, all enforced by the compiler or by an assert:

1. A Slot holds zero or one item.
2. A Slot cannot be copied. One item, one Slot, always.
3. An item enters and leaves unlinked. Take it out of its list first.
4. A Slot is empty when it dies.

Rules 1 and 4 are asserts. Rule 2 is a compile error. Rule 3 is an assert, and
it is the one that catches a double send.

---

## Signature mapping

`*Slot` is an in/out parameter. `ref` says so, and no call site writes `**`.

| Zig | D |
|---|---|
| `fn send(self: *Mbox, slot: *Slot) error{Closed}!void` | `Status send(ref Slot slot)` |
| `fn receive(self: *Mbox, slot: *Slot, ns: ?u64)` | `Status receive(ref Slot slot, Duration)` |
| `fn create(alloc, slot: *Slot) !void` | `Status create(T)(ref Slot slot)` |
| `fn fromSlot(slot: *const Slot) ?*T` | `T* fromSlot(const scope ref Slot)` |
| `slot.* = null` | `slot.take()` |
| `slot.* == null` | `slot.empty()` |
| `slot.*.?` | `slot.peek()` |
| `slot.* orelse return` | `if (slot.empty()) return;` |

There is no `.?`. The unwrap is not checked by the compiler in D — that is the
half of the trade you give up. You get one owner and leak detection instead.

---

## Recovering the type

The Slot carries a type-erased `PolyNode*`. `PolyHelper(T)` reads the tag and
reaches the parent.

```d
template PolyHelper(T)
{
    static assert(__traits(hasMember, T, "poly"),
        T.stringof ~ ": missing field 'poly: PolyNode'");
    static assert(is(typeof(T.poly) == PolyNode),
        T.stringof ~ ": field 'poly' must have type PolyNode");

    // __gshared, never static. See Gotchas.
    private __gshared PolyTag _tag;

    pragma(inline, true)
    void* TAG() @nogc nothrow { return cast(void*) &_tag; }

    pragma(inline, true)
    PolyNode* toPoly(T* self) @nogc nothrow @trusted
    {
        return &self.poly;
    }

    // null on type mismatch. Never modifies the node.
    pragma(inline, true)
    T* fromPoly(PolyNode* n) @nogc nothrow @trusted
    {
        if (n is null || n.tag !is TAG) return null;
        return cast(T*)(cast(void*) n - T.poly.offsetof);
    }

    // null when the Slot is empty or holds another type.
    // Does not empty the Slot.
    T* fromSlot(const scope ref Slot slot) @nogc nothrow
    {
        return fromPoly(cast(PolyNode*) slot.peek());
    }

    // The same, and asserts on failure.
    T* mustFromSlot(const scope ref Slot slot) @nogc nothrow
    {
        auto p = fromSlot(slot);
        assert(p !is null, T.stringof ~ ": wrong tag or empty Slot");
        return p;
    }

    // Takes T out. On success the Slot is left empty.
    // On failure the Slot is unchanged.
    T* moveFromSlot(ref Slot slot) @nogc nothrow
    {
        auto p = fromSlot(slot);
        if (p is null) return null;
        slot.take();
        return p;
    }
}
```

`@fieldParentPtr("poly", node)` has no D equivalent. `T.poly.offsetof` is a
compile-time constant, so the arithmetic form costs nothing at runtime. It is
`@trusted` because the offset is checked at compile time and the tag at runtime.

If `PolyNode` is mandated at offset zero, add

```d
static assert(T.poly.offsetof == 0, T.stringof ~ ": 'poly' must be first");
```

and the cast is a plain reinterpret.

---

## Usual flow

Define a type. Transport it. Recover it.

```d
struct Message
{
    PolyNode poly;          // first field
    const(char)[] text;
    ubyte priority;
}

alias MessageHelper = PolyHelper!Message;
```

```d
Slot s;                                   // empty
scope(exit) freeSlot(s);                  // safe before the item exists

if (MessageHelper.create(theAllocator, s) != Status.ok)
    return;

MessageHelper.mustFromSlot(s).priority = 7;

if (mbx.send(s) != Status.ok)
{
    // error.Closed: the Slot is unchanged. The item is still ours,
    // and scope(exit) releases it.
    return;
}

// send succeeded. The Slot is empty. scope(exit) is a no-op.
```

Receiving side:

```d
Slot s;
scope(exit) freeSlot(s);

if (mbx.receive(s, 1.seconds) != Status.ok)
    return;                               // Slot still empty

auto msg = MessageHelper.fromSlot(s);
if (msg is null)
    return;                               // wrong tag - Slot unchanged

// use msg, then hand the item on or release it
```

### release-before-acquisition

`scope(exit)` evaluates its statement at scope exit, reading the Slot as it is
then. `freeSlot` on an empty Slot does nothing. So the release line goes
directly after the declaration, before the item exists, and stays correct on
every path:

- the create failed — Slot empty, no-op
- the create succeeded and the send failed — Slot holds the item, released
- the send succeeded — Slot empty, no-op
- an early return anywhere between — whichever of the above applies

This is the same property as Zig's `defer` before the acquisition. It survives
the port unchanged, and it is the reason `freeSlot` must be a no-op on empty
rather than an assert.

---

## What the Slot does not do

- It does not allocate.
- It does not free.
- It does not inspect the item.
- It does not know the item's type.
- It does not know who owns the item.

`~this` asserting empty is not a release. It is a report. The Slot is telling
you the item was dropped somewhere upstream, at the line where the Slot died,
in a debug build, with no tracking machinery. That is the whole leak detector
for the idiom.

---

## Gotchas

**`static` in D is thread-local.**

```d
private static  PolyTag _tag;    // WRONG - one per thread
private __gshared PolyTag _tag;  // right
```

With `static`, every thread gets its own tag, tag addresses differ per thread,
and `fromPoly` returns `null` for any item that crossed a thread boundary. It
looks like memory corruption. It is one keyword.

**`TAG` cannot be an `enum`.** The address of a `__gshared` is not a
compile-time constant. Use the inlined accessor above. Outside `-betterC`,
`typeid(T)` is an alternative with a genuinely unique per-type address; under
`-betterC` there is no `TypeInfo`, so `__gshared PolyTag` is the only option.

**`shared` is transitive.** Put it on the atomic field only:

```d
shared bool closed;   // core.atomic at the access sites
```

Marking a whole struct `shared` means casting at every field access, and once
casting is routine the qualifier means nothing.

**`@mustuse` applies to structs and unions, not to enums.** A `Status` enum
returned from `send` can be discarded silently. If you want it forced, return a
one-field `@mustuse struct`.

**Alignment.** `Slot` is one pointer. It passes in a register and costs nothing
over the raw `PolyNode*` in a release build. `@disable this(this)` and `~this`
are compile-time and debug-time only.

---

## Ports of the same idiom

| | Zig | Odin | D |
|---|---|---|---|
| Slot type | `?ItemHandle` | `Maybe(^PolyNode)` | `struct Slot` |
| in/out param | `*Slot` | `^Maybe(^PolyNode)` | `ref Slot` |
| checked unwrap | yes | yes | no |
| copy prevented | no | no | **yes** |
| leak detected at site | no | no | **yes** |
| discard prevented | no | no | **yes** (`@mustuse`) |

D loses the checked unwrap and gains the ownership guarantees. For this idiom
that is the better half — the invariant that matters is one owner, empty at
death, and Zig enforces neither.
