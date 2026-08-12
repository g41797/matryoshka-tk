//! Sample hook, for demo purposes only.
alloc: std.mem.Allocator,
cap: usize,
io: Io,
mutex: Io.Mutex = .init,
count: usize = 0,

pub fn poolHooks(self: *Self, tags: []const *const anyopaque) pool_mod.Pool.Hooks {
    return .{
        .ctx = self,
        .tags = tags,
        .on_get = onGet,
        .on_put = onPut,
        .on_close = onClose,
    };
}

pub fn onGet(ptr: *anyopaque, tag: *const anyopaque, _: usize, slot: *polynode.Slot) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.mutex.lockUncancelable(self.io);
    defer self.mutex.unlock(self.io);

    if (slot.* != null) {
        // item came from pool — pool already decremented its count; mirror that here
        self.count -= 1;
        return;
    }
    // no item in pool — create a fresh one (not counted until put back)
    items.createByTag(tag, self.alloc, slot);
}

pub fn onPut(ptr: *anyopaque, _: usize, slot: *polynode.Slot) ?polynode.ItemList {
    if (slot.* == null) return null;
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.mutex.lockUncancelable(self.io);
    defer self.mutex.unlock(self.io);

    if (self.count >= self.cap) {
        items.freeItem(slot.*.?, self.alloc);
        slot.* = null;
    } else {
        items.resetOnPut(slot);
        self.count += 1;
    }
    return null;
}

pub fn onClose(ptr: *anyopaque, list: *polynode.ItemList) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    items.freeList(list, self.alloc);
    self.count = 0;
}

const Self = @This();
const items = @import("../items/items.zig");
const polynode = @import("matryoshka").polynode;
const pool_mod = @import("matryoshka").pool;
const std = @import("std");
const Io = std.Io;
