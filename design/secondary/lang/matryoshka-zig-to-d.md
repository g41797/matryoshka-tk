## Direct mappings

| Zig | D |
|---|---|
| `@fieldParentPtr("poly", node)` | `cast(T*)(cast(void*)node - T.poly.offsetof)` |
| `comptime validatePolyType(T)` + `@compileError` | `static assert(__traits(hasMember, T, "poly"), msg)` |
| `PolyHelper(T)` returning a type | `template PolyHelper(T) { ... }` |
| `no_create_destroy` opt-in | `static if (__traits(hasMember, T, "no_create_destroy"))` |
| `defer` | `scope(exit)` |
| `*anyopaque` | `void*` |
| `?*T`, `Slot` | `PolyNode*`, `alias Slot = PolyNode*` |
| `std.atomic.Value(bool)`, `.acquire`/`.release`/`.monotonic` | `shared bool` + `core.atomic`, `MemoryOrder.acq`/`.rel`/`.raw` |
| `union(enum) Result` | tagged struct, hand-rolled |
| `std.debug.assert` | `assert` |
| `std.debug.runtime_safety` | `debug { }` or your own `version(...)` |

Nothing there is hard. The friction is elsewhere.

## Correction: I was wrong about Mutex and Condition

`core.sync.mutex.Mutex` and `core.sync.condition.Condition` are **classes**, not structs. My earlier `Mutex m = void; m.__ctor();` was nonsense. You cannot embed them by value in a malloc'd `Mbox`. Your options are `emplace` into a byte buffer sized by `__traits(classInstanceSize, Mutex)`, or skip druntime.

Skip druntime. Write ~60 lines wrapping `pthread_mutex_t` / `pthread_cond_t` and `CRITICAL_SECTION` / `CONDITION_VARIABLE` as plain structs. You get three things you need: embeddable by value, `@nogc nothrow` throughout, and `pthread_condattr_setclock(CLOCK_MONOTONIC)`.

That last one matters — see below.

## The four decisions that actually matter

**1. `Io` disappears, and cancellation goes with it.**

Every `io` parameter and the `io` field vanish. `lockUncancelable(io)` becomes `m.lock()`. But `self.mutex.lock(io) catch |err| return err` in `receive` and `get_wait` has no D equivalent — a pthread mutex acquisition cannot be cancelled. So `Io.Cancelable` leaves both error sets, and `Result.canceled` becomes unreachable.

You are closer to a replacement than it looks. `wake_epoch` plus `broadcast` is already a working out-of-band interruption mechanism. Add a per-waiter cancel flag checked in the same `while` condition and you have cancellation without a runtime. Given your conclusion that `Io.Group` is wrong for long-lived thread pools, this is a simplification, not a loss.

Corollary: `receive_future`, `get_wait_future`, `receiveResult`, `getWaitResult`, and both `Result` unions have no D analog and should not be ported. That deletes a large fraction of the surface and most of the error-mapping code.

**2. Deadline anchoring must be rebuilt by hand.**

You anchor `deadline` once before the retry loop, deliberately, so spurious wakeups don't restart the timeout. `Condition.wait` in D takes a `Duration`, not a deadline. So each iteration:

```d
immutable deadline = MonoTime.currTime + dur;
while (...) {
    auto left = deadline - MonoTime.currTime;
    if (left <= Duration.zero) return Status.timeout;
    if (!cond.wait(left)) { /* timeout */ }
}
```

Same intent, more code, and the clamp at zero is load-bearing.

**3. Replace both hash maps in `Pool` with parallel arrays.**

`lists` and `counts` are keyed by tag, populated once in `init` from `hooks.tags`, and never gain a key. `AutoHashMapUnmanaged` is buying you nothing for a handful of tags. In D, use two fixed arrays allocated once alongside `hooks.tags` and linear-search by pointer.

This removes the allocator dependency from `Pool`'s hot path, removes `ensureTotalCapacity` and its OOM path, removes `clearRetainingCapacity` from `close`, and makes `lists.contains(tag)` a three-comparison loop instead of a hash. Linear search over 4–8 pointers beats hashing at every size you care about.

**4. Write your own intrusive list. Do not port `ItemList`'s std interop.**

