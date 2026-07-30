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

// --- Scenario 4: fromNode success ---
test "4 - fromNode success" {
    var ev: Event = .{ .code = 42 };
    EventPolyHelper.init(&ev);

    const poly: *PolyNode = EventPolyHelper.toNode(&ev);
    const recovered: *Event = EventPolyHelper.mustFromNode(poly);
    try testing.expectEqual(@as(i32, 42), recovered.*.code);
}

// --- Scenario 5: fromNode wrong tag ---
test "5 - fromNode wrong tag" {
    var ev: Event = .{ .code = 42 };
    EventPolyHelper.init(&ev);

    const poly: *PolyNode = EventPolyHelper.toNode(&ev);
    const result: ?*Sensor = SensorPolyHelper.fromNode(poly);
    try testing.expectEqual(@as(?*Sensor, null), result);
}

// --- Scenario 6: Two-level @fieldParentPtr chain ---
test "6 - two-level fieldParentPtr chain" {
    var ev: Event = .{ .code = 99 };
    EventPolyHelper.init(&ev);

    const dll_node: *std.DoublyLinkedList.Node = &ev.poly.node;
    const poly: *PolyNode = @fieldParentPtr("node", dll_node);
    const recovered: *Event = EventPolyHelper.mustFromNode(poly);
    try testing.expectEqual(@as(i32, 99), recovered.*.code);
}

// --- Scenario 7: polynode.reset clears links ---
test "7 - polynode.reset clears links" {
    var ev: Event = .{};
    EventPolyHelper.init(&ev);

    ev.poly.node.prev = &ev.poly.node;
    ev.poly.node.next = &ev.poly.node;
    try testing.expect(polynode.is_linked(EventPolyHelper.toNode(&ev)));

    polynode.reset(EventPolyHelper.toNode(&ev));
    try testing.expectEqual(@as(?*std.DoublyLinkedList.Node, null), ev.poly.node.prev);
    try testing.expectEqual(@as(?*std.DoublyLinkedList.Node, null), ev.poly.node.next);
}

// --- Scenario 8: polynode.is_linked detection ---
test "8 - polynode.is_linked detection" {
    var ev: Event = .{};
    EventPolyHelper.init(&ev);

    try testing.expect(!polynode.is_linked(EventPolyHelper.toNode(&ev)));

    ev.poly.node.prev = &ev.poly.node;
    try testing.expect(polynode.is_linked(EventPolyHelper.toNode(&ev)));

    polynode.reset(EventPolyHelper.toNode(&ev));
    try testing.expect(!polynode.is_linked(EventPolyHelper.toNode(&ev)));
}

