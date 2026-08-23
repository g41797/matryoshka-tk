# How a Matryoshka port is run (001)

Written 2026-08-23, after 3tk (C3) finished. It is the 3tk flow with C3 taken
out of it.

This file is **process**, not design. It says how a port is staged, recorded and
verified. It never says what a port should decide.

## How to use it

A new port reads this once, at the start, and copies the *shape*. It does not
copy another port's answers. The distinction is the whole point of the file, so
it is made explicitly below: **tier 1** transfers as written, **tier 2** transfers
as a question whose answer must be re-derived, **tier 3** is not borrowed at all
because it is shared.

The failure mode this file exists to prevent is inheriting a finished port's
answers along with its questions. 3tk has four builds because C3's axis is
`--safe` × `-O`. A port that writes "four builds" without re-deriving the axis
has performed a ritual, not a verification.

---

## Tier 1 — transfers as written

These are process. No language appears in any of them.

### The three entry-point files

Every port folder has exactly three files edited **in place**, never versioned:

| File | What it is |
|---|---|
| `<x>tk-status.md` | Current state, one screen. **The entry point for a cold session.** |
| `<x>tk-log.md` | Append-only narrative, newest first. Not read by default; read for history. |
| the staging plan | The plan of record — but this one **is** versioned; the status file holds the live pointer to the current version |

The status file is what a start command names, *never* a versioned file, so the
command survives every version bump.

### Stages

- Stages are numbered `XTK-0`, `XTK-1`, … in one flat sequence.
- **Cold start.** Each stage is self-contained: its named inputs plus the status
  file are enough. No stage depends on conversation carried from the previous one.
- The agent's first three actions in every stage: read the status file; read the
  plan's section for the named stage; read that stage's named inputs, and
  nothing outside them.
- **No rolling.** Finishing a stage does not start the next. The owner names it.
- A stage whose status row reads DONE is not re-run without being told.
- Each stage ends with explicit advice — *clear the context, or do not, and why*.
- Plan approval is not stage approval.

### A revision is not a stage

A document can be revised without a stage. A revision needs no plan version and
appears in no stage table. It is how a review gets answered and how an accepted
decision gets folded in.

The versioning is the agent's work: write the next version number, leave the old
file on disk, add a *Superseded* row naming what replaced it, repoint the live
pointers in the status file, append to the log.

**The rule that matters:** a revision that moves a decision has consequences in
the code. The agent names the source files that would change and **stops there**.
Rewriting the code is a separate instruction, and the build matrix must be green
again before the revision is finished.

### Provenance, and why it is not a pointer

Every stage output names, in its opening line, the document versions it was
written against. Those are **provenance**: they record what was true when the
stage ran. They are never repointed to a newer version. Only the live pointers
in the status file move.

The corollary, which comes up whenever files are reorganized: **a path is not a
pointer.** Correcting `foo-001.md` to `backup/foo-001.md` changes where a file
is, never which version is named. That is allowed. Repointing provenance at a
*newer* version is what the rule forbids.

### `backup/`

Nothing is deleted. Superseded versions, and raw drafts that a review has
retired, move to `<port>/backup/`. The live folder holds only what a current
reader needs; `backup/` is the record.

When files move, **every link naming them is corrected in place, in both
directions** — the links pointing at the moved file, and the links inside it
pointing back out. The second direction is the one hand-editing misses. Resolve
each link by basename against where the file actually is, with a script, and
verify zero dangling links afterwards. `kitchen/tools/relink_md.py` does exactly
this: it reports by default, rewrites with `--apply`, and exits non-zero if any
link dangles. A clean second run is the proof the first one finished.

It rewrites **links** and never bare filename mentions in prose, which is the
provenance rule holding: correcting where a file lives is allowed, repointing a
record at a newer version is not, and no tool can tell those apart from the
text.

### Raw drafts are input, never source of truth

A port folder usually starts with a pile of `.md` written in separate sessions
by different AIs. They overlap, they contradict each other, and some predate the
current API. The flow does not read them repeatedly. One early stage **measures**
them against the specification and produces a review; every later stage reads
the review, not the drafts, and the drafts go to `backup/`.

### The negative-test taxonomy

Three shapes, and a port needs all three. None of them is language-specific.

| Shape | Behaviour |
|---|---|
| **runtime negative** | Aborts in every build where the checks are live. In a build where they are compiled out, runs to the end, prints a line containing `no check`, exits 0. |
| **tier-1 negative** | Aborts in **every** build, including the fastest. Reserved for the preconditions the specification refuses to soften. |
| **compile-time negative** | Never compiles, in any build, **and the diagnostic must name the offending type.** A refusal with an unhelpful message is a half-failure. |

### Compile is judged separately from run

The hardest-won rule in this file, and the reason it is here.

