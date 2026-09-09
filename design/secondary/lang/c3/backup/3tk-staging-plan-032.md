# 3tk — staging plan 032

Written 2026-09-09.

**Provenance.** Follows [3tk-staging-plan-031.md](3tk-staging-plan-031.md),
which follows `030`, `029`, `028`, `027` and `026`. **Those earlier ones are
named, not linked as sources: `backup/` is transient — the owner empties it —
and it is never cited as a source of truth.**

**031 is spent.** `3TK-70` was its only stage and it closed on 2026-09-09.
**Only `3TK-50` remains from any earlier plan, and it waits on the owner.**

State is in [3tk-status.md](3tk-status.md). Narrative is in
[3tk-log.md](3tk-log.md).

**The rules every stage is written against are in
[matryoshka-3tk/design/3tk-rules-002.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-rules-002.md)**
— two parts, the port rules and the stage rules. This plan cites that file; it
does not re-argue it. **`3TK-71` adds a sixth port rule to it, as
`3tk-rules-003.md`, and renumbers the stage rules.**

---

## Why this plan exists

**The ruling is two years' old in stage-time and the tests never heard it.**

Stage A, 2026-08-31, ruled a **stack outer illegal** — not only across a mailbox
or a thread boundary. 3tk computes an outer's address from its embedded `Inner`
at every crossing, and a stack address is valid for exactly one lexical instance
of one frame. A copy, or a use after the frame returns, reaches through a stale
address, **and it can appear to work before it fails.**

`examples/` was revised by that stage and is clean: **zero stack outers.**
`test/` and `negative/` were not in its scope and were never revisited. Counted
2026-09-09, per declaration:

| tree | stack outers | files |
|---|---|---|
| `test/` | **41** | 6 of 10 |
| `negative/` | **10**, plus 2 at global scope | 9 of 20 |
| `examples/` | **0** | — |

**`t_identity.c3` is 18 of the 41 and has no heap outer anywhere in its 265
lines.** Every crossing it asserts, every offset, the whole of Parts 4.3, 5.1
and 6.1, rests on `&m`.

**Almost none of it is deliberate.** These files predate `OuterHelper`:
`create`/`release` did not exist to reach for when they were written, and
`mtk::managed` — which did — was never the thing a test reached for either. The
stack outer is what was left. **That is a historic reason, not a subject
requirement.**

**One site is sharp rather than merely wrong.** `t_concurrency.c3:242`, inside
`a_leaver_hands_the_signal_on`, stamps a stack `Msg` and `send`s it into a
mailbox **two other threads are blocked receiving from**, twenty rounds in a
loop, reusing the same frame each round. It passes today only because
`short_waiter` counts and never dereferences the outer. It is the exact shape
pattern entry 14 was written to forbid.

---

## What the sitting of 2026-09-09 ruled

Written as ids. **A later stage cites an id; it does not re-argue the point.**

### T-1 — the mindset, and it is not a MUST

**A test or negative whose *subject requires* a stack outer is correct as it
stands and stays. Anything standing on a historic reason is rewritten.**

The owner's words: *"if test or negative requires not follow rules — it's ok;
but if it's just historic reason — should be re-written."*

This is a judgment asked of each site, **not a rule a grep can apply**. See
`T-6`.

### T-2 — `examples/` is absolute, and its rules document is not touched

**Every outer in `examples/` is allocated. No exemption exists there**, because
a teaching file has no subject that requires a stack outer.
`3tk-example-rules-004.md`'s allocation MUST stays exactly as written, keeps its
scope, and **is not extended to `test/` or `negative/`.** Ruled after the stage
proposed extending it.

The two rules differ in kind — absolute there, defeasible-by-subject here — so
there is no overlap to reconcile and no version of the example rules is written.

### T-3 — the target pattern already exists in the tree

`test/t_helper.c3` and `examples/006-defer_put_early.c3` are the exemplars.
**Nothing is invented by this stage:**

```c3
Slot s;
defer HOLDER.release(mem, &s);
if (catch HOLDER.create(mem, &s)) { always_assert(false, "create failed"); }
```

`mem` is the allocator at every test site. `release` returns `void` and is a
no-op on an empty Slot, **so the `defer` may precede the `create`** — Part 3.4,
and `release_is_a_no_op_on_an_empty_slot` holds it.

### T-4 — the known necessity cases, and they are few

Three sites are exempt **by construction**, because their subject is an outer
that was never stamped and `create` always stamps:

- `test/t_identity.c3:103` — `uninitialized_inner_is_refused`
- `negative/unstamped_crossing.c3:21`
- `negative/unstamped_insert.c3:21`

**This list is not closed and it is not a quota.** The stage asks the question
of all 51 sites and may find more. It may also find fewer: a site is exempt only
if converting it destroys what the test proves.

### T-5 — an exempted site says so, at the site

**Where a site stays on the stack, it carries a line saying why.** Not a
reference to this plan and not a mark — a sentence a reader of the test
understands without leaving the file. Without it the next reader takes the site
for another leftover, which is exactly how the 41 survived `3TK-60` through
`3TK-70`.

### T-6 — no new check, and the reason is not laziness

