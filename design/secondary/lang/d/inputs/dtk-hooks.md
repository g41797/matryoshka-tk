# Pool hooks - D implementation

## Shape mapping

| Zig | D |
|---|---|
| `*const fn (...) void` | `void function(...) @nogc nothrow` |
| `ctx: *anyopaque` | `void* ctx` |
| `tag: *const anyopaque` | `const(void)* tag` |
| `slot: *polynode.Slot` (ptr to optional) | `ref Slot slot` |
| `?polynode.ItemList` | `ItemList` returned by value |
| `?ItemHandle` | `ItemHandle` (pointer, `null` = empty) |

Two things collapse on the way over.

`?ItemList` doesn't need an optional. Your own doc says `null` and empty list mean the same thing, so a default-initialised `ItemList` covers both cases.

`?ItemHandle` doesn't need one either, as long as `ItemHandle` stays a pointer. The null state is already in the type. You lose Zig's flow-typed unwrap — after `if (slot !is null)` the compiler still thinks it might be null — but the `*?*T` transfer idiom survives intact: `ref Slot` is Zig's `*Slot`, and `Slot` is the nullable half. Use `ref` for the outer indirection, never a raw pointer; that keeps the non-nullable/nullable distinction visible at the signature.

## The hooks table

```d
module matryoshka.pool;

import matryoshka.polynode : Slot, ItemList;

alias Tag = const(void)*;

alias OnGet   = void     function(void* ctx, Tag tag, size_t inPoolCount, ref Slot slot) @nogc nothrow;
alias OnPut   = ItemList function(void* ctx, size_t inPoolCount, ref Slot slot) @nogc nothrow;
alias OnClose = void     function(void* ctx, ref ItemList list) @nogc nothrow;

struct Hooks
{
    void*        ctx;
    const(Tag)[] tags;
    OnGet        onGet;
    OnPut        onPut;
    OnClose      onClose;
}
```

The attributes on the alias are not decoration. `@nogc nothrow` is a compile-time enforced piece of the contract — a hook cannot allocate, and cannot throw through the pool's internals. Zig can't state that in the type. Conversion is one-way: a stricter function implicitly converts to a looser pointer type, never the reverse, so a hook that GC-allocates fails to compile at the assignment site rather than at 3am.

## Type tags without TypeInfo

`typeid` drags in `TypeInfo`, which betterC won't give you. Use the address of a per-type static as the tag:

```d
Tag tagOf(T)() @nogc nothrow pure
{
    static immutable ubyte anchor = 0;
    return &anchor;
}
```

One instantiation per `T`, one byte in `.rodata`, address is stable and unique. Same semantics as `*const anyopaque` pointing at a type-erased marker.

## Killing the cast boilerplate

Write the thunks once, in a template, so user code is plain methods on a plain struct:

```d
Hooks makeHooks(T)(T* self, const(Tag)[] tags) @system @nogc nothrow
{
    static void getThunk(void* ctx, Tag tag, size_t n, ref Slot slot) @nogc nothrow
    {
        (cast(T*) ctx).onGet(tag, n, slot);
    }
    static ItemList putThunk(void* ctx, size_t n, ref Slot slot) @nogc nothrow
    {
        return (cast(T*) ctx).onPut(n, slot);
    }
    static void closeThunk(void* ctx, ref ItemList list) @nogc nothrow
    {
        (cast(T*) ctx).onClose(list);
    }

    return Hooks(cast(void*) self, tags, &getThunk, &putThunk, &closeThunk);
}
```

The nested functions are `static`, so they're ordinary function pointers, generated per `T` at compile time. No vtable, no indirection beyond the one pointer call, no allocation.

## The sample, ported

