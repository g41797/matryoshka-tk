# The 3tk porting proposal (002)

Stage 3TK-5 of `3tk-staging-plan-001.md`, **accepted by the owner 2026-08-23**
after 3TK-6 and 3TK-7 built it.

The C3 shape of Matryoshka. Written from
[matryoshka-specification-001.md](matryoshka-specification-001.md), the ruled
review [3tk-drafts-review-001.md](../3tk-drafts-review-001.md), and the measured
answers of [c3-capabilities-001.md](../c3-capabilities-001.md).

Idiomatic C3. Not transliterated Zig.

## Status of the rulings in this file

> **ACCEPTED. Owner's ruling, 2026-08-23. All sixteen.**

Version 001 marked every decision *PROPOSED — owner overridable*, because 3TK-5
ran without the ruling it was waiting for and a proposal is where such rulings
are proposed rather than made.

They were then built. 3TK-6 wrote the toolkit and 3TK-7 wrote the containers,
and **all sixteen survived contact with the compiler** — see
`3tk-toolkit-notes-001.md` and `3tk-containers-notes-001.md`. On that evidence
the owner accepted them as written.

So this version says *ruling* where 001 said *proposal*. The arguments are
unchanged: each decision still carries the alternative it rejects, because the
reason a thing was chosen outlives the choosing.

**What else changed in 002.** Only what the code proved wrong. Every amendment
is marked with the finding that produced it, and none of them moves a decision:

| Where | Was | Now | Finding |
|---|---|---|---|
| Section 1 | the containers in `module mtk` | `module mtk::mailbox`, `module mtk::pool` | **G1**, accepted by the owner |
| Section 1 | `alias msg = mtk::helper{Msg}` | one alias per declaration | F4 |
| D6's macro | `@check` is `@private`, message is a `String` | public, message is compile-time | F3, F5 |
| Section 5.9 | `HashMap{typeid, Bucket}` | a flat `PoolBucket[]` | G4 |
| Section 5.9 | one Slot through `put` | two Slots, and why | G5 |
| Section 5.10 | unqualified names | module-qualified | G1 |
| Section 7.2 | the safe optimized build is `-O3` | `--safe=yes -O3` | **F1** |
| Section 9 | what 3TK-6 would be | what 3TK-6 and 3TK-7 did | — |
| throughout | `return CLOSED?` | `return mtk::CLOSED~` | G2 |

`3tk-porting-proposal-001.md` stays on disk, superseded.

## What this file is not

- Not code. No `.c3` file is written by this stage.
- Not a schedule. Part 22's order is adopted, not dated.
- Not a re-derivation. Where the specification already rules, this file cites
  and does not restate.

---

# 1. The shape in one screen

```
src/
  any.c3      module mtk           AnyNode, AnyHandle, Slot, the faults, @check
  list.c3     module mtk           NodeList — the intrusive list and its checks
  helper.c3   module mtk::helper   <Type> — the per-type border
  owned.c3    module mtk::owned    <Type> — helper plus create and release
  mailbox.c3  module mtk::mailbox  Mailbox
  pool.c3     module mtk::pool     Pool, PoolHooks, GetMode
  mtk.c3      module mtk           the port's identity and reading order
```

Seven files. The first four are the toolkit of Part 17.1; `mailbox.c3` and
`pool.c3` are the two optional tools of Part 17.2.

**The containers are submodules on purpose — G1, and the owner accepted it.**
Part 17.2 says they are built *on* the intrusive layer *with no privileged
access to it*, and Part 17.3 calls that the test of the design. A C3 submodule
cannot see its parent's `@private` declarations, so putting them in
`mtk::mailbox` and `mtk::pool` makes that claim a fact the compiler enforces
rather than a promise the authors keep. It costs an explicit `mtk::` on every
fault the containers return, which is exactly what a caller from outside pays.

`mtk.c3` is not a front door. C3 needs no re-export: `import mtk` brings in
everything `module mtk` declares across every file that declares it. The module
is the front door, and the file carries the port's identity and reading order.

The core types:

```c3
module mtk;

struct AnyNode
{
    AnyNode* prev;
    AnyNode* next;
    typeid   type;
}

alias   AnyHandle = AnyNode*;      // transparent. A handle is a pointer to an inner.
typedef Slot      = AnyHandle;     // distinct. A container of one handle, or nothing.
```

Three words in `AnyNode` on linux-x64: 24 bytes. Part 4.2's two parts, and no
third field.

The border, for one outer type:

```c3
struct Msg { int id; AnyNode node; char[64] body; }   // inner at any offset

alias msg_init     = mtk::helper::init{Msg};          // one alias per declaration
alias msg_from_any = mtk::helper::from_any{Msg};
alias msg_to_any   = mtk::helper::to_any{Msg};
```

A generic module instantiates per declaration, not as a whole — F4. A type that
wants the full surface writes nine aliases, or instantiates inline at the call
site as `owned.c3` does.

---

# 2. The decision register

Sixteen decisions. The eight carried by `c3-capabilities-001.md`, the eleven of
the conflict register so far as they remain open, and the ten of Part 20.
Overlapping, so sixteen rows and not twenty-nine.

All sixteen are **accepted**. The table gives the ruling; the sections after it
give the argument and the alternative each one rejects.

| # | Decision | Ruling | Source |
|---|---|---|---|
| D1 | Hiding the container internals — Q4 | **Public struct, public fields, the helper border does the work.** No opaque typedef | Q4, Part 11.11 |
| D2 | `inline AnyNode`, or a plain field — C2 | **Plain field, at any offset.** No `inline` | C2, Part 7.5 |
| D3 | Allocators — C7, Part 20 decision 2 | **Containers keep one. Application items keep one in the *outer*, never in the inner.** No release call takes an allocator | C7, Part 13 |
| D4 | Typed handles `MboxHandle`, `PoolHandle` — C10 | **No.** One `AnyHandle` | C10, Part 7.5 |
| D5 | The Slot's own type — Part 20 decision 1 | **Distinct.** `typedef Slot = AnyHandle` | Q9, Part 9.9 |
| D6 | The assert policy | **Three tiers, one port macro.** Plain `assert` is never used for a contract violation | Q11, Part 15.5 |
| D7 | The timed wait | **Anchor once, loop on `wait_until`.** `wait_timeout` is banned in the port | Q7, Part 2.5 |
| D8 | The names — C3, C11 | **`mtk`, `AnyNode`, `AnyHandle`, `Slot`, `NodeList`, `Mailbox`, `Pool`.** Not `AnyList`, not `polynode` | C3, C11, Q1 |
| D9 | Interruption — Part 20 decision 8 | **Dropped.** The outcome set loses `interrupted` | Q7, Part 2.9 |
| D10 | One helper, or two — Part 20 decision 3 | **Two generic modules**, `helper` and `owned` | Part 7.3 |
| D11 | The porting order — C8 | **Part 22 as written.** The list is step 5 | C8, Part 22 |
| D12 | The link test's blind spot — Part 20 decision 4 | **Accepted.** No membership field | Part 8.7 |
| D13 | Poll beside receive — Part 20 decision 5 | **Both.** They differ in how empty is reported | Part 19.1 |
| D14 | Out-of-band — Part 20 decision 6 | **Kept**, one level, with the O(1) anchor | Part 11.3 |
| D15 | The outcome mechanism — Part 20 decision 7 | **C3 faults.** `faultdef`, matching the stdlib | Part 19 |
| D16 | The pre-lock fast path — Part 20 decision 9 | **Kept**, with the mandatory re-check | Part 15.4 |

