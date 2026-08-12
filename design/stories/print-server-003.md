# Story: Network Print Server (003)


Change from -002: API 12-4 — the doc speaks the pointer API. Methods on  
`*Mbox` / `*Pool`; `new`, `destroy`, `receiveResult`, `getWaitResult` stay  
free functions on the module.


A complete system design — from domain problem to Matryoshka implementation.

---

## Part 1 — Discussion

Three developers design a print server for a shared office network.

**C** owns the client library — the code that submits jobs on behalf of applications.  
**S** owns the spooler — the server that queues and manages jobs.  
**D** owns the driver — the component that talks to the physical printer.

---

**C**: When my application submits a print job, what do I get back?

**S**: An acknowledgment that the job is queued.

**C**: That's not enough. I need to know when it finishes. Or if it fails.

**S**: You give me a return address when you submit. I send the result there when the job is done.

**C**: So submission and result are separate.

**S**: Yes. You submit, move on, and wait for a result on your own channel.

**C**: Good. My application should not block waiting for a slow printer.

---

**D**: Who hands me the job?

**S**: I do. When you are free, I take the next job from the queue and send it to you.

**D**: What does "send it to you" mean exactly?

**S**: I transfer the job. You own it while you print. I no longer hold it.

**D**: Good. I do not want to share it with anyone while I am working on it.

**S**: You own it completely. When you finish, you send the result back to the client.

**D**: Through you?

**S**: No. Directly. You have the client's return address. You send the result there yourself.

---

**C**: What if I change my mind after submitting?

**S**: If the job is still in my queue, I remove it and send you a canceled result.

**C**: What if it is already with the printer?

**S**: I have to reach the printer.

**D**: How will you reach me? I am printing. I am not listening for new jobs.

**S**: I need a separate signal. Something you see before the next job arrives.

**D**: Use my inbox. But if the cancel waits behind another job, you may send me that job before the cancel arrives. I will start printing the wrong document.

**S**: So the cancel has to reach you before any other job does.

**D**: Yes. Otherwise I cannot honor it reliably.

**C**: What if multiple clients cancel at the same time?

**S**: Each cancel is a separate signal. They all jump the queue. I process them in the order they arrive at the front.

---

**C**: What happens if the printer jams or runs out of paper?

**D**: I detect the error and send a failed result to the client. Then I wait for the operator to clear the fault.

**S**: And the queue keeps accumulating during that time.

**D**: Yes. When the printer is ready again, I signal you, and you send me the next job.

**C**: What signals readiness?

**D**: When I am done with a job — success or failure — I am ready for the next one.

**S**: So readiness is implicit. When you finish, I send the next job. No explicit ready signal needed.

---

**C**: Who owns the document while it is printing?

**D**: I do. From the moment the spooler hands it to me until I send the result to the client.

**C**: And between submission and dispatch to the printer?

**S**: I do. It lives in my queue.

**C**: So at any moment, exactly one party holds the document.

**S**: Yes. The client created it and handed it to me. I hold it until I hand it to the driver. The driver holds it until it sends the result. Nobody shares it.

**D**: That is why I do not need locks while printing. I am the only owner. And I do not need to report progress. Either I finish and send the result, or I fail and send the result. The spooler does not need to know which page I am on.

**S**: And that is why I do not need to track status. If the job is in my queue, I am responsible. If it is not, the driver has it.

At any moment, whoever holds the job owns the problem.

---

## Part 2 — SRS

- Client submits a print job and receives an immediate acknowledgment.
- Submission never waits for printer availability.
- Jobs are dispatched to the printer in submission order.
- Exactly one party holds a job at any moment.
- No job is shared between the spooler and the printer.
- Each client receives one final result — success, failure, or canceled.
- Result is delivered to a return channel provided at submission time.
- A client can cancel a job at any time.
- Cancel removes the job if it is still queued.
- Cancel reaches the printer before any queued job if the job is already with the printer.
- Shutdown loses no jobs.
- All pending clients receive a canceled result on shutdown.

