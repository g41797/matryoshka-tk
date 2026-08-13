# Matryoshka Zig — Give-back Audit Recipe (001)

How to audit a layer for items the toolkit hands back and nobody catches.

Written after MBOX 1 (2026-08-12), which did this by hand for the mailbox.  
INTR 7 did it for the pool a month earlier, from scratch, and the two stages  
shared no method. This doc is so the third one does not start over.

Tool: `kitchen/tools/audit_edges.sh` — the mechanical inventory.  
Rules it enforces: [rules-046.md](rules-046.md) Part 8.

---

## What a give-back edge is

Any call where the toolkit may end up handing the item back to the caller  
instead of taking it.

| edge | what comes back |
|------|-----------------|
| `send`, `send_oob` returning `error.Closed` | the item — the slot is unchanged |
| `close` on a mailbox | every queued item, as a list |
| `receive_batch` | the whole queue, as a list |
| `put` on a closed pool | the item — the slot is unchanged |
| `put_all` | everything after the first refusal, left in the list |
| `Pool.close` | nothing to the caller — it goes to `on_close` |

The last row is the one that catches people. Pool and mailbox differ here,  
and a doc page had it backwards for over a month.

An edge is not a defect. An edge with no release around it is.

---

## The four verdicts

Every site gets exactly one.

- **COVERED** — a `defer`/`errdefer` in the enclosing function names the slot.
- **CATCH-FREES** — the `catch` body releases the item.
- **DISCARDED** — a returned list dropped with `_ =`. Always wrong.
- **BARE** — none of the above. Read it.

There is no fifth verdict. In particular there is no "provably fine today":  
MBOX 1 first graded 32 `_ = mbx.close()` sites that way, and the owner  
rejected the category outright. The reasoning behind it is the problem — the  
release costs nothing when there is nothing to release, so a site that  
reasons about whether the container is empty has encoded an assumption a  
later edit can break in silence. If a release is free, run it unconditionally  
and stop thinking about it.

---

## Order of work

1. **Inventory, read-only.** Run the script. Change nothing yet.
2. **Classify.** Read every BARE and DISCARDED site. The script cannot do
   this part and does not pretend to.
3. **Report.** Take the findings to the owner before editing. MBOX 1 caught
   its own wrong grading here, at a cost of nothing.
4. **Fix**, one file at a time, running `build_and_test_debug.sh` after each,
   as INTR 7 did.
5. **Write the framing down.** Both audits ended with a sentence the docs had
   been missing — "Pool is not storage", "the mailbox holds, it never  
   touches". Put it in `src/` doc comments *and* the pages. INTR 7 put its  
   sentence in three docs and not in `src/pool.zig`, where the contradicting  
   word sat untouched for a month.

---

## What the script cannot tell you

It reads text, not syntax.

- It over-reports BARE by design. A multi-line `catch { ... }` that frees
  the item still lands there. Over-reporting sends a human to read; under-  
  reporting hides a defect.
- It cannot know what a release *is* for a given item. Free it, or put it
  back into a pool, or nothing at all if it lives in the caller's frame —  
  that is the caller's knowledge, which is the whole point of the rule.
- It cannot see whether a container is reachable in the state you care about.

A clean table is not proof of a clean codebase. It is proof that the obvious  
shapes are absent.

---

## Baseline, 2026-08-12, after MBOX 1

Diff against this rather than reading all of it cold.

| scan | count |
|------|-------|
| DISCARDED | 0 |
| BARE | 90 |
| CATCH-FREES | 6 |
| COVERED | 102 |
| documented asserts with no assert in `src/` | 0 |

Of the 90 BARE, 69 are bare `pl.put(&slot)` statements. Those are real  
give-back edges and they are not audited — INTR 7 predates this framing. They  
are the material for a pool re-audit, not noise to filter out.

A rise in DISCARDED, or any unmatched assert, is a regression. Both were  
non-zero before MBOX 1 and are enforced by rules now, so either going  
non-zero again means a rule was not read.

---

## Not yet audited

`polynode` — `PolyHelper`, `ItemHandle`, `Slot`, `ItemList`, the  
`@fieldParentPtr` boundary, `moveFromSlot`/`appendFromSlot`. Never had this  
treatment, and it is the layer the other two stand on.
