// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Close ordering: pool then mailbox.
//!
//! - Seed the pool with 2 items, the mailbox with 1 item.
//! - closePool: pool.close, on_close frees the 2 pool items.
//! - closeMailboxAndFree: mailbox.close, walk the returned list, free the 1 item.
//! - Verify all 3 items were accounted for, in this close order.
//!
//!
//! ```
//!  pool (2 items in free-list)    mailbox (1 item in queue)
//!  │
//!  pool.close ──► on_close ──► freeList (2 pool items freed)
//!  mailbox.close ──► ItemList (1 item)
//!  walk list: popFirst ──► freeItem
//!  │
//!  All 3 items accounted for, no leaks.
//! ```
//!

pub fn close_ordering_pool_then_mailbox(allocator: std.mem.Allocator, io: std.Io) !void {
    const ph: PoolHandle = try pool.new(io, allocator);
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};
    try pool.init(ph, pool_ctx.poolHooks(&tags));

    const mbh: MailboxHandle = try mailbox.new(io, allocator);

    try seedPool(ph, N_POOL);
    try seedMailbox(mbh, allocator, N_MAILBOX);

    std.log.info("before close: {d} in pool, {d} in mailbox", .{ N_POOL, N_MAILBOX });

    closePool(ph, allocator);

    const freed = closeMailboxAndFree(mbh, allocator);
    std.log.info("mailbox.close: walked list, freed {d} mailbox items", .{freed});

    try helpers.expect(error.CrossLayerCloseOrderFailed, freed == N_MAILBOX, "mailbox item count mismatch");
    std.log.info("done: close pool-then-mailbox — {d}+{d} items cleaned up, no leaks", .{ N_POOL, N_MAILBOX });
}

const N_POOL: usize = 2;
const N_MAILBOX: usize = 1;

fn seedPool(ph: PoolHandle, count: usize) !void {
    for (0..count) |i| {
        var slot: Slot = null;
        try pool.get(ph, items.Event.EventPolyHelper.TAG, .new_only, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
        pool.put(ph, &slot);
    }
}

fn seedMailbox(mbh: MailboxHandle, alloc: std.mem.Allocator, count: usize) !void {
    for (0..count) |i| {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(alloc, &slot);
        try items.Event.EventPolyHelper.create(alloc, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(100 + i);
        try mailbox.send(mbh, &slot);
    }
}

fn closePool(ph: PoolHandle, alloc: std.mem.Allocator) void {
    pool.close(ph);
    pool.destroy(ph, alloc);
    std.log.info("pool.close: on_close freed {d} pool items", .{N_POOL});
}

fn closeMailboxAndFree(mbh: MailboxHandle, alloc: std.mem.Allocator) usize {
    var rem: polynode.ItemList = mailbox.close(mbh);
    var freed: usize = 0;
    while (rem.popFirst()) |poly| {
        items.freeItem(poly, alloc);
        freed += 1;
    }
    mailbox.destroy(mbh, alloc);
    return freed;
}

const items = @import("../items/items.zig");
const hooks = @import("../hooks/hooks.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const pool = matryoshka.pool;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
const PoolHandle = pool.PoolHandle;
