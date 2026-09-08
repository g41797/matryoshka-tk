# 3tk — status

**This file is read at the start of every stage and written at the end of one.
It is kept short for that reason.**

## The rule: what goes here, and what goes to the log

> **Status holds what has not happened, what is true now, and how to start.
> [3tk-log.md](3tk-log.md) holds what happened, when, and why.**

- **A stage ends by appending one entry to the log** — newest first — **and
  touching this file only where its state changed**: its own row, the measured
  numbers, the open questions.
- **If a sentence explains a decision, it is log.** If it tells the next session
  what to do, it is status.
- **A finished stage keeps a row here. It never keeps a section.** The narrative
  of what it found, argued and measured lives in the log entry and in whatever
  document the stage produced.
- **Nothing is duplicated between the two.** A fact that is in the log is not
  repeated here to be safe.
- **Ruled 2026-08-28**, after this file reached 2,358 lines by keeping a section
  per stage. It is now a list and a state, and the history it held was already
  in the log.

## What is live now

**The plan is [3tk-staging-plan-028.md](3tk-staging-plan-028.md), written
2026-09-07.** **026 and 027 are both spent and in `backup/`** — 027 ran no stage
at all: the docs-site reading and the four probes overturned its charter within
the same sitting that wrote it, so it was superseded rather than edited.
**Two stages have not run — `3TK-65`, then `3TK-66`** — and 028 holds their
charters. **`3TK-pre-65` ran on 2026-09-07 and closed.** **Nothing is
renumbered**, so `3tk-decisions-007.md` keeps every citation it has.

**`3TK-pre-65` ran on 2026-09-07 — the readable surface.** Six module names
again: `helper.c3` is `module mtk::helper <Outer>;` and `queue.c3` is
`module mtk::queue;`, reversing 3TK-63's merge. **`mtk` is 36 declarations on
the docs site, `mtk::helper` is the only generic page**, and both figures were
read off the generated page rather than predicted. **65 alias sites gained
`helper::` and the queue cost nothing** — C3 imports a module's submodules with
it, so `import mtk;` still gives `InnerQueue` unqualified, and the plan's
estimate of 47 sites counted references, not qualified ones.

**`inner.c3` is written in three parts, and the owner's test is what orders
them: a declaration is yours only if you have no other way to write it.** Part 1
is `Inner`, `Slot`, the Slot's five operations, `Inner.outer_tid` and the five
crossing methods; part 2 is the eight free crossings and the four chain
primitives, each carrying `// For internal usage.`, its `[3tk:]` marks and
nothing else; part 3 is `module mtk @private;` with `inner_offset`. **34
declarations across `src/` carry the marker and no `<* *>` block.**

**Ruled by the owner, 2026-09-07, against the stage's own first reading:
`Slot.to`, `Slot.must`, `Slot.move`, `Inner.to` and `Inner.as` stay in part 1**
even though `OuterHelper` could do them. The measurement is why — across
`examples/` the five are called **51 times and the helper's four crossings
zero**, the helper being reached for `create` (60) and `release` (78) alone.
**The helper is an allocator, not a door.** `outer_tid` is in part 1 for a
different reason: a dispatch switch reads an identity before it knows the type,
and a helper is bound to one type.

**One defect was introduced and one of the stage's own new checks caught it. A
`@require` lives INSIDE the `<* *>` block.** Stripping the block from
`mtk::must_from_inner` stripped its type check, and `negative/wrong_type_must`
stopped aborting in a checking build. **An internal declaration that has a
contract keeps a contract-only block — every line a `@` line, no prose** — and
`run-builds.sh` now asserts exactly that. **No stage tidies one away.**

**`run-builds.sh` is 81 → 89 checks, 0 failures, four builds, 143 tests each.**
Three checks were added: the six-name module list (`Part 4.5`, replacing the
two-name grep that would have gone red on this correct change), *no example
reaches past the helper* — with `010` and `012` listed as allowed rather than
silently skipped, and `test/` exempt as white-box — and *no declaration carries
the marker and a describing block at once*.

**The doc loop is clean: 4 labelled blocks, 0 differing, 418 of 418 sentences,
0 banned words, roundtrip byte-identical.** 510 → 418 is the fall the stage
exists to produce. `mtk::queue` is the new labelled block; `mtk::helper`'s
description is prose in the reference, because the doc-loop parser matches
`module X;` and a generic module line is not that shape.

**`@local` fits nothing in `src/` and it was probed:** with `@local`,
`inner.c3`'s own macros cannot resolve `inner_offset`. `@private` by section
default is the only lever, and Step 5 is closed.

**`3tk-reference-008.md` was edited in place and
`matryoshka-3tk/scripts/run-builds.sh` is tuned to match**, the `diff` being the
`ROOT` line alone. **The three `.yml` files needed no change.**

**Step 4 ran too, and the stage is complete.** `OuterHelper.release` was the
exemplar; the trim then took `OuterHelper`, `inner`, `stamp` and `create`.
**Nothing was deleted** — every sentence moved was already in the reference,
which a clean doc loop proves. What left the source is the argument: why the
carrier is a `typedef` over `uptr`, why the member is called `stamp` and not
`init`, why `create` returns `void?`. What stayed is what a caller needs at the
call site, `create`'s failure behaviour included — *"If `init` fails the outer
was never stamped."* **The rule is: the source says what, the reference says
why.**

**Four probes ran 2026-09-07 and are recorded in `3tk-boundaries-001.md` 4.2a
and 4.4a. Do not re-run them; do not design against the beliefs they replaced.**

1. **Methods cannot be hidden by any attribute.** `@private` **and `@local`**
   are both ignored, with the compiler saying so — *"'@local' modifiers are
   ignored for method declarations"* — and the call succeeding from another
   module. `Part 4.4` was right; the fourteen internal methods of `_Mbox`,
   `_Pool` and `InnerStack` **cannot** become `@local`.
2. **A separate module keeps `inner_offset` hidden.** So **3TK-63's merge was
   never needed**, and `Part 4.2` is re-ruled: `helper.c3` becomes
   `module mtk::helper <Outer>;` and `queue.c3` becomes `module mtk::queue;`.
3. **`c3c docgen` ignores visibility entirely** and groups by module alone.
   `@private` and `@local` declarations are published, `_Mbox`, `_Pool` and
   `InnerStack` among them **as public types**.
4. **The short module prefix works** — `alias MSG = helper::OF{Msg};` compiles,
   so the binding line does not grow.

**The rule that falls out, and it is the centre of the stage: the doc block is
the visibility marker.** A declaration that is not the user surface gets `//`
line comments and no `<* *>` block, **whether or not the compiler can hide it**
— the source loses seven paragraphs, the reference never receives it, and the
docs site shows a bare signature, which is the only *not for you* signal C3
offers. **The marker is one line: `// For internal usage.`** It does not say
"inner", because `Inner` is a type. The seven *"Public because C3 cannot hide a
method"* paragraphs are **withdrawn**; where a maintainer needs the reason, it
is stated **once per file** under the section banner.

**`OuterHelper` keeps its name** — it appears 13 times in `helper.c3` and in no
other `.c3` file, never qualified. **`InnerStack` stays as it is:** private
inside `mtk::pool`.

**`mtk` goes from 59 declarations to 36.** `run-builds.sh:215` asserts the module
list and **fails on this correct change** — it moves in the same pass, the trap
`Part 4.5` already warns about for the stack.

**Accepted gap, ruled 2026-09-07:** the names still appear. `_Mbox`, `_Pool` and
`InnerStack` stay listed on the docs site, **undescribed, not absent**. Docgen
has no visibility filter and no exclude flag. **No stage goes looking for a way
around it.**

It is a relocation stage, so **its proof is that every figure stays identical —
81 checks, four builds, 143 tests each** — with two deliberate exceptions: the
module-list check is rewritten for six names, and **the descriptor count falls
below 510** because internal declarations leave the reference.

**INTR on 2026-09-07 — the state came out of `OuterHelper`. Not a stage, and
nothing is owed.** The carrier is now

```c3
typedef OuterHelper = uptr;

const OuterHelper OF = {};
```

**`typeid outer_tid` is deleted.** It was written once and read by nothing, and
its removal makes the run-time identity check the doc block used to forbid
unwriteable. **`self` stays and is structural** — C3 has no static-method
facility and no namespace alias for a module instantiation, so a zero-state type
is the only way a generic module offers members under one bound name.

**`struct OuterHelper {}` is not available:** c3c 0.8.3 answers *"Zero sized
structs are not permitted."* The `typedef … = uptr` spelling is the standard
library's own, from `LibcAllocator` and `NullAllocator`. **A later reader who
wonders why the carrier is a `uptr` is answered in the doc block, and must not
try the empty struct again.**

