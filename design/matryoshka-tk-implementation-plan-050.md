# Matryoshka Zig — Implementation Plan (050)

Replaces [matryoshka-tk-implementation-plan-049.md](matryoshka-tk-implementation-plan-049.md).

## Status

API 8 complete — 8a, 8b, 8c, 8d. API 9 "intrusive safety" complete.  
177/177 tests.

`ItemList` closed the `std.DoublyLinkedList` boundary. `@fieldParentPtr` is  
gone from `examples/`, `stories/`, and every test except the raw-link  
scenarios that exist to test the layout.

API 7e is closed as superseded — `ItemList.append` takes an `ItemHandle`, so  
the sites `toListNode` targeted no longer exist.

---

## Completed stages (summary)

- Stage 0–8: API, tests, examples layers 1–3 done.
- Stage 9 (Layer 4 infrastructure): pool, mailbox, select, group done.
- EXMPL 3a–4c, API 2–4b, DOC 9–20, INTR 6: see plan-040 for full detail.
- DOC 21: "The Shape of a Real System" page + Graphviz diagram tooling.
- INTR 7: pool `on_put` reset convention, "Pool is not storage" doc fix,
  put-semantics documented, 5 wrong-assumption bugs fixed.
- Staccato scan + "thread" audit: prose-paragraph and stale thread-join
  language fixed repo-wide.
- New Mindset (banned words, Phase A/B/C, code migration `Thread.spawn` →
  `io.concurrent()`, architecture-docs terminology pass): DONE.
- LANDING 1: src/ LOC counter + badge on `kitchen/docs/index.md`.
- REBRAND: repo rename to matryoshka-tk, deferred-item verification. DONE.
  Deferred editorial/conceptual prose pass remains owner's call.
- API 5a–5d + follow-up: Composite Items — `PoolHooks.on_put` returns
  `?std.DoublyLinkedList`; scenario 89; docs to api-reference-026;  
  `popFirst` stale-link bug found and fixed. DONE (168/168 tests).
- MDFIX: markdown hard-break rule + `kitchen/tools/fix_md_hardbreaks.sh`.
  DONE — rule lives in rules-026, script connected to `build_site.sh` and  
  `preview_site.sh`.
- EXMPL 5a–5e: receive router — design note, example + test, pattern docs,
  catalog and nav, cancelDiscard audit (15 sites, no defects). DONE  
  (169/169 tests). Agreed design: [receive-router-001.md](receive-router-001.md).
- API 6: `identifyNodeAs`/`identifySlotAs` → `fromNode`/`fromSlot` (+ `must`
  variants), hard rename, no aliases, ~222 call sites. New `moveFromSlot`  
  takes the item out and empties the Slot. Scenario 98 pins the contract.  
  Docs to api-reference-027, patterns-017, rules-027. DONE (170/170 tests).
- API 7: `PolyHelper` had five inbound accessors and none outbound, so every
  stack item reached into `.poly` by hand and `src/` hand-rolled the missing  
  accessor three times. New `toNode(self: *T) *PolyNode` — pure inspection,  
  cannot fail, no `must` variant. `Slot` is `?*PolyNode`, so `toNode` coerces  
  into a Slot and no `toSlot` is needed. Scenario 99 pins the contract,  
  ~55 call sites migrated, `021-define_type.zig` no longer round-trips a  
  statically-typed item. Docs to api-reference-028, patterns-018. 7d fixed  
  `src/polynode.zig`'s doc comments: three `//!` header typos that shipped  
  into autodocs, and the `PolyNode` comment now names both vocabularies —  
  Mailbox and Pool carry `ItemHandle` and do not look inside, `PolyHelper`  
  takes `*PolyNode` and is where the node is opened.  
  DONE (171/171 tests).
- API 8: `ItemList` — the toolkit's list type, completing the
  `ItemHandle`/`Slot`/`ItemList` trio. Five public signatures moved off  
  `std.DoublyLinkedList`: `mailbox.receive_batch`, `mailbox.close`,  
  `pool.put_all`, `PoolHooks.on_put`, `PoolHooks.on_close`. `popFirst` yields  
  an `ItemHandle` and calls `polynode.reset`, so the documented reset trap  
  became a type guarantee. `_concat` deleted in favour of `ItemList.concat`  
  forwarding to `std`'s `concatByMoving`. 8a design doc (25 questions,  
  answered), 8b type + scenarios 100-103, 8c one atomic migration across  
  `src/`, `examples/`, `tests/`, `stories/`, 8d docs to api-reference-029,  
  patterns-019, rules-029, task1-tests-002. DONE (175/175 tests).  
  Agreed design: [item-list-006.md](item-list-006.md).

