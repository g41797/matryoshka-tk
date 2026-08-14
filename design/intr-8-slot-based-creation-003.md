# INTR 8 — Slot-based creation for Mbox and Pool

`mailbox.new` and `pool.new` fill a `Slot`. They no longer return a pointer.  
A Master detaches once and keeps `*Mbox` / `*Pool`.

Change from -002: the Master's field stays non-optional. Owner's ruling,  
2026-08-14, taken during 8-2 and against what -002 said. The `?*Mbox` clause  
would have edited 202 field reads to encode a state that never occurs, more  
sites than the 186 the change itself served. The unwrap is once, at creation.  
The name this note gave the shape goes with the clause; Part 1 of  
[rules-049.md](rules-049.md) carries the rule, and  
`examples/layer4/018-master_with_pool.zig` is the canonical Master.

Change from -001: `Pool.init` folds into `pool.new`. Owner's decision,  
2026-08-14. `init` is kept and made private, `new` calls it, and ten sites in  
`src/pool.zig` become obsolete with the optional `hooks` field. See "Folding  
Pool.init".

## Why

The Slot idiom covers every transfer in the toolkit. It does not cover creation.

- 22 signatures in `src/` take a Slot parameter. All 22 take it by pointer.
- None take a Slot by value.
- `src/`, `tests/`, `examples/` and `stories/` carry 874 `&slot` call sites.
- `new` and `destroy` are the only place the idiom stops.

Two costs follow from that.

- `destroy(mbx, alloc)` frees the memory and leaves the caller's pointer in
  place. A second destroy is a use-after-free. Nothing writes a null anywhere.
- `PolyHelper.destroy(alloc, &slot)` cannot fail that way. It empties the Slot
  before it releases the item, so a second call does nothing.
- `new` gives no defer-before-acquisition. The caller writes cleanup after the
  `try`, by hand, in the right order, every time.

Pool carries a second gap.

- `Pool.init(hooks)` is a separate public call.
- So a pool exists half-built between `new` and `init`.
- `get` on it hits `std.debug.assert(self.*.hooks != null)`.
- Asserts are removed in ReleaseFast and ReleaseSmall.
- Two of the four modes this repo gates on have no guard at all.

## Infrastructure items and application items

The toolkit has two classes of item. No document said so before this note.

Application items.

- Event, Request, VideoFrame. Whatever the application defines.
- They flow through the toolkit constantly.
- They are created, sent, received and released on every pass.
- The full `PolyHelper` surface serves them, `create` and `destroy` included.

Infrastructure items.

- `Mbox` and `Pool`.
- Each embeds a `PolyNode`, so each can travel through a mailbox or a pool.
- That travel is rare. Two examples in the repo do it.
- Normally a mailbox is created once and stays a field of a Master.
- `PolyHelper` generates no `create` and no `destroy` for them. Both types
  declare `no_create_destroy`.

Same mechanism, opposite usage profile. The reader needs to be told, because  
the shared machinery suggests a symmetry that does not exist in practice.

## Decisions

**`new` fills a Slot.**

```zig
pub fn new(io: Io, alloc: std.mem.Allocator, slot: *polynode.Slot) !void
```

- `!void`, not `void`. `alloc.create` fails. A failure visible only as a
  still-null Slot would force the caller to test the Slot instead of the error.
- Asserts `slot.* == null` on entry. `new` is an acquisition API, and the Slot
  Rule covers every one of them.
- On success the Slot keeps the handle.
- On failure the Slot is unchanged. That is the rule for a refused transfer.

**Hard break, no alias.** The pointer-returning `new` is deleted. API 12 and  
API 11 set the precedent: hard rename, no compatibility shim.

**Two release APIs. Both stay.**

- `destroy(mbx, alloc)` — for a caller that detached and keeps a pointer.
- `destroy_slot(slot, alloc)` — for a caller that keeps a Slot.

They serve two different holders. Neither converts to the other. A Master that  
detached at `init` has a pointer at teardown, and making it rebuild a Slot to  
satisfy a signature buys nothing.

**`destroy_slot` checks inside.**

| Slot state | behaviour |
|---|---|
| `null` | no-op |
| contains another type | panic |
| contains an open Mbox/Pool | panic, Slot unchanged |
| contains a closed Mbox/Pool | empty the Slot, then free |

The last row is the reason the function exists.  
`src/polynode.zig` already carries the rule as a comment on the generated  
`destroy`: clear the Slot before releasing the item.

