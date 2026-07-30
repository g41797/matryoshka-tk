// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Multiple event sources, one mailbox.
//!
//! - Timer task, event sender, and signal sender all send into one mailbox.
//! - Worker has a single receive loop, dispatches on tag.
//! - Senders finish, then the mailbox is closed to end the worker.
//! - Ctx groups the flow: spawnSenders, then awaitSendersAndClose.
//!
//!
//! ```
//!  timerSenderFn ──Timer×2──►
//!  eventSenderFn ──Event×3──► mailbox ──► workerFn (tag dispatch; close-based exit)
//!  signalSenderFn ──ShutdownCommand──►
//!  senders await → mailbox.close → workerFn exits → fut_worker.await
//! ```
//!

pub fn multiple_event_sources_one_mailbox(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbh: MailboxHandle = try mailbox.new(io, allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh);
        items.freeList(&rem, allocator);
        mailbox.destroy(mbh, allocator);
    }

    var sender_ctx: SenderCtx = .{ .mbh = mbh, .alloc = allocator, .io = io };
    var worker_ctx: WorkerCtx = .{ .mbh = mbh, .alloc = allocator };
    var ctx: Ctx = .{ .mbh = mbh, .alloc = allocator, .io = io };
    var futs = try ctx.spawnSenders(&sender_ctx, &worker_ctx);
    ctx.awaitSendersAndClose(&futs);

    std.log.info("done: {d} events, {d} timer ticks, {d} signals — fan-in to one mailbox", .{
        worker_ctx.event_count,
        worker_ctx.timer_count,
        worker_ctx.signal_count,
    });
}

const TICK_NS: i96 = 20_000_000; // 20 ms
const N_EVENTS: usize = 3;
const N_TICKS: usize = 2;

const SenderCtx = struct {
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,
    io: std.Io,
};

fn timerSenderFn(ctx: *SenderCtx) anyerror!void {
    const sleep_t: std.Io.Timeout = .{
        .duration = .{ .raw = .{ .nanoseconds = TICK_NS }, .clock = .real },
    };
    for (0..N_TICKS) |_| {
        try std.Io.Timeout.sleep(sleep_t, ctx.io);
        var slot: Slot = null;
        try items.Timer.TimerPolyHelper.create(ctx.alloc, &slot);
        mailbox.send(ctx.mbh, &slot) catch {
            items.freeSlot(&slot, ctx.alloc);
            return;
        };
    }
}

fn eventSenderFn(ctx: *SenderCtx) anyerror!void {
    for (0..N_EVENTS) |i| {
        var slot: Slot = null;
        try items.Event.EventPolyHelper.create(ctx.alloc, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
        mailbox.send(ctx.mbh, &slot) catch {
            items.freeSlot(&slot, ctx.alloc);
            return;
        };
    }
}

fn signalSenderFn(ctx: *SenderCtx) anyerror!void {
    var slot: Slot = null;
    try items.ShutdownCommand.ShutdownCommandPolyHelper.create(ctx.alloc, &slot);
    mailbox.send(ctx.mbh, &slot) catch items.freeSlot(&slot, ctx.alloc);
}

const WorkerCtx = struct {
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,
    timer_count: usize = 0,
    event_count: usize = 0,
    signal_count: usize = 0,
};

fn workerFn(ctx: *WorkerCtx) anyerror!void {
    while (true) {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        mailbox.receive(ctx.mbh, &slot, null) catch return;

        if (items.Timer.TimerPolyHelper.fromSlot(&slot)) |_| {
            ctx.timer_count += 1;
            std.log.info("worker: timer tick {d}", .{ctx.timer_count});
        } else if (items.Event.EventPolyHelper.fromSlot(&slot)) |ev| {
            ctx.event_count += 1;
            std.log.info("worker: Event code={d}", .{ev.code});
        } else if (items.ShutdownCommand.ShutdownCommandPolyHelper.fromSlot(&slot)) |_| {
            ctx.signal_count += 1;
            std.log.info("worker: ShutdownCommand signal", .{});
        }
    }
}

const Futs = struct {
    timer: Io.Future(anyerror!void),
    events: Io.Future(anyerror!void),
    signal: Io.Future(anyerror!void),
    worker: Io.Future(anyerror!void),
};

const Ctx = struct {
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,
    io: std.Io,

    fn spawnSenders(self: *Ctx, sender_ctx: *SenderCtx, worker_ctx: *WorkerCtx) !Futs {
        return .{
            .timer = try self.io.concurrent(timerSenderFn, .{sender_ctx}),
            .events = try self.io.concurrent(eventSenderFn, .{sender_ctx}),
            .signal = try self.io.concurrent(signalSenderFn, .{sender_ctx}),
            .worker = try self.io.concurrent(workerFn, .{worker_ctx}),
        };
    }

    fn awaitSendersAndClose(self: *Ctx, futs: *Futs) void {
        futs.timer.await(self.io) catch {};
        futs.events.await(self.io) catch {};
        futs.signal.await(self.io) catch {};

        var remaining: polynode.ItemList = mailbox.close(self.mbh);
        items.freeList(&remaining, self.alloc);

        futs.worker.await(self.io) catch {};
    }
};

const items = @import("../items/items.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
const Io = std.Io;
