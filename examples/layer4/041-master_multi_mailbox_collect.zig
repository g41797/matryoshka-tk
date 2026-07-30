// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Master pre-shutdown collect.
//!
//! - Fill mailbox_a with 2 Events, mailbox_b with 3 Sensors.
//! - closeAndMerge closes both, merges the lists with concatByMoving.
//! - collectAndFree walks the combined list once, frees every item.
//!
//!
//! ```
//!  mailbox_a (2 items)    mailbox_b (3 items)
//!  │
//!  mailbox_a.close ──► list_a (ItemList, 2 items)
//!  mailbox_b.close ──► list_b (ItemList, 3 items)
//!  list_a.concat(&list_b) ──► combined (5 items)
//!  walk combined: popFirst ──► freeItem (×5)
//!  │
//!  One stdlib walk handles items from multiple mailboxes — no special API.
//! ```
//!

pub fn master_pre_shutdown_collect(allocator: std.mem.Allocator, io: std.Io) !void {
    const mbh_a: MailboxHandle = try mailbox.new(io, allocator);
    const mbh_b: MailboxHandle = try mailbox.new(io, allocator);

    var ctx: Ctx = .{ .mbh_a = mbh_a, .mbh_b = mbh_b, .alloc = allocator };
    try ctx.fillMailboxA();
    try ctx.fillMailboxB();
    std.log.info("before collect: {d} in mailbox_a, {d} in mailbox_b", .{ N_A, N_B });

    var combined: polynode.ItemList = ctx.closeAndMerge();
    const freed = collectAndFree(&combined, allocator);

    try helpers.expect(error.MasterMultiMailboxFailed, freed == N_A + N_B, "freed count mismatch");
    std.log.info("done: {d} items from {d} mailboxes — stdlib concatByMoving + popFirst walk", .{ freed, 2 });
}

const N_A: usize = 2;
const N_B: usize = 3;

const Ctx = struct {
    mbh_a: MailboxHandle,
    mbh_b: MailboxHandle,
    alloc: std.mem.Allocator,

    fn fillMailboxA(self: *Ctx) !void {
        for (0..N_A) |i| {
            var slot: Slot = null;
            defer items.Event.EventPolyHelper.destroy(self.alloc, &slot);
            try items.Event.EventPolyHelper.create(self.alloc, &slot);
            items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(i + 1);
            try mailbox.send(self.mbh_a, &slot);
        }
    }

    fn fillMailboxB(self: *Ctx) !void {
        for (0..N_B) |i| {
            var slot: Slot = null;
            defer items.Sensor.SensorPolyHelper.destroy(self.alloc, &slot);
            try items.Sensor.SensorPolyHelper.create(self.alloc, &slot);
            items.Sensor.SensorPolyHelper.mustFromSlot(&slot).value = @floatFromInt(i + 10);
            try mailbox.send(self.mbh_b, &slot);
        }
    }

    fn closeAndMerge(self: *Ctx) polynode.ItemList {
        var list_a: polynode.ItemList = mailbox.close(self.mbh_a);
        mailbox.destroy(self.mbh_a, self.alloc);
        var list_b: polynode.ItemList = mailbox.close(self.mbh_b);
        mailbox.destroy(self.mbh_b, self.alloc);
        list_a.concat(&list_b);
        std.log.info("concatByMoving: combined list has {d} items", .{N_A + N_B});
        return list_a;
    }
};

fn collectAndFree(combined: *polynode.ItemList, alloc: std.mem.Allocator) usize {
    var freed: usize = 0;
    while (combined.popFirst()) |poly| {
        items.freeItem(poly, alloc);
        freed += 1;
    }
    return freed;
}

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
const MailboxHandle = mailbox.MailboxHandle;
