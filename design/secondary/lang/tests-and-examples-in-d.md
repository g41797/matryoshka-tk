# Tests and examples in D

The D analog of Matryoshka's three-root verification model.

---

# Part 1 — Confirming the model

Before mapping it, here is the model as I understand it. If any of this is wrong
the rest of the document is wrong with it.

## Two kinds of executable verification, not one

```text
tests       prove the implementation is correct
examples    show what correct usage looks like
```

They are not two flavours of the same thing. They have different audiences,
different failure meanings, and — importantly — different allowed vocabularies.

A test failing means the library is broken. An example failing means either the
library is broken **or the documentation is lying**, which is a different bug
with a different fix.

## The four rules that make it work

**1. The example is the artifact. The wrapper is the harness.**

An example must not know it is being tested. That is why `std.testing` is banned
inside example code — not for tidiness, but because an example containing
`testing.expect` teaches a reader to write test code, and an example depending
on `testing.allocator` cannot be pasted into a real program.

The wrapper in `tests/` supplies the allocator and the Io and does the
verifying. The example stays a program.

**2. Checks in examples must survive the build mode users ship.**

`std.debug.assert` is removed in ReleaseFast and ReleaseSmall. An example
verified with `assert` is unverified in exactly the configuration a user
compiles. Hence `helpers.expect(error.XxxFailed, cond, "description")` — an
error return, never elided.

The per-example error name (`error.BuilderFailed`) means a failure carries the
identity of the example that produced it, so `@errorName(err)` in the wrapper is
a diagnosis rather than a shrug.

**3. Public interfaces only.**

Tests may use internal knowledge. Examples may not. An example that needs
something the public API does not expose is not a broken example — it is a
report that the public API is incomplete.

That makes the example suite an API-surface test, which is a second job it does
for free.

**4. Completeness is about the pool's semantics, not about length.**

Pool items are empty containers on acquisition. Work intent comes from outside
the pool item. So a get → put example demonstrates the pool's lifecycle and
nothing about how anyone would use it.

An example must show where work originates, what the worker does with the pool
resource and its input, and where results go. Three of the four are usually the
missing part.

## One distinction worth sharpening

"Real tests can use internal knowledge" has two readings, and they land in
different places in D:

```text
internal knowledge   the test knows the list is doubly linked, or that OOB
                     is tracked with a counter, and chooses what to probe
                     accordingly — through the public API

internal access      the test reads a private field
```

The first is free. The second is not, in D, and Part 3 is about where it has to
live.

Prefer the first. A test that reaches into a private field is a test that breaks
when you change the implementation for reasons unrelated to the behaviour it
claims to cover.

---

# Part 2 — Roots and dub wiring

```text
src/          implementation
tests/        real tests + example wrappers
examples/     runnable examples
```

Same three roots. The dub wiring is what keeps them from leaking into each
other:

```json
{
    "name": "matryoshka",
    "targetType": "sourceLibrary",
    "sourcePaths": ["src"],

    "configurations": [
        {
            "name": "library",
            "targetType": "sourceLibrary"
        },
        {
            "name": "unittest",
            "targetType": "executable",
            "sourcePaths": ["src", "tests", "examples"],
            "versions": ["MatryoshkaUnittest"],
            "dflags": ["-checkaction=context"]
        },
        {
            "name": "examples",
            "targetType": "executable",
            "sourcePaths": ["src", "examples"],
            "mainSourceFile": "examples/main.d"
        }
    ]
}
```

Three things this buys.

**`examples/` is not in the library configuration.** You work in source mode, so
anything in `sourcePaths` compiles into the consumer's binary. Examples must
not.

**`tests/` is not either.** Same reason.

**The `examples` configuration builds them standalone.** An example must be
runnable, and a configuration that runs them without the test harness is how you
prove it.

---

# Part 3 — The white-box problem

This is the one place D forces a structural change.

D's `private` is **module-scoped**. A test in `tests/mailbox_test.d` cannot see a
private member of `src/matryoshka/mailbox.d`, no matter what it imports. Zig
behaves the same way across files.

So there is a fourth location, whether or not it appears in the directory
listing:

```text
src/**/*.d       implementation
                 + white-box unittests, guarded          ← internal access
tests/           black-box real tests                    ← internal knowledge
                 + example wrappers
examples/        examples                                ← public API only
```

A white-box test lives next to the code it tests, guarded so it never reaches a
consumer:

