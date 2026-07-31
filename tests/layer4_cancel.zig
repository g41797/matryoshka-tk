// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

// --- Scenarios 3, 4, 6: shared loop worker ---

const MbxCtx = struct {
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,
};

fn mbxLoopWorker(ctx: *MbxCtx) error{Canceled}!void {
    while (true) {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        mailbox.receive(ctx.mbh, &slot, null) catch |err| switch (err) {
            error.Canceled => return error.Canceled,
            error.Closed, error.Timeout, error.Wakeup => return,
        };
    }
}

test "3 - Future.cancel stops blocked worker" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const io: Io = threaded.io();

    const mbh: MailboxHandle = try mailbox.new(io, testing.allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh);
        items.freeList(&rem, testing.allocator);
        mailbox.destroy(mbh, testing.allocator);
    }

    var ctx: MbxCtx = .{ .mbh = mbh, .alloc = testing.allocator };
    var fut = try io.concurrent(mbxLoopWorker, .{&ctx});
    fut.cancel(io) catch {};
}

test "4 - Group.cancel stops all workers" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const io: Io = threaded.io();

    const mbh: MailboxHandle = try mailbox.new(io, testing.allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh);
        items.freeList(&rem, testing.allocator);
        mailbox.destroy(mbh, testing.allocator);
    }

    var ctx1: MbxCtx = .{ .mbh = mbh, .alloc = testing.allocator };
    var ctx2: MbxCtx = .{ .mbh = mbh, .alloc = testing.allocator };
    var ctx3: MbxCtx = .{ .mbh = mbh, .alloc = testing.allocator };

    var group: Io.Group = .init;
    defer group.cancel(io);

    try group.concurrent(io, mbxLoopWorker, .{&ctx1});
    try group.concurrent(io, mbxLoopWorker, .{&ctx2});
    try group.concurrent(io, mbxLoopWorker, .{&ctx3});
}

// --- Scenario 5: cancel deferred to next cancellation point ---

const Ctx5 = struct {
    mbh: MailboxHandle,
    ph: PoolHandle,
    alloc: std.mem.Allocator,
    received: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    canceled: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
};

fn worker5(ctx: *Ctx5) error{Canceled}!void {
    while (true) {
        var slot: Slot = null;
        defer pool.put(ctx.ph, &slot); // cancel-protected
        mailbox.receive(ctx.mbh, &slot, null) catch |err| switch (err) {
            error.Canceled => {
                ctx.canceled.store(true, .release);
                return error.Canceled;
            },
            error.Closed, error.Timeout, error.Wakeup => return,
        };
        ctx.received.store(true, .release);
        // pool.put runs in defer: lockUncancelable, succeeds even if cancel pending.
    }
}

test "5 - Worker not blocked when cancel takes effect" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const io: Io = threaded.io();

    const ph: PoolHandle = try pool.new(io, testing.allocator);
    var pool_ctx5: hooks.AlwaysCreateHooks = .{ .alloc = testing.allocator };
    const tags5 = [_]*const anyopaque{EventPolyHelper.TAG};
    try pool.init(ph, pool_ctx5.poolHooks(&tags5));
    defer {
        pool.close(ph);
        pool.destroy(ph, testing.allocator);
    }

    const mbh: MailboxHandle = try mailbox.new(io, testing.allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh);
        items.freeList(&rem, testing.allocator);
        mailbox.destroy(mbh, testing.allocator);
    }

    {
        var slot: Slot = null;
        defer EventPolyHelper.destroy(testing.allocator, &slot);
        try EventPolyHelper.create(testing.allocator, &slot);
        try mailbox.send(mbh, &slot);
    }

    var ctx: Ctx5 = .{ .mbh = mbh, .ph = ph, .alloc = testing.allocator };
    var fut = try io.concurrent(worker5, .{&ctx});

    while (!ctx.received.load(.acquire)) std.Thread.yield() catch {};

    fut.cancel(io) catch {};
    try testing.expect(ctx.canceled.load(.acquire));
}

