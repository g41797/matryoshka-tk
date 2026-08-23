# matryoshka-dtk prototype — scope and go/no-go

The porting proposal is right: do not implement the handbook. Prove the model
first.

This document defines the smallest thing that proves it, what each part answers,
and what "answered" looks like as an observation rather than an impression.

---

## What this is

A throwaway repository or branch. Roughly 1,200 lines. Two to four evenings.

Its only purpose is to convert the open questions into observations. It is not
the first version of `matryoshka-dtk` and no line of it is expected to survive
into one.

## What this is not

```text
not a Pool                  not OOB
not hooks                   not receive_batch
not cancellation            not betterC
not a CI matrix             not documentation
not an API proposal         not a performance test
```

Every one of those is deferred deliberately. §6 says when each comes back.

---

# 1. Three spikes, before anything

Three questions can kill the design, and each is answerable in under an hour by
a file you delete afterwards. Do these first. If any fails, the prototype's
shape changes before you have written anything worth keeping.

## S1 — is `core.sync` usable for a heap-allocated Mbox?

The proposal is right that "the Mutex is a class" does not imply "write your
own". The class problem is about allocation, not usability.

```d
// spike/s1_coresync.d
import core.sync.mutex, core.sync.condition;
import core.lifetime : emplace;
import core.stdc.stdlib : malloc, free;

void main() @nogc nothrow
{
    enum sz = __traits(classInstanceSize, Mutex);
    auto buf = cast(void[]) malloc(sz)[0 .. sz];
    auto m   = emplace!Mutex(buf);

    m.lock_nothrow();
    m.unlock_nothrow();
}
```

**Answered when you know:** whether `emplace` of `Mutex` and `Condition` into
policy-allocated storage compiles, whether the `_nothrow` forms are usable from
`@nogc nothrow` code, and whether `Condition.wait(Duration)` has an equivalent.

**What each outcome means:**

```text
works                   → no custom sync layer. sync.d is ~40 lines of wrapper.
works for Managed only  → two backends, one Mbox. The proposal's §11 direction.
neither                 → custom wrapper, and the maintenance cost is now a
                          known input to the go/no-go rather than a surprise.
```

## S2 — does `shared` stay readable?

```d
// spike/s2_shared.d
struct Box
{
    private int n;
    private ref Box raw() shared @trusted { return *cast(Box*) &this; }

    void bump() shared { raw().n++; }
    int  get()  shared { return raw().n; }
}

void main()
{
    auto b = new shared Box;
    b.bump();
}
```

Then extend it: pass `shared(Box)*` to `core.thread`, to
`std.concurrency.spawn`, and store one in another struct.

**Answered when you know:** whether one `raw()` per public method is sufficient
or whether casts leak into the body, and whether `shared(Mbox)*` passes
`spawn`'s `hasUnsharedAliasing` check without a cast at the call site.

## S3 — does attribute inference reach through a policy and a function pointer?

This is the Pool question in miniature, which is why Pool itself can be
deferred.

```d
// spike/s3_infer.d
struct Managed { T* acquire(T)() { return new T; } }
struct Manual  { T* acquire(T)() @nogc nothrow { return null; } }

struct Holder(P)
{
    P p;
    int* make() { return p.acquire!int(); }     // no attributes written
}

@nogc nothrow unittest
{
    Holder!Manual h;
    auto x = h.make();                          // must compile
}

unittest
{
    Holder!Managed h;
    auto x = h.make();                          // must also compile
}
```

Then repeat with a `void function(...)` field instead of a policy method.

**Answered when you know:** whether `@nogc` is inferred through the template,
and whether an unattributed function pointer field blocks inference for the
whole struct — which decides whether hooks can stay unattributed.

---

# 2. Files, in build order

```text
prototype/
    source/dtk/
        node.d        Node, PolyNode, PolyTag, reset, isLinked
        list.d        intrusive doubly-linked list
        slot.d        Slot  (two variants — see step 2)
        policy.d      Manual, Managed
        helper.d      PolyHelper!(T, Policy), TagOf!T
        sync.d        whatever S1 concluded
        mbox.d        send, receive, close, wakeUpAll
    tests/
        nogc_audit.d  the attribute proof
        mbox_test.d   two threads, one mailbox
    examples/
        ping.d        one item, sender and receiver, both policies
```

One item type. One example. No barrel modules, no package.d, no docs.

---

# 3. What each step proves

## Step 1 — `node.d`, `list.d`

Low risk, needed by everything.

**Proves:** the `offsetof` parent cast works and inlines; `reset` inside
`remove` eliminates the link-clearing hazard; the whole layer infers
`@nogc nothrow` with no attributes written.

**Watch for:** `@trusted` count. This layer should need exactly one — the
parent-pointer cast.

## Step 2 — `slot.d`, both variants

Build the plain alias and the strict struct. Write `examples/ping.d` twice,
once against each, and read them side by side.

```d
// variant A
alias Slot = PolyNode*;

// variant B
@mustuse struct Slot { ... }   // @disable this(this), ~this asserts empty
```

