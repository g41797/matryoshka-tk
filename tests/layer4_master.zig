// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

const WorkerCtx = struct {
    mbx: *Mbox,
    alloc: std.mem.Allocator,
};

fn workerFn(ctx: *WorkerCtx) error{Canceled}!void {
    var slot: Slot = null;
    defer items.freeSlot(&slot, ctx.alloc);
    ctx.mbx.receive(&slot, null) catch |err| switch (err) {
        error.Canceled => return error.Canceled,
        error.Closed, error.Timeout, error.Wakeup => return,
    };
}

// --- Scenario 1: single worker spawn and join ---
test "1 - single worker spawn and join" {
    std.testing.log_level = .debug;
    var threaded: std.Io.Threaded = std.Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const io: Io = threaded.io();

    var mbx_slot: Slot = null;
    try mailbox.new(io, testing.allocator, &mbx_slot);
    const mbx: *Mbox = Mbox.moveFromSlot(&mbx_slot).?;
    defer {
        var rem: polynode.ItemList = mbx.close();
        items.freeList(&rem, testing.allocator);
        mailbox.destroy(mbx, testing.allocator);
    }

    var ctx: WorkerCtx = .{ .mbx = mbx, .alloc = testing.allocator };
    var fut = try io.concurrent(workerFn, .{&ctx});

    var slot: Slot = null;
    defer EventPolyHelper.destroy(testing.allocator, &slot);
    try EventPolyHelper.create(testing.allocator, &slot);
    EventPolyHelper.mustFromSlot(&slot).code = 42;
    try mbx.send(&slot);
    try testing.expect(slot == null);

    try fut.await(io);
}

// --- Scenario 2: worker group spawn and join ---
test "2 - worker group spawn and join" {
    std.testing.log_level = .debug;
    var threaded: std.Io.Threaded = std.Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const io: Io = threaded.io();

    var mbx_slot: Slot = null;
    try mailbox.new(io, testing.allocator, &mbx_slot);
    const mbx: *Mbox = Mbox.moveFromSlot(&mbx_slot).?;
    defer {
        var rem: polynode.ItemList = mbx.close();
        items.freeList(&rem, testing.allocator);
        mailbox.destroy(mbx, testing.allocator);
    }

    var ctx1: WorkerCtx = .{ .mbx = mbx, .alloc = testing.allocator };
    var ctx2: WorkerCtx = .{ .mbx = mbx, .alloc = testing.allocator };
    var ctx3: WorkerCtx = .{ .mbx = mbx, .alloc = testing.allocator };

    var group: Io.Group = .init;
    defer group.cancel(io);

    try group.concurrent(io, workerFn, .{&ctx1});
    try group.concurrent(io, workerFn, .{&ctx2});
    try group.concurrent(io, workerFn, .{&ctx3});

    for (0..3) |i| {
        var slot: Slot = null;
        defer EventPolyHelper.destroy(testing.allocator, &slot);
        try EventPolyHelper.create(testing.allocator, &slot);
        EventPolyHelper.mustFromSlot(&slot).code = @intCast(i);
        try mbx.send(&slot);
    }

    try group.await(io);
}

const matryoshka = @import("matryoshka");
const polynode = matryoshka.polynode;
const mailbox = matryoshka.mailbox;
const Slot = polynode.Slot;
const Mbox = matryoshka.Mbox;

const items = @import("examples").items;
const Event = items.Event;
const EventPolyHelper = items.Event.EventPolyHelper;
const std = @import("std");
const testing = std.testing;
const Io = std.Io;
