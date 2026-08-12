# API 12 — Real Pointers for Mbox/Pool

Application code calls `mb.send(item)` and `p.get(...)` directly.  
No `MailboxHandle`/`PoolHandle` indirection.

Change from -004: banned-word pass. Three hits reworded — "More idiomatic  
Zig" → "Ordinary Zig", "a settled surface" → "an agreed surface", "A scripted  
sweep needs a reader" → "A scripted search-and-replace needs a reader". No  
decision changed.

Change from -002: the 12-2 outcome, corrected call-site counts, and the  
decision to run stories on their own build step.

Change from -001: the `ConcurrentError` decision. Matryoshka defines none —  
`std.Io` already has it. See "Companion types" below.

## Why

- Natural Zig syntax — a method call, not a free function plus a handle.
- Less conceptual baggage — no `MailboxHandle`/`PoolHandle` concept to learn.
- Easier API discovery — IDE completion on `mb.` shows every Mailbox operation.
- More readable application code — the receiver is visually obvious.
- Ordinary Zig — users already understand pointers to long-lived objects.
- Less Matryoshka-specific knowledge — pointers behave the way users expect.

## Decisions

**Dual nature.** `Mbox`/`Pool` keep an embedded `poly: PolyNode`. Direct  
application code calls methods on `*Mbox`/`*Pool`. Transport through another  
Mbox/Pool goes through `toPoly`/`fromPoly` — same "one pointer, two names"  
idiom as [handle-based-programming.md](../kitchen/docs/addendums/handle-based-programming.md).

**Hard break, no alias.** `MailboxHandle` and `PoolHandle` are removed.  
No compatibility shim. Matches API 6 and API 11: hard rename, no aliases.

**Flatten only Mbox/Pool.** Re-exported from `matryoshka.zig` as  
`matryoshka.Mbox` and `matryoshka.Pool`. `polynode.*` stays namespaced —  
`ItemHandle`, `Slot`, `ItemList`, `PolyHelper`, `PolyNode` are generic  
building-block material used by every type, not a single service.

**Struct naming: `Mbox`, not `Mailbox`.** Avoids collision with the owner's  
legacy `Mailbox` type in the sibling `mailbox` repo. `Pool` keeps its name —  
no clash there. File names are unchanged: `src/mailbox.zig` still holds  
`Mbox`, `src/pool.zig` still holds `Pool`.

**Method surface.** `new(io, alloc)`, `destroy`, and `is_it_you` stay  
free/static functions. Everything else becomes a method on `*Mbox`/`*Pool`:  
`send`, `receive`, `try_receive`, `receive_batch`, `send_oob`, `close`,  
`wakeUpAll`, `get`, `get_wait`, `put`, `put_all`, `init`.

`destroy` stays a free function by decision, but Zig method-call syntax  
means `mb.destroy(alloc)` works anyway.

**Event-source functions need no redesign.** `receiveResult`, `getWaitResult`,  
`receive_future`, `get_wait_future` keep working unchanged as function values  
passed into `select.concurrent` / `io.concurrent` / `group.concurrent` — a Zig  
method is just a function with an explicit first parameter. `receiveResult`  
and `getWaitResult` stay free functions, since they are passed as values.

**PolyHelper exposure: direct static methods.** `Mbox.toPoly`, `Mbox.fromPoly`,  
`Mbox.mustFromPoly`, `Mbox.is_it_you` (same for `Pool`) sit directly on the  
type. No separately-named `MboxPolyHelper`/`PoolPolyHelper` for callers to  
look up. `PolyHelper(Mbox)` still generates the guts internally.

`Mbox.TAG`/`Pool.TAG` are re-exported too. Tag comparison outlives the  
helper name that used to carry it.

This is mandatory plumbing, not a nicety — the outer Mbox's `send`/`receive`  
only speak `polynode.Slot`/`ItemHandle`, so sending one Mbox through another  
must cross that border:

```zig
// sender side: worker_mbx: *Mbox, handed to master's inbox
var slot: polynode.Slot = Mbox.toPoly(worker_mbx);
try master_inbox.send(&slot);

// receiver side
var slot: polynode.Slot = null;
try master_inbox.receive(&slot, null);
if (Mbox.is_it_you(slot.?.tag)) {
    const worker_mbx: *Mbox = Mbox.fromPoly(slot.?);
}
```

The API reference's "Worker-finish-signal pattern" and "Wrapper pattern"  
(Tag identity — class, not instance section) need a pointer-based rewrite.  
Scope that into the examples/docs sub-stage, not the src/ rewrite.

