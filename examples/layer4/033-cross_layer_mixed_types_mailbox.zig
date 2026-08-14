// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Mixed types through shared mailbox.
//!
//! - Send one Event and one Sensor into the same mailbox.
//! - receiveAndDispatch pops both, dispatches on tag via fromPoly.
//! - Verifies each payload, frees each item.
//!
//!
//! ```
//!  EventPolyHelper.create ──► slot ──► mbx.send ──► mailbox
//!  SensorPolyHelper.create ──► slot ──► mbx.send ──► mailbox
//!  │
//!  mbx.receive ──► slot (Event or Sensor)
//!    dispatch on poly.tag:
//!    == EventPolyHelper.TAG  ──► fromPoly ──► *Event  ──► verify code==10 ──► freeSlot
//!    == SensorPolyHelper.TAG ──► fromPoly ──► *Sensor ──► verify value==3.14 ──► freeSlot
//!  │
//!  mbx.close ──► freeList (empty: all received)
//! ```
//!

pub fn mixed_types_through_shared_mailbox(allocator: std.mem.Allocator, io: std.Io) !void {
    var mbx_slot: Slot = null;
    try mailbox.new(io, allocator, &mbx_slot);
    const mbx: *Mbox = Mbox.moveFromSlot(&mbx_slot).?;
    defer {
        var rem: polynode.ItemList = mbx.close();
        items.freeList(&rem, allocator);
        mailbox.destroy(mbx, allocator);
    }

    try sendEvent(mbx, allocator);
    try sendSensor(mbx, allocator);
    try receiveAndDispatch(mbx, allocator);
}

fn sendEvent(mbx: *Mbox, alloc: std.mem.Allocator) !void {
    var slot: Slot = null;
    defer items.Event.EventPolyHelper.destroy(alloc, &slot);
    try items.Event.EventPolyHelper.create(alloc, &slot);
    items.Event.EventPolyHelper.mustFromSlot(&slot).code = 10;
    std.log.info("send: Event code={d}", .{10});
    try mbx.send(&slot);
}

fn sendSensor(mbx: *Mbox, alloc: std.mem.Allocator) !void {
    var slot: Slot = null;
    defer items.Sensor.SensorPolyHelper.destroy(alloc, &slot);
    try items.Sensor.SensorPolyHelper.create(alloc, &slot);
    items.Sensor.SensorPolyHelper.mustFromSlot(&slot).value = 3.14;
    std.log.info("send: Sensor value={d}", .{3.14});
    try mbx.send(&slot);
}

fn receiveAndDispatch(mbx: *Mbox, alloc: std.mem.Allocator) !void {
    var event_ok: bool = false;
    var sensor_ok: bool = false;

    for (0..2) |_| {
        var slot: Slot = null;
        try mbx.receive(&slot, null);
        defer items.freeSlot(&slot, alloc);
        const poly: *polynode.PolyNode = slot.?;
        if (items.Event.EventPolyHelper.fromPoly(poly)) |ev| {
            try helpers.expect(error.CrossLayerMixedTypesFailed, ev.code == 10, "wrong Event code");
            std.log.info("received: Event code={d}", .{ev.code});
            event_ok = true;
        } else if (items.Sensor.SensorPolyHelper.fromPoly(poly)) |sn| {
            try helpers.expect(error.CrossLayerMixedTypesFailed, sn.value == 3.14, "wrong Sensor value");
            std.log.info("received: Sensor value={d}", .{sn.value});
            sensor_ok = true;
        } else {
            return error.CrossLayerMixedTypesFailed;
        }
    }

    try helpers.expect(error.CrossLayerMixedTypesFailed, event_ok, "Event not received");
    try helpers.expect(error.CrossLayerMixedTypesFailed, sensor_ok, "Sensor not received");
    std.log.info("done: Event + Sensor through shared mailbox, dispatched on tag", .{});
}

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const Mbox = matryoshka.Mbox;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
