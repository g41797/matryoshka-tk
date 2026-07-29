// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Define a PolyNode type.
//!
//! - Message struct embeds a poly: PolyNode field.
//! - PolyHelper(Message) gives tag identity, init, and toNode.
//! - init sets the tag on a stack value, no heap.
//! - isIt checks the tag.
//! - toNode reaches the embedded PolyNode — the way in.
//! - The node carries the tag and starts unlinked, ready to be placed.
//!
//! Coming back the other way is fromNode. It needs a node whose type is
//! not known statically, so it is shown in 023-tag_dispatch.
//!
//!
//! ```
//!  stack: var msg: Message
//!       │
//!  PolyHelper.init ──► msg.poly.tag set (no alloc)
//!       │
//!  MessagePolyHelper.toNode ──► *PolyNode (the way in)
//!       │
//!  node carries the tag, not linked yet
//!  (stack-allocated — no free needed)
//! ```
//!

pub fn define_a_polynode_type(allocator: std.mem.Allocator, io: std.Io) !void {
    _ = .{ allocator, io };

    // A Message on the stack. No allocator involved.
    var msg: Message = .{ .text = "hello", .priority = 1 };
    MessagePolyHelper.init(&msg);

    // The tag identifies the type at runtime.
    try helpers.expect(error.DefineTypeFailed, MessagePolyHelper.isIt(msg.poly.tag), "expected Message tag");
    try helpers.expect(error.DefineTypeFailed, !items.Event.EventPolyHelper.isIt(msg.poly.tag), "unexpected Event tag");

    // toNode reaches the embedded PolyNode. Nothing else needs to know
    // the field is called poly.
    const handle: polynode.ItemHandle = MessagePolyHelper.toNode(&msg);

    // The node travels with its tag, so a holder can identify it later.
    try helpers.expect(error.DefineTypeFailed, MessagePolyHelper.isIt(handle.*.tag), "node must carry the Message tag");

    // A fresh item sits in no list yet.
    try helpers.expect(error.DefineTypeFailed, !polynode.is_linked(handle), "new item must be unlinked");
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
