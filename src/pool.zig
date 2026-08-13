// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Pool for PolyNode items.
//!
//! A pool:
//! - holds free items by type
//! - creates items through user hooks
//! - recycles returned items
//! - is itself a PolyNode.
//!
//! # Pool is not storage
//!
//! It answers one question: is a reusable item available right now.
//!
//! It signals backpressure through that answer. What happens to an item on
//! `put` is entirely up to the hooks.
//!
//! # The pool touches items — through your hooks
//!
//! This is the difference from `Mbox`, which never touches an item at all.
//! A pool creates, resets, keeps or destroys — but every one of those is
//! your hook doing it, never the pool deciding.
//!
//! # It does not care whether you closed it — except `destroy`
//!
//! Every other method returns `error.Closed`, or is a no-op, and stays a
//! valid object. Only `destroy` makes closedness a precondition. It panics
//! on an open pool.
//!
//! # A closed pool hands items back
//!
//! - `put` on a closed pool is a no-op and leaves `slot.*` unchanged.
//! - `put_all` stops at the first refusal and leaves the rest in the list.
//!
//! Either way the caller still holds those items and must release them.
//!
//! # Closing releases through `on_close`, not through the caller
//!
//! `close` collects every held item and passes the list to `on_close`.
//!
//! The hook releases them. This is the other difference from `Mbox`, which
//! returns the list to the caller and leaves the releasing to them.
//!
//! `close` can be called more than once. Later calls collect nothing.
//!
//! Examples:
//! https://g41797.github.io/matryoshka-tk/examples/pool/
//!
//! The three together:
//! https://g41797.github.io/matryoshka-tk/examples/flow/
//!

const _doc_stub = void;

