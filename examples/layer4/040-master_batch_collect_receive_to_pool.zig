// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Master batch collect: receive_batch → put_all.
//!
//! - Fill the mailbox with 5 items.
//! - batchCollectToPool: mbx.receive_batch returns an ItemList,
//!   passed directly to pl.put_all — no per-item conversion.
//! - verifyPool confirms the pool has items after the transfer.
//!
//!
//! ```
//!  mailbox (5 items)
//!  │
//!  mbx.receive_batch ──► ItemList
//!  pl.put_all ──► pool free-list (5 items recycled)
//!  │
//!  ItemList flows from mailbox to pool without conversion.
//!  pl.close ──► on_close ──► freeList
//! ```
//!

pub fn master_batch_collect_receive_batch_put_all(allocator: std.mem.Allocator, io: std.Io) !void {
    const pl: *Pool = try pool.new(io, allocator);
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};
    try pl.init(pool_ctx.poolHooks(&tags));
    defer {
        pl.close();
        pool.destroy(pl, allocator);
    }

    const mbx: *Mbox = try mailbox.new(io, allocator);
    defer {
        var rem: polynode.ItemList = mbx.close();
        items.freeList(&rem, allocator);
        mailbox.destroy(mbx, allocator);
    }

    try fillMailbox(mbx, allocator, N_ITEMS);
    std.log.info("mailbox: {d} items queued", .{N_ITEMS});

    try batchCollectToPool(pl, mbx, allocator);
    try verifyPool(pl);

    std.log.info("done: {d} items — Mbox.receive_batch → Pool.put_all, no conversion needed", .{N_ITEMS});
}

const N_ITEMS: usize = 5;

fn fillMailbox(mbx: *Mbox, alloc: std.mem.Allocator, count: usize) !void {
    for (0..count) |i| {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(alloc, &slot);
        try items.Event.EventPolyHelper.create(alloc, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
        try mbx.send(&slot);
    }
}

fn batchCollectToPool(pl: *Pool, mbx: *Mbox, alloc: std.mem.Allocator) !void {
    var batch: polynode.ItemList = try mbx.receive_batch();
    pl.put_all(&batch);
    // put_all stops at the first refusal and leaves the rest in the list.
    // A closed pool means those items are still ours to free.
    items.freeList(&batch, alloc);
    std.log.info("receive_batch → put_all: stdlib list bridges mailbox to pool", .{});
}

fn verifyPool(pl: *Pool) !void {
    var slot: Slot = null;
    defer pl.put(&slot);
    pl.get(items.Event.EventPolyHelper.TAG, .available_only, &slot) catch {
        return error.MasterBatchCollectFailed;
    };
    std.log.info("verified: pool has items after put_all", .{});
}

const items = @import("../items/items.zig");
const hooks = @import("../hooks/hooks.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const Mbox = matryoshka.Mbox;
const pool = matryoshka.pool;
const Pool = matryoshka.Pool;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
