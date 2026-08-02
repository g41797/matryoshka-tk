# Story: Video Transcoder Pipeline

A complete system design — from domain problem to Matryoshka implementation.

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
  ├── mailbox.receive(ready_queue) ──► StreamContext (exclusive hold)
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

---

*Implementation: `stories/video_transcoder/video_transcoder.zig`. Scale used: 3 cameras, 2 frames each, 2 video buffers (forces backpressure), 2 encoding workers.*
