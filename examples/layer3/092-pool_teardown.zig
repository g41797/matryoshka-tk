// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Pool teardown.
//!
//! - Seed the pool with 4 Events via new_only.get() + pl.put.
//! - Close the pool.
//! - on_close receives all pooled items via *ItemList, frees them.
//!
//!
//! ```
//!  pl.get (new_only) × 4 ──► pl.put × 4
//!  (pool holds 4 items)
//!       │ pl.close
//!       ▼
//!  on_close ──► AlwaysCreateHooks: destroys all 4 items
//! ```
//!

pub fn pool_teardown(allocator: std.mem.Allocator, io: std.Io) !void {
    var ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};

    var pl_slot: Slot = null;
    try pool.new(io, allocator, ctx.poolHooks(&tags), &pl_slot);
    const pl: *Pool = Pool.moveFromSlot(&pl_slot).?;
    defer pool.destroy(pl, allocator);

    const n: usize = 4;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        var slot: Slot = null;
        defer pl.put(&slot);
        try pl.get(items.Event.EventPolyHelper.TAG, .new_only, &slot);
    }
    std.log.info("pool holds {d} Events before teardown", .{n});

    // Close: on_close receives all pooled items and frees them via AlwaysCreateHooks.
    pl.close();
    std.log.info("pool closed: on_close freed all {d} items", .{n});
}

const items = @import("../items/items.zig");
const hooks = @import("../hooks/hooks.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const pool = matryoshka.pool;
const Pool = matryoshka.Pool;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
