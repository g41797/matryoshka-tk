# 3tk — staging plan 035

Written 2026-09-09.

**Provenance.** Follows `034`, which follows `033`, `032`, `031`, `030`, `029`,
`028`, `027` and `026`. **Those earlier ones are named, not linked: `backup/`
is transient — the owner empties it — and it is never cited as a source of
truth.** `034` is spent: `3TK-73` was its only stage and it closed on
2026-09-09.

**Only `3TK-50` remains from any earlier plan, and it waits on the owner.**

State is in [3tk-status.md](3tk-status.md). Narrative is in
[3tk-log.md](3tk-log.md).

**The rules every stage is written against are in
[matryoshka-3tk/design/3tk-rules-004.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-rules-004.md)**
— two parts, the port rules and the stage rules. This plan cites that file; it
does not re-argue it.

---

## Why this plan exists

**`OuterHelper.create` calls application code that nothing declares.** Two
hooks — `outer.init(a)`, and `outer.destroy(a)` in `release` — are found
structurally by `$defined`, at compile time. **A hook whose name is not exactly
right makes `$defined` answer false, the branch vanishes, and nothing anywhere
reports it.** The outer is allocated zeroed, stamped, and handed back
uninitialized; on the release side the same slip means whatever the outer
acquired is never given up.

**The port already knew.** `helper.c3`'s module block says a wrong name is
silent and names the near misses to watch for. **A comment is the whole of the
defence, and that is what this plan replaces.**

**Only the name is silent.** A hook with the right name and the wrong signature
is already a compile error: `$defined` answers true, the branch compiles, and
the call fails.

**The comparison that made it a question.** `PoolHooks` is an `interface`. The
pool's three hooks are declared in one place, they are a page on the docs site,
and a wrong name cannot compile. The outer's two are the same inversion — the
toolkit calls you — with none of that.

### What was measured on 2026-09-09, before any of this was ruled

All on c3c 0.8.3, git `1d155ee`, LLVM 22.1.8.

- **`$assert <cond> : "message";`** is the spelling. `$assert cond, "msg"` does
  not parse. Stdlib precedent at `time/datetime.c3:55`.
- **A failing `$assert` inside a macro names the call site** — *Note: Inlined
  from here* — so the diagnostic points at the user's line, not at 3tk's.
- **`Init` cannot happen.** C3 refuses a method name that starts uppercase:
  *Error: Expected a function name here, e.g. 'someName'*. The module block's
  near-miss list is one-third wrong and is corrected by this stage.
- **The check cannot live at the binding.** A module-scope `$assert` in a
  generic module cannot see `Outer` — *Error: 'Outer' could not be found*. The
  parameter is not bound at module scope, so the check must sit inside a member
  that is called. **This is what `B-5` is for.**
- **12 distinct outer types** bind `helper::OF{...}` across `src/`, `test/`,
  `negative/` and `examples/`. **9 of the 24 hooks already exist** — 7 `init`,
  2 `destroy` — so the sweep is **15 empty bodies**, and the compiler finds
  every site.

---

## What the sitting of 2026-09-09 ruled

Written as ids. **A later stage cites an id; it does not re-argue the point.**

### B-1 — the hooks are required, and an empty body is how a type says it needs none

**Every outer that `OuterHelper.create` makes declares both hooks.** Not
optional, not opt-in, not selected at the call site.

**Why required rather than checked-if-present.** A per-type fact with no
default should be stated, not inferred from absence — and **absence was the
ambiguity.** Today *no `init`* means either *this type needs none* or *you
spelled it wrong*, and the toolkit cannot tell them apart. Requiring the
declaration removes an ambiguity that optionality created, and an empty body is
how a type says *nothing to do* out loud.

### B-2 — the two signatures, and `finish` cannot fail

```c3
fn void? Outer.init(&self, Allocator a)
fn void  Outer.finish(&self, Allocator a)
```

**`init` keeps `void?`.** Its failure is real and `create` already handles it:
free the allocation, propagate the fault unchanged, and never stamp — so a
pointer that escaped a failed creation can never be mistaken for a live outer.

**`finish` returns plain `void`, and that is a narrowing.** Today `destroy`
returns `void?` and `release` turns a failure into
`mtk::@check(!f, "destroy failed during release")` — an abort in a safe build,
dropped in a fast one. **No caller can act on that fault**, and `release`
returns `void` deliberately so it needs no `!` in a `defer`. Removing the
optional removes a fault nobody can use and makes the mandatory empty stub
honest rather than ceremonial.

