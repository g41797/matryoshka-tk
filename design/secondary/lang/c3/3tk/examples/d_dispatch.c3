<*
 Dispatch — catalog entries 17 through 20.

 An outer arrives with its identity and nothing else. These four shapes are
 the ways to get from that identity to the code that handles it, in rising
 order of how many identities they are worth writing for.

 - `017-dispatch_outer_first.c3` — cross first, branch on the typed pointer.
 - `018-dispatch_identity_first.c3` — branch on the identity, cross inside.
 - `019-dispatch_switch.c3` — a switch over identities.
 - `020-dispatch_table.c3` — a table of handlers, looked up by identity.

 Entries 21 and 22 — the last branch of a chain, and an identity naming a
 type rather than an instance — are rules with no code shape of their own.

 This module holds no code of its own.
*>
module shc::d_dispatch;
