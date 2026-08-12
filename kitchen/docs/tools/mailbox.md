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

## The Mailbox holds. It never touches.

Custody is not use. While the Mailbox has the handle, it does nothing to the  
Item behind it.

- No inspection.
- No copy.
- No free.

Internally it is a list of handles, and that is the whole of it. A Mailbox  
allocates and frees exactly one thing: itself.

This is the difference from a Pool, which does touch items — creating,  
resetting, keeping or destroying them through your hooks.

## Closing and releasing is your job

A Mailbox does not care whether you closed it. Every method on a closed  
Mailbox simply says so and the object stays valid. Only `destroy` insists —  
it must be closed first, and panics otherwise.

When you close it, it hands back everything it was still holding, as a list,  
and it is done.

- What those Items are — heap items to free, pool items to put back — is
  knowledge the Mailbox does not have and never had.

- So releasing them is yours. Walk the list and release each one.

**Release unconditionally.** `close` can be called more than once and returns  
an empty list after the first, so the release loop is always safe to run: on a Mailbox that  
still holds Items, on one already empty, on one closed twice. There is no  
state in which running it is wrong — which means no caller has to reason  
about which state it is in.

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
