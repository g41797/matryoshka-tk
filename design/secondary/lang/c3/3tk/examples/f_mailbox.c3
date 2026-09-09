<*
 Mailbox patterns — catalog entries 27 through 32.

 One endpoint, and the calls a single participant makes on it. The shapes
 that compose several endpoints are in `shc::g_topology`.

 - `027-poll.c3` — a work loop that must not block.
 - `028-receive_all.c3` — draining everything in one call.
 - `029-out_of_band.c3` — a message that overtakes the queue.
 - `030-close_recovery.c3` — what close gives back, and who frees it.
 - `031-release_a_refused_transfer.c3` — a refused send keeps the outer.
 - `032-wake_without_a_message.c3` — ending a wait with nothing to deliver.

 This module holds no code of its own.
*>
module shc::f_mailbox;
