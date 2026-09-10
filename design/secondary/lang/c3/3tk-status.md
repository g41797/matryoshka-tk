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

**`3TK-76` ran 2026-09-10 on Opus 5 and closed, and `036` is spent with it.
No stage is queued.** **Only `3TK-50` remains from any earlier plan, and it waits
on the owner.** Plans `034` and `036` are spent and still in this folder; `035`
and `033` are in `backup/`, and `029` through `032` are gone. **`backup/` is
transient, so none of them is a source of truth.**

**`test/` and `negative/` are on the helper. 94 sites of 117 moved**; the 23 that
stayed are white box under Rule 8 and **every one of them now carries its own
sentence**, so no later stage re-derives the partition. Where they are:
`t_identity.c3` **18** — the offset arithmetic, the checking crossing's refusal,
the null tolerance, the claim inside the heterogeneous walk, the
method-against-macro line and `to_inner`'s own null contract — and **five in
`negative/`**: `unstamped_insert`, `unstamped_crossing`, `wrong_type_must`,
`nocompile_no_inner`, `nocompile_two_inners`. `examples/` is 2 and both are
sanctioned by name at `run-builds.sh:306`. **`src/` was not opened and is still
at its floor**, its six chain sites unchanged.

**The rules file is `3tk-rules-007.md` from here on.** `3TK-76` took
`overwrite_slot` off Rule 8's list of negatives where the bypass IS the
violation — its violation is the second `fill` on a full Slot, the crossing
beside it is plumbing, and the wrapper aborts at neither. **That is the only
change: Rules 1–7 and 9–14 are `006`'s word for word and the numbering did not
shift**, so a citation to `006` resolves unchanged. `006` is in
`matryoshka-3tk/design/backup/`. **The other seven names on that list were each
re-read and each stands**; a stage that wants to convert one is re-opening a
ruling, not finding a leftover.

**The ten callers of the five part-1 methods are still ten and still all in
`test/t_identity.c3`** — re-measured after the sweep. The example rules' promise
holds and nothing is owed.

**`OuterHelper.inner` no longer writes. It verifies.** `mtk::@check` plus
`is_mine`, tolerating null, then `to_inner` — `helper.c3:171`. **`stamp` was not
narrowed and is not to be**, `C-3`: it is still a read-modify-write of the whole
`link` field, which is safe only because its three remaining callers are all
construction-time. `Inner` is one `any`, the pointer half being the chain link,
so a stamp on an outer another thread may be relinking loses that thread's link.
**A stage that "fixes" `stamp` has misread which ruling was open — none is.**

**The identity is asserted at three boundaries now**, not two: the insertion
(`@guard_insert`), the crossing back (`look` and the other three), and the
crossing **out** (`inner`). Four negatives hold them — `unstamped_insert`,
`unstamped_crossing`, `unstamped_inner`, `wrong_type_inner` — and no one of them
can reach another's site.

**The stage rules moved from 8-13 to 9-14, the third such shift.** A citation to
an older number resolves by adding one **per shift**, so check which file a
citation was written against rather than adding one blindly.

**Two `src/` sites changed and their comments went with them.**
`mailbox.c3:51` and `pool.c3:163` are `MBOX.inner(...)` and `POOL.inner(...)`;
the exception comments that justified a raw `to_inner` are deleted, the write
they stepped around being gone. **`src/` is at its floor for this subject**:
`queue.c3:129,211,212` and `pool.c3:763,764,808` are chain plumbing on a
type-erased `Inner*` where no `Outer` is in scope, and no stage re-derives that.

**`linked` takes an `Inner*` as well as an `Outer*`**, `helper.c3:189`. It is
what `C-4` called a lack of support rather than a nicety, and Rule 8's second
clause is the general form: a site that cannot reach the helper because the
helper is **missing a member** is a gap, and the stage that finds it adds the
member instead of writing an exemption.

**The outer's hooks are required, and this is the state a later stage works
against.** Every outer that `OuterHelper.create` makes declares
`fn void? Outer.init(&self, Allocator a)` and
`fn void Outer.finish(&self, Allocator a)`, **and an empty body is fine** — it
is how a type says it has nothing to do, not a placeholder, and **no stage
tidies one away.** `destroy` is gone as a name. The mechanism is **two
compile-time `$assert`s in each of `create` and `release`**, so it is alive in
every build mode. **The containers are outside it** — `_Mbox` and `_Pool`
allocate themselves and never call `create`, and the exemption falls out of
where the check sits rather than out of a list. **No interface, no marker, no
flag at the call site, no second `create`**; Rule 7 of
[3tk-rules-007.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-rules-007.md)
carries the rule and why each was refused, and **none of the four is
reopened.**

**`B-6` is the one a later stage is most likely to get wrong.** 3TK-70's
sentence refusing an `interface OuterHooks` argued from the hooks being
*optional*, and they are not optional any more. **The ruling stands on a
replaced argument** — an interface carries a choice across a boundary at
runtime, and these hooks are never passed. **Do not read the ruling as lapsed
with its argument.**

**The sweep was 14 outer types and 28 hooks, not the charter's 12 and 24.**
Rule 12. **21 hooks were newly written and 20 of the 28 are empty.** The
charter counted `helper::OF{...}` binding sites, which collapses **three
distinct `Holder` types in three modules** into one. Where they are:
`test/common.c3` 7 types, `examples/outers.c3` 3,
`examples/023-infrastructure_wrapper.c3` 1, `negative/common.c3` 2,
`negative/create_into_full_slot.c3` 1.

**The two new negatives are `nocompile_no_init` and `nocompile_no_finish`, and
they are compile-time negatives rather than tier 1.** `B-9`'s word was loose and
Rule 12 fixed it in the stage: *tier 1* means aborts at runtime in every mode,
and a check that refuses to compile has no runtime. They sit in
`NOCOMPILE_EXPECT`, which already runs in every build.
**`nocompile_no_init` spells the hook `initialize` rather than omitting it**,
because the misspelling is the failure the rule exists for.

**Three documents are new or revised, and one is the source of truth for the
rule.** **`3tk-reference-010.md` replaced `009`** and **`3tk-rules-005.md`
replaced `004`**; both superseded versions are in
`matryoshka-3tk/design/backup/`. **`3TK-75` has since superseded both in turn —
`011` and `006` are the live numbers.** **`3tk-decisions-007.md` and `3tk-api-005.md`
were revised in place**, which their own headers ask for, and **every
`helper.c3` citation in both was re-resolved against the built tree** — the file
moved +16 lines above `create`, +18 at `create` and +20 at `release`.

**`matryoshka-3tk/src/` and `matryoshka-3tk/test/` still carry the pre-3TK-74
text, and now the pre-3TK-75 text too**, because 3tk `.c3` sources are edited
only in `matryoshka-tk`'s copy and the owner copies them across. **What `3TK-75`
adds to that queue: `src/helper.c3`, `src/mailbox.c3`, `src/pool.c3`,
`test/t_helper.c3`, and the two new files `negative/unstamped_inner.c3` and
`negative/wrong_type_inner.c3`.** **`run-builds.sh` was ported by both stages and
its diff is the `ROOT` line alone**; the three `.yml` files needed nothing,
`linux.yml` being a build-and-test matrix that runs no negative — **which is why
two new negative programs do not reach CI.**
**`check-doc-loop.sh` and `move-module-docs.sh` are still not in
`matryoshka-3tk/scripts/`** — as before this stage, flagged and not acted on.

