// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Pool for PolyNode items.
//!
//! A pool:
//! - stores free items by type
//! - creates items through user hooks
//! - recycles returned items
//! - is itself a PolyNode.
//!

const _doc_stub = void;

///
///
/// A pool, viewed as an ItemHandle.
///
/// Sendable, embeddable like any handle.
pub const PoolHandle = polynode.ItemHandle;

/// Acquisition strategy for `get`.
pub const GetMode = enum {
    /// Use a stored handle if one is free; otherwise call `on_get` to create.
    available_or_new,
    /// Always call `on_get` with an empty slot — always creates.
    new_only,
    /// Use a stored handle only. `error.NotAvailable` if none is free.
    available_only,
};

/// Errors from `get` / `get_wait`.
pub const GetError = error{ Closed, NotAvailable, NotCreated };

/// User-supplied hooks that
/// - give a pool its policy
/// - move responsibility to user
///
/// Be careful - your code will run in the heart of Matryoshka!!!
///
/// `in_pool_count` is a hint, read under lock before the hook runs without lock:
/// - `on_get`: count after removal — items remaining with this tag.
/// - `on_put`: count before addition — items already stored with this tag.
///
/// Hooks run outside the pool's mutex.
///
/// Multiple threads (tasks) may call a hook at once — the pool does not serialize them.
///
/// A hook that touches shared state must protect it itself.
///
/// A hook must not call pool APIs or blocking operations.
pub const PoolHooks = struct {
    ctx: *anyopaque,
    tags: []const *const anyopaque,

    /// Called before an item is returned from the pool.
    ///
    /// `tag`: runtime type tag of the item to get.
    ///
    /// `in_pool_count`: number of available items with this tag before removal.
    ///
    /// `slot`: receives the selected item, or stays empty if no item is available.
    on_get: *const fn (
        ctx: *anyopaque,
        tag: *const anyopaque,
        in_pool_count: usize,
        slot: *polynode.Slot,
    ) void,

    /// `slot`: keep, accept, or clear the one carried item.
    ///
    /// Return value: list of other items (usually parts of the former item)
    ///
    /// `null` or an empty list: nothing more to add.
    ///
    /// Non-empty list: each item is added the same way `slot`'s item is, same checks.
    on_put: *const fn (
        ctx: *anyopaque,
        in_pool_count: usize,
        slot: *polynode.Slot,
    ) ?std.DoublyLinkedList,

    /// Called when the pool is closed.
    ///
    /// `list`: all items still remaining in the pool.
    ///
    /// The hook is responsible for processing or destroying every item.
    on_close: *const fn (
        ctx: *anyopaque,
        list: *std.DoublyLinkedList,
    ) void,
};

/// Tag identity and lifecycle for the internal pool type.
pub const PoolPolyHelper = polynode.PolyHelper(_Pool);

/// True if the tag identifies a PoolHandle.
pub inline fn is_it_you(tag: *const anyopaque) bool {
    return PoolPolyHelper.isIt(tag);
}

/// Creates a pool.
pub fn new(io: Io, alloc: std.mem.Allocator) !PoolHandle {
    const p: *_Pool = try alloc.create(_Pool);
    errdefer alloc.destroy(p);
    p.* = .{
        .poly = .{ .tag = PoolPolyHelper.TAG },
        .mutex = .init,
        .cond = .init,
        .lists = .empty,
        .counts = .empty,
        .hooks = null,
        .closed = std.atomic.Value(bool).init(false),
        .io = io,
        .alloc = alloc,
    };
    return &p.*.poly;
}

/// Frees the pool.
///
/// Must be closed first.\
/// Destroying an open pool is a programming error — panics.
pub fn destroy(ph: PoolHandle, alloc: std.mem.Allocator) void {
    const p: *_Pool = PoolPolyHelper.mustIdentifyNodeAs(ph);
    if (!p.*.closed.load(.acquire)) {
        @panic("pool.destroy: pool must be closed first");
    }
    p.*.lists.deinit(alloc);
    p.*.counts.deinit(alloc);
    alloc.destroy(p);
}

/// Registers hooks.
///
/// Call once, right after `new`.
pub fn init(ph: PoolHandle, hooks: PoolHooks) !void {
    const p: *_Pool = PoolPolyHelper.mustIdentifyNodeAs(ph);
    std.debug.assert(hooks.tags.len > 0);

    const io: Io = p.*.io;
    p.*.mutex.lockUncancelable(io);
    defer p.*.mutex.unlock(io);

    std.debug.assert(!p.*.closed.load(.monotonic));
    std.debug.assert(p.*.hooks == null);

    // Grow capacity before any modification — OOM fails cleanly here.
    const n: u32 = @intCast(hooks.tags.len);
    try p.*.lists.ensureTotalCapacity(p.*.alloc, n);
    try p.*.counts.ensureTotalCapacity(p.*.alloc, n);

    for (hooks.tags) |tag| {
        p.*.lists.putAssumeCapacity(tag, .{});
        p.*.counts.putAssumeCapacity(tag, 0);
    }

    p.*.hooks = hooks;
}

