// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Pool teardown.
//!
//! - Seed the pool with 4 Events via pool.get(new_only) + pool.put.
//! - Close the pool.
//! - on_close receives all pooled items via *ItemList, frees them.
//!
//!
//! ```
//!  pool.get (new_only) × 4 ──► pool.put × 4
//!  (pool holds 4 items)
//!       │ pool.close
//!       ▼
//!  on_close ──► AlwaysCreateHooks: destroys all 4 items
//! ```
//!

pub fn pool_teardown(allocator: std.mem.Allocator, io: std.Io) !void {
    var ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};

    const ph = try pool.new(io, allocator);
    defer pool.destroy(ph, allocator);
    try pool.init(ph, ctx.poolHooks(&tags));

    const n: usize = 4;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        var slot: Slot = null;
        defer pool.put(ph, &slot);
        try pool.get(ph, items.Event.EventPolyHelper.TAG, .new_only, &slot);
    }
    std.log.info("pool holds {d} Events before teardown", .{n});

    // Close: on_close receives all pooled items and frees them via AlwaysCreateHooks.
    pool.close(ph);
    std.log.info("pool closed: on_close freed all {d} items", .{n});
}

const items = @import("../items/items.zig");
const hooks = @import("../hooks/hooks.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const pool = matryoshka.pool;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
const PoolHandle = pool.PoolHandle;
