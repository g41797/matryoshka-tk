// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Wake blocked receiver without a message.
//!
//! - Worker thread blocks in mailbox.receive with no item ever sent.
//! - Coordinator flips a shutdown flag, then calls mailbox.wakeUpAll —
//!   no item is sent, no message crosses the mailbox.
//! - Worker wakes with error.Wakeup, re-checks the flag, exits.
//!
//!
//! ```
//!  worker thread
//!  mailbox.receive (blocks — mailbox stays empty)
//!       │
//!  coordinator: shutdown.store(true) ──► mailbox.wakeUpAll
//!       │ error.Wakeup
//!       ▼
//!  worker re-checks shutdown flag ──► exits
//! ```
//!

pub fn wake_blocked_receiver_without_a_message(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbh: MailboxHandle = try mailbox.new(io, allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh);
        items.freeList(&rem, allocator);
        mailbox.destroy(mbh, allocator);
    }

    var ctx: WorkerCtx = .{ .mbh = mbh };
    var fut = try io.concurrent(workerFn, .{&ctx});

    // Give the worker time to reach mailbox.receive and block.
    std.Io.Timeout.sleep(.{ .duration = .{ .raw = .{ .nanoseconds = 50_000_000 }, .clock = .real } }, io) catch {};

    ctx.shutdown.store(true, .release);
    try mailbox.wakeUpAll(mbh);

    fut.await(io);

    std.log.info("wake up all: worker woke on error.Wakeup, saw shutdown flag, exited", .{});
    try helpers.expect(error.WakeUpAllFailed, ctx.woke_on_wakeup, "worker did not see error.Wakeup");
}

const WorkerCtx = struct {
    mbh: MailboxHandle,
    shutdown: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    woke_on_wakeup: bool = false,
};

fn workerFn(ctx: *WorkerCtx) void {
    var slot: Slot = null;
    mailbox.receive(ctx.mbh, &slot, null) catch |err| {
        if (err == error.Wakeup and ctx.shutdown.load(.acquire)) {
            ctx.woke_on_wakeup = true;
        }
        return;
    };
}

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const polynode = matryoshka.polynode;
const mailbox = matryoshka.mailbox;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
