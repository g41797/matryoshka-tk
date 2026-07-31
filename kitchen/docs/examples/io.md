# How to... Io — Select, Group, Future

Event loops over multiple sources, cancellation, and awaiting futures  
directly instead of through a mailbox.

- [Two mailboxes + timer in Select](layer4/025-select_two_mailboxes.md)
- [Timer cancel → close → walk remaining](layer4/026-select_cancel_close.md)
- [Cancel reports, Master decides](layer4/027-select_cancel_master_decides.md)
- [Multiple event source types in one Select](layer4/028-select_mixed_sources.md)
- [Cancel → Master close → pool.put_all](layer4/029-select_cancel_recycle.md)
- [Graceful shutdown with in-flight items](layer4/031-select_graceful_shutdown.md)
- [Mailbox receive as Select event source](layer4/042-select_mailbox_event.md)
- [Select direct queue push](layer4/043-select_direct_push.md)
- [Receive router — one registration, many events](layer4/062-receive_router.md)
- [Two Masters, the same items, two different tables](layer4/063-table_dispatch_masters.md)
- [Select mailbox close propagation](layer4/044-select_mailbox_close.md)
- [Select cancel propagation](layer4/045-select_mailbox_cancel.md)
- [Pool get_wait as Select event source](layer4/046-select_pool_event.md)
- [Job pool pattern](layer4/047-select_job_pool.md)
- [Mixed mailbox + pool event sources in Select](layer4/048-select_mailbox_pool_timer.md)
- [receive_future awaited directly](layer4/049-receive_future_direct.md)
- [get_wait_future awaited directly](layer4/050-get_wait_future_direct.md)
- [receive_future with timeout](layer4/051-receive_future_timeout.md)
- [ConcurrencyUnavailable on single-threaded](layer4/052-future_single_threaded.md)
- [Pool + Future: simple worker](layer4/057-mailbox_less_pool_future_worker.md)
- [Pool + Select: job scheduler](layer4/058-mailbox_less_pool_select_scheduler.md)
- [Pool + Group: worker pool](layer4/059-mailbox_less_pool_group_workers.md)
- [Pool + Select + Network](layer4/060-mailbox_less_pool_select_network.md)
- [When to add Mailbox](layer4/061-mailbox_less_to_mailbox_transition.md)
