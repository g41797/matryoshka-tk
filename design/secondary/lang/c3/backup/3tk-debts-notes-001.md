# 3TK-15 — the two debts of 3TK-13

Stage 3TK-15, 2026-08-24. Short, as the stage asked. What the new outcome is
called, what `get_wait` does and why, and which doc comments changed a claim
rather than a path.

Both halves were already decided when this stage started. Neither is a question
and nothing here re-argues one.

---

## A3 — the port broke a MUST in its own specification

### The outcome is called `UNKNOWN_IDENTITY`

`inner.c3:190`. One new member of the port's faultdef, reported by `Pool.get` and
`Pool.get_wait` and by nothing else.

**It is deliberately not a Part 19 outcome, and the faultdef's own comment says
so.** Part 11.7 fixes the pool's set of identities at creation, so asking for
one outside it is a defect of the caller, not a runtime condition — which puts
it outside the sentence that opens that faultdef, *these are runtime
conditions, never defects*. It exists only because the honest report of that
defect used to be `NOT_AVAILABLE`, which Part 19.3 reserves for the
available-only mode.

**Part 19.2's sets are untouched.** Every Part 19 outcome the two gets can now
produce is exactly what 19.2 lists. That was the verification the stage asked
for, and it passes by construction rather than by inspection: nothing was added
to a Part 19 row and nothing was removed from one.

The name was chosen over the alternatives because it names the caller's
mistake rather than the pool's state. `NOT_SERVED` and `WRONG_IDENTITY` both
read as conditions a correct program could meet.

### `get_wait` changed too, and the old behaviour was not broken

`pool.c3:417`. The stage left this open and asked for a reason either way.

The old behaviour was benign and conforming: `b` stayed null, the loop found
nothing, the call timed out, and Part 19.2 lists timeout for that operation. It
was changed anyway, on two grounds, and **neither of them is conformance** —
this is a quality change riding along with a conformance fix, and it is marked
as one so nobody later reads it as forced.

1. **The two gets must not disagree about the same defect.** One caller learns
   its identity is unknown; the other is told the pool is merely slow. From the
   same mistake, in the same pool, on the same day.
2. **The benign answer costs the caller the whole timeout** to deliver a verdict
   the pool already had before it blocked. A defect that sleeps gets diagnosed
   as a performance problem, and then gets tuned rather than fixed.

The `@check` above it is unchanged and still aborts first in a checking build.
`UNKNOWN_IDENTITY` is what a fast build says instead of waiting.

**One consequence, and it is why the diff there is bigger than one line.** The
early return makes `b` non-null for the rest of the function, so the two
`if (b)` guards inside the wait loop became branches that cannot be taken. They
were the whole of the null path before A3. They are removed rather than left,
because a live-looking dead branch is a reader's trap, and the body says so.

### The test

`negative/pool_unknown_identity.c3`, a runtime negative — **not a test-suite
test, and it could not have been one.** A checking build aborts on the `@check`
before any assertion runs, and `run-builds.sh` runs the test suite in all four
builds. The runtime-negative shape is exactly the one that expects an abort
where the checks are live and a clean run where they are not, so it carries both
halves of D6 tier 2 and the Part 19.3 assertion on top.

It asserts all three get modes plus `get_wait`, because *all three* was the
whole of the defect.

**It fails with the A3 fix removed.** Measured, not asserted — `src/` copied,
`Pool.get`'s return reverted to `NOT_AVAILABLE`, compiled `--safe=no -O0`:

```
ERROR: 'Violated assert 'f == mtk::UNKNOWN_IDENTITY': Part 19.3: available-or-new
on an unknown identity must not report NOT_AVAILABLE'
  in main (negative/pool_unknown_identity.c3:60)
rc=132
```

**`@catch_is` is not reachable from a negative program.** It belongs to the test
runner, and a negative is compiled as an ordinary program with `c3c compile`.
The first draft used it and did not compile. The file defines a two-line
`@unknown` macro over `if (catch f = ...)` instead, local to itself — the port
has no such macro and does not want one, because every caller in `src/` and
`test/` branches on the fault rather than fetching it.

### Part 19.3, read against `pool.c3` — conforming

| 19.3 clause | site | verdict |
|---|---|---|
| not-available comes **only** from the available-only mode | `pool.c3:351`, the sole remaining `NOT_AVAILABLE~` in the file, inside `if (mode == AVAILABLE_ONLY)` | conforms |
| not-created comes only from a hook that produced nothing | `pool.c3:362`, immediately after `slot.is_empty()` on the hook's return | conforms |
| the waiting get reports a timeout where available-only reports not-available | `pool.c3:440`, and `get_wait` calls no hook | conforms |

The `NOT_AVAILABLE~` that made P2 a finding is gone. It was the only one outside
the mode guard.

---

## A5 — the doc comments

### The path

**One occurrence, not forty.** `src/inner.c3:5` was the only file still naming
`matryoshka-specification-002.md`; `mtk.c3` was repointed by 3TK-16 when it
rewrote the header, and no other file cited the document by name at all. The
grep the stage asked for is clean across `src/`, `test/` and `negative/`.

**The forty were never path citations.** 003's own assumption A5 says *cites 002
in roughly forty doc comments*, and what the port actually has is roughly ninety
`Part N.N` citations, of which about sixty fall in Parts 003 changed. The debt
was real; it was just filed under the wrong noun. **The work A5 named as *not
mechanical* was all of the work**, and a `sed` would have found one line.

