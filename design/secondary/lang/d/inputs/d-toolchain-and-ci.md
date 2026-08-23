# D toolchain, testing, and CI matrix

For a source-distributed Matryoshka with a compile-time memory policy.

---

## Part 1 — The axis you did not list

Your three axes were OS, build mode, and memory policy. The missing one is
larger than any of them.

**D has three compilers.**

| | backend | role |
|---|---|---|
| **DMD** | own | reference frontend. Fastest compiles. Weakest codegen. Newest language features first. |
| **LDC** | LLVM | best codegen. Best aarch64. Best `-betterC`. Only one with sanitizers. Cross-compiles. |
| **GDC** | GCC | in GCC mainline. Lags the frontend most. What distributions ship. |

They are not interchangeable for this project, for one specific reason:

> This design depends on **attribute inference** for templates.

That is frontend behaviour. DMD and LDC ship different frontend versions at any
given moment, and GDC ships an older one still. A `Mbox!Manual` that infers
`@nogc` on LDC and fails to on GDC is a bug you will only see if you build both.

Minimum: **DMD and LDC**. DMD because it is the reference and catches
frontend-version drift early; LDC because it is what anyone ships.

GDC is optional, and belongs in a nightly job rather than in the matrix. Add it
only if you want distribution packaging to work.

### Compiler version is a second axis

D has no LTS release. DMD ships monthly, LDC follows.

Pick a floor version, document it, and test **floor and latest**. Not the range
between them.

The floor is where `__traits`, `static if` edge cases, and attribute inference
behaviour actually differ. Everything above the floor is the same language for
your purposes.

---

## Part 2 — The rest of the toolchain

### Build tool

`dub`, with source mode:

```json
{
    "name": "matryoshka",
    "targetType": "sourceLibrary",
    "importPaths": ["source"]
}
```

`sourceLibrary` builds nothing. Your `.d` files are compiled into the consumer's
binary. Same model as Zig's `addModule`, same as an Odin collection.

For this project it is close to mandatory — most of the toolkit is templates, so
a static library would emit almost nothing anyway.

### Editors and language server

```text
serve-d          the language server. Everything else is a client of it.
code-d           VS Code extension. The mainstream D setup.
Visual D         Visual Studio integration. The best Windows debugging story.
dfmt             formatter. Configure once, commit the config.
dscanner         static analysis. serve-d runs it inline.
```

One honest note, since you use JetBrains IDEs: **D support in IntelliJ is
noticeably weaker than what you are used to.** The community D plugin is behind
and lightly maintained. For D specifically, VS Code with `code-d` and `serve-d`
is the better environment, and Visual Studio with Visual D is better still on
Windows.

That is a real downgrade from your Zig and Odin setups. Worth knowing before you
commit to the port rather than after.

### Debuggers

```text
Linux      GDB. Understands D mangling. LDC -g emits good DWARF. Best experience.
macOS      LLDB. D support is thinner. Symbols resolve; expression evaluation
           on D types is unreliable.
Windows    LDC -g emits PDB. WinDbg or Visual Studio works.
           mago-debugger (ships with Visual D) understands D types best.
```

Practical guidance: debug on Linux with LDC and GDB. Reproduce elsewhere, but do
not expect to debug a template-heavy stack trace comfortably on macOS.

For this codebase specifically, print-debugging a mailbox under contention is
usually more effective than a breakpoint anyway — a breakpoint changes the
timing you are trying to observe.

### Sanitizers — LDC only

```bash
ldc2 -g -fsanitize=address  ...
ldc2 -g -fsanitize=thread   ...
```

ThreadSanitizer is the single highest-value tool in this whole document.

You have a mutex, a condition variable, an atomic `closed` flag, a `wake_epoch`
counter, and hooks that run with the lock released. TSan finds the ordering bugs
in that shape that no test will find reliably by luck.

Run it. Not once — in CI, on every push.

### Cross-compilation

LDC only:

```bash
ldc2 -mtriple=aarch64-linux-gnu ...
```

Relevant because Manual mode's audience includes targets you do not build on.

### Docs

```text
ddoc      built in, output is dated
adrdox    much better output, single static site, no config
ddox      JSON-driven, integrates with dub
```

You already run MkDocs/Material for Tofu. Keep it, and use `adrdox` output as a
separate API reference rather than trying to make MkDocs consume ddoc.

---

## Part 3 — Testing

### unittest blocks and `dub test`

D's `unittest` is built in. No framework needed to start.

```bash
dub test
dub test --build=unittest-cov     # with coverage
```

