# 3tk — status

Current state of the 3tk line of work. One screen. Updated after every stage.

This file is the entry point for a cold session. Read it, then the stage named  
by the owner in [3tk-staging-plan-009.md](3tk-staging-plan-009.md).

## Scope

The Matryoshka port family: **otk** (Odin), **ztk** (Zig, this repo), **3tk**  
(C3), **dtk** (D). 3tk is the active target. otk needs refactoring, later. ztk  
needs tuning, later. dtk has a prepared folder and no stage has run —  
[../d/dtk-status.md](../d/dtk-status.md).

The first deliverable is not C3 code. It is a portable specification of  
Matryoshka, language-neutral and self-contained, usable as the sole input for  
any port.

## Where the work lives

Everything for these stages lives in this folder,  
`design/secondary/lang/c3/` — plans, status, log, reviews, notes, and the code  
at `3tk/`.

**Two of them left on 2026-08-23.** The portable specification and the ztk audit  
now live in [`../common/`](../common/README.md), because they bind every port  
and never bound only this one. The specification always said so of itself — *a  
port is written from this file alone* — while sitting in a consumer's folder,  
and the revision of that day sent the bill: two of the twenty-seven review items  
were *specification* defects, and fixing them here alone would have left the  
same trap set for D and Odin. A shared input inside one consumer's folder is a  
fork waiting to happen. `common/` also contains  
[port-flow-001.md](../common/port-flow-001.md), the 3tk process written as  
process. Every link that named a moved file was corrected in place, both  
directions.

`c3/backup/` contains what is no longer read: the seven raw drafts, superseded by  
`3tk-drafts-review-001.md`, the review that retired proposal 002, and **every  
superseded version** — of the plan, the proposal and the specification. The  
live folder is what is current; `backup/` is the record. Moved 2026-08-23, and  
every link that names a moved file was corrected to `backup/...` in place.

`design/STATUS.md` and `design/STATUS-LOG.md` are not touched by this work and  
show no trace of it.

## Rules that hold across every stage

- Each stage starts cold. Its named inputs plus this file are enough.
- Each stage ends with advice: clear the context, or do not, and why.
- Finishing a stage does not start the next. The owner names it.
- **inner** = the embedded structure. **outer** = the struct that embeds it.
  Never "parent".
- Porting is not transpiling. The specification says what to preserve; each
  port decides how to spell it.

## Stages

| Stage | What | Output | State |
|---|---|---|---|
| 3TK-0 | staging plan, status, log | this folder | DONE 2026-08-23 |
| 3TK-1 | ztk audit — sources and docs | `ztk-audit-001.md` | DONE 2026-08-23 |
| 3TK-2 | the portable specification | `matryoshka-specification-001.md` | DONE 2026-08-23 |
| 3TK-3 | review of the seven c3 drafts | `3tk-drafts-review-001.md` | DONE 2026-08-23 |
| 3TK-4 | C3 capability study | `c3-capabilities-001.md` | DONE 2026-08-23 |
| 3TK-5 | the 3tk porting proposal | `3tk-porting-proposal-001.md` | DONE 2026-08-23 |
| 3TK-6 | the toolkit, in C3 | `3tk/` + `3tk-toolkit-notes-001.md` | DONE 2026-08-23 |
| 3TK-7 | the two containers, in C3 | `3tk/` + `3tk-containers-notes-001.md` | DONE 2026-08-23 |
| 3TK-8 | the design review answered, the hiding question measured | `3tk-porting-proposal-004.md` + `3tk/` | DONE 2026-08-23 |
| 3TK-9 | the sanitizer run | `3tk-sanitizer-notes-001.md` + `3tk/` | DONE 2026-08-23 |
| 3TK-10 | the core redesign, as a proposal | `3tk-core-redesign-proposal-001.md` | DONE 2026-08-23 |
| 3TK-11 | the core redesign, in code | `3tk/` + [3tk-core-redesign-notes-001.md](3tk-core-redesign-notes-001.md) | DONE 2026-08-23 |
| 3TK-12 | the deviation audit — the port measured against the specification | [3tk-deviations-001.md](3tk-deviations-001.md) | DONE 2026-08-24 |
| 3TK-13 | specification 003 | [matryoshka-specification-003.md](../common/matryoshka-specification-003.md) | DONE 2026-08-24 |
| 3TK-14 | the helper surface, re-thought | [3tk-helper-proposal-001.md](3tk-helper-proposal-001.md) | DONE 2026-08-24 — twelve items + E6, E7. **All ruled** |
| 3TK-15 | the two debts of 3TK-13 — A3 and A5 | `3tk/` + `3tk-debts-notes-001.md` | **DECLARED, not authorized** — **the one to run next.** The code stage it waited for has run |
| 3TK-16 | the helper surface, in code — H0, H0b, H5, H10 | `3tk/` + [3tk-helper-notes-001.md](3tk-helper-notes-001.md) | DONE 2026-08-24 — 35 aliases to 0. **V19 filed** |
| 3TK-17 | Part 7.1 reworded — E6, V19 | `../common/matryoshka-specification-004.md` | **DECLARED, not authorized.** Runs last, and **before dtk's first stage** |

## How to continue after a clear

**3TK-16 has run. `helper.c3` and `managed.c3` are the surface 3TK-14 ruled,
and `3tk/` is green.** Two stages remain and neither is authorized.

**The order is not the numbering, and one leg of it is now spent:**

```
3TK-16  (code, DONE)   →   3TK-15  (the debts)   →   3TK-17  (the specification)
```

**Next: 3TK-15 — the two debts of 3TK-13, A3 and A5.**

```
Run 3TK-15 from design/secondary/lang/c3/3tk-status.md
```

**It was held behind 3TK-16 and the hold is over.** Plan 008 put it there
because *"A5 repoints doc comments in the files 3TK-14 may rewrite"*, and those
files have now been rewritten: `helper.c3` and `managed.c3` were written from
scratch and carry correct citations, and **every other file's stale `002`
citation was deliberately left where it was.** That is A5's whole remaining
scope and it is now stable ground.

**Then 3TK-17 — Part 7.1 reworded, and specification 004.** It is independent
and has one constraint that points outside this folder: **it wants to run before
dtk's first stage.** D's idiomatic answer to *generate code per type* is
templates and mixins — call-site expansion, the same shape as a C3 macro — so
Part 7.1 as written sets dtk the identical trap it set 3tk. **3TK-16 filed V19
against that Part** and did not touch `../common/`; 3TK-17 is the stage that
may.

**`3tk/` is green, and the counts are this stage's own** — `run-builds.sh` 59
checks and 0 failed, `run-sanitizers.sh` 3 checks, **87 tests** over four
builds. 85 became 87: 3TK-16 added two tests for the method surface and removed
none.

---

## What 3TK-16 built

**[3tk-helper-notes-001.md](3tk-helper-notes-001.md).** The mirror of 3TK-11 —
a ruled proposal, built, with no ruling of its own.

**The number is 35 to 0.** Thirty-five `alias` lines named the helper; there are
none left in `src/`, `test/` or `negative/`. `test/common.c3` is four struct
declarations and a doc comment, and **a new outer type costs nothing at all
before it can be used.**

- **H0 / H0b** — `mtk::helper` and `mtk::managed` are ordinary modules of macros
  over `$Type`, plus `to`/`as`/`must`/`move` as methods on `Handle` and `Slot`.
  Neither module is generic. No application writes an alias or an instantiation.
- **H5** — `to_handle`, `from_handle`, `must_from_handle`, `is_mine`. *inner*
  keeps `Inner`, `inner_offset`, `src/inner.c3` and all the prose, and stops
  naming a handle.
- **H10** — `mtk::managed`, `managed.c3`, `t_managed.c3`,
  `nocompile_managed_no_allocator.c3`, and the fixture `struct Holder`. The
  module header disarms the garbage-collector reading in one sentence and
  records E7's: the owning distinction lives at the call site, and D10 is why.
- **The bookkeeping** — `3tk-deviations-001.md` gains **V19** (Part 7.1, an
  **S**, scope `every port`, the only verdict changed) and Part 7.3 moves from
  *two generic modules* to *two modules*. **One line** of `run-builds.sh`.

**The named trap held.** Part 7.1 was wrong while the stage ran and the stage
neither obeyed it nor fixed it. `src/helper.c3`'s header carries a sentence
telling the next reader not to "fix" the file to match it — that guard comes out
when 004 is cut.

---

## What 3TK-14 decided

**3TK-14 has run, and it ended where it was meant to: at a proposal.**
[3tk-helper-proposal-001.md](3tk-helper-proposal-001.md). **Nothing under
`3tk/` was changed and no item is ruled.** Eleven numbered items — H0, H0b and
H1 to H9 — each accept-or-reject on its own, and fifteen compiler measurements
behind them.

**The stage had two inputs and the second one changed the answer.** The first
was [3tk-helper-alternatives.md](3tk-helper-alternatives.md). The second was the
owner's advice, mid-stage, to read `std::collections::interfacelist`,
`std::collections::anylist` *and another sources in std*.

