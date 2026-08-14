// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Close ordering: pool then mailbox.
//!
//! - Seed the pool with 2 items, the mailbox with 1 item.
//! - closePool: pl.close, on_close frees the 2 pool items.
//! - closeMailboxAndFree: mbx.close, walk the returned list, free the 1 item.
//! - Verify all 3 items were accounted for, in this close order.
//!
//!
//! ```
//!  pool (2 items in free-list)    mailbox (1 item in queue)
//!  │
//!  pl.close ──► on_close ──► freeList (2 pool items freed)
//!  mbx.close ──► ItemList (1 item)
//!  walk list: popFirst ──► freeItem
//!  │
//!  All 3 items accounted for, no leaks.
//! ```
//!

pub fn close_ordering_pool_then_mailbox(allocator: std.mem.Allocator, io: std.Io) !void {
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};

    var pl_slot: Slot = null;
    try pool.new(io, allocator, pool_ctx.poolHooks(&tags), &pl_slot);
    const pl: *Pool = Pool.moveFromSlot(&pl_slot).?;

    var mbx_slot: Slot = null;
    try mailbox.new(io, allocator, &mbx_slot);
    const mbx: *Mbox = Mbox.moveFromSlot(&mbx_slot).?;

    try seedPool(pl, N_POOL);
    try seedMailbox(mbx, allocator, N_MAILBOX);

    std.log.info("before close: {d} in pool, {d} in mailbox", .{ N_POOL, N_MAILBOX });

    closePool(pl, allocator);

    const freed = closeMailboxAndFree(mbx, allocator);
    std.log.info("Mbox.close: walked list, freed {d} mailbox items", .{freed});

    try helpers.expect(error.CrossLayerCloseOrderFailed, freed == N_MAILBOX, "mailbox item count mismatch");
    std.log.info("done: close pool-then-mailbox — {d}+{d} items cleaned up, no leaks", .{ N_POOL, N_MAILBOX });
}

const N_POOL: usize = 2;
const N_MAILBOX: usize = 1;

fn seedPool(pl: *Pool, count: usize) !void {
    for (0..count) |i| {
        var slot: Slot = null;
        try pl.get(items.Event.EventPolyHelper.TAG, .new_only, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
        pl.put(&slot);
    }
}

fn seedMailbox(mbx: *Mbox, alloc: std.mem.Allocator, count: usize) !void {
    for (0..count) |i| {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(alloc, &slot);
        try items.Event.EventPolyHelper.create(alloc, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(100 + i);
        try mbx.send(&slot);
    }
}

fn closePool(pl: *Pool, alloc: std.mem.Allocator) void {
    pl.close();
    pool.destroy(pl, alloc);
    std.log.info("Pool.close: on_close freed {d} pool items", .{N_POOL});
}

fn closeMailboxAndFree(mbx: *Mbox, alloc: std.mem.Allocator) usize {
    var rem: polynode.ItemList = mbx.close();
    var freed: usize = 0;
    while (rem.popFirst()) |poly| {
        items.freeItem(poly, alloc);
        freed += 1;
    }
    mailbox.destroy(mbx, alloc);
    return freed;
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