**`3TK-73` ran 2026-09-09 on Opus 5 and closed. This folder is classified.**
Sixteen documents and one script, read and sorted by `A-1`'s two questions —
*is it still true*, then *who is its reader*. **Five stay, two crossed, twelve
retired.** What stays: `3tk-log.md`, `3tk-status.md`, `3tk-staging-plan-034.md`,
`3tk-sanitizer-notes-001.md` and `ref/3tk-doc-loop-005.md`. **Every figure is
identical to 3TK-72's** — 107 checks, four builds, 145 tests each, doc loop 11
blocks and 443 of 443, sanitizers 3 of 3 — which is `A-11`'s proof that the
stage stayed inside `design/`.

**What crossed to `matryoshka-3tk/design/`:** `c3-capabilities-003.md`, trimmed
of two 2026-08 scaffolding sections and carrying a new **Q13** on packaging;
and **`3tk-port-findings-005.md`**, which `A-7` ruled a different subject from
`3tk-decisions-007.md` — that file is the registry of what stands, this one is
the argument, and neither does the other's job. **Every 3tk `file:line` in it
was re-resolved against the built tree and every quoted block re-cut**; ztk's
were left as measured.

**`P4` is closed and `P3` is not.** Both were carried out of
`3tk-deviations-001.md` before it retired; see *Open questions*. **`P3` is now
the only port defect on this file.**

**Two items outside 3tk stay open and are the owner's.**
`design/matryoshka-api-reference-042.md` still says the pool calls `on_close`
*once, with the full list*, against Part 12.2; and Part 12.3 of
`matryoshka-specification-005.md` still cites `pool.c3:445-480` for a window
that has moved twice. **Reported by 3TK-73, not fixed** — the shared books are
not 3tk's to rule on.

**The banned words in the two documents that crossed are fixed** — reported by
3TK-73, approved by the owner the same day, and done in prose only. **Nine
words across the two**, both now clean under the Part 5 pattern. **Quoted
source was not touched**: every remaining match is inside a `c3` or `zig`
block, where it is the code as measured. Both changelogs carry the amended
row.

**`3TK-72` ran 2026-09-09 on Opus 5 and closed. `examples/` is eleven groups.**
An example's module is `shc::<group>::<name>`, each group has a carrier file
`<group>.c3` that describes it and declares nothing, and **the numbers stay in
the filenames** — no file was renamed and no code moved. The eleven are
`a_slot_and_transfer`, `b_cleanup`, `c_crossing`, `d_dispatch`,
`e_infrastructure`, `f_mailbox`, `g_topology`, `h_pool`, `i_shutdown`,
`j_coordinator`, `k_new_in_3tk`. **`b_cleanup` is the owner's split** — the
catalog files entries 5–10 under *Slot and transfer idioms*, and they are their
own subject; **the catalog was not rewritten to match.**

**The probe answered yes and it was checked both ways: `import shc;` reaches two
levels of submodule.** `test/t_examples.c3`'s **52 leaf imports are one line**.
With that line deleted the fully-qualified call fails and c3c names the import it
wants — so it is the import doing the work, not the qualified path resolving on
its own. **A later stage does not re-probe this.**

**Two things the plan had wrong and the stage measured right.** The examples are
reached by **qualified call sites**, not by the import alone, so the sweep was
**103 references in `t_examples.c3`**, not 52. And the two imports between
example files are **018 → 017 and 045 → 018**, not the 019/020 pair the plan
named; `045` is a cross-group import by design, `h_pool` reusing `d_dispatch`'s
hooks the way catalog entry 45 says to. **A group is not a wall**, and the
example rules now say so.

**`3tk-example-rules-005.md` replaced `004`** — *The file name* rewritten and
*The groups* added — and **`3tk-rules-004.md` replaced `003`**, adding Rule 12.
**Both have since been superseded; `006` is the live number of each.**
Both superseded files are in `matryoshka-3tk/design/backup/`.

**`c3-capabilities-003.md` is in `matryoshka-3tk/design/`** — crossed there by
3TK-73 on 2026-09-09, with `002` and `001` in this folder's `backup/`. `002` was
**Rule 12's first use.** Q6 gained the failure half: the three `defer` forms all
verified, **`defer (catch f)`** binding the fault — the parentheses go around
`catch f`, and five other spellings are refused — and `return BOOM~;`, not `?`.
**No `mtk` site uses the bound form and none is owed one.**

**One flag, and it is the owner's call: the docs site does not build
`examples/`.** `docs.yml` runs `c3c docgen --emit-stdlib=no src`, and the line
that would include the examples is commented out directly below it, while the
workflow still triggers on `examples/**`. **`3TK-72`'s grouping is what the site
would show the moment that line is uncommented**, and it was left as found —
uncommenting publishes 63 new modules. **No stage uncomments it without the
owner.**

**Three facts a later stage should not re-derive, all three in Rule 6 or the log.**
**`mem` is per-thread: an outer is freed by the thread that allocated it**, and a
test that spawns a producer creates the outers before the thread starts. **A
`defer release` is registered BEFORE the container's `defer`** — defers are LIFO,
and a bag declared under `defer drop_mailbox(mb)` frees its outers before the
close walks them; AddressSanitizer caught that one. **Neither was reachable while
the outers were on the stack.**

**The exemptions are four, not `T-4`'s three:**
`uninitialized_inner_is_refused`, `negative/unstamped_insert`,
`negative/unstamped_crossing` and — the one the plan did not list —
`test/t_helper.c3`'s `inner_stamps_on_the_way_out`, whose subject is an outer
made by hand. **`T-7`'s two global outers both converted**, and the reasoning is
in the log: the lifetime argument does not reach a global, but neither subject is
the outer.

**Two things outside the sweep, and the owner should read both.**
**`run-builds.sh` was 106 of 107 before this stage began** — `_Mbox.send_at`,
`_Pool.take_back` and `_Pool.take_back_inner` were in `::internal` modules with
no doc block, which Rule 2 forbids; fixed, and it is the only `src/` line this
stage wrote. **And `c3fmt` is not run on `src/`** — the owner ran it
mid-stage and the doc loop refused it: **4 module blocks `DIFFERS` and 453
descriptor sentences instead of 443**, because it hard-wraps doc-block prose at
about 120 columns. `src/` was restored from `matryoshka-3tk/src/`, byte-identical
to the pre-`c3fmt` state; **no git was used.** Ruled by the owner: leave it
unformatted. **The rule is in `3tk-rules-007.md` under Rule 4** — a stage that
wants the source formatted answers the doc loop first.

**`3TK-70` ran 2026-09-09 on Opus 5 and closed.** Six module names are **eleven**,
over the same six files: `mtk::inner::internal`, `mtk::queue::internal`,
`mtk::mailbox::internal`, `mtk::pool::internal` and `mtk::pool::hooks` are new.
`inner.c3`'s third section folded into the first of them. **`mtk::inner`'s docs
page falls from 26 entries to 13**, read off the generated page.
**`3tk-reference-009.md` and `3tk-rules-002.md` replace `008` and `001`**, which
are in `matryoshka-3tk/design/backup/`. Full account in the log entry.

