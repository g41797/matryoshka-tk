// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Define a PolyNode type.
//!
//! - Message struct embeds a poly: PolyNode field.
//! - PolyHelper(Message) gives tag identity and fromNode.
//! - init sets the tag on a stack value, no heap.
//! - isIt checks the tag; fromNode recovers the typed pointer.
//!
//!
//! ```
//!  stack: var msg: Message
//!       │
//!  PolyHelper.init ──► msg.poly.tag set (no alloc)
//!       │
//!  MessagePolyHelper.fromNode ──► field access (no transfer)
//!  (stack-allocated — no free needed)
//! ```
//!

pub fn define_a_polynode_type(allocator: std.mem.Allocator, io: std.Io) !void {
    _ = .{ allocator, io };

    var msg: Message = .{ .text = "hello", .priority = 1 };
    MessagePolyHelper.init(&msg);

    try helpers.expect(error.DefineTypeFailed, MessagePolyHelper.isIt(msg.poly.tag), "expected Message tag");
    try helpers.expect(error.DefineTypeFailed, !items.Event.EventPolyHelper.isIt(msg.poly.tag), "unexpected Event tag");

    const poly: *polynode.PolyNode = &msg.poly;
    const recovered: *Message = MessagePolyHelper.fromNode(poly) orelse return error.CastFailed;
    try helpers.expect(error.DefineTypeFailed, std.mem.eql(u8, "hello", recovered.*.text), "wrong text");
    try helpers.expect(error.DefineTypeFailed, recovered.*.priority == 1, "wrong priority");
}

pub const Message = struct {
    poly: polynode.PolyNode = .{},
    text: []const u8 = "",
    priority: u8 = 0,
};

pub const MessagePolyHelper = polynode.PolyHelper(Message);

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const polynode = @import("matryoshka").polynode;
const std = @import("std");
