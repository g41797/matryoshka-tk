# API 13 — the reference becomes a book

Design note. Second version.

- `-001` was read by the owner and answered in place.
- Every answer is folded into the section it governs.
- Two questions stay open. Both say so.

Stage 13-1 is the restructure. 13-2 and later are sketched at the end.

---

## 0. Two things worth the owner's eye

**Section 5.1 — 475 lines can go for a pointer, at zero risk.**

- Lines 233-707 of the reference already exist near-verbatim under kitchen.
  - `kitchen/docs/api/polynode/manual-definition.md`.
  - `kitchen/docs/api/polyhelper.md`.
- Both are hand-maintained. No generator writes them.
- Both are already in the mkdocs nav.
- So the delete costs nothing and loses nothing.

**Section 9 — Part 6 stays open.**

- The owner rules on it after Parts 1-5 exist.
- Parts 1-5 do not depend on the answer.
- Nothing in this note decides Part 6.

---

## 1. Why

The reference stopped being what it was.

- Then. It was the source.
  - `src/*.zig` doc comments were written from it.
  - Code was created by iteration against it.
- Now. The code is working.
  - The flow reversed: change the API, then update the reference.
- So the reference is no longer a design document.

It should become a book for the user.

- The user reads it to learn Matryoshka.
- The user reads it to use Matryoshka.
- Deep dive is not its job.
  - For that the user goes to `src/`.
  - Or to an example.
  - Or to docs site.

One consequence, stated up front.

- The note at the top of the file is stale.
  - "Function descriptions in this reference serve as the source for `///` Zig
    doc comments in the implementation."
  - That is the old direction. It goes.

---

## 2. What is wrong with the file today

Owner's findings, each confirmed against the version this stage replaced —
`-038`, 2066 lines.

| finding | evidence |
|---------|----------|
| Mixed styles | part staccato, part prose; reads like several authors |
| Wrong order | `ItemHandle` at line 24, `Slot` at line 30 — before Matryoshka is introduced |
| Wrong audience | written from the Matryoshka developer's point of view, not the user's |
| Flat | 22 `##` headings in a row, nothing above them |
| No introduction | what Matryoshka is, and what for, is never stated |
| Missing the foundation | intrusion and type erasure are the basis, and are absent |
| Obsolete lists | `### Types` and `### Functions` list signatures, then repeat each one with its description |
| Too much detail | asserts, edge cases, complexity tables — nobody reads them there |

Size today.

- 2066 lines.
- 22 `##`, 44 `###`, 20 `####`.

---

## 3. The ruling — detail moves into the code

Owner's ruling. Confirmed.

- Edge cases leave the book.
- They become `///` and `//!` comments in `src/*.zig`.
- In human form.
  - A sentence a person reads.
  - Not a spec clause.

Doc comment conventions. Owner's answer to `-001`.

- 13-2 follows the Zig doc comment rules already in force here.
  - Line separation, lists, links.
- The rules come from two places.
  - `matryoshka-zig-0.16-notes-003.md`.
  - The `///` and `//!` style already in `src/*.zig`.
- Part 4 of `rules-046.md` governs. Nothing new is invented for 13-2.

The safety rule.

- Nothing leaves the book before it exists somewhere else.
  - In the code.
  - Or in a kitchen page.
- 13-1 records each displaced item in a carry-over note.
  - `api-13-carryover`, first version. See Section 8.
  - `-001` called this note by a word the owner has since banned.
  - That word is not used in this document.
- 13-2 writes it into the code.
- 13-3 removes it from the book.

So detail is never in neither place.

---

## 4. Naming — the advice asked for

Advice: keep the file name. Bump `-038` to `-039`. Change the `# H1` only.

Reasons.

- Seven design docs link to it.
  - `context.md`, `STATUS.md`, `patterns-027.md`, `matryoshka-concepts-002.md`,
    `matryoshka-zig-0.16-notes-003.md`,  
    `matryoshka-architecture-foundation-4-006.md`,  
    `api-12-real-pointers-005.md`.
