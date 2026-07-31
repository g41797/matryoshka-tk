//! Repro — switch on a runtime pointer value.
//!
//! Full write-up: design/llvm-pointer-switch-bug-001.md
//!
//! What it tests.
//!
//! `byTag` takes the tag as a parameter, so the switch survives to codegen.
//! Pass a `const` instead and the compiler folds the branch away — the switch
//! never reaches the backend and the test proves nothing. That mistake is why
//! several early results looked green.
//!
//! Expected output on success: `1`
//!
//! How to run everything at once.
//!
//! ```
//! bash kitchen/tools/build_repro_matrix.sh > zig-out/repro_matrix.log 2>&1
//! ```
//!
//! 2 backends x 4 optimize levels x 4 targets, then the same grid for the
//! `==` chain workaround. The script prints `zig version` first, so the log
//! records which toolchain ran. It calls plain `zig` — put the version under
//! test first on PATH.
//!
//! Narrow it with environment variables, space separated:
//!
//! ```
//! TARGETS=x86_64-windows bash kitchen/tools/build_repro_matrix.sh
//! TARGETS=native LEVELS=Debug bash kitchen/tools/build_repro_matrix.sh
//! ```
//!
//! `TIMEOUT` defaults to 60 seconds per build. Some combinations hang the
//! compiler.
//!
//! How to run one case by hand.
//!
//! ```
//! zig build-exe design/llvm-pointer-switch-repro.zig -fllvm    -ODebug && ./llvm-pointer-switch-repro
//! zig build-exe design/llvm-pointer-switch-repro.zig -fno-llvm -ODebug && ./llvm-pointer-switch-repro
//! ```
//!
//! `-fllvm` means use LLVM. `-fno-llvm` means use the self-hosted backend.
//! Passing neither takes the default, which differs per version and target —
//! so always pass one, or the result is not comparable.
//!
//! To see the generated IR:
//!
//! ```
//! zig build-exe design/llvm-pointer-switch-repro.zig -fllvm --verbose-llvm-ir > ir.txt 2>&1
//! grep -n -A6 "define.*byTag" ir.txt
//! ```
//!
//! What was measured on zig 0.16.0, x86_64-linux.
//!
//! - `-fllvm` — 16 of 16 builds fail. Every target, every optimize level:
//!   `error: Invalid record (Producer: 'zig 0.16.0' Reader: 'LLVM 21.1.0')`
//! - `-fno-llvm` x86_64-linux — the compiler segfaults at Debug every time,
//!   at ReleaseSafe on two runs of three. ReleaseFast and ReleaseSmall pass.
//! - `-fno-llvm` aarch64-macos — the compiler hangs.
//! - `-fno-llvm` x86_64-macos and x86_64-windows — all four levels build.
//! - The `==` chain doing the same dispatch passes 24 of 24 builds.
//!
//! What is worth knowing from another version.
//!
//! Which cells pass. ReleaseFast and ReleaseSmall on the self-hosted backend
//! are the two that pass on 0.16.0, and the Zig playground may well build with
//! one of them — which would explain why the playground reported 0.15.2 and
//! 0.16.0 as fine while 0.16.0 fails here at Debug. Running the full matrix
//! settles it. The whole log is the useful artifact, passes included.
//!

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
