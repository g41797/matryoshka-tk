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
    list.append(EventPolyHelper.toPoly(&b));
    list.append(EventPolyHelper.toPoly(&c));
    list.prepend(EventPolyHelper.toPoly(&a));

    try testing.expect(!list.isEmpty());
    try testing.expectEqual(@as(usize, 3), list.len());

    // Items come back in order, as Event, with no builtin in sight.
    for ([_]i32{ 1, 2, 3 }) |want| {
        const ih = list.popFirst() orelse unreachable;
        const ev: *Event = EventPolyHelper.fromPoly(ih) orelse unreachable;
        try testing.expectEqual(want, ev.*.code);
    }
    try testing.expect(list.isEmpty());
    try testing.expect(list.popFirst() == null);

    // insertAfter places an item directly behind one already in the list.
    list.append(EventPolyHelper.toPoly(&a));
    list.insertAfter(EventPolyHelper.toPoly(&a), EventPolyHelper.toPoly(&c));
    list.insertAfter(EventPolyHelper.toPoly(&a), EventPolyHelper.toPoly(&b));

    for ([_]i32{ 1, 2, 3 }) |want| {
        const ih = list.popFirst() orelse unreachable;
        try testing.expectEqual(want, EventPolyHelper.mustFromPoly(ih).*.code);
    }
}

