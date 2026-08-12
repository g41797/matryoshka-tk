// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Pool seeding.
//!
//! - Seed the pool with 5 Sensor items via new_only.get() + pl.put.
//! - Consume all 5 with available_only.get() — no allocation.
//! - Free each consumed item, verify the count.
//!
//!
//! ```
//!  pl.get (new_only) × 5 ──► pl.put × 5
//!  (pool holds 5 items)
//!       │ pl.get (available_only) × 5
//!       ▼
//!  slot ──► SensorPolyHelper.destroy per item
//! ```
//!

pub fn pool_seeding(allocator: std.mem.Allocator, io: std.Io) !void {
    var ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Sensor.SensorPolyHelper.TAG};

    const pl = try pool.new(io, allocator);
    defer {
        pl.close();
        pool.destroy(pl, allocator);
    }
    try pl.init(ctx.poolHooks(&tags));

    const n: usize = 5;

    // Seed: new_only forces allocation for each item.
    var i: usize = 0;
    while (i < n) : (i += 1) {
        var slot: Slot = null;
        defer pl.put(&slot);
        try pl.get(items.Sensor.SensorPolyHelper.TAG, .new_only, &slot);
        const sn = items.Sensor.SensorPolyHelper.mustFromSlot(&slot);
        sn.value = @as(f64, @floatFromInt(i)) * 0.1;
    }
    std.log.info("seeded {d} Sensor items into pool", .{n});

    // Consume: available_only takes pre-existing items — no allocation.
    var consumed: usize = 0;
    while (true) {
        var slot: Slot = null;
        defer items.Sensor.SensorPolyHelper.destroy(allocator, &slot);
        pl.get(items.Sensor.SensorPolyHelper.TAG, .available_only, &slot) catch break;
        const sn = items.Sensor.SensorPolyHelper.mustFromSlot(&slot);
        std.log.info("consumed Sensor value={d:.1}", .{sn.value});
        consumed += 1;
    }
    try helpers.expect(error.PoolSeedingFailed, consumed == n, "wrong consumed count");
}

const items = @import("../items/items.zig");
const hooks = @import("../hooks/hooks.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const pool = matryoshka.pool;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
