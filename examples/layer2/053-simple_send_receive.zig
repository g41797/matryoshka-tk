// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Simple send-receive.
//!
//! - One thread sends an Event, then a Sensor, into a mailbox.
//! - Same thread receives both back, in order.
//! - Verifies each roundtrip value.
//!
//!
//! ```
//!  alloc.create ──► slot ──mailbox.send──► mailbox (owns)
//!                                              │ mailbox.receive
//!                                              ▼
//!                                         slot ──► freeSlot
//! ```
//!

pub fn simple_send_receive(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbh: MailboxHandle = try mailbox.new(io, allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh);
        items.freeList(&rem, allocator);
        mailbox.destroy(mbh, allocator);
    }

    {
        var slot: Slot = null;
        defer items.freeSlot(&slot, allocator);
        try items.Event.EventPolyHelper.create(allocator, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = 53;
        try mailbox.send(mbh, &slot);
    }

    {
        var slot: Slot = null;
        defer items.freeSlot(&slot, allocator);
        try items.Sensor.SensorPolyHelper.create(allocator, &slot);
        items.Sensor.SensorPolyHelper.mustFromSlot(&slot).value = 5.3;
        try mailbox.send(mbh, &slot);
    }

    {
        var slot: Slot = null;
        defer items.freeSlot(&slot, allocator);
        try mailbox.receive(mbh, &slot, 1_000_000_000);
        const ev_recv: *items.Event = items.Event.EventPolyHelper.fromSlot(&slot) orelse return error.WrongTag;
        try helpers.expect(error.SimpleSendReceiveFailed, ev_recv.*.code == 53, "wrong event code");
        std.log.info("received Event code={d}", .{ev_recv.*.code});
    }

    {
        var slot: Slot = null;
        defer items.freeSlot(&slot, allocator);
        try mailbox.receive(mbh, &slot, 1_000_000_000);
        const sn_recv: *items.Sensor = items.Sensor.SensorPolyHelper.fromSlot(&slot) orelse return error.WrongTag;
        try helpers.expect(error.SimpleSendReceiveFailed, sn_recv.*.value == 5.3, "wrong sensor value");
        std.log.info("received Sensor value={d:.1}", .{sn_recv.*.value});
    }
}

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const polynode = matryoshka.polynode;
const mailbox = matryoshka.mailbox;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
