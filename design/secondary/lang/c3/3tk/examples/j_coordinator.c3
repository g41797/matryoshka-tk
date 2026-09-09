<*
 Coordinator patterns — catalog entries 49 through 53.

 These carry the "Two levels" rule: a coordinator sequences steps and owns the
 resources, a step does one thing and owns nothing. They are the longest
 examples in the tree, and the ones closest to a real program's shape.

 - `049-the_coordinator.c3` — the structure that sequences the steps.
 - `050-the_step.c3` — one step, doing one thing.
 - `051-acquiring_the_resources.c3` — the mailbox and pool a run needs.
 - `052-releasing_the_resources.c3` — giving them back, in order.
 - `053-the_thread_is_given_one_pointer.c3` — a worker reaches everything
   through its context.

 Entries 54, 55 and 56 — spawn and join in one step, more than one
 coordinator, and pool and mailbox together — have no code shape of their own.

 This module holds no code of its own.
*>
module shc::j_coordinator;
