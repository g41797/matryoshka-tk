# API Reference — matryoshka (root) and Master

## matryoshka (root)

```zig
pub const polynode = @import("polynode.zig");
pub const mailbox = @import("mailbox.zig");
pub const pool = @import("pool.zig");
```

---

## Master (Layer 4) — intentionally not part of the API

No `master` module.  
No `Master` struct.  
By design.

Io creates tasks through `io.concurrent()`.  
Master is an Io task that follows the Matryoshka rules — the coordination boundary.  
It holds and composes the lower layers.

See [Building Blocks — Master](../building-blocks/master.md) for the conceptual framing.

Applications build Masters from:

| What | Where it comes from |
|------|-------------------|
| Transport | `mailbox.MailboxHandle` — one or more mailboxes |
| Lifecycle | `pool.PoolHandle` + `pool.PoolHooks` — handle reuse and policy |
| Memory | `std.mem.Allocator` — who allocates and frees |
| Scheduling | `std.Io` — passed to `mailbox.new` and `pool.new` |
| Worker coordination | `io.concurrent()` → `Future`, or `Io.Group` |
| Cancellation | `Future.cancel(io)` or `group.cancel(io)` |
| Application state | Domain-specific — whatever the subsystem needs |

Both mailbox and pool are optional. Valid combinations:

```text
PolyNode only                        type identity without infrastructure
PolyNode + Mailbox                   type identity + message passing
PolyNode + Pool                      type identity + item lifecycle
PolyNode + Pool + Io.Select          lifecycle + event sources (no mailbox)
PolyNode + Mailbox + Pool            transport + lifecycle
PolyNode + Mailbox + Pool + Io.Select   full stack
```

A Master may be:  
```zig
const Server = struct { inbox: mailbox.MailboxHandle, pool: pool.PoolHandle, ... };
const Scheduler = struct { pool: pool.PoolHandle, ... };  // no mailbox
const Pipeline = struct { stages: [3]mailbox.MailboxHandle, ... };
fn main(init: std.process.Init) !void { ... }
```

Matryoshka provides the building blocks.  
The application assembles them.

### Io backend for Layer 4 tests and examples

Layer 1-3 tests use `std.Io.Threaded.global_single_threaded.*.io()` — no concurrency needed.

Layer 4 tests and examples need real concurrency (`io.concurrent`, `Io.Group`):

- Use `std.Io.Threaded.init(allocator, .{})` to get a real backend.
- Call `.deinit()` when done.

```zig
// In a Layer 4 test:
var threaded = try std.Io.Threaded.init(std.testing.allocator, .{});
defer threaded.deinit();
const io: std.Io = threaded.io();
```

```zig
// In a Layer 4 example (run function):
pub fn run(allocator: std.mem.Allocator, io: std.Io) !void {
    // io is passed in — examples never create the backend themselves
}
```

```zig
// In the test wrapper for a Layer 4 example:
test "17 - minimal master" {
    std.testing.log_level = .debug;
    var threaded = try std.Io.Threaded.init(std.testing.allocator, .{});
    defer threaded.deinit();
    const io: std.Io = threaded.io();
    try layer4.minimal_master.run(std.testing.allocator, io);
}
```

Key rules:

- `std.testing.io` — not used in this project, even in test files.
- `global_single_threaded` — Layer 1-3 only. Returns `error.ConcurrencyUnavailable` for `io.concurrent`.
- `Io.Threaded.init` — Layer 4 tests and example wrappers.
- Examples receive `std.Io` as a parameter. They never import or reference `std.testing`.

### Event sources

See [Addendums — Io 101](../addendums/io-101.md) for the general `Future` → `Io.Select` pattern.

Matryoshka plugs into the same pattern:

```text
  mailbox.receiveResult ──► select.concurrent(.inbox, ...)  ──┐
  pool.getWaitResult    ──► select.concurrent(.pool, ...)   ──┼──► Io.Select.queue ──► Master dispatch
  Io.sleep              ──► select.concurrent(.timer, ...)  ──┤
  direct push           ──► select.queue.putOneUncancelable ──┘
```

- `mailbox.receiveResult` + `select.concurrent` — mailbox as Select event source.
- `pool.getWaitResult` + `select.concurrent` — pool as Select event source.
- `mailbox.receive_future` / `pool.get_wait_future` — Future wrappers for direct await or `Io.Group`.
- Master calls `select.await()`, handles the result, re-spawns the source.

---


