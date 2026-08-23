# 3tk toolkit notes (001)

Stage 3TK-6 of [3tk-staging-plan-002.md](backup/3tk-staging-plan-002.md).

What writing the code taught that
[3tk-porting-proposal-001.md](backup/3tk-porting-proposal-001.md) did not know.

The toolkit is at `3tk/`. Steps 2 to 5 of Part 22 — the inner and the identity,
the per-type helper with the crossings, the Slot and its six rules, the list
with both insert checks. Part 17.1's one required tool. The two containers are
not here.

## The result

**All four builds green. 44 checks, 0 failures.**

```
== c3c 0.8.3, git 1d155ee, LLVM 22.1.8, linux-x64 ==

== build: safe -O0  (--safe=yes -O0) ==   library, 37 tests, 6 negatives, 3 refusals
== build: safe -O3  (--safe=yes -O3) ==   library, 37 tests, 6 negatives, 3 refusals
== build: fast -O0  (--safe=no  -O0) ==   library, 37 tests, 6 negatives, 3 refusals
== build: fast -O3  (--safe=no  -O3) ==   library, 37 tests, 6 negatives, 3 refusals

passed 44, failed 0
all four builds green
```

Reproduce with `3tk/run-builds.sh`. It exits non-zero on any failure and it is
the stage's verification, not a convenience.

- **37 tests**, run four times.
- **6 runtime negative programs**, each provoking one contract violation. In a
  checking build each must **abort**; in a fast build each must **run to the
  end and exit 0**. Both halves are asserted. A negative that aborts in a fast
  build would mean a plain `assert` had survived somewhere, and D6 exists to
  stop that.
- **3 compile-time negative programs**, refused in every mode, each checked for
  a message that names the offending type.

## The findings, worst first

### F1 — `-O2` and above turn safe mode OFF, silently

**The proposal's build table was wrong**, and this is the finding that matters.

Section 7.2 named the second build "safe, optimized" and spelled it `-O3`.
Measured on c3c 0.8.3:

| Flags | `SAFE_MODE` | `OPT_LEVEL` |
|---|---|---|
| *(default)* | **true** | O0 |
| `-O0` | **true** | O0 |
| `-O1` | **true** | O2 |
| `-O2` | **false** | O2 |
| `-O3` | **false** | O2 |
| `--safe=yes -O3` | **true** | O2 |
| `--safe=no -O0` | **false** | O0 |

So `c3c test -O3` is not the safe optimized build. It is the fast build under
another name, and a suite run under it tests nothing the fast build has not
already tested.

The first run of `run-builds.sh` caught this exactly as designed: five
negatives reported *did NOT abort in a checking build* under `-O3`. The script
was right and the proposal was wrong.

**The rule, written down once:** never infer the build mode from the `-O`
level. Both sides are explicit — `--safe=yes` and `--safe=no` — in every build
this port runs.

3TK-4's Q11 measured `--safe=no -O3` and the default, and drew the table from
those two. Neither exposes the implicit switch. The study is not wrong; it is
short by one row, and this is the row.

### F2 — `@private` is ignored on method declarations, entirely

```
Warning: '@private' modifiers are ignored for method declarations.
```

C3 0.8.3 has no way to hide a method. Not a private field (Q4), and not a
private method either.

This lands on **D1**, and it strengthens it. D1 chose "public struct, public
fields, the helper border does the work" because the opaque route costs Part
11.1. It also said the port would put `@private` on every internal function.
Half of that is unavailable: a free function can be private, a method cannot.

`NodeList.contains` and `NodeList.unlink_no_repair` are therefore public
whether the port likes it or not. The response is D1's own: name them for what
they are and document them. `unlink_no_repair` is named for what it leaves
undone — Part 8.8's repair — so a reader who reaches around the surface is told
at the call site what they now owe.

**No change to D1. It was the right ruling for a reason it did not know about.**

### F3 — `@private` does not reach a submodule

