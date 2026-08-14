// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Close ordering: mailbox then pool.
//!
//! - Seed the pool with 1 item, the mailbox with 1 item.
//! - closeMailbox closes the mailbox, returns its list.
//! - returnCloseListToPool walks that list, returns each item to the still-open pool.
//! - pl.close (deferred) then frees both items via on_close.
//!
//!
//! ```
//!  pool (1 item in free-list)    mailbox (1 item in queue)
//!  │
//!  mbx.close ──► ItemList (1 item)
//!  walk list: popFirst ──► fromPoly ──► pl.put (pool still open)
//!  │                                        └──► pool free-list (now 2 items)
//!  pl.close ──► on_close ──► freeList (both items freed)
//!  │
//!  Verify: pool received the item from mailbox close list.
//! ```
//!

pub fn close_ordering_mailbox_then_pool(allocator: std.mem.Allocator, io: std.Io) !void {
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
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

    try seedPool(pl);
    try seedMailbox(mbx, allocator);
    std.log.info("before close: 1 item in pool, 1 item in mailbox", .{});

    var rem: polynode.ItemList = closeMailbox(mbx, allocator);
    const returned = returnCloseListToPool(pl, &rem);

    try helpers.expect(error.CrossLayerCloseOrderFailed, returned == 1, "expected 1 item from mailbox close");
    std.log.info("pool now has 2 items — Pool.close will free all via on_close", .{});
    // Deferred pl.close calls on_close with both items.
}

fn seedPool(pl: *Pool) !void {
    var slot: Slot = null;
    try pl.get(items.Event.EventPolyHelper.TAG, .new_only, &slot);
    items.Event.EventPolyHelper.mustFromSlot(&slot).code = 1;
    pl.put(&slot);
}

fn seedMailbox(mbx: *Mbox, alloc: std.mem.Allocator) !void {
    var slot: Slot = null;
    defer items.Event.EventPolyHelper.destroy(alloc, &slot);
    try items.Event.EventPolyHelper.create(alloc, &slot);
    items.Event.EventPolyHelper.mustFromSlot(&slot).code = 2;
    try mbx.send(&slot);
}

fn closeMailbox(mbx: *Mbox, alloc: std.mem.Allocator) polynode.ItemList {
    const rem: polynode.ItemList = mbx.close();
    mailbox.destroy(mbx, alloc);
    return rem;
}

fn returnCloseListToPool(pl: *Pool, rem: *polynode.ItemList) usize {
    var returned: usize = 0;
    while (rem.popFirst()) |poly| {
        var slot: Slot = poly;
        pl.put(&slot);
        returned += 1;
        std.log.info("mailbox close list: returned item to pool (code={d})", .{items.Event.EventPolyHelper.mustFromPoly(poly).code});
    }
    return returned;
}

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
