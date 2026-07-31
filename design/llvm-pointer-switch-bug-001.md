# Zig bug — switch on a runtime pointer value

Working note. Found during DISPATCH 1, the tag-first dispatch task.

Status: open. Not reported upstream yet.

## Summary

**A `switch` on a pointer value that is not known at compile time does not  
compile.**

No generics needed. No allocator needed. 17 lines are enough.

Three symptoms, one source file:

- zig 0.16.0 with `-fllvm` — **16 of 16 builds fail**. Zig emits LLVM bitcode
  that LLVM rejects. Every target, every optimize level.
- zig 0.16.0 with `-fno-llvm` on x86_64-linux — **the compiler segfaults** at
  Debug. Not deterministic at ReleaseSafe.
- zig 0.16.0 with `-fno-llvm` on aarch64-macos — **the compiler hangs**.
- zig 0.17.0-dev on the playground, no `-fllvm` — fails, message unknown.

The `==` chain doing the same dispatch passes 24 of 24 builds.

`build.zig` sets `.use_llvm = true` at `:23`, `:58` and `:75`, so every kitchen  
script hits the first case. Switching the backend off does not help — it trades  
a clean error for a crash, a hang, or 0.17.

## Error

The whole message, one line:

```
error: Invalid record (Producer: 'zig 0.16.0' Reader: 'LLVM 21.1.0')
```

No file. No line. No source location.

`Invalid record` is LLVM's own string, from its bitcode reader. To use LLVM,  
zig serializes the program into LLVM's binary format — bitcode — and LLVM reads  
it back. *Producer* is who wrote the file, *Reader* is who read it. LLVM found  
an entry it cannot parse.

So zig wrote a malformed file and LLVM refused it. The error arrives after the  
source is gone, which is why it names nothing.

## Minimal repro

17 lines. No matryoshka, no generics, no allocator.

```zig
const std = @import("std");
var ta: u8 = 0;
var tb: u8 = 0;
const TA: *const anyopaque = &ta;
const TB: *const anyopaque = &tb;
var n: usize = 0;
pub fn byTag(tag: *const anyopaque) void {
    switch (tag) {
        TA => n += 1,
        TB => n += 2,
        else => n += 3,
    }
}
pub fn main() void {
    byTag(TA);
    std.debug.print("{}\n", .{n});
}
```

- `zig build-exe -fllvm min.zig` → `Invalid record`, no binary.
- `zig build-exe min.zig` → builds, runs, prints `1`.

`byTag` takes the tag as a **parameter**. That is the whole point — it keeps the  
switch alive to codegen. See "Why earlier results misled" below.

## Root cause, from the emitted IR

`zig build-exe -fllvm --verbose-llvm-ir bug.zig` dumps the IR before it is  
serialized. The generated switch:

```llvm
%5 = ptrtoint ptr %1 to i64
switch i64 %5, label %Default [
  i64 ptrtoint (ptr getelementptr inbounds (i8, ptr @"bug.H(bug.A)._tag", i64 0) to i64), label %Case
  i64 ptrtoint (ptr getelementptr inbounds (i8, ptr @"bug.H(bug.B)._tag", i64 0) to i64), label %Case1
], !dbg !55736
```

The condition is fine — zig converts the pointer to `i64` first, so the switch  
operand is an integer as LLVM requires.

The **case values** are the suspect. They are `ptrtoint` *constant  
expressions*, not literal constant integers. A switch case value has to be a  
plain integer constant; the address of a global is not known until link time, so  
it cannot be one. The bitcode writer emits the constexpr anyway and the reader  
rejects the record.

This is inference from the IR, not a confirmed upstream diagnosis. It is,  
however, the only thing in that instruction that is out of the ordinary, and it  
explains why the self-hosted backend is unaffected — it never writes bitcode.

## The front end contradicts itself

Write the same switch over integers instead of pointers:

```zig
switch (@intFromPtr(tag)) {
    @intFromPtr(TA) => n += 1,
    @intFromPtr(TB) => n += 2,
    else => n += 3,
}
```

