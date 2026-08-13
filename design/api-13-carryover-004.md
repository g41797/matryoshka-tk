# API 13 — carry-over note

The record of what moved out of the api reference, and where it goes.

- Written by stage 13-1.
- Section 2 is discharged. 13-2 wrote the rows into `src/`, 13-3 took them out
  of the book. Both on 2026-08-13. The tables stay as the record of the move.
- Section 3 is still live. Retiring this note to `design/secondary/` would take
  Section 3 with it, so it stays in `design/` until the owner has ruled on the  
  slogan register and the `lifecycle` footprint.
- Empty when both sections are discharged, and then retired to
  `design/secondary/`.

The safety rule it exists for: nothing leaves the book before it exists  
somewhere else. See Section 3 of [api-13-book-002.md](api-13-book-002.md).

Two sections.

- **To the code** — detail that belongs in `src/*.zig` doc comments.
- **To remove later** — the slogan register, in documents 13-1 does not own.

---

## 1. Already discharged in 13-1

Four items left the book in 13-1. Each one already existed elsewhere, so no  
carry-over was needed.

| what | where it was | where it is now |
|------|--------------|-----------------|
| Manual type definition, seven steps | `-038` lines 233-484 | `kitchen/docs/api/polynode/manual-definition.md`, linked from Part 3 |
| PolyHelper generated, create/destroy | `-038` lines 486-707 | `kitchen/docs/api/polyhelper.md`, linked from Part 3 |
| Complexity guarantees table | `-038` lines 1943-1960 | nowhere. Deleted. Not for the reader. |
| Bare signature lists before the descriptions | `### Types` / `### Functions` blocks | replaced by grouped signatures, each with its own description |

The 475 deleted lines are covered by two hand-maintained pages, both already in  
the mkdocs nav. No generator writes them.

---

## 2. To the code

**Discharged.** 13-2 wrote every row below into a `///` or `//!` comment in the  
named file. 13-3 then took the mechanism out of the book. The rows stay as the  
record of where each fact went.

What 13-3 kept in the book, against its row here:

- The precondition half of every assert row. "The Slot must be empty" is
  something a caller satisfies before calling; the assert that enforces it is  
  not. The nine `Assert:` blocks are gone, the preconditions are prose.
- The OOB ordering diagram, the two-`popFirst` warning trimmed to two bullets,
  and two behavioural contracts — waiter order is not FIFO, and there is no  
  put-then-get sequence guarantee. Owner's ruling, 2026-08-13.

One row was deleted rather than moved. See Section 5.

Written as input for 13-2. Each row moves into a `///` or `//!` comment in the named file,  
in human form — a sentence a person reads, not a spec clause.

13-3 removes a row from the book only after it has landed in the code.

Every row below is present in the book today, in Part 3, 4 or 5.

### `src/polynode.zig`

| what | where in the book |
|------|-------------------|
| `is_linked` is blind for a list of exactly one, and the five `!is_linked` asserts inherit that blindness | Part 3, Links |
| `reset` is needed by hand only after reaching through `_list` | Part 3, Links |
| Every `ItemList` insert asserts twice under runtime safety, and why neither check alone is enough | Part 3, Lists, Insert |
| `insertAfter` / `insertBefore` also assert `existing` is in the list and is not the item being inserted | Part 3, Lists, Insert |
| Inserts are O(n) under safety builds, and nothing outside them | Part 3, Lists, Insert |
| `appendFromSlot` / `prependFromSlot` assert the Slot holds an item, and why an insert follows `Mbox.send` rather than `Pool.put` | Part 3, Lists, Insert |
| `remove` asserts the list holds the item | Part 3, Lists, Take out |
| `len` forwards std's O(n) walk, and never replaces the containers' own counters | Part 3, Lists, Inspect |
| `concat` asserts `other != self`, and what `concatByMoving` would do to the items without it | Part 3, Lists, Move whole lists |
| `moveFromList` asserts the std header is consistent — `first` and `last` both null or both set | Part 3, Lists, Move whole lists |
| No copy form of `moveFromList` / `moveToList` — a header copy aliases | Part 3, Lists, Move whole lists |
| An item taken out through `_list` keeps its old `prev`/`next` | Part 3, Lists, `_list` |
| `std.DoublyLinkedList.popFirst` does not clear the links, `ItemList.popFirst` does, and what skipping `reset` breaks | Part 3, Lists, Warning |
| `moveFromSlot` asserts the item is not linked | Part 3, Generation, Through a Slot |
| `PolyHelper.destroy` asserts the item is not linked, and clears the Slot before releasing the item | Part 3, Generation, Heap |

### `src/mailbox.zig`

