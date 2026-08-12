// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Producer → consumer with recycling.
//!
//! - produce: pl.get fills an item, mbx.send transfers it.
//! - consume: mbx.receive gets it back, verifies same pointer, pl.put recycles it.
//! - verifyRecycle: available_only.get() confirms the same pointer — but
//!   on_put already reset the data, so the recycled item holds defaults, not
//!   the value the producer set.
//!
//!
//! ```
//!  pl.get ──► slot ──► producer fills (code=1)
//!  mbx.send ──► mailbox
//!  │
//!  consumer: mbx.receive ──► slot (same pointer)
//!            verify code==1
//!            pl.put ──► on_put resets data ──► pool (item recycled)
//!  │
//!  pl.get ──► slot (same pointer, data reset)
//!  verify reset ──► pl.put ──► pool
//!  pl.close ──► on_close ──► freeList
//! ```
//!

pub fn producer_consumer_with_recycling(allocator: std.mem.Allocator, io: std.Io) !void {
    const pl: *Pool = try pool.new(io, allocator);
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};
    try pl.init(pool_ctx.poolHooks(&tags));
    defer {
        pl.close();
        pool.destroy(pl, allocator);
    }

    const mbx: *Mbox = try mailbox.new(io, allocator);
    defer {
        var rem: polynode.ItemList = mbx.close();
        items.freeList(&rem, allocator);
        mailbox.destroy(mbx, allocator);
    }

    var ctx: Ctx = .{ .pl = pl, .mbx = mbx, .alloc = allocator };
    const sent_ptr = try ctx.produce();
    try ctx.consume(sent_ptr);
    try ctx.verifyRecycle();
}

const Ctx = struct {
    pl: *Pool,
    mbx: *Mbox,
    alloc: std.mem.Allocator,

    fn produce(self: *Ctx) !*items.Event {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(self.alloc, &slot);
        try self.pl.get(items.Event.EventPolyHelper.TAG, .new_only, &slot);
        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
        ev.code = 1;
        std.log.info("producer: get from pool, fill code={d}", .{ev.code});
        try self.mbx.send(&slot);
        return ev;
    }

    fn consume(self: *Ctx, sent_ptr: *items.Event) !void {
        var slot: Slot = null;
        try self.mbx.receive(&slot, null);
        defer self.pl.put(&slot);
        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
        try helpers.expect(error.ProducerConsumerFailed, ev.code == 1, "wrong code after receive");
        try helpers.expect(error.ProducerConsumerFailed, @as(*items.Event, ev) == sent_ptr, "not same pointer");
        std.log.info("consumer: received code={d}, same pointer={}", .{ ev.code, @as(*items.Event, ev) == sent_ptr });
    }

    fn verifyRecycle(self: *Ctx) !void {
        var slot: Slot = null;
        defer self.pl.put(&slot);
        try self.pl.get(items.Event.EventPolyHelper.TAG, .available_only, &slot);
        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
        try helpers.expect(error.ProducerConsumerFailed, ev.code == 0, "expected reset default, not the producer's value");
        std.log.info("recycled item: code={d} (reset by on_put) — pool → producer → mailbox → consumer → pool cycle complete", .{ev.code});
    }
};

const items = @import("../items/items.zig");
const hooks = @import("../hooks/hooks.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const Mbox = matryoshka.Mbox;
const pool = matryoshka.pool;
const Pool = matryoshka.Pool;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
