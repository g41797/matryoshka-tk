# Review of `3tk-porting-proposal-002.md`

## Overall assessment

The proposal is substantially stronger than a normal porting plan.

Its biggest strengths are:

- decisions are explicit;
- rejected alternatives remain documented;
- findings from implementation are folded back into the proposal;
- MUST and SHOULD requirements are mapped systematically;
- C3-specific behaviour is measured rather than assumed;
- build modes are treated as part of the design;
- the proposal distinguishes a language adaptation from a Zig transliteration.

The document is also unusually good at preserving the reason for a decision.

The main problems are not architectural reversals.

They are mostly:

1. internal counting and terminology contradictions;
2. a few statements that are stronger than the evidence shown in the document;
3. several places where the intended invariant is correct but the proposed wording could accidentally specify the wrong implementation;
4. some duplication between the decision sections and the later mapping.

The architecture itself looks coherent.

The following changes would make the document more precise and harder to misimplement.

---

# 1. Fix the explicit contradiction: "two parts" versus three fields

The proposal says:

> Three words in `AnyNode` on linux-x64: 24 bytes.

and later repeatedly describes Part 4.2 as:

> Two parts, nothing more

while the actual type is:

```c3
struct AnyNode
{
    AnyNode* prev;
    AnyNode* next;
    typeid   type;
}
````

This is understandable if the specification means two conceptual parts:

* linkage;
* identity.

But the document sometimes reads as if `AnyNode` physically has two members.

That becomes especially confusing in D3:

> the inner has exactly two parts, and a third is added only with a reason written down

followed by an argument against adding an allocator as a "third field".

There are already three fields.

## Recommended fix

Define this once and use the same distinction everywhere:

> `AnyNode` has two conceptual parts:
>
> 1. intrusive linkage, represented by `prev` and `next`;
> 2. stored type identity, represented by `type`.
>
> It currently has three fields.
>
> Adding another conceptual responsibility or per-item field requires an explicit reason.

Then change references such as:

> D3 already refused a third field in the inner

to:

> D3 already refused an additional per-item allocator field in the inner.

This is the clearest correction in the document.

---

# 2. Fix the explicit contradiction: "seven members" versus nine rows

Section 5.3 says:

> Part 7.2's seven members, as generated.

But the table lists:

1. identity;
2. predicate;
3. checking crossing, handle;
4. asserting crossing, handle;
5. checking crossing, Slot;
6. asserting crossing, Slot;
7. moving crossing, Slot;
8. way back;
9. initializer.

That is nine members.

D10 also says:

> alias h = mtk::helper{Type};      // the seven members of Part 7.2, once

while D3 describes the helper as providing a larger surface.

This is a genuine document contradiction.

## Recommended fix

Do not fix the number without checking the specification.

The proposal should distinguish between:

* the **seven members required by Part 7.2**;
* additional members supplied by the port.

For example:

```md
Part 7.2 requires seven helper members.

The C3 helper provides those seven plus two identity-related members required
by Parts 5.5 and 6.3.