Rejected during API 7d, owner's decision. Recorded so they are not re-proposed.

- `fromNode`/`toNode` taking `ItemHandle` instead of `*PolyNode`.
  Type-identical, so it would have been free at call sites, but  
  `node: ItemHandle` reads badly and no parameter name makes the function  
  name, the parameter, and the type agree. `ItemHandle` means opaque, and  
  layer 1 is the one place the node is opened, and that is what makes it  
  layer 1.
- `isIt` taking `ItemHandle`, with `X.poly.tag` call sites migrated to
  `Helper.toNode(&X).*.tag`. `isIt` must keep its tag parameter: 6 of its 13  
  callers have no item at all, including `items.createByTag`, which uses the  
  tag to decide what to create. Tags are user-facing currency — `pool.get`  
  and `pool.init` take bare tags at ~40 example sites. And `X.poly.tag` reads  
  better than the nested accessor call, so those 4 sites stay.

See `design/STATUS.md` Session Log for full per-stage detail — this plan file  
stays state-only per the slim-plan rule.

---

## API 7e — closed as superseded

`toListNode` on `PolyHelper` was recommended and never implemented. API 8a  
answered it (Q22): `ItemList.append` takes an `ItemHandle`, so the 5 genuine  
`list.append(&x.poly.node)` sites the accessor targeted are gone without it.

The 6 deliberate raw-link sites in `tests/layer1_polynode.zig` scenarios 6, 7,  
8 stay raw, unchanged. That layout is the thing under test.

Full reasoning: [item-list-006.md](item-list-006.md).

---

## Next

**Open — `ItemList` argument validation.** `std.DoublyLinkedList` validates  
nothing by design, so `ItemList` inherits four silent-corruption misuses by  
forwarding. Checking that found an older defect: `polynode.is_linked` returns  
false for a node that is a list's sole member, and six existing asserts rest on  
it — including `PolyHelper.destroy`, where the hole is a use-after-free guard  
that does not guard.

The proposed fix — a debug-only `bool` on `PolyNode` — was **withdrawn** in  
[item-list-003.md](item-list-003.md). The field is written under whichever mutex  
the item's current list sits behind, so in the buggy case it exists to catch,  
the field itself races. The argument applies unchanged to `prev`/`next`, so no  
state stored in an item can validate this class of mistake. Q26 is recommended  
D — nothing.

A **walk** of the list before inserting into it survives the argument,  
because it writes nothing  
and reads only the container's own chain plus an address it never dereferences.  
It closes two of the eight misuse cases — including `insertAfter` with a foreign  
`existing`, which only the rejected pointer field had covered. So the conclusion  
is narrower than 003 stated: detection needing a fact about an *item* is  
impossible; detection answerable from a *container's own contents* is not.

**Answered 2026-07-30 and shipped the same day** — Q26 D, Q27 A, Q28 yes,  
Q31 A, Q32 A, Q33 A, Q34 C, and Q25 closed with nothing further off-limits.  
Decision record in [item-list-007.md](item-list-007.md) §8; what shipped against  
it is §11.

The stage is **"intrusive safety"**, not "ItemList round 2" — the asserts that  
benefit are in `mailbox.zig`, `pool.zig` and `PolyHelper`, none of them  
`ItemList`.

## API 9 — DONE

Built in the ship order of Q32. 177/177 tests across Debug, ReleaseSafe,  
ReleaseFast and ReleaseSmall; cross-compile clean.

1. **Prevention (Q31).** `ItemList.appendFromSlot` / `prependFromSlot`. Each
   asserts the Slot holds an item, inserts, and empties the Slot. Four call  
   sites migrated — two in `examples/layer1/023-tag_dispatch.zig`, one in  
   `025-produce_consume.zig`, one in `tests/layer3_pool.zig`. The `slot = null`  
   line is gone from all of them. `append`/`prepend` stay for the stack-item  
   case, which has no Slot.