- The version suffix is how this repo records change.
  - A rename throws that record away.
- `check_design.sh` gates the links.
  - A rename is churn with no reader benefit.
- The book announces itself in its first line. That is enough.

If a later stage proves it is really a different document, rename then.

---

## 5. What was found on disk

### 5.1 Half a thousand lines are already elsewhere

Lines 233-707 of the reference. 475 lines.

- `### Defining user types — manual step by step` — seven steps.
- `### PolyHelper — all of the above, generated`.
- `### PolyHelper — create and destroy`.

They already exist under kitchen, near-verbatim.

- `kitchen/docs/api/polynode/manual-definition.md` — 272 lines, all seven steps.
- `kitchen/docs/api/polyhelper.md` — 309 lines, generated plus create/destroy.

Both are hand-maintained.

- No generator writes `kitchen/docs/api/**`.
- Checked: no script under `kitchen/tools/` names that path.
- Both are in the mkdocs nav, lines 48 and 50.

So this displacement is a delete plus a pointer. Nothing is lost.

The book drops about 23% on day one, at zero risk.

### 5.2 `src/` already carries real doc comments

| file | `///` lines | `//!` lines | `pub fn` |
|------|-------------|-------------|----------|
| `src/polynode.zig` | 176 | 15 | 7 |
| `src/mailbox.zig` | 132 | 46 | 11 |
| `src/pool.zig` | 131 | 43 | 10 |

Two spot checks, both already in the form wanted.

- `polynode.is_linked` — "True if the node has neighbours. Not a membership
  test. The only member of a list has no neighbours, so this returns false  
  for it."
- `Mbox.send` — states the closed case, the move, and that `error.Closed`
  leaves the slot unchanged.

So 13-2 is gap-filling. Not writing from scratch.

What is missing in the code, and present in the book: the assert lists.

### 5.3 The foundation text exists

- `kitchen/docs/addendums/intrusion-type-erasure.md` — 42 lines.
- Already in the mkdocs nav, line 180.
- It states the two terms and `@fieldParentPtr`.
- It ends with: "This simple mechanism is the basis of Matryoshka."
- The book needs it, expanded into working technique.

### 5.4 The example roots are per module, not per layer

Checked against `kitchen/mkdocs.yml`.

- The site groups examples by module.
  - Nav sections `How to... PolyNode`, `How to... Mailbox`, `How to... Pool`.
  - Each has an overview page.
- `examples/layer1/` through `layer4/` are storage only.
  - The reader never sees a layer number.
  - There is no `layer4` root page.
- `Flow — Master compositions` is the section where the three run together.
  - Overview page `kitchen/docs/examples/flow.md`.

Roots, on the published site.

| module | root |
|--------|------|
| `matryoshka.zig` | `/examples/` |
| `polynode.zig` | `/examples/polynode/` |
| `mailbox.zig` | `/examples/mailbox/` |
| `pool.zig` | `/examples/pool/` |
| all three together | `/examples/flow/` |

Base is `https://g41797.github.io/matryoshka-tk/`.

Section 6.6 says what is done with them.

---

## 6. The book — proposed structure

### 6.1 Every part has the same shape

The reader learns the shape once, then knows it everywhere.

1. **What this is** — high level, short.
2. **Participants** — the types, and the role each one plays.
3. **Usual flow** — the regular usage. First. Before any description.
4. **The API, in named groups** — one named paragraph per group.
5. **Where to go deeper** — `src/`, an example, a kitchen page.

A part may carry its own section.

- It sits between the API groups and "Where to go deeper".
- Only Part 5 uses this. See Section 6.2.

### 6.2 The parts

**Part 1 — Introduction.** New.

- What Matryoshka is.
- What it is for.
- Who it is for.
- What it is not.
  - Plain scope limits. No positioning, no slogan.
- The three tools, one line each. Mailbox and pool both optional.
- What the reader needs before starting.

**Part 2 — Zig, interesting parts.** New. Owner named it.

