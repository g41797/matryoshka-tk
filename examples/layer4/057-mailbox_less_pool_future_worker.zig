// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Pool + Future: simple worker.
//!
//! - Master seeds the pool with 1 empty container, spawns one worker with N passed at spawn time.
//! - Worker loops N times: pl.get_wait, writes its own counter into the container, pl.put.
//! - fut.await blocks until the worker finishes all N cycles.
//! - No mailbox needed — pool is the only coordination point.
//!
//! Transfers (mailbox-less):
//!
//! ```
//!  pool (1 empty container seeded — code=0)
//!  │ io.concurrent (n=3 passed at spawn time)
//!  ▼
//!  worker loop (n cycles):
//!    pl.get ──► slot (empty) ──► ev.code = worker counter ──► pl.put ──► pool
//!  │
//!  fut.await ──► master reads ctx.counter (= n after all cycles)
//!  pl.close ──► on_close ──► freed
//! ```
//!
//!  Work input: spawn-time arg n + worker's own counter.
//!  Pool item is an empty container — a processing slot, not a data carrier.
//!  No mailbox needed for simple single-worker coordination.
//!

pub fn pool_future_simple_worker(allocator: std.mem.Allocator, io: std.Io) !void {
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};

    var pl_slot: Slot = null;
    try pool.new(io, allocator, pool_ctx.poolHooks(&tags), &pl_slot);
    const pl: *Pool = Pool.moveFromSlot(&pl_slot).?;
    defer {
        pl.close();
        pool.destroy(pl, allocator);
    }

    try seedContainer(pl);

    var ctx: WorkerCtx = .{ .pl = pl, .tag = items.Event.EventPolyHelper.TAG, .n = N };
    var fut: std.Io.Future(anyerror!void) = try io.concurrent(workerFn, .{&ctx});
    try fut.await(io);

    try helpers.expect(error.MailboxLessPoolFutureFailed, ctx.counter == N, "wrong cycle count");
    std.log.info("done: worker completed {d} cycles — counter={d}, pool item was empty container, no mailbox needed", .{ N, ctx.counter });
}

const N: usize = 3; // iteration count passed to worker at spawn time

const WorkerCtx = struct {
    pl: *Pool,
    tag: *const anyopaque,
    n: usize,
    counter: usize = 0,
};

fn workerFn(ctx: *WorkerCtx) anyerror!void {
    for (0..ctx.n) |_| {
        var slot: Slot = null;
        try ctx.pl.get_wait(ctx.tag, &slot, null);
        defer ctx.pl.put(&slot);
        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
        ev.code = @intCast(ctx.counter); // write counter into empty container
        ctx.counter += 1;
        std.log.info("worker: cycle {d} — wrote counter into empty container (code={d})", .{ ctx.counter, ev.code });
    }
}

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
const pool = matryoshka.pool;
const Pool = matryoshka.Pool;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