/// Acquires a handle without waiting. Calls `on_get`.
///
/// On success, stores the handle in `slot.*`.
pub fn get(ph: PoolHandle, tag: *const anyopaque, mode: GetMode, slot: *polynode.Slot) GetError!void {
    const p: *_Pool = PoolPolyHelper.mustIdentifyNodeAs(ph);
    std.debug.assert(slot.* == null);

    if (p.*.closed.load(.acquire)) return error.Closed;

    return switch (mode) {
        .available_or_new => _get_available_or_new(p, tag, slot),
        .new_only => _get_new_only(p, tag, slot),
        .available_only => _get_available_only(p, tag, slot),
    };
}

/// Acquires a handle, waiting until one is available.\
/// Calls `on_get`.
///
/// `timeout_ns == null`: waits forever.\
/// `timeout_ns == 0`: returns `error.Timeout` immediately.
///
/// Logically equivalent to `get(.available_only)` at that point, but returns\
/// `error.Timeout` instead of `error.NotAvailable` — intentional,
///
/// `get_wait` always uses the timeout error set regardless of the timeout value.
pub fn get_wait(ph: PoolHandle, tag: *const anyopaque, slot: *polynode.Slot, timeout_ns: ?u64) (GetError || Io.Cancelable || error{Timeout})!void {
    const p: *_Pool = PoolPolyHelper.mustIdentifyNodeAs(ph);
    std.debug.assert(slot.* == null);

    if (p.*.closed.load(.acquire)) return error.Closed;
    const io: Io = p.*.io;

    const timeout_val: Io.Timeout = if (timeout_ns) |ns|
        Io.Timeout{ .duration = .{ .raw = .{ .nanoseconds = @as(i96, @intCast(ns)) }, .clock = .real } }
    else
        .none;
    const deadline: Io.Timeout = timeout_val.toDeadline(io);

    p.*.mutex.lock(io) catch |err| return err;
    defer p.*.mutex.unlock(io);

    std.debug.assert(p.*.hooks != null);
    std.debug.assert(p.*.lists.contains(tag));

    while (true) {
        if (p.*.closed.load(.monotonic)) return error.Closed;

        if (p.*.lists.getPtr(tag)) |list| {
            if (list.popFirst()) |node| {
                p.*.counts.getPtr(tag).?.* -= 1;
                const poly: *polynode.PolyNode = @fieldParentPtr("node", node);
                polynode.reset(poly);
                slot.* = poly;
                return;
            }
        }

        cond_timeout.condition_waitTimeout(&p.*.cond, io, &p.*.mutex, deadline) catch |err| switch (err) {
            error.Timeout => {
                if (p.*.lists.getPtr(tag)) |l| if (l.first != null) p.*.cond.broadcast(io);
                return error.Timeout;
            },
            error.Canceled => {
                if (p.*.lists.getPtr(tag)) |l| if (l.first != null) p.*.cond.broadcast(io);
                return err;
            },
        };
    }
}

/// Returns a handle to the pool.
///
/// `slot.* == null`: no-op.
///
/// Open pool:
/// - Calls `on_put`.
/// - `slot.*` left non-null: the item is added to the pool.
/// - `slot.*` cleared to null by the hook: the item is not added.
/// - Any items in the list returned by the hook are added to the pool.
///
/// Closed pool:
/// - No-op.
/// - `slot.*` is unchanged.
pub fn put(ph: PoolHandle, slot: *polynode.Slot) void {
    if (slot.* == null) return;

    const p: *_Pool = PoolPolyHelper.mustIdentifyNodeAs(ph);

    std.debug.assert(!polynode.is_linked(slot.*.?));

    const io: Io = p.*.io;
    p.*.mutex.lockUncancelable(io);

    if (p.*.closed.load(.monotonic)) {
        p.*.mutex.unlock(io);
        return; // handle stays with the caller
    }

    std.debug.assert(p.*.hooks != null);

    const handle: polynode.ItemHandle = slot.*.?;
    const tag: *const anyopaque = handle.*.tag;
    std.debug.assert(p.*.lists.contains(tag));

    const hooks: PoolHooks = p.*.hooks.?;
    const count: usize = p.*.counts.get(tag) orelse 0;

    p.*.mutex.unlock(io);
    var returned: ?std.DoublyLinkedList = hooks.on_put(hooks.ctx, count, slot);
    p.*.mutex.lockUncancelable(io);

    if (!p.*.closed.load(.monotonic)) {
        var added = false;

        if (slot.* != null) {
            _add_returned_item(p, slot.*.?);
            slot.* = null;
            added = true;
        }

        if (returned) |*list| {
            while (list.popFirst()) |node| {
                const poly: *polynode.PolyNode = @fieldParentPtr("node", node);
                polynode.reset(poly);
                _add_returned_item(p, poly);
                added = true;
            }
        }

        if (added) p.*.cond.broadcast(io);
    }

    p.*.mutex.unlock(io);
}

