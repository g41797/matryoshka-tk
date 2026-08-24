# dtk — status

Current state of the dtk line of work. One screen.

This file is the entry point for a cold session. Read it first.

**No stage has run.** This folder was prepared on 2026-08-23 so that planning
could start from surveyed ground. Nothing here is a design decision, and there is
no staging plan yet — writing one is the next act, and the owner names it.

## What dtk is

The **D** port of Matryoshka. Fourth in the family: **otk** (Odin), **ztk** (Zig,
this repo, the reference implementation), **3tk** (C3, complete), **dtk** (D).

Ported from
[the portable specification](../common/matryoshka-specification-004.md), with ztk
as the reference for *behaviour* — never as a template for syntax.

## Scope — ruled by the owner, 2026-08-23

These are not proposals. They are settled, and every stage works inside them.

- **Linux only.** One target, no cross-target matrix.
- **`@nogc`.** No GC allocation anywhere in the toolkit.
- **Not betterC — yet.** druntime stays, so `typeid`, module constructors and
  Phobos remain available. `-betterC` is a plausible *later* stage: the design
  must not foreclose it, and must not pay for it now.
- **Idiomatic D, not transliterated Zig.** The specification says what to
  preserve; D decides how to spell it. Divergence is expected and gets a recorded
  reason, the way 3tk's decision log does.
- **`inputs/` is input, no force.** See [`inputs/README.md`](inputs/README.md).
  Where an input conflicts with this scope, this scope wins.

## Normative inputs

Read these; nothing in this folder replaces them.

- **[matryoshka-specification-004.md](../common/matryoshka-specification-004.md)**
  — the source of truth. Self-contained and language-neutral. *A port is written
  from this file alone.* A defect found in it is fixed **there**, once, for every
  port — not patched in a dtk document.

  **This is dtk's input, and it changed twice on 2026-08-24.** 003 replaced 002
  and 004 replaced 003; both are now in
  [`../common/backup/`](../common/backup/). The reason matters to a port that
  has not started: 002 was written from ztk and stated Zig's *mechanism* where
  the design has only a *promise*, in fourteen places. A dtk written from 002
  would have reproduced a doubly-linked list, a previous link, the mailbox's
  out-of-band anchor and an inexact link test — and then needed the C3 line's
  redesign stages run again against it. 003 states the promise and shows both
  realizations. **Read the change log first**: it names every difference and the
  five assumptions 003 was written on. No dtk stage has run, so nothing here
  needs revising for it.

  **004 is 3TK-17, and it was cut for dtk's sake specifically.** Part 7.1 was
  the fifteenth place the same mistake was made, and 003 walked past it: it said
  *for each outer type there is a helper bound to that one type*, which is
  Zig's per-type comptime struct written up as though it were the requirement.
  The C3 port answered the same question with macros over a type parameter —
  no per-type object at all — and Part 7.1 stopped describing a conformant
  port. **D's idiomatic answer is templates and mixins: call-site expansion,
  the same shape as the C3 macro, not a per-type struct.** Had 004 not been cut
  first, Part 7.1 would have set dtk the identical trap, and a second port would
  have re-derived this argument from cold. 004's Part 7.1 states the promise —
  the members of Part 7.2 exist per outer type, generated rather than
  hand-written — and shows both realizations. **A named per-type helper object
  is one spelling of it and not the rule.** dtk is free to spell it as D
  spells it.
- **[port-flow-001.md](../common/port-flow-001.md)** — how a port is staged,
  recorded and verified. Its three tiers say what transfers from 3tk verbatim,
  what transfers only as a question, and what is shared.
- [ztk-audit-001.md](../common/ztk-audit-001.md) — evidence about the reference
  implementation, file and line for every claim.

Worth reading, and **not** normative — one language's answers to questions D will
ask differently:
[`../c3/3tk-porting-proposal-003.md`](../c3/3tk-porting-proposal-003.md),
[`../c3/c3-capabilities-001.md`](../c3/c3-capabilities-001.md),
[`../c3/3tk-toolkit-notes-001.md`](../c3/3tk-toolkit-notes-001.md),
[`../c3/3tk-containers-notes-001.md`](../c3/3tk-containers-notes-001.md).

## Where the work lives

Everything for dtk goes under `design/secondary/lang/d/` — plan, status, log,
review, capability study, notes and code. `design/STATUS.md` and
`design/STATUS-LOG.md` are not touched.

Shared documents are **not copied here.** They live in `../common/` and are
linked. That rule exists because the specification used to live inside `c3/`, and
the first review of the C3 proposal raised two defects that were really
*specification* defects.

## Current state

