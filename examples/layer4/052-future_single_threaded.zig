// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! ConcurrencyUnavailable on single-threaded.
//!
//! - On a single-threaded Io backend, mbx.receive_future returns error.ConcurrencyUnavailable.
//! - No concurrent task can be spawned to service the future.
//! - Synchronous mbx.receive still works — it needs no concurrency.
//!
//!
//! ```
//!  mailbox (single-threaded io)
//!  │
//!  receive_future ──► error.ConcurrencyUnavailable
//!  (no concurrent task can be spawned on single-threaded backend)
//!  │
//!  mbx.receive (synchronous) still works
//! ```
//!

pub fn concurrencyunavailable_on_single_threaded(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbx: *Mbox = try mailbox.new(io, allocator);
    defer {
        var rem: polynode.ItemList = mbx.close();
        items.freeList(&rem, allocator);
        mailbox.destroy(mbx, allocator);
    }

    try testFutureUnavailable(mbx);
    try testSynchronousReceive(mbx, allocator);
}

fn testFutureUnavailable(mbx: *Mbox) !void {
    if (mbx.receive_future(null)) |_| {
        return error.FutureSingleThreadedFailed;
    } else |_| {}
    std.log.info("receive_future: ConcurrencyUnavailable on single-threaded backend as expected", .{});
}

fn testSynchronousReceive(mbx: *Mbox, alloc: std.mem.Allocator) !void {
    var slot: Slot = null;
    defer items.Event.EventPolyHelper.destroy(alloc, &slot);
    try items.Event.EventPolyHelper.create(alloc, &slot);
    items.Event.EventPolyHelper.mustFromSlot(&slot).code = 1;
    try mbx.send(&slot);

    var received: Slot = null;
    defer items.freeSlot(&received, alloc);
    try mbx.receive(&received, null);
    std.log.info("synchronous receive still works: code={d}", .{items.Event.EventPolyHelper.mustFromSlot(&received).code});
}

const items = @import("../items/items.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const Mbox = matryoshka.Mbox;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
