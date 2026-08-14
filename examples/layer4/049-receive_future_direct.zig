// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! receive_future awaited directly.
//!
//! - Send one Event into the mailbox.
//! - mbx.receive_future returns an Io.Future(Mbox.Result), no Select needed.
//! - fut.await blocks until the item arrives, then it's freed.
//!
//!
//! ```
//!  master ──EventPolyHelper.create──► slot
//!          ──mbx.send──► mailbox
//!          │
//!  receive_future ──► Future(Mbox.Result)
//!  fut.await ──► Mbox.Result .item ──► slot (master owns)
//!          │
//!  freeSlot
//! ```
//!

pub fn receive_future_awaited_directly(allocator: std.mem.Allocator, io: std.Io) !void {
    var mbx_slot: Slot = null;
    try mailbox.new(io, allocator, &mbx_slot);
    const mbx: *Mbox = Mbox.moveFromSlot(&mbx_slot).?;
    defer {
        var rem: polynode.ItemList = mbx.close();
        items.freeList(&rem, allocator);
        mailbox.destroy(mbx, allocator);
    }

    try sendItem(mbx, allocator);
    try receiveAndVerify(mbx, allocator, io);
}

fn sendItem(mbx: *Mbox, alloc: std.mem.Allocator) !void {
    var slot: Slot = null;
    defer items.Event.EventPolyHelper.destroy(alloc, &slot);
    try items.Event.EventPolyHelper.create(alloc, &slot);
    items.Event.EventPolyHelper.mustFromSlot(&slot).code = 42;
    try mbx.send(&slot);
}

fn receiveAndVerify(mbx: *Mbox, alloc: std.mem.Allocator, io: std.Io) !void {
    var fut: std.Io.Future(Mbox.Result) = try mbx.receive_future(null);
    const result: Mbox.Result = fut.await(io);

    switch (result) {
        .item => |handle| {
            var received: Slot = handle;
            defer items.freeSlot(&received, alloc);
            const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&received);
            try helpers.expect(error.ReceiveFutureDirectFailed, ev.code == 42, "wrong code");
            std.log.info("receive_future direct: got Event code={d}", .{ev.code});
        },
        else => return error.ReceiveFutureDirectFailed,
    }
}

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const Mbox = matryoshka.Mbox;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
