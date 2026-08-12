// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Cancel → Master close → pl.put_all.
//!
//! - Pool seeded with 3 Events, used as a Select event source via getWaitResult.
//! - eventLoop processes one item, then a timer triggers, ending the loop.
//! - cancelAndRecycle empties sel.cancel(), recycles any in-flight item via pl.put.
//! - pl.close then frees everything recycled — no item is lost or double-freed.
//!
//!
//! ```
//!  pool (seeded: Event×3)
//!  │ getWaitResult
//!  ▼
//!  Select(MasterEvent) ◄── sleepFn (timer)
//!  │
//!  .pool_ev .item ──► process ──pl.put──► pool   (1 item processed)
//!  .timer ──► sel.cancel() loop
//!             .pool_ev .item ──► pl.put (recycle, not freed!)
//!             .pool_ev .canceled ──► (no item, skip)
//!  │
//!  pl.close ──► on_close ──► freeList (all recycled items freed cleanly)
//! ```
//!

pub fn cancel_master_close_pool_put_all(allocator: std.mem.Allocator, io: std.Io) !void {
    const pl: *Pool = try pool.new(io, allocator);
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};
    try pl.init(pool_ctx.poolHooks(&tags));
    defer {
        pl.close();
        pool.destroy(pl, allocator);
    }

    try seedPool(pl);

    var buf: [8]MasterEvent = undefined;
    var sel: std.Io.Select(MasterEvent) = std.Io.Select(MasterEvent).init(io, &buf);
    try setupSelect(pl, io, &sel);

    var processed: usize = 0;
    var recycled: usize = 0;
    try eventLoop(pl, &sel, &processed);
    cancelAndRecycle(pl, &sel, &recycled);

    std.log.info("done: processed={d}, recycled via cancel={d}", .{ processed, recycled });
}

const TIMER_NS: i96 = 15_000_000; // 15 ms

const MasterEvent = union(enum) {
    pool_ev: Pool.Result,
    timer: void,
};

fn sleepFn(sleep_t: std.Io.Timeout, io: std.Io) void {
    std.Io.Timeout.sleep(sleep_t, io) catch {};
}

fn seedPool(pl: *Pool) !void {
    for (0..3) |i| {
        var slot: Slot = null;
        try pl.get(items.Event.EventPolyHelper.TAG, .new_only, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
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

fn eventLoop(pl: *Pool, sel: *std.Io.Select(MasterEvent), processed: *usize) !void {
    loop: while (true) {
        const event: MasterEvent = try sel.await();
        switch (event) {
            .pool_ev => |r| switch (r) {
                .item => |handle| {
                    var slot: Slot = handle;
                    defer pl.put(&slot);
                    const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
                    processed.* += 1;
                    std.log.info("pool_ev: processed code={d} → put back to pool", .{ev.code});
                    try sel.concurrent(.pool_ev, pool.getWaitResult, .{ pl, items.Event.EventPolyHelper.TAG, null });
                },
                .closed, .canceled, .timeout, .not_created => break :loop,
            },
            .timer => {
                std.log.info("timer: canceling remaining pool watchers", .{});
                break :loop;
            },
        }
    }
}

fn cancelAndRecycle(pl: *Pool, sel: *std.Io.Select(MasterEvent), recycled: *usize) void {
    while (sel.cancel()) |event| {
        switch (event) {
            .pool_ev => |r| switch (r) {
                .item => |handle| {
                    var slot: Slot = handle;
                    pl.put(&slot);
                    recycled.* += 1;
                    std.log.info("cancel walk: recycled pool item (not freed)", .{});
                },
                .canceled, .closed, .timeout, .not_created => {},
            },
            .timer => {},
        }
    }
}

const items = @import("../items/items.zig");
const hooks = @import("../hooks/hooks.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const pool = matryoshka.pool;
const Pool = matryoshka.Pool;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
