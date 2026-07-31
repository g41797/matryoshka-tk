// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Produce-consume with defer cleanup.
//!
//! - Push 5 Events into a list (producer).
//! - Pop each, sum the codes (consumer).
//! - defer frees any items remaining on error, before or after the loop.
//!
//!
//! ```
//!  alloc.create × 5 ──► list (producer)
//!       │ list.popFirst × 5
//!       ▼
//!  freeItem per node (consumer)
//! ```
//!

pub fn produce_consume_with_defer_cleanup(allocator: std.mem.Allocator, io: std.Io) !void {
    _ = io;
    var list: polynode.ItemList = .{};

    defer freeRemaining(&list, allocator);

    var i: i32 = 0;
    while (i < 5) : (i += 1) {
        var slot: Slot = null;
        try items.Event.EventPolyHelper.create(allocator, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = i;
        list.appendFromSlot(&slot);
    }

    var sum: i32 = 0;
    while (list.popFirst()) |poly| {
        const ev: *items.Event = items.Event.EventPolyHelper.fromNode(poly) orelse return error.CastFailed;
        sum += ev.*.code;
        items.freeItem(poly, allocator);
    }

    try helpers.expect(error.ProduceConsumeFailed, sum == 0 + 1 + 2 + 3 + 4, "wrong sum");
}

fn freeRemaining(list: *polynode.ItemList, alloc: std.mem.Allocator) void {
    while (list.popFirst()) |poly| {
        items.freeItem(poly, alloc);
    }
}

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const polynode = @import("matryoshka").polynode;
const std = @import("std");
const Slot = polynode.Slot;