---

## Part 3 — Matryoshka Translation

Requirement: Non-blocking submission.

Matryoshka:
- `PrintJob` — PolyNode-based struct.
- `job_queue.send(&job_slot)`.
- Ownership transferred immediately.
- Client continues.

---

Requirement: Ordered dispatch.

Matryoshka:
- Spool Master.
- `job_queue` mailbox.
- `Mbox.receive` — FIFO preserved.

---

Requirement: Result notification.

Matryoshka:
- `reply_mbx: *Mbox` embedded in `PrintJob`.
- Printer Master sends `PrintResult` directly to `job.reply_mbx`.
- Spool Master not involved.

---

Requirement: Exclusive hold during printing.

Matryoshka:
- Printer Master holds one job.
- Single slot: `var slot: Slot = null`.
- No shared access. No locks.

---

Requirement: Cancellation with priority.

Matryoshka:
- `job_queue.send_oob(&cancel_slot)`.
- `CancelSignal` arrives at queue front.
- If job already forwarded: `printer_inbox.send_oob(&cancel_slot)`.

---

Requirement: Clean shutdown.

Matryoshka:
- Spool Master closes `job_queue`.
- Remaining jobs in `printer_inbox` receive canceled result via `job.reply_mbx`.
- Closes `printer_inbox`.
- Printer Master gets `error.Closed` on next receive. Exits.

---

**The central insight.**

At any moment, whoever holds the job owns the problem.

- No shared status table.
- No polling.
- No ambiguity about who holds the job.
- Responsibility follows location.

Where the job is.

- Job in `job_queue` — Spool Master owns it.
- Job in `printer_inbox` — moving between Masters.
- Job in Printer slot — Printer Master owns it.
- Result in `reply_mbx` — client owns the outcome.

---

## Part 4 — Flow Diagram

```text
  [ Client A ]  [ Client B ]  [ Client C ]
       │               │               │
       │ job_queue.send(&job_slot)        ← non-blocking, hold transferred
       │ job_queue.send_oob(&cancel_slot) ← OOB: arrives at queue front
       └───────────────┴───────────────┘
                       │
                       V
           SPOOL MASTER (Mbox.receive loop on job_queue)
           ├── on PrintJob:
           │     printer_inbox.send(&job_slot)   ← forward, hold transferred
           │
           ├── on CancelSignal (OOB — arrives before regular jobs):
           │     job still in job_queue?
           │       yes → remove, send PrintResult{.canceled} → job.reply_mbx
           │     job already forwarded to printer_inbox?
           │       yes → printer_inbox.send_oob(&cancel_slot)
           │       no  → job already printing; Printer Master handles it
           │
           V
           [ printer_inbox ]
                       │
                       V
           PRINTER MASTER (Mbox.receive loop on printer_inbox)
           ├── on PrintJob:
           │     var slot: Slot = job           ← exclusive hold, no locks
           │     print(job)                     ← process pages
           │     send PrintResult{.ok} → job.reply_mbx
           │     destroy job
           │
           ├── on CancelSignal (OOB — arrives before next regular job):
           │     if currently printing: abort
           │     send PrintResult{.canceled} → current_job.reply_mbx
           │     destroy current job
           │
           V
           [ reply_mbx — per client ]
                       │
                       V
              Client calls reply_mbx.receive(...)
              receives PrintResult{.ok} or PrintResult{.canceled} or PrintResult{.failed}

  Shutdown sequence:
  Spool Master closes job_queue
    → walks printer_inbox close list: sends .canceled to each job.reply_mbx
    → closes printer_inbox
  Printer Master finishes current job
    → gets error.Closed on next receive
    → exits
```

---

*Analysis and pattern coverage notes: [print-server-analysis-001.md](../secondary/print-server-analysis-001.md)*
