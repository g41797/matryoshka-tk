# Compile surface for the `core` build step

## Description

Compile surface for the `core` build step.

Matryoshka itself, plus the example code that calls Mbox/Pool directly:  
items, hooks, helpers.

The four `layer*/` trees are deliberately absent — this is the fast  
inner-loop check, not the full example build. Use `examples.zig` for that.

## Source

```zig
pub const matryoshka = @import("matryoshka");
pub const items = @import("items/items.zig");
pub const hooks = @import("hooks/hooks.zig");
pub const helpers = @import("helpers/helpers.zig");

// Zig analyzes lazily — an unreferenced declaration is never checked, and the
// step passes while holding stale calls. This forces every public declaration
// above, and everything they reach, through the compiler.
//
// std.testing.refAllDecls is one level deep, and 0.16 has no recursive
// variant, so the walk is written here.
fn refAll(comptime T: type) void {
    inline for (comptime std.meta.declarations(T)) |decl| {
        if (@TypeOf(@field(T, decl.name)) == type) {
            const inner = @field(T, decl.name);
            switch (@typeInfo(inner)) {
                .@"struct", .@"enum", .@"union", .@"opaque" => refAll(inner),
                else => {},
            }
        } else {
            _ = &@field(T, decl.name);
        }
    }
}

test {
    refAll(@This());
}

const std = @import("std");
```
