// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Pool + Group: worker pool.
//!
//! - Pool seeded with N empty containers, N workers spawned via Io.Group with a task index each.
//! - Each worker gets its own container, writes its index, returns it.
//! - group.cancel stops any workers still running, then pl.close frees the rest.
//! - No mailbox — each worker's own container is the coordination surface.
//!
//! Transfers (mailbox-less):
//!
//! ```
//!  pool (N_WORKERS empty containers seeded — code=0)
//!  │ Io.Group (N_WORKERS workers, each with own task index at spawn time)
//!  ├──► worker 0 ──pl.get──► slot (empty) ──► ev.code = 0 ──► pl.put ──► pool
//!  ├──► worker 1 ──pl.get──► slot (empty) ──► ev.code = 1 ──► pl.put ──► pool
//!  └──► worker 2 ──pl.get──► slot (empty) ──► ev.code = 2 ──► pl.put ──► pool
//!  │
//!  group.cancel ──► any worker that has not yet returned exits (all likely done)
//!  pl.close ──► on_close ──► freeList (remaining items freed)
//! ```
//!
//!  Work input: task index passed at spawn time. Pool item is an empty container.
//!  Each worker gets its own container, writes its index, returns it. No mailbox needed.
//!

pub fn pool_group_worker_pool(allocator: std.mem.Allocator, io: std.Io) !void {
    const pl: *Pool = try pool.new(io, allocator);
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};
    try pl.init(pool_ctx.poolHooks(&tags));

    try seedContainers(pl);

    var worker_ctxs: [N_WORKERS]WorkerCtx = undefined;
    var group: Io.Group = .init;
    try spawnWorkers(pl, io, &group, &worker_ctxs);

    std.log.info("master: {d} workers running, {d} empty containers in pool", .{ N_WORKERS, N_WORKERS });
    stopAndClosePool(pl, allocator, io, &group);
}

const N_WORKERS: usize = 3;

const WorkerCtx = struct {
    pl: *Pool,
    id: usize,
};

fn seedContainers(pl: *Pool) !void {
    for (0..N_WORKERS) |_| {
        var slot: Slot = null;
        try pl.get(items.Event.EventPolyHelper.TAG, .new_only, &slot);
        pl.put(&slot);
    }
}

fn workerFn(ctx: *WorkerCtx) error{Canceled}!void {
    var slot: Slot = null;
    defer ctx.pl.put(&slot);
    ctx.pl.get(items.Event.EventPolyHelper.TAG, .available_or_new, &slot) catch return;
    const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
    ev.code = @intCast(ctx.id);
    std.log.info("worker {d}: wrote task index into empty container (code={d})", .{ ctx.id, ev.code });
}

fn spawnWorkers(pl: *Pool, io: std.Io, group: *Io.Group, ctxs: *[N_WORKERS]WorkerCtx) !void {
    for (ctxs, 0..) |*ctx, i| {
        ctx.* = .{ .pl = pl, .id = i };
        try group.concurrent(io, workerFn, .{ctx});
    }
}

fn stopAndClosePool(pl: *Pool, alloc: std.mem.Allocator, io: std.Io, group: *Io.Group) void {
    group.cancel(io);
    std.log.info("master: all workers stopped via group.cancel", .{});
    pl.close();
    pool.destroy(pl, alloc);
    std.log.info("pool closed: on_close freed any remaining containers — no mailbox needed", .{});
}

const items = @import("../items/items.zig");
const hooks = @import("../hooks/hooks.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const pool = matryoshka.pool;
const Pool = matryoshka.Pool;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
const Io = std.Io;
