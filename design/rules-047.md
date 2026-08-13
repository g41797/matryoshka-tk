# Matryoshka Zig — Rules (047)

All coding, doc, and process rules for the project.  
Change from -046: API 13-4 — the custody-sense glossary entry now covers both  
words and is scoped away from the architecture doc's Hold vocabulary. The  
carve-out for the old MBOX 1 framing is retired, because `src/` no longer  
uses it. Two Part 8 sentences reworded to match.  
Which stage introduced which rule is Part 10.

Companion: [matryoshka-concepts-002.md](matryoshka-concepts-002.md) — the concepts and the thinking model.  
Companion: [patterns-028.md](patterns-028.md) — reusable coding patterns.

---

## Part 0 — Every session

Read this part every session. The rest is reference; jump to the part you need.

Hard gates.
- No git. Every git operation goes through the owner.
- No file deletions. Ask the owner.
- Show intent before code. The owner approves before code is written.
- Plan approval is NOT code change approval. Each fix needs its own approval.
- Architectural changes need explicit owner approval.
- One stage at a time. No skipping. Each stage passes before the next.
- No real code before infrastructure (Stage 0) is verified.
- Tests before examples. Stage N.a = impl + tests. Stage N.b = examples. No mixing.

Documents.
- Never overwrite any doc. Create a new file with an incremented suffix
  (-001, -002, ...). All docs require one. No exceptions.
- Doc link rule: after creating a new version, update every cross-reference to
  the old version in every other doc. The owner never does this by hand.
- A bulk repoint excludes `design/STATUS-LOG.md`. A past entry names the version
  that was current when it was written, and that is the fact it records. A  
  `grep -rl ... design/ | xargs sed` rewrites it silently — API 13-3 did exactly  
  that, changing `-039` to `-040` inside a finished entry from earlier the same  
  day. Name the files, or exclude the log.
- Two files are updated in place instead: `design/STATUS.md` and
  `design/context.md`, the stable entry points.
- Read `design/STATUS.md` first. It is current state, not history.

Verification.
- Run kitchen scripts, not manual `zig` commands.
- Order: `build_and_test_debug.sh` → `build_and_test_all.sh` → `build_cross_debug.sh`.
- Build before test. `zig build` must pass before `zig build test`.
- Full verification = all four modes: Debug, ReleaseSafe, ReleaseFast, ReleaseSmall.
- A stage is complete only when all four pass.
- Redirect output to `zig-out/` log files. Read the log file. Not shell stdout.

Status file ownership.
- Four files carry project state. A fact lives in exactly one. The others get a
  pointer, not a copy.
- `design/STATUS.md` — current state only. Rules, constraints, sources of truth,
  decisions, open items, test count, next stage. No narrative, no history. It  
  holds steady across stages; it never grows by accretion.
- The plan — forward-looking work, plus one line per completed stage.
  "Collapse done stages to one-line summaries" means one line, not one paragraph.
- `design/STATUS-LOG.md` — the narrative. A stage's full account is written here
  and nowhere else. Append-only, newest at top. Not read by default, so its size  
  costs nothing.
- `design/context.md` — one short line per doc: the link, then what the doc is.
  Not the doc's changelog.
- Before deleting stage text from `STATUS.md` or the plan, confirm the same
  content is in `STATUS-LOG.md`. Grep by stage name. Text with no log entry is  
  moved there, not dropped.

Per-stage finish checklist.
1. `kitchen/build_and_test_debug.sh` — quick build + Debug test.
2. `kitchen/build_and_test_all.sh` — full build + all four optimization modes.
3. `kitchen/build_cross_debug.sh` — cross-compile Debug for mac + windows.
3a. If the stage touched `build.zig`'s `docs` step or anything under  
    `examples/`/`stories/`/`src/`: run `kitchen/tools/preview_site.sh` and do the  
    rendered-page check in Part 4, "Doc target size". `zig build docs` exiting 0  
    does not catch the stuck-Loading crash.
4. Post-stage cleanup: revise code for obsolete parts, wrong comments, repeated
   code that can be extracted.
5. Re-run all three kitchen scripts after cleanup.
6. Scan changed `.zig` files for patterns not yet in
   [patterns-028.md](patterns-028.md). Report candidates to the owner. The owner
   decides. Do not auto-document, do not auto-extract.
7. Banned-word scan over changed `*.md` and `*.zig` — Part 5. Report to the
   owner. Do not fix without approval.
8. Close the stage across the three status files, per Status file ownership above.
   - Append the narrative to `design/STATUS-LOG.md`, newest at top. Include a
     "Post-stage cleanup" row. Absence of that row means the rule was skipped.
   - Add one line to the plan's "Completed stages".
   - Update `design/STATUS.md` "Current state" and "Next". Nothing else.
9. Sync `README.md` and any touched per-module README.
10. Rules audit: audit every changed `.zig`/`.md` file against every rule in this
    document. Report violations to the owner before closing the stage.

New plan version.
- Create a new plan version after each completed stage or INTR.
- Plans are new versions of `design/matryoshka-tk-implementation-plan-NNN.md`,
  not separate files.
- Keep active and future stages in full detail.
- Old plan versions stay as historical record. Do not delete them.

---

## Part 1 — Structure of code

### Observable by human — MUST

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

Structural extraction signals — always violations, no comment needed to trigger.
1. Any `while` loop with a `switch` body inside a coordinator.
   - Name: `runEventLoop`, `eventLoop`, or domain equivalent.
   - The loop is the step. Extract it regardless of length.
2. Any `Io.Select` setup block inside a coordinator (`buf` + `sel.init` +
   `sel.concurrent` calls).
   - Name: `setupSelect`, or fold into `runEventLoop` if trivially short.
   - `buf` and `sel` are declared at coordinator scope and passed as `*Sel` to
     steps, or held as struct fields in a Master.
