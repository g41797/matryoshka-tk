# 3tk — review of the seven c3 drafts (001)

Stage 3TK-3. Every claim in the seven `c3/` drafts, measured against
[matryoshka-specification-001.md](../common/backup/matryoshka-specification-001.md) and
[ztk-audit-001.md](../common/ztk-audit-001.md).

Conflicts are reported. They are not resolved. The owner rules.

## How to read this

Each draft gets a table. One row per claim.

Verdicts:

| Verdict | Meaning |
|---|---|
| **HOLDS** | Agrees with the specification. Nothing to decide. |
| **GAP** | Not wrong, but incomplete against a MUST or SHOULD. |
| **CONFLICT-S** | Conflicts with the specification. |
| **CONFLICT-D** | Conflicts with another draft. The column names it. |
| **UNVERIFIED** | A C3 language claim. Nothing here can settle it. 3TK-4 does. |
| **OUT** | Outside the specification's subject. Neither confirmed nor denied. |

A row may carry two verdicts. `CONFLICT-S` and `CONFLICT-D` together is the
common case: a draft is wrong, and another draft is right about it.

Spec references are `Part n.m`. Audit references are `audit n.m`.

## The seven drafts

| File | Date on disk | What it is | Overall |
|---|---|---|---|
| `3tk-poc.md` | 08-20 | A whole proposed implementation, with code | **Reject as source.** 9 spec conflicts, 4 of them MUST |
| `ztk-to-3tk.md` | 08-23 07:35 | A process proposal, two stages | **Superseded.** 3TK-0..2 executed it |
| `3tk-build-dist.md` | 08-23 07:34 | C3 packaging and distribution | **Mostly OUT.** 2 conflicts in its framing paragraphs |
| `3tk-design-notes.md` | 08-23 07:35 | The naming and structure mapping | **Largely holds.** Superseded in detail by porting-notes |
| `3tk-polyhelper.md` | 08-23 08:35 | `AnyHelper`, with code | **Useful shape, unverified spelling.** 3 spec conflicts |
| `3tk-additions.md` | 08-23 08:34 | Four separate notes: hooks, methods, Slot, handles | **Split verdict.** The hooks note is the sharpest and the most wrong |
| `3tk-porting-notes.md` | 08-23 08:35 | The full C3 design, latest and most careful | **The best of the seven.** 4 things to fix |

`3tk-poc.md` predates the other six by three days and predates the
specification by three. It is the only draft written without the others in
view. Every one of its conflicts is a consequence of that.

`3tk-porting-notes.md` is the only draft that already contains a verification
rule, splitting confirmed architecture from what needs a compilable prototype.
That split is correct and this review keeps it.

---

# 1. `3tk-poc.md`

| # | Claim | Verdict | Conflicts with | Recommendation |
|---|---|---|---|---|
| P1 | Four building blocks: **Masters**, Items, Mailboxes, Pools | CONFLICT-S | Part 1.3 MUST — *there is no `Master` type*. `audit` line 46: no `Master` anywhere in `src/`. Part 17: **three** tools, and two of those are optional | Drop `Master` from every list of components. The concept is the application's, and the toolkit ships no struct for it |
| P2 | `struct Node { Node* next; Node* prev; }` | CONFLICT-S | Part 4.2 MUST — the inner has **exactly two parts**, links *and the type identity*. Part 5.1, Part 5.4. The whole of Part 6 rests on the missing field | The node without an identity field cannot self-identify, so no crossing can be checked. This single omission removes invariants 9, 10, 11 and 12 of Part 18 |
| P3 | Zero allocations after boot; the framework never escalates to an allocator | CONFLICT-S | Part 12.2 — the on-get hook **creates** an item when none is stored. Part 11.7 — get in *available or new* mode asks the hook. Part 13 — objects take an allocator at creation and keep it | *Transfer* allocates nothing (Part 1.1, Part 4.5). That is the real invariant and it is narrower than what this draft states. Rewrite as "no allocation on a transfer" |
| P4 | Items are created upfront by the user and fed in; the pool never scales | CONFLICT-S | Part 12.2, on get: "Create one, or leave the Slot empty" | Prefilling is one hook policy. Part 11.10 — the pool promises nothing. The draft raises one policy to an invariant |
| P5 | `fn void Mailbox::push(Mailbox*, Node* item)` | CONFLICT-S | Part 9.3 MUST — an operation that acquires takes a **pointer to a Slot**. Part 9.2 rules 3, 4, 5. Part 19.1 — send has the outcome *closed, Slot unchanged* | Every transfer in the toolkit is Slot-shaped. This signature has no Slot, no outcome, and no way to leave the item with the sender |
| P6 | `fn Node* Mailbox::pop_timeout(...)` returns the item | CONFLICT-S | Part 9.3, Part 9.4 — the Slot is the answer, not the return value. Part 9.5 permits a returning form only as the named exception for a select mechanism | The exception is deliberate and named. It is not the default receive |
| P7 | The wait loop passes `timeout_ms` again on every iteration | CONFLICT-S | Part 2.5 MUST — the deadline is anchored **once**, before the loop. Invariant 4 of Part 18 | A spurious wakeup restarts the full timeout. The call can outlive its deadline without bound. This is a real defect, not a spelling one |
| P8 | `Pool` has one `free_list` and one `count` | CONFLICT-S | Part 11.7 MUST — **one free list per identity**, one count per identity, the identity set fixed at creation and not empty | Follows from P2. With no identity in the node there is nothing to group by |
| P9 | The pool has no hooks | CONFLICT-S | Part 12.1 MUST — hooks are a parameter of creation. *A pool cannot exist without them* | |
| P10 | No closed flag, no `close`, no out-of-band, no batch receive, no wake-all | GAP | Part 11.3, 11.6, 11.8, 11.12, 15.3. Invariants 22, 23, 24, 26 | A proof of concept may omit surface. It should say what it omitted. This one does not |
| P11 | `(Node*)ticket` — the cast assumes the node is at offset zero | HOLDS | Part 4.3 SHOULD permits exactly this: "A port whose cast needs offset zero fixes the field at offset zero instead" | Legal. But it conflicts with the `inline AnyNode` direction of the later drafts — see conflict **C2** |
| P12 | `Mailbox` and `Pool` are plain structs, not items | CONFLICT-S | Part 11.1 MUST — both embed an inner and have a type identity. Invariant 21. This is "the toolkit's stated reason for existing" | |
| P13 | C3 gives absolute address stability, no implicit struct moves | HOLDS | Part 3.1, Part 3.2 — participants are long-lived and do not move | The observation is the right one to make. Its C3 half is UNVERIFIED, 3TK-4 |
| P14 | `project.json` multi-root layout with per-example targets | OUT | — | Compare against `3tk-build-dist.md`, which proposes a different one. Conflict **C9** |
| P15 | Toolchain: `dnf groupinstall`, lldb/gdb, VS Code extension, JetBrains TextMate | OUT | — | Stale in one place regardless: the status file records `c3c` already installed at `/usr/bin/c3c`. No install step in any stage |
| P16 | CI: `curl -sL https://github.com \| tar -xz` | OUT | — | The URL is a bare host. The YAML below it also loses its indentation mid-block. Do not copy this file's CI |
| P17 | `c3c docgen` extracts JavaDoc blocks to flat JSON | UNVERIFIED | — | 3TK-4, if documentation is in its scope. It is not in the specification's |
| P18 | Closing question: type erasure by macro casting, or a `PolyNode` pattern with an enum byte tag? | CONFLICT-S | Part 5.2 — the identity is not an index into a table. An enum byte over a closed set of types is that table. Part 5.1 requires uniqueness across **all** outer types in the program, including the application's | Answered by the specification. The question does not need re-asking |
| P19 | Closing question: register each Master in an intrusive active-workers list? | CONFLICT-S | Part 1.3 | Follows from P1 |