2. **Tests (Q29).** `tests/layer1_itemlist.zig`. Scenarios 100-103 moved out of
   `layer1_polynode.zig` unchanged — they are `ItemList`'s contract, and that  
   file is `PolyNode`'s. 104 and 105 are new: the slot-emptying guarantee, and  
   the `popFirst` → `appendFromSlot` round trip. 175 → 177.
3. **Detection (Q34 C).** `ItemList._holds`, private, O(n), the walk as
   designed. `append`/`prepend` assert `!_holds(ih)`; `insertAfter` also  
   asserts `_holds(existing)`. All behind `if (std.debug.runtime_safety)` — the  
   positive assert would trip `unreachable` in a build where the walk is  
   compiled out, so the gate is explicit rather than left to  
   `std.debug.assert`. `mailbox.send` and `pool.put` inherit the check through  
   the same methods; no separate walk was added inside them.
4. **Q28.** `concat` asserts `self != other`.
5. **Docs.** rules-034 ("The neighbour check"), patterns-021 ("Insert from a
   Slot"), api-reference-031, matryoshka-model-006 (companion links only),  
   item-list-007 §11, and the kitchen pages for `is_linked`, std compatibility,  
   and the Slot idioms.

`is_linked` keeps its name, signature, and all seven asserts (Q27, Q33). Its  
doc comment now claims only what it computes. The three test comments that read  
as though the check works are corrected.

**Still open, by decision.** Misuse cases 1 and 5 — an item held by a  
*different* list is not reachable from `self`, and `PolyHelper.destroy` holds a  
Slot rather than a list. That is the price of Q26 = D, and nothing in this stage  
recovers it. Cases 6, 7 and 8 stay documented sharp edges.

Open from API 8a, deferred by the owner: Q25's protection list. It was  
answered "postpone decision" and the migration ran with the three proposed  
protections applied as written — raw-link scenarios 6/7/8 stay raw,  
`polynode.reset` and `is_linked` stay public and unchanged, test count never  
drops. Worth a look before the next stage that touches list code.

CANDIDATES (composed README + landing docs from a repo-wide `.md` audit) is  
dropped, owner's decision. It carried through plan-043 to plan-046 without  
starting. `design/candidates/` does not exist on disk.

---

## API 11 — DONE

`PolyHelper.fromNode` / `mustFromNode` / `toNode` renamed to `fromPoly` /  
`mustFromPoly` / `toPoly`. Hard rename, no aliases, 164 call sites across  
`src/`, `tests/`, `examples/` and `stories/`.

`PolyNode` embeds `node: std.DoublyLinkedList.Node`, so "node" named two things  
at once — `reset` reads `node.node.prev`. The field the helper reaches is  
`poly`. The Slot accessors keep their names: they were never ambiguous.

182/182 tests across four optimize modes; cross-compile clean. Docs to  
api-reference-033, patterns-023, rules-035, item-list-009, task1-tests-005.

---

## Deferred — owner's call on order

- Diagram-notation scan.
- Mailbox-focused equivalent of the INTR 7 pool audit.
- Showcase-post variants (Ziggit, Discord, Reddit).
- Editorial/conceptual prose pass from REBRAND (README intro, manifesto).

---

## Reported, not actioned

- `Io.Select.awaitMany` is used and documented nowhere in the repo. It is
  the natural pair for any batch-receive work.
- `src/pool.zig` carries an uncommitted owner edit made before API 6
  (`get_wait` doc comment now states "does not call on_get hook").
- Stale `helpers/`-path references outside INTR 6's scope:
  `design/patterns-012.md` (2), `design/matryoshka-api-reference-021.md` (3),  
  `design/collected-context-005.md` (3, historical),  
  `kitchen/docs/patterns/pool.md` (2), `kitchen/docs/api/pool.md` (1).  
  These reference already-superseded doc versions.
- **Closed by the 2026-07-30 banned-word pass.** The `patterns-017` section
  titles carried from `-016`/`-015` are reworded in `patterns-020.md`, and the  
  `022-ownership_transfer.zig` `//!` title and entry-point name are reworded  
  too. The **filename** still carries the word — owner's decision, since  
  renaming trips the examples-catalog nav-sync rule.
- Working tree carries uncommitted owner edits to `README.md` and
  `design/mtk-readme.md`, a deleted SPDX header in  
  `src/internal/cond_timeout.zig`, and a deleted  
  `design/stories/photo-archive-pipeline.png`. Left alone.