// Add a single returned item to its per-tag free-list.
inline fn _add_returned_item(p: *_Pool, item: polynode.ItemHandle) void {
    std.debug.assert(!polynode.is_linked(item));
    const tag: *const anyopaque = item.*.tag;
    std.debug.assert(p.*.lists.contains(tag));
    const list = p.*.lists.getPtr(tag).?;
    list.prepend(&item.*.node);
    p.*.counts.getPtr(tag).?.* += 1;
}

/// Returns a batch of handles to the pool. Pops from the caller's list.
///
/// Not atomic with `close()`.
///
/// If the pool closes mid-batch:
/// - items already transferred go to `on_close`;\
/// - items not yet transferred stay in the caller's list.
pub fn put_all(ph: PoolHandle, list: *std.DoublyLinkedList) void {
    if (list.first == null) return;

    const p: *_Pool = PoolPolyHelper.mustIdentifyNodeAs(ph);
    const io: Io = p.*.io;

    // Validate all tags under one lock — no partial transfer on bad input.
    p.*.mutex.lockUncancelable(io);
    var node: ?*std.DoublyLinkedList.Node = list.first;
    while (node) |n| : (node = n.next) {
        const poly: *polynode.PolyNode = @fieldParentPtr("node", n);
        std.debug.assert(p.*.lists.contains(poly.*.tag));
    }
    p.*.mutex.unlock(io);

    // Put each item individually.
    while (list.popFirst()) |n| {
        const poly: *polynode.PolyNode = @fieldParentPtr("node", n);
        polynode.reset(poly);
        var slot: polynode.Slot = poly;
        put(ph, &slot);
        if (slot != null) {
            // Pool closed — item returned to caller — restore and stop.
            list.prepend(&slot.?.*.node);
            break;
        }
    }
}

/// Collects all handles from every per-tag free-list,\
/// calls `on_close` once with the full list,\
/// then wakes any blocked `get_wait` callers.
///
/// Safe to call more than once.
pub fn close(ph: PoolHandle) void {
    const p: *_Pool = PoolPolyHelper.mustIdentifyNodeAs(ph);
    const io: Io = p.*.io;
    p.*.mutex.lockUncancelable(io);

    // Check+set closed inside the mutex — prevents destroy() racing a preempted close() caller.
    if (p.*.closed.load(.monotonic)) {
        p.*.mutex.unlock(io);
        return;
    }
    p.*.closed.store(true, .release);

    var collected: std.DoublyLinkedList = .{};
    var it = p.*.lists.valueIterator();
    while (it.next()) |list| {
        _concat(&collected, list);
    }
    p.*.lists.clearRetainingCapacity();
    p.*.counts.clearRetainingCapacity();

    p.*.cond.broadcast(io);
    p.*.mutex.unlock(io);

    if (p.*.hooks) |hooks| {
        hooks.on_close(hooks.ctx, &collected);
    }
}

/// Returned by `get_wait_future` when the Io backend has no concurrency.
pub const ConcurrentError = error{ConcurrencyUnavailable};

/// Result of `get_wait`.
///
/// `.item` contains a valid ItemHandle.
///
/// The other variants describe why no item was returned.
pub const PoolResult = union(enum) {
    item: polynode.ItemHandle,
    closed: void,
    timeout: void,
    canceled: void,
    not_created: void,
};

/// Maps every `get_wait` outcome to a `PoolResult` variant. Blocking.
///
/// No error union.
///
/// Primary building block for `select.concurrent` and `io.concurrent`/`group.concurrent`.
///
/// On cancellation, returns `.canceled`.
///
/// The pool stays open — closing it is the caller's job.
pub fn getWaitResult(ph: PoolHandle, tag: *const anyopaque, timeout_ns: ?u64) PoolResult {
    var slot: polynode.Slot = null;
    get_wait(ph, tag, &slot, timeout_ns) catch |err| return switch (err) {
        error.Closed => .closed,
        error.Timeout => .timeout,
        error.Canceled => .canceled,
        error.NotAvailable => .not_created,
        error.NotCreated => .not_created,
    };
    return .{ .item = slot.? };
}