**Field exposure accepted.** `Mbox`/`Pool` fields (mutex, cond, list, counts,  
closed, io, alloc) are reachable by anyone holding the pointer — Zig has no  
per-field privacy inside a `pub` struct. Document fields as internal via doc  
comments/naming, matching the existing `ItemList._list` precedent.

**Companion types: nest if owned by one type.**

- `Mbox.Result` — was `mailbox.ReceiveResult`.
- `Pool.Result` — was `pool.PoolResult`.
- `Pool.GetMode`, `Pool.GetError`, `Pool.Hooks` — was `GetMode`, `GetError`,
  `PoolHooks`.

**`ConcurrentError` belongs to the stdlib, not to Matryoshka.** It was  
declared identically in both `mailbox.zig` and `pool.zig` as  
`error{ConcurrencyUnavailable}`. `std.Io` already defines exactly that set,  
and `Io.concurrent` — the function both wrappers call — already returns  
`Io.ConcurrentError!Future(...)`. Both declarations were re-declarations of  
the error set the wrapped call already produces. Both are deleted; the four  
future-wrapper signatures name `Io.ConcurrentError`.

This supersedes -001, which said the shared definition should hoist to  
`matryoshka.ConcurrentError`. There is no `matryoshka.ConcurrentError` —  
Matryoshka does not define, alias, or re-export a stdlib error set.

**Kitchen tooling.** A permanent kitchen script, not throwaway, separated  
from the existing `build_and_test_*.sh` batch. Scoped to current OS and  
Debug mode only — no cross-compile, no ReleaseSafe/Fast/Small matrix.

Named for what it permanently is rather than for this stage:  
`kitchen/build_core_debug.sh`, driving a `zig build core` step over  
`examples/core_surface.zig` — Matryoshka plus the example code that calls  
Mbox/Pool directly (`examples/items/`, `examples/hooks/`,  
`examples/helpers/`). The four `layer*/` trees are left out. It stays in the  
repo after API 12 as the fast inner-loop check that skips all 76 examples.

`core_surface.zig` carries its own recursive `refAll` walk under a `test`  
block. Zig analyzes lazily: without it the step compiled a stale  
`pool_mod.PoolHooks` call in 40 ms and reported success. With it the same  
build takes 3 s and fails, as it should.

## Sub-stages

- 12-1 — `src/` rewrite. DONE 2026-08-12.
- 12-2 — tests. DONE 2026-08-12.
- 12-3 — examples, plus the story. DONE 2026-08-12.
- 12-4 — docs audit. Intent only for now. Runs after 12-1/12-2/12-3, so it
  audits an agreed surface instead of a moving target.

Each sub-stage is expanded and tuned when its turn comes, not now.

### 12-1 outcome

`src/mailbox.zig`, `src/pool.zig` and `src/matryoshka.zig` carry the new  
surface. `examples/hooks/` moved to `Pool.Hooks` — it is part of the core  
script's compile surface, so it could not wait for 12-3.

`kitchen/build_core_debug.sh` exits 0. The full  
`kitchen/build_and_test_debug.sh` fails with 72 errors, all of them old  
handle-API call sites: 64 in `examples/layer2|3|4`, 7 in `tests/`, 1 in  
`stories/`. That is the 12-2/12-3 worklist.

### 12-2 outcome

`tests/` speaks the pointer API. Five files moved:  
`layer2_mailbox.zig`, `layer3_pool.zig`, `layer4_cancel.zig`,  
`layer4_infra.zig`, `layer4_master.zig`. The other ten needed no change.

The transport scenarios 93 and 94 in `layer4_infra.zig` were the only  
non-mechanical part. A pointer is no longer a `Slot`, so they now cross the  
border explicitly with `Mbox.toPoly` / `Mbox.mustFromPoly` and the `Pool`  
pair.

**Call-site counts were wrong.** 12-1 recorded "7 in `tests/`, 1 in  
`stories/`". Those were zig's early-abort error counts, not totals. The real  
figures: about 550 sites across the five test files, and 14 in the story.  
The 64 for `examples/layer2|3|4` was low for the same reason — the real  
remaining figure is 64 *reported* errors over roughly 40 files.

**Stories run on their own build step.** `zig build test` compiled and ran  
`stories/video_transcoder.zig` through `tests/stories_test.zig`, so an  
unmigrated story blocked the whole suite. `build.zig` now carries a  
`stories` step and `tests/matryoshka_tests.zig` no longer imports  
`stories_test.zig`. A story is a long narrative program; it does not gate  
the unit-test suite. Migrating it belongs to 12-3.