**The compiler settled the note's argument first.** Both shapes the note
proposed are unavailable in C3 0.8.3, and its own *Important correction* had
already guessed the first: a generic module cannot declare a method on its type
parameter — *`'Type' could not be found`* — and an instantiated generic module
cannot be aliased as a namespace, in any of four spellings. A generic module is
not a value and not a type; it can be named only through one of its
declarations, and that is the whole reason `test/common.c3` looks the way it
does.

**Then the stdlib settled the stage's own answer.** C3's core already carries
Part 6.3's two crossings for its own type-erased value, and it does **not**
generate a helper object per type for them — `core/builtin.c3:111-134`:

```c3
macro anycast(any v, $Type)  { if (v.type != $Type) return TYPE_MISMATCH~; ... }
macro any.to(self, $Type)    // the checking crossing
macro any.as(self, $Type)    // the asserting crossing, via @require
```

The type is named **at the call site**. There is no instantiation and no alias.
The stdlib reaches for the generic-struct shape for *containers*, which have
state — `interfacelist.c3:7-29`, `anylist.c3:21`. **The helper has no state.**

**So H0 is what the stage recommends: the helper becomes macros, and no
application writes an alias for any type, ever.**

```c3
Msg m;
mtk::helper::init(&m);                 // type inferred
Handle h = mtk::helper::handle_of(&m); // type inferred

Msg* p = h.to(Msg);      // checking      -- C3's own name, from `any`
Msg* q = h.as(Msg);      // asserting     -- ditto, and a @require contract
Msg* c = s.move(Msg);    // moving, both postconditions
```

Measured against the real `src/`, containers included: **zero errors, seventeen
behavioural assertions true, a live mailbox round trip, identical under
`-O3 --safe=no`, and eight alias lines deleted outright from `mailbox.c3` and
`pool.c3`.** `test/common.c3` loses all twenty of its alias lines and keeps only
its four structs. `@require` turns out to be D6's tier 2 natively — it aborts in
a safe build naming the caller's line and compiles out under `--safe=no`.

**H0's one real cost is named and not decided.** Under H0 there is no per-type
helper object, so **Part 7.1's literal words stop describing the port** — *for
each outer type there is a helper bound to that one type*. It is a SHOULD, every
Part 7.2 member is present, every crossing is still in one file. Accepting H0
means either recording a deviation or rewording Part 7.1 in `../common/`, and
**3TK-14 was allowed to touch neither.** H0b also moves D10's *spelling* — two
generic modules become two modules — which Part 7.3 permits and which the stage
raises as a question rather than answering.

**H1 to H3 are the alternative, if H0 is rejected**: a generic struct inside the
generic module, one ALL-CAPS alias per type instead of nine. That shape is the
stdlib's own idiom for containers and it was measured first, so it stands
complete. **H4 to H9 are independent of the choice.**

**Three findings that hold under either surface:**

- **`TYPE` must stay public — the note is wrong there.** The pool is *keyed* on
  the identity: `Pool.create(a, typeid[] tags, …)`, `Pool.get(typeid want, …)`,
  `Pool.count_of(typeid)`. `OWNED_TYPE` is read at 46 call sites in `test/`. An
  application that cannot name its type's identity cannot create a pool. (Under
  H0 it names it as `Owned::typeid` and the alias disappears.)
- **Hiding `OFF` is a speed bump, not a border.** `mtk::inner_offset` is public
  at `src/inner.c3:238` and application code can do the arithmetic through it
  today — that compiles. It cannot be closed either, because C3's `@private` is
  module-scoped and `mtk::helper` is a submodule. **Part 7.5's MUST is held by
  convention and the layering checks, not by visibility, and always was.**
- **The count in the plan is wrong.** `test/common.c3` carries **twenty** alias
  lines, not seventeen.

**Green, trivially: `run-builds.sh` 59 checks, `run-sanitizers.sh` 3 checks, 85
tests.** No file under `3tk/` was touched.

## What the owner ruled, 2026-08-24

**H0, H0b, H5 and H10 are ACCEPTED. Every H item is ruled.** The helper becomes macros; `mtk::owned`
follows; the members are named for the **handle**. H1 to H3 are withdrawn, H4,
H6, H8 and H9 are settled or forced by H0, H7 stands as recommended.

**The accepted surface, and it is what a cold session should read first:**

```c3
Msg m;
mtk::helper::init(&m);                  // type inferred, no argument
Handle h = mtk::helper::to_handle(&m);  // type inferred

Msg* p = h.to(Msg);      // checking crossing   -- C3's own name, from `any`
Msg* q = h.as(Msg);      // asserting crossing  -- a @require contract
Msg* a = s.to(Msg);      // checking, from a Slot
Msg* b = s.must(Msg);    // asserting, from a Slot
Msg* c = s.move(Msg);    // moving, both postconditions
```

**No application writes an alias for any type, ever.** `test/common.c3` keeps
its four structs and loses all twenty alias lines; `mailbox.c3` and `pool.c3`
lose eight between them.

**H5's evidence, because it looked like churn and was not.** R1's own table —
`3tk-core-redesign-proposal-002.md:182` — gives the reason for `to_inner` as
*"it now says the direction"*. That is the `to_` prefix, not the noun, and the
same pass kept the word *handle* for the type at `:174`. **H5 finishes R1
rather than reversing it.** *inner* keeps `Inner`, `inner_offset`,
`src/inner.c3` and the prose; it stops naming a handle.

**One measurement of this stage was corrected and re-run, not edited.** M11 to
M13 were measured with `handle_of`, which was the stage's own invention and
dropped the very prefix R1 valued. The accepted spelling is `to_handle`, and
the probes were **re-run** so every quoted line is still output from a program
that ran — seventeen assertions true, zero errors, identical under
`-O3 --safe=no`.

**H10 — the rename, accepted.** `mtk::owned` becomes **`mtk::managed`**, and the
test fixture `struct Owned` becomes **`struct Holder`**. The word is Zig's
sense, not .NET's — *the item keeps its allocator* — and the module's doc
comment says so in one sentence, because **dtk is scoped `@nogc`** and is the
port that would otherwise meet the word wrong.

Measured after the ruling: the rename compiles clean and the seventeen
assertions still hold. **`run-builds.sh`'s expectation string does not change** —
the compile-time negative is keyed on the literal `mtk::helper`
(`run-builds.sh:71`) and the message at `src/inner.c3:274` names both modules,
so only its second half moves. **One line of the harness changes**, and only if
`negative/nocompile_owned_no_allocator.c3` is renamed with the module — which
the stage advises, since that word names the module you tried to use.
`test/t_owned.c3` is free: `c3c test` discovers it.

**E6 and E7 were ruled too, and they came out asymmetrically.**

**E6 — Part 7.1 is a *specification* defect, an S/V row scoped `every port`, not
a port deviation.** Of its three clauses, only *"for each outer type there is a
helper bound to that one type"* fails under H0 — and that clause is **ztk's
mechanism**. Part 7.1's own closing sentence sets the floor lower than H0 sits:
*a port with no compile-time generation writes the same block by hand and loses
only the typing.* H0 generates; it just has no named per-type object.

**This is the disease 3TK-13 existed to cure** — 002 stated Zig's mechanism
where the design has only a promise, fourteen times, and 003 fixed fourteen.
**Part 7.1 is the fifteenth, and 3TK-13 missed it.** The deciding argument is
**dtk**: no stage has run there, and D's idiomatic answer to *generate per type*
is templates and mixins — call-site expansion, the same shape as a C3 macro.
Fixing 7.1 here would leave the identical trap set for D and for Odin, which is
the argument that moved the specification to `../common/` in the first place.

**E7 — nothing is lost, and the premise was wrong.** The owning distinction was
never a property of the type in 3tk: `struct Owned` carries no marker, and
`src/owned.c3:5` says so — *"C3 has no property to branch on and needs
neither."* D10 already moved the decision off the type; H0b moves it from the
alias line to the call line, both on the application's side. The build-time gate
survives, measured under the rename: *type Plain has no Allocator field; use
mtk::helper instead of mtk::managed.* **No change to anything.**

## What is owed, and by which stage

**3TK-14 could write none of the following, and did not.**

| Owed | Who | Why not 3TK-14 |
|---|---|---|
| The **S/V row** for Part 7.1 in `3tk-deviations-001.md` | the code stage | that file is 3TK-12's output, and a stage may not rewrite a finished stage's output |
| Part 7.3's row updated, *two generic modules* → *two modules* | the code stage | same |
| **Part 7.1 reworded** in `../common/` | **a stage that does not exist** | no stage may touch `../common/` under plan 008 |
| One line of `run-builds.sh` for the renamed `nocompile_` file | the code stage | H10 |
| The GC sentence in `managed.c3`, and the call-site-distinction sentence | the code stage | H10, E7 |

