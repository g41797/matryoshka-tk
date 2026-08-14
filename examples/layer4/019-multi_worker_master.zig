// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Multi-worker Master.
//!
//! - Master spawns 3 workers via Io.Group, all sharing one mailbox.
//! - sendItems pushes 3 Events; workers compete for them.
//! - awaitAll closes the mailbox, frees anything left, awaits the group.
//! - Shutdown cancels the group on defer, in case a worker is still running.
//!
//!
//! ```
//!  master ──Event×3──► mailbox ──► worker A (Io.Group)
//!                             ├──► worker B  (compete; each freeSlot)
//!                             └──► worker C
//!  mbx.close ──► remaining freeList ──► group.await
//! ```
//!

pub fn multi_worker_master(allocator: std.mem.Allocator, io: std.Io) !void {
    var mbx_slot: Slot = null;
    try mailbox.new(io, allocator, &mbx_slot);
    const mbx: *Mbox = Mbox.moveFromSlot(&mbx_slot).?;
    defer {
        var rem: polynode.ItemList = mbx.close();
        items.freeList(&rem, allocator);
        mailbox.destroy(mbx, allocator);
    }

    var worker_ctxs: [3]WorkerCtx = undefined;
    var group: Io.Group = .init;
    defer group.cancel(io);
    try spawnWorkers(mbx, allocator, io, &group, &worker_ctxs);
    try sendItems(mbx, allocator);
    try awaitAll(mbx, allocator, io, &group);
    std.log.info("master: all workers done", .{});
}

const WorkerCtx = struct {
    mbx: *Mbox,
    alloc: std.mem.Allocator,
};

fn workerFn(ctx: *WorkerCtx) error{Canceled}!void {
    while (true) {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        ctx.mbx.receive(&slot, null) catch |err| switch (err) {
            error.Canceled => return error.Canceled,
            error.Closed, error.Timeout, error.Wakeup => return,
        };
    }
}

fn spawnWorkers(mbx: *Mbox, alloc: std.mem.Allocator, io: std.Io, group: *Io.Group, ctxs: *[3]WorkerCtx) !void {
    for (ctxs) |*ctx| {
        ctx.* = .{ .mbx = mbx, .alloc = alloc };
        try group.concurrent(io, workerFn, .{ctx});
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

fn awaitAll(mbx: *Mbox, alloc: std.mem.Allocator, io: std.Io, group: *Io.Group) !void {
    var remaining: polynode.ItemList = mbx.close();
    items.freeList(&remaining, alloc);
    try group.await(io);
}

const items = @import("../items/items.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const Mbox = matryoshka.Mbox;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
const Io = std.Io;
