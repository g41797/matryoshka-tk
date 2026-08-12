// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Communication channel for ItemHandles.
//!
//! A mailbox:
//! - sends/receives ItemHandles
//! - supports waiting and non-waiting receive
//! - holds handles until they are received
//! - is itself a PolyNode
//!
//!  Thread(task) safe
//!  - Multi-Producer/Multi-Consumer (MPMC)
//!  - Multi-Sender/Multi-Receiver
//!  - Fan-In/Fan-Out
//!
//! # The mailbox holds. It never touches.
//!
//! On the ok path it "transfers" the item from the sender to the receiver.
//!
//! - No inspection.
//! - No copy.
//! - No free.
//!
//! # It does not care whether you closed it — except `destroy`
//!
//! Every other method returns `error.Closed` and stays a valid object.
//! Only `destroy` makes closedness a precondition. It panics on an open
//! mailbox.
//!
//! # Closing and releasing is the caller's job
//!
//! `close` hands the list back and is done. What those items are — heap
//! items to free, pool items to put back — is knowledge the mailbox does
//! not have and never had.
//!
//! # Release unconditionally
//!
//! `close` can be called more than once and returns an empty list after the first.
//!
//! So the release loop is always safe to run:
//!
//! - on a mailbox that still holds items
//! - on one already empty
//! - on one closed twice
//!
//! There is no state in which running it is wrong. Never write
//! `_ = mbx.close()`.
//!
const _doc_stub = void;

