// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Tag-dispatch consume loop.
//!
//! - Push one Event and one Sensor into a mixed-type list.
//! - Pop each node, check its tag.
//! - Recover the typed pointer with fromPoly, process it.
//! - Free every item; count events and sensors separately.
//!
//! This is item-first dispatch: the item is in hand, each type is asked to
//! cast it. For the other way round — a tag and no item — see
//! 026-tag_first_dispatch.
//!
//!
//! ```
//!  alloc.create (Event) ──► list
//!  alloc.create (Sensor) ──► list
//!       │ list.popFirst
//!       ▼
//!  tag check ──► EventPolyHelper.fromPoly or SensorPolyHelper.fromPoly
//!       │ freeItem per node
//! ```
//!

pub fn tag_dispatch_consume_loop(allocator: std.mem.Allocator, io: std.Io) !void {
    _ = io;
    var list: polynode.ItemList = .{};

    defer freeRemaining(&list, allocator);

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

    var processed_events: usize = 0;
    var processed_sensors: usize = 0;

    while (list.popFirst()) |poly| {
        if (items.Event.EventPolyHelper.fromPoly(poly)) |recovered_ev| {
            try helpers.expect(error.TagDispatchFailed, recovered_ev.*.code == 7, "wrong event code");
            processed_events += 1;
            items.freeItem(poly, allocator);
        } else if (items.Sensor.SensorPolyHelper.fromPoly(poly)) |recovered_sn| {
            try helpers.expect(error.TagDispatchFailed, recovered_sn.*.value == 2.71, "wrong sensor value");
            processed_sensors += 1;
            items.freeItem(poly, allocator);
        } else {
            return error.UnknownTag;
        }
    }

    try helpers.expect(error.TagDispatchFailed, processed_events == 1, "wrong event count");
    try helpers.expect(error.TagDispatchFailed, processed_sensors == 1, "wrong sensor count");
}

fn freeRemaining(list: *polynode.ItemList, alloc: std.mem.Allocator) void {
    while (list.popFirst()) |poly| {
        items.freeItem(poly, alloc);
    }
}

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const polynode = @import("matryoshka").polynode;
const std = @import("std");
const Slot = polynode.Slot;
