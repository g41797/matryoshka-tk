
---

# Slot-Based Programming

---


Matryoshka infrastructure does not work with application objects.

It works with **Slots**.

A Slot is a temporary container.

It may contain an ItemHandle.

Or it may be empty.

The infrastructure never needs to know what the Item actually is.

Mailbox and Pool work mostly with Slots.

---


## Why

---


Concurrent software is mostly about ownership.

Who owns an Item now?

Who owns it next?

The infrastructure should answer these questions.

It should not know object types.

It should not call application methods.

It should not depend on inheritance.

It should only move ownership.

Slots make ownership explicit.

---


## The Slot

---


A Slot is not the object being transferred.

The ItemHandle is transferred.

The Slot is the container used during the transfer.

The Slot also represents ownership.

A non-empty Slot means:

> I own this ItemHandle.

An empty Slot means:

> I no longer own it.

The Slot itself never moves.

Only the ItemHandle moves.

---


## Ownership Transfer

---


Sending does not send a Slot.

Sending uses a Slot.

```zig
mailbox.send(&slot);
```

The Mailbox takes the ItemHandle from the Slot.

If sending succeeds:

```
Before send

Slot
 └── ItemHandle

After send

Slot
 └── empty
```

Ownership has moved to the Mailbox.

The sender no longer owns the ItemHandle.

Receiving works the opposite way.

```zig
mailbox.receive(&slot);
```

The Mailbox places a ItemHandle into the Slot.

```
Before receive

Slot
 └── empty

After receive

Slot
 └── ItemHandle
```

Now the receiver owns the ItemHandle.

The same Slot can be reused thousands of times.

It is only a temporary container.

---


## Infrastructure View

---


Most infrastructure API works with Slots.

```zig
mailbox.send(&slot);
```

```zig
mailbox.receive(&slot);
```

```zig
pool.get(&slot);
```

```zig
pool.put(&slot);
```

The infrastructure never sees application objects.

It only sees Slots and ItemHandles

---


## Application View

---


The application knows the real Item type.

It converts the ItemHandle inside the Slot back into an object.

```zig
const request = RequestPolyHelper.fromSlot(&slot) orelse return;
```

or

```zig
const frame = VideoFramePolyHelper.fromSlot(&slot) orelse return;
```

From this point the code works with ordinary Zig objects.

No wrappers.

No virtual methods.

No runtime type information.

Just little bit of _comptime_.

---


## Example

---


An HTTP connection creates a Request Item.

```
Request
    │
    ▼
ItemHandle
    │
    ▼
 Slot
```

The request is sent.

```zig
mailbox.send(&slot);
```

The Slot becomes empty.

The worker receives the request.

```zig
mailbox.receive(&slot);
```

The Slot now owns the Handle again.

The application converts it.

```
Slot
 │
 ▼
RequestPolyHelper.fromSlot()
 │
 ▼
*Request
```

The worker processes the request.

When finished, ownership moves again.

The Handle may be:

- returned to a Pool
- sent to another Mailbox
- destroyed

The infrastructure never knows it was an HTTP request.

---


## Benefits

---


### Explicit ownership

---


Ownership is visible.

A full Slot owns a Handle.

An empty Slot does not.

---


### Zero-copy

---


Only the Handle moves.

The Item stays where it is.

---


### Generic infrastructure

---


Mailbox and Pool never depend on application types.

The same code works for every Item.

---


### Simple APIs

---


Every transfer looks the same.

```zig
mailbox.send(&slot);
```

```zig
mailbox.receive(&slot);
```

```zig
pool.get(&slot);
```

```zig
pool.put(&slot);
```

---


### Separation of responsibilities

---


The infrastructure moves ownership.

The application gives meaning to the Item.

Neither knows about the other's implementation.

---


## Programming Model

---


Infrastructure programming is Slot-based.

Application programming is object-based.

The boundary is explicit.

```
Application Object
        │
        ▼
     ItemHandle
        │
        ▼
       Slot
        │
        ▼
Matryoshka Infrastructure
        │
        ▼
       Slot
        │
        ▼
     ItemHandle
        │
        ▼
Application Object
```

---


This is one of the core ideas of Matryoshka.

The infrastructure operates on Slots.

Ownership moves by transferring Handles.

The application works with Items.


---

