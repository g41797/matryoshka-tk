// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Timer cancel → close → walk remaining.
//!
//! - Two mailboxes + timer in Select, both mailboxes empty.
//! - Timer triggers first, calls sel.cancel() on both mailbox sources.
//! - Both return .canceled; cancel and close are kept as separate operations.
//! - Both mailboxes are then closed, remaining items freed via freeList.
//!
//!
//! ```
//!  mbh1 (empty)    mbh2 (empty)
//!  │ receiveResult  │ receiveResult
//!  └────────┬───────┘
//!           ▼
//!  Select(MasterEvent) ◄── sleepFn (short timer triggers first)
//!  │
//!  .timer ──► sel.cancel() loop
//!             .inbox1 .canceled ──► log
//!             .inbox2 .canceled ──► log
//!  │
//!  mailbox.close(mbh1) ──► freeList
//!  mailbox.close(mbh2) ──► freeList
//! ```
//!

pub fn timer_cancel_close_walk_remaining(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbh1: MailboxHandle = try mailbox.new(io, allocator);
    const mbh2: MailboxHandle = try mailbox.new(io, allocator);
    defer {
        var rem1: polynode.ItemList = mailbox.close(mbh1);
        items.freeList(&rem1, allocator);
        mailbox.destroy(mbh1, allocator);
        var rem2: polynode.ItemList = mailbox.close(mbh2);
        items.freeList(&rem2, allocator);
        mailbox.destroy(mbh2, allocator);
    }

    var buf: [8]MasterEvent = undefined;
    var sel: std.Io.Select(MasterEvent) = std.Io.Select(MasterEvent).init(io, &buf);
    var ctx: Ctx = .{ .mbh1 = mbh1, .mbh2 = mbh2, .alloc = allocator, .io = io };
    try ctx.setupSelect(&sel);
    try Ctx.awaitTimerFirst(&sel);
    ctx.clearCanceled(&sel);

    try helpers.expect(error.SelectCancelCloseFailed, ctx.canceled1 and ctx.canceled2, "expected both inboxes canceled");
    std.log.info("done: timer triggered, sel.cancel() stopped both inbox sources", .{});
}

const TIMER_NS: i96 = 8_000_000; // 8 ms

const MasterEvent = union(enum) {
    inbox1: mailbox.ReceiveResult,
    inbox2: mailbox.ReceiveResult,
    timer: void,
};

fn sleepFn(sleep_t: std.Io.Timeout, io: std.Io) void {
    std.Io.Timeout.sleep(sleep_t, io) catch {};
}

const Ctx = struct {
    mbh1: MailboxHandle,
    mbh2: MailboxHandle,
    alloc: std.mem.Allocator,
    io: std.Io,
    canceled1: bool = false,
    canceled2: bool = false,

    fn setupSelect(self: *Ctx, sel: *std.Io.Select(MasterEvent)) !void {
        const sleep_t: std.Io.Timeout = .{
            .duration = .{ .raw = .{ .nanoseconds = TIMER_NS }, .clock = .real },
        };
        try sel.concurrent(.inbox1, mailbox.receiveResult, .{ self.mbh1, null });
        try sel.concurrent(.inbox2, mailbox.receiveResult, .{ self.mbh2, null });
        try sel.concurrent(.timer, sleepFn, .{ sleep_t, self.io });
    }

    fn awaitTimerFirst(sel: *std.Io.Select(MasterEvent)) !void {
        const first: MasterEvent = try sel.await();
        switch (first) {
            .timer => std.log.info("timer: canceling both inbox sources", .{}),
            else => return error.SelectCancelCloseFailed,
        }
    }

    fn clearCanceled(self: *Ctx, sel: *std.Io.Select(MasterEvent)) void {
        while (sel.cancel()) |event| {
            switch (event) {
                .inbox1 => |r| switch (r) {
                    .canceled => {
                        std.log.info("inbox1: .canceled", .{});
                        self.canceled1 = true;
                    },
                    .item => |handle| {
                        var slot: Slot = handle;
                        items.freeSlot(&slot, self.alloc);
                    },
                    .closed, .timeout, .wakeup => {},
                },
                .inbox2 => |r| switch (r) {
                    .canceled => {
                        std.log.info("inbox2: .canceled", .{});
                        self.canceled2 = true;
                    },
                    .item => |handle| {
                        var slot: Slot = handle;
                        items.freeSlot(&slot, self.alloc);
                    },
                    .closed, .timeout, .wakeup => {},
                },
                .timer => {},
            }
        }
    }
};

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