The full generated surface therefore has nine members:
```

Then explicitly mark the table:

| Member           | Origin   |
| ---------------- | -------- |
| `TYPE`           | Part 5   |
| `is_mine`        | Part 7.2 |
| `from_any`       | Part 6.3 |
| `must_from_any`  | Part 6.3 |
| `from_slot`      | Part 7.2 |
| `must_from_slot` | Part 7.2 |
| `move_from_slot` | Part 7.2 |
| `to_any`         | Part 7.2 |
| `init`           | Part 5.5 |

If `to_any` or another member is not actually one of the seven specified
members, adjust the origin column from the specification rather than preserving
the current count.

The important thing is:

**never call a nine-member API "the seven members".**

---

# 3. D3 has a terminology contradiction about allocators

D3 correctly argues:

> Application items keep one in the outer, never in the inner.

But the decision register says:

> No release call takes an allocator.

Later, the override says:

> `mtk::owned` loses its second `$assert` and gains an `Allocator` parameter on
> `release`, and Part 13.1's clause is knowingly broken for application items
> only.

This is logically fine as an override discussion.

The problem is that the ruling "no release call takes an allocator" is broader
than the actual design boundary.

The containers and `owned` helper have different allocation domains.

## Recommended fix

State the invariant more precisely:

> A released object obtains the allocator from its own lifetime state.
>
> `Mailbox` and `Pool` store it in the container.
>
> An `owned` application item stores it in its outer object.
>
> Therefore the public `release` surface takes no allocator parameter.

This gives one principle rather than three separate rules.

It also makes the rejection of an allocator in `AnyNode` clearer:

> The allocator belongs to the allocation owner, not to the polymorphic inner.

That is a stronger architectural statement.

---

# 4. D5 needs a precise explanation of where Slot conversion is allowed

D5 says:

> The friction appears only where a handle becomes a Slot or the reverse, which
> is the helper, which is where Part 7.5 wants it.

This is slightly misleading.

The rest of the proposal explicitly gives `Slot` operations such as:

* `is_empty`;
* `peek`;
* `take`.

Those operations necessarily perform the ordinary Slot/handle interpretation
outside the per-type helper.

That is not a problem.

The problem is only the **outer/item ↔ inner/handle border**.

## Recommended fix

Replace the quoted sentence with:

> The distinction between `Slot` and `AnyHandle` is handled by the small Slot
> primitives. The only outer/item ↔ inner/handle crossing remains in the
> per-type helper, as Part 7.5 requires.

This is more exact.

Otherwise the reader may conclude that every conversion involving `Slot` must
literally happen in `helper.c3`, which the proposal itself does not do.

---

# 5. Define the Slot API once instead of describing it informally

D5 says:

> The port supplies three one-line macros on `Slot` — `is_empty`, `peek`,
> `take`.

But no authoritative signatures appear later.

This matters because `Slot` is a distinct `typedef`, and the exact pointer
levels are central to the port.

## Recommended fix

Add a small normative subsection immediately after the type definitions:

```c3
typedef Slot = AnyHandle;