3. Any cluster of `io.concurrent` / `group.concurrent` / `Thread.spawn` calls
   inside a coordinator.
   - Name: `spawnWorkers`, `runWorkers`, `spawnSenders`, or equivalent.
   - `await` calls belong in the same step or in a paired `awaitWorkers` step.
4. Any for-loop or sequential block that sends, fills, or seeds items inside a
   coordinator.
   - Name: `sendItems`, `fillMailbox`, `seedPool`, `sendEvents`, or equivalent.

Step function parameters.
- Pass only state that is transient between specific steps — output of one step,
  input to the next.
- State shared by the coordinator and most steps belongs in a struct field.
  - Masters: `self.field`. Already in the struct, no parameter needed.
  - Flat coordinators with 3+ shared params: introduce a local value struct. No
    heap allocation.
- A step function with 3+ parameters that are all coordinator-scope state
  signals: introduce a struct.
- Simple extractions with 1-2 params: explicit parameters are fine.

Applies to all code: `src/`, `helpers/`, `examples/`, `tests/`, `stories/`.  
Small functions with no distinct phases need no extraction.

### One quality bar

Tests, examples, and stories follow one quality bar.
- Same bar as production code: structured, reusable, well-named.
- No throwaway code in any category.
- Quality, modularity, and naming are identical to production code.

They differ only in visibility and job.
- Tests check correctness. Internal. Not in generated docs.
- Examples show one pattern. Part of generated docs.
- Stories show matryoshka thinking across multiple layers. Part of narrative docs.

The difference is the job, never the quality.

### The Master pattern

A Master is a coordination boundary.
- It owns its resources: mailboxes, pools, allocator, application state.
- It coordinates startup order, shutdown order, and cancellation policy for those
  resources.
- An `Io.Select` loop is a Master. An `Io.Group` of workers under one coordinator
  is a Master.
- There is no required Master struct or interface. The responsibility defines it,
  not the type.

When to stay flat.
- Minimal functionality: one loop, one action per iteration.
- All state fits in local variables.
- Short lifecycle: exits cleanly on close or cancel.
- No shared state between steps.

When to allocate a Master.
- Multiple steps or phases with state shared between them.
- Complex lifecycle: distinct init / work / shutdown phases.
- `run` needs named private steps to remain readable.
- Growing functionality that would make a flat function hard to follow.

Master struct shape.
- `init(allocator, io) !*MasterXYZ` — allocates on heap, acquires all resources,
  can fail.
- `destroy` — releases resources in correct order, frees the allocation last.
- `run` — readable main flow: sequenced calls to private step functions.
- Private functions — each implements one internal step.
- Fields — shared state between steps; replace scattered locals.
- The entry point and `run` sit at the top of the file — see Part 4, "File layout".

```zig
pub fn <snake_case>(allocator: std.mem.Allocator, io: std.Io) !void {
    const master = try MasterXYZ.init(allocator, io);
    defer master.destroy();
    try master.run();
}
```

The same two-tier rule applies to worker functions inside any example or story.  
Canonical reference: `examples/layer4/018-master_with_pool.zig`.

### Master composition in stories

A story composes Masters.
- A story composes more than one Master.
- Each Master is its own structured unit: a Master struct allocated on the heap.
- A Master's `run` does the coordination: receive, dispatch, re-spawn, shut down.
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

## Part 2 — Rules by category

Shared structure is Part 1. Only the differences are here.

### Tests

What a test must do.
- Check correctness of the implementation.
- Cover one behavior at a time.
- Cover edge cases, error paths, state transitions, contract violations.

What a test must not do.
- No throwaway code.
- No story flows. That is the job of examples.

Allocator and io source.
- Tests supply `std.testing.allocator`.
- Tests supply `std.Io`, usually via `std.Io.Threaded.init`.
- Tests set `std.testing.log_level = .debug`.
- Tests use `testing.expect` for verification.

### Examples

Checks.
- Use `helpers.expect(error.XxxFailed, condition, "description")` for invariants.
- It works in all build modes. `std.debug.assert` is removed in ReleaseFast and
  ReleaseSmall.
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
  description: lowercase, words joined with `_`.
- Never a quoted identifier (`@"..."`). Zig's autodoc viewer cannot resolve
  declaration links for quoted identifiers, and the generated `examplesdocs` page  
  for that example breaks.
- The staccato description text itself is unchanged and still lives verbatim as
  the first line of the file's `//!` doc comment.
- The Master's own private `run` is unaffected. This rule targets the public
  entry point.
- `//!` doc comment at the top of the file. No doc comment = not done. See Part 4.
- Show correct resource cleanup. `errdefer` on error paths, `defer` on all-path
  cleanup.
- Examples become docs. Leaky examples teach leaky habits.
- Reference model: tofu `recipes/cookbook.zig`.

Completeness.
- Show where work input originates: caller seeds, network provides, timer
  triggers, worker's own accumulated state.
- Show what the worker does with a pool resource and any additional input.
- Show where results go after processing.
- A lifecycle-only example (get → put, no input source, no output destination) is
  not complete.
- Pool items are empty containers on acquisition. Work intent must come from
  outside the pool item.
- See "Pool items are empty containers" in
  [matryoshka-concepts-002.md](matryoshka-concepts-002.md).

### Stories

- Signature: `pub fn run(allocator: std.mem.Allocator, io: std.Io) !void`.
- Must show multiple layers composing into a real flow.
- `///` doc comment at the top of the file: staccato description + ASCII transfer
  circuit diagram. See Part 4.
