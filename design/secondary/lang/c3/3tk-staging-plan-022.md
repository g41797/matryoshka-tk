# 3tk — staging plan 022

Written 2026-09-03.

**Provenance.** Follows [3tk-staging-plan-021.md](backup/3tk-staging-plan-021.md).
021 declared one stage, **3TK-57**, and it has since run and closed
(2026-08-31, GitHub Actions CI, built in `matryoshka-3tk`). **021 is fully
spent.** This plan declares one stage: **3TK-58.**

State is in [3tk-status.md](3tk-status.md). Narrative is in
[3tk-log.md](3tk-log.md). Neither is duplicated here.

---

## Why this plan exists

**`Mailbox` and `Pool` are public structs today, with every field readable
and writable from outside the module** — the leading underscore is
convention only, not an enforced boundary; `ref/3tk-api-003.md` even states
"C3 0.8.3 hides neither a field nor a method" as the rationale for the
current shape. The owner wants that changed: `Mailbox` and `Pool` become
**opaque handles**, following the idiom already used by C3's own stdlib
(`std::thread::channel::UnboundedChannel`, in
`/home/g41797/dev/langs/c3/lib/std/threads/unbounded_channel.c3`) —
`typedef Mailbox = void;` as the public type, the real fields in an
`@private` impl struct in the same module, every method casting the opaque
pointer to the real type as its first line. Client code that only calls
public methods (`mb.send(...)`, `pool.get(...)`, etc.) does not change; code
that reached into `_active`/`_cv` directly no longer compiles.

**Scope, ruled before this plan was written**: `Mailbox` and `Pool` only —
not `PoolBucket` (also a public struct today), and not the core
(`PolyNode`/`Inner`). This matches the boundary [3tk-status.md](3tk-status.md)
already records from the earlier API 12 work: flatten `Mailbox`/`Pool` only,
never the core.

**The owner's tests are black-box by convention.** The exceptions to that —
three test files reaching `Mailbox`/`Pool` fields directly today — are
in scope for this stage, not a follow-up, because an opaque `Mailbox`/`Pool`
makes those reads a compile error. One of the three cannot be replaced by any
public call (reasoning below); it is dropped, not rewritten.

## The stage

```
3TK-58   Mailbox/Pool opaque handles      3tk/src/, 3tk/test/, matryoshka-3tk 3tk-reference-006.md
```

## 3TK-58 — Mailbox/Pool opaque handles

**1. `src/mailbox.c3`, `src/pool.c3`.**

- `struct Mailbox { ... }` → `struct _Mbox @private { ... }` (same fields, same
  layout — `Inner node` stays the first field, since `to_handle`/`of` still
  compute a `Handle` from its address).
- `struct Pool { ... }` → `struct _Pool @private { ... }`, same treatment.
- `typedef Mailbox = void;` / `typedef Pool = void;` become the public types.
- Every method signature changes from `fn T Mailbox.method(&self, ...)` to
  `fn T Mailbox.method(&mbox, ...)` (parameter renamed since `self` no longer
  names the real type), with `_Mbox* self = (_Mbox*)mbox;` as the first line
  of the body — body otherwise unchanged. Same for `Pool`.
- `to_handle`, `of`, and the `@closed_fast` macro take the opaque pointer and
  cast internally, the same way.
- The descriptive `<* *>` doc comment currently above `struct Mailbox` /
  `struct Pool` moves to above the new `typedef` line. Mechanically safe:
  `check-doc-loop.sh` matches every `<* *>` block's sentences against the
  reference text as a flat pool, regardless of what declaration follows it —
  confirmed by reading the script before this plan was written. c3c itself
  has no working docgen to have a placement rule at all (`MANUAL.md` ~line
  10427: "`c3c docs` ... Not added yet!").

**2. New public API**: `Mailbox.is_quiet()` / `Pool.is_quiet()` → `bool`,
returning `self._closed && self._active == 0` under the mutex, same
predicate `release()` already asserts. Deliberately narrower than a raw
`active_count()` accessor — the owner's call, to avoid exposing the count as
a number tests could otherwise be tempted to inspect more closely than the
contract promises.

**3. Test fixes, same stage:**

