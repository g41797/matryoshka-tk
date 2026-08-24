# d/inputs — raw material, no force

Seventeen `.md` and one book, written in earlier sessions by different AIs,
before the portable specification existed and before the owner ruled the scope.

**None of it binds.** Nothing here is a design of record, nothing here has been
measured against
[the specification](../../common/matryoshka-specification-003.md), and some of it
contradicts the rest. It is here to be mined, not obeyed.

Where an input conflicts with the scope in [`../dtk-status.md`](../dtk-status.md),
**the scope wins.** Where two inputs conflict with each other, neither wins until
a stage measures both.

They moved here from `design/secondary/lang/` on 2026-08-23, where they were
loose files, so that `lang/` holds only port folders and `common/`.

## The map

Descriptive only. Each line says what the document *argues*, never that it is
right.

### Design of the port

| File | Lines | What it argues |
|---|---|---|
| `dtk-porting-proposal.md` | 2725 | The big one. Argues D fits Matryoshka well enough to start, and sketches the whole port. Explicitly *"not a porting plan yet"*. |
| `matryoshka-d-handbook.md` | 1203 | The design session collected in one place: Slot, PolyNode/PolyHelper, Mbox, Pool, memory policy, items and the collector. |
| `matryoshka-zig-to-d.md` | 394 | A direct Zig-to-D mapping table. Closest thing here to a transliteration, and therefore the one to read most sceptically. |
| `polynode-polyhelper-d.md` | 621 | Intrusion and type erasure in D: `offsetof` arithmetic in place of `@fieldParentPtr`, templates in place of `comptime`. |
| `dtk-hooks.md` | 408 | The pool hook signatures in D, with a shape table. Already assumes `@nogc nothrow`. |

### The Slot — three inputs, three different answers

| File | Lines | What it argues |
|---|---|---|
| `slot-idiom-d.md` | 1076 | *"In D, a pointer is already nullable, so a plain pointer is enough."* |
| `slot-idiom-d-porting-notes.md` | 344 | *"D has neither, so the Slot is a struct."* |
| `matryoshka-zig-to-d.md` | — | `alias Slot = PolyNode*` — a third position again. |

**They contradict each other, and the contradiction is load-bearing.** 3tk found
the Slot needs five operations with a refuse-to-overwrite rule, which a bare
pointer cannot enforce. Unresolved here on purpose.

### Memory, GC, betterC

| File | Lines | What it argues |
|---|---|---|
| `nogc-vs-betterC.md` | 635 | The two are different things: `@nogc` is a function-level guarantee, `-betterC` drops druntime. Directly relevant to the ruled scope. |
| `gc-or-no-gc-recommendation.md` | 292 | Guidance for *applications*: pick one mode for the whole application, never mixed. |
| `application-items-and-gc.md` | 358 | Argues the toolkit does not care about allocation, with three exceptions, one of them the pool. |
| `matryoshka-memory-policy.md` | 484 | **Conflicts with the ruled scope.** Proposes two modes, Manual and Managed, selected at compile time. |
| `matryoshka-comptime-policy-emb-desk.md` | 479 | **Conflicts with the ruled scope.** The same two-mode design under the names Embedded and Desktop. |

The last two propose a dual-mode toolkit. The owner has ruled **one** mode:
`@nogc`, Linux only, not betterC yet. Their machinery for *selecting* a policy is
out of scope; their observations about what `@nogc` costs are still worth reading.

### Toolchain, verification, scope

| File | Lines | What it argues |
|---|---|---|
| `d-toolchain-and-ci.md` | 444 | Opens by adding an axis: **D has three compilers** (dmd, ldc2, gdc), and argues that matters more than OS or build mode. |
| `tests-and-examples-in-d.md` | 619 | The D form of Matryoshka's verification model, and the distinction between two kinds of executable verification. |
| `dtk-phase1.md` | 365 | Argues for *Linux/POSIX only + manual only* as phase 1 — the closest input to the ruled scope, and arguably its source. |
| `dtk-prototype-scope.md` | 426 | Argues for a throwaway ~1200-line prototype first, with go/no-go criteria stated as observations. |

### Comparison, and the book

| File | What it is |
|---|---|
| `matryoshka-vs-std-concurrency.md` | Why Matryoshka is not `std.concurrency`: actor model versus intrusive handoff. Useful for a future README, not for the design. |
| `Programming_in_D.epub` | Ali Cehreli's book. Reference material. |

## How a stage should use this folder

The same way 3tk used its seven drafts: **measure them, once, in one stage,
against the specification** — producing a review that says which claims hold,
which conflict, and which the owner must rule on. Every later stage reads the
review. The drafts are not re-read, and they are not source of truth.

That is [`../../common/port-flow-001.md`](../../common/port-flow-001.md), tier 1,
*"raw drafts are input, never source of truth"*.
