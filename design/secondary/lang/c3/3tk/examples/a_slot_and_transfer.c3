<*
 Slot and transfer idioms — catalog entries 1 through 4.

 The `Slot` is how an outer is handed over, and these three examples are the
 mechanics every later group builds on: a Slot starts empty, a transfer leaves
 it empty, and a Slot is what an insert reads from.

 - `001-empty_slot.c3` — a Slot needs no initializer.
 - `003-transfer_empties_slot.c3` — the Slot says where the outer went.
 - `004-insert_from_slot.c3` — putting an outer on a queue.

 Entry 2, "The Slot is never overwritten", is a rule with no code shape of its
 own and has no file. The cleanup idioms that the catalog files under this
 section are their own group, `shc::b_cleanup`.

 This module holds no code of its own.
*>
module shc::a_slot_and_transfer;
