# Task 2 — Example Scenarios for Layer 4 and Cross-Layer (007)


Change from -006: API 12-4 — the doc speaks the pointer API. Methods on  
`*Mbox` / `*Pool`; `new`, `destroy`, `receiveResult`, `getWaitResult` stay  
free functions on the module.



Change from 005: DISPATCH 2 — scenario 63 added, two Masters and two tables.

Change from 004: added scenarios 95 and 96. Both existed in `examples/layer4/`,  
in the barrel and in the site nav, but had never been listed in this catalog.

Change from 003: EXMPL 5 — added scenario 62, the receive router.

Index only. Full staccato description lives in each source file's `///` doc comment,  
per "Description as code" in [rules-043.md](rules-043.md).

Pool items are empty containers on acquisition. Work input comes from outside the pool item:  
a mailbox, a timer, a network source, spawn-time arguments, or the worker's own accumulated state.  
See "Pool items are empty containers" in [matryoshka-concepts-002.md](matryoshka-concepts-002.md).

All Layer 4 examples use real `Io.Threaded.init(gpa, .{})` — concurrency, cancellation, real I/O.

Master is a concept, not a type. Each example may structure its coordination boundary differently.

---

## Master Patterns

17. **Minimal Master** → [examples/layer4/017-minimal_master.zig](../examples/layer4/017-minimal_master.zig)
18. **Master with Pool** → [examples/layer4/018-master_with_pool.zig](../examples/layer4/018-master_with_pool.zig)
19. **Multi-worker Master** → [examples/layer4/019-multi_worker_master.zig](../examples/layer4/019-multi_worker_master.zig)
20. **Pipeline of Masters** → [examples/layer4/020-pipeline_masters.zig](../examples/layer4/020-pipeline_masters.zig)
21. **Request-response between Masters** → [examples/layer4/021-request_response.zig](../examples/layer4/021-request_response.zig)

---

## Mailbox as Multiplexer

22. **Timer via mailbox** → [examples/layer4/022-timer_via_mailbox.zig](../examples/layer4/022-timer_via_mailbox.zig)
23. **OOB via send_oob** → [examples/layer4/023-oob_signal.zig](../examples/layer4/023-oob_signal.zig)
24. **Multiple event sources, one mailbox** → [examples/layer4/024-multi_source_mailbox.zig](../examples/layer4/024-multi_source_mailbox.zig)

---

## Io Integration (timer + mailboxes)

25. **Two mailboxes + timer in Select** → [examples/layer4/025-select_two_mailboxes.zig](../examples/layer4/025-select_two_mailboxes.zig)
26. **Timer cancel → close → walk remaining** → [examples/layer4/026-select_cancel_close.zig](../examples/layer4/026-select_cancel_close.zig)
27. **Cancel reports, Master decides** → [examples/layer4/027-select_cancel_master_decides.zig](../examples/layer4/027-select_cancel_master_decides.zig)
28. **Multiple event source types in one Select** → [examples/layer4/028-select_mixed_sources.zig](../examples/layer4/028-select_mixed_sources.zig)
29. **Cancel → Master close → Pool.put_all** → [examples/layer4/029-select_cancel_recycle.zig](../examples/layer4/029-select_cancel_recycle.zig)
30. **Timeout on mailbox** → [examples/layer4/030-mailbox_timeout.zig](../examples/layer4/030-mailbox_timeout.zig)
31. **Graceful shutdown with in-flight items** → [examples/layer4/031-select_graceful_shutdown.zig](../examples/layer4/031-select_graceful_shutdown.zig)

---

## Cross-Layer Integration (Layers 1-3)

32. **Pool → Mailbox → Pool roundtrip** → [examples/layer4/032-cross_layer_pool_mailbox_roundtrip.zig](../examples/layer4/032-cross_layer_pool_mailbox_roundtrip.zig)
33. **Mixed types through shared mailbox** → [examples/layer4/033-cross_layer_mixed_types_mailbox.zig](../examples/layer4/033-cross_layer_mixed_types_mailbox.zig)
34. **Batch receive + pool return** → [examples/layer4/034-cross_layer_batch_receive_pool_return.zig](../examples/layer4/034-cross_layer_batch_receive_pool_return.zig)
35. **Pool hooks + mailbox flow** → [examples/layer4/035-cross_layer_pool_hooks_mailbox_flow.zig](../examples/layer4/035-cross_layer_pool_hooks_mailbox_flow.zig)
36. **Close ordering: pool then mailbox** → [examples/layer4/036-cross_layer_close_pool_then_mailbox.zig](../examples/layer4/036-cross_layer_close_pool_then_mailbox.zig)
37. **Close ordering: mailbox then pool** → [examples/layer4/037-cross_layer_close_mailbox_then_pool.zig](../examples/layer4/037-cross_layer_close_mailbox_then_pool.zig)
38. **Pool + Mailbox flow** → [examples/layer4/038-cross_layer_pool_mailbox_flow.zig](../examples/layer4/038-cross_layer_pool_mailbox_flow.zig)

---

