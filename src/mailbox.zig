// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Communication channel for ItemHandles.
//!
//! A mailbox:
//! - sends/receives ItemHandles
//! - supports waiting and non-waiting receive
//! - keeps handles until they are received
//! - is itself a PolyNode
//!
//!  Thread(task) safe
//!  - Multi-Producer/Multi-Consumer (MPMC)
//!  - Multi-Sender/Multi-Receiver
//!  - Fan-In/Fan-Out
//!
//! The mailbox keeps items. It never touches them. On the ok path it
//! "transfers" the item from the sender to the receiver.
//!
//! - No inspection.
//! - No copy.
//! - No free.
//!
//! Examples:
//! https://g41797.github.io/matryoshka-tk/examples/mailbox/
//!
//! The three together:
//! https://g41797.github.io/matryoshka-tk/examples/flow/
//!
const _doc_stub = void;

/// A mailbox - tool for Items exchanging
///
/// A mailbox is also a PolyNode.
///
/// Use `toPoly`/`fromPoly` for using it as any other item.
///
/// The fields below are internal.\
/// Don't touch.
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

    /// Result of a receive attempt, packed into a union.
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

    /// Sends an item. It goes behind every item already queued.
    ///
    /// If mailbox is closed - returns error.Closed
    ///
    /// Otherwise:
    /// - appends the handle to the tail of the queue
    /// - `slot.*` becomes null.
    ///
    /// On `error.Closed` the slot is unchanged.\
    /// The sender still has the item.
    ///
    /// Asserts the slot is not empty, and that the item has no neighbours.
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

    /// Sends an item out of band, ahead of all regular items.
    ///
    /// If mailbox is closed - returns error.Closed
    ///
    /// Otherwise:
    /// - inserts the handle after the last OOB handle
    /// - ahead of all regular handles
    /// - `slot.*` becomes null
    ///
    /// On `error.Closed` the slot is unchanged.\
    /// The sender still has the item.
    ///
    /// Asserts the slot is not empty, and that the item has no neighbours.
    ///
    /// FIFO among OOB handles. Every OOB handle sits ahead of every regular
    /// one.
    ///
    /// ```text
    /// send(R1), send(R2):   [R1, R2]                 oob=0
    /// send_oob(O1):         [O1, R1, R2]             oob=1
    /// send(R3):             [O1, R1, R2, R3]         oob=1
    /// send_oob(O2):         [O1, O2, R1, R2, R3]     oob=2
    /// receive -> O1:        [O2, R1, R2, R3]         oob=1
    /// receive -> O2:        [R1, R2, R3]             oob=0
    /// ```
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

    /// Receives an item, waiting until one is available.
    ///
    /// If mailbox is closed - returns error.Closed
    ///
    /// Otherwise:
    /// - waits until a handle is available
    /// - stores it to `slot.*`
    /// - OOB handles have priority
    ///
    /// - `timeout_ns == null`: waits forever.
    /// - `timeout_ns == 0`: returns `error.Timeout` immediately for an empty
    ///   mailbox. Same reach as try_receive. Reported as an error instead of
    ///   false.
    ///
    /// receive breaks on
    /// - timeout
    /// - cancel
    /// - `wakeUpAll()`
    ///
    /// For the break - `slot.*` stays null.
    ///
    /// That includes `error.Wakeup` from a wakeUpAll() while this receiver
    /// was blocked.
    ///
    /// Cancel does not close mailbox.
    ///
    /// Several receivers compete for each handle. One gets it.
    ///
    /// Order among them is up to the Io runtime. It is not FIFO.
    ///
    /// Asserts the slot is empty.
    pub fn receive(self: *Mbox, slot: *polynode.Slot, timeout_ns: ?u64) (error{ Closed, Timeout, Wakeup } || Io.Cancelable)!void {
        std.debug.assert(slot.* == null);

        if (self.*.closed.load(.acquire)) return error.Closed;
        const io: Io = self.*.io;

        const timeout_val: Io.Timeout = if (timeout_ns) |ns|
            Io.Timeout{ .duration = .{ .raw = .{ .nanoseconds = @as(i96, @intCast(ns)) }, .clock = .real } }
        else
            .none;

        // Anchor the deadline once, before the retry loop. condition_waitTimeout
        // calls toDeadline itself, but converting a duration inside the loop
        // would restart the timeout on every spurious wakeup.
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

    /// Receives an item if one is available now. Never waits.
    ///
    /// If mailbox is closed - returns error.Closed
    ///
    /// Otherwise:
    /// - attempts to receive a handle, without waiting.
    /// - sends the handle into the slot on success — `slot.*` becomes non-null.
    ///
    /// Returns
    /// - true if a handle was received
    /// - false if the mailbox was empty
    ///
    /// Asserts the slot is empty.
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

    /// Takes every stored item at once, as a list.
    ///
    /// If mailbox is closed - returns error.Closed
    ///
    /// Otherwise:
    /// - returns all stored handles as list
    /// - empties mailbox
    ///
    /// Returns an empty list if the mailbox is empty.
    ///
    /// An empty mailbox is not an error. This never waits.
    ///
    /// The caller has every item in the list.\
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
    /// The caller has every item in the returned list.\
    /// Release them — free them, or put them back into a pool.
    ///
    /// Releasing is the caller's job. What those items are — heap items to
    /// free, pool items to put back — is knowledge the mailbox does not have
    /// and never had.
    ///
    /// Run the release unconditionally. An empty list costs nothing.
    /// No call site has to know whether the mailbox was emptied first.
    ///
    /// So the release loop is always safe to run:
    ///
    /// - on a mailbox that still has items
    /// - on one already empty
    /// - on one closed twice
    ///
    /// ```zig
    /// var rem: polynode.ItemList = mbx.close();
    /// // release every item in `rem`
    /// ```
    ///
    /// Never write `_ = mbx.close()`. It drops items the mailbox gave back.
    ///
    /// Those items keep their list links, so send rejects them afterwards.
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

    /// Wakes every blocked receiver.
    ///
    /// If mailbox is closed - returns error.Closed
    ///
    /// Otherwise:
    /// - wakes receivers currently waiting in `receive()`
    /// - as result - waiting receivers return `error.Wakeup`.
    ///
    /// Receivers that start waiting later are not affected. The effect does
    /// not persist past the call.
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

    /// Wraps `receiveResult` in an `Io.Future` for direct await or `Io.Group` use.
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
/// Destroying an open mailbox is a programming error — panics. Closedness is
/// a precondition here, and nowhere else: every other method returns
/// error.Closed and stays a valid object.
pub fn destroy(mbx: *Mbox, alloc: std.mem.Allocator) void {
    if (!mbx.*.closed.load(.acquire)) {
        @panic("mailbox.destroy: mailbox must be closed first");
    }
    alloc.destroy(mbx);
}

/// Packs every `receive()` outcome into a `Mbox.Result`, returned via Io.Queue.
///
/// Waiting.
///
/// Primary building block for
/// - `select.concurrent`
/// - `io.concurrent`
/// - `group.concurrent`.
///
/// The mailbox does not change its state.
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