Part 20 decision 10 — where the O(n) insert check lives on a port with no build
modes — does not arise. C3 has build modes. D6 places it.

The rest of this section argues each one.

## D1 — Hiding the container internals

**Ruling: option 3 of Q4. Public struct, public fields, the border does the
work.**

Q4 measured three options. The reasoning against the other two:

- Option 1, a comment saying internal, is ztk. It claims nothing and gains
  nothing. It is what this decision would default to, not what it should
  choose.
- Option 2, `typedef Pool = void`, buys real hiding and sells a MUST for a
  SHOULD. Part 11.1 MUST says the two containers **are themselves items** — the
  mailbox embeds an inner, the pool embeds an inner, a pool sits on a list. A
  `typedef Pool = void` embeds nothing. The property has to be re-established
  through `PoolImpl`, the helper binds to `PoolImpl`, and the type the
  application names is no longer the type the toolkit describes. Part 11.11 is
  a SHOULD. Part 11.1 is a MUST and invariant 21.

Option 3 is chosen for a reason stronger than "what is left". Part 7.5 MUST
already puts every crossing in one file. The fields of `Mailbox` and `Pool`
being *reachable* is then a documentation problem: an application that reads
`pool.in_pool` has not broken an invariant, it has read a stale hint — which is
what Part 12.4 says that number is even to a hook.

What the port does instead, and it is not nothing:

- Every internal free function and macro carries `@private`. That is
  declaration-level visibility, which C3 *does* have (Q4, *read*
  `collections/list.c3:426`).
- The mutex, the condition variable and the closed flag are named with a
  leading underscore, and the header comment of each container names the
  reachable fields as internal.
- No public method reads a field the application could not have derived.

Part 0 requires a port that skips a SHOULD to say why. This section is that
statement: **Part 11.11 is skipped, because in C3 0.8.3 the only mechanism that
delivers it costs Part 11.1.**

*If the owner overrides to option 2:* D4 is unaffected, D10 is unaffected, and
the helper instantiations in `mailbox.c3` and `pool.c3` bind to `MailboxImpl`
and `PoolImpl`. Every public method gains a leading cast. Section 5.11's table
is the part that changes.

## D2 — A plain inner field, not `inline`

**Ruling: `AnyNode node;`, at whatever offset the outer's author likes. No
`inline`.**

Both compile (Q3). The argument is Part 7.5 and Part 10.1, and the capability
study is the first document in this folder to state it:

- `inline` makes `outer -> inner` an implicit conversion. The crossing then
  does not appear at the call site, and it does not appear in `helper.c3`
  either. It appears nowhere.
- Part 7.5 MUST: *every crossing goes through the helper*, and that is *what
  makes the arithmetic auditable: it appears in one file*.
- Part 10.1: the four words — inner, handle, Slot, item — exist so a reader of
  a signature knows which side of the border they are on. An implicit
  conversion erases the border at exactly the place the reader is looking.

The cost of the ruling is one call, `msg::to_any(m)`, where `inline` would have
written nothing. Part 7.2 requires that function to exist regardless. So the
cost is a call site, not a line of library code.

The gain beyond auditability: with no `inline`, `Msg` may embed its inner at
any offset, and the port never has to reason about what an implicit conversion
does in an overload or a generic context.

## D3 — Allocators

**Ruling, in three parts.**

1. **`Mailbox` and `Pool` keep an `Allocator` and release with it.** Part 13.1
   in full, including its sharp clause. Q8 verified the shape:
   `alloc::free(self.alloc, self)`, no parameter. This is the half the
   specification already settles, and ztk's mismatch (Part 13.3) does not exist
   in the port.
2. **The inner does not grow an allocator field.** Part 4.2 MUST: the inner has
   exactly two parts, and a third is added only with a reason written down,
   because *every item pays for it*. An allocator in `AnyNode` is 16 bytes on
   an interface value, added to a 24-byte inner, on every item in the program,
   to serve the subset of items the toolkit allocates. Refused.
3. **An item that wants a release with no allocator parameter keeps the
   allocator in its own outer, and takes the `owned` helper.** This is the new
   part, and it is what makes 1 and 2 compatible.

`mtk::owned <Type>` is the create-and-release variant of D10. It discovers two
fields by compile-time reflection, not one:

```c3
module mtk::owned <Type>;

// $OFF   — offset of the AnyNode field.        Part 7.4, as in mtk::helper.
// $AOFF  — offset of the Allocator field.
$assert $OFF  >= 0 : "type " +++ Type::name +++ " has no AnyNode field";
$assert $AOFF >= 0 : "type " +++ Type::name +++ " has no Allocator field; use mtk::helper";

fn void create(Allocator a, Slot* slot);   // Part 9.8: creation fills a Slot
fn void release(Slot* slot);               // Part 13.1: no allocator parameter
```

`create` writes the allocator into the outer's field and the identity into the
inner. `release` reads the allocator back out of the outer, frees, and clears
the Slot — a no-op on an empty Slot, Part 9.2 rule 6.

The `$assert` message names the alternative, which is the whole point of Part
7.4's *the message names the offending type*: a type that does not want to pay
the pointer is told, at build time, which helper it should have taken.

So Part 20 decision 2 is answered **per type, at the type's own choice**, and
not once for the whole port. That is better than the binary the specification
frames, and it costs one extra `$assert` and one extra offset lookup in a
module that is generated anyway.

**This answers C7 and the first open question of `3tk-status.md` together**, as
the review required.

*If the owner overrides* to "no application item keeps an allocator":
`mtk::owned` loses its second `$assert` and gains an `Allocator` parameter on
`release`, and Part 13.1's clause is knowingly broken for application items
only. The two containers are unaffected either way.

## D4 — One handle type

**Ruling: no `MboxHandle`, no `PoolHandle`. One `AnyHandle`.**

Q9's second negative probe priced it: a distinct handle type does not convert,
so every Slot-shaped call site writes `(AnyHandle*)&h`.

Part 7.5 MUST says application code never performs the crossing by hand and the
arithmetic appears in one file. A cast at every call site is the exact opposite
shape, and it is a cast the compiler cannot check — `(AnyHandle*)` on the wrong
thing compiles.

Part 11.1 is the second argument and the stronger one. The containers are
ordinary items with ordinary crossings. A `PoolHandle` says they are special.