```d
struct SampleHooks
{
    @disable this(this);          // see note below

    Allocator alloc;
    size_t    cap;
    Mutex     mutex;
    size_t    count;

    Hooks poolHooks(const(Tag)[] tags) @system @nogc nothrow return
    {
        return makeHooks(&this, tags);
    }

    void onGet(Tag tag, size_t, ref Slot slot) @nogc nothrow
    {
        mutex.lock();
        scope (exit) mutex.unlock();

        if (slot !is null)
        {
            count--;              // came from pool; mirror the pool's decrement
            return;
        }
        createByTag(tag, alloc, slot);   // fresh item, not counted until put back
    }

    ItemList onPut(size_t, ref Slot slot) @nogc nothrow
    {
        if (slot is null) return ItemList.init;

        mutex.lock();
        scope (exit) mutex.unlock();

        if (count >= cap)
        {
            freeItem(slot, alloc);
            slot = null;
        }
        else
        {
            resetOnPut(slot);
            count++;
        }
        return ItemList.init;
    }

    void onClose(ref ItemList list) @nogc nothrow
    {
        freeList(list, alloc);
        count = 0;
    }
}
```

`scope(exit)` is `defer`. Same shape, same line count.

## Four things that will bite

**Lifetime of `ctx`.** Zig's `self: *Self` makes the escape obvious. D's `&this` on a value type does not — copy the struct and the copy's hooks table still points at the original, or at a dead temporary. `@disable this(this)` plus a `return` attribute on `poolHooks` is the cheap defence. The hooks struct must outlive the pool; state that in the doc comment as loudly as the "your code runs in the heart of Matryoshka" line.

**The mutex.** `core.sync.mutex.Mutex` is a class. Options that aren't: raw `pthread_mutex_t` / `SRWLOCK` behind a small struct, or `core.internal.spinlock.SpinLock` — struct, `@nogc`, betterC-clean, but an internal module, so wrap it rather than using it directly. Note that D has no `lockUncancelable` distinction, so the "a hook returns void and can't report a cancelled lock" paragraph just disappears from the D docs.

**`shared`.** Hooks run concurrently and unserialised, so `count` is logically shared. D's `shared` won't survive the trip through `void*` anyway, so it buys you nothing at the boundary. Either mark the field `shared` and use `core.atomic` inside the lock-free paths, or keep it plain and treat the mutex as the whole story — but pick one and write it down.

**Asserts.** `assert` is stripped by `-release`, which matches your ReleaseFast/ReleaseSmall behaviour. The tag-mismatch check ports as a plain `assert` with no ceremony.

# The delegate alternative

Same functionality, minus the `ctx` field and every cast.

## The hooks table

```d
module matryoshka.pool;

import matryoshka.polynode : Slot, ItemList;

alias Tag = const(void)*;

alias OnGet   = void     delegate(Tag tag, size_t inPoolCount, ref Slot slot) @nogc nothrow;
alias OnPut   = ItemList delegate(size_t inPoolCount, ref Slot slot) @nogc nothrow;
alias OnClose = void     delegate(ref ItemList list) @nogc nothrow;

struct Hooks
{
    const(Tag)[] tags;
    OnGet        onGet;
    OnPut        onPut;
    OnClose      onClose;
}
```

A delegate is `{ void* ptr; F funcptr; }`. Taking `&self.onGet` fills `ptr` with `self` and `funcptr` with the method's address. No allocation, no vtable, no class. The context that was explicit in the Zig version is now the delegate's own first word.

## The sample

```d
struct SampleHooks
{
    @disable this(this);

    Allocator alloc;
    size_t    cap;
    Mutex     mutex;
    size_t    count;

    Hooks poolHooks(const(Tag)[] tags) @nogc nothrow return
    {
        return Hooks(tags, &this.onGet, &this.onPut, &this.onClose);
    }

    void onGet(Tag tag, size_t, ref Slot slot) @nogc nothrow
    {
        mutex.lock();
        scope (exit) mutex.unlock();

        if (slot !is null)
        {
            count--;              // came from pool; mirror the pool's decrement
            return;
        }
        createByTag(tag, alloc, slot);   // fresh item, not counted until put back
    }

    ItemList onPut(size_t, ref Slot slot) @nogc nothrow
    {
        if (slot is null) return ItemList.init;

        mutex.lock();
        scope (exit) mutex.unlock();

        if (count >= cap)
        {
            freeItem(slot, alloc);
            slot = null;
        }
        else
        {
            resetOnPut(slot);
            count++;
        }
        return ItemList.init;
    }

    void onClose(ref ItemList list) @nogc nothrow
    {
        freeList(list, alloc);
        count = 0;
    }
}
```

