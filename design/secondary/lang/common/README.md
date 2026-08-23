# lang/common — what binds every port

The Matryoshka port family is **otk** (Odin), **ztk** (Zig, this repo), **3tk**
(C3) and **dtk** (D). Each has its own folder beside this one, holding its own
plan, status, log, notes and code.

This folder holds what is **not** any one port's: the documents every port is
written from, and the process every port follows.

## What is here

- **[matryoshka-specification-002.md](matryoshka-specification-002.md)** — the
  portable specification. Self-contained and language-neutral. *A port is
  written from this file alone.* Source of truth for all four ports.
- **[ztk-audit-001.md](ztk-audit-001.md)** — read-only evidence about ztk, the
  reference implementation. Every claim names a file and a line range. It is the
  specification's own input, and it is about Zig, not about any port.
- **[port-flow-001.md](port-flow-001.md)** — how a port is run. The process
  3tk proved, written as process, with C3's answers left out.
- `backup/` — superseded versions of the above. Nothing is deleted.

## The rule this folder exists to enforce

**A port folder never copies these files. It links to them.**

The specification lived inside `c3/` until 2026-08-23, and the cost showed up
the first time it was reviewed: two of the twenty-seven items raised against the
C3 proposal were *specification* defects. Had they been fixed only in the C3
document, the same trap would have been left set for D and Odin. A shared input
that lives in one consumer's folder is a fork waiting to happen.

So a defect found by any port against these documents is fixed **here**, once,
in a new version — and the other ports read the new version.

## The rule about borrowing from a port folder

`port-flow-001.md` is here because it is process. Everything else a finished
port produced — its capability study, its proposal, its notes — stays in that
port's folder. Those are worth reading, and they are **not** worth copying: they
are one language's answers, and the next language's questions are only sometimes
the same. `port-flow-001.md` says which is which.

## Where the ports are

| Port | Language | Folder | State |
|---|---|---|---|
| ztk | Zig | this repo's `src/` | the reference implementation; green, needs tuning |
| 3tk | C3 | [`../c3/3tk-status.md`](../c3/3tk-status.md) | complete through 3TK-7 |
| dtk | D | [`../d/dtk-status.md`](../d/dtk-status.md) | prepared, no stage has run |
| otk | Odin | `../odin/` | needs refactoring; no status file yet |
