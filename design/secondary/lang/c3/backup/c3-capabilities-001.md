# C3 capability study (001)

Stage 3TK-4. The capability questionnaire of
[matryoshka-specification-001.md](../common/backup/matryoshka-specification-001.md) Part 21,
answered for C3, with a citation per answer.

Every answer marked **verified** was compiled and run. Every answer marked
**read** comes from the stdlib sources only.

## The toolchain measured

- `c3c` 0.8.3, git `1d155ee`, LLVM 22.1.8, installed at
  `/home/g41797/dev/langs/c3`.
- Stdlib sources at `/home/g41797/dev/langs/c3/lib/std/`.
- Target `linux-x64`. Probes compiled with `c3c compile-run`, and where build
  mode mattered, with `--safe=no` and `-O0`/`-O3`.

Citations are `file:line` under `lib/std/`.

## What a probe is

A probe is a small program written for one question, compiled, and run. Its
output is quoted in the answer. Probe sources are reproduced inline here rather
than kept as files, so this document is self-contained.

Twelve probes were run. Three of them are negative — they are expected to fail
to compile, and the compiler's message is the evidence.

## The short answer

| Q | Subject | C3 |
|---|---|---|
| Q1 | Compile-time generation over a type | **yes** — generic modules |
| Q2 | A per-type identity | **yes** — `typeid`, native |
| Q3 | Embedding and inner-to-outer arithmetic | **yes** — `inline` *and* `::members` offsets |
| Q4 | Opaque types or private fields | **half** — no private fields; a real opaque type instead |
| Q5 | Interfaces or vtables | **yes** — `interface` and `@dynamic` |
| Q6 | Scope-exit cleanup | **yes** — `defer` |
| Q7 | Threads, mutex, timed condition wait | **yes** — including `wait_until` on an absolute deadline |
| Q8 | An allocator an object keeps for life | **yes** — `Allocator` is itself an interface |
| Q9 | A two-state container for the Slot | **yes** — nullable pointer, and it can be made distinct |
| Q10 | Atomics | **yes** — `Atomic{Type}` with orderings |
| Q11 | Build modes | **yes, with a trap** — see Q11 |
| Q12 | Compile-time reflection on fields | **yes** — `$Type::members` with `.name`, `.type`, `.offset` |

Eleven of twelve are a clean yes. C3 is a better host for Matryoshka than Zig
0.16 is, on every axis the specification measures except one — Q4 — and the
excluded surface of Part 16 shrinks by a whole file.

---

# Q1 — Compile-time generation over a type

**Yes. Generic modules.** Verified.

A module is parameterized on a type, and every declaration inside it is
generated per instantiation.

```c3
module mtk::helper <Type>;
```

*Read*: `collections/list.c3:4`, `collections/linkedlist.c3:4`,
`collections/maybe.c3:1` — the whole stdlib collection layer is built this way.

Instantiation is by brace, one alias per generated declaration:

```c3
alias msg_init     = mtk::helper::init{Msg};
alias msg_from_any = mtk::helper::from_any{Msg};
```

*Read*: `hash/sha256.c3:8-9`, `math/complex.c3:7-11`.

**Verified.** A complete per-type helper — Part 7.2's seven members — was
generated for two outer types and exercised:

```
distinct tags        : true
Job inner offset     : 8
from_any right type  : true
from_any wrong type  : true
must_from_any        : true
move: got item       : true
move: slot cleared   : true
mismatch: nothing    : true
mismatch: untouched  : true
```

The last two lines are Part 7.2's moving crossing on a mismatch: nothing
returned, Slot untouched.

**Consequence for the port.** Part 7.1's SHOULD is met in full. The helper is
generated, not hand-written.

**Against the drafts.** `3tk-polyhelper.md` proposed
`macro PolyHelper(Type) { ... fn ... }` with a body full of function
declarations. That is not the mechanism. A C3 macro does not declare
functions; a generic *module* does. The draft's overall shape survives; its
spelling does not.

---

# Q2 — A per-type identity

**Yes. `typeid` is native, and it satisfies every clause of Part 5.1.**
Verified.

The spelling is `Type::typeid`, with a double colon. `Type.typeid` does not
compile — *"A type can't appear here."*

Probe output:

```
module-scope const typeid : true
Msg != Msg2 (same layout) : true
Msg == Msg                : true
stored in field, read back: true
typeid as uptr            : 47b328
```