**Proves or disproves:** "the Slot is pleasant." This is a killer criterion in
the proposal and it cannot be settled by argument.

**Decide by:** which `ping.d` you would rather hand to a new user. Not which
has better guarantees — that answer is already known and is not the question.

**Watch for:** how often variant B forces `.peek()` where variant A reads
directly. If the example is dominated by accessor calls, the strict Slot loses
regardless of what it enforces.

## Step 3 — `policy.d`, `helper.d`

One item type, both policies.

**Proves:** that Manual and Managed share one implementation. This is the
proposal's killer #2.

**Watch for:** the count of `static if (Policy.managed)`. The claim is three —
`acquire`, `release`, and hook aliases. Hooks are deferred here, so the
prototype's honest number is **two**. A third means the claim is already wrong.

**Also settle here:** whether `TagOf!T` at module scope gives one tag per type
across both policy instantiations. One `assert(TAG!(Request, Manual) is
TAG!(Request, Managed))` closes it.

## Step 4 — `sync.d`

Implement what S1 concluded, and nothing more than `Mutex` and `Condition`.

**Watch for:** line count. See the threshold in §5.

## Step 5 — `mbox.d`

`send`, `receive` with timeout, `close`, `wakeUpAll`. Nothing else.

**Proves:** that the concurrency model works and that `shared` survives contact
with a real type.

**Settle here, by writing it both ways:** whether `closed` needs to be atomic.
Write it as an ordinary field under the mutex first. Only if a use appears that
must read it outside the lock does it become `shared bool`. The proposal is
right that this was inherited rather than chosen.

## Step 6 — the measurement pass

Not a build step. An hour with `grep` and the thresholds below.

---

# 4. Which open question each step answers

The proposal's §50 lists fifteen questions. Twelve are answerable by this
prototype; three are not, and should stay open rather than be guessed.

| Question | Answered by | Answered means |
|---|---|---|
| Public struct pointer or opaque? | Step 5 | `ping.d` compiles against an opaque `Mbox*` with no loss |
| Methods or module functions? | Step 5 | whichever `ping.d` reads better with `shared` in play |
| Slot representation | Step 2 | the two `ping.d` files, read side by side |
| Slot copy/move rules | Step 2 | variant B compiles the example without fighting it |
| Slot destructor assertion | Step 2 | it fires on a deliberately dropped Slot, and never otherwise |
| PolyTag mechanism | Step 3 | one tag per type across both policies, asserted |
| `shared` on the Mbox API | S2 + Step 5 | one `raw()` per method, no cast in any body |
| druntime sync for Managed | S1 | `emplace` works, `_nothrow` forms usable |
| Native wrapper for Manual | S1 | only if S1's first two outcomes both fail |
| Manual/Managed template boundary | Step 3 | the `static if` count is 2 |
| Item allocation rules | Step 3 | `Manual` + a GC-referencing item fails to compile |
| Item destructor prohibition | Step 3 | write one, observe the timing difference, then decide |
| Cancellation API | **deferred** | needs Pool and a real workload |
| BetterC | **deferred** | separate target, see §6 |
| Minimum compiler version | **deferred** | pick after the prototype compiles on latest |

---

# 5. Go / no-go, as numbers

Set these **now**, before writing, so the verdict cannot be retrofitted. The
values below are proposals — change them if you disagree, but change them
today, not after you have seen the code.

```text
[ ] @trusted blocks in source/dtk/, excluding sync.d          ≤ 6
[ ] cast( occurrences outside sync.d and helper.d             ≤ 3
[ ] static if (Policy.managed) occurrences                     = 2
[ ] shared-cast sites per public Mbox method                   = 1
[ ] lines in sync.d                                          ≤ 150
[ ] ping.d compiles unchanged against both policies         yes/no
[ ] the @nogc nothrow unittest compiles                      yes/no
[ ] Manual mode links with no druntime GC symbol             yes/no
[ ] mbox_test.d clean under LDC -fsanitize=thread            yes/no
[ ] a GC-referencing item under Manual fails to compile      yes/no
```

The last five are binary. The first five are the ones that will actually decide
it, because they measure whether the D version reads like D or like Zig wearing
a costume.

If `sync.d` exceeds 150 lines, that is not a failure of the prototype — it is
S1 telling you that a synchronization layer is a project of its own, which is
exactly the danger the proposal names.

---

# 6. Deferred, and when each returns

```text
Pool + hooks        after go. The @nogc-hook question is pre-answered by S3.
OOB, receive_batch  after go. Neither changes the model.
Cancellation        after Pool. It needs a workload to be designed against.
betterC             separate target, separate branch, after v0.1 works.
                    Manual ≠ betterC — do not let it shape the design.
CI matrix           after go. Until then: ldc latest, linux, debug, both
                    policies. Four jobs.
Documentation       after go. Nothing is worth documenting yet.
Naming (dtk/ztk)    orthogonal. Decide whenever.
```

---
---

# Addendum A — reconciliation

Three categories. **Settled** means the language forces it, not that we
preferred it. Everything chosen rather than forced is a hypothesis.

## Settled — forced by D