**`006` was `3TK-75`'s**, which added **Rule 8 — white box where the work
requires it, black box everywhere else** at the end of Part 1 and shifted the
stage rules 8-13 to 9-14. **`007` is `3TK-76`'s and shifted nothing**; see the
top of this file. `005` was `3TK-74`'s,
which added **Rule 7 — every outer the helper creates declares both hooks** at
the end of Part 1, rewrote **Rule 4**'s last paragraph, and shifted the stage
rules
`004` numbered 7–12 to 8–13. **A citation to an older number resolves by adding
one**, and live text written against `004` was not rewritten for it. `004` is
`3TK-72`'s, which added
**Rule 12, now 13 — a document is versioned, not asked about**: when a document a stage
touches needs more than a sentence changed, the stage writes the new version and
moves the old to `backup/`, **in the stage and without asking**. A new version of
an existing document is not a new document, so the standing *ask before creating
a file in `matryoshka-3tk/design/`* does not reach it. Rules 1–11 are unchanged,
word for word.

`003` was `3TK-71`'s and is in `matryoshka-3tk/design/backup/` with `002` and
`001`. It added **Rule 6 — a test's outer is allocated too, unless the test's
subject forbids it** — at the end of Part 1 and renumbered the five stage rules
6–10 into 7–11. What `3TK-70` changed before that is unchanged too: Rules 2, 3
and 4. **Rule 3's truth moved from position to module** — a declaration is
internal because it is in an `mtk::X::internal` section, not because it sits
below a comment banner — **Rule 4 gained the direction criterion** (a submodule
is warranted when the toolkit is the caller), and **Rule 2's *no prose in an
internal block* is a stated ruling** with the consequence that a declaration may
carry an example if and only if it is not in an `::internal` module.

**Three things a later stage should not re-derive.** A `@private` declaration in
a submodule is **not** visible to its parent — that is why `_Mbox`, `_Pool` and
`inner_offset` lost theirs. A parent reaches its child with no import; a cousin
needs one, and `import mtk;` supplies it. **A non-generic submodule under the
generic `mtk::helper` renders sanely in docgen** (`M-8`'s probe, run and
recorded) — its page is its own and carries no generic parameter.

**INTR 11 ran 2026-09-09 and changed no code.** It triaged an outside AI review
of the published archive, answered five of its nineteen pieces of advice and
closed them, raised three flags, and found that the `[3tk: ...]` marks this file
called gone are 60 strong. See the log entry. **`3TK-70` classified them: 11
went and 49 stand**, every one of the 49 resolving to a live specification Part.
The eight `Q-8, Part 5.2` marks were Boundaries; `A3`, `D6` and `P1`, which the
plan left unclassified, are `3tk-drafts-review-001.md` ids and that document is in
`backup/` — **the test is not which document but whether the document is live.**

**Plan 030 is spent too.** `3TK-69` ran and closed on 2026-09-08, applying `L-1` …
`L-12` and deciding nothing new. **`3TK-pre-65`, `3TK-67`, `3TK-65`, `3TK-66`,
`3TK-68` and `3TK-69` are all closed** — the whole line 026 opened. **Nothing is
renumbered** — execution order and numeric order differ, deliberately:
67, 65, 66, 68, 69. **No stage "corrects" that.**

**The source LOC is computed on demand, not committed.** `matryoshka-3tk/scripts/count_src_loc.sh`
and `inject_src_loc.sh` are the two new scripts (`L-2`, `L-3`) — no
`matryoshka-tk` copy, the first 3tk script pair that is not ported.
`src/mtk.c3`'s module doc block and the reference (`009` now) both carry
`[[LOC]]` (`L-5`); `docs.yml` substitutes it in the runner's own checkout,
before `c3c docgen` (`L-8`). **`src/*.c3` is 665 lines by `L-1`'s definition**
(2,073 raw). The rules file's Rule 5 carries `L-9`'s sharpened wording — still
Rule 5 in `003`, the new rule having gone in after it. Full
account in the log entry.

**Only 3TK-50 is open**, and it waits on the owner, not on any stage above.

**`src/*.c3` is 684 lines by `L-1`'s definition** (2,245 raw), up from 665.
Computed on demand, never committed; `[[LOC]]` is still the token.

**`3tk-decisions-007.md`'s citations are no longer stale.** `3TK-66` re-anchored
all of them, and the api table's, from the built tree on 2026-09-08 — **326
citations, none resolved from the number it carried**. The repair is finished
and the debt is closed. Anything that moves a line in `../3tk/src` re-runs that
resolution in the same stage; it is not a debt for a later one.

**`3tk-boundaries-001.md` and `3tk-terms-001.md` are spent** and in
`matryoshka-3tk/design/backup/` since 2026-09-08 — `3TK-66`'s closing act.
**`backup/` is transient, so neither is a source of truth.** Their content is in
the source, in [3tk-reference-011.md] and in
[3tk-rules-007.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-rules-007.md).
`3tk-decisions-007.md` still cites Boundaries by part number, and its header now
frames those as **historical markers** — which sitting ruled the entry — with
`007` and `../3tk/src` as what stands where they would differ.

**The sitting of 2026-09-08 ruled six things and changed no code.** They are
**`3TK-67` carried all six into effect on 2026-09-08, and the rules among them
now live in
[matryoshka-3tk/design/3tk-rules-007.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-rules-007.md).**
**That file is the source of truth for every rule that binds 3tk and is not in
the common tk set, and it is where a rule is changed.** It has two parts: the
port rules (how 3tk source is written) and the stage rules (how a 3tk stage is
run, including *compact/clear/nothing*, the model recommendation, the exemplar
before the sweep, the script-and-CI port, and *fix the definition, do not halt*).
**Nothing about those rules is restated here or in the staging plan; cite that
file.**

**The two superseded `run-builds.sh` checks are gone, replaced by `3TK-67`.**
What stands in their place is one two-directional check — every declaration below
a file's internal banner opens with `For internal usage.`, none above one does, a
file has at most one banner, and each banner's presence is asserted by name.
`check-doc-loop.sh` excludes the marker by exact match on the whole line.

**The order inverted, and it worked.** The landing page was a module-layout
change, not a docs change, so it preceded `3TK-66`, which rewrote the books and
all 52 examples against module names that were already settled. `3TK-66` kept
its closing act because `Parts 4.2` and `4.2a` were still live when `3TK-67`
needed them. **The inversion is spent; nothing later depends on it.**

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
primitives, each carrying `// For internal usage.` and nothing else; part 3 is
`module mtk @private;` with `inner_offset`. **34 declarations across `src/`
carry the marker and no `<* *>` block.**

**The `[3tk: D1 …]` decision-citation marks are gone from `src/`** — 103 of
them, ruled and removed 2026-09-08. Nothing checked their content —
`run-builds.sh`, `move-module-docs.sh` and `doc_blocks.py` all stepped over any
`//` line between a block and its declaration generically, not by parsing the
mark — so removing them changed no script logic, only comments describing them.

