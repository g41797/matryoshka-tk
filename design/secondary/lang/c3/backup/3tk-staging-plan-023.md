# 3tk — staging plan 023

Written 2026-09-04.

**Provenance.** Follows [3tk-staging-plan-022.md](backup/3tk-staging-plan-022.md).
022 declared one stage, **3TK-58**, and it has since run and closed
(2026-09-03, `Mailbox`/`Pool` opaque handles). **022 is fully spent.** This
plan declares one stage: **3TK-59.**

State is in [3tk-status.md](3tk-status.md). Narrative is in
[3tk-log.md](3tk-log.md). Neither is duplicated here.

---

## Why this plan exists

**The owner read the `Slot` / `Handle` / `Inner*` model and objected that it is
hard for an ordinary developer**, and that `Handle` is an `alias`, not a
`typedef`. The objection is correct, and it is structural rather than cosmetic.

**The ruling, stated as a rule and not as a judgement about one name:**

> **A concept gets a C3 type when the type system can express useful semantics
> for it. Otherwise it stays vocabulary.**
>
> In 3tk, *handle* is a useful concept. `Handle` is not a useful C3 type.
> `Slot` is.

The rule reads on both names without appeal to taste.

- **`Slot` is a `typedef`** — a distinct type whose semantics the compiler and
  the checks enforce. It is empty or full; `fill` requires empty; `fill`
  refuses null; `take` empties it. **It earns a type name.**
- **`Handle` is an `alias` — it is not a type.** The compiler sees `Inner*`. It
  does not refuse assignment from any other `Inner*`, does not refuse null,
  does not detect a stale pointer, and says nothing about who must free the
  outer. It buys vocabulary only, and vocabulary does not need to be a C3
  identifier.

*(Secondary, and not load-bearing: "handle" also tends to suggest indirection
or validation that 3tk does not perform — a stale `Handle` is a dangling
pointer exactly like a stale `Inner*`. This cuts the owner's way on the
ordinary-developer question, but the rule above is what decides the stage.)*

**The alias also costs three visible things, measured on the tree.**

1. **A mismatch the reader must be told about.** A method cannot attach to a
   pointer alias in c3c 0.8.3, so the crossings are declared on the struct:
   `macro Inner.to(&self, $Type)`. A reader sees `Handle h`, then `h.to(Msg)`,
   and needs an explanation — and **`test/t_identity.c3:164` already contains
   that explanation as a comment in the source.** The tree documents the
   confusion the alias causes.
2. **An incoherent signature.** `fn void Inner.repoint_to(&self, Handle to)`
   spells one type two ways in one line.
3. **A third noun in the teaching sequence**, for a concept that turns out,
   when counted, to be almost entirely one code shape.

**Intended outcome:** the developer's vocabulary is two real types — **embed an
`Inner`, hold a `Slot`** — and *handle* survives as an English word in the
prose, where a role can live without the type system having to carry it.

## The measurement this rests on

`grep -w Handle` over `3tk/`, measured 2026-09-04. **133 occurrences.**

| where | count | note |
|---|---|---|
| `src/` | 56 | of which **26 are inside doc comments**; 30 real code sites |
| `test/` | 30 | |
| `examples/` | 42 | |
| `negative/` | 5 | |

**The shape that matters.** Of the ~77 occurrences outside `src/`, roughly 45
are one single line, the walk over a queue —

```c3
while (Handle h = q.pop_front())      // or it.next()
```

— and about a dozen more are `Handle h = <a call that returns one>;`. Only a
handful are anything else: `touch_by_switch(Handle h)` in
`examples/019-dispatch_switch.c3`, `guarded_walk(..., Handle h)` in
`examples/060-guarding_an_expensive_check.c3`, and the `(Handle)&m.node` casts
in `test/t_identity.c3`.

Against that: **51 mentions in `3tk-reference-006.md`, 22 in
`3tk-patterns-002.md`.**

**The two counts argue for the split directly.** The 45 walk declarations do
not demonstrate an abstraction; they demonstrate a convenient *spelling* for
`Inner*`. The 73 documentation mentions do demonstrate that the *word* carries
architectural weight. The word is load-bearing; the alias is not.

```text
C3 source:        Inner*
Documentation:    handle
```

**The measurement is supporting evidence. The rule above is the argument.**

## What was rejected, and why

**Deleting the word as well.** Ruled out by a rule that already holds across
every stage — **"Porting is not transpiling. The specification says what to
preserve; each port decides how to spell it."** The specification describes the
*role*; each port spells it as its type system allows.

