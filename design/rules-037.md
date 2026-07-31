# Matryoshka Zig — Rules (037)

Versioned doc. Replaces [rules-036.md](rules-036.md).  
Change from -036: DISPATCH 2 — one entry, the transfer rule for table  
dispatch handlers. It is a convention for handler authors, not a toolkit MUST.  
Change from -035: DISPATCH 1 — two rules. Every dispatch chain ends with a  
final branch. No `switch` over tags; it does not compile.  
Change from -034: API 11 — the accessor naming rule names `fromPoly` /  
`fromSlot`. The helper reaches the `poly` field, and `node` was already taken  
by `std.DoublyLinkedList.Node` inside `PolyNode`.  
Change from -033: the neighbour check — what `is_linked` is worth, and the two  
checks that are exact where it is not. API 9 keeps all seven `!is_linked`  
asserts, so what they promise has to be written down.  
All coding, doc, and process rules for the project.  
Companion: [matryoshka-model-006.md](matryoshka-model-006.md) — the thinking model.  
Companion: [patterns-025.md](patterns-025.md) — reusable coding patterns.

---

## Observable by human — MUST

Every function with distinct phases or steps is written in two levels.

Level 1 — the coordinator (`run`, any sequencing function).
- Dominant structure: calls to named step functions.
- Simple glue stays inline: a guard, a `helpers.expect`, a `std.log.info` line.
- Inline logic blocks with distinct purpose — extract to a named step.
- The full flow is visible in a few lines without opening anything.

Level 2 — the step functions.
- Each implements exactly one step.
- Named for what they do. The name IS the documentation.
- `var`/`const` declarations are fine anywhere they are needed.

Development order.
- Write the coordinator first. Name the steps before implementing them.
- Add stub step functions that compile but do nothing.
- Fill in steps one by one, sequentially or iteratively.
- The flow is known and visible from the start.

The signal.
- If you feel the need to place a comment explaining a block of code: stop.
- That block must be a named step function instead.
- A comment marks a step you should have named before writing.
- Common sense: a 1-2 line guard or log between step calls stays inline.
- Only blocks with distinct, nameable purpose are extracted.

Structural extraction signals.
- These patterns are always violations — no comment needed to trigger extraction.
- 1. Any `while` loop with a `switch` body inside a coordinator.
  - Name: `runEventLoop`, `eventLoop`, or domain equivalent.
  - The loop is the step. Extract it regardless of length.
- 2. Any `Io.Select` setup block inside a coordinator (`buf` + `sel.init` + `sel.concurrent` calls).
  - Name: `setupSelect`, or fold into `runEventLoop` if trivially short.
  - `buf` and `sel` are declared at coordinator scope and passed as `*Sel` to steps,
    or held as struct fields in a Master.
- 3. Any cluster of `io.concurrent` / `group.concurrent` / `Thread.spawn` calls inside a coordinator.
  - Name: `spawnWorkers`, `runWorkers`, `spawnSenders`, or equivalent.
  - `await` calls belong in the same step or in a paired `awaitWorkers` step.
- 4. Any for-loop or sequential block that sends, fills, or seeds items inside a coordinator.
  - Name: `sendItems`, `fillMailbox`, `seedPool`, `sendEvents`, or equivalent.
  - Already covered by the comment signal but now also structural — no comment required.

Step function parameters.
- Pass only state that is transient between specific steps (output of one step, input to the next).
- State shared by the coordinator and most steps belongs in a struct field.
  - Masters: `self.field` — already in the struct, no parameter needed.
  - Flat coordinators with 3+ shared params: introduce a local value struct. No heap allocation.
- A step function with 3+ parameters that are all coordinator-scope state signals: introduce a struct.
- Simple extractions with 1-2 params: explicit parameters are fine.

Applies to all code: `src/`, `helpers/`, `examples/`, `tests/`, `stories/`.  
Small functions with no distinct phases need no extraction.

---

## Description as code — MUST

An example's or story's description is written like its code, not like prose about its code.

Applies to.
- Every `//!` description block at the top of an example's or story's file.
- `task1-examples-*.md` / `task2-examples-*.md` catalog entries (see Catalog docs below).

Same shape as Observable by human.
- One-line intent — what the example demonstrates. This is the coordinator line.
- Named steps as bullets — one step per bullet, in the order they run.
- A bullet names a step the same way a step function is named: what it does, not how.
- No single long sentence chaining multiple facts with commas — that is an unextracted
  block, same violation as an unextracted code block.

Staccato rhythm applies.
- Short intro line, then bullets.
- One fact per bullet.
- No prose paragraphs.

Placement — `//!` file-level doc comment, not `//`.
- The description + ASCII transfer diagram is a `//!` doc comment, placed at the
  very top of the file, directly after the SPDX header, before any declaration.
- `//!` is autodoc-extractable and renders on the file's own container page. Plain
  `//` is not extracted at all.
- Not `///` on the entry point: every example file has exactly one public entry
  point, so the file-level `//!` description is sufficient. Mixing `//!` (file)  
  and `///` (declaration) above the same function is a bug, not a style choice —  
  they are different token kinds to the autodoc parser, and the function's own  
  doc silently truncates to whichever kind sits immediately above it.
