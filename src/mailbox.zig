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
const _doc_stub = void;

///
///
/// A mailbox, represented as an ItemHandle.
///
/// Can be sent, stored, and embedded like any other handle.
pub const MailboxHandle = polynode.ItemHandle;

/// Tag identity and control functions for the internal mailbox type.
pub const MailboxPolyHelper = polynode.PolyHelper(_Mailbox);

/// Creates a mailbox.
pub fn new(io: Io, alloc: std.mem.Allocator) !MailboxHandle {
    const mbx: *_Mailbox = try alloc.create(_Mailbox);
    errdefer alloc.destroy(mbx);
    mbx.* = .{
        .poly = .{ .tag = MailboxPolyHelper.TAG },
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
    return MailboxPolyHelper.toPoly(mbx);
}

/// True if the tag identifies a Mailbox.
pub inline fn is_it_you(tag: *const anyopaque) bool {
    return MailboxPolyHelper.isIt(tag);
}

/// Frees the mailbox.
///
/// Must be closed first.
///
/// Destroying an open mailbox is a programming error — panics.
pub fn destroy(mbh: MailboxHandle, alloc: std.mem.Allocator) void {
    const mbx: *_Mailbox = MailboxPolyHelper.mustFromPoly(mbh);
    if (!mbx.*.closed.load(.acquire)) {
        @panic("mailbox.destroy: mailbox must be closed first");
    }
    alloc.destroy(mbx);
}

/// If mailbox is closed - returns error.Closed
///
/// Otherwise:
/// - appends the handle to the tail of the queue
/// - 'slot.*` becomes null.
pub fn send(mbh: MailboxHandle, slot: *polynode.Slot) error{Closed}!void {
    std.debug.assert(slot.* != null);
    std.debug.assert(!polynode.is_linked(slot.*.?));

    const mbx: *_Mailbox = MailboxPolyHelper.mustFromPoly(mbh);

    if (mbx.*.closed.load(.acquire)) return error.Closed;
    const io: Io = mbx.*.io;

    mbx.*.mutex.lockUncancelable(io);
    defer mbx.*.mutex.unlock(io);

    if (mbx.*.closed.load(.monotonic)) return error.Closed;

    const handle: polynode.ItemHandle = slot.*.?;
    mbx.*.list.append(handle);
    mbx.*.len += 1;
    slot.* = null;

    mbx.*.cond.signal(io);
}

/// If mailbox is closed - returns error.Closed
///
/// Otherwise:
/// - inserts the handle after the last OOB handle
/// - ahead of all regular handles
/// - `slot.*` becomes null
pub fn send_oob(mbh: MailboxHandle, slot: *polynode.Slot) error{Closed}!void {
    std.debug.assert(slot.* != null);
    std.debug.assert(!polynode.is_linked(slot.*.?));

    const mbx: *_Mailbox = MailboxPolyHelper.mustFromPoly(mbh);

    if (mbx.*.closed.load(.acquire)) return error.Closed;
    const io: Io = mbx.*.io;

    mbx.*.mutex.lockUncancelable(io);
    defer mbx.*.mutex.unlock(io);

    if (mbx.*.closed.load(.monotonic)) return error.Closed;

    const handle: polynode.ItemHandle = slot.*.?;

    if (mbx.*.oob_last) |last| {
        mbx.*.list.insertAfter(last, handle);
    } else {
        mbx.*.list.prepend(handle);
    }
    mbx.*.oob_last = handle;
    mbx.*.oob_count += 1;
    mbx.*.len += 1;
    slot.* = null;

    mbx.*.cond.signal(io);
}

/// If mailbox is closed - returns error.Closed
///
/// Otherwise:
/// - waits until a handle is available
/// - stories it to slot.*
/// - OOB handles have priority
///
/// - `timeout_ns == null`: waits forever.
/// - `timeout_ns == 0`: returns `error.Timeout` immediately for empty mailbox
///
/// receive breaks on
/// - timeout
/// - cancel
/// - `wakeUpAll()
///
/// For the break - `slot.*` stays null.
///
/// Cancel does not close mailbox.
pub fn receive(mbh: MailboxHandle, slot: *polynode.Slot, timeout_ns: ?u64) (error{ Closed, Timeout, Wakeup } || Io.Cancelable)!void {
    std.debug.assert(slot.* == null);

    const mbx: *_Mailbox = MailboxPolyHelper.mustFromPoly(mbh);

    if (mbx.*.closed.load(.acquire)) return error.Closed;
    const io: Io = mbx.*.io;

    const timeout_val: Io.Timeout = if (timeout_ns) |ns|
        Io.Timeout{ .duration = .{ .raw = .{ .nanoseconds = @as(i96, @intCast(ns)) }, .clock = .real } }
    else
        .none;

    const deadline: Io.Timeout = timeout_val.toDeadline(io);

    mbx.*.mutex.lock(io) catch |err| return err;
    defer mbx.*.mutex.unlock(io);

    if (mbx.*.closed.load(.monotonic)) return error.Closed;

    const my_epoch: u64 = mbx.*.wake_epoch;

    while (mbx.*.len == 0 and mbx.*.wake_epoch == my_epoch) {
        if (mbx.*.closed.load(.monotonic)) return error.Closed;
        cond_timeout.condition_waitTimeout(&mbx.*.cond, io, &mbx.*.mutex, deadline) catch |err| switch (err) {
            error.Timeout => {
                if (mbx.*.len > 0) mbx.*.cond.signal(io);
                return error.Timeout;
            },
            error.Canceled => {
                if (mbx.*.len > 0) mbx.*.cond.signal(io);
                return err;
            },
        };
    }

    if (mbx.*.len == 0) return error.Wakeup;

    const ih: polynode.ItemHandle = mbx.*.list.popFirst().?;
    mbx.*.len -= 1;
    if (mbx.*.oob_count > 0) {
        mbx.*.oob_count -= 1;
        if (mbx.*.oob_count == 0) mbx.*.oob_last = null;
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
pub fn try_receive(mbh: MailboxHandle, slot: *polynode.Slot) error{Closed}!bool {
    std.debug.assert(slot.* == null);

    const mbx: *_Mailbox = MailboxPolyHelper.mustFromPoly(mbh);

    if (mbx.*.closed.load(.acquire)) return error.Closed;
    const io: Io = mbx.*.io;

    mbx.*.mutex.lockUncancelable(io);
    defer mbx.*.mutex.unlock(io);

    if (mbx.*.closed.load(.monotonic)) return error.Closed;

    if (mbx.*.len == 0) return false;

    const ih: polynode.ItemHandle = mbx.*.list.popFirst().?;
    mbx.*.len -= 1;
    if (mbx.*.oob_count > 0) {
        mbx.*.oob_count -= 1;
        if (mbx.*.oob_count == 0) mbx.*.oob_last = null;
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
pub fn receive_batch(mbh: MailboxHandle) error{Closed}!polynode.ItemList {
    const mbx: *_Mailbox = MailboxPolyHelper.mustFromPoly(mbh);

    if (mbx.*.closed.load(.acquire)) return error.Closed;
    const io: Io = mbx.*.io;

    mbx.*.mutex.lockUncancelable(io);
    defer mbx.*.mutex.unlock(io);

    if (mbx.*.closed.load(.monotonic)) return error.Closed;

    const result: polynode.ItemList = mbx.*.list;
    mbx.*.list = .{};
    mbx.*.len = 0;
    mbx.*.oob_count = 0;
    mbx.*.oob_last = null;
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
pub fn close(mbh: MailboxHandle) polynode.ItemList {
    const mbx: *_Mailbox = MailboxPolyHelper.mustFromPoly(mbh);
    const io: Io = mbx.*.io;
    mbx.*.mutex.lockUncancelable(io);

    // Check+set closed inside the mutex — prevents destroy() racing a preempted close() caller.
    if (mbx.*.closed.load(.monotonic)) {
        mbx.*.mutex.unlock(io);
        return .{};
    }
    mbx.*.closed.store(true, .release);

    const result: polynode.ItemList = mbx.*.list;
    mbx.*.list = .{};
    mbx.*.len = 0;
    mbx.*.oob_count = 0;
    mbx.*.oob_last = null;

    mbx.*.cond.broadcast(io);
    mbx.*.mutex.unlock(io);

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
pub fn wakeUpAll(mbh: MailboxHandle) error{Closed}!void {
    const mbx: *_Mailbox = MailboxPolyHelper.mustFromPoly(mbh);

    if (mbx.*.closed.load(.acquire)) return error.Closed;
    const io: Io = mbx.*.io;

    mbx.*.mutex.lockUncancelable(io);
    defer mbx.*.mutex.unlock(io);

    if (mbx.*.closed.load(.monotonic)) return error.Closed;

    mbx.*.wake_epoch += 1;
    mbx.*.cond.broadcast(io);
}

/// Returned by `receive_future` when the Io backend has no concurrency.
pub const ConcurrentError = error{ConcurrencyUnavailable};

/// 'Packed' result of receive attempt
pub const ReceiveResult = union(enum) {
    item: polynode.ItemHandle,
    closed: void,
    timeout: void,
    canceled: void,
    wakeup: void,
};

/// Wraps `receiveResult`
/// - in an `Io.Future`
/// - for direct await
/// - or `Io.Group` use.
pub fn receive_future(mbh: MailboxHandle, timeout_ns: ?u64) ConcurrentError!Io.Future(ReceiveResult) {
    const mbx: *_Mailbox = MailboxPolyHelper.mustFromPoly(mbh);
    return mbx.*.io.concurrent(receiveResult, .{ mbh, timeout_ns });
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
pub fn receiveResult(mbh: MailboxHandle, timeout_ns: ?u64) ReceiveResult {
    var slot: polynode.Slot = null;
    receive(mbh, &slot, timeout_ns) catch |err| return switch (err) {
        error.Closed => .closed,
        error.Timeout => .timeout,
        error.Canceled => .canceled,
        error.Wakeup => .wakeup,
    };
    return .{ .item = slot.? };
}

const _Mailbox = struct {
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
};

const polynode = @import("polynode.zig");
const cond_timeout = @import("internal/cond_timeout.zig");
const std = @import("std");
const Io = std.Io;