///
///
/// A pool.
///
/// A pool is also a PolyNode. `toPoly`/`fromPoly` carry it through
/// a mailbox or another pool like any other item.
///
/// The fields below are internal.\
/// Don't touch.
pub const Pool = struct {
    const no_create_destroy = void{};

    poly: polynode.PolyNode,
    mutex: Io.Mutex,
    cond: Io.Condition,
    lists: std.AutoHashMapUnmanaged(*const anyopaque, polynode.ItemList),
    counts: std.AutoHashMapUnmanaged(*const anyopaque, usize),
    hooks: ?Hooks,
    closed: std.atomic.Value(bool),
    io: Io,
    alloc: std.mem.Allocator,

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
    /// `in_pool_count` is a hint. It is read under the lock and used without
    /// it, so another thread may have changed the real count by then:
    /// - `on_get`: count after removal — items remaining with this tag.
    /// - `on_put`: count before addition — items already stored with this tag.
    ///
    /// Hooks run outside the pool's mutex.
    ///
    /// Multiple threads (tasks) may call a hook at once — the pool does not serialize them.
    ///
    /// A hook that touches shared state must protect it itself.
    ///
    /// A hook must not call pool APIs or blocking operations. That is the
    /// contract, not a deadlock warning — the lock is not held while a hook
    /// runs.
    ///
    /// A hook that needs shared state locks it with `Io.Mutex` and
    /// `lockUncancelable`. A hook returns void, so it has no way to report a
    /// cancelled lock.
    pub const Hooks = struct {
        ctx: *anyopaque,
        tags: []const *const anyopaque,

        /// Called before an item is returned from the pool.
        ///
        /// `tag`: runtime type tag of the item to get.
        ///
        /// `in_pool_count`: number of available items with this tag before removal.
        ///
        /// `slot`: receives the selected item, or stays empty if no item is available.
        ///
        /// Returning an item whose tag is not the requested one is a programming
        /// error. Asserted in Debug and ReleaseSafe.
        on_get: *const fn (ctx: *anyopaque, tag: *const anyopaque, in_pool_count: usize, slot: *polynode.Slot) void,

        /// `slot`: keep, accept, or clear the one carried item.
        ///
        /// Return value: list of other items (usually parts of the former item)
        ///
        /// `null` or an empty list: nothing more to add.
        ///
        /// Non-empty list: each item is added the same way `slot`'s item is, same checks.
        ///
        /// This is how a composite item gives its parts back — the parts go into
        /// the list, the parent stays in `slot`.
        ///
        /// The hook gives back only valid, unlinked, correctly-tagged items. The
        /// pool does not check that they form a real composite, and does not
        /// distinguish a composite item from a simple one.
        on_put: *const fn (ctx: *anyopaque, in_pool_count: usize, slot: *polynode.Slot) ?polynode.ItemList,

        /// Called when the pool is closed.
        ///
        /// `list`: all items still remaining in the pool.
        ///
        /// The hook is responsible for processing or destroying every item.
        on_close: *const fn (
            ctx: *anyopaque,
            list: *polynode.ItemList,
        ) void,
    };

    /// Result of `get_wait`.
    ///
    /// `.item` contains a valid ItemHandle.
    ///
    /// The other variants describe why no item was returned.
    pub const Result = union(enum) {
        item: polynode.ItemHandle,
        closed: void,
        timeout: void,
        canceled: void,
        not_created: void,
    };

    /// Runtime type ID of Pool.
    pub const TAG: *const anyopaque = helper.TAG;

    /// Reach the PolyNode embedded in the pool.
    ///
    /// Use it to send a pool through a mailbox or another pool.
    pub inline fn toPoly(self: *Pool) *polynode.PolyNode {
        return helper.toPoly(self);
    }

    /// Cast back to the pool through its embedded PolyNode.
    ///
    /// Returns null if the node is not a pool.
    pub inline fn fromPoly(node: *polynode.PolyNode) ?*Pool {
        return helper.fromPoly(node);
    }

    /// Same as fromPoly().
    ///
    /// Panics on type mismatch.
    pub inline fn mustFromPoly(node: *polynode.PolyNode) *Pool {
        return helper.mustFromPoly(node);
    }

    /// True if the tag identifies a Pool.
    pub inline fn is_it_you(tag: *const anyopaque) bool {
        return helper.isIt(tag);
    }

    /// Registers hooks.
    ///
    /// Call once, right after `new`.
    ///
    /// Asserts the tag list is not empty, the pool is not closed, and no hooks
    /// are registered yet.
    pub fn init(self: *Pool, hooks: Hooks) !void {
        std.debug.assert(hooks.tags.len > 0);

        const io: Io = self.*.io;
        self.*.mutex.lockUncancelable(io);
        defer self.*.mutex.unlock(io);

        std.debug.assert(!self.*.closed.load(.monotonic));
        std.debug.assert(self.*.hooks == null);

        // Grow capacity before any modification — OOM fails cleanly here.
        const n: u32 = @intCast(hooks.tags.len);
        try self.*.lists.ensureTotalCapacity(self.*.alloc, n);
        try self.*.counts.ensureTotalCapacity(self.*.alloc, n);

        for (hooks.tags) |tag| {
            self.*.lists.putAssumeCapacity(tag, .{});
            self.*.counts.putAssumeCapacity(tag, 0);
        }

        self.*.hooks = hooks;
    }

    /// Acquires a handle without waiting. Calls `on_get`.
    ///
    /// On success, stores the handle in `slot.*`.
    ///
    /// Asserts the slot is empty, the hooks are registered, and the tag is one
    /// of the registered ones.
    pub fn get(self: *Pool, tag: *const anyopaque, mode: GetMode, slot: *polynode.Slot) GetError!void {
        std.debug.assert(slot.* == null);

        if (self.*.closed.load(.acquire)) return error.Closed;

        return switch (mode) {
            .available_or_new => _get_available_or_new(self, tag, slot),
            .new_only => _get_new_only(self, tag, slot),
            .available_only => _get_available_only(self, tag, slot),
        };
    }

    /// Acquires a handle, waiting until one is available.
    ///
    /// `timeout_ns == null`: waits forever.\
    /// `timeout_ns == 0`: returns `error.Timeout` immediately.
    ///
    /// Logically equivalent to `get(.available_only)` at that point, but returns\
    /// `error.Timeout` instead of `error.NotAvailable` — intentional
    ///
    /// does not call on_get hook
    ///
    /// `get_wait` always uses the timeout error set regardless of the timeout value.
    ///
    /// Asserts the slot is empty, the hooks are registered, and the tag is one
    /// of the registered ones.
    pub fn get_wait(self: *Pool, tag: *const anyopaque, slot: *polynode.Slot, timeout_ns: ?u64) (GetError || Io.Cancelable || error{Timeout})!void {
        std.debug.assert(slot.* == null);

        if (self.*.closed.load(.acquire)) return error.Closed;
        const io: Io = self.*.io;

        const timeout_val: Io.Timeout = if (timeout_ns) |ns|
            Io.Timeout{ .duration = .{ .raw = .{ .nanoseconds = @as(i96, @intCast(ns)) }, .clock = .real } }
        else
            .none;
        const deadline: Io.Timeout = timeout_val.toDeadline(io);

        self.*.mutex.lock(io) catch |err| return err;
        defer self.*.mutex.unlock(io);

        std.debug.assert(self.*.hooks != null);
        std.debug.assert(self.*.lists.contains(tag));

        while (true) {
            if (self.*.closed.load(.monotonic)) return error.Closed;

            if (self.*.lists.getPtr(tag)) |list| {
                if (list.popFirst()) |ih| {
                    self.*.counts.getPtr(tag).?.* -= 1;
                    slot.* = ih;
                    return;
                }
            }

            cond_timeout.condition_waitTimeout(&self.*.cond, io, &self.*.mutex, deadline) catch |err| switch (err) {
                error.Timeout => {
                    if (self.*.lists.getPtr(tag)) |l| if (!l.isEmpty()) self.*.cond.broadcast(io);
                    return error.Timeout;
                },
                error.Canceled => {
                    if (self.*.lists.getPtr(tag)) |l| if (!l.isEmpty()) self.*.cond.broadcast(io);
                    return err;
                },
            };
        }
    }

    /// Returns a handle to the pool.
    ///
    /// `slot.* == null`: returns immediately. No hook call, no assert on the
    /// tag.
    ///
    /// Open pool:
    /// - Calls `on_put`.
    /// - `slot.*` left non-null: the item is added to the pool.
    /// - `slot.*` cleared to null by the hook: the item is not added.
    /// - Any items in the list returned by the hook are added to the pool.
    ///
    /// Four outcomes the hook may pick. None of them is mandated:
    /// - deleted, nothing returned — hook frees the item and clears `slot.*`.
    /// - returned as-is — hook leaves the data alone, `slot.*` stays non-null.
    /// - returned after reset — hook resets the data first.
    /// - deleted, a different item returned — hook frees the original and puts
    ///   another item in `slot.*`.
    ///
    /// A non-null `slot.*` when the hook returns means exactly one thing: an
    /// item — the original or a replacement — is kept.
    ///
    /// Closed pool:
    /// - No-op.
    /// - `slot.*` is unchanged, so the caller still holds the item and must
    ///   release it.
    ///
    /// Asserts the item has no neighbours, when the slot is not empty.
    ///
    /// No sequence guarantee. Put three times, get three times, and the count,
    /// the identity and the order of what comes back are hook policy. The
    /// shape of the call sequence promises nothing.
    pub fn put(self: *Pool, slot: *polynode.Slot) void {
        if (slot.* == null) return;

        std.debug.assert(!polynode.is_linked(slot.*.?));

        const io: Io = self.*.io;
        self.*.mutex.lockUncancelable(io);

        if (self.*.closed.load(.monotonic)) {
            self.*.mutex.unlock(io);
            return; // handle stays with the caller
        }

        std.debug.assert(self.*.hooks != null);

        const handle: polynode.ItemHandle = slot.*.?;
        const tag: *const anyopaque = handle.*.tag;
        std.debug.assert(self.*.lists.contains(tag));

        const hooks: Hooks = self.*.hooks.?;
        const count: usize = self.*.counts.get(tag) orelse 0;

        self.*.mutex.unlock(io);
        var returned: ?polynode.ItemList = hooks.on_put(hooks.ctx, count, slot);
        self.*.mutex.lockUncancelable(io);

        if (!self.*.closed.load(.monotonic)) {
            var added = false;

            if (slot.* != null) {
                _add_returned_item(self, slot.*.?);
                slot.* = null;
                added = true;
            }

            if (returned) |*list| {
                while (list.popFirst()) |ih| {
                    _add_returned_item(self, ih);
                    added = true;
                }
            }

            if (added) self.*.cond.broadcast(io);
        }

        self.*.mutex.unlock(io);
    }

    /// Returns a batch of handles to the pool. Pops from the caller's list.
    ///
    /// Not atomic with `close()`.
    ///
    /// If the pool closes mid-batch:
    /// - items already transferred go to `on_close`;\
    /// - items not yet transferred stay in the caller's list.
    ///
    /// So check the list after the call. A non-empty list means the caller
    /// still holds those items and must release them.
    ///
    /// The restored order after a mid-batch close may differ from the original
    /// order.
    ///
    /// Asserts every item's tag is one of the registered ones, under one lock,
    /// before anything is transferred.
    pub fn put_all(self: *Pool, list: *polynode.ItemList) void {
        if (list.isEmpty()) return;

        const io: Io = self.*.io;

        // Validate all tags under one lock — no partial transfer on bad input.
        self.*.mutex.lockUncancelable(io);
        var it = list.iterator();
        while (it.next()) |ih| {
            std.debug.assert(self.*.lists.contains(ih.*.tag));
        }
        self.*.mutex.unlock(io);

        // Put each item individually.
        while (list.popFirst()) |ih| {
            var slot: polynode.Slot = ih;
            self.*.put(&slot);
            if (slot != null) {
                // Pool closed — item returned to caller — restore and stop.
                list.prepend(slot.?);
                break;
            }
        }
    }

    /// Collects all handles from every per-tag free-list,\
    /// calls `on_close` once with the full list,\
    /// then wakes any blocked `get_wait` callers.
    ///
    /// Safe to call more than once. Later calls collect nothing, and `on_close`
    /// runs once.
    pub fn close(self: *Pool) void {
        const io: Io = self.*.io;
        self.*.mutex.lockUncancelable(io);

        // Check+set closed inside the mutex — prevents destroy() racing a preempted close() caller.
        if (self.*.closed.load(.monotonic)) {
            self.*.mutex.unlock(io);
            return;
        }
        self.*.closed.store(true, .release);

        var collected: polynode.ItemList = .{};
        var it = self.*.lists.valueIterator();
        while (it.next()) |list| {
            collected.concat(list);
        }
        self.*.lists.clearRetainingCapacity();
        self.*.counts.clearRetainingCapacity();

        self.*.cond.broadcast(io);
        self.*.mutex.unlock(io);

        if (self.*.hooks) |hooks| {
            hooks.on_close(hooks.ctx, &collected);
        }
    }

    /// Wraps `getWaitResult` in an `Io.Future` for direct await or `Io.Group` use.
    ///
    /// No heap allocation — args are copied by the runtime.
    ///
    /// `error.ConcurrencyUnavailable` on single-threaded backends.
    pub fn get_wait_future(self: *Pool, tag: *const anyopaque, timeout_ns: ?u64) Io.ConcurrentError!Io.Future(Result) {
        return self.*.io.concurrent(getWaitResult, .{ self, tag, timeout_ns });
    }
};

