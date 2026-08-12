// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! When to add Mailbox.
//!
//! - Same pool + Select setup as scenario 60, plus multiple independent mock clients.
//! - Clients are unknown and independent — fan-in requires a mailbox as a third source.
//! - Shows the transition point: mailbox-less works until senders multiply and diverge.
//!
//! Transfers (transition: mailbox-less → mailbox needed):
//!
//! ```
//!  pool (seeded)       mock clients (io.concurrent ×N_CLIENTS → mbx.send)
//!  │ getWaitResult      │ receiveResult
//!  └────────┬───────────┘
//!           ▼
//!  Select(MasterEvent)
//!  │
//!  .pool_ev .item ──► process ──► pl.put ──► pool (re-spawn)
//!  .inbox .item   ──► freeSlot               (re-spawn receiveResult)
//!  │
//!  clients finish → mbx.close → inbox returns .closed
//!  sel.cancelDiscard ──► pl.close ──► on_close ──► freed
//! ```
//!
//!  Transition: when senders are multiple and independent, fan-in via mailbox
//!  becomes necessary. Mailbox is the third event source in Select.
//!

pub fn when_to_add_mailbox(allocator: std.mem.Allocator, io: std.Io) !void {
    const pl: *Pool = try pool.new(io, allocator);
    var pool_ctx: hooks.AlwaysCreateHooks = .{ .alloc = allocator };
    const tags = [_]*const anyopaque{items.Event.EventPolyHelper.TAG};
    try pl.init(pool_ctx.poolHooks(&tags));
    defer {
        pl.close();
        pool.destroy(pl, allocator);
    }

    const mbx: *Mbox = try mailbox.new(io, allocator);
    defer mailbox.destroy(mbx, allocator);

    try seedPool(pl);

    var ctxs: [N_CLIENTS]ClientCtx = undefined;
    var futs: [N_CLIENTS]Io.Future(anyerror!void) = undefined;
    var ctx: Ctx = .{ .mbx = mbx, .alloc = allocator, .io = io };
    try ctx.spawnClients(&ctxs, &futs);

    var buf: [8]MasterEvent = undefined;
    var sel: std.Io.Select(MasterEvent) = std.Io.Select(MasterEvent).init(io, &buf);
    try ctx.setupSelect(pl, &sel);
    try ctx.runEventLoop(pl, &sel);

    ctx.awaitClients(&futs);
    ctx.closeMailboxAfterClients();

    try helpers.expect(error.MailboxTransitionFailed, ctx.pool_done == N_POOL_ITEMS, "pool items mismatch");
    try helpers.expect(error.MailboxTransitionFailed, ctx.inbox_done == N_CLIENTS, "client items mismatch");
    std.log.info("done: {d} clients → mailbox fan-in; {d} pool items — mailbox needed for independent senders", .{ ctx.inbox_done, ctx.pool_done });
}

const NET_DELAY_NS: i96 = 10_000_000; // 10 ms per client
const N_CLIENTS: usize = 3;
const N_POOL_ITEMS: usize = 2;

const MasterEvent = union(enum) {
    pool_ev: Pool.Result,
    inbox: Mbox.Result,
};

const ClientCtx = struct {
    mbx: *Mbox,
    alloc: std.mem.Allocator,
    id: usize,
    delay: std.Io.Timeout,
};

fn clientFn(ctx: *ClientCtx, io: std.Io) anyerror!void {
    std.Io.Timeout.sleep(ctx.delay, io) catch {};
    var slot: Slot = null;
    defer items.Event.EventPolyHelper.destroy(ctx.alloc, &slot);
    try items.Event.EventPolyHelper.create(ctx.alloc, &slot);
    items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(ctx.id);
    std.log.info("client {d}: sending to mailbox", .{ctx.id});
    ctx.mbx.send(&slot) catch {};
}

const Ctx = struct {
    mbx: *Mbox,
    alloc: std.mem.Allocator,
    io: std.Io,
    pool_done: usize = 0,
    inbox_done: usize = 0,

    fn spawnClients(self: *Ctx, ctxs: *[N_CLIENTS]ClientCtx, futs: *[N_CLIENTS]Io.Future(anyerror!void)) !void {
        const client_delay: std.Io.Timeout = .{
            .duration = .{ .raw = .{ .nanoseconds = NET_DELAY_NS }, .clock = .real },
        };
        for (0..N_CLIENTS) |i| {
            ctxs[i] = .{ .mbx = self.mbx, .alloc = self.alloc, .id = i + 1, .delay = client_delay };
            futs[i] = try self.io.concurrent(clientFn, .{ &ctxs[i], self.io });
        }
    }

    fn awaitClients(self: *Ctx, futs: *[N_CLIENTS]Io.Future(anyerror!void)) void {
        for (futs) |*fut| {
            fut.await(self.io) catch {};
        }
    }

    fn closeMailboxAfterClients(self: *Ctx) void {
        var rem: polynode.ItemList = self.mbx.close();
        items.freeList(&rem, self.alloc);
    }

    fn setupSelect(self: *Ctx, pl: *Pool, sel: *std.Io.Select(MasterEvent)) !void {
        try sel.concurrent(.pool_ev, pool.getWaitResult, .{ pl, items.Event.EventPolyHelper.TAG, null });
        try sel.concurrent(.inbox, mailbox.receiveResult, .{ self.mbx, null });
    }

    fn runEventLoop(self: *Ctx, pl: *Pool, sel: *std.Io.Select(MasterEvent)) !void {
        while (self.pool_done < N_POOL_ITEMS or self.inbox_done < N_CLIENTS) {
            const event: MasterEvent = try sel.await();
            switch (event) {
                .pool_ev => |r| switch (r) {
                    .item => |handle| {
                        var slot: Slot = handle;
                        defer pl.put(&slot);
                        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
                        ev.code += 1;
                        self.pool_done += 1;
                        std.log.info("pool_ev: processed code={d} ({d}/{d})", .{ ev.code, self.pool_done, N_POOL_ITEMS });
                        if (self.pool_done < N_POOL_ITEMS) {
                            try sel.concurrent(.pool_ev, pool.getWaitResult, .{ pl, items.Event.EventPolyHelper.TAG, null });
                        }
                    },
                    .closed, .canceled, .timeout, .not_created => break,
                },
                .inbox => |r| switch (r) {
                    .item => |handle| {
                        var slot: Slot = handle;
                        defer items.freeSlot(&slot, self.alloc);
                        const ev: *items.Event = items.Event.EventPolyHelper.mustFromSlot(&slot);
                        self.inbox_done += 1;
                        std.log.info("inbox: client item code={d} ({d}/{d})", .{ ev.code, self.inbox_done, N_CLIENTS });
                        if (self.inbox_done < N_CLIENTS) {
                            try sel.concurrent(.inbox, mailbox.receiveResult, .{ self.mbx, null });
                        }
                    },
                    .closed, .canceled, .timeout, .wakeup => break,
                },
            }
        }
        sel.cancelDiscard();
    }
};

fn seedPool(pl: *Pool) !void {
    for (0..N_POOL_ITEMS) |i| {
        var slot: Slot = null;
        try pl.get(items.Event.EventPolyHelper.TAG, .new_only, &slot);
        items.Event.EventPolyHelper.mustFromSlot(&slot).code = @intCast(100 + i);
        pl.put(&slot);
    }
}

const items = @import("../items/items.zig");
const hooks = @import("../hooks/hooks.zig");
const helpers = @import("../helpers/helpers.zig");
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const Mbox = matryoshka.Mbox;
const pool = matryoshka.pool;
const Pool = matryoshka.Pool;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
const Io = std.Io;
