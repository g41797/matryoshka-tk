// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Worker finish signal via mailbox return.
//!
//! - Master spawns a worker via `io.concurrent`, sends 3 Events + a ShutdownCommand sentinel.
//! - On the sentinel, the worker sends its own mailbox handle back to the master's inbox.
//! - Master confirms the returned item is a MailboxHandle and the expected instance.
//! - Master closes and destroys the worker's mailbox, then awaits the worker's future.
//!
//!
//! ```
//!  master ──Event×3 + ShutdownCommand──► worker_mbh ──► worker task
//!                                                           │ process
//!                                                           │ send worker_mbh ──► master_inbox
//!                                                           ▼ exit
//!  master ◄──worker_mbh (as ItemHandle)── master_inbox
//!  master: close + destroy worker_mbh (tag+pointer verified first)
//! ```
//!

pub fn worker_finish_signal_via_mailbox_return(allocator: std.mem.Allocator, io: std.Io) !void {
    const master_inbox: MailboxHandle = try mailbox.new(io, allocator);
    defer {
        _ = mailbox.close(master_inbox);
        mailbox.destroy(master_inbox, allocator);
    }

    const worker_mbh: MailboxHandle = try mailbox.new(io, allocator);

    try sendJobsAndShutdown(worker_mbh, allocator);

    var worker_ctx: WorkerCtx = undefined;
    var fut = try spawnWorker(master_inbox, worker_mbh, &worker_ctx, allocator, io);

    try receiveAndVerify(master_inbox, worker_mbh, allocator);
    std.log.info("master: received worker_mbh back — worker finished (processed={d})", .{worker_ctx.processed});

    fut.await(io);
}

const WorkerCtx = struct {
    master_inbox: MailboxHandle,
    worker_mbh: MailboxHandle,
    alloc: std.mem.Allocator,
    processed: usize = 0,
};

fn cleanupReturnedMailbox(slot: *Slot, alloc: std.mem.Allocator) void {
    const returned: MailboxHandle = slot.*.?;
    _ = mailbox.close(returned);
    mailbox.destroy(returned, alloc);
    slot.* = null;
}

fn workerFn(ctx: *WorkerCtx) void {
    while (true) {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        mailbox.receive(ctx.worker_mbh, &slot, null) catch return;
        const poly: *PolyNode = slot.?;

        if (items.ShutdownCommand.ShutdownCommandPolyHelper.fromNode(poly) != null) {
            items.freeSlot(&slot, ctx.alloc);
            slot = ctx.worker_mbh;
            mailbox.send(ctx.master_inbox, &slot) catch {};
            slot = null;
            return;
        }

        if (items.Event.EventPolyHelper.fromNode(poly)) |ev| {
            ctx.processed += 1;
            std.log.info("worker processed Event code={d}", .{ev.code});
            items.freeSlot(&slot, ctx.alloc);
        }
    }
}

fn sendJobsAndShutdown(worker_mbh: MailboxHandle, alloc: std.mem.Allocator) !void {
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(alloc, &slot);
        try items.Event.EventPolyHelper.create(alloc, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @as(i32, @intCast(i + 1));
        try mailbox.send(worker_mbh, &slot);
    }

    var slot: Slot = null;
    defer items.ShutdownCommand.ShutdownCommandPolyHelper.destroy(alloc, &slot);
    try items.ShutdownCommand.ShutdownCommandPolyHelper.create(alloc, &slot);
    try mailbox.send(worker_mbh, &slot);

    std.log.info("master: sent 3 Events + ShutdownCommand to worker", .{});
}

fn spawnWorker(master_inbox: MailboxHandle, worker_mbh: MailboxHandle, ctx: *WorkerCtx, alloc: std.mem.Allocator, io: std.Io) !std.Io.Future(void) {
    ctx.* = .{ .master_inbox = master_inbox, .worker_mbh = worker_mbh, .alloc = alloc };
    return io.concurrent(workerFn, .{ctx});
}

fn receiveAndVerify(master_inbox: MailboxHandle, worker_mbh: MailboxHandle, alloc: std.mem.Allocator) !void {
    var slot: Slot = null;
    defer if (slot) |mh| {
        _ = mailbox.close(mh);
        mailbox.destroy(mh, alloc);
    };
    try mailbox.receive(master_inbox, &slot, null);
    try helpers.expect(error.WorkerFinishFailed, mailbox.is_it_you(slot.?.*.tag), "expected a MailboxHandle");
    try helpers.expect(error.WorkerFinishFailed, slot.? == worker_mbh, "wrong mailbox returned");
    cleanupReturnedMailbox(&slot, alloc);
}

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const polynode = matryoshka.polynode;
const PolyNode = polynode.PolyNode;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
