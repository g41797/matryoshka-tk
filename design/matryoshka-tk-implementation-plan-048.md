# Matryoshka Zig — Implementation Plan (048)

Replaces [matryoshka-tk-implementation-plan-047.md](matryoshka-tk-implementation-plan-047.md).

## Status

API 7 complete — 7a, 7b, 7c, 7d. 171/171 tests.

API 7e is a decision gate. Recommendation recorded, not implemented —  
it adds public API surface, so it needs the owner.

---

## Completed stages (summary)

- Stage 0–8: API, tests, examples layers 1–3 done.
- Stage 9 (Layer 4 infrastructure): pool, mailbox, select, group done.
- EXMPL 3a–4c, API 2–4b, DOC 9–20, INTR 6: see plan-040 for full detail.
- DOC 21: "The Shape of a Real System" page + Graphviz diagram tooling.
- INTR 7: pool `on_put` reset convention, "Pool is not storage" doc fix,
  put-semantics documented, 5 wrong-assumption bugs fixed.
- Staccato sweep + "thread" audit: prose-paragraph and stale thread-join
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
  (169/169 tests). Settled design: [receive-router-001.md](receive-router-001.md).
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

Rejected during API 7d, owner's decision. Recorded so they are not re-proposed.

- `fromNode`/`toNode` taking `ItemHandle` instead of `*PolyNode`.
  Type-identical, so it would have been free at call sites, but  
  `node: ItemHandle` reads badly and no parameter name makes the function  
  name, the parameter, and the type agree. `ItemHandle` means opaque, and  
  layer 1 is the one place the node is opened on purpose.
- `isIt` taking `ItemHandle`, with `X.poly.tag` call sites migrated to
  `Helper.toNode(&X).*.tag`. `isIt` must keep its tag parameter: 6 of its 13  
  callers have no item at all, including `items.createByTag`, which uses the  
  tag to decide what to create. Tags are user-facing currency — `pool.get`  
  and `pool.init` take bare tags at ~40 example sites. And `X.poly.tag` reads  
  better than the nested accessor call, so those 4 sites stay.

See `design/STATUS.md` Session Log for full per-stage detail — this plan file  
stays state-only per the slim-plan rule.

---

## API 7e — open decision gate

**Accessor for `&x.poly.node`.** Was 7d before the renumber.  
Recommendation below. **Not implemented — owner's call, API surface change.**

11 sites reach two levels. Split by kind, not by file.

Genuine list insertion — 5 sites. An accessor would help.

- `tests/layer3_pool.zig:968,974,980` — scenario 89's `onPutComposite`.
- `tests/layer1_polynode.zig:104,105,146,147,160` — `list.append`.
- `examples/layer1/022-ownership_transfer.zig:42`.

Deliberate raw-link manipulation — 6 sites. An accessor must not touch these.

- `tests/layer1_polynode.zig:50` — scenario 6 walks the two-level chain on
  purpose. That chain is the thing under test.
- `tests/layer1_polynode.zig:61,62,66,67,77` — scenarios 7 and 8 set and read
  `prev`/`next` by hand to drive `is_linked` and `reset`. Reaching in is the  
  point.

Why it is worth doing.

- `onPutComposite` is a user-facing path, not a test artifact. API 5a made
  `on_put` return a `std.DoublyLinkedList`, so hook authors compose lists.  
  That hook writes `&x.*.poly.node` three times in a row.
- It closes the last hand-reach into `poly` outside `src/`.

Recommended shape: `toListNode` on `PolyHelper`, symmetric with `toNode`.

```zig
pub inline fn toListNode(self: *T) *std.DoublyLinkedList.Node {
    return &self.poly.node;
}
```

- `list.append(SensorPolyHelper.toListNode(sn));` — one call, no field path.
- Same rule class as `toNode`: pure inspection, cannot fail, no `must` variant.

Two alternatives were considered and are weaker.

- A module-level `polynode.listNode(node: *PolyNode)` matches the existing
  `reset` / `is_linked` shape, but composes badly:  
  `list.append(polynode.listNode(Helper.toNode(sn)))`.
- An `appendTo(list, node)` helper reads well but hides a std container
  operation behind a Matryoshka name.

Open question for the owner: whether app code should hold a  
`*std.DoublyLinkedList.Node` at all, or whether raw list composition should  
stay an explicit, slightly awkward act.

---

## Next

API 7e — the `toListNode` decision gate above. Owner's call.  
No other stage is queued.

CANDIDATES (composed README + landing docs from a repo-wide `.md` audit) is  
dropped, owner's decision. It carried through plan-043 to plan-046 without  
starting. `design/candidates/` does not exist on disk.

---

## Deferred — owner's call on order

- Diagram-notation sweep.
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
- Pre-existing banned-word hits carried into `design/patterns-017.md` from
  `-016`/`-015`: section titles "Slot and ownership idioms" and "Transfer  
  clears ownership", plus body uses. Reported per the scan rule, not fixed  
  without approval.
- `examples/layer1/022-ownership_transfer.zig` keeps `ownership` in its
  filename, `//!` title, and entry-point name. Renaming trips the  
  examples-catalog nav-sync rule — separate stage, owner's call.
- Working tree carries uncommitted owner edits to `README.md` and
  `design/mtk-readme.md`, a deleted SPDX header in  
  `src/internal/cond_timeout.zig`, and a deleted  
  `design/stories/photo-archive-pipeline.png`. Left alone.
