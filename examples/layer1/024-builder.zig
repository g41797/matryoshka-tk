// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Builder pattern.
//!
//! - Builder wraps an allocator, no other state.
//! - createEvent / createSensor build a typed item into a Slot.
//! - fromNode recovers the typed pointer for field access.
//! - destroyByTag frees whichever type the Slot holds.
//!
//!
//! ```
//!  alloc.create ──► slot (non-null)
//!       │
//!  Builder.fromNode ──► field access (no transfer)
//!       │
//!  Builder.destroyByTag ──► slot = null (freed)
//! ```
//!

pub fn builder_pattern(allocator: std.mem.Allocator, io: std.Io) !void {
    _ = io;
    const b: Builder = .{ .alloc = allocator };

    {
        var slot: Slot = null;
        defer b.destroyByTag(&slot);
        try b.createEvent(100, &slot);
        const ev = items.Event.EventPolyHelper.mustFromSlot(&slot);
        try helpers.expect(error.BuilderFailed, ev.code == 100, "wrong event code");
    }

    {
        var slot: Slot = null;
        defer b.destroyByTag(&slot);
        try b.createSensor(9.8, &slot);
        const sn = items.Sensor.SensorPolyHelper.mustFromSlot(&slot);
        try helpers.expect(error.BuilderFailed, sn.value == 9.8, "wrong sensor value");
    }
}

pub const Builder = struct {
    alloc: std.mem.Allocator,

    pub fn createEvent(self: Builder, code: i32, slot: *Slot) !void {
        try items.Event.EventPolyHelper.create(self.alloc, slot);
        items.Event.EventPolyHelper.mustFromSlot(slot).code = code;
    }

    pub fn createSensor(self: Builder, value: f64, slot: *Slot) !void {
        try items.Sensor.SensorPolyHelper.create(self.alloc, slot);
        items.Sensor.SensorPolyHelper.mustFromSlot(slot).value = value;
    }

    pub fn destroyByTag(self: Builder, slot: *Slot) void {
        items.freeSlot(slot, self.alloc);
    }
};

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const polynode = @import("matryoshka").polynode;
const std = @import("std");
const Slot = polynode.Slot;
