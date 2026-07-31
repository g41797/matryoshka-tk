// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Table dispatch — the third way, where the choice is data.
//!
//! 023 and 026 write the choice as code. This one writes it as a value.
//!
//! - 023 has the item and asks each type to cast it: fromPoly.
//! - 026 has the tag and asks each type to confirm it: isIt.
//! - Both put the choice in the chain, so the choice is fixed where the
//!   chain is written. Two receivers that treat an Event differently write
//!   two chains.
//! - A table is `{tag, handler}` pairs the receiver owns. Change the table
//!   and the same tag reaches a different handler.
//!
//! - Push an Event, a Sensor and a Timer into one mixed list.
//! - Dispatch each through a table that names all three.
//! - Then dispatch an Event through a second table, which maps the same
//!   tag to a different handler. No chain can express that.
//! - A tag no table names gives error.NoHandler with the item still in the
//!   Slot, so the caller frees it. The last branch of a chain cannot.
//!
//!
//! ```
//!  alloc.create (Event, Sensor, Timer)  ──► list
//!       │ list.popFirst
//!       ▼
//!  table.dispatch(&recorder, &slot)
//!       │ find: entry.tag == poly.tag
//!       ▼
//!  handler(recorder, slot) ──► Slot says where the item went
//!       │ freeSlot per item
//! ```
//!

/// A receiver. Its handlers look at the item and leave it in the Slot.
const Recorder = struct {
    events: usize = 0,
    sensors: usize = 0,
    timers: usize = 0,
    marked: usize = 0,
    last_code: i32 = 0,

    fn onEvent(self: *Recorder, slot: *Slot) anyerror!void {
        // The table matched the tag, so this cast cannot fail.
        self.last_code = items.Event.EventPolyHelper.mustFromSlot(slot).*.code;
        self.events += 1;
    }

    fn onSensor(self: *Recorder, slot: *Slot) anyerror!void {
        const sn = items.Sensor.SensorPolyHelper.mustFromSlot(slot);
        try helpers.expect(error.TableDispatchFailed, sn.*.value == 2.71, "wrong sensor value");
        self.sensors += 1;
    }

    fn onTimer(self: *Recorder, _: *Slot) anyerror!void {
        // A handler that never reaches the item. The tag was enough.
        self.timers += 1;
    }

    /// The second table's handler for an Event. Same tag, other work.
    fn markEvent(self: *Recorder, _: *Slot) anyerror!void {
        self.marked += 1;
    }
};

const Table = helpers.TagTable(Recorder);

/// The table is a value, so it is a container-level const. Every Recorder
/// shares it and nothing builds it at start-up.
const record_table: Table = .{ .entries = &.{
    .{ .tag = items.Event.EventPolyHelper.TAG, .handler = Recorder.onEvent },
    .{ .tag = items.Sensor.SensorPolyHelper.TAG, .handler = Recorder.onSensor },
    .{ .tag = items.Timer.TimerPolyHelper.TAG, .handler = Recorder.onTimer },
} };

/// A second table over the same receiver type. The Event tag is in both,
/// against a different handler. The Sensor tag is in neither — a receiver
/// with no handler for a type is a normal state of affairs.
const mark_table: Table = .{ .entries = &.{
    .{ .tag = items.Event.EventPolyHelper.TAG, .handler = Recorder.markEvent },
} };

pub fn table_dispatch_loop(allocator: std.mem.Allocator, io: std.Io) !void {
    _ = io;
    var list: polynode.ItemList = .{};

    defer items.freeList(&list, allocator);

    {
        var slot: Slot = null;
        try items.Event.EventPolyHelper.create(allocator, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = 7;
        list.appendFromSlot(&slot);
    }

    {
        var slot: Slot = null;
        try items.Sensor.SensorPolyHelper.create(allocator, &slot);
        items.Sensor.SensorPolyHelper.mustFromSlot(&slot).value = 2.71;
        list.appendFromSlot(&slot);
    }

    {
        var slot: Slot = null;
        try items.Timer.TimerPolyHelper.create(allocator, &slot);
        list.appendFromSlot(&slot);
    }

    var recorder: Recorder = .{};

    while (list.popFirst()) |poly| {
        var slot: Slot = poly;

        // Covers every outcome. The handler may take the item, forward it,
        // or leave it — this frees whatever is left, and does nothing when
        // the Slot is null.
        defer items.freeSlot(&slot, allocator);

        try record_table.dispatch(&recorder, &slot);
    }

    try helpers.expect(error.TableDispatchFailed, recorder.events == 1, "wrong event count");
    try helpers.expect(error.TableDispatchFailed, recorder.sensors == 1, "wrong sensor count");
    try helpers.expect(error.TableDispatchFailed, recorder.timers == 1, "wrong timer count");
    try helpers.expect(error.TableDispatchFailed, recorder.last_code == 7, "wrong event code");

    try secondTable(allocator, &recorder);
}

/// The same tag, the other table, the other handler.
fn secondTable(allocator: std.mem.Allocator, recorder: *Recorder) !void {
    {
        var slot: Slot = null;
        defer items.freeSlot(&slot, allocator);

        try items.Event.EventPolyHelper.create(allocator, &slot);
        try mark_table.dispatch(recorder, &slot);

        // The Event tag reached markEvent, not onEvent. The item is the
        // same one record_table would have sent to onEvent.
        try helpers.expect(error.TableDispatchFailed, recorder.marked == 1, "wrong marked count");
        try helpers.expect(error.TableDispatchFailed, recorder.events == 1, "onEvent ran again");
    }

    {
        var slot: Slot = null;
        defer items.freeSlot(&slot, allocator);

        try items.Sensor.SensorPolyHelper.create(allocator, &slot);

        // mark_table has no entry for a Sensor. Nothing is called and the
        // item never leaves the Slot, so the defer above frees it. The
        // last branch of an isIt chain has no type and cannot.
        const missed = mark_table.dispatch(recorder, &slot);
        try helpers.expect(error.TableDispatchFailed, missed == error.NoHandler, "expected NoHandler");
        try helpers.expect(error.TableDispatchFailed, slot != null, "miss took the item");
    }
}

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const polynode = @import("matryoshka").polynode;
const std = @import("std");
const Slot = polynode.Slot;
