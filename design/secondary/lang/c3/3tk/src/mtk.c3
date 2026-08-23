<*
 Matryoshka, the C3 port — the toolkit.

 There is no front-door file to write. In C3 the module IS the front door:
 `import mtk` brings in everything `module mtk` declares, across every file
 that declares it. This file therefore carries the port's identity and its
 reading order, and nothing else.

 The proposal's section 1 listed `mtk.c3` as a re-exporting front door. C3
 needs no re-export. Recorded in 3tk-toolkit-notes-001.md.

 The files, and the modules they declare:

   any.c3      module mtk            AnyNode, AnyHandle, Slot, the faults, @check
   list.c3     module mtk            NodeList and its walker
   helper.c3   module mtk::helper    <Type> — the border, Part 7.5
   owned.c3    module mtk::owned     <Type> — helper plus create and release
   mailbox.c3  module mtk::mailbox   Mailbox. Part 11.3 to 11.6
   pool.c3     module mtk::pool      Pool, PoolHooks. Part 11.7 to 11.10, Part 12

 The first four are the toolkit of Part 17.1 — the one required tool, and the
 thing without which there is nothing to port. The last two are the optional
 tools of Part 17.2.

 **The containers are submodules on purpose.** A C3 submodule cannot see its
 parent's `@private` declarations, so `mtk::mailbox` and `mtk::pool` are
 structurally outside `mtk`.

 What that proves, exactly: the core's explicit private boundary is enforced by
 the compiler, not by the authors' discipline. What it does not prove: D1 chose
 public structs with public fields, so coupling to the core's PUBLIC surface
 stays possible and stays visible in the source. That half is held by the Part
 17.2 layering rule and the check `run-builds.sh` runs for it.

 Specification: matryoshka-specification-001.md.
 Design rulings: 3tk-porting-proposal-001.md, D1 to D16.
*>
module mtk;

const String VERSION = "0.1.0";