- Test wrapper in a single `tests/stories_test.zig`, using `std.Io.Threaded.init`.
- SPDX header required if the file sits under `src/`; the owner adds SPDX headers.
- Stories always use the Master pattern. A story is never a flat function.
- Story narrative uses the 4-part structure: architecture dialogue, SRS,
  matryoshka translation, flow diagram.

Story file layout — MUST.

Each story is a mini-project. Two artifacts plus one shared test file.

- Narrative: `design/stories/name-NNN.md`.
  - Part 1 — Arch Design. Domain problem. Architect dialogue: constraints,
    tradeoffs, decisions. Result: bounded scope, defined boundaries.
  - Part 2 — SRS. Numbered requirements, one per bullet. Domain language, not
    Matryoshka language.
  - Part 3 — Matryoshka Translation. Map each requirement to a concept.
    Programmer dialogue preferred: it shows the reasoning, not just the result.
  - Part 4 — Flow Diagram. Full system ASCII diagram. All layers, all transfer
    flows, all event sources. Diagram only. No prose.
- Code: `stories/name/name.zig`.
  - ASCII transfer circuit diagram at the top of the file.
  - Code is structured around Masters. See [patterns-028.md](patterns-028.md)
    for the Master composition pattern.
- Test wrapper: `tests/stories_test.zig`. Single file, all story wrappers.
- What qualifies as a story: at least two layers composing, and a real domain
  problem. See [matryoshka-concepts-002.md](matryoshka-concepts-002.md),  
  "Three-category model".

---

## Part 3 — Zig style

Import order (LE style).
- "LE" means "little-endian" — imports are placed at the bottom of the file,
  after the code.
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
- Do not add SPDX headers to new `src/` files. The owner will.

Layer terminology.
- Use "layer" not "block" everywhere — docs, tests, examples, directories.
- Exception: Odin reference paths (`block1/`, `block2/`) are quoted literals
  naming Odin's own directories.

Handle naming.
- `ItemHandle` is the canonical name for `*PolyNode`. It supersedes `NodeHandle`,
  which leaked the intrusive-list-node implementation detail into a name meant to  
  describe what the caller holds.
- Short variable name: `ih`.
- Bare `handle` is acceptable informal shorthand in prose and comments once the
  type is clear from context.
- `MailboxHandle` / `PoolHandle` are unaffected — they already name the role, not
  the implementation.

Accessor naming.
- A name says what the caller does, not how the helper works.
- Inspection is `fromPoly` / `fromSlot`. It never empties a Slot and never
  modifies a Node. `fromSlot` takes `*const Slot` so it cannot.
- Extraction is `moveFromSlot`. It always empties the Slot on success, and leaves
  it unchanged on failure.
- No `As` suffix. The type is already the namespace:
  `EventPolyHelper.fromSlot(&slot)`.
- A helper that mutates its argument gets no `must` variant. Hiding failure behind
  `unreachable` would make the state change less obvious. This is why  
  `moveFromSlot` has none while `fromPoly` and `fromSlot` do.
- Every consuming operation asserts the item is not linked into a list.

General style.
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
- Cleanup ops (`pool.put`, `PolyHelper.destroy`, `helpers.freeSlot`) are no-ops on
  null slots.
- Use defer-before-acquisition — safe because cleanup is null-safe.
- Never use `allocator.create` / `allocator.destroy` directly on PolyNode-based
  user types in examples or tests. Use `PolyHelper.create`, `PolyHelper.destroy`,  
  or `helpers.freeSlot`.
- Exception: `receiveResult` and `getWaitResult` hand the item over through the
  returned union value, not a `*Slot`. The caller extracts the handle and holds it  
  from that point.

---

## Part 4 — Comments, doc comments, autodoc

### What a comment says

Staccato applies here. It is defined once, in Part 6, and covers comments, doc  
comments, and documents alike.

Comment-specific rules.
- Do not explain WHAT — names do that.
- Explain WHY only if non-obvious.
- No multi-paragraph docstrings.
- No "used by X" / "added for Y flow" comments.
- No references to design docs (`.md` files) inside `src/*.zig` comments.
  - Readers of source or generated docs only see the `.zig` files.
  - Comments must be self-contained. Explain the fact, do not point at a doc.
- File-header `//!` standard: model on `std.Io`'s own file header.
  - A header that reads as one run-on paragraph across several `//!` lines is a
    violation even if each individual line is short.
  - Applies to any doc comment, not just headers, naming more than one fact.

### `///` and `//!` in `src/`

- Both are allowed in `src/`.
- `//!` at the top of each file: high-level module description.
- `///` on every `pub` declaration: function, type, error set, const.
- `examples/` and `stories/` entry-point functions keep their own rule below.

First-declaration doc-stub rule.
- If a file's first declaration after the `//!` header carries a `///` doc
  comment, Zig's autodoc container page splices that comment onto the module  
  overview page with no separator, regardless of blank lines.
- Fix: insert `const _doc_stub = void;` — no doc comment, non-`pub` — as the first
  declaration after the `//!` header. It absorbs the splice. Being undocumented  
  and private, it does not appear in the rendered docs at all.
- Only needed when the first declaration would otherwise carry a `///` comment.
  A file with no `///` comments at all needs no stub — that is every `examples/`  
  and `stories/` file, where the description lives entirely in `//!`.
- Verify by rendering the page, not by reading the source. A source-level fix here
  is unverifiable without checking the actual rendered page.

Documented asserts must exist — MUST.
- A doc page or reference section that lists "Assert:" entries lists only
  asserts present in `src/`. Copy them from the source, do not infer them  
  from what the function ought to check.
- MBOX 1 found 15 entries of the form `mailbox.is_it_you(mbx.*.tag)` /
  `pool.is_it_you(pl.*.tag)` across the api pages and the API reference. No  
  such assert exists, and neither struct has a `.tag` field, so the line  
  could not compile as written. It survived because nothing compiles a doc  
  page.