What N4 wanted — static separation of the mailbox API from the pool API — is
delivered by the *typed pointer*, which is where C3 already delivers it.
`mbox::from_any(h)` returns a `Mailbox*` or nothing, and a `Mailbox*` cannot be
passed to a pool function. The separation is at the border, once, rather than
at every call site.

## D5 — A distinct Slot

**Ruling: `typedef Slot = AnyHandle`. Distinct, not an alias.**

This pairs with D4 and does not contradict it. The cast cost that sinks typed
*handles* does not arise for the Slot, because the Slot is the port's own
currency and every function that takes one takes `Slot*` by design — Part 9.3.
The friction appears only where a handle becomes a Slot or the reverse, which
is the helper, which is where Part 7.5 wants it.

What it buys, from Q9, verified in both directions:

- An `AnyHandle` cannot be passed where a `Slot` is wanted.
- A `Slot*` cannot be passed where an `AnyHandle*` is wanted.

So Part 9.2 rule 1 — never overwrite a full Slot — gains a compile-time ally:
the two-star confusion that four drafts fell into (C4) does not typecheck.

A zero-initialized `Slot` is null, so rule 2 — a Slot starts empty — is the
default state of the language, with no initializer to forget.

The cost Part 9.9 predicts is real: reading a distinct Slot needs
`(AnyHandle)slot` or a port-supplied `slot.get()`, not the bare null test. The
port supplies three one-line macros on `Slot` — `is_empty`, `peek`, `take` —
and the reading shape is then better than the bare null test, not worse.

**C4 is settled by the word, not by the type.** The Slot is the container. The
Slot is not `AnyHandle*`; `AnyHandle*` is a *pointer to* a Slot. In this port
that distinction is enforced by the compiler, so the four drafts' usage is now
unwritable.

## D6 — The assert policy

**Ruling: three tiers. A plain `assert` never guards a contract violation.
**

Q11 found the trap: at `--safe=no` with optimization, a plain C3 `assert` is
not a removed check, it is an *assumption the optimizer may act on*. A violated
contract then produces undefined behaviour rather than a missed diagnostic. The
probe segfaulted having printed nothing.

ztk's model — an assert either fires or is gone — does not survive the port. So
the port does not use the mechanism that breaks it.

| Tier | Spelling | Where | Behaviour in a fast build |
|---|---|---|---|
| 1 | `always_assert(cond, msg)` | Part 11.12 only | Aborts. Every build mode, no exception |
| 2 | `mtk::@check(cond, msg)` | every other contract violation | **Compiled out entirely.** Not an assumption |
| 3 | `$if env::COMPILER_SAFE_MODE:` block | Part 8.6's walk | Not compiled at all |

Tier 2 is one port macro, and it is the reason this decision is a design
contribution rather than a table:

```c3
macro @check(#cond, $msg)
{
    $if env::COMPILER_SAFE_MODE:
        always_assert(#cond, $msg);
    $endif
}
```

Two corrections from the code. It is **not** `@private`: C3's `@private` does
not reach a submodule, so `mtk::helper` could not see it — and Part 17.2 makes
that right anyway, since an application writing its own Slot-shaped call is
entitled to the same check (F3). And the message is a **compile-time** string,
because `always_assert` takes one (F5). The clause is carried to the abort
intact:

```
ERROR: 'Violated assert '#cond': Part 8.6 walk: the item is already on this list'
```

In a safe build it is `always_assert`, which aborts and names the message. In
`--safe=no` it expands to nothing — the condition is not evaluated, and nothing
is handed to the optimizer as a promise. That is ztk's model, restored, on a
language whose `assert` does not provide it.

The site list:

| Site | Spec | Tier |
|---|---|---|
| Releasing an open mailbox or pool | 11.12 MUST | **1** |
| Overwriting a full Slot | 9.2 rule 3 | 2 |
| Inserting an item that already has neighbours | 8.6 link test | 2 |
| Inserting an item already on this list | 8.6 walk | **3** |
| Moving a list onto itself | 8.9 | 2, **plus the early return** |
| A hook returning an item of the wrong identity | 12.2 | 2 |
| An asserting crossing on a mismatch | 6.3 | 2 |

Part 8.9's pair is not softened: the assert is tier 2 and compiles out, and the
early return is ordinary code and does not. The specification says exactly this,
and it is the one place where the port keeps both.

Every *runtime condition* — closed, timeout, nothing available — is a fault and
never an assert, in every build mode. Part 15.5, and D15.

## D7 — The timed wait

**Ruling: `wait_timeout` does not appear in the port.** Closer to a finding
than a decision, and 3TK-7 proved it by sabotage — see the note at the end of
this section.

Q7 read the stdlib: `wait_timeout` computes `time::now() + ms` on **every
call**. A retry loop built on it restarts the full timeout at every spurious
wakeup, without bound. That is precisely Part 2.5 MUST and invariant 4, and it
fails silently — the call simply never times out under load.

The one shape, written once and used at every waiting site:

```c3
Time deadline = time::now() + timeout;        // anchored once, before the loop
while (true)
{
    // re-evaluate the state from scratch — Part 2.4
    if (...) { ...; return; }
    if (self._closed) return CLOSED?;
    if (catch f = self._cond.wait_until(&self._mu, deadline))
    {
        if (f == thread::WAIT_TIMEOUT)
        {
            // Part 2.6: the leaver checks the container and signals
            if (!self._queue.is_empty()) self._cond.signal();
            return TIMEOUT?;
        }
        return f?;
    }
}
```

Four MUSTs are in those lines and the port writes them once: 2.4 the re-check,
2.5 the anchor, 2.6 the hand-off, 15.3 the flag read under the mutex.

`3tk-poc.md` row P7 is the draft that got this wrong. It is the only draft that
touched the code path.

**Proved by sabotage, 3TK-7.** The trouble with this MUST is that a wrong
implementation passes every ordinary timeout test. `wait_until(deadline)` was
swapped for `wait_timeout(timeout)` in `Mailbox.receive` and the suite reported
`FAILED: 70 passed, 1 failed`, naming Part 2.5. The sabotage was reverted. A
test for an invariant of this shape is worth nothing until it has been seen to
fail.

## D8 — The names

**Ruling.**

| Thing | Name | Why |
|---|---|---|
| The module root | `mtk` | `any` is a reserved keyword (Q4/C3). `matryoshka` as a path prefix on every line is noise |
| The inner | `AnyNode` | C11. `polynode` is the ztk name and this is not a transliteration |
| A handle | `AnyHandle` | Part 10.1. A transparent alias, and it is the reading aid |
| The Slot | `Slot` | Part 9. Distinct type, D5 |
| The list | **`NodeList`** | **Not `AnyList`.** `std::collections::anylist` exists, is heterogeneous, and **shallow-copies and owns every element** — the semantic opposite, under the name every draft chose |
| The per-type helper | `mtk::helper <Type>` | A generic module, not a macro. Q1 corrected `3tk-polyhelper.md` |
| The owning variant | `mtk::owned <Type>` | D10, D3 |
| The containers | `Mailbox`, `Pool` | Unchanged |
| The hooks | `PoolHooks` | An interface. Q5 |

