// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Shutdown with remaining item cleanup.
//!
//! - Send 5 Events and 3 Sensors into a mailbox, none received.
//! - Close the mailbox — all items come back in the returned list.
//! - Walk the list with popFirst, free every item.
//!
//!
//! ```
//!  alloc.create × (n_events + n_sensors) ──► mailbox
//!       │ mailbox.close (no receive — all items returned)
//!       ▼
//!  DoublyLinkedList ──► freeItem × N
//! ```
//!

pub fn shutdown_with_remaining_item_cleanup(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbh: MailboxHandle = try mailbox.new(io, allocator);
    defer mailbox.destroy(mbh, allocator);

    const n_events: usize = 5;
    const n_sensors: usize = 3;

    var i: usize = 0;
    while (i < n_events) : (i += 1) {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(allocator, &slot);
        try items.Event.EventPolyHelper.create(allocator, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i);
        try mailbox.send(mbh, &slot);
    }

    i = 0;
    while (i < n_sensors) : (i += 1) {
        var slot: Slot = null;
        defer items.Sensor.SensorPolyHelper.destroy(allocator, &slot);
        try items.Sensor.SensorPolyHelper.create(allocator, &slot);
        items.Sensor.SensorPolyHelper.mustFromSlot(&slot).value = @as(f64, @floatFromInt(i)) * 1.1;
        try mailbox.send(mbh, &slot);
    }

    // Close without receiving — all items come back in the returned list.
    var remaining: std.DoublyLinkedList = mailbox.close(mbh);
    var freed: usize = 0;
    while (remaining.popFirst()) |node| {
        items.freeItem(@fieldParentPtr("node", node), allocator);
        freed += 1;
    }

    std.log.info("shutdown cleanup: freed {d} items", .{freed});
    try helpers.expect(error.ShutdownCleanupFailed, freed == n_events + n_sensors, "wrong freed count");
}

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const polynode = matryoshka.polynode;
const mailbox = matryoshka.mailbox;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