```d
// src/matryoshka/mailbox.d

version (MatryoshkaUnittest)
unittest
{
    // may read private fields — same module
    auto mbx = makeTestMbox();
    mbx.sendSome(3);
    assert(mbx.len == 3);
    assert(mbx.oobCount == 0);
}
```

The guard matters. A consumer building their own project with `-unittest` would
otherwise compile and run your tests inside their binary. `version(unittest)`
alone does not protect you — `MatryoshkaUnittest` is set only by your own dub
configuration.

**Keep this population small.** Every white-box test is coupled to the
implementation. The rule of thumb: a test goes in `src/` only if the behaviour
it covers is genuinely unobservable from outside. Invariant violations,
internal state transitions, and the reconciliation paths qualify. Almost nothing
else does.

---

# Part 4 — Real tests in D

## What replaces `std.testing.allocator`

D has no leak-checking test allocator. You already need a `Manual` policy for
the toolkit, so build the test one alongside it:

```d
// tests/support/test_arena.d

struct TestArena
{
    private size_t outstanding;
    private size_t failAfter = size_t.max;
    private size_t served;

    void* alloc(size_t n, size_t align_) @nogc nothrow
    {
        if (served++ >= failAfter) return null;   // OOM-path testing
        outstanding++;
        return core.stdc.stdlib.malloc(n);
    }

    void dealloc(void* p, size_t n) @nogc nothrow
    {
        outstanding--;
        core.stdc.stdlib.free(p);
    }

    ~this() @nogc nothrow
    {
        assert(outstanding == 0, "test arena: items leaked");
    }
}
```

Two Zig facilities in one type: `testing.allocator`'s leak detection, and
`FailingAllocator`'s deterministic OOM. `failAfter` is what lets you cover
`Status.noMemory` paths at all — in Managed mode `new` throws
`OutOfMemoryError` and there is nothing to test.

Managed-mode leak checking is coarser: `GC.stats` before and after a loop of
many iterations. Growth means retention, usually a list still holding items.

## What replaces `std.Io`

Nothing. There is no io parameter in D. Test signatures lose it, and so do
example signatures — see Part 5.

## What replaces `testing.log_level = .debug`

`std.logger` (`std.experimental.logger` on older Phobos):

```d
sharedLog = cast(shared) new FileLogger(stderr, LogLevel.trace);
```

Test-side only. It allocates, so it is Managed-only, which is fine — this is
harness code.

## Named tests

D unittest blocks are anonymous. "One behavior at a time" is only useful if a
failure tells you which behavior.

Use `unit-threaded` in `tests/`:

```d
@("close returns every queued item")
unittest { ................ }

@("OOB precedes every regular message")
unittest { ................ }
```

It is a test-only dependency, so it never reaches a consumer and never has to
satisfy `-betterC`. It also gives you `@Serial` for the tests that must not run
concurrently — relevant for anything touching a shared pool.

## Contract violations — D can test these, Zig cannot

`assert` throws `AssertError`, which is catchable in a non-release build. So the
contract-violation category becomes directly expressible:

```d
@("send rejects an empty Slot")
unittest
{
    Slot empty;
    assertThrown!AssertError(mbx.send(empty));
}

@("put rejects a linked item")
unittest
{
    assertThrown!AssertError(pool.put(linkedSlot));
}
```

This is a genuine gain over the Zig suite. Every `assert` in the implementation
becomes a testable contract rather than a comment that fires in development.

Only in non-release builds — which is one more reason the CI matrix runs
`debug`, `release` and `release-nobounds` separately.

## Invariants

`Mbox` and `Pool` get `invariant` blocks (see the handbook). They are not tests,
but they turn every test into a checker of internal consistency, and they fire
at the method that broke the invariant rather than the one that later tripped
over it.

---

# Part 5 — Examples in D

## Checks that survive `-release`

Same problem, same shape, different mechanism. D's `assert` is removed by
`-release`, so examples cannot use it either.

```d
// examples/support/expect.d

mixin template ExampleError(string name)
{
    class Failure : ExampleFailure
    {
        this(string desc, string file = __FILE__, size_t line = __LINE__)
        {
            super(name, desc, file, line);
        }
    }

    void expect(bool condition, string desc,
                string file = __FILE__, size_t line = __LINE__)
    {
        if (!condition) throw new Failure(desc, file, line);
    }
}
```

Used as:

```d
// examples/pipeline.d
mixin ExampleError!"PipelineFailed";

................
expect(pool.outstanding == 0, "pool must be empty after close");
```