// exact spelling to be finalized from the compiled implementation
macro bool slot_is_empty(Slot s);
macro AnyHandle slot_peek(Slot s);
macro AnyHandle slot_take(Slot* s);
```

Or use the actual C3 spelling implemented by 3TK-6.

The important design point should be explicit:

* `peek` does not clear;
* `take` clears;
* only `Slot*` operations can transfer ownership of the Slot's content;
* ordinary code does not repeatedly cast `Slot` to `AnyHandle`.

This would make D5 much easier to understand.

---

# 6. Clarify `AnyHandle` and nullability

The proposal repeatedly says that list operations return:

> a null handle on an empty list

while also using `AnyHandle` as the ordinary handle type.

The type declaration is:

```c3
alias AnyHandle = AnyNode*;
```

That probably means null is represented directly by the pointer.

But because the document is otherwise very careful about `?` and `~`, this
should be stated once.

## Recommended fix

Add:

> `AnyHandle` is a nullable pointer representation.
>
> Null is used only by non-failing container primitives whose natural result is
> "no item", such as `NodeList.pop_front`.
>
> Public operations whose absence is part of their outcome contract use C3
> faults instead.

This makes the distinction between:

* null handle;
* empty Slot;
* `EMPTY~`;
* `TIMEOUT~`;
* `NOT_AVAILABLE~`;

much easier to follow.

---

# 7. Recheck the `receive_all` closed semantics

The mailbox surface says:

```c3
fn void? receive_all(&self, NodeList* out)
```

with outcomes:

> a list, possibly empty; `CLOSED`

This needs an explicit precedence rule.

Suppose the mailbox is closed but still contains items.

Which result occurs?

Possible implementations are materially different:

1. return remaining items, then report `CLOSED` on the next call;
2. report `CLOSED` immediately and leave remaining items for `close`;
3. move remaining items and also somehow report `CLOSED`.

The current wording does not make this obvious.

The same issue exists conceptually for `poll` and `receive`.

## Recommended fix

Add one rule near the mailbox state machine:

> When items are available, acquisition wins over the closed state.
>
> `CLOSED` is returned only when the requested acquisition cannot produce an
> item because the mailbox is closed and empty.

If that is the intended specification behaviour.

If not, state the actual precedence explicitly.

Do not leave this to implementation interpretation.

---

# 8. `wake_all` returning `CLOSED` needs a reason or reconsideration

The proposal gives:

```c3
fn void? wake_all(&self)
```

with:

> done; `CLOSED`

But waking waiters after close is normally harmless.

The document also says:

* close is idempotent;
* waking carries no meaning;
* wake-all is based on a generation counter.

There is no obvious architectural reason in the proposal why calling
`wake_all` on a closed mailbox must fail.

This is not necessarily wrong.

It is just underexplained.

## Recommended improvement

Either document:

> `wake_all` after close returns `CLOSED` because the operation is defined as
> acting on an open mailbox only.

or simplify it:

> `wake_all` is harmless after close and always returns successfully.

The second shape may be easier because it preserves the principle that a wakeup
has no meaning and does not change ownership or state.

Do not change this solely for aesthetic reasons.
Check the specification's intended Part 11.5 semantics first.

---

# 9. Part 2.10 should not be described as entirely "not applicable"

Section 5.1 says:

> 2.10 Cleanup paths run to the end | MUST where 2.9 | Not applicable under D9.

That is mechanically understandable if Part 2.10 only constrains interruption.

But the proposal elsewhere says:

> `Pool.put` cannot fail regardless.

and relies on cleanup/give-back paths completing normally.

Therefore "not applicable" risks suggesting that the general principle of
non-aborting cleanup no longer matters.

## Recommended fix

Use narrower wording:

> Not applicable as an interruption-specific requirement because D9 drops
> interruption.
>
> The ordinary give-back and cleanup paths remain non-failing where required by
> Parts 9, 11 and 19.

This preserves the exact conditional status without weakening the broader
design.

---

# 10. The layering test should not be described only as a grep

The proposal says:

> no function in `mailbox.c3` or `pool.c3` reads a field or calls a `@private`
> function of the core four.

and later:

> The layering. Section 5.12's claim, as a grep in the test script

There are two problems.

First, the containers intentionally live in submodules so they cannot access
the parent's `@private` declarations.

That part is already enforced by the compiler.

Second, because the core structs have public fields under D1, a grep is only a
convention check for field access.

It is not a full layering proof.

## Recommended fix

Separate the two guarantees:

> The compiler proves that `mtk::mailbox` and `mtk::pool` cannot call
> `@private` declarations of the core.
>
> A source-level check additionally rejects direct reads of the core structs'
> internal fields.
>
> The test script therefore checks a naming convention, while C3 enforces the
> actual visibility boundary.

This is more honest and stronger.

Also define the forbidden field pattern.

For example, if the rule is:

* `_prev`;
* `_next`;
* `_type`;

or whatever the actual core-private fields are.

Otherwise "reads a field" is too broad because the containers must necessarily
work with public API-visible values somewhere.

---

# 11. D1 slightly overstates what submodules prove

D1 says putting containers in submodules makes the claim:

> built on the intrusive layer with no privileged access to it

a compiler-enforced fact.

That is mostly true for `@private` declarations.

But the proposal itself chooses public structs and public fields.

Therefore the compiler does not prevent all privileged implementation coupling.

It prevents access only to declarations actually marked `@private`.

## Recommended wording

Replace:

> makes that claim a fact the compiler enforces

with:

> makes the core's explicit private boundary compiler-enforced.
>
> Public surface coupling remains visible in source and is constrained by the
> Part 17.2 layering rule and its tests.

That avoids claiming stronger information hiding than D1 actually chooses.

---

# 12. The `NodeList` count needs an explicit invariant

Section 5.5 says:

> `len` is O(1): the port keeps a count

This is a meaningful additional state field.

But the list invariant table does not explicitly say:

> count equals the number of linked nodes.

That invariant is necessary for every operation that mutates the list.

## Recommended fix

Add to the list invariant discussion:

> `NodeList.len` equals the number of items currently linked into the list.
>
> Every insertion increments it exactly once.
>
> Every removal decrements it exactly once.
>
> `append_list` transfers both counts and leaves the source at zero.

This is especially important because the proposal is otherwise focused on link
invariants and could accidentally under-document count corruption.

Also clarify whether `len` is the exact field name or merely the operation.

---

# 13. `PoolBucket[]` needs its lifetime and growth rule stated

G4 says:

> a flat `PoolBucket[]` allocated once at creation

This is good.

But the proposal should explicitly say whether:

* every configured identity has exactly one bucket;
* the array never grows;
* duplicate tags are rejected;
* lookup failure is possible;
* bucket lookup occurs under the pool mutex.

Those details affect `get`, `put`, `close`, and hooks.

## Recommended addition

```md
The bucket set is fixed at `Pool.create`.

Each configured identity appears exactly once.

Creation rejects an empty set and duplicate identities.

