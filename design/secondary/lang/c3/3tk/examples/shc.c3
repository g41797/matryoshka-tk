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

 The catalog groups patterns by theme: Slot and transfer idioms, crossing
 the border, dispatch, the infrastructure as an outer, mailbox patterns,
 topology patterns, pool patterns, shutdown, and coordinator patterns.

 Read a pattern's own file for what it shows. This module holds no code of
 its own.
*>
module shc;
