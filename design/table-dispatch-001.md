# Table dispatch (001)

Working document for DISPATCH 2.

Describes the use case and the chosen solution.

Written before the example. The example is built from this document.

---

## Agreed design

Every row is decided. Sections below give the reasoning.

| decision | value |
|---|---|
| `src/` change | none |
| handler type | `*const fn (self: *T, slot: *Slot) anyerror!void` |
| item transfer | handler may take it, forward it, or leave it |
| after a hit | caller frees whatever is left in the Slot |
| lookup miss | `find` returns null, `dispatch` returns `error.NoHandler` |
| table contents | `{tag, handler}` pairs only — no receiver pointer |
| receiver passed | at the call: `table.dispatch(self, &slot)` |
| table storage | `entries: []const Entry` — a comptime literal or a receiver-owned buffer. No allocator |
| tables per receiver | one is the base case. Several is optional |
| transfer rule | convention for handler authors, not a toolkit rule |
| ships as | `examples/helpers/TagTable.zig` + pattern documentation |

---

## The problem

A `PolyTag` says what an item **is**. It says nothing about what a receiver  
should **do** with it.

The same `Event` reaches four Masters and means four different things.

```
Event.TAG
    │
    ├── LogMaster      -> write a line
    ├── RouteMaster    -> send to another mailbox
    ├── StoreMaster    -> write to disk
    └── CountMaster    -> add one to a counter
```

So the handler cannot belong to the tag.

Both existing ways put the choice in the receiver's code:

```zig
if (EventPolyHelper.isIt(tag)) {
    // this call site, and only this one, decides what happens
}
```

The chain is source. Two Masters that treat `Event` differently write two  
chains. A Master that treats `Event` differently before and after a shutdown  
signal writes the chain twice and picks with an `if`.

That is the limit. The choice is fixed where the code is written.

## The solution

Make the choice **data**.

A table of `{tag, handler}` pairs, owned by the receiver:

```zig
const log_table: Table = .{ .entries = &.{
    .{ .tag = EventPolyHelper.TAG,  .handler = logEvent },
    .{ .tag = SensorPolyHelper.TAG, .handler = logSensor },
} };

const count_table: Table = .{ .entries = &.{
    .{ .tag = EventPolyHelper.TAG,  .handler = countEvent },
} };
```

`EventPolyHelper.TAG` appears in both tables against different handlers. That  
is the whole point, and no chain can express it.

`SensorPolyHelper.TAG` appears in the first table only. `CountMaster` has no  
handler for a sensor, which is a normal state of affairs, not a defect.

## A tag works as data

A `const` table holding `EventPolyHelper.TAG` compiles and runs on both  
backends at all four optimize levels. Measured before this document was  
written.

This is worth stating because DISPATCH 1 ended at the opposite result: a  
`switch` over tags does not compile anywhere. The two facts sit next to each  
other and the difference matters.

- A `switch` prong needs the tag's **number**, which the linker assigns after
  compilation. Nobody has it at compile time.
- A `const` initializer needs to know **which global** the pointer names. The
  compiler does know that, and the linker fills the number in later.

So storing a tag has always worked. It was only ever `switch` that asked for  
something that does not exist.

Full write-up: `llvm-pointer-switch-bug-001.md`.

---

## Why it is not part of Matryoshka

`T` is the application's receiver type.

- The handler's first parameter is `*T`.
- `T` is a Master, a worker, an application struct. Matryoshka cannot name it.

The alternative is a `*anyopaque` context pointer with a cast in every handler,  
which is what `PoolHooks` does — because the pool is library code that runs  
before the application type exists.

A table has no such constraint. The receiver builds its own table and knows its  
own type, so `TagTable(T)` gives every handler a typed `self` and no cast.

Nothing in `src/` is needed. `PolyHelper.TAG`, `isIt` and `Slot` already  
provide the parts:

- `TAG` is a value that can be stored.
- comparing two tags is `==`.
- `Slot` carries the item and reports what the handler did with it.

The table is composed from blocks that exist. Adding it to `src/` would add a  
generic parameter to an API that is otherwise concrete — `MailboxHandle`,  
`Slot`, `ItemHandle` — for no capability the application cannot write itself.

So it ships as an example plus pattern documentation.

Applications are free to write a different table, or none at all.

---

## Shape

```zig
pub fn TagTable(comptime T: type) type {
    return struct {
        pub const Handler = *const fn (self: *T, slot: *Slot) anyerror!void;

        pub const Entry = struct {
            tag: *const anyopaque,
            handler: Handler,
        };

        entries: []const Entry,

        pub fn find(self: @This(), tag: *const anyopaque) ?Handler { ... }
        pub fn dispatch(self: @This(), receiver: *T, slot: *Slot) !void { ... }
    };
}
```

Notes on each part.