**Nothing at the surface changed** — the nine member bodies never referenced
`self`, and all 65 alias sites and every call are byte-identical. **The figures
are 3TK-64's, unchanged: `run-builds.sh` green at 81 checks, four builds, 143
tests each.** The doc loop is clean at **510 of 510** sentences, 0 differing
blocks, 0 banned words; 509 → 510 is the one rewritten block.

`3tk-reference-008.md`'s helper paragraph is rewritten to match and **is already
in `matryoshka-3tk`**, since design documents are edited there directly.
**`src/helper.c3` joins the batch the owner has yet to copy.** No script and no
`.yml` needed a change: nothing in either names the field or the struct keyword,
and CI builds and tests the same way it did.

**3TK-64 ran on 2026-09-07 — `OuterHelper`, and the end of *managed*.** It is
plan 026's third build stage and the one where semantics change. `helper.c3` is
**`module mtk <Outer>;`**, carrying `OuterHelper` and `const OF` (built with a
`typeid` field, which the INTR above removed); a user binds
`alias MSG = mtk::OF{Msg};` and calls nine members. **Both spellings are
superseded by 3TK-pre-65: the module is `mtk::helper <Outer>` and the binding is
`alias MSG = helper::OF{Msg};`.** **`managed.c3` is deleted**,
`required_alloc_offset` with it, and **the word *managed* survives in no name.**

**`run-builds.sh` is green — 81 checks, four builds, 143 tests each.** 89 → 81
because **two compile-time negatives were retired** (four builds apart):
`nocompile_managed_no_allocator` and `nocompile_managed_two_allocators`
asserted a concept that no longer exists, and both shapes must now compile and
run. **Their proof is positive and lives in `test/t_helper.c3`**, which
replaced `t_managed.c3`. 134 → 143 tests for the same reason.

**`create` and `release` take the allocator and are helper members.** `create`
allocates zeroed, calls the outer's optional `init(a)` hook, **stamps after the
hook** so a failed creation leaves nothing stamped, and fills the Slot;
`release` calls the optional `destroy(a)`, empties the Slot and frees. `release`
returns `void`, so it needs no `!`, no `!!` and no cast in a `defer`.

**Three things this stage decided that the documents left open, all three in
the log:**
- **`mtk::init` is now `mtk::stamp`**, at about sixty call sites. `Part 3.3`
  named the *member* `stamp`; leaving the macro called `init` would have put
  two opposite meanings on one word in one module, since `Msg.init(a)` is now
  the user's hook.
- **An alias is per-module ceremony**, and c3c forces it: *"Aliases from other
  modules must be prefixed with the module name."* A shared alias in
  `outers.c3` buys nothing, so **each example module carries its own one-line
  alias per outer type**, and `outers.c3` says why where they used to be.
- **`_Mbox` and `_Pool` took their `@private` alias** — `alias MBOX @private =
  mtk::OF{_Mbox};`, the attribute before the `=` — **except `to_inner`**, which
  keeps the read-only macro. The helper has no non-stamping way out of an
  `Outer*`, and that direction is crossed concurrently. Both sites say so.

**About forty `release` sites had no allocator in scope** and each was given
one honestly — a parameter on a local helper, a field on a thread's context
struct, `self.alloc` in a hook object, `mem` in `test/`. **No site was given an
allocator it was not created with.** `Event`, `Sensor` and both `Holder`s keep
their `Allocator` field and now fill it in an `init` hook of their own, so the
hook path is exercised by every example.

**The doc loop is clean — 3 labelled blocks, 0 differing, 509 of 509 sentences,
0 banned words, `move-module-docs.sh roundtrip` byte-identical.**
`3tk-reference-008.md` was edited in place: the `mtk::managed` labelled block is
a four-line gravestone, *The API — allocating an outer for you* is replaced by
**The API — the helper**, and *The API — identity* documents `stamp` and
`Inner.outer_tid`. **Parts 1 to 7 still spell `managed::create` in their prose
and worked examples — that is 3TK-66's charter, and the new section says so in
its first lines.**

**`matryoshka-3tk/scripts/run-builds.sh` is tuned to match**, and the `diff` is
the `ROOT` line alone. **The three `.yml` files needed no change**, though the
first version of this file gave a wrong reason: **nothing in CI runs that
script.** `linux.yml` re-implements build and test inline across a four-leg
matrix.

**Ruled by the owner, 2026-09-07: CI is the matrix, and the matrix is enough.**
Every failure shows as its own leg. **The negatives and the layering greps are
deliberately outside CI and stay hand-run** — an accepted gap, not an oversight.
**No stage proposes moving `run-builds.sh` into CI.** The `scripts/` copy is
still carried across every stage, because it is run by hand there.

**Three dead files were removed from `matryoshka-3tk` with a plain `rm`** —
`test/t_managed.c3` and the two `negative/nocompile_managed_*.c3` — because a
copy adds files and never deletes them, and `t_managed.c3` would have failed
`c3c test` on all four legs.

**`3tk-decisions-007.md` is folded and 3TK-64 owes it nothing.** `RT-3`, `RT-5`,
`RT-6` … `RT-10`, `RT-12` … `RT-18` and `HR-5` are in the body; **the parked
section holds no live ahead-of-the-source decision**, only `RT-1`, the `MS-1`
measurements and four entries marked RULED or DISCHARGED. Two stale things were
corrected in the fold: the `3TK-65` heading was plan 025's numbering, and the
field ruled as `otrid` was built as **`outer_tid`**.

**The restore was skipped on the owner's ruling and is not owed by anyone.**
189 of the 222 changed lines were the botched renumbering, 21 citations name the
now-deleted `managed.c3`, and **3TK-66 re-anchors all 222 from the built tree in
one pass.** The file's header says so and tells a reader to treat any citation
older than 3TK-64 as naming a file, not a line. `reapply_decisions.py` is spent
and need not be run.

**Not yet copied to `matryoshka-3tk`'s `src`/`test`/`negative`/`examples`, or
pushed** — that is the owner's step.

**3TK-63 ran on 2026-09-07 — the merge into `mtk`, and plan 026's second build
stage.** `inner.c3` absorbed `helper.c3`'s crossing macros and declares
`module mtk;`; `queue.c3` declares `module mtk;`; `helper.c3` is **emptied and
kept**, and 3TK-64 refills it as `module mtk <Outer>;`. **Eight module names are
four.** `mtk::inner`, `mtk::helper` and `mtk::queue` are gone as names, and
`InnerQueue` is `mtk::InnerQueue` at every user site.

**`run-builds.sh` is green — 89 checks, four builds, 134 tests each, identical
to 3TK-62 in every figure.** That identity is the whole proof of a relocation
stage, and it holds.

**`inner_offset` is `@private` and it was probed, not assumed** — a foreign
module calling it now fails to compile, while `mtk::pool` and `mtk::mailbox`
still expand the crossings, because a macro body resolves against its defining
module. **`reset` and `is_linked` stay public**, as `Part 4.3` predicted, and
carry the *"public because"* line. **Two tests stopped reaching for
`inner_offset`** and read the offset through `to_inner` instead; no test was
lost or added.

**Two deviations from the documents, both deliberate and both in the log.**
*One:* `Part 4.4`'s unhideable-method line is **not** written onto `Slot`'s
methods — it ends *"not part of the user surface"*, and `examples/` calls
`.fill` 34 times. `Slot` is public by intent, not by the language's failure.
*Two:* `required_alloc_offset` was **moved into `managed.c3` as `@local`**, not
deleted: plan 026 said it has no caller *"once `managed.c3` goes"*, and
`managed.c3` goes in **3TK-64**. The concept leaves the core here and leaves the
codebase there.

**`run-builds.sh` changed by exactly one string.**
`NOCOMPILE_EXPECT[nocompile_managed_no_allocator]` was `mtk::helper`, a module
this stage abolished; it is now `Plain`, the type name, as the other three
compile-time negatives already were. **The check count did not move.**

**The doc loop is fully clean for the first time — 4 labelled blocks, 0
differing, 476 of 476 sentences, 0 banned words, and `move-module-docs.sh
roundtrip` byte-identical.** `PL-10` is closed, and the status file was right
that it was five lines and a block, not one sentence.

**Both doc-loop scripts learned a rule and 3TK-64 onward depends on it: a module
has one description however many sections it is written in.** The carrier is the
file with a `<* *>` above its module line; the others carry a `//` banner.
`check-doc-loop.sh` reports those as *section only, no block* and asserts every
labelled block is carried by **exactly one** file; `move_module_docs.py` stops
with an error on two carriers. Without that second guard it wrote the merged
`mtk` block into `queue.c3`, purely on alphabetical order.

**`3tk-reference-008.md` was edited in place again**, under the ruling that
covered 3TK-62. The three absorbed blocks are inside `mtk`'s, the module table
shows one module over three files, and a new subsection under *The API — the
link* — *"Public, and why"* — states the visibility rule the source repeats.

