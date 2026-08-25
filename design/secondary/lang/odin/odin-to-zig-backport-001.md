# Odin to Zig — Idiom Mapping

> **otk's normative input is the portable specification**, and this note is the
> first time this folder says so — added 2026-08-24 by stage 3TK-19, a debt
> 3TK-13 and 3TK-17 both left open. **otk is ported from
> [`../common/matryoshka-specification-004.md`](../common/matryoshka-specification-004.md)
> alone**: self-contained, language-neutral, and the source of truth for every
> port in the family — **otk** (Odin), **ztk** (Zig), **3tk** (C3), **dtk** (D).
> A defect found in it is fixed **there**, once, for every port, and never
> patched in a folder like this one. The file has moved twice and been recut
> twice, so the path above is the only one to trust: it was
> `matryoshka-specification-002.md` inside the C3 folder, then 003, then 004
> when 3TK-17 reworded Part 7.1, and it moved to `../common/` on 2026-08-23
> because a shared input inside one consumer's folder is a fork waiting to
> happen. The superseded versions are in
> [`../common/backup/`](../common/backup/), and **004's change log names every
> difference** — it is the thing to read first, because 002 was written from ztk
> and stated Zig's *mechanism* in fifteen places where the design has only a
> *promise*. **The document below is not that input.** It maps Odin idiom to
> Zig idiom and its Zig column is a proposal history overtook; it says nothing
> about what otk must preserve. Whether otk is brought to the specification is
> not decided here, and no stage of the 3tk line has decided it.

The complete idiom mapping between the Odin `matryoshka` prototype and the Zig  
port, extracted from the Zig 0.16 implementation guide when that guide was retired  
in DOC 23.

## What this is for

Read it in one direction only: backporting `matryoshka-tk` to Odin. Every  
mapping here works both ways, so it doubles as the reverse reference.

The Odin prototype lives at `/home/g41797/dev/root/github.com/g41797/matryoshka/`.

## What this is not

Not a Zig API reference. The Zig names below are the ones the guide proposed  
before the port was written, not the ones that shipped. `pool_get_wait` is  
`pool.get_wait`. `mailbox_receive` is `mailbox.receive`. `MayItem` is `Slot`.  
For the shipped surface read `../matryoshka-api-reference-033.md`, or `src/`.

The Odin side is accurate. The Zig side is a proposal that history overtook.  
Read the left column, then check the right one against `src/`.

---

# Cancellation — Odin comparison

Odin has no cancellation.

`sync.mutex_lock` and `sync.cond_wait` never return errors.

The only way to wake a blocked Odin worker is the `mailbox_close` / `pool_close` broadcast.

There is no injection mechanism and no `CancelProtection`.

`Future.cancel` is new in Zig.

---

# The mapping

Every Odin language idiom used in matryoshka sources and examples, with its Zig 0.16 equivalent. Examples are drawn directly from the Odin source.

---

### 1. `using` embedding vs `@fieldParentPtr`

**Odin** — `using` at offset 0 promotes fields and makes direct pointer casts safe:

```odin
Event :: struct {
    using poly: PolyNode,  // offset 0 — required
    code:       int,
    message:    string,
}

// Recovery: cast is safe because poly is at offset 0
ev := (^Event)(poly)
```

**Zig** — no `using`; embed as a named field and recover with `@fieldParentPtr`:

```zig
pub const Event = struct {
    poly:    PolyNode,
    code:    i64,
    message: []const u8,
};

// Recovery: field name validated at compile time
const ev: *Event = @fieldParentPtr("poly", poly);
```

**Key difference**: Odin's `using` promotes fields — you write `event.tag` not `event.poly.tag` — and makes the raw cast safe by guaranteeing offset 0. Zig requires explicit field access (`event.poly.tag`) and `@fieldParentPtr` for recovery. The Zig version is safer: the compiler checks the field name and enforces correct types.

**Two-level chain in matryoshka** (required because `PolyNode` embeds `std.DoublyLinkedList.Node`):

```zig
// Step 1: *DoublyLinkedList.Node → *PolyNode  (inside mailbox/pool implementation)
const poly: *PolyNode = @fieldParentPtr("node", dll_node);

// Step 2: *PolyNode → *UserType  (in user dispatch code)
const ev: *Event = @fieldParentPtr("poly", poly);
```

---

### 2. `rawptr` vs `*const anyopaque`