- `anyerror` and not an inferred error set. A function pointer type needs the
  error set written out, and the table holds handlers written by different  
  authors, so nothing narrower can be named. This is the price of a table.

- `entries` is a slice. The table needs no allocator, no `deinit` and no
  `init`. It is a value. Where the backing array comes from is the receiver's  
  business — see "Building a table at run time".

- The receiver pointer is **not** in the table. It arrives as the first
  argument. One receiver can point at several tables without holding several  
  copies of a pointer to itself, and one table can be shared by every receiver  
  of that type.

- `find` returns `?Handler`, matching `fromPoly`, which returns `?*T`. The
  error belongs one level up, in `dispatch`.

- Linear search. A receiver handles a handful of item types. A hash map costs
  an allocator and a hash per call to save a comparison or two. If a table ever  
  grows enough to matter, the search changes and nothing else does.

## Building a table at run time

The examples use comptime literals, because a Master usually knows its own  
handlers when it is written. That is a choice of the example, not a limit of  
the type.

`entries` is `[]const Entry`. A slice does not care where its backing array  
came from, so a receiver that decides its handlers at run time owns a buffer  
and slices it:

```zig
const Master = struct {
    buf: [8]Entry = undefined,
    n: usize = 0,
    table: Table = .{ .entries = &.{} },

    fn register(self: *Master, tag: *const anyopaque, h: Handler) !void {
        if (self.n == self.buf.len) return error.TableFull;
        self.buf[self.n] = .{ .tag = tag, .handler = h };
        self.n += 1;
        self.table = .{ .entries = self.buf[0..self.n] };
    }
};
```

Still no allocator. The buffer lives in the receiver, so its lifetime is the  
receiver's.

Verified: a table built this way dispatches the same as a comptime one.

One difference from a comptime table. The buffer is a field, so a  
receiver-built table **cannot be shared** — it belongs to the one receiver that  
holds it. A comptime table is shared by every receiver of that type. This is  
inherent to where the bytes live, not a defect of either.

An allocated buffer would be needed only if the entry count cannot be bounded  
at compile time — handlers registered by a plugin, or a table built from a  
config file that names the types. Nothing in this toolkit works that way: a  
Master's item types are known when the Master is written, which is what  
`PoolHooks.tags` already assumes at pool registration. No example allocates,  
and none should need to.

Coverage: `027` and `063` both use comptime literals, which is the shape to  
copy. The `register` form above is pinned down by a test — it is a detail of  
where the bytes live, so it earns a test and this section rather than an  
example of its own.

## Outcomes

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

The fourth row is the one to write down: a handler may forward an item and  
then fail. The item is gone and the error is about something else. A caller  
that frees on error without looking at the Slot double-frees.

The null-safe cleanup idiom covers every row:

```zig
var slot: Slot = null;
defer items.freeSlot(&slot, allocator);   // no-op when null
try mailbox.receive(mbh, &slot, null);
try master.table.dispatch(master, &slot);
```

## The miss

`error.NoHandler` is not a defect. A tag present in one table and absent from  
another is the normal result of two receivers doing different jobs.

And it is the one place a table beats a chain.

The last branch of an `isIt` chain **cannot free** the item. There is no type  
there, so there is no size, so `alloc.destroy` cannot be called. See  
`patterns/dispatch.md`.

A table miss is different. The item never left the caller's Slot, and the  
caller knows its own type set even though the table matched nothing. So the  
caller frees it with the same `defer` it already had.

## The transfer rule

For handler authors, not for the toolkit:

> On return, the Slot is null if the handler took the item, full if it did not.

`src/` cannot enforce this and does not care. It is a convention between the  
person writing a handler and the person writing the loop that calls it.

It lives in three places:

- the doc comment on `Handler`, where a handler author reads it
- `patterns/dispatch.md`
- this table

## Several tables per receiver — optional

The base case is one table per receiver. Most Masters never change behaviour  
and want nothing more.

A receiver that does change behaviour holds a pointer:

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
instead of holding the pointer. That is an application choice. A `switch` over  
an enum compiles — it is only tags that cannot be switched on.

## Precedent

`PoolHooks` is the same idea with the set fixed:

```zig
on_get: *const fn (ctx: *anyopaque, tag: *const anyopaque, in_pool_count: usize, slot: *Slot) void,
```

A context pointer, a tag, and a Slot that reports the result. The hook's set of  
handlers is decided by the toolkit; a table's set is decided by the receiver.

The table is not a new concept in this codebase. It is the hook shape with the  
handler set opened up.

---

## Related

- `patterns-025.md` — Polymorphic dispatch, all three forms
- `rules-039.md` — the transfer rule as an author convention
- `llvm-pointer-switch-bug-001.md` — why a tag cannot be a `switch` prong
- `receive-router-001.md` — the other example-plus-pattern that stayed out of
  `src/`, for the same reason
