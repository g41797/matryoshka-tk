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
//!  producer ──Event──► transformer_mbh ──► transformer
//!                                              │ Event→Sensor conversion
//!                                              ▼
//!  consumer ◄──Sensor── consumer_mbh ◄── transformer
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
    out_mbh: MailboxHandle,
    alloc: std.mem.Allocator,
};

fn producerFn(ctx: *ProducerCtx) anyerror!void {
    for (0..3) |i| {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        try items.Event.EventPolyHelper.create(ctx.alloc, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
        try mailbox.send(ctx.out_mbh, &slot);
        std.log.info("producer: sent Event code={d}", .{i + 1});
    }
    {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        try items.ShutdownCommand.ShutdownCommandPolyHelper.create(ctx.alloc, &slot);
        try mailbox.send(ctx.out_mbh, &slot);
        std.log.info("producer: sent ShutdownCommand sentinel", .{});
    }
}

const TransformerCtx = struct {
    in_mbh: MailboxHandle,
    out_mbh: MailboxHandle,
    alloc: std.mem.Allocator,
};

fn transformerFn(ctx: *TransformerCtx) anyerror!void {
    while (true) {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        mailbox.receive(ctx.in_mbh, &slot, null) catch return;
        const poly: *PolyNode = slot.?;

        if (items.Event.EventPolyHelper.fromNode(poly)) |ev| {
            const value: f64 = @floatFromInt(ev.code);
            items.freeSlot(&slot, ctx.alloc);
            items.Sensor.SensorPolyHelper.create(ctx.alloc, &slot) catch continue;
            items.Sensor.SensorPolyHelper.mustFromSlot(&slot).value = value;
            mailbox.send(ctx.out_mbh, &slot) catch {
                items.freeSlot(&slot, ctx.alloc);
            };
            std.log.info("transformer: Event→Sensor value={d}", .{value});
        } else if (items.ShutdownCommand.ShutdownCommandPolyHelper.fromNode(poly)) |_| {
            mailbox.send(ctx.out_mbh, &slot) catch {};
            std.log.info("transformer: forwarded ShutdownCommand, done", .{});
            return;
        } else {
            items.freeSlot(&slot, ctx.alloc);
        }
    }
}

const ConsumerCtx = struct {
    in_mbh: MailboxHandle,
    alloc: std.mem.Allocator,
    count: usize = 0,
};

fn consumerFn(ctx: *ConsumerCtx) anyerror!void {
    while (true) {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        mailbox.receive(ctx.in_mbh, &slot, null) catch return;
        const poly: *PolyNode = slot.?;

        if (items.Sensor.SensorPolyHelper.fromNode(poly)) |sn| {
            ctx.count += 1;
            std.log.info("consumer: Sensor value={d} (total={d})", .{ sn.value, ctx.count });
            items.freeSlot(&slot, ctx.alloc);
        } else if (items.ShutdownCommand.ShutdownCommandPolyHelper.fromNode(poly)) |_| {
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
    transformer_mbh: MailboxHandle,
    consumer_mbh: MailboxHandle,
    prod_ctx: ProducerCtx,
    trans_ctx: TransformerCtx,
    cons_ctx: ConsumerCtx,

    fn init(allocator: std.mem.Allocator, io: std.Io) !*PipelineMaster {
        const self = try allocator.create(PipelineMaster);
        errdefer allocator.destroy(self);
        self.allocator = allocator;
        self.io = io;
        self.transformer_mbh = try mailbox.new(io, allocator);
        errdefer {
            var rem: std.DoublyLinkedList = mailbox.close(self.transformer_mbh);
            items.freeList(&rem, allocator);
            mailbox.destroy(self.transformer_mbh, allocator);
        }
        self.consumer_mbh = try mailbox.new(io, allocator);
        self.prod_ctx = .{ .out_mbh = self.transformer_mbh, .alloc = allocator };
        self.trans_ctx = .{ .in_mbh = self.transformer_mbh, .out_mbh = self.consumer_mbh, .alloc = allocator };
        self.cons_ctx = .{ .in_mbh = self.consumer_mbh, .alloc = allocator };
        return self;
    }

    fn destroy(self: *PipelineMaster) void {
        var rem1: std.DoublyLinkedList = mailbox.close(self.transformer_mbh);
        items.freeList(&rem1, self.allocator);
        mailbox.destroy(self.transformer_mbh, self.allocator);
        var rem2: std.DoublyLinkedList = mailbox.close(self.consumer_mbh);
        items.freeList(&rem2, self.allocator);
        mailbox.destroy(self.consumer_mbh, self.allocator);
        self.allocator.destroy(self);
    }
};

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const polynode = matryoshka.polynode;
const PolyNode = polynode.PolyNode;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