- If the example uses a Master, the Master's own `run` method is the real
  coordinator, but it is private (`fn`, not `pub fn`) — no doc comment on it. Its  
  steps are still named, self-documenting per Observable by human; no separate  
  doc block needed.

ASCII diagrams — fenced code block.
- Any ASCII diagram inside a `//!` block (transfer diagrams, flow diagrams) is
  wrapped in a ` ``` ` fenced code block: ` ``` ` on its own `//!` line, the  
  diagram lines, then ` ``` ` on its own `//!` line to close.
- Reason: the autodoc viewer renders doc comments as CommonMark markdown, which
  collapses single line breaks into one flat paragraph. A fenced (or 4-space  
  indented) code block is the only way box-drawing diagrams keep their shape.
- Trailing prose after a diagram (a summary sentence, not the diagram itself)
  stays outside the fence, as a normal paragraph.

File layout — flow descriptors at the top.
- The entry point (`pub fn <snake_case>`) sits at the top of the file, directly
  after the `//!` description + diagram block.
- Where a Master exists, its `run` method also moves up, directly after the entry
  point, ahead of struct fields, `init`, `destroy`, and step functions.
- These two functions are the file's flow descriptors — a reader sees the whole shape
  first, then drops into detail only if needed.
- Imports stay at the bottom (LE style, unchanged).

Catalog docs (`task1-examples-*.md`, `task2-examples-*.md`) are an index, not a copy.
- One line per scenario: number, name, one-line hook, link to the source file.
- The full staccato description lives in the source `//!` block only.
- Do not duplicate the description in both places — the source is the single source
  of truth; the catalog just routes to it.

---

## Code quality — all categories

Tests, examples, and stories follow one quality bar.

- Same bar as production code: structured, reusable, well-named.
- No throwaway code in any category.
- Quality, modularity, and naming are identical to production code.

They differ only in visibility and job.

- Tests check correctness. Internal. Not in generated docs.
- Examples show one pattern. Part of generated docs.
- Stories show matryoshka thinking across multiple layers. Part of narrative docs.

The difference is the job, never the quality.

---

## Coding Rules — Tests

What a test must do.
- Check correctness of the implementation.
- Cover one behavior at a time.
- Cover edge cases, error paths, state transitions, contract violations.
- Be structured, reusable, well-named. Same quality as production code.

What a test must not do.
- No throwaway code.
- No story flows. That is the job of examples.

Allocator and io source.
- Tests supply `std.testing.allocator`.
- Tests supply `std.Io`, usually via `std.Io.Threaded.init`.
- Tests set `std.testing.log_level = .debug`.
- Tests use `testing.expect` for verification.

---

## Coding Rules — Examples

Checks.
- Use `helpers.expect(error.XxxFailed, condition, "description")` for invariant checks.
- Works in all build modes, unlike `std.debug.assert` which is removed in ReleaseFast and ReleaseSmall.
- Each example uses its own error name, e.g. `error.BuilderFailed`.

No testing APIs.
- No `std.testing` anything inside example code.
- No `testing.allocator`, no `testing.expect*`, no `testing.log_level`.
- No `std.debug.assert`.
- Use `std.log` for diagnostic output.

Test wrappers live in `tests/`.
- Every example is runnable code.
- A test wrapper calls the example and verifies it.
- Test wrappers supply `std.testing.allocator` and `std.Io`.
- Test wrappers set `std.testing.log_level = .debug`.
- Test wrappers catch errors with `@errorName(err)` for diagnostics.

Scope and shape.
- One pattern. One layer.
- Entry point uses a descriptive name, not `run`.
- Signature: `pub fn <snake_case>(allocator: std.mem.Allocator, io: std.Io) !void`.
- `<snake_case>` is a plain identifier derived from the example's one-line staccato
  description (lowercase, words joined with `_`) — never a quoted identifier  
  (`@"..."`). Zig's built-in `zig build docs` autodoc viewer cannot resolve  
  declaration links for quoted identifiers; using one breaks the generated  
  `examplesdocs` page for that example.
- The staccato description text itself is unchanged and still lives verbatim as
  the first line of the file's `//!` doc comment.
- Master's own `run` method (private, inside the Master struct) is unaffected — this
  rule targets only the example's public entry point.
