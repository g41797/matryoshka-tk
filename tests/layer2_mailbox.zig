// --- Scenario 26: mailbox.new and mailbox.destroy ---
test "26 - mailbox new and destroy" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    try testing.expect(mailbox.is_it_you(mbh.*.tag));

    const remaining: polynode.ItemList = mailbox.close(mbh);
    try testing.expect(remaining.isEmpty());
    mailbox.destroy(mbh, alloc);
}

// --- Scenario 27: Send and receive single item ---
test "27 - send and receive single item" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    var ev: Event = .{ .code = 27 };
    EventPolyHelper.init(&ev);
    var slot: Slot = EventPolyHelper.toPoly(&ev);

    try mailbox.send(mbh, &slot);
    try testing.expectEqual(@as(Slot, null), slot);

    try mailbox.receive(mbh, &slot, 1_000_000_000);
    try testing.expect(slot != null);

    const poly: *PolyNode = slot.?;
    const recovered: *Event = EventPolyHelper.fromPoly(poly) orelse return error.WrongTag;
    try testing.expectEqual(@as(i32, 27), recovered.*.code);
}

// --- Scenario 28: FIFO ordering ---
test "28 - fifo ordering" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    var ev1: Event = .{ .code = 1 };
    var ev2: Event = .{ .code = 2 };
    var ev3: Event = .{ .code = 3 };
    EventPolyHelper.init(&ev1);
    EventPolyHelper.init(&ev2);
    EventPolyHelper.init(&ev3);

    var s1: Slot = EventPolyHelper.toPoly(&ev1);
    var s2: Slot = EventPolyHelper.toPoly(&ev2);
    var s3: Slot = EventPolyHelper.toPoly(&ev3);
    try mailbox.send(mbh, &s1);
    try mailbox.send(mbh, &s2);
    try mailbox.send(mbh, &s3);

    for ([_]i32{ 1, 2, 3 }) |expected| {
        var slot: Slot = null;
        try mailbox.receive(mbh, &slot, 1_000_000_000);
        const poly: *PolyNode = slot.?;
        const ev: *Event = EventPolyHelper.fromPoly(poly) orelse return error.WrongTag;
        try testing.expectEqual(expected, ev.*.code);
    }
}

// --- Scenario 29: Send to closed mailbox returns error.Closed ---
test "29 - send to closed mailbox" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    _ = mailbox.close(mbh);
    defer mailbox.destroy(mbh, alloc);

    var ev: Event = .{ .code = 29 };
    EventPolyHelper.init(&ev);
    var slot: Slot = EventPolyHelper.toPoly(&ev);

    try testing.expectError(error.Closed, mailbox.send(mbh, &slot));
}

// --- Scenario 30: Receive from closed mailbox returns error.Closed ---
test "30 - receive from closed mailbox" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    _ = mailbox.close(mbh);
    defer mailbox.destroy(mbh, alloc);

    var slot: Slot = null;
    try testing.expectError(error.Closed, mailbox.receive(mbh, &slot, 1_000_000_000));
}

// --- Scenario 31: Receive timeout ---
test "31 - receive timeout" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    var slot: Slot = null;
    try testing.expectError(error.Timeout, mailbox.receive(mbh, &slot, 1_000));
}

// --- Scenario 32: Receive wait forever (item sent from another thread) ---

const Ctx32 = struct {
    mbh: MailboxHandle,
    ev: Event,
};

fn sender32(ctx: *Ctx32) void {
    var slot: Slot = &ctx.*.ev.poly;
    mailbox.send(ctx.*.mbh, &slot) catch {};
}

