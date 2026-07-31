// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

// Transfer flow:
//
//  buf_pool (VideoBuffer×N_BUFFERS)
//  │ getWaitResult ──► Network Master (Io.Select)
//  │   on buffer: fill ──► attach to StreamContext ──► ready_queue
//  │                                                        │
//  ▼                                                        ▼
//  [ buf_pool ]◄── pool.put ◄── Worker (Io.Group) ◄── mailbox.receive
//  (pool signals ──► Network Master wakes)   │
//                                          └──► EncodedSegment ──► storage_mbh
//                                                                        │
//                                                                        ▼
//                                                              Storage Task
//                                                              (logs, frees)
//
//  Shutdown:
//  Network closes ready_queue ──► workers get error.Closed ──► group.await
//  close storage_mbh ──► storage task exits ──► pool.close ──► on_close frees

// --- Types ---

const N_CAMERAS: usize = 3;
const N_FRAMES_PER_CAMERA: usize = 2; // total frames = 6
const N_BUFFERS: usize = 2; // fewer than workers — forces backpressure
const N_WORKERS: usize = 2;

const VideoBuffer = struct {
    poly: polynode.PolyNode = .{},
    camera_id: u32 = 0,
    frame_id: u32 = 0,
    data: [64]u8 = .{0} ** 64,
};
const VideoBufferPolyHelper = polynode.PolyHelper(VideoBuffer);

// StreamContext carries per-camera encoder state.
// Routed through ready_queue — worker gets exclusive access, no locks needed.
const StreamContext = struct {
    poly: polynode.PolyNode = .{},
    camera_id: u32 = 0,
    frame_id: u32 = 0,
    frames_processed: u32 = 0, // encoder state: accumulates across frames
    buffer_slot: Slot = null, // VideoBuffer in transit (owned by StreamContext)
};
const StreamContextPolyHelper = polynode.PolyHelper(StreamContext);

const EncodedSegment = struct {
    poly: polynode.PolyNode = .{},
    camera_id: u32 = 0,
    segment_id: u32 = 0,
};
const EncodedSegmentPolyHelper = polynode.PolyHelper(EncodedSegment);

// --- Pool hooks for VideoBuffer pool (fixed-size: N_BUFFERS, no on-demand creation) ---

const VideoBufCtx = struct {
    alloc: std.mem.Allocator,

    pub fn poolHooks(self: *VideoBufCtx, tags: []const *const anyopaque) pool.PoolHooks {
        return .{
            .ctx = self,
            .tags = tags,
            .on_get = onGet,
            .on_put = onPut,
            .on_close = onClose,
        };
    }

    // No on-demand creation: pool size is fixed by seeding at startup.
    fn onGet(_: *anyopaque, _: *const anyopaque, _: usize, _: *Slot) void {}

    // Keep all returned buffers.
    fn onPut(_: *anyopaque, _: usize, _: *Slot) ?polynode.ItemList {
        return null;
    }

    fn onClose(ctx: *anyopaque, list: *polynode.ItemList) void {
        const self: *VideoBufCtx = @ptrCast(@alignCast(ctx));
        while (list.popFirst()) |poly| {
            var s: Slot = poly;
            VideoBufferPolyHelper.destroy(self.alloc, &s);
        }
    }
};

// --- Storage task ---

const StorageCtx = struct {
    storage_mbh: MailboxHandle,
    alloc: std.mem.Allocator,
};

fn storageFn(ctx: *StorageCtx) error{Canceled}!void {
    while (true) {
        var slot: Slot = null;
        defer EncodedSegmentPolyHelper.destroy(ctx.alloc, &slot);
        mailbox.receive(ctx.storage_mbh, &slot, null) catch |err| switch (err) {
            error.Canceled => return error.Canceled,
            error.Closed, error.Timeout, error.Wakeup => return,
        };
        const seg: *EncodedSegment = EncodedSegmentPolyHelper.mustFromSlot(&slot);
        std.log.info("storage: camera={d} segment={d}", .{ seg.camera_id, seg.segment_id });
    }
}

// --- Encoding worker ---

const WorkerCtx = struct {
    ready_queue: MailboxHandle,
    buf_ph: PoolHandle,
    storage_mbh: MailboxHandle,
    alloc: std.mem.Allocator,
    id: usize,
};