`std.container.dlist` is value-based and GC-allocating. Nothing in Phobos fits. Write the 40 lines.

You come out ahead. Your own list means `remove` clears links intrinsically, so the entire hazard documented at the bottom of `polynode.zig` — `_list` exposed, `reset` needed by hand, false positives from `is_linked` — disappears. You can also keep an O(1) `len`, which retires the comment about mailbox and pool needing their own counters. And `moveFromList`/`moveToList` exist only to interop with `std.DoublyLinkedList`; drop both.

## Two things D gives you that Zig cannot

**`@mustuse` on `ItemList`.** Your doc comment says *"Never write `_ = mbx.close()`. It drops items the mailbox gave back."* In D that stops being a comment:

```d
import core.attribute : mustuse;

@mustuse struct ItemList { ... }
```

Discarding the result of `close()` is now a compile error. This is the single strongest argument for the port — your most dangerous documented rule becomes a type error.

**`@disable this(this)` on `ItemList` and `Slot`.** The comment at line 523, *"There is no copy form. A header copy aliases the same items"*, is currently enforced by convention. Disable the postblit and an accidental header copy won't compile. Same for the double-send class of bug that `is_linked` admits it cannot always catch.

## One bug in the Zig, worth fixing before you port

`receive` and `get_wait` both build the timeout with `.clock = .real`. That is wall clock. An NTP step or a manual clock change extends or collapses every pending timeout in the process. Timeouts want monotonic.

Since the D port needs its own condvar wrapper anyway, set `CLOCK_MONOTONIC` on the condattr there and use `MonoTime`. Then fix the Zig side to match, or the two implementations will disagree under clock adjustment and you'll be debugging it through a test that only fails on one machine.

## Two smaller gotchas that will bite

**`static` in D is thread-local.** `var _tag: PolyTag = .{}` inside `PolyHelper` becomes:

```d
__gshared PolyTag _tag;
```

If you write `static PolyTag _tag;`, every thread gets its own copy, tag addresses differ per thread, and `fromPoly` returns `null` for any item that crossed a thread boundary. Silent, and it will look like a memory corruption bug. This is the port's most likely one-character disaster.

`TAG` also can't be an `enum` — the address of a `__gshared` isn't a compile-time constant. Use `pragma(inline, true) void* TAG() @nogc nothrow { return &_tag; }`. Outside betterC, `typeid(T)` is an alternative with a genuinely unique per-type address; inside betterC it isn't available.

**`shared` is transitive and D means it.** Make `closed` a `shared bool` and leave the rest of `Mbox` unshared, using `core.atomic` at the access sites. If you mark the whole struct `shared`, every field access needs a cast and you will end up casting so routinely that the qualifier stops meaning anything.

`*Slot` is an in/out parameter. D has a direct keyword for that — `ref` — so you never write `PolyNode**` at a call site.

## Layer 1: the plain alias

```d
alias ItemHandle = PolyNode*;
alias Slot       = PolyNode*;   // null == empty
```

Signatures translate mechanically:

| Zig | D |
|---|---|
| `fn send(self: *Mbox, slot: *Slot) error{Closed}!void` | `Status send(ref Slot slot)` |
| `fn receive(self: *Mbox, slot: *Slot, ...)` | `Status receive(ref Slot slot, ...)` |
| `fn create(alloc, slot: *Slot) !void` | `Status create(T)(ref Slot slot)` |
| `slot.* = null` | `slot = null` |
| `slot.* orelse return null` | `if (slot is null) return null;` |
| `slot.*.?` | `slot` |

The `.?` disappears because `PolyNode*` is both the nullable and the non-nullable type. That is the whole loss: nothing distinguishes "checked" from "unchecked" any more.

Helper side:

```d
template PolyHelper(T)
{
    static assert(__traits(hasMember, T, "poly"),
        T.stringof ~ ": missing field 'poly'");
    static assert(is(typeof(T.poly) == PolyNode),
        T.stringof ~ ": field 'poly' must be PolyNode");

    private __gshared PolyTag _tag;   // __gshared, not static

    pragma(inline, true)
    void* TAG() @nogc nothrow { return &_tag; }

    pragma(inline, true)
    T* fromPoly(PolyNode* n) @nogc nothrow @trusted
    {
        if (n is null || n.tag !is TAG) return null;
        return cast(T*)(cast(void*)n - T.poly.offsetof);
    }

    pragma(inline, true)
    PolyNode* toPoly(T* self) @nogc nothrow @trusted { return &self.poly; }

    // *const Slot  ->  const scope ref
    T* fromSlot(const scope ref Slot slot) @nogc nothrow
    {
        return fromPoly(cast(PolyNode*) slot);
    }

    T* mustFromSlot(const scope ref Slot slot) @nogc nothrow
    {
        auto p = fromSlot(slot);
        assert(p !is null);
        return p;
    }

    T* moveFromSlot(ref Slot slot) @nogc nothrow
    {
        auto p = fromSlot(slot);
        if (p is null) return null;
        assert(!isLinked(slot));
        slot = null;
        return p;
    }
}
```

Call sites read almost identically to the Zig:

```d
Slot s = null;
scope(exit) freeSlot(s);                  // defer-before-acquisition

if (create!Event(s) != Status.ok) return;
mustFromSlot!Event(s).code = 53;
if (mbx.send(s) != Status.ok) { /* still ours */ }
```

`scope(exit)` evaluates `freeSlot(s)` at exit, reading `s` as it is then — so the no-op-on-empty property that makes defer-before-acquisition safe carries over unchanged.

## Layer 2: the wrapper, and why it's worth it

The alias works. It gives up two invariants you currently defend with asserts and doc comments. A wrapper takes both back:

```d
import core.attribute : mustuse;

@mustuse struct Slot
{
    private PolyNode* h;

    @disable this(this);                       // no silent aliasing copy
    @disable void opAssign(ref Slot);

    this(PolyNode* n) @nogc nothrow { h = n; }

    ~this() @nogc nothrow
    {
        // The Slot never knows how to release. It only knows it must be empty.
        assert(h is null, "Slot destroyed non-empty — item leaked");
    }

    bool empty() const @nogc nothrow { return h is null; }

    PolyNode* peek() @nogc nothrow { return h; }

    PolyNode* take() @nogc nothrow            // the only way out
    {
        auto t = h;
        h = null;
        return t;
    }

    void put(PolyNode* n) @nogc nothrow       // the only way in
    {
        assert(h is null, "Slot already holds an item");
        assert(!isLinked(n));
        h = n;
    }
}
```

Three properties you cannot express in Zig:

- **`@disable this(this)`** — `Slot a = b;` won't compile. Two Slots can never name one item, so the double-send class of bug that `is_linked` openly admits it cannot always catch becomes a compile error instead.
- **`~this` asserting empty** — a Slot that goes out of scope still holding an item fires at the exact line the leak happened, in debug builds, with no tracking machinery. This is the leak detector for the whole idiom.
- **`@mustuse`** — combined with returning `Slot` by value anywhere, discarding it won't compile.

The destructor deliberately does not release. It cannot: the Slot has no idea whether the item is heap-owned, pool-owned, or borrowed — which is exactly the knowledge the mailbox doesn't have either. Assert, don't guess.

Cost: `slot.*` becomes `slot.peek()` / `slot.take()` / `slot.put()` at every internal site, and `create`/`destroy` need friend access, which D gives you via `package` or by putting the helper in the same module.

## What I would not do

`Nullable!(PolyNode*)` from `std.typecons` wraps a type that is already nullable, drags in Phobos, and costs a bool. It buys nothing here.

## One knock-on simplification

`Hooks.on_put` returns `?ItemList` in Zig, and the doc says *"null or an empty list: nothing more to add."* Those two cases are already identical in meaning. In D just return `ItemList` and test `isEmpty()`. One less nullable in the API, no behaviour change.

Right — and the three languages sit at three different points.

| | non-nullable pointer | optional type | compiler forces the unwrap |
|---|---|---|---|
| **Zig** | `*T` — yes | `?T`, language-level | yes: `orelse`, `.?`, `if (x) \|v\|` |
| **Odin** | no, `^T` is nullable | `Maybe(T)` in core, plus the implicit nil state of every union | yes for `Maybe`: `v, ok := m.?` |
| **D** | no | none — `std.typecons.Nullable!T` is a library struct | no |