- `//!` doc comment at the top of the file: staccato description + ASCII transfer
  circuit diagram, diagram wrapped in a ` ``` ` fenced code block. No doc comment =  
  not done. See Description as code above.
- The entry point (and Master `run` method, if any) placed at the top of the file, right
  after that doc comment.
- Show correct resource cleanup. `errdefer` on error paths, `defer` on all-path cleanup.
- Examples become docs. Leaky examples teach leaky habits.
- Reference model: tofu `recipes/cookbook.zig`.

Completeness.
- Show where work input originates: caller seeds, network provides, timer triggers, worker's own accumulated state.
- Show what the worker does with a pool resource and any additional input.
- Show where results go after processing.
- A lifecycle-only example (get → put, no input source, no output destination) is not complete.
- Pool items are empty containers on acquisition. Work intent must come from outside the pool item.
- See "Pool items are empty containers" in [matryoshka-model-005.md](matryoshka-model-005.md).

Master pattern.
- Small examples: flat function. All state fits in local variables. No Master needed.
- Big examples: allocate a Master struct on the heap.
- The same two-tier rule applies to worker functions inside any example or story.

When to stay flat (simple case).
- Minimal functionality: one loop, one action per iteration.
- All state fits in local variables.
- Short lifecycle: exits cleanly on close or cancel.
- No shared state between steps.

When to allocate a Master (complex case).
- Multiple steps or phases with state shared between them.
- Complex lifecycle: distinct init / work / shutdown phases.
- `run` method needs named private steps to remain readable.
- Growing functionality that would make a flat function hard to follow.

Master struct shape.
- The entry point and the Master's `run` method sit at the top of the file (see
  Description as code above), directly after the doc comment:

```zig
pub fn <snake_case>(allocator: std.mem.Allocator, io: std.Io) !void {
    const master = try MasterXYZ.init(allocator, io);
    defer master.destroy();
    try master.run();
}
```

- `init(allocator, io) !*MasterXYZ` — allocates on heap, acquires all resources, can fail.
- `destroy` — releases resources in correct order, frees the allocation last.
- Master's `run` — readable main flow: sequenced calls to private step functions.
- Private functions — each implements one internal step.
- Fields — shared state between steps; replace scattered locals.

Canonical reference: `examples/layer4/018-master_with_pool.zig`.

---

## Coding Rules — Stories

- Signature: `pub fn run(allocator: std.mem.Allocator, io: std.Io) !void`.
- Must show multiple layers composing into a real flow.
- `///` doc comment at the top of the file: staccato description + ASCII transfer
  circuit diagram (see Description as code above).
- Test wrapper in single `tests/stories_test.zig`, using `std.Io.Threaded.init`.
- SPDX header required if the file sits under `src/`; owner adds SPDX headers.
- Stories always use the Master pattern. A story is never a flat function.

### Story structure — Master composition rule

A story composes Masters. This rule is derived from matryoshka's own Master concept.

What a Master is.
- A Master is a coordination boundary.
- It owns its resources: mailboxes, pools, allocator, application state.
- It coordinates startup order, shutdown order, and cancellation policy for those resources.
- An `Io.Select` loop is a Master. An `Io.Group` of workers under one coordinator is a Master.
- There is no required Master struct or interface. The responsibility defines it, not the type.

How a story is structured around Masters.
- A story composes more than one Master.
- Each Master is its own structured unit: a Master struct allocated on the heap.
- Master struct has `init`, `destroy`, `run`, and private step functions.
- A Master's fields hold the handles it owns and the state it tracks.
- A Master's `run` function does the coordination: receive, dispatch, re-spawn, shut down.
- Do not inline a Master's coordination logic into the top-level `run`.

What `pub fn run` does.
- `run` is thin.
- `run` initializes shared resources.
- `run` starts the Masters.
- `run` awaits the Masters' shutdown in the mandatory order.
- `run` does not hold a Master's per-event coordination logic.

Why this shape.
- It mirrors how matryoshka separates the coordination boundary from the entry point.
- The reader sees one Master at a time, each with its owned resources.
- Shutdown order is visible in `run`, not buried inside a loop.

---

## Coding Standards

Import order (LE style).
- "LE" means "_Little-endian_" - imports are placed at the bottom of the file, after the code.
- Package and local imports first.
- `const std = @import("std")` always last.
- Do NOT flag std-last as a violation.

```zig
const polynode = @import("polynode.zig");
const cond_timeout = @import("internal/cond_timeout.zig");
const std = @import("std");
```

SPDX headers.
- Required in all `src/` files.
- Owner-added. Never remove them during edits.
- Do not add SPDX headers to new `src/` files. Owner will add them.

Layer terminology.
- Use "layer" not "block" everywhere — docs, tests, examples, directories.
- Exception: Odin reference paths (`block1/`, `block2/`) are quoted literals naming Odin's own directories.

Handle naming (API 4).
- `ItemHandle` is the canonical name for `*PolyNode` — supersedes `NodeHandle`,
  which leaked the intrusive-list-node implementation detail into a name  
  meant to describe what the caller holds.
- Short variable name: `ih` (was `nh` — never actually used in code before
  this rule, so nothing to migrate).
- Bare `handle` is acceptable informal shorthand in prose/comments once the
  type is clear from context — matches existing usage throughout the API  
  reference.
- `MailboxHandle` / `PoolHandle` are unaffected — they already name the role,
  not the implementation.

Accessor naming (API 6).
- A name says what the caller does, not how the helper works. `identifyNodeAs`
  and `identifySlotAs` described the implementation and are gone.
- Inspection is `fromPoly` / `fromSlot`. It never empties a Slot and never
  modifies a Node. `fromSlot` takes `*const Slot` so it cannot.
- Extraction is `moveFromSlot`. It always empties the Slot on success, and
  leaves it unchanged on failure.
- No `As` suffix. The type is already the namespace:
  `EventPolyHelper.fromSlot(&slot)`.
