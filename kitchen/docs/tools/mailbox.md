# Mailbox

Everything communicates.

A Mailbox moves an Item from one Master to another.

## What a Mailbox does

A Mailbox moves a handle from one owner to another.

```text
Before                           After

sender Slot                      sender Slot
+-------------------+            +-------------------+
|      Handle       |            |       empty        |
+-------------------+            +-------------------+

send  ───────────────────►      Mailbox holds the handle
```

```text
Before                           After

receiver Slot                    receiver Slot
+-------------------+            +-------------------+
|       empty       |            |      Handle        |
+-------------------+            +-------------------+

receive   ◄──────────────────    Receiver holds the handle
```

- Send moves a handle in. Receive moves a handle out.
- The Mailbox never copies the Item — it moves the handle to it.
- The Mailbox never inspects what the handle points to. Any PolyNode-based Item
  can travel through any Mailbox.

## One owner at a time

- While a handle sits in a Mailbox, the Mailbox owns it — not the sender, not the
  receiver.

- Exactly one party holds the handle at any moment: sender, then Mailbox, then
  receiver.

- No locks needed while a receiver processes what it received — nobody else has it.

## Mailboxes are themselves exchangeable

A Mailbox is built from a `PolyNode`, same as any application Item.

- A Mailbox can be sent through another Mailbox.
- A Mailbox can be stored in a Pool.
- A Mailbox can be embedded into a larger structure.

e.g. Worker 

- can signal "I'm done" 
- via sending its own Mailbox
- back to coordinator

---

See also: [API Reference — Mailbox](../api/mailbox/index.md) for the actual Zig functions.
