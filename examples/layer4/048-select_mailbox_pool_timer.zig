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
//!  .pool_ev .item ──► pl.put
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
    inbox: Mbox.Result,
    pool_ev: Pool.Result,
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
        try self.sel.concurrent(.inbox, mailbox.receiveResult, .{ self.mbx, null });
        try self.sel.concurrent(.pool_ev, pool.getWaitResult, .{ self.pl, items.Event.EventPolyHelper.TAG, null });
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
                            try self.sel.concurrent(.inbox, mailbox.receiveResult, .{ self.mbx, null });
                        }
                    },
                    .closed, .canceled, .timeout, .wakeup => break,
                },
                .pool_ev => |r| switch (r) {
                    .item => |handle| {
                        var slot: Slot = handle;
                        defer self.pl.put(&slot);
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
    mbx: *Mbox,
    pl: *Pool,
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
        self.mbx = try mailbox.new(io, allocator);
        errdefer {
            var rem: polynode.ItemList = self.mbx.close();
            items.freeList(&rem, allocator);
            mailbox.destroy(self.mbx, allocator);
        }
        self.pool_ctx = .{ .alloc = allocator };
        self.tags = .{items.Event.EventPolyHelper.TAG};
        self.pl = try pool.new(io, allocator);
        errdefer {
            self.pl.close();
            pool.destroy(self.pl, allocator);
        }
        try self.pl.init(self.pool_ctx.poolHooks(&self.tags));
        try self.seedResources();
        self.sel = std.Io.Select(MasterEvent).init(self.io, &self.buf);
        return self;
    }

    fn destroy(self: *MailboxPoolTimerMaster) void {
        var rem: polynode.ItemList = self.mbx.close();
        items.freeList(&rem, self.allocator);
        mailbox.destroy(self.mbx, self.allocator);
        self.pl.close();
        pool.destroy(self.pl, self.allocator);
        self.allocator.destroy(self);
    }

    fn seedResources(self: *MailboxPoolTimerMaster) !void {
        for (0..2) |i| {
            var slot: Slot = null;
            defer items.Event.EventPolyHelper.destroy(self.allocator, &slot);
            try items.Event.EventPolyHelper.create(self.allocator, &slot);
            items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
            try self.mbx.send(&slot);
        }
        {
            var slot: Slot = null;
            try self.pl.get(items.Event.EventPolyHelper.TAG, .new_only, &slot);
            items.Event.EventPolyHelper.mustFromSlot(&slot).code = 10;
            self.pl.put(&slot);
        }
    }
};

const items = @import("../items/items.zig");
const hooks = @import("../hooks/hooks.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const Mbox = matryoshka.Mbox;
const pool = matryoshka.pool;
const Pool = matryoshka.Pool;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