A `@private` declaration in `mtk` is invisible from `mtk::helper`. Verified
with a three-module probe.

So `@check` cannot be private, as D6's sample wrote it — `mtk::helper`,
`mtk::owned` and any application code are all outside `mtk` for this purpose.

The resolution is not a workaround. **Part 17.2** says the two containers use
only what an application could use, and every crossing they perform is one an
application could write. An application writing its own Slot-shaped call is
entitled to the same contract check. `@check` is public on purpose, and the
doc comment says so.

### F4 — a generic module instantiates per declaration, not as a whole

Section 1 of the proposal showed:

```c3
alias msg = mtk::helper{Msg};        // the whole helper, one line
```

There is no such form. `Error: 'mtk::helper' could not be found`. Each
declaration is aliased on its own:

```c3
alias msg_init     = mtk::helper::init{Msg};
alias msg_from_any = mtk::helper::from_any{Msg};
alias MSG_OFF      = mtk::helper::OFF{Msg};
```

Or used inline without an alias at all, which is what `owned.c3` does:
`mtk::helper::init{Type}(item)`.

3TK-4's Q1 said this — *"one alias per generated declaration"* — and the
proposal's own section 1 contradicted it. The proposal is wrong; the study was
right.

**Consequence.** An outer type that wants the full surface writes nine aliases.
That is Part 7.1's *"loses only the typing"* arriving as nine lines rather than
one. It is not a defect and it does not touch a MUST, but a port that expected
one line should expect nine.

### F5 — `always_assert` takes a compile-time message

`macro void always_assert(bool #value, String $fmt = "", ...)`. The message is
`$fmt`, a compile-time string, not a runtime `String`.

`@check` therefore takes `$msg` and not `String msg`. No cost — every message
in the port is a literal — and one gain: the message cannot be built at runtime,
so a contract check cannot accidentally allocate.

Verified that the message survives to the abort:

```
ERROR: 'Violated assert '#cond': Part 8.6 walk: the item is already on this list'
  in @check (src/any.c3:95)
```

The specification clause is in the message at every tier 2 site. A reader of a
crash sees which MUST or SHOULD was broken.

### F6 — a module-scope `$assert` cannot see a generic module's type parameter

In `module mtk::owned <Type>;`, a `$assert` at module scope reports
`'Type' could not be found`.

The check moved inside a macro, `mtk::required_alloc_offset($Type)`, where
`$Type::name` resolves. The message is unchanged and the build-time refusal
still names the type and the alternative:

```
type Plain has no Allocator field; use mtk::helper instead of mtk::owned
```

**No change to D3.** The mechanism moved one level down.

### F7 — `alloc::new` aborts; `alloc::new_try` is the one Part 9.2 rule 4 needs

`alloc::new` returns a plain pointer and aborts on a failed allocation. There
is no failure path, so rule 4 — *a failing acquisition leaves the Slot
unchanged* — would have nothing to be true on.

`owned::create` uses `alloc::new_try`, which returns an optional. That is what
makes `create` a real acquisition with a real failure mode.

An amendment to D3's spelling, not to D3.

### F8 — small spellings the proposal guessed at

| Subject | Proposal / draft | Actual in 0.8.3 |
|---|---|---|
| Size of a type | `Msg.sizeof` | `Msg::size` |
| Size of a pointer | `$sizeof(void*)` | no such builtin; `uptr::size` |
| A member's type | `$m.typeid` | `$m.type`, compared as `$m.type == AnyNode` |
| Signed size type | `isz` | no such type; `long` |
| Aliasing a constant | `alias msg_off = ...OFF{Msg}` | must be **ALL UPPERCASE**: `MSG_OFF` |
| A null identity | `(typeid)null` | no cast from a pointer; zero the struct instead |
| Test sources in `project.json` | `"test-sources": ["test/*.c3"]` | a **directory**: `["test"]` |
| Allocator module | `allocator::` | `alloc::`, from `std::core::mem::alloc` |

