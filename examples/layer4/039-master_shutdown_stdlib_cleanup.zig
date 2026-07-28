// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Master shutdown: close → stdlib walk → free.
//!
//! - Seed both mailbox and pool with 2 items each.
//! - closeMailbox: mailbox.close, walk the returned list with popFirst, free each item.
//! - closePool: pool.close, on_close frees the pool items.
//! - Entire cleanup is standard Zig stdlib — no Matryoshka-specific cleanup API.
//!
//!
//! ```
//!  pool (2 items)    mailbox (2 items)
//!  │
//!  mailbox.close ──► std.DoublyLinkedList ──► popFirst ──► freeItem (×2)
//!  pool.close   ──► on_close ──► freeList (×2)
//!  │
//!  Entire shutdown: standard Zig stdlib — no Matryoshka-specific cleanup API.
//! ```
//!

pub fn master_shutdown_close_stdlib_walk_free(allocator: std.mem.Allocator, io: std.Io) !void {
    const ph: PoolHandle = try pool.new(io, allocator);
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};
    try pool.init(ph, pool_ctx.poolHooks(&tags));

    const mbh: MailboxHandle = try mailbox.new(io, allocator);

    try seedMailbox(mbh, allocator, N_ITEMS);
    try seedPool(ph, N_ITEMS);

    std.log.info("master: shutdown initiated — {d} in mailbox, {d} in pool", .{ N_ITEMS, N_ITEMS });

    const mbx_freed = closeMailbox(mbh, allocator);
    std.log.info("mailbox.close: freed {d} items via stdlib popFirst", .{mbx_freed});

    closePool(ph, allocator);
    std.log.info("pool.close: on_close freed {d} pool items", .{N_ITEMS});

    try helpers.expect(error.MasterShutdownFailed, mbx_freed == N_ITEMS, "mailbox freed count mismatch");
    std.log.info("done: master shutdown — stdlib walk, no Matryoshka-specific cleanup API", .{});
}

const N_ITEMS: usize = 2;

fn seedMailbox(mbh: MailboxHandle, alloc: std.mem.Allocator, count: usize) !void {
    for (0..count) |i| {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(alloc, &slot);
        try items.Event.EventPolyHelper.create(alloc, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
        try mailbox.send(mbh, &slot);
    }
}

fn seedPool(ph: PoolHandle, count: usize) !void {
    for (0..count) |i| {
        var slot: Slot = null;
        try pool.get(ph, items.Event.EventPolyHelper.TAG, .new_only, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(100 + i);
        pool.put(ph, &slot);
    }
}

fn closeMailbox(mbh: MailboxHandle, alloc: std.mem.Allocator) usize {
    var mbx_list: std.DoublyLinkedList = mailbox.close(mbh);
    var freed: usize = 0;
    while (mbx_list.popFirst()) |node| {
        const poly: *polynode.PolyNode = @fieldParentPtr("node", node);
        polynode.reset(poly);
        items.freeItem(poly, alloc);
        freed += 1;
    }
    mailbox.destroy(mbh, alloc);
    return freed;
}

fn closePool(ph: PoolHandle, alloc: std.mem.Allocator) void {
    pool.close(ph);
    pool.destroy(ph, alloc);
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