- The check is a grep of the documented assert against `src/`, run by whoever
  edits the page.

### Description as code — MUST

An example's or story's description is written like its code, not like prose about  
its code.

Applies to.
- Every `//!` description block at the top of an example's or story's file.
- `task1-examples-*.md` / `task2-examples-*.md` catalog entries.

Same shape as Observable by human.
- One-line intent — what the example demonstrates. This is the coordinator line.
- Named steps as bullets — one step per bullet, in the order they run.
- A bullet names a step the same way a step function is named: what it does, not
  how.
- No single long sentence chaining multiple facts with commas. That is an
  unextracted block, the same violation as an unextracted code block.
- Staccato applies. Part 6.

Placement — `//!`, not `//`, not `///`.
- The description + ASCII transfer diagram is a `//!` doc comment at the very top
  of the file, directly after the SPDX header, before any declaration.
- `//!` is autodoc-extractable and renders on the file's own container page. Plain
  `//` is not extracted at all.
- Every example file has exactly one public entry point, so the file-level `//!`
  is sufficient.
- Mixing `//!` and `///` above the same function is a bug, not a style choice.
  They are different token kinds to the autodoc parser, and the function's own doc  
  silently truncates to whichever kind sits immediately above it.
- If the example uses a Master, the Master's `run` is the real coordinator, but it
  is private (`fn`, not `pub fn`) — no doc comment on it. Its steps are still  
  named, per Observable by human.

ASCII diagrams — fenced code block.
- Any ASCII diagram inside a `//!` block is wrapped in a ` ``` ` fenced code
  block: ` ``` ` on its own `//!` line, the diagram lines, then ` ``` ` on its own  
  `//!` line to close.
- Reason: the autodoc viewer renders doc comments as CommonMark, which collapses
  single line breaks into one flat paragraph. A fenced or 4-space-indented block  
  is the only way box-drawing diagrams keep their shape.
- Trailing prose after a diagram stays outside the fence, as a normal paragraph.

File layout — flow descriptors at the top.
- The entry point (`pub fn <snake_case>`) sits at the top of the file, directly
  after the `//!` description + diagram block.
- Where a Master exists, its `run` method also moves up, directly after the entry
  point, ahead of struct fields, `init`, `destroy`, and step functions.
- These two functions are the file's flow descriptors. A reader sees the whole
  shape first, then drops into detail only if needed.
- Imports stay at the bottom (LE style, unchanged).

Catalog docs are an index, not a copy.
- One line per scenario: number, name, one-line hook, link to the source file.
- The full staccato description lives in the source `//!` block only.
- Do not duplicate the description in both places. The source is the single source
  of truth; the catalog routes to it.

### Exclusive access, in comments

No "ownership" / "ownership transfer" / "owner" language in `src/` comments. Too  
abstract, reads like a computer-science paper.
- Say what happens: an operation sends an object, a handle, or a slot from one
  place to another.
- The invariant to state: an object sits in exactly one place, in exactly one
  state, at any moment. Not "one owner".
- Staccato style allows an extra bullet line if plain language needs more room
  than the abstract term did.

The transfer also orders memory.
- The holder that receives an item sees every write the previous holder made
  before the transfer.
- Mailbox and pool publish through their own mutex. The mutex carries the ordering.
- Consequence: a holder reads and asserts on the item's fields with plain loads.
  No atomics, no fences.
- This is what the `is_linked` / `prev` / `next` asserts rest on. Without it they
  would be data races, not checks.
- Limit: the guarantee covers an item that has been transferred. It says nothing
  about an item two holders both believe they hold — that mistake breaks the  
  premise, so no assert can catch it.
- State this in `src/` comments as "the previous holder's writes are visible", not
  as a memory-model term.

The neighbour check.
- `polynode.is_linked` reads `prev` and `next`. It answers "does this node have
  neighbours", not "is this node in a list".
- `std.DoublyLinkedList` never sets the links of a list's only member, so a list of
  exactly one reports false.
- The seven `!is_linked` asserts in `src/` are kept. They catch the multi-element
  case, which is where most real double-sends land, and they are blind for a list  
  of one.
- Do not write a comment, a doc line, or a test name that presents the check as a
  membership test. Say "has neighbours".
- Nothing repairs it. State kept in an item cannot validate this class of mistake
  — reading that state needs the exclusivity whose absence is the bug.
- Two checks are exact. Neither reads the item.
  - `ItemList._holds` walks the list it already holds under its own lock, and
    compares addresses instead of reading the item. Runtime safety only.
  - `concat` compares its two arguments; `appendFromSlot` reads a `Slot` in the
    caller's own frame.
- Prevention beats detection. `appendFromSlot` / `prependFromSlot` empty the slot
  themselves, so there is no `slot = null` line left to forget.

### Doc target size

Keep every `zig build docs` target small.
- `build.zig`'s `docs` step must never root a doc target (`b.addObject` +
  `getEmittedDocs()`) at a module whose transitive import graph spans a large  
  tree.
- A combined target like that makes the Zig autodoc client (`main.wasm`) hang
  forever on "Loading..." in the browser, throwing  
  `Uncaught (in promise) RangeError: Maximum call stack size exceeded`.
- `apidocs` (rooted at `src/matryoshka.zig`) stays well under this size and needs
  no special handling. The rule applies to any future target.
- Precedent: the repo hit this once with a combined `examples/` autodoc target,
  and so did the sibling `tofu` repo. See `STATUS-LOG.md`, CMPCT 2 entry.

Verifying a doc target.
- `zig build docs` exiting 0 is necessary but not sufficient. It catches neither
  bug class on its own.
