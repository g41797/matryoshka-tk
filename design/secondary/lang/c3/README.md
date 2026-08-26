# lang/c3 — the 3tk port

The C3 port of Matryoshka. Everything the port has produced lives here: plans,
status, log, notes, reviews, and the code at [`3tk/`](3tk/). What binds *every*
port — the portable specification, the ztk audit, the port process — lives in
[`../common/`](../common/README.md) and is linked, never copied.

**This file is an index.** One line per live file: what it is, and who reads it.
It re-describes no document's content and rules on nothing.

## Start here

| File | What it is | Who reads it |
|---|---|---|
| [3tk-status.md](3tk-status.md) | Where the work stands. Edited in place | **Anyone opening this folder, first.** A cold session starts here |
| [3tk-staging-plan-019.md](3tk-staging-plan-019.md) | The current plan. Holds only what has not run | **The owner**, to authorize a stage; **a stage**, to run it |
| [3tk-log.md](3tk-log.md) | The narrative, append-only, newest first | Anyone asking *when did this happen, and why* |

## `ref/` — revised with the source, not frozen

**Every other file in this folder is a finished stage output**, frozen at the
moment its stage ran. **These are the opposite: they are alive.** A change to
`3tk/src` revises them in the same stage that changes it.

| File | What it is | Who reads it |
|---|---|---|
| [ref/3tk-api-002.md](ref/3tk-api-002.md) | Using the toolkit: what each thing is for, when to reach for it, what it refuses | **Anyone calling the port.** The page to learn it from |
| [ref/3tk-decisions-002.md](ref/3tk-decisions-002.md) | What was decided, its marker, and where it lives in the code. Nine sections | The owner, and any AI, **instead of travelling through this folder** |
| [ref/3tk-api-003.md](ref/3tk-api-003.md) | The same surface as a verification table: every assert and contract with its `file:line` | Anyone checking that 002 is true. **Not a page to learn from** |
| [ref/3tk-reference-002.md](ref/3tk-reference-002.md) | The toolkit as a book. Seven parts, in 042's shape, with the eight labelled module blocks in Part 7 | Anyone reading the port end to end |
| [ref/3tk-doc-loop-003.md](ref/3tk-doc-loop-003.md) | **Not content — procedure.** How the reference and the `<* *>` blocks in `3tk/src` are kept saying the same thing | Any stage editing either side, before it edits |
| [ref/3tk-example-rules-001.md](ref/3tk-example-rules-001.md) | **Not content — procedure.** What an example under `3tk/examples/` must be, and what binds a stage that adds one | Any stage writing an example or the pattern catalog, before it writes |
| [ref/3tk-patterns-001.md](ref/3tk-patterns-001.md) | The pattern catalog: 62 shapes a person assembles the toolkit into, every code block compiled | **Anyone writing an application on 3tk**, after the API page; any stage writing an example |

## Read from elsewhere

| File | What it is | Who reads it |
|---|---|---|
| [../common/matryoshka-specification-004.md](../common/matryoshka-specification-004.md) | The portable specification. Source of truth for all four ports | Every port. **A port is written from this file alone** |
| [../common/ztk-audit-001.md](../common/ztk-audit-001.md) | Read-only evidence about ztk, the reference implementation | The specification's own input |
| [../common/port-flow-001.md](../common/port-flow-001.md) | How a port is run, written as process | The next port, before its first stage |

## The design of record

| File | What it is | Who reads it |
|---|---|---|
| [3tk-porting-proposal-004.md](3tk-porting-proposal-004.md) | Sixteen decisions, accepted 2026-08-23. The design of record for everything the redesign did not touch | Anyone changing the port's shape |
| [3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md) | The redesign as ruled — R1 to R15 with R6b. What replaced part of 004 | Anyone reconstructing why the core is what it is |
| [3tk-helper-proposal-001.md](3tk-helper-proposal-001.md) | The helper surface: fifteen compiler measurements, eleven items, all ruled 2026-08-24 | Anyone changing `3tk/src/helper.c3` |
| [c3-capabilities-001.md](c3-capabilities-001.md) | What C3 can and cannot do, measured | A C3 question about the language, not the port |

## The port measured

| File | What it is | Who reads it |
|---|---|---|
| [3tk-deviations-001.md](3tk-deviations-001.md) | The port measured against the specification, deviation by deviation | Anyone asking whether 3tk conforms |
| [3tk-port-findings-003.md](3tk-port-findings-003.md) | What 3tk does and why, in ten sections. **The only document here written to be read by another port.** Describes and recommends nothing | **dtk and ztk** |
| [3tk-readership-001.md](3tk-readership-001.md) | Who reads each of the seven notes files, and when | The owner, deciding what is spent |

## The notes

Each is a finished stage's record. The reader column is the readership file's,
above, and is not re-argued here.

| File | What it is | Who reads it |
|---|---|---|
| [3tk-toolkit-notes-001.md](3tk-toolkit-notes-001.md) | F1 to F9: what the C3 toolchain does | A later port, at its capability study |
| [3tk-containers-notes-001.md](3tk-containers-notes-001.md) | The toolkit notes continued, on containers | The same reader, the same occasion |
| [3tk-sanitizer-notes-001.md](3tk-sanitizer-notes-001.md) | Seven findings, and the working route on a machine without sanitizer runtimes | Whoever next runs a sanitizer here |
| [3tk-helper-notes-001.md](3tk-helper-notes-001.md) | What building the ruled helper surface taught | One future editor of `helper.c3` — §8 only |
| [3tk-core-redesign-notes-001.md](3tk-core-redesign-notes-001.md) | What writing the redesign taught | Nobody, in normal work |
| [3tk-debts-notes-001.md](3tk-debts-notes-001.md) | The two debts of 3TK-13, paid | Nobody |
| [3tk-drafts-review-001.md](3tk-drafts-review-001.md) | The review that retired the seven raw drafts | Nobody |

## Open, and not ruled on by anything

| File | What it is | Who reads it |
|---|---|---|
| [3tk-who-supports-slot.md](3tk-who-supports-slot.md) | From the owner. Argues the containers should not support the Slot idiom at all | **The owner.** Answering it either way retires the file |
| [3tk-doc-split.md](3tk-doc-split.md) | From the owner. The source files serve the AI, not the user, and cannot build documentation | **3TK-29 to 3TK-31**, as their input; **the owner**, to rule on it |

## The code

[`3tk/`](3tk/) — the port itself. `src/` is eight files, `test/` ten, `negative/`
the compile-failure cases.

```
./3tk/run-builds.sh        # four builds, exits non-zero on any failure
./3tk/preview-docs.sh      # the doc comments as a reader sees them, in a browser
./3tk/check-doc-loop.sh    # every descriptor line, and every module block, against the reference
./3tk/move-module-docs.sh  # a module description, reference <-> src, copied and diffed
./3tk/run-sanitizers.sh    # thread on two builds, address on one; exits 2 if its compiler is missing
```

The two build scripts take an optional directory; with no argument each runs
against its own. `check-doc-loop.sh` takes source file names, and with no
argument reads all eight. `move-module-docs.sh` takes a direction — `in`, `out`
or `roundtrip` — and module names, and with none moves all eight. The format it
copies lives in `3tk/doc_blocks.py`, which both scripts read.

`backup/` holds superseded versions and what is no longer read. **The owner
empties it periodically, so nothing here points into it.**