**Recommendation for the file.** Retire it. Mark it superseded in
`3tk-status.md` rather than deleting it: P7 and P13 are worth keeping in the
record, and the file is the clearest available evidence of what a port looks
like when it is written without the specification.

---

# 2. `ztk-to-3tk.md`

This draft proposes the process, not the design. It is measured against what
was actually done.

| # | Claim | Verdict | Conflicts with | Recommendation |
|---|---|---|---|---|
| Z1 | Stage 1: investigate ztk, produce a porting analysis | HOLDS | — | Done, as 3TK-1, `ztk-audit-001.md` |
| Z2 | Separate architecture (A) from Zig implementation choices (B) | HOLDS | — | Done. `audit 3` is that table. The specification's Part 16 is the B list, named once |
| Z3 | Category C: state openly what is not yet known | HOLDS | — | Kept. Part 20 (ten decisions) and Part 21 (twelve questions) are the C list, structured |
| Z4 | Stage 2: the implementation plan, after the owner resolves the questions | HOLDS | — | That is 3TK-5, and it is correctly not started |
| Z5 | Stage 1 should use Opus, mechanical work Sonnet | OUT | — | An operating note, not a design claim |
| Z6 | Determine the source of truth: local tree versus GitHub remote | HOLDS | — | Settled. `audit` reads the local tree. ztk is green at 195/195 |
| Z7 | The purpose question: (A) semantic port, (B) language-native, (C) reference implementation | HOLDS | — | Answered by the specification, in Part 5.3, Part 7.1, Part 19 and the porting rule in `3tk-status.md`: **B**. The architecture is the invariant, the spelling is the port's |
| Z8 | Make type identity and the helper the **first** feasibility investigation | HOLDS | — | Matches Part 21 Q1 and Q2, and Part 22 step 2. Carry into 3TK-4 as its first two questions |
| Z9 | `typeid` is a dangerous area, because the ztk tag is a unique opaque identity rather than "some runtime type number" | HOLDS | — | The concern is precise and Part 5.3 confirms its basis. Part 5.1 states what any replacement must satisfy. The four other drafts assume `typeid` passes; **none of them checks it against Part 5.1**. See conflict **C1** |
| Z10 | Do not broaden the execution model during the initial port; thread-based only | HOLDS | — | Part 2.1 MUST, plain threads. Part 1.2, not an async runtime |
| Z11 | Build a feature/test matrix between the two repositories | OUT | — | A 3TK-5 decision. Note that Part 5.3, Part 9.9 and Part 20 make an exact parallel *undesirable* in places: the port is expected to diverge where C3 has a better mechanism |
| Z12 | Documentation is an open problem; C3 may need a different solution | OUT | — | Real, and untouched by any stage so far. Not in the specification's scope |

**Recommendation for the file.** Superseded by `3tk-staging-plan-001.md`. Its
one live residue is Z8 and Z9 — the first questions 3TK-4 should answer.

---

# 3. `3tk-design-notes.md`

The earlier of the two design documents. `3tk-porting-notes.md` covers the same
ground later and more carefully. Only rows where the two differ, or where the
specification has something to say, are listed.

