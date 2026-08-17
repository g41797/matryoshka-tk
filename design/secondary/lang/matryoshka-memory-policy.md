# Generating Matryoshka from a compile-time memory policy

Two modes. One implementation.

```text
Manual      you allocate and release      no GC     -betterC reachable
Managed     the collector owns items      GC        the ordinary D application
```

The mode is chosen at compile time. Application code does not name it.

---

## Picking a mode

The names describe the mechanism, not the machine. Both modes run anywhere.

Choose **Manual** if any one of these is true:

```text
[ ] You have a measured tail-latency budget the collector violates.
[ ] You are targeting -betterC, or a platform with no runtime.
[ ] You are a shared library loaded into a host that does not own druntime.
```

Otherwise choose **Managed**.

Measured, not assumed. "It feels wasteful" is not on the list. A latency-budgeted
server is desktop-class hardware that needs Manual, and an embedded Linux box
with no budget is fine on Managed.

---

## The claim this design rests on

Audit the two modes and ask what actually differs.

**Differs:**

```text
1. how an item is allocated and released
2. the attribute set (@nogc or not)
3. the hook function pointer types (they carry the attribute set)
```

**Must not differ:**

```text
the Slot idiom            the error model (status codes, both modes)
send / receive logic      the intrusive list
the tag mechanism         the mutex and condvar wrappers
the pool's free lists     the API shape
the hook contract         the assert set
```

That is the whole audit. One of those three differences is an allocator. The
other two are consequences of it.

So the policy is **an allocator, and nothing else**. Everything the compiler
needs follows from that.

This matters because the tempting design is two implementations behind a
`version`, and that design is wrong. Every line that exists in only one mode is
a line your CI tests in only one mode.

---

## The policy type

A struct. Two operations, one compile-time flag.

```d
/// You allocate. You release. No collector.
struct Manual
{
    enum bool managed = false;

    private Arena* arena;          // or a vtable, or nothing

    T* acquire(T)() @nogc nothrow
    {
        return cast(T*) arena.alloc(T.sizeof, T.alignof);
    }

    void release(T)(T* p) @nogc nothrow
    {
        arena.dealloc(p, T.sizeof);
    }
}

/// The collector owns the items.
struct Managed
{
    enum bool managed = true;

    T* acquire(T)() nothrow
    {
        return new T;
    }

    void release(T)(T* p) nothrow
    {
        // The collector reclaims. Nothing to do.
    }
}
```

The policy is an **instance**, not a namespace. That is deliberate.

A Manual application may want a per-connection arena, or one arena per mailbox.
A static allocator forecloses that. `Managed` carries no state, so it costs one
byte of padding in a struct that already holds a mutex.

Same signature in both modes. The mode is not visible in any call.

---

## Selecting the default

`version` picks the default. Aliases hide it.

```d
version (MatryoshkaManual)
    alias DefaultPolicy = Manual;
else
    alias DefaultPolicy = Managed;

alias PolyHelper(T) = PolyHelperImpl!(T, DefaultPolicy);
alias Mbox          = MboxImpl!DefaultPolicy;
alias Pool(H)       = PoolImpl!(DefaultPolicy, H);
```

In dub:

```json
"configurations": [
    { "name": "managed" },
    { "name": "manual", "versions": ["MatryoshkaManual"] }
]
```

Managed is the unmarked default, because the mode that needs no rules should be
the one you get by not thinking about it.

Application code, in both modes, unchanged:

```d
Slot s;
scope(exit) release(s);

if (create!Request(policy, s) != Status.ok) return;
mustFromSlot!Request(s).id = 7;
if (mbx.send(s) != Status.ok) return;
```

Nothing there names a policy. Nothing there changes between modes.

### Why templates, when `version` alone would do

Two reasons, and both are worth the template noise.

**Both modes compile in one build.** A `version`-gated implementation is only
ever type-checked in the mode you are building. A templated one lets a single CI
run instantiate both and catch the error in whichever mode you are not looking
at.

**A user with a genuine need can name the impl directly.** Rare, but the door
exists without you having to build it later.

---

## Attribute inference does the `@nogc` work

This is the part that makes the design cheap rather than tedious.

D infers attributes for template functions. You never write `@nogc`.

```text
MboxImpl!Manual.send    →  inferred @nogc nothrow
MboxImpl!Managed.send   →  inferred nothrow
```

Same source. The attribute falls out of what the instantiation actually calls.