No bucket is created or destroyed after creation.

Lookup is linear over the fixed array.

All bucket lookup and mutation happens under the pool mutex, except application
hook execution after the required state has been detached.
```

This makes G4 a complete design rather than only a performance choice.

---

# 14. The `on_put` two-Slot explanation should define the transaction order

G5 is one of the strongest improvements in version 002.

However, the exact order is important.

The proposal says:

> `Pool.put` clears the caller's Slot at the moment it accepts the item

and then gives the hook its own Slot.

The implementation should specify what "accepts" means.

## Recommended sequence

```md
`Pool.put` has two Slot domains.

1. The caller's Slot is checked and contains the offered item.
2. The pool decides under its mutex that the pool accepts the offer.
3. The item is removed from the caller's Slot.
4. A hook-local Slot is initialized with that item.
5. The mutex is released.
6. `on_put` receives the hook-local Slot.
7. The hook-local result is interpreted and the resulting item is either
   pooled, released, or otherwise handled according to Part 12.2.

After step 3 the caller's Slot remains empty regardless of what the hook does.
```

Adjust the exact sequence to the implementation if the hook can cause refusal.

The key invariant is:

**the caller's observable result must not depend on the hook's temporary Slot.**

That deserves a short explicit statement.

---

# 15. The D6 macro deserves one more rule: contract expressions must have no required side effects

The macro:

```c3
macro @check(#cond, $msg)
{
    $if env::COMPILER_SAFE_MODE:
        always_assert(#cond, $msg);
    $endif
}
```

does not evaluate `cond` in fast builds.

That is intentional and correct.

But it creates an important coding rule:

```c3
mtk::@check(do_something(), "...");
```

would perform `do_something()` only in safe builds.

## Recommended addition

> An expression passed to `mtk::@check` must have no required side effects.
>
> The expression may not perform cleanup, state mutation, allocation, I/O, or
> any operation required for correctness.
>
> `@check` is observational only.

This follows directly from the three-tier design and should be stated.

---

# 16. Avoid saying that Tier 2 is simply "compiled out entirely" without the side-effect qualification

The current table says:

> Compiled out entirely. Not an assumption.

That is accurate for the intended mechanism.

But add:

> Consequently, the condition is not evaluated in a fast build.

This is actually stated later, but it belongs directly in the policy table.

Then the rule above about side effects becomes obvious.

---

# 17. The build matrix is excellent, but "every one of them, every time" conflicts with some tests being build-specific

Section 7.2 says:

> Every one of them, every time.

Section 7.3 then says:

> Safe builds only, by construction.

for the O(n) walk checks.

These statements are not fatal, but they contradict literally.

## Recommended fix

Change the opening sentence to:

> Every build runs every test applicable to that build.
>
> The complete CI matrix covers all four builds.

Then distinguish:

* tests expected to run in all four;
* Tier 2/3 tests meaningful only in safe builds;
* compile-time refusal tests;
* abort/negative tests.

This makes the matrix precise.

---

# 18. "55 checks" and "71 tests" need a glossary

Section 9 says:

> All four builds green: 55 checks, 0 failures. 71 tests × 4 builds, 6 runtime
> negatives, 2 tier 1 negatives, 3 compile-time refusals, 3 layering checks.

A reader cannot tell whether:

* 55 checks are test cases;
* 71 tests include build variants;
* negatives are included in 71;
* compile-time refusals are included in the four-build count.

The numbers may all be correct, but the counting dimensions are mixed.

## Recommended fix

Use a small summary table:

| Category                   | Count | Runs in           |
| -------------------------- | ----: | ----------------- |
| Ordinary runtime tests     |     X | four builds       |
| Safe-mode invariant tests  |     X | safe builds       |
| Runtime negative tests     |     6 | applicable builds |
| Tier 1 abort tests         |     2 | four builds       |
| Compile-time refusal tests |     3 | compile checks    |
| Layering checks            |     3 | source checks     |

Then:

> "55 checks" means ...
>
> "71 tests" means ...

Do not make the reader reverse-engineer the metrics.

---

# 19. "Part 18 is complete" should distinguish tested, structural, and documented invariants earlier

The document later says:

> twenty-eight tested or provoked, five structural or documented

This is good.

But the stronger statement:

> Part 18 is complete.

appears first.

## Recommended fix

Use the full statement immediately:

> Part 18 is complete: all thirty-three invariants are accounted for.
>
> Twenty-eight are directly tested or deliberately provoked.
>
> Five are structural or documented because their nature does not admit an
> independent runtime test.

This prevents "complete" from being read as "all 33 have executable tests".

---

# 20. The proposal should separate accepted design from implementation findings more consistently

Version 002 has a good idea:

> Only what the code proved wrong.

But some findings are really:

* implementation discoveries;
* syntax corrections;
* measured capability facts;
* design amendments.

These are not all the same category.

For example:

* F1 changes build spelling;
* F4 changes generic alias usage;
* G4 changes the pool representation;
* G5 changes the hook transaction shape.

G4 and G5 are much more architectural than F1.

## Recommended improvement

Use three finding classes:

```md
F — factual correction
    The earlier document stated C3 behaviour incorrectly.

I — implementation finding
    The design was right, but implementation exposed a missing detail.

G — design gain
    Implementation revealed a better shape and the accepted design changed
    structurally without changing its governing decision.
```

Then G4 and G5 are easier to understand as meaningful amendments rather than
ordinary corrections.

This would also support the claim:

> No decision moved.

because the document could say explicitly:

> Decisions remained stable; implementation findings refined their realization.

That is more precise.

---

# 21. "The code is the truth; the ztk book is wrong twice" is useful but too informal for a normative mapping table

The sentence is memorable:

> The code is the truth; the ztk book is wrong twice.

But section 5 is the most normative part of the proposal.

The sentence introduces ambiguity:

* Which code?
* Which book?
* What exactly is wrong twice?
* Is the port intentionally departing from the specification or correcting an
  implementation description?

## Recommended fix

Move the colourful sentence to a finding note.

In the normative table write:

> `get_wait` never invokes creation hooks.
>
> This follows the measured implementation and the accepted interpretation of
> Part 11.9.
>
> Two older ztk documentation statements describing waiting acquisition were
> found inconsistent and are superseded for the port.

Then link the exact audit finding where available.

The design document should say exactly what wins when sources disagree.

---

# 22. Define whether `typeid` is stored before or after object initialization

Part 5.4 says:

> stored, not computed

and Part 5.5 says:

> `helper::init` writes it

This is fine.

But `owned::create` should specify the ordering of:

1. allocation;
2. outer initialization;
3. allocator storage;
4. identity initialization;
5. publishing through a Slot.

This is especially relevant because the proposal strongly relies on a Slot not
being full until acquisition succeeds.

## Recommended rule

```md
An item is not placed into a Slot until its outer lifetime state and `AnyNode`
identity are initialized.

`owned::create` therefore:

1. allocates the outer;
2. initializes the outer allocator state;
3. initializes the `AnyNode` links and identity;
4. places the resulting handle into the empty Slot.

If allocation or initialization fails before step 4, the Slot remains unchanged.
```

Use the actual C3 failure model if allocation cannot fail in the proposed API.

---

# 23. The helper's `TYPE` identity name should be checked for terminology consistency

The document uses:

```c3
const typeid TYPE = Type::typeid;
```

Elsewhere it discusses per-type identity as `Type::typeid`.

The helper may therefore expose both the language's identity and a copied
constant.

That may be useful.

But the document should say why `TYPE` exists instead of simply using
`Type::typeid`.

## Recommended improvement

Either remove it if redundant, or document:

> `TYPE` is the helper's stable API spelling for the outer's identity.
>
> It avoids exposing reflection syntax at helper call sites.

Without this explanation it looks like unnecessary duplication.

---

# 24. Consider moving the implementation history out of the main normative path

Sections 1 through 8 are a proposal/specification mapping.

Section 9 is historical evidence.

The history is valuable, but references such as:

* 3TK-6;
* 3TK-7;
* F1;
* F3;
* G4;
* sabotage;
* first run of `run-builds.sh`;

appear throughout the normative text.

This sometimes interrupts reading the actual design.

## Recommended structure

Keep the main document in three layers:

```text
1. Accepted design
2. Specification mapping
3. Evidence and findings
```

Then move implementation-specific evidence to appendices:

```text
Appendix A — Findings that amended version 001
Appendix B — Build evidence
Appendix C — Conflict register
Appendix D — What 3TK-6 and 3TK-7 built
```

The evidence should remain.

The improvement is only that a future maintainer can read the accepted design
without already knowing the staging history.

---

# 25. The opening status statement can be simplified

The opening currently explains:

* 001 was proposed;
* stages 6 and 7 built it;
* all sixteen survived;
* owner accepted them;
* 002 says ruling;
* arguments remain.

This is all useful, but the opening spends many words establishing history
before the reader reaches the design.

## Recommended replacement

```md
## Status

All sixteen decisions in this file are accepted by the owner as of
2026-08-23.

Version 001 proposed them.

3TK-6 and 3TK-7 implemented them and produced the findings incorporated here.

No accepted decision changed.

Version 002 changes only the realization where implementation disproved or
refined an earlier assumption.

Rejected alternatives remain documented because the reason for a decision is
part of the design record.
```

This says the same thing more directly.

---

# 26. The strongest architectural rule should be promoted

The document repeatedly establishes this idea:

> The application owns outer types.
>
> The toolkit owns only the inner protocol.
>
> The helper is the named border.
>
> Containers operate only on handles and Slots.

This is probably the central rule of the entire port.

It currently emerges from many sections rather than being stated once as a
primary rule.

## Recommended addition near section 1

```md
## The port's central boundary

Application code owns outer types.

`mtk` owns the representation and rules of `AnyNode`, `AnyHandle`, `Slot` and
`NodeList`.

The per-type helper is the only named border between an application outer and
the toolkit inner.

Containers never know an application's outer type.

Application code never performs inner-offset arithmetic.

A Slot transfers a handle without exposing an outer type.
```

This would make D2, D4, D5, D10 and Part 17 read as consequences of one
principle.

---

# 27. Recommended small terminology cleanup

Use these terms consistently:

| Current mixture          | Recommended                             |
| ------------------------ | --------------------------------------- |
| two parts / three fields | two conceptual parts / three fields     |
| crossing                 | reserve for outer ↔ inner conversion    |
| Slot conversion          | Slot primitive or handle extraction     |
| checking build           | safe build                              |
| fast build               | `--safe=no` build                       |
| item accepted            | define exact state transition           |
| internal field           | public-but-internal-by-convention field |
| hidden implementation    | compiler-hidden private implementation  |

The document is already terminology-heavy.

Small consistency improvements will reduce the chance that later code reads a
prose distinction as an API distinction.

---

# 28. Suggested priority order for fixes

## Must fix before treating the document as stable

1. "seven members" versus nine members.
2. "two parts" versus three fields.
3. exact closed/available precedence for `receive_all`, and preferably the
   other mailbox acquisition operations.
4. exact meaning and ordering of the two-Slot `Pool.put` transaction.
5. clarify that `@check` expressions must not have required side effects.
6. correct "every one of them, every time" versus safe-build-only tests.

## Strongly recommended

7. define the Slot primitive surface and exact pointer shapes.
8. add the `NodeList.len` invariant.
9. define fixed `PoolBucket[]` construction rules.
10. distinguish compiler-enforced privacy from source-level layering checks.
11. qualify Part 2.10 as interruption-specific rather than simply
    "not applicable".
12. explain or reconsider `wake_all -> CLOSED`.

## Editorial improvements

13. reduce staging-history interruptions in normative sections.
14. define the central outer/helper/inner boundary near the beginning.
15. classify findings as factual corrections, implementation findings, or
    design gains.
16. normalize test-count terminology.
17. replace informal "code is the truth" wording in normative tables.

---

# Final judgement

The proposal has no obvious fundamental contradiction in its main architecture.

The accepted core is coherent:

```text
application outer
        |
        | per-type helper
        v
     AnyNode
        |
        v
    AnyHandle
        |
        v
      Slot
        |
        +----------------+
        |                |
        v                v
    NodeList          containers
                    mailbox / pool
```

The most important conceptual improvement is to state this boundary explicitly
and make the rest of the document derive from it.

The most important correctness fixes are the member count, the
two-conceptual-parts/three-fields terminology, and the exact outcome precedence
around closed containers.

The document should also be careful not to overclaim what submodules prove.
They provide a real compiler-enforced boundary for `@private` declarations.
They do not make public-field coupling impossible.

After those corrections, the proposal would read less like a collection of
successful C3 investigations and more like a stable design record whose C3
investigations provide evidence for the accepted shape.

That is the direction I recommend for version 003:
**keep the decisions, keep the findings, fix the few literal contradictions,
and make the central boundary and state-transition rules more explicit.**