| # | Claim | Verdict | Conflicts with | Recommendation |
|---|---|---|---|---|
| D1 | `PolyNode`→`AnyNode`, `PolyHelper`→`AnyHelper`, `ItemHandle`→`AnyHandle`, `ItemList`→`AnyList` | HOLDS | — | Part 5.3, Part 8.2 — names are the port's business. Note Part 10.1: the specification's own four words are **inner**, **handle**, **Slot**, **item**, and Part 10.3 bans "object" for an item |
| D2 | `Item` → `Any` | CONFLICT-D | `3tk-additions.md`: `any` is a reserved keyword, so `Any` should not be a type name. `3tk-porting-notes.md`: C3 is case-sensitive, so `Any` *may* be fine — verify | A three-way disagreement inside the drafts. Conflict **C3**. UNVERIFIED, 3TK-4 |
| D3 | `struct AnyNode { AnyNode* next; AnyNode* prev; typeid type; }` | HOLDS | Part 4.2 — exactly two parts, links and identity. Three fields, two parts. Correct | Field order differs from `3tk-polyhelper.md`, which writes `prev, next, type`. Cosmetic. Pick one |
| D4 | `typeid` replaces the manual tag | HOLDS, UNVERIFIED | Part 5.3 — "A language with a native runtime type identifier uses it" | Must still satisfy every clause of Part 5.1 and be storable per Part 5.4. 3TK-4 Q2. Conflict **C1** |
| D5 | Application types embed with `inline AnyNode` | HOLDS, UNVERIFIED | Part 4.1, Part 4.3 | Conflicts with the offset-zero cast of `3tk-polyhelper.md`. Conflict **C2** |
| D6 | `AnyHandle = AnyNode*` | HOLDS | Part 10.1 — a handle is a pointer to an inner with no type knowledge | |
| D7 | A Slot is `AnyHandle*`, a pointer-to-pointer | CONFLICT-S | Part 9.1 — **a Slot is a container of one handle, or of nothing**. The nullable `AnyHandle` *is* the Slot. `AnyHandle*` is a *pointer to* a Slot, which is what Part 9.3 says an operation takes | Not a representation error. A naming error, and it propagates into all three drafts that repeat it. Conflict **C4** |
| D8 | `AnyHelper` should not mechanically reproduce `PolyHelper`; decide after investigating C3 | HOLDS | Part 7.1, Part 7.2 — the shape is fixed, generation is the convenience | |
| D9 | Compile-time validation that `T` embeds `AnyNode` | HOLDS | Part 7.4 SHOULD. Part 21 Q12 | |
| D10 | Runtime `typeid` and compile-time type information stay conceptually separate | HOLDS | Part 5 versus Part 7.4 — exactly this split | Well put. Keep the sentence |
| D11 | C3 has no intrusive doubly-linked list, so `AnyList` is first | HOLDS in part | Part 8.5 MUST — even a port that *has* one still writes the checking layer over it. So the premise does not matter | UNVERIFIED premise, irrelevant conclusion. Write the layer either way |
| D12 | `AnyList` operations: insertion, removal, first/last, iteration, empty, move between lists, null handling | GAP | Part 8.2 also requires: add **from a Slot**, at front and back; insert after and before a named item; how many. Part 8.6 the double check; Part 8.8 clearing links on removal; Part 8.9 refusing a self-move twice | Four MUSTs and two SHOULDs are missing from the operation list. Conflict **C6** |
| D13 | The `AnyList` API should not be copied from `std.DoublyLinkedList` | HOLDS | `audit 3` row 16 — the std list is *incidental* | |
| D14 | `Mbox` and `Pool` embed `inline AnyNode`; they are not merely holders of one | HOLDS | Part 11.1 MUST. Invariant 21 | The most important thing these drafts get right, and `3tk-poc.md` gets wrong |
| D15 | Private fields hide implementation state; no opaque handle needed for hiding | HOLDS, UNVERIFIED | Part 11.11 SHOULD — "a case where a port is *better* than ztk". Part 21 Q4 | |
| D16 | `PoolHooks` keeps `ctx`, `tags`, `on_get`, `on_put`, `on_close` | CONFLICT-D | `3tk-additions.md` proposes an interface and drops `ctx` | Conflict **C5**. Part 12.1 MUST: "The port spells them in the language's own interface mechanism". The struct-of-pointers form is named there as *the ztk spelling, because Zig has no interface keyword* |
| D17 | Pool outcome states: item, closed, timeout, canceled, not_created | GAP | Part 19.2 — plain get also has **not-available**, and Part 19.3 marks the not-available / timeout divergence as a MUST | One outcome missing. It is the one Part 19.3 exists to explain |
| D18 | Components receive an allocator, no hidden global | HOLDS | Part 13.1 SHOULD | Silent on the sharp half: Part 13.1 also says *no release call takes an allocator as a parameter*. See conflict **C7** |
| D19 | No `std.Io` equivalent; do not invent a 3tk Io layer | HOLDS | Part 16, rows 1 to 12. `audit 4` | Unanimous across the drafts |
| D20 | Implementation order: `AnyList` first, then `AnyNode`/`AnyHandle`/`AnyHelper`, then Mbox and Pool | CONFLICT-S | Part 22 — inner and identity, **then the helper**, then the Slot, then the list. The list is step 5, not step 1 | Part 22 is explicitly "not conformance, a suggestion". So this is a conflict the owner may simply allow. Conflict **C8** |

---

# 4. `3tk-polyhelper.md`

Code-level. The shape is close to Part 7.2. The spelling is unverified
throughout and the file contradicts itself once.