Every combination — both backends, all four optimize levels — is rejected, and  
rejected correctly:

```
intptr.zig:9:9: error: unable to evaluate comptime expression
```

A switch prong must be known at compile time. A global's address is assigned at  
link time, so it never is.

That is the whole bug in one sentence. **`switch (@intFromPtr(tag))` is  
diagnosed. `switch (tag)`, which says the same thing with the same values, is  
accepted and then miscompiled.** The front end should reject both.

Two consequences:

- The pointer switch is a front-end hole, not a backend defect. The backend
  failures are downstream symptoms of IR that should never have been produced.
- No future zig fixes this in the direction we wanted. Making the compiler
  correct here means *rejecting* the pointer switch, not lowering it. The `==`  
  chain is not a workaround — it is the correct construct.

The way to get a real `switch` back is to stop identifying types by address:  
give each type a small dense integer ID that is comptime-known. That is an API  
change to `PolyTag`, not a code shape, and it is a separate task.

## Two levels of comptime-known

`TAG` is comptime-known at one level and not at another. Measured, not argued:

| operation on `TAG` | comptime? |
|--------------------|-----------|
| `TA == TB` inside a `comptime` block | **yes**, evaluates to `false` |
| `if (TA == TB)` inside `comptime { }` | **yes**, compiles |
| `@intFromPtr(TA)` at comptime | **no** — `unable to evaluate comptime expression` |
| `const TA = @intFromPtr(&ta);` at container scope | **no** — same error, at the `const` |
| `H.id()` returning `@intFromPtr(TAG)`, used as a prong | **no** — see below |

- **Symbolically** it is known. The compiler knows `TAG` means "the address of
  `H(A)._tag`", and knows that is a different global from `H(B)._tag`. It can  
  decide `TA == TB` without running anything.
- **Numerically** it is not. Nobody knows the integer until the linker places
  the global.

A `switch` needs the numeric level — prongs lower into constants to compare  
against. `==` needs only the symbolic level — it becomes one address comparison  
at run time, no constant required.

That is the hole. The front end checked the symbolic level, saw "comptime  
known", and accepted `switch (tag)`. The backend then needed the numeric level,  
did not have it, and emitted `ptrtoint` constant expressions. Ask for the  
numeric level explicitly and the front end refuses, correctly, wherever it is  
asked — as a prong, in a `comptime` block, or as a top-level `const`.

There is no spelling that gets the number. The `==` chain is not a downgrade;  
it uses the level of knowledge that exists.

`TAG` stays usable for comptime work that does not need the integer — comptime  
type checks, `@compileError` guards, dispatch on a type known at compile time.

## Comptime IDs — considered, declined for now

A `switch` becomes possible if tags stop being addresses. Verified working on  
both backends, `-fllvm` and `-fno-llvm`:

```zig
pub const ID: u64 = std.hash.Fnv1a_64.hash(@typeName(T));

switch (id) {
    AH.ID => ...,
    BH.ID => ...,
    else => ...,
}
```

Comptime-known, so it is a legal prong.

Ruled out along the way:

- **Link-time IDs** — a prong must be comptime-known. Link time is not.
- **A comptime auto-increment counter** — Zig has no mutable global comptime
  state, by design. Dense sequential IDs need a central registry listing every  
  type, which closes the type set.

What the hash costs:

- **Collisions become possible and undetectable.** Two types in independently
  compiled libraries can hash the same and nothing catches it. Address identity  
  makes collision impossible, not unlikely. That guarantee is the thing being  
  traded away.
- **`@typeName` is the fully-qualified path.** Moving or renaming a file changes
  the ID. Harmless while it stays in memory, a trap if anyone persists it.
- **Large blast radius.** `PolyNode.tag` reaches `PoolHooks.tags`, `pool.get`,
  `mailbox.is_it_you`, `pool.is_it_you`, every `Helper.TAG` comparison and every  
  hook. API-5 sized.

