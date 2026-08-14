// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! OOB via send_oob.
//!
//! - Send 3 Events via mbx.send, queued in order.
//! - Send 1 Sensor via mbx.send_oob, jumps to queue front.
//! - Receive 4 items: OOB Sensor arrives first, then the 3 Events.
//! - Free every received item.
//!
//!
//! ```
//!  mbx.send (Event×3) ──► queue tail
//!  mbx.send_oob (Sensor) ──► queue front
//!       │ mbx.receive ×4
//!       ▼
//!  OOB Sensor arrives first, then Events in send order
//!  freeSlot per item
//! ```
//!

pub fn oob_via_send_oob(allocator: std.mem.Allocator, io: std.Io) !void {
    var mbx_slot: Slot = null;
    try mailbox.new(io, allocator, &mbx_slot);
    const mbx: *Mbox = Mbox.moveFromSlot(&mbx_slot).?;
    defer {
        var rem: polynode.ItemList = mbx.close();
        items.freeList(&rem, allocator);
        mailbox.destroy(mbx, allocator);
    }

    const codes = [_]i32{ 1, 2, 3 };
    for (codes) |code| {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(allocator, &slot);
        try items.Event.EventPolyHelper.create(allocator, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = code;
        try mbx.send(&slot);
    }

    {
        var slot: Slot = null;
        defer items.Sensor.SensorPolyHelper.destroy(allocator, &slot);
        try items.Sensor.SensorPolyHelper.create(allocator, &slot);
        items.Sensor.SensorPolyHelper.mustFromSlot(&slot).value = -1.0;
        try mbx.send_oob(&slot);
    }

    var received_oob: bool = false;
    var event_count: usize = 0;
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        var slot: Slot = null;
        defer items.freeSlot(&slot, allocator);
        try mbx.receive(&slot, 1_000_000_000);
        const poly: *PolyNode = slot.?;
        if (items.Sensor.SensorPolyHelper.fromPoly(poly)) |oob_sn| {
            std.log.info("OOB signal value={d:.1}", .{oob_sn.value});
            try helpers.expect(error.OobSignalFailed, !received_oob, "duplicate OOB");
            try helpers.expect(error.OobSignalFailed, event_count == 0, "OOB did not arrive first");
            received_oob = true;
            items.freeSlot(&slot, allocator);
        } else if (items.Event.EventPolyHelper.fromPoly(poly)) |ev| {
            std.log.info("event code={d}", .{ev.code});
            event_count += 1;
            items.freeSlot(&slot, allocator);
        }
    }

    try helpers.expect(error.OobSignalFailed, received_oob, "OOB not received");
    try helpers.expect(error.OobSignalFailed, event_count == 3, "wrong event count");
}

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const polynode = matryoshka.polynode;
const mailbox = matryoshka.mailbox;
const Mbox = matryoshka.Mbox;
const PolyNode = polynode.PolyNode;
const Slot = polynode.Slot;