### The comments that changed a claim rather than a path

Twelve, in five files. Each one is a place where the comment was right about 002
and would have been wrong about 003 — not a stale pointer.

| file | what the comment claimed | what 003 says | V |
|---|---|---|---|
| `inner.c3:48` | the exact link test let the walk be deleted **from this port** | Part 8.6 is deleted from the specification too, and a port without an exact test carries the walk under 8.7 | V4 |
| `inner.c3:52` | *it replaces retired invariant 16* | still true, and 003 retires row 16 **in place** — it is still numbered 16 and 16b is this | V12 |
| `inner.c3:170` | the interrupted outcome is *absent*, by D9 | 19.1 and 19.2 mark it **conditional on Part 2.9**, so dropping the SHOULD drops the outcome and still conforms | V13 |
| `inner.c3:238` | the link test *is now exact* — **R6b's doing** | Part 8.7 MUSTs exactness and names three prices; R6b paid one | V5 |
| `inner.c3:249` | Part 8.7 *is a MUST to document* the blind spot | 003 does not document it, it **forbids** it | V5 |
| `queue.c3:11` | R2 argues for two primitives **against** 8.1's singular noun | 8.1 says *ordering primitives*, plural, and shows both shapes | V2 |
| `queue.c3:64` | Part 6.5's demonstration, unqualified | the dispatch table is **the application's**, said outright, so a port that ships nothing has skipped nothing | V18 |
| `queue.c3:78` | *Part 8.6 used to ask for a pair* | attributed to **002's** 8.6; 003's is a tombstone | V4 |
| `queue.c3:147` | Part 8.2, flat | 8.2 is split three ways and the Slot-shaped insert is **promoted**, with 12.5 as the reason | V3 |
| `stack.c3:2` | Part 8, with no note on the plural | added, pointing at the queue's argument | V2 |
| `mailbox.c3:30` and `pool.c3:146` | *Part 11.2's internal base* | 11.2 states **the five parts each container has**; a shared base is one mechanism and Part 4.4 lets a port refuse it. **The refusal is now the specification's to allow, not this port's to justify** | V6 |
| `mailbox.c3:60` | *TWO queues, not one list with an anchor* — as this port's departure | the three guarantees are the MUST; the anchor is ztk's mechanism, two queues are 3tk's, and 11.3 shows both | V7 |

### The two worth reading twice

**`pool.c3:511`.** The comment said *Part 12.2's **called once** is the one
clause this bends*, and it does not bend it any more. 003 weakened 12.2 to
*called once by close, and once more per straggling put* — the only MUST 003
weakens anywhere — and added Part 12.3 as a new MUST with invariant 35. **The
code now obeys the rule it was written to deviate from**, and the same comment
still ended with *specification 003 rules the shape and this is 3tk's answer
until it does*, which was a promise written before 003 existed and left standing
after it did. `pool.c3:99`, the `on_close` doc, carried the same stale claim and
is fixed with it.

**`pool.c3:233`.** *the pairing Part 8.6 uses for the insert walk*, in the
present tense, about a Part that no longer exists. The pairing itself — an
expensive check behind the tier gate — is what `create`'s O(n²) duplicate scan
does, and it is still the right technique. It just has no Part left to cite, and
the comment now says that instead of citing one.

### What was left alone, and why

- **`Part 8.2:` on the ordinary operations** — `is_empty`, `len`, `push`, `pop`
  and the rest. 003 regrouped Part 8.2 into required, required-at-the-surface
  and provided-if-useful, but every one of those operations is still Part 8.2's
  and every citation is still true. Only `push_back_slot` moved group, and only
  it got a note.
- **`3tk-core-redesign-proposal-002.md`** — a different document, still live,
  still cited by `mtk.c3` and `inner.c3`. A grep for `002` finds it. It is not
  the specification.
- **`3tk-status.md` and the log.** Provenance, as the stage said.

---

## One thing this stage did not do, and it is owed

**`3tk-deviations-001.md`'s P2 is now stale and this stage did not touch it.**
The row reads *NOT_AVAILABLE is returned from every mode on an unknown
identity*, and the section below it ends *the port has three answers available
and the audit takes none*. A3 took the first of the three and this stage built
it.

The stage's *what it may not do* does not forbid the edit, but 3TK-14's did, in
the general form — *a stage may not rewrite a finished stage's output* — and
3TK-16 was granted its two rows explicitly rather than by inference. **A
permission that had to be granted to the previous stage is not one this stage
can assume.** So it is named here instead: the row wants the same treatment
V19 got, additive, in the audit's own vocabulary, from a stage the owner names.

## Verification

| # | asked | result |
|---|---|---|
| 1 | `run-builds.sh` green, count **at least 59** | green, **63** — the new negative adds one check per build |
| 2 | `run-sanitizers.sh` green, 3 checks | green, 3 |
| 3 | a test that fails with the A3 fix removed | measured, quoted above |
| 4 | no `matryoshka-specification-002` in `src/`, `test/`, `negative/` | clean |
| 5 | Part 19.3 read against `pool.c3`, reported | conforming, table above |

87 tests over four builds.

## Change log

| Version | Date | Description |
|---|---|---|
| 001 | 2026-08-24 | First version. Stage 3TK-15. A3 and A5, the two debts of 3TK-13. |
