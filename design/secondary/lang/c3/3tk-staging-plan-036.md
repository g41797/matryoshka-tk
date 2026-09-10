# 3tk — staging plan 036

Written 2026-09-10.

**Provenance.** Follows `035`, which follows `034`, `033`, `032`, `031`, `030`,
`029`, `028`, `027` and `026`. **Those earlier ones are named, not linked:
`backup/` is transient — the owner empties it — and it is never cited as a
source of truth.** `035` is spent: `3TK-74` was its only stage, it closed on
2026-09-09, and the owner moved `035` to `backup/` on 2026-09-10. **It is named
here, not linked.**

**Only `3TK-50` remains from any earlier plan, and it waits on the owner.**

State is in [3tk-status.md](3tk-status.md). Narrative is in
[3tk-log.md](3tk-log.md).

**The rules every stage is written against are in
[matryoshka-3tk/design/3tk-rules-005.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-rules-005.md)**
— two parts, the port rules and the stage rules. This plan cites that file; it
does not re-argue it.

---

## Why this plan exists

**The helper is finished as a surface and the trees that use it are not.**
`3TK-64` built `OuterHelper`, `3TK-pre-65` gave it its module, and `3TK-74`
closed its hooks. `3TK-66` rewrote all 52 examples onto it and
`run-builds.sh:305-313` has guarded them since. **`test/` and `negative/` were
never in that scope**, and they still carry **113 calls to
`inner::internal::*` where an `OuterHelper` member does the same job.**

**Those are leftovers, not choices.** `q.push_back(inner::internal::to_inner(m))`
is not probing the border; it is the ordinary user line written the way it had
to be written before the helper existed.

**Sizing that up found the cause of something older, and it is not where the
comments say it is.** `OuterHelper.inner` stamps, and `stamp` is a
read-modify-write of the whole `link` field:

```c3
inner.link = any_make(inner.link.ptr, $Typeof(*outer)::typeid);
```

`Inner` is one `any`. **The pointer half is the chain link; the typeid half is
the identity.** So a stamp reads the link and writes it back — and if another
thread relinks in between, the stale pointer goes back and **that thread's link
is lost.** `mailbox.c3:48-52` and `pool.c3:160-164` each say the stamp *"writes
the same bytes it finds, but it writes them"*, which is true of the typeid half
and understates the other one.

**`HS-10` ruled the stamp writes `.type` only.** The built code does not. **The
ruling and the implementation disagree, and the two `src/` exceptions are the
two places that noticed and stepped around it.**

### What was measured on 2026-09-10, before any of this was ruled

Read off the built tree at `design/secondary/lang/c3/3tk/`.

- **`src/` is at its floor.** `queue.c3:129,211,212` and `pool.c3:763,764,808`
  are chain plumbing on a **type-erased `Inner*`** — no `Outer` is in scope, so
  no `helper::OF{…}` binding can exist. `mailbox.c3:58` and `pool.c3:165` are
  the two non-stamping `to_inner` sites. **Everything else in `mailbox.c3` and
  `pool.c3` already goes through the `@private` `MBOX`/`POOL` aliases.**
- **The population is `test/` 98 and `negative/` 15.** `examples/` is 2, both
  already sanctioned by name.
  - `t_queue.c3` 40, `t_identity.c3` 26, `t_mailbox.c3` 15, `t_slot.c3` 11,
    `t_pool.c3` 4, `t_concurrency.c3` 2.
  - By shape: `to_inner` 54, `from_inner` 21, `move_from_slot` 8,
    `must_from_slot` 6, `is_linked` 4, `is_mine` 3, `from_slot` 2.
- **`OuterHelper.inner` has seven call sites in the whole tree and all seven are
  in `test/t_helper.c3`.** None in `src/`, `examples/` or `negative/`. **The
  stamping door is used by nothing but its own test.**
- **Stamping happens at four sites and three of them are construction-time**:
  `helper.c3:224` inside `create`, `mailbox.c3:79` `MBOX.stamp`, `pool.c3:207`
  `POOL.stamp`. **`helper.c3:170`, inside `inner()`, is the fourth — and the
  only one that can fire on an outer another thread already holds.**
- **`linked` already prefers the read-only door**:
  `is_linked(to_inner(outer))`, `helper.c3:192`. `inner()` is the outlier in its
  own file.
