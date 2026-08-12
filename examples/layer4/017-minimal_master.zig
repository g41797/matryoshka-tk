// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Minimal Master.
//!
//! - Master spawns one worker via io.concurrent.
//! - sendItems pushes 3 Events into the shared mailbox.
//! - awaitWorker closes the mailbox, frees anything left, awaits the worker.
//! - Shutdown cleanup uses a plain stdlib list — no Matryoshka-specific cleanup API.
//!
//!
//! ```
//!  master ──alloc.create──► slot ──mbx.send──► mailbox
//!                                                      │ worker (io.concurrent)
//!                                                      │ mbx.receive ──► freeSlot
//!  mbx.close ──► remaining list ──► freeList
//!  fut.await ──► worker done
//! ```
//!

pub fn minimal_master(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbx: *Mbox = try mailbox.new(io, allocator);
    defer {
        var rem: polynode.ItemList = mbx.close();
        items.freeList(&rem, allocator);
        mailbox.destroy(mbx, allocator);
    }

    var ctx: WorkerCtx = .{ .mbx = mbx, .alloc = allocator };
    var fut = try io.concurrent(workerFn, .{&ctx});
    try sendItems(mbx, allocator);
    try awaitWorker(mbx, allocator, io, &fut);
    std.log.info("master: worker done", .{});
}

const WorkerCtx = struct {
    mbx: *Mbox,
    alloc: std.mem.Allocator,
};

fn workerFn(ctx: *WorkerCtx) anyerror!void {
    while (true) {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        ctx.mbx.receive(&slot, null) catch return;
    }
}

fn sendItems(mbx: *Mbox, alloc: std.mem.Allocator) !void {
    for (0..3) |i| {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(alloc, &slot);
        try items.Event.EventPolyHelper.create(alloc, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
        try mbx.send(&slot);
        std.log.info("master: sent Event code={d}", .{i + 1});
    }
}

fn awaitWorker(mbx: *Mbox, alloc: std.mem.Allocator, io: std.Io, fut: *Io.Future(anyerror!void)) !void {
    var remaining: polynode.ItemList = mbx.close();
    items.freeList(&remaining, alloc);
    try fut.await(io);
}

const items = @import("../items/items.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const Mbox = matryoshka.Mbox;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
const Io = std.Io;
