# Patterns — Mailbox and Topology Patterns

Concepts: [Tools — Mailbox](../tools/mailbox.md).  
API: [API Reference — Mailbox](../api/mailbox/index.md).

## Mailbox patterns

### Try-receive polling

When to use.

- Non-blocking work loop.

Code shape.  
```zig
if (try mailbox.try_receive(mbh, &slot)) {
    ...
}
```

### Batch receive

When to use.

- Empty an entire mailbox in one call.

Code shape.  
```zig
var list = try mailbox.receive_batch(mbh);

while (list.popFirst()) |node| {
    ...
}
```

Why.

- Reduces synchronization overhead.
- Natural bulk processing.

### Out-of-band priority

When to use.

- Shutdown.
- Urgent control messages.

Code shape.  
```zig
try mailbox.send_oob(mbh, &slot);
```

Why.

- OOB messages always precede normal traffic.
- FIFO inside the OOB region.

### Mailbox close recovery

When to use.

- Shutdown. Recover every queued item.

Code shape.  
```zig
var list = mailbox.close(mbh);

while (list.popFirst()) |node| {
    ...
}
```

Why.

- Nothing leaks.
- Close is also the end-of-stream signal for blocked receivers (see Group shutdown in
  [Shutdown & Master Patterns](master-and-shutdown.md)).

### Wake blocked receivers without a message

When to use.

- Re-check external state (a flag flipped outside the mailbox) without sending a real item.
- Poke a Master blocked in `receive()` so it re-evaluates its loop condition.

Code shape.  
```zig
shutdown.store(true, .release);
try mailbox.wakeUpAll(mbh);
```

```zig
mailbox.receive(mbh, &slot, null) catch |err| switch (err) {
    error.Wakeup => {
        if (shutdown.load(.acquire)) return;
        continue; // spurious poke, re-check and keep waiting
    },
    else => ...,
};
```

Why.

- Distinct from `close()`: the mailbox is not torn down, sending still works afterward.
- Distinct from `send()`: nothing is queued, no item to free.
- Only receivers already blocked at the time of the call return `error.Wakeup` — a receiver
  that starts `receive()` afterward is not affected.

Example: `examples/layer2/097-wake_up_all.zig`.

---

## Topology patterns

Recurring shapes for connecting mailboxes and workers. Each is a composition of the  
Mailbox patterns above, not a new mechanism.

### Request-Response

When to use.

- One side asks, the other answers, on two dedicated mailboxes.

Pattern.  
```
main ──Event(request)──► req_mbh ──► worker
                                        │ process
                                        V
main ◄──Event(response)── resp_mbh ◄── worker
```

Why.

- Request and response never share a mailbox — no risk of the caller receiving its own request back.
- Caller blocks on `resp_mbh` with a timeout; worker loops on `req_mbh` until closed.

Example: `examples/layer2/057-request_response.zig`, `examples/layer4/021-request_response.zig`.

### Pipeline

When to use.

- A chain of stages, each transforming and forwarding.

Pattern.  
```
producer ──Event──► stage1 ──► transformer ──Event──► stage2 ──► consumer
```

Why.

- Each stage owns one item at a time — the slot rule holds at every hop.
- A sentinel value (e.g. `code == -1`) signals end-of-stream down the chain; the last stage frees it.

Example: `examples/layer2/056-pipeline.zig`, `examples/layer4/020-pipeline_masters.zig`.

### Fan-In

When to use.

- Several concurrent senders, one shared mailbox, one receiver.

Pattern.  
```
sender A ──►
sender B ──► mailbox ──receive_batch──► one receiver, dispatch by tag
sender C ──►
```

Why.

- The mailbox itself does the merging — no separate synchronization needed.
- Batch receive plus polymorphic dispatch (mixed item types) empties it in one pass.

Example: `examples/layer2/058-fan_in.zig`, `examples/layer4/053-pool_fan_in.zig`.

### Fan-Out

When to use.

- Several worker threads compete for items on one shared mailbox.

Pattern.  
```
main ──items──► mailbox ──► worker A
                       ├──► worker B   (compete; each item goes to exactly one)
                       └──► worker C
```

Why.

- The mailbox does the load distribution. No round-robin logic in application code.
- `mailbox.close` returns any item left unclaimed — the closer must free it.

Example: `examples/layer2/061-fan_out.zig`, `examples/layer4/054-pool_fan_out.zig`.

---

