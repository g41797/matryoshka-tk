// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Two Masters, the same items, two different tables.
//!
//! The case a chain cannot express. A PolyTag says what an item **is**, not
//! what a Master should **do** with it. The same Event is a log line to one
//! Master and a counter bump to another, so the handler belongs to the pair
//! (Master, tag) — which is what a table holds.
//!
//! - Two Masters, one mailbox each. Neither knows about the other.
//! - The producer sends the same three item types to both.
//! - LogMaster names all three tags. CountMaster names Event and Sensor,
//!   and has no handler for a Timer — a normal state of affairs, not a
//!   defect. It sees error.NoHandler and frees the item itself.
//! - EventPolyHelper.TAG sits in both tables against different handlers.
//!
//!
//! ```
//!  producer ──► LogMaster.mailbox   ──► log_table   ──► logEvent
//!           │                                       ──► logSensor
//!           │                                       ──► logTimer
//!           │
//!           └──► CountMaster.mailbox ──► count_table ──► countEvent
//!                                                    ──► countSensor
//!                                       Timer: no entry ──► NoHandler
//! ```
//!
//! Each Master runs the identical loop:
//!
//! ```
//!  try_receive ──► table.dispatch(self, &slot) ──► freeSlot whatever is left
//! ```
//!
//! Only the table differs. Changing what a Master does is changing data, not
//! rewriting a chain.
//!

pub fn table_dispatch_two_masters(allocator: std.mem.Allocator, io: std.Io) !void {
    var log_master: LogMaster = try .init(allocator, io);
    defer log_master.deinit();

    var count_master: CountMaster = try .init(allocator, io);
    defer count_master.deinit();

    // The same items to both mailboxes.
    try produce(allocator, log_master.mbx);
    try produce(allocator, count_master.mbx);

    try log_master.run();
    try count_master.run();

    try helpers.expect(error.TableDispatchMastersFailed, log_master.lines == 3, "wrong line count");
    try helpers.expect(error.TableDispatchMastersFailed, count_master.events == 1, "wrong event count");
    try helpers.expect(error.TableDispatchMastersFailed, count_master.sensors == 1, "wrong sensor count");
    try helpers.expect(error.TableDispatchMastersFailed, count_master.unhandled == 1, "wrong unhandled count");

    std.log.info(
        "log master: {d} lines. count master: {d} events, {d} sensors, {d} unhandled",
        .{ log_master.lines, count_master.events, count_master.sensors, count_master.unhandled },
    );
}

/// One Event, one Sensor, one Timer.
fn produce(allocator: std.mem.Allocator, mbx: *Mbox) !void {
    {
        var slot: Slot = null;
        errdefer items.freeSlot(&slot, allocator);
        try items.Event.EventPolyHelper.create(allocator, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = 7;
        try mbx.send(&slot);
    }

    {
        var slot: Slot = null;
        errdefer items.freeSlot(&slot, allocator);
        try items.Sensor.SensorPolyHelper.create(allocator, &slot);
        items.Sensor.SensorPolyHelper.mustFromSlot(&slot).value = 2.71;
        try mbx.send(&slot);
    }

    {
        var slot: Slot = null;
        errdefer items.freeSlot(&slot, allocator);
        try items.Timer.TimerPolyHelper.create(allocator, &slot);
        try mbx.send(&slot);
    }
}

/// Writes a line for every item it is given.
const LogMaster = struct {
    const Table = helpers.TagTable(LogMaster);

    /// A container-level const. Every LogMaster shares it, and nothing
    /// builds it at start-up.
    const table: Table = .{ .entries = &.{
        .{ .tag = items.Event.EventPolyHelper.TAG, .handler = logEvent },
        .{ .tag = items.Sensor.SensorPolyHelper.TAG, .handler = logSensor },
        .{ .tag = items.Timer.TimerPolyHelper.TAG, .handler = logTimer },
    } };

    allocator: std.mem.Allocator,
    mbx: *Mbox,
    lines: usize = 0,

    fn init(allocator: std.mem.Allocator, io: std.Io) !LogMaster {
        var mbx_slot: Slot = null;
        try mailbox.new(io, allocator, &mbx_slot);
        return .{ .allocator = allocator, .mbx = Mbox.moveFromSlot(&mbx_slot).? };
    }

    fn deinit(self: *LogMaster) void {
        var rem: polynode.ItemList = self.mbx.close();
        items.freeList(&rem, self.allocator);
        mailbox.destroy(self.mbx, self.allocator);
    }

    fn run(self: *LogMaster) !void {
        while (true) {
            var slot: Slot = null;
            // Covers every outcome: takes, forwards, or leaves. Does
            // nothing when the handler emptied the Slot.
            defer items.freeSlot(&slot, self.allocator);

            if (!try self.mbx.try_receive(&slot)) return;
            try table.dispatch(self, &slot);
        }
    }

    // The table matched the tag, so mustFromSlot cannot fail.

    fn logEvent(self: *LogMaster, slot: *Slot) anyerror!void {
        const ev = items.Event.EventPolyHelper.mustFromSlot(slot);
        std.log.info("log master: event code={d}", .{ev.*.code});
        self.lines += 1;
    }

    fn logSensor(self: *LogMaster, slot: *Slot) anyerror!void {
        const sn = items.Sensor.SensorPolyHelper.mustFromSlot(slot);
        std.log.info("log master: sensor value={d}", .{sn.*.value});
        self.lines += 1;
    }

    fn logTimer(self: *LogMaster, _: *Slot) anyerror!void {
        // A handler that never reaches the item. The tag was enough.
        std.log.info("log master: timer", .{});
        self.lines += 1;
    }
};

/// Counts what it is given. Same items, other work.
const CountMaster = struct {
    const Table = helpers.TagTable(CountMaster);

    /// The Event tag is in this table too, against a different handler.
    /// The Timer tag is absent — this Master has nothing to do with one.
    const table: Table = .{ .entries = &.{
        .{ .tag = items.Event.EventPolyHelper.TAG, .handler = countEvent },
        .{ .tag = items.Sensor.SensorPolyHelper.TAG, .handler = countSensor },
    } };

    allocator: std.mem.Allocator,
    mbx: *Mbox,
    events: usize = 0,
    sensors: usize = 0,
    unhandled: usize = 0,

    fn init(allocator: std.mem.Allocator, io: std.Io) !CountMaster {
        var mbx_slot: Slot = null;
        try mailbox.new(io, allocator, &mbx_slot);
        return .{ .allocator = allocator, .mbx = Mbox.moveFromSlot(&mbx_slot).? };
    }

    fn deinit(self: *CountMaster) void {
        var rem: polynode.ItemList = self.mbx.close();
        items.freeList(&rem, self.allocator);
        mailbox.destroy(self.mbx, self.allocator);
    }

    fn run(self: *CountMaster) !void {
        while (true) {
            var slot: Slot = null;
            defer items.freeSlot(&slot, self.allocator);

            if (!try self.mbx.try_receive(&slot)) return;

            table.dispatch(self, &slot) catch |err| switch (err) {
                // No entry matched, so nothing was called and the item
                // never left the Slot. This Master knows its own type
                // set, so the defer above frees it. The last branch of an
                // isIt chain has no type and cannot.
                error.NoHandler => self.unhandled += 1,
                else => return err,
            };
        }
    }

    fn countEvent(self: *CountMaster, _: *Slot) anyerror!void {
        self.events += 1;
    }

    fn countSensor(self: *CountMaster, _: *Slot) anyerror!void {
        self.sensors += 1;
    }
};

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const Mbox = matryoshka.Mbox;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
