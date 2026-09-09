<*
 Shutdown — catalog entries 46 through 48.

 3tk has no cancellation. A wait ends on an outer, a close, a wake, or the
 timeout, and nothing else — so shutting down is reading which of those
 happened and freeing what close gives back.

 - `046-reading_the_fault_on_a_receive.c3` — the four outcomes of a wait.

 Entries 47 and 48 — the shutdown order, and shutdown by message — are a
 numbered order and a diagram, with no code shape of their own.

 This module holds no code of its own.
*>
module shc::i_shutdown;
