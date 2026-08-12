// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Batch processing.
//!
//! - Main sends 10 Events, then a ShutdownCommand sentinel.
//! - Worker blocks on the first item via mbx.receive.
//! - Worker then empties the rest with mbx.receive_batch.
//! - Sentinel found in either place ends the worker.
//!
//!
//! ```
//!  main ──Event×10 + ShutdownCommand──► mailbox
//!       │
//!  worker: receive (first item) ──► freeSlot
//!          receive_batch (rest) ──► walk + freeItem
//!          (ShutdownCommand in batch → exit)
//! ```
//!

pub fn batch_processing(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbx: *Mbox = try mailbox.new(io, allocator);
    defer {
        var rem: polynode.ItemList = mbx.close();
        items.freeList(&rem, allocator);
        mailbox.destroy(mbx, allocator);
    }

    var ctx: WorkerCtx = .{ .mbx = mbx, .alloc = allocator };
    var fut = try io.concurrent(batchWorkerFn, .{&ctx});

    const n: usize = 10;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(allocator, &slot);
        try items.Event.EventPolyHelper.create(allocator, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i);
        try mbx.send(&slot);
    }

    // Signal worker to stop — all n items are already queued before this.
    {
        var slot: Slot = null;
        defer items.ShutdownCommand.ShutdownCommandPolyHelper.destroy(allocator, &slot);
        try items.ShutdownCommand.ShutdownCommandPolyHelper.create(allocator, &slot);
        try mbx.send(&slot);
    }

    fut.await(io);

    const total = ctx.first_count + ctx.batch_count;
    std.log.info("batch: first={d} batch={d} total={d}", .{ ctx.first_count, ctx.batch_count, total });
    try helpers.expect(error.BatchProcessingFailed, total == n, "wrong total");
    try helpers.expect(error.BatchProcessingFailed, ctx.first_count > 0, "no items received as first");
}

const WorkerCtx = struct {
    mbx: *Mbox,
    alloc: std.mem.Allocator,
    first_count: usize = 0,
    batch_count: usize = 0,
};

fn batchWorkerFn(ctx: *WorkerCtx) void {
    while (true) {
        var slot: Slot = null;
        ctx.mbx.receive(&slot, null) catch return;
        const poly: *PolyNode = slot.?;

        if (items.ShutdownCommand.ShutdownCommandPolyHelper.fromPoly(poly)) |_| {
            items.freeSlot(&slot, ctx.alloc);
            return;
        }

        items.freeSlot(&slot, ctx.alloc);
        ctx.first_count += 1;

        var batch: polynode.ItemList = ctx.mbx.receive_batch() catch return;
        while (batch.popFirst()) |bpoly| {
            if (items.ShutdownCommand.ShutdownCommandPolyHelper.fromPoly(bpoly)) |_| {
                items.freeItem(bpoly, ctx.alloc);
                return;
            }
            items.freeItem(bpoly, ctx.alloc);
            ctx.batch_count += 1;
        }
    }
}

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const polynode = matryoshka.polynode;
const mailbox = matryoshka.mailbox;
const Mbox = matryoshka.Mbox;
const PolyNode = polynode.PolyNode;
const Slot = polynode.Slot;
