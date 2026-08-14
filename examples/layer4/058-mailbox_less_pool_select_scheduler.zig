// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Pool + Select: job scheduler.
//!
//! - Pool seeded with N empty containers, used as a Select source alongside a timer.
//! - runEventLoop fills each container with the Master's cycle counter, re-spawns.
//! - Timer just logs progress from Master state; pool gates the processing rate.
//! - No mailbox anywhere in this example.
//!
//! Transfers (mailbox-less):
//!
//! ```
//!  pool (N_ITEMS empty containers seeded — code=0)
//!  │ getWaitResult         timer (sleepFn)
//!  └──────┬────────────────────────┘
//!         ▼
//!  Select(MasterEvent)
//!  │
//!  .pool_ev .item ──► fill ev.code from Master cycle index ──► pl.put ──► pool
//!                 ──► re-spawn getWaitResult (while cycle < TARGET)
//!                 ──► break (at TARGET, no getWaitResult re-spawned)
//!  .timer         ──► log cycle from Master state ──► re-spawn timer (while cycle < TARGET)
//!  │
//!  sel.cancelDiscard ──► timer cancelled (no items in-flight at this point)
//!  pl.close ──► on_close ──► freed
//! ```
//!
//!  Work input: Master's own cycle counter. Pool item is an empty container — the processing slot.
//!  No mailbox. Pool + Select gates the processing loop.
//!

pub fn pool_select_job_scheduler(allocator: std.mem.Allocator, io: std.Io) !void {
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};

    var pl_slot: Slot = null;
    try pool.new(io, allocator, pool_ctx.poolHooks(&tags), &pl_slot);
    const pl: *Pool = Pool.moveFromSlot(&pl_slot).?;
    defer {
        pl.close();
        pool.destroy(pl, allocator);
    }

    try seedPool(pl);

    var buf: [8]MasterEvent = undefined;
    var sel: std.Io.Select(MasterEvent) = std.Io.Select(MasterEvent).init(io, &buf);
    try setupSelect(pl, io, &sel);

    var cycle: usize = 0;
    var ticks: usize = 0;
    try runEventLoop(pl, io, &sel, &cycle, &ticks);

    try helpers.expect(error.MailboxLessSchedulerFailed, cycle == TARGET, "wrong cycle count");
    std.log.info("done: {d} cycles scheduled by Master counter, {d} timer ticks — Pool+Select, no mailbox", .{ cycle, ticks });
}

const N_ITEMS: usize = 3;
const TARGET: usize = N_ITEMS * 2; // process each container twice
const TIMER_NS: i96 = 20_000_000; // 20 ms

const MasterEvent = union(enum) {
    pool_ev: Pool.Result,
    timer: void,
};

fn sleepFn(sleep_t: std.Io.Timeout, io: std.Io) void {
    std.Io.Timeout.sleep(sleep_t, io) catch {};
}

fn seedPool(pl: *Pool) !void {
    for (0..N_ITEMS) |_| {
        var slot: Slot = null;
        try pl.get(items.Event.EventPolyHelper.TAG, .new_only, &slot);
        pl.put(&slot);
    }
}

fn setupSelect(pl: *Pool, io: std.Io, sel: *std.Io.Select(MasterEvent)) !void {
    const sleep_t: std.Io.Timeout = .{
        .duration = .{ .raw = .{ .nanoseconds = TIMER_NS }, .clock = .real },
    };
    try sel.concurrent(.pool_ev, pool.getWaitResult, .{ pl, items.Event.EventPolyHelper.TAG, null });
    try sel.concurrent(.timer, sleepFn, .{ sleep_t, io });
}

fn runEventLoop(pl: *Pool, io: std.Io, sel: *std.Io.Select(MasterEvent), cycle: *usize, ticks: *usize) !void {
    while (true) {
        const event: MasterEvent = try sel.await();
        switch (event) {
            .pool_ev => |r| switch (r) {
                .item => |handle| {
                    var slot: Slot = handle;
                    defer pl.put(&slot);
                    const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
                    ev.code = @intCast(cycle.*);
                    cycle.* += 1;
                    std.log.info("pool_ev: filled container with cycle index={d} ({d}/{d})", .{ ev.code, cycle.*, TARGET });
                    if (cycle.* < TARGET) {
                        try sel.concurrent(.pool_ev, pool.getWaitResult, .{ pl, items.Event.EventPolyHelper.TAG, null });
                    } else {
                        break;
                    }
                },
                .closed, .canceled, .timeout, .not_created => break,
            },
            .timer => {
                ticks.* += 1;
                std.log.info("timer tick {d}: maintenance — cycles so far: {d}", .{ ticks.*, cycle.* });
                if (cycle.* < TARGET) {
                    const sleep_t: std.Io.Timeout = .{
                        .duration = .{ .raw = .{ .nanoseconds = TIMER_NS }, .clock = .real },
                    };
                    try sel.concurrent(.timer, sleepFn, .{ sleep_t, io });
                }
            },
        }
    }
    sel.cancelDiscard();
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