// --- Scenario 6: broadcast shutdown via mailbox.close ---

test "6 - Broadcast shutdown: mailbox.close before join" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const io: Io = threaded.io();

    const mbh: MailboxHandle = try mailbox.new(io, testing.allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh);
        items.freeList(&rem, testing.allocator);
        mailbox.destroy(mbh, testing.allocator);
    }

    var ctx: MbxCtx = .{ .mbh = mbh, .alloc = testing.allocator };
    var fut = try io.concurrent(mbxLoopWorker, .{&ctx});

    var rem: polynode.ItemList = mailbox.close(mbh);
    defer items.freeList(&rem, testing.allocator);

    try fut.await(io);
}

// --- Scenario 7: cancel worker, then close pool and mailbox ---

const Ctx7 = struct {
    mbh: MailboxHandle,
    ph: PoolHandle,
    alloc: std.mem.Allocator,
};

fn worker7(ctx: *Ctx7) error{Canceled}!void {
    while (true) {
        var slot: Slot = null;
        defer pool.put(ctx.ph, &slot);
        mailbox.receive(ctx.mbh, &slot, null) catch |err| switch (err) {
            error.Canceled => return error.Canceled,
            error.Closed, error.Timeout, error.Wakeup => return,
        };
    }
}

test "7 - Cancel shutdown: future.cancel before close" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const io: Io = threaded.io();

    const ph: PoolHandle = try pool.new(io, testing.allocator);
    var pool_ctx7: hooks.AlwaysCreateHooks = .{ .alloc = testing.allocator };
    const tags7 = [_]*const anyopaque{EventPolyHelper.TAG};
    try pool.init(ph, pool_ctx7.poolHooks(&tags7));

    const mbh: MailboxHandle = try mailbox.new(io, testing.allocator);

    var ctx: Ctx7 = .{ .mbh = mbh, .ph = ph, .alloc = testing.allocator };
    var fut = try io.concurrent(worker7, .{&ctx});

    fut.cancel(io) catch {};

    pool.close(ph);
    pool.destroy(ph, testing.allocator);

    var rem: polynode.ItemList = mailbox.close(mbh);
    items.freeList(&rem, testing.allocator);
    mailbox.destroy(mbh, testing.allocator);
}

// --- Scenario 8: pool.put on closed pool, caller keeps the item ---

const Ctx8 = struct {
    mbh: MailboxHandle,
    ph: PoolHandle,
    alloc: std.mem.Allocator,
};

fn worker8(ctx: *Ctx8) error{Canceled}!void {
    var slot: Slot = null;
    defer items.freeSlot(&slot, ctx.alloc); // frees slot if pool.put left it non-null
    mailbox.receive(ctx.mbh, &slot, null) catch |err| switch (err) {
        error.Canceled => return error.Canceled,
        error.Closed, error.Timeout, error.Wakeup => return,
    };
    pool.put(ctx.ph, &slot); // pool closed: slot stays non-null, the caller keeps the item
}

test "8 - pool.put on closed pool" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const io: Io = threaded.io();

    const ph: PoolHandle = try pool.new(io, testing.allocator);
    pool.close(ph); // close before init: put checks closed before any assertions
    defer pool.destroy(ph, testing.allocator);

    const mbh: MailboxHandle = try mailbox.new(io, testing.allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh);
        items.freeList(&rem, testing.allocator);
        mailbox.destroy(mbh, testing.allocator);
    }

    {
        var slot: Slot = null;
        defer EventPolyHelper.destroy(testing.allocator, &slot);
        try EventPolyHelper.create(testing.allocator, &slot);
        try mailbox.send(mbh, &slot);
    }

    var ctx: Ctx8 = .{ .mbh = mbh, .ph = ph, .alloc = testing.allocator };
    var fut = try io.concurrent(worker8, .{&ctx});
    try fut.await(io);
}

// --- Scenario 9: mailbox.close returns remaining items ---

const Ctx9 = struct {
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,
};