Two hazards Q1 found, carried as rules: **a struct name that is all uppercase
does not compile**, and `Any` is available as a *type* name but unusable as a
*module* name.

`C3` — the review's third conflict — is closed by that pair: `3tk-porting-notes.md`
was right that `Any` works as a type, `3tk-additions.md` was right about the
keyword and wrong about what follows from it.

`C11` is closed for the type names here, and for the file names by section 1.

## D9 — Interruption is dropped

**Ruling: Part 2.9 is not implemented.**

Part 2.9 is a SHOULD whose own text says: *on a port with no such mechanism,
this outcome is dropped and the timeout outcome stays*. Q7 measured C3: there is
no interruptible condition wait. `INTERRUPTED` exists for `sleep` and for
`TimedMutex.lock_timeout` on `EINTR`, and nowhere else.

Building it — a per-waiter flag plus a broadcast — is possible and is not free:
it is a field per waiter, a second reason to wake, and a second cause to keep
distinct from closed at every wait site. Part 2.10 then applies as well, and
every give-back path has to be proved uninterruptible.

The port drops it, and the outcome sets of Part 19 lose exactly one value in
two rows: `receive` and `get with waiting`. Nothing else changes. Part 16 rows
11 and 12 were already going.

*If the owner overrides:* Part 11.5's counter mechanism is the model to copy —
a counter, captured before the wait, compared after every wakeup — and Part
2.10 becomes a review item for every path in `pool.c3`.

## D10 — Two generic modules

**Ruling: `mtk::helper <Type>` and `mtk::owned <Type>`.**

Part 7.3's distinction is real and portable: not every type wants create and
release. ztk spells it with a marker constant and a branching generator, and
pays 110 duplicated lines. Q1 found there is no `has_tag` property to branch
on in C3 anyway.

Two modules, with `owned` composing `helper` rather than copying it:

```c3
module mtk::owned <Type>;
import mtk;

alias h = mtk::helper{Type};      // the seven members of Part 7.2, once
fn void create(Allocator a, Slot* slot)  { ... }
fn void release(Slot* slot)              { ... }
```

An application writes one alias for a plain type and one for an owning type,
and the two spell the same seven members. No duplication, no marker constant,
no branch.

## D11 — The order

**Ruling: Part 22 as written. The list is step 5.**

C8 records two true reasons pointing opposite ways. Part 22's reason wins on a
mechanical point: the list *speaks in handles* (Part 8.3) and two of its
operations *take Slots* (Part 8.2). It cannot be written, let alone tested,
before `AnyHandle` and `Slot` exist.

The drafts' reason — that both containers depend on the list — is satisfied
anyway, since the list is step 5 and the containers are 6 and 7.

One amendment from Q1: **the helper needs no prototyping step of its own.** It
was prototyped in 3TK-4, for two outer types, with all seven members of Part
7.2 exercised. Step 3 starts from working code.

## D12 to D16, briefly

**D12 — the link test's blind spot is accepted.** Part 8.7 prices the
alternative at a field per item, and D3 already refused a third field in the
inner for a stronger reason. The blind spot is documented at the link test and
in `NodeList`'s header comment, as Part 8.7 requires. The walk of Part 8.6 is
what covers it in checking builds.

**D13 — both a receive and a poll.** Part 20 decision 5 notes a zero-timeout
receive has the same reach. The two are kept apart because they report the
empty case differently — `poll` reports `EMPTY`, a receive at a zero deadline
reports `TIMEOUT` — and Part 19.1 lists both. One is not a special case of the
other to a caller reading outcomes.

**D14 — out-of-band is kept**, one level, not a queue, with the anchor at the
last out-of-band item so the insert stays O(1) and the anchor cleared when that
item is taken. Part 11.3, invariant 22.

**D15 — outcomes are C3 faults.** `faultdef CLOSED, TIMEOUT, NOT_AVAILABLE,
NOT_CREATED, EMPTY, WOKEN;`, returned as `void?` or `Type?`. It is what the
stdlib does — `thread::WAIT_TIMEOUT` is a fault (Q7) — and `if (catch f = ...)`
is the language's own reading shape. Part 19's set is fixed; this is the
spelling. Note that these are *runtime conditions*, never defects: D6 keeps
them out of the assert tiers entirely.

**D16 — the pre-lock fast path is kept**, as `Atomic{bool}`, with the
acquire-outside / relaxed-inside / release-on-store ordering Part 15.4
specifies, and with the re-read under the lock. Part 15.4's prohibition is
respected literally: the port may not drop the re-check while keeping the fast
read. Q10 verified the orderings exist with contracts rejecting invalid
combinations.

---

# 3. What C3 deletes

Measured, not estimated.

| Deleted | Was | Why |
|---|---|---|
| The whole of Part 16, rows 1 to 11 | ztk's `std.Io` surface | The port is on plain threads. Part 16's own preamble |
| **Row 7 alone: 71 lines** | The hand-written timed condition wait | `ConditionVariable.wait_until` exists, on an absolute deadline. Q7 |
| Row 12 | The interruptible error in two signatures | D9 |
| The per-type mutable byte, and the linker-merging defence | Part 5.3's ztk realization | `typeid` is native and two identically-shaped types differ. Q2 |
| The `ctx` field on the hook struct | Part 12.1's ztk realization | The implementing object is the context. Q5 |
| 110 duplicated lines in the generator | Part 7.3's ztk realization | D10, two composing modules |
| Runtime validation of the outer type | Part 7.4's fallback | `$assert` over `$Type::members`, at build time, naming the type. Q12 |
| Hand-written cleanup at every exit | Part 9.7's fallback | `defer`. Q6 |
| The allocator parameter on both release calls | Part 13.3's ztk mismatch | D3, Q8 |

And one thing C3 *adds* that ztk cannot have: Part 6.5's dispatch may be a
`switch` on `typeid`, because a `typeid` is a compile-time-known constant and a
ztk tag is a linker-assigned address. Q2 verified it compiles. The port
provides the table — handlers registered at runtime is the general case — and
documents the `switch` as available where the handler set is fixed.

Not deleted, and deliberately: Part 8.1's list. `std::collections::linkedlist`
allocates a node per element, and `anylist` copies. Neither is intrusive. Part
8.5 required the port to write the checking layer regardless.

---

# 4. What the port pays

Four costs, from Q4 through Q11, all knowing.

1. **No private fields.** D1. Part 11.11 is skipped with the reason written
   down.
2. **No interruptible wait.** D9. Part 2.9 is dropped, as its own text allows.
3. **`assert` under `--safe=no -O3` is an assumption, not a removed check.**
   D6 routes around it and no plain `assert` guards a contract in the port.
4. **No intrusive list in the stdlib.** The port writes `NodeList`. It was
   going to anyway — Part 8.5.

---

# 5. The mapping — every MUST and SHOULD

Part by part. The specification's marking, and the C3 shape.

MAY elements are in section 6. EXCLUDED elements are in section 3.

