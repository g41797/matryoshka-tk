// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Receive router — one registration, many events.
//!
//! - seedPool: pre-fills the pool with P items. P is the number in flight.
//! - startProducer: producer takes an item with get_wait, fills it, sends it.
//! - setupSelect: registers the router once, and a timer.
//! - eventLoop: Master handles items and puts them back. It never re-registers
//!   the router. It does re-register the timer, every time.
//! - closeMailbox: after M items, the mailbox closes. The router finishes.
//! - shutdown: walks the Select, then closes the pool, then the mailbox.
//!
//!
//! ```
//!  pool (P items, pre-filled)
//!  │ get_wait ──► producer fills ──► mailbox.send
//!  ▼
//!  mailbox
//!  │ receiveResult
//!  ▼
//!  receive_router ──► sel.queue.putOneUncancelable ──► Select queue
//!         │ loops. one registration covers every item.
//!         └──► returns .closed ──► Select wraps it ──► Select queue
//!  │
//!  Master: .inbox .item ──► read code ──► pool.put ──► pool
//!                       ──► no re-registration
//!          .timer       ──► re-register the timer
//!          .inbox .closed ──► leave the loop
//!  │
//!  shutdown: sel.cancel walk ──► pool.close ──► mailbox.close
//! ```
//!
//!  The timer branch re-registers. The router branch does not. That is the
//!  whole difference.
//!
//!  Buffer size is a precondition: N >= P + T. P items can be in flight, and
//!  each of the T registered tasks needs a slot for its final value.
//!

pub fn receive_router_one_registration(allocator: std.mem.Allocator, io: std.Io) !void {
    const master = try RouterMaster.init(allocator, io);
    defer master.destroy();
    try master.run();
}

/// Items in flight. Fixed by the pre-filled pool.
const P: usize = 2;

/// Tasks registered in the Select: the router, and the timer.
const T: usize = 2;

/// Select buffer length. The precondition, written as code.
const N: usize = P + T;

/// Items the producer sends.
const M: usize = 6;

const TIMER_NS: i96 = 100_000;

/// Producer pace. Keeps the run long enough for the timer to tick.
const PRODUCE_NS: i96 = 300_000;

const MasterEvent = union(enum) {
    inbox: mailbox.ReceiveResult,
    timer: void,
};

/// Receives in a loop. Puts each result in the Select queue.
///
/// The router is application code. It disposes of the one item it holds.
/// It does not close the mailbox. It does not clear what is still inside.
///
/// It never returns an item. Select puts the return value in the queue, and
/// throws it away if the queue is closed by then. Only the reason for
/// stopping rides out on the return.
fn receive_router(
    mbh: MailboxHandle,
    timeout_ns: ?u64,
    sel: *std.Io.Select(MasterEvent),
    ph: PoolHandle,
    alloc: std.mem.Allocator,
) mailbox.ReceiveResult {
    while (true) {
        const result: mailbox.ReceiveResult = mailbox.receiveResult(mbh, timeout_ns);

        var held: Slot = switch (result) {
            .item => |handle| handle,
            else => null,
        };
        defer {
            pool.put(ph, &held); // back to the pool
            items.freeSlot(&held, alloc); // pool closed — nowhere to put it back
        }

        switch (result) {
            .closed, .canceled => return result,
            .item, .timeout, .wakeup => {},
        }

        sel.queue.putOneUncancelable(sel.io, .{ .inbox = result }) catch return .canceled;

        held = null; // the queue has it now
    }
}

fn sleepFn(sleep_t: std.Io.Timeout, io: std.Io) void {
    std.Io.Timeout.sleep(sleep_t, io) catch {};
}

const ProducerCtx = struct {
    mbh: MailboxHandle,
    ph: PoolHandle,
    io: std.Io,
};

fn producerFn(ctx: *ProducerCtx) void {
    for (0..M) |i| {
        sleepFn(.{ .duration = .{ .raw = .{ .nanoseconds = PRODUCE_NS }, .clock = .real } }, ctx.io);
        var slot: Slot = null;
        pool.get_wait(ctx.ph, items.Event.EventPolyHelper.TAG, &slot, null) catch return;
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
        mailbox.send(ctx.mbh, &slot) catch {
            pool.put(ctx.ph, &slot);
            return;
        };
    }
}

