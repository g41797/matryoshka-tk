// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Batch receive + pool return.
//!
//! - fillMailbox sends 10 pool-sourced items into the mailbox.
//! - batchCollectToPool: mbx.receive_batch returns an ItemList,
//!   passed straight into pl.put_all — no per-item walk needed.
//! - verifyPool confirms the pool has items again after the bulk return.
//!
//!
//! ```
//!  pl.get (×10, new_only) ──► mbx.send (×10) ──► mailbox (10 items)
//!  │
//!  mbx.receive_batch ──► ItemList (10 items)
//!  pl.put_all ──► pool free-list (10 items recycled)
//!  │
//!  pl.get (.available_only) ×10 ──► verify count==10
//!  pl.close ──► on_close ──► freeList
//! ```
//!

pub fn batch_receive_pool_return(allocator: std.mem.Allocator, io: std.Io) !void {
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};

    var pl_slot: Slot = null;
    try pool.new(io, allocator, pool_ctx.poolHooks(&tags), &pl_slot);
    const pl: *Pool = Pool.moveFromSlot(&pl_slot).?;
    defer {
        pl.close();
        pool.destroy(pl, allocator);
    }

    var mbx_slot: Slot = null;
    try mailbox.new(io, allocator, &mbx_slot);
    const mbx: *Mbox = Mbox.moveFromSlot(&mbx_slot).?;
    defer {
        var rem: polynode.ItemList = mbx.close();
        items.freeList(&rem, allocator);
        mailbox.destroy(mbx, allocator);
    }

    var ctx: Ctx = .{ .pl = pl, .mbx = mbx, .alloc = allocator };
    try ctx.fillMailbox();
    try ctx.batchCollectToPool();
    try ctx.verifyPool();
    std.log.info("done: {d} items — Mbox.receive_batch → Pool.put_all — stdlib list bridges layers", .{N_ITEMS});
}

const N_ITEMS: usize = 10;

const Ctx = struct {
    pl: *Pool,
    mbx: *Mbox,
    alloc: std.mem.Allocator,

    fn fillMailbox(self: *Ctx) !void {
        for (0..N_ITEMS) |i| {
            var slot: Slot = null;
            defer items.Event.EventPolyHelper.destroy(self.alloc, &slot);
            try self.pl.get(items.Event.EventPolyHelper.TAG, .new_only, &slot);
            items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
            try self.mbx.send(&slot);
        }
        std.log.info("sent {d} items to mailbox", .{N_ITEMS});
    }

    fn batchCollectToPool(self: *Ctx) !void {
        var batch: polynode.ItemList = try self.mbx.receive_batch();
        self.pl.put_all(&batch);
        // put_all stops at the first refusal and leaves the rest in the
        // list. A closed pool means those items are still ours to free.
        items.freeList(&batch, self.alloc);
        std.log.info("receive_batch → put_all: {d} items returned to pool", .{N_ITEMS});
    }

    fn verifyPool(self: *Ctx) !void {
        var slot: Slot = null;
        defer self.pl.put(&slot);
        self.pl.get(items.Event.EventPolyHelper.TAG, .available_only, &slot) catch {
            return error.CrossLayerBatchFailed;
        };
        std.log.info("verified: pool has items after put_all", .{});
    }
};

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