**`matryoshka-3tk/scripts/run-builds.sh` is tuned to match** — one line, the
same expectation string. The two repos' copies now differ only in the `ROOT`
line that is meant to differ. **The doc-loop scripts have no copy in that repo.**
**The three `.yml` files needed no change**, same reason as 3TK-62.

**Until the owner copies `src/` and `test/`, that repo's `run-builds.sh` still
reports the one FAIL 3TK-62 left** — *"src/pool.c3 has no stack banner"* — and
it clears with the copy.

**WITHDRAWN by the owner, 2026-09-07 — the restore this stage asked for is not
owed and will not be run.** It said `3tk-decisions-007.md` had to be restored
with `git checkout --` and the three intended edits re-applied with
`reapply_decisions.py`. **3TK-64 measured the pending change and the owner ruled
it not worth the command:** 189 of the 222 changed lines were nothing but the
botched renumbering, 21 citations name `managed.c3`, which 3TK-64 deleted, and
**3TK-66 re-anchors all 222 from the built tree in one pass** — which overwrites
whatever the numbers say, restored or not. `reapply_decisions.py` is spent.

**What happened is still worth knowing.** A fourth thing was attempted here and
should not have been: re-anchoring the file's citations into the three moved
files. It ran in three passes, and the third matched on old line numbers and
overwrote what the first two had already corrected — many-to-one, so not
reversible from the file. **The renumbering is not retried by any stage but
3TK-66**, and `007`'s own header now warns a reader to read a citation older
than 3TK-64 as naming a file, not a line.

**Not yet copied to `matryoshka-3tk`'s `src`/`test`/`negative`, or pushed** —
that is the owner's step.

**3TK-61 ran on 2026-09-06 and changed no code.** It was declared in plan 024 as
one subject — `managed.c3`'s `Allocator` field — with the clause *"a **62** if it
turns out structural."* It turned out structural. The owner expanded it into a
general rethinking of the core's shape and ruled most of it, and **the stage
ended as an analysis: no `src/` change, `run-builds.sh` re-measured green and
unchanged.**

**Everything it settled is in
[matryoshka-3tk/design/3tk-boundaries-001.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-boundaries-001.md)**,
written by id — `RT-n` a ruling, `HR-n` a helper requirement, `PL-n` the parking
lot, `MS-n` a measurement. **A later stage cites an id; it does not re-argue the
point.** The building was ordered by
[026](backup/3tk-staging-plan-026.md) as **3TK-62 … 3TK-66**; **028 carries the
two that have not run** and inserts `3TK-pre-65` ahead of them. **024 through 027
are spent and in `backup/`.**

**The headline rulings, in one paragraph.** `OuterHelper` becomes a **first-class
citizen** — `struct OuterHelper { typeid otrid; }`, in `helper.c3`, module
`mtk::helper`, forwarding to the crossing macros, which move into `inner.c3`.
**`stack.c3` becomes private** at the end of `pool.c3` and `t_stack.c3` is
deleted, **reversing 3TK-45**. **`managed.c3` leaves the core** into module
**`xtn`** under `3tk/extensions/`, and **the word *managed* survives in no
name**. **`create` and `release` take the allocator**; the `Allocator` field in
an Outer becomes **optional**, for the Outer's own allocations. Governing all of
it: **an Outer is a long-lived heap object, and a user who does otherwise pays.**

**Two measurements were run and one overturned a claim.** `MS-1`: across the 52
`examples/` files the user's whole vocabulary is six spellings — `release` 78,
`create` 61, `.must(` 26, `.to(` 25, `.move(` 4, `.as(` 4 — and **`init` is
called zero times**, because `create` does it. Users reach for the **method**
forms, **59 sites to 8**, almost always on a Slot. `MS-2`: **C3 has no struct
default field initializers**, but `alloc::new_try` **already zeroes** when given
no `#init`, so the claim that 3tk's `create` leaves the outer undefined was
false and is recorded closed.

**`3tk-decisions-007.md` was written and `006` is in
`matryoshka-3tk/design/backup/`.** It carries a new section — *"Ruled by
3TK-61, decided and not yet built"* — because a stage that changed no code has
decisions with no `file:line` to cite, and the file's own rule forbids it from
contradicting `../3tk/src`. **Each build stage folds its own entries into the
body with real `file:line` and deletes them from that section;** when the
section is empty the rethinking is built.

**3TK-61 had a second sitting the same day, and again changed no code.** The
owner asked for the first of those three points — the helper's shape — to be
**proposed** rather than left as a question, then asked two further questions
that turned out structural. The result is
`3tk-boundaries-001.md` **sections 10-15** and **`MS-6` … `MS-9`**, and new
ids: **`HS-n`** a proposed element of the shape, **`V-n`** a variant, **`Q-n`**
a question. `001` and `002` are in `matryoshka-3tk/design/backup/`.

- **Sections 10-12 — the shape.** Nine members in three groups plus two in
  `xtn`, which embeds the base helper `inline` so **one alias still reaches all
  ten**. `HR-5` is discharged by `HS-10`: `inner()` stamps the identity
  idempotently, writing `.type` only, which is safe on a **linked** inner.
  Five variants, each with a recommendation and a named fallback. **`MS-4` and
  `MS-5` are owed, not run**, and `Q-5` pre-answers the case where `MS-5`
  fails so a probe cannot stall 3TK-65.
- **Section 13 — how the internals stay internal.** `MS-6`: **`@private`
  reaches the module and nothing else** — not a submodule, not the parent, and
  C3 has no package or friend visibility. So the only lever is which symbols
  share a module. `MS-7` probed the shape and it ran. **The mailbox and the
  pool are already clients of the helper** — `_Mbox` and `_Pool` are Outers,
  crossing at six sites — so **`PL-7` becomes a precondition, not a
  preference**. `queue.c3` joins for free.
- **Section 14 — how the outer's fields are found.** `MS-9`: matching on the
  **name** works, with a default macro parameter, and the failure message names
  the fix. The allocator half lets an outer keep **two** allocators, which
  `RT-12`/`RT-13` already imply it should be allowed to.
- **Section 15 — how it is used**, written against
  `examples/006-defer_put_early.c3`. The user's ceremony is **one alias**, and
  the mailbox and the pool do exactly the same thing on a `@private` alias
  each. **The user's surface and mtk's own surface are the same surface.**

**`MS-8` corrected the document seven times: `Outer.typeid` does not compile
anywhere.** The spelling is **`Outer::typeid`**.

**Three rulings are re-opened by the proposal and no stage may assume any of
them:** `RT-3`'s module name (`Q-10`), `RT-11`/`PL-7` (`Q-11`), and `RT-13`'s
*found twice is an error* (`Q-14`). **`Q-6` is answered** — `init` has two
mtk-internal callers, `mailbox.c3:95` and `pool.c3:193` — unless the owner
rejects the reasoning in 15.5.

**The three points are now fifteen questions, `Q-1` … `Q-15`, and every one of
them is smaller than the three were.** They are listed in section 12 of the
rethinking document and none of them is a stage's to assume.

**3tk has exactly two terms: `Inner` and `Outer`. There is no third.**
**3TK-60 ran on 2026-09-04.** `Inner` is a real C3 type and the field you lend;
`Outer` is a role and the struct you own. **The words *handle* and *item* are
retired** — from `src/`, `test/`, `negative/`, `examples/` and every book —
and so is **`node`**, which named the embedded field and was a third term in
the same position. The crossings are `to_inner` / `from_inner` /
`must_from_inner`; an `Inner*` parameter or local is named **`inner`**, spelled
in full; the embedded field is `Inner inner;`. `Slot` is untouched: a real type
naming a container state, not a participant.

**Two owner rulings inside the stage.** *One:* `inner`, not the plan's `n` and
not an abbreviation — the pair must be spelled symmetrically, and `inner` does
**not** collide with the module `mtk::inner` (measured on c3c 0.8.3; C3 keeps
module paths and value identifiers in separate namespaces). *Two:* the field
`node` was ruled in, though plan 024 did not scope it.

**This supersedes 3TK-59, which kept *handle* as an English word.** Both
rulings are entries in
[matryoshka-3tk/design/3tk-decisions-007.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-decisions-007.md),
where dtk will read them. The live decision is stated in
[3tk-terms-001.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-terms-001.md),
which **stays live until 3TK-66** — its section 5 is superseded by
[3tk-boundaries-001.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-boundaries-001.md),
and the two are spent together.

**A rename must move nothing, and it moved nothing.** `run-builds.sh` is green
— **87 checks, 0 failures, four builds, 140 tests each, identical to 3TK-59.**
`check-doc-loop.sh` is **0 differing blocks, 471 of 472 sentences, 0 banned
words** — better than the plan allowed, because `move-module-docs.sh out`
closed the standing `managed.c3` `DIFFERS` block and one of the two missing
sentences on its way past.

