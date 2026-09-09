<*
 Cleanup idioms — catalog entries 5 through 10.

 An outer is always somewhere: with you, in a Slot, on a queue, or inside a
 tool. These examples are how you make sure it is freed exactly once on every
 path out of a function, including the paths a fault takes.

 - `005-null_safe_cleanup.c3` — a cleanup that is safe on an empty Slot.
 - `006-defer_put_early.c3` — the defer is written before the outer is used.
 - `007-defer_release_early.c3` — the same shape, freeing rather than putting.
 - `008-defer_for_received_outer.c3` — the receiver owns what it receives.
 - `009-refused_put_fallback.c3` — a refused transfer leaves the outer with you.
 - `010-no_raw_allocator_call.c3` — an outer is freed through the helper.

 The catalog files these under "Slot and transfer idioms". They are their own
 group here because they are their own subject: the Slot mechanics they build
 on are in `shc::a_slot_and_transfer`.

 This module holds no code of its own.
*>
module shc::b_cleanup;