## 5.1 Parts 1 to 3 — the frame

| Spec | Marking | C3 shape |
|---|---|---|
| 1.1 What it is | MUST | The design, unchanged. `mtk` ships no thread and no queue type of its own |
| 1.2 What it is not | MUST | No `Future`, no select, no event loop. `3tk-poc.md` P1 and `3tk-build-dist.md` B3 both proposed a fourth layer; refused |
| 1.3 No `Master` type | MUST | Not written. Named in the docs as the application's |
| 2.1 Plain threads | MUST | `std::thread::Thread`. The toolkit starts none |
| 2.2 Two primitives | MUST | `Mutex` and `ConditionVariable`. *Read* `threads/thread.c3:11-17` |
| 2.3 Timeout is the primitive | MUST | Every waiting call takes a `Duration`; the poll takes none |
| 2.4 A wakeup carries no meaning | MUST | The `while(true)` of D7. No wakeup short-circuits |
| 2.5 The deadline is anchored once | MUST | D7. `wait_until` on a `Time` computed before the loop |
| 2.6 Signal hand-off on a lost race | MUST | D7's timeout arm, and the same three lines on the closed arm |
| 2.7 Many producers, many consumers | MUST | Falls out of the mutex. Nothing per-thread is kept |
| 2.8 Order among receivers undefined | MUST | Documented. `signal` picks; the port does not promise fairness |
| 2.9 Interruption | SHOULD | **Dropped. D9** |
| 2.10 Cleanup paths run to the end | MUST where 2.9 | Not applicable under D9. `Pool.put` cannot fail regardless — Part 19.2 |
| 3.1 Long-lived heap objects | MUST | `alloc::new(a, Type)`. Documented as a precondition of every participant |
| 3.2 The address is fixed | MUST | Documented. C3 does not move a heap allocation |
| 3.3 Items versus participants | SHOULD | Documented. A short-lived item is legal; a participant is not |

## 5.2 Parts 4 and 5 — the inner and the identity

| Spec | Marking | C3 shape |
|---|---|---|
| 4.1 The outer embeds the inner | MUST | `AnyNode node;` as a field. **D2**, no `inline` |
| 4.2 Two parts, nothing more | MUST | `prev`, `next`, `type`. 24 bytes. **D3 part 2 refuses a third** |
| 4.3 The field may sit anywhere | SHOULD | `$Type::members` gives `.offset`; the crossing subtracts it. Q3, verified at offset 8 |
| 4.4 One inner per outer | MUST | `$assert` in the helper: exactly one `AnyNode` field, not zero and not two |
| 5.1 A per-type identity | MUST | `Type::typeid`. Every clause measured. Q2 |
| 5.2 What it is not | MUST | Falls out. A `typeid` is not per-item, not a string, not an index |
| 5.3 Spelling is free | SHOULD | Native identifier taken. The address trick and the mutable byte are deleted |
| 5.4 Stored, not computed | MUST | `AnyNode.type`, written by the initializer, read by the walker |
| 5.5 The uninitialized identity | SHOULD | `mtk::helper::init` writes it, and `owned::create` calls `init`. A stack item still needs `init` called, and the doc says so |

Part 5.5 is the one place C3 gives no more than Zig: there is no required
constructor. The mitigation is that a zeroed `typeid` matches no type, so the
first crossing refuses rather than mis-claiming.

## 5.3 Parts 6 and 7 — the crossings and the helper

| Spec | Marking | C3 shape |
|---|---|---|
| 6.1 Self-identification | MUST | `h.type == Type::typeid` |
| 6.2 Three places, no others | MUST | The helper's crossings, and `NodeList`'s walk in the application's hands |
| 6.3 Two forms | MUST | `from_any` returns `Type*` or null; `must_from_any` is tier 2 of D6 then the cast |
| 6.4 What it makes safe | background | — |
| 6.5 Dispatch on the identity | SHOULD | A table keyed on `typeid`. A miss leaves the item in its Slot and returns. **`switch` over `Type::typeid` also compiles** — Q2, and ztk cannot |
| 7.1 A per-type helper | SHOULD | `module mtk::helper <Type>;`, one `alias` per outer type. Q1, verified for two types |
| 7.2 The seven members | MUST | Table below |
| 7.3 Create and release | SHOULD | **D10**, `mtk::owned <Type>` |
| 7.4 Validation of the type | SHOULD | `$assert` over `$Type::members`, at build time, and **the message names the type**. Q12, verified |
| 7.5 The border, named once | MUST | **D2 and D4 both exist to protect this.** All arithmetic is in `helper.c3` |

Part 7.2's seven members, as generated. All seven were compiled and exercised
in 3TK-4.

| Member | Signature | Part |
|---|---|---|
| The identity | `const typeid TYPE = Type::typeid;` | 5 |
| The predicate | `fn bool is_mine(AnyHandle h)` | 7.2 |
| Checking crossing, handle | `fn Type* from_any(AnyHandle h)` | 6.3 |
| Asserting crossing, handle | `fn Type* must_from_any(AnyHandle h)` | 6.3 |
| Checking crossing, Slot | `fn Type* from_slot(Slot* s)` | 7.2 |
| Asserting crossing, Slot | `fn Type* must_from_slot(Slot* s)` | 7.2 |
| **Moving** crossing, Slot | `fn Type* move_from_slot(Slot* s)` | 7.2 |
| The way back | `fn AnyHandle to_any(Type* item)` | 7.2 |
| The initializer | `fn void init(Type* item)` | 5.5 |

The moving crossing is the one with two postconditions, and 3TK-4 verified
both: on a match the pointer is returned **and** the Slot is cleared; on a
mismatch nothing is returned **and the Slot is untouched** — Part 9.2 rule 4.

## 5.4 Part 8 — the list

| Spec | Marking | C3 shape |
|---|---|---|
| 8.1 Intrusive, heterogeneous, O(1), no allocation | MUST | `NodeList`, written by the port. The stdlib has nothing intrusive |
| 8.2 The surface | SHOULD | Sixteen operations, section 5.5. None can fail |
| 8.3 The list speaks in handles | MUST | Every entry point takes `AnyHandle` or `Slot*`. Never `Type*` |
| 8.4 The walk | SHOULD | `NodeListIterator`, taken from the list, yielding handles. Removal during a walk is not supported, and the doc says so |
| 8.5 The checks live here | MUST | `NodeList` is the layer. There is no raw primitive under it |
| 8.6 The double check | SHOULD | The link test is **tier 2** of D6. The walk is **tier 3**, a `$if env::COMPILER_SAFE_MODE` block, so the O(n) is not merely compiled out but never compiled |
| 8.7 The link test's blind spot | MUST | Documented at the function and in the header. **D12** |
| 8.8 The repair | MUST | Every removal clears `prev` and `next`. One `@private` helper, called from all of them |
| 8.9 Moving a list onto itself | SHOULD | The pair: a tier-2 check **and** an early return. The return is not compiled out |
| 8.10 Bridging to the language's own list | MAY | **Dropped.** Section 6 |
| 8.11 Test access to the raw list | MAY | **Dropped.** Section 6 |