// --- Scenario 9: Slot null semantics ---
test "9 - slot null semantics" {
    var ev: Event = .{};
    EventPolyHelper.init(&ev);

    var slot: Slot = EventPolyHelper.toNode(&ev);
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
        if (EventPolyHelper.fromNode(poly)) |recovered_ev| {
            try testing.expectEqual(@as(i32, 10), recovered_ev.*.code);
            count_event += 1;
        } else if (SensorPolyHelper.fromNode(poly)) |recovered_sn| {
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

    const slot: Slot = EventPolyHelper.toNode(&ev);
    try testing.expect(slot != null);
    try testing.expect(!polynode.is_linked(EventPolyHelper.toNode(&ev)));
}

// --- Scenario 12: IN_FLIGHT → HELD (list) ---
test "12 - IN_FLIGHT to HELD via list" {
    var ev1: Event = .{};
    EventPolyHelper.init(&ev1);
    var ev2: Event = .{};
    EventPolyHelper.init(&ev2);

    var slot: Slot = EventPolyHelper.toNode(&ev1);
    var list: std.DoublyLinkedList = .{};
    list.append(&ev1.poly.node);
    list.append(&ev2.poly.node);
    slot = null;

    try testing.expectEqual(@as(Slot, null), slot);
    try testing.expect(polynode.is_linked(EventPolyHelper.toNode(&ev1)));
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
    _ = EventPolyHelper.mustFromNode(poly);
    EventPolyHelper.destroy(alloc, &slot);

    try testing.expectEqual(@as(Slot, null), slot);
}

// --- Scenario 17: Use after nil-out ---
test "17 - slot is null after nil-out" {
    var ev: Event = .{};
    EventPolyHelper.init(&ev);

    var slot: Slot = EventPolyHelper.toNode(&ev);
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
    var slot: Slot = EventPolyHelper.toNode(&ev);
    try testing.expect(SensorPolyHelper.moveFromSlot(&slot) == null);
    try testing.expect(slot != null);
    try testing.expectEqual(@as(*PolyNode, EventPolyHelper.toNode(&ev)), slot.?);

    // Right tag — item comes back, slot is empty.
    const taken: *Event = EventPolyHelper.moveFromSlot(&slot) orelse unreachable;
    try testing.expectEqual(@as(*Event, &ev), taken);
    try testing.expectEqual(@as(i32, 98), taken.*.code);
    try testing.expectEqual(@as(Slot, null), slot);
}

// --- Scenario 99: toNode contract ---
test "99 - toNode reaches the embedded PolyNode" {
    var ev: Event = .{ .code = 99 };
    EventPolyHelper.init(&ev);

    // Reaches the embedded node.
    const node: *PolyNode = EventPolyHelper.toNode(&ev);
    try testing.expectEqual(@as(*PolyNode, &ev.poly), node);
    try testing.expectEqual(EventPolyHelper.TAG, node.*.tag);

    // Inverse of fromNode.
    try testing.expectEqual(@as(*Event, &ev), EventPolyHelper.mustFromNode(node));

    // Never modifies the item — still unlinked after the call.
    try testing.expect(!polynode.is_linked(node));

    // Coerces straight into a Slot, no separate accessor needed.
    const slot: Slot = EventPolyHelper.toNode(&ev);
    try testing.expectEqual(@as(i32, 99), EventPolyHelper.mustFromSlot(&slot).*.code);

    // Each item reaches its own node.
    var other: Event = .{ .code = 7 };
    EventPolyHelper.init(&other);
    try testing.expect(EventPolyHelper.toNode(&other) != node);
}

// --- Scenario 100: ItemList speaks ItemHandle ---
test "100 - ItemList append, prepend, insertAfter, popFirst" {
    var a: Event = .{ .code = 1 };
    var b: Event = .{ .code = 2 };
    var c: Event = .{ .code = 3 };
    EventPolyHelper.init(&a);
    EventPolyHelper.init(&b);
    EventPolyHelper.init(&c);

    var list: ItemList = .{};
    try testing.expect(list.isEmpty());
    try testing.expectEqual(@as(usize, 0), list.len());
    try testing.expect(list.popFirst() == null);

    // append puts items at the end, prepend at the front.
    list.append(EventPolyHelper.toNode(&b));
    list.append(EventPolyHelper.toNode(&c));
    list.prepend(EventPolyHelper.toNode(&a));

    try testing.expect(!list.isEmpty());
    try testing.expectEqual(@as(usize, 3), list.len());

    // Items come back in order, as Event, with no builtin in sight.
    for ([_]i32{ 1, 2, 3 }) |want| {
        const ih = list.popFirst() orelse unreachable;
        const ev: *Event = EventPolyHelper.fromNode(ih) orelse unreachable;
        try testing.expectEqual(want, ev.*.code);
    }
    try testing.expect(list.isEmpty());
    try testing.expect(list.popFirst() == null);

    // insertAfter places an item directly behind one already in the list.
    list.append(EventPolyHelper.toNode(&a));
    list.insertAfter(EventPolyHelper.toNode(&a), EventPolyHelper.toNode(&c));
    list.insertAfter(EventPolyHelper.toNode(&a), EventPolyHelper.toNode(&b));

    for ([_]i32{ 1, 2, 3 }) |want| {
        const ih = list.popFirst() orelse unreachable;
        try testing.expectEqual(want, EventPolyHelper.mustFromNode(ih).*.code);
    }
}

// --- Scenario 101: popFirst clears the links ---
test "101 - ItemList popFirst returns an unlinked item" {
    var a: Event = .{ .code = 1 };
    var b: Event = .{ .code = 2 };
    EventPolyHelper.init(&a);
    EventPolyHelper.init(&b);

    var list: ItemList = .{};
    list.append(EventPolyHelper.toNode(&a));
    list.append(EventPolyHelper.toNode(&b));

    // Linked while held.
    try testing.expect(polynode.is_linked(EventPolyHelper.toNode(&a)));

    // This is the guarantee: no caller-side reset() needed.
    const first = list.popFirst() orelse unreachable;
    try testing.expect(!polynode.is_linked(first));

    // Holds for the last item too, whose links point back, not forward.
    const second = list.popFirst() orelse unreachable;
    try testing.expect(!polynode.is_linked(second));

    // A popped item goes straight into a Slot, which asserts it is unlinked.
    var slot: Slot = second;
    try testing.expectEqual(@as(i32, 2), EventPolyHelper.moveFromSlot(&slot).?.*.code);
}

// --- Scenario 102: moves empty their source ---
test "102 - ItemList moveFromList and moveToList" {
    var a: Event = .{ .code = 1 };
    var b: Event = .{ .code = 2 };
    EventPolyHelper.init(&a);
    EventPolyHelper.init(&b);

    // Arriving from a std list: the source is emptied, never aliased.
    var raw: std.DoublyLinkedList = .{};
    raw.append(&a.poly.node);
    raw.append(&b.poly.node);

    var list = ItemList.moveFromList(&raw);
    try testing.expect(raw.first == null);
    try testing.expect(raw.last == null);
    try testing.expectEqual(@as(usize, 2), list.len());

    // Leaving for a std list: this list is emptied in turn.
    var back = list.moveToList();
    try testing.expect(list.isEmpty());
    try testing.expectEqual(@as(usize, 2), back.len());
    try testing.expectEqual(@as(*std.DoublyLinkedList.Node, &a.poly.node), back.first.?);

    // Both directions are fine with an empty list.
    var nothing: std.DoublyLinkedList = .{};
    var empty = ItemList.moveFromList(&nothing);
    try testing.expect(empty.isEmpty());
    try testing.expect(empty.moveToList().first == null);
}

// --- Scenario 103: iterate and concat ---
test "103 - ItemList iterate walks, concat empties the source" {
    var a: Event = .{ .code = 1 };
    var b: Event = .{ .code = 2 };
    var c: Event = .{ .code = 3 };
    EventPolyHelper.init(&a);
    EventPolyHelper.init(&b);
    EventPolyHelper.init(&c);

    var first: ItemList = .{};
    first.append(EventPolyHelper.toNode(&a));

    var second: ItemList = .{};
    second.append(EventPolyHelper.toNode(&b));
    second.append(EventPolyHelper.toNode(&c));

    // concat moves every item over and leaves the source empty.
    first.concat(&second);
    try testing.expect(second.isEmpty());
    try testing.expectEqual(@as(usize, 3), first.len());

    // iterate yields ItemHandle in order and removes nothing.
    var seen: i32 = 0;
    var it = first.iterate();
    while (it.next()) |ih| {
        seen += 1;
        try testing.expectEqual(seen, EventPolyHelper.mustFromNode(ih).*.code);
        // Still linked — a walk is not a pop.
        try testing.expect(polynode.is_linked(ih));
    }
    try testing.expectEqual(@as(i32, 3), seen);
    try testing.expectEqual(@as(usize, 3), first.len());

    // Walking an empty list yields nothing.
    var none: ItemList = .{};
    var empty_it = none.iterate();
    try testing.expect(empty_it.next() == null);
}

const items = @import("examples").items;
const Event = items.Event;
const Sensor = items.Sensor;
const EventPolyHelper = items.Event.EventPolyHelper;
const SensorPolyHelper = items.Sensor.SensorPolyHelper;

const polynode = @import("matryoshka").polynode;
const PolyNode = polynode.PolyNode;
const Slot = polynode.Slot;
const ItemList = polynode.ItemList;
const std = @import("std");
const testing = std.testing;
