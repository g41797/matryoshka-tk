# Story — Video Transcoder

A service receives video streams from many cameras.

Every camera continuously produces compressed frames.

Frames must be decoded.

Frames may be filtered.

Frames must be encoded again.

Encoded video is written to storage.

Thousands of cameras work simultaneously.

One slow camera must not affect the others.

Memory is limited.

Buffers are reused.

Processing scales by adding workers.

Frames are never shared.

Frames move.

Ownership moves with them.

---

# Diagram 1 — External view

```text
 Cameras

   │
   V

 Video Transcoder

   │
   V

 Storage
```

---

# Diagram 2 — Main processing pipeline

```text
CompressedFrame

>>>==============================

{ Decoder }

        │

RawFrame

==============================>>>

{ Filter }

        │

FilteredFrame

==============================>>>

{ Encoder }

        │

EncodedSegment

==============================>>>

{ Storage }
```

---

# Diagram 3 — Worker pool

```text
RawFrame

==============================>>>

{ Encoder #1 }

{ Encoder #2 }

{ Encoder #3 }

        │
        V

[ VideoBuffer ]
```

Equivalent compact notation

```text
RawFrame

==============================>>>

{ Encoder }

        │
        V

[ VideoBuffer ]
```

---

# Diagram 4 — Shared worker queue

```text
RawFrame

{ Decoder #1 }
{ Decoder #2 }
{ Decoder #3 }

      │
      V

>>>==============================>>>

{ Encoder #1 }
{ Encoder #2 }
{ Encoder #3 }
```

Many producers.

Many consumers.

One shared Mailbox.

---

# Diagram 5 — Memory reuse

```text
                 VideoBuffer

              [ VideoBuffer ]

                 ▲       │
                 │       │
                 │       V

           { Decoder }  { Encoder }
```

Decoder borrows a buffer.

Encoder returns it.

Pool never talks to Mailbox.

Pool never executes.

---

# Diagram 6 — Complete architecture

```text
CompressedFrame

{ Camera #1 }
{ Camera #2 }
{ Camera #3 }

        │
        V

>>>==============================

{ Decoder }

        │

RawFrame

==============================>>>

{ Filter }

        │

FilteredFrame

==============================>>>

{ Encoder #1 }
{ Encoder #2 }
{ Encoder #3 }

        │
        ├──────────────► [ VideoBuffer ]
        │
        V

EncodedSegment

==============================>>>

{ Storage }
```

---

# Diagram 7 — Ownership

```text
CompressedFrame

{ Camera }

      │

      V

===========>

{ Decoder }

      │

      V

===========>

{ Filter }

      │

      V

===========>

{ Encoder }

      │

      V

===========>

{ Storage }
```

Only one Master owns an Item at any time.

Items travel.

Ownership travels.

---

# Diagram 8 — System overview

```text
CompressedFrame

>>>==============================

{ Decoder }

        │
        V

RawFrame

==============================>>>

{ Filter }

        │
        V

FilteredFrame

==============================>>>

{ Encoder }

        │
        V

EncodedSegment

==============================>>>

{ Storage }

                ▲
                │
                │

          [ VideoBuffer ]
```

---

# Video Transcoder

External view.

Not Matryoshka-Tk.

- Receives video from many cameras.
- Processes many streams simultaneously.
- Decodes compressed frames.
- Applies image processing.
- Encodes video into the target format.
- Writes encoded video to storage.
- Preserves frame order for every camera.
- Reuses memory.
- Scales by adding workers.
- Continues processing while new video arrives.
- Finishes in-flight work during shutdown.
- Produces encoded video ready for playback.

