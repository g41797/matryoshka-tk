//! Fake items for the examples — don't ship these.
pub const Event = @import("Event.zig");
pub const Sensor = @import("Sensor.zig");
pub const ShutdownCommand = @import("ShutdownCommand.zig");
pub const Timer = @import("Timer.zig");

pub fn freeItem(poly: *polynode.PolyNode, alloc: std.mem.Allocator) void {
    if (Event.EventPolyHelper.fromPoly(poly)) |ev| {
        alloc.destroy(ev);
    } else if (Sensor.SensorPolyHelper.fromPoly(poly)) |sn| {
        alloc.destroy(sn);
    } else if (Timer.TimerPolyHelper.fromPoly(poly)) |tm| {
        alloc.destroy(tm);
    } else if (ShutdownCommand.ShutdownCommandPolyHelper.fromPoly(poly)) |sc| {
        alloc.destroy(sc);
    } else {
        // An unknown tag cannot be freed here — destroy needs the type.
        // These four are the whole item set of the examples, so reaching
        // this branch means the caller passed something else.
        unreachable;
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
    if (tag == Event.EventPolyHelper.TAG) {
        Event.EventPolyHelper.create(alloc, slot) catch return;
    } else if (tag == Sensor.SensorPolyHelper.TAG) {
        Sensor.SensorPolyHelper.create(alloc, slot) catch return;
    } else unreachable;
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