**The gap worth naming: the specification stage is not declared.** Plan 008 has
3TK-14 and 3TK-15 and nothing else. Rewording Part 7.1 is small — state the
promise, show both realizations marked *ztk* and *3tk*, as 003 did for the other
fourteen — but it needs a stage, and it wants to run **before dtk's first
stage**, not after.

**No code stage has been named, and it is now the only thing missing.** Every H
item is ruled; H0, H0b, H5 and H10 all land in one stage, alongside 3TK-15's A5,
which repoints doc comments in the same files. One pass instead of five.

**E6 and E7 are ruled**, so the code stage knows what it owes — the table above.
The one thing that stage cannot do is the Part 7.1 rewording, which is not
3tk's to make alone and has no stage.

## The state before 3TK-14 — 3TK-13 and the specification


**3TK-13 has run. The gap is closed.**
[matryoshka-specification-003.md](../common/matryoshka-specification-003.md) is
the source of truth for every port, and 002 is in
[`../common/backup/`](../common/backup/). A cold session reads this file, then
003's change log — every difference from 002 is named there, so nothing needs
diffing.

**Eighteen changes, and one theme.** 002 was written from ztk, and in fourteen
places it stated Zig's *mechanism* where the design has only a *promise*. Those
Parts now state the promise and show both realizations, marked *ztk* and *3tk*.
Beyond the fourteen: **one new MUST** — Part 12.3, what the pool does with a
hook's result if the pool closed while the hook ran, which is the rule P1 fell
through and which 002 did not have at all; **one deleted operation** — the
pool's *put a list*; **one deleted Part** — 8.6's O(n) insert walk, tombstoned
in place; and **one weakened MUST** — Part 12.2's close hook is *called once by
close, and once more per straggling put*. That last one is the only place 003
weakens anything, and it is named twice in the change log so nobody meets it by
accident.

**No Part renumbered and no invariant row renumbered.** A deletion is a
tombstone in place. Part 8.6 says it was deleted; invariant row 16 says it was
retired and 16b replaces it; row 35 is new. Assumption A1, and roughly forty doc
comments in `3tk/src/` depend on it.

**Nothing in `3tk/` was touched** — `run-builds.sh` 59 checks, still green,
trivially.

**3tk-only findings did not reach `../common/`.** The audit's P1 to P6 are the
port failing rules that already said the right thing, and the split existed to
keep them here. Part 2.6 and Part 19.3 are unchanged for exactly that reason.

[3tk-deviations-001.md](3tk-deviations-001.md) stays the record of the
measurement; *The gap between the port and the specification* below is now
history and says so.

**Green: `run-builds.sh` 59 checks, `run-sanitizers.sh` 3 checks, 85 tests over
four builds.** Two code changes since 3TK-11, both ruled by the owner on
2026-08-24 after the audit reported: `InnerStack.push_slot` and its test deleted
(P6), and **the late close fixed in `Pool.put` with a test that holds the window
open** (P1). 85 tests before, 84 after the deletion, 85 again with the new one.

**Nothing is authorized. 3TK-15 is declared, in
[3tk-staging-plan-009.md](3tk-staging-plan-009.md), and does not run until the
owner types its line. 3TK-14's eleven items are unruled.**

**3TK-15 — the two debts of 3TK-13. This is the one to run next**, and it was
always to run after 3TK-14, because A5 repoints doc comments in the files
3TK-14's items may rewrite:

```
Run 3TK-15 from design/secondary/lang/c3/3tk-status.md
```

- **A3 — the port breaks a MUST in its own specification.** `Pool.get` returns
  `NOT_AVAILABLE` for an identity the pool was not created with, from **every**
  mode; Part 19.3 says it comes only from the available-only mode. A `@check`
  catches it in a checking build and expands to nothing under `--safe=no` — D6 —
  so it is the observable behaviour of a fast build. **Already ruled**: the port
  gets a distinct outcome and 003 stays untouched. `pool.c3:288-290`.
- **A5 — about forty doc comments cite a superseded document.** `3tk/src/` names
  `matryoshka-specification-002.md`, which moved to `../common/backup/` on
  2026-08-24. Nothing breaks; they are stale pointers. **The part that is not
  mechanical**: where 003 changed the rule a comment cites, the comment's claim
  changes too — a comment citing Part 8.6 is citing a **deleted** Part.

**Telling otk that its input moved is in neither stage and has none.** dtk was
told — one paragraph in [`../d/dtk-status.md`](../d/dtk-status.md), which is the
whole of what 3TK-13 was permitted to write outside `../common/`. The Odin folder
has no stage and was not touched. **If that matters, it needs the owner to name
it.**

**The record of what the owner ruled after the audit is kept below.** Two things
were ruled and fixed in code; two were defaulted as assumptions.

1. ~~**P1**~~ — **RULED AND FIXED 2026-08-24.** `Pool.put` gave up the mutex
   across the hook, as Part 12.3 MUST requires, and a `Pool.close` inside that
   window drained the pool and ran the close hook before `put` relocked. The
   item was then with nobody: the caller's Slot was cleared, so Part 9.4 said
   the pool had it, and the close hook had already run. **The owner ruled both
   halves** — re-read the closed flag after the hook, and send what the call is
   holding to `on_close`. **Part 12.2's *called once* is deliberately bent**: a
   hook may see a second call carrying stragglers and must not destroy its own
   state on the first. Two calls to cleanup beats leaked parts. `t_concurrency.c3`
   holds the window open deterministically and fails on invariant 34 without the
   fix. **V11 is no longer an undetermined row — 003 writes this rule**, and its
   third clause is the only place 003 weakens an existing MUST.
2. ~~**P6**~~ — **RULED AND DONE 2026-08-24.** Measured at the owner's
   instruction: `3tk-who-supports-slot.md` is advice, and the code answered most
   of it. **Part 8.2's *add at the back from a Slot* is used**, by a pool hook
   filling `extra` from a Slot — `t_pool.c3:70`, Part 12.5's composite
   mechanism — so `InnerQueue.push_back_slot` stays and Part 8.2 does not change
   for it. `InnerStack.push_slot` had no caller but its own test and R13 put it
   out of the application's reach, so **it and `push_from_a_slot` are deleted**.
   The stack has four operations. **This stopped being an every-port question.**
3. **P2** — `NOT_AVAILABLE` from every get mode: a distinct outcome, a tier 1
   site, or an accepted checking-build promise.
4. **P5 and V18** — whether Part 6.5's dispatch table is the toolkit's element
   or the application's.

**P3 and P4 need no ruling.** Both are small, both are 3tk-only, and neither
loses anything today — see the audit's §2.

### The assumptions 3TK-13 starts from, 2026-08-24

**These are assumptions, not rulings, and the difference is deliberate.** The
owner was asked five questions before the cut, said *take all recommendations,
record them as assumptions*, and that is what these are: defaults the stage
proceeds on. **003's change log records each one as an assumption**, so a later
reader can overturn any of them without having to work out whether a ruling was
being contradicted.

| # | Assumption | Why | What it costs to overturn |
|---|---|---|---|
| A1 | **Parts do not renumber. A deleted Part becomes a tombstone in place** — 8.6 stays 8.6 and says it was deleted in 003, and why | Part numbers are cited by hand in the D-register, the R-register, the notes, the audit and roughly forty doc comments in `3tk/src/`. Renumbering silently invalidates every one, and the citations that break are the ones a later reader trusts most. Part 18's invariant table already works this way — row 16 is retired, not removed | Cheap now, expensive later. Overturn before anything cites 003 |
| A2 | **The *ztk* lines stay, and *3tk* lines are added beside them where the two ports differ** | The audit's whole finding is that a Zig mechanism was read as the rule. Two realizations side by side is what stops the next reader mistaking either one for it, and it is cheap while both are fresh | 003 gets noticeably longer. Overturning means deleting lines, not writing them |
| A3 | **P2 is answered in the port, not in 003.** `Pool.get` reports a distinct outcome for an identity the pool was not created with, instead of `NOT_AVAILABLE` | Part 19.3's *not-available comes only from the available-only mode* keeps its MUST, and 003 stays untouched | **This is a code change and 3TK-13 does not make it** — it is a document stage. It wants its own small stage, or folding into whichever code stage comes next. Recorded here so it is not lost |
| A4 | **Part 6.5's dispatch table is the application's, and 003 says so in one sentence** | Every clause in 6.5 describes application code — *one handler per pair of receiver and identity*, *the caller releases it*. 3tk shipped nothing and said nothing, and on this reading it had nothing to ship | One sentence either way. It also closes P5, which otherwise stays a skipped SHOULD with no written why |
| A5 | **Filing and scope.** 002 goes to a new `../common/backup/`; **the port's doc comments are NOT repointed** from 002 to 003; one line goes into `../d/dtk-status.md` saying 003 is dtk's input | The specification lives in `common/` now, so its record belongs there and `c3/backup/` stays the C3 line's own. Forty comment edits would bury a document stage. dtk has run no stage and 003 is the thing it has been waiting for | The doc-comment repoint becomes a later stage's work, and until it runs `3tk/src/` cites a superseded version — **stated in 003's change log so it is a known debt, not a surprise** |

