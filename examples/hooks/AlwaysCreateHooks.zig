//! Sample hook, for demo purposes only.
alloc: std.mem.Allocator,

pub fn poolHooks(self: *Self, tags: []const *const anyopaque) pool_mod.PoolHooks {
    return .{
        .ctx = self,
        .tags = tags,
        .on_get = onGet,
        .on_put = onPut,
        .on_close = onClose,
    };
}

pub fn onGet(ptr: *anyopaque, tag: *const anyopaque, _: usize, slot: *polynode.Slot) void {
    if (slot.* != null) return;
    const self: *Self = @ptrCast(@alignCast(ptr));

    // The pool hands over a tag and an empty Slot. There is no item to cast,
    // so the tag is the only thing to dispatch on.
    if (items.Event.EventPolyHelper.isIt(tag)) {
        items.Event.EventPolyHelper.create(self.alloc, slot) catch return;
    } else if (items.Sensor.SensorPolyHelper.isIt(tag)) {
        items.Sensor.SensorPolyHelper.create(self.alloc, slot) catch return;
    } else {
        // Registered with a tag this hook cannot build — a bug at pool.init.
        unreachable;
    }
}

pub fn onPut(_: *anyopaque, _: usize, slot: *polynode.Slot) ?polynode.ItemList {
    if (slot.* == null) return null;
    items.resetOnPut(slot);
    return null;
}

pub fn onClose(ptr: *anyopaque, list: *polynode.ItemList) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    items.freeList(list, self.alloc);
}

const Self = @This();
const items = @import("../items/items.zig");
const polynode = @import("matryoshka").polynode;
const pool_mod = @import("matryoshka").pool;
const std = @import("std");
