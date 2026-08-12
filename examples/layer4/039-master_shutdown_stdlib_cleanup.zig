// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Master shutdown: close → stdlib walk → free.
//!
//! - Seed both mailbox and pool with 2 items each.
//! - closeMailbox: mbx.close, walk the returned list with popFirst, free each item.
//! - closePool: pl.close, on_close frees the pool items.
//! - Entire cleanup is standard Zig stdlib — no Matryoshka-specific cleanup API.
//!
//!
//! ```
//!  pool (2 items)    mailbox (2 items)
//!  │
//!  mbx.close ──► ItemList ──► popFirst ──► freeItem (×2)
//!  pl.close   ──► on_close ──► freeList (×2)
//!  │
//!  Entire shutdown: standard Zig stdlib — no Matryoshka-specific cleanup API.
//! ```
//!

pub fn master_shutdown_close_stdlib_walk_free(allocator: std.mem.Allocator, io: std.Io) !void {
    const pl: *Pool = try pool.new(io, allocator);
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};
    try pl.init(pool_ctx.poolHooks(&tags));

    const mbx: *Mbox = try mailbox.new(io, allocator);

    try seedMailbox(mbx, allocator, N_ITEMS);
    try seedPool(pl, N_ITEMS);

    std.log.info("master: shutdown initiated — {d} in mailbox, {d} in pool", .{ N_ITEMS, N_ITEMS });

    const mbx_freed = closeMailbox(mbx, allocator);
    std.log.info("Mbox.close: freed {d} items via stdlib popFirst", .{mbx_freed});

    closePool(pl, allocator);
    std.log.info("Pool.close: on_close freed {d} pool items", .{N_ITEMS});

    try helpers.expect(error.MasterShutdownFailed, mbx_freed == N_ITEMS, "mailbox freed count mismatch");
    std.log.info("done: master shutdown — stdlib walk, no Matryoshka-specific cleanup API", .{});
}

const N_ITEMS: usize = 2;

fn seedMailbox(mbx: *Mbox, alloc: std.mem.Allocator, count: usize) !void {
    for (0..count) |i| {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(alloc, &slot);
        try items.Event.EventPolyHelper.create(alloc, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
        try mbx.send(&slot);
    }
}

fn seedPool(pl: *Pool, count: usize) !void {
    for (0..count) |i| {
        var slot: Slot = null;
        try pl.get(items.Event.EventPolyHelper.TAG, .new_only, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(100 + i);
        pl.put(&slot);
    }
}

fn closeMailbox(mbx: *Mbox, alloc: std.mem.Allocator) usize {
    var mbx_list: polynode.ItemList = mbx.close();
    var freed: usize = 0;
    while (mbx_list.popFirst()) |poly| {
        items.freeItem(poly, alloc);
        freed += 1;
    }
    mailbox.destroy(mbx, alloc);
    return freed;
}

fn closePool(pl: *Pool, alloc: std.mem.Allocator) void {
    pl.close();
    pool.destroy(pl, alloc);
}

const items = @import("../items/items.zig");
const hooks = @import("../hooks/hooks.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const Mbox = matryoshka.Mbox;
const pool = matryoshka.pool;
const Pool = matryoshka.Pool;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
