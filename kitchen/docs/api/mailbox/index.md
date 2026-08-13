# Mailbox

New to the concept? See [Tools — Mailbox](../../tools/mailbox.md) first.

Moves handles between Masters.

```zig
const mailbox = @import("matryoshka").mailbox;
const Mbox = @import("matryoshka").Mbox;

// typical usage:
var slot: polynode.Slot = &event.poly;
try inbox.send(&slot);              // slot is now null
try inbox.receive(&slot, null);     // slot is now non-null
```

---

## Types

```zig
pub const Mbox = struct { ... };
```

Application code holds `*Mbox` and calls methods on it.

A mailbox is also a PolyNode. `toPoly`/`fromPoly` carry it through another  
mailbox or pool. A mailbox can be:

- sent through another mailbox
- stored in pools
- embedded into larger structures

Same rules as application items.

The struct fields are internal. Use the methods.

---

## What a mailbox never does

The mailbox keeps items. It never touches them. No inspection, no copy, no  
free — it  
allocates and frees exactly one thing, itself.

So every item it holds goes back to a caller:

| edge | who ends up holding the item |
| --- | --- |
| `receive`, `try_receive` | the receiver |
| `send`, `send_oob` returning `error.Closed` | the sender — the slot is unchanged |
| `receive_batch` | the caller, as a list |
| `close` | the caller, as a list |

Releasing them is the caller's job. Free them, or put them back into a pool  
— which one is knowledge the mailbox does not have and never had.

Contrast with [Pool](../pool/index.md), which does touch items, through  
your hooks.

---

## new

```zig
pub fn new(io: Io, alloc: std.mem.Allocator) !*Mbox
```

- Creates a new mailbox.
- Stores `io` internally.

---