```text
ztk (Zig)    Handle / ItemHandle
dtk (D)      Handle, if D can give it semantics
3tk (C3)     Inner*
```

That is not a divergence to be reconciled; it is what the rule provides for.
`kitchen/docs/addendums/handle-based-programming.md` describes the role and
stays as it is. **The shared terminology is not changed to accommodate one
language.**

**`typedef Handle = Inner*`.** Making it a real type looks as though it would
repair the mismatch, and it would let the crossings become `Handle.to`. But a
distinct type is worth its price only when it expresses semantics, and this one
would express none. It would add a third abstraction for the developer to
learn, which is the direction the owner objected to. The honest representation
is preferred.

**Touching `Slot`.** Nothing here proposes making `Slot` opaque. That was
3TK-58's change to `Mailbox` and `Pool`, and it does not extend to `Slot`.
`Slot` stays `typedef Slot = Inner*`, with every method and every check it has
today.

## The stage

```
3TK-59   remove the Handle alias      3tk/src/, test/, examples/, negative/,
                                      ref/3tk-decisions-005.md,
                                      matryoshka-3tk 3tk-reference-007.md
                                      and 3tk-patterns-003.md
```

## 3TK-59 — remove the `Handle` alias, keep the word in prose

**Ruled by the owner, 2026-09-04: Opus runs the whole stage**, steps 1 through
6, not only the prose half. Steps 1 and 2 are mechanical and the compiler
checks them, but steps 3, 4 and 4b rewrite 73 sites of published prose plus a
decisions entry, and `check-doc-loop.sh` verifies only that sentences *match* —
it cannot say whether the replacement text is flat or off-voice. **Do not
switch models part-way through.**

### Named inputs

A session running this stage cold reads these and needs nothing else.

- This file, and [3tk-status.md](3tk-status.md).
- `3tk/src/inner.c3`, `helper.c3`, `queue.c3`, `stack.c3`, `mailbox.c3`,
  `pool.c3`.
- `matryoshka-3tk/design/3tk-reference-006.md`, Part 3.
- `matryoshka-3tk/design/3tk-patterns-002.md`, entries 1–16.
- `design/rules-049.md` Part 5, for the banned words.
- **The one site that is evidence, by line:** `test/t_identity.c3:164`.

### 1. `src/`, and the doc comments in the same stage

*(The rule: a change to `3tk/src` revises the reference in the same stage,
never as a debt for the next one.)*

- `src/inner.c3` — delete `alias Handle = Inner*;` and its doc comment. The
  Slot declaration becomes `typedef Slot = Inner*;`.
- **Rewrite the 26 doc-comment lines** across `inner.c3`, `helper.c3`,
  `mailbox.c3`, `pool.c3`. **These are prose and are rewritten, not
  substituted** — "Everything 3tk transports is a `Handle`" has no mechanical
  `Inner*` form. It becomes a sentence about the role, with *handle* as an
  English word.
- The remaining ~30 code sites in `src/` are the mechanical part: `Handle` →
  `Inner*`, `(Handle)` → `(Inner*)`, `(Slot)(Handle)null` →
  `(Slot)(Inner*)null`.
- `queue.c3`, `stack.c3`, `mailbox.c3`, `pool.c3` signatures follow.

### 2. `test/`, `examples/`, `negative/`

~77 sites, most of them the walk over a queue.

- **Delete `test/t_identity.c3:164`'s explanatory comment.** It exists only to
  explain that the alias makes the crossings reachable as methods, and it is
  the clearest single proof this change is right.
- Keep `t_identity.c3`'s `(Inner*)&m.node` casts. They were always about the
  raw pointer.

### 3. `3tk-reference-006.md` → `007`

51 sites, written directly in `matryoshka-3tk/design/`. Part 3's *Participants*
loses a bullet and gains a sentence: the transported thing is an `Inner*`, and
*handle* is what the books call it. **`006` moves to that repo's `backup/` with
a plain `mv`.**

### 4. `3tk-patterns-002.md` → `003`

22 sites, same treatment. Entry 12 (*The `$Type` crossing*) and entry 59 (*The
optional-declaration walk*) carry the most. **`002` to `backup/` with a plain
`mv`.**

### 4b. Record the rule where another port will read it

