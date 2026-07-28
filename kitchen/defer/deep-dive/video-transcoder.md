# Deep Dive — Video Transcoder

This is the harder companion to [Story — Print Server](../story/print-server/discussion.md)  
— read that first if you haven't. This page has a real implementation:  
`stories/video_transcoder/video_transcoder.zig`.

---

## Part 1 — Discussion

A video platform is growing. The engineering team meets to discuss scale.

**Operator**: We receive thousands of uploaded videos every day. Some are seconds long. Some are hours.

**Product**: Users need to know when their video is ready. A long upload cannot silently disappear for an hour.

**Operations**: Transcoding is memory-intensive. We cannot keep decoded frames from thousands of videos in memory at the same time. We will run out.

**Operator**: And we have cameras. Thousands of them. Live feeds, not uploads. They send frames continuously.

**Operations**: Then memory is the hard constraint. We cannot buffer everything. The processing pipeline must consume frames as fast as they arrive, or it must slow the source.

---

The developers begin negotiating responsibilities.

**Dec** owns the decoder — the component that reads compressed video and produces raw frames.

**Fil** owns the filter — the component that applies color correction and other transforms.

**Enc** owns the encoder — the component that compresses frames into output segments for storage.

---

**Dec**: I read compressed video and produce frames. I do not want to know who applies filtering or who compresses the result. I produce frames and hand them off.

**Fil**: I receive frames, transform them, and hand them on. I do not want to know where frames come from or where they go after me.

**Enc**: I receive transformed frames and compress them. But I cannot accept new frames while I am writing. Writing takes time. If you push frames at me while I am busy, you either lose them or I must buffer them.

**Dec**: Then we need a place to hold frames between stages.

**Enc**: Buffers. But how many? And who allocates them?

**Operations**: Every buffer held is memory consumed. We need a fixed number of buffers total. When they are all in use, no new frames.

**Dec**: That is fine by me. If there is no free buffer, I wait. I cannot decode without somewhere to put the result.

**Operations**: You do not need a separate signal to stop?

**Dec**: No. A free buffer is the signal. No buffer, no decode. The constraint is structural.

---

**Operator**: We have thousands of cameras. We cannot assign one thread per camera.

**Enc**: And encoding is stateful. Frames from camera A must go through the same encoder state in order. I cannot mix frames from two cameras in the same pass.

**Dec**: So the encoder state must travel with the frames. We need one state object per camera. Whoever picks up that state processes the next frame for that camera.

**Fil**: Same for filtering. My state is per-camera too.

**Enc**: Then we are not routing frames. We are routing state. The frame attaches to the camera state. A worker picks up the state and processes the attached frame.

**Dec**: A worker that holds the camera state is the only one processing that camera at that moment. No coordination needed between workers.

**Enc**: And when the worker finishes, it returns the state to a shared queue. The next worker picks it up for the next frame.

**Dec**: The buffers go back too. The encoder returns the buffer when it finishes writing. That is what unblocks me.

---

**Operations**: What happens during shutdown?

**Dec**: I stop producing. The buffers still in flight finish their current work.

**Enc**: When there is nothing left to process, workers exit. Then we release the buffers.

**Operations**: And the camera states?

**Dec**: They live as long as there are frames for them. When a worker finishes the last frame for a camera, it releases the state.

---

## Part 2 — SRS

- Frames arrive from thousands of cameras simultaneously.
- Ingest does not wait for processing to complete.
- Frames from one camera are processed in arrival order.
- No two workers process frames from the same camera at the same time.
- Video buffers are reused. No allocation per frame.
- When workers fall behind, ingest slows. No coordination signal required.
- A fixed pool of workers handles all cameras.
- Workers do not interfere with each other.
- Ingest stops on shutdown.
- All in-flight frames complete processing.
- All memory is released.
- No frames are lost.

---

## Part 3 — Matryoshka Translation

Requirement: Memory reuse.

Matryoshka:

- `VideoBuffer` — PolyNode-based struct.
- `Pool` of `VideoBuffer`.
- Workers return buffers on completion.

---

Requirement: Flow control.

Matryoshka:

- `pool.getWaitResult` inside `Io.Select`.
- Pool availability is an async event.
- Empty pool pauses the Network Master.
- No polling. No sleep. No coordinator.

---

Requirement: Sequential processing per stream. Concurrent processing.

Matryoshka:

- `StreamContext` — PolyNode-based struct, carries per-camera encoder state.
- `ready_queue` — Mailbox of `StreamContext`.
- Worker receives `StreamContext` via `mailbox.receive`.
- Worker owns it exclusively. No other worker can touch it.
- `Io.Group` of encoding workers.

---

Requirement: Continuous ingest.

Matryoshka:

- Network Master: `Io.Select` loop.
- Two sources: pool availability, incoming network data.
- Fixed `Io.Group` of workers loops on `mailbox.receive(ready_queue)`.