- A helper that mutates its argument gets no `must` variant. Hiding failure
  behind `unreachable` would make the state change less obvious. This is why  
  `moveFromSlot` has none while `fromPoly` and `fromSlot` do.
- Every consuming operation asserts the item is not linked into a list.

General Zig style.
- Explicit typing: `const x: T = ...` where the type is known.
- Explicit dereference: `ptr.*.field`.
- Check the standard library before adding custom definitions.
- `errdefer` after every `alloc.create` or resource-acquiring `try`.
- `defer` for cleanup that must run on all exit paths.

The Slot Rule.
- Never overwrite a non-null slot.
- Always start with `var slot: Slot = null`.
- All acquisition APIs assert `slot.* == null` on entry.
- Transfer clears the slot: `slot.* = null`.
- Cleanup ops (`pool.put`, `PolyHelper.destroy`, `helpers.freeSlot`) are no-ops on null slots.
- Use defer-before-acquisition — safe because cleanup is null-safe.
- Never use `allocator.create` / `allocator.destroy` directly on PolyNode-based user types in examples or tests. Use `PolyHelper.create`, `PolyHelper.destroy`, or `helpers.freeSlot`.
- Exception: `receiveResult` and `getWaitResult` hand the item over through the returned union value, not a `*Slot`. The caller extracts the handle and holds it from that point.

Banned words.
- `drain` — use `clear`, `reset`, `empty`, or a domain verb. Example: `clearList` not `drainList`.
- `dll` / `DLL` — clashes with Windows DLL. Use `List.Node`, `list_node_ptr`, or spell out `DoublyLinkedList`.
- "commit" when meaning save/update/write — implies git, which is owner-only. Say "save", "update", or "write".
- AI-sh word list: robust, seamlessly, comprehensive, leverage, efficient, powerful, facilitate, utilize, ensure, performant, ergonomic, idiomatic, streamline, orchestrate, sophisticated, intuitive, scalable, unlock, empower, harness, deliver, fed, arm, leg, idempotent, fires, faces, pitch, object model, execution context, execution model, programming model, paradigm, mindset, ownership, gained, wire, wired, wires, wiring (added in rules-026 — use "connect"/"add to nav"/"hook up" or the concrete action instead).
- Banned (rules-028): `seam`, `seamless` — `seamlessly` was already listed. Use "boundary", or name the two things that meet.
- Banned (rules-028): `sweep` — say what the work is. "Search and replace across the repo", "re-read every call site", "scan `.md` files".
- Banned (rules-028): `settle`, `settled` — use "agreed", "decided", or "the owner accepted it".
- Banned (rules-030): `underneath` — name the thing. "The plain std list", "the std list this holds", or the field name.
- Banned (rules-030): `on purpose` — as a defence of a design choice it explains nothing. Give the reason, or state who does it: "Tests use this field", "the layout is what these tests check".
- Banned (rules-032): `hatch` — covers "escape hatch". A metaphor where a plain
  description belongs, same family as `seam` and `underneath`. Name the field:  
  "the `_list` field", "the raw field", "reaching through `_list`".
- Replacements for `ownership` (rules-031). The word was banned in `src/` from
  rules-012 and repo-wide in the AI-sh list, but no replacement was written down,  
  so each pass invented its own. Name the action instead:

  | instead of | write |
  |---|---|
  | transfers ownership | transfers the item / the item moves |
  | caller retains ownership | the caller keeps the item |
  | ASCII ownership diagram | ASCII transfer diagram |
  | exclusive ownership | exclusive access |
  | ownership circuit | transfer circuit |
  | ownership path | transfer path |

- Scan the rules file against its own ban (rules-031). rules-030 used
  `ownership` five times while banning it — in the two doc-comment rules, the  
  story rule, the SPDX rule, and the `receiveResult` exception. A banned-word  
  scan that skips `rules-0NN.md` misses the document most likely to repeat the  
  word, because the rule text has to talk about it.
- Scoped ban (rules-026): "object" when referring to an Item/ItemHandle — the application/user data an ItemHandle wraps. Use "item" or "ItemHandle" instead. Does not ban "object" elsewhere in prose or code.
- Scan `.zig` and `.md` after any stage that changes them. Report hits to owner. Do not fix without approval.

---

## Comment and Doc Comment Rules

- Short intro line, then bullets. Staccato rhythm.
- One fact per bullet.
- No prose paragraphs with comma-separated lists.
- No dense multi-fact sentences.
- Bullet nesting: when a bullet splits at a colon, "and", or into multiple
  sub-items, demote each part to a nested bullet, one level deeper, one item  
  per line. Do not cram a comma-list or colon-plus-list onto one line.
- LONG SENTENCES DISABLED. Use bullets.
  - Break a long sentence into several short sentences, one line each.
  - Or break it into bullets.
  - No prose. Ever.
- Do not explain WHAT — names do that.
- Explain WHY only if non-obvious.
- No multi-paragraph docstrings.
- No "used by X" / "added for Y flow" comments.
- `///` and `//!` allowed in `src/` (lifted in rules-011, was banned in rules-010).
  - `//!` at the top of each file: high-level module description, staccato style.
  - `///` on every `pub` declaration: function, type, error set, const.
  - Same staccato/comment rules as everywhere else in this section.
  - `examples/` and `stories/` entry-point functions keep their own rule — see
    Description as code above.