The panic on a wrong type is deliberate. The caller named the module when it  
wrote `mailbox.destroy_slot`, so a Pool in that Slot is a mistake in the  
caller, not a case to route around.

**`destroy_slot` does not close.** This is forced, not chosen.

- `mbx.close()` returns an `ItemList`.
- Part 8 of the rules says that list is walked unconditionally.
- `_ = mbx.close()` is banned. MBOX 1 removed 32 of them.
- A `destroy_slot` that closed internally would have to discard that list.
- So the closed-first panic stays, and `destroy_slot` is not a blind `defer`
  target the way `PolyHelper.destroy` is.

**`Pool.init` folds into `pool.new`.**

```zig
pub fn new(io: Io, alloc: std.mem.Allocator, hooks: Pool.Hooks, slot: *polynode.Slot) !void
```

`hooks` comes before `slot`, so the Slot is the last parameter in both modules.

`init` is kept and made private.

- `new` is the coordinator. `init` is its named step.
- That is Part 1's shape, coordinator plus named steps.
- Inlining the body would leave a block that needs a comment to explain it.
  Part 1 calls that the signal to extract a step, not to write the comment.

The evidence that folding is safe.

- Around 30 call sites create a pool. Every one calls `init` two or three lines
  after `new`.
- That includes the Masters, which do both inside their own `init`.
- No site registers hooks at a distance from creation.
- No test exercises a pool that has no hooks yet.

The gain is correctness, not tidiness. The half-built state stops existing, so  
nothing has to guard against it. A Debug-only assert was the whole defence.

## What the fold makes obsolete

Ten sites in `src/pool.zig`.

| # | site | today | after |
|---|---|---|---|
| 1 | `:44` | `hooks: ?Hooks` | `hooks: Hooks` |
| 2 | `:181` | `pub fn init` | `fn init`, a private step of `new` |
| 3 | `:188` | `assert(!closed)` | a fresh pool is never closed |
| 4 | `:189` | `assert(hooks == null)` | called once, from `new` |
| 5 | `:255, :328, :530, :558, :577` | five `assert(hooks != null)` | obsolete |
| 6 | `:334, :540, :561` | three `.?` unwraps | plain field reads |
| 7 | `:437` | `if (self.*.hooks) \|hooks\|` in `close` | unconditional |
| 8 | `:462` | `.hooks = null` | the real hooks |
| 9 | `:185-186` | `lockUncancelable` in `init` | nothing else has the pointer yet |
| 10 | `:177, :208, :235` | "call once, right after `new`", "asserts the hooks are registered" | obsolete text |

`assert(hooks.tags.len > 0)` at `:182` stays. It checks caller input, not  
internal state.

## Cleanup duty moves into new

`ensureTotalCapacity` runs twice inside `init` and can fail after `alloc.create`  
has succeeded. Today a failed `init` left the caller a valid pool, and `destroy`  
released the two maps. After the fold, `new` owns that.

```zig
const p: *Pool = try alloc.create(Pool);
errdefer alloc.destroy(p);
p.* = .{ ... };
errdefer p.*.lists.deinit(alloc);
errdefer p.*.counts.deinit(alloc);
try init(p, hooks);
slot.* = Pool.toPoly(p);
```

- `errdefer` runs in reverse order of registration: `counts`, then `lists`, then
  the allocation.
- A partial failure is covered. `lists` may have grown while `counts` failed.
- `deinit` on an empty map is a no-op, so the chain is safe at every point.
- `slot.* = ...` is the last statement. Nothing that can fail follows it.
- That is what makes "failure leaves the Slot unchanged" true, rather than an
  intention.
- `mailbox.new` takes the same shape. It has no maps, so it keeps the one
  `alloc.destroy` errdefer it already has.

**All three Slot accessors are re-exported.** `fromSlot`, `mustFromSlot` and  
`moveFromSlot` sit on `Mbox` and on `Pool`, as `inline` one-liners over the  
private helper.

- `moveFromSlot` is what a Master calls to detach. Without it the stage does
  not work.
- `mustFromSlot` already has callers written the long way.
  `examples/layer4/095-mailbox_as_item.zig` unwraps a Slot by hand in three  
  places.
- `fromSlot` completes the trio. The api reference documents the three
  together as one idiom, and shipping two of three would need a paragraph  
  explaining the gap.

