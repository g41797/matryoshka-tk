// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Shutdown via ShutdownCommand.
//!
//! - Main sends 3 Events, then a ShutdownCommand PolyNode.
//! - Worker processes each Event, exits cleanly on the sentinel.
//! - Mailbox stays open throughout — worker owns every item it received.
//!
//!
//! ```
//!  main ──Event×3──► mailbox ──► worker (processes, freeSlot)
//!  main ──ShutdownCommand──► mailbox ──► worker (exits, freeSlot)
//!  (mailbox stays open; worker owns all received items)
//! ```
//!

pub fn shutdown_via_shutdowncommand(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbx: *Mbox = try mailbox.new(io, allocator);

    defer {
        var rem: polynode.ItemList = mbx.close();
        items.freeList(&rem, allocator);
        mailbox.destroy(mbx, allocator);
    }

    var ctx: WorkerCtx = .{ .mbx = mbx, .alloc = allocator };
    var fut = try io.concurrent(workerFn, .{&ctx});

    const codes = [_]i32{ 10, 20, 30 };
    for (codes) |code| {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(allocator, &slot);
        try items.Event.EventPolyHelper.create(allocator, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = code;
        try mbx.send(&slot);
    }

    // Send shutdown signal — mailbox stays open.
    {
        var slot: Slot = null;
        defer items.ShutdownCommand.ShutdownCommandPolyHelper.destroy(allocator, &slot);
        try items.ShutdownCommand.ShutdownCommandPolyHelper.create(allocator, &slot);
        try mbx.send(&slot);
    }

    fut.await(io);

    std.log.info("shutdown_exit: worker processed {d} items before ShutdownCommand", .{ctx.processed});
    try helpers.expect(error.ShutdownExitFailed, ctx.processed == 3, "wrong processed count");
}

const WorkerCtx = struct {
    mbx: *Mbox,
    alloc: std.mem.Allocator,
    processed: usize = 0,
};

fn workerFn(ctx: *WorkerCtx) void {
    while (true) {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        ctx.mbx.receive(&slot, null) catch return;
        const poly: *PolyNode = slot.?;
        if (items.ShutdownCommand.ShutdownCommandPolyHelper.fromPoly(poly)) |_| {
            std.log.info("worker: ShutdownCommand received, exiting cleanly", .{});
            return;
        } else if (items.Event.EventPolyHelper.fromPoly(poly)) |ev| {
            std.log.debug("worker: Event code={d}", .{ev.*.code});
            ctx.processed += 1;
        } else if (items.Sensor.SensorPolyHelper.fromPoly(poly)) |sn| {
            std.log.debug("worker: Sensor value={d:.1}", .{sn.*.value});
            ctx.processed += 1;
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