test "32 - receive wait forever (null timeout), item from thread" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    var ctx: Ctx32 = .{
        .mbh = mbh,
        .ev = .{ .code = 32 },
    };
    EventPolyHelper.init(&ctx.ev);

    var fut = try io.concurrent(sender32, .{&ctx});
    defer fut.await(io);

    var slot: Slot = null;
    try mailbox.receive(mbh, &slot, null);
    try testing.expect(slot != null);

    const poly: *PolyNode = slot.?;
    const ev: *Event = EventPolyHelper.fromPoly(poly) orelse return error.WrongTag;
    try testing.expectEqual(@as(i32, 32), ev.*.code);
}

// --- Scenario 33: Close returns remaining items ---
test "33 - close returns remaining items" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);

    var ev1: Event = .{ .code = 1 };
    var ev2: Event = .{ .code = 2 };
    var ev3: Event = .{ .code = 3 };
    EventPolyHelper.init(&ev1);
    EventPolyHelper.init(&ev2);
    EventPolyHelper.init(&ev3);

    var s1: Slot = EventPolyHelper.toPoly(&ev1);
    var s2: Slot = EventPolyHelper.toPoly(&ev2);
    var s3: Slot = EventPolyHelper.toPoly(&ev3);
    try mailbox.send(mbh, &s1);
    try mailbox.send(mbh, &s2);
    try mailbox.send(mbh, &s3);

    var remaining: polynode.ItemList = mailbox.close(mbh);
    defer mailbox.destroy(mbh, alloc);

    var count: usize = 0;
    while (remaining.popFirst()) |_| {
        count += 1;
    }
    try testing.expectEqual(@as(usize, 3), count);
}

// --- Scenario 34: second close returns empty list ---
test "34 - second close returns empty list" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);

    var ev: Event = .{ .code = 34 };
    EventPolyHelper.init(&ev);
    var slot: Slot = EventPolyHelper.toPoly(&ev);
    try mailbox.send(mbh, &slot);

    var first: polynode.ItemList = mailbox.close(mbh);
    const second: polynode.ItemList = mailbox.close(mbh);
    defer mailbox.destroy(mbh, alloc);

    var count_first: usize = 0;
    while (first.popFirst()) |_| count_first += 1;
    try testing.expectEqual(@as(usize, 1), count_first);

    try testing.expect(second.isEmpty());
}

// --- Scenario 35: send_oob delivers to front of queue ---
test "35 - send_oob delivers to front" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    var ev1: Event = .{ .code = 1 };
    var ev2: Event = .{ .code = 2 };
    var ev3: Event = .{ .code = 3 };
    var oob: Event = .{ .code = 99 };
    EventPolyHelper.init(&ev1);
    EventPolyHelper.init(&ev2);
    EventPolyHelper.init(&ev3);
    EventPolyHelper.init(&oob);

    {
        var slot: Slot = EventPolyHelper.toPoly(&ev1);
        try mailbox.send(mbh, &slot);
    }
    {
        var slot: Slot = EventPolyHelper.toPoly(&ev2);
        try mailbox.send(mbh, &slot);
    }
    {
        var slot: Slot = EventPolyHelper.toPoly(&ev3);
        try mailbox.send(mbh, &slot);
    }
    {
        var slot: Slot = EventPolyHelper.toPoly(&oob);
        try mailbox.send_oob(mbh, &slot);
    }

    var slot: Slot = null;
    try mailbox.receive(mbh, &slot, 1_000_000_000);
    const poly: *PolyNode = slot.?;
    const first_ev: *Event = EventPolyHelper.fromPoly(poly) orelse return error.WrongTag;
    try testing.expectEqual(@as(i32, 99), first_ev.*.code);
}

// --- Scenario 36: send_oob wakes blocked receiver ---

const Ctx36 = struct {
    mbh: MailboxHandle,
    ev: Event,
};

fn oob_sender36(ctx: *Ctx36) void {
    var slot: Slot = &ctx.*.ev.poly;
    mailbox.send_oob(ctx.*.mbh, &slot) catch {};
}

