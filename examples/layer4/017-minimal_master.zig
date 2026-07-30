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
//!  master ──alloc.create──► slot ──mailbox.send──► mailbox
//!                                                      │ worker (io.concurrent)
//!                                                      │ mailbox.receive ──► freeSlot
//!  mailbox.close ──► remaining list ──► freeList
//!  fut.await ──► worker done
//! ```
//!

pub fn minimal_master(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbh: MailboxHandle = try mailbox.new(io, allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh);
        items.freeList(&rem, allocator);
        mailbox.destroy(mbh, allocator);
    }

    var ctx: WorkerCtx = .{ .mbh = mbh, .alloc = allocator };
    var fut = try io.concurrent(workerFn, .{&ctx});
    try sendItems(mbh, allocator);
    try awaitWorker(mbh, allocator, io, &fut);
    std.log.info("master: worker done", .{});
}

const WorkerCtx = struct {
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,
};

fn workerFn(ctx: *WorkerCtx) anyerror!void {
    while (true) {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        mailbox.receive(ctx.mbh, &slot, null) catch return;
    }
}

fn sendItems(mbh: MailboxHandle, alloc: std.mem.Allocator) !void {
    for (0..3) |i| {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(alloc, &slot);
        try items.Event.EventPolyHelper.create(alloc, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
        try mailbox.send(mbh, &slot);
        std.log.info("master: sent Event code={d}", .{i + 1});
    }
}

fn awaitWorker(mbh: MailboxHandle, alloc: std.mem.Allocator, io: std.Io, fut: *Io.Future(anyerror!void)) !void {
    var remaining: polynode.ItemList = mailbox.close(mbh);
    items.freeList(&remaining, alloc);
    try fut.await(io);
}

const items = @import("../items/items.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
const Io = std.Io;