**A3 is the only one that leaves work behind.** The other four are decided by
3TK-13 doing its own job.

### What the owner ruled, 2026-08-23

**Given in this order, one question at a time, after 3TK-10 reported.** These
are the rulings, not recommendations.

**They are folded into
[3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md), which is
3TK-11's input.** 001 is in `backup/` and records what the stage proposed before
the ruling. Plan 006's 3TK-11 section names 001 *as ruled by the owner*; the
ruling produced 002, and this file is the live pointer, as it is for every other
versioned document here.

**R6 — REJECTED. No membership field.** `Inner` is two fields, `next` and
`type`. 16 bytes on linux-x64, down from 24.

**The guard is mechanism B — the self-link.** The last item of every chain
points at itself. Then:

- `is_linked(h) => h.next != null`, and it is **exact**. On a chain, `next` is
  never null. Off a chain, it is always null.
- **Part 8.7's blind spot closes with no field.** Today an item alone on a list
  has `prev == null` and `next == null` and reports unlinked — the hole D12
  accepted. Self-linked, it reports linked.
- **`contains` and the O(n) walk on every insert are still deleted.** Once the
  link test is exact it refuses an item on *any* chain, this container or
  another, so the walk of Part 8.6 catches nothing it misses.
- The guard becomes tier 2, so it is live in a fast build.
- `reset(h)` clears `next` to null. Every walk ends at `n.next == n`.

**Corrected by 3TK-11, in a detail and not in the ruling.** The tier 2 bullet
above is left as it was said, because this section is the record of what was
ruled. What the code shows: tier 2 is `@check`, which under `--safe=no` expands
to nothing at all — that is the whole of D6 and of 3TK-4's Q11 finding — so the
guard does **not** abort in a fast build. What moving it from tier 3 to tier 2
actually bought is the exact check at O(1) in an ordinary safe build, where
before it cost an O(n) walk per insert. The ruling stands; the consequence was
described one step too far. `3tk-core-redesign-notes-001.md`.

**Why the field was refused, and 001 got this wrong.** 001 argued mechanism B
gave `next` three meanings across eleven sites in `list.c3`. That count is the
container ruling 2 abolishes: with `remove`, `pop_back`, `insert_after`,
`insert_before`, `front` and `back` deleted, about four sites touch `next`. The
objection was priced against the old container. The field bought exactly one
query — O(1) *is it on this container* — and `remove` was its only caller.

**R8 — ACCEPTED.** Out-of-band first, then ordinary, first-in first-out within
each, for `close` and `receive_all` both. One rule: *where the mailbox gives
items back as a list, the list is in the order `receive` would have taken them
out.* It changes nothing — the single queue already keeps out-of-band ahead of
ordinary, so the two order assertions at `t_mailbox.c3:225` and `:251` pass
untouched.

**R9 — ACCEPTED.** Invariant 22 is kept. Only D14's anchor and Part 11.3's two
anchor bullets are deleted. The ordering is a promise to callers and it stands.

**R14 — ACCEPTED. The specification moves to 003.** Not a 3tk deviation. Nine
Parts change and dtk and otk read them. **Not done by 3TK-11** — `../common/` is
untouched so far, and cutting 003 is its own piece of work.

**R11 — ACCEPTED, and Part 11.7 stays silent on order.** The pool becomes a
stack. Specification 003 says the container is a stack and promises no order,
because Part 11.10 MUST already says the pool promises nothing about which item
comes back.

**The owner's reason for LIFO, which 001 did not have and which must not be
lost.** It is **not** cache locality and **not** performance. It is defect
surfacing:

> Under FIFO the item just given back goes to the *back* of the free list. Code
> still holding a pointer to it after `put` writes to an item nobody has
> re-taken, so nothing conflicts. If the put hook did not reset the contents,
> the stale holder reads data that still looks plausible and never trips. The
> item is reissued much later, and the damage appears far from its cause.
>
> Under LIFO the item is on top and the **next `get` gives it straight to a new
> owner**. The stale holder and the new owner write the same item at the same
> moment, so the defect appears next to its cause.

Same reasoning as not quarantining freed memory. **This belongs in the doc
comment on the pool's stack**, because a later reader who takes the stack for an
arbitrary choice will "improve" it back to a queue. It also explains why the
order is deliberately not promised: what makes the property useful is that
nobody is entitled to it.

**R12 — ACCEPTED, with the order left unstated.** `Pool.close` empties every
bucket into **one `InnerQueue`**, flattened — the close hook never sees buckets
or per-identity groups. One container, one loop, `pop_front` until empty,
release each item. The write is `pop` then `push_back` because it is the
simplest, **and no order is promised**, because the hook's loop is the same
whatever order the items arrive in. O(n), once, on a pool going down.

**R13 — ACCEPTED.** The five list-typed public signatures take `InnerQueue*`.
**There is no `InnerList`** — `3tk-naming-001.md` offers that name only if a
general list survives a real requirement, ruling 2 refuses one, and §1.1's audit
found no requirement. `InnerStack` stays behind `PoolBucket.free` and appears in
no public signature.

**R1, R2, R3, R5, R7 — the direction itself.** Ruled 2026-08-23, before the
stage ran.

**R4 — OUTSTANDING.** The last one. `InnerQueue` keeps a front insert
(`push_front`, `push_front_slot`) because Part 11.8 MUST requires a refused list
put to return the item to the **front** of the caller's list — `pool.c3:451`.
So the FIFO is not quite minimal, and it is a MUST that forces it.

**One more instruction, 2026-08-23:** a banned word of `rules-049.md` Part 5
that 001 used three times is not to be used. **Part 5's own scan scope skips
`design/secondary/`, so no scan had ever covered this folder.** A full scan of
the whole Part 5 list found nine hits, all of them in
`backup/3tk-core-redesign-proposal-001.md`: three of that word, four
custody-sense uses of two others, and two AI-ish words. `3tk-status.md` and
`3tk-log.md` were clean. **Proposal 002 is clean against the whole list**, and
001 was left as it was, being a record.

### The stage that produced it

```
Run 3TK-10 from design/secondary/lang/c3/3tk-status.md
```

**Done 2026-08-23. That row reads DONE and it is not re-run.**

**The sequence, confirmed by the owner 2026-08-23: proposal first, then code.**
It was followed: 3TK-10 wrote the proposal, the owner ruled R1 to R15 question
by question, and 3TK-11 wrote nothing 3TK-10 had not ruled. **Both are DONE.**

**The owner's direction of 2026-08-23 is now worked out in the proposal**, and
it is repeated here because a cold session should not have to open a second file
to know what was ruled:

1. **Drop `Any*` and every inherited ztk name.** The vocabulary becomes
   **Outer / Inner**. `AnyNode` → `Inner`, `AnyHandle` → `Handle`.
2. **Stop reproducing Zig's `DoublyLinkedList`.** No general-purpose list type.
3. **FIFO for the mailbox, LIFO for the pool** — the minimal intrusive
   containers, nothing more.
4. **The mailbox has two FIFOs**, ordinary and out-of-band, instead of one list
   with an anchor.
5. **One link, not two.** `next` only. `prev` goes.

Its reading is [3tk-naming-001.md](3tk-naming-001.md) and
[3tk-to-fifo-lifo-single-001.md](3tk-to-fifo-lifo-single-001.md), both from the
owner, plus specification Parts 4, 8 and 11.

**The four consequences are answered**, in the proposal's sections 5, 3, 4 and
8 respectively. Two of them came out differently from the way plan 006 framed
them, and both are in the proposal's *What the reading found*: consequence 2
makes the port **stronger**, not weaker, and invariant 22 **survives**.

**3TK-11 has run and is not re-run.** To add the next stage, the shape is a
single line and the agent does the versioning:

```
Add 3TK-12 to the plan and run it
```

To bump the plan without running anything yet, add `Do not run it.`

Whatever the stage, the agent's first three actions are: read this file, read
the plan's section for that stage, read that stage's named inputs. Nothing
outside them. A stage whose row above reads DONE is not re-run without being
told.

### The candidates for a later stage, and what each is worth

None is authorized. They are listed so the owner can name one without
re-deriving the list, and in the order this file would recommend them.

**The sanitizer run is gone from this list — 3TK-9 did it**, and it found four
races in the tests and none in the port.

**The table was written to be read after 3TK-11, and 3TK-11 has run.** The core
has stopped moving, so the two candidates that were waiting on it — a worked
example and the cross-target builds — are both live now. A worked example
written today is written against `Inner`, `InnerQueue` and `InnerStack` and will
not be obsolete on arrival.

**Specification 003 is not in this table** because it is not a candidate: R14
ruled it, and it needs scheduling rather than choosing. It is the one thing that
belongs ahead of everything here, because the port is currently ahead of the
document every other port reads.