`ref/3tk-decisions-004.md` → `005`, with one entry carrying the ruling — *a
concept gets a C3 type when the type system can express semantics for it;
otherwise it stays vocabulary* — and `Slot` and `Handle` as the worked pair.
This is what 3TK-20 established the decisions file for, and **dtk will face the
same question**, with D's type system possibly giving a different answer.
`004` to `backup/`.

### 5. Verification

**Nothing behavioural changes — an alias has no semantics — so the builds are
the proof.**

- `./3tk/run-builds.sh` — must be **87 checks, 0 failures, four builds, 140
  tests each**, identical to 3TK-58's measurement. Any difference is a defect
  of this stage, not a finding. Compilation is the check: a site the search
  missed fails to build.
- `./3tk/check-doc-loop.sh` with `REF` pointed at the new
  `3tk-reference-007.md` — expected **0 differing module blocks but the
  pre-existing `managed.c3` one, and 2 pre-existing missing sentences** (a
  `helper.c3` and a `managed.c3` module-summary line). The sentence count will
  move from 466 as prose is rewritten; **what must not move is the number of
  unmatched sentences.** A new differing block means a doc comment was
  rewritten and the reference was not.
- `grep -rw Handle 3tk/` — **zero hits in code.** Hits inside doc comments and
  `.md` prose are expected and correct; that is the design of the change.
- **The banned-word check on everything this stage writes.** Steps 1 through 4b
  rewrite a great deal of prose, which is where a banned word gets in.
  `check-doc-loop.sh` reports the count for the doc comments and must stay at
  **0**; this file and `3tk-decisions-005.md` are read against
  `rules-049.md` Part 5 by hand. **`drain` in particular** —
  `rules-049.md:683` bans it, the shape it names here is a **walk** (catalog
  entries 15 and 59), and it reached a draft of this plan before the owner
  caught it.
- `./3tk/run-sanitizers.sh` is **not** required. No allocation, lifetime or
  concurrency path is touched.

### 6. Close the stage

Append the `3TK-59` entry to [3tk-log.md](3tk-log.md), newest first. Add its
row to this status file's stage table, and update *What is live now*, *The
measured numbers* and *How to start after a clear*. End with the clear-or-
compact advice, measured against how the run actually went.

---

## Rules that hold

- **No stage runs `git`.** Moves in this repo are plain `mv`; the owner saves
  and pushes. The same applies inside `matryoshka-3tk` for design docs.
- **A change to `3tk/src` revises the reference in the same stage.** For this
  stage that is `3tk-reference-007.md` in `matryoshka-3tk`, since that is where
  the live reference lives.
- **`3tk/src`, `test`, `examples` and the scripts are edited only in this
  repo.** Copying them to `matryoshka-3tk` is the owner's step, as with every
  stage since 3TK-50.
- **Porting is not transpiling.** It is the rule that keeps *handle* in the
  shared specification while C3 spells it `Inner*`.

## Versioning

**`3tk-staging-plan-022.md` is superseded by this file** and moves to
`backup/`. `3tk-reference-006.md`, `3tk-patterns-002.md` and
`ref/3tk-decisions-004.md` are superseded as part of this stage's own work, not
before it.

## How to continue after a clear

**This file is what a cold session reads.** The stage is fully declared here;
nothing it needs stays only in a conversation.

```
Read design/secondary/lang/c3/3tk-status.md and 3tk-staging-plan-023.md,
then run 3TK-59.
```

**The advice, given before the stage runs:** steps 1 and 2 are ~110 mechanical
rewrite sites across `src/`, `test/`, `examples/` and `negative/`. That work
wants a fresh context far more than it wants the argument that produced it, and
the argument is now on disk. **Clear before step 1.**

## What this plan leaves to the owner

- **Whether the word *handle* should eventually leave the shared specification
  too.** This plan keeps it, on the porting rule. Changing it is a
  specification stage across four ports, not a 3tk stage.
- **Whether the dropped `the_deadline_is_anchored_once` coverage gap is
  acceptable long-term.** Tracked as the "Tests improvements" TODO in
  [3tk-status.md](3tk-status.md), untouched here.
- **"Managed Outers — re-thinking"** — raised 2026-09-03, not elaborated,
  entirely separate from 3TK-59 and not started by it.
- **3TK-50's remaining step** — eleven steps not yet copied to
  `matryoshka-3tk` and pushed. Independent of this stage.
- **The seven questions plan 018 left and 019 carried**, and everything in
  [3tk-status.md](3tk-status.md)'s *Open questions* — untouched by this stage,
  and not reopened by it.