A `run-builds.sh` grep cannot tell necessity from history. It would need an
allow-list, **and the allow-list would be the judgment — restated in a shell
script, where a reader of the test never sees it.** `T-5`'s line is the record.

**The enforcement that does exist is real:** `c3c test` detects leaks by
default, in all four builds, so every `create` without its `release` fails the
build rather than passing quietly.

### T-7 — the two global outers are a third case

`negative/release_during_on_put.c3:60` and
`negative/release_with_straggler_put.c3:68` declare `Msg one;` at **global
scope**, not in a frame. **A global outer's address is valid for the life of the
program**, so the lifetime argument that condemns a stack outer does not reach
it. The stage rules each of the two on its own and **says which way in the log**;
it does not silently fold them into the sweep.

### T-8 — the rules file gains a port rule, and the stage rules renumber

**`3tk-rules-003.md`**, a new version; `002` to `matryoshka-3tk/design/backup/`.

New **Rule 6**, at the end of **Part 1**, the port rules:

> **An outer in `test/` or `negative/` is heap-allocated through the helper,
> unless the test's subject forbids it — and then the site says so.**

It goes in Part 1 because it governs how source is written, not how a stage is
run. **The five stage rules renumber 6–10 into 7–11.** Ruled against the
alternative of appending it as Rule 11: a rules file is normative, and a port
rule filed after the stage rules teaches every later reader that the Parts mean
nothing.

### T-9 — the renumbering re-anchors its own citations

**Three live citations break and the stage fixes all three, in the stage** —
`3tk-status.md` twice (Rule 7, the model basis; Rule 10, *fix the definition*)
and `3tk-staging-plan-030.md`'s `L-9` once (Rule 5). **Each is resolved from the
rule's own text, never from the number it carried** — `3TK-66`'s method, and
`3TK-70`'s.

### T-10 — the figures must not move, and that is the proof

No test is added or removed. `src/` is not touched. **107 checks, four builds,
145 tests each, doc loop 11 blocks and 443 of 443.** A moved number is a defect
of the sweep, not a result of it.

---

### T-11 — the stage decides, and does not come back

**Ruled by the owner, 2026-09-09: every decision this stage meets is the
stage's.** `T-1` was answered once, as a rule; applying it 53 times is reading,
not ruling, and the stage has the test in front of it.

That covers the two globals of `T-7`, any site whose conversion is arguable, and
**the location of `3tk-rules-003.md`** — the standing *ask before creating a file
in `matryoshka-3tk/design/`* is waived for this one file, which goes beside
`3tk-rules-002.md`.

**The stage does not halt to ask.** Where the rule turns out under-specified,
Rule 10 governs — fix the definition in the stage and record what was fixed.
**Every decision taken under this id is named in the log entry**, so the owner
reads them afterwards rather than being asked for them in advance.

---

## The stage

| stage | what it does | model |
|---|---|---|
| **3TK-71** | **The tests allocate their outers.** 41 sites in `test/` and 12 in `negative/`, each asked whether its subject requires the stack; converted unless it does, and annotated where it does. Then `3tk-rules-003.md` with Rule 6 and the renumbering, and the three citations re-anchored. | **Opus 5** |

**Why Opus 5.** Rule 7's basis is how much of the stage is *deciding* rather
than *applying*. The pattern is settled and `T-3` supplies it, but `T-1` is a
judgment asked 53 times, and `T-4` says the exemption list is open. A mechanical
sweep would convert the three necessity cases and break them.

### Steps

**1. The exemplar comes before the sweep** — Rule 8. `test/t_slot.c3`: six
sites, one existing `create`, the smallest file with a representative mix.
Rewritten whole and read before anything else runs.

**2. `test/`, the remaining five files.** `t_identity.c3` (18), `t_queue.c3` (8),
`t_helper.c3` (4), `t_mailbox.c3` (4), `t_concurrency.c3` (1). `t_pool.c3` and
`t_alloc.c3` already allocate and are untouched; `common.c3` and `t_examples.c3`
declare no outer.

**`t_identity.c3`'s offset probes convert.** `inner_at_any_offset` takes two
addresses and asserts arithmetic, never crossing a boundary — *it is only
arithmetic* is a historic reason, and a reader of the suite should see one
allocation pattern rather than two.

**3. `negative/`, nine files.** Same judgment. For every site that converts,
**check that the added `create` runs before, and does not disturb, the line the
program exists to abort on** — a negative is a whole program, not a `@test`, and
`run-builds.sh` asserts each one still aborts, by name, in the safe builds.

**4. `3tk-rules-003.md`** — `T-8`. Written directly in `matryoshka-3tk/design/`.
**Ask the owner before creating the file there**, every time.

**5. The three citations** — `T-9`.

**6. Close.** `run-builds.sh`, `check-doc-loop.sh`,
`move-module-docs.sh roundtrip`, the `matryoshka-3tk/scripts/` diff and the
`.yml` review (Rule 9 — **"none needed" is an answer that must be written into
the log**). Then the log entry and this file's row in the status.

---

## What this plan does not do

- **It does not touch `src/`.** No production line moves, so the doc loop must
  read identically.
- **It does not touch `examples/`** — `T-2`.
- **It does not add a check** — `T-6`.
- **It does not write a version of `3tk-example-rules-004.md`** — `T-2`.