A "compile and run" command reports a compile failure the same way it reports a
crash: a non-zero exit. So a negative program that *stopped compiling* is read as
a negative program that *aborted*, and passes forever having proved nothing.

That is not hypothetical. 3tk's tier-1 pool negative — the one exercising the
single precondition the specification refuses to soften — had never compiled. It
was reported green in every build, in every mode, across two stages. The harness
must compile first, judge that, and only then run and judge that.

### Sabotage verification

**A check that has never been observed failing proves nothing.** After adding a
check and its negative test, break the check on purpose, confirm the suite goes
red, and put it back. A negative test is a claim about the future; the only
evidence for it is having seen it fire.

### The build harness

One script in the port folder. It iterates every build mode, and for each: builds
the library, runs the test suite, runs every negative of all three shapes, and
reports pass/fail counts. It exits non-zero on any failure and needs nothing but
the compiler on the path.

It must be runnable **without an agent**. The owner verifying the port should not
need a session to do it.

### Terminology, in all prose, in every port

- **inner** = the embedded structure. **outer** = the struct that embeds it.
  **Never "parent".**
- **Slot** = a container of one handle or nothing.
- Porting is not transpiling. The specification says what to preserve; each port
  decides how to spell it.

---

## Tier 2 — the question transfers, the answer does not

Copying a finished port's answer here is the error this file is guarding against.
In each row, take the left column and re-derive the right one.

| The question every port must answer | What 3tk answered, as an *example only* |
|---|---|
| **What is the build matrix?** Enumerate the axes that change what code exists — checks on/off, optimization, runtime present/absent. Test **every** combination. Never infer one axis from another. | Four builds: `--safe` × `-O`. And the trap that made the rule: `-O2` and above silently set `SAFE_MODE=false`, so the "safe, optimized" build had to be spelled `--safe=yes -O3` or it was not that build at all. **The count is not portable. Neither is the trap.** |
| **What is the assert policy?** Matryoshka needs at least three tiers: one that aborts always, one that vanishes in a fast build, one that never compiles at all. What does the language give? | `always_assert` / a `@check` macro that is compiled out entirely / a `$if CHECKED:` block. Three C3 spellings of three portable ideas. |
| **How is the layering enforced?** The containers must be built *on* the intrusive layer with no privileged access. Is that enforceable by the compiler, or only by convention plus a grep? | C3 got it free: a submodule cannot see its parent's private declarations. Another language will get less, or get it differently. Whatever the answer, do not overclaim it. |
| **How are outcomes returned?** The specification's outcome sets — empty, timeout, closed — must reach the caller. What is the idiomatic mechanism, and what does it cost? | A fault-return operator. Zig uses error unions. A language whose exceptions allocate has a real constraint here. |
| **How is a type's identity spelled?** | A compiler-provided type id, where one exists and compiles. |
| **What is the capability study?** Answer the specification's Part 21 questionnaire for the language, one citation per answer, and mark each **verified** (compiled and run) or **read** (from stdlib sources only). | `c3-capabilities-001.md`. The *form* is tier 1; every answer in it is tier 2. |

Also tier 2: the porting proposal's section skeleton — a numbered decision log
with a recorded reason per decision, surface tables, a counts glossary saying
what each number counts, a terminology table. Good scaffolding. Every entry
re-argued.

---

## Tier 3 — not borrowed, shared

The specification and the ztk audit are not copied into a port folder. They live
here, and a port links to them. A defect a port finds in them is fixed **here**,
once, in a new version, and every port reads the new version.

See [README.md](README.md) for why.

---

## The stage sequence, as a template

3tk ran eight stages. The sequence generalizes, but **a port is entitled to a
different one** — its risks are its own, and a front-loaded design problem
deserves its own early stage even though no earlier port needed it.

| # | What | Output |
|---|---|---|
| 0 | the staging plan, status, log | the folder |
| 1 | audit the reference implementation | an evidence document *(already done — [ztk-audit-001.md](ztk-audit-001.md))* |
| 2 | the portable specification | *(already done — the specification)* |
| 3 | measure the port folder's raw drafts against the specification | a review that retires the drafts |
| 4 | the capability study | Part 21 answered for the language |
| 5 | the porting proposal | the design of record |
| 6 | the toolkit: inner, identity, per-type helper, Slot, list | code + notes |
| 7 | the two containers: mailbox, pool | code + notes |

Stages 1 and 2 are **done once for the family**. A new port starts at the
equivalent of 3, and its own stage 0.

---

## What a port may not do quietly

- Renumber or rewrite a finished stage's output.
- Repoint a provenance line at a newer document version.
- Report a build matrix it did not run in full. *A stage that reports three
  builds when there are four has not run.*
- Claim a check is enforced more strongly than it is.
- Count a negative test as passing without having seen it fail.