test "36 - send_oob wakes blocked receiver" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    var ctx: Ctx36 = .{
        .mbh = mbh,
        .ev = .{ .code = 36 },
    };
    EventPolyHelper.init(&ctx.ev);

    var fut = try io.concurrent(oob_sender36, .{&ctx});
    defer fut.await(io);

    var slot: Slot = null;
    try mailbox.receive(mbh, &slot, 5_000_000_000);
    try testing.expect(slot != null);

    const poly: *PolyNode = slot.?;
    const ev: *Event = EventPolyHelper.fromPoly(poly) orelse return error.WrongTag;
    try testing.expectEqual(@as(i32, 36), ev.*.code);
}

// --- Scenario 37: Multiple send_oob items maintain FIFO among themselves ---
test "37 - multiple send_oob items are FIFO among OOBs" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    var oob_a: Event = .{ .code = 10 };
    var oob_b: Event = .{ .code = 20 };
    var regular: Event = .{ .code = 99 };
    EventPolyHelper.init(&oob_a);
    EventPolyHelper.init(&oob_b);
    EventPolyHelper.init(&regular);

    {
        var slot: Slot = EventPolyHelper.toPoly(&regular);
        try mailbox.send(mbh, &slot);
    }
    {
        var slot: Slot = EventPolyHelper.toPoly(&oob_a);
        try mailbox.send_oob(mbh, &slot);
    }
    {
        var slot: Slot = EventPolyHelper.toPoly(&oob_b);
        try mailbox.send_oob(mbh, &slot);
    }

    // Expected order: oob_a(10), oob_b(20), regular(99)
    const expected = [_]i32{ 10, 20, 99 };
    for (expected) |code| {
        var slot: Slot = null;
        try mailbox.receive(mbh, &slot, 1_000_000_000);
        const poly: *PolyNode = slot.?;
        const ev: *Event = EventPolyHelper.fromPoly(poly) orelse return error.WrongTag;
        try testing.expectEqual(code, ev.*.code);
    }
}

// --- Scenario 38: send_oob to closed mailbox returns error.Closed ---
test "38 - send_oob to closed mailbox" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    _ = mailbox.close(mbh);
    defer mailbox.destroy(mbh, alloc);

    var ev: Event = .{ .code = 38 };
    EventPolyHelper.init(&ev);
    var slot: Slot = EventPolyHelper.toPoly(&ev);

    try testing.expectError(error.Closed, mailbox.send_oob(mbh, &slot));
}

// --- Scenario 39: Data priority over closed ---
test "39 - data priority over closed" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);

    var ev: Event = .{ .code = 39 };
    EventPolyHelper.init(&ev);
    var slot: Slot = EventPolyHelper.toPoly(&ev);
    try mailbox.send(mbh, &slot);

    var remaining: polynode.ItemList = mailbox.close(mbh);
    defer mailbox.destroy(mbh, alloc);

    var count: usize = 0;
    while (remaining.popFirst()) |ih| {
        count += 1;
        const recovered: *Event = EventPolyHelper.fromPoly(ih) orelse return error.WrongTag;
        try testing.expectEqual(@as(i32, 39), recovered.*.code);
    }
    try testing.expectEqual(@as(usize, 1), count);
}

// --- Scenario 40: receive_batch gets all items ---
test "40 - receive_batch gets all items" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    var events: [5]Event = undefined;
    for (&events, 0..) |*ev, i| {
        ev.* = .{ .code = @as(i32, @intCast(i)) };
        EventPolyHelper.init(ev);
        var slot: Slot = &ev.*.poly;
        try mailbox.send(mbh, &slot);
    }

    var batch: polynode.ItemList = try mailbox.receive_batch(mbh);

    var count: usize = 0;
    while (batch.popFirst()) |_| count += 1;
    try testing.expectEqual(@as(usize, 5), count);

    var slot: Slot = null;
    const got: bool = try mailbox.try_receive(mbh, &slot);
    try testing.expect(!got);
}

