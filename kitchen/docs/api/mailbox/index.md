# Mailbox

New to the concept? See [Tools — Mailbox](../../tools/mailbox.md) first.

Moves handles between Masters.

```zig
const mailbox = @import("matryoshka").mailbox;

// typical usage:
var slot: polynode.Slot = &event.poly;
try mailbox.send(inbox, &slot);              // slot is now null
try mailbox.receive(inbox, &slot, null);     // slot is now non-null
```

---

## Types

```zig
pub const MailboxHandle = ItemHandle;
```

MailboxHandle is itself a *PolyNode.  
A mailbox can be:

- sent through another mailbox
- stored in pools
- embedded into larger structures

Same rules as application items.

---

## new

```zig
pub fn new(io: Io, alloc: std.mem.Allocator) !MailboxHandle
```

- Creates a new mailbox.
- Stores `io` internally.

---