In Zig you would thread this by hand, or not have it at all. Here it is free,
and it is *verified* — if a line in shared code allocates, `Mbox!Manual` stops
being `@nogc` and the check in the Testing section below fails.

The hook types come from the same place:

```d
template Hooks(Policy)
{
    static if (Policy.managed)
    {
        alias OnGet   = void function(void*, const(void)*, size_t, ref Slot) nothrow;
        alias OnPut   = ItemList function(void*, size_t, ref Slot) nothrow;
        alias OnClose = void function(void*, ref ItemList) nothrow;
    }
    else
    {
        alias OnGet   = void function(void*, const(void)*, size_t, ref Slot) @nogc nothrow;
        alias OnPut   = ItemList function(void*, size_t, ref Slot) @nogc nothrow;
        alias OnClose = void function(void*, ref ItemList) @nogc nothrow;
    }
}
```

`nothrow` in both. That is not negotiable in either mode — a throwing
`on_close` destroys the only remaining reference to every pooled item.

`@nogc` only in Manual, because a `@nogc` hook type would lock out every
Managed application without a cast.

---

## One thing that must not be templated: the tag

If `_tag` lives inside `PolyHelperImpl!(T, Policy)`, then `Request` has two type
IDs — one per policy. A pool instantiated one way stops recognising an item
created the other way.

Lift it out:

```d
private template TagOf(T)
{
    __gshared PolyTag tag;      // __gshared, never static
}

// inside PolyHelperImpl!(T, Policy):
pragma(inline, true)
const(void)* TAG() @nogc nothrow @trusted
{
    return cast(const(void)*) &TagOf!T.tag;
}
```

One tag per type, for the life of the binary, regardless of policy.

The same fix applies to `Pool`'s own tag: put it at module scope so every
`Pool!H` shares one type ID.

Rule of thumb: **template what varies, and nothing that establishes identity.**

---

## The payoff: rules become compile errors

An earlier note listed five rules a no-GC application had to follow. The policy
makes three of them the compiler's job.

### Rule: no GC references inside item structs

An item you allocated yourself is not scanned. Anything GC-allocated that it
points at is collectable while the item still points at it.

With a compile-time policy, `PolyHelper` can simply refuse:

```d
template PolyHelperImpl(T, Policy)
{
    static assert(is(T == struct), T.stringof ~ ": must be a struct");
    static assert(__traits(hasMember, T, "poly"),
        T.stringof ~ ": missing field 'poly: PolyNode'");
    static assert(is(typeof(T.poly) == PolyNode),
        T.stringof ~ ": field 'poly' must have type PolyNode");
    static assert(T.poly.offsetof == 0,
        T.stringof ~ ": 'poly' must be the first field");

    static if (!Policy.managed)
        static assert(!hasManagedRefs!T,
            T.stringof ~ ": Manual mode - item types must not hold"
            ~ " GC-managed references");

    ................
}
```

The trait:

```d
template hasManagedRefs(T)
{
    static if (is(T == class) || is(T == interface))
        enum hasManagedRefs = true;
    else static if (isDynamicArray!T || isAssociativeArray!T || isDelegate!T)
        enum hasManagedRefs = true;
    else static if (isStaticArray!T)
        enum hasManagedRefs = hasManagedRefs!(typeof(T.init[0]));
    else static if (is(T == struct) || is(T == union))
        enum hasManagedRefs = anySatisfy!(hasManagedRefs, Fields!T);
    else
        enum hasManagedRefs = false;     // scalars, pointers, function pointers
}
```

So this compiles under Managed and fails under Manual, with a message naming the
type:

```d
struct Request
{
    PolyNode poly;
    uint id;
    ubyte[] data;      // dynamic array
    string name;       // dynamic array
}
```

Be honest about the limit: the trait checks **types, not provenance**. A
`ubyte*` pointing into GC memory still passes. It catches the mistakes people
actually make, not all of them.

If `std.traits` is awkward under `-betterC`, the same trait is twenty lines with
`__traits(allMembers)`. It is CTFE-only either way, so there is no runtime
dependency to strip.

### Rule: same allocator for items and toolkit objects

There is now one place allocation happens. Mixing is not something an
application can do by accident, because there is no second code path to reach.

### Rule: hooks are `@nogc`

Enforced by the hook alias above, under Manual only.

Two of the five remain runtime concerns and no policy can fix them:
`thread_attachThis` for threads druntime did not create, and anchored
`MonoTime` deadlines.