None of these touches a decision. They are recorded so a later stage does not
re-derive them.

### F9 — there is no front door to write

The proposal listed `mtk.c3` as a file that re-exports the others. C3 needs no
re-export: `import mtk` brings in everything `module mtk` declares, across
every file that declares it. The module is the front door.

`src/mtk.c3` was kept, holding the port's identity, the reading order of the
files, and `VERSION`. It re-exports nothing because there is nothing to
re-export.

## The sixteen decisions, after the code

| # | Decision | State |
|---|---|---|
| D1 | Public struct, the border does the work | **Survived, strengthened.** F2 removed the alternative D1 had not considered |
| D2 | Plain inner field, no `inline` | **Survived.** `Msg` at offset 8 and `Job` at offset 0 are both tested |
| D3 | Allocators, per type, in the outer | **Survived.** Amended by F6 and F7, in spelling only |
| D4 | One handle type | **Survived.** No cast appears at any call site in the tests |
| D5 | A distinct Slot | **Survived.** The reading shape grew from three macros to five |
| D6 | Three assert tiers, one `@check` macro | **Survived.** Amended by F5. Proved by six negatives × four builds |
| D7 | Anchor the deadline, never `wait_timeout` | **Not exercised.** The toolkit does not wait. Carried to the container stage |
| D8 | The names | **Survived.** `NodeList`, `mtk`, `AnyNode`, `AnyHandle`, `Slot`. F4 and the alias-case rule of F8 are additions |
| D9 | Interruption dropped | **Not exercised.** No waits here |
| D10 | Two composing generic modules | **Survived.** `owned` calls `helper`; the seven members exist once |
| D11 | Part 22's order | **Followed.** Steps 2 to 5, in that order |
| D12 | The link test's blind spot accepted | **Survived, and now has a test that fails if someone closes it.** See below |
| D13 | Poll beside receive | **Not exercised.** Mailbox |
| D14 | Out-of-band kept | **Not exercised.** Mailbox |
| D15 | Faults as the outcome mechanism | **Declared, barely exercised.** The fault set is in `any.c3`; the list cannot fail (Part 19.4) and only `owned::create` returns an optional |
| D16 | The pre-lock fast path | **Not exercised.** Containers |

Sixteen ruled, nine exercised, nine survived. Nothing the code met contradicted
a decision. Two decisions were amended in spelling and none in substance.

**On D12, and why it is worth a paragraph.** Part 8.7's blind spot is an
accepted cost, and an accepted cost that is only documented tends to get
"fixed" by the next reader. `the_link_test_has_a_blind_spot` asserts that an
item alone on a list reports **false** to the link test. If someone turns the
link test into a real membership test, that test fails and names D12. An
accepted cost with a test attached is a decision; without one it is a comment.

## Part 18, invariant by invariant

The thirty-three of the specification. The toolkit reaches fifteen.