// --- Scenario 41: receive_batch on empty returns empty list ---
test "41 - receive_batch on empty returns empty list" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    const batch: polynode.ItemList = try mailbox.receive_batch(mbh);
    try testing.expect(batch.isEmpty());
}

// --- Scenario 42: Batch items walkable via popFirst ---
test "42 - batch items walkable via popFirst" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    var ev1: Event = .{ .code = 1 };
    var ev2: Event = .{ .code = 2 };
    EventPolyHelper.init(&ev1);
    EventPolyHelper.init(&ev2);

    var s1: Slot = EventPolyHelper.toPoly(&ev1);
    var s2: Slot = EventPolyHelper.toPoly(&ev2);
    try mailbox.send(mbh, &s1);
    try mailbox.send(mbh, &s2);

    var batch: polynode.ItemList = try mailbox.receive_batch(mbh);

    while (batch.popFirst()) |poly| {
        // ItemList.popFirst clears the links — no caller-side reset
        try testing.expect(!polynode.is_linked(poly));
    }
}

// --- Scenario 43: Send transfers the item ---
test "43 - send transfers the item (slot is null)" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    var ev: Event = .{ .code = 43 };
    EventPolyHelper.init(&ev);
    var slot: Slot = EventPolyHelper.toPoly(&ev);

    try testing.expect(slot != null);
    try mailbox.send(mbh, &slot);
    try testing.expectEqual(@as(Slot, null), slot);
}

// --- Scenario 44: Receive transfers the item ---
test "44 - receive transfers the item (slot is non-null)" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    var ev: Event = .{ .code = 44 };
    EventPolyHelper.init(&ev);
    var slot: Slot = EventPolyHelper.toPoly(&ev);
    try mailbox.send(mbh, &slot);

    try mailbox.receive(mbh, &slot, 1_000_000_000);
    try testing.expect(slot != null);
}

// --- Scenario 45: try_receive on empty returns false ---
test "45 - try_receive on empty returns false" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    var slot: Slot = null;
    const got: bool = try mailbox.try_receive(mbh, &slot);
    try testing.expect(!got);
    try testing.expectEqual(@as(Slot, null), slot);
}

// --- Scenario 46: try_receive gets item ---
test "46 - try_receive gets item" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    var ev: Event = .{ .code = 46 };
    EventPolyHelper.init(&ev);
    var slot: Slot = EventPolyHelper.toPoly(&ev);
    try mailbox.send(mbh, &slot);

    const got: bool = try mailbox.try_receive(mbh, &slot);
    try testing.expect(got);
    try testing.expect(slot != null);
}

// --- Scenario 47: IN_FLIGHT → HELD (mailbox.send) ---
test "47 - send: IN_FLIGHT to HELD, slot is null" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    var ev1: Event = .{ .code = 47 };
    var ev2: Event = .{ .code = 48 };
    EventPolyHelper.init(&ev1);
    EventPolyHelper.init(&ev2);
    var slot1: Slot = EventPolyHelper.toPoly(&ev1);
    var slot2: Slot = EventPolyHelper.toPoly(&ev2);

    try testing.expect(slot1 != null);
    try testing.expect(!polynode.is_linked(EventPolyHelper.toPoly(&ev1)));

    try mailbox.send(mbh, &slot1);
    try mailbox.send(mbh, &slot2);

    try testing.expectEqual(@as(Slot, null), slot1);
    try testing.expect(polynode.is_linked(EventPolyHelper.toPoly(&ev1)));
}

// --- Scenario 48: HELD → IN_FLIGHT (mailbox.receive) ---
test "48 - receive: HELD to IN_FLIGHT, slot is non-null" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    var ev: Event = .{ .code = 48 };
    EventPolyHelper.init(&ev);
    var slot: Slot = EventPolyHelper.toPoly(&ev);
    try mailbox.send(mbh, &slot);

    try mailbox.receive(mbh, &slot, 1_000_000_000);

    try testing.expect(slot != null);
    const poly: *PolyNode = slot.?;
    try testing.expect(!polynode.is_linked(poly));
}

