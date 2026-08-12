// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Job pool circular flow.
//!
//! - Master pre-loads a job list, seeds the pool with 1 container.
//! - runEventLoop: pool availability triggers the next dispatch from the job list.
//! - Worker doubles the value, returns the container — which triggers the next dispatch.
//! - Loop ends once all jobs are dispatched and the last result returns.
//!
//! Transfers (circular):
//!
//! ```
//!  Master job list: [{code=10},{code=20},{code=30}]
//!  pool (1 empty container seeded)
//!  │ getWaitResult drives pace
//!  ▼
//!  master: fill container from job list ──► mbx.send ──► mbx
//!                                                              │ worker
//!                                                              │ process (code *= 2) ──► pl.put ──► pool
//!  pool triggers again ──► master dispatches next job (or breaks when all N sent + last returned)
//! ```
//!
//!  Container circulates: pool → master fills → mailbox → worker → pool.
//!  Work input: Master's pre-loaded job list. Pool provides the container and controls pacing.
//!  Master counter tracks completed jobs.
//!

pub fn job_pool_circular_flow(allocator: std.mem.Allocator, io: std.Io) !void {
    const pl: *Pool = try pool.new(io, allocator);
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};
    try pl.init(pool_ctx.poolHooks(&tags));
    defer {
        pl.close();
        pool.destroy(pl, allocator);
    }

    const mbx: *Mbox = try mailbox.new(io, allocator);
    defer mailbox.destroy(mbx, allocator);

    try seedContainer(pl);

    var ctx: Ctx = .{ .mbx = mbx, .alloc = allocator, .io = io };
    var worker_ctx: WorkerCtx = .{ .mbx = mbx, .pl = pl };
    var buf: [4]MasterEvent = undefined;
    var sel: std.Io.Select(MasterEvent) = std.Io.Select(MasterEvent).init(io, &buf);
    var worker_fut = try ctx.spawnWorkerAndSetupSelect(pl, &worker_ctx, &sel);

    var job_idx: usize = 0;
    var completed: usize = 0;
    try ctx.runEventLoop(pl, &sel, &job_idx, &completed);

    try ctx.closeMailboxAndAwait(&worker_fut);

    try helpers.expect(error.JobPoolCircularFailed, completed == N, "did not complete all jobs");
    std.log.info("done: {d} jobs — Master list → pool container → mailbox → worker → pool (circular)", .{completed});
}

const N: usize = 3;

const jobs = [N]i32{ 10, 20, 30 };

const MasterEvent = union(enum) {
    pool_ev: Pool.Result,
};

const WorkerCtx = struct {
    mbx: *Mbox,
    pl: *Pool,
};

fn workerFn(ctx: *WorkerCtx) anyerror!void {
    while (true) {
        var slot: Slot = null;
        ctx.mbx.receive(&slot, null) catch return;
        defer ctx.pl.put(&slot);
        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
        ev.code *= 2;
        std.log.info("worker: processed job, result code={d}", .{ev.code});
    }
}

const Ctx = struct {
    mbx: *Mbox,
    alloc: std.mem.Allocator,
    io: std.Io,

    fn spawnWorkerAndSetupSelect(self: *Ctx, pl: *Pool, worker_ctx: *WorkerCtx, sel: *std.Io.Select(MasterEvent)) !Io.Future(anyerror!void) {
        const fut = try self.io.concurrent(workerFn, .{worker_ctx});
        try sel.concurrent(.pool_ev, pool.getWaitResult, .{ pl, items.Event.EventPolyHelper.TAG, null });
        return fut;
    }

    fn runEventLoop(self: *Ctx, pl: *Pool, sel: *std.Io.Select(MasterEvent), job_idx: *usize, completed: *usize) !void {
        while (true) {
            const event: MasterEvent = try sel.await();
            switch (event) {
                .pool_ev => |r| switch (r) {
                    .item => |handle| {
                        if (job_idx.* < N) {
                            var slot: Slot = handle;
                            const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
                            ev.code = jobs[job_idx.*];
                            std.log.info("master: dispatching job {d} (code={d})", .{ job_idx.*, ev.code });
                            job_idx.* += 1;
                            // A refused send leaves the item in the slot.
                            // It came from the pool, so it goes back there.
                            self.mbx.send(&slot) catch |err| {
                                pl.put(&slot);
                                return err;
                            };
                            try sel.concurrent(.pool_ev, pool.getWaitResult, .{ pl, items.Event.EventPolyHelper.TAG, null });
                        } else {
                            const ev: *items.Event = items.Event.EventPolyHelper.mustFromPoly(handle);
                            completed.* = job_idx.*;
                            std.log.info("master: last result code={d}, all {d} jobs complete", .{ ev.code, completed.* });
                            var slot: Slot = handle;
                            pl.put(&slot);
                            break;
                        }
                    },
                    .closed, .canceled, .timeout, .not_created => break,
                },
            }
        }
        sel.cancelDiscard();
    }

    fn closeMailboxAndAwait(self: *Ctx, worker_fut: *Io.Future(anyerror!void)) !void {
        var rem: polynode.ItemList = self.mbx.close();
        items.freeList(&rem, self.alloc);
        try worker_fut.await(self.io);
    }
};

fn seedContainer(pl: *Pool) !void {
    var slot: Slot = null;
    try pl.get(items.Event.EventPolyHelper.TAG, .new_only, &slot);
    pl.put(&slot);
}

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
const Io = std.Io;
