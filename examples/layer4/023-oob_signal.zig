// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! OOB via send_oob.
//!
//! - Send 3 Events via mailbox.send, queued in order.
//! - Send a ShutdownCommand via mailbox.send_oob, jumps to queue front.
//! - processingLoop receives 4 items: OOB signal first, then the 3 Events.
//! - Free every received item, verify the arrival order.
//!
//!
//! ```
//!  mailbox.send (Event×3) ──► queue tail
//!  mailbox.send_oob (ShutdownCommand) ──► queue front
//!       │ mailbox.receive ×4
//!       ▼
//!  OOB ShutdownCommand arrives first, then Events in send order
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

    try sendItems(mbh, allocator);
    try sendOobItem(mbh, allocator);
    std.log.info("sent 3 Events (regular) + 1 ShutdownCommand (OOB)", .{});
    try processingLoop(mbh, allocator);
}

fn sendItems(mbh: MailboxHandle, alloc: std.mem.Allocator) !void {
    for (0..3) |i| {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(alloc, &slot);
        try items.Event.EventPolyHelper.create(alloc, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
        try mailbox.send(mbh, &slot);
    }
}

fn sendOobItem(mbh: MailboxHandle, alloc: std.mem.Allocator) !void {
    var slot: Slot = null;
    defer items.ShutdownCommand.ShutdownCommandPolyHelper.destroy(alloc, &slot);
    try items.ShutdownCommand.ShutdownCommandPolyHelper.create(alloc, &slot);
    try mailbox.send_oob(mbh, &slot);
}

fn processingLoop(mbh: MailboxHandle, alloc: std.mem.Allocator) !void {
    var shutdown_seen: bool = false;
    var event_count: usize = 0;

    for (0..4) |_| {
        var slot: Slot = null;
        defer items.freeSlot(&slot, alloc);
        try mailbox.receive(mbh, &slot, null);
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
const polynode = matryoshka.polynode;
const PolyNode = polynode.PolyNode;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