`poolHooks` no longer needs `@system` — no cast, so it can stay `@safe` if the rest of the struct allows it. `return` is still required: the delegates carry `&this` out of the function.

## Call site inside the pool

```d
// on get, after the item was taken under the lock
Slot slot = takeUnderLock(tag);
hooks.onGet(tag, remaining, slot);
assert(slot is null || tagOfItem(slot) is tag, "hook returned wrong tag");
```

One extra concern versus the function-pointer version: a delegate has two words, so "is this hook installed" is `hooks.onGet !is null` (which tests `funcptr`). If hooks are mandatory, validate once when the pool is constructed rather than on every call:

```d
Pool init(Hooks hooks, ...)
{
    assert(hooks.onGet !is null && hooks.onPut !is null && hooks.onClose !is null);
    ...
}
```

## Optional: check the shape at compile time

If you want a single entry point that also produces a readable error when a method is missing or mis-attributed:

```d
Hooks makeHooks(T)(return T* self, const(Tag)[] tags) @nogc nothrow
{
    static assert(is(typeof(&self.onGet)   : OnGet),   T.stringof ~ ": bad or missing onGet");
    static assert(is(typeof(&self.onPut)   : OnPut),   T.stringof ~ ": bad or missing onPut");
    static assert(is(typeof(&self.onClose) : OnClose), T.stringof ~ ": bad or missing onClose");

    return Hooks(tags, &self.onGet, &self.onPut, &self.onClose);
}
```

Without it, a `@nogc`-violating method produces a conversion error pointing at the struct literal, which is survivable but not friendly.

## What changes in the contract

**Attributes must match exactly on the method, not just be compatible in spirit.** `@nogc nothrow` is required. Qualifiers leak into the delegate type: a `const` method yields `const` context and won't convert to `OnGet`. Leave the hook methods unqualified.

**The one allocation trap is nested functions, not methods.** `&self.method` never allocates. A nested function that captures a local does — D puts the closure on the GC heap. `@nogc` on the alias rejects that at compile time, so the trap is closed by the type, not by discipline.

**Lifetime is unchanged and still yours to manage.** The delegate's context word is `&this`. Copy the struct and the pool keeps calling the original; let it die and you have a dangling context. `@disable this(this)` plus `return` on `poolHooks` covers the common accidents, nothing covers a heap-allocated hooks struct freed early.

**Three different owners are now possible.** Nothing forces the three delegates to share a context. `onClose` can belong to a shutdown coordinator while `onGet`/`onPut` belong to the cache. The Zig version can't express that with one `ctx`. Useful occasionally, and worth a sentence in the docs so nobody assumes the old invariant still holds.

[Note] - problem of using druntime Mutex

Yes, and `@nogc` isn't the obstacle. `@nogc` only forbids GC allocation — locking is fine. The obstacle is that druntime's `Mutex` is a class, so constructing one means `new`, which means GC. Its methods are already `@nogc nothrow`; only the birth is a problem.

Since classes are out anyway, wrap the OS primitive.

## A struct mutex

