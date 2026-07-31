// --- Scenario 1: Tag uniqueness ---
test "1 - tag uniqueness" {
    try testing.expect(EventPolyHelper.TAG != SensorPolyHelper.TAG);

    const tag1: *const anyopaque = EventPolyHelper.TAG;
    const tag2: *const anyopaque = EventPolyHelper.TAG;
    try testing.expectEqual(tag1, tag2);
}

// --- Scenario 2: Tag init ---
test "2 - tag init" {
    var ev: Event = .{};
    EventPolyHelper.init(&ev);
    try testing.expectEqual(EventPolyHelper.TAG, ev.poly.tag);
}

// --- Scenario 3: Tag identity check ---
test "3 - tag identity check" {
    var ev: Event = .{};
    EventPolyHelper.init(&ev);
    try testing.expect(EventPolyHelper.isIt(ev.poly.tag));
    try testing.expect(!SensorPolyHelper.isIt(ev.poly.tag));
}

// --- Scenario 4: fromPoly success ---
test "4 - fromPoly success" {
    var ev: Event = .{ .code = 42 };
    EventPolyHelper.init(&ev);

    const poly: *PolyNode = EventPolyHelper.toPoly(&ev);
    const recovered: *Event = EventPolyHelper.mustFromPoly(poly);
    try testing.expectEqual(@as(i32, 42), recovered.*.code);
}

// --- Scenario 5: fromPoly wrong tag ---
test "5 - fromPoly wrong tag" {
    var ev: Event = .{ .code = 42 };
    EventPolyHelper.init(&ev);

    const poly: *PolyNode = EventPolyHelper.toPoly(&ev);
    const result: ?*Sensor = SensorPolyHelper.fromPoly(poly);
    try testing.expectEqual(@as(?*Sensor, null), result);
}

// --- Scenario 6: Two-level @fieldParentPtr chain ---
test "6 - two-level fieldParentPtr chain" {
    var ev: Event = .{ .code = 99 };
    EventPolyHelper.init(&ev);

    const dll_node: *std.DoublyLinkedList.Node = &ev.poly.node;
    const poly: *PolyNode = @fieldParentPtr("node", dll_node);
    const recovered: *Event = EventPolyHelper.mustFromPoly(poly);
    try testing.expectEqual(@as(i32, 99), recovered.*.code);
}

// --- Scenario 7: polynode.reset clears links ---
test "7 - polynode.reset clears links" {
    var ev: Event = .{};
    EventPolyHelper.init(&ev);

    ev.poly.node.prev = &ev.poly.node;
    ev.poly.node.next = &ev.poly.node;
    try testing.expect(polynode.is_linked(EventPolyHelper.toPoly(&ev)));

    polynode.reset(EventPolyHelper.toPoly(&ev));
    try testing.expectEqual(@as(?*std.DoublyLinkedList.Node, null), ev.poly.node.prev);
    try testing.expectEqual(@as(?*std.DoublyLinkedList.Node, null), ev.poly.node.next);
}

// --- Scenario 8: polynode.is_linked reads the neighbour links ---
// Not a membership test: the sole member of a list has no neighbours, so
// is_linked reports false for it. See rules — the neighbour check.
test "8 - polynode.is_linked detection" {
    var ev: Event = .{};
    EventPolyHelper.init(&ev);

    try testing.expect(!polynode.is_linked(EventPolyHelper.toPoly(&ev)));

    ev.poly.node.prev = &ev.poly.node;
    try testing.expect(polynode.is_linked(EventPolyHelper.toPoly(&ev)));

    polynode.reset(EventPolyHelper.toPoly(&ev));
    try testing.expect(!polynode.is_linked(EventPolyHelper.toPoly(&ev)));
}

// --- Scenario 9: Slot null semantics ---
test "9 - slot null semantics" {
    var ev: Event = .{};
    EventPolyHelper.init(&ev);

    var slot: Slot = EventPolyHelper.toPoly(&ev);
    try testing.expect(slot != null);

    slot = null;
    try testing.expectEqual(@as(Slot, null), slot);
}