fn workerFn(ctx: *WorkerCtx) error{Canceled}!void {
    while (true) {
        var slot: Slot = null;
        defer StreamContextPolyHelper.destroy(ctx.alloc, &slot);
        mailbox.receive(ctx.ready_queue, &slot, null) catch |err| switch (err) {
            error.Canceled => return error.Canceled,
            error.Closed, error.Timeout, error.Wakeup => return,
        };
        const sc: *StreamContext = StreamContextPolyHelper.mustFromSlot(&slot);
        sc.frames_processed += 1;
        std.log.info("worker {d}: encoding camera={d} frame={d} (total={d})", .{
            ctx.id, sc.camera_id, sc.frame_id, sc.frames_processed,
        });

        // Return buffer to pool — wakes Network Master if it is waiting.
        pool.put(ctx.buf_ph, &sc.buffer_slot);
        // If pool closed during shutdown, buffer is retained; free it.
        if (sc.buffer_slot != null) {
            VideoBufferPolyHelper.destroy(ctx.alloc, &sc.buffer_slot);
        }

        // Send encoded segment to storage.
        var seg_slot: Slot = null;
        defer EncodedSegmentPolyHelper.destroy(ctx.alloc, &seg_slot);
        EncodedSegmentPolyHelper.create(ctx.alloc, &seg_slot) catch continue;
        const seg: *EncodedSegment = EncodedSegmentPolyHelper.mustFromSlot(&seg_slot);
        seg.camera_id = sc.camera_id;
        seg.segment_id = sc.frames_processed;
        mailbox.send(ctx.storage_mbh, &seg_slot) catch {};
    }
}

// --- Network Master ---
//
// A Master is a coordination boundary: it owns its resources and coordinates
// their flow. The Network Master owns the buffer pool (as a backpressure source)
// and the ready queue. Its Io.Select loop fills buffers and routes StreamContext
// items to the workers.

const NetworkEvent = union(enum) {
    buf_ev: pool.PoolResult,
};

const NetworkMaster = struct {
    io: std.Io,
    alloc: std.mem.Allocator,
    buf_ph: PoolHandle,
    ready_queue: MailboxHandle,
    sent: usize = 0,
    camera_frames: [N_CAMERAS]u32 = .{0} ** N_CAMERAS,
    camera_idx: usize = 0,

    const total: usize = N_CAMERAS * N_FRAMES_PER_CAMERA;

    // Io.Select loop: wait for a free buffer (backpressure), fill it, route it.
    fn produce(self: *NetworkMaster) !void {
        var sel_buf: [4]NetworkEvent = undefined;
        var sel: std.Io.Select(NetworkEvent) = std.Io.Select(NetworkEvent).init(self.io, &sel_buf);

        try sel.concurrent(.buf_ev, pool.getWaitResult, .{ self.buf_ph, VideoBufferPolyHelper.TAG, null });

        while (self.sent < total) {
            const ev: NetworkEvent = try sel.await();
            switch (ev) {
                .buf_ev => |r| switch (r) {
                    .item => |handle| try self.onBuffer(&sel, handle),
                    .closed, .canceled, .timeout, .not_created => break,
                },
            }
        }

        sel.cancelDiscard();
        std.log.info("network: all {d} frames sent", .{total});
    }

    // Per free-buffer step: fill, wrap in a StreamContext, send to the ready queue.
    fn onBuffer(self: *NetworkMaster, sel: *std.Io.Select(NetworkEvent), handle: ItemHandle) !void {
        var buf_slot: Slot = handle;

        const vb: *VideoBuffer = VideoBufferPolyHelper.mustFromSlot(&buf_slot);
        vb.camera_id = @intCast(self.camera_idx);
        vb.frame_id = self.camera_frames[self.camera_idx];
        self.camera_frames[self.camera_idx] += 1;
        std.log.info("network: camera={d} frame={d} buffer filled", .{ vb.camera_id, vb.frame_id });

        var ctx_slot: Slot = null;
        defer StreamContextPolyHelper.destroy(self.alloc, &ctx_slot);
        try StreamContextPolyHelper.create(self.alloc, &ctx_slot);
        const sc: *StreamContext = StreamContextPolyHelper.mustFromSlot(&ctx_slot);
        sc.camera_id = vb.camera_id;
        sc.frame_id = vb.frame_id;
        sc.buffer_slot = buf_slot;
        buf_slot = null; // the StreamContext holds the buffer now

        errdefer pool.put(self.buf_ph, &sc.buffer_slot);
        try mailbox.send(self.ready_queue, &ctx_slot);

        self.sent += 1;
        self.camera_idx = (self.camera_idx + 1) % N_CAMERAS;

        if (self.sent < total) {
            try sel.concurrent(.buf_ev, pool.getWaitResult, .{ self.buf_ph, VideoBufferPolyHelper.TAG, null });
        }
    }

    // Shutdown: close the ready queue, reclaim buffers, free unsent contexts.
    fn closeAndReclaim(self: *NetworkMaster) void {
        var rem: polynode.ItemList = mailbox.close(self.ready_queue);
        while (rem.popFirst()) |poly| {
            const sc: *StreamContext = StreamContextPolyHelper.mustFromPoly(poly);
            pool.put(self.buf_ph, &sc.buffer_slot);
            if (sc.buffer_slot != null) {
                VideoBufferPolyHelper.destroy(self.alloc, &sc.buffer_slot);
            }
            var sc_slot: Slot = poly;
            StreamContextPolyHelper.destroy(self.alloc, &sc_slot);
        }
    }
};

