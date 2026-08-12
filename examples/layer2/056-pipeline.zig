// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Pipeline.
//!
//! - Chain of 3 stages: producer, transformer, consumer.
//! - Producer sends 5 Events, then a sentinel (code == -1).
//! - Transformer squares each code, forwards the sentinel, then exits.
//! - Consumer sums results, frees the sentinel, exits.
//!
//!
//! ```
//!  producer ──Event──► stage1 mailbox ──► transformer
//!                                              │ Event→Event (code²)
//!                                              ▼
//!  consumer ◄──Event── stage2 mailbox ◄── transformer
//!  (sentinel: Event code=-1 terminates each stage; consumer frees)
//! ```
//!

pub fn pipeline(allocator: std.mem.Allocator, io: std.Io) !void {
    const stage1: *Mbox = try mailbox.new(io, allocator);
    const stage2: *Mbox = try mailbox.new(io, allocator);
    defer {
        var r1: polynode.ItemList = stage1.close();
        items.freeList(&r1, allocator);
        var r2: polynode.ItemList = stage2.close();
        items.freeList(&r2, allocator);
        mailbox.destroy(stage1, allocator);
        mailbox.destroy(stage2, allocator);
    }

    var prod_ctx: ProducerCtx = .{ .outbox = stage1, .alloc = allocator };
    var tran_ctx: StageCtx = .{ .inbox = stage1, .outbox = stage2, .alloc = allocator };
    var cons_ctx: ConsumerCtx = .{ .mbx = stage2, .alloc = allocator };

    var f_prod = try io.concurrent(producerFn, .{&prod_ctx});
    var f_tran = try io.concurrent(transformerFn, .{&tran_ctx});
    var f_cons = try io.concurrent(consumerFn, .{&cons_ctx});

    f_prod.await(io);
    f_tran.await(io);
    f_cons.await(io);

    // 0²+1²+2²+3²+4² = 30.
    std.log.info("pipeline: count={d} sum={d}", .{ cons_ctx.count, cons_ctx.sum });
    try helpers.expect(error.PipelineFailed, cons_ctx.count == 5, "wrong item count");
    try helpers.expect(error.PipelineFailed, cons_ctx.sum == 30, "wrong sum");
}

const ProducerCtx = struct {
    outbox: *Mbox,
    alloc: std.mem.Allocator,
};

fn producerFn(ctx: *ProducerCtx) void {
    var i: i32 = 0;
    while (i < 5) : (i += 1) {
        var slot: Slot = null;
        items.Event.EventPolyHelper.create(ctx.alloc, &slot) catch return;
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = i;
        ctx.outbox.send(&slot) catch {
            items.freeSlot(&slot, ctx.alloc);
            return;
        };
    }
    {
        var slot: Slot = null;
        items.Event.EventPolyHelper.create(ctx.alloc, &slot) catch return;
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = -1;
        ctx.outbox.send(&slot) catch items.freeSlot(&slot, ctx.alloc);
    }
}

const StageCtx = struct {
    inbox: *Mbox,
    outbox: *Mbox,
    alloc: std.mem.Allocator,
};

fn transformerFn(ctx: *StageCtx) void {
    while (true) {
        var slot: Slot = null;
        ctx.inbox.receive(&slot, null) catch return;
        const ev: *items.Event = items.Event.EventPolyHelper.fromSlot(&slot) orelse {
            items.freeSlot(&slot, ctx.alloc);
            continue;
        };
        if (ev.code == -1) {
            ctx.outbox.send(&slot) catch items.freeSlot(&slot, ctx.alloc);
            return;
        }
        ev.code = ev.code * ev.code;
        ctx.outbox.send(&slot) catch items.freeSlot(&slot, ctx.alloc);
    }
}

const ConsumerCtx = struct {
    mbx: *Mbox,
    alloc: std.mem.Allocator,
    sum: i32 = 0,
    count: usize = 0,
};

fn consumerFn(ctx: *ConsumerCtx) void {
    while (true) {
        var slot: Slot = null;
        ctx.mbx.receive(&slot, null) catch return;
        const ev: *items.Event = items.Event.EventPolyHelper.fromSlot(&slot) orelse {
            items.freeSlot(&slot, ctx.alloc);
            continue;
        };
        if (ev.code == -1) {
            items.freeSlot(&slot, ctx.alloc);
            return;
        }
        std.log.info("pipeline: result={d}", .{ev.code});
        ctx.sum += ev.code;
        ctx.count += 1;
        items.freeSlot(&slot, ctx.alloc);
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