// --- Scenario 49: is_linked detection; assert triggers in Debug/ReleaseSafe (no panic-catch in testing) ---
// The list holds two items here, which is the case the assert catches. Against
// a list of one it would not fire — is_linked reads neighbours, not membership.
test "49 - send linked item: is_linked detection (assert documented)" {
    var ev1: Event = .{ .code = 49 };
    var ev2: Event = .{ .code = 50 };
    EventPolyHelper.init(&ev1);
    EventPolyHelper.init(&ev2);

    var list: polynode.ItemList = .{};
    list.append(&ev1.poly);
    list.append(&ev2.poly);

    // mailbox.send would assert(!is_linked) here (Open Item 11), and does
    // catch it, because ev1 has a neighbour.
    try testing.expect(polynode.is_linked(EventPolyHelper.toPoly(&ev1)));

    // ItemList.popFirst clears the links on the way out
    _ = list.popFirst();
    try testing.expect(!polynode.is_linked(EventPolyHelper.toPoly(&ev1)));
    _ = list.popFirst();
}

// --- Scenario 50: Fan-in (3+1) — 3 sender threads, main receives ---

const Ctx50Sender = struct {
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,
};

fn sender50_event(ctx: *Ctx50Sender) void {
    var slot: Slot = null;
    EventPolyHelper.create(ctx.*.alloc, &slot) catch return;
    mailbox.send(ctx.*.mbh, &slot) catch items.freeSlot(&slot, ctx.*.alloc);
}

fn sender50_sensor(ctx: *Ctx50Sender) void {
    var slot: Slot = null;
    SensorPolyHelper.create(ctx.*.alloc, &slot) catch return;
    mailbox.send(ctx.*.mbh, &slot) catch items.freeSlot(&slot, ctx.*.alloc);
}

test "50 - fan-in (3+1): 3 sender threads, main receives all" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);

    var ctx_a: Ctx50Sender = .{ .mbh = mbh, .alloc = alloc };
    var ctx_b: Ctx50Sender = .{ .mbh = mbh, .alloc = alloc };
    var ctx_c: Ctx50Sender = .{ .mbh = mbh, .alloc = alloc };

    var fa = try io.concurrent(sender50_event, .{&ctx_a});
    var fb = try io.concurrent(sender50_sensor, .{&ctx_b});
    var fc = try io.concurrent(sender50_event, .{&ctx_c});

    var received: usize = 0;
    while (received < 3) {
        var slot: Slot = null;
        mailbox.receive(mbh, &slot, 5_000_000_000) catch break;
        if (slot) |poly| {
            freeItem(poly, alloc);
            received += 1;
        }
    }

    fa.await(io);
    fb.await(io);
    fc.await(io);

    var rem: polynode.ItemList = mailbox.close(mbh);
    while (rem.popFirst()) |ih| {
        freeItem(ih, alloc);
    }
    mailbox.destroy(mbh, alloc);

    try testing.expectEqual(@as(usize, 3), received);
}

// --- Scenario 51: Fan-slot (1+2) — main sends, 2 receiver threads ---

const Ctx51Receiver = struct {
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,
    items_received: usize = 0,
};

fn receiver51(ctx: *Ctx51Receiver) void {
    var slot: Slot = null;
    mailbox.receive(ctx.*.mbh, &slot, null) catch return;
    if (slot) |poly| {
        freeItem(poly, ctx.*.alloc);
        ctx.*.items_received += 1;
    }
}