| # | Invariant | Part | State |
|---|---|---|---|
| 1-5 | Threads, the two primitives, the wakeup, the deadline, the hand-off | 2.x | **Out of scope.** No waits in the toolkit |
| 6 | Participants are long-lived and do not move | 3.1 | **Documented.** A precondition on the application, not a check the toolkit can make |
| 7 | The outer embeds the inner; the list allocates nothing | 4.1 | **Tested.** `inner_at_any_offset`, `the_list_is_a_queue`. Nothing in `list.c3` takes an allocator |
| 8 | One inner per outer | 4.4 | **Build time.** `nocompile_two_inners`, refused in all four modes |
| 9 | A per-type identity, unique, O(1) | 5.1 | **Tested.** `identity_is_per_type`, on two identically-shaped types |
| 10 | Stored, never computed | 5.4 | **Tested.** `identity_is_stored` |
| 11 | Self-identification at every crossing | 6.1 | **Tested.** `checking_crossing_refuses`, `null_handle_is_nobodys` |
| 12 | Two crossing forms | 6.3 | **Tested and provoked.** `checking_crossing_refuses`, plus `wrong_type_must` |
| 13 | Heterogeneous, O(1), allocation-free | 8.1 | **Tested.** `one_list_three_types`, three types at two offsets |
| 14 | The list speaks in handles | 8.3 | **Structural, and tested.** No entry point in `list.c3` names a typed pointer |
| 15 | The checks live in the list layer | 8.5 | **Provoked.** `insert_twice_same_list`, `insert_linked_item` |
| 16 | The link test is not a membership test | 8.7 | **Tested, both ways.** `the_link_test_has_a_blind_spot` and `the_walk_has_a_blind_spot_too` |
| 17 | A removed item's links are cleared | 8.8 | **Tested.** `every_removal_repairs`, across all three removers |
| 18 | The six Slot rules | 9.2 | **All six.** Rules 2, 4, 5, 6 tested; rules 1 and 3 provoked by `overwrite_slot` and `create_into_full_slot` |
| 19 | The Slot, not the outcome, says where the item went | 9.4 | **Tested.** `rule5_a_transfer_clears_the_slot`, `one_place_at_a_time` |
| 20 | An item is in exactly one place | 9.6 | **Tested.** `one_place_at_a_time` |
| 21-33 | The containers | 11.x-15.x | **Out of scope.** Steps 6 and 7 of Part 22 |

Fifteen of the twenty the toolkit can reach, tested or provoked. Rows 6 and 14
are structural and say so.

Part 8.6's argument — that *neither check alone is enough* — is the one place
the tests carry the reasoning rather than the result. Two tests state the two
blind spots, and two negatives provoke the two checks. That is four artefacts
for one SHOULD, and it is the SHOULD the whole list layer exists for.

## What the specification did not say, and the code had to decide

Three places where the code had to choose and the specification is silent.
Recorded as findings for the owner, not as decisions taken quietly.

1. **Adding from an empty Slot.** Part 9.2 rule 6 makes a *release* a no-op on
   an empty Slot. It says nothing about an *insert*. The port treats it as a
   contract violation — tier 2 — **paired with an early return**, so a fast
   build does nothing rather than dereference a null. That is Part 8.9's
   assert-plus-return shape reused wherever a compiled-out check would leave a
   hole, and the port applies it as a rule.
2. **A remove of an item that is not on this list.** Part 8.8 covers the
   repair and Part 8.7 covers what the link test cannot see. The port adds a
   tier 3 membership walk to `remove`, `insert_after` and `insert_before`, on
   the same reasoning that gives Part 8.6 its walk. Not required by any
   marking.
3. **`front`, `back`, `pop_front`, `pop_back` on an empty list return null.**
   Part 8.2 says both may find the list empty and Part 19.4 says no list
   operation can fail. Null is therefore the answer, not a fault. A port that
   made it a fault would have added an error set the specification says does
   not exist.

## For the next stage

The two containers, steps 6 and 7 of Part 22. Not authorized; named so the
owner can name it.

What is waiting for them:

- **D7's wait loop**, unexercised, and F1 says the build flags are a trap. The
  container stage is where Part 2.4, 2.5 and 2.6 are first written, and where
  `wait_timeout` must not appear.
- **D6 tier 1 has no site yet.** `always_assert` is reached only through
  `@check` in safe builds. Its own site — Part 11.12, close before release — is
  in the container stage, and it is the one call that must abort in the fast
  optimized build. `run-builds.sh` will need a negative that asserts an abort in
  **all four** modes, which no current negative does.
- **D15 is barely exercised.** The fault set exists; the outcome tables of Part
  19.1 and 19.2 are the containers'.
- `run-builds.sh` extends by adding rows to two arrays. It was written for that.

---

## Change log

| Version | Date | Description |
|---|---|---|
| 001 | 2026-08-23 | First version. Stage 3TK-6. Four builds green, 44 checks. |