///
///
/// A mailbox.
///
/// Application code holds `*Mbox` and calls methods on it.
///
/// A mailbox is also a PolyNode.
///
/// Use `toPoly`/`fromPoly` for using it as any other item.
pub const Mbox = struct {
    const no_create_destroy = void{};

    poly: polynode.PolyNode,
    mutex: Io.Mutex,
    cond: Io.Condition,
    list: polynode.ItemList,
    len: usize,
    closed: std.atomic.Value(bool),
    oob_count: usize,
    oob_last: ?polynode.ItemHandle,
    wake_epoch: u64,
    io: Io,
    alloc: std.mem.Allocator,

    /// 'Packed' result of receive attempt
    pub const Result = union(enum) {
        item: polynode.ItemHandle,
        closed: void,
        timeout: void,
        canceled: void,
        wakeup: void,
    };

    /// Runtime type ID of Mbox.
    pub const TAG: *const anyopaque = helper.TAG;

    /// Reach the PolyNode embedded in the mailbox.
    ///
    /// Use it to send a mailbox through another mailbox or pool.
    pub inline fn toPoly(self: *Mbox) *polynode.PolyNode {
        return helper.toPoly(self);
    }

    /// Cast back to the mailbox through its embedded PolyNode.
    ///
    /// Returns null if the node is not a mailbox.
    pub inline fn fromPoly(node: *polynode.PolyNode) ?*Mbox {
        return helper.fromPoly(node);
    }

    /// Same as fromPoly().
    ///
    /// Panics on type mismatch.
    pub inline fn mustFromPoly(node: *polynode.PolyNode) *Mbox {
        return helper.mustFromPoly(node);
    }

    /// True if the tag identifies a Mbox.
    pub inline fn is_it_you(tag: *const anyopaque) bool {
        return helper.isIt(tag);
    }

    /// If mailbox is closed - returns error.Closed
    ///
    /// Otherwise:
    /// - appends the handle to the tail of the queue
    /// - `slot.*` becomes null.
    ///
    /// On `error.Closed` the slot is unchanged.\
    /// The sender still holds the item.
    pub fn send(self: *Mbox, slot: *polynode.Slot) error{Closed}!void {
        std.debug.assert(slot.* != null);
        std.debug.assert(!polynode.is_linked(slot.*.?));

        if (self.*.closed.load(.acquire)) return error.Closed;
        const io: Io = self.*.io;

        self.*.mutex.lockUncancelable(io);
        defer self.*.mutex.unlock(io);

        if (self.*.closed.load(.monotonic)) return error.Closed;

        const handle: polynode.ItemHandle = slot.*.?;
        self.*.list.append(handle);
        self.*.len += 1;
        slot.* = null;

        self.*.cond.signal(io);
    }

    /// If mailbox is closed - returns error.Closed
    ///
    /// Otherwise:
    /// - inserts the handle after the last OOB handle
    /// - ahead of all regular handles
    /// - `slot.*` becomes null
    ///
    /// On `error.Closed` the slot is unchanged.\
    /// The sender still holds the item.
    pub fn send_oob(self: *Mbox, slot: *polynode.Slot) error{Closed}!void {
        std.debug.assert(slot.* != null);
        std.debug.assert(!polynode.is_linked(slot.*.?));

        if (self.*.closed.load(.acquire)) return error.Closed;
        const io: Io = self.*.io;

        self.*.mutex.lockUncancelable(io);
        defer self.*.mutex.unlock(io);

        if (self.*.closed.load(.monotonic)) return error.Closed;

        const handle: polynode.ItemHandle = slot.*.?;

        if (self.*.oob_last) |last| {
            self.*.list.insertAfter(last, handle);
        } else {
            self.*.list.prepend(handle);
        }
        self.*.oob_last = handle;
        self.*.oob_count += 1;
        self.*.len += 1;
        slot.* = null;

        self.*.cond.signal(io);
    }

    /// If mailbox is closed - returns error.Closed
    ///
    /// Otherwise:
    /// - waits until a handle is available
    /// - stores it to `slot.*`
    /// - OOB handles have priority
    ///
    /// - `timeout_ns == null`: waits forever.
    /// - `timeout_ns == 0`: returns `error.Timeout` immediately for empty mailbox
    ///
    /// receive breaks on
    /// - timeout
    /// - cancel
    /// - `wakeUpAll()`
    ///
    /// For the break - `slot.*` stays null.
    ///
    /// Cancel does not close mailbox.
    pub fn receive(self: *Mbox, slot: *polynode.Slot, timeout_ns: ?u64) (error{ Closed, Timeout, Wakeup } || Io.Cancelable)!void {
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

        if (self.*.closed.load(.monotonic)) return error.Closed;

        const my_epoch: u64 = self.*.wake_epoch;

        while (self.*.len == 0 and self.*.wake_epoch == my_epoch) {
            if (self.*.closed.load(.monotonic)) return error.Closed;
            cond_timeout.condition_waitTimeout(&self.*.cond, io, &self.*.mutex, deadline) catch |err| switch (err) {
                error.Timeout => {
                    if (self.*.len > 0) self.*.cond.signal(io);
                    return error.Timeout;
                },
                error.Canceled => {
                    if (self.*.len > 0) self.*.cond.signal(io);
                    return err;
                },
            };
        }

        if (self.*.len == 0) return error.Wakeup;

        const ih: polynode.ItemHandle = self.*.list.popFirst().?;
        self.*.len -= 1;
        if (self.*.oob_count > 0) {
            self.*.oob_count -= 1;
            if (self.*.oob_count == 0) self.*.oob_last = null;
        }

        slot.* = ih;
    }

    /// If mailbox is closed - returns error.Closed
    ///
    /// Otherwise:
    /// - attempts to receive a handle, without waiting.
    /// - sends the handle into the slot on success — `slot.*` becomes non-null.
    ///
    /// Returns
    /// - true if a handle was received
    /// - false if the mailbox was empty
    pub fn try_receive(self: *Mbox, slot: *polynode.Slot) error{Closed}!bool {
        std.debug.assert(slot.* == null);

        if (self.*.closed.load(.acquire)) return error.Closed;
        const io: Io = self.*.io;

        self.*.mutex.lockUncancelable(io);
        defer self.*.mutex.unlock(io);

        if (self.*.closed.load(.monotonic)) return error.Closed;

        if (self.*.len == 0) return false;

        const ih: polynode.ItemHandle = self.*.list.popFirst().?;
        self.*.len -= 1;
        if (self.*.oob_count > 0) {
            self.*.oob_count -= 1;
            if (self.*.oob_count == 0) self.*.oob_last = null;
        }

        slot.* = ih;
        return true;
    }

    /// If mailbox is closed - returns error.Closed
    ///
    /// Otherwise:
    /// - returns all stored handles as list
    /// - empties mailbox
    ///
    /// Returns an empty list if the mailbox is empty.
    ///
    /// The caller holds every item in the list.\
    /// Release them — free them, or put them back into a pool.
    pub fn receive_batch(self: *Mbox) error{Closed}!polynode.ItemList {
        if (self.*.closed.load(.acquire)) return error.Closed;
        const io: Io = self.*.io;

        self.*.mutex.lockUncancelable(io);
        defer self.*.mutex.unlock(io);

        if (self.*.closed.load(.monotonic)) return error.Closed;

        const result: polynode.ItemList = self.*.list;
        self.*.list = .{};
        self.*.len = 0;
        self.*.oob_count = 0;
        self.*.oob_last = null;
        return result;
    }

    /// Closes the mailbox.
    ///
    /// Returns all handles as a list.
    ///
    /// Wakes waited receivers.
    ///
    /// Safe to call more than once.\
    /// Later calls return an empty list.
    ///
    /// The caller holds every item in the returned list.\
    /// Release them — free them, or put them back into a pool.
    ///
    /// Run the release unconditionally. An empty list costs nothing, so no
    /// call site has to know whether the mailbox was emptied first.
    ///
    /// ```zig
    /// var rem: polynode.ItemList = mbx.close();
    /// // release every item in `rem`
    /// ```
    ///
    /// Never write `_ = mbx.close()` — it drops items the mailbox handed
    /// back.
    pub fn close(self: *Mbox) polynode.ItemList {
        const io: Io = self.*.io;
        self.*.mutex.lockUncancelable(io);

        // Check+set closed inside the mutex — prevents destroy() racing a preempted close() caller.
        if (self.*.closed.load(.monotonic)) {
            self.*.mutex.unlock(io);
            return .{};
        }
        self.*.closed.store(true, .release);

        const result: polynode.ItemList = self.*.list;
        self.*.list = .{};
        self.*.len = 0;
        self.*.oob_count = 0;
        self.*.oob_last = null;

        self.*.cond.broadcast(io);
        self.*.mutex.unlock(io);

        return result;
    }

    /// If mailbox is closed - returns error.Closed
    ///
    /// Otherwise:
    /// - wakes receivers currently waiting in `receive()`
    /// - as result - waiting receivers return `error.Wakeup`.
    ///
    /// Receivers that start waiting later are not affected.
    ///
    /// The mailbox remains open.
    ///
    /// Don't confuse with Cancel
    pub fn wakeUpAll(self: *Mbox) error{Closed}!void {
        if (self.*.closed.load(.acquire)) return error.Closed;
        const io: Io = self.*.io;

        self.*.mutex.lockUncancelable(io);
        defer self.*.mutex.unlock(io);

        if (self.*.closed.load(.monotonic)) return error.Closed;

        self.*.wake_epoch += 1;
        self.*.cond.broadcast(io);
    }

    /// Wraps `receiveResult`
    /// - in an `Io.Future`
    /// - for direct await
    /// - or `Io.Group` use.
    pub fn receive_future(self: *Mbox, timeout_ns: ?u64) Io.ConcurrentError!Io.Future(Result) {
        return self.*.io.concurrent(receiveResult, .{ self, timeout_ns });
    }
};

