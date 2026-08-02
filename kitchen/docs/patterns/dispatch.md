# Patterns — Dispatch

Concepts: [Building Blocks — PolyNode](../building-blocks/polynode.md).  
API: [API Reference — PolyNode, ItemHandle, Slot](../api/polynode/index.md).

One mailbox carries many types. One pool holds many types. The receiver has to  
find out what arrived.

There are three ways. The first two differ by what you are holding. The third  
differs by where the choice lives.

**Using item** — you have an `ItemHandle`. Ask each type to cast it.

```zig
if (EventPolyHelper.fromPoly(handle)) |ev| {
    // handle Event
} else if (SensorPolyHelper.fromPoly(handle)) |sn| {
    // handle Sensor
} else return error.UnknownTag;
```

**Using tag** — you have a tag and nothing else. Ask each type to confirm it.

```zig
const tag: *const anyopaque = handle.*.tag;

if (EventPolyHelper.isIt(tag)) {
    const ev = EventPolyHelper.mustFromPoly(handle);
} else if (SensorPolyHelper.isIt(tag)) {
    const sn = SensorPolyHelper.mustFromPoly(handle);
} else return error.UnknownTag;
```

**Using table** — the choice is data the receiver owns, not code at the call  
site.

```zig
const table: Table = .{ .entries = &.{
    .{ .tag = EventPolyHelper.TAG,  .handler = onEvent },
    .{ .tag = SensorPolyHelper.TAG, .handler = onSensor },
} };

try table.dispatch(self, &slot);
```

The first two put the choice where the chain is written, so every receiver that  
handles an Event handles it the same way. The third puts it in a value, so two  
receivers can map one tag to two different handlers.

## Using item

When to use.

- You hold the item.
- Two or three types, and every branch wants the typed pointer straight away.

Code shape.  
```zig
if (EventPolyHelper.fromPoly(handle)) |ev| {
    // handle Event
} else if (ShutdownCommandPolyHelper.fromPoly(handle)) |_| {
    // handle ShutdownCommand
} else {
    // unknown tag
}
```

Why.

- One call does the tag check and the cast.
- `fromPoly` returns null on a mismatch, so the chain just continues.

Example: `examples/layer1/023-tag_dispatch.zig`,  
`examples/layer4/031-select_graceful_shutdown.zig`,  
`examples/layer4/033-cross_layer_mixed_types_mailbox.zig`.

## Using tag

When to use.

- You have a tag and no item. A pool hook is the clear case.
- Four or more types.
- A branch that does not need the item at all — count it, route it, log it.

Code shape.  
```zig
const tag: *const anyopaque = handle.*.tag;

if (EventPolyHelper.isIt(tag)) {
    const ev = EventPolyHelper.mustFromPoly(handle);
    // handle Event
} else if (SensorPolyHelper.isIt(tag)) {
    const sn = SensorPolyHelper.mustFromPoly(handle);
    // handle Sensor
} else if (TimerPolyHelper.isIt(tag)) {
    // the tag was enough — never touches the item
} else {
    // unknown tag
}
```

Why.

- `isIt` asks about a tag. It needs no item, so it works where `fromPoly`
  cannot be called at all.

- Inside a confirmed branch the tag is already proven, so `mustFromPoly` cannot
  fail. Use it, not `fromPoly` — a second check there is dead code with a dead  
  null path hanging off it.

- The tag is read once into a local. Every branch asks about that one value.

Example: `examples/layer1/026-tag_first_dispatch.zig`,  
`examples/hooks/AlwaysCreateHooks.zig`, `examples/items/items.zig`.

### Where there is no item

`PoolHooks.on_get` is handed a tag and an empty Slot:

```zig
on_get: *const fn (ctx: *anyopaque, tag: *const anyopaque, in_pool_count: usize, slot: *Slot) void,
```

The hook's job is to build the item. There is nothing to cast yet, so  
using the item is not an option — only the tag exists.

`PoolHooks.tags` is `[]const *const anyopaque`, the set the pool was  
registered with. A hook that dispatches over the same set is answering the  
question the registration already asked.

```zig
pub fn onGet(ptr: *anyopaque, tag: *const anyopaque, _: usize, slot: *Slot) void {
    if (slot.* != null) return;
    const self: *Self = @ptrCast(@alignCast(ptr));

    if (items.Event.EventPolyHelper.isIt(tag)) {
        items.Event.EventPolyHelper.create(self.alloc, slot) catch return;
    } else if (items.Sensor.SensorPolyHelper.isIt(tag)) {
        items.Sensor.SensorPolyHelper.create(self.alloc, slot) catch return;
    } else {
        unreachable;
    }
}
```