- No "ownership" / "ownership transfer" / "owner" language in `src/` comments
  (added in rules-012). Too abstract, reads like a computer-science paper.
  - Say what happens: an operation sends an object, a handle, or a slot from
    one place to another.
  - The invariant to state: an object sits in exactly one place, in exactly
    one state, at any moment. Not "one owner."
  - Staccato style allows an extra bullet line if plain language needs more
    room than the abstract term did.
- Exclusive access, second half (added in rules-033): the transfer also orders
  memory.
  - The holder that receives an item sees every write the previous holder made
    before the transfer.
  - Mailbox and pool publish through their own mutex. The mutex carries the
    ordering.
  - Consequence: a holder reads and asserts on the item's fields with plain
    loads. No atomics, no fences.
  - This is what the `is_linked` / `prev` / `next` asserts rest on. Without it
    they would be data races, not checks.
  - Limit: the guarantee covers an item that has been transferred. It says
    nothing about an item two holders both believe they hold — that mistake  
    breaks the premise, so no assert can catch it.
  - State this in `src/` comments as "the previous holder's writes are visible",
    not as a memory-model term.
- The neighbour check (added in rules-034): `polynode.is_linked` reads
  `prev` and `next`. It answers "does this node have neighbours", not "is this  
  node in a list".
  - `std.DoublyLinkedList` never sets the links of a list's only member, so a
    list of exactly one reports false.
  - The seven `!is_linked` asserts in `src/` are kept. They catch the
    multi-element case, which is where most real double-sends land, and they  
    are blind for a list of one.
  - Do not write a comment, a doc line, or a test name that presents the check
    as a membership test. Say "has neighbours".
  - Nothing repairs it. State kept in an item cannot validate this class of
    mistake — reading that state needs the exclusivity whose absence is the  
    bug.
  - Two checks are exact. Neither reads the item.
    - `ItemList._holds` walks the list it already holds under its own lock,
      and compares addresses instead of reading the item. Runtime safety  
      only.
    - `concat` compares its two arguments; `appendFromSlot` reads a `Slot` in
      the caller's own frame.
  - Prevention beats detection. `appendFromSlot` / `prependFromSlot` empty the
    slot themselves, so there is no `slot = null` line left to forget.

- No references to design docs (`.md` files: rules, plans, api-reference,
  STATUS, patterns) inside `src/*.zig` comments (added in rules-012).
  - Readers of source or generated docs only see the `.zig` files.
  - Comments must be self-contained — explain the fact, don't point at a doc.
- File-header (`//!`) staccato standard (added in rules-013): model on
  `std.Io`'s own file header — short intro line, then a flat bullet list of  
  concrete facts, one per bullet.
  - A header that reads as one run-on paragraph across several `//!` lines
    is a violation even if each individual line is short — packing more  
    than one distinct fact into unbulleted lines is still dense prose.
  - Applies to any doc comment (not just headers) naming more than one
    distinct fact.
- Verification rule (added in rules-013): a scan (banned words,
  terminology bans, `.md`-reference check, line-length/staccato check)  
  is only "done" when re-run live against current file contents at the  
  moment of the claim.
  - A prior pass's claim of completion is not sufficient — re-run the
    grep/check yourself before reporting a scan as complete.
  - Reason: a DOC 16 pass claimed the ownership-terminology pass was
    complete across `src/*.zig`; a live re-check found 6 remaining hits  
    the earlier pass had missed in `polynode.zig`, `mailbox.zig`, and  
    `pool.zig`.
- First-declaration doc-stub rule (added in rules-017, supersedes the
  rules-016 blank-line rule — that hypothesis was tested and disproved):  
  if a file's first declaration after the `//!` header carries a `///` doc  
  comment, Zig's autodoc container page splices that comment onto the  
  module overview page with no separator, regardless of blank lines.
  - Fix: insert `const _doc_stub = void;` (no doc comment, non-`pub`) as
    the first declaration after the `//!` header. It absorbs the splice;  
    being undocumented and private, it does not appear in the rendered  
    docs at all.
  - Only needed when the first declaration would otherwise carry a `///`
    comment. Files with no `///` comments at all (every `examples/`/  
    `stories/` file — description lives entirely in `//!`) need no stub.
  - Verified empirically via headless-Chrome render of `zig build docs`
    output, not assumed from source alone — a plain source-level fix here  
    is unverifiable without checking the actual rendered page.

---

## Documentation Rules

* Document is not a novel.

* Do not use prose style.

* Use simple English.

* Use short sentences.

* Prefer bullets over long paragraphs.

* One fact per bullet.

* Use a staccato rhythm.

   * Start with a short introduction.
   * Follow with a bullet list.
   * One bullet. One fact.
   * Keep the introduction short.
   * Do not chain multiple ideas into one sentence.
   * Do not replace bullet lists with many standalone one-line sentences.

