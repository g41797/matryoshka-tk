// --- Scenario 18: MailboxHandle is a PolyNode ---
test "18 - MailboxHandle is a PolyNode" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    try testing.expect(mailbox.is_it_you(mbh.*.tag));
    _ = mailbox.close(mbh);
    mailbox.destroy(mbh, alloc);
}

// --- Scenario 19: PoolHandle is a PolyNode ---
test "19 - PoolHandle is a PolyNode" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const ph: PoolHandle = try pool.new(io, alloc);
    try testing.expect(pool.is_it_you(ph.*.tag));
    pool.close(ph);
    pool.destroy(ph, alloc);
}

// --- Scenario 20: per-module destroy ---
test "20 - per-module destroy" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    _ = mailbox.close(mbh);
    mailbox.destroy(mbh, alloc);

    const ph: PoolHandle = try pool.new(io, alloc);
    pool.close(ph);
    pool.destroy(ph, alloc);
}

// --- Scenario 93: send mailbox through mailbox ---
test "93 - send mailbox through mailbox" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const carrier: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(carrier);
        mailbox.destroy(carrier, alloc);
    }

    const inner: MailboxHandle = try mailbox.new(io, alloc);

    {
        var slot: Slot = inner;
        try mailbox.send(carrier, &slot);
        try testing.expect(slot == null);
    }

    var slot: Slot = null;
    try mailbox.receive(carrier, &slot, null);
    try testing.expect(slot != null);
    try testing.expect(mailbox.is_it_you(slot.?.*.tag));

    const recovered: MailboxHandle = slot.?;
    _ = mailbox.close(recovered);
    mailbox.destroy(recovered, alloc);
}

// --- Scenario 94: hold pool as pool item ---

const PoolTransportCtx = struct {
    alloc: std.mem.Allocator,
};

fn poolTransportOnGet(_: *anyopaque, _: *const anyopaque, _: usize, _: *Slot) void {}

fn resetOnPut(_: *Slot) void {} // PoolHandle items carry no resettable scalar state — kept for on_put-shape consistency

fn poolTransportOnPut(_: *anyopaque, _: usize, slot: *Slot) ?std.DoublyLinkedList {
    resetOnPut(slot);
    return null;
}

fn poolTransportOnClose(ctx_opaque: *anyopaque, list: *std.DoublyLinkedList) void {
    const ctx: *PoolTransportCtx = @ptrCast(@alignCast(ctx_opaque));
    while (list.popFirst()) |node| {
        const poly: *PolyNode = @fieldParentPtr("node", node);
        const ph: PoolHandle = poly;
        pool.close(ph);
        pool.destroy(ph, ctx.alloc);
    }
}

test "94 - hold pool as pool item" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const carrier: PoolHandle = try pool.new(io, alloc);
    var transport_ctx: PoolTransportCtx = .{ .alloc = alloc };
    const pool_tags = [_]*const anyopaque{PoolPolyHelper.TAG};
    try pool.init(carrier, .{
        .ctx = &transport_ctx,
        .tags = &pool_tags,
        .on_get = poolTransportOnGet,
        .on_put = poolTransportOnPut,
        .on_close = poolTransportOnClose,
    });
    defer {
        pool.close(carrier);
        pool.destroy(carrier, alloc);
    }

    const inner: PoolHandle = try pool.new(io, alloc);

    {
        var slot: Slot = inner;
        pool.put(carrier, &slot);
        try testing.expect(slot == null);
    }

    var slot: Slot = null;
    try pool.get(carrier, PoolPolyHelper.TAG, .available_only, &slot);
    try testing.expect(slot != null);
    try testing.expect(pool.is_it_you(slot.?.*.tag));

    const recovered: PoolHandle = slot.?;
    pool.close(recovered);
    pool.destroy(recovered, alloc);
}

const matryoshka = @import("matryoshka");
const polynode = matryoshka.polynode;
const mailbox = matryoshka.mailbox;
const pool = matryoshka.pool;
const PolyNode = polynode.PolyNode;
const Slot = polynode.Slot;
const std = @import("std");
const testing = std.testing;
const Io = std.Io;
const MailboxHandle = mailbox.MailboxHandle;
const PoolHandle = pool.PoolHandle;
const PoolHooks = pool.PoolHooks;
const PoolPolyHelper = pool.PoolPolyHelper;
