// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Backpressure pool.
//!
//! - 4 threads concurrently pl.get and pl.put, 8 iterations each.
//! - on_put caps the pool at 2 items, destroys anything past the cap.
//! - After all threads join, empty the pool and count what remains.
//! - Verify the remaining count never exceeds the cap.
//!
//!
//! ```
//!  CappedPool (cap=2)
//!       │ pl.get (available_or_new) — 4 threads concurrently
//!       ▼
//!  worker thread (processes)
//!       │ pl.put (defer) — on_put destroys excess above cap
//!       ▼
//!  CappedPool (≤ cap items retained)
//! ```
//!

pub fn backpressure_pool(allocator: std.mem.Allocator, io: std.Io) !void {
    const cap: usize = 2;
    var pool_ctx: hooks.CappedPoolHooks = .{ .alloc = allocator, .cap = cap, .io = io };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};

    var pl_slot: Slot = null;
    try pool.new(io, allocator, pool_ctx.poolHooks(&tags), &pl_slot);
    const pl: *Pool = Pool.moveFromSlot(&pl_slot).?;
    defer {
        pl.close();
        pool.destroy(pl, allocator);
    }

    var workers: [thread_count]WorkerCtx = undefined;
    var futures: [thread_count]std.Io.Future(void) = undefined;

    for (&workers, &futures) |*wctx, *f| {
        wctx.* = .{ .pl = pl, .alloc = allocator };
        f.* = try io.concurrent(workerFn, .{wctx});
    }

    for (&futures) |*f| f.await(io);

    // consume remaining items to count them
    var in_pool: usize = 0;
    while (true) {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(allocator, &slot);
        pl.get(items.Event.EventPolyHelper.TAG, .available_only, &slot) catch break;
        in_pool += 1;
    }

    std.log.info("capped pool (cap={d}): {d} items remain after {d} threads x {d} iterations", .{
        cap, in_pool, thread_count, iterations,
    });
    try helpers.expect(error.CappedPoolFailed, in_pool <= cap, "pool exceeded cap");
}

const thread_count = 4;
const iterations = 8;

const WorkerCtx = struct {
    pl: *Pool,
    alloc: std.mem.Allocator,
};

fn workerFn(ctx: *WorkerCtx) void {
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        var slot: Slot = null;
        defer ctx.pl.put(&slot);
        ctx.pl.get(items.Event.EventPolyHelper.TAG, .available_or_new, &slot) catch return;
        std.log.debug("worker: got item", .{});
    }
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