- The section says why it exists, in its first lines.
  - These are the parts of Zig that Matryoshka is built out of.
  - Not Zig trivia.
- It is short. It is not an academy document.
  - A reader who wants the full teaching treatment goes elsewhere.

Target of the part. Owner's words, in order.

- The reader understands **intrusion** as a technique.
  - `std.DoublyLinkedList` works on Nodes.
  - The links are part of the struct.
  - No wrapper allocation.
- The reader understands **type erasure** as a technique.
  - The list does not know the parent type.
  - `@fieldParentPtr` gets back to the parent.
  - Why the caller must check before casting.
- The reader meets **`Handle`**, called `ParentHandle` here.
  - The reason for it: keep two things apart.
    - The real pointer to the user's struct.
    - The intrusive struct.

What `ParentHandle` is, and is not. Owner's correction to `-001`.

- The mechanism is **part of Zig**.
  - `*Node` plus `@fieldParentPtr`.
  - Zig gives it. This book names it.
- Only the term is ours.
  - No invention is claimed here.
  - Part 2 supplies vocabulary.
- `ItemHandle` is **part of Matryoshka**.
  - It belongs to polynode.
  - So it is introduced in Part 3, not here.
  - Part 3 says it is the analog of `ParentHandle`.
- The analogy is the bridge between the two parts.
  - This is why Part 2 comes first.
  - This is why Part 2 stays short.
  - Its job is to make Part 3 cheap to read.

The specimen. Owner's ruling.

- A `DoublyLinkedList` / `Node` / `ParentHandle` demonstration is added to
  `tests/`.
  - New file. `tests/zig_mechanisms.zig`.
  - Not `examples/` — it demonstrates a Zig mechanism, not a way to use
    Matryoshka.
- The Part 2 snippet is extracted from that test.
  - Not from the stdlib file.
  - A stdlib path moves when the toolchain moves, and no kitchen script builds
    it.
- The test file is permanent.
  - Its header says it exists for the book.
  - Without that line someone deletes it later as a test that asserts nothing
    about Matryoshka.

Removed from Part 2.

- "The one rule — one place, one state" goes.
  - Owner: it reads as advertising, not as documentation.
  - Not relocated to another part. Removed.
- The same register is removed wherever this note governs.
  - Elsewhere it is recorded, not edited. See Section 8.

**Part 3 — polynode.**

- Participants: `PolyNode`, `ItemHandle`, `Slot`, `ItemList`, `PolyHelper`.
- `ItemHandle` and `Slot` are introduced here.
  - After Part 2 has given the reason for a handle.
  - Not on line 24.
- Usual flow: define a type, transport it, recover it.
- Groups.
  - Identity — the tag.
  - Links — `reset`, `is_linked`.
  - Lists — `ItemList`. Short. It is a list.
    - Say what it adds. Do not explain what a list is.
  - Generation — `PolyHelper`, what it saves you.
- Short snippets, from real working code. Section 6.6.

**Part 4 — mailbox.**

- Participants: `Mbox`, `Slot`, `ItemList`, the Io it holds.
- Usual flow: the four steps, already written and approved in FLOW 1-1r.
- Groups.
  - Create and destroy.
  - Send.
  - Receive.
  - Control — close, wake up.
  - Event source — the async face.
- No hooks section. Mailbox has no counterpart. See Part 5.
- Short snippets, from real working code. Section 6.6.

**Part 5 — pool.**

- Participants: `Pool`, `Pool.Hooks`, `Slot`, `ItemList`.
- Usual flow: the five steps, already written and approved in FLOW 1-1r.
- Groups.
  - Create and destroy.
  - Get.
  - Put.
  - Control — close.
  - Event source.
- Then its own section: **Hooks**.
- Then "Where to go deeper".
- Short snippets, from real working code. Section 6.6.

Group naming. Owner's ruling.

- The group is called **Create and destroy**.
- "register hooks" leaves the group name.
- Inside the group, hooks get one or two sentences.
  - What they are. Enough to keep reading.
  - A link down to the Hooks section.

