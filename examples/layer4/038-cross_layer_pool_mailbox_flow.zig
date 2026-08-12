// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Pool + Mailbox flow.
//!
//! - getAndSend: pl.get fills an item, mbx.send transfers it.
//! - receiveAndVerify: mbx.receive gets it back, pl.put returns it.
//! - One transfer circuit, single-threaded — the minimal cross-layer flow.
//!
//!
//! ```
//!  pl.get ──► slot (code=7)
//!  mbx.send ──► mailbox owns item
//!  mbx.receive ──► slot (same item)
//!  pl.put ──► pool free-list
//!  pl.close ──► on_close ──► freed
//! ```
//!
//!  Pattern: pool → mailbox → pool. One transfer circuit, single-threaded.
//!

pub fn pool_mailbox_flow(allocator: std.mem.Allocator, io: std.Io) !void {
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
    try ctx.getAndSend();
    try ctx.receiveAndVerify();
}

const Ctx = struct {
    pl: *Pool,
    mbx: *Mbox,
    alloc: std.mem.Allocator,

    fn getAndSend(self: *Ctx) !void {
        var slot: Slot = null;
        defer items.Event.EventPolyHelper.destroy(self.alloc, &slot);
        try self.pl.get(items.Event.EventPolyHelper.TAG, .new_only, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = 7;
        std.log.info("Pool.get: code={d}", .{7});
        try self.mbx.send(&slot);
    }

    fn receiveAndVerify(self: *Ctx) !void {
        var slot: Slot = null;
        try self.mbx.receive(&slot, null);
        defer self.pl.put(&slot);
        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
        try helpers.expect(error.CrossLayerFlowFailed, ev.code == 7, "wrong code after receive");
        std.log.info("Mbox.receive: code={d} — pool→mailbox→pool flow complete", .{ev.code});
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