| what | where in the book |
|------|-------------------|
| `send` / `send_oob` assert `slot.* != null` and `!is_linked` | Part 4, Send |
| `receive` / `try_receive` assert `slot.* == null` | Part 4, Receive |
| `timeout_ns = 0` in `receive` is equivalent to `try_receive` | Part 4, Receive |
| Order among competing waiters depends on the Io runtime, and is not FIFO | Part 4, Receive |
| `wakeUpAll` called while a receiver is blocked returns `error.Wakeup` and leaves the Slot null | Part 4, Receive |
| `wakeUpAll` does not affect receivers that start after it returns | Part 4, Control |
| `receive_batch` returns an empty list rather than an error, and does not wait | Part 4, Receive |
| `close` is repeatable, and the second call returns an empty list | Part 4, Control |
| `_ = mbx.close()` drops items that keep their list links, so `send` rejects them afterwards | Part 4, Control |
| `destroy` makes closedness a precondition and panics on an open mailbox | Part 4, Create and destroy |
| The OOB ordering sequence | Part 4, Send |

### `src/pool.zig`

| what | where in the book |
|------|-------------------|
| `init` asserts the tags are not empty, each tag is not null, and the pool is not closed | Part 5, Create and destroy |
| `get` / `get_wait` assert `slot.* == null`, the pool is initialized, and the tag is registered | Part 5, Get |
| `get_wait` with a zero timeout returns `error.Timeout`, not `error.NotAvailable` — a deliberate divergence from `get(.available_only)` | Part 5, Get |
| `put` on a null Slot returns immediately, with no hook call and no tag assert | Part 5, Put |
| `put` asserts `!is_linked` when the Slot holds an item | Part 5, Put |
| The four outcomes `on_put` may pick, and the rule that a non-null Slot afterwards means exactly that an item was kept | Part 5, Put |
| A closed pool's `put` returns with the Slot unchanged, so the caller still has the item | Part 5, Put |
| No sequence guarantee — put-then-get counts, identity and order are hook policy | Part 5, Put |
| `put_all` is not atomic with respect to `close`, and what happens to each half of the batch | Part 5, Put |
| `put_all` restoration order after a mid-batch close may differ from the original order | Part 5, Put |
| `put_all` asserts each node's tag is registered | Part 5, Put |
| `close` is repeatable, calls `on_close` once with the full list, and broadcasts to blocked `get_wait` callers | Part 5, Control |
| A hook returning an item with a different tag is a programming error, asserted in Debug and ReleaseSafe | Part 5, Hooks, `on_get`. Also in `kitchen/docs/api/pool/hooks-discipline.md`. |
| `in_pool_count` is a hint — read under lock, used without it | Part 5, Hooks |
| Hooks run outside the pool's lock, and may run on several threads at once | Part 5, Hooks |
| Hook reentrancy is forbidden, and the reason is the contract, not deadlock | Part 5, Hooks |
| A hook that touches shared state uses `Io.Mutex` with `lockUncancelable`, because hooks return `void` | Part 5, Hooks |

Rows referring to composite items — `on_put` returning an extra `ItemList`, and  
that the pool does not validate the composite — belong with `put` and `on_put`  
in the same pass.

---

## 3. To remove later

The slogan register, and one banned word, in files 13-1 does not own. Recorded  
here, not edited.

The owner decides each one.

### The slogan

`-038` opened with "Every object follows the same rule: one place, one state, at  
any moment", and carried a `## One place, one state` heading. Both are gone from  
the book — the owner ruled the register is advertising, not documentation. The  
substance stayed: the slot rule in Part 6 says the same thing as a rule a reader  
can act on.

The same register survives elsewhere.

| file | line | what it says |
|------|------|--------------|
| `kitchen/docs/manifesto.md` | 160 | "The one rule that matters:" |
| `kitchen/docs/api/polynode/functions.md` | 37 | heading `## One place, one state — read-only ops` |
| `README.md` | 77 | links to "beautiful documentation" |
| `design/matryoshka-concepts-002.md` | 252 | "A *worker* is simply a Master with one job." |
| `design/patterns-028.md` | 1339 | "It simply never re-registers." |

`design/` and `kitchen/docs/` are separate decisions. 13-4 reconciles the  
kitchen pages against the book.

### `lifecycle`

`lifecycle` is a banned word — Part 5 of [rules-047.md](rules-047.md). The  
glossary gate does not cover it, so the manual scan is the only check, and the  
live footprint is large.

| file | hits |
|------|------|
| `design/matryoshka-architecture-foundation-4-006.md` | 26 |
| `design/patterns-028.md` | 5 |
| `design/matryoshka-concepts-002.md` | 5 |
| `design/STATUS.md` | 2. One live use, in the Project line — "Item-transfer and lifecycle toolkit". The other names the word to record the ban. |
| `design/context.md` | 1, in the `task2-tests` line |
| `src/matryoshka.zig` | 0. Closed by 13-2 — the line now reads "pool: item reuse through your hooks". |
| `kitchen/docs/**` | 17, across 10 pages |

