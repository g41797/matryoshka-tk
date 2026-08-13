# API 13 — the reference becomes a book

Design note. Owner reads it and gives updates. New version per revision.

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

**Section 9 — Part 6 needs a ruling before its body is written.**

- Part 6 folds ten flat sections into one part.
- It is the largest judgment call in the stage.
- Owner rules on the section list first.
- Parts 1-5 get built while waiting. They do not depend on the answer.

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

One consequence, stated up front.

- The note at the top of the file is stale.
  - "Function descriptions in this reference serve as the source for `///` Zig
    doc comments in the implementation."
  - That is the old direction. It goes.

---

## 2. What is wrong with the file today

Owner's findings, each confirmed against `matryoshka-api-reference-038.md`.

| finding | evidence |
|---------|----------|
| Mixed styles | part staccato, part prose; reads like several authors |
| Wrong order | `ItemHandle` at line 24, `Slot` at line 30 — before Matryoshka is introduced |
| Wrong audience | written from the Matryoshka developer's mindset, not the user's |
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

The safety rule.

- Nothing leaves the book before it exists somewhere else.
  - In the code.
  - Or in a kitchen page.
- 13-1 records each displaced item in a ledger.
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

---

## 6. The book — proposed structure

### 6.1 Every part has the same shape

The reader learns the shape once, then knows it everywhere.

1. **What this is** — high level, short.
2. **Participants** — the types, and the role each one plays.
3. **Usual flow** — the regular usage. First. Before any description.
4. **The API, in named groups** — one named paragraph per group.
5. **Where to go deeper** — `src/`, an example, a kitchen page.

### 6.2 The parts

**Part 1 — Introduction.** New.

- What Matryoshka is.
- What it is for.
- Who it is for.
- What it is not.
- The three tools, one line each. Mailbox and pool both optional.
- What the reader needs before starting.

**Part 2 — The foundation.** New.

- Intrusion and type erasure.
  - `std.DoublyLinkedList` works on Nodes.
  - The links are part of the struct.
  - The list does not know the parent type.
  - No wrapper allocation.
- The technique of working with them.
  - `@fieldParentPtr` to get back to the parent.
  - Why the caller must check before casting.
- The one rule — one place, one state.
- `ItemHandle` and `Slot` introduced **here**.
  - After the reason for them exists.
  - Not on line 24.

**Part 3 — polynode.**

- Participants: `PolyNode`, `ItemHandle`, `Slot`, `ItemList`, `PolyHelper`.
- Usual flow: define a type, transport it, recover it.
- Groups.
  - Identity — the tag.
  - Links — `reset`, `is_linked`.
  - Lists — `ItemList`.
  - Generation — `PolyHelper`, what it saves you.

**Part 4 — mailbox.**

- Participants: `Mbox`, `Slot`, `ItemList`, the Io it holds.
- Usual flow: the four steps, already written and approved in FLOW 1-1r.
- Groups.
  - Create and destroy.
  - Send.
  - Receive.
  - Control — close, wake up.
  - Event source — the async face.

**Part 5 — pool.**

- Participants: `Pool`, `Pool.Hooks`, `Slot`, `ItemList`.
- Usual flow: the five steps, already written and approved in FLOW 1-1r.
- Groups.
  - Create and register hooks.
  - Get.
  - Put.
  - Control — close.
  - Event source.

**Part 6 — Using them together.**

- Today: ten flat `##` sections. They become one part with sections.
- Candidates: tag identity, slot programming, cooperative cleanup, cancel
  model, thread safety, invariants, contract violations, layer dependencies.
- **This is the largest judgment call in the stage.** See Section 9.

**Part 7 — Beyond the toolkit.**

- The `matryoshka` root module.
- Master — and why it is deliberately not part of the API.
- The Io backend.

**Change log.** Stays at the end, as it is now.

---

## 7. What leaves the book, and where it goes