// --- Scenario 101: popFirst clears the links ---
test "101 - ItemList popFirst returns an unlinked item" {
    var a: Event = .{ .code = 1 };
    var b: Event = .{ .code = 2 };
    EventPolyHelper.init(&a);
    EventPolyHelper.init(&b);

    var list: ItemList = .{};
    list.append(EventPolyHelper.toPoly(&a));
    list.append(EventPolyHelper.toPoly(&b));

    // Linked while held.
    try testing.expect(polynode.is_linked(EventPolyHelper.toPoly(&a)));

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

// --- Scenario 103: iterator and concat ---
test "103 - ItemList iterator walks, concat empties the source" {
    var a: Event = .{ .code = 1 };
    var b: Event = .{ .code = 2 };
    var c: Event = .{ .code = 3 };
    EventPolyHelper.init(&a);
    EventPolyHelper.init(&b);
    EventPolyHelper.init(&c);

    var first: ItemList = .{};
    first.append(EventPolyHelper.toPoly(&a));

    var second: ItemList = .{};
    second.append(EventPolyHelper.toPoly(&b));
    second.append(EventPolyHelper.toPoly(&c));

    // concat moves every item over and leaves the source empty.
    first.concat(&second);
    try testing.expect(second.isEmpty());
    try testing.expectEqual(@as(usize, 3), first.len());

    // iterator yields ItemHandle in order and removes nothing.
    var seen: i32 = 0;
    var it = first.iterator();
    while (it.next()) |ih| {
        seen += 1;
        try testing.expectEqual(seen, EventPolyHelper.mustFromPoly(ih).*.code);
        // Still linked — a walk is not a pop.
        try testing.expect(polynode.is_linked(ih));
    }
    try testing.expectEqual(@as(i32, 3), seen);
    try testing.expectEqual(@as(usize, 3), first.len());

    // Walking an empty list yields nothing.
    var none: ItemList = .{};
    var empty_it = none.iterator();
    try testing.expect(empty_it.next() == null);

    // Same list twice does nothing. concatByMoving would ring the items and
    // clear the header, and all 3 would be gone.
    //
    // The assert catches this under runtime safety, so only the builds
    // without it reach the early return. Those are the builds that need it.
    if (!std.debug.runtime_safety) {
        first.concat(&first);
        try testing.expectEqual(@as(usize, 3), first.len());
        try testing.expectEqual(@as(i32, 1), EventPolyHelper.mustFromPoly(first.first().?).*.code);
        try testing.expectEqual(@as(i32, 3), EventPolyHelper.mustFromPoly(first.last().?).*.code);
    }
}

// --- Scenario 104: appendFromSlot and prependFromSlot empty the Slot ---
test "104 - ItemList appendFromSlot and prependFromSlot take the item" {
    var a: Event = .{ .code = 1 };
    var b: Event = .{ .code = 2 };
    var c: Event = .{ .code = 3 };
    EventPolyHelper.init(&a);
    EventPolyHelper.init(&b);
    EventPolyHelper.init(&c);

    var list: ItemList = .{};

    // The Slot Rule, now kept by the insert itself: the caller writes no
    // `slot = null` line, so it cannot be the line the caller forgets.
    var slot: Slot = EventPolyHelper.toPoly(&b);
    list.appendFromSlot(&slot);
    try testing.expect(slot == null);

    slot = EventPolyHelper.toPoly(&c);
    list.appendFromSlot(&slot);
    try testing.expect(slot == null);

    slot = EventPolyHelper.toPoly(&a);
    list.prependFromSlot(&slot);
    try testing.expect(slot == null);

    try testing.expectEqual(@as(usize, 3), list.len());
    for ([_]i32{ 1, 2, 3 }) |want| {
        const ih = list.popFirst() orelse unreachable;
        try testing.expectEqual(want, EventPolyHelper.mustFromPoly(ih).*.code);
    }
}

// --- Scenario 105: the pop-to-append round trip needs no reset ---
test "105 - ItemList popFirst feeds appendFromSlot directly" {
    var a: Event = .{ .code = 1 };
    var b: Event = .{ .code = 2 };
    EventPolyHelper.init(&a);
    EventPolyHelper.init(&b);

    var from: ItemList = .{};
    from.append(EventPolyHelper.toPoly(&a));
    from.append(EventPolyHelper.toPoly(&b));

    // popFirst hands back an unlinked item, so it is a legal Slot value, and
    // appendFromSlot asserts nothing the pop did not already guarantee.
    var to: ItemList = .{};
    while (from.popFirst()) |ih| {
        var slot: Slot = ih;
        to.appendFromSlot(&slot);
        try testing.expect(slot == null);
    }

    try testing.expect(from.isEmpty());
    try testing.expectEqual(@as(usize, 2), to.len());
    try testing.expectEqual(@as(i32, 1), EventPolyHelper.mustFromPoly(to.popFirst().?).*.code);
    try testing.expectEqual(@as(i32, 2), EventPolyHelper.mustFromPoly(to.popFirst().?).*.code);
}

// --- Scenario 106: remove takes one item out, wherever it sits ---
test "106 - ItemList remove unlinks head, middle and tail" {
    var a: Event = .{ .code = 1 };
    var b: Event = .{ .code = 2 };
    var c: Event = .{ .code = 3 };
    EventPolyHelper.init(&a);
    EventPolyHelper.init(&b);
    EventPolyHelper.init(&c);

    const ia = EventPolyHelper.toPoly(&a);
    const ib = EventPolyHelper.toPoly(&b);
    const ic = EventPolyHelper.toPoly(&c);

    var list: ItemList = .{};
    list.append(ia);
    list.append(ib);
    list.append(ic);

    // Middle.
    list.remove(ib);
    try testing.expectEqual(@as(usize, 2), list.len());
    try testing.expect(!polynode.is_linked(ib));

    // Head.
    list.remove(ia);
    try testing.expectEqual(@as(usize, 1), list.len());
    try testing.expect(!polynode.is_linked(ia));

    // Tail, and the last item at the same time.
    list.remove(ic);
    try testing.expect(list.isEmpty());
    try testing.expect(!polynode.is_linked(ic));

    // A removed item is unlinked, so it goes straight back in.
    list.append(ib);
    try testing.expectEqual(@as(usize, 1), list.len());
}

// --- Scenario 107: popLast mirrors popFirst ---
test "107 - ItemList popLast returns an unlinked item" {
    var a: Event = .{ .code = 1 };
    var b: Event = .{ .code = 2 };
    EventPolyHelper.init(&a);
    EventPolyHelper.init(&b);

    var empty: ItemList = .{};
    try testing.expect(empty.popLast() == null);

    var list: ItemList = .{};
    list.append(EventPolyHelper.toPoly(&a));
    list.append(EventPolyHelper.toPoly(&b));

    const last_ih = list.popLast() orelse unreachable;
    try testing.expectEqual(@as(i32, 2), EventPolyHelper.mustFromPoly(last_ih).*.code);
    try testing.expect(!polynode.is_linked(last_ih));

    // The sole member of a list. is_linked reports false for it either way,
    // which is why the pop has to call reset itself.
    const only = list.popLast() orelse unreachable;
    try testing.expectEqual(@as(i32, 1), EventPolyHelper.mustFromPoly(only).*.code);
    try testing.expect(!polynode.is_linked(only));
    try testing.expect(list.isEmpty());
    try testing.expect(list.popLast() == null);
}

// --- Scenario 108: first and last look, they do not take ---
test "108 - ItemList first and last leave the item in place" {
    var a: Event = .{ .code = 1 };
    var b: Event = .{ .code = 2 };
    EventPolyHelper.init(&a);
    EventPolyHelper.init(&b);

    var list: ItemList = .{};
    try testing.expect(list.first() == null);
    try testing.expect(list.last() == null);

    // A list of one. Both ends are the same item.
    list.append(EventPolyHelper.toPoly(&a));
    try testing.expect(list.first().? == list.last().?);
    try testing.expectEqual(@as(i32, 1), EventPolyHelper.mustFromPoly(list.first().?).*.code);

    list.append(EventPolyHelper.toPoly(&b));
    try testing.expectEqual(@as(i32, 1), EventPolyHelper.mustFromPoly(list.first().?).*.code);
    try testing.expectEqual(@as(i32, 2), EventPolyHelper.mustFromPoly(list.last().?).*.code);

    // Nothing was taken.
    try testing.expectEqual(@as(usize, 2), list.len());
}

// --- Scenario 109: insertBefore mirrors insertAfter ---
test "109 - ItemList insertBefore places the item ahead of an existing one" {
    var a: Event = .{ .code = 1 };
    var b: Event = .{ .code = 2 };
    var c: Event = .{ .code = 3 };
    EventPolyHelper.init(&a);
    EventPolyHelper.init(&b);
    EventPolyHelper.init(&c);

    const ia = EventPolyHelper.toPoly(&a);
    const ib = EventPolyHelper.toPoly(&b);
    const ic = EventPolyHelper.toPoly(&c);

    var list: ItemList = .{};
    list.append(ic);

    // Before the only item, so this is also a prepend.
    list.insertBefore(ic, ia);
    try testing.expect(list.first().? == ia);

    list.insertBefore(ic, ib);
    try testing.expectEqual(@as(usize, 3), list.len());

    for ([_]i32{ 1, 2, 3 }) |want| {
        const ih = list.popFirst() orelse unreachable;
        try testing.expectEqual(want, EventPolyHelper.mustFromPoly(ih).*.code);
    }
}

// --- Scenario 110: moveFromList rejects a half-set std header ---
test "110 - ItemList moveFromList takes a consistent std list" {
    var a: Event = .{ .code = 1 };
    EventPolyHelper.init(&a);

    var raw: std.DoublyLinkedList = .{};
    raw.append(&EventPolyHelper.toPoly(&a).node);

    var list = ItemList.moveFromList(&raw);
    try testing.expect(raw.first == null);
    try testing.expect(raw.last == null);
    try testing.expectEqual(@as(usize, 1), list.len());
    try testing.expect(list.first().? == list.last().?);
}

const items = @import("examples").items;
const Event = items.Event;
const EventPolyHelper = items.Event.EventPolyHelper;

const polynode = @import("matryoshka").polynode;
const Slot = polynode.Slot;
const ItemList = polynode.ItemList;
const std = @import("std");
const testing = std.testing;
