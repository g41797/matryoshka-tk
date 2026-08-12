// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Request-response between Masters.
//!
//! - Master A sends an Event request to Master B's inbox.
//! - Master B computes a response, sends a Sensor to Master A's inbox.
//! - Both masters run concurrently; runMasters awaits both.
//!
//!
//! ```
//!  master A ──Event(request)──► b_inbox ──► master B
//!  master A ◄──Sensor(response)── a_inbox ◄── master B
//!  (fut_a + fut_b run concurrently; fut_a.await → fut_b.await)
//! ```
//!

pub fn request_response_between_masters(allocator: std.mem.Allocator, io: std.Io) !void {
    const a_inbox: *Mbox = try mailbox.new(io, allocator);
    defer {
        var rem: polynode.ItemList = a_inbox.close();
        items.freeList(&rem, allocator);
        mailbox.destroy(a_inbox, allocator);
    }

    const b_inbox: *Mbox = try mailbox.new(io, allocator);
    defer {
        var rem: polynode.ItemList = b_inbox.close();
        items.freeList(&rem, allocator);
        mailbox.destroy(b_inbox, allocator);
    }

    try runMasters(a_inbox, b_inbox, allocator, io);
    std.log.info("request-response done: both masters completed", .{});
}

const MasterACtx = struct {
    a_inbox: *Mbox,
    b_inbox: *Mbox,
    alloc: std.mem.Allocator,
};

fn masterAFn(ctx: *MasterACtx) anyerror!void {
    {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        try items.Event.EventPolyHelper.create(ctx.alloc, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = 42;
        try ctx.b_inbox.send(&slot);
        std.log.info("master A: sent Event code=42 request to B", .{});
    }

    var slot: Slot = null;
    defer items.freeSlot(&slot, ctx.alloc);
    try ctx.a_inbox.receive(&slot, null);

    if (items.Sensor.SensorPolyHelper.fromSlot(&slot)) |sn| {
        std.log.info("master A: received Sensor response value={d}", .{sn.value});
        items.freeSlot(&slot, ctx.alloc);
    } else {
        items.freeSlot(&slot, ctx.alloc);
    }
}

const MasterBCtx = struct {
    a_inbox: *Mbox,
    b_inbox: *Mbox,
    alloc: std.mem.Allocator,
};

fn masterBFn(ctx: *MasterBCtx) anyerror!void {
    var slot: Slot = null;
    defer items.freeSlot(&slot, ctx.alloc);
    try ctx.b_inbox.receive(&slot, null);

    var response_value: f64 = 0.0;
    if (items.Event.EventPolyHelper.fromSlot(&slot)) |ev| {
        response_value = @floatFromInt(ev.code);
        std.log.info("master B: received Event code={d}, computing response", .{ev.code});
        items.freeSlot(&slot, ctx.alloc);
    } else {
        items.freeSlot(&slot, ctx.alloc);
    }

    try items.Sensor.SensorPolyHelper.create(ctx.alloc, &slot);
    items.Sensor.SensorPolyHelper.mustFromSlot(&slot).value = response_value;
    try ctx.a_inbox.send(&slot);
    std.log.info("master B: sent Sensor response value={d}", .{response_value});
}

fn runMasters(a_inbox: *Mbox, b_inbox: *Mbox, alloc: std.mem.Allocator, io: std.Io) !void {
    var ctx_a: MasterACtx = .{ .a_inbox = a_inbox, .b_inbox = b_inbox, .alloc = alloc };
    var ctx_b: MasterBCtx = .{ .a_inbox = a_inbox, .b_inbox = b_inbox, .alloc = alloc };
    var fut_a = try io.concurrent(masterAFn, .{&ctx_a});
    var fut_b = try io.concurrent(masterBFn, .{&ctx_b});
    try fut_a.await(io);
    try fut_b.await(io);
}

const items = @import("../items/items.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const Mbox = matryoshka.Mbox;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