**Not yet copied to `matryoshka-3tk`'s `src`/`test`/`negative`/`examples`, or
pushed** — that is the owner's step. The design documents were written directly
in `matryoshka-3tk/design/`.

**`Mailbox` and `Pool` are opaque types.** **3TK-58 ran on 2026-09-03**:
both became `typedef ... = void;`, with the real fields in `@private`
`_Mbox`/`_Pool` structs; every method casts on its first line. New public
`is_quiet()` on both replaced five direct `_active` reads across
`t_mailbox.c3`/`t_pool.c3`, and `t_concurrency.c3`'s
`the_deadline_is_anchored_once` was dropped — no black-box way to provoke a
spurious wakeup once `_cv` is unreachable. `run-builds.sh` is green (87
checks, four builds, 140 tests each) and `check-doc-loop.sh` was clean against
`3tk-reference-006.md`, since superseded by `007`, but for the same two
pre-existing gaps that predate that stage. See the log entry for the full
account. **Its `src`/`test` changes are not yet copied to `matryoshka-3tk`
or pushed either** — that is the owner's step; the reference doc itself was
written directly in `matryoshka-3tk/design/`, per that session's ruling.

**`P6` is built.** **3TK-56 ran on 2026-08-30**: `on_close` takes the queue by
value, `InnerQueue.take()` is in `queue.c3`, both `pool.c3` call sites use it,
and `3tk-open-defects.md` has no open row left. Only **3TK-50** — the examples
tree, independent of the fix — has not run.

