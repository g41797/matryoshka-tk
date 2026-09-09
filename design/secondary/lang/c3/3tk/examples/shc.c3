<*
 A pattern catalog for `mtk`, not part of the library itself.

 Every file here is real C3, compiled by the ordinary build — no `@test`,
 no `assert`, nothing from the test surface. One file, one pattern, named
 `NNN-name.c3`. The number correlates the file with its row in the pattern
 catalog.

 - `shc::outers` declares the demo outers shared by every example.
 - `shc::helpers` gives the one check an example is allowed to make,
   `shc::helpers::expect`.
 - Every other file is one pattern, with one public function taking an
   `Allocator` and reporting by returning, never by aborting.

 A pattern belongs to a group, and a group is a submodule of its own with a
 file of its own — `<group>.c3`, which describes the group and declares
 nothing. A pattern's module is `shc::<group>::<name>`. The eleven groups, in
 the order to read them:

 - `shc::a_slot_and_transfer` — the Slot, and what a transfer does to it.
 - `shc::b_cleanup` — freeing exactly once, on every path out.
 - `shc::c_crossing` — giving up a type and recovering it.
 - `shc::d_dispatch` — from an identity to the code that handles it.
 - `shc::e_infrastructure` — a mailbox and a pool are outers too.
 - `shc::f_mailbox` — one endpoint, and the calls made on it.
 - `shc::g_topology` — several endpoints, arranged.
 - `shc::h_pool` — keeping outers and handing them back.
 - `shc::i_shutdown` — the four ways a wait ends.
 - `shc::j_coordinator` — the two levels, and who owns what.
 - `shc::k_new_in_3tk` — the shapes C3 made cheap.

 A group segment is prefixed `a_` … `k_` because it orders the groups on the
 generated page and a module segment cannot start with a digit. The number
 stays in the filename, where it names the catalog row.

 Read a pattern's own file for what it shows. This module holds no code of
 its own.
*>
module shc;
