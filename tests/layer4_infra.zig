// --- Scenario 18: Mbox is a PolyNode ---
test "18 - Mbox is a PolyNode" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbx: *Mbox = try mailbox.new(io, alloc);
    try testing.expect(Mbox.is_it_you(mbx.poly.tag));
    var rem: polynode.ItemList = mbx.close();
    items.freeList(&rem, alloc);
    mailbox.destroy(mbx, alloc);
}

// --- Scenario 19: Pool is a PolyNode ---
test "19 - Pool is a PolyNode" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const pl: *Pool = try pool.new(io, alloc);
    try testing.expect(Pool.is_it_you(pl.poly.tag));
    pl.close();
    pool.destroy(pl, alloc);
}

// --- Scenario 20: per-module destroy ---
test "20 - per-module destroy" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbx: *Mbox = try mailbox.new(io, alloc);
    var rem: polynode.ItemList = mbx.close();
    items.freeList(&rem, alloc);
    mailbox.destroy(mbx, alloc);

    const pl: *Pool = try pool.new(io, alloc);
    pl.close();
    pool.destroy(pl, alloc);
}

// --- Scenario 93: send mailbox through mailbox ---
test "93 - send mailbox through mailbox" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const carrier: *Mbox = try mailbox.new(io, alloc);
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

    const inner: *Mbox = try mailbox.new(io, alloc);

    {
        var slot: Slot = Mbox.toPoly(inner);
        try carrier.send(&slot);
        try testing.expect(slot == null);
    }

    var slot: Slot = null;
    try carrier.receive(&slot, null);
    try testing.expect(slot != null);
    try testing.expect(Mbox.is_it_you(slot.?.*.tag));

    const recovered: *Mbox = Mbox.mustFromPoly(slot.?);
    var rem: polynode.ItemList = recovered.close();
    items.freeList(&rem, alloc);
    mailbox.destroy(recovered, alloc);
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

    const carrier: *Pool = try pool.new(io, alloc);
    var transport_ctx: PoolTransportCtx = .{ .alloc = alloc };
    const pool_tags = [_]*const anyopaque{Pool.TAG};
    try carrier.init(.{
        .ctx = &transport_ctx,
        .tags = &pool_tags,
        .on_get = poolTransportOnGet,
        .on_put = poolTransportOnPut,
        .on_close = poolTransportOnClose,
    });
    defer {
        carrier.close();
        pool.destroy(carrier, alloc);
    }

    const inner: *Pool = try pool.new(io, alloc);

    {
        var slot: Slot = Pool.toPoly(inner);
        carrier.put(&slot);
        try testing.expect(slot == null);
    }

    var slot: Slot = null;
    try carrier.get(Pool.TAG, .available_only, &slot);
    try testing.expect(slot != null);
    try testing.expect(Pool.is_it_you(slot.?.*.tag));

    const recovered: *Pool = Pool.mustFromPoly(slot.?);
    recovered.close();
    pool.destroy(recovered, alloc);
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
