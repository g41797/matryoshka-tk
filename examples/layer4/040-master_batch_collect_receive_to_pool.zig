// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Master batch collect: receive_batch → put_all.
//!
//! - Fill the mailbox with 5 items.
//! - batchCollectToPool: mailbox.receive_batch returns an ItemList,
//!   passed directly to pool.put_all — no per-item conversion.
//! - verifyPool confirms the pool has items after the transfer.
//!
//!
//! ```
//!  mailbox (5 items)
//!  │
//!  mailbox.receive_batch ──► ItemList
//!  pool.put_all ──► pool free-list (5 items recycled)
//!  │
//!  ItemList flows from mailbox to pool without conversion.
//!  pool.close ──► on_close ──► freeList
//! ```
//!

pub fn master_batch_collect_receive_batch_put_all(allocator: std.mem.Allocator, io: std.Io) !void {
    const ph: PoolHandle = try pool.new(io, allocator);
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};
    try pool.init(ph, pool_ctx.poolHooks(&tags));
    defer {
        pool.close(ph);
        pool.destroy(ph, allocator);
    }

    const mbh: MailboxHandle = try mailbox.new(io, allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh);
        items.freeList(&rem, allocator);
        mailbox.destroy(mbh, allocator);
    }

    try fillMailbox(mbh, allocator, N_ITEMS);
    std.log.info("mailbox: {d} items queued", .{N_ITEMS});

    try batchCollectToPool(ph, mbh);
    try verifyPool(ph);

    std.log.info("done: {d} items — mailbox.receive_batch → pool.put_all, no conversion needed", .{N_ITEMS});
}

const N_ITEMS: usize = 5;

fn fillMailbox(mbh: MailboxHandle, alloc: std.mem.Allocator, count: usize) !void {
    for (0..count) |i| {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(alloc, &slot);
        try items.Event.EventPolyHelper.create(alloc, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
        try mailbox.send(mbh, &slot);
    }
}

fn batchCollectToPool(ph: PoolHandle, mbh: MailboxHandle) !void {
    var batch: polynode.ItemList = try mailbox.receive_batch(mbh);
    pool.put_all(ph, &batch);
    std.log.info("receive_batch → put_all: stdlib list bridges mailbox to pool", .{});
}

fn verifyPool(ph: PoolHandle) !void {
    var slot: Slot = null;
    defer pool.put(ph, &slot);
    pool.get(ph, items.Event.EventPolyHelper.TAG, .available_only, &slot) catch {
        return error.MasterBatchCollectFailed;
    };
    std.log.info("verified: pool has items after put_all", .{});
}

const items = @import("../items/items.zig");
const hooks = @import("../hooks/hooks.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const pool = matryoshka.pool;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
const PoolHandle = pool.PoolHandle;