- Load the generated page in a real or headless browser and check the console for
  `RangeError` / `Uncaught`.
- Check `tar tf kitchen/docs/<target>/sources.tar` for files outside that target's
  own area. `getEmittedDocs()` can leak sibling files into the wrong target's  
  source browser.
- Required whenever `build.zig`'s `docs` step or anything under
  `examples/`/`stories/`/`src/` changes: run `kitchen/tools/preview_site.sh` and  
  do both checks for every doc target.

### Live-scan rule

- A scan — banned words, terminology bans, `.md`-reference check, staccato check —
  is only "done" when re-run live against current file contents at the moment of  
  the claim.
- A prior pass's claim of completion is not sufficient. Re-run the grep yourself
  before reporting a scan as complete.
- Reason: a pass has claimed completion and been wrong. See `STATUS-LOG.md`,
  CMPCT 2 entry.

---

## Part 5 — Banned words

Scan `.zig` and `.md` after any stage that changes them. Report hits to the owner.  
Do not fix without approval.

Four words are also enforced automatically, by the glossary gate in  
`check_design.sh`: `MayItem`, `Block N`, `ownership`, `ledger`. The rest of  
this list is the manual scan. A word in the automatic set still belongs here —  
the gate covers `design/*.md` only, not `src/`, `tests/` or `examples/`.

Scan scope. Skip `design/STATUS-LOG.md`, `design/secondary/` and  
`kitchen/defer/` — all three are append-only or frozen, and rewriting them  
destroys a record. In the files that remain, a changelog row that names a  
banned word to record its earlier removal stays as it is; the row exists to  
say the word is gone. Stdlib names such as `ensureTotalCapacity` are not  
hits. A banned word inside a file name is an owner decision, not a fix.

Scan this rules file against its own ban. The rule text has to name the banned  
word to ban it, so a scan that skips `rules-0NN.md` misses the document most  
likely to repeat it — which has happened. See `STATUS-LOG.md`, CMPCT 2 entry.

Words.
- `drain` — use `clear`, `reset`, `empty`, or a domain verb. `clearList`, not
  `drainList`.
- `dll` / `DLL` — clashes with Windows DLL. Use `List.Node`, `list_node_ptr`, or
  spell out `DoublyLinkedList`.
- "commit" when meaning save / update / write — implies git, which is owner-only.
  Say "save", "update", or "write".
- `seam`, `seamless` — use "boundary", or name the two things that meet.
- `sweep` — say what the work is. "Search and replace across the repo", "re-read
  every call site", "scan `.md` files".
- `settle`, `settled` — use "agreed", "decided", or "the owner accepted it".
- `underneath` — name the thing. "The plain std list", or the field name.
- `on purpose` — as a defence of a design choice it explains nothing. Give the
  reason, or state who does it.
- `hatch`, including "escape hatch" — a metaphor where a plain description
  belongs. Name the field: "the `_list` field", "reaching through `_list`".
- `lifecycle` — AI-sh, and it says nothing a reader can act on. When the
  subject is how a mailbox or a pool is created, used and taken down, the  
  section is called **Usual flow**. When the subject is what state an item is  
  in, say **item states**.
- `ledger` — a book-keeping metaphor for a plain list. Say what the list is.
  - The plan's per-stage line: "one line per completed stage".
  - A record of what moved and where: "carry-over note", or name the two  
    places.
  - Owner's ban, API 13, 2026-08-13.
  - Enforced by the glossary gate in `check_design.sh`, not by the manual scan  
    alone.
- `hands`, as in "a closed pool hands items back" — use `gives back`,
  `returns`, `passes to`, or name the receiver. `holds` in the custody sense  
  goes the same way; prefer `keeps`, `has`, or `contains` for a container.  
  API 13-4 reworded both across `src/`, and the MBOX 1 framing with them: it  
  now reads "The mailbox keeps items. It never touches them." The carve-out  
  that exempted the old wording is retired.
  - Scoped to the custody sense. `hold`/`holder`/`held` in
    [matryoshka-architecture-foundation-4-006.md](matryoshka-architecture-foundation-4-006.md)  
    is the deliberate replacement for the banned `ownership` family, chosen  
    on 2026-07-09, and names sections and the `HELD` state. It stays.

AI-sh word list.
- robust, seamlessly, comprehensive, leverage, efficient, powerful, facilitate,
  utilize, ensure, performant, ergonomic, idiomatic, streamline, orchestrate,  
  sophisticated, intuitive, scalable, unlock, empower, harness, deliver, fed, arm,  
  leg, idempotent, fires, faces, pitch, object model, execution context, execution  
  model, programming model, paradigm, mindset, ownership, gained, wire, wired,  
  wires, wiring.
- For the `wire` family use "connect", "add to nav", "hook up", or the concrete
  action.

Scoped ban.
- "object" when referring to an Item or ItemHandle — the application data an
  ItemHandle wraps. Use "item" or "ItemHandle". Does not ban "object" elsewhere in  
  prose or code.

Replacements for `ownership`. Name the action instead.

| instead of | write |
|---|---|
| transfers ownership | transfers the item / the item moves |
| caller retains ownership | the caller keeps the item |
| ASCII ownership diagram | ASCII transfer diagram |
| exclusive ownership | exclusive access |
| ownership circuit | transfer circuit |
| ownership path | transfer path |

---

## Part 6 — Writing documents

### Where a doc lives — MUST

`design/` shows what Matryoshka is. Nothing else.

A doc belongs in `design/` when it describes the current state of the toolkit:  
the concepts, the API, the rules, the patterns, the architecture, the Zig  
details, a design note behind a decision that is live in `src/`, or the tests  
and examples index.

