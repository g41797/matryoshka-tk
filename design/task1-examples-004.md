# Task 1 — Example Scenarios for Layers 1–3 (004)

Versioned doc. Replaces [task1-examples-003.md](task1-examples-003.md).

Change from -003: banned-word pass. `ownership` removed from the Layer 1 heading  
and from scenario 22's title, matching the reworded `//!` description. The file  
name `022-ownership_transfer.zig` is unchanged — owner's decision.

Index only. Full staccato description lives in each source file's `///` doc comment,  
per "Description as code" in [rules-009.md](rules-009.md).

Master, Cancel, Futures, Io.Group, and subsystem coordination  
are intentionally excluded. Layers 1–3 must be fully testable without them.

---

## Layer 1 — Holding and transfer (PolyNode + Slot + Tags)

21. **Define a PolyNode type** → [examples/layer1/021-define_type.zig](../examples/layer1/021-define_type.zig)
22. **Item transfer via Slot** → [examples/layer1/022-ownership_transfer.zig](../examples/layer1/022-ownership_transfer.zig)
23. **Tag-dispatch consume loop** → [examples/layer1/023-tag_dispatch.zig](../examples/layer1/023-tag_dispatch.zig)
24. **Builder pattern** → [examples/layer1/024-builder.zig](../examples/layer1/024-builder.zig)
25. **Produce-consume with defer cleanup** → [examples/layer1/025-produce_consume.zig](../examples/layer1/025-produce_consume.zig)

---

## Layer 2 — Movement (Mailbox)

53. **Simple send-receive** → [examples/layer2/053-simple_send_receive.zig](../examples/layer2/053-simple_send_receive.zig)
54. **Worker loop pattern** → [examples/layer2/054-worker_loop.zig](../examples/layer2/054-worker_loop.zig)
55. **OOB via send_oob** → [examples/layer2/055-oob_signal.zig](../examples/layer2/055-oob_signal.zig)
56. **Pipeline** → [examples/layer2/056-pipeline.zig](../examples/layer2/056-pipeline.zig)
57. **Request-response** → [examples/layer2/057-request_response.zig](../examples/layer2/057-request_response.zig)
58. **Fan-in** → [examples/layer2/058-fan_in.zig](../examples/layer2/058-fan_in.zig)
59. **Shutdown with remaining item cleanup** → [examples/layer2/059-shutdown_cleanup.zig](../examples/layer2/059-shutdown_cleanup.zig)
60. **Batch processing** → [examples/layer2/060-batch_processing.zig](../examples/layer2/060-batch_processing.zig)
61. **Fan-out** → [examples/layer2/061-fan_out.zig](../examples/layer2/061-fan_out.zig)
62. **Shutdown via ShutdownCommand** → [examples/layer2/062-shutdown_exit.zig](../examples/layer2/062-shutdown_exit.zig)

---

## Layer 3 — Lifecycle (Pool)

89. **Basic recycler** → [examples/layer3/089-basic_recycler.zig](../examples/layer3/089-basic_recycler.zig)
90. **Backpressure pool** → [examples/layer3/090-capped_pool.zig](../examples/layer3/090-capped_pool.zig)
91. **Pool seeding** → [examples/layer3/091-pool_seeding.zig](../examples/layer3/091-pool_seeding.zig)
92. **Pool teardown** → [examples/layer3/092-pool_teardown.zig](../examples/layer3/092-pool_teardown.zig)

---

## Layer 4 — Infra as Items

Infra handles (MailboxHandle, PoolHandle) are PolyNodes and can be transported as items.  
Tag dispatch confirms class. Pointer comparison identifies instance. Role is established by protocol.

95. **Worker finish signal via mailbox return** → [examples/layer4/095-mailbox_as_item.zig](../examples/layer4/095-mailbox_as_item.zig)
96. **Pool holds pools at teardown** → [examples/layer4/096-pool_as_item.zig](../examples/layer4/096-pool_as_item.zig)

---

## Cross-Layer Notes

- All examples are single-threaded or use `std.Thread.spawn` — no `io.concurrent()`
- Each example has a test wrapper that calls the example and verifies it works
- Examples demonstrate working API — they cannot be written until tests prove the API
- Examples become docs — verified examples are pulled into documentation