**Corrected by INTR 11, 2026-09-09: that removal was specific, and this file
used to generalise it. 60 marks of a different shape remain** — `pool.c3` 37,
`mailbox.c3` 10, `helper.c3` 7, `queue.c3` 3, `inner.c3` 3. **14 carry a
non-`Part` id** (`Q-8` ×8, `R12` ×2, `V11` ×2, `A3` ×2, `D6`, `P1`), and `Q-`,
`R-` and `V-` are `3tk-boundaries-001.md` ids — a spent document in a transient
`backup/`. **The other 46 are a bare `Part N.M`, which is ambiguous by
construction**: the shared specification and Boundaries number Parts the same
way. **`3TK-70` classifies them, resolving each from the code it sits on and
never from the number it carries.** Full account in the INTR 11 log entry.

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

**`run-builds.sh` is 123 checks, 0 failures, four builds, 146 tests each, and the doc loop is 463 of 463** — `3TK-75`'s figures, and the current ones. 115, 145 and 458 were `3TK-74`'s; 107 and 443 were `3TK-70`'s through `3TK-73`'s; the two figures moved together because two new negatives run once per build and the helper's three doc blocks grew. The paragraphs below are each stage's own reading at the time it ran.

**`run-builds.sh` was 81 → 89 checks, 0 failures, four builds, 143 tests each.**
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
allocates zeroed, calls the outer's `init(a)` hook, **stamps after the
hook** so a failed creation leaves nothing stamped, and fills the Slot;
`release` calls `finish(a)`, empties the Slot and frees. `release`
returns `void`, so it needs no `!`, no `!!` and no cast in a `defer`.
(The hooks were optional and `finish` was `destroy` when 3TK-64 wrote this; both
changed in 3TK-74, and the shape of the two members did not.)

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
`Inner.outer_tid`. **3TK-66 finished it on 2026-09-08:** the helper section moved to the front of
Part 3, *Usual flow* is four steps off `MSG.create`, and no `managed::` remains
anywhere in the book.

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

**The restore was skipped on the owner's ruling and is owed by nobody.**
189 of the 222 changed lines were the botched renumbering, and 21 citations named
the deleted `managed.c3`. **3TK-66 re-anchored them on 2026-09-08** — 326
citations across `007` and the api table, each resolved from its own entry's
text rather than from the number it carried. `reapply_decisions.py` is spent and
will not be run.

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
**3TK-66 re-anchored all of them from the built tree on 2026-09-08** — which
overwrote whatever the numbers said, restored or not. `reapply_decisions.py` is
spent.

**What happened is still worth knowing.** A fourth thing was attempted here and
should not have been: re-anchoring the file's citations into the three moved
files. It ran in three passes, and the third matched on old line numbers and
overwrote what the first two had already corrected — many-to-one, so not
reversible from the file. **3TK-66 did it once, differently — resolving each citation from its entry's own
text, never from its old number — and `007`'s header now records how, and what a
citation means when it lands on a `module` line.**

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
`026` as **3TK-62 … 3TK-66**; 029 carried the
three of those that had not run — reordered, and with `3TK-67`, `3TK-68` and
`3TK-69` added — **and all of them but `3TK-69` have now run. 024 through 029
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
where dtk will read them. **Both `3tk-terms-001.md` and `3tk-boundaries-001.md` were spent by 3TK-66 on
2026-09-08 and are in `matryoshka-3tk/design/backup/`, which is transient.** The
two-term ruling is carried by the books themselves now — each states it and dates
it to 3TK-60 rather than pointing at a document.

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

**`3tk-lifetime-fix-005.md` bound 3TK-53 and 3TK-54 and
has now been built.** Three review rounds are absorbed into it and **reviewing of
it is closed.** Section 4 is the ruling and the text it owes; section 15 is what
the ruling closed. **The one thing it asked for and did not decide — what the
added lock in `Pool.get` costs — is measured in the log's 3TK-54 entry.**