Declined. The switch buys a compulsory `else` and a nicer shape. It costs  
guaranteed-unique type identity, in a toolkit whose premise is that independent  
parts compose without coordination.

If it is ever revisited: hash only, as a full replacement. Keeping the address  
as identity *and* adding an ID for dispatch means two identities for one type,  
which is worse than either.

## Runtime `id()` — considered, does not help

The proposal: give `PolyHelper` an integer accessor and switch on that instead.

```zig
pub inline fn id() usize {
    return @intFromPtr(TAG);
}
```

It reads like it should work. It does not:

```
idsw.zig:8:43: error: unable to evaluate comptime expression
        pub inline fn id() usize { return @intFromPtr(TAG); }
                                          ^~~~~~~~~~~~~~~~
note: operation is runtime due to this operand
```

The note is the whole answer. **`inline fn` does not make a value  
comptime-known** — it inlines a computation that is still a run-time one. So  
`switch (@intFromPtr(tag)) { H.id() => ... }` is refused exactly as  
`@intFromPtr(TAG)` is, and for the same reason. Wrapping the builtin in a  
function changes nothing.

As a plain run-time accessor `id()` works — verified on both backends, correct  
dispatch, a distinct value per type. But `@intFromPtr(tag)` is already  
available at any call site, so it would add a name, not a capability.

If it is ever wanted for its own sake, the honest uses are small:

- a `std.AutoHashMap(usize, ...)` key, for per-type counters or a routing table
  built at run time
- shorter log lines than a formatted pointer

And two costs would come with it:

- **The value is an address.** It changes between runs. Safe inside one
  process, wrong for anything persisted or sent to another one.
- **It duplicates `isIt`.** `isIt(tag)` and `tid == H.id()` answer the same
  question. API 6 and API 11 were both about removing exactly that kind of  
  second spelling.

Not added. `isIt` stays the way to ask about a tag.

## Why earlier results misled

Three things looked like passes and were not. All three are worth knowing,  
because they will fool anyone who repeats this work.

1. **Comptime folding.** A reduced repro where `tag` is a `const` in the same
   function passes on 0.15.2, 0.16.0 and 0.17.0-dev. The IR shows why: there is  
   no switch in the output at all. Zig resolved the branch at compile time and  
   emitted `n += 1`. It never tested the lowering.
2. **Dead code.** `items.destroyByTag` was converted to a switch and the tree
   stayed green. It is never called — the `destroyByTag` hits in  
   `examples/layer1/024-builder.zig` are `Builder.destroyByTag`, a different  
   function. Zig does not codegen an unreferenced function.
3. **Isolation.** A pointer switch in a small file of its own can pass while the
   same shape fails in the full test binary — again because the small case was  
   comptime-folded.

Rule for testing this: the tag must arrive as a **runtime value**, and the  
function must actually be **called**.

## Build matrix, zig 0.16.0

`kitchen/tools/build_repro_matrix.sh` builds the repro across both backends,  
four optimize levels and four targets, then does the same for the workaround.  
Native rows are built and run, cross rows built only.

Matrix 1 — `switch` on a runtime pointer:

| target | backend | Debug | ReleaseSafe | ReleaseFast | ReleaseSmall |
|--------|---------|-------|-------------|-------------|--------------|
| x86_64-linux | `-fllvm` | fail | fail | fail | fail |
| x86_64-linux | `-fno-llvm` | **crash** | crash / pass | pass | pass |
| x86_64-macos | `-fllvm` | fail | fail | fail | fail |
| x86_64-macos | `-fno-llvm` | pass | pass | pass | pass |
| aarch64-macos | `-fllvm` | fail | fail | fail | fail |
| aarch64-macos | `-fno-llvm` | **hang** | not run | not run | not run |
| x86_64-windows | `-fllvm` | fail | fail | fail | fail |
| x86_64-windows | `-fno-llvm` | pass | pass | pass | pass |

`fail` is always the same one-line `Invalid record`.