A doc belongs in `design/secondary/` when it is any of these:
- a state snapshot — `STATUS.md` already owns current state
- a superseded draft of something that now exists in finished form
- a session log of a past stage — `STATUS-LOG.md` already owns the narrative
- a process or tooling note rather than a design statement
- an intention nobody has started

`kitchen/defer/` is frozen too. It is deferred material: drafts and notes that  
were never finished and are absent from `mkdocs.yml` nav, so nothing in it  
ships. Treat it exactly like `design/secondary/` — not updated, links not  
repaired, never a source of truth. Its code snippets predate API 12 and must  
not be copied from.

Rules for the split.
- A doc in `design/` may link down into `design/secondary/`.
- A doc in `design/secondary/` is frozen. It is not updated. Its own links are
  not repaired.
- Nothing in `design/secondary/` is a source of truth. If the two folders
  disagree, `design/` is right.
- Every file in either folder is listed in exactly one index: `design/context.md`
  or `design/secondary/context.md`. A file in neither is an orphan and is a  
  violation.

Present tense — MUST.
- A doc in `design/` describes what is, not what will be.
- No "downstream docs get rewritten later". No "this will be replaced in a later
  stage". No "planned for".
- Forward-looking work belongs in the plan. Intentions nobody has started belong
  in `design/secondary/`.
- A doc that describes a future state of the documentation is drift. It is the
  thing this rule exists to prevent.

Retiring a doc.
- Merging several docs into one, or moving a doc to `design/secondary/`, is not
  overwriting. The never-overwrite rule in Part 0 does not apply.
- Deleting a doc still needs owner approval, per the Part 0 hard gate.
- Git history is the archive. A doc that has been merged into a successor does
  not need a copy left behind.

### The design gate — MUST

`kitchen/tools/check_design.sh` gates any stage that touches `design/`, the way  
`kitchen/build_and_test_debug.sh` gates a code stage. Exit 0 or the stage is not  
done.

Four checks:

- **Dead cross-references, in both syntaxes.** The markdown-link form and the
  backtick form. The backtick form is the one that rots unseen — DOC 22  
  swept the folder by hand, checked only markdown links, and left 23 dead  
  backtick refs behind.
- **Orphans.** Every file under `design/` is named in `context.md` or in
  `secondary/context.md`.
- **Forward-looking prose.** `design/` says what is, not what will be.
- **Glossary conformance.** Retired vocabulary must not come back. `MayItem` is
  `Slot`. The four things are Layers, not Blocks. Hold and transfer, not the  
  ownership family.

Exemptions, all narrow:

- `secondary/` is exempt from all but the orphan check. It is frozen.
- `STATUS-LOG.md` is exempt from all but the orphan check. It is an append-only
  historical narrative and legitimately names docs that no longer exist.
- A change-log row may name the doc it replaced. That name is the
  point of the row.
- `kitchen/tools/.check_design_allow` holds literal substrings for the handful of rows
  that record a past banned-word pass. Adding to it needs a reason written in  
  the file. It is not a place to silence a real hit.

### Staccato — the one definition

Applies everywhere text is written: documents, comments, doc comments, example  
descriptions. Parts 1, 2 and 4 point here.

- A document is not a novel. Do not use prose style.
- Use simple English. Use short sentences.
- Start with a short introduction, then a bullet list. Keep the introduction short.
- One fact per bullet. Prefer bullets over long paragraphs.
- No prose paragraphs with comma-separated lists. No dense multi-fact sentences.
- Do not chain multiple ideas into one sentence.
- LONG SENTENCES DISABLED. Break a long sentence into several short sentences, one
  line each, or into bullets. No prose. Ever.
- Bullet nesting: when a bullet splits at a colon, at "and", or into multiple
  sub-items, demote each part to a nested bullet, one level deeper, one item per  
  line. Do not cram a comma-list onto one line.
- Do not replace bullet lists with many standalone one-line sentences. That is
  padding, not rhythm.

Diagrams.
- Use ASCII diagrams. Make them human-readable.
- Do not optimize diagrams for compactness.
- Prefer clarity over brevity. Do not save space in files.

Structure.
- Cross-reference instead of duplicating.
- When extending an existing document, match the heading levels already in use.
- Link to [matryoshka-concepts-002.md](matryoshka-concepts-002.md),
  [patterns-028.md](patterns-028.md), and this file.

Markdown hard breaks — MUST.
- CommonMark collapses two lines separated by a single newline into one rendered
  line — a soft break becomes a space.
- A staccato two-line effect survives only two ways: the first line ends with two
  or more trailing spaces, or the two lines are separated by a blank line.
- Prefer a blank-line-separated short paragraph wherever the intent is a readable
  separate line. It avoids trailing-space fragility and matches the bullet-heavy  
  style.
- Where a genuine intra-paragraph hard break is wanted, the first line MUST end in
  two or more trailing spaces.
- Exempt: list items, headings, blockquotes, table rows, link/image reference lines
  (badges, shields, footnote-style refs), and fenced code content. A following  
  non-blank line after these is normal Markdown syntax, not a soft-break hazard.
- Enforced by `kitchen/tools/fix_md_hardbreaks.sh`, connected to `build_site.sh`
  and `preview_site.sh`. It runs as part of the build/preview pipeline, not  
  standalone.

mkdocs pages — blank line before every list.
- Always put a blank line between a lead-in paragraph or heading and the bullet or
  numbered list that follows it.
- mkdocs's Python-Markdown renderer needs the blank line to recognize the list.
  Without it, the list renders as flat inline text with literal `-`/`1.`  
  characters.
- GitHub renders such a list correctly even without the blank line. Do not rely on
  that as a check. Verify with `mkdocs build --strict`, not by reading the raw  
  `.md` source.
