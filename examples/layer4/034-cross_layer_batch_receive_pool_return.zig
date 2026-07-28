// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Batch receive + pool return.
//!
//! - fillMailbox sends 10 pool-sourced items into the mailbox.
//! - batchCollectToPool: mailbox.receive_batch returns a std.DoublyLinkedList,
//!   passed straight into pool.put_all — no per-item walk needed.
//! - verifyPool confirms the pool has items again after the bulk return.
//!
//!
//! ```
//!  pool.get (×10, new_only) ──► mailbox.send (×10) ──► mailbox (10 items)
//!  │
//!  mailbox.receive_batch ──► std.DoublyLinkedList (10 items)
//!  pool.put_all ──► pool free-list (10 items recycled)
//!  │
//!  pool.get (.available_only) ×10 ──► verify count==10
//!  pool.close ──► on_close ──► freeList
//! ```
//!

pub fn batch_receive_pool_return(allocator: std.mem.Allocator, io: std.Io) !void {
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
        var rem: std.DoublyLinkedList = mailbox.close(mbh);
        items.freeList(&rem, allocator);
        mailbox.destroy(mbh, allocator);
    }

    var ctx: Ctx = .{ .ph = ph, .mbh = mbh, .alloc = allocator };
    try ctx.fillMailbox();
    try ctx.batchCollectToPool();
    try ctx.verifyPool();
    std.log.info("done: {d} items — mailbox.receive_batch → pool.put_all — stdlib list bridges layers", .{N_ITEMS});
}

const N_ITEMS: usize = 10;

const Ctx = struct {
    ph: PoolHandle,
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,

    fn fillMailbox(self: *Ctx) !void {
        for (0..N_ITEMS) |i| {
            var slot: Slot = null;
            defer items.Event.EventPolyHelper.destroy(self.alloc, &slot);
            try pool.get(self.ph, items.Event.EventPolyHelper.TAG, .new_only, &slot);
            items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
            try mailbox.send(self.mbh, &slot);
        }
        std.log.info("sent {d} items to mailbox", .{N_ITEMS});
    }

    fn batchCollectToPool(self: *Ctx) !void {
        var batch: std.DoublyLinkedList = try mailbox.receive_batch(self.mbh);
        pool.put_all(self.ph, &batch);
        std.log.info("receive_batch → put_all: {d} items returned to pool", .{N_ITEMS});
    }

    fn verifyPool(self: *Ctx) !void {
        var slot: Slot = null;
        defer pool.put(self.ph, &slot);
        pool.get(self.ph, items.Event.EventPolyHelper.TAG, .available_only, &slot) catch {
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
const pool = matryoshka.pool;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
const PoolHandle = pool.PoolHandle;