const RouterMaster = struct {
    fn run(self: *RouterMaster) !void {
        try self.seedPool();
        try self.startProducer();
        try self.setupSelect();
        try self.eventLoop();
        try self.shutdown();
        try helpers.expect(error.ReceiveRouterFailed, self.inbox_count == M, "not all items routed");
        try helpers.expect(error.ReceiveRouterFailed, self.registrations == 1, "router registered more than once");
        try helpers.expect(error.ReceiveRouterFailed, self.timer_count > 0, "timer never re-registered");
        std.log.info(
            "done: {d} items through one router registration, {d} timer re-registrations",
            .{ self.inbox_count, self.timer_count },
        );
    }

    fn timerTimeout() std.Io.Timeout {
        return .{ .duration = .{ .raw = .{ .nanoseconds = TIMER_NS }, .clock = .real } };
    }

    fn seedPool(self: *RouterMaster) !void {
        for (0..P) |_| {
            var slot: Slot = null;
            try pool.get(self.ph, items.Event.EventPolyHelper.TAG, .new_only, &slot);
            pool.put(self.ph, &slot);
        }
    }

    fn startProducer(self: *RouterMaster) !void {
        self.producer_ctx = .{ .mbh = self.mbh, .ph = self.ph, .io = self.io };
        self.producer_fut = try self.io.concurrent(producerFn, .{&self.producer_ctx});
    }

    fn setupSelect(self: *RouterMaster) !void {
        self.sel = std.Io.Select(MasterEvent).init(self.io, &self.buf);
        try self.sel.concurrent(.inbox, receive_router, .{
            self.mbh,
            null,
            &self.sel,
            self.ph,
            self.allocator,
        });
        self.registrations += 1;
        try self.sel.concurrent(.timer, sleepFn, .{ timerTimeout(), self.io });
    }

    fn eventLoop(self: *RouterMaster) !void {
        while (true) {
            const event: MasterEvent = try self.sel.await();
            switch (event) {
                .inbox => |result| switch (result) {
                    .item => |handle| {
                        self.acceptItem(handle);
                        if (self.inbox_count == M) self.closeMailbox();
                    },
                    .closed, .canceled, .timeout, .wakeup => return,
                },
                .timer => {
                    self.timer_count += 1;
                    try self.sel.concurrent(.timer, sleepFn, .{ timerTimeout(), self.io });
                },
            }
        }
    }

    /// Reads the item, then puts it back. The pool slot frees the producer.
    fn acceptItem(self: *RouterMaster, handle: ItemHandle) void {
        var slot: Slot = handle;
        defer pool.put(self.ph, &slot);
        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
        self.inbox_count += 1;
        std.log.info("master: item {d} of {d}, code={d}", .{ self.inbox_count, M, ev.code });
    }

    /// Ends the stream. The router sees `.closed` and finishes.
    fn closeMailbox(self: *RouterMaster) void {
        var rem: polynode.ItemList = mailbox.close(self.mbh);
        pool.put_all(self.ph, &rem);
        items.freeList(&rem, self.allocator);
    }

    /// Walks the Select first. Parked events carry items.
    ///
    /// The pool closes only after the router has finished, so the router
    /// always has somewhere to put its last item.
    fn shutdown(self: *RouterMaster) !void {
        while (self.sel.cancel()) |event| {
            switch (event) {
                .inbox => |result| switch (result) {
                    .item => |handle| {
                        var slot: Slot = handle;
                        pool.put(self.ph, &slot);
                        items.freeSlot(&slot, self.allocator);
                    },
                    .closed, .canceled, .timeout, .wakeup => {},
                },
                .timer => {},
            }
        }
        self.producer_fut.await(self.io);
    }

    allocator: std.mem.Allocator,
    io: std.Io,
    ph: PoolHandle,
    mbh: MailboxHandle,
    pool_ctx: hooks.AlwaysCreateHooks,
    tags: [1]*const anyopaque,
    buf: [N]MasterEvent,
    sel: std.Io.Select(MasterEvent),
    producer_ctx: ProducerCtx,
    producer_fut: std.Io.Future(void),
    inbox_count: usize,
    timer_count: usize,
    registrations: usize,

    fn init(allocator: std.mem.Allocator, io: std.Io) !*RouterMaster {
        const self = try allocator.create(RouterMaster);
        errdefer allocator.destroy(self);
        self.allocator = allocator;
        self.io = io;
        self.inbox_count = 0;
        self.timer_count = 0;
        self.registrations = 0;
        self.pool_ctx = .{ .alloc = allocator };
        self.tags = .{items.Event.EventPolyHelper.TAG};
        self.ph = try pool.new(io, allocator);
        errdefer {
            pool.close(self.ph);
            pool.destroy(self.ph, allocator);
        }
        try pool.init(self.ph, self.pool_ctx.poolHooks(&self.tags));
        self.mbh = try mailbox.new(io, allocator);
        return self;
    }

    fn destroy(self: *RouterMaster) void {
        var rem: polynode.ItemList = mailbox.close(self.mbh);
        items.freeList(&rem, self.allocator);
        mailbox.destroy(self.mbh, self.allocator);
        pool.close(self.ph);
        pool.destroy(self.ph, self.allocator);
        self.allocator.destroy(self);
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
const ItemHandle = polynode.ItemHandle;
const MailboxHandle = mailbox.MailboxHandle;
const PoolHandle = pool.PoolHandle;