Clause by clause against Part 5.1:

| Clause | Result |
|---|---|
| A value identifying the type of the outer | `typeid`, one word |
| Unique at runtime across all outer types | **`Msg` and `Msg2` have identical layouts and differ.** No merging |
| Two items of one type carry the same value | `Msg::typeid == Msg::typeid` |
| Two of different types never do | as above |
| O(1) to compare | a pointer-sized value, compared by `==` |

Part 5.4 — *stored, not computed* — holds: the value assigns to a struct field
and reads back equal.

Part 5.3's second half does not apply. C3 has a native identifier, so the
address-of-a-per-type-global trick, and ztk's mutable-byte defence against
linker merging, are both unnecessary.

*Read*: `core/types.c3:83` `typeid.is_subtype_of`, `core/builtin.c3:145`
`@typeid`, `core/builtin.c3:760` `typeid.hash`, `collections/object.c3:13` —
the stdlib itself stores a `typeid` in a struct field for exactly this purpose.

**This closes conflict C1 of the review.** Four drafts assumed it; the fifth
flagged it as the dangerous area. The four were right, and the assumption is
now measured rather than assumed.

**One thing the ztk model gains.** Part 6.5 records that a `switch` over ztk's
tags does not compile on any backend, because a tag is a linker-assigned
address. In C3 it compiles:

```c3
switch (handle.type)
{
    case Msg.typeid: ...
    case Job.typeid: ...
    default:         ...
}
```

Verified — the probe printed `switch: Job`. So Part 6.5's dispatch table is
optional for this port. The table remains the better shape where handlers are
registered at runtime; the branch is available where they are not.

---

# Q3 — Embedding and inner-to-outer arithmetic

**Yes, both ways.** Verified.

**By value, with implicit conversion.** `inline` on the field gives an implicit
outer-pointer to inner-pointer conversion:

```c3
struct Msg { inline AnyNode node; int id; }
Msg* pm = &m;
AnyNode* an = pm;      // implicit
```

Probe: `implicit Msg* -> AnyNode* : true`, and the result equals `&m.node`.

**At any offset, by arithmetic.** The offset of a field is available at compile
time (Q12), so the way back works from a field that is not first:

```c3
struct Job { int pri; AnyNode node; String what; }   // inner at offset 8
Job* back = (Job*)((char*)node_ptr - OFF);
```

Probe: `Job inner offset : 8`, `inner -> outer at offset 8: true`.

**Consequence for the port.** Part 4.3's fallback — *"A port whose cast needs
offset zero fixes the field at offset zero instead"* — is not needed. C3 has
the full freedom the specification's SHOULD describes.

**This closes conflict C2 of the review.** `3tk-polyhelper.md` assumed offset
zero and a plain cast; `3tk-design-notes.md` and `3tk-porting-notes.md` wanted
`inline`. Both compile. They are not, however, the same design:

| | `inline AnyNode node` | `AnyNode node` at any offset |
|---|---|---|
| Outer to inner | implicit | `to_any()` through the helper |
| Field may sit anywhere | yes | yes |
| Reader sees the crossing | **no** | yes |

The second column is what Part 7.5 asks for: *every* crossing goes through the
helper, so the arithmetic appears in one file. `inline` makes one direction of
the crossing invisible at the call site. That is a real argument against
`inline` that neither draft raised, and it is the owner's to weigh.

Note also Part 10.1: the four names exist so a reader of a signature knows
which side of the border they are on. An implicit conversion erases that.

---

# Q4 — Opaque types or private fields

**No private fields. A real opaque type instead.** Verified, including two
negative probes.

**Per-field visibility does not exist.**

```c3
struct Thing { int a; int b @private; }
```

> `Error: '@private' cannot be used here.`

Nothing in the stdlib uses per-field visibility. `@private` and `@local` apply
to declarations — functions, globals, constants, whole types.
*Read*: `collections/list.c3:426`, `core/dstring.c3:10`, `core/dstring.c3:749`.

**A private struct behind a public alias hides nothing.**

```c3
struct PoolImpl @private { ... int in_pool; ... }
alias Pool = PoolImpl;
```

Another module reads `p.in_pool` and it compiles. The alias re-exports the
layout.

**A distinct opaque type does work.**