- Enforced by `kitchen/tools/fix_md_lists.sh` — auto-fixes every
  `kitchen/docs/**/*.md` in place, part of `build_site.sh` / `preview_site.sh` /  
  CI. Mechanical formatting only.

Examples-catalog nav sync.
- Any stage that adds, removes, or renames a file under `examples/` or `stories/`
  must also update `kitchen/mkdocs.yml`'s Examples Catalog `nav:` block and the  
  matching hand-authored group page under `kitchen/docs/examples/`.
- `kitchen/tools/gen_examples_docs.sh` only mirrors `.zig` files into generated
  `.md` pages. It does not touch `nav:` or the group pages. A new example gets a  
  generated page automatically but stays unreachable until `nav:` and the group  
  pages are updated by hand.
- Verify with `bash kitchen/tools/build_site.sh`: check for
  `INFO - The following pages exist in the docs directory, but are not included in  
  the "nav" configuration` and confirm no `examples/*.md` path appears in that  
  list. This has caught a real miss.

---

## Part 7 — Dispatch

### Dispatch chains end with a final branch — MUST

Every `fromPoly` or `isIt` chain writes its last `else`.

The trailing branch is optional to the compiler. Leave it out and an item whose  
tag nobody claimed falls through in silence.

What goes in it:
- Closed set, every helper present in the chain — `unreachable`. Reaching it means
  the caller passed something that cannot exist.
- Open set, a mailbox anyone can send to — count it, log it, or return an error.
  Then move on.

It cannot free the item. `alloc.destroy` takes `*T`, and the allocator needs the  
size to release the memory. With no type there is no size. An unknown item can  
only be dropped or reported; its memory belongs to whoever knows what it is.

Catalog: [patterns-028.md](patterns-028.md), "The last branch of a dispatch chain".

### No switch over tags — MUST

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
wherever a compile-time value is required, including as a container-level `const`.

`isIt` and `==` need only to know which global the tag names. That the compiler  
does know.

Detail, with the build matrix:
[llvm-pointer-switch-bug-001.md](secondary/llvm-pointer-switch-bug-001.md).

### The transfer rule for dispatch handlers — convention, not a MUST

Applies to a handler stored in a dispatch table:

> On return, the Slot is null if the handler took the item, full if it did not.

`src/` cannot enforce this and does not care. It is a convention between the  
person writing a handler and the person writing the loop that calls it, and it is  
written down here because both are often the same person a month apart.

A handler may take the item, forward it, or look and leave it. What it must not do  
is leave the Slot lying about which.

The loop covers every case with one line:

```zig
defer items.freeSlot(&slot, allocator);   // no-op when null
```

A handler may also move the item and *then* fail. The Slot reports where the item  
is; the error reports whether the work succeeded. They are two different  
questions, and a caller that frees on error without looking at the Slot  
double-frees.

Where it is written: the doc comment on `TagTable.Handler`, and
[patterns-028.md](patterns-028.md), "Polymorphic dispatch — table".

Detail: [table-dispatch-002.md](table-dispatch-002.md).

---

## Part 8 — Implementation invariants

General.
- Source of truth for signatures, types, errors: the current API reference. It
  wins over all other sources.
- Never send a stack-allocated item. Use `alloc.create` or `pool.get`.
- After transfer (`send`, `put`), `slot.* = null`.
- A refused transfer gives the item back. `send`/`send_oob` returning
  `error.Closed` leave `slot.*` unchanged, and `put` on a closed pool is a  
  no-op that leaves it unchanged. The caller still holds the item. Handle  
  that path — free the item, or put it somewhere that will.
- After `close`, walk the returned list. Free heap items or return pool items.
- Walk it **unconditionally** — MUST. `mailbox.close` can be called more than once and
  returns an empty list on later calls, so the release loop is always safe:  
  on a mailbox still holding items, on one already empty, on one closed  
  twice. There is no state in which running it is wrong, which means no call  
  site has to reason about which state it is in.
- Never write `_ = mbx.close()`. It drops items the mailbox gave back. Even
  where nothing leaks — items that live in the caller's frame — the dropped  
  list is still a chain of linked nodes, and `send` asserts an unlinked item,  
  so those items cannot be sent again. MBOX 1 found 32 sites doing this while  
  this rule was already on the books.
- After `put_all`, check the list. It stops at the first refusal and leaves
  the rest with the caller.
