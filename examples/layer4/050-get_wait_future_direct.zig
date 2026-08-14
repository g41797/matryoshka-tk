// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! get_wait_future awaited directly.
//!
//! - Seed the pool with one Event.
//! - pl.get_wait_future returns an Io.Future(Pool.Result), no Select needed.
//! - fut.await blocks until the item is available.
//! - on_put already reset it to defaults when it was seeded — no fixed
//!   value survives a put/get pass, regardless of what was set before put.
//!
//!
//! ```
//!  pl.get ──► slot ──► pl.put ──► on_put resets data ──► pool
//!  │
//!  get_wait_future ──► Future(Pool.Result)
//!  fut.await ──► Pool.Result .item ──► slot (default data, master owns)
//!  │
//!  pl.put ──► pool ──pl.close──► on_close ──► freeList
//! ```
//!

pub fn get_wait_future_awaited_directly(allocator: std.mem.Allocator, io: std.Io) !void {
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};

    var pl_slot: Slot = null;
    try pool.new(io, allocator, pool_ctx.poolHooks(&tags), &pl_slot);
    const pl: *Pool = Pool.moveFromSlot(&pl_slot).?;
    defer {
        pl.close();
        pool.destroy(pl, allocator);
    }

    try seedPool(pl);
    try receiveViaFuture(pl, io);
}

fn seedPool(pl: *Pool) !void {
    var slot: Slot = null;
    try pl.get(items.Event.EventPolyHelper.TAG, .new_only, &slot);
    items.Event.EventPolyHelper.mustFromSlot(&slot).code = 7;
    pl.put(&slot); // on_put resets code back to 0 — set value doesn't survive
}

fn receiveViaFuture(pl: *Pool, io: std.Io) !void {
    var fut: std.Io.Future(Pool.Result) = try pl.get_wait_future(items.Event.EventPolyHelper.TAG, null);
    const result: Pool.Result = fut.await(io);

    switch (result) {
        .item => |handle| {
            var slot: Slot = handle;
            defer pl.put(&slot);
            const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
            try helpers.expect(error.GetWaitFutureDirectFailed, ev.code == 0, "expected reset default, not the pre-put value");
            std.log.info("get_wait_future direct: got Event code={d} (reset by on_put)", .{ev.code});
        },
        else => return error.GetWaitFutureDirectFailed,
    }
}

const items = @import("../items/items.zig");
const hooks = @import("../hooks/hooks.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const pool = matryoshka.pool;
const Pool = matryoshka.Pool;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
