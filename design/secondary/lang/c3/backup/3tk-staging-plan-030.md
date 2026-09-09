# 3tk — staging plan 030

Written 2026-09-08.

**Provenance.** Follows [3tk-staging-plan-029.md](backup/3tk-staging-plan-029.md),
which follows `028`, `027` and `026`. **Those are named, not linked as sources:
`backup/` is transient — the owner empties it — and it is never cited as a source
of truth.**

**029 ran four stages and is spent.** `3TK-67`, `3TK-65`, `3TK-66` and `3TK-68`
all ran on 2026-09-08 and all closed. **One stage of 029 has not run — `3TK-69` —
and a second owner sitting the same day settled every question its charter left
open.** That is a different charter, not an edit to one, and a plan version is not
rewritten in place.

State is in [3tk-status.md](3tk-status.md). Narrative is in
[3tk-log.md](3tk-log.md).

**The rules every stage is written against are in
[matryoshka-3tk/design/3tk-rules-001.md](https://github.com/g41797/matryoshka-3tk/blob/main/design/3tk-rules-001.md)**
— created by `3TK-67`, in two parts, the port rules and the stage rules. **029's
Rules 1 to 7 live there now and are not restated here.** This plan cites that
file; it does not re-argue it.

**No stage is renumbered.** `3TK-69` keeps the number it has had since 029.

---

## Spent stages

**`3TK-67` — the landing page, the marker, and the rules file — ran 2026-09-08.**
**`3TK-65` — the safe-build checks — ran 2026-09-08.** **`3TK-66` — the books and
the examples — ran 2026-09-08.** **`3TK-68` — the names and the scripts — ran
2026-09-08.** Their charters are removed. What they did is in
[3tk-log.md](3tk-log.md) and the state they left is in
[3tk-status.md](3tk-status.md).

**Everything 029 recorded as spent stays spent** — `3TK-pre-65`, `3TK-62`,
`3TK-63`, `3TK-64` and the INTR of 2026-09-07. None is re-opened here.

**The order inversion is spent too.** 029 ran 67, 65, 66, 68 deliberately out of
numeric order and said no later stage corrects it. Nothing left depends on it;
`3TK-69` is last by every ordering.

---

## What the second sitting of 2026-09-08 ruled

**Twelve rulings, all about the source LOC, and together they replace everything
029's `3TK-69` charter left open.** They are stated once, here. `3TK-69` applies
them; it does not re-decide them.

**None of them is a rule in the sense `3tk-rules-001.md` uses** — they bind one
stage, not every future one — **except `L-9`, which restates Rule 5 and which
`3TK-69` carries into that file.**

### L-1 — what a line is

**Every line under `src/` that is real code.** Not counted: **blank lines**,
**comments**, and **the machinery** — `import`, `$include`, `$exec`, `$embed` and
anything else that is not the port's own code.

**The definition is ztk's and 3tk copies the definition, not the code.**
`kitchen/tools/src_loc.py` counts a `src/*.zig` line when, stripped, it is
non-empty, does not start `//`, and is not an `@import(` line beginning `const`,
`pub const`, `var`, `pub var` or `@import(` itself.
`kitchen/tools/count_src_loc.sh` is a four-line wrapper that resolves `../../src`
and prints the total.

**The C3 scanner is harder for one reason, and it is the reason it is written
fresh:** C3 has `/* */` block comments and `<* *>` doc blocks, which are **state
carried across lines**, not a per-line test. A `startswith` scan is wrong here.

**`src/*.c3` was 2,073 lines raw on 2026-09-08.** That figure is the raw `wc` and
is **not** the number this definition produces.

### L-2 — the scripts live in `matryoshka-3tk/scripts/`

Not `kitchen/tools/`, which is the ztk and kitchen line's. This is 3tk's own
tooling and it belongs with 3tk's other four scripts.

### L-3 — two scripts, not one

**The counter** computes the number and prints it. **It is useful alone, and the
owner has ruled that the console is enough** — that half of `3TK-69` stands
whatever happens to the injection.

**The injector** runs the counter and substitutes the result. It is a separate
program because its failure modes, its flags and its consumers are different.

**Both follow the convention the four ported scripts already have: an optional
directory argument, and exit 2 on a bad one.**

### L-4 — the number is injected into `src/mtk.c3`, not into the generated HTML

**Ruled by the owner against the session's own first recommendation, and the
argument is durability.** `docs.yml` already patches `docs.html`, and that patch
is **coupled to docgen's output shape** — its own comment says a future c3c that
reshapes the function must be caught there. A placeholder in `mtk.c3` is **a
string 3tk owns**, which no c3c release can move.

### L-5 — the placeholder is `[[LOC]]`

**Literal replacement, no regex.** The spelling was chosen against three tests:
it has **no meaning in C3**; it is **not an `@`**, which would look like a
contract directive and invite a false check; and it **reads as a slot** to a
human in both the source and the book.

**`[[NAME]]` is reserved as the shape for every future token** — a date, a
version, a test count — so the next one needs no decision.

### L-6 — there is no template file

**The token alone is the contract.** `mtk.c3` carries the sentence — *"We present
you `[[LOC]]` lines…"* or whatever the owner writes — and the script knows only
`[[LOC]]`. **The prose is then edited freely without touching the script, which
is the whole point of the proposal.**

**A file holding the sentence was considered and rejected: it would be a second
place that must match `mtk.c3` byte-for-byte**, so editing the prose would
silently stop the match — reintroducing one level up exactly the coupling the
proposal removes.

**If a file is ever wanted, it maps token → producer**, `[[LOC]] =
scripts/count_src_loc.sh`, **never token → sentence.** That form stays in sync by
construction and extends to a second token.

### L-7 — running it locally is a MUST, and a local run does not dirty the tree

**Dry run is the default.** The injector reports what it would change and where,
and **writes only under an explicit flag**. CI passes the flag; a person does not
unless they mean it.

### L-8 — CI substitutes in place, in its own checkout, never into a copied tree

**Measured, not assumed.** `docs.yml`'s existing patch builds source links as
`'https://github.com/g41797/matryoshka-3tk/blob/main/' + filePath`. Inject into a
`build/src/` copy and docgen records that path, so **every "Defined in" link on
the published site 404s.** In-place in the runner keeps `filePath` correct, and
the checkout is thrown away regardless.

### L-9 — Rule 5, restated: generated content is never *committed*

The rule as 029 wrote it was *generated content never edits a checked-in source*.
**It is sharpened, not broken:** *generated content is never **committed**, and
is injected downstream of the checkout.*

**The three harms Rule 5 names are what the rule is for, and all three are still
avoided:** the doc loop never sees a moving number, because the committed source
and `3tk-reference-008.md` both carry the token; the two repos do not diverge,
because both carry the same committed line; and no working tree comes back dirty,
because the only write happens in CI's ephemeral checkout or under a flag the
person typed.

**`3TK-69` carries this sharpened wording into `3tk-rules-001.md`'s port rules,
replacing Rule 5's current sentence.**

### L-10 — strict in CI, lenient locally

**A missing `[[LOC]]` in CI is an error and fails the job.** The alternative is a
site that publishes the placeholder with nobody noticing. **Locally it is a
report**, since a person may be running the check against a tree that has not
grown the token yet.

**Every occurrence is replaced, and the count is printed**, so a second use site
is never half-substituted.

### L-11 — nothing enters the language

No module, no `project.json` change, **no `$include`, and therefore no
`--trust=include`.** The manual requires trust level 2 for `$include`, and that
flag would have to be added to `run-builds.sh`'s four builds, `linux.yml`'s four
matrix legs, `sanitizers.yml`, docgen in `docs.yml` — **in both repos** — and to
**every downstream build that compiles 3tk as a dependency**. For a library whose
subject is being embedded in someone else's project, a build that fails under
default trust is a cost charged to every user.

**One thing would reverse this, and it is the owner's to rule: a decision that a
program must be able to read the count as a constant.** Shapes where that is
wanted exist — a banner printing `mtk 0.1.0, N lines`, an `about` string, a test
asserting a size budget. **Nothing reads such a constant today**, so the flag
would buy a value with no consumer. **The question is recorded, not assumed
either way. If the owner rules it in, `3TK-69` becomes an Opus 5 stage and the
`$include` shape returns** — with one point in its favour already established:
the `$include(…)` line inside the source is **fixed text**, so the doc loop would
not see a moving number there either.

### L-12 — the cost that is accepted, written down

**`[[LOC]]` appears in the published book.** `check-doc-loop.sh` requires
`src/mtk.c3`'s module block and `3tk-reference-008.md` to be identical, so the
token is carried in both, and a reader of the reference sees it.

**The alternative was a placeholder sentence true as written, swapped wholesale
by CI** — which keeps the book clean but pins the prose to the script, and `L-6`
ruled the other way. **This is the trade for editing the prose freely, and it is
accepted.**

---

## 3TK-69 — the source LOC

**The only stage of this plan, and the last of the line 026 opened.**

**Model: Sonnet 5.** Rule 7 cuts both ways and this is the side it usually does
not: the deciding was spent in the sitting above, and what is left is applying
`L-1` … `L-12` — two scripts against a written definition, one token, one
workflow step, and a re-measurement whose expected figures are stated in advance.
**If the owner rules `L-11`'s question in, this becomes Opus 5**, because the
trust-level trade and the `$include` shape come back with it.

**The goal:** a source line count, computed on demand, printed on the console,
and shown with the generated documentation.

### Step 1 — the counter

Write the counting script and its scanner in `matryoshka-3tk/scripts/`,
implementing `L-1`. A C3 scanner must carry state across lines for `/* */` and
`<* *>`. **Test it on a file that has every shape in it** — a block comment
opened and closed on one line, one spanning lines, a doc block, an `import`, a
line that is code with a trailing comment — before trusting the total.

**Print the number and nothing else**, so `$(…)` consumes it without parsing.

**Then state the figure in the log entry**, beside the 2,073 raw lines, so the
difference between the two is on the record.

### Step 2 — the token in the source

Write the sentence carrying `[[LOC]]` into `src/mtk.c3`'s module doc block, and
**the identical sentence into `3tk-reference-008.md`** — the doc loop compares
them and it must stay at 409 of 409.

**`src/mtk.c3` is edited in `matryoshka-tk` only**; the reference is edited
directly in `matryoshka-3tk/design/`.

### Step 3 — the injector

Write it in `matryoshka-3tk/scripts/`, implementing `L-3`, `L-5`, `L-6`, `L-7`
and `L-10`: run the counter, replace every `[[LOC]]`, dry run by default, write
under a flag, strict when CI runs it, and print how many occurrences it changed.

### Step 4 — `docs.yml`

One step in `matryoshka-3tk/.github/workflows/docs.yml`, **before `c3c docgen`**,
running the injector with the write flag against the runner's own checkout
(`L-8`). **The existing "Defined in" patch is not touched.**

### Step 5 — the rules file

Carry `L-9`'s sharpened wording into `3tk-rules-001.md`'s port rules, replacing
Rule 5's sentence. **Nothing else in that file moves.**

### Verification

- **`run-builds.sh` at 107 checks, 0 failures, four builds, 145 tests each** —
  every figure identical. Nothing this stage does touches a declaration.
- **`check-doc-loop.sh` at 409 of 409, 0 differing, 0 banned words**, with the
  token in both files. **If the token makes a block differ, the sentence is not
  identical on the two sides** — that is the failure to look for first.
- **The counter run twice on an unchanged tree gives the same number.**
- **The injector's dry run reports one occurrence; the tree is unchanged after
  it.** Then the write path is exercised on a scratch copy, never on `src/`.
- **The injector fails loudly with no token**, tested by running it against a
  tree that has none — `Rule 8`: a new check is broken in both directions before
  it is trusted.
- **`matryoshka-3tk/scripts/` diff:** the four ported scripts still differ from
  this repo's only in the `ROOT` line. **The two new scripts have no copy in
  `matryoshka-tk`** — they are written where they live, which is the first time
  a 3tk script is not ported, and the log says so.
- **The `.yml` review**, `docs.yml` in scope and this time it does change; the
  log states what the other two needed, and *"none needed"* is an answer.

---

## 3TK-50 — unchanged, and independent

**It has no next step** — every catalog section with a code shape is covered —
and it is not blocked by, and does not block, anything above. **It waits on the
owner** to say what closes it: copying and pushing the last steps to
`matryoshka-3tk`, and updating the status table.

---

## Versions written, and what moves to backup

**This plan.** `029` moves to `design/secondary/lang/c3/backup/` with a plain
`mv`, joining 019–028.

**Nothing else is versioned by this plan.** `3TK-69` edits
`3tk-reference-008.md` and `3tk-rules-001.md` **in place** — a sentence and a
rule's wording, under the standing ruling that design documents in
`matryoshka-3tk/design/` are edited there directly.

**Edited in place, not versioned:** `3tk-status.md`, `3tk-log.md` (append-only,
newest first). Every `.c3` file is edited in place — sources are not versioned.

**No new file is created in `matryoshka-3tk/design/`**, so the standing
ask-the-owner-first rule is not engaged. **The two new scripts go in
`matryoshka-3tk/scripts/`, which `L-2` settles.**

---

## Standing constraints

Carried from 029 unchanged, because none of them was touched. Restated in full so
this plan is enough on its own.

- **Git is disabled.** No stage runs `git`. Moves are plain `mv`; the owner
  saves.
- **No destructive command after a `cd`.** A failed `cd` aborts the `&&` chain
  but **not the next statement**. It has cost a plan file once and put two stray
  files in the repository root once. Absolute paths are the fix, and a stage that
  writes `mkdir … && cd …` checks that the target is a directory and not an
  existing file.
- **3tk sources are edited in `matryoshka-tk` only.** The owner copies to
  `matryoshka-3tk`. Design documents under `matryoshka-3tk/design/` are the one
  place edited directly — **and the owner is asked where before any new file is
  created there, every time.**
- **Every stage tunes `matryoshka-3tk/scripts/` and
  `matryoshka-3tk/.github/workflows/` to the changes it made in `matryoshka-tk`.**
  It is **part of the stage, not a follow-up.**
  - **The port is one line.** The four scripts are byte-identical except that
    `ROOT` gains `/..`. Copy, re-apply that line, `diff`, and require the ROOT
    line to be the only difference. **That diff is the verification.**
  - **The four are** `run-builds.sh`, `run-builds-light.sh`, `run-sanitizers.sh`,
    `preview-docs.sh`. `check-doc-loop.sh`, `move-module-docs.sh` and their two
    Python modules are **not** ported and are not to be. **`3TK-69`'s two new
    scripts are written in `matryoshka-3tk/scripts/` directly and have no
    `matryoshka-tk` copy.**
  - **The `.yml` files are the one thing a stage may edit directly in
    `matryoshka-3tk`**, and a stage states in its log entry whether they needed a
    change — **"none needed" is an answer and must be written down.**
  - **Read the workflow files before saying they need no change.** A grep for
    renamed symbols is not the check: `linux.yml` and `sanitizers.yml` run `c3c`
    inline, and `docs.yml` runs `c3c docgen`.
  - **CI is the matrix, and the matrix is enough.** `run-builds.sh` is never moved
    into CI and no stage proposes it; the negatives, the tier 1 lifetime programs
    and the `Part 17.2` greps are verified when the owner runs the script by hand.
    An accepted gap, written down as one.
- **No claim about C3 syntax is built on without a compile.** A scratch probe
  costs thirty seconds.
- `3tk-log.md` is **append-only**, newest first. Every stage gets an entry,
  however short.
- The banned-word scan skips `design/STATUS-LOG.md`, `design/secondary/` and
  `kitchen/defer/`; hits are reported, not fixed without approval.
- **The stage rules — compact/clear/nothing, the model recommendation, the
  exemplar before the sweep, the script-and-CI port, and *fix the definition, do
  not halt* — are in `3tk-rules-001.md`'s second part** and are not restated
  here. **This plan pins one model per charter: `3TK-69` is Sonnet 5**, on the
  basis in `L-11` and in the charter above. **Advice, not an action** — the
  choice stays the owner's, and a pinned name that has gone stale is not a reason
  to stall.

---

## What each stage must be told before it runs

**One question is open and it is the owner's: `L-11`** — whether a program must
be able to read the count as a C3 constant. **`3TK-69` proceeds on *no*, which is
what `L-11` rules**, and reports rather than assumes if it finds a reason to
doubt it.

**Nothing else is owed.** Every other question is answered in `L-1` … `L-12`
above.

**A stage that finds itself needing a design answer has found a gap in
`3tk-rules-001.md` or in this plan, and the gap is reported before the stage
continues.**