| | |
|---|---|
| Stages run | **none** |
| Staging plan | **does not exist yet** |
| Code | none |
| Scope | ruled, above |
| Inputs | 18 files in `inputs/`, mapped, unmeasured |
| Blocked on | **T1** — no D compiler installed. See the next section. |

## Before any stage can run

**Two lists. Nothing in this folder proceeds until the first one is done, and
the second one is what the first stages exist to settle.**

A cold session should not have to re-derive either. 3tk never needed this
section because C3 was already installed and measured; dtk starts from an empty
machine, and that is a real difference in the flow, not an oversight.

### List 1 — the toolchain: decide, then install

**Nothing D is installed on this machine.** No `dmd`, no `ldc2`, no `gdc`, no
`dub`, and nothing under `/home/g41797/dev/langs/`. Measured 2026-08-23.

`inputs/d-toolchain-and-ci.md` opens by arguing that the compiler choice is a
larger axis than OS or build mode. With Linux-only ruled, it is the axis left.

| # | To decide | Options measured on this machine (Fedora 44) | Recommended |
|---|---|---|---|
| **T1** | **Which compiler is the port's compiler** | `ldc` 1.42.0 in the Fedora repo — LLVM 20.1, DMD frontend 2.112, ships `/usr/bin/ldc2` and `/usr/bin/ldmd2`. `gcc-gdc` 16.2.1 in the repo. **`dmd` is not packaged**; it installs from upstream's script. | **`ldc2`.** LLVM backend, the strongest `-betterC` path for the later *"yet"*, one `dnf` line, and it matches how `c3c` is already installed here — a system binary, no install step inside any stage. |
| **T2** | **One compiler or several** | The port could be built by two or three. | **One, for now.** A second compiler multiplies the build matrix before that matrix has even been defined (T3). Add one later as its own stage, the way 3tk's cross-target builds were left as a candidate. |
| **T3** | **The build matrix** | `-release`, bounds checking (`-boundscheck=`), `-checkaction=`, `-unittest`. | Undecided — see D3 below. It is a *design* decision, not a toolchain one, but it cannot be measured until T1 is installed. |
| **T4** | **`dub`, or a plain script** | `dub` 1.41.0 is packaged and is **not** pulled in by `ldc`. 3tk uses a hand-written `run-builds.sh` and needs nothing but the compiler on the path. | **A script, matching 3tk.** `port-flow-001.md` requires the harness be runnable without an agent; a script with no package manager between it and the compiler is the shortest path to that. Revisit if packaging becomes a stage. |

**To install the recommendation** — the owner runs this; no stage installs
anything:

```
sudo dnf install ldc
```

That gives `/usr/bin/ldc2` and `/usr/bin/ldmd2`, plus `ldc-libs` (druntime and
phobos, shared, `.so.112`). Add `dub` only if T4 is decided the other way.

Once installed, the *first* thing a stage records is the exact version, the way
`c3-capabilities-001.md` records `c3c` 0.8.3 / LLVM 22.1.8 / linux-x64. Every
capability answer is against that version and no other.

```
ldc2 --version
```

**Until T1 is installed, the capability study cannot run at all.** It must
*measure* — 3tk's study marked every answer **verified** (compiled and run) or
**read** (from stdlib sources only), and that distinction caught real defects.
An unmeasured capability study is a guess with citations.

### List 2 — the design decisions that block the proposal

None of these is answerable from `inputs/`, and none may be settled outside a
stage. Detail for each is under *Open questions* below.

| # | To decide | Blocks | Needs a compiler first |
|---|---|---|---|
| **D1** | **How outcomes reach the caller.** `@nogc` forbids `throw new Exception`, so the specification's *empty* / *timeout* / *closed* cannot be thrown. | The whole public surface. Nothing can be specified before it. | No — it is decidable from the language rules |
| **D2** | **The assert policy.** Three tiers are needed: aborts always, vanishes in a fast build, never compiles. And the always-abort itself must be `@nogc`. | The verification harness, and every check in the toolkit. | Yes, to confirm what `-release` actually removes |
| **D3** | **The build matrix** — which axes exist, and how many combinations. **It is not four**; four is C3's `--safe` × `-O` axis. | The harness, and every claim the port makes about being green. | Yes |
| **D4** | **The Slot's shape.** Three inputs give three incompatible answers. 3tk found it needs five operations including refuse-to-overwrite, which a bare pointer cannot enforce. | The intrusive layer, and therefore both containers. | No |
| **D5** | **How the layering is enforced.** C3 got it from the compiler for free. D's `private`/`package`/module rules give something different, and it must not be overclaimed. | The Part 17.2 test. | Yes |
| **D6** | **Type identity.** druntime is present, so `typeid` is available — but *available* and *usable in `@nogc` code without allocating* are different claims. | The per-type helper. | Yes |

