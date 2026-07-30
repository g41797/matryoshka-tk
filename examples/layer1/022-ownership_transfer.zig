// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Item transfer via Slot.
//!
//! - Create an Event, place it in a Slot.
//! - Take it out with moveFromSlot, append it to a list.
//! - Pop the item back out of the list, assign it to a Slot.
//! - Verify the recovered data, then free it.
//!
//! moveFromSlot checks the tag and empties the Slot in one step.\
//! fromSlot would leave the Slot full — that is the difference.
//!
//!
//! ```
//!  alloc.create ──► slot (non-null)
//!       │ moveFromSlot + list.append
//!       ▼
//!  list (holds item)
//!       │ list.popFirst + slot=item
//!       ▼
//!  slot (holds item again)
//!       │ freeSlot
//!       ▼
//!  freed
//! ```
//!

pub fn item_transfer_via_slot(allocator: std.mem.Allocator, io: std.Io) !void {
    _ = io;

    var slot: Slot = null;
    defer items.Event.EventPolyHelper.destroy(allocator, &slot);
    try items.Event.EventPolyHelper.create(allocator, &slot);
    const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
    ev.*.code = 42;
    try helpers.expect(error.ItemTransferFailed, slot != null, "slot should be non-null after create");

    // Transfer to list — moveFromSlot checks the tag and empties the slot.
    var list: polynode.ItemList = .{};
    const moved: *items.Event = items.Event.EventPolyHelper.moveFromSlot(&slot) orelse return error.WrongTag;
    list.append(&moved.*.poly);
    try helpers.expect(error.ItemTransferFailed, slot == null, "slot should be null after transfer");

    // Recover from list — assign back to slot.
    slot = list.popFirst() orelse return error.EmptyList;
    try helpers.expect(error.ItemTransferFailed, slot != null, "slot should be non-null after recovery");

    const recovered: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
    try helpers.expect(error.ItemTransferFailed, recovered.*.code == 42, "wrong event code");

    items.freeSlot(&slot, allocator);
    try helpers.expect(error.ItemTransferFailed, slot == null, "slot should be null after destroy");
    // defer runs as no-op
}

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const polynode = @import("matryoshka").polynode;
const std = @import("std");
const Slot = polynode.Slot;