```d
version (Posix)
{
    import core.sys.posix.pthread;

    struct Mutex
    {
        @disable this(this);
        private pthread_mutex_t m;

        void initialize() @nogc nothrow { pthread_mutex_init(&m, null); }
        void terminate()  @nogc nothrow { pthread_mutex_destroy(&m); }
        void lock()       @nogc nothrow { pthread_mutex_lock(&m); }
        void unlock()     @nogc nothrow { pthread_mutex_unlock(&m); }
    }
}
else version (Windows)
{
    struct SRWLOCK { void* ptr; }

    extern (Windows) @nogc nothrow
    {
        void AcquireSRWLockExclusive(SRWLOCK*);
        void ReleaseSRWLockExclusive(SRWLOCK*);
    }

    struct Mutex
    {
        @disable this(this);
        private SRWLOCK m;        // SRWLOCK_INIT is all-zero

        void initialize() @nogc nothrow {}
        void terminate()  @nogc nothrow {}
        void lock()       @nogc nothrow { AcquireSRWLockExclusive(&m); }
        void unlock()     @nogc nothrow { ReleaseSRWLockExclusive(&m); }
    }
}
```

Thirty lines, no allocation, betterC-clean, works in all three of your environments.

Three details that matter. `@disable this(this)` is mandatory — a copied `pthread_mutex_t` is garbage, and your hooks struct already hands out `&this`, so it must not move after the delegates are built. Call `initialize()` explicitly: zero-init happens to be valid for a Linux `pthread_mutex_t` and for `SRWLOCK`, but not on macOS, where the initializer carries a magic signature. Both are non-recursive, which is what you want — re-entry from a hook is a bug, and you'd rather it deadlock loudly than succeed quietly.

`core.internal.spinlock.SpinLock` is the other option: struct, `@nogc`, no init call. It's an internal module, so wrap it behind the same three methods if you use it, and don't spin across an allocator call.

## The sample doesn't need one

Look at what the lock is actually protecting in the Zig version — a `size_t` and a cap check. And look at what's inside the critical section: `createByTag` and `freeItem`. You're holding a lock across the allocator, on every miss, in a hook the pool explicitly refuses to serialize. That's the contention, not the counter.

The counter alone is a CAS loop:

```d
import core.atomic;

struct SampleHooks
{
    @disable this(this);

    Allocator     alloc;
    size_t        cap;
    shared size_t count;

    void onGet(Tag tag, size_t, ref Slot slot) @nogc nothrow
    {
        if (slot !is null)
        {
            atomicFetchSub(count, 1);   // came from pool; mirror the decrement
            return;
        }
        createByTag(tag, alloc, slot);  // fresh item, no lock held
    }

    ItemList onPut(size_t, ref Slot slot) @nogc nothrow
    {
        if (slot is null) return ItemList.init;

        for (;;)
        {
            const c = atomicLoad(count);
            if (c >= cap) break;                 // full — fall through and free
            if (cas(&count, c, c + 1))
            {
                resetOnPut(slot);
                return ItemList.init;
            }
        }

        freeItem(slot, alloc);
        slot = null;
        return ItemList.init;
    }

    void onClose(ref ItemList list) @nogc nothrow
    {
        freeList(list, alloc);
        atomicStore(count, 0UL);
    }
}
```

`onPut` is check-then-act, so it needs the CAS loop rather than a bare increment. `onGet`'s decrement doesn't. `onClose` runs once, after the pool is closed, with no concurrent hooks — the atomic store there is hygiene, not necessity.

## When you still need the lock

The allocator. `Mallocator` is thread-safe; a region, freelist, or arena allocator generally is not. If your `alloc` isn't safe for concurrent use, the lock goes around the allocator call and nothing else — never around the counter as well, or you've serialized every put behind every miss.

```d
mutex.lock();
createByTag(tag, alloc, slot);
mutex.unlock();
```

Which raises a wording problem in the Zig doc you'll inherit. It says a hook must not call blocking operations, then two paragraphs later tells the hook to take an `Io.Mutex`. In Zig the distinction is carried by `Io` — blocking the *scheduler* is the sin, a brief mutex is not. D has no `Io`, so that distinction evaporates and the contract reads as self-contradictory. For the D docs I'd state it plainly: a hook may take a lock it owns, for a bounded and short span; it must not block on IO, on a condition variable, or on anything the pool itself could be holding.