The Hooks section. Owner's ruling.

- It is **not** a sibling of Get and Put.
  - Get and Put are things the user calls.
  - Hooks are things the user implements.
  - Different act, different reader, so not the same list.
- It sits one level up, beside the API-groups section.
- It comes last in the part.
  - The first-pass reader wants orientation only.
  - The hook writer arrives on a second visit.
  - By then Get and Put mean something.
- Pool is allowed to be the longer part.

What the Hooks section carries.

- What each hook is for.
- When each one is called.
- What the user must not do inside one.
- Book level only.
  - Asserts and edge cases are not written here.
  - They go to `src/pool.zig` in 13-2. Section 7.

`kitchen/docs/api/pool/hooks-discipline.md`.

- Untouched in 13-1.
  - It stays in the nav. It stays accurate.
  - 13-1 does not edit kitchen pages.
- The book states the rules in its own voice.
  - It does not defer to that page for them.
  - A reader who must leave the book to learn what not to do inside a hook is a
    reader the book failed.
- The overlap is deliberate, and is reconciled in 13-4. Section 10.

Where the hook writer goes deeper. All four already exist.

- `src/pool.zig`.
- `examples/hooks/CappedPoolHooks.zig`.
- `examples/hooks/AlwaysCreateHooks.zig`.
- `kitchen/docs/api/pool/hooks-discipline.md`.

`examples/layer4/035-cross_layer_pool_hooks_mailbox_flow.zig` is a consumer
example, not a writer's example.

- It shows what hooks do to the items.
- It does not show how to write one.
- So it belongs to the short mention, or to the usual flow.

**Part 6 — Using them together.**

- Today: ten flat `##` sections. They become one part with sections.
- Candidates: tag identity, slot programming, cooperative cleanup, cancel
  model, thread safety, invariants, contract violations, layer dependencies.
- **Open. The owner rules after Parts 1-5 exist.** See Section 9.

**Part 7 — Beyond the toolkit.**

- The `matryoshka` root module.
- Master — and why it is deliberately not part of the API.
- The Io backend.

**Change log.** Stays at the end, as it is now.

### 6.6 Snippets

Owner's ruling. Two halves.

Short snippets in the book come from real working code.

- Extracted from `examples/**/*.zig`, `stories/`, or `tests/`.
- Verbatim, or trimmed by whole lines.
- Nothing is written for the book.
- Each snippet names its source file.
- The gain: every snippet compiles, and a kitchen script already ran it.

No snippets in `src/`.

- Owner: too messy.
- A `///` snippet cannot be compiled.
  - So it rots while the example beside it stays green.
  - The same lines in the book, the example and the doc comment drift three
    ways.
  - `src/` is the one of the three with no way to detect the drift.

Instead, each module head gets links.

- The shape already exists in `src/matryoshka.zig`.
  - `//! Full documentation:`
  - `//! https://g41797.github.io/matryoshka-tk/`
- Each module points at its own examples root. Section 5.4.
- **Every** module also points at `/examples/flow/`.
  - Described as where the three run together.
- Roots only. Never a file path.
  - Files get renamed. One rename is already queued.
  - A root survives it.
- No per-function pointers. No checker needed.

This work belongs to **13-2**, not 13-1.

- 13-1 changes no `src/*.zig`.
- 13-2 already opens those four files for doc comments.
- Recorded in Section 10 so it is not lost.

---

## 7. What leaves the book, and where it goes