**Odin** — `rawptr` is the untyped pointer:

```odin
PolyTag :: struct { _: u8 }

@(private)
event_tag: PolyTag = {}
EVENT_TAG: rawptr = &event_tag

event_is_it_you :: #force_inline proc(tag: rawptr) -> bool {
    return tag == EVENT_TAG
}
```

**Zig** — `*const anyopaque` is the untyped pointer; `const` because tags are never mutated:

```zig
pub const PolyTag = struct { _: u8 = 0 };

var event_tag: PolyTag = .{};
pub const EVENT_TAG: *const anyopaque = &event_tag;

pub inline fn event_is_it_you(tag: *const anyopaque) bool {
    return tag == EVENT_TAG;
}
```

**Note**: Odin uses `rawptr` for all untyped pointers. Zig distinguishes `*anyopaque` (mutable) from `*const anyopaque` (read-only). Use `*const anyopaque` for tags — tags are never mutated.

---

### 3. `Maybe(T)` vs `?T` — ownership state

**Odin** — `Maybe(^PolyNode)` with `.?` destructuring:

```odin
MayItem :: Maybe(^PolyNode)

m: MayItem = &ev.poly       // take ownership
ptr, ok := m^.?             // destructure (ok == true if non-nil)
m^ = nil                    // release ownership
```

**Zig** — `?*PolyNode` with `orelse`/`if` unwrapping:

```zig
pub const MayItem = ?*PolyNode;

var m: MayItem = &ev.poly;          // take ownership
const ptr = m orelse return;        // unwrap or bail
// or: if (m) |ptr| { ... }
m = null;                           // release ownership
```

**Key difference**: The semantics are identical. The syntax differs. Odin uses `.?` suffix; Zig uses `orelse` or `if (opt) |val|`. Odin's multi-return destructuring (`ptr, ok := m^.?`) becomes Zig's `if (m.*) |ptr| { ... }`.

**At API boundaries** — Odin passes `^MayItem` (pointer to the optional); Zig passes `*MayItem`:

```odin
mailbox_send :: proc(mb: Mailbox, m: ^MayItem) -> SendResult
```
```zig
pub fn mailbox_send(mbh: MailboxHandle, m: *MayItem) error{Closed}!void
```

---

### 4. Pointer syntax: `^T` / `m^` vs `*T` / `m.*`

| Odin | Zig | Meaning |
|------|-----|---------|
| `^T` | `*T` | pointer to T |
| `^^T` | `**T` | pointer to pointer to T |
| `m^` | `m.*` | dereference pointer |
| `m^ = nil` | `m.* = null` | write through pointer |
| `nil` | `null` | null pointer / absent optional |

Odin uses `^` as both pointer-type sigil and dereference operator. Zig uses `*` for pointer types and `.*` for dereference.

---

### 5. Explicit casts: `cast(T)` vs `@ptrCast` / `@fieldParentPtr`

**Odin** — `cast(^T)ptr` for bare pointer reinterpretation:

```odin
// offset-0 cast: works because _Mailbox has 'using poly: PolyNode' first
mbx_Ptr := cast(^_Mailbox)mb

// in _pop: list.Node cast to PolyNode
result := cast(^PolyNode)raw
```

**Zig** — `@ptrCast` for raw reinterpretation, `@fieldParentPtr` for struct recovery:

```zig
// Preferred: field-based recovery (type-safe, compile-checked)
const mailbox: *_Mailbox = @fieldParentPtr("poly", mb);
const poly: *PolyNode = @fieldParentPtr("node", dll_node);

// Only when you truly need raw reinterpretation (rare in matryoshka)
const ptr: *_Mailbox = @ptrCast(@alignCast(raw));
```

**Rule**: In matryoshka, `cast(^_Mailbox)mb` → `@fieldParentPtr("poly", mb)`. Never use `@ptrCast` where `@fieldParentPtr` applies — `@fieldParentPtr` validates field existence and type at compile time.

---

### 6. Opaque handle pattern: `Mailbox :: ^PolyNode`

This is matryoshka's central idiom — the handle IS the embedded `PolyNode` pointer.

**Odin**:

```odin
Mailbox :: ^PolyNode  // type alias

mailbox_new :: proc(alloc: mem.Allocator) -> Mailbox {
    mbx, _ := new(_Mailbox, alloc)     // _Mailbox has 'using poly: PolyNode' at offset 0
    mbx^.tag = MAILBOX_TAG
    return cast(Mailbox)mbx         // safe: poly is at offset 0
}

_unwrap :: proc(m: Mailbox) -> ^_Mailbox {
    return cast(^_Mailbox)m            // safe: reverse of the above cast
}
```

