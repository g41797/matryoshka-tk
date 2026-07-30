// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Timeout on mailbox.
//!
//! - receiveTimeouts calls mailbox.receive with a non-null timeout, twice, on an empty mailbox.
//! - Each call returns error.Timeout; Io.sleep runs between retries.
//! - sendAndReceive sends one Event, then receives it back within the same timeout.
//!
//!
//! ```
//!  mailbox (initially empty)
//!  │
//!  master: receive(50ms) ──► error.Timeout ──► Io.sleep retry
//!          receive(50ms) ──► error.Timeout ──► (second retry)
//!  │
//!  EventPolyHelper.create ──► slot ──mailbox.send──► mailbox
//!  │
//!  master: receive(50ms) ──► slot ──► freeSlot
//! ```
//!

pub fn timeout_on_mailbox(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbh: MailboxHandle = try mailbox.new(io, allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh);
        items.freeList(&rem, allocator);
        mailbox.destroy(mbh, allocator);
    }

    var ctx: Ctx = .{ .mbh = mbh, .alloc = allocator, .io = io };
    const retries = try ctx.receiveTimeouts();
    try helpers.expect(error.MailboxTimeoutFailed, retries == 2, "expected 2 timeouts");
    try ctx.sendAndReceive();
    std.log.info("done: {d} timeouts then 1 successful receive", .{retries});
}

const TIMEOUT_NS: u64 = 50_000_000; // 50 ms
const SLEEP_NS: i96 = 10_000_000; // 10 ms between retries

const Ctx = struct {
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,
    io: std.Io,

    fn receiveTimeouts(self: *Ctx) !usize {
        const sleep_t: std.Io.Timeout = .{
            .duration = .{ .raw = .{ .nanoseconds = SLEEP_NS }, .clock = .real },
        };
        var retries: usize = 0;
        while (retries < 2) {
            var slot: Slot = null;
            mailbox.receive(self.mbh, &slot, TIMEOUT_NS) catch |err| switch (err) {
                error.Timeout => {
                    retries += 1;
                    std.log.info("receive: .Timeout (retry {d})", .{retries});
                    std.Io.Timeout.sleep(sleep_t, self.io) catch {};
                    continue;
                },
                else => return err,
            };
            defer items.freeSlot(&slot, self.alloc);
            std.log.info("receive: got item (unexpected)", .{});
            break;
        }
        return retries;
    }

    fn sendAndReceive(self: *Ctx) !void {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(self.alloc, &slot);
        try items.Event.EventPolyHelper.create(self.alloc, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = 9;
        try mailbox.send(self.mbh, &slot);

        var received: Slot = null;
        defer items.freeSlot(&received, self.alloc);
        try mailbox.receive(self.mbh, &received, TIMEOUT_NS);
        std.log.info("receive after send: code={d}", .{items.Event.EventPolyHelper.mustFromSlot(&received).code});
    }
};

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
