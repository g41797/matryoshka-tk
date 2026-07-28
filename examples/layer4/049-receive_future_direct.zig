// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! receive_future awaited directly.
//!
//! - Send one Event into the mailbox.
//! - mailbox.receive_future returns an Io.Future(ReceiveResult), no Select needed.
//! - fut.await blocks until the item arrives, then it's freed.
//!
//!
//! ```
//!  master ──EventPolyHelper.create──► slot
//!          ──mailbox.send──► mailbox
//!          │
//!  receive_future ──► Future(ReceiveResult)
//!  fut.await ──► ReceiveResult .item ──► slot (master owns)
//!          │
//!  freeSlot
//! ```
//!

pub fn receive_future_awaited_directly(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbh: MailboxHandle = try mailbox.new(io, allocator);
    defer {
        var rem: std.DoublyLinkedList = mailbox.close(mbh);
        items.freeList(&rem, allocator);
        mailbox.destroy(mbh, allocator);
    }

    try sendItem(mbh, allocator);
    try receiveAndVerify(mbh, allocator, io);
}

fn sendItem(mbh: MailboxHandle, alloc: std.mem.Allocator) !void {
    var slot: Slot = null;
    defer items.Event.EventPolyHelper.destroy(alloc, &slot);
    try items.Event.EventPolyHelper.create(alloc, &slot);
    items.Event.EventPolyHelper.mustFromSlot(&slot).code = 42;
    try mailbox.send(mbh, &slot);
}

fn receiveAndVerify(mbh: MailboxHandle, alloc: std.mem.Allocator, io: std.Io) !void {
    var fut: std.Io.Future(mailbox.ReceiveResult) = try mailbox.receive_future(mbh, null);
    const result: mailbox.ReceiveResult = fut.await(io);

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
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