// --- Scenario 10: Multiple types in one list ---
test "10 - multiple types in one list" {
    var ev: Event = .{ .code = 10 };
    EventPolyHelper.init(&ev);
    var sn: Sensor = .{ .value = 3.14 };
    SensorPolyHelper.init(&sn);

    var list: std.DoublyLinkedList = .{};
    list.append(&ev.poly.node);
    list.append(&sn.poly.node);

    var count_event: usize = 0;
    var count_sensor: usize = 0;

    while (list.popFirst()) |node| {
        const poly: *PolyNode = @fieldParentPtr("node", node);
        if (EventPolyHelper.fromPoly(poly)) |recovered_ev| {
            try testing.expectEqual(@as(i32, 10), recovered_ev.*.code);
            count_event += 1;
        } else if (SensorPolyHelper.fromPoly(poly)) |recovered_sn| {
            try testing.expectEqual(@as(f64, 3.14), recovered_sn.*.value);
            count_sensor += 1;
        } else {
            return error.UnexpectedTag;
        }
    }

    try testing.expectEqual(@as(usize, 1), count_event);
    try testing.expectEqual(@as(usize, 1), count_sensor);
}

// --- Scenario 11: FREE → IN_FLIGHT ---
test "11 - FREE to IN_FLIGHT" {
    var ev: Event = .{ .code = 1 };
    EventPolyHelper.init(&ev);

    const slot: Slot = EventPolyHelper.toPoly(&ev);
    try testing.expect(slot != null);
    try testing.expect(!polynode.is_linked(EventPolyHelper.toPoly(&ev)));
}

// --- Scenario 12: IN_FLIGHT → HELD (list) ---
test "12 - IN_FLIGHT to HELD via list" {
    var ev1: Event = .{};
    EventPolyHelper.init(&ev1);
    var ev2: Event = .{};
    EventPolyHelper.init(&ev2);

    var slot: Slot = EventPolyHelper.toPoly(&ev1);
    var list: std.DoublyLinkedList = .{};
    list.append(&ev1.poly.node);
    list.append(&ev2.poly.node);
    slot = null;

    try testing.expectEqual(@as(Slot, null), slot);
    try testing.expect(polynode.is_linked(EventPolyHelper.toPoly(&ev1)));
}

// --- Scenario 13: HELD → IN_FLIGHT (list) ---
test "13 - HELD to IN_FLIGHT via list pop" {
    var ev: Event = .{};
    EventPolyHelper.init(&ev);

    var list: std.DoublyLinkedList = .{};
    list.append(&ev.poly.node);

    const node: *std.DoublyLinkedList.Node = list.popFirst() orelse unreachable;
    const poly: *PolyNode = @fieldParentPtr("node", node);
    const slot: Slot = poly;

    try testing.expect(slot != null);
    try testing.expect(!polynode.is_linked(poly));
}

// --- Scenario 14: IN_FLIGHT → FREE ---
test "14 - IN_FLIGHT to FREE" {
    const alloc: std.mem.Allocator = testing.allocator;
    var slot: Slot = null;
    try EventPolyHelper.create(alloc, &slot);
    try testing.expect(slot != null);

    const poly: *PolyNode = slot.?;
    _ = EventPolyHelper.mustFromPoly(poly);
    EventPolyHelper.destroy(alloc, &slot);

    try testing.expectEqual(@as(Slot, null), slot);
}

// --- Scenario 17: Use after nil-out ---
test "17 - slot is null after nil-out" {
    var ev: Event = .{};
    EventPolyHelper.init(&ev);

    var slot: Slot = EventPolyHelper.toPoly(&ev);
    slot = null;
    try testing.expectEqual(@as(Slot, null), slot);
}

// --- Scenario 98: moveFromSlot contract ---
test "98 - moveFromSlot takes the item and empties the slot" {
    var ev: Event = .{ .code = 98 };
    EventPolyHelper.init(&ev);

    // Empty slot — nothing to take.
    var empty: Slot = null;
    try testing.expect(EventPolyHelper.moveFromSlot(&empty) == null);
    try testing.expectEqual(@as(Slot, null), empty);

    // Wrong tag — slot is left unchanged.
    var slot: Slot = EventPolyHelper.toPoly(&ev);
    try testing.expect(SensorPolyHelper.moveFromSlot(&slot) == null);
    try testing.expect(slot != null);
    try testing.expectEqual(@as(*PolyNode, EventPolyHelper.toPoly(&ev)), slot.?);

    // Right tag — item comes back, slot is empty.
    const taken: *Event = EventPolyHelper.moveFromSlot(&slot) orelse unreachable;
    try testing.expectEqual(@as(*Event, &ev), taken);
    try testing.expectEqual(@as(i32, 98), taken.*.code);
    try testing.expectEqual(@as(Slot, null), slot);
}