**Zig**:

```zig
pub const MailboxHandle = *PolyNode;      // same type alias concept

pub fn mailbox_new(io: Io, alloc: std.mem.Allocator) !MailboxHandle {
    const mbx = try alloc.create(_Mailbox);
    mbx.* = .{ .poly = .{ .node = .{}, .tag = MAILBOX_TAG }, .io = io, ... };
    return &mbx.poly;               // return pointer to the embedded PolyNode
}

fn unwrap(mbh: MailboxHandle) *_Mailbox {
    return @fieldParentPtr("poly", mbh);  // recover _Mailbox from its poly field
}
```

**Key difference**: In Odin, `cast(Mailbox)mbx` works because of offset-0 `using`. In Zig, `return &mbx.poly` makes the pointer explicit. `@fieldParentPtr` recovers the parent. Semantics are identical. The Zig version is explicit about what address is returned.

---

### 7. `sync.Mutex` / `sync.Cond` vs `Io.Mutex` / `Io.Condition`

**Odin** — OS-backed, no cancellation awareness:

```odin
import "core:sync"

sync.mutex_lock(&mbx^.mutex)
defer sync.mutex_unlock(&mbx^.mutex)
sync.cond_wait(&mbx^.cond, &mbx^.mutex)
sync.cond_wait_with_timeout(&mbx^.cond, &mbx^.mutex, remaining)
sync.cond_signal(&mbx^.cond)
sync.cond_broadcast(&ptr^.cond)
```

**Zig** — IO-scheduled, every wait is a cancellation point:

```zig
mailbox.mutex.lock(io) catch |err| return err;               // propagates error.Canceled directly
defer mailbox.mutex.unlock(io);
try mailbox.cond.wait(io, &mailbox.mutex);                      // Cancelable!void
condition_waitTimeout(&mailbox.cond, io, &mailbox.mutex, dl)    // workaround for missing waitTimeout
    catch |err| switch (err) { ... };
mailbox.cond.signal(io);
mailbox.cond.broadcast(io);
```