| # | Claim | Verdict | Conflicts with | Recommendation |
|---|---|---|---|---|
| H1 | Helper contents: `is_it`, `from_poly`, `must_from_poly`, `to_poly`, `from_slot`, `must_from_slot`, `move_from_slot`, `init`, `create`, `destroy` | HOLDS | Part 7.2 MUST — every one of the seven required members is present, plus the two of Part 7.3 | The best structural match in the drafts. Check it against Part 7.2 item by item when implementing |
| H2 | `typedef Slot = ItemHandle?` — an optional handle | CONFLICT-D, CONFLICT-S | Contradicted **later in the same file**, which says Slot is `ItemHandle*`. Against Part 9.1, the first form is nearer right: a Slot is the two-state container itself | The file states both. Conflict **C4** again, now internal to one draft |
| H3 | `@fieldParentPtr` becomes a simple cast because the node is the first field | CONFLICT-D | `3tk-design-notes.md` and `3tk-porting-notes.md` both specify `inline AnyNode` embedding, and porting-notes says explicitly: *do not* replace inline embedding with a first-field requirement unless C3 forces it | Conflict **C2**. Part 4.3 permits either. The two are not compatible in one codebase |
| H4 | `const TAG = Type::typeid` | UNVERIFIED | — | Whether a `typeid` is a compile-time constant usable this way is exactly Part 21 Q2. 3TK-4 |
| H5 | `macro PolyHelper(Type) { ... fn ... }` — a macro whose body declares functions, instantiated by `def MboxHelper = PolyHelper(Mbox)` | UNVERIFIED | — | This is the load-bearing mechanism of the whole file and it is the least verified thing in it. Part 21 Q1. 3TK-4, first |
| H6 | `fn Type*? from_poly(...)` returning null on mismatch; `must_from_poly` with `@require` | HOLDS | Part 6.3 MUST — the checking form and the asserting form, named apart | The naming does distinguish them at the call site, as Part 6.3 requires |
| H7 | `move_from_slot`: check type, assert not linked, clear the Slot, return the pointer | HOLDS | Part 7.2, the **moving** crossing: on a match return and clear; on a mismatch return nothing and leave the Slot untouched. The code does both | Correct in every detail, including the mismatch path |
| H8 | `create(Allocator, slot)` with `@require(*slot == null)`, filling the Slot rather than returning | HOLDS | Part 9.8 SHOULD — a create fills a Slot. Part 9.2 rule 3 — asserts empty on entry | |
| H9 | `destroy(Allocator allocator, slot)` — the allocator is a **parameter** of release | CONFLICT-S | Part 13.1 SHOULD — *no release call takes an allocator as a parameter*. Part 13.2 gives the reason. Part 13.3: removing this parameter is named as the specific thing a conforming port does | Part 13.4 leaves *application items* open, and this helper is for application items. So it is a live decision, not a settled error. Conflict **C7**, and Part 20 decision 2 |
| H10 | `destroy` returns early on an empty Slot | HOLDS | Part 9.2 rule 6 — a release is a no-op on an empty Slot | |
| H11 | `init` writes `prev`, `next`, `type` | HOLDS | Part 7.2, Part 5.4, Part 5.5 | |
| H12 | Opt out of create/destroy with `$if !Type.has_tag("no_create_destroy")` | CONFLICT-D, UNVERIFIED | `3tk-porting-notes.md` names this construct and says: *do not depend on speculative syntax such as an unverified `Type.has_tag(...)`* | Porting-notes is right. Part 7.3 requires the *distinction* to be real, by any means; it does not license an invented one. The file itself hedges in its last paragraph |
| H13 | `AnyNode.is_linked()` returns true if either neighbour is non-null | HOLDS, GAP | Part 8.7 MUST — correct, **and** it is not a membership test. An item alone on a list reports false | The blind spot must be written down where the function is. Part 20 decision 4 asks whether to accept it or pay a field |
| H14 | `AnyNode.reset()` clears both links | HOLDS | Part 8.8 MUST — the repair | |
| H15 | Usage example: `Mbox` gets a helper, and opts out of create/destroy | HOLDS | Part 7.3 — "A type that allocates itself... gets a helper without them". Part 11.1 — the mailbox is still an item and still needs the rest of the helper | |
| H16 | Mapping table: `tag: *const anyopaque` → `type: typeid` | HOLDS | Part 5.3, `audit 3` row 3 | Subject to conflict **C1** |

**Not covered anywhere in the file, and required.** Part 7.4 — the generator
rejects a type with no inner field, or an inner of the wrong type, and the
message names the offending type. `3tk-design-notes.md` D9 raises it; the code
draft does not implement it.

---

# 5. `3tk-additions.md`

Four unrelated notes in one file. They should be split.

## 5.1 The `PoolHooks` interface note

| # | Claim | Verdict | Conflicts with | Recommendation |
|---|---|---|---|---|
| A1 | Use a C3 `interface` for `PoolHooks`, not a struct of function pointers | HOLDS, UNVERIFIED | Part 12.1 MUST — "The port spells them in the language's own interface mechanism". Part 21 Q5 | Aligned with the specification and against `3tk-design-notes.md` D16. Conflict **C5**, and the specification already leans this way |
| A2 | `ctx` disappears; the implementing object is the context | HOLDS | Part 12.1 — the ztk `ctx` exists *because* Zig has no interface keyword | |
| A3 | The proposed interface is `void on_get(AnyHandle item)` | CONFLICT-S | Part 12.2 MUST — on get, the pool **asks for an item of a named identity**, the Slot is **empty on entry**, and the hook creates one or leaves it empty. The signature has it the wrong way round: it hands the hook an item it is supposed to produce | The signature also drops the identity parameter, and with it Part 11.7's per-identity grouping. Two MUSTs |
| A4 | `AnyHandle on_put(AnyHandle item)` | CONFLICT-S | Part 12.2 — put has **four** outcomes, and Part 12.5 the extra list of parts. A single returned handle cannot express "released with nothing kept" apart from "kept as it is", and cannot carry the list at all | The extra list is the composite mechanism. Part 12.5: removing it means a composite item cannot give its parts back in one call |
| A5 | `void on_close()` | CONFLICT-S | Part 12.2 MUST — close is called **once, with the full list of what remained**, and the hook is responsible for every item in it. Part 11.8 — the pool's close gives nothing back to the caller, so if the hook does not receive the list, the items are lost | Three MUSTs across A3, A4, A5. The interface *mechanism* is right and the three *signatures* are all wrong |
| A6 | `tags` may just be fields of the implementing type; if the pool needs them generically, define how | CONFLICT-S | Part 11.7 MUST — the set of identities is **fixed at creation and is not empty**, and the pool keeps one free list and one count per identity. `tags` is that set. The pool does need it, generically, and always | The draft's own hedge is the right instinct. The answer is that `tags` belongs to the pool's creation parameters, not to the hook object |
| A7 | Interfaces give dynamic dispatch without a hand-built vtable | UNVERIFIED | Part 21 Q5 | 3TK-4 |
| A8 | Data is type-erased by `AnyNode`, behaviour by the interface | HOLDS | A good framing. Part 6 versus Part 12 | Keep the sentence |
| A9 | `any` is a reserved keyword, so a type named `Any` should not be in the design | UNVERIFIED, CONFLICT-D | `3tk-design-notes.md` D2 uses `Any`; `3tk-porting-notes.md` says case-sensitivity may permit it | Conflict **C3**. 3TK-4 |