Example: `examples/hooks/AlwaysCreateHooks.zig`.

## Always write the last branch

When to use.

- Every dispatch chain, both ways.

Why.

- A chain's trailing `else` is optional. Leave it out and an unrecognised item
  falls through in silence.

- `items.freeItem` did exactly that until it was fixed — an unknown tag went
  past every branch and the item was dropped with nothing said.

What goes in it depends on the type set.

- **Closed set** — every type is yours and every helper is in the chain.
  `unreachable`. Reaching it means the caller passed something that cannot  
  exist.

- **Open set** — a mailbox anyone can send to. Count it, log it, move on.
  Returning an error is fine too.

## The last branch cannot free

`alloc.destroy(ptr)` takes `*T`, and the allocator needs the size to release  
the memory. In the last branch there is no type, so there is no size.

So an unknown item cannot be freed there. It can only be dropped, counted, or  
reported. Its memory belongs to whoever knows what it is — the sender, or the  
pool it came from.

This is the strongest argument for keeping each dispatch site's type set  
closed, and for `unreachable` when it is.

A table does not have this problem. See "The miss" below.

## Using table

When to use.

- Two receivers do different work with the same item type.
- One receiver changes what it does — before and after a shutdown signal, say
  — and you would otherwise write the chain twice and pick with an `if`.

- A handler set that reads better as a list than as a chain.

A `PolyTag` says what an item **is**. It says nothing about what a receiver  
should **do** with it. The same Event reaches four Masters and means four  
different things:

```
Event.TAG
    │
    ├── LogMaster      -> write a line
    ├── RouteMaster    -> send to another mailbox
    ├── StoreMaster    -> write to disk
    └── CountMaster    -> add one to a counter
```

So the handler cannot belong to the tag. It belongs to the pair  
(receiver, tag) — which is what a table holds.

### The type

Nothing in `src/` is needed. `PolyHelper.TAG` is a value that can be stored,  
comparing two tags is `==`, and `Slot` reports what the handler did with the  
item. The table is composed from blocks that already exist, so it ships as an  
example. This is the whole of it — copy it, or write a different one:

```zig
pub fn TagTable(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Handler = *const fn (self: *T, slot: *Slot) anyerror!void;

        pub const Entry = struct {
            tag: *const anyopaque,
            handler: Handler,
        };

        entries: []const Entry = &.{},

        pub fn find(self: Self, tag: *const anyopaque) ?Handler {
            for (self.entries) |entry| {
                if (entry.tag == tag) return entry.handler;
            }
            return null;
        }

        pub fn dispatch(self: Self, receiver: *T, slot: *Slot) anyerror!void {
            const poly = slot.* orelse return error.EmptySlot;
            const handler = self.find(poly.*.tag) orelse return error.NoHandler;
            return handler(receiver, slot);
        }
    };
}
```

Notes on each part.

- `T` is the application's own receiver type, which the toolkit cannot name.
  That is why the table is not in `src/`. A `*anyopaque` context and a cast in  
  every handler — what `PoolHooks` does — is the price library code pays; an  
  application table does not have to.

- `anyerror` and not an inferred error set. A function pointer type needs its
  error set written out, and the table holds handlers written by different  
  authors.

- The receiver pointer is **not** in the table. It arrives as the first
  argument, so one table can be shared by every receiver of its type.

- No allocator, no `init`, no `deinit`. A table is a value.

- Linear search. A receiver handles a handful of item types. If a table ever
  grows enough to matter, the search changes and nothing else does.

### The tables

Container-level `const` values, built once by the compiler:

```zig
const Table = helpers.TagTable(Recorder);

const log_table: Table = .{ .entries = &.{
    .{ .tag = EventPolyHelper.TAG,  .handler = Recorder.logEvent },
    .{ .tag = SensorPolyHelper.TAG, .handler = Recorder.logSensor },
} };

const count_table: Table = .{ .entries = &.{
    .{ .tag = EventPolyHelper.TAG,  .handler = Recorder.countEvent },
} };
```

`EventPolyHelper.TAG` is in both tables against different handlers. That is  
the point, and no chain can express it.

`SensorPolyHelper.TAG` is in the first table only. The second receiver has no  
handler for a sensor, which is a normal state of affairs, not a defect.

Storing a tag in a `const` works, even though a `switch` over tags does not  
compile anywhere. A `const` initializer needs to know *which global* the  
pointer names, which the compiler does know. A `switch` prong needs the  
address, which the linker assigns later. See "No switch on a tag".

