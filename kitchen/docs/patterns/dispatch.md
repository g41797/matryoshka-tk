# Patterns — Dispatch

Concepts: [Building Blocks — PolyNode](../building-blocks/polynode.md).  
API: [API Reference — PolyNode, ItemHandle, Slot](../api/polynode/index.md).

One mailbox carries many types. One pool holds many types. The receiver has to  
find out what arrived.

There are two ways. They differ by what you are holding.

- **Item-first** — you have an `ItemHandle`. Ask each type to cast it.
- **Tag-first** — you have a tag and nothing else. Ask each type to confirm it.

## Item-first dispatch

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

## Tag-first dispatch

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
item-first is not an option — only the tag exists.

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

Full write-up, with the build matrix: `design/llvm-pointer-switch-bug-001.md`.

## Which way

| you hold | use |
|----------|-----|
| an item, 2-3 types | item-first, `fromPoly` |
| an item, many types, or branches that skip the item | tag-first, `isIt` |
| a tag only — pool hooks | tag-first, no choice |

Both ways read the same tag and cost the same. Pick the one that says what the  
code is doing.

## Related

- [Slot & PolyNode Idioms](slot-and-polynode.md)
- [API Reference — Tag Identity](../api/tags-and-slots/index.md)
- [Pool — Hook discipline](../api/pool/hooks-discipline.md)
