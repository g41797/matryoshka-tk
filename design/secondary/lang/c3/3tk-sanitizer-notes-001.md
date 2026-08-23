# 3tk — the sanitizer notes (001)

Stage 3TK-9 of [3tk-staging-plan-005.md](backup/3tk-staging-plan-005.md), 2026-08-23.

What the sanitizers said about the port, what it cost to ask them, and what a
later port should copy. Same shape as `3tk-toolkit-notes-001.md` and
`3tk-containers-notes-001.md`: findings, numbered, with the command that
produced each one.

**The headline.** The port is clean under ThreadSanitizer and AddressSanitizer.
The first run was not — four data races — and **all four were in the toolkit's
own test hooks, none in `src/`**. The sanitizer's first act was to catch the
tests breaking the contract the port documents.

---

## S1 — c3c has sanitizers, and the machine did not

`c3c` 0.8.3 accepts `--sanitize=address|memory|thread` and passes the flag to
the system linker. Plan 003 asked for "whatever sanitizer the toolchain offers"
and nobody had checked; this is the answer, three stages late.

The first attempt failed at link:

```
$ c3c test --safe=yes -O0 --sanitize=thread
/usr/bin/ld.bfd: cannot find /usr/lib64/libtsan.so.2.0.0
```

**That is not a c3c defect**, and the two-line check that proves it is worth
more than the assumption it replaces:

```
$ echo 'int main(){return 0;}' > /tmp/t.c && cc -fsanitize=thread -o /tmp/t /tmp/t.c
/usr/bin/ld.bfd: cannot find /usr/lib64/libtsan.so.2.0.0
```

Fedora ships the sanitizer runtimes in packages that are not installed here.
The tool was fine; the machine was missing a library.

## S2 — clang is the way in, and it needs no root

`c3c --cc <path>` sets the compiler used as the system linker. clang carries its
own sanitizer runtimes:

```
$ c3c test --safe=yes -O0 --sanitize=thread --cc clang
```

links and runs. **No install, no root, no change to the machine** — which
matters because a stage that requires the owner to install packages is a stage
that does not run on a fresh checkout.

`valgrind` is present as well and was not needed. Recorded so the next stage
does not re-derive the option.

## S3 — the first run found four data races, all in the tests

```
ThreadSanitizer: reported 4 warnings
```

Every one in `TestHooks`:

```
t_pool.c3:37   self.gets++
t_pool.c3:38   self.last_get_count = in_pool
t_pool.c3:45   self.puts++
t_pool.c3:46   self.last_put_count = in_pool
```

driven by `t_concurrency.c3`'s three producers and three consumers on one pool.

**The frames that appear in `src/` are the hook call sites** — `pool.c3:284` and
`pool.c3:396` — where the pool has *already unlocked*. That is Part 12.3 being
obeyed, not broken. The port put itself in the stack trace by doing the right
thing.

**The contract the tests broke is the port's own**, written into `PoolHooks`'s
doc comment as a contract rather than a warning:

> hooks run OUTSIDE the pool's mutex, several at once on different threads. **A
> hook that touches shared state protects it itself.**

`TestHooks` did not. It had been racing since 3TK-7, and every build was green
in four modes the whole time, because **a data race is precisely the defect a
passing test suite cannot see.** That is the argument for this stage, and it
made it by itself on the first run.

## S4 — the fix belongs in the hook, and the wrong fix was available

The counters became `Atomic{usz}` — the same mechanism the port uses for its own
`_closed_fast` — with `.add()` and `.store()` in the hooks and `.load()` at the
assertions.

**The wrong fix was one line and would have passed:** hold the pool's mutex
across the hook call. Every warning disappears, and Part 12.3 is destroyed —
application code would run under a toolkit lock, which is the deadlock the whole
rule exists to prevent. A sanitizer says *there is a race*; it does not say
*which side is wrong*. That judgement is not the tool's.

Reads stay plain. Every assertion runs after `join`, which orders them.

## S5 — after the fix, clean everywhere it was asked

```
thread  safe -O0    0 warnings, 77 tests passed
thread  fast -O3    0 warnings, 77 tests passed
address safe -O0    clean, 77 tests passed
```

The fast build matters: `--safe=no -O3` is where the port's asserts are gone and
the optimizer is most aggressive, and it is the mode a race would most likely
survive into.

## S6 — `c3c test` already tracks leaks, and no document said so

`c3c --help` carries `--test-noleak: Disable tracking allocator and memory leak
detection for tests.` **Leak detection is on by default in `c3c test`**, and
nothing in this folder recorded it across nine stages.

It does not diminish 3TK-8's `t_alloc.c3`: the tracking allocator sees leaks on
paths the tests actually take, and 3TK-8's leak lived on an allocation-failure
path that nothing could reach until a failing allocator existed. The two find
different things. But a port reading these notes should know the default is
there before building its own.

## S7 — the harness question, and why it is a second script

`run-sanitizers.sh`, not a row in `run-builds.sh`.

`run-builds.sh` requires `c3c` and nothing else, and that is the property worth
protecting: it is what a cold session runs and what any other machine runs. The
sanitizers need a C compiler shipping their runtimes, which on this machine is
clang and on another may be neither. A hard dependency on clang does not belong
in the gate.

The new script **skips loudly and exits 2** when its compiler is absent —
`"This is a skip and not a pass: nothing was verified"` — because a silent skip
that exits 0 is how a verification step dies without anyone noticing. It also
separates *did not build* from *found something*, which is 3TK-8's harness
lesson applied before it cost anything a second time.

## What is still not covered

- **`memory`** — the third sanitizer c3c offers. Not run. MemorySanitizer needs
  the whole dependency stack instrumented to avoid false positives, and the C3
  standard library here is not.
- **`a_leaver_hands_the_signal_on` is still a race test run 20 times.** It has
  now run 20 times under ThreadSanitizer, which is a great deal stronger than 20
  times without. Still evidence, not proof.
- **Cross-target builds.** Untouched by this stage, still on the candidate list.