## 5.2 The method-call note

| # | Claim | Verdict | Conflicts with | Recommendation |
|---|---|---|---|---|
| A10 | `fn void Something.doSomething(Something* self)` is callable as `s.doSomething()` and as `Something.doSomething(s)`; a value receiver is auto-addressed | UNVERIFIED | — | Pure C3 mechanics. No specification bearing. 3TK-4, cheaply |

## 5.3 The Slot / double-pointer note

| # | Claim | Verdict | Conflicts with | Recommendation |
|---|---|---|---|---|
| A11 | Zig `*?*T`, Odin `^Maybe(^T)`, C3 `T**` — because C3 pointers are already nullable | HOLDS | Part 9.9 MAY — "Any two-state container works: a nullable pointer, a tagged union, a struct with a flag". Part 21 Q9 | The cross-language comparison is sound and is worth keeping for the otk and dtk lines |
| A12 | C3's `~` optional is a heavy result/fault structure, wrong for a nullable pointer | UNVERIFIED | — | 3TK-4 |
| A13 | Therefore the Slot **is** the double pointer | CONFLICT-S | Part 9.1 — the Slot is the nullable handle. The double pointer is the *signature shape* of Part 9.3 | Conflict **C4**, third occurrence. The representation the drafts propose is right; only the word "Slot" is attached to the wrong half of it |
| A14 | Contracts (`@require`) could restore Zig's non-null guarantee | HOLDS | Part 9.9 — a port may make the Slot distinct or opaque and catch misuse at compile time. Part 20 decision 1 | An argument *for* the distinct-type option, in a note that otherwise argues for the transparent one |

## 5.4 The typed-handle note

| # | Claim | Verdict | Conflicts with | Recommendation |
|---|---|---|---|---|
| A15 | A distinct `typedef MboxHandle = AnyNode*` does not implicitly convert, so `&mbh` is not an `AnyNode**` and needs a cast | UNVERIFIED | — | 3TK-4 |
| A16 | Therefore pass `(AnyNode**)&mbh`, or go through a temporary | CONFLICT-S in effect | Part 7.5 MUST — application code never performs the crossing by hand; **every** crossing goes through the helper, so the arithmetic appears in one file. A cast at every Slot call site is the opposite | The cost this note discovers is an argument against typed handles, and the note does not draw it. See conflict **C10** |
| A17 | `inline` on the typedef makes the single conversion implicit but not the double one | UNVERIFIED | — | 3TK-4 |

---

# 6. `3tk-porting-notes.md`

The latest and the most careful. Only rows that add to, or differ from,
`3tk-design-notes.md` are listed; D-rows it repeats carry the same verdict.