| Candidate | What it does | Why it might wait |
|---|---|---|
| **`3tk-porting-proposal-005.md`** | Folds the core redesign into the design of record, so one document describes the port that exists. A **revision**, not a stage — see *If you want a document revised* below | **Waits on specification 003.** 004's decisions cite specification Parts by number, and 003 rewrites nine of them. Folding first means folding twice. Highest value once 003 is cut: it is the first document a cold reader trips on |
| **Cross-target builds** | ztk is green on three cross targets; 3tk has been built for linux-x64 only | Mechanical, and `run-builds.sh` already has the shape for it. Now the top of the list |
| **A worked example** | An application using the port end to end — a producer, a consumer, a pool with real hooks — as documentation that compiles | The tests prove the invariants; nothing yet shows a reader how to *use* it. It would also be the first honest test of whether the hook contract is easy to obey — 3TK-9 says the toolkit's own tests did not obey it |
| **Packaging** | `.c3l`, `c3c dist`, distribution. `backup/3tk-build-dist.md` B2 claims the tooling is early alpha, and that is still unverified | Outside the specification entirely, and it depends on the C3 toolchain rather than on this work |
| **MemorySanitizer** | The third sanitizer c3c offers, not run by 3TK-9 | Needs the whole dependency stack instrumented, including the C3 standard library, or it reports false positives. Low value for the effort |

The two build-and-example candidates would each be one stage. Packaging may not
be worth a stage until B2 is checked, which is ten minutes of measurement.

#### `3tk-porting-proposal-005.md`, in more detail

**Recorded here so it is not re-derived, 2026-08-24. Not authorized, not
scheduled.**

**The problem it fixes.** `3tk-porting-proposal-004.md` is the design of record
and it names `AnyNode`, `AnyHandle`, `NodeList` and `Pool.put_all` — types and
a call that no longer exist. Someone reading 004 today is reading the port **as
it was before 3TK-11**, and nothing inside the file says so. The redesign lives
in a second document,
[3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md), and a
reader has to hold both and know which wins.

**What it is.** A merge, and **no decision reopens.** D1 to D16 survive
3TK-11 — the notes checked this. Two were overtaken by rulings already written
down: D14's anchor clause, by R7, and D12's accepted link-test blind spot, by
R6b. Everything else — D1's public representation, D3's allocators, D5's
distinct Slot, D6's tiers, D7's wait loop, D15's faults, section 6's seven
implementation invariants — is unchanged and stays as written.

**Why it waits on 003.** Nearly every decision in 004 justifies itself by citing
a specification Part. 003 rewrites nine of those Parts and may renumber inside
them. A 005 cut first has to be cut again.

**The trap, and it is the reason this note exists rather than a one-line row.**
**Do not renumber D1 to D16, and do not merge the D and R registers into one
sequence.** Every notes file, every negative program comment, `3tk-log.md` and
this file cite decisions by number — `D6 tier 2`, `D1's ruling`, `R6b`. A
renumber silently falsifies all of them, and with `git` off there is no revert.
Two registers side by side, D for the port and R for the redesign, with 005
saying which R overtook which D. That is a recommendation, not a ruling.

**What it may not do**, and both are the folder's standing rules rather than
this candidate's:

- It does not rewrite a finished stage's output. `3tk-toolkit-notes-001.md` and
  `3tk-containers-notes-001.md` still describe `AnyNode` and `NodeList`, and
  they are right to — they record what was true when those stages ran.
- It does not repoint provenance. The stage outputs name the proposal version
  each was written against; only the live pointers in this file move. 004 goes
  to `backup/` and every link naming it is corrected in place.

**How to ask for it**, once 003 exists — it is a revision, so it needs no plan
version:

```
Read design/secondary/lang/c3/3tk-status.md. Revise the porting proposal:
fold the core redesign into it as 005, against specification 003.
```

### If you want a document revised, not a stage run

**A revision is not a stage.** It needs no plan version and it appears in no
stage table. `3tk-porting-proposal-002.md` was made this way — the owner
accepted the sixteen decisions and the amendments were folded in, with no stage
involved.

Type what you want changed, and name the document or just say which one:

```
Read design/secondary/lang/c3/3tk-status.md. Revise the porting proposal:
D5 should be a transparent alias, not a distinct Slot type.
```

```
Read design/secondary/lang/c3/3tk-status.md. Revise the specification:
Part 11.9's open question about the ztk book is decided — the book is being
fixed, so drop the note.
```

The versioning is the agent's work, not yours. It writes the next version
number, leaves the old file on disk, adds a row to *Superseded* naming what
replaced it, repoints the live pointers in this file, and appends to
`3tk-log.md`. The files that are edited in place instead — this one and the log
— are listed under *Files*.

**The rule that matters, and the agent applies it without being reminded:** a
revision that moves a decision has consequences in `3tk/`. The agent names the
source files that would change and **stops there**. Rewriting the code is a
separate instruction, and the four builds have to be green again before the
revision is finished:

```
...and apply it to the code.
```

Two things a revision is not allowed to do quietly. It does not renumber or
rewrite a finished stage's output — those record what was true when the stage
ran. And it does not repoint the provenance lines inside stage outputs, which
name the document version each stage was written against; only the live
pointers in this file move. The distinction is stated in *Superseded*.

### If the next work is not 3tk

The specification is the deliverable that outlives this line of work. It, the
ztk audit and `port-flow-001.md` are in [`../common/`](../common/README.md). Any
of these starts from the specification and nothing else:

- **otk** (Odin) needs refactoring.
- **ztk** (Zig, this repo) needs tuning.
- **dtk** (D) has a prepared folder as of 2026-08-23 —
  [../d/dtk-status.md](../d/dtk-status.md). Scope is ruled (Linux only, `@nogc`,
  not betterC yet), the eighteen inputs are mapped, and no stage has run. It
  starts by reading its own status file, not this one.

Those are separate lines of work with their own folders under
`design/secondary/lang/`, and none of them belongs in a 3TK stage.

### If you only want to know where things stand

```
Read design/secondary/lang/c3/3tk-status.md and report where the 3tk work stands.
```

### To verify the port without an agent

```
design/secondary/lang/c3/3tk/run-builds.sh
```

Four builds, exits non-zero on any failure. It needs `c3c` on the path and
nothing else, and 3TK-9 deliberately kept it that way.

**Both scripts take an optional directory, added 2026-08-24 on the owner's
instruction.** With no argument — or an empty one — each runs against its own
directory exactly as before, which is what every existing invocation and every
line on this page does. With an argument, that path replaces `dirname "$0"`:

```
./3tk/run-builds.sh              # the script's own directory, unchanged
./3tk/run-builds.sh /some/tree   # that tree instead
```

**A `cd` that fails is fatal, and that is not decoration.** Neither script sets
`-e`, so before this a failed `cd` would have let the whole body run in whatever
directory the caller happened to be in, and `run-builds.sh` does `rm -rf` on its
temporary directory at exit. A caller-supplied path made that reachable. A bad
path now prints one line and exits 2 with nothing else run.

The sanitizers are a **second** script, because they need a C compiler that
ships their runtimes and `run-builds.sh` may not depend on one:

```
design/secondary/lang/c3/3tk/run-sanitizers.sh
```

Thread on two builds, address on one. It **skips and exits 2** if its compiler
is missing, saying so — a skip is not a pass. `SAN_CC=<compiler>` overrides the
default of `clang`. It takes the same optional directory as `run-builds.sh`, and
guards its `cd` the same way.

## Files

Edited in place, no suffix — the entry points:

- `3tk-status.md` — this file.
- `3tk-log.md` — the narrative, append-only, newest first.

Versioned — a change makes a new file, the old one stays and is listed below:

- **Current plan: [3tk-staging-plan-009.md](3tk-staging-plan-009.md).** It adds
  **3TK-16 and 3TK-17**, and amends 3TK-15's ordering. Everything 3TK-0 to
  3TK-14 has run, **and 3TK-16 has run**; **3TK-15 and 3TK-17 are declared and
  neither is authorized.** The order is **3TK-16 → 3TK-15 → 3TK-17**, and it is
  not the numbering.
- [ztk-audit-001.md](../common/ztk-audit-001.md) — the 3TK-1 output.
- **[matryoshka-specification-003.md](../common/matryoshka-specification-003.md) — the
  portable specification, and the source of truth for every port.** The 3TK-2
  output, revised twice: by 3TK-2's own successor into 002, and by **3TK-13**
  into 003 from the deviation audit.
- [3tk-drafts-review-001.md](3tk-drafts-review-001.md) — the 3TK-3 output.
- [c3-capabilities-001.md](c3-capabilities-001.md) — the 3TK-4 output.
- **[3tk-porting-proposal-004.md](3tk-porting-proposal-004.md) — the design of
  record. The sixteen decisions accepted by the owner, 2026-08-23; D1's argument
  rewritten and its ruling reaffirmed by 3TK-8, same day.**
- [3tk-toolkit-notes-001.md](3tk-toolkit-notes-001.md) — the 3TK-6 output,
  beside the code at `3tk/`.
- [3tk-containers-notes-001.md](3tk-containers-notes-001.md) — the 3TK-7
  output.
