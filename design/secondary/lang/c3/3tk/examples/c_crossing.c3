<*
 Crossing the border — catalog entries 11 through 16.

 The border is between the `Inner` the toolkit holds and the outer you own.
 These examples are how a type is given up on the way in and recovered on the
 way out.

 - `011-embedding_the_inner.c3` — the field that makes a struct an outer.
 - `012-type_crossing.c3` — the three spellings of a crossing, side by side.
 - `013-recovering_the_type.c3` — checked and asserted, and what each costs.
 - `015-walk_a_batch.c3` — reading a queue without consuming it.
 - `016-reach_into_a_full_slot.c3` — looking without taking.

 Entry 14, "Stack outers are illegal", is a prohibition with no code shape.
 It is why every outer in this tree is allocated.

 `012` and `013` are the two examples allowed to name a crossing below the
 helper; every other example in the tree goes through `OuterHelper`.

 This module holds no code of its own.
*>
module shc::c_crossing;
