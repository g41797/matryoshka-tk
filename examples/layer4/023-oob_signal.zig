// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! OOB via send_oob.
//!
//! - Send 3 Events via mbx.send, queued in order.
//! - Send a ShutdownCommand via mbx.send_oob, jumps to queue front.
//! - processingLoop receives 4 items: OOB signal first, then the 3 Events.
//! - Free every received item, verify the arrival order.
//!
//!
//! ```
//!  mbx.send (Event×3) ──► queue tail
//!  mbx.send_oob (ShutdownCommand) ──► queue front
//!       │ mbx.receive ×4
//!       ▼
//!  OOB ShutdownCommand arrives first, then Events in send order
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

    try sendItems(mbx, allocator);
    try sendOobItem(mbx, allocator);
    std.log.info("sent 3 Events (regular) + 1 ShutdownCommand (OOB)", .{});
    try processingLoop(mbx, allocator);
}

fn sendItems(mbx: *Mbox, alloc: std.mem.Allocator) !void {
    for (0..3) |i| {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(alloc, &slot);
        try items.Event.EventPolyHelper.create(alloc, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
        try mbx.send(&slot);
    }
}

fn sendOobItem(mbx: *Mbox, alloc: std.mem.Allocator) !void {
    var slot: Slot = null;
    defer items.ShutdownCommand.ShutdownCommandPolyHelper.destroy(alloc, &slot);
    try items.ShutdownCommand.ShutdownCommandPolyHelper.create(alloc, &slot);
    try mbx.send_oob(&slot);
}

fn processingLoop(mbx: *Mbox, alloc: std.mem.Allocator) !void {
    var shutdown_seen: bool = false;
    var event_count: usize = 0;

    for (0..4) |_| {
        var slot: Slot = null;
        defer items.freeSlot(&slot, alloc);
        try mbx.receive(&slot, null);
        const poly: *PolyNode = slot.?;

        if (items.ShutdownCommand.ShutdownCommandPolyHelper.fromPoly(poly)) |_| {
            try helpers.expect(error.OobOrderFailed, !shutdown_seen, "OOB ShutdownCommand must arrive before any Event");
            try helpers.expect(error.OobOrderFailed, event_count == 0, "OOB must be first item received");
            shutdown_seen = true;
            std.log.info("received OOB ShutdownCommand (first, as expected)", .{});
            items.freeSlot(&slot, alloc);
        } else if (items.Event.EventPolyHelper.fromPoly(poly)) |ev| {
            try helpers.expect(error.OobOrderFailed, shutdown_seen, "Events must arrive after the OOB item");
            event_count += 1;
            std.log.info("received Event code={d} (event {d}/3)", .{ ev.code, event_count });
            items.freeSlot(&slot, alloc);
        } else {
            return error.OobOrderFailed;
        }
    }

    try helpers.expect(error.OobOrderFailed, shutdown_seen, "OOB item not received");
    try helpers.expect(error.OobOrderFailed, event_count == 3, "expected 3 Events");
    std.log.info("OOB ordering verified: shutdown came first, then {d} events", .{event_count});
}

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const Mbox = matryoshka.Mbox;
const polynode = matryoshka.polynode;
const PolyNode = polynode.PolyNode;
const Slot = polynode.Slot;