fn worker9(ctx: *Ctx9) error{Canceled}!void {
    for (0..3) |_| {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        mailbox.receive(ctx.mbh, &slot, null) catch return;
    }
}

test "9 - mailbox.close returns remaining items" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const io: Io = threaded.io();

    const mbh: MailboxHandle = try mailbox.new(io, testing.allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh);
        items.freeList(&rem, testing.allocator);
        mailbox.destroy(mbh, testing.allocator);
    }

    for (0..10) |i| {
        var slot: Slot = null;
        defer EventPolyHelper.destroy(testing.allocator, &slot);
        try EventPolyHelper.create(testing.allocator, &slot);
        EventPolyHelper.mustFromSlot(&slot).code = @intCast(i);
        try mailbox.send(mbh, &slot);
    }

    var ctx: Ctx9 = .{ .mbh = mbh, .alloc = testing.allocator };
    var fut = try io.concurrent(worker9, .{&ctx});
    try fut.await(io);

    var rem: polynode.ItemList = mailbox.close(mbh);
    defer items.freeList(&rem, testing.allocator);

    var count: usize = 0;
    var it = rem.iterator();
    while (it.next()) |_| count += 1;
    try testing.expectEqual(@as(usize, 7), count);
}

// --- Scenario 10: pool.close calls on_close with all items ---

const Ctx10 = struct {
    alloc: std.mem.Allocator,
    item_count: usize = 0,

    fn onGet(ctx_ptr: *anyopaque, tag: *const anyopaque, _: usize, slot: *Slot) void {
        if (slot.* != null) return;
        const self: *Ctx10 = @ptrCast(@alignCast(ctx_ptr));
        items.createByTag(tag, self.alloc, slot);
    }

    fn onPut(_: *anyopaque, _: usize, slot: *Slot) ?polynode.ItemList {
        if (slot.* == null) return null;
        items.resetOnPut(slot);
        return null;
    }

    fn onClose(ctx_ptr: *anyopaque, list: *polynode.ItemList) void {
        const self: *Ctx10 = @ptrCast(@alignCast(ctx_ptr));
        while (list.popFirst()) |node| {
            self.item_count += 1;
            items.freeItem(node, self.alloc);
        }
    }
};

test "10 - pool.close calls on_close with all items" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const io: Io = threaded.io();

    const ph: PoolHandle = try pool.new(io, testing.allocator);
    var ctx10: Ctx10 = .{ .alloc = testing.allocator };
    const tags10 = [_]*const anyopaque{EventPolyHelper.TAG};
    const hooks10: pool.PoolHooks = .{
        .ctx = &ctx10,
        .tags = &tags10,
        .on_get = Ctx10.onGet,
        .on_put = Ctx10.onPut,
        .on_close = Ctx10.onClose,
    };
    try pool.init(ph, hooks10);

    for (0..5) |_| {
        var slot: Slot = null;
        defer EventPolyHelper.destroy(testing.allocator, &slot);
        try EventPolyHelper.create(testing.allocator, &slot);
        pool.put(ph, &slot);
        try testing.expect(slot == null);
    }

    pool.close(ph);
    try testing.expectEqual(@as(usize, 5), ctx10.item_count);
    pool.destroy(ph, testing.allocator);
}

// --- Scenario 11: error.Canceled distinct from error.Closed in mailbox.receive ---

const Ctx11 = struct {
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,
    got_canceled: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    got_closed: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
};

fn worker11(ctx: *Ctx11) error{Canceled}!void {
    var slot: Slot = null;
    defer items.freeSlot(&slot, ctx.alloc);
    mailbox.receive(ctx.mbh, &slot, null) catch |err| switch (err) {
        error.Canceled => {
            ctx.got_canceled.store(true, .release);
            return error.Canceled;
        },
        error.Closed => {
            ctx.got_closed.store(true, .release);
            return;
        },
        error.Timeout, error.Wakeup => return,
    };
}

