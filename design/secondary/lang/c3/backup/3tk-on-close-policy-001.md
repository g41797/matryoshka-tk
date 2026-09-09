# 3tk — the close hook is not called once

Finding. First version. 2026-08-27. **Fixed the same day.**

- Came out of `P6`, while looking at the two close-hook sites.
- Started as a design question. It is not one.
- The shared specification already ruled it. Three 3tk sites carried the old answer.
- All three are corrected. Section 4 records what was done.

**This file is the record. Nothing is owed from it.**

Line numbers were printed live on 2026-08-27. Re-print before trusting them.

---

## 1. What was suspected

`on_close` runs outside the mutex, at two sites.

```
pool.c3:434    Pool.put, after on_put returned and the pool turned out closed
pool.c3:492    Pool.close, with everything the buckets held
```

The two can run at the same time, on two threads.

- `put` unlocks at `pool.c3:421` and runs `on_put`.
- `close` runs whole: sets the flag, drains every bucket, unlocks at `:489`, calls the hook at `:492`.
- `put` relocks at `:423`, sees the flag, unlocks at `:433`, calls the hook at `:434`.
- Two calls. Two different lists. Concurrent.

That looked like a broken promise.

## 2. It is not. The specification ruled it

`../common/matryoshka-specification-004.md`, Part 12.2, *on close*.

- "Called once by close — and once more for each put that discovers the pool closed while its own hook was running."
- "A hook MUST therefore tolerate a later call and MUST NOT destroy its own state on the first one."
- The clause was weakened deliberately in `003`.
  - `002` said *called once*.
  - `002` had not noticed the window Part 12.3 opens.
  - The spec states the trade: two calls to a cleanup hook is a smaller cost than items with no holder.

The concurrency is ruled too. Part 12.3.

- "Several hooks run at once, on different threads. The pool does not serialize them."
- "A hook that touches shared state protects it itself."

So both axes are closed.

| axis | ruled | where |
|------|-------|-------|
| outside the mutex, or under it | outside | 12.2 *on close*, 12.3 first bullet |
| once, or once per batch | once per batch | 12.2 *on close* |

3tk's code is correct. Nothing in `3tk/src` changes.

## 3. What is actually wrong

Three doc sites still say *called once*. All three are `002`-era wording that `003` superseded.

| site | text |
|------|------|
| `3tk/src/pool.c3:92` | The hook is called once, outside the mutex, after the closed flag is set. |
| `3tk/src/pool.c3:469` | The hook is called once, outside the mutex, after the closed flag is set. |
| `ref/3tk-reference-004.md:1039` | The hook is called once, outside the mutex, after the closed flag is set. |

Why it matters.

- A hook writer reads the descriptor and writes a hook that runs once.
- It runs twice, and the second call finds state the first one tore down.
- The port's own comment is what misled them.

The two `pool.c3` sites are inside `<* *>`.

- So the doc loop is owed.
- So the reference becomes `-004`.

## 4. What was done, 2026-08-27

Two of the three sites contradicted themselves. The truthful lines sat right
beside the stale one.

`3tk/src/pool.c3:92`, the hooks interface.

- The next two lines already said *called once by `close`, and possibly once more with stragglers from a concurrent `put`*, and *so a hook must not free its own context on the first call*.
- So only the word *once* was written out of line 92.
- The block no longer argues with itself.

`3tk/src/pool.c3:469`, `Pool.close`.

- Same word written out.
- The *possibly once more* sentence added, in the same words as line 92.
- The hook's obligation stays at the interface, where the hook writer is reading.

`ref/3tk-reference-004.md`, the close bullets.

- Same two changes.
- The reference already had the truthful sentences, in its hooks section. It carried both answers in one file.

The reference is versioned.

- `-003` to `backup/`. `-004` in its place. Every live cross-reference repointed.
- Historical mentions in `3tk-log.md`, `3tk-status.md` and `3tk-open-defects.md` still name `-003`, because that is what those entries recorded at the time.
- The version paragraph at the top was stale too — it still said *this is 002*. It now names `004`, with `003` and `002` summarised under it.

Verified.

- `check-doc-loop.sh` — 0 differing blocks, 440 sentences, 439 found, 1 missing, 0 banned words.
- The one miss is the pre-existing `inner.c3` module summary. It predates this fix.
- The sentence count rose by one. That is the sentence added to `Pool.close`.

No ruling was needed and none was taken.

## 5. Two things for the owner, outside 3tk

**The user-facing shared reference carries the same stale claim.**

- `design/matryoshka-api-reference-042.md:1470` — "The pool calls it once, with the full list."
- That is the book every port's user reads.
- It contradicts the specification it is meant to describe.
- 3tk found it. 3tk does not rule on it.

**A stale citation in the specification.**

- Part 12.3 cites *3tk: `pool.c3:445-480`* for the window.
- The window is live at `pool.c3:421-445`.
- Same kind of drift, one file up.

## 6. What this leaves for P6

`P6` keeps its own question, unchanged.

- The hook returns.
- The pool does not know whether the items were processed or freed.
- The pool has no way to say anything if they were not.

That is a leak question, not a policy question. It is not affected by anything in this file.

`P6`'s two remaining sites are `pool.c3:434` and `:492`. The same two sites. Different subject.