**Where `3tk-staging-plan-020.md` disagrees with it, the
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
| **3TK-50** | **The examples tree**, plan 019's leftover and the first code under `3tk/examples/`, run in steps grouped by catalog section. Reads [3tk-example-rules-006.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-example-rules-006.md) and [3tk-patterns-003.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-patterns-003.md), both in `matryoshka-3tk/design/`. **Independent of the fix. Steps 1 through 11 ran 2026-08-31 — every catalog section with a code shape is now covered.** The catalog's two remaining sections, "The 18 that dropped" and "What this document does not do", write no code (a table of ztk entries with nothing to port, and a closing note) — **there is no step 12.** | **3TK-50 has no next step. Ask the owner what closes it** — copying and pushing the last steps to `matryoshka-3tk`, and updating this table, are what remain. |
| **3TK-67** | **The landing page, the marker, and the rules file.** Ran 2026-09-08 on Opus 5. `inner.c3` is `module mtk::inner;`, `mtk` a landing page of four source declarations. One internal banner per file and the marker in 31 blocks — **31, not 34; the 34 was a grep of the string, three hits being prose about it** — across **four** files, not five. The two superseded checks are replaced by one two-directional partition check, written and negative-tested before the sweep. Created `3tk-rules-001.md`; migrated Boundaries `4.4a` into it, marked superseded and left in place. | **Closed.** 95 checks green, 143 tests in each of four builds, every per-build figure identical. `PL-6`/`Q-1` answered: the prefix costs **two** lines in all of `examples/`, both already allow-listed, and the spelling is `inner::`. |
| **3TK-65** | **The safe-build checks.** Ran 2026-09-08 on Opus 5. The stamp keeps its reason in the file; `check_stamped` is one shared guard at **both** boundaries — the four crossings of `helper.c3` (**six call sites**, `look` and `must_look` each having two `$Typeof` arms) and both `@guard_insert`s. Gated by `mtk::@check`, so a fast build carries nothing. Discharges `HR-5`, answers `Q-8`. | **Closed.** 107 checks green, 145 tests in each of four builds, doc loop 409 of 409. Two new negatives, `unstamped_insert` and `unstamped_crossing`, one per boundary. **`[&in]` on `to_inner` was refused deliberately** — null in, null out — and two tests in `t_identity.c3` hold the refusal. |
| **3TK-66** | **The books and the examples.** Ran 2026-09-08 on Opus 5. **58 crossing sites across `examples/` moved to the helper**, leaving five method sites and one free site — all six inside `012` and `013`, the two files whose subject is the layering. The helper section moved to the front of the reference's Part 3, `mtk::managed` is gone from all four books, Boundaries `Part 6` is in as *What is deliberately absent*, and the example rules gained a MUST naming the two exempt files. **326 citations re-anchored** across `007` and the api table, each from its entry's own text. | **Closed.** 107 checks green, 145 tests in each of four builds, doc loop 409 of 409 and 0 banned words. Appendix B deleted and the `007` *not yet built* section closed with it; `3tk-boundaries-001.md` and `3tk-terms-001.md` moved to `matryoshka-3tk/design/backup/`. **`3tk-api-005.md` replaces `004`** — revised in place first, then versioned on the owner's ruling; `004` is not in `backup/` and the log says why. |
| **3TK-68** | **The names and the scripts.** `negative/insert_linked_item.c3` — the **one** filename still carrying a retired word, which 3TK-60's contents-only `grep` could never have seen — renamed, and `run-builds.sh:60` (`RUNTIME_NEGATIVES`) with it in both repos. Plus the `matryoshka-3tk/scripts/` diff audit and the `.yml` review with `docs.yml` in scope. | **Closed.** Ran on Sonnet 5, as the charter asked. 107 checks green in four builds, 145 tests each; the renamed negative still aborts in the safe builds. All four ported scripts diffed clean but for `ROOT`, plus the same rename line in `matryoshka-3tk`'s copy, which is the owner's to port. **The three `.yml` files needed none** — `docs.yml` included. |
| **3TK-69** | **The source LOC.** A counting script and an injector, both in `matryoshka-3tk/scripts/`; the number replaces `[[LOC]]` in `src/mtk.c3` in CI's own checkout before `c3c docgen`. **Nothing enters the language and no trust flag is paid.** The twelve rulings `L-1` … `L-12` in `3tk-staging-plan-030.md` (spent, in `backup/`) settle what a line is, where the scripts live, the token, dry-run-by-default, and strict-in-CI. | **Closed.** Ran 2026-09-08 on Sonnet 5, as the charter asked. `L-11` was ruled *no* and nothing entered the language. `src/*.c3` is **665 lines** by `L-1`'s definition, 2,073 raw. |
| **3TK-70** | **The module split, and the hooks page.** Ran 2026-09-09 on Opus 5. Four `::internal` submodules and **`mtk::pool::hooks`**, the section that opens `pool.c3`. **6 module names became 11**, over the same six files. `inner.c3`'s third section folded in and `inner_offset` lost its `@private`; so did `_Mbox` and `_Pool`, because a `@private` in a submodule is invisible to its parent. Rewrote Rules 2, 3 and 4 as `3tk-rules-002.md`, reference `009`, and re-anchored 320 citations. | **Closed.** 107 checks green, 145 tests in each of four builds, doc loop **11 blocks**, 0 differing, 443 of 443, roundtrip byte-identical. `mtk::inner` fell **26 → 13** on the generated page. The qualification sweep was **221 sites, not the ~35 the plan estimated** — Rule 11 (Rule 10 when 3TK-70 cited it). `M-8`'s probe answered yes. |
| **3TK-71** | **The tests allocate their outers.** Ran 2026-09-09 on Opus 5. Every outer in `test/` and `negative/` goes through `OuterHelper.create`, bar **four** sites whose subject forbids it, each annotated at the site. The plan's 53 was the scalar declarations only — **nineteen arrays of outers** were missed and all converted; `test/common.c3` grew **`MsgBag`** and `fresh_msgs()` is gone. `T-7`'s two global outers both converted. **`3tk-rules-003.md`** adds **Rule 6**, a port rule, and renumbers the stage rules 6–10 into 7–11. | **Closed.** 107 checks green, 145 tests in each of four builds, doc loop 11 blocks, 0 differing, 443 of 443, roundtrip byte-identical, **sanitizers 3 of 3**. The baseline was **106 of 107** — three `::internal` declarations of 3TK-70 had no doc block. **`c3fmt`, run by the owner mid-stage, broke the doc loop** (4 blocks `DIFFERS`, 453 sentences); `src/` restored with no git, and **Rule 4 now says `c3fmt` is not run on `src/`**. `mem` is per-thread and defers are LIFO: two real defects the stack was hiding. |
| **3TK-72** | **The example groups.** Ran 2026-09-09 on Opus 5. Eleven group modules, each with a carrier file that declares nothing; **49 example `module` lines** gained a group segment and **no file was renamed**. `b_cleanup` is an eleventh group split out of the catalog's first section by the owner. `test/t_examples.c3`'s **52 leaf imports became one `import shc;`** on a probe that was checked both ways, and its 52 call sites were qualified. `3tk-example-rules-005.md` and `3tk-rules-004.md` replace `004` and `003`. | **Closed.** 107 checks green, 145 tests in each of four builds, doc loop 11 blocks, 0 differing, 443 of 443, roundtrip byte-identical, **sanitizers 3 of 3** — every figure identical to `3TK-71`'s, which is the proof of a grouping stage. **The plan's 52 was 103** (call sites, not imports) and its named intra-example import pair was wrong; both corrected in the stage under `G-9`. |
| **3TK-74** | **The outer's hooks become required.** Ran 2026-09-09 on Opus 5. `init` and `finish` declared by every outer the helper creates, empty bodies allowed; `destroy` renamed and narrowed from `void?` to `void`; two compile-time `$assert`s in each of `create` and `release`; the module block rewritten and `B-7`'s pool comparison written into the reference. **`3tk-rules-005.md` adds Rule 7 and rewrites Rule 4's last paragraph**; **`3tk-reference-010.md`** replaces `009`; `3tk-decisions-007.md` and `3tk-api-005.md` revised in place with every `helper.c3` citation re-resolved. | **Closed.** **115 checks green** — 107 plus the two new negatives, once per build — 145 tests in each of four builds, doc loop 11 blocks, 0 differing, **458 of 458**, 0 banned words, roundtrip byte-identical, sanitizers 3 of 3. **The sweep was 14 types and 28 hooks, not 12 and 24** (Rule 12: the charter counted binding sites, and three distinct `Holder` types collapse into one). The two negatives are **compile-time, not tier 1**. `B-5`'s exemption needed no code. |
| **3TK-75** | **The helper stopped writing.** Ran 2026-09-10 on Opus 5. `OuterHelper.inner` verifies the identity instead of stamping it — `mtk::@check` plus `is_mine`, null tolerated — so the read-modify-write of the whole `link` field is gone from the one door that could fire on an outer another thread holds. **`stamp` itself is untouched** (`C-3`), its three callers all being construction-time. `linked` takes an `Inner*` too; the two container sites that kept a raw `to_inner` go through their alias and their exception comments are deleted. Two tests corrected, one added, **two negatives added rather than `C-8`'s one** — a negative program aborts once, so two aborts cannot share a program (Rule 13). **`3tk-rules-006.md` adds Rule 8** and shifts the stage rules 8-13 to 9-14; **`3tk-example-rules-006.md`** names `t_identity.c3` as the file keeping the examples rule's promise; **`3tk-reference-011.md`** replaces `010`; `3tk-decisions-007.md` and `3tk-api-005.md` revised in place, every `helper.c3` citation re-resolved. | **Closed.** **123 checks green** — 115 plus two runtime negatives once per build — **146 tests** in each of four builds, doc loop 11 blocks, 0 differing, **463 of 463**, 0 banned words, roundtrip byte-identical, **sanitizers 3 of 3**, which is the run that mattered. **`C-7` was written here**, so `3TK-76`'s step 4 is spent. |
| **3TK-76** | **The sweep.** Ran 2026-09-10 on Opus 5. **94 of 117 call sites in `test/` and `negative/` moved off `inner::internal::*` onto `OuterHelper`** — the population was 117, not the plan's 113 (Rule 13). `t_slot.c3` was the exemplar and settled that **the doc block moves with the code**. `t_queue.c3`, `t_mailbox.c3`, `t_pool.c3`, `t_concurrency.c3` and `t_slot.c3` are black box entire; **`t_identity.c3` split 8 and 18**, and **23 white-box sites each gained a sentence**. **`3tk-rules-007.md` replaces `006`, one list corrected and nothing else**: `overwrite_slot` is off Rule 8's bypass-is-the-violation list, its violation being the second `fill` on a full Slot. Numbering did not shift. Step 4 was spent by `3TK-75`; the ten part-1 callers were re-measured and are still ten, still all in `t_identity.c3`. | **Closed.** **Every figure identical to `3TK-75`'s, which is the proof of a relocation stage** — 123 checks green, 146 tests in each of four builds, doc loop 11 blocks, 0 differing, 463 of 463, 0 banned words, roundtrip byte-identical, **sanitizers 3 of 3**. `src/` was not opened. No script or `.yml` changed, so Rule 12's carry is empty. |
| **3TK-73** | **The design-folder audit. Ran 2026-09-09 on Opus 5. Closed.** Sixteen documents and one script classified — five stay, two crossed to `matryoshka-3tk/design/`, twelve retired to `backup/`. The capability study trimmed, re-measured and crossed as `c3-capabilities-003.md` with a new Q13 folded in from `3tk-build-dist.md`; `3tk-port-findings-005.md` crossed after `A-7` ruled it a different subject from `3tk-decisions-007.md`, with every 3tk `file:line` re-resolved; `3tk-release-while-busy-001.md` read against the ruling of 2026-08-28 and retired with nothing owed; `ref/3tk-doc-loop-005.md` written. **No code was written**, and every figure is identical to 3TK-72's — `A-11`. | **Findings: `P4` closed by the code, `P3` carried into this file, `_Mbox.has_queued` has no readers, and two items in the shared books are still open.** The full account is the log entry of 2026-09-09. |