/// Creates a pool.
pub fn new(io: Io, alloc: std.mem.Allocator) !*Pool {
    const p: *Pool = try alloc.create(Pool);
    errdefer alloc.destroy(p);
    p.* = .{
        .poly = .{ .tag = Pool.TAG },
        .mutex = .init,
        .cond = .init,
        .lists = .empty,
        .counts = .empty,
        .hooks = null,
        .closed = std.atomic.Value(bool).init(false),
        .io = io,
        .alloc = alloc,
    };
    return p;
}

/// True if the tag identifies a Pool.
pub inline fn is_it_you(tag: *const anyopaque) bool {
    return Pool.is_it_you(tag);
}

/// Frees the pool.
///
/// Must be closed first.\
/// Destroying an open pool is a programming error — panics.
pub fn destroy(p: *Pool, alloc: std.mem.Allocator) void {
    if (!p.*.closed.load(.acquire)) {
        @panic("pool.destroy: pool must be closed first");
    }
    p.*.lists.deinit(alloc);
    p.*.counts.deinit(alloc);
    alloc.destroy(p);
}

/// Maps every `get_wait` outcome to a `Pool.Result` variant. Blocking.
///
/// No error union.
///
/// Primary building block for `select.concurrent` and `io.concurrent`/`group.concurrent`.
///
/// On cancellation, returns `.canceled`.
///
/// The pool stays open — closing it is the caller's job.
pub fn getWaitResult(p: *Pool, tag: *const anyopaque, timeout_ns: ?u64) Pool.Result {
    var slot: polynode.Slot = null;
    p.*.get_wait(tag, &slot, timeout_ns) catch |err| return switch (err) {
        error.Closed => .closed,
        error.Timeout => .timeout,
        error.Canceled => .canceled,
        error.NotAvailable => .not_created,
        error.NotCreated => .not_created,
    };
    return .{ .item = slot.? };
}