Always add `-checkaction=context`. It turns a bare assert failure into one that
shows the compared values:

```json
"dflags": ["-checkaction=context"]
```

**Keep tests out of `sourcePaths`.** In source mode, anything in `sourcePaths`
is compiled into the consumer's binary — including your unittest blocks, if they
build with `-unittest`.

```json
"configurations": [
    { "name": "library",  "targetType": "sourceLibrary" },
    { "name": "unittest", "targetType": "executable",
      "sourcePaths": ["source", "tests"] }
]
```

### Consider unit-threaded

For a concurrency library, `unit-threaded` earns its keep: named tests,
filtering by name, parallel execution, and `@Serial` for the ones that must not
run concurrently.

It is a test-only dependency, so it never reaches a consumer and never has to
satisfy `-betterC`.

### Invariants — use them, Zig has no equivalent

D structs support `invariant`, checked at every public method boundary in
non-release builds.

`Mbox` has invariants you currently defend with scattered asserts:

```d
invariant
{
    assert(oobCount <= len);
    assert(oobLast is null || oobCount > 0);
    assert((len == 0) == list.isEmpty());
}
```

`Pool` has more: per-tag count matches per-tag list length, and every stored
item is unlinked from every other list.

This is free coverage. Every test you already have starts checking these on
every call, and the failure points at the method that broke the invariant rather
than at the method that later tripped over it.

One caveat: the invariant runs on public method entry and exit, so it must hold
at those boundaries. If a method legitimately breaks and restores an invariant
internally, that is fine — only the boundaries are checked.

### The `@nogc` verification test

The most important test in Manual mode is not a test of behaviour.

```d
@nogc nothrow unittest
{
    // Does not compile if anything reachable here allocates or throws.
    ubyte[4096] storage = void;
    auto arena  = Arena(storage[]);
    auto policy = Manual(&arena);

    Slot s;
    scope(exit) destroyItem!Request(policy, s);

    assert(create!Request(policy, s) == Status.ok);
    assert(mustFromSlot!Request(s) !is null);
}
```

There is nothing to assert. The attribute on the unittest is the assertion, and
the compiler evaluates it against the whole call graph.

Write one of these per public entry point: `send`, `send_oob`, `receive`,
`try_receive`, `receive_batch`, `close`, `get`, `get_wait`, `put`, `put_all`.

### GC stress — the Managed-mode equivalent

Manual mode gets compile-time verification. Managed mode needs a runtime job,
because the failure it guards against is invisible.

Run a background thread that collects while messages are in flight:

```d
auto collector = new Thread({
    foreach (_; 0 .. 10_000) { GC.collect(); Thread.yield(); }
});
```

Combine with a smaller heap so collections are frequent:

```bash
./tests --DRT-gcopt=heapSizeFactor=1:profile:1
```

This is the job that catches an item freed while queued. Nothing else will.

### Leak accounting, per mode

```text
Manual     your arena reports outstanding allocations at teardown.
           Assert zero at the end of every test.
Managed    GC.stats before and after. Growth across many iterations
           means something is retained, not leaked - usually a list
           still holding items.
```

Add the outstanding-item counter to `Pool` regardless of mode. Incremented on
`get`, decremented on `put`. `close` reporting `outstanding != 0` is the only
leak detector an application will ever get, and it costs one integer.

### betterC tests are separate executables

`-betterC` has no `unittest` runner and no `main` from druntime.

```d
extern(C) int main()
{
    // exercise Manual-mode paths, return non-zero on failure
    return 0;
}
```

One small program per area. They prove betterC compatibility in a way nothing
compiled with druntime can.

### Concurrency test shapes worth having

```text
MPMC saturation        N producers, M consumers, fixed message count,
                       assert every message arrives exactly once
close under contention  close() while receivers are blocked;
                       assert no item lost, every receiver returns Closed
wakeUpAll race          wakeUpAll() concurrent with send();
                       assert the epoch logic does not swallow an item
OOB ordering            interleave send and send_oob;
                       assert every OOB precedes every regular
pool churn              get/put loop across threads, hooks that
                       count calls; assert counts reconcile
put_all mid-close       close() during put_all; assert the caller's list
                       is left holding exactly the untransferred items
```

Run all of these under TSan. That is where they pay.

---

## Part 4 — The CI matrix

### The full axis list

```text
1. compiler          dmd, ldc          (+ gdc nightly)
2. compiler version  floor, latest
3. OS                linux, macos, windows
4. architecture      x86_64, aarch64
5. build type        debug, release, release-nobounds
6. memory policy     managed, manual
7. betterC           off, on            (manual only)
8. libc              glibc, musl        (optional, linux only)
```

