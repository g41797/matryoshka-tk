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
    items.createByTag(tag, self.alloc, slot);
}

pub fn onPut(_: *anyopaque, _: usize, slot: *polynode.Slot) ?std.DoublyLinkedList {
    if (slot.* == null) return null;
    items.resetOnPut(slot);
    return null;
}

pub fn onClose(ptr: *anyopaque, list: *std.DoublyLinkedList) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    items.freeList(list, self.alloc);
}

const Self = @This();
const items = @import("../items/items.zig");
const polynode = @import("matryoshka").polynode;
const pool_mod = @import("matryoshka").pool;
const std = @import("std");