- **[3tk-naming-001.md](3tk-naming-001.md)** and
  **[3tk-to-fifo-lifo-single-001.md](3tk-to-fifo-lifo-single-001.md)** — from
  the owner, 2026-08-23. Not produced by any stage and not versioned by this
  folder. **The input to 3TK-10.** The first proposes Outer/Inner naming; the
  second argues `NodeList` should not be the centre of the design. Both were
  carried out by 3TK-10 and 3TK-11 and are history now.
- **[3tk-who-supports-slot.md](3tk-who-supports-slot.md)** — from the owner.
  Not produced by any stage. **Open, and not ruled on by anything.** It argues
  the containers should not support the Slot idiom at all. It was at `3tk/src/`
  until the owner moved it here on 2026-08-23; it uses names the redesign
  refused, so it reads as older than it is. See *Open questions*.
- **[3tk-helper-alternatives.md](3tk-helper-alternatives.md)** — from the
  owner, 2026-08-24. Not produced by any stage and not versioned by this
  folder. **The first input to 3TK-14.** It is advice, not a ruling, and it
  withdraws its own favourite proposal near the end. 3TK-14 measured both of its
  shapes and the compiler refused both. **Its second input was spoken, not
  written**: read the C3 stdlib. That is recorded in the log and in Part A2 of
  the proposal, and it is what produced H0.
- [3tk-helper-proposal-001.md](3tk-helper-proposal-001.md) — the 3TK-14 output.
  Fifteen compiler measurements, eleven numbered items, **all ruled 2026-08-24**.
  Its second input was the owner's mid-stage advice to read the C3 stdlib's
  `interfacelist`, `anylist` and `core/builtin.c3`, and that advice is what
  produced H0. **3TK-16 built it.**
- **[3tk-helper-notes-001.md](3tk-helper-notes-001.md) — the 3TK-16 output.**
  What building the ruled surface taught: three C3 spellings the proposal's
  scratch runs did not carry, the rename that was never a rename, and 35 aliases
  to 0.
- [3tk-sanitizer-notes-001.md](3tk-sanitizer-notes-001.md) — the 3TK-9 output.
  Seven findings. The port is clean under thread and address; the four races the
  first run found were all in the tests.
- **[3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md) — the
  3TK-10 output as ruled, and 3TK-11's input. Executed 2026-08-23.** Sixteen
  decisions, R1 to R15 with R6b, every one accepted or refused on the record.
  Proposal 004 stays the design of record for everything the redesign does not
  touch, and it is **not edited** — it records what was built, and 002 records
  what replaced it.
- **[3tk-core-redesign-notes-001.md](3tk-core-redesign-notes-001.md) — the
  3TK-11 output.** What writing the redesign taught: the six self-link sites,
  invariant 5 in a mailbox with two queues, and three corrections to 002 in
  details rather than decisions — the stack has five operations and not six,
  tier 2 does not reach a fast build, and two `put_all` tests were converted
  rather than deleted.



### Superseded

**Every superseded version is in `backup/`.** Nothing is deleted, and the live
folder contains only what a current reader needs.

- [3tk-core-redesign-proposal-001.md](backup/3tk-core-redesign-proposal-001.md),
  replaced by
  [3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md) on
  2026-08-23, when the owner ruled on it question by question. **Three decisions
  moved**, which is why a version was cut rather than a note appended: **R6 was
  refused** and the self-link replaced it, **R11 acquired its reason**, and
  **R15 dropped `put_all`**, retiring R4. 001 is the record of what the stage
  proposed; 002 is what was ruled, and 002 is 3TK-11's input.

- [3tk-staging-plan-001.md](backup/3tk-staging-plan-001.md), replaced by plan
  002 on 2026-08-23. The only change was the addition of 3TK-6.
- [3tk-staging-plan-002.md](backup/3tk-staging-plan-002.md), replaced by
  [3tk-staging-plan-003.md](backup/3tk-staging-plan-003.md) on 2026-08-23. The only
  change is the addition of 3TK-7.
- [3tk-staging-plan-003.md](backup/3tk-staging-plan-003.md), replaced by
  [3tk-staging-plan-004.md](backup/3tk-staging-plan-004.md) on 2026-08-23. The only
  change is the addition of 3TK-8.
- [3tk-porting-proposal-001.md](backup/3tk-porting-proposal-001.md), replaced by
  proposal 002 on 2026-08-23, when the owner accepted all sixteen decisions.
- [3tk-porting-proposal-002.md](backup/3tk-porting-proposal-002.md), replaced by
  [3tk-porting-proposal-003.md](backup/3tk-porting-proposal-003.md) on 2026-08-23, in
  answer to [3tk-porting-proposal-review.md](backup/3tk-porting-proposal-review.md).
  No decision moved.
- [3tk-staging-plan-007.md](backup/3tk-staging-plan-007.md), replaced by
  [3tk-staging-plan-008.md](backup/3tk-staging-plan-008.md) on 2026-08-24. The
  only change is the addition of 3TK-14 and 3TK-15.
- [3tk-staging-plan-008.md](backup/3tk-staging-plan-008.md), replaced by
  [3tk-staging-plan-009.md](3tk-staging-plan-009.md) on 2026-08-24. The changes
  are the addition of 3TK-16 and 3TK-17, an amendment note on 3TK-15's ordering,
  and one corrected stale line — 008 and 007 both said *currently 007* in the
  versioning section.
- [3tk-staging-plan-006.md](backup/3tk-staging-plan-006.md), replaced by
  [3tk-staging-plan-007.md](backup/3tk-staging-plan-007.md) on 2026-08-24. The only
  change is the addition of 3TK-12 and 3TK-13.
- [3tk-staging-plan-005.md](backup/3tk-staging-plan-005.md), replaced by
  [3tk-staging-plan-006.md](backup/3tk-staging-plan-006.md) on 2026-08-23. The
  only change is the addition of 3TK-10 and 3TK-11.
- [3tk-staging-plan-004.md](backup/3tk-staging-plan-004.md), replaced by
  [3tk-staging-plan-005.md](backup/3tk-staging-plan-005.md) on 2026-08-23. The only
  change is the addition of 3TK-9.
- [3tk-porting-proposal-003.md](backup/3tk-porting-proposal-003.md), replaced by
  [3tk-porting-proposal-004.md](3tk-porting-proposal-004.md) on 2026-08-23, by
  stage 3TK-8, in answer to
  [3tk-porting-proposal-003-review.md](backup/3tk-porting-proposal-003-review.md).
  **No decision moved.** D1's *argument* was rewritten and its *ruling*
  reaffirmed by the owner.
- [3tk-porting-proposal-addendum-001.md](backup/3tk-porting-proposal-addendum-001.md),
  folded into proposal 004 on 2026-08-23. Its nine measured answers are D1's
  table; the addendum existed only until a proposal version could carry them.
- [3tk-porting-proposal-003-review.md](backup/3tk-porting-proposal-003-review.md),
  answered by proposal 004 on 2026-08-23 and moved here, as the first review
  was. It is history now: everything a current reader needs from it is in 004's
  *What changed in 004*, section 6 and section 10.
- [matryoshka-specification-001.md](../common/backup/matryoshka-specification-001.md),
  replaced by
  [matryoshka-specification-002.md](../common/backup/matryoshka-specification-002.md) on
  2026-08-23 — three imprecisions the C3 port found, and invariant 34, with no
  rule changed — and **002 replaced by
  [matryoshka-specification-003.md](../common/matryoshka-specification-003.md) on
  2026-08-24**, from the deviation audit. Both are in `../common/backup/`, which
  3TK-13 created; `c3/backup/` stays the C3 line's own. **The other ports read
  003.**

The stage outputs name the document versions they were written against. Those
are provenance and are not repointed; the live pointers above are.

**A path is not a pointer.** When a superseded file moves to `backup/`, the
links naming it are corrected to `backup/...` in place, in every file that
names it. That changes where the file is, never which version is named — the
stage outputs of 3TK-1 to 3TK-5 still name plan 001, and the notes of 3TK-6 and
3TK-7 still name proposal 001. Repointing provenance at a *newer* version is
what the rule forbids, and none of it happened.

The stage outputs of 3TK-1 to 3TK-5 each name plan 001 in their opening line.
Those are **provenance, not pointers** — they record which plan version the
stage ran under — and they are not repointed. The live pointers are the ones in
this file.

## Current state

**The port is clean under ThreadSanitizer and AddressSanitizer**, and the run
that established it found four data races first — **all four in the toolkit's
own test hooks, none in `src/`.** Stage 3TK-9, `3tk-sanitizer-notes-001.md`.

- **What the races were.** `TestHooks`'s counters, incremented without
  synchronization while three producers and three consumers ran on one pool. The
  frames that appear in `src/` are `pool.c3:284` and `:396` — the hook call
  sites, where the pool has *already unlocked*. That is Part 12.3 being obeyed.
