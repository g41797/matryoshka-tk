// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Fan-out.
//!
//! - Main sends 5 Events and 4 Sensors into one mailbox.
//! - 3 worker threads share the mailbox, compete for items.
//! - Main closes the mailbox, frees any items left unclaimed.
//! - Verifies every item was either received or freed.
//!
//!
//! ```
//!  main ──Event×5 + Sensor×4──► mailbox ──► worker A
//!                                      ├──► worker B  (compete; each item goes to one)
//!                                      └──► worker C
//!  mbx.close ──► remaining list ──► freeItem (main)
//! ```
//!

pub fn fan_out(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbx: *Mbox = try mailbox.new(io, allocator);
    defer mailbox.destroy(mbx, allocator);

    var ctx_a: WorkerCtx = .{ .mbx = mbx, .alloc = allocator };
    var ctx_b: WorkerCtx = .{ .mbx = mbx, .alloc = allocator };
    var ctx_c: WorkerCtx = .{ .mbx = mbx, .alloc = allocator };

    var fa = try io.concurrent(fanOutWorkerFn, .{&ctx_a});
    var fb = try io.concurrent(fanOutWorkerFn, .{&ctx_b});
    var fc = try io.concurrent(fanOutWorkerFn, .{&ctx_c});

    const n_events: usize = 5;
    const n_sensors: usize = 4;

    var i: usize = 0;
    while (i < n_events) : (i += 1) {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(allocator, &slot);
        try items.Event.EventPolyHelper.create(allocator, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i);
        try mbx.send(&slot);
    }

    i = 0;
    while (i < n_sensors) : (i += 1) {
        var slot: Slot = null;
        defer items.Sensor.SensorPolyHelper.destroy(allocator, &slot);
        try items.Sensor.SensorPolyHelper.create(allocator, &slot);
        items.Sensor.SensorPolyHelper.mustFromSlot(&slot).value = @as(f64, @floatFromInt(i));
        try mbx.send(&slot);
    }

    var rem: polynode.ItemList = mbx.close();
    var remaining: usize = 0;
    while (rem.popFirst()) |ih| {
        items.freeItem(ih, allocator);
        remaining += 1;
    }

    fa.await(io);
    fb.await(io);
    fc.await(io);

    const total: usize = ctx_a.received + ctx_b.received + ctx_c.received;
    std.log.info("fan-out: a={d} b={d} c={d} remaining={d}", .{ ctx_a.received, ctx_b.received, ctx_c.received, remaining });
    try helpers.expect(error.FanOutFailed, total + remaining == n_events + n_sensors, "wrong total");
}

const WorkerCtx = struct {
    mbx: *Mbox,
    alloc: std.mem.Allocator,
    received: usize = 0,
};

fn fanOutWorkerFn(ctx: *WorkerCtx) void {
    while (true) {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        ctx.mbx.receive(&slot, null) catch return;
        ctx.received += 1;
    }
}

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const polynode = matryoshka.polynode;
const mailbox = matryoshka.mailbox;
const Mbox = matryoshka.Mbox;
const Slot = polynode.Slot;
