// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! OOB via send_oob.
//!
//! - Send 3 Events via mailbox.send, queued in order.
//! - Send 1 Sensor via mailbox.send_oob, jumps to queue front.
//! - Receive 4 items: OOB Sensor arrives first, then the 3 Events.
//! - Free every received item.
//!
//!
//! ```
//!  mailbox.send (Event×3) ──► queue tail
//!  mailbox.send_oob (Sensor) ──► queue front
//!       │ mailbox.receive ×4
//!       ▼
//!  OOB Sensor arrives first, then Events in send order
//!  freeSlot per item
//! ```
//!

pub fn oob_via_send_oob(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbh: MailboxHandle = try mailbox.new(io, allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh);
        items.freeList(&rem, allocator);
        mailbox.destroy(mbh, allocator);
    }

    const codes = [_]i32{ 1, 2, 3 };
    for (codes) |code| {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(allocator, &slot);
        try items.Event.EventPolyHelper.create(allocator, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = code;
        try mailbox.send(mbh, &slot);
    }

    {
        var slot: Slot = null;
        defer items.Sensor.SensorPolyHelper.destroy(allocator, &slot);
        try items.Sensor.SensorPolyHelper.create(allocator, &slot);
        items.Sensor.SensorPolyHelper.mustFromSlot(&slot).value = -1.0;
        try mailbox.send_oob(mbh, &slot);
    }

    var received_oob: bool = false;
    var event_count: usize = 0;
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        var slot: Slot = null;
        defer items.freeSlot(&slot, allocator);
        try mailbox.receive(mbh, &slot, 1_000_000_000);
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
const PolyNode = polynode.PolyNode;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