- **The five part-1 methods have exactly ten callers left in `test/`, and all
  ten are in `t_identity.c3`** — `.to(` 6, `.must(` 1, `.move(` 2, `.as(` 1.
  **This is load-bearing; see `C-7`.**
- **Both halves of the replacement already exist.** `mtk::@check` (`mtk.c3:66`)
  compiles to nothing outside `env::COMPILER_SAFE_MODE`, and `is_mine`
  (`inner.c3:247`) **reads** `.link.type`.

## What the sitting of 2026-09-10 ruled

### C-1 — `inner()` verifies; it does not stamp

**`OuterHelper.inner` stops writing.** It becomes `to_inner` plus a safe-build
check:

```c3
macro Inner* OuterHelper.inner(self, Outer* outer)
{
    mtk::@check(outer == null || inner::internal::is_mine(inner::internal::to_inner(outer), Outer),
        "the outer was never stamped, or carries another type: make it with `create`, or call `stamp` once");
    return inner::internal::to_inner(outer);
}
```

**It is strictly better than the stamp it replaces.** The stamp covered a
forgotten identity by writing one. The check catches a **forgotten** stamp *and*
a **wrong-type** one, **writes nothing**, and costs nothing in a release build.

**Null passes.** `is_mine(null)` is false, so the `outer == null ||` guard is
required — the same tolerance `check_stamped` (`inner.c3:278`) already carries,
and what `t_identity.c3:291` asserts.

### C-2 — the user is responsible for the stamp, and the doc block says so

**`OuterHelper.stamp` already exists** (`helper.c3:183`) for the one case
`inner()`'s stamp was covering — *"For an outer you allocated by hand."* **The
toolkit's story is two moments and they are complete without a third:
`create` stamps what it makes, `stamp` stamps what you made.**

`inner()`'s doc block is **rewritten, not patched**. *"Stamping the identity on
the way"* and *"costs nothing to call twice"* go. What arrives: the user is
responsible for the stamp, `create` does it for you, `stamp` is the door for a
hand-made outer, and **this door only verifies.**

### C-3 — `stamp` itself is not touched