- **The contract they broke is the port's own**, in `PoolHooks`'s doc comment:
  *a hook that touches shared state protects it itself.* The tests had been
  racing since 3TK-7 with every build green in four modes, because a data race
  is exactly the defect a passing suite cannot see.
- **The fix is in the hook**, where the specification puts it: `Atomic{usz}`
  counters, the same mechanism the port uses for `_closed_fast`. The one-line
  wrong fix — hold the pool's mutex across the hook — would have silenced every
  warning and destroyed Part 12.3. A sanitizer says there is a race; it does not
  say which side is wrong.
- **The sanitizers needed no install and no root.** Fedora's runtimes are
  missing so `cc` cannot link them — and plain `cc -fsanitize=thread` fails
  identically, so it is the machine, not c3c. `--cc clang` links. S1, S2.

```
all four builds green — 59 checks, 0 failures     ./3tk/run-builds.sh
  safe -O0   safe -O3   fast -O0   fast -O3        (needs c3c alone)
85 tests in each, 7 runtime negatives, 2 tier 1, 3 refusals, 3 layering

sanitizers clean — 3 runs, 0 findings              ./3tk/run-sanitizers.sh
  thread safe -O0    thread fast -O3    address safe -O0
```

**77 tests before 3TK-11, 85 after.** The check count did not move: the redesign
renamed one negative and rewrote another, and added none.

The two scripts are separate for one reason: the gate depends on `c3c` and
nothing else, and 3TK-9 kept it that way rather than buying coverage with a
dependency.

**Part 18 is complete: still thirty-four invariants, all accounted for.** The
redesign retired row 16 — *the link test is not a membership test* — and put the
self-link invariant in its place, kept row 22 against plan 006's expectation
that two queues would delete it, and strengthened row 13. The re-walk is in
`3tk-core-redesign-notes-001.md`.

**No decision has moved across four proposal versions.** All sixteen accepted by
the owner 2026-08-23; D1 reaffirmed the same day after its *argument* was found
wrong, which is the distinction this folder keeps.

The documents, in the order a cold session reads them:

- `../common/matryoshka-specification-003.md` — the portable specification.
  Source of truth for **every** port, not just this one.
- `3tk-porting-proposal-004.md` — the C3 shape of it. D1 to D16, accepted.
  Section 6 is the implementation contract; section 10 is what the code taught.
- `3tk-toolkit-notes-001.md`, `3tk-containers-notes-001.md`,
  `3tk-sanitizer-notes-001.md` — what the code taught. Twenty-two findings.
- `c3-capabilities-001.md`, `3tk-drafts-review-001.md`,
  `../common/ztk-audit-001.md` — the measurements the proposal was built on.

**The core redesign is designed, ruled and built.**
[3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md) is the
3TK-10 output as ruled; 3TK-11 carried every one of its sixteen decisions into
`3tk/` and
[3tk-core-redesign-notes-001.md](3tk-core-redesign-notes-001.md) is what the
code taught doing it. Four things a reader should know:

- **The required-operation audit passes.** `insert_before`, `remove`,
  `pop_back`, `front` and `back` have **no caller in `src/` at all**;
  `insert_after` has one, the out-of-band insert. Deleting `prev` costs the
  port nothing it uses.
- **The guard got stronger, and cost nothing.** `prev` is deleted and the last
  item of every chain points at itself, so `is_linked` is **exact**. `Inner` is
  two fields and 16 bytes — the two size tests that asserted 24 were the first
  thing the stage had to change. Part 8.7's blind spot is closed, `contains` and
  the O(n) walk on every insert are deleted, and the check moved from tier 3 to
  **tier 2**. R6b, after R6's field was refused.

  **Correction to 002 §10.3, from the code:** tier 2 does **not** reach a fast
  build. `@check` under `--safe=no` expands to nothing, which is the whole of
  D6. What R6b bought is the O(1) check in an ordinary safe build, not an abort
  in a fast one. `3tk-core-redesign-notes-001.md`.
- **`put_all` is dropped.** It was `Pool.put` in a loop, inherited from
  `pool.zig:394`, and it cost a container operation and a MUST clause while
  giving the difficult case back to the caller in a different shape. R15.
- **The pool's order is a behaviour change with a reason**: last-in first-out
  so a use-after-release meets a live second owner at the next `get`, instead
  of rotting quietly at the back of a free list. **Not performance.**

## The gap between the port and the specification

**CLOSED 2026-08-24 by 3TK-13. This section is history and is kept as the
record of a gap that no longer exists.** The current source of truth is
[`../common/matryoshka-specification-003.md`](../common/matryoshka-specification-003.md),
and its claim about itself — *a port is written from this file alone* — is true
again. Everything below describes the state before 003 was cut. Read it only if
you want to know what the gap was; do not act on it.

**The specification described ztk.** `../common/backup/matryoshka-specification-002.md`
was written by 3TK-2 from `../common/ztk-audit-001.md` and the three Zig
sources; 68 of its lines are marked *ztk*. Where it states a **promise** it is
port-neutral and it holds. Where it states a **mechanism**, the mechanism it
states is the Zig one — the doubly-linked list, `prev`, the out-of-band anchor,
one free list per identity. That distinction is not a criticism of the document;
it is what 3TK-10 discovered and what R14 rules should be fixed.

**3tk no longer had that mechanism, and `../common/` did not know.** 3TK-11
wrote nothing there, exactly as plan 006 required. So the document's own claim —
*a port is written from this file alone* — was **false for 3tk**, and a port
started from 002 would have reproduced `prev`, the general list and the anchor,
and then needed 3TK-10 and 3TK-11 run again against it. **3TK-13 is what fixed
it**, and no port started from 002 in the meantime: dtk had run no stage.

**What is known to differ, as of 2026-08-23.** This list is the *forecast*,
proposal 002 §8.1, plus what 3TK-11 corrected. **It is not an audit and it is
not complete** — that is precisely 3TK-12's job:

| Part | Marking | What the port does instead |
|---|---|---|
| 4.2 | MUST | The inner is one link plus the identity, 16 bytes. The last item of a chain points at itself |
| 8.1 | MUST | No doubly-linked list. Two ordering primitives whose nodes are the inners of Part 4 |
| 8.2 | SHOULD | Sixteen operations become **seven on the queue and five on the stack**. §5.1's *six* is an arithmetic slip 3TK-11 corrected |
| 8.6 | SHOULD | Deleted. One exact check replaces two partial ones |
| 8.7 | MUST | Rewritten. The link test is exact for every path through the public surface; the blind spot is closed |
| 8.9 | SHOULD | Unchanged in force, narrowed to the queue |
| 11.3 | MUST | Two queues, no anchor. **The three ordering guarantees stay** — invariant 22 survived, R9 |
| 11.7 | MUST | One **stack** per identity, and the Part stays silent on order. *Put a list* is deleted |
| 11.8 | MUST | The list-put clause and the restored-order warning are deleted with `put_all` |
| 18 | — | Row 16 retired and replaced by the self-link invariant, row 22 kept, row 13 strengthened. Still thirty-four rows |

**Three things this table does not tell you, and each is a reason not to cut 003
from it:**

1. **It was written before the code existed.** 3TK-11 found three of proposal
   002's statements wrong — the operation count above, tier 2 not reaching a
   fast build, and two `put_all` tests converted rather than deleted. None is a
   decision; all three are the kind of detail a specification states as a rule.
2. **It covers only the Parts the redesign aimed at.** Parts 9, 12.5 and 17.2
   were not aimed at, and all three are touched by a container surface that
   changed shape.
3. **It does not say which deviations bind every port.** Some belong in 003;
   some are 3tk's business for ever. Nothing on disk makes that split yet, and
   making it wrong sends a C3 decision into dtk and otk.

**3TK-12 measured it and 3TK-13 cut it.**
[3tk-deviations-001.md](3tk-deviations-001.md) is the record of the difference,
003 is the document that no longer has it, and the table above is superseded
twice over. The table stays
because it is what was believed before the measurement, and the audit's §4 is a
list of the places it was wrong. What the audit adds, in one line each:

- **The table's ten rows stand**, with one count corrected. Nine were §8.1's;
  Part 8.9 was right that it is unchanged in force.
- **Five more Parts move, and §8.1 said all five were untouched** — 19.2, 20,
  21, 22, and 11.2 — because Part 8.6 was deleted without following its
  referrers, and because Parts 11.2 and 12.2 name a *type* the redesign changed
  rather than an operation it deleted.
- **Five port-side deviations exist, and a forecast could not have found any of
  them.** P1 strands items on a concurrent close.
- **The split is made**: 17 rows bind every port and reach 003; 5 are 3tk's
  business and stay in this folder.

**Nothing is waiting on the owner except the choice of what runs next.**
Specification 003 is ruled in direction, and plan 007 now schedules the two
stages that get there — the audit, then the cut. Everything else in *The
candidates for a later stage* is unauthorized and
listed only so the owner can pick without re-deriving the list.

## What is left, and none of it is Matryoshka