So Odin is the middle case, and you already hit exactly this problem there. `?*T` in Zig became `^Maybe(^T)` in odin-itc precisely because `^T` alone is nullable and gives you no checked unwrap. The `Maybe` wrapper was how you got the discipline back.

D is the weakest of the three. No `?T`, no non-null pointer, no `orelse`, no payload capture, and `Nullable!T` doesn't collapse to pointer-size the way Zig's `?*T` does — it's a `bool` plus storage, so wrapping a pointer in it costs you two words and buys nothing you can't get from `is null`.

Which means: **the wrapper `struct Slot` from the previous message is D's `Maybe`.** Same role your Odin `Maybe(^T)` plays. You are doing the same thing you already did once, for the same reason.

The difference is what you get in exchange. Odin's `Maybe` gives you a checked unwrap and nothing more — a `Maybe(^T)` can still be copied, so two of them can name one item. D's wrapper gives up the checked unwrap (you write `slot.empty()` instead of `.?`) and gains two things neither Zig nor Odin can express:

- `@disable this(this)` — one owner, enforced at compile time
- `~this()` asserting empty — leak detected at the line where it happened

For the Slot idiom specifically that trade is favourable. The invariant you actually care about is *exactly one owner, and it must be empty when it dies*. Zig's `?*T` enforces neither; it only stops you from dereferencing without checking. D inverts which half you get.

# Mbox and Pool as no gs objects

## Mbox: yes

Nothing in it allocates on the item path. It never touches an item at all. Every field ports to a no-GC equivalent:

| field | D |
|---|---|
| `poly` | `PolyNode` — plain struct |
| `mutex`, `cond` | your own pthread/Win32 wrapper structs |
| `list` | your own intrusive list |
| `len`, `oob_count`, `oob_last`, `wake_epoch` | plain |
| `closed` | `shared bool` + `core.atomic` |
| `io` | gone |
| `alloc` | see below |

Two replacements are mandatory, both already discussed: `core.sync.Mutex` and `Condition` are classes, so you write the primitives; and `std.DoublyLinkedList` has no D counterpart, so you write the list.

One new one: **do not use `std.experimental.allocator`.** `RCIAllocator` and friends are not `@nogc`, so a single field of that type poisons every method that touches it. `Mbox` needs an allocator for exactly two calls — `mailbox.new` and `mailbox.destroy`, one struct each. A two-function-pointer vtable, or `malloc`/`free` directly, covers it.

So: `Mbox` is `@nogc nothrow` end to end, verified by the compiler.

## Pool: two changes, one of them a real decision

**Change 1, mechanical.** `AutoHashMapUnmanaged` has no `@nogc` equivalent in Phobos. D's built-in AA (`ItemList[void*]`) is GC-only. This is a hard blocker, and the fix is the one I suggested earlier: parallel arrays sized from `hooks.tags` at construction. Not a workaround — the maps never gain a key after `init`, so they were never earning their cost.

**Change 2, a decision.** This is the part the claim glosses over:

> A `@nogc` function cannot call a function pointer whose type is not `@nogc`.

Your hooks are function pointers. So you cannot have both of these:

- `Pool.get`, `put`, `close` marked `@nogc`
- hooks that a GC-using application can supply

Earlier I advised leaving `@nogc` *off* the hook types, so GC applications aren't locked out. That advice stands, but it costs you the attribute on `Pool` itself. Three ways out:

**(a) Mark the hook types `@nogc nothrow`.** `Pool` is fully `@nogc`, verified. GC-using applications must cast their hook to a `@nogc` pointer — a well-known D escape hatch, and their problem rather than yours. Consistent with a no-GC toolkit.

**(b) Leave the hook types unattributed.** `Pool` methods carry no `@nogc`. The pool is still GC-free *in fact* — it allocates nothing, ever — just not attribute-verified. "No-GC struct" remains true as a statement about behaviour, not as a compiler guarantee.

**(c) Template `Pool` on the hooks type.** D infers attributes for templates, so `Pool!NoGcHooks` comes out `@nogc` and `Pool!GcHooks` does not, from one implementation. This is the best answer and the only one with no trade-off — except that each instantiation would get its own `PolyTag`, so a pool would no longer have one type ID.