## stdlib Compatibility (Master-level)

39. **Master shutdown: close → stdlib walk → free** → [examples/layer4/039-master_shutdown_stdlib_cleanup.zig](../examples/layer4/039-master_shutdown_stdlib_cleanup.zig)
40. **Master batch collect: receive_batch → put_all** → [examples/layer4/040-master_batch_collect_receive_to_pool.zig](../examples/layer4/040-master_batch_collect_receive_to_pool.zig)
41. **Master pre-shutdown collect** → [examples/layer4/041-master_multi_mailbox_collect.zig](../examples/layer4/041-master_multi_mailbox_collect.zig)

---

## Mailbox as Select Event Source (Master + external Io)

42. **Mailbox receive as Select event source** → [examples/layer4/042-select_mailbox_event.zig](../examples/layer4/042-select_mailbox_event.zig)
43. **Select direct queue push** → [examples/layer4/043-select_direct_push.zig](../examples/layer4/043-select_direct_push.zig)
44. **Select mailbox close propagation** → [examples/layer4/044-select_mailbox_close.zig](../examples/layer4/044-select_mailbox_close.zig)
45. **Select cancel propagation** → [examples/layer4/045-select_mailbox_cancel.zig](../examples/layer4/045-select_mailbox_cancel.zig)
62. **Receive router — one registration, many events** → [examples/layer4/062-receive_router.zig](../examples/layer4/062-receive_router.zig)
63. **Two Masters, the same items, two different tables** → [examples/layer4/063-table_dispatch_masters.zig](../examples/layer4/063-table_dispatch_masters.zig)

---

## Pool as Select Event Source

46. **Pool get_wait as Select event source** → [examples/layer4/046-select_pool_event.zig](../examples/layer4/046-select_pool_event.zig)
47. **Job pool pattern** → [examples/layer4/047-select_job_pool.zig](../examples/layer4/047-select_job_pool.zig)
48. **Mixed mailbox + pool event sources in Select** → [examples/layer4/048-select_mailbox_pool_timer.zig](../examples/layer4/048-select_mailbox_pool_timer.zig)

---

## Event Source Futures

49. **receive_future awaited directly** → [examples/layer4/049-receive_future_direct.zig](../examples/layer4/049-receive_future_direct.zig)
50. **get_wait_future awaited directly** → [examples/layer4/050-get_wait_future_direct.zig](../examples/layer4/050-get_wait_future_direct.zig)
51. **receive_future with timeout** → [examples/layer4/051-receive_future_timeout.zig](../examples/layer4/051-receive_future_timeout.zig)
52. **ConcurrencyUnavailable on single-threaded** → [examples/layer4/052-future_single_threaded.zig](../examples/layer4/052-future_single_threaded.zig)

---

## Communication Patterns

53. **Pool fan-in: many workers return** → [examples/layer4/053-pool_fan_in.zig](../examples/layer4/053-pool_fan_in.zig)
54. **Pool fan-out: many workers acquire** → [examples/layer4/054-pool_fan_out.zig](../examples/layer4/054-pool_fan_out.zig)
55. **Producer → consumer with recycling** → [examples/layer4/055-producer_consumer_recycle.zig](../examples/layer4/055-producer_consumer_recycle.zig)
56. **Job pool circular flow** → [examples/layer4/056-job_pool_circular.zig](../examples/layer4/056-job_pool_circular.zig)
95. **Worker finish signal via mailbox return** → [examples/layer4/095-mailbox_as_item.zig](../examples/layer4/095-mailbox_as_item.zig)
96. **Pool holds pools at teardown** → [examples/layer4/096-pool_as_item.zig](../examples/layer4/096-pool_as_item.zig)

---

## Mailbox-less Patterns

57. **Pool + Future: simple worker** → [examples/layer4/057-mailbox_less_pool_future_worker.zig](../examples/layer4/057-mailbox_less_pool_future_worker.zig)
58. **Pool + Select: job scheduler** → [examples/layer4/058-mailbox_less_pool_select_scheduler.zig](../examples/layer4/058-mailbox_less_pool_select_scheduler.zig)
59. **Pool + Group: worker pool** → [examples/layer4/059-mailbox_less_pool_group_workers.zig](../examples/layer4/059-mailbox_less_pool_group_workers.zig)
60. **Pool + Select + Network** → [examples/layer4/060-mailbox_less_pool_select_network.zig](../examples/layer4/060-mailbox_less_pool_select_network.zig)
61. **When to add Mailbox** → [examples/layer4/061-mailbox_less_to_mailbox_transition.zig](../examples/layer4/061-mailbox_less_to_mailbox_transition.zig)

---

## Reference

- ICE agent pattern: `/home/g41797/Downloads/media-protocols-master/src/ice/agent.zig`
- Io as an Interface: https://ziglang.org/download/0.16.0/release-notes.html#IO-as-an-Interface
- std.Io overview: https://ziggit.dev/t/std-io-overview/
- Discussion about Io and Zig: https://ziggit.dev/t/discussion-about-io-and-zig/
