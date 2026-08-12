# Control group

New to the concept? See [Tools — Mailbox](../../tools/mailbox.md) first.

---

## wakeUpAll

```zig
pub fn wakeUpAll(self: *Mbox) error{Closed}!void
```

- Wakes every receiver currently blocked in `receive()` — no item is sent, nothing is queued.
- Blocked receivers return `error.Wakeup`.
- Future receivers (those that call `receive()` after `wakeUpAll()` returns) are not affected.
- Distinct from `close()`: the mailbox is not torn down, and the effect does not persist for
  receivers that start later.


---

## close

```zig
pub fn close(self: *Mbox) polynode.ItemList
```

- Can be called more than once.
- Returns remaining handles as list (empty list on second call).
- Collects all handles still in the queue.
- Wakes up any receivers waiting on the mailbox.

**The caller holds every item in that list.** Release them — free them, or  
put them back into a pool. The mailbox does not know which, and never did.

Run the release unconditionally:

```zig
var rem: polynode.ItemList = mbx.close();
// release every item in `rem`
```

`close` can be called more than once and returns an empty list after the  
first, so an empty list costs nothing. No call site has to work out whether  
the mailbox was empty first.

Never write `_ = mbx.close()`. It drops items the mailbox handed back, and  
the items it drops keep their list links — `send` asserts an unlinked item,  
so they cannot be sent again.

---

## destroy

```zig
pub fn destroy(mbx: *Mbox, alloc: std.mem.Allocator) void
```

- Frees the mailbox.
- Must be closed first.
- Calling destroy on an open mailbox is a programming error (panic).

---

## is_it_you

```zig
pub fn is_it_you(tag: *const anyopaque) bool
```

- Returns true if tag identifies a *Mbox.

---