| what | where it is now | goes to | when |
|------|-----------------|---------|------|
| Manual step-by-step, seven steps | 233-484 | delete; point at `kitchen/docs/api/polynode/manual-definition.md` | 13-1 |
| PolyHelper generated, create/destroy | 486-707 | delete; point at `kitchen/docs/api/polyhelper.md` | 13-1 |
| Complexity guarantees | 1943-1960 | delete. Not for the user. | 13-1 |
| Bare signature list before the descriptions | `### Types` / `### Functions` in each part | delete the list. Keep one signature, with its description. | 13-1 |
| Assert lists, per function | throughout | `src/*.zig` `///` comments | 13-2, removed in 13-3 |
| Edge cases written as spec clauses | throughout | `src/*.zig` `///` comments, human form | 13-2, removed in 13-3 |

Nothing in the last two rows is deleted in 13-1.

---

## 8. Deliverables of 13-1

- The api reference, next version — `-039`. The book.
  - New `# H1`. New structure. Parts 1-7.
  - `-038` removed. Cross-references repointed in the seven design docs.
  - Changelog row `039` added.
  - The stale `>` note at the top goes.
  - The dead pointer at line 1827 fixed.
    - It says "See **Addendums → Io 101**".
    - That section was removed from the file.
    - `kitchen/docs/addendums/io-101.md` still exists. Point there.
- A displacement ledger, new design note, `book-ledger` first version.
  - One row per displaced item: what, where it was, where it went.
  - Rows marked `to-src` are the input to 13-2.
  - Rows marked `dropped` say why.
- `design/context.md` — the reference's line rewritten.
  - It still promises a trailing Addendums/Io 101 section.
  - That section is gone. The line is false today.
- `design/STATUS.md`, `design/STATUS-LOG.md`, plan bumped.

---

## 9. Open question — Part 6

Part 6 folds ten flat sections into one part.

- It is the largest judgment call in the stage.
- It is the one most likely to be wrong.

Proposal.

- Draft the Part 6 section list first.
- Show it to the owner before writing the body.
- Build Parts 1-5 while waiting. They do not depend on the answer.

---

## 10. Later stages

**13-2 — the code takes the detail.**

- Write the displaced items into `src/*.zig` doc comments.
- Human form. A sentence a person reads.
- Input: the `to-src` rows of the ledger.
- Doc comments only. No behaviour change.

**13-3 — the book sheds the detail.**

- Remove from the book what 13-2 put into the code.
- Only rows the ledger marks as landed.

**13-4 — the book governs.**

- The book is standalone. It dictates the content of every other doc.
- Read the neighbours for information that belongs in the book.
  - `matryoshka-concepts-002.md` and `patterns-027.md` overlap it most.
  - `kitchen/docs/` pages, both directions.
- Move information in. Move information out. Record both.

**Not in scope.**

- FLOW 1-2 and FLOW 1-3. Postponed by the owner.

---

## 11. Verification of 13-1

- `bash kitchen/tools/check_design.sh > zig-out/check_design.log 2>&1`, exit 0.
  - Dead links in both syntaxes, orphans, forward tense, glossary.
- Staccato self-check on every new or reworked section.
- No `*.zig` change in 13-1. No build script required.
- Read the book front to back, as a reader who does not know Matryoshka.
  - Every term is introduced before it is used.
  - Every part has the same five-piece shape.
- Session Log row appended. STATUS.md updated.

---

## 12. Related documents

- [matryoshka-api-reference-038.md](matryoshka-api-reference-038.md) — the file being rebuilt.
- [rules-044.md](rules-044.md) — staccato, Part 6. Banned words, Part 5.
- [matryoshka-concepts-002.md](matryoshka-concepts-002.md) — overlaps the book.
- [patterns-027.md](patterns-027.md) — overlaps the book.

---

## Change log

| Version | Date | Changes |
|---------|------|---------|
| 001 | 2026-08-13 | First version. The reason for the change, the eight findings, the ruling that detail moves into the code, the naming advice, what was found on disk, the seven-part structure, the displacement table, the deliverables of 13-1, the open question on Part 6, and the sketch of 13-2 through 13-4. |