## 5.5 The `NodeList` surface — Part 8.2

Names are the port's business; these are the port's.

| Operation | Signature |
|---|---|
| Take from the front | `fn AnyHandle pop_front(&self)` |
| Take from the back | `fn AnyHandle pop_back(&self)` |
| Remove a named item | `fn void remove(&self, AnyHandle h)` |
| Look at the front | `fn AnyHandle front(&self)` |
| Look at the back | `fn AnyHandle back(&self)` |
| Add at the back | `fn void push_back(&self, AnyHandle h)` |
| Add at the front | `fn void push_front(&self, AnyHandle h)` |
| Add at the back from a Slot | `fn void push_back_slot(&self, Slot* s)` |
| Add at the front from a Slot | `fn void push_front_slot(&self, Slot* s)` |
| Insert after | `fn void insert_after(&self, AnyHandle at, AnyHandle h)` |
| Insert before | `fn void insert_before(&self, AnyHandle at, AnyHandle h)` |
| Is it empty | `fn bool is_empty(&self)` |
| How many | `fn usz len(&self)` |
| Walk it | `fn NodeListIterator iter(&self)` |
| Move another list onto this one | `fn void append_list(&self, NodeList* other)` |

`pop_front`, `pop_back`, `front` and `back` return a null handle on an empty
list. That is Part 8.2's *both may find the list empty*, and it is not a fault —
Part 19.4, no operation on the list can fail.

`len` is O(1): the port keeps a count, because Part 11.7 needs one per identity
and Part 8.2 asks for the operation.

`append_list` carries Part 8.9's pair.

## 5.6 Part 9 — the Slot

| Spec | Marking | C3 shape |
|---|---|---|
| 9.1 A container of one handle, or nothing | MUST | `typedef Slot = AnyHandle`. **D5** |
| 9.2 The six rules | MUST | Table below |
| 9.3 The signature shape | MUST | Every acquiring operation takes `Slot*` and returns `void?`. The item is never returned |
| 9.4 The Slot is the answer | MUST | Documented at `Pool.put`, at the dispatch table, and at every transfer |
| 9.5 The one exception | MAY | **Dropped.** No select mechanism. Section 6 |
| 9.6 One place at a time | MUST | The invariant the whole file protects |
| 9.7 Cleanup before acquisition | SHOULD | `defer` on the line **before** the acquisition. Q6 |
| 9.8 Creation is an acquisition | SHOULD | `owned::create(a, &slot)`. No pointer returned |
| 9.9 The Slot's own type | MAY | **Taken.** D5, distinct |

The six rules, and where each is enforced:

| # | Rule | Enforcement |
|---|---|---|
| 1 | Never overwrite a full Slot | Tier 2 check at every acquiring entry point. D5 makes the two-star confusion untypeable |
| 2 | A Slot starts empty | Zero-initialization. A `Slot` is null by default |
| 3 | An acquisition asserts the Slot is empty on entry | Tier 2, first line of every acquiring function |
| 4 | A failing acquisition leaves the Slot unchanged | Every fault path returns before the write. Verified for `move_from_slot` in 3TK-4 |
| 5 | A transfer clears the Slot | The write to null is in the same block as the link-in |
| 6 | A release is a no-op on an empty Slot | `if (!*s) return;` — which is what makes 9.7 legal |

Part 9.7's shape, in C3:

```c3
Slot slot;                                  // rule 2: empty
defer msg::release(&slot);                  // registered BEFORE the acquisition
if (catch f = pool.get(Msg::typeid, &slot)) return f?;
Msg* m = msg::must_from_slot(&slot);
...
```

Rule 6 is what makes the `defer` safe on the path where `get` failed and the
Slot was never filled.

## 5.7 Part 10 — the synonyms

| Spec | Marking | C3 shape |
|---|---|---|
| 10.1 Four names kept apart | SHOULD | `AnyNode` the inner, `AnyHandle` the handle, `Slot` the Slot, the outer's own name the item. **D2 exists to stop `inline` collapsing two of them** |
| 10.2 Why not collapsed | background | In this port the compiler learns something after all: `Slot` is distinct. D5 |
| 10.3 The word "object" | SHOULD | Prose rule, carried into the port's docs |

## 5.8 Part 11.1 to 11.6 — the mailbox

| Spec | Marking | C3 shape |
|---|---|---|
| 11.1 The containers are items | MUST | `struct Mailbox { AnyNode node; ... }`, with `alias mbox = mtk::helper{Mailbox};`. **D1 is what keeps this literal** |
| 11.2 One internal base | SHOULD | Not a public type. The five members are repeated in both structs, `@private` functions shared |
| 11.3 The mailbox | MUST | Seven operations, section 5.10 |
| 11.4 Out-of-band is one level | MAY | **Kept. D14** |
| 11.5 Waking every waiter | SHOULD | A `usz _wake_gen` counter, captured before the wait, compared after every wakeup, with `broadcast`. Q7 confirmed `broadcast` exists |
| 11.6 The give-back rule | MUST | Every path returns items to a caller. The doc names the mistake: discarding the list `close` returns drops items that keep their links, and a later send then refuses them |

## 5.9 Part 11.7 to 11.12 and Part 12 — the pool

| Spec | Marking | C3 shape |
|---|---|---|
| 11.7 The pool | MUST | One `NodeList` per identity, in a flat `PoolBucket[]` allocated once at creation and asserted non-empty. **G4:** a hash map buys nothing for a set that is fixed and small; the linear scan is faster and allocates once |
| 11.8 The give-back rule, pool side | MUST | `close` passes everything to the hook and returns nothing. A closed pool leaves the Slot unchanged. A list put stops at the first refusal and pushes that item back at the **front** of the caller's list |
| 11.9 Waiting get never creates | MUST | `get_wait` has no hook call in it. **The code is the truth; the ztk book is wrong twice** — Part 11.9, `audit 5.2` |
| 11.10 No sequence guarantee | MUST | Documented. Nothing promised about which item returns |
| 11.11 Hidden implementation | SHOULD | **Skipped. D1**, with the reason written down |
| 11.12 Close before release | MUST | **`always_assert`. Tier 1 of D6.** The one call that aborts in every build mode. Close is idempotent and the second call does not re-run the hook. The test-and-set is inside the mutex |
| 12.1 Hooks as an interface | MUST | `interface PoolHooks`, a creation parameter. Q5, verified. **`ctx` is deleted** |
| 12.2 The three hooks | MUST | Signatures below |
| 12.3 Hook concurrency | MUST | Unlock, call, relock. Documented: hooks run in parallel, protect their own state, and do not call back |
| 12.4 The count is a hint | MUST | Passed by value, read under the lock, documented as stale. After removal on get, before addition on put |
| 12.5 The extra list on put | SHOULD | A second `NodeList*` parameter on `on_put`. Each item added the same way, with the same checks |