| # | Claim | Verdict | Conflicts with | Recommendation |
|---|---|---|---|---|
| N1 | Same naming table as D1, plus "C3 is case-sensitive, so `Any` may be usable — verify" | UNVERIFIED, CONFLICT-D | `3tk-additions.md` A9 states flatly that it is not | Conflict **C3** |
| N2 | `AnyNode` holds `next`, `prev`, `typeid`; `any` is not a replacement for `AnyNode` | HOLDS | Part 4.2. The second half matters: a language `any` carries a type and a pointer, but not the **links**, and Part 4.1 needs the links in the item | Correct and worth stating |
| N3 | `inline` embedding is the intended design; do not downgrade it to a first-field rule unless C3 forces it | CONFLICT-D, UNVERIFIED | `3tk-polyhelper.md` H3 assumes offset zero and a plain cast | Conflict **C2**. Part 4.3 permits either, and names the cost of the offset-zero form: "loses nothing except freedom of layout" |
| N4 | Typed handles `MboxHandle` / `PoolHandle` for static API separation, not for representation | GAP | The specification neither requires nor forbids them. But Part 11.1 makes both containers ordinary items, and Part 7.5 requires every crossing to run through the helper | Weigh against `3tk-additions.md` A16, which finds the cast cost. Conflict **C10**. A Part 20-style decision the port must add to its own list |
| N5 | A Slot is not another runtime wrapper; it describes the *use* of an `AnyHandle` through `AnyHandle*` | CONFLICT-S | Part 9.1 | Conflict **C4**, fourth occurrence. This is the clearest statement of the mistake and therefore the best place to fix it |
| N6 | Slot operations: `fromSlot`, `mustFromSlot`, `moveFromSlot`, `create`, `destroy`; a move validates, obtains, verifies invariants, clears, returns | HOLDS | Part 7.2, Part 9.2 rules 4 and 5 | The five-step move matches the specification step for step |
| N7 | The `AnyHelper` conceptual API: `is`, `fromAny`, `mustFromAny`, `toAny`, `fromSlot`, `mustFromSlot`, `moveFromSlot`, `init`, `create`, `destroy` | HOLDS | Part 7.2 plus Part 7.3, complete | |
| N8 | A type mismatch is an invariant failure, not a Pool or Mbox outcome | HOLDS | Part 15.5, Part 19 — no outcome set contains a type error. Part 6.3, the asserting form | Sharp and correct. The distinction the specification draws in Part 15.5, arrived at independently |
| N9 | Do not design the Any infrastructure around large `typeid` switches | HOLDS | Part 6.5 SHOULD — one handler per pair of receiver and identity, a table keyed on the identity, and a branch is permitted where the language allows it. `audit` line 473: a switch over tags does not compile in Zig, on any backend | Agrees. Note that Part 6.5 makes the dispatch *table* a SHOULD, which this draft does not mention at all — see the gap below |
| N10 | `AnyList` first, before `AnyHelper` | CONFLICT-S | Part 22 | Conflict **C8**, same as D20 |
| N11 | `AnyList` operations: empty, first, last, push, append, insert, remove, pop, iteration, reset | GAP | Part 8.2 — still missing *add from a Slot* at both ends, and *how many*. Part 8.6 the double check, Part 8.9 the self-move refusal | Better than D12, still short. Conflict **C6** |
| N12 | List invariants: no double insert, removal clears links, boundaries valid, moves preserve invariants | HOLDS | Part 8.6, Part 8.8. Invariant 17 | The double-insert invariant is named without the *two* checks Part 8.6 requires, and the reason neither alone suffices |
| N13 | `Pool` is not an ordinary application item and has its own lifetime; this affects create/destroy | HOLDS | Part 7.3, Part 11.12 | |
| N14 | The create/destroy opt-out must be real; three candidate designs offered; do not depend on `has_tag` | HOLDS | Part 7.3 — "The distinction is real and portable. A port makes it by any means its language offers: two generators, an interface, a flag, a separate name" | The three candidates are three of the four the specification names. Directly contradicts `3tk-polyhelper.md` H12, and is right to |
| N15 | `PoolHooks` as an interface is possible but not final; compare against simplicity, allocation, lifetime, absence, dispatch, tags, existing semantics | HOLDS | Part 12.1 leans to the interface. Nothing forbids the comparison | The comparison list is missing the two conditions the specification makes MUST: hooks run **outside the mutex** and in **parallel** (Part 12.3), and hooks are a parameter of **creation** (Part 12.1). Add both to the list |
| N16 | Allocation stays explicit; no hidden global; construction controlled by the owning component | HOLDS | Part 13.1 | Same omission as D18 — silent on the release parameter. Conflict **C7** |
| N17 | Distinguish operational outcomes (closed, timeout, canceled, not_created) from invariant failures | HOLDS, GAP | Part 15.5, Part 19 | Same missing outcome as D17: **not-available**, and the Part 19.3 divergence |
| N18 | No `std.Io`, no invented 3tk Io layer | HOLDS | Part 16 | |
| N19 | Public structs with private state; typed handles are a separate concern from information hiding; do not mix the two reasons | HOLDS | Part 11.11, Part 21 Q4 | The separation is clean and the specification does not make it this explicitly. Worth carrying back |
| N20 | Do not impose an artificial "imports first" rule | OUT | — | 3TK-4 or a style decision |
| N21 | Order: verify C3 assumptions → `AnyNode`/`AnyHandle` → `AnyList` → prototype `AnyHelper` → decide create/destroy → Mbox → Pool → hooks → synchronization → results | CONFLICT-S | Part 22, steps 2 to 7. The helper is step 3 and the list step 5; this draft swaps them. Step 1, verify first, matches Part 22 step 1 and Part 21 exactly | Conflict **C8** |
| N22 | The verification rule: confirmed architecture versus what needs a compilable prototype, with both lists written out | HOLDS | Part 21 is that rule, formalized | The single best contribution of the seven drafts. Its "requires a prototype" list is a ready-made agenda for 3TK-4 |
| N23 | The confirmed list includes "Slot uses `AnyHandle*`" | CONFLICT-S | Part 9.1 | Conflict **C4**. Note that this places the error in the *confirmed* column, where it is hardest to dislodge |

**Not covered.** These parts of the specification appear in no draft at all —
see section 8.

---

# 7. `3tk-build-dist.md`

Packaging. Outside the specification's subject except in its framing
paragraphs, which describe the toolkit and get two things wrong.

| # | Claim | Verdict | Conflicts with | Recommendation |
|---|---|---|---|---|
| B1 | C3 modules, `project.json`, `.c3l` as the distribution unit | OUT, UNVERIFIED | — | 3TK-4, or a separate tooling stage |
| B2 | Library packaging is early alpha; `c3c dist` incomplete; no real registry | OUT, UNVERIFIED | — | If true, it shapes 3TK-5's delivery plan. Worth confirming |
| B3 | The toolkit's building blocks, layered: PolyNode + ItemHandle + Slot → Mailbox → Pool → **higher-level patterns (Master, Select, Group, Future, pipelines, shutdown)** | CONFLICT-S | Part 1.3 MUST, no `Master`. Part 1.2 MUST, "no task, no future, no event loop". Part 16 rows 3, 5, 9, 10 — the future-returning calls and the two result unions are **excluded surface** | The fourth layer does not exist in the toolkit. Part 17: one required tool and two optional ones, and that is all. Same error as `3tk-poc.md` P1 |
| B4 | Zig packaging: `build.zig` + `build.zig.zon`, name `matryoshka`, version 0.0.1, minimum Zig 0.16, root `src/matryoshka.zig`, static library plus module | HOLDS as far as the audit goes | — | The audit confirms Zig 0.16 and the `std.Io` dependency that comes with it. The version and file names are not audited. Low risk |
| B5 | ~720–750 lines of code | UNVERIFIED | — | Not a figure the audit gives. `polynode.zig` alone spans to line 603. Do not quote it |
| B6 | Ship source-only `.c3l`, prebuilt libraries later | OUT | — | Reasonable, given B2 |
| B7 | Suggested layout `src/{matryoshka,polynode,mailbox,pool,polyhelper}.c3` | OUT | — | Mirrors ztk's file split. Part 17.3 suggests the layering, not the file names. Note that it uses `polynode`/`polyhelper`, the **ztk** names, while every other draft has renamed them to `Any*`. Minor conflict **C11** |
| B8 | `project.json` with `"type": "test"` targets, `test-sources`, debug and release targets, `c3c test` | UNVERIFIED | — | 3TK-4 Q11 touches the build-mode half of this. Part 15.5 and Part 8.6 both depend on a checking build existing |
| B9 | Two different `project.json` shapes, one here and one in `3tk-poc.md` | CONFLICT-D | `3tk-poc.md` P14 | Conflict **C9**. Neither is authoritative. Both predate any compilation |
| B10 | `import matryoshka; // then use PolyNode / Mailbox / Pool exactly as in the Zig design` | CONFLICT-S | Part 5.3, Part 8.2 — the spelling is the port's, and every other draft has renamed these | "Exactly as in the Zig design" is the transpiling instinct the status file's rules forbid |