/// Wraps `getWaitResult` in an `Io.Future` for direct await or `Io.Group` use.
///
/// No heap allocation — args are copied by the runtime.
///
/// `error.ConcurrencyUnavailable` on single-threaded backends.
pub fn get_wait_future(ph: PoolHandle, tag: *const anyopaque, timeout_ns: ?u64) ConcurrentError!Io.Future(PoolResult) {
    const p: *_Pool = PoolPolyHelper.mustIdentifyNodeAs(ph);
    return p.*.io.concurrent(getWaitResult, .{ ph, tag, timeout_ns });
}

fn _concat(dst: *std.DoublyLinkedList, src: *std.DoublyLinkedList) void {
    if (src.first == null) return;
    if (dst.last) |last| {
        last.next = src.first;
        src.first.?.prev = last;
    } else {
        dst.first = src.first;
    }
    dst.last = src.last;
    src.* = .{};
}

inline fn _get_available_or_new(p: *_Pool, tag: *const anyopaque, slot: *polynode.Slot) GetError!void {
    const io: Io = p.*.io;
    p.*.mutex.lockUncancelable(io);

    if (p.*.closed.load(.monotonic)) {
        p.*.mutex.unlock(io);
        return error.Closed;
    }
    std.debug.assert(p.*.hooks != null);
    std.debug.assert(p.*.lists.contains(tag));

    if (p.*.lists.getPtr(tag)) |list| {
        if (list.popFirst()) |node| {
            p.*.counts.getPtr(tag).?.* -= 1;
            const poly: *polynode.PolyNode = @fieldParentPtr("node", node);
            polynode.reset(poly);
            slot.* = poly;
        }
    }

    const hooks: PoolHooks = p.*.hooks.?;
    const count: usize = p.*.counts.get(tag) orelse 0;
    p.*.mutex.unlock(io);

    hooks.on_get(hooks.ctx, tag, count, slot);
    if (slot.*) |h| std.debug.assert(h.*.tag == tag);

    return if (slot.* != null) {} else error.NotCreated;
}

inline fn _get_new_only(p: *_Pool, tag: *const anyopaque, slot: *polynode.Slot) GetError!void {
    const io: Io = p.*.io;
    p.*.mutex.lockUncancelable(io);

    if (p.*.closed.load(.monotonic)) {
        p.*.mutex.unlock(io);
        return error.Closed;
    }
    std.debug.assert(p.*.hooks != null);
    std.debug.assert(p.*.lists.contains(tag));

    const hooks: PoolHooks = p.*.hooks.?;
    const count: usize = p.*.counts.get(tag) orelse 0;
    p.*.mutex.unlock(io);

    hooks.on_get(hooks.ctx, tag, count, slot);
    if (slot.*) |h| std.debug.assert(h.*.tag == tag);

    return if (slot.* != null) {} else error.NotCreated;
}

inline fn _get_available_only(p: *_Pool, tag: *const anyopaque, slot: *polynode.Slot) GetError!void {
    const io: Io = p.*.io;
    p.*.mutex.lockUncancelable(io);
    defer p.*.mutex.unlock(io);

    if (p.*.closed.load(.monotonic)) return error.Closed;
    std.debug.assert(p.*.hooks != null);
    std.debug.assert(p.*.lists.contains(tag));

    if (p.*.lists.getPtr(tag)) |list| {
        if (list.popFirst()) |node| {
            p.*.counts.getPtr(tag).?.* -= 1;
            const poly: *polynode.PolyNode = @fieldParentPtr("node", node);
            polynode.reset(poly);
            slot.* = poly;
            return;
        }
    }

    return error.NotAvailable;
}

const _Pool = struct {
    const no_create_destroy = void{};

    poly: polynode.PolyNode,
    mutex: Io.Mutex,
    cond: Io.Condition,
    lists: std.AutoHashMapUnmanaged(*const anyopaque, std.DoublyLinkedList),
    counts: std.AutoHashMapUnmanaged(*const anyopaque, usize),
    hooks: ?PoolHooks,
    closed: std.atomic.Value(bool),
    io: Io,
    alloc: std.mem.Allocator,
};

const polynode = @import("polynode.zig");
const cond_timeout = @import("internal/cond_timeout.zig");
const std = @import("std");
const Io = std.Io;