**The helper stays private.** `Mbox` and `Pool` already re-export five members  
as one-line wrappers. This extends that pattern.

- A public `helper` would give `Mbox.helper.fromPoly` beside the existing
  `Mbox.fromPoly`. Two spellings for one call.
- API 4, API 6 and API 11 were each a rename to remove a duplicate name.
- It would also publish `init`, which re-tags a live object and has no caller.

**The Master keeps `*Mbox` / `*Pool`.** The Slot is a local in `init`.

```zig
var mbx_slot: polynode.Slot = null;
try mailbox.new(io, alloc, &mbx_slot);
self.mbx = Mbox.moveFromSlot(&mbx_slot).?;
```

- The field is reached as `self.mbx`. The unwrap is here and nowhere else.
- One Slot per resource, each named for its resource. Never one Slot reused.
- Nothing fallible sits between `new` and the detach, so the Slot window needs
  no `errdefer`. The resource's `errdefer` comes after the detach and guards  
  the field.
- A field typed `polynode.Slot` would be `?*PolyNode`, so every mailbox
  operation would need `Mbox.mustFromPoly` first. That is a cast on every call.
- The Master's own `init(allocator, io) !*MasterXYZ` signature does not change.
- A pool is one call: `pool.new(io, alloc, hooks, &slot)`, then detach. The
  separate `pl.init(hooks)` line goes away at every site.

## Rejected

**A top-level `matryoshka.destroy_slot`.** Deferred, not refused.

- It can never be universal. Part 7 already proves the point for dispatch
  chains: with no type there is no size, so nothing can free an unknown item.
- It would know two tags, `Mbox.TAG` and `Pool.TAG`, and nothing else.
- Sitting at the top namespace it would read as universal, and a caller would
  pass an application item to it.
- If it ships it must use the Slot convention, never a panic. Mbox or Pool —
  freed, Slot emptied. Anything else — Slot left full, still the caller's.
- The one call site that would gain is
  `examples/layer4/095-mailbox_as_item.zig`, which already writes a dispatch  
  chain it needs for other reasons.
- `src/matryoshka.zig` is a namespace today. Three re-exports, two aliases, no
  functions. This would change what the file is.

**A Slot-only `destroy`.** It would close the dangling-pointer hole completely,  
because there would be no unchecked entry point left. It also makes every  
Master rebuild a Slot from a pointer at teardown. Rejected on that cost. The  
hole narrows rather than closes, and that is a known consequence.

## Scale

- 186 `new` call sites.
- Around 30 `pl.init(hooks)` lines, deleted.
- 201 `destroy` call sites.
- 30 breaking snippets in documents, plus 65 generated example pages.

## Sub-stages

`tests/` and `examples/` cannot be separated. Every example has a wrapper in  
`tests/`, so both compile into one binary under `zig build test`. API 12 tried  
the split and closed 12-2 at 120/120 with the example wrappers held out — a  
stage that ran without a real gate. Not repeated here.

- **INTR 8-1** — `src/`. Gate: `kitchen/build_core_debug.sh`.
- **INTR 8-2** — `tests/`, `examples/`, `stories/` together. Gate: all three
  kitchen scripts.
- **INTR 8-3** — documents. Gate: `check_design.sh`, `build_site.sh`.

Detail for each: [matryoshka-tk-implementation-plan-072.md](matryoshka-tk-implementation-plan-072.md).

## Rules this stage changes

Four findings, all four discharged into [rules-049.md](rules-049.md) by 8-3.

- Part 3, the Slot Rule. The null-safe cleanup list names `pool.put`,
  `PolyHelper.destroy` and `helpers.freeSlot`. `mailbox.destroy_slot` and  
  `pool.destroy_slot` join it.
- Part 3. `new` becomes an acquisition API asserting `slot.* == null`. Worth
  naming, since the rule lists them.
- Part 1, Master struct shape. The rule covers `init`, `destroy`, `run` and
  fields. It said nothing about how a Master acquires its infrastructure. It  
  gains "How a Master acquires a mailbox or a pool", with the non-optional  
  field and the one-Slot-per-resource rule.
- Part 8. The `new` and `destroy_slot` contract joins the transfer invariants.

## Open

- `language-of-matryoshka.md` is unsuffixed, against "all docs require one".
  The infrastructure-item entry landed in it in 8-3, edited in place by the  
  owner's ruling of 2026-08-14. The suffix question is still open and is  
  carried by 13-4b-3.