---

# 8. What no draft covers

Present in the specification, absent from all seven drafts. Not conflicts —
holes. Listed because 3TK-5 must fill them and nothing before it will.

| Spec | Subject | Marking |
|---|---|---|
| Part 2.4 | A wakeup carries no meaning; re-check the state | MUST, invariant 3 |
| Part 2.5 | The deadline is anchored once, before the loop | MUST, invariant 4. Only `3tk-poc.md` touches the code path, and gets it wrong |
| Part 2.6 | A leaver signals if the container is not empty — signal hand-off on a lost race | MUST, invariant 5 |
| Part 2.8 | Order among receivers is not defined | MUST |
| Part 2.9, 2.10 | Interruption, and cleanup paths running to the end | SHOULD. Part 20 decision 8 |
| Part 3.1, 3.2 | Participants are long-lived heap objects at a fixed address | MUST, invariant 6. Only `3tk-poc.md` P13 gestures at it |
| Part 6.5 | Dispatch on the identity — the handler table, and a miss leaving the item in its Slot | SHOULD |
| Part 8.6 | The double check on insert, and why neither check alone is enough | SHOULD, and it is the reason the list layer exists |
| Part 8.9 | Refusing to move a list onto itself, twice — assert and early return | SHOULD |
| Part 9.2 | The six Slot rules, as six | MUST, invariant 18. Drafts use the idiom; none enumerates the rules |
| Part 9.7 | Cleanup registered **before** acquisition | SHOULD. Part 21 Q6 |
| Part 11.3 | Out-of-band ordering, and the O(1) anchor at the last out-of-band item | MUST, invariant 22 |
| Part 11.5 | Waking every waiter, and the counter mechanism | SHOULD |
| Part 11.6 | The give-back rule, mailbox side, and the named mistake of discarding a close's list | MUST, invariant 23 |
| Part 11.8 | The give-back rule, pool side; a list put stops at the first refusal | MUST, invariant 24 |
| Part 11.9 | The waiting get never creates | MUST, invariant 25 |
| Part 11.12 | Close before release, unconditional, in every build mode | MUST, invariant 26 |
| Part 12.3 | Hooks run outside the mutex, in parallel, and do not call back | MUST, invariant 28 |
| Part 12.4 | The in-pool count is a hint | MUST, invariant 29 |
| Part 14.2 | The transfer orders memory | MUST, invariant 31 |
| Part 15.1, 15.2 | One mutex per container; no lock held across a call into application code | MUST, invariants 32 and 33 |
| Part 15.4 | The atomic pre-lock fast path | SHOULD. Part 20 decision 9, Part 21 Q10 |

Twelve of the thirty-three invariants of Part 18 appear in no draft.

---

# 9. The conflict register

The eleven conflicts the owner rules on. Each names the drafts on both sides
and what the specification says, where it says anything.

### C1 — Does `typeid` satisfy Part 5.1?

- **For:** `3tk-design-notes.md` D4, `3tk-porting-notes.md` N2,
  `3tk-polyhelper.md` H4, H16. All four assume yes.
- **Against:** `ztk-to-3tk.md` Z9 flags it as the dangerous area, precisely
  because the ztk tag is a unique opaque identity, not "some runtime type
  number".
- **Specification:** Part 5.1 MUST, five clauses. Part 5.3 permits a native
  identifier. Part 21 Q2 asks the question.
- **Note:** four drafts assume it and none checks it. This is the single
  highest-leverage question in 3TK-4, because Parts 5, 6, 7 and 11.7 all rest
  on it.

### C2 — `inline AnyNode`, or `AnyNode` as the first field?

- **Inline:** `3tk-design-notes.md` D5, `3tk-porting-notes.md` N3, the latter
  explicitly forbidding the downgrade.
- **First field, plain cast:** `3tk-polyhelper.md` H3, and every code sample in
  it. `3tk-poc.md` P11 assumes it too.
- **Specification:** Part 4.3 SHOULD permits both. Offset-zero "loses nothing
  except freedom of layout". Part 21 Q3.
- **Note:** the two cannot coexist. Every helper in `3tk-polyhelper.md` is
  written for the offset-zero form.

### C3 — Is `Any` usable as a type name?

- **Yes:** `3tk-design-notes.md` D2. **Maybe:** `3tk-porting-notes.md` N1.
  **No:** `3tk-additions.md` A9.
- **Specification:** silent. Part 5.3 and Part 8.2 leave names to the port.
  Part 10.1 gives the specification's own four words.
- **Note:** decidable in one minute in 3TK-4. It affects only prose, since no
  draft actually declares a type named `Any`.

### C4 — What is the Slot?