test "11 - error.Canceled distinct from error.Closed in mailbox.receive" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const io: Io = threaded.io();

    const mbh: MailboxHandle = try mailbox.new(io, testing.allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh);
        items.freeList(&rem, testing.allocator);
        mailbox.destroy(mbh, testing.allocator);
    }

    var ctx: Ctx11 = .{ .mbh = mbh, .alloc = testing.allocator };
    var fut = try io.concurrent(worker11, .{&ctx});
    fut.cancel(io) catch {};

    try testing.expect(ctx.got_canceled.load(.acquire));
    try testing.expect(!ctx.got_closed.load(.acquire));

    var rem: polynode.ItemList = mailbox.close(mbh);
    items.freeList(&rem, testing.allocator);

    var slot: Slot = null;
    try testing.expectError(error.Closed, mailbox.try_receive(mbh, &slot));
}

// --- Scenario 12: error.Canceled distinct from error.Closed in pool.get_wait ---

const Ctx12 = struct {
    ph: PoolHandle,
    alloc: std.mem.Allocator,
    got_canceled: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
};

fn worker12(ctx: *Ctx12) error{Canceled}!void {
    var slot: Slot = null;
    defer items.freeSlot(&slot, ctx.alloc);
    pool.get_wait(ctx.ph, EventPolyHelper.TAG, &slot, null) catch |err| switch (err) {
        error.Canceled => {
            ctx.got_canceled.store(true, .release);
            return error.Canceled;
        },
        error.Closed, error.Timeout, error.NotAvailable, error.NotCreated => return,
    };
}

test "12 - error.Canceled distinct from error.Closed in pool.get_wait" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const io: Io = threaded.io();

    const ph: PoolHandle = try pool.new(io, testing.allocator);
    var pool_ctx12: hooks.AlwaysCreateHooks = .{ .alloc = testing.allocator };
    const tags12 = [_]*const anyopaque{EventPolyHelper.TAG};
    try pool.init(ph, pool_ctx12.poolHooks(&tags12));
    defer {
        pool.close(ph);
        pool.destroy(ph, testing.allocator);
    }

    var ctx: Ctx12 = .{ .ph = ph, .alloc = testing.allocator };
    var fut = try io.concurrent(worker12, .{&ctx});
    fut.cancel(io) catch {};

    try testing.expect(ctx.got_canceled.load(.acquire));

    pool.close(ph);
    var slot: Slot = null;
    try testing.expectError(error.Closed, pool.get(ph, EventPolyHelper.TAG, .available_only, &slot));
}

// --- Scenario 13: pool.put is cancel-protected ---

const Ctx13 = struct {
    io: Io,
    mbh: MailboxHandle,
    ph: PoolHandle,
    alloc: std.mem.Allocator,
};

fn worker13(ctx: *Ctx13) error{Canceled}!void {
    var pool_slot: Slot = null;
    defer pool.put(ctx.ph, &pool_slot); // cancel-protected: must complete even with active cancel

    pool.get(ctx.ph, EventPolyHelper.TAG, .available_or_new, &pool_slot) catch return;

    var msg_slot: Slot = null;
    defer items.freeSlot(&msg_slot, ctx.alloc);

    mailbox.receive(ctx.mbh, &msg_slot, null) catch |err| switch (err) {
        error.Canceled => {
            ctx.io.recancel(); // activate cancel again: pool.put must complete despite active cancel
            return error.Canceled;
            // defers (LIFO): msg_slot freed (null, no-op), pool_slot put (lockUncancelable)
        },
        error.Closed, error.Timeout, error.Wakeup => return,
    };
}

test "13 - pool.put is cancel-protected" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const io: Io = threaded.io();

    const ph: PoolHandle = try pool.new(io, testing.allocator);
    var pool_ctx13: hooks.AlwaysCreateHooks = .{ .alloc = testing.allocator };
    const tags13 = [_]*const anyopaque{EventPolyHelper.TAG};
    try pool.init(ph, pool_ctx13.poolHooks(&tags13));
    defer {
        pool.close(ph);
        pool.destroy(ph, testing.allocator);
    }

    const mbh: MailboxHandle = try mailbox.new(io, testing.allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh);
        items.freeList(&rem, testing.allocator);
        mailbox.destroy(mbh, testing.allocator);
    }

    var ctx: Ctx13 = .{ .io = io, .mbh = mbh, .ph = ph, .alloc = testing.allocator };
    var fut = try io.concurrent(worker13, .{&ctx});
    fut.cancel(io) catch {};
    // If pool.put succeeded, item is in pool. pool.close (defer) frees it via on_close.
    // Test allocator verifies no leaks.
}

