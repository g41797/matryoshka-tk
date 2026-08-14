// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Fan-in.
//!
//! - 3 concurrent senders: Events, Sensors, and a mixed sender.
//! - All send into one shared mailbox.
//! - Single receiver empties it with mbx.receive_batch.
//! - Counts events and sensors received, verifies the total.
//!
//!
//! ```
//!  eventSenderFn ──Event×5──►
//!  sensorSenderFn ──Sensor×5──► mailbox ──receive_batch──► freeItem per node
//!  altSenderFn ──mixed×4──►
//!  (3 concurrent senders fan-in to one mailbox)
//! ```
//!

pub fn fan_in(allocator: std.mem.Allocator, io: std.Io) !void {
    var mbx_slot: Slot = null;
    try mailbox.new(io, allocator, &mbx_slot);
    const mbx: *Mbox = Mbox.moveFromSlot(&mbx_slot).?;
    defer {
        var rem: polynode.ItemList = mbx.close();
        items.freeList(&rem, allocator);
        mailbox.destroy(mbx, allocator);
    }

    var ctx_ev: SenderCtx = .{ .mbx = mbx, .alloc = allocator };
    var ctx_sn: SenderCtx = .{ .mbx = mbx, .alloc = allocator };
    var ctx_alt: SenderCtx = .{ .mbx = mbx, .alloc = allocator };

    var f1 = try io.concurrent(eventSenderFn, .{&ctx_ev});
    var f2 = try io.concurrent(sensorSenderFn, .{&ctx_sn});
    var f3 = try io.concurrent(altSenderFn, .{&ctx_alt});

    f1.await(io);
    f2.await(io);
    f3.await(io);

    const total_sent: usize = ctx_ev.sent + ctx_sn.sent + ctx_alt.sent;
    var batch: polynode.ItemList = try mbx.receive_batch();
    var events_received: usize = 0;
    var sensors_received: usize = 0;

    while (batch.popFirst()) |poly| {
        if (items.Event.EventPolyHelper.fromPoly(poly)) |_| {
            events_received += 1;
        } else if (items.Sensor.SensorPolyHelper.fromPoly(poly)) |_| {
            sensors_received += 1;
        }
        items.freeItem(poly, allocator);
    }

    std.log.info("fan-in: sent={d} events={d} sensors={d}", .{ total_sent, events_received, sensors_received });
    try helpers.expect(error.FanInFailed, events_received + sensors_received == total_sent, "wrong total");
}

const SenderCtx = struct {
    mbx: *Mbox,
    alloc: std.mem.Allocator,
    sent: usize = 0,
};

fn eventSenderFn(ctx: *SenderCtx) void {
    var i: i32 = 0;
    while (i < 5) : (i += 1) {
        var slot: Slot = null;
        items.Event.EventPolyHelper.create(ctx.alloc, &slot) catch return;
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = i;
        ctx.mbx.send(&slot) catch {
            items.freeSlot(&slot, ctx.alloc);
            return;
        };
        ctx.sent += 1;
    }
}

fn sensorSenderFn(ctx: *SenderCtx) void {
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        var slot: Slot = null;
        items.Sensor.SensorPolyHelper.create(ctx.alloc, &slot) catch return;
        items.Sensor.SensorPolyHelper.mustFromSlot(&slot).value = @as(f64, @floatFromInt(i)) * 0.1;
        ctx.mbx.send(&slot) catch {
            items.freeSlot(&slot, ctx.alloc);
            return;
        };
        ctx.sent += 1;
    }
}

fn altSenderFn(ctx: *SenderCtx) void {
    var i: i32 = 0;
    while (i < 4) : (i += 1) {
        var slot: Slot = null;
        if (@rem(i, 2) == 0) {
            items.Event.EventPolyHelper.create(ctx.alloc, &slot) catch return;
            items.Event.EventPolyHelper.mustFromSlot(&slot).code = 100 + i;
        } else {
            items.Sensor.SensorPolyHelper.create(ctx.alloc, &slot) catch return;
            items.Sensor.SensorPolyHelper.mustFromSlot(&slot).value = @as(f64, @floatFromInt(i));
        }
        ctx.mbx.send(&slot) catch {
            items.freeSlot(&slot, ctx.alloc);
            return;
        };
        ctx.sent += 1;
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