| Odin | Zig | Notes |
|------|-----|-------|
| `sync.mutex_lock(&m)` | `m.lock(io) catch ...` | Zig returns `Cancelable!void` |
| `sync.mutex_unlock(&m)` | `m.unlock(io)` | same semantics |
| `sync.cond_wait(&c, &m)` | `c.wait(io, &m)` | cancellation point in Zig |
| `sync.cond_wait_with_timeout(...)` | `condition_waitTimeout(...)` | Zig gap: no native waitTimeout (issue #31278) |
| `sync.cond_signal(&c)` | `c.signal(io)` | — |
| `sync.cond_broadcast(&c)` | `c.broadcast(io)` | — |

**Critical**: `std.Thread.Mutex` and `std.Thread.Condition` must NOT be used in `_Mailbox` or `_Pool`. They do not go through the IO vtable and cannot return `error.Canceled`.

---

### 8. Intrusive list: `core:container/intrusive/list` vs `std.DoublyLinkedList`

**Odin**:

```odin
import list "core:container/intrusive/list"

l: list.List
list.push_back(&l, &ev.poly.node)
list.push_front(&l, &node.node)
raw := list.pop_front(&l)      // returns ^list.Node
result = mbx^.list             // list copy = atomic snapshot
mbx^.list = list.List{}        // reset to empty
```

**Zig**:

```zig
var l: std.DoublyLinkedList = .{};
l.append(&ev.poly.node);       // push_back
l.prepend(&node.node);         // push_front
const raw = l.popFirst();      // returns ?*std.DoublyLinkedList.Node
var result = l;                // copy struct = snapshot
l = .{};                       // reset to empty
```

| Odin | Zig |
|------|-----|
| `list.List` | `std.DoublyLinkedList` |
| `list.Node` | `std.DoublyLinkedList.Node` |
| `list.push_back(&l, &node)` | `l.append(&node)` |
| `list.push_front(&l, &node)` | `l.prepend(&node)` |
| `list.pop_front(&l)` | `l.popFirst()` |
| copy struct by value | same in Zig |
| `list.List{}` | `.{}` |

**Node definition is identical in concept**:

```odin
// Odin core:container/intrusive/list Node
Node :: struct { next, prev: ^Node }
```
```zig
// Zig std.DoublyLinkedList Node
pub const Node = struct { prev: ?*Node = null, next: ?*Node = null };
```

---

### 9. `map[rawptr]T` vs `std.AutoHashMapUnmanaged(*const anyopaque, T)`

**Odin** — built-in map, garbage-collected key/value:

```odin
lists:  map[rawptr]list.List
counts: map[rawptr]int

p^.lists  = make(map[rawptr]list.List, 16, alloc)
p^.counts = make(map[rawptr]int,       16, alloc)

p^.lists[tag]  = l           // store
p^.counts[tag] -= 1          // update
delete(p.lists)              // free
delete(p.counts)             // free

// iteration
for tag in ptr.lists {
    if list_ptr, ok := ptr.lists[tag]; ok { ... }
}
```

**Zig 0.16.0** — use `AutoHashMapUnmanaged`; explicit allocator per operation; init with `.empty`:

```zig
lists:  std.AutoHashMapUnmanaged(*const anyopaque, std.DoublyLinkedList),
counts: std.AutoHashMapUnmanaged(*const anyopaque, usize),

// Init: .empty (zero struct literal, no allocator stored in map)
p.lists  = .empty;
p.counts = .empty;

try p.lists.put(alloc, tag, l);   // allocator first
p.counts.getPtr(tag).?.* -= 1;   // read-only lookup, no alloc needed
p.lists.deinit(alloc);           // free
p.counts.deinit(alloc);          // free

// iteration (unchanged)
var it = p.lists.iterator();
while (it.next()) |entry| {
    const tag = entry.key_ptr.*;
    var list = entry.value_ptr;
    ...
}
```

**Key differences**: Odin map operations are infallible. Zig `put(alloc, k, v)` returns an error on OOM. In 0.16.0 all mutating operations take the allocator explicitly — the map does not store it. `getPtr(key)` and `get(key)` are read-only and need no allocator. The managed `ArrayHashMap`/`AutoArrayHashMap` variants were removed in 0.16.0. `std.AutoHashMap` (managed) and `std.AutoHashMapUnmanaged` both remain; `_Pool` uses `AutoHashMapUnmanaged` since it already holds `alloc: std.mem.Allocator`.

---

### 10. `[dynamic]rawptr` vs `std.ArrayList(*const anyopaque)`

**Odin** — built-in dynamic array:

```odin
tags: [dynamic]rawptr

append(&hooks.tags, EVENT_TAG)
defer delete(hooks.tags)
slice.contains(ptr.hooks.tags[:], tag)
```

**Zig 0.16.0** — `std.ArrayList`; `.init(allocator)` is gone, allocator passed per-operation:

```zig
tags: std.ArrayList(*const anyopaque),

// Init: .empty (no allocator stored in struct)
hooks.tags = .empty;

try hooks.tags.append(alloc, EVENT_TAG);   // allocator first
defer hooks.tags.deinit(alloc);            // allocator required
std.mem.indexOfScalar(*const anyopaque, hooks.tags.items, tag) != null
```

For fixed-size tag lists (common case), a `[]const *const anyopaque` slice avoids `ArrayList` entirely:

```zig
// Static tag list — no allocation needed
const TAGS = [_]*const anyopaque{ &event_tag, &sensor_tag };
hooks.tags = &TAGS;
```

---

### 11. `new` / `free` vs `alloc.create` / `alloc.destroy`

**Odin**:

```odin
mbx, err := new(_Mailbox, alloc)
if err != .None { return nil }
// ...
free(mb, alloc)
```

**Zig**:

```zig
const mbx = try alloc.create(_Mailbox);
mbx.* = std.mem.zeroes(_Mailbox);  // explicit zero-init (or use .{} literal)
// ...
alloc.destroy(mb);
```

| Odin | Zig |
|------|-----|
| `new(T, alloc)` | `try alloc.create(T)` |
| `free(ptr, alloc)` | `alloc.destroy(ptr)` |
| auto zero-initialized | requires `= .{}` or `= std.mem.zeroes(T)` |
| returns `(^T, Allocator_Error)` | returns `Allocator.Error!*T` |

---

### 12. Enum result types vs error unions

**Odin** — enum result codes, checked with `==`:

```odin
SendResult :: enum { Ok, Closed, Invalid }

mailbox_send :: proc(mb: Mailbox, m: ^MayItem) -> SendResult

if mailbox_send(inbox, &mi) != .Ok { ... }
```

**Zig** — error union, checked with `try` / `catch` / `switch`:

```zig
pub fn mailbox_send(mbh: MailboxHandle, m: *MayItem) error{Closed}!void

try mailbox_send(inbox, &mi);                              // propagate
mailbox_send(inbox, &mi) catch |err| { ... };              // handle
```

**Mapping of specific enums**:

| Odin Result | Zig Equivalent |
|------------|----------------|
| `SendResult.Ok` | `void` (success) |
| `SendResult.Closed` | `error.Closed` |
| `SendResult.Invalid` | `error.Invalid` or `@panic` |
| `RecvResult.Ok` | `void` (single item) or `?*std.DoublyLinkedList.Node` (batch — `mailbox_receive_batch`) |
| `RecvResult.Closed` | `error.Closed` |
| `RecvResult.Interrupted` | removed — OOB via `mailbox_send_oob` |
| `RecvResult.Timeout` | `error.Timeout` |
| `RecvResult.Already_In_Use` | `@panic` (precondition violation) |
| `Pool_Get_Result.Ok` | `void` |
| `Pool_Get_Result.Not_Available` | `error.NotAvailable` |
| `Pool_Get_Result.Not_Created` | `null` (hook returned nothing) or `error` |
| `Pool_Get_Result.Closed` | `error.Closed` |
| `Pool_Get_Result.Timeout` | `error.Timeout` (from `pool_get_wait` with `timeout_ns`) |
| `Pool_Get_Result.Already_In_Use` | `@panic` (precondition violation) |

**Note on nil returns**: Odin's `mailbox_new` returns `nil` on allocation failure. Zig returns `error.OutOfMemory` via `!MailboxHandle`. This makes failure explicit and composable.

---

### 13. `#partial switch` vs exhaustive `switch`

**Odin** — `#partial switch` handles a subset of enum cases; unhandled fall through silently:

```odin
#partial switch res {
case .Ok:
    ...
case .Closed:
    return
case:
    fmt.printfln("unexpected: %v", res)
    return
}
```

**Zig** — `switch` is exhaustive by default; use `else` for unhandled cases:

```zig
switch (res) {
    .ok      => { ... },
    .closed  => return,
    else     => |err| { std.debug.print("unexpected: {}\n", .{err}); return err; },
}
```

With error unions:

```zig
mailbox_receive(inbox, &mi, timeout_ns) catch |err| switch (err) {
    error.Closed       => return,
    error.Canceled     => return,
    error.Timeout      => continue,
};
```

**Key difference**: Zig's exhaustive switch catches missed cases at compile time. `#partial switch` silently ignores unhandled values. For error handling, Zig's `catch |err| switch` is more natural than Odin's switch on a result enum.

---

### 14. `@(private)` vs implicit file-scope privacy

**Odin** — `@(private)` makes a declaration private to the package:

```odin
@(private)
mailbox_tag: PolyTag = {}
MAILBOX_TAG: rawptr = &mailbox_tag

@(private)
_Mailbox :: struct { ... }

@(private)
_unwrap :: proc(m: Mailbox) -> ^_Mailbox { ... }
```

**Zig** — declarations without `pub` are private by default:

```zig
var mailbox_tag: PolyTag = .{};         // private: no pub
pub const MAILBOX_TAG: *const anyopaque = &mailbox_tag;

const _Mailbox = struct { ... };            // private: no pub

fn unwrap(m: Mailbox) *_Mailbox { ... }    // private: no pub
```

**Note**: In Zig, `pub` is explicit — you must mark things public. In Odin, symbols are public by default and made private with `@(private)`. The visibility model is inverted.

---

### 15. `#force_inline proc` vs `inline fn`

**Odin**:

```odin
mailbox_is_it_you :: #force_inline proc(tag: rawptr) -> bool {
    return tag == MAILBOX_TAG
}
```

**Zig**:

```zig
pub inline fn mailbox_is_it_you(tag: *const anyopaque) bool {
    return tag == MAILBOX_TAG;
}
```

`#force_inline` → `inline fn`. Both guarantee the function is always inlined.

---

### 16. `panic` vs `@panic`

**Odin**:

```odin
panic("mailbox_send: node is still linked — detach before sending")
panic("non-mailbox is used for mailbox operations")
```

**Zig**:

```zig
@panic("mailbox_send: node is still linked — detach before sending");
@panic("non-mailbox is used for mailbox operations");
```

Direct substitution. Both abort with a message. In Zig, `@panic` is a builtin; in Odin, `panic` is a procedure from the `builtin` package.

---

### 17. `context.allocator` vs explicit allocator parameter

**Odin** — implicit `context` threading:

```odin
alloc := context.allocator
p := matryoshka.pool_new(alloc)
```

**Zig** — no implicit context; allocator passed explicitly:

```zig
// Caller holds the allocator and passes it where needed
const p = try pool_new(io, allocator);
```

**Impact**: Every function that allocates in Odin can use `context.allocator` without a parameter. In Zig, any function that allocates must receive `alloc: std.mem.Allocator` explicitly. This is already reflected in the Zig API: `mailbox_new(io, alloc)` and `pool_new(io, alloc)`.

---

### 18. Thread API: `core:thread` vs `std.Thread`

**Odin**:

```odin
import "core:thread"

t := thread.create(worker_proc)  // worker_proc :: proc(t: ^thread.Thread)
t.data = m                        // pass data via thread.data field
thread.start(t)
defer thread.destroy(t)
thread.join(t)
```

**Zig**:

```zig
const t = try std.Thread.spawn(.{}, worker_proc, .{m});
// worker_proc :: fn (m: *Master) void  — args passed directly, no .data field
defer t.join();
```

**Key difference**: Odin passes data through `thread.data: rawptr`. Zig passes arguments directly to the thread function as a tuple — no side-channel needed. `thread.destroy` is implicit when the thread handle is no longer used (or explicit via detach/join).

---

### 19. Map / list iteration

**Odin**:

```odin
// Map iteration — keys and values
for tag in ptr.lists {
    if list_ptr, ok := ptr.lists[tag]; ok {
        for {
            node := list.pop_front(&list_ptr)
            if node == nil { break }
            list.push_back(&all_items, node)
        }
    }
}

// walk intrusive list and free each node
for {
    raw := list.pop_front(&remaining)
    if raw == nil { break }
    poly := (^PolyNode)(raw)
    // ...
}
```

**Zig**:

```zig
// Map iteration — valueIterator or full iterator
var it = p.lists.iterator();
while (it.next()) |entry| {
    var list = entry.value_ptr;
    while (list.popFirst()) |node| {
        result.append(node);
    }
}

// walk intrusive list and free each node
while (remaining.popFirst()) |dll_node| {
    const poly: *PolyNode = @fieldParentPtr("node", dll_node);
    // ...
}
```

Odin's `for ... { if raw == nil { break } }` pattern maps to Zig's `while (expr) |val| {}` loop — more idiomatic and avoids the explicit nil check.

---

### 20. Zero initialization

**Odin** — all struct values are zero-initialized by default:

```odin
result := list.List{}    // explicit zero struct literal
// or:
_mailbox: _Mailbox            // also zero-initialized (without =)
```

**Zig** — must be explicit:

```zig
var result: std.DoublyLinkedList = .{};   // zero struct literal
const mailbox = try alloc.create(_Mailbox);
mailbox.* = .{};                             // must zero-init after create
```

Zig's `undefined` is deliberately NOT zero — it triggers safety checks in debug mode. Always use `.{}` or `std.mem.zeroes(T)` after `alloc.create(T)`.

---

### 21. Type-checking dispatch patterns

**Odin** — raw tag comparison then cast:

```odin
if event_is_it_you(poly.tag) {
    ev := (^Event)(poly)
    // use ev
} else if sensor_is_it_you(poly.tag) {
    s := (^Sensor)(poly)
    // use s
} else {
    panic("unknown tag")
}
```

**Zig** — same logic, `@fieldParentPtr` for recovery:

```zig
if (event_is_it_you(poly.tag)) {
    const ev: *Event = @fieldParentPtr("poly", poly);
    // use ev
} else if (sensor_is_it_you(poly.tag)) {
    const s: *Sensor = @fieldParentPtr("poly", poly);
    // use s
} else {
    @panic("unknown tag");
}
```

The pattern is structurally identical. The only difference is `@fieldParentPtr` replacing the bare cast.

---

### Quick Reference Table

| Odin idiom | Zig 0.16 equivalent |
|-----------|---------------------|
| `PolyTag :: struct { _: u8 }` | `const PolyTag = struct { _: u8 = 0 }` — unique address per instance |
| `using poly: PolyNode` at offset 0 | embed as named field `poly: PolyNode`; recover with `@fieldParentPtr("poly", p)` |
| `(^UserType)(poly)` | `@fieldParentPtr("poly", poly)` — two-level chain validated at compile time |
| `rawptr` | `*const anyopaque` (for tags); `*anyopaque` (for mutable ctx) |
| `Maybe(^PolyNode)` | `?*PolyNode` |
| `ptr, ok := m^.?` | `if (m.*) \|ptr\| { ... }` |
| `m^` | `m.*` |
| `^T` | `*T` |
| `nil` | `null` |
| `Mailbox :: ^PolyNode` opaque handle | `MailboxHandle = *PolyNode` |
| `Pool :: ^PolyNode` opaque handle | `PoolHandle = *PolyNode` |
| `cast(^T)ptr` | `@fieldParentPtr("field", ptr)` or `@ptrCast(@alignCast(ptr))` |
| `#force_inline proc` | `inline fn` |
| `@(private)` | omit `pub` |
| `panic(msg)` | `@panic(msg)` |
| `io` passed at each call | `io: Io` stored in `_Mailbox` and `_Pool` at init |
| `context.allocator` implicit | explicit `alloc: std.mem.Allocator` parameter |
| `sync.Mutex` + `sync.Cond` | `Io.Mutex` + `Io.Condition` (IO-aware, cancellable) |
| `sync.cond_wait_with_timeout(...)` | `condition_waitTimeout(...)` (workaround for Zig issue #31278) |
| `list.List` / `list.Node` | `std.DoublyLinkedList` / `std.DoublyLinkedList.Node` |
| `list.push_back(&l, &node)` | `l.append(&node)` |
| `list.pop_front(&l)` | `l.popFirst()` |
| `map[rawptr]T` | `std.AutoHashMapUnmanaged(*const anyopaque, T)` — `ArrayHashMap`/`AutoArrayHashMap` managed variants removed in 0.16.0; `AutoHashMap` (managed) still exists |
| `make(map[...], cap, alloc)` | `var m: std.AutoHashMapUnmanaged(K,V) = .empty;` — allocator passed per-op, not stored in map |
| `m[tag] = v` | `try m.put(alloc, tag, v)` — allocator is first arg |
| `delete(map)` | `map.deinit(alloc)` — allocator required |
| `[dynamic]rawptr` | `std.ArrayList(*const anyopaque)` — `.init(alloc)` gone; use `.empty` + `append(alloc, item)` / `deinit(alloc)` |
| `new(T, alloc)` | `try alloc.create(T)` |
| `free(ptr, alloc)` | `alloc.destroy(ptr)` |
| auto zero-initialized | explicit `.{}` or `std.mem.zeroes(T)` |
| result enum (Ok/Closed/...) | `error{Closed,...}!void` error union |
| `#partial switch res { case .X: ... }` | `switch (res) { .x => ..., else => ... }` |
| `closed: bool` under mutex | `closed: std.atomic.Value(bool)` — pre-lock fast-path |
| `thread.create(proc)` + `t.data = ptr` | `std.Thread.spawn(.{}, proc, .{ptr})` or `io.concurrent(proc, .{ptr})` |
| `for tag in map { ... }` | `var it = map.iterator(); while (it.next()) \|e\| { ... }` |
| `for { raw := pop(); if raw == nil { break } }` | `while (list.popFirst()) \|node\| { ... }` |
| `try_receive_batch(mb)` | `mailbox_receive_batch(mb)` — returns `std.DoublyLinkedList` (empty list if nothing) |
| `pool_put_all(p, m: ^MayItem)` | `pool_put_all(pool, list: *std.DoublyLinkedList)` — explicit list struct; same operation |
| `mailbox_interrupt(mb)` | `mailbox_send_oob(mb, m)` — OOB signal is a PolyNode prepended to front |
| `mailbox_is_it_you(tag)` | `mailbox_is_it_you(tag: *const anyopaque) bool` |
| `pool_is_it_you(tag)` | `pool_is_it_you(tag: *const anyopaque) bool` |
| `pool_close(p) -> (list.List, ^PoolHooks)` | `pool_close(pool) void` — on_close receives `*std.DoublyLinkedList`; caller retains hooks reference |
| `panic` on misuse | `@panic` or `unreachable` |
