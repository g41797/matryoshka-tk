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
//!  pool.get (new_only) ──► on_get creates ──► slot (code=1)
//!  mailbox.send ──► mailbox owns item
//!  mailbox.receive ──► slot (same item)
//!  pool.put ──► on_put: count<cap → keep, reset data ──► pool free-list
//!  │
//!  pool.get (new_only) ──► on_get creates fresh ──► slot (code=2)
//!  mailbox.send ──► mailbox owns item
//!  mailbox.receive ──► slot (same item)
//!  pool.put ──► on_put: count>=cap → destroy ──► freed
//!  │
//!  pool.get (.available_only) ──► recycled (data reset) ──► verify
//!  pool.close ──► on_close ──► freeList
//! ```
//!

pub fn pool_hooks_mailbox_flow(allocator: std.mem.Allocator, io: std.Io) !void {
    const ph: PoolHandle = try pool.new(io, allocator);
    // CappedPoolHooks: cap=1 — first put keeps, second put destroys.
    var pool_ctx: hooks.CappedPoolHooks = .{ .alloc = allocator, .cap = 1, .io = io };
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
    try ctx.round1();
    try ctx.round2();
    try ctx.verifyRecycled();
}

const Ctx = struct {
    ph: PoolHandle,
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,

    fn round1(self: *Ctx) !void {
        {
            var slot: Slot = null;
            defer items.Event.EventPolyHelper.destroy(self.alloc, &slot);
            try pool.get(self.ph, items.Event.EventPolyHelper.TAG, .new_only, &slot);
            items.Event.EventPolyHelper.mustFromSlot(&slot).code = 1;
            std.log.info("on_get: created Event code=1", .{});
            try mailbox.send(self.mbh, &slot);
        }
        {
            var slot: Slot = null;
            try mailbox.receive(self.mbh, &slot, null);
            defer pool.put(self.ph, &slot);
            std.log.info("on_put: count<cap → keeping Event code={d}", .{items.Event.EventPolyHelper.mustFromSlot(&slot).code});
        }
    }

    fn round2(self: *Ctx) !void {
        {
            var slot: Slot = null;
            defer items.Event.EventPolyHelper.destroy(self.alloc, &slot);
            try pool.get(self.ph, items.Event.EventPolyHelper.TAG, .new_only, &slot);
            items.Event.EventPolyHelper.mustFromSlot(&slot).code = 2;
            std.log.info("on_get: created fresh Event code=2", .{});
            try mailbox.send(self.mbh, &slot);
        }
        {
            var slot: Slot = null;
            try mailbox.receive(self.mbh, &slot, null);
            defer items.freeSlot(&slot, self.alloc);
            std.log.info("on_put: count>=cap → destroying Event code={d}", .{items.Event.EventPolyHelper.mustFromSlot(&slot).code});
            pool.put(self.ph, &slot);
            // on_put set slot.* = null — item was freed; freeSlot sees null → no-op.
        }
    }

    fn verifyRecycled(self: *Ctx) !void {
        var slot: Slot = null;
        defer pool.put(self.ph, &slot);
        try pool.get(self.ph, items.Event.EventPolyHelper.TAG, .available_only, &slot);
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
const pool = matryoshka.pool;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
const PoolHandle = pool.PoolHandle;
