// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Pool fan-in: many workers return.
//!
//! - Seed the pool with N empty containers, one per worker mailbox.
//! - dispatch fills each container from the Master's job list, sends it to its worker.
//! - Each worker doubles the value, writes it to its results slot, returns the
//!   (now-processed) container to the pool for reuse.
//! - on_put resets the container's data on return — the pool lends reusable
//!   containers, it does not carry results back. Results travel through a
//!   dedicated results array instead, written before each worker's container
//!   goes back to the pool.
//! - collectResults sums the N results array entries after all workers finish.
//!
//!
//! ```
//!  Master job list: [{code=1},{code=2},{code=3}]
//!  pool (N empty containers seeded)
//!  │
//!  master: pool.get ──► fill from job list ──► mailbox.send ──► mbh[0..N]
//!                                                                   │ worker[i] (io.concurrent)
//!                                                                   │ mailbox.receive ──► process ──► results[i] ──► pool.put (on_put resets) ──► pool
//!  master: fut[i].await ──► all workers done
//!  master: sum results[0..N] ──► verify results
//!  pool.close ──► on_close ──► freeList
//! ```
//!
//!  Ownership: Master list → pool containers → worker mailboxes → workers → pool → master.
//!  Pool items are empty containers: Master fills from job list, worker writes result back.
//!

pub fn pool_fan_in_many_workers_return(allocator: std.mem.Allocator, io: std.Io) !void {
    const master = try PoolFanInMaster.init(allocator, io);
    defer master.destroy();
    try master.run();
}

const N: usize = 3;

// Job descriptors — Master's own list, separate from pool containers.
const jobs = [N]i32{ 10, 20, 30 };

const WorkerCtx = struct {
    mbh: MailboxHandle,
    ph: PoolHandle,
    result: *i32,
};

fn workerFn(ctx: *WorkerCtx) anyerror!void {
    var slot: Slot = null;
    mailbox.receive(ctx.mbh, &slot, null) catch return;
    defer pool.put(ctx.ph, &slot); // return container to pool — on_put resets it, doesn't carry the result
    const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
    ev.code *= 2; // process: double the job value
    ctx.result.* = ev.code; // capture the result before the container is reset
    std.log.info("worker: processed job, result code={d}", .{ev.code});
}

const PoolFanInMaster = struct {
    fn run(self: *PoolFanInMaster) !void {
        try self.seedPool();
        try self.dispatch();
        try self.awaitWorkers();
        const result_sum: i32 = self.collectResults();
        try helpers.expect(error.PoolFanInFailed, result_sum == 120, "wrong result sum");
        std.log.info("fan-in: {d} results — Master list → pool → worker mailboxes → results array → master", .{N});
    }

    fn seedPool(self: *PoolFanInMaster) !void {
        for (0..N) |_| {
            var slot: Slot = null;
            try pool.get(self.ph, items.Event.EventPolyHelper.TAG, .new_only, &slot);
            pool.put(self.ph, &slot);
        }
    }

    fn dispatch(self: *PoolFanInMaster) !void {
        for (0..N) |i| {
            var slot: Slot = null;
            try pool.get(self.ph, items.Event.EventPolyHelper.TAG, .available_only, &slot);
            const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
            ev.code = jobs[i];
            std.log.info("master: filled container with job code={d}, sending to worker {d}", .{ ev.code, i });
            try mailbox.send(self.mbhs[i], &slot);
        }
    }

    fn awaitWorkers(self: *PoolFanInMaster) !void {
        for (0..N) |i| try self.futs[i].await(self.io);
    }

    fn collectResults(self: *PoolFanInMaster) i32 {
        var result_sum: i32 = 0;
        for (self.results) |r| {
            result_sum += r;
            std.log.info("master: result code={d}", .{r});
        }
        return result_sum;
    }

    allocator: std.mem.Allocator,
    io: std.Io,
    ph: PoolHandle,
    pool_ctx: hooks.AlwaysCreateHooks,
    tags: [1]*const anyopaque,
    mbhs: [N]MailboxHandle,
    ctxs: [N]WorkerCtx,
    futs: [N]std.Io.Future(anyerror!void),
    results: [N]i32,

    fn init(allocator: std.mem.Allocator, io: std.Io) !*PoolFanInMaster {
        const self = try allocator.create(PoolFanInMaster);
        errdefer allocator.destroy(self);
        self.allocator = allocator;
        self.io = io;
        self.pool_ctx = .{ .alloc = allocator };
        self.tags = .{items.Event.EventPolyHelper.TAG};
        self.results = .{0} ** N;
        self.ph = try pool.new(io, allocator);
        errdefer {
            pool.close(self.ph);
            pool.destroy(self.ph, allocator);
        }
        try pool.init(self.ph, self.pool_ctx.poolHooks(&self.tags));
        var created: usize = 0;
        errdefer for (0..created) |i| {
            var rem: std.DoublyLinkedList = mailbox.close(self.mbhs[i]);
            items.freeList(&rem, allocator);
            mailbox.destroy(self.mbhs[i], allocator);
        };
        for (0..N) |i| {
            self.mbhs[i] = try mailbox.new(io, allocator);
            created += 1;
            self.ctxs[i] = .{ .mbh = self.mbhs[i], .ph = self.ph, .result = &self.results[i] };
            self.futs[i] = try io.concurrent(workerFn, .{&self.ctxs[i]});
        }
        return self;
    }

    fn destroy(self: *PoolFanInMaster) void {
        for (0..N) |i| {
            var rem: std.DoublyLinkedList = mailbox.close(self.mbhs[i]);
            items.freeList(&rem, self.allocator);
            mailbox.destroy(self.mbhs[i], self.allocator);
        }
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
const MailboxHandle = mailbox.MailboxHandle;
const PoolHandle = pool.PoolHandle;