test "51 - fan-slot (1+2): main sends, 2 receiver threads" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);

    {
        var slot: Slot = null;
        try EventPolyHelper.create(alloc, &slot);
        try mailbox.send(mbh, &slot);
    }

    {
        var slot: Slot = null;
        try SensorPolyHelper.create(alloc, &slot);
        try mailbox.send(mbh, &slot);
    }

    var ctx_a: Ctx51Receiver = .{ .mbh = mbh, .alloc = alloc };
    var ctx_b: Ctx51Receiver = .{ .mbh = mbh, .alloc = alloc };

    var fa = try io.concurrent(receiver51, .{&ctx_a});
    var fb = try io.concurrent(receiver51, .{&ctx_b});

    var rem: polynode.ItemList = mailbox.close(mbh);

    fa.await(io);
    fb.await(io);

    var remaining_count: usize = 0;
    while (rem.popFirst()) |ih| {
        freeItem(ih, alloc);
        remaining_count += 1;
    }
    mailbox.destroy(mbh, alloc);

    const total: usize = ctx_a.items_received + ctx_b.items_received + remaining_count;
    try testing.expectEqual(@as(usize, 2), total);
}

// --- Scenario 52: Combined (3+2+main) — fan-in + fan-slot, close after 100ms ---

const Ctx52Sender = struct {
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,
    items_sent: usize = 0,
};

const Ctx52AltSender = struct {
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,
    items_sent: usize = 0,
    send_event: bool = true,
};

const Ctx52Receiver = struct {
    mbh: MailboxHandle,
    alloc: std.mem.Allocator,
    items_received: usize = 0,
};

fn sender52_event(ctx: *Ctx52Sender) void {
    while (true) {
        var slot: Slot = null;
        EventPolyHelper.create(ctx.*.alloc, &slot) catch break;
        mailbox.send(ctx.*.mbh, &slot) catch {
            items.freeSlot(&slot, ctx.*.alloc);
            break;
        };
        ctx.*.items_sent += 1;
    }
}

fn sender52_sensor(ctx: *Ctx52Sender) void {
    while (true) {
        var slot: Slot = null;
        SensorPolyHelper.create(ctx.*.alloc, &slot) catch break;
        mailbox.send(ctx.*.mbh, &slot) catch {
            items.freeSlot(&slot, ctx.*.alloc);
            break;
        };
        ctx.*.items_sent += 1;
    }
}

fn sender52_alt(ctx: *Ctx52AltSender) void {
    while (true) {
        var slot: Slot = null;
        if (ctx.*.send_event) {
            EventPolyHelper.create(ctx.*.alloc, &slot) catch break;
        } else {
            SensorPolyHelper.create(ctx.*.alloc, &slot) catch break;
        }
        mailbox.send(ctx.*.mbh, &slot) catch {
            items.freeSlot(&slot, ctx.*.alloc);
            break;
        };
        ctx.*.items_sent += 1;
        ctx.*.send_event = !ctx.*.send_event;
    }
}

fn receiver52(ctx: *Ctx52Receiver) void {
    while (true) {
        var slot: Slot = null;
        mailbox.receive(ctx.*.mbh, &slot, null) catch break;
        if (slot) |poly| {
            freeItem(poly, ctx.*.alloc);
            ctx.*.items_received += 1;
        }
    }
}

