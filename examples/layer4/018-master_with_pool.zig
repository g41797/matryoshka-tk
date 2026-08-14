// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Master with Pool.
//!
//! - Master owns a pool (with hooks) and a mailbox.
//! - sendItems fills 3 pool items with Event data, sends each into the mailbox.
//! - Worker loops on mbx.receive, returns each item to the pool via pl.put.
//! - Shutdown cancels the worker future, then destroy releases pool and mailbox in order.
//!
//!
//! ```
//!  master ──pl.get──► slot ──mbx.send──► mailbox
//!                                                 │ worker (io.concurrent)
//!                                                 │ mbx.receive ──► slot
//!                                                 │ pl.put (defer) ──► pool (recycled)
//!  fut.cancel ──► worker exits at next mbx.receive
//!  master.destroy ──► pl.close ──► mbx.close ──► free remaining
//! ```
//!

pub fn master_with_pool(allocator: std.mem.Allocator, io: std.Io) !void {
    const master = try MasterWithPool.init(allocator, io);
    defer master.destroy();
    try master.run();
}

const WorkerCtx = struct {
    mbx: *Mbox,
    pl: *Pool,
};

fn workerFn(ctx: *WorkerCtx) anyerror!void {
    while (true) {
        var slot: Slot = null;
        defer ctx.pl.put(&slot);
        ctx.mbx.receive(&slot, null) catch return;
    }
}

const MasterWithPool = struct {
    fn run(self: *MasterWithPool) !void {
        try self.sendItems();
        var fut = try self.io.concurrent(workerFn, .{&self.worker_ctx});
        fut.cancel(self.io) catch {};
        std.log.info("master: worker stopped", .{});
    }

    fn sendItems(self: *MasterWithPool) !void {
        for (0..3) |i| {
            var slot: Slot = null;
            defer self.pl.put(&slot);
            try self.pl.get(items.Event.EventPolyHelper.TAG, .available_or_new, &slot);
            const ev = items.Event.EventPolyHelper.mustFromSlot(&slot);
            ev.code = @intCast(i + 1);
            std.log.info("master: sending Event code={d}", .{ev.code});
            try self.mbx.send(&slot);
        }
    }

    allocator: std.mem.Allocator,
    io: std.Io,
    pool_ctx: hooks.AlwaysCreateHooks,
    tags: [1]*const anyopaque,
    pl: *Pool,
    mbx: *Mbox,
    worker_ctx: WorkerCtx,

    fn init(allocator: std.mem.Allocator, io: std.Io) !*MasterWithPool {
        const self = try allocator.create(MasterWithPool);
        errdefer allocator.destroy(self);
        self.allocator = allocator;
        self.io = io;
        self.pool_ctx = .{ .alloc = allocator };
        self.tags = .{items.Event.EventPolyHelper.TAG};

        var pl_slot: Slot = null;
        try pool.new(io, allocator, self.pool_ctx.poolHooks(&self.tags), &pl_slot);
        self.pl = Pool.moveFromSlot(&pl_slot).?;
        errdefer {
            self.pl.close();
            pool.destroy(self.pl, allocator);
        }

        var mbx_slot: Slot = null;
        try mailbox.new(io, allocator, &mbx_slot);
        self.mbx = Mbox.moveFromSlot(&mbx_slot).?;

        self.worker_ctx = .{ .mbx = self.mbx, .pl = self.pl };
        return self;
    }

    fn destroy(self: *MasterWithPool) void {
        self.pl.close();
        pool.destroy(self.pl, self.allocator);
        var rem: polynode.ItemList = self.mbx.close();
        items.freeList(&rem, self.allocator);
        mailbox.destroy(self.mbx, self.allocator);
        self.allocator.destroy(self);
    }
};

const items = @import("../items/items.zig");
const hooks = @import("../hooks/hooks.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const Mbox = matryoshka.Mbox;
const pool = matryoshka.pool;
const Pool = matryoshka.Pool;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
