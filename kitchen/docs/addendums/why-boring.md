# How a boring enterprise programmer thinks

I don't want another event loop.

I don't want another scheduler.

I don't want another async framework.

I want to solve business problems.

---

I have customers.

I have orders.

I have invoices.

I have payments.

I have users.

I have permissions.

Sockets are not my business.

---

Networking is infrastructure.

Databases are infrastructure.

Timers are infrastructure.

Files are infrastructure.

I don't want them leaking into every function.

---

When I open the source tree, I want to see

```
Customer
Order
Invoice
Payment
```

Not

```
Poll
Await
Callback
Completion
Continuation
```

---

When a message arrives,

I don't care if it came from

* TCP
* UDP
* QUIC
* IPC
* Shared memory
* A file
* A timer

I care that

```
CreateOrder
```

arrived.

---

I don't think in sockets.

I think in business events.

---

I don't want fifty items touching the same state.

I want one owner.

One place.

One decision.

---

I don't optimize first.

I optimize after measuring.

Most engineering time is spent understanding code.

Not making it 3% faster.

---

When somebody joins the team,

I want them to understand the architecture in a week.

Not the scheduler in a month.

---

Five years later,

I want to add a feature.

Not rewrite how the system runs.

---

Performance matters.

Architecture matters longer.

For most enterprise software,

architecture wins more often than microbenchmarks.

---

That is the thinking behind a "boring system."

Not slow.

Not old.

Just predictable.

Easy to understand.

Easy to change.

Easy to keep running.