// --- Resource setup helpers ---

// Seed the buffer pool with exactly N_BUFFERS buffers — fixes the backpressure limit.
fn seedBufferPool(buf_ph: PoolHandle, alloc: std.mem.Allocator) !void {
    for (0..N_BUFFERS) |_| {
        var slot: Slot = null;
        try VideoBufferPolyHelper.create(alloc, &slot);
        pool.put(buf_ph, &slot);
    }
}

// Free any EncodedSegments left in the storage close list.
fn freeSegmentList(list: *polynode.ItemList, alloc: std.mem.Allocator) void {
    while (list.popFirst()) |poly| {
        var s: Slot = poly;
        EncodedSegmentPolyHelper.destroy(alloc, &s);
    }
}

// --- Main entry point ---
//
// Thin: initialize shared resources, start the Masters, await shutdown in order.

pub fn run(allocator: std.mem.Allocator, io: std.Io) !void {
    // Shared resources.
    // Buffer pool: fixed N_BUFFERS — acts as backpressure signal.
    const buf_ph: PoolHandle = try pool.new(io, allocator);
    var buf_ctx: VideoBufCtx = .{ .alloc = allocator };
    const buf_tags = [_]*const anyopaque{VideoBufferPolyHelper.TAG};
    try pool.init(buf_ph, buf_ctx.poolHooks(&buf_tags));
    defer {
        pool.close(buf_ph);
        pool.destroy(buf_ph, allocator);
    }

    try seedBufferPool(buf_ph, allocator);

    // Ready queue: StreamContext items route camera state to workers.
    // Storage mailbox: encoded segments flow from workers to storage task.
    // Both are closed and destroyed explicitly during shutdown below.
    const ready_queue: MailboxHandle = try mailbox.new(io, allocator);
    const storage_mbh: MailboxHandle = try mailbox.new(io, allocator);

    // Start the storage task.
    var storage_ctx: StorageCtx = .{ .storage_mbh = storage_mbh, .alloc = allocator };
    var storage_fut = try io.concurrent(storageFn, .{&storage_ctx});

    // Start the encoding workers (Io.Group).
    var wctx0: WorkerCtx = .{ .ready_queue = ready_queue, .buf_ph = buf_ph, .storage_mbh = storage_mbh, .alloc = allocator, .id = 0 };
    var wctx1: WorkerCtx = .{ .ready_queue = ready_queue, .buf_ph = buf_ph, .storage_mbh = storage_mbh, .alloc = allocator, .id = 1 };
    var group: Io.Group = .init;
    try group.concurrent(io, workerFn, .{&wctx0});
    try group.concurrent(io, workerFn, .{&wctx1});

    // Start the Network Master loop.
    var network: NetworkMaster = .{
        .io = io,
        .alloc = allocator,
        .buf_ph = buf_ph,
        .ready_queue = ready_queue,
    };
    try network.produce();

    // Shutdown, in order.
    // 1. Network Master closes the ready queue; reclaim buffers, free unsent contexts.
    network.closeAndReclaim();

    // 2. Workers finish current frames, then exit on error.Closed.
    try group.await(io);
    mailbox.destroy(ready_queue, allocator);
    std.log.info("workers: all done", .{});

    // 3. Storage task: close the mailbox (signals exit), free unsent segments, await.
    {
        var srem: polynode.ItemList = mailbox.close(storage_mbh);
        freeSegmentList(&srem, allocator);
    }
    storage_fut.await(io) catch {};
    mailbox.destroy(storage_mbh, allocator);
    std.log.info("storage: done", .{});

    try helpers.expect(
        error.VideoTranscoderFailed,
        network.sent == NetworkMaster.total,
        "not all frames were sent",
    );
}

const helpers = @import("examples").helpers;
const matryoshka = @import("matryoshka");
const std = @import("std");
const mailbox = matryoshka.mailbox;
const pool = matryoshka.pool;
const polynode = matryoshka.polynode;
const Slot = polynode.Slot;
const ItemHandle = polynode.ItemHandle;
const MailboxHandle = mailbox.MailboxHandle;
const PoolHandle = pool.PoolHandle;
const Io = std.Io;