// --- Scenario 14: mailbox.close uses lockUncancelable ---
//
// Use two mailboxes: mbh_listen (empty) forces the worker to block before cancel
// takes effect. mbh_data (3 items pre-loaded) is closed by the worker when canceled,
// exercising the lockUncancelable path with cancel active.

const Ctx14 = struct {
    io: Io,
    mbh_listen: MailboxHandle,
    mbh_data: MailboxHandle,
    alloc: std.mem.Allocator,
    close_count: usize = 0,
};

fn worker14(ctx: *Ctx14) error{Canceled}!void {
    var slot: Slot = null;
    defer items.freeSlot(&slot, ctx.alloc);
    mailbox.receive(ctx.mbh_listen, &slot, null) catch |err| switch (err) {
        error.Canceled => {
            ctx.io.recancel(); // activate cancel again
            // mailbox.close uses lockUncancelable: completes despite active cancel
            var rem: polynode.ItemList = mailbox.close(ctx.mbh_data);
            var it = rem.iterator();
            while (it.next()) |_| ctx.close_count += 1;
            items.freeList(&rem, ctx.alloc);
            return error.Canceled;
        },
        error.Closed, error.Timeout, error.Wakeup => return,
    };
}

test "14 - mailbox.close uses lockUncancelable" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const io: Io = threaded.io();

    // Worker blocks here (always empty); cancel takes effect while blocked.
    const mbh_listen: MailboxHandle = try mailbox.new(io, testing.allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh_listen);
        items.freeList(&rem, testing.allocator);
        mailbox.destroy(mbh_listen, testing.allocator);
    }

    // Worker closes this on cancel; second close in defer returns empty list.
    const mbh_data: MailboxHandle = try mailbox.new(io, testing.allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh_data);
        items.freeList(&rem, testing.allocator);
        mailbox.destroy(mbh_data, testing.allocator);
    }

    for (0..3) |i| {
        var slot: Slot = null;
        defer EventPolyHelper.destroy(testing.allocator, &slot);
        try EventPolyHelper.create(testing.allocator, &slot);
        EventPolyHelper.mustFromSlot(&slot).code = @intCast(i);
        try mailbox.send(mbh_data, &slot);
    }

    var ctx: Ctx14 = .{ .io = io, .mbh_listen = mbh_listen, .mbh_data = mbh_data, .alloc = testing.allocator };
    var fut = try io.concurrent(worker14, .{&ctx});
    fut.cancel(io) catch {};

    try testing.expectEqual(@as(usize, 3), ctx.close_count);
}

// --- Scenario 15: recancel propagation ---

const Ctx15 = struct {
    io: Io,
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,
    second_canceled: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
};

fn worker15(ctx: *Ctx15) error{Canceled}!void {
    var slot: Slot = null;
    defer items.freeSlot(&slot, ctx.alloc);
    mailbox.receive(ctx.mbh, &slot, null) catch |err| switch (err) {
        error.Canceled => ctx.io.recancel(), // activate cancel again: next cancellation point returns error.Canceled
        error.Closed, error.Timeout, error.Wakeup => return,
    };
    mailbox.receive(ctx.mbh, &slot, null) catch |err| switch (err) {
        error.Canceled => {
            ctx.second_canceled.store(true, .release);
            return error.Canceled;
        },
        error.Closed, error.Timeout, error.Wakeup => return,
    };
}

