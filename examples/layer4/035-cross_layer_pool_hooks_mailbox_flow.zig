// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Pool hooks + mailbox flow.
//!
//! - round1: on_get creates an item, mailbox carries it, on_put keeps it (cap
//!   not yet reached) and resets its data.
//! - round2: on_get creates a fresh item, mailbox carries it, on_put destroys
//!   it (cap reached).
//! - verifyRecycled confirms the kept item is still in the pool, holding
//!   reset data — not the value round1 set.
//!
//!
//! ```
//!  pl.get (new_only) ──► on_get creates ──► slot (code=1)
//!  mbx.send ──► mailbox owns item
//!  mbx.receive ──► slot (same item)
//!  pl.put ──► on_put: count<cap → keep, reset data ──► pool free-list
//!  │
//!  pl.get (new_only) ──► on_get creates fresh ──► slot (code=2)
//!  mbx.send ──► mailbox owns item
//!  mbx.receive ──► slot (same item)
//!  pl.put ──► on_put: count>=cap → destroy ──► freed
//!  │
//!  pl.get (.available_only) ──► recycled (data reset) ──► verify
//!  pl.close ──► on_close ──► freeList
//! ```
//!

pub fn pool_hooks_mailbox_flow(allocator: std.mem.Allocator, io: std.Io) !void {
    // CappedPoolHooks: cap=1 — first put keeps, second put destroys.
    var pool_ctx: hooks.CappedPoolHooks = .{ .alloc = allocator, .cap = 1, .io = io };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};

    var pl_slot: Slot = null;
    try pool.new(io, allocator, pool_ctx.poolHooks(&tags), &pl_slot);
    const pl: *Pool = Pool.moveFromSlot(&pl_slot).?;
    defer {
        pl.close();
        pool.destroy(pl, allocator);
    }

    var mbx_slot: Slot = null;
    try mailbox.new(io, allocator, &mbx_slot);
    const mbx: *Mbox = Mbox.moveFromSlot(&mbx_slot).?;
    defer {
        var rem: polynode.ItemList = mbx.close();
        items.freeList(&rem, allocator);
        mailbox.destroy(mbx, allocator);
    }

    var ctx: Ctx = .{ .pl = pl, .mbx = mbx, .alloc = allocator };
    try ctx.round1();
    try ctx.round2();
    try ctx.verifyRecycled();
}

const Ctx = struct {
    pl: *Pool,
    mbx: *Mbox,
    alloc: std.mem.Allocator,

    fn round1(self: *Ctx) !void {
        {
            var slot: Slot = null;
            defer items.Event.EventPolyHelper.destroy(self.alloc, &slot);
            try self.pl.get(items.Event.EventPolyHelper.TAG, .new_only, &slot);
            items.Event.EventPolyHelper.mustFromSlot(&slot).code = 1;
            std.log.info("on_get: created Event code=1", .{});
            try self.mbx.send(&slot);
        }
        {
            var slot: Slot = null;
            try self.mbx.receive(&slot, null);
            defer self.pl.put(&slot);
            std.log.info("on_put: count<cap → keeping Event code={d}", .{items.Event.EventPolyHelper.mustFromSlot(&slot).code});
        }
    }

    fn round2(self: *Ctx) !void {
        {
            var slot: Slot = null;
            defer items.Event.EventPolyHelper.destroy(self.alloc, &slot);
            try self.pl.get(items.Event.EventPolyHelper.TAG, .new_only, &slot);
            items.Event.EventPolyHelper.mustFromSlot(&slot).code = 2;
            std.log.info("on_get: created fresh Event code=2", .{});
            try self.mbx.send(&slot);
        }
        {
            var slot: Slot = null;
            try self.mbx.receive(&slot, null);
            defer items.freeSlot(&slot, self.alloc);
            std.log.info("on_put: count>=cap → destroying Event code={d}", .{items.Event.EventPolyHelper.mustFromSlot(&slot).code});
            self.pl.put(&slot);
            // on_put set slot.* = null — item was freed; freeSlot sees null → no-op.
        }
    }

    fn verifyRecycled(self: *Ctx) !void {
        var slot: Slot = null;
        defer self.pl.put(&slot);
        try self.pl.get(items.Event.EventPolyHelper.TAG, .available_only, &slot);
        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
        try helpers.expect(error.CrossLayerHooksFailed, ev.code == 0, "expected reset default, not round1's value");
        std.log.info("recycled item: code={d} (reset by on_put) — hooks decided keep/destroy correctly", .{ev.code});
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