```c3
typedef Pool = void;                         // in the library module
fn int Pool.count(&self) => ((PoolImpl*)self).in_pool;
```

From another module: `p.count()` works, and `p.in_pool` gives

> `Error: There is no field or method 'Pool.in_pool'.`

**Consequence for the port.** Part 11.11 SHOULD says *"Where the language has
opaque types or private fields, they are hidden"*, and calls this a place where
a port can be better than ztk. C3 can be better, but only by the opaque route,
and the opaque route costs something the drafts did not price:

- A `typedef Pool = void` is no longer a struct that embeds an inner. Part 11.1
  MUST — *the two containers are themselves items* — then has to be satisfied
  through the implementation struct, and the helper for the container is bound
  to `PoolImpl`, not to `Pool`.
- Every method body begins with a cast.

**Against the drafts.** `3tk-design-notes.md` D15 and `3tk-porting-notes.md`
N19 both state that C3 private fields let the struct stay public while its
state is hidden, and N19 builds a whole separation of concerns on it —
*"private fields hide implementation state; typed handles restrict API usage.
Do not mix these two reasons"*. The first half of that sentence describes a
feature C3 does not have in 0.8.3. This is the study's sharpest correction, and
it reopens a design question both drafts considered settled.

The honest options for the port are three, and none is free:

1. Public struct, public fields, a comment saying internal — exactly ztk, no
   better.
2. `typedef Pool = void` — real hiding, at the cost above.
3. Keep the fields public and rely on the helper border. Part 7.5 already makes
   the crossing single-sited; the fields being reachable is then a
   documentation problem, not a structural one.

---

# Q5 — Interfaces or vtables

**Yes.** Verified.

```c3
interface PoolHooks
{
    fn void on_get(typeid want, AnyHandle* slot);
    fn void on_put(AnyHandle* slot);
    fn void on_close(AnyHandle list);
}

struct MyHooks (PoolHooks) { int made; }
fn void MyHooks.on_get(&self, typeid want, AnyHandle* slot) @dynamic { ... }
```

Probe: `interface dispatch : true`.

Three further facts, each verified:

- An interface value is **nullable**. An unset one compares equal to `null`.
- An interface value **carries the concrete typeid**: `h.type == Hk::typeid`.
- The stdlib's own `Allocator` is an interface. *Read*: `core/alloc.c3:17`.

**Consequence for the port.** Part 12.1 MUST — *"The port spells them in the
language's own interface mechanism"* — is met directly. The `ctx` field of the
ztk hook struct disappears, because the implementing object is the context.
Part 21 Q5's fallback is not needed.

**This closes conflict C5 of the review**, on the mechanism. It does not close
the signatures. The probe deliberately used the signatures the *specification*
requires, not the ones `3tk-additions.md` proposed:

- `on_get` takes the wanted identity and a **Slot to fill** — Part 12.2, "The
  Slot is empty on entry. Create one, or leave the Slot empty."
- `on_put` takes a **Slot**, so all four outcomes of Part 12.2 are expressible,
  and the extra list of Part 12.5 can be added as a second parameter.
- `on_close` takes **the list of what remained** — Part 12.2, and Part 11.8,
  since nothing comes back to the caller.

All three compile as written. The draft's three signatures were not a C3
limitation; they were a misreading.

`tags` — Part 11.7's fixed, non-empty set of identities — is a creation
parameter of the pool, not a member of the hook object. Nothing in C3 pushes it
either way, and `3tk-additions.md` A6's hedge was right to hedge.

---

# Q6 — Scope-exit cleanup

**Yes. `defer`.** Verified.

The stdlib relies on it heavily, including for allocator swapping.
*Read*: `core/mem.c3:510`.

There is also a scoped-lock macro that takes a body:

```c3
macro void Mutex.@in_lock(&mutex; @body)
```

*Read*: `threads/thread.c3:71`.

**Consequence for the port.** Part 9.7 SHOULD — the release of a Slot is
arranged *before* the acquisition that fills it — is one line. The
write-it-at-every-exit fallback is not needed.

---

# Q7 — Threads, a mutex, a condition variable with a timed wait

**Yes, all four, and the timed wait is the good kind.** Verified.

*Read*: `threads/thread.c3:11-17` — `Mutex`, `TimedMutex`,
`ConditionVariable`, `Thread`, `OnceFlag`, all as typedefs over native types.

