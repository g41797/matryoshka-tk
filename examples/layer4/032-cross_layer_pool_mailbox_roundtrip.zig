// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Pool → Mailbox → Pool roundtrip.
//!
//! - getAndSend: pl.get fills an item, mbx.send transfers it.
//! - receiveAndVerify: mbx.receive gets it back, verifies same pointer and data.
//! - verifyRecycle: pl.put then available_only.get() confirms the same pointer recycles.
//! - Single-threaded — no concurrency needed to prove the transfer path.
//!
//!
//! ```
//!  pl.get ──► slot (code=42, ptr=P)
//!  mbx.send ──► mailbox owns P
//!  mbx.receive ──► slot (same ptr P, code still 42)
//!  verify code==42, ptr==P
//!  pl.put ──► pool free-list (P recycled)
//!  pl.get (.available_only) ──► slot (same ptr P)
//!  verify ptr==P ──► pl.put ──► pool
//!  pl.close ──► on_close ──► freed
//! ```
//!

pub fn pool_mailbox_pool_roundtrip(allocator: std.mem.Allocator, io: std.Io) !void {
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
    const sent_ptr = try ctx.getAndSend();
    try ctx.receiveAndVerify(sent_ptr);
    try ctx.verifyRecycle(sent_ptr);
}

const Ctx = struct {
    pl: *Pool,
    mbx: *Mbox,
    alloc: std.mem.Allocator,

    fn getAndSend(self: *Ctx) !*items.Event {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(self.alloc, &slot);
        try self.pl.get(items.Event.EventPolyHelper.TAG, .new_only, &slot);
        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
        ev.code = 42;
        std.log.info("Pool.get: code={d} ptr={*}", .{ ev.code, ev });
        try self.mbx.send(&slot);
        return ev;
    }

    fn receiveAndVerify(self: *Ctx, sent_ptr: *items.Event) !void {
        var slot: Slot = null;
        try self.mbx.receive(&slot, null);
        defer self.pl.put(&slot);
        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
        try helpers.expect(error.CrossLayerRoundtripFailed, ev.code == 42, "wrong code after receive");
        try helpers.expect(error.CrossLayerRoundtripFailed, ev == sent_ptr, "not same pointer after receive");
        std.log.info("Mbox.receive: code={d} same_ptr={}", .{ ev.code, ev == sent_ptr });
    }

    fn verifyRecycle(self: *Ctx, sent_ptr: *items.Event) !void {
        var slot: Slot = null;
        defer self.pl.put(&slot);
        try self.pl.get(items.Event.EventPolyHelper.TAG, .available_only, &slot);
        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
        try helpers.expect(error.CrossLayerRoundtripFailed, ev == sent_ptr, "not same pointer on second get");
        std.log.info("Pool.get (recycled): same_ptr={} — pool→mailbox→pool roundtrip complete", .{ev == sent_ptr});
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