Matrix 2 — the `==` chain, same file otherwise:

**24 builds, 24 passes.** Both backends, all four optimize levels, native plus  
x86_64-macos plus x86_64-windows. Every native row ran and printed `1`.

Three distinct symptoms on one source file:

1. **`-fllvm` — 16 of 16 fail.** Every target, every optimize level, identical
   message. Not target-specific, not optimization-specific.
2. **`-fno-llvm` on x86_64-linux — the compiler segfaults.** Signal 11, at
   Debug every time. ReleaseSafe crashed on two runs and passed on a third, so  
   the crash is not deterministic. ReleaseFast and ReleaseSmall have always  
   passed.
3. **`-fno-llvm` on aarch64-macos — the compiler hangs.** No output, no exit.
   Killed by hand three times. It survives `timeout -k 10`, so the hang is in a  
   child process that outlives the SIGKILL sent to zig itself — most likely the  
   linker. Pinning it needs process-group killing (`setsid` plus a kill on the  
   whole group). Not done. Recorded as a hang, not as a clean timeout.

Cross-compiling to macos and windows with `-fno-llvm` passes while native  
x86_64-linux crashes, same backend and same level. Noted, not chased.

## Versions

Playground runs use the default backend, not `-fllvm`.

| Zig | Where | Repro | Result |
|-----|-------|-------|--------|
| 0.16.0 | local, `-fllvm` | runtime-tag switch | fail |
| 0.16.0 | local, default backend | runtime-tag switch | pass |
| 0.15.2 | playground | comptime-folded | pass, proves nothing |
| 0.16.0 | playground | comptime-folded | pass, proves nothing |
| 0.17.0-dev.1509+bb296ab9b | playground | comptime-folded | pass, proves nothing |
| 0.17.0-dev.1509+bb296ab9b | playground | generic + allocator | fail, message unknown |
| 0.17.0-dev.1509+bb296ab9b | playground | runtime-tag switch (17 lines) | **fail**, message unknown |

The last row is the important one. The 17-line repro fails on 0.17 as well, and  
the playground does not pass `-fllvm` — no bitcode is written there and LLVM is  
never involved.

So the fault is not confined to the LLVM bitcode writer. Either both backends  
have their own version of it, or the cause sits earlier, before the backend  
split. The `ptrtoint`-constexpr reading above explains the 0.16 `-fllvm` case  
and does not explain this one.

Both 0.17 failures returned only the playground's generic "An error occurred:"  
with an empty body. That covers a compiler crash, a timeout, or output the  
playground could not parse. The real diagnostic needs a local 0.17 toolchain  
and is the single biggest gap in this note.

What it rules out: dropping `.use_llvm = true` is not a fix. It would make 0.16  
build and then fail again on 0.17.

## Workaround

The `if` chain, comparing tags with `==`, compiles everywhere. It lowers to  
`icmp` plus branches — no switch instruction, no case values, no constexpr.

```zig
if (tag == Event.EventPolyHelper.TAG) {
    ...
} else if (tag == Sensor.SensorPolyHelper.TAG) {
    ...
} else unreachable;
```

Same dispatch, same tag comparison. It loses the compulsory `else` that the  
switch form gives.

## What this means for the toolkit

The tag-first dispatch idiom cannot be written as a `switch` on zig 0.16 with  
the current build settings. Not "sometimes" — never, wherever the tag is a  
runtime value, which is every real dispatch site.

It is broken on 0.16 under `-fllvm` and on 0.17 without it. There is no  
toolchain in reach where the idiom works.

Options:

1. **Drop the switch idiom.** Document the `==` chain as the one way to dispatch
   tag-first. Nothing in the toolkit changes, the docs stay honest, and the  
   repo carries no code that any current or upcoming zig rejects.
2. Report upstream. The 17-line repro is ready. Independent of option 1.
3. ~~Drop `.use_llvm = true`~~ — ruled out. 0.17 fails without it.
4. Wait for a fix. Blocks DISPATCH 1 indefinitely.

## Search terms