**The full-field rebuild stays.** Its three callers are all construction-time
(`C-1`'s measurement), where no other thread holds the outer.

**This is deliberate and it is the narrow ruling.** Narrowing the write to the
typeid half would need a probe of whether c3c 0.8.3 lets a `.type` half be
assigned alone, and `MS-8` is the precedent for how confident an `any` spelling
can be while being wrong. **Removing the one door that exposes the write is the
smaller change and it closes the same hole.** A later stage that wants `stamp`
narrowed may run that probe; **nothing here depends on it.**

### C-4 — `linked` takes an `Inner*` too, and this is a lack of support

`helper.c3:192` gains `$Typeof` dispatch, the shape `look` and `must_look`
already carry at `:92` and `:115`.

**Why it is not a nicety.** After a `pop_front` a caller holds an `Inner*`.
`t_queue.c3:155-157` and `t_mailbox.c3:265` do exactly that, and the only
helper spelling available to them is `MSG.linked(MSG.look(inner))` — two
crossings for a yes/no, worse than the raw call. **Without the overload those
four sites would be exempted for a reason that is not a real one**, and `C-6`
would be wrong at four sites on its first use.

### C-5 — the two `src/` exceptions go, because their reason goes with them

`mailbox.c3:58` becomes `MBOX.inner((_Mbox*)p)` and `pool.c3:165` becomes
`POOL.inner((_Pool*)p)`. **The exception comments at `mailbox.c3:48-52` and
`pool.c3:160-164` are deleted** — `inner()` no longer writes, so there is
nothing to step around. What replaces the write at those two sites is a
read-only check that is gone in a release build.

**`queue.c3` and `pool.c3`'s six chain sites stay.** They are `C-6` white box by
necessity, and no stage looks for a way around them.

### C-6 — white box and black box, and this is the rule

**Ruled by the owner, 2026-09-10:**

> **If the source cannot do its functionality without accessing internals — and
> it is not a lack of support, as `linked` was — it continues to use internals:
> white box. Otherwise black box: use the wrappers.**

**The second clause is what makes it usable.** A site that cannot reach the
helper because the helper is *missing a member* is not white box; it is a gap,
and the stage that finds it **adds the member** (`C-4`) rather than writing an
exemption.

**It goes in both rules files.** `3tk-rules-005.md` gets it as **Rule 8**, at
the end of Part 1 after Rule 7, **written in Rule 6's voice** — defeasible by
subject, **a sentence at the site**, exemptions named. Stage rules 8-13 shift to
9-14. `3tk-example-rules-005.md` gets the paragraph `C-7` needs. **Rule 13
versions both without asking**; the superseded pair goes to
`matryoshka-3tk/design/backup/`.

**One wording trap when Rule 8 is written.** This plan is in
`design/secondary/`, which Part 5 freezes for the banned-word scan, so its own
prose is not held to the list. **`matryoshka-3tk/design/` is held to it** —
`3TK-73` fixed nine words in the two documents that crossed. **Rule 8 and the
`3tk-example-rules` paragraph are written clean under the Part 5 pattern**, and
several words this plan uses freely are on the list.

**No new script check, and the refusal is Rule 6's own:** *"A grep cannot tell
necessity from history; it would need an allow-list, and the allow-list would be
the judgment restated in a shell script, where a reader of the test never sees
it."* **That reasoning is exactly this rule's.** The `examples/` guard at
`run-builds.sh:305-313` survives because the examples rule is **absolute** — no
exemption at all, so a two-name allow-list is the whole judgment. **This rule is
defeasible, so the sentence at the site is the enforcement.**

### C-7 — the examples rule's promise, and who keeps it

`3tk-example-rules-005.md`, under *Every example leads with the helper*, says:

> **The exemption does not reach `test/`.** The tests probe the primitives on
> purpose, and all five methods keep callers there. **That is why an example may
> drop them without leaving anything unexercised.**

**`examples/` gave up `Slot.to`, `Slot.must`, `Slot.move`, `Inner.to` and
`Inner.as` on that promise.** A blanket sweep of `test/` would strip the last
callers off five public methods and break it without ever opening the file.

**Measured: all ten remaining callers are in `t_identity.c3`**, which is `C-6`
white box on its own subject. **The two rules agree and the promise holds — and
`3TK-76` writes that down in both files**, so the next stage to open
`t_identity.c3` finds the reason there instead of re-deriving it.

### C-8 — the two tests that assert the old behaviour

- **`t_helper.c3:263`** —
  `always_assert(JOB.inner(&j).outer_tid() == Job::typeid, "the crossing out did not stamp")`
  **asserts exactly what `C-1` removes.** It is rewritten as a `JOB.stamp(&j)`
  test: the subject was always that a hand-made outer gets its identity, and
  that is `stamp`'s job.
- **`t_helper.c3:195-215`**,
  `the_stamp_is_idempotent_and_safe_on_a_linked_outer`. **The test stays. Its
  doc block is narrowed to say single-threaded.** It proves the rebuild
  preserves `link.ptr` with nobody else touching it, which is true — and is not
  the concurrent claim the name appears to certify. **Leaving the wording is how
  a later stage talks itself back into a write.**
- **One new test**: `inner()` on an unstamped outer aborts in a safe build, on a
  wrong-typed outer too, and **passes `null` through.**

### C-9 — what these stages do not do

- **They do not narrow `stamp`** (`C-3`).
- **They do not touch `examples/`.** It was cleaned by `3TK-66`, it is guarded,
  and its three named exemptions — `010`, `012`, `013` — are already ruled.
- **They do not add a guard for `test/` or `negative/`** (`C-6`).
- **They do not uncomment the examples line in `docs.yml`.** That flag is the
  owner's and stays where `3TK-72` left it.
- **They do not renumber anything.**

## The stages

| stage | what it does | model |
|---|---|---|
| **3TK-75** | **The helper stops writing.** `inner()` verifies instead of stamping; `linked` gains its `Inner*` overload; the two `src/` exceptions go; two tests corrected and one added; the white-box rule written into both rules files. | **Opus 5** |
| **3TK-76** | **The sweep.** 113 sites in `test/` and `negative/` onto the helper, against `C-6`'s partition, exemplar first. | **Opus 5** |

**Why they are two.** Rule 10 puts the exemplar before the sweep; **this is that
shape one level up.** `3TK-75` changes what the helper *means* — `inner()` stops
writing and starts checking — and **113 sites must be rewritten onto a settled
surface, not a moving one.** A single stage would also hide the concurrency
change inside a diff of a hundred mechanical edits, which is where a
sanitizer regression goes unnoticed.

**Why Opus 5 for both.** Rule 9's basis is how much of the stage is deciding
rather than applying. **`3TK-75` is deciding almost throughout** — it contradicts
a standing ruling (`HS-10`), changes a concurrency-relevant write, and writes a
new port rule. **`3TK-76` looks mechanical and is not**: its value is `C-6`'s
partition, and `negative/` **punishes a wrong call silently** — a negative that
stops proving its violation still passes.

### Steps — 3TK-75

**1. `inner()` and its doc block.** `C-1` and `C-2`. Rewritten, not patched.

**2. The new test and the two corrections.** `C-8`. **The new test before the
`src/` change is visible in the figures**, so the abort is measured rather than
asserted.

**3. `linked`'s overload.** `C-4`.

**4. The two `src/` exceptions and their comments.** `C-5`.

**5. The rules.** `C-6` and `C-7`, both files, Rule 13 versioning.

**6. Close.** `run-builds.sh`, `check-doc-loop.sh`, `move-module-docs.sh
roundtrip`, **`run-sanitizers.sh` — which is the one that matters here**, the
stamp removal being a concurrency change. **The figures move in this stage** —
step 2 adds a test — and the new ones go into the status. Then Rule 11, the log
entry and the status row.

### Steps — 3TK-76

**1. The exemplar: `t_slot.c3`.** Rule 10. Eleven sites, one subject. **Rewrite
it whole and stop.** The ruling on it is what the sweep then applies.

**2. The partition, written before the sweep.** `C-6`. Every white-box site
named, **and each one gains its sentence** — not a reference to this plan and
not a mark, a sentence a reader of the test understands without leaving the
file. This is Rule 6's requirement and this rule inherits it.

**3. The sweep.** The conversions are:

| from | to |
|---|---|
| `inner::internal::to_inner(x)` | `X.inner(x)` |
| `inner::internal::from_inner(i, T)` | `T_.look(i)` |
| `inner::internal::must_from_inner` | `must_look` |
| `inner::internal::from_slot(&s, T)` | `T_.look(&s)` |
| `inner::internal::must_from_slot` | `must_look` |
| `inner::internal::move_from_slot(&s, T)` | `T_.take(&s)` |
| `inner::internal::is_linked(i)` | `T_.linked(i)` — needs `C-4` |

**White box, stays:** `src/queue.c3` (3) and `src/pool.c3` (3);
**`t_identity.c3`, and not all of it** — the border is its subject at `:48-52`,
`:117-118`, `:145-147`, `:219` and `:291`, while **`:173-176` and `:251` are
incidental and convert**; and **six negatives** where the bypass *is* the
violation — `unstamped_insert`, `unstamped_crossing` (both already Rule 6
exemptions), `overwrite_slot`, `wrong_type_must`, `nocompile_no_inner`,
`nocompile_two_inners`.

**Black box, sweeps:** `t_queue.c3`, `t_mailbox.c3`, `t_slot.c3`, `t_pool.c3`,
`t_concurrency.c3`, `t_identity.c3`'s six — and `negative/`'s
`insert_linked_outer`, `insert_twice_same_queue`, `self_move`,
`release_during_on_put`, `release_with_straggler_put`.

**4. `C-7` into both rules files.**

**5. Close.** **The figures must not move.** A sweep is a relocation stage and
**its proof is that every number is identical** to `3TK-75`'s closing set —
checks, builds, tests each, doc loop. **A sweep that changes a test count
changed a test.** Then Rule 11, the log entry and the status row.

## Not gaps, and nothing is owed

- **`is_mine` has no helper form**, and example `010`'s whole subject is that
  there is **no** crossing. `MSG.look(i) != null` is a different assertion.
- **`check_stamped`, `reset` and `inner_offset` have no helper form** and none
  is owed. They are `C-6` white box wherever they appear.
- **A non-stamping `inner()` is no longer a gap** — after `C-1` that is what
  `inner()` is.