* Story narrative uses the 4-part structure:

   * Architecture dialogue.
   * SRS.
   * Matryoshka translation.
   * Flow diagram.

* Use ASCII diagrams.

* Make diagrams human-readable.

* Do not optimize diagrams for compactness.

* Prefer clarity over brevity.

* Do not save space in files.

* Cross-reference instead of duplicating.

* Link to:

   * `matryoshka-model-005.md`
   * `rules-009.md`
   * `patterns-008.md`

* When extending an existing document:

   * Match the heading levels already in use.

* mkdocs site pages (`kitchen/docs/*.md`) — blank line before every list.

   * Always put a blank line between a lead-in paragraph/heading and the
     bullet or numbered list that follows it.
   * mkdocs's Python-Markdown renderer needs the blank line to recognize the
     list. Without it, the list renders as flat inline text with literal  
     `-`/`1.` characters instead of an actual list.
   * GitHub markdown renders such a list correctly even without the blank
     line — do not rely on that as a check. Verify with  
     `mkdocs build --strict` (or by eye in `mkdocs serve`), not by reading  
     the raw `.md` source.
   * Enforced by `kitchen/tools/fix_md_lists.sh` — auto-fixes every
     `kitchen/docs/**/*.md` in place, part of `build_site.sh`/  
     `preview_site.sh`/CI (see `kitchen/notes.md`). Mechanical formatting  
     only; hand-written prose still needs a blank line for the fix to  
     recognize the list wasn't intentional inline text.

* Examples-catalog nav sync — keep `kitchen/mkdocs.yml` matching `examples/`
  and `stories/`.

   * Any stage that adds, removes, or renames a file under `examples/` or
     `stories/` must also update `kitchen/mkdocs.yml`'s Examples Catalog  
     `nav:` block and the matching hand-authored group page under  
     `kitchen/docs/examples/` (`index.md`, `polynode.md`, `mailbox.md`,  
     `pool.md`, `io.md`, `flow.md`, or whatever grouping is current).
   * `kitchen/tools/gen_examples_docs.sh` only mirrors `.zig` files into
     generated `.md` pages — it does not touch `nav:` or the group pages.  
     A new example gets a generated page automatically, but stays orphaned  
     (reachable only if some page happens to link it, otherwise not  
     reachable at all) until `nav:`/group pages are updated by hand.
   * Verify with `bash kitchen/tools/build_site.sh`: check for `INFO -
     The following pages exist in the docs directory, but are not included  
     in the "nav" configuration` and confirm no `examples/*.md` path  
     appears in that list. Found and fixed once already (DOC 20  
     follow-up, 2026-07-08) — the mirrored pages built fine but were  
     silently missing from `nav:` until this check caught it.