The three hooks, as the specification requires them and as Q5 compiled them —
**not** as `3tk-additions.md` proposed:

```c3
interface PoolHooks
{
    fn void on_get(typeid want, usz in_pool, Slot* slot);
    fn void on_put(usz in_pool, Slot* slot, NodeList* extra);
    fn void on_close(NodeList* remaining);
}
```

- `on_get` gets an empty Slot and the wanted identity. Leaving it empty is the
  `NOT_CREATED` outcome. Returning an item of another identity is a defect —
  tier 2.
- `on_put` gets a Slot carrying all four of Part 12.2's outcomes: emptied means
  released, full means kept, full with a different item means replaced.
- **G5: that is not the caller's Slot.** `Pool.put` clears the caller's Slot at
  the moment it accepts the item — Part 9.4, cleared means kept — and then hands
  the hook a Slot of its own. A port that passes the caller's through lets a
  hook that *keeps* the item leave the caller's Slot full, which reads as
  *refused*.
- `on_close` gets the list of what remained, is called **once**, **outside the
  mutex**, **after the flag is set**, and owns every item in it.

## 5.10 The container surfaces — Part 11.3, 11.7, and Part 19

`Mailbox`, in `mtk::mailbox`. Created with `mailbox::create(a)`:

| Operation | Signature | Outcomes |
|---|---|---|
| send | `fn void? send(&self, Slot* s)` | done; `CLOSED`, Slot unchanged |
| send out-of-band | `fn void? send_oob(&self, Slot* s)` | as send |
| receive | `fn void? receive(&self, Slot* s, Duration t)` | item; `CLOSED`; `TIMEOUT`; `WOKEN` |
| poll | `fn void? poll(&self, Slot* s)` | item; `EMPTY`; `CLOSED` |
| receive the batch | `fn void? receive_all(&self, NodeList* out)` | a list, possibly empty; `CLOSED` |
| close | `fn void close(&self, NodeList* out)` | a list. Cannot fail |
| wake every waiter | `fn void? wake_all(&self)` | done; `CLOSED` |
| release | `fn void release(&self)` | **Tier 1 assert if open.** No allocator parameter |

`Pool`, in `mtk::pool`. Created with `pool::create(a, tags, hooks)`:

| Operation | Signature | Outcomes |
|---|---|---|
| get | `fn void? get(&self, typeid want, GetMode m, Slot* s)` | item; `CLOSED`; `NOT_AVAILABLE`; `NOT_CREATED` |
| get with waiting | `fn void? get_wait(&self, typeid want, Slot* s, Duration t)` | item; `CLOSED`; `TIMEOUT` |
| put | `fn void put(&self, Slot* s)` | Nothing. **Read the Slot** |
| put a list | `fn void put_all(&self, NodeList* items)` | Nothing. **Read the list** |
| close | `fn void close(&self)` | Nothing. Cannot fail |
| release | `fn void release(&self)` | **Tier 1 assert if open.** No allocator parameter |

`enum GetMode { AVAILABLE_OR_NEW, NEW_ONLY, AVAILABLE_ONLY }`.

The faults are `mtk::CLOSED`, `mtk::TIMEOUT`, `mtk::EMPTY`, `mtk::WOKEN`,
`mtk::NOT_AVAILABLE`, `mtk::NOT_CREATED`. The return spelling is `~` and not
`?` — `return mtk::CLOSED~;` — because `?` marks the optional type. G2.

Part 19.3's asymmetry, kept: `NOT_AVAILABLE` comes only from `AVAILABLE_ONLY`,
`NOT_CREATED` only from a hook that produced nothing, and `get_wait` reports
`TIMEOUT` where `AVAILABLE_ONLY` would report `NOT_AVAILABLE`.

`put` and `put_all` return `void`, not `void?`. Part 19.2 — put cannot fail —
and Part 9.4 — the Slot is the answer, not the outcome. This is the shape the
whole idiom exists for, and the port does not soften it into a fault.

## 5.11 Parts 13 to 15

| Spec | Marking | C3 shape |
|---|---|---|
| 13.1 An allocator kept for life | SHOULD | **D3.** `alloc::free(self.alloc, self)`, no parameter. Q8, verified |
| 13.4 Application items | open | **D3 part 3.** Per type, by which helper it takes |
| 13.5 No explicit allocator | SHOULD | Does not apply. C3 parameterizes allocation |
| 14.1 One holder at a time | MUST | The Slot idiom is how it is spelled. D5 helps the compiler help |
| 14.2 The transfer orders memory | MUST | Both containers publish through their own mutex. Items are read with plain loads. Documented, because it is invisible in the signatures |
| 14.3 The transfer circuit | SHOULD | Carried into the port's docs as the diagram it is |
| 15.1 One mutex per container | MUST | `Mutex _mu`, covering that object's state only. No application data under it |
| 15.2 No lock across application code | MUST | The unlock-call-relock of 12.3. No path takes two locks, so there is no ordering to state |
| 15.3 The closed flag | MUST | Read and set under the mutex. Setting it is the whole of close's state change |
| 15.4 The pre-lock check | SHOULD | **D16.** `Atomic{bool}`, acquire outside, relaxed inside, release on the store, **and the re-read under the lock** |
| 15.5 Asserts versus outcomes | SHOULD | **D6.** Three tiers, and every runtime condition is a fault |

## 5.12 Part 17 — the layering

| Spec | Marking | C3 shape |
|---|---|---|
| 17.1 One tool is required | MUST | `any.c3`, `helper.c3`, `owned.c3`, `list.c3`. Usable with neither container |
| 17.2 Two are optional | SHOULD | `mailbox.c3` and `pool.c3` import `mtk` and use only public entry points |

17.2's second clause is a testable claim, and the port tests it: **no function
in `mailbox.c3` or `pool.c3` reads a field or calls a `@private` function of
the core four.** Every crossing they perform is one an application could write.
Section 7 makes it a test.

---

# 6. What is dropped, and why

Beyond section 3's excluded surface.

| Dropped | Marking | Why |
|---|---|---|
| Interruption, Part 2.9 | SHOULD | **D9.** No interruptible condition wait in C3. The SHOULD's own text permits the drop |
| Hidden container internals, Part 11.11 | SHOULD | **D1.** The only C3 mechanism that delivers it costs Part 11.1 MUST |
| Bridging to the language's own list, Part 8.10 | MAY | Its condition is not met: the stdlib has no intrusive list of the same node type. Q7's reading of `collections/linkedlist.c3:9-14` |
| Test access to the raw list, Part 8.11 | MAY | There is no raw list under `NodeList`. C3 has `@test` functions in the same module, which reach the internals directly |
| The union-returning calls, Part 9.5 | MAY | Its stated purpose is a select mechanism. There is none, and Part 1.2 refuses to add one |
| The `interrupted` outcome, Part 19 | — | Follows from D9. Two rows lose one value |

Six drops. Two SHOULDs with written reasons, three MAYs whose conditions are
not met, and one consequence.

---

# 7. Build and test

## 7.1 The project