test "52 - combined (3+2+main): fan-in + fan-slot, close after 100ms" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);

    var ctx_se: Ctx52Sender = .{ .mbh = mbh, .alloc = alloc };
    var ctx_ss: Ctx52Sender = .{ .mbh = mbh, .alloc = alloc };
    var ctx_sa: Ctx52AltSender = .{ .mbh = mbh, .alloc = alloc };
    var ctx_ra: Ctx52Receiver = .{ .mbh = mbh, .alloc = alloc };
    var ctx_rb: Ctx52Receiver = .{ .mbh = mbh, .alloc = alloc };

    var f_se = try io.concurrent(sender52_event, .{&ctx_se});
    var f_ss = try io.concurrent(sender52_sensor, .{&ctx_ss});
    var f_sa = try io.concurrent(sender52_alt, .{&ctx_sa});
    var f_ra = try io.concurrent(receiver52, .{&ctx_ra});
    var f_rb = try io.concurrent(receiver52, .{&ctx_rb});

    const sleep_t: Io.Timeout = .{
        .duration = .{
            .raw = .{ .nanoseconds = @as(i96, 100_000_000) },
            .clock = .real,
        },
    };
    Io.Timeout.sleep(sleep_t, io) catch {};

    var rem: polynode.ItemList = mailbox.close(mbh);

    f_se.await(io);
    f_ss.await(io);
    f_sa.await(io);
    f_ra.await(io);
    f_rb.await(io);

    var remaining_count: usize = 0;
    while (rem.popFirst()) |ih| {
        freeItem(ih, alloc);
        remaining_count += 1;
    }
    mailbox.destroy(mbh, alloc);

    const total_sent: usize = ctx_se.items_sent + ctx_ss.items_sent + ctx_sa.items_sent;
    const total_received: usize = ctx_ra.items_received + ctx_rb.items_received;
    try testing.expectEqual(total_sent, total_received + remaining_count);
}

// --- OOB invariant: oob_last resets to null after last OOB received; stale pointer corrupts next send_oob ---
test "oob last resets after last oob received, next send_oob goes to front" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    var ev_b: Event = .{ .code = 2 };
    var ev_a: Event = .{ .code = 1 };
    EventPolyHelper.init(&ev_b);
    EventPolyHelper.init(&ev_a);
    {
        var slot: Slot = EventPolyHelper.toPoly(&ev_b);
        try mailbox.send(mbh, &slot);
    } // queue=[B], oob_count=0
    {
        var slot: Slot = EventPolyHelper.toPoly(&ev_a);
        try mailbox.send_oob(mbh, &slot);
    } // queue=[A,B], oob_count=1, oob_last=&A

    {
        var slot: Slot = null;
        try mailbox.receive(mbh, &slot, 1_000_000_000);
        const a_ev: *Event = EventPolyHelper.fromSlot(&slot) orelse return error.WrongTag;
        try testing.expectEqual(@as(i32, 1), a_ev.*.code); // received A
    }

    // After receiving the only OOB item: oob_count==0, oob_last must be null.
    // send_oob C must prepend (go before B), not insert after dangling A.
    var ev_c: Event = .{ .code = 3 };
    EventPolyHelper.init(&ev_c);
    {
        var slot: Slot = EventPolyHelper.toPoly(&ev_c);
        try mailbox.send_oob(mbh, &slot);
    } // queue=[C,B], oob_count=1

    {
        var slot: Slot = null;
        try mailbox.receive(mbh, &slot, 1_000_000_000);
        const c_ev: *Event = EventPolyHelper.fromSlot(&slot) orelse return error.WrongTag;
        try testing.expectEqual(@as(i32, 3), c_ev.*.code); // C must be first
    }

    {
        var slot: Slot = null;
        try mailbox.receive(mbh, &slot, 1_000_000_000);
        const b_ev: *Event = EventPolyHelper.fromSlot(&slot) orelse return error.WrongTag;
        try testing.expectEqual(@as(i32, 2), b_ev.*.code); // B must be second
    }
}

// --- wakeUpAll: wakes a blocked receiver with error.Wakeup ---
test "wakeUpAll wakes blocked receiver" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    const Ctx = struct {
        mbh: MailboxHandle,
        result: ?anyerror = null,
    };
    var ctx: Ctx = .{ .mbh = mbh };

    const worker = struct {
        fn run(c: *Ctx) void {
            var slot: Slot = null;
            mailbox.receive(c.*.mbh, &slot, 5_000_000_000) catch |err| {
                c.*.result = err;
                return;
            };
        }
    }.run;

    var fut = try io.concurrent(worker, .{&ctx});

    std.Io.Timeout.sleep(.{ .duration = .{ .raw = .{ .nanoseconds = 50_000_000 }, .clock = .real } }, io) catch {};
    try mailbox.wakeUpAll(mbh);

    fut.await(io);
    try testing.expectEqual(@as(?anyerror, error.Wakeup), ctx.result);
}

