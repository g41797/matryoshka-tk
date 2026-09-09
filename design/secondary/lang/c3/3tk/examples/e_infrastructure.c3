<*
 The infrastructure is an outer too — catalog entries 23 through 26.

 A mailbox is an outer and a pool is an outer: each embeds an inner and
 carries an identity, so either can be sent through a mailbox or kept on a
 queue like anything else you own.

 - `023-infrastructure_wrapper.c3` — when the endpoint alone is not enough.
 - `024-mailbox_as_message.c3` — sending a mailbox through a mailbox.
 - `025-worker_finish_signal.c3` — the outer that says a worker is done.
 - `026-pool_as_message.c3` — sending a pool the same way.

 This module holds no code of its own.
*>
module shc::e_infrastructure;
