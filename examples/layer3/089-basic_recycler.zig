// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Basic recycler.
//!
//! - Create a pool with hooks for the Event tag.
//! - pool.get with available_or_new allocates a fresh item.
//! - pool.put returns it — the hook resets it to defaults on put.
//! - pool.get again recycles the same item, now holding default data.
//!
//!
//! ```
//!  pool.get (available_or_new) ──► slot (new via on_get)
//!       │ pool.put ──► on_put resets data ──► pool (recycled)
//!       │ pool.get (available_or_new) ──► slot (same item, data reset)
//!       │ EventPolyHelper.destroy ──► freed
//! ```
//!

pub fn basic_recycler(allocator: std.mem.Allocator, io: std.Io) !void {
    var ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};

    const ph = try pool.new(io, allocator);
    defer {
        pool.close(ph);
        pool.destroy(ph, allocator);
    }
    try pool.init(ph, ctx.poolHooks(&tags));

    var slot: Slot = null;
    defer pool.put(ph, &slot);

    try pool.get(ph, items.Event.EventPolyHelper.TAG, .available_or_new, &slot);
    const ev = items.Event.EventPolyHelper.fromSlot(&slot) orelse return error.WrongTag;
    ev.code = 89;
    std.log.info("got fresh Event, set code={d}", .{ev.code});

    pool.put(ph, &slot);
    std.log.info("returned Event to pool", .{});

    try pool.get(ph, items.Event.EventPolyHelper.TAG, .available_or_new, &slot);
    const ev2 = items.Event.EventPolyHelper.fromSlot(&slot) orelse return error.WrongTag;
    std.log.info("recycled Event code={d}", .{ev2.code});
    try helpers.expect(error.BasicRecyclerFailed, ev2.code == 0, "recycled item was not reset by the hook");

    items.Event.EventPolyHelper.destroy(allocator, &slot);
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
