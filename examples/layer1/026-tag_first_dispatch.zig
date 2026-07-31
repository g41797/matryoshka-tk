// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Tag-first dispatch, the other way round from 023.
//!
//! - 023 has the item. It asks each type to cast: fromPoly.
//! - This one starts from the tag alone. It asks each type to confirm: isIt.
//! - Only after a tag is confirmed does mustFromPoly reach the item.
//! - A pool hook works this way because it has no item — see AlwaysCreateHooks.
//!
//! - Push an Event, a Sensor and a Timer into one mixed list.
//! - Read each tag once, confirm it, then reach the item.
//! - The last branch handles a tag nobody claimed. Always write it.
//!
//!
//! ```
//!  alloc.create (Event)  ──► list
//!  alloc.create (Sensor) ──► list
//!  alloc.create (Timer)  ──► list
//!       │ list.popFirst
//!       ▼
//!  tag ──► isIt ──► mustFromPoly ──► item
//!       │ freeItem per node
//! ```
//!

pub fn tag_first_dispatch_loop(allocator: std.mem.Allocator, io: std.Io) !void {
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

    var events: usize = 0;
    var sensors: usize = 0;
    var timers: usize = 0;

    while (list.popFirst()) |poly| {
        // One read. Every branch below asks about this tag.
        const tag: *const anyopaque = poly.*.tag;

        if (items.Event.EventPolyHelper.isIt(tag)) {
            // The tag is proven, so this cast cannot fail.
            const ev = items.Event.EventPolyHelper.mustFromPoly(poly);
            try helpers.expect(error.TagFirstDispatchFailed, ev.*.code == 7, "wrong event code");
            events += 1;
        } else if (items.Sensor.SensorPolyHelper.isIt(tag)) {
            const sn = items.Sensor.SensorPolyHelper.mustFromPoly(poly);
            try helpers.expect(error.TagFirstDispatchFailed, sn.*.value == 2.71, "wrong sensor value");
            sensors += 1;
        } else if (items.Timer.TimerPolyHelper.isIt(tag)) {
            // A branch that never reaches the item. The tag was enough.
            timers += 1;
        } else {
            // Nobody claimed the tag. This branch cannot free the item —
            // destroy needs the type, and here there is none.
            return error.UnknownTag;
        }

        items.freeItem(poly, allocator);
    }

    try helpers.expect(error.TagFirstDispatchFailed, events == 1, "wrong event count");
    try helpers.expect(error.TagFirstDispatchFailed, sensors == 1, "wrong sensor count");
    try helpers.expect(error.TagFirstDispatchFailed, timers == 1, "wrong timer count");
}

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const polynode = @import("matryoshka").polynode;
const std = @import("std");
const Slot = polynode.Slot;