**D1 is the one to settle first**, and it is the reason dtk's stage sequence may
not match 3tk's. C3 had no equivalent — its fault returns were already the right
shape — so no earlier port needed a stage for it. Here it is front-loaded, and
everything else waits behind it.

The likely answer is a return-value discipline, which is what C3's fault returns
and Zig's error unions already are. That would make this **convergence** across
the family rather than divergence. Likely is not decided.

## Open questions — recorded, not answered

Answering any of these is design work, and design work belongs in a stage.

These are the detail behind *Before any stage can run*. The toolchain half is
**T1–T4** and is not repeated here.

### 1. `@nogc` versus exceptions — **D1**

`throw new Exception` allocates on the GC. If the specification's outcome sets —
Part 19's *empty*, *timeout*, *closed* — were expressed as thrown exceptions,
`@nogc` forbids it outright.

That pushes toward a return-value discipline, which is what C3's fault returns
and Zig's error unions already are. Likely **convergence** across the ports
rather than divergence. It is the first real design question the proposal must
answer, and it is front-loaded in a way no earlier port's was — which is a reason
dtk's stage sequence may not match 3tk's.

### 2. The build matrix — **D3**

`-release`, bounds checking, `-checkaction`, and whatever else changes what code
exists. The count is unknown and **it is not four** — four is C3's `--safe` × `-O`
axis and does not transfer. `port-flow-001.md` tier 2.

The portable half of the rule does transfer: enumerate every axis, test every
combination, and never infer one axis from another.

### 3. The assert policy — **D2**

Matryoshka needs three tiers: one that aborts always, one that vanishes in a fast
build, one that never compiles. D's `assert` under `-release`, `debug` blocks,
`version()` blocks and `static assert` are the raw material. Which maps to which
is unmeasured — and whichever abort is chosen must itself be `@nogc`.

### 4. The layering test — **D5**

The containers must be built *on* the intrusive layer with no privileged access.
C3 got this enforced by the compiler for free, because a submodule cannot see its
parent's private declarations. D's `private`/`package`/module rules give a
different answer, stronger or weaker, and it is unmeasured. Whatever it turns out
to be, it must not be overclaimed.

### 5. The Slot — **D4**

Three inputs give three different answers — a plain pointer, a struct, and an
alias to a pointer. 3tk found the Slot needs five operations including a
refuse-to-overwrite rule. Unresolved, deliberately.

### 6. Type identity — **D6**

The specification requires an item to carry its type, so a container can refuse
a give-back of the wrong kind. druntime is present, so `typeid` exists — but
*exists* and *usable inside `@nogc` code without allocating* are different
claims, and only the second one matters here.

3tk hit the neighbouring problem from the other side: C3's `Type.typeid` did not
compile at all on c3c 0.8.3, and the port carried a helper constant instead. The
lesson that transfers is not the workaround. It is that this is **measured, not
assumed** — which puts it behind T1.

## Candidate first stages

**None is authorized, and the list is not ordered.** It exists so the owner can
name one without re-deriving it.

| Candidate | What it produces | Note |
|---|---|---|
| **The staging plan** (`DTK-0`) | the plan of record, and this file gains a stage table | Every other candidate becomes a stage inside it. The conventional first move. |
| **Measure `inputs/`** | a review that retires the 18 drafts, measured against the specification | 3tk's 3TK-3. Big folder, sharp contradictions, and the earlier it happens the less wrong reading is done downstream. |
| **The D capability study** | Part 21 of the specification answered for D, one citation per answer | **Blocked on T1.** It must measure, not read. |
| **The `@nogc` outcome question** (**D1**) | a ruling on how outcomes reach the caller | 3tk had no equivalent, and it blocks the whole public surface. It may deserve its own stage precisely because it is front-loaded. |

## Standing facts

- **No D toolchain on this machine.** Nothing to measure against yet, and one
  `dnf` line away — *Before any stage can run*, T1. 3tk never needed an install
  step in any stage because `c3c` was already present; dtk does, and it is the
  owner's to run, not a stage's.
- ztk is green: 195/195 in four modes, three cross targets.
- 3tk is complete through 3TK-7: four builds green, 59 checks, 73 tests.
- Terminology, in all prose: **inner** = the embedded structure, **outer** = the
  struct that embeds it. **Never "parent".** A **Slot** holds one handle or
  nothing.
- Porting is not transpiling.

## Files

Edited in place, never versioned:

- `dtk-status.md` — this file.
- `dtk-log.md` — the narrative, append-only, newest first.

Versioned, when they come to exist: the staging plan, the inputs review, the
capability study, the porting proposal, the notes.

- `inputs/` — raw material, no force. [`inputs/README.md`](inputs/README.md).
