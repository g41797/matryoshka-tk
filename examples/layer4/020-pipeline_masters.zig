// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Pipeline of Masters.
//!
//! - 3 Masters chained: producer, transformer, consumer.
//! - Producer sends Events, then a ShutdownCommand sentinel.
//! - Transformer converts each Event to a Sensor, forwards the sentinel, exits.
//! - Consumer sums received Sensors, exits on the sentinel.
//!
//!
//! ```
//!  producer ──Event──► transformer_mbx ──► transformer
//!                                              │ Event→Sensor conversion
//!                                              ▼
//!  consumer ◄──Sensor── consumer_mbx ◄── transformer
//!  (ShutdownCommand sentinel propagates: producer→transformer→consumer)
//!  fut_prod.await → fut_trans.await → fut_cons.await
//! ```
//!

pub fn pipeline_of_masters(allocator: std.mem.Allocator, io: std.Io) !void {
    const master = try PipelineMaster.init(allocator, io);
    defer master.destroy();
    try master.run();
}

const ProducerCtx = struct {
    out_mbx: *Mbox,
    alloc: std.mem.Allocator,
};

fn producerFn(ctx: *ProducerCtx) anyerror!void {
    for (0..3) |i| {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        try items.Event.EventPolyHelper.create(ctx.alloc, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
        try ctx.out_mbx.send(&slot);
        std.log.info("producer: sent Event code={d}", .{i + 1});
    }
    {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        try items.ShutdownCommand.ShutdownCommandPolyHelper.create(ctx.alloc, &slot);
        try ctx.out_mbx.send(&slot);
        std.log.info("producer: sent ShutdownCommand sentinel", .{});
    }
}

const TransformerCtx = struct {
    in_mbx: *Mbox,
    out_mbx: *Mbox,
    alloc: std.mem.Allocator,
};

fn transformerFn(ctx: *TransformerCtx) anyerror!void {
    while (true) {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        ctx.in_mbx.receive(&slot, null) catch return;
        const poly: *PolyNode = slot.?;

        if (items.Event.EventPolyHelper.fromPoly(poly)) |ev| {
            const value: f64 = @floatFromInt(ev.code);
            items.freeSlot(&slot, ctx.alloc);
            items.Sensor.SensorPolyHelper.create(ctx.alloc, &slot) catch continue;
            items.Sensor.SensorPolyHelper.mustFromSlot(&slot).value = value;
            ctx.out_mbx.send(&slot) catch {
                items.freeSlot(&slot, ctx.alloc);
            };
            std.log.info("transformer: Event→Sensor value={d}", .{value});
        } else if (items.ShutdownCommand.ShutdownCommandPolyHelper.fromPoly(poly)) |_| {
            ctx.out_mbx.send(&slot) catch {};
            std.log.info("transformer: forwarded ShutdownCommand, done", .{});
            return;
        } else {
            items.freeSlot(&slot, ctx.alloc);
        }
    }
}

const ConsumerCtx = struct {
    in_mbx: *Mbox,
    alloc: std.mem.Allocator,
    count: usize = 0,
};

fn consumerFn(ctx: *ConsumerCtx) anyerror!void {
    while (true) {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        ctx.in_mbx.receive(&slot, null) catch return;
        const poly: *PolyNode = slot.?;

        if (items.Sensor.SensorPolyHelper.fromPoly(poly)) |sn| {
            ctx.count += 1;
            std.log.info("consumer: Sensor value={d} (total={d})", .{ sn.value, ctx.count });
            items.freeSlot(&slot, ctx.alloc);
        } else if (items.ShutdownCommand.ShutdownCommandPolyHelper.fromPoly(poly)) |_| {
            std.log.info("consumer: ShutdownCommand received, done", .{});
            items.freeSlot(&slot, ctx.alloc);
            return;
        } else {
            items.freeSlot(&slot, ctx.alloc);
        }
    }
}

const PipelineMaster = struct {
    fn run(self: *PipelineMaster) !void {
        try self.runWorkers();
        try helpers.expect(error.PipelineFailed, self.cons_ctx.count == 3, "expected consumer to receive 3 Sensors");
        std.log.info("pipeline done: consumer received {d} items", .{self.cons_ctx.count});
    }

    fn runWorkers(self: *PipelineMaster) !void {
        var fut_prod: std.Io.Future(anyerror!void) = try self.io.concurrent(producerFn, .{&self.prod_ctx});
        var fut_trans: std.Io.Future(anyerror!void) = try self.io.concurrent(transformerFn, .{&self.trans_ctx});
        var fut_cons: std.Io.Future(anyerror!void) = try self.io.concurrent(consumerFn, .{&self.cons_ctx});
        try fut_prod.await(self.io);
        try fut_trans.await(self.io);
        try fut_cons.await(self.io);
    }

    allocator: std.mem.Allocator,
    io: std.Io,
    transformer_mbx: *Mbox,
    consumer_mbx: *Mbox,
    prod_ctx: ProducerCtx,
    trans_ctx: TransformerCtx,
    cons_ctx: ConsumerCtx,

    fn init(allocator: std.mem.Allocator, io: std.Io) !*PipelineMaster {
        const self = try allocator.create(PipelineMaster);
        errdefer allocator.destroy(self);
        self.allocator = allocator;
        self.io = io;

        var transformer_mbx_slot: Slot = null;
        try mailbox.new(io, allocator, &transformer_mbx_slot);
        self.transformer_mbx = Mbox.moveFromSlot(&transformer_mbx_slot).?;
        errdefer {
            var rem: polynode.ItemList = self.transformer_mbx.close();
            items.freeList(&rem, allocator);
            mailbox.destroy(self.transformer_mbx, allocator);
        }

        var consumer_mbx_slot: Slot = null;
        try mailbox.new(io, allocator, &consumer_mbx_slot);
        self.consumer_mbx = Mbox.moveFromSlot(&consumer_mbx_slot).?;
        self.prod_ctx = .{ .out_mbx = self.transformer_mbx, .alloc = allocator };
        self.trans_ctx = .{ .in_mbx = self.transformer_mbx, .out_mbx = self.consumer_mbx, .alloc = allocator };
        self.cons_ctx = .{ .in_mbx = self.consumer_mbx, .alloc = allocator };
        return self;
    }

    fn destroy(self: *PipelineMaster) void {
        var rem1: polynode.ItemList = self.transformer_mbx.close();
        items.freeList(&rem1, self.allocator);
        mailbox.destroy(self.transformer_mbx, self.allocator);
        var rem2: polynode.ItemList = self.consumer_mbx.close();
        items.freeList(&rem2, self.allocator);
        mailbox.destroy(self.consumer_mbx, self.allocator);
        self.allocator.destroy(self);
    }
};

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const Mbox = matryoshka.Mbox;
const polynode = matryoshka.polynode;
const PolyNode = polynode.PolyNode;
const Slot = polynode.Slot;