### B-3 — `destroy` is renamed `finish`, and the rename earns its cost

**`destroy` is C3's own word for *tear this object down*** — `_cv.destroy()`,
`_mu.destroy()` in this very port — and that is precisely what the user must
**not** do to their outer: `release` frees it after the hook returns. The
current name tells them to do the one thing that would double-free.

**`finish` says *wind up your business* and does not suggest the outer goes
away.** It is unused anywhere in the port and is on no ban list, measured
2026-09-09. **The rename is free in this stage** because all 12 types are being
touched anyway.

### B-4 — the mechanism is two compile-time asserts, and nothing else

```c3
$assert $defined(outer.init)   : "every outer declares `init` — an empty body is fine";
$assert $defined(outer.finish) : "every outer declares `finish` — an empty body is fine";
```

**Compile-time, so it is alive in every build mode** — unlike anything routed
through `mtk::@check`, which compiles out under `--safe=no`, the build where a
silently-uninitialized outer does the most damage.

**Three alternatives were weighed and refused, and none is reopened.**

- **A flag at the call site** — `create(a, slot, bool needs_init)`. Refused.
  As a runtime `bool` the check dies in a fast build. As a compile-time
  parameter it works but puts the knowledge **at the call site**, where it does
  not live: whether `Msg` needs an `init` is a fact about `Msg`. The protection
  is then only as good as the least careful call site.
- **Two `create` members**, one requiring hooks and one not. Refused, **and
  `release` is what refuses it.** The pair must match, and **nothing carries
  the choice from `create` to `release`**: the Slot holds an `Inner*`, which
  carries a chain link and a `typeid` and has no room for a bit saying which
  variant made the outer. So the pairing is enforceable nowhere. It is also not
  one bit but two — an outer may want `init` and no teardown, or the reverse —
  and `release`'s call sites are the generic ones: a `defer` registered before
  the acquisition, and the loop that drains what `close` gave back. Those are
  written once and reused, and they are exactly where a second member gets
  picked by habit.
- **A near-miss list**, asserting the absence of `initialize`, `setup`,
  `deinit`. Refused as a *substitute*. **A list can only catch names someone
  predicted**; `B-1` catches every name that is not the right one. It is
  strictly weaker and mandatory makes it redundant.

### B-5 — the MUST binds outers the helper creates, and the containers are outside it

**The check fires at `create` and `release`**, because the measurement above
shows it cannot live at the binding.

**`_Mbox` and `_Pool` never call `OuterHelper.create`.** They bind
`helper::OF{_Pool}` and use `stamp` and `look`, but they allocate themselves,
because they hold a mutex and a condition variable whose teardown order is the
whole of `Pool.release`. **Forcing them to declare two empty hooks beside a
real constructor would be worse than saying nothing.**

**So the rule is worded: every outer that the helper creates declares both
hooks.** That is a line and not a fudge — the hooks are `OuterHelper.create`'s
contract, and a container with its own creation path is not making that
contract. **It is an outer for crossing, not for allocation.** One sentence in
the module block says so, and the exemption stops being a hole.

### B-6 — no interface, and 3TK-70's ruling stands on a replaced argument

**There is still no hooks module and no interface for the outer's hooks.**

**But the argument that produced that ruling is gone, and the stage must record
the replacement rather than re-affirm the old text.** 3TK-70 ruled it because
*both hooks are optional, and an inert interface reads as mandatory*. `B-1`
deletes that premise.

**The reason now, and it is stronger:** an interface exists to carry a choice
across a boundary at runtime, and **these hooks are not passed.** There is
nothing to implement and nothing to hand over. An interface here would add
runtime dispatch through a vtable to answer a question the compiler already
knows, on a helper that has no instantiation at all.

**A later stage that finds 3TK-70's old sentence must not read the ruling as
lapsed with its argument.**

### B-7 — the difference from the pool is explained, in the reference and in the module block

**The user's confusion is legitimate and the text must not dismiss it.** Both
are inversions: in both cases the toolkit calls your code. So the answer is not
*these are different kinds of thing*. They are the same kind of thing, differing
in **how many answers there are and when the answer is fixed.**

> **A pool's hooks are policy: one answer per pool, chosen when you create it,
> so you pass them in. An outer's hooks are the type's own: one answer per type,
> fixed forever, so you declare them on the type.**

