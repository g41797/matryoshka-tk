// --- Scenario 18: Mbox is a PolyNode ---
test "18 - Mbox is a PolyNode" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    var mbx_slot: Slot = null;
    try mailbox.new(io, alloc, &mbx_slot);
    const mbx: *Mbox = Mbox.moveFromSlot(&mbx_slot).?;
    try testing.expect(Mbox.is_it_you(mbx.poly.tag));
    var rem: polynode.ItemList = mbx.close();
    items.freeList(&rem, alloc);
    mailbox.destroy(mbx, alloc);
}

// Hooks for a pool that is never `get` or `put`.
//
// `new` registers hooks and `close` calls `on_close`, so even a pool that only
// proves its own tag needs a full set. The list `on_close` receives is always
// empty here, because nothing is ever stored.
const InertCtx = struct {};
var inert_ctx: InertCtx = .{};
const inert_tags = [_]*const anyopaque{Pool.TAG};

fn inertOnGet(_: *anyopaque, _: *const anyopaque, _: usize, _: *Slot) void {}

fn inertOnPut(_: *anyopaque, _: usize, _: *Slot) ?polynode.ItemList {
    return null;
}

fn inertOnClose(_: *anyopaque, list: *polynode.ItemList) void {
    std.debug.assert(list.first() == null);
}

const inert_hooks: Pool.Hooks = .{
    .ctx = &inert_ctx,
    .tags = &inert_tags,
    .on_get = inertOnGet,
    .on_put = inertOnPut,
    .on_close = inertOnClose,
};

// --- Scenario 19: Pool is a PolyNode ---
test "19 - Pool is a PolyNode" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    var pl_slot: Slot = null;
    try pool.new(io, alloc, inert_hooks, &pl_slot);
    const pl: *Pool = Pool.moveFromSlot(&pl_slot).?;
    try testing.expect(Pool.is_it_you(pl.poly.tag));
    pl.close();
    pool.destroy(pl, alloc);
}

// --- Scenario 20: per-module destroy ---
test "20 - per-module destroy" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    var mbx_slot: Slot = null;
    try mailbox.new(io, alloc, &mbx_slot);
    const mbx: *Mbox = Mbox.moveFromSlot(&mbx_slot).?;
    var rem: polynode.ItemList = mbx.close();
    items.freeList(&rem, alloc);
    mailbox.destroy(mbx, alloc);

    var pl_slot: Slot = null;
    try pool.new(io, alloc, inert_hooks, &pl_slot);
    const pl: *Pool = Pool.moveFromSlot(&pl_slot).?;
    pl.close();
    pool.destroy(pl, alloc);
}

// --- Scenario 93: send mailbox through mailbox ---
test "93 - send mailbox through mailbox" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    var carrier_slot: Slot = null;
    try mailbox.new(io, alloc, &carrier_slot);
    const carrier: *Mbox = Mbox.moveFromSlot(&carrier_slot).?;
    defer {
        // The carrier can only be holding `inner`, so the release closes and
        // destroys whatever mailbox is still in there.
        var rem: polynode.ItemList = carrier.close();
        while (rem.popFirst()) |ih| {
            const left: *Mbox = Mbox.mustFromPoly(ih);
            var left_rem: polynode.ItemList = left.close();
            items.freeList(&left_rem, alloc);
            mailbox.destroy(left, alloc);
        }
        mailbox.destroy(carrier, alloc);
    }

    var inner_slot: Slot = null;
    try mailbox.new(io, alloc, &inner_slot);
    const inner: *Mbox = Mbox.moveFromSlot(&inner_slot).?;

    {
        var slot: Slot = Mbox.toPoly(inner);
        try carrier.send(&slot);
        try testing.expect(slot == null);
    }

    var slot: Slot = null;
    try carrier.receive(&slot, null);
    try testing.expect(slot != null);
    try testing.expect(Mbox.is_it_you(slot.?.*.tag));

    const recovered: *Mbox = Mbox.mustFromSlot(&slot);
    var rem: polynode.ItemList = recovered.close();
    items.freeList(&rem, alloc);
    mailbox.destroy_slot(&slot, alloc);
}

// --- Scenario 94: hold pool as pool item ---

const PoolTransportCtx = struct {
    alloc: std.mem.Allocator,
};

fn poolTransportOnGet(_: *anyopaque, _: *const anyopaque, _: usize, _: *Slot) void {}

fn resetOnPut(_: *Slot) void {} // Pool items carry no resettable scalar state — kept for on_put-shape consistency

fn poolTransportOnPut(_: *anyopaque, _: usize, slot: *Slot) ?polynode.ItemList {
    resetOnPut(slot);
    return null;
}

fn poolTransportOnClose(ctx_opaque: *anyopaque, list: *polynode.ItemList) void {
    const ctx: *PoolTransportCtx = @ptrCast(@alignCast(ctx_opaque));
    while (list.popFirst()) |poly| {
        const pl: *Pool = Pool.mustFromPoly(poly);
        pl.close();
        pool.destroy(pl, ctx.alloc);
    }
}

test "94 - hold pool as pool item" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    var transport_ctx: PoolTransportCtx = .{ .alloc = alloc };
    const pool_tags = [_]*const anyopaque{Pool.TAG};

    var carrier_slot: Slot = null;
    try pool.new(io, alloc, .{
        .ctx = &transport_ctx,
        .tags = &pool_tags,
        .on_get = poolTransportOnGet,
        .on_put = poolTransportOnPut,
        .on_close = poolTransportOnClose,
    }, &carrier_slot);
    const carrier: *Pool = Pool.moveFromSlot(&carrier_slot).?;
    defer {
        carrier.close();
        pool.destroy(carrier, alloc);
    }

    var inner_slot: Slot = null;
    try pool.new(io, alloc, inert_hooks, &inner_slot);
    const inner: *Pool = Pool.moveFromSlot(&inner_slot).?;

    {
        var slot: Slot = Pool.toPoly(inner);
        carrier.put(&slot);
        try testing.expect(slot == null);
    }

    var slot: Slot = null;
    try carrier.get(Pool.TAG, .available_only, &slot);
    try testing.expect(slot != null);
    try testing.expect(Pool.is_it_you(slot.?.*.tag));

    const recovered: *Pool = Pool.mustFromSlot(&slot);
    recovered.close();
    pool.destroy_slot(&slot, alloc);
}

const items = @import("examples").items;
const matryoshka = @import("matryoshka");
const polynode = matryoshka.polynode;
const mailbox = matryoshka.mailbox;
const pool = matryoshka.pool;
const PolyNode = polynode.PolyNode;
const Slot = polynode.Slot;
const std = @import("std");
const testing = std.testing;
const Io = std.Io;
const Mbox = matryoshka.Mbox;
const Pool = matryoshka.Pool;
