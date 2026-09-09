# 3tk — the close hook takes the queue by value

**The ruling that closes `P6`, and the charter for the stage that builds it.**
Ruled by the owner on 2026-08-28, in conversation, after the `Q5` lifetime fix
was complete in code and in the shared specification.

**This document is the stage's only input besides
[3tk-status.md](3tk-status.md).** It is written before the stage runs, because
the ruling and the code are separated by a context clear.

## 1. The ruling

> **`on_close` takes the queue by value.** That says to the hook: **I do not care
> what you did.** Comments and documentation say the same thing in words.

**Responsibility moves to the hook, entirely and visibly.** The pool hands the
items over and keeps nothing — no pointer, no count, no check.

## 2. What it decides about `P6`

**`P6` is ruled: option 3, *trust the hook and write it down*.** Options 1 and 2
of [3tk-open-defects.md](3tk-open-defects.md) — count what came back, or assert
the queue is empty after the hook returns — **are closed for good, not
deferred.** After a by-value hand-off the pool holds nothing to count.

**Measured, not assumed**, on c3c 0.8.3, 2026-08-28:

```
hook sees count=7 empty=false     // a by-value struct parameter is an lvalue;
hook after drain count=0          // &self methods bind to it, so ergonomics
caller still sees count=7         // are unchanged — and the caller learns nothing
```

**The third line is the ruling working as intended.** It is also why the copy
must become a real move: two live copies of one chain is the shape invariant 20
forbids.

## 3. The five defaults, all accepted by the owner

| | question | ruled |
|---|---|---|
| 1 | the operation's name | **`take()`** — `Slot.take()` already means *remove it and give it to me, leaving the source empty* |
| 2 | does `InnerStack` get one | **no.** No caller. Part 8.2's *provided if useful* |
| 3 | does `_close` change shape | **no.** Private, one caller per tool, the application never sees it |
| 4 | does this reach the shared specification | **no version.** Part 12.2 says the hook is handed the items, not through what. **Record it** as a `3tk` decision and a port finding so dtk reads the argument |
| 5 | `on_put`'s `extra` | **unchanged, stays `InnerQueue*`.** It is a genuine out-parameter — the hook puts items in and the pool takes them. The asymmetry is the two directions being spelled differently |

**Not decisions, already fixed by Part 12.2**: both call sites pass by value;
the main close path calls the hook unconditionally; the straggler path keeps its
`is_empty` guard.

## 4. The work

1. **`InnerQueue.take()` in `queue.c3`.** Returns an `InnerQueue` by value and
   leaves `self` empty. O(1), cannot fail, no guard — `append_queue` needs two
   guards only because it has a destination that can be itself. Doc block in the
   file's own shape.
2. **The signature.** `fn void on_close(InnerQueue remaining);` in `pool.c3`'s
   hook interface.
3. **Both call sites.** `pool.c3:493` — the straggler path, still guarded by
   `is_empty` — and `pool.c3:563`, the main close. Each becomes
   `on_close(q.take())`. **Line numbers were live 2026-08-28; re-print.**
4. **The wording, and it is half the ruling.** The hook's doc block keeps
   *process or free every item* and gains: **the pool does not verify it and
   never will.** The same sentence goes to `ref/3tk-reference-004.md` and to the
   descriptors. The silence must not read as a promise.
5. **The doc loop, in the same stage.** A change to `3tk/src` revises `ref/` in
   the same stage — ruled 2026-08-25. `./check-doc-loop.sh`.
6. **`ref/3tk-decisions-003.md`** gains the entry `P6` was always going to need,
   and **[3tk-port-findings-003.md](3tk-port-findings-003.md)** gains the
   argument for dtk and otk to read. Both are versioned: next number, superseded
   version to `backup/`.
7. **`P6` closed** in [3tk-open-defects.md](3tk-open-defects.md) — table row and
   section, *ruled 2026-08-28, built by this stage*.
8. **One positive test** that the source queue is empty after `take()`. **No
   negative is possible**: a hook that keeps items dereferences nothing, so no
   build can notice. That is the ruling, not a gap.

## 5. What is touched outside `src/`

**19 mentions of `on_close` across 6 files**, counted 2026-08-28:
`test/t_pool.c3`, `test/t_concurrency.c3`, `negative/common.c3`,
`negative/release_during_on_put.c3`, `negative/release_during_on_close.c3`,
`negative/release_with_straggler_put.c3`.

**The three `release_during_*` negatives are tier 1** and must still abort in
every build mode. They are the lifetime fix's own tests and this stage must not
weaken them.

## 6. What was argued and lost, so it is not re-argued

**The advice was 2 + 3** — assert the queue is empty in a checked build, and
document it. The argument for it: a leak dereferences nothing, so a fast build
cannot notice it however the parameter is spelled, and the checked-build
assertion is the only detector this defect could ever have.

**The owner ruled 3.** *I do not care what you did* is a defensible interface,
and stating it in the type is stronger than stating it in a comment beside a
pointer that suggests otherwise. **Recorded here so the trade is visible, not to
reopen it.**

## 7. Verification

```
./run-builds.sh        four builds green, 0 failures
./check-doc-loop.sh    0 differing blocks, 0 banned words
./run-sanitizers.sh    3 passed — the hook path changed, so this is owed
```

**Every number moves in this stage** — checks, tests, and the *item* word counts
in `ref/3tk-example-rules-001.md`. Re-measure and write the new ones into
[3tk-status.md](3tk-status.md).
