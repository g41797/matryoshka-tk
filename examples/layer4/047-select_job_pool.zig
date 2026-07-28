// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Job pool pattern.
//!
//! - Master pre-loads a job queue, seeds the pool with N empty containers.
//! - dispatchJobs: pool availability (getWaitResult) gates dispatch to N workers.
//! - Each worker doubles its job's code, returns the container via pool.put.
//! - shutdown closes all worker mailboxes, awaits every worker future.
//!
//!
//! ```
//!  Master job queue: [{code=10},{code=20},{code=30}] (pre-loaded before loop)
//!  pool (N empty containers seeded)
//!  │ getWaitResult — triggers when a container is returned by a worker (or initially available)
//!  ▼
//!  Select(MasterEvent)
//!  │
//!  .pool_ev .item ──► pop job from Master queue ──► fill container ──► mailbox.send ──► mbh[worker_i]
//!                 ──► re-spawn getWaitResult (until queue exhausted)
//!                 ──► break (queue empty — no more jobs to dispatch)
//!  │
//!  worker[i]: mailbox.receive ──► process (code *= 2) ──► pool.put ──► pool (triggers next pool_ev)
//!  │
//!  master: mailbox.close (×N) ──► workers exit ──► futs.await
//!  pool.close ──► on_close ──► freeList (returns all remaining containers)
//! ```
//!
//!  Pool availability gates job submission. Work input: Master's pre-loaded queue.
//!  Pool provides empty containers. One container per in-flight job.
//!  Master dispatches jobs until queue exhausted, then shuts down workers.
//!

pub fn job_pool_pattern(allocator: std.mem.Allocator, io: std.Io) !void {
    const master = try JobPoolMaster.init(allocator, io);
    defer master.destroy();
    try master.run();
}

const N: usize = 3;

// Master's pre-loaded job queue — separate from pool containers.
const jobs = [N]i32{ 10, 20, 30 };

const WorkerCtx = struct {
    mbh: MailboxHandle,
    ph: PoolHandle,
    id: usize,
};

fn workerFn(ctx: *WorkerCtx) anyerror!void {
    while (true) {
        var slot: Slot = null;
        mailbox.receive(ctx.mbh, &slot, null) catch return;
        defer pool.put(ctx.ph, &slot); // return container to pool — triggers next pool_ev
        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
        ev.code *= 2; // process: double the job value
        std.log.info("worker {d}: processed job, result code={d}", .{ ctx.id, ev.code });
    }
}

const MasterEvent = union(enum) {
    pool_ev: pool.PoolResult,
};

const JobPoolMaster = struct {
    fn run(self: *JobPoolMaster) !void {
        try self.seedPool();
        const job_idx: usize = try self.dispatchJobs();
        try self.shutdown();
        try helpers.expect(error.SelectJobPoolFailed, job_idx == N, "not all jobs dispatched");
        std.log.info("done: {d} jobs dispatched — Master queue → pool containers → worker mailboxes (pool gated)", .{job_idx});
    }

    fn seedPool(self: *JobPoolMaster) !void {
        for (0..N) |_| {
            var slot: Slot = null;
            try pool.get(self.ph, items.Event.EventPolyHelper.TAG, .new_only, &slot);
            pool.put(self.ph, &slot);
        }
    }

    fn dispatchJobs(self: *JobPoolMaster) !usize {
        var buf: [N + 1]MasterEvent = undefined;
        var sel: std.Io.Select(MasterEvent) = std.Io.Select(MasterEvent).init(self.io, &buf);
        try sel.concurrent(.pool_ev, pool.getWaitResult, .{ self.ph, items.Event.EventPolyHelper.TAG, null });

        var job_idx: usize = 0;
        var worker_i: usize = 0;

        while (job_idx < N) {
            const event: MasterEvent = try sel.await();
            switch (event) {
                .pool_ev => |r| switch (r) {
                    .item => |handle| {
                        var slot: Slot = handle;
                        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
                        ev.code = jobs[job_idx];
                        std.log.info("master: dispatching job {d} (code={d}) to worker {d}", .{ job_idx, ev.code, worker_i });
                        try mailbox.send(self.mbhs[worker_i], &slot);
                        job_idx += 1;
                        worker_i = (worker_i + 1) % N;
                        if (job_idx < N) {
                            try sel.concurrent(.pool_ev, pool.getWaitResult, .{ self.ph, items.Event.EventPolyHelper.TAG, null });
                        }
                    },
                    .closed, .canceled, .timeout, .not_created => break,
                },
            }
        }
        sel.cancelDiscard();
        return job_idx;
    }

    fn shutdown(self: *JobPoolMaster) !void {
        for (0..N) |i| {
            var rem: std.DoublyLinkedList = mailbox.close(self.mbhs[i]);
            items.freeList(&rem, self.allocator);
        }
        for (0..N) |i| try self.futs[i].await(self.io);
    }

    allocator: std.mem.Allocator,
    io: std.Io,
    ph: PoolHandle,
    pool_ctx: hooks.AlwaysCreateHooks,
    tags: [1]*const anyopaque,
    mbhs: [N]MailboxHandle,
    ctxs: [N]WorkerCtx,
    futs: [N]std.Io.Future(anyerror!void),

    fn init(allocator: std.mem.Allocator, io: std.Io) !*JobPoolMaster {
        const self = try allocator.create(JobPoolMaster);
        errdefer allocator.destroy(self);
        self.allocator = allocator;
        self.io = io;
        self.pool_ctx = .{ .alloc = allocator };
        self.tags = .{items.Event.EventPolyHelper.TAG};
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
            self.ctxs[i] = .{ .mbh = self.mbhs[i], .ph = self.ph, .id = i };
            self.futs[i] = try io.concurrent(workerFn, .{&self.ctxs[i]});
        }
        return self;
    }

    fn destroy(self: *JobPoolMaster) void {
        pool.close(self.ph);
        pool.destroy(self.ph, self.allocator);
        for (0..N) |i| mailbox.destroy(self.mbhs[i], self.allocator);
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