- `mailbox.close`, `pool.close`, `pool.put`, `pool.put_all` use `lockUncancelable`.
- Never use `std.Thread.Mutex` / `std.Thread.Condition` in `_Mailbox` or `_Pool`.
- `error.Canceled` is never remapped to `error.Closed`.
- `condition_waitTimeout` is a private helper copied from the legacy mailbox
  (codeberg/zig#31278).

`ItemList` and `polynode.reset`.
- `std.DoublyLinkedList` does nothing for node safety. Any removal — `remove`,
  `pop`, `popFirst`, or any variant — does NOT zero `prev`/`next` on the removed  
  node.
- `ItemList.popFirst` does. It calls `polynode.reset` before returning, so a popped
  `ItemHandle` is never linked.
- This is a property of the type, not a rule the developer carries. It replaces the
  former "call `reset` after every removal" rule, which was widely skipped and cost  
  a real bug.
- `polynode.reset` stays public. It is needed by hand in exactly one case: items
  taken out through `ItemList._list`.
- `ItemList._list` is the raw field. While a caller uses it, the `ItemList`
  promises are suspended. Tests that manipulate raw links use it; application code  
  does not.

`*std.DoublyLinkedList.Node` is not `*PolyNode`.
- From the langref, `struct` section: "Zig gives no guarantees about the order of
  fields and the size of the struct but the fields are guaranteed to be  
  ABI-aligned." And: "Struct field order is determined by the compiler, however, a  
  base pointer can be computed from a field pointer."
- `PolyNode` is a plain struct. `node` written first says nothing about its offset.
- `@ptrCast` between the two pointer types is unsound, even where it compiles and
  appears to work.
- `@fieldParentPtr` is the only defined conversion.
- Rule: `@fieldParentPtr` appears in `src/polynode.zig` and in the raw-link tests of
  `tests/layer1_polynode.zig`. Nowhere else. The closing gate is  
  `grep -rn "fieldParentPtr" src/ tests/ examples/ stories/`.

---

## Part 9 — Patterns

The pattern catalog lives in [patterns-028.md](patterns-028.md).

It covers:
- Observable function shapes: coordinator / step / init / destroy / Select event
  loop / spawn-await.
- Description as code: example and story doc comments follow the same
  coordinator/step shape.
- Pool modes, seeding, backpressure, hooks.
- `Io.Select` event loop and re-register.
- `Io.Group` worker sets and shutdown.
- Graceful shutdown ordering.
- Polymorphic dispatch, item-first and tag-first.
- Error handling on receive (Closed/Timeout vs Canceled).
- Master composition.

Rules constrain. Patterns reuse.  
Read the catalog for code shapes. Read this doc for what is mandatory.

---

## Part 10 — Provenance

One line per rule, oldest first. This replaces the changelog that used to grow in  
the header. The full account of each stage is in
[STATUS-LOG.md](STATUS-LOG.md), by date.

- rules-011 — `///` and `//!` allowed in `src/`. They were banned in rules-010.
- rules-012 — no "ownership" language in `src/` comments; no `.md` references in
  `src/` comments.
- rules-013 — the file-header `//!` staccato standard; the live-scan rule.
- rules-016 — the blank-line hypothesis for the autodoc splice. Tested and
  disproved.
- rules-017 — the `_doc_stub` first-declaration rule, superseding rules-016.
- rules-026 — the `wire` family banned; "object" banned when it means an Item.
- rules-028 — `seam`, `seamless`, `sweep`, `settle` banned.
- rules-030 — `underneath`, `on purpose` banned.
- rules-031 — the `ownership` replacement table; scan the rules file against its
  own ban.
- rules-032 — `hatch` banned.
- rules-033 — exclusive access, second half: the transfer also orders memory.
- rules-034 — the neighbour check: what `is_linked` is worth, and the two checks
  that are exact where it is not.
- rules-035 (DISPATCH 1) — dispatch chains end with a final branch; no `switch`
  over tags.
- rules-036 (DISPATCH 2) — the transfer rule for dispatch handlers. A convention
  for handler authors, not a toolkit MUST.
- rules-037 (API 11) — accessor naming became `fromPoly` / `fromSlot`. The
  helper reaches the `poly` field, and `node` was already taken by  
  `std.DoublyLinkedList.Node` inside `PolyNode`.
- rules-038 (CMPCT 1) — status file ownership. One owner per fact across
  `STATUS.md`, the plan, `STATUS-LOG.md` and `context.md`.
- rules-039 (CMPCT 2) — the restructure. Gates first, one topic in one place, the
  dated rationale moved to `STATUS-LOG.md`. No rule changed meaning.
- rules-040 (DOC 22) — where a doc lives: `design/` is the current picture,
  `design/secondary/` is frozen. Present tense in `design/`. Retiring a doc is  
  not overwriting. Story file layout moved here from a retired model  
  document.
- rules-041 (DOC 23) — the design gate. `kitchen/tools/check_design.sh` must
  exit 0 before a stage that touched `design/` is done. It is what makes the  
  "where a doc lives" rule enforceable rather than remembered.
- rules-047 (API 13-4) — the custody-sense entry in Part 5 covers `hands` and
  `holds` together, and is scoped away from the architecture doc's Hold  
  vocabulary. The carve-out for the old MBOX 1 framing is retired: `src/` was  
  reworded in 13-4a, so there is nothing left to exempt.
- rules-046 (API 13-3) — a bulk repoint excludes `STATUS-LOG.md`. The log
  already had two exemptions, both for reading it — the banned-word scan and  
  three of the four design-gate checks. This is the first for writing to it.  
  Earned the hard way: a `grep -rl ... design/ | xargs sed` renaming the api  
  reference rewrote a version number inside a finished log entry from earlier  
  the same day.
- rules-046 (API 13) — one word added to Part 5, from the owner's ruling of
  2026-08-13. It was this repo's name for the plan's per-stage line and for  
  any record of what moved where. A book-keeping metaphor standing in for a  
  plain list. This is the first banned word the glossary gate enforces from  
  the day it is banned; the three before it were added to the gate later.  
  The three uses inside this document were rewritten in the same pass.
- rules-044 (FLOW 1-1) — two words added to Part 5, both from the owner's
  ruling of 2026-08-12. The first named the create/use/close/destroy section  
  in a way that told the reader nothing; that section is Usual flow  
  everywhere now, and the item-state material keeps its own name. The second  
  is the verb two shipped sentences used for giving an item back.
- rules-043 (PROSE 1) — the full banned-word pass. `kitchen/defer/` declared
  frozen beside `design/secondary/`, and Part 5 gained a scan scope so the  
  next run does not re-derive which files are off-limits. The scope is what  
  turned a 500-hit raw count into the ~20 that were real.
- rules-042 (MBOX 1) — the mailbox audit. Part 8's release rules made
  unconditional and given their reason: the list `close` gives back must be  
  walked every time, `_ = mbx.close()` is banned, a refused `send`/`put`  
  leaves the item with the caller, and `put_all` must be checked for what it  
  refused. Part 4 gains "documented asserts must exist" — the audit found 15  
  documented asserts that were never in `src/`.
