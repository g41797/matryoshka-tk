## Stage 1 — Claude Code investigates `matryoshka-ztk` and prepares a porting-analysis document

Goal:

> Build an accurate understanding of what `matryoshka-ztk` actually is before deciding how to map it to C3.

This is not yet "make a plan to port it."

Claude should inspect:

* repository structure
* public API
* core implementation
* tests
* examples
* generated/documentation sources
* build and test setup
* Zig-specific mechanisms
* compile-time mechanisms
* concurrency model
* type-erasure model
* ownership/lifetime conventions
* all assumptions hidden in tests

And, importantly, separate things into:

### A. Architecture that must be preserved

For example, things like:

* Master
* Item
* Mailbox
* Pool
* PolyNode / PolyHelper
* type tags
* intrusive structures
* slot/optional-pointer patterns
* communication semantics
* cancellation/interrupt/data channels

These should be described **independently of Zig syntax**.

### B. Zig implementation choices

For example:

* comptime
* `anyopaque`
* pointer-based tags
* error unions
* `union(enum)`
* `?T`
* allocators
* `std.Io`
* mutexes/conditions
* test organization
* build system
* generated Zig documentation

These must **not automatically be preserved** in C3.

### C. Open mapping problems

Claude should explicitly identify:

> "I understand what this does, but I do not yet know the correct C3 implementation."

That is much better than letting it silently invent a solution.

The output of Stage 1 should be something like:

> **matryoshka-ztk → matryoshka-3tk Porting Analysis**

with:

1. System inventory
2. Architectural invariants
3. Component dependency map
4. Zig-specific mechanisms
5. C3 mapping candidates
6. Semantic risks
7. Unknowns requiring decisions
8. Recommended porting order

---

## Stage 2 — Create the actual implementation plan

Then use the Stage 1 analysis, together with your answers to unresolved architectural questions, to create:

> **matryoshka-3tk implementation plan**

This plan should be concrete:

### Phase 0 — C3 feasibility experiments

Small throwaway experiments for the dangerous parts.

For example:

* runtime type/tag mechanism
* recovering a concrete type from erased node/tag
* generic/macro generation for PolyHelper equivalents
* optional pointer / Slot representation
* intrusive linked list support
* synchronization primitives
* condition-variable semantics
* thread/task model
* atomics
* allocator/resource model
* test support

### Phase 1 — Foundation

Probably:

```text
PolyTag / type identity
        ↓
PolyNode
        ↓
PolyHelper equivalent
        ↓
ItemHandle / Slot
```

But the exact order should come from the Stage 1 dependency analysis.

### Phase 2 — Standalone structures

Likely:

* intrusive lists
* Pool internals
* Mailbox internals

with focused tests before integration.

### Phase 3 — Concurrency integration

Only after C3's actual concurrency facilities have been validated.

### Phase 4 — Public API

Adapt the architecture to idiomatic C3 **without unnecessarily copying Zig API shapes**.

### Phase 5 — Examples

Port examples selectively, starting with the ones that exercise the architecture rather than merely demonstrating syntax.

### Phase 6 — Documentation

Decide separately how documentation works in C3.

Your current documentation model is an important issue:

```text
hand-written MkDocs
        +
generated Zig API documentation
```

C3 may require a different solution, so this should not be treated as an afterthought.

---

# One important modification: use you as the architecture authority

I would not give Claude an instruction like:

> Analyze the repository and decide how to port Matryoshka to C3.

Too much authority.

I would instead make the process:

```text
You
 │
 │ define intended architectural semantics
 ▼
Claude Code
 │
 │ investigates repository
 │
 ▼
Porting analysis
 │
 │ identifies C3 mismatches and questions
 ▼
You
 │
 │ resolve architectural decisions
 ▼
Claude Code
 │
 ▼
Concrete implementation plan
```

That is particularly important for `matryoshka-3tk`, because C3 differences may expose places where `matryoshka-ztk`'s design is partly an artifact of Zig rather than an actual Matryoshka requirement.

---

# I think Stage 1 should probably use Opus, not Sonnet

My suggested division:

**Opus:**

* whole-repository architectural analysis
* identifying invariants
* distinguishing architecture from Zig implementation
* finding subtle semantic dependencies
* comparing alternative mappings
* producing the final plan

**Sonnet:**

* targeted repository exploration
* searching usages
* generating inventories
* tracing APIs
* checking that every public component is covered
* later implementation work

I would avoid burning Opus on mechanical file-by-file summarization.

---

# My biggest concern: local + remote repository

Before designing the Claude workflow, I need to understand what exactly Claude should treat as authoritative.

You said you have:

* local `matryoshka-ztk`
* remote `matryoshka-ztk`

and locally it is close to finished.

This creates an important possibility:

```text
GitHub remote
    ↓ possibly older
local repository
    ↓ possibly uncommitted / ahead
actual source of truth
```

If Claude analyzes the remote version while the important work is only local, the plan can be wrong from the start.

---

# Questions I would ask before writing the actual Claude Code plan

These are the questions I think genuinely matter. I would not ask many more.

### 1. What is the exact purpose of `matryoshka-3tk`?

Is it intended to be:

**A. A semantic port**

> Same Matryoshka architecture and essentially the same API, expressed in C3.

**B. A language-native implementation**

> Preserve the architecture, but redesign APIs and implementation around what C3 does well.

**C. A reference implementation**

> Keep it as close as practical to `matryoshka-ztk` so the repositories can be compared.

This answer changes the entire plan.

---

### 2. Is the local repository the source of truth?

Specifically:

* Is local ahead of GitHub?
* Are there uncommitted changes?
* Is the local documentation complete?
* Should Claude inspect Git history, or only the current working tree?

My default would be:

> **Analyze the current local working tree first. Use Git history only when it helps explain a design decision.**

---

### 3. Do you already know enough C3 to state the target minimum version?

This matters because the feasibility experiments depend heavily on actual language capabilities.

For example, the plan needs to know whether you expect to use:

* C3 `typeid`
* macros
* generics
* interfaces
* compile-time reflection
* threads/atomics from the current C3 standard library

I especially remember that **`typeid` is one of the potentially dangerous areas for PolyNode**, because your existing type-tag design is based on a unique opaque identity rather than simply "I have some runtime type number."

I would make **type identity and PolyHelper the first C3 feasibility investigation**.

---

### 4. Should `matryoshka-3tk` initially support the same execution model as `matryoshka-ztk`?

In other words, is the first target:

```text
thread-based execution
```

only?

Or should the plan investigate another C3-native execution abstraction?

I strongly recommend **not broadening this during the initial port**. The project should preserve the same basic execution-model scope first.

---

### 5. What is the intended relationship between the repositories?

Do you want:

```text
matryoshka-ztk
matryoshka-3tk
```

to eventually have approximately parallel:

* concepts
* directory structure
* tests
* examples
* documentation pages

or can they diverge substantially?

This affects whether Claude should build a **feature/test matrix** between the two repositories.

I think such a matrix would be extremely useful if parallel implementations are your goal.

---

## My current recommendation

**Yes: do two stages.**

But call them:

### Stage 1: Discovery and Porting Analysis

Not "planning the plan."

The output should answer:

> What exactly must be ported, what is architecture, what is Zig-specific, what is difficult in C3, and what decisions are still required?

### Stage 2: Implementation Plan

Only after Stage 1 and after you resolve the important C3/architecture questions.

I would also add a small **Stage 0 inside Stage 1**:

> Verify repository state and establish the exact source of truth.

That costs very little and prevents Claude from analyzing the wrong revision.