Notes.

- The book itself is clean. One changelog row names the word to record an
  earlier removal, which Part 5 of the rules allows.
- `design/rules-047.md` names it to ban it, and is exempt.
- `design/matryoshka-tk-implementation-plan-070.md` names it in the rows that
  recorded the ban.
- The `src/matryoshka.zig` hit was one line, and 13-2 already had the file open.
  Closed 2026-08-13, owner approved. Six sites left.
- The architecture document carries 26 of the 39 hits now left under `design/`
  and `src/`. It is a large edit, and the owner's call.

---

## 5. Found by 13-2

Three things the code did not back. Reported, not fixed.

### An assert that does not exist

The `src/pool.zig` row reads "`init` asserts the tags are not empty, each tag is  
not null, and the pool is not closed".

- `hooks.tags` is `[]const *const anyopaque`. The elements are not optional.
- There is no null check, and there cannot be one.
- What `init` does assert: the tag list is not empty, the pool is not closed, and
  no hooks are registered yet.
- The doc comment says those three. The null clause was not written.
- Rules Part 4 makes this a MUST: a documented assert must exist in `src/`.
- 13-3 deleted the clause from the book instead of moving it. Part 5, Create and
  destroy, now says the tag list must not be empty, and nothing about null.

### Two counts of the same asserts, both wrong

`!is_linked` asserts in `src/`, counted live on 2026-08-13:

| where | count |
|-------|-------|
| `src/polynode.zig` | 4 |
| `src/mailbox.zig` | 2 |
| `src/pool.zig` | 2 |

Eight textual sites. Seven distinct ones — `PolyHelper.moveFromSlot` appears  
twice, once per helper variant, from one piece of source.

- Section 2 of this note says five.
- Part 4 of [rules-047.md](rules-047.md) says seven.
- The rules file is right about the distinct count and could still be read as
  the textual one.

13-2 wrote no number. The `is_linked` doc comment says every `!is_linked` assert  
inherits the blind spot, and leaves counting to whoever needs it. A number in a  
doc comment goes stale on the next assert added, and nothing checks it.

### `hands` in two module headers — discharged by 13-4

A banned word, Part 5 of the rules.

| file | line | text | outcome |
|------|------|------|---------|
| `src/mailbox.zig` | 33 | "`close` hands the list back and is done" | reworded, then moved onto `close` |
| `src/pool.zig` | 31 | "# A closed pool hands items back" | reworded, then moved onto `put`/`put_all` |

The count was two here and four in `src/`. 13-4a found `handed` at  
`src/mailbox.zig:355` and `src/polynode.zig:521` as well, and reworded all  
four.

Owner's ruling, 13-4: `holds` in the custody sense goes the same way, and the  
MBOX 1 framing goes with it. `src/mailbox.zig` now reads "The mailbox keeps  
items. It never touches them." The carve-out in the rules is retired.

Scoped away from `hold`/`holder`/`held` in
[matryoshka-architecture-foundation-4-006.md](matryoshka-architecture-foundation-4-006.md).
That vocabulary was chosen on 2026-07-09 to replace a banned family of words,  
and it now names sections and the `HELD` state. Part 5 of
[rules-047.md](rules-047.md) carries the word itself.

---

## 4. Related documents

- [api-13-book-002.md](api-13-book-002.md) — the design note this stage runs
  from. Sections 3, 7 and 10 point here.
- [matryoshka-api-reference-041.md](matryoshka-api-reference-041.md) — the book.
- [rules-047.md](rules-047.md) — banned words, Part 5. Doc comments, Part 4.
- [matryoshka-tk-implementation-plan-070.md](matryoshka-tk-implementation-plan-070.md) —
  the 13-2 entry names this note as its input.

---

## Change log

| Version | Date | Changes |
|---------|------|---------|
| 004 | 2026-08-13 | 13-4b-1 discharged the custody-wording finding. The two-header table gains outcomes and the real count of four. The owner's ruling on the custody sense and on the MBOX 1 framing is recorded, with the scope-out for the architecture doc's Hold vocabulary. |
| 003 | 2026-08-13 | 13-3 discharged Section 2 from the other end — the book shed the mechanism. Section 2 records what 13-3 kept against its row and why. Section 5's first finding closed: the `init` null-tag clause is deleted from the book. The note stays in `design/` because Section 3 is still live. |
| 002 | 2026-08-13 | 13-2 landed Section 2 in `src/`. Section 2 keeps its rows for 13-3 and gains a landed marker. New Section 5: the `init` null-tag assert that does not exist, two stale counts of the `!is_linked` asserts, and the two `hands` hits in module headers. |
| 001 | 2026-08-13 | First version, written by 13-1. The four items already discharged, the three per-file tables of detail for 13-2, the slogan register recorded for the owner, and the `lifecycle` footprint. |
