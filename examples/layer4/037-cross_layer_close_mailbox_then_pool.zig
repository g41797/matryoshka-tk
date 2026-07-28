// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Close ordering: mailbox then pool.
//!
//! - Seed the pool with 1 item, the mailbox with 1 item.
//! - closeMailbox closes the mailbox, returns its list.
//! - returnCloseListToPool walks that list, returns each item to the still-open pool.
//! - pool.close (deferred) then frees both items via on_close.
//!
//!
//! ```
//!  pool (1 item in free-list)    mailbox (1 item in queue)
//!  │
//!  mailbox.close ──► std.DoublyLinkedList (1 item)
//!  walk list: popFirst ──► fromNode ──► pool.put (pool still open)
//!  │                                        └──► pool free-list (now 2 items)
//!  pool.close ──► on_close ──► freeList (both items freed)
//!  │
//!  Verify: pool received the item from mailbox close list.
//! ```
//!

pub fn close_ordering_mailbox_then_pool(allocator: std.mem.Allocator, io: std.Io) !void {
    const ph: PoolHandle = try pool.new(io, allocator);
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};
    try pool.init(ph, pool_ctx.poolHooks(&tags));
    defer {
        pool.close(ph);
        pool.destroy(ph, allocator);
    }

    const mbh: MailboxHandle = try mailbox.new(io, allocator);

    try seedPool(ph);
    try seedMailbox(mbh, allocator);
    std.log.info("before close: 1 item in pool, 1 item in mailbox", .{});

    var rem: std.DoublyLinkedList = closeMailbox(mbh, allocator);
    const returned = returnCloseListToPool(ph, &rem);

    try helpers.expect(error.CrossLayerCloseOrderFailed, returned == 1, "expected 1 item from mailbox close");
    std.log.info("pool now has 2 items — pool.close will free all via on_close", .{});
    // Deferred pool.close calls on_close with both items.
}

fn seedPool(ph: PoolHandle) !void {
    var slot: Slot = null;
    try pool.get(ph, items.Event.EventPolyHelper.TAG, .new_only, &slot);
    items.Event.EventPolyHelper.mustFromSlot(&slot).code = 1;
    pool.put(ph, &slot);
}

fn seedMailbox(mbh: MailboxHandle, alloc: std.mem.Allocator) !void {
    var slot: Slot = null;
    defer items.Event.EventPolyHelper.destroy(alloc, &slot);
    try items.Event.EventPolyHelper.create(alloc, &slot);
    items.Event.EventPolyHelper.mustFromSlot(&slot).code = 2;
    try mailbox.send(mbh, &slot);
}

fn closeMailbox(mbh: MailboxHandle, alloc: std.mem.Allocator) std.DoublyLinkedList {
    const rem: std.DoublyLinkedList = mailbox.close(mbh);
    mailbox.destroy(mbh, alloc);
    return rem;
}

fn returnCloseListToPool(ph: PoolHandle, rem: *std.DoublyLinkedList) usize {
    var returned: usize = 0;
    while (rem.popFirst()) |node| {
        const poly: *polynode.PolyNode = @fieldParentPtr("node", node);
        polynode.reset(poly);
        var slot: Slot = poly;
        pool.put(ph, &slot);
        returned += 1;
        std.log.info("mailbox close list: returned item to pool (code={d})", .{items.Event.EventPolyHelper.mustFromNode(poly).code});
    }
    return returned;
}

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