`expect` is an ordinary function. Nothing removes it in any build mode. The
per-example type gives you the identity property — a wrapper reporting
`typeid(e).name` gets `PipelineFailed`, the direct analog of `@errorName(err)`.

**In Manual mode**, exceptions are unavailable. The same `expect` name resolves
to an abort-with-diagnostic version, selected by policy. The example source does
not change; only the harness does. See Part 6.

## No testing APIs — the D ban list

```text
banned in examples/           because
--------------------------------------------------------------
std.exception.assertThrown    testing vocabulary
assert                        removed by -release
unit_threaded.*               testing vocabulary
TestArena                     a user does not have one
GC.stats assertions           harness concern
version(unittest) blocks      an example is not a test
```

Allowed: `std.logger` for diagnostics in Managed mode, `expect` from
`examples/support/`, and the public `matryoshka` package module.

## The entry point

Zig:

```zig
pub fn <snake_case>(allocator: std.mem.Allocator, io: std.Io) !void
```

D:

```d
void buildAndDrainAPipeline(ref Policy policy);
```

Three changes, each with a reason.

**`io` is gone.** There is no `std.Io`.

**`allocator` becomes `ref Policy`.** The policy is the allocator in D (see the
handbook), so passing it is passing the allocator, and it also fixes the mode.
Examples should be policy-generic where the pattern permits:

```d
void buildAndDrainAPipeline(P)(ref P policy);
```

Then the same example source is verified in both modes, and a Manual-mode reader
sees Manual-mode code.

**`!void` becomes `void` plus exceptions**, in Managed mode. `Status` is the
library's error model, not the example's — an example demonstrating library
usage checks `Status` returns from library calls, and reports its *own* check
failures through `expect`. Those are two different things and should not share a
channel.

## Naming the entry point

The Zig rule exists because Zig's autodoc cannot resolve declaration links for
quoted identifiers (`@"..."`), which breaks the generated page.

**That constraint does not exist in D.** D identifiers cannot contain spaces at
all, so there is no quoted-identifier form to avoid, and no autodoc breakage to
prevent.

So the underlying rule survives and the mechanism does not:

```text
keep    the name is derived from the example's one-line staccato description
drop    the snake_case requirement — it was a workaround, not a preference
```

`buildAndDrainAPipeline` from "Build and drain a pipeline" reads naturally to a
D programmer; `build_and_drain_a_pipeline` reads as ported Zig. Consistency
across your three ports is a real argument the other way — your call, but the
reason for the original rule is gone.

## The doc comment

`//!` becomes a module doc comment immediately before `module`:

```d
/**
 * Build and drain a pipeline.
 *
 * Work arrives from the caller's seed list, the worker enriches each item
 * from the pool, and results are published to the results mailbox.
 */
module matryoshka.examples.pipeline;
```

First sentence is the staccato description, verbatim, as before. `ddoc` and
`adrdox` both treat it as the summary.

**"No doc comment = not done" can be enforced**, if your compiler floor has
`__traits(docComment)`:

```d
// tests/examples_have_docs.d
static foreach (mod; AllExampleModules)
    static assert(__traits(docComment, mod).length > 0,
        fullyQualifiedName!mod ~ ": missing module doc comment");
```

A compile error rather than a review comment. Worth confirming against your
chosen floor version before relying on it.

## Cleanup

`errdefer` → `scope(failure)`. `defer` → `scope(exit)`.

The reasoning carries over unchanged: examples become docs, and leaky examples
teach leaky habits. The Slot idiom's release-before-acquisition shape is the
thing most worth demonstrating, since it is the pattern a reader will copy:

```d
Slot s;
scope(exit) release(s);          // registered before the item exists

if (create!Request(policy, s) != Status.ok) return;
if (mbx.send(s) != Status.ok) return;    // failure leaves the Slot ours
```

## Completeness

Unchanged, and unenforceable by any compiler. It stays a review rule:

```text
[ ] Where does work input originate?      caller seed / network / timer /
                                          the worker's accumulated state
[ ] What does the worker do with the pool resource and its input?
[ ] Where do results go after processing?
```

A get → put example fails all three. Put the checklist in the PR template.

---

# Part 6 — Test wrappers

The wrapper's whole job is to supply what the example does not carry and to
report what the example threw.