test "15 - recancel propagation" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const io: Io = threaded.io();

    const mbh: MailboxHandle = try mailbox.new(io, testing.allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh);
        items.freeList(&rem, testing.allocator);
        mailbox.destroy(mbh, testing.allocator);
    }

    var ctx: Ctx15 = .{ .io = io, .mbh = mbh, .alloc = testing.allocator };
    var fut = try io.concurrent(worker15, .{&ctx});
    fut.cancel(io) catch {};

    try testing.expect(ctx.second_canceled.load(.acquire));
}

// --- Scenario 16: checkCancel in CPU-bound work ---

const Ctx16 = struct {
    io: Io,
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,
    in_loop: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    check_canceled: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
};

fn worker16(ctx: *Ctx16) error{Canceled}!void {
    var slot: Slot = null;
    defer items.freeSlot(&slot, ctx.alloc);
    mailbox.receive(ctx.mbh, &slot, null) catch return;

    ctx.in_loop.store(true, .release);
    var i: usize = 0;
    while (true) : (i +%= 1) {
        if (i % 1000 == 0) {
            ctx.io.checkCancel() catch {
                ctx.check_canceled.store(true, .release);
                return error.Canceled;
            };
        }
    }
}

test "16 - checkCancel in CPU-bound work" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const io: Io = threaded.io();

    const mbh: MailboxHandle = try mailbox.new(io, testing.allocator);
    defer {
        var rem: polynode.ItemList = mailbox.close(mbh);
        items.freeList(&rem, testing.allocator);
        mailbox.destroy(mbh, testing.allocator);
    }

    {
        var slot: Slot = null;
        defer EventPolyHelper.destroy(testing.allocator, &slot);
        try EventPolyHelper.create(testing.allocator, &slot);
        try mailbox.send(mbh, &slot);
    }

    var ctx: Ctx16 = .{ .io = io, .mbh = mbh, .alloc = testing.allocator };
    var fut = try io.concurrent(worker16, .{&ctx});

    while (!ctx.in_loop.load(.acquire)) std.Thread.yield() catch {};

    fut.cancel(io) catch {};
    try testing.expect(ctx.check_canceled.load(.acquire));
}

// --- INTR 4 Bug 3.1: pool.put must broadcast for multi-tag pools ---
//
// With signal(), put(tag_B) might wake a thread waiting for tag_A.
// That thread finds no item for tag_A and goes back to sleep.
// The tag_B waiter remains blocked indefinitely.
// Fix: use broadcast() in put() so all waiters check their own tag.

const CtxGetter = struct {
    ph: PoolHandle,
    tag: *const anyopaque,
    started: *std.atomic.Value(u32),
    got_item: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
};

fn multiTagGetter(ctx: *CtxGetter) anyerror!void {
    _ = ctx.started.fetchAdd(1, .monotonic);
    var slot: Slot = null;
    pool.get_wait(ctx.ph, ctx.tag, &slot, null) catch return;
    ctx.got_item.store(slot != null, .release);
    pool.put(ctx.ph, &slot);
}

test "INTR4-1 - pool.put broadcasts: multi-tag waiters each get correct item" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const io: Io = threaded.io();

    const ph: PoolHandle = try pool.new(io, testing.allocator);
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = testing.allocator };
    const tags = [_]*const anyopaque{ EventPolyHelper.TAG, SensorPolyHelper.TAG };
    try pool.init(ph, pool_ctx.poolHooks(&tags));
    defer {
        pool.close(ph);
        pool.destroy(ph, testing.allocator);
    }

    var started = std.atomic.Value(u32).init(0);
    var ctx_ev: CtxGetter = .{ .ph = ph, .tag = EventPolyHelper.TAG, .started = &started };
    var ctx_sn: CtxGetter = .{ .ph = ph, .tag = SensorPolyHelper.TAG, .started = &started };

    var fut_ev = try io.concurrent(multiTagGetter, .{&ctx_ev});
    var fut_sn = try io.concurrent(multiTagGetter, .{&ctx_sn});

    // Wait for both tasks to enter get_wait and block.
    while (started.load(.acquire) < 2) std.Thread.yield() catch {};
    const sleep_t: Io.Timeout = .{
        .duration = .{ .raw = .{ .nanoseconds = @as(i96, 10_000_000) }, .clock = .real },
    };
    Io.Timeout.sleep(sleep_t, io) catch {};

    // Seed one item per tag. broadcast() in put() wakes all waiters; each checks its own tag.
    {
        var slot: Slot = null;
        try pool.get(ph, EventPolyHelper.TAG, .new_only, &slot);
        pool.put(ph, &slot);
    }
    {
        var slot: Slot = null;
        try pool.get(ph, SensorPolyHelper.TAG, .new_only, &slot);
        pool.put(ph, &slot);
    }

    try fut_ev.await(io);
    try fut_sn.await(io);

    try testing.expect(ctx_ev.got_item.load(.acquire));
    try testing.expect(ctx_sn.got_item.load(.acquire));
}

