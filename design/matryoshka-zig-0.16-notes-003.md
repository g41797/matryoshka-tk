# Matryoshka in Zig 0.16 — Notes (003)


Change from -002: API 12-4 — the doc speaks the pointer API. Methods on  
`*Mbox` / `*Pool`; `new`, `destroy`, `receiveResult`, `getWaitResult` stay  
free functions on the module.


What Zig 0.16 provides, what it removed, and how cancellation works. The  
constraints these impose are why `matryoshka-tk` is shaped the way it is.

Replaces the 0.16 implementation guide, a pre-implementation feasibility study.  
The port shipped, so the block-by-block build instructions went with it; the  
Odin idiom mapping moved to
[secondary/odin-to-zig-backport-001.md](secondary/odin-to-zig-backport-001.md).

Companion: [matryoshka-api-reference-040.md](matryoshka-api-reference-040.md) — the API surface.\  
Companion: [rules-046.md](rules-046.md) — the rules these constraints justify.

`.minimum_zig_version` is `0.16.0`.

---

# 1. std.Io is the concurrency interface

`std.Io` in 0.16 is not narrow "bytes from files" I/O.

It is the complete concurrency and scheduling interface: file system,  
networking, processes, time, mutexes, futexes, events, conditions.

`Io.Mutex` and `Io.Condition` are real types. They are not wrappers around  
`std.Thread.Mutex/Condition`. They are backed by `io.futexWait` through the  
vtable:

```zig
// Io.Mutex.lock — takes io, returns Cancelable
pub fn lock(m: *Mutex, io: Io) Cancelable!void {
    ...
    try io.futexWait(State, &m.state.raw, .contended);
}

// Io.Condition.wait — takes io, returns Cancelable
pub fn wait(cond: *Condition, io: Io, mutex: *Mutex) Cancelable!void {
    ...
    try io.futexWait(u32, &cond.epoch.raw, epoch);
}
```

Consequences:

- Every wait is a cancellation point returning `Cancelable!void`.
- `_Mailbox` and `_Pool` use `Io.Mutex` and `Io.Condition`.
- All `std.Thread.*` synchronization primitives were removed in 0.16.0.

# 2. Removed primitives — hard constraint

These do not exist in `std.Thread` anymore.

| Removed | Replacement |
|---------|------------|
| `Thread.Mutex` | `Io.Mutex` |
| `Thread.Condition` | `Io.Condition` |
| `Thread.Futex` | `Io.Futex` |
| `Thread.ResetEvent` | `Io.Event` |
| `Thread.WaitGroup` | `Io.Group` |
| `Thread.Semaphore` | `Io.Semaphore` |
| `Thread.RwLock` | `Io.RwLock` |
| `Thread.Pool` | `Io.Group` + `io.concurrent()` |
| `Thread.Mutex.Recursive` | (no replacement — design smell) |

`std.Thread.spawn` and `std.Thread.join` still exist. Only the sync primitives  
and thread pool are gone.

This is not a recommendation. "Must not use" now means "does not exist."

`std.Thread.Mutex/Condition` would not go through the Io vtable and could not  
return `error.Canceled`. They never appear in `_Mailbox` or `_Pool`.

This is the mechanical reason behind the `std.Thread.spawn` ban in
[rules-046.md](rules-046.md): a thread spawned outside Io carries no
cancellation token, so nothing can wake it but a close broadcast.

# 3. Two backends

```text
Io.Threaded   OS threads + futex.        Production-ready.   ← target this
Io.Evented    fibers (green threads).    Work in progress.   Not production-ready.
```

`_Mailbox` and `_Pool` are correct on both backends — all blocking goes through  
the Io vtable.

Tests use the single-threaded backend:

```zig
const io = std.Io.Threaded.global_single_threaded.io();
```

# 4. Task spawning

Two Io-native spawning APIs:

```zig
// io.async — may run eagerly (single-threaded: runs to completion inline)
pub fn async(io: Io, function: anytype, args: ...) Future(ReturnType)

// io.concurrent — requires actual concurrency (else ConcurrentError)
pub fn concurrent(io: Io, function: anytype, args: ...) ConcurrentError!Future(ReturnType)
```

A Master is a task created with `io.concurrent()`. `io.async` may run inline,  
which is not a Master.

`Future(T)` has two methods:

```zig
pub fn cancel(f: *Future(T), io: Io) T  // request cancelation, then await
pub fn await(f: *Future(T), io: Io)  T  // await completion without cancelation
```

`Future.cancel(io)` injects `error.Canceled` at the worker's next cancellation  
point — the next Io call returning `Cancelable!void`.

`Io.Group` manages a set of concurrent tasks:

```zig
pub const Group = struct {
    pub fn async(g: *Group, io: Io, function: anytype, args: ...) void
    pub fn concurrent(g: *Group, io: Io, function: anytype, args: ...) ConcurrentError!void
    pub fn await(g: *Group, io: Io) Cancelable!void     // wait for all
    pub fn cancel(g: *Group, io: Io) void               // cancel all, then await
};
```

`Io.Group` replaces `Thread.Pool` + `Thread.WaitGroup`. For a Master managing  
multiple workers, prefer `Io.Group`.

# 5. Container migration

0.16.0 moves all growable containers to the unmanaged variant — the allocator is  
passed per operation, not stored in the struct.

| Old name | Status | Use instead |
|----------|--------|-------------|
| `ArrayHashMap` | removed | — |
| `AutoArrayHashMap` | removed | — |
| `StringArrayHashMap` | removed | — |
| `ArrayListUnmanaged` | deprecated alias | `ArrayList` (now IS unmanaged) |
| `array_list.Managed` | deprecated | `ArrayList` |
| `AutoHashMap` | still exists (managed) | prefer `AutoHashMapUnmanaged` |
| `AutoHashMapUnmanaged` | current | use this |
| `ArrayList` | current — IS unmanaged | use this |

`_Pool` keeps two `std.AutoHashMapUnmanaged` maps, `lists` and `counts`, both  
keyed on the tag pointer. Init with `.empty`. All mutating ops take the  
allocator explicitly:

```zig
var m: std.AutoHashMapUnmanaged(K, V) = .empty;
try m.put(alloc, key, value);   // allocator is the first arg
m.deinit(alloc);                // allocator required
```

`getPtr(key)` and `get(key)` are read-only — no allocator needed.

# 6. Known gaps