Two of these need justification.

**Build type is not two values, it is three.** `-release` removes asserts and
turns off bounds checks in `@system`/`@trusted` code. Your design is
assert-dense, and `ItemList._holds` is an O(n) walk that only runs under safety.
So `release` exercises genuinely different code from `debug`, and
`release-nobounds` differs again. All three, or you are shipping an untested
configuration.

**Architecture matters because of atomics and alignment.** x86_64 has a strong
memory model that hides missing acquire/release. aarch64 does not. A missing
barrier in the `closed` flag or `wake_epoch` passes on x86 and fails on Apple
silicon or an ARM server.

### Pruning

The full cross-product is in the hundreds. Prune by depth, not by dropping axes.

**Tier 1 — every push (6 jobs)**

| OS | compiler | build | policy |
|---|---|---|---|
| linux-x64 | ldc latest | debug | managed |
| linux-x64 | ldc latest | debug | manual |
| linux-x64 | ldc latest | release | managed |
| linux-x64 | ldc latest | release | manual |
| linux-x64 | dmd latest | debug | managed |
| linux-x64 | dmd latest | debug | manual |

Fast, and catches most compile-time and logic breakage.

**Tier 2 — every PR and every push to main (add ~12 jobs)**

| OS | compiler | build | policy | note |
|---|---|---|---|---|
| macos-arm64 | ldc latest | debug, release | managed, manual | 4 jobs — the aarch64 memory model |
| windows-x64 | ldc latest | debug, release | managed, manual | 4 jobs — the Win32 sync wrapper |
| windows-x64 | dmd latest | debug | managed | 1 job — different linker path |
| linux-x64 | ldc latest | release-nobounds | managed, manual | 2 jobs |
| linux-x64 | ldc latest | debug | manual | +betterC, 1 job |

Windows is not optional here. `Mutex` and `Cond` are a genuinely different
implementation there — `CRITICAL_SECTION` and `CONDITION_VARIABLE`, not pthreads
— and `SleepConditionVariableCS` has different spurious-wakeup behaviour.

**Dedicated jobs — every push (5 jobs)**

```text
TSan          ldc, linux, debug, both policies    the concurrency suite
ASan          ldc, linux, debug, manual           use-after-free on the item path
GC stress     ldc, linux, debug, managed          collect-while-in-flight
coverage      dmd, linux, unittest-cov            report to codecov
@nogc audit   ldc, linux, manual                  the attribute unittests
```

**Nightly**

```text
compiler floor versions, all OSes
gdc latest
linux-aarch64
alpine / musl
betterC on macos and windows
```

### GitHub Actions shape

```yaml
- uses: dlang-community/setup-dlang@v1
  with:
    compiler: ${{ matrix.compiler }}    # ldc-latest, dmd-latest, ldc-1.xx
```

That action handles all three compilers and pinned versions on all three OSes.
It is the only D-specific CI setup you need.

Mode selection, given import-based policy selection:

```yaml
- run: dub test --config=unittest-${{ matrix.policy }} --build=${{ matrix.build }}
```

Two test configurations, each importing `matryoshka.manual` or
`matryoshka.managed`. No version identifiers, no build flags, and both modes
compile in every job.

---

## Part 5 — What to add first

If you build this incrementally, this order gives the most per hour spent:

```text
1. dub test on linux + ldc, both policies, debug           the floor
2. the @nogc verification unittests                        Manual mode's proof
3. TSan on the concurrency suite                           finds real bugs today
4. release and release-nobounds                            catches assert-dependence
5. windows + macos-arm64                                   the sync wrapper, the memory model
6. GC stress in Managed mode                               the invisible failure
7. dmd alongside ldc                                       frontend drift
8. betterC                                                 only if it is a supported target
9. struct invariants                                       cheap, retroactive coverage
10. coverage reporting                                     last, it measures rather than finds
```

Steps 2 and 3 are the two that find things nothing else finds. Everything else
is breadth.

---

## Checklist

```text
[ ] Two compilers in the matrix, not one.
[ ] Floor and latest compiler versions pinned and documented.
[ ] Three build types: debug, release, release-nobounds.
[ ] Both memory policies in every tier.
[ ] aarch64 present, for the memory model.
[ ] Windows present, for the sync wrapper.
[ ] TSan on every push.
[ ] A @nogc unittest per public entry point.
[ ] A GC-stress job in Managed mode.
[ ] Tests outside sourcePaths.
[ ] -checkaction=context in dflags.
[ ] Struct invariants on Mbox and Pool.
```