**The table is in run order, not numeric order.** `3TK-50` is independent of all
of it and blocks nothing.

**3TK-52, 3TK-53, 3TK-54, 3TK-55 and 3TK-56 all ran, 2026-08-28 to
2026-08-30**, and between them the two tools carry the mechanism, the defect
list agrees with them, the shared specification states the rule and `on_close`
is by value.

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
going further. [3tk-example-rules-006.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-example-rules-006.md)
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
`3tk-lifetime-fix-005.md` section 15 said how each
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
- **One port defect, and it is the only one. `P3`.** Written out in full here by
  **3TK-73 on 2026-09-09**, because the audit that held it —
  `3tk-deviations-001.md` — retired the same day, and a live finding may not be
  the only thing in `backup/` that matters. **Nothing cites that file any
  more.**
  - **What it is.** A waiting call can return the condition variable's own
    fault, outside Part 19's outcome set. Both wait loops carry
    `if (f != thread::WAIT_TIMEOUT) return f~;`, which hands the application a
    value from `std::thread`'s faultdef where Part 19 fixes the outcome set of
    every operation. A caller matching on `mtk::CLOSED`, `mtk::TIMEOUT` and
    `mtk::WOKEN` meets something else.
  - **Where.** `pool.c3:412` in `Pool.get_wait` and `mailbox.c3:232` in
    `Mailbox.receive`, re-read 2026-09-09. **Re-print before trusting them.**
  - **Its severity, which is the whole of it.** Unreachable on the current
    posix backend: `NativeConditionVariable.wait_until` returns `WAIT_TIMEOUT`
    or `OK` and aborts on anything else. It is recorded because it is a
    *contract* statement sitting in the port's two most-copied loops, and the
    next port will copy the shape before it checks its own backend. **Both
    sites now say so in a trailing comment**, added since the audit: *dead
    today: `wait_until` can only fail with `WAIT_TIMEOUT`, kept for future wait
    failures.*
  - **`3tk-only`, and not ruled.** Whose: the owner's.
- **`P4` is closed, and 3TK-73 closed it by reading the code rather than by
  ruling anything.** The finding was that the pool's leaver signalled on one
  bucket over a condition variable shared by *n*, against Part 2.6.
  **`grep -n 'signal()' src/pool.c3` returns nothing**, 2026-09-09: every wake
  the pool performs is a `broadcast` — `pool.c3:502` in `put`, `pool.c3:684` in
  `_close` — and `Pool.get_wait`'s timeout path leaves without signalling at
  all. The branch the finding names went with 3TK-70's removal of the two
  vacuous Part 2.6 signals. What used to be the reason nothing was ever lost —
  every path that makes an outer available broadcasts — is now the whole
  mechanism. **The specification did not move for it, and did not have to.**
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
  [3tk-port-findings-005.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-port-findings-005.md) §5a.
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
been run. **`run-builds.sh`, `check-doc-loop.sh`, `move-module-docs.sh roundtrip`
and `run-sanitizers.sh` were all run on 2026-09-10 by 3TK-75; the docgen preview
was last run on 2026-09-09 by 3TK-70.** The
`handle`/`item`/`node` scan was last run 2026-09-04 by 3TK-60.

