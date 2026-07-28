// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Cancel reports, Master decides.
//!
//! - Phase 1: two mailboxes in Select, timer triggers first (both empty).
//! - sel.cancel() reports both as .canceled — mailboxes stay open.
//! - Master decides: close mbh1 permanently, keep mbh2 for phase 2.
//! - Phase 2: fresh Select on mbh2 only, sends and receives 2 items.
//!
//!
//! ```
//!  mbh1 (empty)    mbh2 (empty)
//!  │ receiveResult  │ receiveResult
//!  └────────┬───────┘
//!            ▼
//!  Select(MasterEvent) ◄── sleepFn (timer triggers first — both mailboxes empty)
//!  │
//!  .timer ──► sel.cancel() loop
//!             .inbox1 .canceled ──► master decides: close mbh1 permanently
//!             .inbox2 .canceled ──► master decides: keep mbh2, re-spawn later
//!  │
//!  Phase 2: new Select, mbh2 only
//!  send 2 items to mbh2 ──► receive them via fresh Select
//! ```
//!

pub fn cancel_reports_master_decides(allocator: std.mem.Allocator, io: std.Io) !void {
    const master = try CancelDecideMaster.init(allocator, io);
    defer master.destroy();
    try master.run();
}

const TIMER_NS: i96 = 6_000_000; // 6 ms — triggers first (both mailboxes are empty)

const MasterEvent = union(enum) {
    inbox1: mailbox.ReceiveResult,
    inbox2: mailbox.ReceiveResult,
    timer: void,
};

fn sleepFn(sleep_t: std.Io.Timeout, io: std.Io) void {
    std.Io.Timeout.sleep(sleep_t, io) catch {};
}

const CancelDecideMaster = struct {
    fn run(self: *CancelDecideMaster) !void {
        const respawn_inbox2: bool = try self.phase1Cancel();
        try helpers.expect(error.SelectCancelMasterDecidesFailed, self.mbh1_closed, "mbh1 should be closed");
        try helpers.expect(error.SelectCancelMasterDecidesFailed, respawn_inbox2, "expected inbox2 to be canceled");
        const items_after: usize = try self.phase2Receive();
        try helpers.expect(error.SelectCancelMasterDecidesFailed, items_after == 2, "expected 2 items from mbh2 in phase 2");
        std.log.info("done: mbh1 closed; mbh2 continued with {d} items in phase 2", .{items_after});
    }

    fn phase1Cancel(self: *CancelDecideMaster) !bool {
        const sleep_t: std.Io.Timeout = .{
            .duration = .{ .raw = .{ .nanoseconds = TIMER_NS }, .clock = .real },
        };
        var buf: [8]MasterEvent = undefined;
        var sel: std.Io.Select(MasterEvent) = std.Io.Select(MasterEvent).init(self.io, &buf);
        defer sel.cancelDiscard();

        try sel.concurrent(.inbox1, mailbox.receiveResult, .{ self.mbh1, null });
        try sel.concurrent(.inbox2, mailbox.receiveResult, .{ self.mbh2, null });
        try sel.concurrent(.timer, sleepFn, .{ sleep_t, self.io });

        const first: MasterEvent = try sel.await();
        try helpers.expect(error.SelectCancelMasterDecidesFailed, first == .timer, "expected timer to trigger first");
        std.log.info("timer: making per-source decisions", .{});

        var respawn_inbox2: bool = false;
        while (sel.cancel()) |event| {
            switch (event) {
                .inbox1 => |r| switch (r) {
                    .canceled, .closed => {
                        std.log.info("inbox1: stopped — master closes mbh1", .{});
                        var rem: std.DoublyLinkedList = mailbox.close(self.mbh1);
                        items.freeList(&rem, self.allocator);
                        self.mbh1_closed = true;
                    },
                    .item => |handle| {
                        var slot: Slot = handle;
                        items.freeSlot(&slot, self.allocator);
                    },
                    .timeout, .wakeup => {},
                },
                .inbox2 => |r| switch (r) {
                    .canceled => {
                        std.log.info("inbox2: canceled — master will continue using mbh2", .{});
                        respawn_inbox2 = true;
                    },
                    .item => |handle| {
                        var slot: Slot = handle;
                        items.freeSlot(&slot, self.allocator);
                    },
                    .closed, .timeout, .wakeup => {},
                },
                .timer => {},
            }
        }
        return respawn_inbox2;
    }

    fn phase2Receive(self: *CancelDecideMaster) !usize {
        for (0..2) |i| {
            var slot: Slot = null;
            defer items.Event.EventPolyHelper.destroy(self.allocator, &slot);
            try items.Event.EventPolyHelper.create(self.allocator, &slot);
            items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 10);
            try mailbox.send(self.mbh2, &slot);
        }

        var buf2: [4]MasterEvent = undefined;
        var sel2: std.Io.Select(MasterEvent) = std.Io.Select(MasterEvent).init(self.io, &buf2);
        defer sel2.cancelDiscard();

        try sel2.concurrent(.inbox2, mailbox.receiveResult, .{ self.mbh2, null });

        var items_after: usize = 0;
        while (items_after < 2) {
            const event: MasterEvent = try sel2.await();
            switch (event) {
                .inbox2 => |r| switch (r) {
                    .item => |handle| {
                        var slot: Slot = handle;
                        defer items.freeSlot(&slot, self.allocator);
                        items_after += 1;
                        std.log.info("inbox2 phase2: item code={d}", .{items.Event.EventPolyHelper.mustFromSlot(&slot).code});
                        if (items_after < 2) {
                            try sel2.concurrent(.inbox2, mailbox.receiveResult, .{ self.mbh2, null });
                        }
                    },
                    .closed, .canceled, .timeout, .wakeup => break,
                },
                else => break,
            }
        }
        return items_after;
    }

    allocator: std.mem.Allocator,
    io: std.Io,
    mbh1: MailboxHandle,
    mbh2: MailboxHandle,
    mbh1_closed: bool,

    fn init(allocator: std.mem.Allocator, io: std.Io) !*CancelDecideMaster {
        const self = try allocator.create(CancelDecideMaster);
        errdefer allocator.destroy(self);
        self.allocator = allocator;
        self.io = io;
        self.mbh1_closed = false;
        self.mbh1 = try mailbox.new(io, allocator);
        errdefer {
            var rem: std.DoublyLinkedList = mailbox.close(self.mbh1);
            items.freeList(&rem, allocator);
            mailbox.destroy(self.mbh1, allocator);
        }
        self.mbh2 = try mailbox.new(io, allocator);
        return self;
    }

    fn destroy(self: *CancelDecideMaster) void {
        if (!self.mbh1_closed) {
            var rem: std.DoublyLinkedList = mailbox.close(self.mbh1);
            items.freeList(&rem, self.allocator);
        }
        mailbox.destroy(self.mbh1, self.allocator);
        var rem2: std.DoublyLinkedList = mailbox.close(self.mbh2);
        items.freeList(&rem2, self.allocator);
        mailbox.destroy(self.mbh2, self.allocator);
        self.allocator.destroy(self);
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
