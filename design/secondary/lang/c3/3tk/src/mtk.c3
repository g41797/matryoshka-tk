<*
 Matryoshka, the C3 port — the toolkit.

 There is no front-door file to write. In C3 the module IS the front door:
 `import mtk` brings in everything `module mtk` declares, across every file
 that declares it. This file therefore carries the port's identity and its
 reading order, and nothing else.

 The proposal's section 1 listed `mtk.c3` as a re-exporting front door. C3
 needs no re-export. Recorded in 3tk-toolkit-notes-001.md.

 The files, and the modules they declare:

   inner.c3    module mtk            Inner, Handle, Slot, is_linked, reset,
                                     the faults, @check
   queue.c3    module mtk            InnerQueue and its walker. First-in first-out
   stack.c3    module mtk            InnerStack. Last-in first-out
   helper.c3   module mtk::helper    macros over $Type — the border, Part 7.5
   managed.c3  module mtk::managed   helper plus create and release
   mailbox.c3  module mtk::mailbox   Mailbox. Part 11.3 to 11.6
   pool.c3     module mtk::pool      Pool, PoolHooks. Part 11.7 to 11.10, Part 12

 The first five are the toolkit of Part 17.1 — the one required tool, and the
 thing without which there is nothing to port. The last two are the optional
 tools of Part 17.2.

 **The vocabulary is Outer and Inner — R1.** The application's struct is the
 outer; the structure it embeds is the `Inner`. `Outer` is a category and never
 a type: no such type is declared anywhere here. The `Any` prefix the port
 inherited from ztk is gone, and so is `NodeList` — R2 refused a
 general-purpose list, and the port keeps two ordering primitives instead, a
 queue for the mailbox and a stack for the pool.

 **The containers are submodules, and the reason is enforcement.** A C3
 submodule cannot see its parent's `@private` declarations, so `mtk::mailbox`
 and `mtk::pool` are structurally outside `mtk`.

 What that proves, exactly: the core's explicit private boundary is enforced by
 the compiler, not by the authors' discipline. What it does not prove: D1 chose
 public structs with public fields, so coupling to the core's PUBLIC surface
 stays possible and stays visible in the source. That half is held by the Part
 17.2 layering rule and the check `run-builds.sh` runs for it.

 **Neither helper module is generic — H0 and H0b.** Their members are macros
 over `$Type` and the code is generated per call site. No application writes
 an alias or an instantiation for any type, anywhere.

 Specification: ../common/matryoshka-specification-003.md. Part 7.1 is a known
 SPECIFICATION defect against this port's shape — 3tk-deviations-001.md V19,
 reworded by 3TK-17.
 Design rulings: 3tk-porting-proposal-004.md, D1 to D16;
 3tk-core-redesign-proposal-002.md, R1 to R15; and 3tk-helper-proposal-001.md,
 H0, H0b, H5, H6, H7, H8, H9, H10.
*>
module mtk;

const String VERSION = "0.2.0";