**`zig build test` cannot go green until 12-3.** The test module imports  
`examples`, and the four `layer*_examples.zig` wrappers pull in the  
unmigrated tree. 12-2's gate is therefore: zero errors originating in  
`tests/`, and 120/120 passing when the example wrappers are held out.

### 12-3 outcome

63 files moved: 11 in `examples/layer2`, 4 in `layer3`, 48 in `layer4`, and  
`stories/video_transcoder.zig`. The three barrel files, `examples.zig` and  
`core_surface.zig` name no API and needed nothing.

`zig build test` is green at **191/191** — the pre-12-1 figure of 192 minus  
the story test, which now has its own step. `zig build stories` is green and  
runs the transcoder narrative end to end.

**The transport files.** `095-mailbox_as_item.zig` and  
`096-pool_as_item.zig` were the only non-mechanical work, the same shape as  
scenarios 93 and 94 in `tests/layer4_infra.zig`. Worth naming one line:  
`095` verifies that the mailbox handed back by a finished worker is the  
*same instance* the master handed out. Under the old API that read  
`slot.? == worker_mbh`, comparing two pointers that happened to have the  
same type. It now reads `Mbox.mustFromPoly(slot.?) == worker_mbx` — the  
comparison the example was always about, now spelled so the compiler agrees.

`096` held the last `PoolPolyHelper` reference in the repo.

**Doc comments were swept, including diagrams.** Owner's call. The `//!`  
blocks are the published description of each example, and roughly 180 lines  
across `layer2|3|4` named operations as `mailbox.receive` / `pool.put` —  
module functions that no longer exist. They now read `mbx.receive` / `pl.put`.  
Nothing compiles these, so this was a grep pass, not a build result.

**Release and cross matrix.** `build_and_test_all.sh` had not run since  
before 12-1. It passes: 191/191 in Debug, ReleaseSafe, ReleaseFast and  
ReleaseSmall. `build_cross_debug.sh` passes for x86_64-macos,  
aarch64-macos and x86_64-windows. Open Item 13's ReleaseSmall flake did not  
appear.

**Not done here, by decision.** `kitchen/docs/examples/**` is a committed  
mirror generated by `gen_examples_docs.sh` and is now stale against the  
migrated sources. 12-4 regenerates it alongside the hand-written pages.

### 12-4 outcome

Documentation now speaks the pointer API. API 12 is closed.

`kitchen/docs/examples/**` was regenerated from the migrated sources — 88  
pages, zero handle references left. 34 hand-written site pages were swept:  
`kitchen/docs/patterns/`, `kitchen/docs/api/**`, six addendums, and the two  
example catalog pages.

Eleven design docs went up a version, listed in the plan's ledger line.

**Two pages needed more than renaming.** `../kitchen/docs/api/tags-and-slots/index.md` opened  
by saying `_Mailbox` and `_Pool` are private structs — API 12 made them  
public with internal fields, so the claim was false, not just old. And the  
`Types` blocks in the mailbox and pool pages published `pub const  
MailboxHandle = ItemHandle;`, an alias that no longer exists; they now state  
the struct and the pointer rule, worded from the `///` blocks in `src/`.

**The two deferred write-ups.** Worker-finish-signal and Wrapper, in the API  
reference and `patterns-027.md`. Both were rewritten around the real  
comparison — `Mbox.mustFromPoly(slot.?) == worker_mbx`, two `*Mbox` the  
compiler agrees about — with a line on why the handle-era version leaned on  
the tag alone.

**A scripted search-and-replace needs a reader.** The mechanical pass turned every  
`mod.method(receiver, args)` into `receiver.method(args)`, and it wrongly  
renamed the first parameter of six *free* functions to `self`:  
`mailbox.receiveResult`, `mailbox.destroy`, `pool.getWaitResult`,  
`pool.destroy`, and five local helpers in `../kitchen/docs/patterns/master-and-shutdown.md` that  
merely take a mailbox or pool. Each was checked against `src/` and corrected.  
Free functions keep module form; only methods moved onto the pointer.

**Found, not fixed.** Roughly fifteen `std.log.info` strings inside  
`examples/layer4/*.zig` still name operations as `pool.get:` /  
`mailbox.close:`. 12-3 swept the `//!` doc comments but not log text, and  
they surface in the generated mirror. They are source files, so a docs-only  
stage left them. Small follow-up.

## See also

- [handle-based-programming.md](../kitchen/docs/addendums/handle-based-programming.md) — the pointer/handle idiom this extends.
- [matryoshka-api-reference-036.md](matryoshka-api-reference-036.md) — the API surface, rewritten to real pointers across 12-2 through 12-4.