```d
// tests/examples/pipeline_test.d
module matryoshka.tests.examples.pipeline_test;

import matryoshka.examples.pipeline;

@("example: build and drain a pipeline")
unittest
{
    auto arena  = TestArena();          // asserts zero outstanding on scope exit
    auto policy = Manual(&arena);

    sharedLog = cast(shared) new FileLogger(stderr, LogLevel.trace);

    try
        buildAndDrainAPipeline(policy);
    catch (ExampleFailure e)
        assert(false, typeid(e).name ~ ": " ~ e.msg);
}
```

Four things, matching the Zig wrapper's four:

```text
supplies the allocator      TestArena + Manual policy
supplies the io             — nothing to supply
sets the log level          sharedLog
reports the error by name   typeid(e).name, the @errorName analog
```

The `TestArena` destructor asserting zero outstanding gives the wrapper leak
detection for free — the example does not know it is happening, which is the
point.

## Manual mode wrappers

For a policy-generic example, add a second wrapper that instantiates it with a
Manual policy in a betterC build, and checks the exit code:

```text
tests/betterc/pipeline_main.d      extern(C) int main()
```

The example source is identical. Only the harness differs. That is what proves
an example is honest about the mode it claims to demonstrate.

---

# Part 7 — Rule by rule

| Matryoshka (Zig) | D |
|---|---|
| `tests/`, `examples/`, `src/` | same three, plus guarded unittests in `src/` |
| tests use `std.testing.allocator` | `TestArena` — leak check in the destructor |
| tests use `FailingAllocator` | `TestArena.failAfter` |
| tests supply `std.Io` | nothing to supply |
| `testing.log_level = .debug` | `sharedLog` + `FileLogger(LogLevel.trace)` |
| `testing.expect` | `assert` in unittests, or `unit-threaded` |
| tests may use internal knowledge | same — internal *access* moves to `src/` |
| one behavior per test | `@("name") unittest` via unit-threaded |
| contract-violation tests | `assertThrown!AssertError` — new capability |
| examples: no `std.testing` | same ban list, plus `assert` and `TestArena` |
| examples: no `std.debug.assert` | no `assert` — same reason, `-release` |
| `helpers.expect(error.X, ...)` | `mixin ExampleError!"X"` + `expect` |
| own error name per example | own `Failure` subclass per example |
| `std.log` for diagnostics | `std.logger`, Managed only |
| `//!` first line = description | module doc comment before `module` |
| no doc comment = not done | `static assert(__traits(docComment, mod).length)` |
| entry point `(allocator, io) !void` | `(ref Policy)` — templated where possible |
| snake_case, never `@"..."` | constraint does not exist; keep the derivation |
| `errdefer` / `defer` | `scope(failure)` / `scope(exit)` |
| wrapper catches `@errorName(err)` | wrapper catches, reports `typeid(e).name` |
| completeness rule | unchanged, review-enforced |

---

# Part 8 — What D enforces, what stays discipline

**Enforced by the compiler:**

```text
examples cannot touch privates          module-scoped private
examples never ship                     sourcePaths, per configuration
tests never ship                        sourcePaths, per configuration
white-box tests never ship              version(MatryoshkaUnittest)
every example has a doc comment         __traits(docComment) static assert
checks survive -release                 expect is a function, not an assert
Manual-mode examples allocate nothing   @nogc inference on the instantiation
```

**Still review discipline:**

```text
one behavior per test
no throwaway code
no story flows in tests
completeness — input source, work, output destination
one pattern, one layer per example
the doc comment's first line is the staccato description
```

The first list is longer than it would be in Zig, mostly because dub
configurations and module-scoped `private` do work that a Zig build script has
to be told to do.

The second list is the same length as before, and is the one that decides
whether the examples are actually worth reading.

---

# Checklist for a new example

```text
[ ] Lives in examples/. Not in sourcePaths for the library configuration.
[ ] Module doc comment. First sentence is the staccato description.
[ ] Entry point name derived from that description.
[ ] Signature takes ref Policy. Templated on the policy where the pattern allows.
[ ] mixin ExampleError!"<Name>Failed" at the top.
[ ] Every invariant checked with expect(), never assert.
[ ] No std.testing, no unit_threaded, no TestArena, no version(unittest).
[ ] Only public matryoshka API. If something is missing, the API is incomplete.
[ ] scope(exit) / scope(failure) on every acquired resource.
[ ] Release-before-acquisition demonstrated on at least one Slot.
[ ] Shows where input comes from.
[ ] Shows what the worker does with the pool item and the input.
[ ] Shows where results go.
[ ] A wrapper in tests/ that supplies TestArena, sets the log level,
    and reports typeid(e).name on failure.
[ ] Builds and runs under the examples configuration, standalone.
```