---

## Two places where the modes genuinely diverge

Both are behavioural, not structural. Document them; do not try to hide them.

**Out of memory.**

```text
Manual     acquire returns null          →  create returns Status.noMemory
Managed    new throws OutOfMemoryError   →  the process dies
```

The null check in `create` is dead code under Managed. Leave it — it costs a
branch and keeps one source.

This is the right outcome. OOM in a GC application is not recoverable in any
useful sense.

**Destructor timing.**

```text
Manual     ~this runs at destroy(), synchronously
Managed    ~this runs when the collector finalizes, later, on another thread
```

That is a real semantic difference and it will bite someone.

The fix is a rule, not code: **item types have no destructors.** Items are
transported data. If one needs teardown, do it in `on_put` where the concrete
type is known and the timing is yours.

Add it as a `static assert` if you want it enforced:

```d
static assert(!__traits(hasMember, T, "__dtor"),
    T.stringof ~ ": item types must not have destructors");
```

---

## What must never be forked

The temptation, once `static if (Policy.managed)` exists, is to use it for more
than allocation. Resist it specifically here:

```text
error model         status codes in both. Never exceptions in one.
API shape           same signatures. Same names. Same order.
send/receive logic  one implementation. No mode-specific fast path.
list, mutex, cond   policy-free. They allocate nothing.
assert set          the same asserts fire in both modes.
```

Every `static if (Policy.managed)` outside `acquire`, `release`, and the hook
aliases is a bug waiting for the mode you did not build.

A useful consequence: because the list, the mutex wrapper and the condvar
wrapper allocate nothing, they need no policy at all. They stay non-template,
compile once, and a precompiled Matryoshka library is mode-agnostic. Only the
templated parts are emitted into the user's compilation, where the mode is
known.

---

## Testing both modes

This is not optional. Attribute inference means an accidental allocation in
shared code fails **only** under Manual.

The check is a test that cannot pass unless the whole call graph is clean:

```d
@nogc nothrow unittest
{
    // If anything reachable from MboxImpl!Manual allocates, throws,
    // or calls a non-@nogc function, this unittest does not compile.
    ubyte[4096] storage = void;
    auto arena  = Arena(storage[]);
    auto policy = Manual(&arena);

    Slot s;
    scope(exit) destroyItem!Request(policy, s);

    assert(create!Request(policy, s) == Status.ok);
    assert(mustFromSlot!Request(s) !is null);
}
```

The unittest *is* the verification. There is nothing to assert about `@nogc` —
the attribute on the unittest does it.

CI runs both dub configurations:

```text
dub test --config=managed
dub test --config=manual
```

And one more check worth having: instantiate every public template against both
policies in a single module, so a mode-specific compile error surfaces in one
build rather than in whichever configuration someone runs next.

---

## Skeleton

```text
matryoshka/
  policy.d        Manual, Managed, DefaultPolicy, the version block
  node.d          Node, PolyNode, PolyTag, reset, isLinked   (policy-free)
  list.d          the intrusive list                          (policy-free)
  sync.d          Mutex, Cond wrappers over pthread / Win32   (policy-free)
  slot.d          Slot                                        (policy-free)
  polyhelper.d    PolyHelperImpl!(T, Policy), TagOf!T, traits
  mailbox.d       MboxImpl!Policy
  pool.d          PoolImpl!(Policy, Hooks), Hooks!Policy
  package.d       the aliases application code imports
```

Five of nine modules are policy-free. That is the audit at the top of this
document, expressed as a directory listing.

---

## Summary

| | Manual | Managed |
|---|---|---|
| item allocation | arena / `malloc` | `new` |
| item release | explicit | collector |
| inferred attributes | `@nogc nothrow` | `nothrow` |
| hook types | `@nogc nothrow` | `nothrow` |
| GC refs in items | compile error | allowed |
| item destructors | discouraged | discouraged |
| OOM | `Status.noMemory` | fatal |
| `-betterC` | reachable | no |
| threads outside druntime | must attach | must attach |
| application source | identical | identical |
| dub configuration | `manual` | `managed` (default) |

---

## The simple rule

The policy is an allocator.

Template what varies. Never template what establishes identity.

`static if (Policy.managed)` appears in three places: `acquire`, `release`, and
the hook aliases. If it appears in a fourth, something has gone wrong.

Test both modes in one CI run, and let a `@nogc` unittest do the proving.
