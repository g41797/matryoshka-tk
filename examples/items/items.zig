//! Fake items for the examples — don't ship these.
pub const Event = @import("Event.zig");
pub const Sensor = @import("Sensor.zig");
pub const ShutdownCommand = @import("ShutdownCommand.zig");
pub const Timer = @import("Timer.zig");

pub fn freeItem(poly: *polynode.PolyNode, alloc: std.mem.Allocator) void {
    if (Event.EventPolyHelper.fromNode(poly)) |ev| {
        alloc.destroy(ev);
    } else if (Sensor.SensorPolyHelper.fromNode(poly)) |sn| {
        alloc.destroy(sn);
    } else if (Timer.TimerPolyHelper.fromNode(poly)) |tm| {
        alloc.destroy(tm);
    } else if (ShutdownCommand.ShutdownCommandPolyHelper.fromNode(poly)) |sc| {
        alloc.destroy(sc);
    }
}

pub fn freeSlot(slot: *polynode.Slot, alloc: std.mem.Allocator) void {
    if (slot.*) |poly| {
        freeItem(poly, alloc);
        slot.* = null;
    }
}

pub fn freeList(list: *polynode.ItemList, alloc: std.mem.Allocator) void {
    while (list.popFirst()) |ih| {
        freeItem(ih, alloc);
    }
}

pub fn createByTag(tag: *const anyopaque, alloc: std.mem.Allocator, slot: *polynode.Slot) void {
    if (Event.EventPolyHelper.isIt(tag)) {
        Event.EventPolyHelper.create(alloc, slot) catch return;
    } else if (Sensor.SensorPolyHelper.isIt(tag)) {
        Sensor.SensorPolyHelper.create(alloc, slot) catch return;
    }
}

pub fn resetOnPut(slot: *polynode.Slot) void {
    if (Event.EventPolyHelper.fromSlot(slot)) |ev| {
        ev.*.code = 0;
    } else if (Sensor.SensorPolyHelper.fromSlot(slot)) |sn| {
        sn.*.value = 0.0;
    }
}

pub fn destroyByTag(tag: *const anyopaque, alloc: std.mem.Allocator, slot: *polynode.Slot) void {
    if (Event.EventPolyHelper.isIt(tag)) {
        Event.EventPolyHelper.destroy(alloc, slot);
    } else if (Sensor.SensorPolyHelper.isIt(tag)) {
        Sensor.SensorPolyHelper.destroy(alloc, slot);
    } else if (Timer.TimerPolyHelper.isIt(tag)) {
        Timer.TimerPolyHelper.destroy(alloc, slot);
    } else if (ShutdownCommand.ShutdownCommandPolyHelper.isIt(tag)) {
        ShutdownCommand.ShutdownCommandPolyHelper.destroy(alloc, slot);
    }
}

const polynode = @import("matryoshka").polynode;
const std = @import("std");
