// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Pool get_wait as Select event source.
//!
//! - Pool seeded with 3 empty Event containers, used as a Select event source.
//! - runEventLoop fills each returned container with the Master's own cycle counter.
//! - Re-spawns getWaitResult until the target cycle count is reached, then stops.
//! - Work input is the Master's counter; the pool item is only an empty container.
//!
//!
//! ```
//!  pool (seeded: Event×3, all empty — code=0)
//!  │ getWaitResult — blocks until item available
//!  ▼
//!  Select(MasterEvent) ◄── sleepFn (timer)
//!  │
//!  .pool_ev .item ──► fill ev.code from Master counter ──► put back
//!                 ──► re-spawn getWaitResult (while cycle < target)
//!                 ──► break (when cycle == target, timer still in-flight)
//!  .timer         ──► log Master counter ──► re-spawn timer
//!  │
//!  sel.cancelDiscard() ──► timer cancelled (no items in-flight at this point)
//!  pl.close ──► on_close ──► freed
//! ```
//!
//!  Work input: Master's own cycle counter. Pool item is an empty container.
//!  Stop condition: cycle reaches target. getWaitResult not re-spawned at target,
//!  so cancelDiscard only cancels the timer — no items in-transit, no leak.
//!

pub fn pool_get_wait_as_select_event_source(allocator: std.mem.Allocator, io: std.Io) !void {
    const pl: *Pool = try pool.new(io, allocator);
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};
    try pl.init(pool_ctx.poolHooks(&tags));
    defer {
        pl.close();
        pool.destroy(pl, allocator);
    }

    try seedPool(pl);

    var buf: [4]MasterEvent = undefined;
    var sel: std.Io.Select(MasterEvent) = std.Io.Select(MasterEvent).init(io, &buf);
    try setupSelect(pl, io, &sel);
    const cycle = try runEventLoop(pl, io, &sel);

    try helpers.expect(error.SelectPoolEventFailed, cycle == TARGET, "wrong cycle count");
    std.log.info("done: {d} cycles driven by Master counter — pool items were empty containers", .{cycle});
}

const N_ITEMS: usize = 3;
const TARGET: usize = N_ITEMS * 2; // process each container twice
const TIMER_NS: i96 = 30_000_000; // 30 ms

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

fn runEventLoop(pl: *Pool, io: std.Io, sel: *std.Io.Select(MasterEvent)) !usize {
    var cycle: usize = 0;
    while (true) {
        const event: MasterEvent = try sel.await();
        switch (event) {
            .pool_ev => |r| switch (r) {
                .item => |handle| {
                    var slot: Slot = handle;
                    defer pl.put(&slot);
                    const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
                    ev.code = @intCast(cycle);
                    cycle += 1;
                    std.log.info("pool_ev: filled container with cycle={d}", .{ev.code});
                    if (cycle < TARGET) {
                        try sel.concurrent(.pool_ev, pool.getWaitResult, .{ pl, items.Event.EventPolyHelper.TAG, null });
                    } else {
                        break;
                    }
                },
                .closed, .canceled, .timeout, .not_created => break,
            },
            .timer => {
                std.log.info("timer: maintenance — cycles completed so far: {d}", .{cycle});
                const sleep_t: std.Io.Timeout = .{
                    .duration = .{ .raw = .{ .nanoseconds = TIMER_NS }, .clock = .real },
                };
                try sel.concurrent(.timer, sleepFn, .{ sleep_t, io });
            },
        }
    }
    sel.cancelDiscard();
    return cycle;
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