// Add a single returned item to its per-tag free-list.
inline fn _add_returned_item(p: *Pool, item: polynode.ItemHandle) void {
    std.debug.assert(!polynode.is_linked(item));
    const tag: *const anyopaque = item.*.tag;
    std.debug.assert(p.*.lists.contains(tag));
    const list = p.*.lists.getPtr(tag).?;
    list.prepend(item);
    p.*.counts.getPtr(tag).?.* += 1;
}

inline fn _get_available_or_new(p: *Pool, tag: *const anyopaque, slot: *polynode.Slot) Pool.GetError!void {
    const io: Io = p.*.io;
    p.*.mutex.lockUncancelable(io);

    if (p.*.closed.load(.monotonic)) {
        p.*.mutex.unlock(io);
        return error.Closed;
    }
    std.debug.assert(p.*.hooks != null);
    std.debug.assert(p.*.lists.contains(tag));

    if (p.*.lists.getPtr(tag)) |list| {
        if (list.popFirst()) |ih| {
            p.*.counts.getPtr(tag).?.* -= 1;
            slot.* = ih;
        }
    }

    const hooks: Pool.Hooks = p.*.hooks.?;
    const count: usize = p.*.counts.get(tag) orelse 0;
    p.*.mutex.unlock(io);

    hooks.on_get(hooks.ctx, tag, count, slot);
    if (slot.*) |h| std.debug.assert(h.*.tag == tag);

    return if (slot.* != null) {} else error.NotCreated;
}

