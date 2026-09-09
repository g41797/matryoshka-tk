<*
 Pool patterns — catalog entries 37 through 45.

 The pool keeps outers you are finished with and hands them back. It holds no
 policy of its own: what happens when nothing is kept is the caller's choice
 of mode and the hook object's answer.

 - `037-available_or_new.c3` — reuse if you can, otherwise ask the hook.
 - `038-new_only.c3` — always ask the hook.
 - `039-available_only.c3` — never ask the hook.
 - `040-seeding_a_fixed_size_pool.c3` — a hook that stops creating.
 - `042-the_hook_object_is_the_context.c3` — the hook carries its own state.
 - `045-a_pool_of_several_identities.c3` — one pool, one free list per type.

 Entries 41, 43 and 44 — the pool holds no policy, a hook runs outside the
 lock, and the `on_close` hook — are rules with no code shape of their own.

 This module holds no code of its own.
*>
module shc::h_pool;
