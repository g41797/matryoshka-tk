// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Producer → consumer with recycling.
//!
//! - produce: pool.get fills an item, mailbox.send transfers it.
//! - consume: mailbox.receive gets it back, verifies same pointer, pool.put recycles it.
//! - verifyRecycle: pool.get(available_only) confirms the same pointer — but
//!   on_put already reset the data, so the recycled item holds defaults, not
//!   the value the producer set.
//!
//!
//! ```
//!  pool.get ──► slot ──► producer fills (code=1)
//!  mailbox.send ──► mailbox
//!  │
//!  consumer: mailbox.receive ──► slot (same pointer)
//!            verify code==1
//!            pool.put ──► on_put resets data ──► pool (item recycled)
//!  │
//!  pool.get ──► slot (same pointer, data reset)
//!  verify reset ──► pool.put ──► pool
//!  pool.close ──► on_close ──► freeList
//! ```
//!

pub fn producer_consumer_with_recycling(allocator: std.mem.Allocator, io: std.Io) !void {
    const ph: PoolHandle = try pool.new(io, allocator);
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};
    try pool.init(ph, pool_ctx.poolHooks(&tags));
    defer {
        pool.close(ph);
        pool.destroy(ph, allocator);
    }

    const mbh: MailboxHandle = try mailbox.new(io, allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh);
        items.freeList(&rem, allocator);
        mailbox.destroy(mbh, allocator);
    }

    var ctx: Ctx = .{ .ph = ph, .mbh = mbh, .alloc = allocator };
    const sent_ptr = try ctx.produce();
    try ctx.consume(sent_ptr);
    try ctx.verifyRecycle();
}

const Ctx = struct {
    ph: PoolHandle,
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,

    fn produce(self: *Ctx) !*items.Event {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(self.alloc, &slot);
        try pool.get(self.ph, items.Event.EventPolyHelper.TAG, .new_only, &slot);
        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
        ev.code = 1;
        std.log.info("producer: get from pool, fill code={d}", .{ev.code});
        try mailbox.send(self.mbh, &slot);
        return ev;
    }

    fn consume(self: *Ctx, sent_ptr: *items.Event) !void {
        var slot: Slot = null;
        try mailbox.receive(self.mbh, &slot, null);
        defer pool.put(self.ph, &slot);
        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
        try helpers.expect(error.ProducerConsumerFailed, ev.code == 1, "wrong code after receive");
        try helpers.expect(error.ProducerConsumerFailed, @as(*items.Event, ev) == sent_ptr, "not same pointer");
        std.log.info("consumer: received code={d}, same pointer={}", .{ ev.code, @as(*items.Event, ev) == sent_ptr });
    }

    fn verifyRecycle(self: *Ctx) !void {
        var slot: Slot = null;
        defer pool.put(self.ph, &slot);
        try pool.get(self.ph, items.Event.EventPolyHelper.TAG, .available_only, &slot);
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
const pool = matryoshka.pool;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
const PoolHandle = pool.PoolHandle;
