# 3tk — staging plan 021

Written 2026-08-31.

**Provenance.** Follows [3tk-staging-plan-020.md](backup/3tk-staging-plan-020.md). 020
carried **3TK-50** forward unchanged and declared **3TK-51 to 3TK-55**. All of
that has since run — 3TK-50 closed across eleven steps (`3tk-log.md`, 2026-08-31),
3TK-51 through 3TK-55 all ran 2026-08-28, and **3TK-56 also ran** (2026-08-30,
closing `P6`) without a separate declaration, since it fell directly out of
3TK-54's own measurement. **020 is fully spent.** This plan declares one stage:
**3TK-57.**

State is in [3tk-status.md](3tk-status.md). Narrative is in
[3tk-log.md](3tk-log.md). Neither is duplicated here.

---

## Why this plan exists

**Everything 3tk builds and tests locally — `run-builds.sh`'s four modes,
`run-sanitizers.sh`'s three sanitizer runs — has no automated check on a push
or a pull request.** The owner asked for GitHub Actions workflows, patterned on
the ones already in this repo for ztk (`.github/workflows/linux.yml`,
`mac.yml`, `windows.yml`, `docs.yml`), but adapted: c3c has no `setup-c3`
action the way Zig has `mlugg/setup-zig`, 3tk's toolchain is measured only on
linux-x64, and the owner does not want CI invoking `run-builds.sh` or
`run-sanitizers.sh` as scripts — the workflows replicate their underlying
commands directly as steps, the same way ztk's workflows call `zig build test`
directly rather than through a wrapper.

**Four decisions the owner made, binding on 3TK-57:**

1. **Linux only.** No macOS/Windows legs — the port calls pthread directly and
   has never been tried on either.
2. **Sanitizers in their own file, manually triggered** (`workflow_dispatch`
   only, never push/PR), installing their own compiler (clang) rather than
   assuming the runner has it.
3. **Negatives, tier-1 aborts and nocompile checks stay local-only.** CI runs
   build+test per mode; `run-builds.sh` remains the full local gate.
4. **The docs workflow does only the `c3c docgen` flow** — no mkdocs, no
   `kitchen/tools/*.sh` equivalent. `c3c docgen` already produces a complete,
   self-contained doc site; there is nothing for it to wrap.

**One call flagged for the owner to override, not yet resolved:** this repo's
Pages deployment already belongs to ztk's `docs.yml`. A second workflow
calling `deploy-pages` without coordination would clobber it. **3TK-57's docs
workflow builds and uploads the `c3c docgen` output as a workflow artifact
only — it does not deploy to Pages** until the owner decides how the two doc
sets should coexist on one site.

## The stage

```
3TK-57   GitHub Actions CI for 3tk      .github/workflows/ + README.md
```

**Why one stage and not several.** Unlike 3TK-51–55, nothing here is staged on
an unresolved design question — the four decisions above are already made, and
the three workflow files have no dependency order between them. Splitting them
into separate stages would only fragment one afternoon's work across several
clear points for no reason the *Five stages means five clear points* logic in
020 actually needed.

---

## 3TK-57 — GitHub Actions CI for 3tk

**Output: three new workflow files, plus three README badges.**

| file | trigger | what it does |
|---|---|---|
| `.github/workflows/3tk-linux.yml` | push, pull_request, workflow_dispatch; `paths: design/secondary/lang/c3/3tk/**` | `c3c build mtk` + `c3c test`, matrix `safe:[yes,no] × opt:[O0,O3]` — the same four combinations as `run-builds.sh`'s `MODES` |
| `.github/workflows/3tk-sanitizers.yml` | workflow_dispatch only | installs clang, then `c3c test --sanitize=<thread\|address> --cc clang` for the same three combinations `run-sanitizers.sh` runs (`thread safe-O0`, `thread fast-O3`, `address safe-O0`), 15-minute timeout per run |
| `.github/workflows/3tk-docs.yml` | push to `main` with `paths` on `3tk/src/**` and `3tk/examples/**`, plus workflow_dispatch | `c3c docgen --emit-stdlib=no src examples`, uploaded as a build artifact — not deployed |

**Installing c3c.** No `setup-c3` action exists. Confirmed against the GitHub
API: `v0.8.3`'s Linux asset is `c3-linux.tar.gz`, which extracts to `c3/`
containing `c3/c3c` and a bundled `c3/lib/std/` — self-contained, matching the
version 3tk's own capability answers are measured against
(`3tk-status.md`: "c3c 0.8.3, LLVM 22.1.8, linux-x64"). Every workflow installs
it the same way:

```yaml
- name: Install c3c
  run: |
    curl -sL https://github.com/c3lang/c3c/releases/download/v0.8.3/c3-linux.tar.gz -o c3.tar.gz
    tar xzf c3.tar.gz
    echo "$PWD/c3" >> "$GITHUB_PATH"
```

**Every 3tk workflow scopes itself.** Unlike ztk's workflows, which own the
whole repo, each 3tk file needs `paths:` (where it triggers on push/PR) and a
job-level `working-directory: design/secondary/lang/c3/3tk`, since 3tk is one
subtree in a multi-port repo.

**README.md gains 3 more badges**, top of file alongside the existing 4, one
per new workflow, same style: `.../actions/workflows/<file>.yml`.

**Tests, and the stage does not close without them checked:**

- Each new workflow file parses as valid YAML.
- Every command in every workflow matches, field for field, what
  `run-builds.sh` / `run-sanitizers.sh` / `preview-docs.sh` actually run —
  checked against their source, not paraphrased.
- The c3c download step is verified against the live GitHub API response for
  `v0.8.3` (asset name, extracted layout) before being written into the
  workflow files, not assumed.

**What is not verified from here, and is the owner's step once pushed:** that
the c3c download step actually succeeds on `ubuntu-latest`, and that
`apt-get install clang` on `ubuntu-latest` pulls in whatever `libtsan`/`libasan`
the sanitizer runs need — unlike this Fedora machine, which is missing them
under its default `cc`. **No stage runs `git`.** The files are written; the
owner pushes and watches the first run.

---

## Rules that hold

- **`run-builds.sh` stays green throughout** — nothing in 3TK-57 touches
  `3tk/src`, `test/`, `negative/` or `examples/`, so the counts do not move.
- **No stage runs `git`.** Moves are plain `mv`. The owner saves and pushes.
- **A claim about c3c is measured, never argued** — the download URL and
  tarball layout above were fetched and inspected, not assumed from memory.
- **The Pages-collision question is written down, not guessed at.** 3TK-57
  does not deploy to Pages; it stops at "build and upload as a workflow
  artifact" and leaves the coexistence question open.

## Versioning

**`3tk-staging-plan-020.md` is superseded by this file** and moves to
`backup/`. Nothing else this stage produces is a versioned document —
`.github/workflows/*.yml` and `README.md` are edited in place, same as any
other source file a stage touches.

## What this plan leaves to the owner

- **The Pages-collision question.** A subpath, a merge step before one
  `deploy-pages` call, a separate deployment mechanism (e.g.
  `peaceiris/actions-gh-pages` targeting a subfolder of `gh-pages`) — or 3tk's
  docs staying artifact-only indefinitely. Not decided here.
- **Whether macOS/Windows legs ever get added**, and who confirms the port
  actually builds there first.
- **Whether sanitizers stay manual-only**, or graduate to a scheduled or
  push-triggered run once the workflow has been exercised a few times.
- **The seven questions plan 018 left and 019 carried**, and everything in
  `3tk-status.md`'s *Open questions* — untouched by this stage, and not
  reopened by it.