// --- INTR 4 Bug 3.2: re-signal on cancel — item not stranded ---
//
// When a waiter exits due to cancel/timeout while an item is present,
// it re-signals the condition so the next waiter can get the item.
// Without the fix, canceling the only active waiter (even after item arrives)
// could leave the item unclaimed if another waiter starts after the put signal was lost.

const CtxCancel = struct {
    ph: PoolHandle,
    started: *std.atomic.Value(bool),
    got_item: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
};

fn canceledGetter(ctx: *CtxCancel) anyerror!void {
    ctx.started.store(true, .release);
    var slot: Slot = null;
    defer pool.put(ctx.ph, &slot);
    pool.get_wait(ctx.ph, EventPolyHelper.TAG, &slot, null) catch return;
    ctx.got_item.store(true, .release);
}

test "INTR4-2 - re-signal on cancel: second waiter gets item after first is canceled" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const io: Io = threaded.io();

    const ph: PoolHandle = try pool.new(io, testing.allocator);
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = testing.allocator };
    const tags = [_]*const anyopaque{EventPolyHelper.TAG};
    try pool.init(ph, pool_ctx.poolHooks(&tags));
    defer {
        pool.close(ph);
        pool.destroy(ph, testing.allocator);
    }

    // Thread A: blocked in get_wait — will be canceled.
    var started_a = std.atomic.Value(bool).init(false);
    var ctx_a: CtxCancel = .{ .ph = ph, .started = &started_a };
    var fut_a = try io.concurrent(canceledGetter, .{&ctx_a});
    while (!started_a.load(.acquire)) std.Thread.yield() catch {};
    const sleep_t: Io.Timeout = .{
        .duration = .{ .raw = .{ .nanoseconds = @as(i96, 5_000_000) }, .clock = .real },
    };
    Io.Timeout.sleep(sleep_t, io) catch {};

    fut_a.cancel(io) catch {};

    // Thread B: gets the item seeded after A is canceled.
    var started_b = std.atomic.Value(bool).init(false);
    var ctx_b: CtxCancel = .{ .ph = ph, .started = &started_b };
    var fut_b = try io.concurrent(canceledGetter, .{&ctx_b});
    while (!started_b.load(.acquire)) std.Thread.yield() catch {};
    Io.Timeout.sleep(sleep_t, io) catch {};

    // Seed one item. B must get it (A is gone).
    {
        var slot: Slot = null;
        try pool.get(ph, EventPolyHelper.TAG, .new_only, &slot);
        pool.put(ph, &slot);
    }

    try fut_b.await(io);
    try testing.expect(ctx_b.got_item.load(.acquire));
}

const items = @import("examples").items;
const hooks = @import("examples").hooks;
const EventPolyHelper = items.Event.EventPolyHelper;
const SensorPolyHelper = items.Sensor.SensorPolyHelper;
const matryoshka = @import("matryoshka");
const polynode = matryoshka.polynode;
const mailbox = matryoshka.mailbox;
const pool = matryoshka.pool;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
const PoolHandle = pool.PoolHandle;
const std = @import("std");
const testing = std.testing;
const Io = std.Io;
