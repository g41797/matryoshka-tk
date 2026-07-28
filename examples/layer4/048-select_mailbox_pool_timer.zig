// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Mixed mailbox + pool event sources in Select.
//!
//! - Mailbox pre-loaded with 2 Events, pool seeded with 1 Event, both are Select sources.
//! - eventLoop handles each with a uniform switch, re-spawning after mailbox items.
//! - Timer ticks independently; the loop exits once both targets are met.
//!
//!
//! ```
//!  mailbox (pre-loaded: Event×2)   pool (seeded: Event×1)
//!     │ receiveResult                  │ getWaitResult
//!     └────────────┬───────────────────┘
//!                  ▼
//!         Select(MasterEvent) ◄── sleepFn (timer)
//!                  │ sel.await()
//!                  ▼
//!  .inbox .item ──► freeSlot
//!  .pool_ev .item ──► pool.put
//!  .timer         ──► log tick, re-spawn
//!  done when inbox×2 + pool×1 received ──► sel.cancelDiscard()
//! ```
//!

pub fn mixed_mailbox_pool_event_sources_in_select(allocator: std.mem.Allocator, io: std.Io) !void {
    const master = try MailboxPoolTimerMaster.init(allocator, io);
    defer master.destroy();
    try master.run();
}

const TIMER_NS: i96 = 20_000_000; // 20 ms

const MasterEvent = union(enum) {
    inbox: mailbox.ReceiveResult,
    pool_ev: pool.PoolResult,
    timer: void,
};

fn sleepFn(sleep_t: std.Io.Timeout, io: std.Io) void {
    std.Io.Timeout.sleep(sleep_t, io) catch {};
}

const MailboxPoolTimerMaster = struct {
    fn timerTimeout() std.Io.Timeout {
        return .{ .duration = .{ .raw = .{ .nanoseconds = TIMER_NS }, .clock = .real } };
    }

    fn run(self: *MailboxPoolTimerMaster) !void {
        try self.setupSelect();
        try self.eventLoop();
        try helpers.expect(error.SelectMailboxPoolTimerFailed, self.inbox_count == 2, "mailbox items mismatch");
        try helpers.expect(error.SelectMailboxPoolTimerFailed, self.pool_count == 1, "pool items mismatch");
        std.log.info("done: inbox={d}, pool={d}, ticks={d}", .{ self.inbox_count, self.pool_count, self.ticks });
    }

    fn setupSelect(self: *MailboxPoolTimerMaster) !void {
        try self.sel.concurrent(.inbox, mailbox.receiveResult, .{ self.mbh, null });
        try self.sel.concurrent(.pool_ev, pool.getWaitResult, .{ self.ph, items.Event.EventPolyHelper.TAG, null });
        try self.sel.concurrent(.timer, sleepFn, .{ timerTimeout(), self.io });
    }

    fn eventLoop(self: *MailboxPoolTimerMaster) !void {
        while (self.inbox_count < 2 or self.pool_count < 1) {
            const event: MasterEvent = try self.sel.await();
            switch (event) {
                .inbox => |r| switch (r) {
                    .item => |handle| {
                        var slot: Slot = handle;
                        defer items.freeSlot(&slot, self.allocator);
                        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
                        self.inbox_count += 1;
                        std.log.info("inbox: Event code={d} ({d}/2)", .{ ev.code, self.inbox_count });
                        if (self.inbox_count < 2) {
                            try self.sel.concurrent(.inbox, mailbox.receiveResult, .{ self.mbh, null });
                        }
                    },
                    .closed, .canceled, .timeout, .wakeup => break,
                },
                .pool_ev => |r| switch (r) {
                    .item => |handle| {
                        var slot: Slot = handle;
                        defer pool.put(self.ph, &slot);
                        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
                        self.pool_count += 1;
                        std.log.info("pool_ev: Event code={d} ({d}/1)", .{ ev.code, self.pool_count });
                    },
                    .closed, .canceled, .timeout, .not_created => break,
                },
                .timer => {
                    self.ticks += 1;
                    std.log.info("timer: tick {d}", .{self.ticks});
                    try self.sel.concurrent(.timer, sleepFn, .{ timerTimeout(), self.io });
                },
            }
        }
        self.sel.cancelDiscard();
    }

    allocator: std.mem.Allocator,
    io: std.Io,
    mbh: MailboxHandle,
    ph: PoolHandle,
    pool_ctx: hooks.AlwaysCreateHooks,
    tags: [1]*const anyopaque,
    inbox_count: usize,
    pool_count: usize,
    ticks: usize,
    buf: [8]MasterEvent,
    sel: std.Io.Select(MasterEvent),

    fn init(allocator: std.mem.Allocator, io: std.Io) !*MailboxPoolTimerMaster {
        const self = try allocator.create(MailboxPoolTimerMaster);
        errdefer allocator.destroy(self);
        self.allocator = allocator;
        self.io = io;
        self.inbox_count = 0;
        self.pool_count = 0;
        self.ticks = 0;
        self.mbh = try mailbox.new(io, allocator);
        errdefer {
            var rem: std.DoublyLinkedList = mailbox.close(self.mbh);
            items.freeList(&rem, allocator);
            mailbox.destroy(self.mbh, allocator);
        }
        self.pool_ctx = .{ .alloc = allocator };
        self.tags = .{items.Event.EventPolyHelper.TAG};
        self.ph = try pool.new(io, allocator);
        errdefer {
            pool.close(self.ph);
            pool.destroy(self.ph, allocator);
        }
        try pool.init(self.ph, self.pool_ctx.poolHooks(&self.tags));
        try self.seedResources();
        self.sel = std.Io.Select(MasterEvent).init(self.io, &self.buf);
        return self;
    }

    fn destroy(self: *MailboxPoolTimerMaster) void {
        var rem: std.DoublyLinkedList = mailbox.close(self.mbh);
        items.freeList(&rem, self.allocator);
        mailbox.destroy(self.mbh, self.allocator);
        pool.close(self.ph);
        pool.destroy(self.ph, self.allocator);
        self.allocator.destroy(self);
    }

    fn seedResources(self: *MailboxPoolTimerMaster) !void {
        for (0..2) |i| {
            var slot: Slot = null;
            defer items.Event.EventPolyHelper.destroy(self.allocator, &slot);
            try items.Event.EventPolyHelper.create(self.allocator, &slot);
            items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
            try mailbox.send(self.mbh, &slot);
        }
        {
            var slot: Slot = null;
            try pool.get(self.ph, items.Event.EventPolyHelper.TAG, .new_only, &slot);
            items.Event.EventPolyHelper.mustFromSlot(&slot).code = 10;
            pool.put(self.ph, &slot);
        }
    }
};

const items = @import("../items/items.zig");
const hooks = @import("../hooks/hooks.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const pool = matryoshka.pool;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
const PoolHandle = pool.PoolHandle;
