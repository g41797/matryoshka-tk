// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Request-response.
//!
//! - Main sends an Event (code=42) to the worker's request mailbox.
//! - Worker adds 1000 to the code, sends it to the response mailbox.
//! - Main receives the response, verifies the value.
//!
//!
//! ```
//!  main ──Event(code=42)──► req_mbx ──► worker
//!                                          │ code += 1000
//!                                          ▼
//!  main ◄──Event(code=1042)── resp_mbx ◄── worker
//! ```
//!

pub fn request_response(allocator: std.mem.Allocator, io: std.Io) !void {
    var req_mbx_slot: Slot = null;
    try mailbox.new(io, allocator, &req_mbx_slot);
    const req_mbx: *Mbox = Mbox.moveFromSlot(&req_mbx_slot).?;
    defer mailbox.destroy(req_mbx, allocator);

    var resp_mbx_slot: Slot = null;
    try mailbox.new(io, allocator, &resp_mbx_slot);
    const resp_mbx: *Mbox = Mbox.moveFromSlot(&resp_mbx_slot).?;
    defer mailbox.destroy(resp_mbx, allocator);

    var ctx: WorkerCtx = .{ .req_mbx = req_mbx, .resp_mbx = resp_mbx, .alloc = allocator };
    var fut = try io.concurrent(workerFn, .{&ctx});

    {
        var slot: Slot = null;
        defer items.freeSlot(&slot, allocator);
        try items.Event.EventPolyHelper.create(allocator, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = 42;
        try req_mbx.send(&slot);
    }

    {
        var slot: Slot = null;
        defer items.freeSlot(&slot, allocator);
        try resp_mbx.receive(&slot, 5_000_000_000);
        const resp: *items.Event = items.Event.EventPolyHelper.fromSlot(&slot) orelse return error.WrongTag;
        std.log.info("request_response: response code={d}", .{resp.*.code});
        try helpers.expect(error.RequestResponseFailed, resp.*.code == 1042, "wrong response code");
    }

    var rem_req: polynode.ItemList = req_mbx.close();
    items.freeList(&rem_req, allocator);
    fut.await(io);

    var rem_resp: polynode.ItemList = resp_mbx.close();
    items.freeList(&rem_resp, allocator);
}

const WorkerCtx = struct {
    req_mbx: *Mbox,
    resp_mbx: *Mbox,
    alloc: std.mem.Allocator,
};

fn workerFn(ctx: *WorkerCtx) void {
    while (true) {
        var slot: Slot = null;
        defer items.freeSlot(&slot, ctx.alloc);
        ctx.req_mbx.receive(&slot, null) catch return;
        const ev: *items.Event = items.Event.EventPolyHelper.fromSlot(&slot) orelse continue;
        std.log.debug("worker: request code={d}", .{ev.*.code});
        ev.*.code += 1000;
        ctx.resp_mbx.send(&slot) catch {};
    }
}

const items = @import("../items/items.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const polynode = matryoshka.polynode;
const mailbox = matryoshka.mailbox;
const Mbox = matryoshka.Mbox;
const Slot = polynode.Slot;