Everything below was **outside 3TK-8**, which was about the proposal and two
creation paths, and none of it moved. From `3tk-containers-notes-001.md`. Each
is a candidate for a 3TK-9, and *How to continue after a clear* has them as a
table with a recommendation.

- **`a_leaver_hands_the_signal_on` is a race test run 20 times.** It has now run
  20 times **under ThreadSanitizer**, which is much stronger than 20 times
  without. Still evidence, not proof.
- **MemorySanitizer was not run.** c3c offers it; it needs the whole dependency
  stack instrumented, including the C3 standard library, or it reports false
  positives. `3tk-sanitizer-notes-001.md`.
- **linux-x64 only.** ztk is green on three cross targets; 3tk has been built
  for one.
- **`Mailbox.create`'s cleanup is untested**, and the test file says so at the
  site. Its only acquisition through the caller's allocator is the object
  itself; `_mu.init()` and `_cv.init()` allocate through the platform, so a
  failing allocator cannot reach them. The fix is correct by construction and
  the pool's identical shape *is* provoked. Proposal 004, section 8.3.
- **Packaging.** `backup/3tk-build-dist.md` B2 claims C3 library packaging is early
  alpha and `c3c dist` incomplete. Still unverified, still a tooling stage's.

The other three ports are untouched by this line of work: **otk** needs
refactoring, **ztk** needs tuning, **dtk** is thinking only. The specification
is what any of them would be written from.

## Standing facts

- C3 is installed. `c3c` at `/usr/bin/c3c`. Stdlib sources at
  `/home/g41797/dev/langs/c3/lib/std/`. No install step in any stage.
- The toolchain measured by 3TK-4 is `c3c` 0.8.3, git `1d155ee`, LLVM 22.1.8,
  target linux-x64. Every capability answer is against that version.
- The seven `3tk-*.md` and `ztk-to-3tk.md` drafts, **now in `backup/`**, were
  written in separate sessions by different AIs. They contradict each other and
  some predate API 12, API 13 and INTR 8. They are raw input, never source of
  truth. 3TK-3 read them and measured them; `3tk-drafts-review-001.md` is that
  measurement, and it is what later stages read instead of the drafts. Read the
  measurement, not the drafts — that is why they are in `backup/`.
- ztk itself is green: 195/195 in four modes, three cross targets, INTR 8 closed
  2026-08-14.
- 3tk is green: **85 tests** in four modes, plus 12 negative programs and 3
  layering checks. `3tk/run-builds.sh`, 59 checks, 0 failures.
- **C3 has no UFCS.** A free function cannot be called as `handle.f(...)`;
  the receiver is written into the declaration, `fn void Type.f(&self)`. And a
  method cannot be attached to a pointer alias, so `Handle` carries none.
  Proposal 004, D1 — M1 and M4.
- **C3 0.8.3 has no field-level privacy, and `inline` does not create one.** A
  `@private` struct inlined into a public one hides the type *name*; every field
  in it stays readable, writable and addressable from another module.
  `@private` on a field is refused outright. Proposal 004, D1 — M5.
- **The sanitizers work, but not through `cc` on this machine.** c3c 0.8.3 has
  `--sanitize=address|memory|thread`; Fedora's sanitizer runtimes are not
  installed, so `cc` fails to link — and plain `cc -fsanitize=thread` fails the
  same way, so it is the machine and not c3c. `--cc clang` links, with no
  install and no root. `3tk-sanitizer-notes-001.md` S1 and S2.
- **`c3c test` detects leaks by default** — `--test-noleak` turns it off. Nine
  stages passed before any document said so. S6.
- **Never infer a C3 build mode from the `-O` level.** `-O2` and above set
  `SAFE_MODE=false`. Always pass `--safe=yes` or `--safe=no` explicitly.
  `3tk-toolkit-notes-001.md` F1.
- The fault-return operator is `~`, not `?`. `return mtk::CLOSED~;`.
  `3tk-containers-notes-001.md` G2.

## Open questions

- **Should the containers support the Slot idiom at all?** A note from the
  owner, [3tk-who-supports-slot.md](3tk-who-supports-slot.md), argues they
  should not: `push_back_slot` and `push_slot` would move to `Mailbox` and
  `Pool`, and `InnerQueue` and `InnerStack` would speak only in `Handle`.
  **3TK-10 did not rule on it and 3TK-11 did not act on it** — §5.1 keeps both
  Slot inserts and R13 says nothing against them, so the code has them. It uses
  names the redesign refused — `InnerList`, `push_front` — so it reads as older
  than it is. **The owner moved it out of `3tk/src/` to this folder on
  2026-08-23**, so it is no longer mistakable for current design. Small: two
  methods and their two tests.
- **The banned-word scan has never covered this folder.** `rules-049.md` Part
  5's own scope skips `design/secondary/`, so eleven stages of documents were
  written unchecked. Found 2026-08-23 when the owner caught one word in the
  redesign proposal; a full scan then found nine hits in that file alone. The
  proposal was replaced by a clean 002. **Whether Part 5's scope should change
  is the owner's call and belongs to the kitchen line, not to 3tk.**
- ~~Three uses of a Part 5 word in this file, each describing a folder
  containing files rather than an item in custody.~~ **Closed by the owner,
  2026-08-23: fixed.** All three now read `contains`, which is one of Part 5's
  own named replacements and is more exact for a folder. Part 5 scopes that ban
  to the custody sense but names replacements "for a container"; the owner
  resolved the ambiguity toward fixing. One other word, the concrete noun for
  c3c's test runner, was judged not a hit and is untouched.
- **`3tk-log.md` carries about a dozen older hits and is deliberately left as
  it is.** Owner's instruction, 2026-08-23: the log is append-only and
  rewriting it destroys the record, which is also why Part 5's scope skips it.

- **3TK-8's four questions are all closed**, ruled on 2026-08-23 before the
  stage started. They are kept below with their answers, and in the stage's plan
  section, because the reasons are part of the design record.
- ~~Does the 003 review move to `backup/`?~~ **Closed by the owner, 2026-08-23:
  yes**, once proposal 004 answers it — as the first review did. It moves only
  **after** 004 carries what a current reader needs from it; until then it is
  input and stays live.
- ~~Is the failing-allocator test worth building?~~ **Closed by the owner,
  2026-08-23: build it, in a dedicated file.** `3tk/test/t_alloc.c3` becomes the
  home for the test allocators — counting, failing, and whatever a later stage
  needs — rather than an addition to `common.c3`, which is the shared fixture
  every test file reads. `project.json` declares `"test-sources": [ "test" ]`,
  so the harness needs no change. Verified.
- ~~Where do the capability answers live?~~ **Closed by the owner, 2026-08-23:
  inside proposal 004 only.** `c3-capabilities-001.md` is the 3TK-4 output and
  is not amended; no `c3-capabilities-002.md` is cut. The measurements have one
  home, beside the decision they support.
- ~~Does the D1 ruling stand?~~ **Closed by the owner, 2026-08-23.** Public
  direct representation, and **no code changes for the sake of hiding** — the
  port does not fight the language for a boundary the language will not enforce
  (M5). D1's *argument* is corrected in proposal 004, a comment marks the
  boundary, and the documents say so. The `Impl*` split is rejected on the
  record, on cost rather than on Part 11.1.
- ~~The allocator direction.~~ **Closed by the owner's ruling of 2026-08-23**,
  which accepted D3 along with the other fifteen. The answer is per type, by
  which helper the type takes: `mtk::owned` finds the outer's `Allocator` field
  at build time and names `mtk::helper` when there is none, so no release call
  in the port takes an allocator parameter. Proposal 003, D3, states it as one
  principle rather than three rules. The ztk half of the gap that 3TK-1
  measured — `ztk-audit-001.md` section 5.1, `destroy` taking an allocator it
  did not keep — is untouched by this and belongs to the ztk line.
- `Pool.get_wait` does not call `on_get`. The book says twice that it does.
  `ztk-audit-001.md` section 5.2. The code is the truth. The specification
  follows the code, Part 11.9. The book still needs a fix that is not this line
  of work.
- The specification is 1366 lines against the plan's expected 600-900. The
  staccato rule is one fact per line, and the content did not compress below
  this without dropping facts. Nothing was padded and nothing was cut to fit.
  Flagged for the owner.
- `kitchen/tools/check_design.sh` exits 1, not the 0 the plan expected. **63
  problems after 3TK-8, up from 43**, and the whole rise is orphans — 29 to 49 —
  because `design/secondary/context.md` lists no `lang/` subfolder, so every
  file under it counts as one. 3TK-8 added two files and moved three to
  `backup/`; each is a new path and a new row. **The 14 dead links did not
  move**, and that is the number that would signal a regression. All 14 are in
  `design/context.md` and name documents older than this work. The cause is the
  next item.
- `design/secondary/context.md` does not list the `lang/` subfolders at all.
  Drift, noted, not fixed. Every file in `c3/`, `d/` and `odin/` is an orphan
  by the gate's count because of it.
- Three more documentation-drift items, all in `design/`, none touching `src/`.
  `ztk-audit-001.md` section 7.