```
./3tk/run-builds.sh        123 checks, 0 failures, four builds green
                           146 tests in each build
                           115 -> 123 and 145 -> 146 is 3TK-75: two runtime
                           negatives, unstamped_inner and wrong_type_inner,
                           each run once per build, and one test for the null
                           the reading door passes through. A stage that
                           removes a write adds programs; the relocation stage
                           that follows it must move NO figure at all
                           107 -> 115 is 3TK-74: two compile-time negatives,
                           nocompile_no_init and nocompile_no_finish, each
                           run once per build. 3TK-70 held both figures. The count did not move
                           because the two checks it rewrote kept their shape:
                           the module list is still six per-file checks, now
                           comparing the file's ORDERED LIST of module lines
                           against eleven names, and the partition check is
                           still one check plus six banner assertions, now
                           keyed on which module section a declaration is in
                           rather than on the banner. Both went red on the
                           correct change and moved in the same pass
                           95 -> 107 and 143 -> 145 is 3TK-65, which added
                           the shared stamp guard at both boundaries and a
                           negative for each; 3TK-66 and 3TK-68 both held
                           every figure, which for a books-and-names stage
                           is the whole proof
                           89 -> 95 was 3TK-67: it replaced the marker/block
                           check with one two-directional partition check and
                           added six banner assertions, four for the files
                           that have internal declarations and two for the
                           two files that must not grow one
./3tk/check-doc-loop.sh    11 labelled blocks, 0 differing, 463 of 463
                           sentences, 0 missing, 0 banned words.
                           458 -> 463 is 3TK-75: inner's doc block was
                           rewritten and linked's grew its second arm
                           443 -> 458 is 3TK-74: the helper's module block was
                           rewritten and create's and release's both grew.
                           5 -> 11 is 3TK-70: four ::internal modules,
                           mtk::pool::hooks, and mtk::helper, which became a
                           labelled block once doc_blocks.py learned the
                           generic module line. 409 -> 443 is the new module
                           blocks plus the helper's hooks paragraph; nothing
                           was deleted and the per-module figures prove it.
                           --- 3TK-65's reading, superseded ---
                           5 labelled blocks, 0 differing, 409 of 409
                           sentences, 0 missing, 0 banned words.
                           418 -> 408 was 3TK-67 rewriting mtk's module
                           block to orient, and NOT the marker: mailbox
                           (85), pool (134) and queue (34) all held while
                           gaining 18 markers between them, and THAT is the
                           invariant that proves the exclusion, not the
                           total, which any prose edit moves.
                           408 -> 409 is 3TK-65's one added sentence
./3tk/move-module-docs.sh
                roundtrip  byte-identical, over eleven blocks
./3tk/preview-docs.sh      read off the generated page, 2026-09-09:
                           mtk 10, mtk::inner 13, mtk::inner::internal 14,
                           mtk::queue 11, mtk::queue::internal 1,
                           mtk::helper 11, mtk::mailbox 17,
                           mtk::mailbox::internal 6, mtk::pool::hooks 1,
                           mtk::pool 16, mtk::pool::internal 11.
                           mtk::inner was 26 before the split and 13 + 14 is
                           27, the one extra being inner_offset from the
                           folded third section. mtk::helper is still the
                           only page marked generic; all eleven modules
                           carry a description
./3tk/count_src_loc.sh     684 lines by L-1's definition, 2,245 raw
                           (the script is in matryoshka-3tk/scripts/)

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
./3tk/run-sanitizers.sh    3 of 3 clean, 146 tests in each, run by 3TK-75
                           on 2026-09-10: thread safe -O0, thread fast -O3,
                           address safe -O0. THAT is the run that matters for
                           3TK-75 — removing a write is a concurrency change
                           --- superseded ---
                           not re-run this stage — 3TK-60 changed no
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
- **A misspelled hook name is silently not called. Raised by INTR 11,
  2026-09-09.** `OuterHelper.create` compiles `$if $defined(outer.init):`, so a
  wrong **signature** or **return type** is loud — the branch compiles and then
  fails — but a wrong **name** (`Init`, `initialize`, `deinit`) answers false,
  the branch vanishes, and nothing is reported at any stage. `alloc::new_try`
  zeroes, so the result is a plausible zeroed outer whose failure surfaces far
  from its cause. **Candidate stage:** a compile-time near-miss guard that
  `$error`s when an outer defines a near-miss name and neither hook. **`3TK-70`
  only documents it.**
- **Three from the outside review, INTR 11, none acted on.** `UNKNOWN_IDENTITY`
  is both a fault and a defect and the dual nature is documented nowhere in one
  place; the memory-order assumptions are unwritten beyond the ACQUIRE/RELEASE
  pair on the closed flag; and `send` returns `CLOSED` where `put` returns
  `void`, under one *Slot is the answer* convention. The log entry says which
  advice each came from.
- **What an outsider currently sees.** The published `matryoshka-3tk` is version
  0.0.1, sources only — no `test/`, no `examples/`, no scripts, an older `src/`.
  Every review of it will keep reporting *"zero tests, zero examples"*. **Not a
  defect and no stage fixes it**; the copy is the owner's step, and 3TK-62
  onward are queued on it.
- **Managed Outers — re-thinking. Absorbed by 3TK-61 on 2026-09-06 and no
  longer a flag.** The discussion happened, and it went further than the flag:
  *managed* stops being a concept altogether. `create`/`release` take the
  allocator, the `Allocator` field becomes optional and serves the Outer's own
  allocations, and the code moves to module `xtn`. Ruled as `RT-5`, `RT-12`
  and `RT-13`; built by **3TK-64**.

## Rules that hold across every stage

- **Each stage starts cold.** Its named inputs plus this file are enough.
- **Before the first stage and after every stage, the session says whether to
  compact, clear, or do nothing** — unasked, with the reason — **and when it is
  clear, it gives the exact prompt to continue with**, the two-line shape in
  *How to start after a clear*. **Ruled by the owner 2026-09-08**, strengthening
  the older *"each stage ends with advice"*.
- **Before every stage, the session says which model is suitable for performing
  it, by name, and why.** **Ruled by the owner 2026-09-08**, names pinned the
  same day. Two-way: a stage that is a mechanical sweep against a settled rule
  **says so**, rather than silently taking the strongest model. The basis is how
  much of the stage is **deciding** rather than **applying**. **Advice, not an
  action** — the session names the model and the choice stays the owner's. **030
  pins `3TK-69` as Sonnet 5**, revising 029's Opus 5 because the sitting of
  2026-09-08 spent the deciding — see `L-11`. **A pinned name that has gone stale is not a reason to
  stall** — the basis in `Rule 8` governs and the stage picks its nearest
  equivalent.
- **Both of the above are *stage rules* and their statement moves to
  `3tk-rules-001.md`'s second part**, created by `3TK-67`. This file then keeps
  only the operational line a cold session needs — which stage is next, which
  model, which prompt — and cites rather than re-argues, the way it already
  treats `3tk-boundaries-001.md`.
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
- **`ref/`** — **holds only [ref/3tk-doc-loop-005.md](ref/3tk-doc-loop-005.md)
  now.** 3TK-60 moved the api table and the decisions record to
  `matryoshka-3tk/design/` and the superseded copies to `backup/`. **`ref/`
  takes no new versions** — owner's ruling: every new document goes to
  `matryoshka-3tk/design/`.
- **[`matryoshka-3tk/design/`](https://github.com/g41797/matryoshka-3tk/tree/main/design)**
  — a second, separate local repo, for light builds, doc-site preview, and the
  live copies pushed there after each verified step. **The reference book, the
  example rules and the pattern catalog live there now, not in this repo's
  `ref/`**, and since 3TK-60 the api table, the decisions record and the terms
  document too: `3tk-reference-011.md`, `3tk-example-rules-006.md`,
  `3tk-patterns-004.md`, `3tk-api-005.md`, `3tk-decisions-007.md`,
  and **`3tk-rules-007.md`** — 3tk's own rules document, normative, for every
  rule that binds the C3 port and is not already a rule in the common tk set,
  created as `001` by `3TK-67` and rewritten by `3TK-70`. `3tk-terms-001.md` and
  `3tk-boundaries-001.md` are spent and in that repo's `backup/`. It does not bind `3tk/examples/`, which the example rules govern.
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

**No stage is queued.** `036` is spent, `3TK-50` waits on the owner, and the next
plan is the owner's to open.

For orientation, or to start whatever the owner names:

```
Read design/secondary/lang/c3/3tk-status.md and report where the 3tk work stands.
```

**The rules every stage is written against are in
[matryoshka-3tk/design/3tk-rules-007.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-rules-007.md),
and are not restated here.** Two parts: the port rules and the stage rules —
*compact/clear/nothing*, the model recommendation, the exemplar before the sweep,
the script-and-CI port, and *fix the definition, do not halt*. **`001` is in that
repo's `backup/` and is not cited.**

**What `3TK-70` left standing that a later stage must not re-derive.**

- **A `@private` declaration in a submodule is not visible to its parent.**
  Measured on c3c 0.8.3. That is why `_Mbox`, `_Pool` and `inner_offset` are
  public: the split won, per the owner's ruling that the intent is visibility on
  the docs site and not preventing use.
- **A parent module reaches its child with no import** — `mtk::inner` writes
  `internal::from_inner(...)`. A cousin needs one, and `import mtk;` supplies it,
  because importing a module imports every submodule of it.
- **A non-generic submodule under the generic `mtk::helper` renders sanely in
  docgen**, on its own page and with no generic parameter. `M-8`'s probe, run in
  a scratch directory. **Do not re-run it.**
- **`doc_blocks.py` walks sections, not files**, and its module pattern accepts a
  generic module line. Eleven modules, eleven labelled blocks, and `mtk::helper`
  is one of them.
- **The `[3tk: ...]` marks are 49 and every one resolves to a live specification
  Part.** The test a later stage applies is not which document an id belongs to
  but whether that document is live: `backup/` is transient, so an id that
  resolves there goes.
- **The free crossings are spelled `inner::internal::`.** Two lines in
  `examples/` name them, both allow-listed.

**`[&in]` on `to_inner` was refused, and the refusal is closed.** `3TK-67` left
the call to `3TK-65` and `3TK-65` said no: `to_inner` accepts null on purpose,
and the annotation would be a new runtime abort smuggled in under a formatting
rule. `test/t_identity.c3`'s `to_inner_takes_null_and_answers_null` and
`the_identity_check_tolerates_null` hold it. **No stage reopens it without a
program showing what the annotation would catch.**

**Not yet copied to `matryoshka-3tk`'s `src`/`test`/`negative`/`examples`, or
pushed** — 3TK-62, 3TK-63, 3TK-64, the INTR, 3TK-pre-65, 3TK-67, 3TK-65, 3TK-66
3TK-68 and 3TK-70 are all waiting on that, and it is the owner's step.
**3TK-70 adds all six `src/` files, `test/` and `negative/`.** **3TK-66 changed
no `src/`**, so what it adds to the queue is `examples/` alone — 26 files. Every
`design/` document it touched was edited directly in `matryoshka-3tk` and needs
no copy. **3TK-68 adds the renamed `negative/insert_linked_outer.c3` and
`run-builds.sh`'s line 60**, which is the one difference its audit found in
`matryoshka-3tk`'s copy of that script.

**The rethinking is spent, and its document with it.**
`3tk-boundaries-001.md` and `3tk-terms-001.md` moved to
`matryoshka-3tk/design/backup/` on 2026-09-08 — 3TK-66's closing act, and the
content had dissolved into the source and the books first. **`backup/` is
transient, so neither is a source of truth and no stage cites either as one.**

**Where each part of it lives now.** The governing rule, the rulings `RT-1` …
`RT-18`, the helper requirements, the proposed shape and the variants are
entries in
[3tk-decisions-007.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-decisions-007.md),
which cites them by marker as **history** — which sitting ruled the entry — with
`007` and `../3tk/src` as what stands where they would differ. The surface, the
invariants and *what is deliberately absent* are in
[3tk-reference-011.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-reference-011.md).
The rules that bind a stage are in `3tk-rules-007.md`. **The measurements and
the narrative are in [3tk-log.md](3tk-log.md), under 3TK-61 and 3TK-66.**

**All fifteen questions were closed before the document was spent** — `Q-1` …
`Q-15`, ruled by the second sitting of 3TK-61 on 2026-09-06 and built by
3TK-62 … 3TK-66. **A stage that finds itself needing an answer has found a gap;
it reports the gap to the owner before continuing, and does not go to `backup/`
for it.**

**What remains parked is parked, and is not the rethinking's.** `PL-1`, `PL-2`,
`PL-4`, `PL-5`, `PL-8`, `PL-9` and the container re-entrancy guard are in
`007`'s body, where a later stage will find them.

**3TK-61 ran on 2026-09-06 in two sittings and closed. It changed no code** —
`run-builds.sh` was re-measured green and unchanged, which is the whole
verification a stage that only rules and records can offer. The second sitting
added the proposal, sections 10-15, and four measurements; its probes were
written in a scratch directory and **nothing under `3tk/` was touched.** Plan 024 is **fully
spent** and is in `backup/`.

**3TK-60 ran on 2026-09-04 and closed.** The two terms, in the source and in
the books; six documents written, three moved repo.

**3TK-59 ran on 2026-09-04 and closed**, all six steps —
`3tk-staging-plan-023.md` is spent and moved to
`backup/`.

**3TK-58 ran on 2026-09-03 and closed** — `Mailbox`/`Pool` are opaque
types, `is_quiet()` exists on both, and the three test files are back to
black-box.

**3TK-50 is separately still waiting on the owner** — it has no next step
(catalog sections with a code shape are all covered) and eleven steps are
not yet copied to `matryoshka-3tk` and pushed/previewed there; that is
independent of 3TK-58 and does not block it.

## The stages that have run

**Seventy-seven rows, and the log has an entry for every one.** 3TK-62, 3TK-63 and
3TK-64 were added by 3TK-pre-65, which found them missing; the four of 2026-09-08
were added when 030 was written. **The table is in execution order, so 67, 65, 66,
68 sit out of numeric order deliberately.** This table is the list, not the
record.

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
| **3TK-67** | the landing page, the marker, and the rules file | 2026-09-08 |
| **3TK-65** | the safe-build checks | 2026-09-08 |
| **3TK-66** | the books and the examples | 2026-09-08 |
| **3TK-68** | the names and the scripts | 2026-09-08 |
| **3TK-69** | the source LOC | 2026-09-08 |
| **3TK-70** | the module split, and the hooks page | 2026-09-09 |
| **3TK-71** | the tests allocate their outers | 2026-09-09 |
| **3TK-72** | the example groups | 2026-09-09 |
| **3TK-73** | the design-folder audit | 2026-09-09 |
| **3TK-74** | the outer's hooks become required | 2026-09-09 |
| **3TK-75** | the helper stopped writing | 2026-09-10 |

**Seven rows were added on 2026-09-10 by `3TK-75`**, which found the list had
stopped at `3TK-68` while seven stages had run past it. The count above was
corrected with them.

**3TK-50 is missing from the list because it has not run** — it is plan 019's
leftover and is in the table above.

## The interrupt stages

**An INTR stage is important work that is not part of the flow.** The log has
each one. **The numbering is the owner's, not a count of rows** — this file said
*"seven"* while listing rows through INTR 8, and the unnumbered INTR of
2026-09-07 (the state came out of `OuterHelper`) is in this file and in no table.
The owner ruled the 2026-09-09 one **INTR 11**, and that settles it.

| | what it was | touched code |
|---|---|---|
| **INTR 1–3** | four implementation reviews triaged into seven problems and five questions; the questions answered; **six of the ten items fixed** | **INTR 3 did**, and paid the doc loop inside the stage |
| **INTR 4–5** | two reviews of the lifetime document absorbed, twenty points then thirty-three | no |
| **INTR 6** | **the owner's ruling on `Q5`**, and the document rewritten around it | no |
| **INTR 7** | the third review — ten clarifications, and **reviewing closed** | no |
| **INTR 8** | this file compacted, 2,358 lines to a list and a state | no |
| **unnumbered, 2026-09-07** | the state came out of `OuterHelper`; `typeid outer_tid` deleted | **yes**, and nothing was owed |
| **INTR 11** | an outside AI review of the **published archive** triaged — five pieces of advice answered and closed, three flags raised, and **60 surviving `[3tk: ...]` marks measured** against a status sentence that said they were gone | no |

**`3tk-open-defects.md` was the working list** for what INTR
1–3 found: one table and one section per item, edited in place. **`P6` was the
last item open** and was ruled on 2026-08-28; **3TK-56 built it on 2026-08-30.
Nothing on that list is open any more.**
