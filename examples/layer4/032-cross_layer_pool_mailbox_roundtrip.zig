// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Pool → Mailbox → Pool roundtrip.
//!
//! - getAndSend: pool.get fills an item, mailbox.send transfers it.
//! - receiveAndVerify: mailbox.receive gets it back, verifies same pointer and data.
//! - verifyRecycle: pool.put then pool.get(available_only) confirms the same pointer recycles.
//! - Single-threaded — no concurrency needed to prove the ownership path.
//!
//!
//! ```
//!  pool.get ──► slot (code=42, ptr=P)
//!  mailbox.send ──► mailbox owns P
//!  mailbox.receive ──► slot (same ptr P, code still 42)
//!  verify code==42, ptr==P
//!  pool.put ──► pool free-list (P recycled)
//!  pool.get (.available_only) ──► slot (same ptr P)
//!  verify ptr==P ──► pool.put ──► pool
//!  pool.close ──► on_close ──► freed
//! ```
//!

pub fn pool_mailbox_pool_roundtrip(allocator: std.mem.Allocator, io: std.Io) !void {
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
        var rem: std.DoublyLinkedList = mailbox.close(mbh);
        items.freeList(&rem, allocator);
        mailbox.destroy(mbh, allocator);
    }

    var ctx: Ctx = .{ .ph = ph, .mbh = mbh, .alloc = allocator };
    const sent_ptr = try ctx.getAndSend();
    try ctx.receiveAndVerify(sent_ptr);
    try ctx.verifyRecycle(sent_ptr);
}

const Ctx = struct {
    ph: PoolHandle,
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,

    fn getAndSend(self: *Ctx) !*items.Event {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(self.alloc, &slot);
        try pool.get(self.ph, items.Event.EventPolyHelper.TAG, .new_only, &slot);
        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
        ev.code = 42;
        std.log.info("pool.get: code={d} ptr={*}", .{ ev.code, ev });
        try mailbox.send(self.mbh, &slot);
        return ev;
    }

    fn receiveAndVerify(self: *Ctx, sent_ptr: *items.Event) !void {
        var slot: Slot = null;
        try mailbox.receive(self.mbh, &slot, null);
        defer pool.put(self.ph, &slot);
        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
        try helpers.expect(error.CrossLayerRoundtripFailed, ev.code == 42, "wrong code after receive");
        try helpers.expect(error.CrossLayerRoundtripFailed, ev == sent_ptr, "not same pointer after receive");
        std.log.info("mailbox.receive: code={d} same_ptr={}", .{ ev.code, ev == sent_ptr });
    }

    fn verifyRecycle(self: *Ctx, sent_ptr: *items.Event) !void {
        var slot: Slot = null;
        defer pool.put(self.ph, &slot);
        try pool.get(self.ph, items.Event.EventPolyHelper.TAG, .available_only, &slot);
        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
        try helpers.expect(error.CrossLayerRoundtripFailed, ev == sent_ptr, "not same pointer on second get");
        std.log.info("pool.get (recycled): same_ptr={} — pool→mailbox→pool roundtrip complete", .{ev == sent_ptr});
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