inline fn _get_new_only(p: *Pool, tag: *const anyopaque, slot: *polynode.Slot) Pool.GetError!void {
    const io: Io = p.*.io;
    p.*.mutex.lockUncancelable(io);

    if (p.*.closed.load(.monotonic)) {
        p.*.mutex.unlock(io);
        return error.Closed;
    }
    std.debug.assert(p.*.hooks != null);
    std.debug.assert(p.*.lists.contains(tag));

    const hooks: Pool.Hooks = p.*.hooks.?;
    const count: usize = p.*.counts.get(tag) orelse 0;
    p.*.mutex.unlock(io);

    hooks.on_get(hooks.ctx, tag, count, slot);
    if (slot.*) |h| std.debug.assert(h.*.tag == tag);

    return if (slot.* != null) {} else error.NotCreated;
}

inline fn _get_available_only(p: *Pool, tag: *const anyopaque, slot: *polynode.Slot) Pool.GetError!void {
    const io: Io = p.*.io;
    p.*.mutex.lockUncancelable(io);
    defer p.*.mutex.unlock(io);

    if (p.*.closed.load(.monotonic)) return error.Closed;
    std.debug.assert(p.*.hooks != null);
    std.debug.assert(p.*.lists.contains(tag));

    if (p.*.lists.getPtr(tag)) |list| {
        if (list.popFirst()) |ih| {
            p.*.counts.getPtr(tag).?.* -= 1;
            slot.* = ih;
            return;
        }
    }

    return error.NotAvailable;
}

const helper = polynode.PolyHelper(Pool);

const polynode = @import("polynode.zig");
const cond_timeout = @import("internal/cond_timeout.zig");
const std = @import("std");
const Io = std.Io;