// --- wakeUpAll: does not affect a receiver that starts afterward ---
test "wakeUpAll does not affect future receiver" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    try mailbox.wakeUpAll(mbh);

    var ev: Event = .{ .code = 64 };
    EventPolyHelper.init(&ev);
    var send_slot: Slot = EventPolyHelper.toPoly(&ev);
    try mailbox.send(mbh, &send_slot);

    var slot: Slot = null;
    try mailbox.receive(mbh, &slot, 1_000_000_000);
    const recovered: *Event = EventPolyHelper.fromSlot(&slot) orelse return error.WrongTag;
    try testing.expectEqual(@as(i32, 64), recovered.*.code);
}

// --- wakeUpAll: wakes every receiver currently blocked ---
test "wakeUpAll wakes all blocked receivers" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    const Ctx = struct {
        mbh: MailboxHandle,
        result: ?anyerror = null,
    };
    var ctx_a: Ctx = .{ .mbh = mbh };
    var ctx_b: Ctx = .{ .mbh = mbh };
    var ctx_c: Ctx = .{ .mbh = mbh };

    const worker = struct {
        fn run(c: *Ctx) void {
            var slot: Slot = null;
            mailbox.receive(c.*.mbh, &slot, 5_000_000_000) catch |err| {
                c.*.result = err;
                return;
            };
        }
    }.run;

    var fa = try io.concurrent(worker, .{&ctx_a});
    var fb = try io.concurrent(worker, .{&ctx_b});
    var fc = try io.concurrent(worker, .{&ctx_c});

    std.Io.Timeout.sleep(.{ .duration = .{ .raw = .{ .nanoseconds = 50_000_000 }, .clock = .real } }, io) catch {};
    try mailbox.wakeUpAll(mbh);

    fa.await(io);
    fb.await(io);
    fc.await(io);

    try testing.expectEqual(@as(?anyerror, error.Wakeup), ctx_a.result);
    try testing.expectEqual(@as(?anyerror, error.Wakeup), ctx_b.result);
    try testing.expectEqual(@as(?anyerror, error.Wakeup), ctx_c.result);
}

// --- wakeUpAll: on a closed mailbox returns error.Closed ---
test "wakeUpAll on closed mailbox returns error.Closed" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    _ = mailbox.close(mbh);

    try testing.expectError(error.Closed, mailbox.wakeUpAll(mbh));
    mailbox.destroy(mbh, alloc);
}

// --- wakeUpAll: with no blocked receivers is a no-op for the next receive ---
test "wakeUpAll with no waiters does not affect next receive" {
    const io: Io = testing.io;
    const alloc: std.mem.Allocator = testing.allocator;

    const mbh: MailboxHandle = try mailbox.new(io, alloc);
    defer {
        _ = mailbox.close(mbh);

        mailbox.destroy(mbh, alloc);
    }

    try mailbox.wakeUpAll(mbh);
    try mailbox.wakeUpAll(mbh);

    var slot: Slot = null;
    try testing.expectError(error.Timeout, mailbox.receive(mbh, &slot, 0));
}

const items = @import("examples").items;
const helpers = @import("examples").helpers;

const matryoshka = @import("matryoshka");
const polynode = matryoshka.polynode;
const mailbox = matryoshka.mailbox;
const PolyNode = polynode.PolyNode;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;

const Event = items.Event;
const Sensor = items.Sensor;
const EventPolyHelper = items.Event.EventPolyHelper;
const SensorPolyHelper = items.Sensor.SensorPolyHelper;
const std = @import("std");
const testing = std.testing;
const Io = std.Io;
const freeItem = items.freeItem;
