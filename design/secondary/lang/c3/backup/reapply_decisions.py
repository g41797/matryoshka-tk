# Re-applies 3TK-63's three intended edits to matryoshka-3tk/design/3tk-decisions-007.md
# AFTER the owner restores it. No line renumbering: that is left as recorded debt.
import sys
p='/home/g41797/dev/root/github.com/g41797/matryoshka-3tk/design/3tk-decisions-007.md'
t=open(p).read()

old = """### Files and modules — 3TK-62, 3TK-63

**BUILT by 3TK-62, 2026-09-07.** `RT-4` — the stack is private and the pool is
what cares — is no longer ahead of the source. Its entry is now in the body,
under *The stack, at the end of `pool.c3`*, with real `file:line`.

- **`inner.c3` absorbs the old `helper.c3` content** — `Inner`, `Slot`, the link
  and Slot operations and the crossing macros in one file. `RT-2`.
  **SUPERSEDED in its module name:** the file declares **`module mtk;`**, not
  `mtk::inner` — the second sitting merged eight module names into four
  (Boundaries `Part 4.2`). The split was a seam the user should not have to see, and the two
  module blocks stated the same paragraph twice.
- **`helper.c3` survives and is refilled by `OuterHelper`.** `RT-3`.
  **SUPERSEDED in its module name:** the file declares **`module mtk <Outer>;`**
  — the same name in its generic form, which C3 permits (Boundaries `A.6`), not
  `mtk::helper`.
"""
new = """### Files and modules — 3TK-64

**BUILT by 3TK-62, 2026-09-07.** `RT-4` — the stack is private and the pool is
what cares — is no longer ahead of the source. Its entry is now in the body,
under *The stack, at the end of `pool.c3`*, with real `file:line`.

**BUILT by 3TK-63, 2026-09-07.** `RT-2` — `inner.c3` absorbs the old
`helper.c3` content, and the module is `mtk` — is no longer ahead of the source.
`inner.c3` declares `module mtk;`, holds `Inner`, `Slot`, the link and Slot
operations and the crossing macros, and `inner_offset` is `@private` to that
module.

**The `file:line` in the `inner.c3`, `helper.c3` and `queue.c3` sections below
are pre-3TK-63 and have not been re-anchored.** Every line in those three files
moved, `helper.c3` is empty, and the whole of the old `mtk::inner`,
`mtk::helper` and `mtk::queue` module blocks is now one block in `mtk.c3`. The
*claims* in those sections are still true of the source; only the coordinates
are stale. **3TK-66 re-anchors them when it rewrites the books.**

- **`helper.c3` survives and is refilled by `OuterHelper`.** `RT-3`.
  **SUPERSEDED in its module name:** the file declares **`module mtk <Outer>;`**
  — the same name in its generic form, which C3 permits (Boundaries `A.6`), not
  `mtk::helper`. **Half built by 3TK-63:** the file is emptied and kept, with a
  `//` banner saying what refills it. 3TK-64 refills it.
"""
assert t.count(old)==1, 'block 1 not found — file may not be restored'
t=t.replace(old,new)

old2 = """  **`required_alloc_offset` is deleted outright** (3TK-63), and with it the
  negative program that asserted an Outer without an `Allocator` field fails to
  compile."""
new2 = """  **`required_alloc_offset` leaves the core**, and with it the negative program
  that asserted an Outer without an `Allocator` field fails to compile.
  **CORRECTED by 3TK-63, 2026-09-07:** plan 026 dated the deletion to that
  stage, on the reasoning that the macro has no caller once `managed.c3` goes —
  but `managed.c3` goes in **3TK-64**, and until then it has two. 3TK-63
  **moved** the macro into `managed.c3` and made it `@local`; 3TK-64 deletes the
  file and the macro with it."""
assert t.count(old2)==1, 'block 2 not found'
t=t.replace(old2,new2)

old3 = """- **`helper.c3` is not a wall.** `mtk::inner_offset` is public, so any module
  importing `mtk` can compute an offset and cast. `H0` neither creates nor
  fixes that. `../3tk/src/inner.c3:165`."""
new3 = """- **REVERSED by 3TK-63, 2026-09-07 — the border is now a wall, as far as C3
  will make one.** This entry read *"`helper.c3` is not a wall: `mtk::inner_offset`
  is public, so any module importing `mtk` can compute an offset and cast."*
  Since the merge, `inner_offset` is **`@private` to `module mtk`** and a
  foreign module calling it does not compile. Probed, not assumed. What is still
  open is `Inner.link` itself, which is a public field: the door is narrower,
  not shut, and the books say so plainly rather than claiming a lock. `H0` still
  neither creates nor fixes that."""
assert t.count(old3)==1, 'block 3 not found'
t=t.replace(old3,new3)
open(p,'w').write(t)
print('re-applied')