Everything else follows from that sentence, and the stage writes the table with
it:

| | pool hooks | outer hooks |
|---|---|---|
| what it decides | the pool's **policy** | the type's **own** construction and teardown |
| how many answers | **one per pool** — two pools of the same outer type can differ | **one per type, forever** |
| when it is fixed | at `pool::create`, at runtime | at compile time, by the type |
| how it is spelled | `interface PoolHooks`, implemented and **passed** | two methods **declared on your outer** |
| may it be absent | a pool cannot exist without hooks | no — **but the body may be empty** |
| where it lives | its own page, `mtk::pool::hooks` | on your type, and in `create`/`release`'s contract |

**And the one line a user asks for before they ask it** — *why must I write two
empty methods* — is `B-1`'s answer, and it goes in the module block.

### B-8 — Rule 9 governs the order, and it is not optional here

**The two asserts and one exemplar type first.** Watch the build go red across
the eleven types that have not been swept. Only then sweep.

**Negative-test the check in both directions before trusting it** — a type with
a correctly spelled hook, and a type with `initialize` where `init` belongs.

### B-9 — what the stage owes besides the source

- **The doc loop, in the same stage.** `create` and `release`'s doc blocks both
  change. `./check-doc-loop.sh`.
- **`3tk-reference-009.md`** — the two contracts, the required rule, and `B-7`'s
  table.
- **`3tk-decisions-007.md`** — the new MUST, `B-2`'s narrowing, `B-3`'s rename,
  `B-5`'s exemption, and **`B-6` recorded as a replaced argument.**
- **Two negatives**, tier 1: a missing `init` and a missing `finish`, each
  proven to fail the build, and each added to `run-builds.sh`.
- **`helper.c3`'s module block rewritten**, not patched — its optionality
  paragraph is the premise `B-1` deletes. **And its near-miss list corrected**:
  `Init` cannot happen.
- **Rule 10** — the script changes carried across to `matryoshka-3tk`, and the
  `.yml` review. **"None needed" is an answer that must be written into the
  log.**

### B-10 — what this stage does not do

- **It does not touch `PoolHooks`.** The pool's three hooks are unchanged in
  name, shape and mechanism. `B-7` explains the difference; it does not narrow
  it.
- **It does not add a marker, a flag or a second `create`.** `B-4` closed all
  three for good, not deferred.
- **It does not make the containers declare hooks** — `B-5`.
- **It does not reopen `3TK-50`.**

---

## The stage

| stage | what it does | model |
|---|---|---|
| **3TK-74** | **The outer's hooks become required.** `init` and `finish` declared by every outer the helper creates, empty bodies allowed; `destroy` renamed and narrowed to `void`; two compile-time asserts; the module block rewritten and the pool comparison written into the reference. **15 empty bodies over 12 types**, and two negatives. | **Opus 5** |

**Why Opus 5.** Rule 8's basis is how much of the stage is deciding rather than
applying. **This is the middle case, and Rule 8 names it**: the stage both
changes a rule and applies it. The sweep is mechanical and the compiler finds
every site, but the deciding half — `B-5`'s exemption, `B-6`'s replaced
argument, `B-7`'s explanation, and `B-2`'s narrowing — is small, load-bearing
and binds later stages.

### Steps

**1. The two asserts and one exemplar.** `B-4` and `B-8`. Add the asserts to
`create` and `release`, give one type its two hooks, and **watch the other
eleven go red.** Do not proceed until they have.

**2. The two negatives.** `B-9`. Both directions, and both in `run-builds.sh`
before the sweep, so the sweep is measured rather than asserted.

**3. The rename and the sweep.** `B-3`. `destroy` to `finish`, `void?` to
`void`, and the 15 empty bodies. The compiler is the work list.

**4. The module block.** `B-1`, `B-5`, `B-6`. Rewritten, not patched. The
optionality paragraph goes; the exemption sentence and the not-passed argument
arrive; the near-miss list is corrected.

**5. The reference and the decisions record.** `B-7` and `B-9`.

**6. Close.** `run-builds.sh`, `check-doc-loop.sh`, `move-module-docs.sh
roundtrip`, `run-sanitizers.sh`. **The figures move in this stage** — two
negatives add checks — and the new ones go into the status. Then Rule 10, the
log entry and the status row.