- `zig "Invalid record" "Producer: 'zig"`
- `repo:ziglang/zig "Invalid record"`
- `zig switch on pointer ptrtoint constant expression bitcode`
- `llvm switch case value must be constant integer ptrtoint`
- ziglang/zig labels `backend-llvm`, `miscompilation`

## Tree state when this was written

- `kitchen/build_and_test_debug.sh` exits 0, 182/182 tests pass.
- No source file changed. `examples/items/items.zig` and
  `tests/layer1_polynode.zig` were converted during the investigation and  
  reverted. `zig fmt --check` clean.
- `src/` was never touched.
- `.zig-cache` was deleted and rebuilt during the bisection.

## Appendix — the two test scenarios that trigger it

Written, then removed from `tests/layer1_polynode.zig`. Kept here so the work is  
not lost. They need `Timer` and `TimerPolyHelper` added to that file's imports.

```zig
// --- Scenario 111: tag switch recovers every type ---
test "111 - tag switch recovers every type" {
    var ev: Event = .{ .code = 11 };
    EventPolyHelper.init(&ev);

    var sn: Sensor = .{ .value = 1.5 };
    SensorPolyHelper.init(&sn);

    var tm: Timer = .{};
    TimerPolyHelper.init(&tm);

    var list: ItemList = .{};
    list.append(EventPolyHelper.toPoly(&ev));
    list.append(SensorPolyHelper.toPoly(&sn));
    list.append(TimerPolyHelper.toPoly(&tm));

    var events: usize = 0;
    var sensors: usize = 0;
    var timers: usize = 0;
    var unknown: usize = 0;

    // The tag is read once. Inside a prong the tag is already proven,
    // so mustFromPoly cannot fail.
    while (list.popFirst()) |ih| switch (ih.*.tag) {
        EventPolyHelper.TAG => {
            try testing.expectEqual(@as(i32, 11), EventPolyHelper.mustFromPoly(ih).*.code);
            events += 1;
        },
        SensorPolyHelper.TAG => {
            try testing.expectEqual(@as(f64, 1.5), SensorPolyHelper.mustFromPoly(ih).*.value);
            sensors += 1;
        },
        TimerPolyHelper.TAG => {
            timers += 1;
        },
        else => unknown += 1,
    };

    try testing.expectEqual(@as(usize, 1), events);
    try testing.expectEqual(@as(usize, 1), sensors);
    try testing.expectEqual(@as(usize, 1), timers);
    try testing.expectEqual(@as(usize, 0), unknown);
}

// --- Scenario 112: unknown tag reaches else ---
test "112 - unknown tag reaches else" {
    var ev: Event = .{ .code = 12 };
    EventPolyHelper.init(&ev);

    var fr: Foreign = .{ .mark = 9 };
    ForeignPolyHelper.init(&fr);

    var list: ItemList = .{};
    list.append(EventPolyHelper.toPoly(&ev));
    list.append(ForeignPolyHelper.toPoly(&fr));

    var events: usize = 0;
    var unknown: usize = 0;

    // A pointer switch is never exhaustive, so else is compulsory.
    // The chain form can omit its trailing else. This one cannot.
    while (list.popFirst()) |ih| switch (ih.*.tag) {
        EventPolyHelper.TAG => {
            try testing.expectEqual(@as(i32, 12), EventPolyHelper.mustFromPoly(ih).*.code);
            events += 1;
        },
        // The item is dropped, not freed. Freeing needs the type,
        // and here there is none.
        else => unknown += 1,
    };

    try testing.expectEqual(@as(usize, 1), events);
    try testing.expectEqual(@as(usize, 1), unknown);

    // The unknown item is untouched — its holder still owns it.
    try testing.expectEqual(@as(u8, 9), fr.mark);
}

/// A type the dispatch site does not know about.
const Foreign = struct {
    poly: PolyNode = .{},
    mark: u8 = 0,
};
const ForeignPolyHelper = polynode.PolyHelper(Foreign);
```