A receiver that decides its handlers at run time owns a buffer and slices it —  
still no allocator, because the buffer is a field:

```zig
fn register(self: *Master, tag: *const anyopaque, h: Table.Handler) !void {
    if (self.n == self.buf.len) return error.TableFull;
    self.buf[self.n] = .{ .tag = tag, .handler = h };
    self.n += 1;
    self.table = .{ .entries = self.buf[0..self.n] };
}
```

The difference: a table built this way belongs to the one receiver holding the  
buffer, while a comptime table is shared by every receiver of that type.

### The call

```zig
var slot: Slot = null;
defer items.freeSlot(&slot, allocator);   // no-op when null

if (!try mailbox.try_receive(mbh, &slot)) return;
try table.dispatch(self, &slot);
```

A handler may take the item, forward it, or look and leave it. The `defer`  
covers all three: it frees whatever is left and does nothing when the Slot is  
null.

**The transfer rule**, a convention between the handler author and the loop  
that calls it:

> On return, the Slot is null if the handler took the item, full if it did not.

`src/` cannot enforce this and does not care.

### Outcomes

A call has five outcomes. They are worth listing because a chain never had to  
state them — a chain's branch either ran or did not.

| slot after | error | meaning |
|---|---|---|
| null | none | the handler took or forwarded the item |
| full | none | the handler looked and left it. Caller frees |
| full | yes | failed before the item moved. Caller frees |
| null | yes | the item moved, then something else failed |
| untouched | `error.NoHandler` | no entry matched. Nothing was called |

The Slot and the error answer two different questions, and the caller needs  
both.

- The **Slot** reports where the item is.
- The **error** reports whether the work succeeded.

The fourth row is the one to write down: a handler may forward an item and then  
fail. The item is gone and the error is about something else. A caller that  
frees on error without looking at the Slot double-frees.

### The miss

`error.NoHandler` is not a defect. A tag present in one table and absent from  
another is the normal result of two receivers doing different jobs.

And it is the one place a table beats a chain. The last branch of a chain  
cannot free the item — there is no type there, so there is no size. A table  
miss is different: nothing was called and the item never left the caller's  
Slot, and the caller knows its own type set even though the table matched  
nothing. So the caller frees it with the `defer` it already had.

```zig
table.dispatch(self, &slot) catch |err| switch (err) {
    error.NoHandler => self.unhandled += 1,   // the defer frees it
    else => return err,
};
```

### Several tables per receiver

One table per receiver is the base case. Most receivers never change what they  
do and want nothing more.

A receiver that does change holds a pointer:

```zig
const Master = struct {
    current: *const Table = &normal_table,

    fn beginShutdown(self: *Master) void {
        self.current = &shutdown_table;
    }
};
```

Changing every type's behaviour at once is one pointer store. Nothing is  
rebuilt and nothing is registered again. This is what makes the tables being  
`const` data worth having.

A receiver that already has a state enum for its own reasons can map from it  
instead of holding the pointer. A `switch` over an enum compiles — it is only  
tags that cannot be switched on.

Example: `examples/layer1/027-table_dispatch.zig`,  
`examples/layer4/063-table_dispatch_masters.zig`,  
`examples/helpers/TagTable.zig`.

## No switch on a tag

A `switch` over `Helper.TAG` values does not compile. Not on any zig version or  
backend available.

A switch prong must be known at compile time. A tag is the address of a global,  
and the linker assigns that address, so its value is not known until after  
compilation. Write it and zig accepts the source, then the backend fails —  
LLVM rejects the emitted bitcode, or the self-hosted backend crashes.

`@intFromPtr` does not help. It is refused wherever it is asked for a  
compile-time value.

The chain is not a workaround for the missing switch. `==` and `isIt` need only  
to know *which global* the tag names, which the compiler does know. The switch  
asked for the number, which nobody has.

The same distinction is why a table works. Storing a tag has always been fine.

Full write-up, with the build matrix: `design/secondary/llvm-pointer-switch-bug-001.md`.

## Which way

| you hold | use |
|----------|-----|
| an item, 2-3 types | using item, `fromPoly` |
| an item, many types, or branches that skip the item | using tag, `isIt` |
| a tag only — pool hooks | using tag, no choice |
| a receiver whose work differs from another's over the same types | using table |

The first three read the same tag and cost the same. Pick the one that says  
what the code is doing. Reach for a table when the choice has to move out of  
the code and into data.

## Related

- [Slot & PolyNode Idioms](slot-and-polynode.md)
- [API Reference — Tag Identity](../api/tags-and-slots/index.md)
- [Pool — Hook discipline](../api/pool/hooks-discipline.md)