**Before 3TK-50 could start, the owner reviewed the pattern catalog and ruled
a defect in it: a stack outer is illegal, not only across a mailbox or thread
boundary.** 3tk computes an outer's address from its embedded `Inner` at every
crossing, and a stack address is valid for exactly one lexical instance of one
frame — a copy, or a use after the frame returns, reaches through a stale
address, and it can appear to work before it fails. **This closed a Stage A,
2026-08-31**, ahead of 3TK-50: the reference book, the pattern catalog and the
example rules were revised — the one stack-outer example in each was replaced
with a heap outer — and republished as new versions in a second local repo,
[`matryoshka-3tk/design/`](https://github.com/g41797/matryoshka-3tk/tree/main/design),
which the owner is also using for light builds and doc-site preview. The old
versions moved to `backup/` here, and every live cross-reference in this repo
now points at the new location. **3TK-50 starts from the corrected documents.**

**The lifetime fix is built, on both tools, and its books are closed.** **The
mailbox by 3TK-53 and the pool by 3TK-54, both 2026-08-28**; each `release` now
checks `_closed && _active == 0` under the mutex and aborts in all four builds
when it does not hold. **3TK-55 closed the defect row on 2026-08-28** and
re-measured everything against the built tree.

**And the shared half is written too.** **3TK-52 wrote
[../common/matryoshka-specification-005.md](../common/matryoshka-specification-005.md)
on 2026-08-28**, after the owner ruled `Q-D`. `Part 11.12` is now *Closed and
quiet before release*, `004` is in `common/backup/`, and every live link points
at `005`. **The lifetime fix is complete, in code and in text.**

**The owner ruled it on 2026-08-28:**

> **Release while a call is in flight is not prevented. It is written down as a
> thing the caller must not do, and it is checked. It is not waited for.**

**[3tk-lifetime-fix-005.md](3tk-lifetime-fix-005.md) bound 3TK-53 and 3TK-54 and
has now been built.** Three review rounds are absorbed into it and **reviewing of
it is closed.** Section 4 is the ruling and the text it owes; section 15 is what
the ruling closed. **The one thing it asked for and did not decide — what the
added lock in `Pool.get` costs — is measured in the log's 3TK-54 entry.**

**Where [3tk-staging-plan-020.md](3tk-staging-plan-020.md) disagrees with it, the
document wins.** The plan is published and is not edited in place, so its 3TK-53
charter still says `release(InnerQueue* out)` and *the `always_assert` removed*.
**Both are wrong**: no signature changes, and the assertion is **rewritten**, to
check `_closed && _active == 0`.

**And two places where the document lost, both settled by 3TK-53 and both
settled the same way by 3TK-54:**

- **`release` does not call `_close`.** Section 2 says it does *if the tool is
  still open*; section 13 says `negative/release_open_pool.c3` must still abort.
  Both cannot hold. **The check comes first, and nothing else runs when it
  fails** — so `_close` has one caller in each tool, not two.
- **`Part 11.12` belonged to 3TK-52, not to the code stages.** It is in
  [../common/matryoshka-specification-005.md](../common/matryoshka-specification-005.md)
  and binds four ports. **A code stage wrote the rule into `ref/` and the
  descriptors and left the shared clause alone.** That is what let 53 and 54 run
  while `Q-D` was open, and **3TK-52 has since written the clause itself.**

## The stages that have not run

| stage | what it does | start it with |
|---|---|---|
| **3TK-50** | **The examples tree**, plan 019's leftover and the first code under `3tk/examples/`, run in steps grouped by catalog section. Reads [3tk-example-rules-003.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-example-rules-003.md) and [3tk-patterns-003.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-patterns-003.md), both in `matryoshka-3tk/design/`. **Independent of the fix. Steps 1 through 11 ran 2026-08-31 — every catalog section with a code shape is now covered.** The catalog's two remaining sections, "The 18 that dropped" and "What this document does not do", write no code (a table of ztk entries with nothing to port, and a closing note) — **there is no step 12.** | **3TK-50 has no next step. Ask the owner what closes it** — copying and pushing the last steps to `matryoshka-3tk`, and updating this table, are what remain. |
| **3TK-65** | **The safe-build checks.** The idempotent stamp; the identity check at the crossing and at both `@guard_insert`s, all `$if env::COMPILER_SAFE_MODE`-gated so a fast build carries nothing. Discharges `HR-5`. Reads Boundaries `Part 5.1` … `5.3`. | **Next.** *How to start after a clear* carries the detail 3TK-pre-65 left it: `mtk::stamp` is in part 2 of `inner.c3` with a contract-only block, `OuterHelper.stamp`/`.inner` are its two callers, and `@guard_insert` is in `mtk::queue` and in `pool.c3`'s stack section. |
| **3TK-66** | **The books and the examples.** The bulk, last, as in 3TK-60: everything leads with the helper, all 52 examples use it. Run in steps by catalog section. Boundaries `Part 6` is written in as its own short section. **Its closing act spends `3tk-boundaries-001.md` and `3tk-terms-001.md` to `matryoshka-3tk/design/backup/`, and deletes Appendix B — that deletion is the proof the `007` repair finished.** | After 3TK-65. |

**3TK-52, 3TK-53, 3TK-54, 3TK-55 and 3TK-56 all ran, 2026-08-28 to
2026-08-30**, and between them the two tools carry the mechanism, the defect
list agrees with them, the shared specification states the rule and `on_close`
is by value. **3TK-50 is the only stage left, and it does not block or get
blocked by anything above.**

**3TK-50 step 1 ran 2026-08-31**, catalog section "Slot and transfer idioms."
`3tk/examples/` now exists: `outers.c3` and `helpers.c3` are the shared
infrastructure, and nine files carry entries 1 and 3 through 10 (entry 2 has
no code shape). `test/t_examples.c3` wraps all nine, and `project.json`'s
`test-sources` gained `"examples"`. The log entry has the one finding worth
keeping: a leak in entry 3's own example, from discarding the queue
`Mailbox.close` gave back, which entry 30 itself warns against.

**3TK-50 step 2 ran 2026-08-31**, catalog section "Crossing the border."
Five more files carry entries 11, 12, 13, 15 and 16 (entry 14, "Stack outers
are illegal", has no code shape — its prohibition is why every outer in this
section and the last is heap-allocated). Two build errors surfaced only by
`run-builds.sh`: a standalone `!catch` is not legal c3c 0.8.3, and
`foreach (i : usz[3])` does not enumerate. Both are in the log entry.
`run-builds.sh` is green — 87 checks, four builds, 106 tests each. **Not yet
copied to `matryoshka-3tk` or pushed** — that is the owner's step.

**3TK-50 step 3 ran 2026-08-31**, catalog section "Dispatch". Four more files
carry entries 17 through 20 (entries 21 and 22 have no code shape — the last
branch rule and a diagram — so neither has a file). One build error surfaced
only by `run-builds.sh`: the catalog's entry 18 code shape still has
`on_close` taking `InnerQueue*`, the signature from before 3TK-56 made the
hook take the queue by value; the example was corrected, the catalog was not
— it lives in `matryoshka-3tk` and this stage only writes `examples/`.
`run-builds.sh` is green — 87 checks, four builds, 110 tests each. **Not yet
copied to `matryoshka-3tk` or pushed** — that is the owner's step.

**3TK-50 step 4 ran 2026-08-31**, catalog section "The infrastructure is an
outer too". Four more files carry entries 23 through 26 — every entry in this
section has a code shape, so all four got a file. One build error surfaced
only by `run-builds.sh`: entry 26's no-op hooks struct had no fields, and c3c
refuses a zero-sized struct; it was given one unused `bool` field. `run-builds.sh`
is green — 87 checks, four builds, 114 tests each. **Not yet copied to
`matryoshka-3tk` or pushed** — that is the owner's step.

**3TK-50 step 5 ran 2026-08-31**, catalog section "Mailbox patterns". Six
more files carry entries 27 through 32 — every entry in this section has a
code shape, so all six got a file. One defect found before any build ran:
entry 31's first draft called `send` on a mailbox already released, a
use-after-free, fixed by releasing only after the refused send is checked.
One build error surfaced only by `run-builds.sh`: entry 32's `Atomic{bool}`
needed `import std::atomic::types` written explicitly, since nothing else in
that file pulls it in the way `mtk` does elsewhere. Entry 32 is the section's
only example with a real second thread, following `t_concurrency.c3`'s
`Thread`/`thread::sleep` shape. `run-builds.sh` is green — 87 checks, four
builds, 120 tests each. **Not yet copied to `matryoshka-3tk` or pushed** —
that is the owner's step.

**3TK-50 step 6 ran 2026-08-31, out of catalog order: the wrapper rule made
explicit, and the two wrappers that already broke it.** The owner asked for
the "no logic of its own" rule for `test/t_examples.c3` wrappers to be
written down explicitly and for the tree to be checked against it before
going further. [3tk-example-rules-003.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-example-rules-003.md)
now spells out that a wrapper may create and tear down shared infrastructure
but must not touch a `Slot`, a `Handle` or an `InnerQueue` itself. Checked
against every wrapper written by steps 1 through 5: two violated it —
`test_example_insert_from_slot` drained and released a queue itself, and
`test_example_reach_into_a_full_slot` received and released a Slot itself.
Both moved into their example functions (`004-insert_from_slot.c3` and
`016-reach_into_a_full_slot.c3`), and both wrappers are now call-and-assert.
`run-builds.sh` is green — 87 checks, four builds, 120 tests each, unchanged
in count since no test was added or removed. **Not yet copied to
`matryoshka-3tk` or pushed** — that is the owner's step.

**3TK-50 step 7 ran 2026-08-31**, catalog section "Topology patterns", entries
33–36. Four more files carry entries 33 through 36 — none says *no code
shape*, so all four got a file, composing the mailbox calls entries 27–32
already established with real threads: `033-request_response.c3`,
`034-pipeline.c3`, `035-fan_in.c3`, `036-fan_out.c3`. No build error, the
first step since step 1 with none. `run-builds.sh` is green — 87 checks, four
builds, 124 tests each. **Not yet copied to `matryoshka-3tk` or pushed** —
that is the owner's step.

**3TK-50 step 8 ran 2026-08-31**, catalog section "Pool patterns", entries
37–45. Six of the nine entries carry a code shape and got a file — 37
`AVAILABLE_OR_NEW`, 38 `NEW_ONLY`, 39 `AVAILABLE_ONLY`, 40 seeding a
fixed-size pool, 42 the hook object is the context, 45 a pool of several
identities (reusing entry 18's `CreateByIdentityHooks` rather than writing a
second one); entries 41, 43 and 44 have no code shape of their own and got
no file. Two defects, found before any build ran and by a build error: 45's
first draft called a `Handle.identity()` method that does not exist, fixed
to read `h.link.type` the way entry 17's dispatch chain does; 40's first
draft returned a fault with `?`, some other language's operator, fixed to
`~`. `run-builds.sh` is green — 87 checks, four builds, 130 tests each. **Not
yet copied to `matryoshka-3tk` or pushed** — that is the owner's step.

**3TK-50 step 9 ran 2026-08-31**, catalog section "Shutdown", entries 46–48.
One of the three entries carries a code shape and got a file — 46, reading
the fault on a receive — the other two do not: 47 is a numbered order plus
prose, 48 is an ASCII diagram, same precedent as entries 21 and 22. One
approach tried and found wrong before any build ran: calling `wake_all`
before a receiver blocks does not produce `WOKEN`, because `_wake_gen` is
snapshotted only once a receive starts waiting — the file follows entry 32's
`Thread`/`Atomic{bool}` shape instead, blocking a receiver first and waking
it from the main thread once it has parked. `run-builds.sh` is green — 87
checks, four builds, 131 tests each. **Not yet copied to `matryoshka-3tk` or
pushed** — that is the owner's step.

**3TK-50 step 10 ran 2026-08-31**, catalog section "Coordinator patterns",
entries 49–53 — **the section runs through entry 56, not 49; step 10's own
log entry first covered only 49, and a later correction (below) added
50–53 after the owner asked where they were.** Five files:

- **49, The coordinator.** `049-the_coordinator.c3`, the catalog's
  `Master`/`run` shape verbatim: `seed_the_work`, `process_the_work` and
  `shut_down` are named steps, `shut_down` follows entry 47's order for a
  mailbox and a pool together.
- **50, The step.** `StepMaster.seed_the_work`/`process_the_work` kept
  verbatim; `process_the_work` is `wake_all` alone.
- **51, Acquiring the resources.** `master_create` shows `mbx` and `pool`
  as plain pointers, never a Slot to unwrap.
- **52, Releasing the resources.** `Master.shut_down`, reverse acquisition
  order, allocation freed last.
- **53, The thread is given one pointer.** `WorkerCtx` carries a `target`
  count rather than trusting `Mailbox.close` to end the worker's loop.

Entries 54, 55 and 56 have no `c3` block — bullets, bullets, an ASCII
diagram — and got no file, same precedent as every other bulleted or
diagrammed entry. Two defects, both in entries added by the correction:
49's wrapper bound `Holder::typeid` to `test/common.c3`'s `Holder` rather
than `exm::outers::Holder` — the two share a name and the wrapper's module,
`mtk_test`, sees both — fixed by qualifying it as
`exm::outers::Holder::typeid`; 52's first draft asked `AVAILABLE_OR_NEW`
for a second outer expecting it distinct from the one just put back, but
that mode reuses what is free first, so the pool's own remainder at close
was empty — fixed by asking `NEW_ONLY` for the second. `run-builds.sh` is
green — 87 checks, four builds, 141 tests each. **Not yet copied to
`matryoshka-3tk` or pushed** — that is the owner's step.

**3TK-50 step 11 ran 2026-08-31**, catalog section "New, and 3tk-only",
entries 57–62 — the six shapes with no ztk entry behind them (entry 42 is
here too and already has its file, from step 8). Five got files; 62 is two
bullet lists with no `c3` block, same precedent as 21, 22, 41, 43, 44, 47,
48, 54, 55 and 56. Entry 61's `on_close` took the queue by value, not the
catalog's stale `InnerQueue*` — the same correction step 3 made for entry
18. Two module names exceeded c3c's 31-character limit and were shortened
from the file's own title: `exm::identity_costs_nothing` and
`exm::composite_outer_gives_back`. **This was the last step: every catalog
section with a code shape now has one.** `run-builds.sh` is green — 87
checks, four builds, 141 tests each, once step 10's correction is folded
in. **Not yet copied to `matryoshka-3tk` or pushed** — that is the owner's
step.

## Open questions

| | what it asks | whose |
|---|---|---|

**Nothing is open in the lifetime-fix / `P6` set.** `Q-A`, `Q-B`, `Q-C`, `Q-E`
and `Q-G` were closed by the ruling of 2026-08-28 —
[3tk-lifetime-fix-005.md](3tk-lifetime-fix-005.md) section 15 says how each
went. `Q-D.1` and `Q-D.2` were ruled on 2026-08-28 and 3TK-52 built both
answers, so section 14 of that document, which still lists `Q-D` as open, is
out of date and this file is what holds. **`P6` / `Q-F` was ruled on
2026-08-28 and built by 3TK-56 on 2026-08-30.**

**And these, which are not about the lifetime fix.** One line each; the document
named holds the reasoning.

- **`Q-1` … `Q-15`, the rethinking's, and they gate 3TK-63, 3TK-64 and
  3TK-65.** Not repeated here: **section 12** of
  [3tk-boundaries-001.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-boundaries-001.md)
  is where they are asked and where they are answered, each with the variant
  and the recommendation beside it. Three of them re-open a ruling — `Q-10`
  (`RT-3`'s module name), `Q-11` (`RT-11`/`PL-7`), `Q-14` (`RT-13`'s *found
  twice is an error*) — and `Q-6` is already answered by 15.5. **Whose:** the
  owner's, all of them.
- **Two port defects, and they are the only ones.** **P3** — a waiting call can
  return the condition variable's own fault, outside Part 19's outcome set;
  unreachable on the current posix backend, recorded because the next port copies
  the shape. **P4** — Part 2.6 MUST: the pool's leaver signals on one bucket over
  a condition variable shared by *n*. Nothing is lost today, because every path
  that makes an item available calls `broadcast`. **Both `3tk-only`, neither
  ruled.** [3tk-deviations-001.md](3tk-deviations-001.md).
- **The port said `Item` where the owner's word is `Outer`. 3tk's half is
  closed; the shared half is not.** The 2026-08-26 ruling was *new work says
  Outer; the existing tree is not searched and replaced* — **superseded by
  3TK-60**, which searched and replaced the whole 3tk tree and its books.
  **What is left is the shared specification**, which still says *item*, and
  ztk. **The deadline is unchanged — dtk's first stage** — because dtk builds
  from the specification alone and would bake the word into a fourth port.
  **Whose:** the shared text is nobody's until the owner says so; it is not
  3tk's to rewrite alone.
- **A ztk/3tk behavioural difference: whether `on_get` runs when a get already
  found a stored item.** 3tk does not, ztk does; Parts 11.7 and 12.2 side with
  3tk, the ztk audit and book with ztk. **Recorded, not ruled** — whichever way
  it goes, one of three things moves.
  [3tk-port-findings-004.md](3tk-port-findings-004.md) §5a.
- **Two lines of the ztk book are wrong about `on_get`** — `042.md:1288` and
  `:1448-1449`. **The ztk line's work, not this one.** The port is right and
  everything else agrees with it.
- **Should the containers support the Slot idiom at all?**
  `backup/3tk-who-supports-slot.md` argues they should not.
  3TK-10 did not rule it and 3TK-11 did not act on it, so the code has it. Two
  methods and two tests.
- **ztk owes one sentence, and it is the ztk line's to write.** Specification
  `005` Part 11.12 says **every port states** the closed-and-quiet precondition,
  and that a port which does not check it says so. **`src/mailbox.zig` has a
  closed flag and no count of calls in flight**, so ztk states rather than
  checks — which the clause allows and which nobody has yet written into ztk's
  own documentation. **No ztk code change is implied.**
- **Whether otk gets a status file.** The pointer at the specification is
  written; the folder is not prepared, and preparing it means saying what otk's
  line of work is. The owner's.
- **Whether the banned-word scan should cover this folder.** `rules-049.md`
  Part 5's scope skips `design/secondary/`. **The kitchen line's call, not 3tk's.**
- **`design/secondary/context.md` lists no `lang/` subfolder**, so every file
  under it counts as an orphan to `kitchen/tools/check_design.sh`. Drift, noted,
  not fixed. **The 14 dead links are the number that would signal a regression**,
  not the orphan count.

**The seven questions plans 018 and 019 left are still open** and are in those
plans.

## Standing facts

- **`Mutex.destroy` is `pthread_mutex_destroy` and it aborts on `EBUSY`**, so a
  held mutex cannot be destroyed. `release` takes the mutex, checks quiet,
  releases it, then destroys the condition variable and the mutex. Established
  against the real structs by 3TK-53, and the pool's `release` has the same
  shape; **section 7 of the fix document is a sketch and is not to be copied.**
- **The count covers the hook, not the function body.** A pool call that leaves
  the mutex to run application code stays active until that code has returned,
  and that includes the *second* `on_close` a straggling `put` performs. A
  refactor that lowers the count before the hook breaks the fix silently, and
  only `run-sanitizers.sh` and the four tier 1 programs would say so.
- **`@private` on a method is ignored by c3c 0.8.3**, with a warning, and the
  port already lives with it: `Mailbox._close` and the pool's helpers are private
  by intent and reachable in fact. What keeps them out of reach is `module
  mtk::mailbox` being a submodule, which `run-builds.sh` checks.
- **C3 is installed.** `c3c` at `/usr/bin/c3c`, stdlib sources at
  `/home/g41797/dev/langs/c3/lib/std/`. **No install step in any stage.**
- The toolchain 3TK-4 measured is `c3c` 0.8.3, LLVM 22.1.8, linux-x64. **Every
  capability answer is against that version.**
- **Never infer a build mode from the `-O` level.** `-O2` and above set
  `SAFE_MODE=false`. Always pass `--safe=yes` or `--safe=no` explicitly.
- **The fault-return operator is `~`**, not `?`. `return mtk::CLOSED~;`
- **`c3c test` detects leaks by default.** `--test-noleak` turns it off.
- **A negative program is compiled as an ordinary program**, so the test
  runner's macros — `@catch_is` among them — are out of reach. A negative that
  wants a fault writes `if (catch f = ...)`.
- **C3 has no UFCS**, and a method cannot be attached to a pointer alias. That
  is why the crossings are declared on `Inner` — `macro Inner.to(&self,
  $Type)` — and it is one of the three costs that ended the `Handle` alias in
  3TK-59.
- **C3 0.8.3 has no field-level privacy**, and `inline` does not create one. A
  `@private` struct inlined into a public one hides the type *name*; its fields
  stay readable and writable from another module.
- **The sanitizers need `--cc clang` on this machine.** Fedora's runtimes are not
  installed, so `cc` cannot link them — and plain `cc -fsanitize=thread` fails
  identically, so it is the machine and not c3c.
- **The seven raw drafts in `backup/` are input, never source of truth.** They
  contradict each other and some predate API 12 and 13.
  `3tk-drafts-review-001.md` is the measurement later stages read instead.
- **ztk is green** — 195/195 in four modes, three cross targets, closed
  2026-08-14.
- **[3tk-log.md](3tk-log.md) carries about a dozen older banned-word hits and is
  left as it is.** Owner's instruction: the log is append-only and rewriting it
  destroys the record.

## The measured numbers

**Re-measure before trusting any of these.** A scan counts only when it has just
been run. **`run-builds.sh` and `check-doc-loop.sh` were both re-run on
2026-09-07 by 3TK-pre-65 and the numbers below are that stage's.** The `handle`/
`item`/`node` scan was last run 2026-09-04 by 3TK-60.

```
./3tk/run-builds.sh        89 checks, 0 failures, four builds green
                           143 tests in each build
                           81 -> 89: the two-name layering grep became the
                           six-name module list plus one "nothing else"
                           check, and 3TK-pre-65 added the partition check
                           and the marker/block check
./3tk/check-doc-loop.sh    4 labelled blocks, 0 differing, 418 of 418
                           sentences, 0 missing, 0 banned words.
                           510 -> 418 is 3TK-pre-65 moving internal
                           declarations out of the reference, and it is the
                           one stage where a falling count is the point
./3tk/move-module-docs.sh
                roundtrip  byte-identical
./3tk/preview-docs.sh      mtk 36 declarations; mtk::helper the only page
                           marked generic; mtk, mtk::queue, mtk::mailbox,
                           mtk::pool all is_generic=false

--- superseded, kept for the shape of the fall ---
./3tk/run-builds.sh        87 checks, 0 failures, four builds green (3TK-61)
                           140 tests in each build (down from 141 — one test
                           dropped, see the 3TK-58 log entry)
./3tk/check-doc-loop.sh    re-run 2026-09-06: 1 DIFFERS (mtk::inner), 475
                           sentences, 470 found, 5 missing, 0 banned words.
                           NOT 3TK-61's doing — it changed no code. Four of
                           the five are the owner's uncommitted edit to
                           src/inner.c3, which gave the module block a new
                           opening ("Contains all for / - embedding an Inner
                           / - moving it / - through the type-erased
                           toolkit.") that reference 008 does not carry; the
                           fifth is the standing struct-descriptor summary.
                           3TK-63 rewrites that block anyway and closes all
                           five. Previously 0 differing, 472/471/1. Runs
                           bare: 3TK-60 pointed the REF default in both
                           check-doc-loop.sh and move-module-docs.sh at
                           matryoshka-3tk's 3tk-reference-008.md, four
                           versions on from the dead ../ref/ path
grep -riwE handle|item|
     node|Handle 3tk/      0 in every .c3 file, and 0 for the crossing
                           identifiers to_handle/from_handle/
                           must_from_handle/take_back_handle anywhere
./3tk/run-sanitizers.sh    not re-run this stage — 3TK-60 changed no
                           semantics, so nothing it checks can have moved
```

`run-builds.sh` needs `c3c` and nothing else, and that is deliberate. Both
scripts take an optional directory and exit 2 on a bad one.

## TODO

**Flags for a later stage, not yet elaborated into a plan.**

- **Tests improvements — closed by 3TK-58, 2026-09-03**, for the part that
  could be. `test/t_mailbox.c3`/`t_pool.c3`'s direct `_active` reads are now
  `is_quiet()`. `test/t_concurrency.c3`'s `the_deadline_is_anchored_once` had
  no black-box equivalent and was dropped instead — see the log entry for
  why. **Still open: whether the dropped Part 2.5/D7 coverage (deadline
  anchored once, not restarted by a spurious wakeup) needs some other
  verification** — a stress test, a manual sanitizer run, or nothing.
  Owner's call.
- **Managed Outers — re-thinking. Absorbed by 3TK-61 on 2026-09-06 and no
  longer a flag.** The discussion happened, and it went further than the flag:
  *managed* stops being a concept altogether. `create`/`release` take the
  allocator, the `Allocator` field becomes optional and serves the Outer's own
  allocations, and the code moves to module `xtn`. Ruled as `RT-5`, `RT-12`
  and `RT-13`; built by **3TK-64**.

## Rules that hold across every stage

- **Each stage starts cold.** Its named inputs plus this file are enough.
- **Each stage ends with advice**: clear the context, or do not, and why.
- **Finishing a stage does not start the next.** The owner names it.
- **inner** = the embedded structure. **outer** = the struct that embeds it.
  Never "parent".
- **Porting is not transpiling.** The specification says what to preserve; each
  port decides how to spell it.
- **A port may run ahead of the shared specification**, writing a rule into its
  own code and its own `ref/` while the shared clause is still open, **as long as
  it writes down which way it assumed the question would go.** The shared text
  catches up in a later stage. **Ruled 2026-08-28** as `Q-D.2`, after 3TK-53 and
  3TK-54 had done exactly that. **The boundary is dtk**: dtk builds from the
  specification alone, so the shared text is current before dtk's first stage.
  The `Item`/`Outer` wording has the same deadline for the same reason:
  3TK-60 closed 3tk's half of it and the shared clause is still open.
- **A change to `3tk/src` revises `ref/` in the same stage** — not later, and not
  as a debt for the next stage. A file under `ref/` that contradicts `3tk/src`
  is a defect of the stage that changed the source. Ruled 2026-08-25.
- **Every document is versioned.** A change makes the next number and the
  superseded version goes to `backup/`. `3tk-status.md` and `3tk-log.md` are the
  two exceptions and are edited in place.

## Where things live

- **`design/secondary/lang/c3/`** — this folder. Plans, status, log, notes, and
  the code at `3tk/`.
- **[`3tk/.notes.txt`](3tk/.notes.txt)** — local tool paths (C3 Manual, the
  stdlib source tree) and the C3 Playground link, plus the doc-loop run
  recipes (`check`, `from-reference`, `to-reference`, `move-module-docs.sh`)
  and the two restart lines. Not versioned, edited in place.
- **[`../common/`](../common/)** — what binds every port: the portable
  specification, the ztk audit, `port-flow-001.md`. Moved there 2026-08-23
  because a shared input inside one consumer's folder is a fork waiting to
  happen.
- **`ref/`** — **holds only [ref/3tk-doc-loop-004.md](ref/3tk-doc-loop-004.md)
  now.** 3TK-60 moved the api table and the decisions record to
  `matryoshka-3tk/design/` and the superseded copies to `backup/`. **`ref/`
  takes no new versions** — owner's ruling: every new document goes to
  `matryoshka-3tk/design/`.
- **[`matryoshka-3tk/design/`](https://github.com/g41797/matryoshka-3tk/tree/main/design)**
  — a second, separate local repo, for light builds, doc-site preview, and the
  live copies pushed there after each verified step. **The reference book, the
  example rules and the pattern catalog live there now, not in this repo's
  `ref/`**, and since 3TK-60 the api table, the decisions record and the terms
  document too: `3tk-reference-008.md`, `3tk-example-rules-004.md`,
  `3tk-patterns-004.md`, `3tk-api-004.md`, `3tk-decisions-007.md`,
  `3tk-terms-001.md`, and since 3TK-61 **`3tk-boundaries-001.md`** — the live
  working document for the 3TK-62…66 line, cited by id.
  Moved there because the owner is running builds and previews from that repo
  going forward. **Ask the owner exactly where before creating a new file
  there — every time**, even though `design/` is the default target.
- **[`matryoshka-3tk/scripts/`](https://github.com/g41797/matryoshka-3tk/tree/main/scripts)
  and `matryoshka-3tk/.github/workflows/`** — **every stage tunes both to what
  it changed in `matryoshka-tk`, in the stage.** The four scripts there are
  byte-identical to this repo's copies but for one line: `ROOT` gains `/..`.
  Copy, re-apply that line, `diff`, and require the ROOT line to be the only
  difference. `check-doc-loop.sh` and `move-module-docs.sh` are **not** ported.
  The `.yml` files are the one thing a stage edits directly in that repo, and
  **"none needed" is an answer that must be written into the log.**
- **`backup/`** — superseded versions. **Not a source of truth**, and the owner
  empties it. `3tk-patterns-001.md`, `3tk-example-rules-001.md`,
  `3tk-reference-004.md` and `3tk-doc-loop-003.md` moved here when their
  successors published to `matryoshka-3tk`; `3tk-decisions-004.md` and
  `3tk-staging-plan-022.md` followed. **`3tk-reference-006.md` and
  `3tk-patterns-002.md` went to `matryoshka-3tk`'s own `backup/`**, not this
  one, since that is where their successors live.
- **The port family:** otk (Odin), ztk (Zig, this repo), **3tk (C3, active)**,
  dtk (D — [../d/dtk-status.md](../d/dtk-status.md), no stage has run).
- `design/STATUS.md` and `design/STATUS-LOG.md` are untouched by this work.

**Unresolved, and it needs one word from the owner:** twelve documents and
`README.md` are in `backup/` while other files link to them at root. Are they
**archived** — in which case the links stop treating them as live — or
**displaced**, in which case they come back?

## How to start after a clear

Every line begins the same way, because every stage reads this file first:

```
Read design/secondary/lang/c3/3tk-status.md.
```

**`3TK-65` is next.** Start it with:

```
Read design/secondary/lang/c3/3tk-status.md and 3tk-staging-plan-028.md, then run 3TK-65
```

**`3TK-65` is the safe-build checks** — the idempotent stamp, the identity check
at the crossing and at both `@guard_insert`s, every one of them
`$if env::COMPILER_SAFE_MODE`-gated so a fast build carries nothing. It
discharges `HR-5` and reads Boundaries `Part 5.1` … `5.3`.

**What 3TK-pre-65 left it, and the names it must use.** `mtk::stamp` is the
macro to gate around and it is now in **part 2 of `inner.c3`**, carrying
`// For internal usage.` and a **contract-only** `<* *>` block. `OuterHelper.stamp`
and `.inner` are its two callers, in `mtk::helper`. The crossings to guard are
the four `OuterHelper` members in `helper.c3`; `@guard_insert` is in `queue.c3`
(now `mtk::queue`) and in `pool.c3`'s stack section.

**Three things 3TK-pre-65 built that 3TK-65 must not undo:**

1. **A `@require` lives inside the `<* *>` block.** An internal declaration with
   a contract keeps a contract-only block — every line a `@` line, no prose.
   Deleting one deletes the check, silently; that is how
   `negative/wrong_type_must` broke mid-stage.
2. **`run-builds.sh` asserts the module list of six**, that no example reaches
   past the helper into part 2, and that no declaration carries the marker and a
   describing block at once. A new declaration in part 2 takes the marker, or
   the build says so.
3. **The banners in `inner.c3` are load-bearing** — `// Part 2 of 3: public, and
   not yours` and `module mtk @private;` are what the partition check greps for,
   the same way `pool.c3`'s stack banner is.

**Not yet copied to `matryoshka-3tk`'s `src`/`test`/`negative`/`examples`, or
pushed** — 3TK-62, 3TK-63, 3TK-64, the INTR and 3TK-pre-65 are all waiting on
that, and it is the owner's step. `3tk-boundaries-001.md`,
`3tk-reference-008.md` and `scripts/run-builds.sh` are already there, edited in
place.

**Read the rulings before touching anything.** Every stage from 3TK-62 to
3TK-66 reads
[matryoshka-3tk/design/3tk-boundaries-001.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-boundaries-001.md)
and cites it by id. It is written to be enough on its own: the governing rule,
the rulings `RT-1` … `RT-18`, the helper requirements `HR-1` … `HR-10`, the
measurements `MS-1` … `MS-9` with their results, the parking lot `PL-1` …
`PL-10`, the rule for reading ztk, and — from the second sitting — the proposed
shape `HS-1` … `HS-11`, the variants `V-1` … `V-7` and the questions `Q-1` …
`Q-15`. **Nothing about the rethinking lives
outside that document, this file, and the 3TK-61 log entry.**

**None of the fifteen questions is open any more.** Plan 026's own closing
section says it: every point plan 025 held open was ruled by the second sitting
of 3TK-61, and **a stage that finds itself needing an answer has found a gap in
`3tk-boundaries-001.md`** — the gap is reported before the stage continues. The
paragraph below is the pre-026 state and is kept only until 3TK-66 spends the
document.

**Fifteen questions were the owner's and no stage might assume any of them.**
They are `Q-1` … `Q-15` in **section 12** of the rethinking document, which is
where they are answered. Grouped by what they block:

- **Before 3TK-63:** `Q-1` (`PL-6`, the `inner::to_inner` stutter), `Q-15`
  (the inner found by name, and `V-7a` or `V-7b`).
- **Before 3TK-64:** `Q-2` (`HR-10`, where `create`/`release` live), `Q-14`
  (the allocator found by name, **and whether the compile-time refusal comes
  with it** — without it an outer with `Allocator a;` is silently unmanaged).
- **Before 3TK-65:** `Q-3` … `Q-13` — the member names, the member list,
  `MSG` or `msg`, where the safe-build check goes, when `MS-4`/`MS-5` run, and
  `Q-10` … `Q-13`, which are section 13's: is `RT-3`'s module name spent, is
  `PL-7` ruled road 1, how far does the merge go, and does `run-builds.sh`
  assert the module surface.

**`Q-6` is answered by 15.5** and needs only a yes.

**`3tk-boundaries-001.md` and `3tk-terms-001.md` are spent together**, and not
before: they move to `matryoshka-3tk/design/backup/` with a plain `mv` once
their content has dissolved into the code and the books. **That is 3TK-66's
closing act**, not an earlier stage's. `3tk-terms-001.md` section 5 is
superseded by the rethinking document's rulings on managed.

**3TK-61 ran on 2026-09-06 in two sittings and closed. It changed no code** —
`run-builds.sh` was re-measured green and unchanged, which is the whole
verification a stage that only rules and records can offer. The second sitting
added the proposal, sections 10-15, and four measurements; its probes were
written in a scratch directory and **nothing under `3tk/` was touched.** Plan 024 is **fully
spent** and is in `backup/`.

**3TK-60 ran on 2026-09-04 and closed.** The two terms, in the source and in
the books; six documents written, three moved repo.

**3TK-59 ran on 2026-09-04 and closed**, all six steps —
[3tk-staging-plan-023.md](backup/3tk-staging-plan-023.md) is spent and moved to
`backup/`.

**3TK-58 ran on 2026-09-03 and closed** — `Mailbox`/`Pool` are opaque
types, `is_quiet()` exists on both, and the three test files are back to
black-box.

**3TK-50 is separately still waiting on the owner** — it has no next step
(catalog sections with a code shape are all covered) and eleven steps are
not yet copied to `matryoshka-3tk` and pushed/previewed there; that is
independent of 3TK-58 and does not block it.

For orientation only:

```
Read design/secondary/lang/c3/3tk-status.md and report where the 3tk work stands.
```

## The stages that have run

**Sixty-six rows, and the log has an entry for every one.** 3TK-62, 3TK-63 and
3TK-64 were added by 3TK-pre-65, which found them missing. This table is the list,
not the record.

| stage | | |
|---|---|---|
| **3TK-0** | staging plan | 2026-08-23 |
| **3TK-1** | ztk audit | 2026-08-23 |
| **3TK-2** | portable specification | 2026-08-23 |
| **3TK-3** | drafts review | 2026-08-23 |
| **3TK-4** | C3 capability study | 2026-08-23 |
| **3TK-5** | 3tk porting proposal | 2026-08-23 |
| **3TK-6** | toolkit in C3 | 2026-08-23 |
| **3TK-7** | two containers in C3 | 2026-08-23 |
| **3TK-8** | review answered, and a leak nobody could reach | 2026-08-23 |
| **3TK-9** | sanitizer found the tests, not the port | 2026-08-23 |
| **3TK-10** | core redesign, as a proposal | 2026-08-23 |
| **3TK-11** | core redesign, in code | 2026-08-23 |
| **3TK-12** | audit found what a forecast could not | 2026-08-24 |
| **3TK-13** | specification 003, and gap closes | 2026-08-24 |
| **3TK-14** | helper surface, measured then proposed, then re-measured against the stdlib | 2026-08-24 |
| **3TK-15** | two debts paid, and one of them was misfiled | 2026-08-24 |
| **3TK-16** | helper surface, in code | 2026-08-24 |
| **3TK-17** | Part 7.1 states promise, and 004 is cut for one Part | 2026-08-24 |
| **3TK-18** | field is called `link` | 2026-08-24 |
| **3TK-19** | three debts, and two of them were not repointings | 2026-08-24 |
| **3TK-20** | what this port decided, written where another port can read it | 2026-08-24 |
| **3TK-21** | `Inner` is one `any` | 2026-08-25 |
| **3TK-22** | findings document, against the shape it now describes | 2026-08-25 |
| **3TK-23** | retire what is no longer read | 2026-08-25 |
| **3TK-24** | pool difference, written where another port will find it | 2026-08-25 |
| **3TK-25** | status file is an entry point again | 2026-08-25 |
| **3TK-26** | stale `inner.c3` citations | 2026-08-25 |
| **3TK-27** | who reads notes | 2026-08-25 |
| **3TK-28** | a README for folder | 2026-08-25 |
| **3TK-29** | decisions, in one file | 2026-08-25 |
| **3TK-30** | API skeleton | 2026-08-25 |
| **3TK-30b** | page a caller reads | 2026-08-25 |
| **3TK-31** | exemplar, refused once, then written from ztk | 2026-08-25 |
| **3TK-32** | strings a user sees | 2026-08-25 |
| **3TK-33** | strip: `mtk.c3`, `inner.c3`, `helper.c3` | 2026-08-26 |
| **3TK-34** | strip: `managed.c3`, `queue.c3`, `stack.c3` | 2026-08-26 |
| **3TK-35** | strip: `mailbox.c3`, `pool.c3` | 2026-08-26 |
| **3TK-36** | reference in 042's shape | 2026-08-26 |
| **3TK-37** | comments moved out of the reference | 2026-08-26 |
| **3TK-38** | preview script | 2026-08-26 |
| **3TK-39** | doc loop as a document | 2026-08-26 |
| **3TK-40** | loop's first use on files it was not written for | 2026-08-26 |
| **3TK-41** | two containers, and the module description ruled | 2026-08-26 |
| **3TK-42** | last two files, and the loop closed | 2026-08-26 |
| **3TK-43** | flow document | 2026-08-26 |
| **3TK-44** | split, and what moves to `mtk` | 2026-08-26 |
| **3TK-45** | stack is public | 2026-08-26 |
| **3TK-46** | eight sections, eight labels | 2026-08-26 |
| **3TK-47** | move, and the checker | 2026-08-26 |
| **3TK-48** | rules for an example | 2026-08-26 |
| **3TK-49** | pattern catalog | 2026-08-26 |
| **3TK-51** | accumulated description | 2026-08-28 |
| **3TK-53** | mailbox, in code: closed is not quiet | 2026-08-28 |
| **3TK-54** | pool, in code: the hook window, and one lock measured | 2026-08-28 |
| **3TK-52** | the shared clause: closed and quiet, and specification 005 | 2026-08-28 |
| **3TK-55** | the defect list catches up with the code | 2026-08-28 |
| **3TK-56** | the close hook takes the queue by value, and `P6` is closed | 2026-08-30 |
| **3TK-57** | GitHub Actions CI — built in `matryoshka-3tk`, not here | 2026-08-31 |
| **3TK-58** | `Mailbox`/`Pool` opaque handles | 2026-09-03 |
| **3TK-59** | the `Handle` alias removed, the word kept | 2026-09-04 |
| **3TK-60** | the two terms: `Inner` and `Outer`, no third | 2026-09-04 |
| **3TK-61** | the rethinking — ruled, measured, proposed; no code changed | 2026-09-06 |
| **3TK-62** | the stack goes into the pool | 2026-09-07 |
| **3TK-63** | the merge into `mtk` — reversed by 3TK-pre-65 | 2026-09-07 |
| **3TK-64** | `OuterHelper`, and the end of *managed* | 2026-09-07 |
| **3TK-pre-65** | the readable surface | 2026-09-07 |

**3TK-50 is missing from the list because it has not run** — it is plan 019's
leftover and is in the table above.

## The interrupt stages

**An INTR stage is important work that is not part of the flow.** Seven have run;
the log has each one.

| | what it was | touched code |
|---|---|---|
| **INTR 1–3** | four implementation reviews triaged into seven problems and five questions; the questions answered; **six of the ten items fixed** | **INTR 3 did**, and paid the doc loop inside the stage |
| **INTR 4–5** | two reviews of the lifetime document absorbed, twenty points then thirty-three | no |
| **INTR 6** | **the owner's ruling on `Q5`**, and the document rewritten around it | no |
| **INTR 7** | the third review — ten clarifications, and **reviewing closed** | no |
| **INTR 8** | this file compacted, 2,358 lines to a list and a state | no |

**[3tk-open-defects.md](3tk-open-defects.md) is the working list** for what INTR
1–3 found: one table and one section per item, edited in place. **`P6` was the
last item open** and was ruled on 2026-08-28; **3TK-56 built it on 2026-08-30.
Nothing on that list is open any more.**