The condition variable has **three** waits. *Read*: `threads/thread.c3:78-104`.

| Call | Shape |
|---|---|
| `wait(mutex)` | untimed |
| `wait_timeout(mutex, ms or Duration)` | relative |
| `wait_until(mutex, Time)` | **absolute deadline** |

This matters more than it looks. Part 2.5 MUST — *the deadline is anchored
once, before the loop* — and invariant 4 of Part 18. The relative form
recomputes the deadline on every call:

```c3
fn void? NativeConditionVariable.wait_timeout(&cond, NativeMutex* mtx, long ms)
{
    Time time = time::now() + time::ms(ms);
    return cond.wait_until(mtx, time) @inline;
}
```

*Read*: `threads/os/thread_posix.c3:158-162`.

**So a wait loop written on `wait_timeout` violates Part 2.5**, and does so
silently — every spurious wakeup restarts the full timeout, without bound.
This is exactly the defect the review found in `3tk-poc.md` (row P7), and C3
makes it easy to write. The port anchors once and loops on `wait_until`.

Verified, both directions:

```
received under deadline : true
elapsed under 500ms     : true
past deadline times out : true
```

A deadline already in the past returns immediately with `thread::WAIT_TIMEOUT`.

The timeout is reported as a fault, not a return value:
`if (catch f = cv.wait_until(&mu, deadline)) { ... f == thread::WAIT_TIMEOUT ... }`.
*Read*: `threads/thread.c3:22-31` for the `faultdef` set, and
`threads/os/thread_posix.c3:179-194` for `ETIMEDOUT`.

`broadcast` exists — *read*: `threads/thread.c3:81` — which Part 11.5's
wake-every-waiter needs.

**Consequence for the port. Part 16 row 7 is deleted.** ztk hand-wrote a timed
condition wait, 71 lines, because Zig 0.16 has none. C3 has one, in the
stdlib, on an absolute deadline. Rows 1 to 11 of Part 16 go with the rest of
`std.Io`. Every draft agreed there is no `std.Io` equivalent, and every draft
was right.

**Interruption — Part 2.9, a SHOULD — has no native support.** `INTERRUPTED`
exists as a fault, but only for `sleep` and for `TimedMutex.lock_timeout` on
`EINTR`. *Read*: `threads/os/thread_posix.c3:94`, `:334`. There is no
interruptible condition wait. A port that wants Part 2.9 builds it from a flag
and a broadcast. Part 20 decision 8 stands open, and C3 does not settle it.

---

# Q8 — An allocator an object keeps for life

**Yes.** Verified.

`Allocator` is an interface, so it is one pointer-plus-type value that stores
in a field. *Read*: `core/alloc.c3:17`.

```c3
struct PoolImpl { inline AnyNode node; int in_pool; Allocator alloc; }
fn void Pool.release(&self) { alloc::free(self.alloc, self); }   // no parameter
```

Verified: created through `alloc::new(a, PoolImpl)`, released through the kept
allocator with no second argument.

*Read*: `core/alloc.c3:179` `new`, `core/alloc.c3:113` `free`,
`core/allocators.c3:18` — `mem` is a builtin alias for the thread allocator, so
a default exists without a global dependency being forced on the library.

**Consequence for the port.** Part 13.1 SHOULD is met in full, including its
sharp clause: *no release call takes an allocator as a parameter*. Part 13.5
does not apply — allocation is parameterized.

**Conflict C7 of the review stays open, and narrows.** The language imposes
nothing. Part 13.4 leaves the application-item half to the port, Part 20
decision 2 lists it, and the first open question in `3tk-status.md` is the same
question. `3tk-polyhelper.md` H9 wrote `destroy(Allocator, slot)`; that is now
a choice, not a necessity, and Part 13.1 says which way to choose for the two
containers at least.

---

# Q9 — A two-state container for the Slot

**Yes, and it can be made distinct.** Verified, with two negative probes.

Pointers are nullable by default, so `AnyNode*` is already a two-state
container. That is the transparent option, and it is what the drafts propose.

The distinct option also works:

```c3
typedef Slot = AnyHandle;
```

and it is enforced in both directions:

> `Error: Implicitly casting 'AnyHandle' (AnyNode*) to 'Slot' is not permitted`

> `Error: Implicitly casting 'Slot*' to 'AnyHandle*' (AnyNode**) is not permitted`

