// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! get_wait_future awaited directly.
//!
//! - Seed the pool with one Event.
//! - pool.get_wait_future returns an Io.Future(PoolResult), no Select needed.
//! - fut.await blocks until the item is available.
//! - on_put already reset it to defaults when it was seeded — no fixed
//!   value survives a put/get pass, regardless of what was set before put.
//!
//!
//! ```
//!  pool.get ──► slot ──► pool.put ──► on_put resets data ──► pool
//!  │
//!  get_wait_future ──► Future(PoolResult)
//!  fut.await ──► PoolResult .item ──► slot (default data, master owns)
//!  │
//!  pool.put ──► pool ──pool.close──► on_close ──► freeList
//! ```
//!

pub fn get_wait_future_awaited_directly(allocator: std.mem.Allocator, io: std.Io) !void {
    const ph: PoolHandle = try pool.new(io, allocator);
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};
    try pool.init(ph, pool_ctx.poolHooks(&tags));
    defer {
        pool.close(ph);
        pool.destroy(ph, allocator);
    }

    try seedPool(ph);
    try receiveViaFuture(ph, io);
}

fn seedPool(ph: PoolHandle) !void {
    var slot: Slot = null;
    try pool.get(ph, items.Event.EventPolyHelper.TAG, .new_only, &slot);
    items.Event.EventPolyHelper.mustFromSlot(&slot).code = 7;
    pool.put(ph, &slot); // on_put resets code back to 0 — set value doesn't survive
}

fn receiveViaFuture(ph: PoolHandle, io: std.Io) !void {
    var fut: std.Io.Future(pool.PoolResult) = try pool.get_wait_future(ph, items.Event.EventPolyHelper.TAG, null);
    const result: pool.PoolResult = fut.await(io);

    switch (result) {
        .item => |handle| {
            var slot: Slot = handle;
            defer pool.put(ph, &slot);
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
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
const PoolHandle = pool.PoolHandle;
