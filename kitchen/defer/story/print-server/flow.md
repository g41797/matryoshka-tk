# Story: Network Print Server — Flow Diagram

```text
  [ Client A ]  [ Client B ]  [ Client C ]
       │               │               │
       │ mailbox.send(job_queue, &job_slot)        ← non-blocking, ownership transferred
       │ mailbox.send_oob(job_queue, &cancel_slot) ← OOB: arrives at queue front
       └───────────────┴───────────────┘
                       │
                       V
           SPOOL MASTER (mailbox.receive loop on job_queue)
           ├── on PrintJob:
           │     mailbox.send(printer_inbox, &job_slot)   ← forward, ownership transferred
           │
           ├── on CancelSignal (OOB — arrives before regular jobs):
           │     job still in job_queue?
           │       yes → remove, send PrintResult{.canceled} → job.reply_mbh
           │     job already forwarded to printer_inbox?
           │       yes → mailbox.send_oob(printer_inbox, &cancel_slot)
           │       no  → job already printing; Printer Master handles it
           │
           V
           [ printer_inbox ]
                       │
                       V
           PRINTER MASTER (mailbox.receive loop on printer_inbox)
           ├── on PrintJob:
           │     var slot: Slot = job           ← exclusive ownership, no locks
           │     print(job)                     ← process pages
           │     send PrintResult{.ok} → job.reply_mbh
           │     destroy job
           │
           ├── on CancelSignal (OOB — arrives before next regular job):
           │     if currently printing: abort
           │     send PrintResult{.canceled} → current_job.reply_mbh
           │     destroy current job
           │
           V
           [ reply_mbh — per client ]
                       │
                       V
              Client calls mailbox.receive(reply_mbh, ...)
              receives PrintResult{.ok} or PrintResult{.canceled} or PrintResult{.failed}

  Shutdown sequence:
  Spool Master closes job_queue
    → walks printer_inbox close list: sends .canceled to each job.reply_mbh
    → closes printer_inbox
  Printer Master finishes current job
    → gets error.Closed on next receive
    → exits
```

---

Next: [Tools](../../tools/index.md) — see PolyNode, Mailbox, Pool,  
and Master named individually, still no Zig syntax.