A zero-initialized `Slot` is null, so Part 9.2 rule 2 — *a Slot starts empty* —
is the default state.

There is also `std::collections::maybe` — a `{value, has_value}` struct,
generic. *Read*: `collections/maybe.c3:1-8`. It is not needed for a pointer and
costs a word.

**Consequence for the port.** Part 9.9 MAY, and Part 20 decision 1, are live
and both options are real. The distinct type catches misuse at compile time and
costs the language's own null test, exactly as Part 9.9 predicts.

**On conflict C4 of the review — the naming.** The probes make the shape plain.
The Slot is the nullable handle. `AnyHandle*` is a *pointer to* a Slot, which is
what Part 9.3 says an acquiring operation takes. Four drafts call the double
pointer "the Slot". Nothing in C3 forces or excuses that; it is a word to fix,
and Part 9.2's six rules are unstateable until it is.

**On conflict C10 — typed handles.** The second negative probe is the cost
`3tk-additions.md` A15 predicted and `3tk-porting-notes.md` N4 did not price:
a distinct handle type means every Slot-shaped call site writes
`(AnyHandle*)&h`. Part 7.5 MUST says application code never performs the
crossing by hand and the arithmetic appears in one file. A cast at every call
site is the opposite of that. The language confirms the cost; the ruling is
still the owner's.

---

# Q10 — Atomics

**Yes.** Verified.

```c3
struct Atomic <Type> { Type data; }
```

*Read*: `atomic.c3:10`. Load and store take an `AtomicOrdering` — `RELAXED`,
`ACQUIRE`, `RELEASE`, `ACQUIRE_RELEASE`, `SEQ_CONSISTENT` — with contracts
rejecting the invalid combinations. *Read*: `atomic.c3:19-31`.
`compare_exchange` takes separate success and failure orderings.
*Read*: `atomic.c3:49`.

There is also a standalone fence: `thread::fence($ordering)`.
*Read*: `threads/thread.c3:66`.

Probe: `atomic acquire load : true`, after a `RELEASE` store.

**Consequence for the port.** Part 15.4's pre-lock fast path is available, and
Part 15.3's closed flag has its natural spelling. Part 14.2 — *the transfer
orders memory* — is expressible. Part 20 decision 9 stays a design choice, not
a capability question.

---

# Q11 — Build modes

**Yes, and there is a trap the specification's model does not cover.**
Verified across four builds.

Two assert forms exist.

| Form | Safe build (default) | `--safe=no -O0` | `--safe=no -O3` |
|---|---|---|---|
| `assert(cond, msg)` | aborts, names the message | **no-op, execution continues** | **undefined behaviour — segfault** |
| `always_assert(cond, msg)` | aborts | aborts | aborts |

*Read*: `core/builtin.c3:158` — `always_assert` is a plain runtime check with
`abort`, unconditional.

Build mode is readable at compile time:

```c3
const bool COMPILER_SAFE_MODE = $feat(SAFE_MODE);
const bool TESTING = $feat(TESTING);
const CompilerOptLevel COMPILER_OPT_LEVEL = ...;
```

*Read*: `core/env.c3:129-140`. Verified: a default build reports
`SAFE_MODE=true OPT=O0`; `--safe=no -O3` reports `SAFE_MODE=false OPT=O2`.

**The trap.** In ztk's model an assert that is compiled out is *gone*. In C3 at
`--safe=no` with optimization, a plain `assert` becomes an assumption the
optimizer is entitled to act on. A violated assert is then not a missed check —
it is undefined behaviour. The probe segfaults, having printed nothing at all,
in a program whose only fault is one false `assert`.

**Consequence for the port.** Three places in the specification depend on this,
and each gets a different answer:

- **Part 11.12 MUST** — close before release *"stops the program. In every
  build mode. Not an assert that compiles out."* → `always_assert`. This is the
  one call the specification refuses to soften, and C3 has exactly the right
  primitive for it.
- **Part 8.6 SHOULD** — the double check on insert, *"under a build mode that
  checks"* → guard the O(n) walk with `$if env::COMPILER_SAFE_MODE`, so the
  loop is not merely unchecked in a fast build but absent from it.
- **Part 15.5 SHOULD** — asserts versus reported outcomes → plain `assert`, and
  the port writes down that a violated one is UB in an optimized unsafe build,
  not a silent pass.