One `project.json`. C9 is closed by writing a third shape rather than choosing
between two that were never compiled.

```json
{
  "langrev": "1",
  "authors": [ "g41797" ],
  "version": "0.1.0",
  "sources": [ "src/**" ],
  "targets": {
    "mtk": { "type": "static-lib" },
    "mtk-test": { "type": "test", "sources": [ "src/**", "test/**" ] }
  }
}
```

`3tk-build-dist.md` B2 claims C3 library packaging is early alpha and `c3c dist`
incomplete. **Unverified, and this stage did not verify it.** It affects
distribution, not the port. The proposal ships source, as B6 suggests, and the
question is a tooling stage's.

## 7.2 The four builds

Every one of them, every time. D6's whole point is that the tiers behave
differently across them, and a port that tests one build has tested one tier.

| Build | Flags | What it proves |
|---|---|---|
| Safe, unoptimized | `--safe=yes -O0` | Tiers 1, 2 and 3 all live. Every check runs |
| Safe, optimized | `--safe=yes -O3` | The same, under an optimizer |
| Fast, unoptimized | `--safe=no -O0` | Tier 1 still aborts. Tiers 2 and 3 are gone |
| **Fast, optimized** | `--safe=no -O3` | **The one that segfaulted in Q11's probe.** Proves the port has no plain `assert` guarding a contract |

The fourth is not optional. It is the build in which C3's own `assert` becomes
undefined behaviour, and the reason D6 exists.

**F1, and version 001 had this wrong.** 001 spelled the second build `-O3`.
Measured on c3c 0.8.3, **`-O2` and above set `SAFE_MODE=false`**: `-O3` alone is
the fast build under another name, and a suite run under it tests nothing the
fast build has not already tested. The first run of `run-builds.sh` caught it —
five negatives reported *did NOT abort in a checking build*.

**Never infer the build mode from the `-O` level.** Both sides are explicit,
`--safe=yes` or `--safe=no`, in every build this port runs.

## 7.3 The tests

Grouped by what they establish, not by file.

**The invariants.** Part 18's thirty-three, each with at least one test naming
its number. Twelve of them appear in no draft in this folder — the review's
section 8 — so they are written from the specification and not from any prior
C3 text.

**The six Slot rules.** One test each. Rule 4 — a failing acquisition leaves the
Slot unchanged — needs a failure induced at every acquiring entry point, not
just one.

**The double check.** Part 8.6's two cases, and the proof that neither alone
suffices: a list of exactly one member, which only the walk catches, and an
item on a *different* list, which only the link test catches. Safe builds only,
by construction.

**The deadline.** D7's anchor, tested the way Q7 tested the primitive: a wait
woken spuriously several times must still time out at roughly the original
deadline. A `wait_timeout`-based loop passes every naive timeout test and fails
this one.

**The give-back rules.** Part 11.6 and 11.8, including the two named mistakes:
discarding the list `close` returns, and a mid-batch `put_all` refusal leaving
the rest with the caller at the front of their list.

**Close before release.** Tier 1, in all four builds, including the fast
optimized one. The only test that asserts on an abort.

**The layering.** Section 5.12's claim, as a grep in the test script:
`mailbox.c3` and `pool.c3` reference no `@private` name from the core four.
Part 17.3 calls this the test of the design, so the port makes it one.

**Concurrency.** Many producers and many consumers on one mailbox; hooks
running in parallel on different threads; a `close` racing a `release`. Run
under the four builds, and under a thread sanitizer where the toolchain offers
one.

## 7.4 What the kitchen gate needs

`kitchen/tools/check_design.sh` exits 1 today, before this stage and after it.
43 problems, 29 of them orphans under `design/secondary/lang/`, because
`design/secondary/context.md` lists no `lang/` subfolder at all.

This file adds one more orphan row, for the same reason. It is drift in
`context.md`, not in this line of work, and it is not fixed here. Recorded
again so the count is not mistaken for a regression.

---

# 8. The conflict register, closed

Every conflict of `3tk-drafts-review-001.md` section 9, with its state after
this stage.

| # | Subject | State |
|---|---|---|
| C1 | Does `typeid` satisfy Part 5.1? | **Closed by 3TK-4.** Yes, measured |
| C2 | `inline`, or a plain field? | **Closed here. D2** — plain field |
| C3 | Is `Any` usable? | **Closed by 3TK-4** and applied in D8 — type yes, module no |
| C4 | What is the Slot? | **Closed here. D5** — the Slot is the container, and in this port the compiler enforces it |
| C5 | Hooks: interface or struct? | **Closed by 3TK-4** on the mechanism, and the signatures are fixed in 5.9 |
| C6 | The `AnyList` surface | **Closed here.** Section 5.5, sixteen operations, from Part 8.2 |
| C7 | Allocator at release? | **Closed here. D3** — no release call takes one |
| C8 | Where the list goes in the order | **Closed here. D11** — Part 22 as written, step 5 |
| C9 | Two `project.json` shapes | **Closed here.** Section 7.1, a third, written to be compiled |
| C10 | Typed handles | **Closed here. D4** — no |
| C11 | `polynode` or `AnyNode` naming | **Closed here. D8** — `AnyNode`, and `NodeList` not `AnyList` |

Eleven closed, four of them by 3TK-4 and seven here. All seven accepted by the
owner, 2026-08-23.

---

# 9. What was built from this

Both stages are done and this section is a record rather than a plan.

- **3TK-6** wrote steps 2 to 5 — `any.c3`, `helper.c3`, `owned.c3`, `list.c3`.
  The toolkit of Part 17.1. Nine findings, in `3tk-toolkit-notes-001.md`.
- **3TK-7** wrote steps 6 and 7 — `mailbox.c3`, `pool.c3`. The two optional
  tools of Part 17.2, depending on nothing in the first beyond its public
  surface. Six findings, in `3tk-containers-notes-001.md`.

**All four builds green: 55 checks, 0 failures.** 71 tests × 4 builds, 6
runtime negatives, 2 tier 1 negatives, 3 compile-time refusals, 3 layering
checks. `3tk/run-builds.sh`.

**Part 18 is complete.** All thirty-three invariants reached — twenty-eight
tested or provoked, five structural or documented, each saying which.

Sixteen decisions, sixteen exercised, sixteen survived. The amendments across
both stages are two spellings and one structural change, all folded into this
version, and none of them moved a decision.

What is not done is listed in `3tk-containers-notes-001.md`: no sanitizer run,
the signal hand-off test is a race run twenty times, and linux-x64 is the only
target built. Packaging was never in this line of work.

---

## Change log

| Version | Date | Description |
|---|---|---|
| 001 | 2026-08-23 | First version. Stage 3TK-5. Sixteen decisions, all PROPOSED. |
| 002 | 2026-08-23 | **Owner accepted all sixteen.** G1's submodules accepted. Amendments from the code folded in: F1's build flags, F3/F5's `@check`, F4's aliases, G2's `~`, G4's flat buckets, G5's two Slots. No decision moved. |