| | Why |
|---|---|
| `cast(ubyte*)`, not `void*`, for the parent pointer | `void*` arithmetic does not compile |
| `__gshared`, never `static`, for the tag | module and template `static` is thread-local |
| `initItem`, not `init` | `init` is a reserved property name |
| No AA in a `@nogc` Pool | D's built-in AA is GC-only; Phobos has no `@nogc` map |
| White-box tests live in `src/` | `private` is module-scoped |
| `static assert(T.poly.offsetof == 0)` is available | D lays out plain structs in declaration order |
| No error unions | exceptions are unavailable under `@nogc` |
| No `Io`-based cancellation | there is no `Io` |
| Deadline anchoring is manual | `Condition.wait` takes a `Duration`, not a deadline |
| Write your own intrusive list | `std.container.DList` is value-based and allocates |
| `core.sync.Mutex`/`Condition` are classes | fact — but the *response* is a hypothesis, see S1 |

## Hypothesis — to be tested

| | Tested by |
|---|---|
| Strict `Slot` struct beats the plain alias | Step 2 |
| `@disable this(this)` is worth the accessor calls | Step 2 |
| Destructor-asserts-empty is useful in practice | Step 2 |
| `shared` methods + one `raw()` cast per method | S2, Step 5 |
| Manual and Managed share one implementation | Step 3 |
| Exactly two `static if (Policy.managed)` | Step 3 |
| Import-based policy selection | after Step 3 |
| `hasManagedRefs` compile-time item check | Step 3 |
| Item types must have no destructors | Step 3 |
| Parallel arrays in Pool | deferred — but forced for `@nogc`, so narrower than it looks |
| Per-waiter cancellation flag | deferred |
| Struct `invariant` blocks | after go |
| Documented unittests as the API reference | after go |

## Rejected

| | Why |
|---|---|
| betterC as an early target | Manual ≠ betterC; it distorts every other decision |
| `ItemInfo` carrying allocation mode at runtime | the policy template parameter already is the check; the runtime field costs a word per item to catch a configuration the never-mix rule forbids |
| Custom pthread/Win32 sync as the default assumption | S1 first |
| `shared bool closed` + atomics by default | one synchronization mechanism until a lock-free read is actually needed |
| The full CI matrix up front | four jobs until go |
| Porting the documentation | nothing is stable enough to document |
| Starting from the Zig→D mapping table | architecture → lifetime → allocation → concurrency → type erasure → API |

## Independent of D

One item belongs to neither list: the Zig `receive` and `get_wait` build their
timeouts with `.clock = .real`. Wall clock. An NTP step or a manual clock change
moves every pending timeout in the process. Fix it in `matryoshka-ztk`
regardless of what happens to the D port.

---
---

# Addendum B — errata against the handbook

Four corrections, plus one framing error.

## B1 — "Write your own Mutex and Cond" was too fast

**The handbook says:** `core.sync.Mutex` and `Condition` are classes, therefore
write ~60 lines wrapping pthread and Win32.

**Correction:** the class problem is about allocation, not usability.
`emplace` into policy-allocated storage may resolve it, and druntime provides
`lock_nothrow`/`unlock_nothrow` and `@nogc`-usable forms. A custom
synchronization layer is a standing maintenance commitment and should be the
outcome of S1, not its premise.

**Where this propagates:** the monotonic-clock argument was bundled into the
same recommendation. It survives independently — whichever backend wins, the
timed wait must use a monotonic clock.

## B2 — `shared bool closed` was inherited, not chosen

**The handbook says:** `closed` is `shared bool` with `core.atomic` at the
access sites.

**Correction:** that came straight from the Zig, where the atomic exists because
there is no alternative. In D, if every mailbox field is under the mailbox
mutex, `closed` can be an ordinary field. Two synchronization mechanisms need a
reason. Add the atomic when a lock-free read appears, not before.

## B3 — Manual and betterC were conflated

**The handbook says:** betterC is "reachable" in Manual mode, includes it in
the CI matrix, and gates several decisions on it.

**Correction:** `@nogc` and `-betterC` are different targets. betterC removes
the runtime; `@nogc` removes GC allocation. Manual mode should target `@nogc`
plus minimal runtime dependency. betterC is a separate compatibility branch
taken after v0.1 exists, and it must not shape the design before then.

## B4 — the wakeUpAll rationale was overweighted

**The handbook says:** the epoch counter is needed because GC collections cause
spurious condvar wakeups.

**Correction:** a condition-variable wait must be predicate-based regardless of
any GC, so the loop structure is not a D-specific requirement. The epoch earns
its place for a different reason: it lets a receiver distinguish *deliberately
woken, no item* from *spurious, keep waiting*. Keep the epoch, drop the
justification.

## B5 — "Decisions taken" overstates what happened

The handbook's final section is headed *Decisions taken*. Nothing in it has been
compiled. They were conclusions reached in conversation, and the proposal is
right to call them hypotheses.

**Read that section as Addendum A's second table**, not as a specification. The
only genuinely settled items are the ones D forces, and those are in Addendum
A's first table.