Part 20 decision 10 — *where does the O(n) insert check live on a port with no
build modes* — does not arise. C3 has build modes.

Tests are first class: `fn ... @test`, run by `c3c compile-test`. Verified:
`1 passed, 0 failed, 0 skipped`.

---

# Q12 — Compile-time reflection on a struct's fields

**Yes.** Verified.

```c3
$foreach $m : Off::members:
    // $m.name   $m.type   $m.offset
$endforeach
```

Probe output for `struct Off { int pad; AnyNode node; double d; }`:

```
name=pad  offset=0
name=node offset=8
name=d    offset=32
```

*Read*: `io/formatter.c3:38-48` and `encoding/json_marshal.c3:44` use the same
mechanism.

The property spellings that exist in 0.8.3, since three drafts guessed
otherwise: `Type::members`, `Type::name`, `Type::typeid`, `Type::size`,
`Type::alignment`, `Type::kind`, `Type::inner`, `Type::len`. Not `sizeof`, not
`nameof`, not `membersof`, and not `.offsetof` on a member — it is `.offset`.

**Consequence for the port.** Part 7.4 SHOULD is met at build time, in full,
including its last clause — *the message names the offending type*:

```c3
$assert $off >= 0 : "type " +++ Type::name +++ " has no AnyNode field";
```

Verified against a type with no inner:

> `Error: type NotAnItem has no AnyNode field`

That is Part 7.4's four bullets, all four, before the program links.

**One mechanical note worth carrying.** A `return` inside `$foreach` does not
end compile-time iteration. The offset lookup accumulates into a `var $off` and
asserts afterwards; written the obvious way it always reaches the `$error`.

---

# Verified spellings

The drafts guessed at C3 syntax in a dozen places. What compiles, in 0.8.3:

| Subject | Draft guess | Actual |
|---|---|---|
| Type identity | `Type::typeid` (`3tk-polyhelper.md`) | **`Type::typeid`** — correct |
| Generated helper | `macro PolyHelper(Type) { fn ... }` | `module m::helper <Type>;` plus `alias f = m::helper::f{Type}` |
| Contracts | `fn ... @require(cond)` | `<* @require cond : "message" *>` above the function |
| Field offset | not attempted | `$Type::members` → `$m.offset` |
| Size | `Type.sizeof` | `Type::size` |
| Type name | `Type.nameof` | `Type::name` |
| Field list | `Type.membersof` | `Type::members` |
| Create/destroy opt-out | `$if !Type.has_tag("no_create_destroy")` | no such property. Two generic modules, or a second parameter |
| Slot alias | `typedef Slot = ItemHandle?` | `alias AnyHandle = AnyNode*` (transparent) or `typedef Slot = AnyHandle` (distinct) |
| Allocator calls | `allocator.alloc(Type)` | `alloc::new(a, Type)`, `alloc::free(a, p)` |
| Module named `any` | proposed by three drafts | **rejected** — reserved keyword |
| Type named `Any` | disputed | **accepted** — `struct Any` and `alias Any` both compile |

Two naming hazards found while probing, neither in any draft:

- **A struct name that is all uppercase is rejected.** `struct H` does not
  compile. Short helper names need a lowercase letter.
- **`std::collections::anylist` already exists**, and it is a heterogeneous
  list that **shallow-copies every element and owns the copies**
  (*read*: `collections/anylist.c3:4-19`). It is the semantic opposite of the
  Matryoshka list, under the exact name the drafts chose for it. Naming the
  port's list `AnyList` invites a reader to assume the wrong thing.

---

# What this study rules on

The eleven conflicts of
[3tk-drafts-review-001.md](3tk-drafts-review-001.md) section 9, so far as a
capability study can rule on them.