// --- Scenario 99: toPoly contract ---
test "99 - toPoly reaches the embedded PolyNode" {
    var ev: Event = .{ .code = 99 };
    EventPolyHelper.init(&ev);

    // Reaches the embedded node.
    const node: *PolyNode = EventPolyHelper.toPoly(&ev);
    try testing.expectEqual(@as(*PolyNode, &ev.poly), node);
    try testing.expectEqual(EventPolyHelper.TAG, node.*.tag);

    // Inverse of fromPoly.
    try testing.expectEqual(@as(*Event, &ev), EventPolyHelper.mustFromPoly(node));

    // Never modifies the item — still unlinked after the call.
    try testing.expect(!polynode.is_linked(node));

    // Coerces straight into a Slot, no separate accessor needed.
    const slot: Slot = EventPolyHelper.toPoly(&ev);
    try testing.expectEqual(@as(i32, 99), EventPolyHelper.mustFromSlot(&slot).*.code);

    // Each item reaches its own node.
    var other: Event = .{ .code = 7 };
    EventPolyHelper.init(&other);
    try testing.expect(EventPolyHelper.toPoly(&other) != node);
}

// --- Scenario 111: tag-first dispatch recovers every type ---
test "111 - tag-first dispatch recovers every type" {
    var ev: Event = .{ .code = 11 };
    EventPolyHelper.init(&ev);

    var sn: Sensor = .{ .value = 1.5 };
    SensorPolyHelper.init(&sn);

    var tm: Timer = .{};
    TimerPolyHelper.init(&tm);

    var list: ItemList = .{};
    list.append(EventPolyHelper.toPoly(&ev));
    list.append(SensorPolyHelper.toPoly(&sn));
    list.append(TimerPolyHelper.toPoly(&tm));

    var events: usize = 0;
    var sensors: usize = 0;
    var timers: usize = 0;
    var unknown: usize = 0;

    // isIt proves the tag. mustFromPoly then cannot fail.
    while (list.popFirst()) |ih| {
        const tag: *const anyopaque = ih.*.tag;
        if (EventPolyHelper.isIt(tag)) {
            try testing.expectEqual(@as(i32, 11), EventPolyHelper.mustFromPoly(ih).*.code);
            events += 1;
        } else if (SensorPolyHelper.isIt(tag)) {
            try testing.expectEqual(@as(f64, 1.5), SensorPolyHelper.mustFromPoly(ih).*.value);
            sensors += 1;
        } else if (TimerPolyHelper.isIt(tag)) {
            timers += 1;
        } else {
            unknown += 1;
        }
    }

    try testing.expectEqual(@as(usize, 1), events);
    try testing.expectEqual(@as(usize, 1), sensors);
    try testing.expectEqual(@as(usize, 1), timers);
    try testing.expectEqual(@as(usize, 0), unknown);
}

// --- Scenario 112: unknown tag reaches the final else ---
test "112 - unknown tag reaches the final else" {
    var ev: Event = .{ .code = 12 };
    EventPolyHelper.init(&ev);

    var fr: Foreign = .{ .mark = 9 };
    ForeignPolyHelper.init(&fr);

    var list: ItemList = .{};
    list.append(EventPolyHelper.toPoly(&ev));
    list.append(ForeignPolyHelper.toPoly(&fr));

    var events: usize = 0;
    var unknown: usize = 0;

    while (list.popFirst()) |ih| {
        if (EventPolyHelper.isIt(ih.*.tag)) {
            try testing.expectEqual(@as(i32, 12), EventPolyHelper.mustFromPoly(ih).*.code);
            events += 1;
        } else {
            // The item is dropped, not freed. Freeing needs the type,
            // and the branch that runs has none.
            unknown += 1;
        }
    }

    try testing.expectEqual(@as(usize, 1), events);
    try testing.expectEqual(@as(usize, 1), unknown);

    // Dispatch left the unknown item alone. Its holder still owns it.
    try testing.expectEqual(@as(u8, 9), fr.mark);
}

/// A type the dispatch site does not know about.
const Foreign = struct {
    poly: PolyNode = .{},
    mark: u8 = 0,
};
const ForeignPolyHelper = polynode.PolyHelper(Foreign);

const items = @import("examples").items;
const Event = items.Event;
const Sensor = items.Sensor;
const Timer = items.Timer;
const EventPolyHelper = items.Event.EventPolyHelper;
const SensorPolyHelper = items.Sensor.SensorPolyHelper;
const TimerPolyHelper = items.Timer.TimerPolyHelper;

const polynode = @import("matryoshka").polynode;
const PolyNode = polynode.PolyNode;
const Slot = polynode.Slot;
const ItemList = polynode.ItemList;
const std = @import("std");
const testing = std.testing;
