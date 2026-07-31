// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Batch processing.
//!
//! - Main sends 10 Events, then a ShutdownCommand sentinel.
//! - Worker blocks on the first item via mailbox.receive.
//! - Worker then empties the rest with mailbox.receive_batch.
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
    const mbh: MailboxHandle = try mailbox.new(io, allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh);
        items.freeList(&rem, allocator);
        mailbox.destroy(mbh, allocator);
    }

    var ctx: WorkerCtx = .{ .mbh = mbh, .alloc = allocator };
    var fut = try io.concurrent(batchWorkerFn, .{&ctx});

    const n: usize = 10;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(allocator, &slot);
        try items.Event.EventPolyHelper.create(allocator, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i);
        try mailbox.send(mbh, &slot);
    }

    // Signal worker to stop — all n items are already queued before this.
    {
        var slot: Slot = null;
        defer items.ShutdownCommand.ShutdownCommandPolyHelper.destroy(allocator, &slot);
        try items.ShutdownCommand.ShutdownCommandPolyHelper.create(allocator, &slot);
        try mailbox.send(mbh, &slot);
    }

    fut.await(io);

    const total = ctx.first_count + ctx.batch_count;
    std.log.info("batch: first={d} batch={d} total={d}", .{ ctx.first_count, ctx.batch_count, total });
    try helpers.expect(error.BatchProcessingFailed, total == n, "wrong total");
    try helpers.expect(error.BatchProcessingFailed, ctx.first_count > 0, "no items received as first");
}

const WorkerCtx = struct {
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,
    first_count: usize = 0,
    batch_count: usize = 0,
};

fn batchWorkerFn(ctx: *WorkerCtx) void {
    while (true) {
        var slot: Slot = null;
        mailbox.receive(ctx.mbh, &slot, null) catch return;
        const poly: *PolyNode = slot.?;

        if (items.ShutdownCommand.ShutdownCommandPolyHelper.fromPoly(poly)) |_| {
            items.freeSlot(&slot, ctx.alloc);
            return;
        }

        items.freeSlot(&slot, ctx.alloc);
        ctx.first_count += 1;

        var batch: polynode.ItemList = mailbox.receive_batch(ctx.mbh) catch return;
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
const PolyNode = polynode.PolyNode;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
