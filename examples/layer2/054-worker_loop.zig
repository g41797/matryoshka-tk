// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Worker loop pattern.
//!
//! - Main sends 3 Events and 2 Sensors into a mailbox.
//! - Worker thread loops on mailbox.receive, dispatches on tag.
//! - Worker exits on error.Closed.
//! - Main closes the mailbox, frees any items left unreceived.
//!
//!
//! ```
//!  main ──alloc.create──► slot ──mailbox.send──► mailbox
//!                                                    │
//!                                              worker thread
//!                                              mailbox.receive
//!                                                    │ freeSlot
//!  mailbox.close ──► remaining list ──► freeList (main)
//! ```
//!

pub fn worker_loop_pattern(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbh: MailboxHandle = try mailbox.new(io, allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh);
        items.freeList(&rem, allocator);
        mailbox.destroy(mbh, allocator);
    }

    var ctx: WorkerCtx = .{ .mbh = mbh, .alloc = allocator };
    var fut = try io.concurrent(workerFn, .{&ctx});

    const codes = [_]i32{ 1, 2, 3 };
    for (codes) |code| {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(allocator, &slot);
        try items.Event.EventPolyHelper.create(allocator, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = code;
        try mailbox.send(mbh, &slot);
    }

    const values = [_]f64{ 1.5, 2.5 };
    for (values) |value| {
        var slot: Slot = null;
        defer items.Sensor.SensorPolyHelper.destroy(allocator, &slot);
        try items.Sensor.SensorPolyHelper.create(allocator, &slot);
        items.Sensor.SensorPolyHelper.mustFromSlot(&slot).value = value;
        try mailbox.send(mbh, &slot);
    }

    var rem: polynode.ItemList = mailbox.close(mbh);
    var remaining: usize = 0;
    while (rem.popFirst()) |ih| {
        items.freeItem(ih, allocator);
        remaining += 1;
    }
    fut.await(io);

    std.log.info("worker loop: processed={d} remaining={d} event_sum={d} sensor_sum={d:.1}", .{
        ctx.count, remaining, ctx.event_sum, ctx.sensor_sum,
    });
    try helpers.expect(error.WorkerLoopFailed, ctx.count + remaining == 5, "wrong total");
}

const WorkerCtx = struct {
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,
    event_sum: i32 = 0,
    sensor_sum: f64 = 0.0,
    count: usize = 0,
};

fn workerFn(ctx: *WorkerCtx) void {
    while (true) {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        mailbox.receive(ctx.mbh, &slot, null) catch return;
        const poly: *PolyNode = slot.?;
        if (items.Event.EventPolyHelper.fromPoly(poly)) |ev| {
            std.log.debug("worker: Event code={d}", .{ev.*.code});
            ctx.event_sum += ev.*.code;
            ctx.count += 1;
        } else if (items.Sensor.SensorPolyHelper.fromPoly(poly)) |sn| {
            std.log.debug("worker: Sensor value={d:.1}", .{sn.*.value});
            ctx.sensor_sum += sn.*.value;
            ctx.count += 1;
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
