// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Worker finish signal via mailbox return.
//!
//! - Master spawns a worker via `io.concurrent`, sends 3 Events + a ShutdownCommand sentinel.
//! - On the sentinel, the worker sends its own mailbox back to the master's inbox.
//! - Master confirms the returned item is an Mbox and the expected instance.
//! - Master closes and destroys the worker's mailbox, then awaits the worker's future.
//!
//!
//! ```
//!  master ──Event×3 + ShutdownCommand──► worker_mbx ──► worker task
//!                                                           │ process
//!                                                           │ send worker_mbx ──► master_inbox
//!                                                           ▼ exit
//!  master ◄──worker_mbx (as ItemHandle)── master_inbox
//!  master: close + destroy worker_mbx (tag+pointer verified first)
//! ```
//!

pub fn worker_finish_signal_via_mailbox_return(allocator: std.mem.Allocator, io: std.Io) !void {
    const master_inbox: *Mbox = try mailbox.new(io, allocator);
    defer {
        var rem: polynode.ItemList = master_inbox.close();
        releaseInbox(&rem, allocator);
        mailbox.destroy(master_inbox, allocator);
    }

    const worker_mbx: *Mbox = try mailbox.new(io, allocator);

    try sendJobsAndShutdown(worker_mbx, allocator);

    var worker_ctx: WorkerCtx = undefined;
    var fut = try spawnWorker(master_inbox, worker_mbx, &worker_ctx, allocator, io);

    try receiveAndVerify(master_inbox, worker_mbx, allocator);
    std.log.info("master: received worker_mbx back — worker finished (processed={d})", .{worker_ctx.processed});

    fut.await(io);
}

const WorkerCtx = struct {
    master_inbox: *Mbox,
    worker_mbx: *Mbox,
    alloc: std.mem.Allocator,
    processed: usize = 0,
};

fn cleanupReturnedMailbox(slot: *Slot, alloc: std.mem.Allocator) void {
    const returned: *Mbox = Mbox.mustFromPoly(slot.*.?);
    var rem: polynode.ItemList = returned.close();
    items.freeList(&rem, alloc);
    mailbox.destroy(returned, alloc);
    slot.* = null;
}

/// Release one handle from the master's inbox.
///
/// The inbox carries application items *and* the worker's mailbox, so the
/// release has to ask which one the handle is. `Mbox.fromPoly` is the
/// checking form — it returns null for an application item instead of
/// panicking.
fn releaseHandle(ih: *PolyNode, alloc: std.mem.Allocator) void {
    if (Mbox.fromPoly(ih)) |returned| {
        var left: polynode.ItemList = returned.close();
        items.freeList(&left, alloc);
        mailbox.destroy(returned, alloc);
    } else {
        items.freeItem(ih, alloc);
    }
}

/// Release everything the master's inbox still holds.
fn releaseInbox(rem: *polynode.ItemList, alloc: std.mem.Allocator) void {
    while (rem.popFirst()) |ih| {
        releaseHandle(ih, alloc);
    }
}

fn workerFn(ctx: *WorkerCtx) void {
    while (true) {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        ctx.worker_mbx.receive(&slot, null) catch return;
        const poly: *PolyNode = slot.?;

        if (items.ShutdownCommand.ShutdownCommandPolyHelper.fromPoly(poly) != null) {
            items.freeSlot(&slot, ctx.alloc);
            slot = Mbox.toPoly(ctx.worker_mbx);
            ctx.master_inbox.send(&slot) catch {};
            slot = null;
            return;
        }

        if (items.Event.EventPolyHelper.fromPoly(poly)) |ev| {
            ctx.processed += 1;
            std.log.info("worker processed Event code={d}", .{ev.code});
            items.freeSlot(&slot, ctx.alloc);
        }
    }
}

fn sendJobsAndShutdown(worker_mbx: *Mbox, alloc: std.mem.Allocator) !void {
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(alloc, &slot);
        try items.Event.EventPolyHelper.create(alloc, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @as(i32, @intCast(i + 1));
        try worker_mbx.send(&slot);
    }

    var slot: Slot = null;
    defer items.ShutdownCommand.ShutdownCommandPolyHelper.destroy(alloc, &slot);
    try items.ShutdownCommand.ShutdownCommandPolyHelper.create(alloc, &slot);
    try worker_mbx.send(&slot);

    std.log.info("master: sent 3 Events + ShutdownCommand to worker", .{});
}

fn spawnWorker(master_inbox: *Mbox, worker_mbx: *Mbox, ctx: *WorkerCtx, alloc: std.mem.Allocator, io: std.Io) !std.Io.Future(void) {
    ctx.* = .{ .master_inbox = master_inbox, .worker_mbx = worker_mbx, .alloc = alloc };
    return io.concurrent(workerFn, .{ctx});
}

fn receiveAndVerify(master_inbox: *Mbox, worker_mbx: *Mbox, alloc: std.mem.Allocator) !void {
    var slot: Slot = null;
    defer if (slot) |poly| {
        releaseHandle(poly, alloc);
        slot = null;
    };
    try master_inbox.receive(&slot, null);
    try helpers.expect(error.WorkerFinishFailed, Mbox.is_it_you(slot.?.*.tag), "expected an Mbox");
    try helpers.expect(error.WorkerFinishFailed, Mbox.mustFromPoly(slot.?) == worker_mbx, "wrong mailbox returned");
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
const Mbox = matryoshka.Mbox;