* Doc-generation module size — keep every `zig build docs` target small.

   * `build.zig`'s `docs` step must never root a doc target (`b.addObject` +
     `getEmittedDocs()`) at a module whose transitive import graph spans a  
     large tree. A combined target like that makes the Zig autodoc client  
     (`main.wasm`) hang forever on "Loading..." in the browser, throwing  
     `Uncaught (in promise) RangeError: Maximum call stack size exceeded`.  
     The principle still applies to any future `zig build docs` target —  
     `apidocs` (rooted at `src/matryoshka.zig`) stays well under this size  
     and needs no special handling.
   * Historical detail (DOC 20 removed the affected targets): matryoshka-tk
     hit this after INTR 6 (2026-07-07) with a combined `examples/`  
     autodoc target (~70+ files); same symptom confirmed in the sibling  
     `tofu` repo (commit `1020ba27`, "Fix build of docs. Update GitHub  
     Pages"). The fix at the time split it into 8 small per-area targets  
     (`layer1docs`..`layer4docs`, `itemsdocs`, `hooksdocs`, `helpersdocs`,  
     `storiesdocs`), each staged into an isolated directory via  
     `b.addWriteFiles()` to avoid `getEmittedDocs()` also leaking sibling  
     files into the wrong target's source browser (found 2026-07-08).  
     DOC 20 removed all 8 targets — example docs are now a hand-organized  
     mkdocs catalog (`kitchen/docs/examples/`, generated by  
     `kitchen/tools/gen_examples_docs.sh`) instead of Zig autodoc output —  
     so the staging workaround no longer exists in `build.zig`. Kept here  
     only as precedent if a future doc target grows large again.
   * Verify a doc target actually renders (not just that `zig build docs`
     exits 0) by loading the generated page in a real or headless browser  
     and checking the console for `RangeError`/`Uncaught` — a clean build  
     exit does not guarantee the client-side autodoc viewer can render the  
     result.
   * Required verification step, whenever `build.zig`'s `docs` step or
     anything under `examples/`/`stories/`/`src/` changes: run  
     `kitchen/tools/preview_site.sh` and, for every doc target,  
     (1) open the page in a browser (or drive it headlessly) and check  
     the console for `RangeError`/`Uncaught`, and (2) check  
     `tar tf kitchen/docs/<target>/sources.tar` for files outside that  
     target's own area. `zig build docs` exiting 0 is necessary but not  
     sufficient — it catches neither bug class on its own.

---

## Process / Workflow Rules

Auto-mode.
- No git. All git operations go through the owner.
- No file deletions - ask owner.

Per-stage finish checklist.
1. `kitchen/build_and_test_debug.sh` — quick build + Debug test.
2. `kitchen/build_and_test_all.sh` — full build + all 4 optimization modes.
3. `kitchen/build_cross_debug.sh` — cross-compile Debug for mac + windows.
3a. If the stage touched `build.zig`'s `docs` step or anything under  
    `examples/`/`stories/`/`src/`: run `kitchen/tools/preview_site.sh` and  
    open every doc target page (or drive headlessly), checking the  
    browser console for `RangeError`/`Uncaught`. `zig build docs` exiting  
    0 does not catch the "stuck Loading" autodoc crash — see  
    "Doc-generation module size" under Documentation Rules.
4. Post-stage cleanup: revise code for obsolete parts, wrong comments, repeated code that can be extracted.
5. Re-run all three kitchen scripts after cleanup.
6. After kitchen scripts pass: scan changed `.zig` files for patterns not yet in `patterns-008.md`.
   - Report candidate new patterns to owner. Owner decides.
   - Do not auto-document or auto-extract. Report only.
7. AI-sh + banned words scan over changed `*.md` and `*.zig`. Report to owner.
8. Update `design/STATUS.md` Session Log. Include a "Post-stage cleanup" row. Absence of that row means the rule was skipped.
9. Sync `README.md` and any touched per-module README.
10. Rules audit: after any stage that changes `*.zig` or `*.md` files, audit all changed files
    against every rule in this document. Report violations to owner before closing the stage.  
    Covers: Observable structural signals, Description as code, descriptive entry-point  
    names, Slot Rule, import order, banned words, example completeness, Master pattern  
    shape, comment rules, doc rules — all rules.

Kitchen script order.
- `build_and_test_debug.sh` → `build_and_test_all.sh` → `build_cross_debug.sh`.
- Build before test. `zig build` must pass before `zig build test`.
- Full verification = all 4 optimization modes: Debug, ReleaseSafe, ReleaseFast, ReleaseSmall.
- A stage is complete only when all 4 modes pass.
- Redirect build/test output to `zig-out/` log files. Analyze via files, not shell stdout.

New plan version vs update.
- Create a new plan version after each completed stage or INTR.
- Plans are new versions of `design/matryoshka-tk-implementation-plan-NNN.md`, not separate files.
- Collapse done stages to one-line summaries. Keep active and future stages in full detail.
- Old plan versions stay as historical record. Do not delete them.

Document versioning.
- Never overwrite any doc. Create a new file with incremented suffix.
- All docs require a version suffix (-001, -002, ...). No exceptions.
- Doc link rule: after creating any new doc version, update all cross-references to the old version in every other doc. No exception. Owner never does this manually.
- `design/context.md` is the stable entry point.

Stage discipline.
- Read `design/STATUS.md` Session Log first.
- Show intent before code. Owner approves before code is written.
- Plan approval is NOT code change approval. Each fix needs its own approval.
- One stage at a time. No skipping. Each stage passes before the next.
- No real code before infrastructure (Stage 0) is verified.
- Tests before examples. Stage N.a = impl + tests. Stage N.b = examples. No mixing.
- Architectural changes need explicit owner approval.

Implementation invariants.
- Source of truth for signatures, types, errors: the current API reference. Wins over all other sources.
- Never send a stack-allocated item. Use `alloc.create` or `pool.get`.
- After transfer (`send`, `put`), `slot.* = null`.
- After `close`, walk the returned list. Free heap items or return pool items.
- `mailbox.close`, `pool.close`, `pool.put`, `pool.put_all` use `lockUncancelable`.
- Never use `std.Thread.Mutex` / `std.Thread.Condition` in `_Mailbox` or `_Pool`.
- `error.Canceled` is never remapped to `error.Closed`.
- `condition_waitTimeout` is a private helper copied from the legacy mailbox (codeberg/zig#31278).

---

## Implementation invariants

`ItemList` and `polynode.reset`. (API 8)
- `std.DoublyLinkedList` does nothing for node safety. Any removal (`remove`, `pop`, `popFirst`, or any variant) does NOT zero `prev`/`next` on the removed node.
- `ItemList.popFirst` does. It calls `polynode.reset` before returning, so a popped `ItemHandle` is never linked.
- This is a property of the type, not a rule the developer carries. It replaces the former "call `reset` after every removal" rule, which was obeyed at 13 of 34 sites and cost a real bug (`_add_returned_item`, composite lists of 3+ items).
- `polynode.reset` stays public. It is needed by hand in exactly one case: items taken out through `ItemList._list`.
- `ItemList._list` is the raw field. While a caller uses it, the `ItemList` promises are suspended. Tests that manipulate raw links use it; application code does not.

`*std.DoublyLinkedList.Node` is not `*PolyNode`. (API 8)
- From the langref, `struct` section: "Zig gives no guarantees about the order of fields and the size of the struct but the fields are guaranteed to be ABI-aligned." And: "Struct field order is determined by the compiler, however, a base pointer can be computed from a field pointer."
- `PolyNode` is a plain struct. `node` written first says nothing about its offset.
- `@ptrCast` between the two pointer types is unsound, even where it compiles and appears to work.
- `@fieldParentPtr` is the only defined conversion.
- Rule: `@fieldParentPtr` appears in `src/polynode.zig` and in the raw-link tests of `tests/layer1_polynode.zig`. Nowhere else. The closing gate is `grep -rn "fieldParentPtr" src/ tests/ examples/ stories/`.

---

## Matryoshka Coding Patterns

The pattern catalog lives in [patterns-025.md](patterns-025.md).

- Observable function shapes: coordinator / step / init / destroy / Select event loop / spawn-await.
- Description as code: example/story doc comments follow the same coordinator/step shape.
- Pool modes, seeding, backpressure, hooks.
- Io.Select event loop and re-register.
- Io.Group worker sets and shutdown.
- Graceful shutdown ordering.
- Polymorphic dispatch, item-first and tag-first.
- Error handling on receive (Closed/Timeout vs Canceled).
- Master composition.

- Rules constrain.
- Patterns reuse.
- Read the catalog for code shapes.
- Read this doc for what is mandatory.

---

## Dispatch chains end with a final branch — MUST

Every `fromPoly` or `isIt` chain writes its last `else`.

The trailing branch is optional to the compiler. Leave it out and an item whose  
tag nobody claimed falls through in silence. `items.freeItem` did exactly that  
until DISPATCH 1 fixed it.

What goes in it:

- Closed set, every helper present in the chain — `unreachable`. Reaching it
  means the caller passed something that cannot exist.
- Open set, a mailbox anyone can send to — count it, log it, or return an
  error. Then move on.

It cannot free the item. `alloc.destroy` takes `*T`, and the allocator needs the  
size to release the memory. With no type there is no size. An unknown item can  
only be dropped or reported; its memory belongs to whoever knows what it is.

Catalog: [patterns-025.md](patterns-025.md), "The last branch of a dispatch  
chain".

---

## The transfer rule for dispatch handlers — convention, not a MUST

Applies to a handler stored in a dispatch table:

> On return, the Slot is null if the handler took the item, full if it did not.

`src/` cannot enforce this and does not care. It is a convention between the  
person writing a handler and the person writing the loop that calls it, and it  
is written down here because both are often the same person a month apart.

A handler may take the item, forward it, or look and leave it. What it must not  
do is leave the Slot lying about which.

The loop covers every case with one line:

```zig
defer items.freeSlot(&slot, allocator);   // no-op when null
```

A handler may also move the item and *then* fail. The Slot reports where the  
item is; the error reports whether the work succeeded. They are two different  
questions, and a caller that frees on error without looking at the Slot  
double-frees.

Where it is written: the doc comment on `TagTable.Handler`, and  
[patterns-025.md](patterns-025.md), "Polymorphic dispatch — table".

Detail: [table-dispatch-001.md](table-dispatch-001.md).

---

## No switch over tags — MUST

Dispatch on a tag with `isIt` or `==`, never with `switch`.

```zig
// WRONG — accepted by the front end, then fails in the backend
switch (handle.*.tag) {
    EventPolyHelper.TAG => ...,
    else => ...,
}

// CORRECT
if (EventPolyHelper.isIt(handle.*.tag)) {
    ...
} else {
    ...
}
```

A switch prong must be known at compile time. A tag is the address of a global,  
and the linker assigns that address, so the value is not known while compiling.  
Zig accepts the source and the backend then fails — LLVM rejects the emitted  
bitcode, or the self-hosted backend crashes or hangs. `@intFromPtr` is refused  
wherever a compile-time value is required, including as a container-level  
`const`.

`isIt` and `==` need only to know which global the tag names. That the compiler  
does know.

Detail, with the build matrix: [llvm-pointer-switch-bug-001.md](llvm-pointer-switch-bug-001.md).

---

## Markdown hard-break rule — MUST

CommonMark collapses two lines separated by a single newline into one  
rendered line (soft break -> a space). A staccato-style two-line effect  
survives only two ways:

- The first line ends with two-or-more trailing spaces (a hard break).
- The two lines are separated by a blank line (separate paragraphs).

Rules:

- Prefer a blank-line-separated short paragraph over a same-paragraph line
  break wherever the intent is a readable separate line. This avoids  
  trailing-space fragility and matches the existing bullet-heavy style.
- Where a genuine intra-paragraph hard break is wanted (two lines that must
  stay in the same paragraph), the first line MUST end in two-or-more  
  trailing spaces.
- List items, headings, blockquotes, table rows, link/image reference
  lines (badges, shields, footnote-style refs), and fenced code content  
  are exempt — a following non-blank line after these is normal Markdown  
  syntax, not a soft-break hazard.
- Enforced by `kitchen/tools/fix_md_hardbreaks.sh`, connected to
  `build_site.sh` and `preview_site.sh` the same way  
  `kitchen/tools/fix_md_lists.sh` enforces the blank-line-before-list rule.  
  It runs automatically as part of the build/preview pipeline, not  
  standalone.