---

Requirement: Clean shutdown.

Matryoshka:

- Network Master stops. Closes `ready_queue`.
- Workers receive `error.Closed`. Exit.
- `Io.Group.await` — all workers done.
- Close storage mailbox.
- `pool.close` — releases remaining buffers via `on_close`.

---

**The central insight.**

Pool exhaustion is backpressure.

- No free buffer — no decoded frame.
- No coordinator. No signal. No rate manager.
- The constraint is structural.

Where the architecture lives.

- Pool empty → Network Master waits.
- Worker returns buffer → pool signals → Network Master resumes.
- `StreamContext` in Mailbox → sequential processing without thread-per-camera.
- `Io.Group` → fixed concurrency, one exclusive owner per stream.
- `mailbox.close` → shutdown cascades downstream.

---

## Part 4 — Flow Diagram

```text
  [ Cameras (simulated) ]
        │
        V
  NETWORK MASTER (Io.Select)
  ├── pool.getWaitResult ──► VideoBuffer available? (backpressure: pauses when all buffers in use)
  │
  │   on buffer available:
  │     fill buffer (camera_id, frame_id)
  │     attach to StreamContext
  │     send StreamContext to ready_queue
  │
  V
  [ ready_queue: Mailbox of StreamContext ]
        │
        V
  ENCODING WORKERS (Io.Group)
  ├── mailbox.receive(ready_queue) ──► StreamContext (exclusive ownership)
  │     encode frame (sequential, lock-free)
  │     pool.put buffer ──────────────────────────────────► [ buf_pool ]
  │     create EncodedSegment                                    │
  │     mailbox.send to storage_mbh                         pool signals
  │     destroy StreamContext                                     │
  │     loop back to receive                              Network Master resumes
  │
  V
  [ storage_mbh: Mailbox of EncodedSegment ]
        │
        V
  STORAGE TASK (io.concurrent)
  ├── mailbox.receive(storage_mbh) ──► EncodedSegment
  │     write to storage (simulated: log)
  │     release segment
  │     loop back to receive
  V
  [ Storage ]

  Shutdown sequence:
  Network Master stops ──► closes ready_queue
  Workers get error.Closed ──► exit
  Io.Group.await ──► all workers done
  close storage_mbh ──► storage task gets error.Closed ──► exit
  pool.close ──► on_close ──► release remaining buffers
```

Scale used in the real run: 3 cameras, 2 frames each, 2 video buffers (forces  
backpressure), 2 encoding workers.

---

## The real code

Full source: `stories/video_transcoder/video_transcoder.zig` (340 lines).

### Setup — seeding the backpressure limit

```zig
fn seedBufferPool(buf_ph: PoolHandle, alloc: std.mem.Allocator) !void {
    for (0..N_BUFFERS) |_| {
        var slot: Slot = null;
        try VideoBufferPolyHelper.create(alloc, &slot);
        pool.put(buf_ph, &slot);
    }
}
```

`N_BUFFERS` is deliberately smaller than `N_WORKERS` in the real run — the pool runs dry  
on purpose, so the Network Master's backpressure path actually executes.

### Network Master — pool availability as a Select event source

```zig
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
}
```

No sleep, no poll. `pool.getWaitResult` is the only event source — when a worker returns a  
buffer, the Select loop wakes on its own.

### Worker — exclusive ownership, then hand back the buffer

```zig
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

        // Return buffer to pool — wakes Network Master if it is waiting.
        pool.put(ctx.buf_ph, &sc.buffer_slot);
        // If pool closed during shutdown, buffer is retained; free it.
        if (sc.buffer_slot != null) {
            VideoBufferPolyHelper.destroy(ctx.alloc, &sc.buffer_slot);
        }
        // ... build EncodedSegment, send to storage_mbh ...
    }
}
```

The `pool.put` here is the other half of the backpressure loop — it's what makes the  
Network Master's `getWaitResult` wake up.

### Shutdown — the mandatory order, applied

```zig
// 1. Network Master closes the ready queue; reclaim buffers, free unsent contexts.
network.closeAndReclaim();

// 2. Workers finish current frames, then exit on error.Closed.
try group.await(io);
mailbox.destroy(ready_queue, allocator);

// 3. Storage task: close the mailbox (signals exit), free unsent segments, await.
{
    var srem: std.DoublyLinkedList = mailbox.close(storage_mbh);
    freeSegmentList(&srem, allocator);
}
storage_fut.await(io) catch {};
mailbox.destroy(storage_mbh, allocator);
```

Same 9-step sequence as  
[Patterns — Graceful shutdown sequence](../patterns/master-and-shutdown.md), applied to  
three coordination boundaries instead of one: Network Master, worker group, storage task.

---

See also: [Patterns — Master composition](../patterns/master-and-shutdown.md) for the  
general shape this story follows.
