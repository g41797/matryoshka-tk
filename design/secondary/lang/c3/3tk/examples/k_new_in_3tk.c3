<*
 New, and 3tk-only — catalog entries 57 through 62.

 Shapes with no entry behind them in the port 3tk came from. They exist
 because of what C3 makes cheap: compile-time reflection, a type's own
 `typeid`, and a build that can drop its checks.

 - `057-the_allocator_in_the_outer.c3` — an outer that reaches its own.
 - `058-an_identity_costs_no_registration.c3` — a new type needs no ceremony.
 - `059-the_optional_declaration_walk.c3` — walking a queue with `while`.
 - `060-guarding_an_expensive_check.c3` — a check a fast build drops.
 - `061-a_composite_outer_gives_back_its_parts.c3` — an outer of outers.

 Entry 62, what a fast build stops checking, is prose about the builds and has
 no code shape. Entry 42 is 3tk-only too and sits with the pool patterns,
 which is where it is read.

 This module holds no code of its own.
*>
module shc::k_new_in_3tk;