| # | Subject | Ruling |
|---|---|---|
| **C1** | Does `typeid` satisfy Part 5.1? | **Closed. Yes**, every clause, measured. Two identically-shaped types differ |
| **C2** | `inline`, or first field? | **Both compile.** Offset arithmetic works at any offset, so `inline` is not required for layout freedom. Left open, with a new argument: `inline` hides one direction of the crossing, against Part 7.5 |
| **C3** | Is `Any` usable? | **Closed.** As a **type name**, yes. As a **module name**, no — reserved. `3tk-porting-notes.md` was right, `3tk-additions.md` was right about the keyword and wrong about the consequence |
| **C4** | What is the Slot? | **Not a C3 question.** Part 9.1 already answers it. Both representations compile; the word is attached to the wrong half in four drafts |
| **C5** | Hooks: interface or struct? | **Closed on the mechanism. Interface**, per Part 12.1, verified. The three signatures in `3tk-additions.md` remain wrong against Part 12.2, and the corrected ones compile |
| **C6** | The `AnyList` surface | **Not a C3 question.** Part 8.2 has the full list. Note the name collision above |
| **C7** | Allocator at release? | **Open, and narrowed.** C3 imposes nothing. Part 13.1 settles the two containers; Part 13.4 and Part 20 decision 2 leave application items to the owner |
| **C8** | Where the list goes in the order | **Not a C3 question.** Part 22 is a suggestion. Note that the helper now needs no prototyping stage of its own — it was prototyped here |
| **C9** | Two `project.json` shapes | **Untouched.** Out of this stage's scope |
| **C10** | Typed handles | **Cost confirmed.** A distinct handle type forces an explicit cast at every Slot-shaped call site. The ruling is the owner's; the language has stated the price |
| **C11** | `polynode` or `AnyNode` naming | **Untouched**, except that `anylist` is taken by the stdlib |

And one thing the study found that the review did not ask about:

**Q4 reopens a settled question.** `3tk-design-notes.md` D15 and
`3tk-porting-notes.md` N19 both build on C3 private struct fields. There are
none. Part 11.11's "a port can be better than ztk here" is still reachable, by
the opaque-type route, at a cost neither draft priced.

---

# What Matryoshka gains, and what it still pays

**Gains, measured.**

- The whole of Part 16 rows 1 to 11 disappears with `std.Io`, and **row 7 — the
  hand-written timed condition wait, 71 lines — disappears because C3 has one**.
- Part 5's identity is native. No per-type global, no defence against linker
  merging, no mutable byte.
- Part 7.4's validation runs at build time and names the offending type.
- Part 6.5's dispatch may be a `switch`. ztk cannot.
- Part 12.1's hooks are an interface, and `ctx` disappears with it.
- Part 9.7's cleanup-before-acquisition is one `defer`.
- Part 13.1's release-without-an-allocator-parameter is natural.

**Still paid.**

- **Q4.** No private fields. Hiding costs an opaque type, and an opaque
  container is no longer literally the struct that embeds the inner.
- **Part 2.9.** No interruptible condition wait. A port that models
  interruption builds it.
- **Q11.** A plain `assert` under `--safe=no -O3` is an assumption, not a
  removed check. Part 11.12's unconditional stop must be `always_assert`, and
  Part 8.6's O(n) walk must be `$if`-guarded rather than assert-guarded.
- **Part 8.1.** No intrusive doubly-linked list in the stdlib. The stdlib's
  `linkedlist` allocates a node per element (*read*:
  `collections/linkedlist.c3:9-14`) and its `anylist` copies. The port writes
  its own — which Part 8.5 requires in any case.

---

# For 3TK-5

Carried forward, in the order the porting proposal will need them.

1. **The Q4 decision.** Three options are listed under Q4. It is now a real
   decision, not a settled assumption, and it touches Part 11.1 and Part 11.11.
2. **The C2 decision**, with the new argument: `inline` versus an explicit
   crossing through the helper, weighed against Part 7.5 and Part 10.1.
3. **The C7 decision**, jointly with the first open question of
   `3tk-status.md`.
4. **The C10 decision**, now that the cast cost is confirmed.
5. **The assert policy.** Which of the three forms — `always_assert`, `assert`,
   `$if`-guarded block — applies at each site. Part 8.6, Part 11.12, Part 15.5.
6. **The `wait_until` rule**, written down once: anchor the deadline before the
   loop, never loop on `wait_timeout`.
7. **The names.** `AnyList` collides with `std::collections::anylist`. `Any` is
   available as a type, unavailable as a module. No all-uppercase type names.
8. **Interruption.** Part 20 decision 8, with no native support to lean on.

Nothing in Part 21 blocks the port. Every "no" in this study is a cost the port
pays knowingly, and there are four of them.

---

## Change log

| Version | Date | Description |
|---|---|---|
| 001 | 2026-08-23 | First version. Stage 3TK-4. c3c 0.8.3, twelve probes. |