| file | today | after |
|---|---|---|
| `test/t_mailbox.c3:443,471,510` | `always_assert(mb._active == 0, ...)` | `always_assert(mb.is_quiet(), ...)` |
| `test/t_pool.c3:672,700,733,736` | `always_assert(p._active == 0, ...)` | `always_assert(p.is_quiet(), ...)` |
| `test/t_concurrency.c3` | `the_deadline_is_anchored_once` calls `mb._cv.broadcast()` directly to provoke a spurious wakeup | **dropped** — no replacement |
| `test/t_identity.c3:43-44,70-71,98-99` | `.node` access, target type not yet confirmed | read first; fix only if it touches `Mailbox`/`Pool` |

**Why `the_deadline_is_anchored_once` has no replacement.** The defect it
guards against (Part 2.5, D7 — `wait_until`'s deadline must be anchored once,
not recomputed on each spurious wakeup) only shows up when the mailbox's
internal wait loop re-enters `cv.wait_until(deadline)` with *nothing*
changed: no new item, `_wake_gen` unmoved, not closed. Every public way to
signal the condition variable changes one of exactly those three things:
`send`/`send_oob` add an item (the loop's `dequeue()` then succeeds and it
returns), `wake_all()` bumps `_wake_gen` (the loop sees the generation change
and returns `WOKEN`), `close()` sets `_closed` (same). There is no sequence
of public calls that re-enters the wait loop while all three stay unchanged
— the "spurious, keep waiting" case is structurally unreachable from outside
the module by construction, which is exactly what the existing doc comment
on this test already said before this stage: *"there is no public way to
produce a spurious wakeup, because a spurious wakeup is not a feature."*
Once `_cv` itself is no longer reachable, the test's own mechanism for
provoking the case it tests goes with it. Tracked as the "Tests improvements"
TODO in [3tk-status.md](3tk-status.md); the guarantee stays documented, not
mechanically tested, going forward.

**4. Reference doc**, written directly in the separate `matryoshka-3tk` repo
(per the owner's ruling this session, [[design-docs-editable-in-3tk-repo]] in
Claude's own memory — design docs there are editable directly, not deferred):
a new `3tk-reference-006.md`, rewriting the `Mailbox`/`Pool` sections to
describe the opaque shape and retracting "C3 0.8.3 hides neither a field nor
a method," which described the shape this stage removes.
`3tk-reference-005.md` moves to that repo's `backup/` with a plain `mv`
(never `git mv` — git stays untouched there too).

**5. Verification.**

- `./3tk/run-builds.sh` after the `src/` and test changes. Compilation is the
  check: any leftover direct field access (anything this plan's search
  missed) fails to build. Fix iteratively until green, same precedent as
  3TK-50's steps.
- `./3tk/check-doc-loop.sh` against the new `3tk-reference-006.md` once it
  exists (the in-repo default `REF` path is already known stale — point it
  at the new file explicitly).
- Confirmed before writing this plan: no `Mailbox{...}` / `Pool{...}` struct
  literal exists anywhere under `3tk/`, so no construction site needs
  updating for that reason.

---

## Rules that hold

- **No stage runs `git`.** Moves in this repo are plain `mv`; the owner saves
  and pushes. The same now applies inside `matryoshka-3tk` for design docs,
  per this session's ruling.
- **A change to `3tk/src` revises `ref/` in the same stage** — this stage's
  `ref/` update is the reference book in `matryoshka-3tk`, since that is
  where the live reference now lives; this repo's `ref/3tk-api-003.md` is
  already known stale and is not the target.
- **Tests stay black-box after this stage.** The three files fixed here are
  brought back into that convention, not given a new sanctioned way to reach
  internals.

## Versioning

**`3tk-staging-plan-021.md` is superseded by this file** and moves to
`backup/`. `3tk-reference-005.md`, in `matryoshka-3tk/design/`, is superseded
by `3tk-reference-006.md` as part of this stage's own work, not before it.

## What this plan leaves to the owner

- **Whether the dropped `the_deadline_is_anchored_once` coverage gap is
  acceptable long-term**, or whether some other verification (a stress test,
  a manual sanitizer run, something else) should stand in for it. Tracked as
  the "Tests improvements" TODO, not resolved here.
- **"Managed Outers — re-thinking"** — raised this session, not elaborated,
  entirely separate from 3TK-58 and not started by it.
- **The seven questions plan 018 left and 019 carried**, and everything in
  `3tk-status.md`'s *Open questions* — untouched by this stage, and not
  reopened by it.