**No `Io.Condition.waitTimeout`** (open issue codeberg/zig#31278).

`src/internal/cond_timeout.zig` supplies `condition_waitTimeout`, which calls  
`io.futexWaitTimeout` directly. Both `Mbox.receive` and `Pool.get_wait`  
depend on it.

**`heap.ThreadSafeAllocator` removed** as an anti-pattern. Allocators are  
expected to be thread-safe on their own. `heap.ArenaAllocator` is thread-safe  
and lock-free by default.

`_Mailbox` and `_Pool` store `alloc` at init. Callers must pass a thread-safe  
allocator if `new`/`destroy` run from multiple threads. Matryoshka does not wrap  
allocators.

---

# 7. Cancellation

Everything about cancellation in one place.

## 7.1 How it works

Cancellation points are the waiting operations:

```zig
mutex.lock(io) catch ...           // cancellation point — returns Cancelable!void
cond.wait(io, &mutex) catch ...    // cancellation point — returns Cancelable!void
cond.broadcast(io)                 // NOT a cancellation point — returns void
cond.signal(io)                    // NOT a cancellation point — returns void
mutex.unlock(io)                   // NOT a cancellation point — returns void
```

Only waits return `error.Canceled`.

Signal, broadcast, and unlock never do.

A worker blocked in an Io wait wakes immediately when canceled:

```text
future.cancel(io) called
    ↓
Zig Io runtime marks task as canceled
    ↓
worker is blocked in Io.Condition.wait
    ↓
Io.Condition.wait returns error.Canceled
    ↓
caller handles error.Canceled
```

A worker that is not blocked sees it at its next wait:

```text
future.cancel(io) called
    ↓
Zig Io runtime marks task as canceled
    ↓
worker reaches next Io wait (e.g. mutex.lock at start of next operation)
    ↓
mutex.lock returns error.Canceled
    ↓
caller handles error.Canceled
```

Cancellation is never missed.

It takes effect at whichever Io wait the worker hits next.

## 7.2 Two delivery mechanisms

Zig 0.16 offers two ways to unblock a worker. Both are valid. They differ in who  
initiates the unblock.

```text
Broadcast path              Future.cancel path
─────────────              ──────────────────
Mbox.close / Pool.close    future.cancel(io)
     ↓                          ↓
cond.broadcast             Io marks task canceled
     ↓                          ↓
worker wakes               worker hits next Io wait
     ↓                          ↓
error.Closed               error.Canceled
     ↓                          ↓
worker exits loop          worker exits loop
```

Broadcast path: `Mbox.close` / `Pool.close` call `cond.broadcast(io)`  
internally.

Future.cancel path: spawn the worker with `io.concurrent()` and call  
`future.cancel(io)` on shutdown.

Both require `Mbox.close` and `Pool.close` afterward. `future.cancel` stops  
the worker. It does not close anything.

## 7.3 Cancel-protected vs cancelable operations

Receive operations are cancelable — the worker must wake when canceled.

Close and put operations are cancel-protected — they are cleanup paths that must  
complete.

Two mechanisms make an operation cancel-protected.

`lockUncancelable` — for a single lock acquisition:

```zig
mbx.*.mutex.lockUncancelable(io);   // blocks until acquired, never returns error.Canceled
defer mbx.*.mutex.unlock(io);
```

This is the one the code uses. Every cancel-protected entry point in  
`src/mailbox.zig` and `src/pool.zig` opens with it.

`CancelProtection` — for a larger region:

```zig
pub const CancelProtection = enum(u1) {
    unblocked = 0,  // default: Io functions are cancellation points
    blocked   = 1,  // no Io function returns error.Canceled
};

const old = io.swapCancelProtection(.blocked);
defer _ = io.swapCancelProtection(old);
// inside here: error.Canceled is unreachable from any Io call
```

Use `lockUncancelable` when only the lock acquisition needs protection. Use  
`swapCancelProtection` when several Io calls in a region all need it.  
`lockUncancelable` is simpler and more explicit than `swapCancelProtection`  
plus `mutex.lock(io) catch unreachable`, which is why it won.

`Pool.put` MUST be cancel-protected.

A worker that receives `error.Canceled` from `Mbox.receive` must return its  
item reliably. If `Pool.put` could itself fail with `error.Canceled`, the item  
would be lost with nothing holding it. `Pool.put` returns `void`.

The per-function cancel contract lives in
[matryoshka-api-reference-040.md](matryoshka-api-reference-040.md).

## 7.4 `error.Canceled` is not `error.Closed`

These are distinct. Do not remap one to the other.

- `error.Closed` — `Mbox.close` or `Pool.close` was called.
- `error.Canceled` — the task was canceled while the mailbox or pool was still
  open.

Different causes. Different meaning. `Mbox.receive` and `Pool.get_wait`  
propagate `error.Canceled` directly.

Both cause the worker to exit its loop. The worker may handle them differently.

## 7.5 Post-wakeup check sequence

A return from `Io.Condition.wait` is just a wakeup. It carries no application  
meaning.

The scheduler resumed the task. What the code finds after waking is the event.

In `Mbox.receive` the check sequence enforces this:

```zig
while (mbx.len == 0) {
    if (mbx.closed.load(.monotonic)) return error.Closed;   // mailbox shut down
    cond_timeout.condition_waitTimeout(...) catch |err| switch (err) {
        error.Timeout  => return error.Timeout,             // caller's deadline
        error.Canceled => return err,                       // task canceled — propagated directly
    };
    // loop: woke up, check again — wakeup itself told us nothing
}
// data available — dequeue immediately
// OOB items arrive via send_oob (prepend) — they are PolyNodes with specific tags
```

The order: closed? → `len > 0`? → dequeue / loop.

The loop re-evaluates state on every wakeup. No single wakeup short-circuits to  
a conclusion.

---

# 8. Comptime — what Zig buys

Gains Zig's type system and comptime enable that Odin cannot express. Four  
shipped. Three did not, and stay here because they are still worth doing.

## Generated tag identity per PolyNode type — REALIZED

Shipped as `PolyHelper` in `src/polynode.zig`. In Odin every PolyNode-based type  
declares its tag identity by hand; the block is identical for every type and  
only the name changes. Zig generates it once and derives it for any `T`.

```zig
pub fn PolyHelper(comptime T: type) type {
    comptime validatePolyType(T);
    return struct {
        var _tag: PolyTag = .{};
        pub const TAG: *const anyopaque = &_tag;
        pub inline fn isIt(tag: *const anyopaque) bool { return tag == TAG; }
        ...
    };
}
```

`usingnamespace` was removed in 0.16.0, so the generated namespace cannot live  
inside the struct. It is a file-level `const` alongside it — `Mbox`,  
`Pool`.

Why `var _tag` and not `const`: a mutable global has a guaranteed unique runtime  
address. `const` may be deduplicated by the linker.

Why uniqueness holds: Zig memoizes comptime function results by argument.  
`PolyHelper(Foo)` and `PolyHelper(Bar)` are different types. Each has its own  
`_tag` global.

Why the validator does not check offset: `@fieldParentPtr("poly", ptr)` computes  
the correct offset at compile time. Offset 0 is not required. Placing `poly`  
first matches Odin's convention but is not a correctness constraint in Zig.

## Comptime field validation — REALIZED

`validatePolyType` in `src/polynode.zig` rejects a type without a  
`poly: PolyNode` field at compile time, naming the type in the error.

## Two-level recovery — REALIZED

Odin uses runtime `rawptr` comparison for tag dispatch. `PolyHelper.fromPoly`  
returns `?*T` and `mustFromPoly` panics on mismatch; both recover through  
`@fieldParentPtr`, so the field name is checked at compile time. Runtime cost is  
identical to Odin's.

## Atomic pre-lock fast-path — REALIZED

Both `_Mailbox` and `_Pool` carry `closed: std.atomic.Value(bool)` and check it  
before acquiring the mutex, which avoids lock contention on the common  
post-close path:

```zig
if (mbx.closed.load(.acquire)) return error.Closed;   // no mutex acquired (fast path)
mbx.mutex.lock(io) catch |err| return err;            // propagates error.Canceled directly
defer mbx.mutex.unlock(io);
if (mbx.closed.load(.monotonic)) return error.Closed; // re-check under lock
```

The double check prevents a race: close may fire between the first check and the  
lock acquire.

## Typed slot wrapper — NOT TAKEN

The shipped `Slot` is `?ItemHandle`, untyped. A per-type wrapper would keep the  
concrete type at the API boundary:

```zig
fn TypedSlot(comptime T: type) type { return ?*T; }
```

The gain: type errors at send/receive become compile-time rather than runtime  
tag-mismatch panics. The cost: it suits single-type mailboxes only. A  
polymorphic mailbox carrying mixed types needs the untyped `Slot` and dispatches  
via `PolyHelper.isIt` after receive, which is the common case here.

## Closed-type Pool — NOT TAKEN

`_Pool` keys two runtime hash maps on tag pointers, which is necessary when the  
type set is open. If every type were known at compile time, an `inline for` over  
the type list would unroll into a chain of tag comparisons — no hash map, no  
allocation, no runtime dispatch.

Worth doing only for a closed subsystem. For the general Pool — open type set,  
hooks, runtime registration — `AutoHashMapUnmanaged` is correct.

## Pool item alignment validation — NOT TAKEN

A pool backed by a slab allocator may have alignment constraints. A comptime  
`@alignOf(T) > slab_align` check would catch a mismatch at build time instead of  
at load. Not needed while the pool allocates per item rather than from a slab.

## Hook signature validation — NOT TAKEN, NOT NEEDED

`Pool.Hooks` field types already enforce the signatures. A separate comptime  
assertion would only matter for dynamically constructed hooks, which do not  
exist here.

---

## Change log

| Version | Date       | Description |
|---------|------------|-------------|
| 002     | 2026-08-02 | DOC 23. Replaces `matryoshka-tk-0.16-implementation-guide-001.md`. Dropped the four block-by-block build walkthroughs and the Master-patterns section — the port shipped and `src/` is the truth. Odin idiom mapping moved to `secondary/odin-to-zig-backport-001.md`. Kept the 0.16 constraints, the cancellation contract and the comptime opportunities; the opportunities are now marked realized or not, checked against `src/`. Vocabulary brought in line with the glossary: `MayItem` → `Slot`, `Block N` → the four concepts by name, ownership-family words → hold and transfer. |
| 001     | 2026-06-22 | First version, as `matryoshka-tk-0.16-implementation-guide-001.md`. A pre-implementation feasibility study: "Verdict: this port is viable." |