That last problem is fixable in one line: put the pool's tag at **module scope**, not inside the template.

```d
private __gshared PolyTag _poolTag;   // one ID for every Pool!H
```

Then every instantiation shares one type ID, and a pool transported through a mailbox is still recognisably a pool. I would take (c).

## The distinction worth keeping straight

`@nogc` is a compiler-checked promise. "No-GC" is a property of the code. They come apart in exactly one place here — the hooks — and nowhere else. Both structs are GC-free by construction regardless of which option you pick; the only question is whether the compiler will say so.

Two things that do *not* block `@nogc`, in case you were planning around them: `assert` is permitted in `@nogc` functions, and it is also permitted in `nothrow` ones, because `AssertError` is an `Error` rather than an `Exception`. Your assert-heavy style survives intact.

## If you want `-betterC` too, that is a separate claim

`@nogc` and `-betterC` are not the same target. Plain no-GC D keeps `TypeInfo`, module constructors, and `core.sync`. `-betterC` drops all three, plus `ModuleInfo` and exceptions.

For these two structs the betterC delta is small — you have already given up `core.sync`, exceptions, and `typeid` (which is why the tag is a `__gshared PolyTag`). Templates, `static if`, `static assert`, `__gshared`, struct destructors, and `core.atomic` all survive. So betterC is reachable, but confirm it as its own goal rather than assuming `@nogc` delivered it.

Application Items - used via PolyNode - gc, no gc, or matryoshka does not care



# Build with sources of foreign modules

## D's equivalent

```json
{
    "name": "matryoshka",
    "targetType": "sourceLibrary",
    "importPaths": ["source"]
}
```

`sourceLibrary` builds nothing. Dub adds your `.d` files to the consumer's compilation. Same model as Zig's `addModule` and an Odin collection directory.

For this design it isn't just convenient, it's close to mandatory. Most of the toolkit is templates, so a static library would emit almost nothing anyway — templates are instantiated in the consumer's compilation regardless.

## Where it changes my advice

I recommended `version(MatryoshkaManual)`. In source mode there's a better option: **select the mode by import.**

```d
// source/matryoshka/manual.d
public import matryoshka.impl;
alias Mbox          = MboxImpl!Manual;
alias PolyHelper(T) = PolyHelperImpl!(T, Manual);
alias Pool(H)       = PoolImpl!(Manual, H);

// source/matryoshka/managed.d
public import matryoshka.impl;
alias Mbox          = MboxImpl!Managed;
alias PolyHelper(T) = PolyHelperImpl!(T, Managed);
alias Pool(H)       = PoolImpl!(Managed, H);
```

Consumer:

```d
import matryoshka.manual;   // or matryoshka.managed
```

Better than `version` on four counts:

- No build flag, no dub configuration, no version identifier to document.
- No question about whether `versions` propagates into a dependency — it doesn't reliably, and this sidesteps it entirely.
- Both modes always compile, in every build. Your CI problem disappears rather than being solved.
- The mode is visible in the source file that uses it, not buried in a build file three directories up.

Cost: the "never mix" rule is no longer enforced by there being only one `DefaultPolicy`. Importing both in one module gives you an ambiguous `Mbox` at the use site — a real error, but only at use. Across separate modules, nothing complains. Document it as a rule; it was a rule before too.

## Three source-mode specifics worth knowing

**Your unittests land in the consumer's binary.** Anyone compiling with `-unittest` gets your test blocks compiled and run alongside theirs. Keep tests in a directory outside `sourcePaths` and pull it in only under a `unittest` configuration:

```json
"configurations": [
    { "name": "library", "targetType": "sourceLibrary" },
    { "name": "unittest", "targetType": "executable", "sourcePaths": ["source", "tests"] }
]
```

**`-betterC` becomes the consumer's flag, applied to your sources too.** You can't verify betterC compatibility from your side alone — only a betterC test *program* built against your sources proves it. Worth a third dub configuration.

**One thing from the policy doc no longer applies.** It says the policy-free modules — the list, the mutex wrapper, `slot.d`, `node.d` — could be precompiled once and stay mode-agnostic. In source mode there's nothing precompiled, so that paragraph is dead weight. The modules are still policy-free, which is the part that matters; the packaging benefit isn't real for you.