| what | where it is now | goes to | when |
|------|-----------------|---------|------|
| Manual step-by-step, seven steps | 233-484 | delete; point at `kitchen/docs/api/polynode/manual-definition.md` | 13-1 |
| PolyHelper generated, create/destroy | 486-707 | delete; point at `kitchen/docs/api/polyhelper.md` | 13-1 |
| Complexity guarantees | 1943-1960 | delete. Not for the user. | 13-1 |
| Bare signature list before the descriptions | `### Types` / `### Functions` in each part | delete the list. Keep one signature, with its description. | 13-1 |
| "The one rule — one place, one state" | Part 2 material | delete. Slogan. | 13-1 |
| Assert lists, per function | throughout | `src/*.zig` `///` comments | 13-2, removed in 13-3 |
| Edge cases written as spec clauses | throughout | `src/*.zig` `///` comments, human form | 13-2, removed in 13-3 |
| Hook tag mismatch is a programming error, asserted in Debug and ReleaseSafe | `kitchen/docs/api/pool/hooks-discipline.md`, and the Hooks section | `src/pool.zig` `///` comment | 13-2 |

Rows marked 13-2 are not deleted in 13-1.

Every row of this table is written into `api-13-carryover`, first version. Section 8.

---

## 8. Deliverables of 13-1

The book.

- The api reference, next version — `-039`.
  - New `# H1`. New structure. Parts 1-7.
  - `-038` removed. Cross-references repointed in the seven design docs.
  - Changelog row `039` added.
  - The stale `>` note at the top goes.
  - The dead pointer at line 1827 fixed.
    - It says "See **Addendums → Io 101**".
    - That section was removed from the file.
    - `kitchen/docs/addendums/io-101.md` still exists. Point there.

The test.

- `tests/zig_mechanisms.zig`. New file.
  - The `DoublyLinkedList` / `Node` / `ParentHandle` demonstration.
  - Its header says it exists for the book.
- This is the one `*.zig` change 13-1 makes.
  - `-001` said 13-1 changes no `*.zig` at all.
  - That line is replaced by this narrow exception.
  - The test's only reader is the book. It is book work.
  - `build_and_test_debug.sh` must pass. Section 11.

The glossary.

- `ParentHandle` gets an entry in `language-of-matryoshka.md`.
- It lands with 13-1, not after it.
  - `check_design.sh` gates glossary conformance.
  - A term used in the book with no entry fails the stage's own gate.

The carry-over note.

- `api-13-carryover`, first version. New design note.
- Two sections.
  - **To the code** — what leaves the book for `src/*.zig`.
    - One row per item: what, where it was, which file it goes to.
    - This is 13-2's input.
    - 13-3 removes from the book only what has landed.
  - **To remove later** — the slogan register outside this stage's scope.
    - One row per hit: file, line, what it says.
    - Candidates: `matryoshka-concepts-002.md`, `patterns-027.md`, `README.md`,
      `src/` doc comments.
    - 13-1 records. It does not edit documents it does not own.
- One file, not two.
  - Same shape. Same life.
  - Written by 13-1, consumed by a later stage, empty when discharged.
- It must be referenced, or it fails the gate.
  - `check_design.sh` flags orphans.
  - `design/context.md` — one line saying what it is.
  - This note — Sections 3, 7 and 10.
  - The plan — the 13-2 entry names it as input.
- When both sections are discharged it is retired.
  - Moved to `design/secondary/`, frozen.
  - `context.md` and `secondary/context.md` updated.
  - Not deleted. The record of what moved, and why, is worth keeping.

The status files.

- `design/context.md` — the reference's line rewritten.
  - It still promises a trailing Addendums/Io 101 section.
  - That section is gone. The line is false today.
- `design/context.md` — new lines for this note and the carry-over note.
- `design/STATUS.md`, `design/STATUS-LOG.md`, plan bumped.

---

## 9. Open — Part 6

Part 6 folds ten flat sections into one part.

- It is the largest judgment call in the stage.
- It is the one most likely to be wrong.

Owner's answer to `-001`: discuss after Parts 1-5 are ready.

- Parts 1-5 get built first. They do not depend on the answer.
- The Part 6 section list is then shown to the owner.
- The body is written after that.
- This note does not decide it.

---

## 10. Later stages

**13-2 — the code takes the detail.**

- Write the displaced items into `src/*.zig` doc comments.
- Human form. A sentence a person reads.
- Input: the "to the code" rows of `api-13-carryover`, first version.
- Follow the Zig doc comment rules. Section 3.
- Add the module-head links. Section 6.6.
  - Four files. `matryoshka.zig`, `polynode.zig`, `mailbox.zig`, `pool.zig`.
  - Each gets its own examples root, plus `/examples/flow/`.