/// Creates a mailbox.
pub fn new(io: Io, alloc: std.mem.Allocator) !*Mbox {
    const mbx: *Mbox = try alloc.create(Mbox);
    errdefer alloc.destroy(mbx);
    mbx.* = .{
        .poly = .{ .tag = Mbox.TAG },
        .mutex = .init,
        .cond = .init,
        .list = .{},
        .len = 0,
        .closed = std.atomic.Value(bool).init(false),
        .oob_count = 0,
        .oob_last = null,
        .wake_epoch = 0,
        .io = io,
        .alloc = alloc,
    };
    return mbx;
}

/// True if the tag identifies a Mbox.
pub inline fn is_it_you(tag: *const anyopaque) bool {
    return Mbox.is_it_you(tag);
}

/// Frees the mailbox.
///
/// Must be closed first.
///
/// Destroying an open mailbox is a programming error — panics.
pub fn destroy(mbx: *Mbox, alloc: std.mem.Allocator) void {
    if (!mbx.*.closed.load(.acquire)) {
        @panic("mailbox.destroy: mailbox must be closed first");
    }
    alloc.destroy(mbx);
}

/// Packs 'receive()` results to union,
/// returned via Io.Queue
///
///  Waiting.
///
///
/// Primary building block for
/// - `select.concurrent`
/// - `io.concurrent`
/// - `group.concurrent`.
///
///
/// The mailbox does not change it's state.
pub fn receiveResult(mbx: *Mbox, timeout_ns: ?u64) Mbox.Result {
    var slot: polynode.Slot = null;
    mbx.*.receive(&slot, timeout_ns) catch |err| return switch (err) {
        error.Closed => .closed,
        error.Timeout => .timeout,
        error.Canceled => .canceled,
        error.Wakeup => .wakeup,
    };
    return .{ .item = slot.? };
}

const helper = polynode.PolyHelper(Mbox);

const polynode = @import("polynode.zig");
const cond_timeout = @import("internal/cond_timeout.zig");
const std = @import("std");
const Io = std.Io;
