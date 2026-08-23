# dtk — log

Narrative of the dtk line of work. Append-only, newest first.

Not read by default. Read it for history: what was decided, when, and why.
Current state is in [dtk-status.md](dtk-status.md).

---

## 2026-08-23 — the ground prepared, and nothing designed

Written: `dtk-status.md`, this file, `inputs/README.md`. Created:
`../common/` with `README.md` and `port-flow-001.md`.

No stage ran. There is no staging plan. This entry records preparation only.

**The specification moved out of `c3/`.** It had always described itself as
language-neutral — *"a port is written from this file alone"* — while living
inside one port's folder. The revision of 2026-08-23 showed the bill for that:
of the twenty-seven items raised against the C3 proposal, two were
*specification* defects, and fixing them only in the C3 document would have left
the same trap set for D and for Odin. So `matryoshka-specification-002.md` and
`ztk-audit-001.md` moved to `../common/`, with `001` of the specification into
`../common/backup/`. Fourteen links across nine files were rewritten in both
directions by resolving each link's basename against where the file actually
lives; zero dangling links afterwards.

The provenance lines did not move. The specification still opens by naming stage
3TK-2 of plan 001, and the two `.c3` source headers still name specification 001.
A path is not a pointer.

**The flow was written down as flow.** `../common/port-flow-001.md` is the 3tk
process with C3 taken out of it, in three tiers. Tier 1 transfers as written —
the status/log/plan triad, cold-start stages, *finishing a stage does not start
the next*, the provenance rule, the three shapes of negative test, compile judged
separately from run, and sabotage verification. Tier 2 transfers only as a
question: the build matrix is **not** four builds, that is C3's `--safe` × `-O`
axis, and a port that copies the number has performed a ritual rather than a
verification. Tier 3 is the shared folder itself.

The reason tier 2 exists at all: the failure mode of *"reuse the proven flow"* is
inheriting C3's answers along with C3's questions.

**The scope was ruled by the owner**, and is recorded in `dtk-status.md`
verbatim: Linux only, `@nogc`, not betterC *yet*, idiomatic D rather than
transliterated Zig, and `inputs/` binding nothing.

**The eighteen inputs were mapped, not measured.** `inputs/README.md` says what
each argues and never that it is right. Two contradictions are worth naming here
because a later stage will have to rule on them. The Slot has three incompatible
answers across three documents — a plain pointer, a struct, and an alias to a
pointer — and 3tk found the Slot needs five operations with a refuse-to-overwrite
rule that a bare pointer cannot enforce. And two inputs propose a dual
Manual/Managed compile-time memory policy, which the ruled scope has already
overtaken.

**One fact blocks a stage: no D compiler is installed.** No `dmd`, no `ldc2`, no
`gdc`, no `dub`, and nothing under `/home/g41797/dev/langs/`. A capability study
has to *measure* — 3tk's marked every answer verified-and-run or read-only, and
the distinction earned its keep. `ldc2` is recommended and not ruled: LLVM
backend, the best `-betterC` path for the later *"yet"*, packaged on Fedora.

**A blocked-list was added to `dtk-status.md`**, on the owner's instruction, so
that a later start does not re-derive it: *Before any stage can run*. Two lists.
**T1–T4** are toolchain decisions with the install command spelled out and the
options measured against this machine — `ldc` 1.42.0 and `gcc-gdc` 16.2.1 are in
the Fedora 44 repo, `dmd` is not packaged, `dub` 1.41.0 exists and is not pulled
in by `ldc`. **D1–D6** are the design decisions that block the proposal, each
naming what it blocks and whether it needs a compiler first.

**D1 — how outcomes reach the caller under `@nogc` — is the one to settle
first**, and it is why dtk's stage sequence may not match 3tk's. C3 needed no
equivalent stage: its fault returns were already the right shape. Here the
question is front-loaded and the whole public surface waits behind it.

3tk never needed an install section because `c3c` was already on the machine.
dtk starting from nothing is a real difference in the flow, not an oversight,
and the status file now says so.

Nothing in this folder answers a design question. That was the constraint, and
re-reading `dtk-status.md` cold is how it was checked: it states the scope, names
the inputs, lists what is blocked, and leaves the design open.