- Doc comments only. No behaviour change.

**13-3 — the book sheds the detail.**

- Remove from the book what 13-2 put into the code.
- Only rows the carry-over note marks as landed.

**13-4 — the book governs.**

- The book is standalone. It dictates the content of every other doc.
- Read the neighbours for information that belongs in the book.
  - `matryoshka-concepts-002.md` and `patterns-027.md` overlap it most.
  - `kitchen/docs/` pages, both directions.
- Reconcile `kitchen/docs/api/pool/hooks-discipline.md`.
  - The book's Hooks section states the same rules by then.
  - Decide: does the page keep its own text, or become a pointer.
  - Named here so it is not rediscovered by accident.
- Move information in. Move information out. Record both.

**Not in scope.**

- FLOW 1-2 and FLOW 1-3. Postponed by the owner.

---

## 11. Verification of 13-1

- `bash kitchen/tools/check_design.sh > zig-out/check_design.log 2>&1`, exit 0.
  - Dead links in both syntaxes, orphans, forward tense, glossary.
  - The glossary check covers the new `ParentHandle` entry.
  - The orphan check covers `api-13-carryover`, first version.
- `bash kitchen/build_and_test_debug.sh > zig-out/build_and_test_debug.log 2>&1`,
  exit 0.
  - New in this stage. `tests/zig_mechanisms.zig` must build and pass.
  - `-001` said no build script was required. That is no longer true.
- Banned-word and AI-sh scan. The stage changes `*.md` and `*.zig`.
- Staccato self-check on every new or reworked section.
- Read the book front to back, as a reader who does not know Matryoshka.
  - Every term is introduced before it is used.
  - Every part has the same five-piece shape.
  - Part 2 makes Part 3 cheap. If it does not, Part 2 is wrong.
- Session Log row appended. STATUS.md updated.

---

## 12. Related documents

- [matryoshka-api-reference-040.md](matryoshka-api-reference-040.md) — the book
  this note describes.
- [rules-046.md](rules-046.md) — staccato, Part 6. Banned words, Part 5.
  Doc comments, Part 4.
- [matryoshka-concepts-002.md](matryoshka-concepts-002.md) — overlaps the book.
- [patterns-027.md](patterns-027.md) — overlaps the book.
- [language-of-matryoshka.md](language-of-matryoshka.md) — gains `ParentHandle`.

---

## 13. Still to be decided by the owner

- **Part 6.** Section 9. After Parts 1-5.

The banned word is no longer open. Owner ruled on 2026-08-13.

- It is in Part 5 of `rules-046.md`, and the glossary gate enforces it.
- The previous rules version is gone. Sixteen files repointed.
- One claim in this note's first version was wrong, and is corrected here.
  - It said the gate would start rejecting the word repo-wide.
  - The gate reads `design/*.md` only.
  - `src/`, `tests/` and `examples/` stay with the manual scan.

---

## Change log

| Version | Date | Changes |
|---------|------|---------|
| 001 | 2026-08-13 | First version. The reason for the change, the eight findings, the ruling that detail moves into the code, the naming advice, what was found on disk, the seven-part structure, the displacement table, the deliverables of 13-1, the open question on Part 6, and the sketch of 13-2 through 13-4. |
| 002 | 2026-08-13 | The owner's notes on `-001`, folded into the sections they govern. Part 2 named and rewritten — the handle is Zig's, only the term is ours, and `ItemHandle` moves to Part 3. Its specimen becomes a new test file. A slogan is removed. Part 5 gains a Hooks section one level above Get and Put. Snippets come from real working code, and none go into `src/`; module heads get example roots instead, in 13-2. The example roots are per module, not per layer. The displacement record is renamed and given a reference chain. 13-1 gains one `*.zig` file and a build script run. Part 6 stays open. |