- **The double pointer is the Slot:** `3tk-design-notes.md` D7,
  `3tk-additions.md` A13, `3tk-porting-notes.md` N5 and N23 — the last of which
  puts it in its *confirmed* column.
- **The optional handle is the Slot:** `3tk-polyhelper.md` H2, first block,
  before the same file reverses itself.
- **Specification:** Part 9.1 MUST — a Slot is a container of one handle, or of
  nothing. Part 9.3 MUST — an operation that acquires takes a **pointer to a
  Slot**. So `AnyHandle` is the Slot and `AnyHandle*` is the parameter.
- **Note:** the drafts' *representation* is right and their *word* is wrong.
  Left as is, Part 9.2's six rules become unstateable, because five of them are
  rules about the Slot and there would be no name for the thing they govern.

### C5 — `PoolHooks`: interface, or struct of function pointers?

- **Interface:** `3tk-additions.md` A1, A2. **Struct with `ctx` and `tags`:**
  `3tk-design-notes.md` D16. **Undecided:** `3tk-porting-notes.md` N15.
- **Specification:** Part 12.1 MUST — the port spells them in the language's
  own interface mechanism; the ztk struct exists only because Zig has no
  interface keyword. Part 21 Q5.
- **Note:** the specification leans hard to the interface. But the three
  signatures `3tk-additions.md` proposes are each wrong against Part 12.2 —
  rows A3, A4, A5 — and `tags` cannot simply move into the hook object, row A6.
  Ruling for the interface does not settle the shape of it.

### C6 — The `AnyList` surface

- `3tk-design-notes.md` D12 and `3tk-porting-notes.md` N11 give two different
  incomplete lists.
- **Specification:** Part 8.2 gives the full surface. Part 8.6, 8.8, 8.9 give
  the three behaviours neither draft lists.
- **Note:** not really a conflict between drafts. Both are simply short of
  Part 8.2, and in different places.

### C7 — Does a release call take an allocator?

- **Yes, as a parameter:** `3tk-polyhelper.md` H9, in code.
- **Silent:** `3tk-design-notes.md` D18, `3tk-porting-notes.md` N16. Both state
  the general allocator principle and neither addresses the release parameter.
- **Specification:** Part 13.1 SHOULD — no release call takes an allocator as a
  parameter. Part 13.3 names removing it as the thing a conforming port does.
  Part 13.4 leaves the application-item half **open**, and Part 20 decision 2
  lists it.
- **Note:** genuinely open by the specification's own words. It is also the
  first open question on the `3tk-status.md` list. The two must be answered
  together.

### C8 — Where does the list go in the order?

- **List first:** `3tk-design-notes.md` D20, `3tk-porting-notes.md` N21.
- **Specification:** Part 22 — inner and identity, helper, Slot, list, mailbox,
  pool. The list is step 5.
- **Note:** Part 22 says of itself "Not conformance. A suggestion." The drafts'
  reason is that Mbox and Pool both depend on the list. The specification's
  reason is that the list *speaks in handles* (Part 8.3) and its inserts take
  Slots (Part 8.2), so it depends on the helper and the Slot. Both reasons are
  true. The owner picks.

### C9 — Two `project.json` shapes

- `3tk-poc.md` P14 versus `3tk-build-dist.md` B8.
- **Specification:** silent, and rightly.
- **Note:** neither has been compiled. Defer wholesale to 3TK-4 or a tooling
  stage.

### C10 — Typed handles `MboxHandle` and `PoolHandle`

- **For:** `3tk-porting-notes.md` N4, for static API separation.
- **The cost, found but not weighed:** `3tk-additions.md` A15, A16 — a distinct
  typedef does not convert, so every Slot-shaped call needs an explicit
  `(AnyNode**)` cast at the call site.
- **Specification:** Part 7.5 MUST — application code never performs the
  crossing by hand, and every crossing goes through the helper, so the
  arithmetic appears in one file. Part 11.1 — both containers are ordinary
  items with ordinary crossings.
- **Note:** the two notes are in the same author's family of drafts and do not
  cite each other. A16 is an argument against N4 and is not presented as one.

### C11 — `polynode`/`polyhelper` or `AnyNode`/`AnyHelper`?

- `3tk-build-dist.md` B7 and B10 keep the ztk file and type names. Every other
  draft renames.
- **Note:** minor, and almost certainly an artefact of B7 being written before
  the renaming discussion.

---

# 10. What to carry forward

Independent of every ruling above.

**Into 3TK-4, as its agenda.** The "requires a compilable C3 prototype" list of
`3tk-porting-notes.md` N22 maps almost one to one onto Part 21's twelve
questions. Add to it, in this order:

1. C1 — `typeid` against all five clauses of Part 5.1. Q2.
2. H5 — whether a macro can generate the per-type helper at all. Q1.
3. C2 — `inline` embedding and inner-to-outer arithmetic. Q3.
4. Q7 — a condition variable with a **timed** wait. Nothing in any draft
   mentions whether C3 has one. ztk paid 71 lines for its absence, and Part 16
   row 7 says a language that has one deletes them.
5. Q11 — build modes and compiled-out asserts, which Part 8.6 and Part 15.5
   both need.
6. C3 and A10 — the two cheap ones.

**Into 3TK-5.** Section 8, the twenty-two uncovered parts. Twelve of the
thirty-three invariants have never been discussed in this folder.

**Retire.** `3tk-poc.md` and `ztk-to-3tk.md`, as superseded — kept on disk,
marked in `3tk-status.md`.

**Keep whole.** `3tk-porting-notes.md` N22, the verification rule, and N8, the
outcome-versus-invariant distinction. Both were arrived at independently of the
specification and both agree with it.

---

## Change log

| Version | Date | Description |
|---|---|---|
| 001 | 2026-08-23 | First version. Stage 3TK-3. |
