// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Zig mechanisms, on their own.
//!
//! This file exists for the book. Part 2 of the api reference quotes it.
//!
//! It imports no Matryoshka code, and asserts nothing about Matryoshka.
//! That is deliberate. It shows the three parts of Zig that Matryoshka is
//! built out of, before Matryoshka enters the picture.
//!
//! Keep this file. A reader of Part 2 reads these lines.
//!
//! Three mechanisms:
//! - intrusion — the links are part of the struct
//! - type erasure — the list operates on Node, not on the concrete type
//! - ParentHandle — a `*Node` plus `@fieldParentPtr` gets the parent back

// --- The two parent structs ---

/// A parent struct with the list links embedded in it.
const Reading = struct {
    node: std.DoublyLinkedList.Node = .{},
    value: i32 = 0,
};

/// A different parent struct, with the same embedded links.
const Label = struct {
    node: std.DoublyLinkedList.Node = .{},
    text: []const u8 = "",
};

/// A `ParentHandle` is a pointer to the embedded Node.
///
/// It is a handle to the parent struct, carried as a pointer to one field of
/// it. Zig gives the mechanism. This file only names it.
const ParentHandle = *std.DoublyLinkedList.Node;

/// The way back. From the handle to the parent struct.
///
/// The caller supplies `T`. The handle does not carry it.
fn parentOf(comptime T: type, handle: ParentHandle) *T {
    return @fieldParentPtr("node", handle);
}

// --- Scenario B1: intrusion — the links are part of the struct ---
test "B1 - a list of stack structs, with no wrapper allocation" {
    var a: Reading = .{ .value = 1 };
    var b: Reading = .{ .value = 2 };
    var c: Reading = .{ .value = 3 };

    // Nothing is allocated here. The list header is one struct, and every
    // link it follows lives inside a Reading.
    var list: std.DoublyLinkedList = .{};
    list.append(&a.node);
    list.append(&b.node);
    list.append(&c.node);

    try testing.expectEqual(@as(usize, 3), list.len());

    // The items come back in order, as Reading.
    for ([_]i32{ 1, 2, 3 }) |want| {
        const handle: ParentHandle = list.popFirst() orelse unreachable;
        try testing.expectEqual(want, parentOf(Reading, handle).*.value);
    }

    try testing.expect(list.first == null);
}

// --- Scenario B2: type erasure — the list does not know the parent type ---
test "B2 - one list holds two unrelated parent types" {
    var r: Reading = .{ .value = 7 };
    var l: Label = .{ .text = "seven" };

    var list: std.DoublyLinkedList = .{};
    list.append(&r.node);
    list.append(&l.node);

    // The list took both. It never asked what the parent type was.
    try testing.expectEqual(@as(usize, 2), list.len());

    // Getting them out again works only because this test knows the order it
    // put them in. The handles carry no type.
    const first: ParentHandle = list.popFirst() orelse unreachable;
    const second: ParentHandle = list.popFirst() orelse unreachable;

    try testing.expectEqual(@as(i32, 7), parentOf(Reading, first).*.value);
    try testing.expectEqualStrings("seven", parentOf(Label, second).*.text);
}

// --- Scenario B3: the cast is unchecked, so the caller must know ---
test "B3 - the wrong parent type is not caught by anything" {
    var l: Label = .{ .text = "not a reading" };

    const handle: ParentHandle = &l.node;

    // Both casts compile. Both run. Only one of them is right.
    //
    // A Label read as a Reading gives whatever bytes sit where `value` would
    // be. Zig does not check it, and the handle carries nothing to check
    // against.
    const as_label: *Label = parentOf(Label, handle);
    const as_reading: *Reading = parentOf(Reading, handle);

    try testing.expectEqualStrings("not a reading", as_label.*.text);

    // Read, so the compiler keeps the line. The value read is meaningless.
    _ = as_reading.*.value;

    // This is the gap Matryoshka closes. polynode adds a tag next to the
    // node, so the check the caller has to do by hand here is a check on the
    // handle itself.
}

// --- Scenario B4: a handle is a pointer, so identity survives the round trip ---
test "B4 - the handle round trip returns the same struct" {
    var r: Reading = .{ .value = 42 };

    const handle: ParentHandle = &r.node;
    const back: *Reading = parentOf(Reading, handle);

    try testing.expect(back == &r);
    try testing.expectEqual(@as(i32, 42), back.*.value);
}

const std = @import("std");
const testing = std.testing;
