# API Reference — Mailbox — send

New to the concept? See [Tools — Mailbox](../../tools/mailbox.md) first.

---

## send

```text
Before                           After

sender Slot                      sender Slot
+-------------------+            +-------------------+
|    ItemHandle     |            |       null        |
+-------------------+            +-------------------+

mailbox.send(mbh, &slot)  ───►      Mailbox holds ItemHandle
```

```zig
pub fn send(mbh: MailboxHandle, slot: *Slot) error{Closed}!void
```

- Appends handle to tail.
- Moves the handle — `slot.*` set to null.
- Assert:
  - `mailbox.is_it_you(mbh.*.tag)`
  - `slot.* != null`
  - `!polynode.is_linked(slot.*)`

---

## send_oob

Advanced: OOB (out of the box).

```zig
pub fn send_oob(mbh: MailboxHandle, slot: *Slot) error{Closed}!void
```

- Inserts handle after last OOB handle.
- FIFO among OOBs, all OOBs before regular handles.
- Moves the handle — `slot.*` set to null.
- Assert:
  - `mailbox.is_it_you(mbh.*.tag)`
  - `slot.* != null`
  - `!polynode.is_linked(slot.*)`

OOB ordering:

```
send(R1), send(R2):       [R1, R2]                oob=0
send_oob(O1):             [O1, R1, R2]            oob=1
send(R3):                 [O1, R1, R2, R3]        oob=1
send_oob(O2):             [O1, O2, R1, R2, R3]   oob=2
receive → O1:             [O2, R1, R2, R3]        oob=1
receive → O2:             [R1, R2, R3]            oob=0
```

---

