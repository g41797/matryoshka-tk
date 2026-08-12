// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! receive_future with timeout.
//!
//! - receiveWithTimeout: receive_future on an empty mailbox with a 50ms timeout, resolves .timeout.
//! - sendAndReceiveItem: sends one Event, then receive_future(null) resolves .item.
//! - Confirms the future resolves to whichever result actually occurs.
//!
//!
//! ```
//!  mailbox (empty)
//!  │
//!  receive_future(50ms) ──► Future(Mbox.Result)
//!  fut.await ──► Mbox.Result .timeout
//!  │
//!  EventPolyHelper.create ──► slot ──mbx.send──► mailbox
//!  receive_future(null) ──► fut.await ──► Mbox.Result .item ──► freeSlot
//! ```
//!

pub fn receive_future_with_timeout(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbx: *Mbox = try mailbox.new(io, allocator);
    defer {
        var rem: polynode.ItemList = mbx.close();
        items.freeList(&rem, allocator);
        mailbox.destroy(mbx, allocator);
    }

    var ctx: Ctx = .{ .mbx = mbx, .alloc = allocator, .io = io };
    try ctx.receiveWithTimeout();
    try ctx.sendAndReceiveItem();
}

const TIMEOUT_NS: u64 = 50_000_000; // 50 ms

const Ctx = struct {
    mbx: *Mbox,
    alloc: std.mem.Allocator,
    io: std.Io,

    fn receiveWithTimeout(self: *Ctx) !void {
        var fut_t: std.Io.Future(Mbox.Result) = try self.mbx.receive_future(TIMEOUT_NS);
        const r_timeout: Mbox.Result = fut_t.await(self.io);
        try helpers.expect(error.ReceiveFutureTimeoutFailed, r_timeout == .timeout, "expected .timeout");
        std.log.info("receive_future timeout: got .timeout as expected", .{});
    }

    fn sendAndReceiveItem(self: *Ctx) !void {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(self.alloc, &slot);
        try items.Event.EventPolyHelper.create(self.alloc, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = 5;
        try self.mbx.send(&slot);

        var fut_item: std.Io.Future(Mbox.Result) = try self.mbx.receive_future(null);
        const r_item: Mbox.Result = fut_item.await(self.io);
        switch (r_item) {
            .item => |handle| {
                var received: Slot = handle;
                defer items.freeSlot(&received, self.alloc);
                std.log.info("receive_future after timeout: got Event code={d}", .{items.Event.EventPolyHelper.mustFromSlot(&received).code});
            },
            else => return error.ReceiveFutureTimeoutFailed,
        }
    }
};

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const Mbox = matryoshka.Mbox;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
