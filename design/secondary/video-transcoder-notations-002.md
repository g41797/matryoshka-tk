# Video Transcoder

A video transcoder converts video.

Input and output formats differ.

Many video streams arrive simultaneously.

Every stream is independent.

Frames flow through the system.

The system never stops receiving work.

---

# Overall architecture

```text
               CompressedFrame

 Camera A
 Camera B
 Camera C

      VVV

      ||
      ||
      ||

      VVV

   { Receiver }

        │

        V

====================

        │

        V

   { Decoder }

        │

        V

====================

        │

        V

   { Filter }

        │

        V

====================

        │

        V

 { Encoder #1 }

 { Encoder #2 }

 { Encoder #3 }

        │

        V

====================

        │

        V

   { Storage }
```

---

# Multiple producers

Many cameras.

One Receiver.

```text
 Camera A

 Camera B

 Camera C

 Camera D

      VVV

      ||
      ||
      ||

      VVV

 { Receiver }
```

Many producers.

One Mailbox.

One Master.

---

# Worker farm

One Decoder.

Many Encoders.

```text
      { Decoder }

           │

           V

====================>>>

     { Encoder #1 }

     { Encoder #2 }

     { Encoder #3 }
```

One Mailbox.

Many consumers.

Load distributes naturally.

---

# Vertical worker farm

The same architecture.

Different layout.

```text
      { Decoder }

           VVV

           ||
           ||
           ||

           VVV

     { Encoder #1 }

     { Encoder #2 }

     { Encoder #3 }
```

Orientation has no meaning.

Readability does.

---

# Decoder and buffer pool

Decoder borrows memory.

Decoder returns memory.

```text
             [ VideoBuffer ]

                    ▲
                    │
                    │
                    │

             { Decoder }
```

Pool owns reusable buffers.

Pool does not execute.

Pool does not communicate.

---

# Encoder and buffer pool

Many workers.

One shared Pool.

```text
            [ VideoBuffer ]

        ▲       ▲       ▲
        │       │       │

{ Encoder #1 }

{ Encoder #2 }

{ Encoder #3 }
```

Workers borrow.

Workers return.

Pool reuses.

---

# Complete ownership

Communication flows forward.

Ownership flows sideways.

```text
 Camera

   │

   V

====================

   │

   V

{ Decoder } ---------> [ VideoBuffer ]

   │

   V

====================

   │

   V

{ Filter }

   │

   V

====================

   │

   V

{ Encoder } ---------> [ VideoBuffer ]

   │

   V

====================

   │

   V

{ Storage }
```

Mailboxes move Items.

Pools manage ownership.

The two never communicate.

---

# Independent streams

Every stream is isolated.

```text
Camera A

  V

=======>

{ Decoder }

  V

=======>

{ Encoder }

  V

=======>

Storage A
```

```text
Camera B

  V

=======>

{ Decoder }

  V

=======>

{ Encoder }

  V

=======>

Storage B
```

One slow stream

does not stop

another stream.

---

# Backpressure

Encoders become busy.

Mailbox fills.

Decoder continues

until limits are reached.

```text
{ Decoder }

      │

      V

==============================

      │

      V

{ Encoder #1 }   Busy

{ Encoder #2 }   Busy

{ Encoder #3 }   Busy
```

Work waits.

Workers do not block each other.

---

# Graceful shutdown

Shutdown follows

the normal communication path.

```text
Shutdown!

      V

====================

      V

{ Decoder }

      V

====================

      V

{ Filter }

      V

====================

      V

{ Encoder }

      V

====================

      V

{ Storage }
```

No special control path.

Shutdown is another Item.

---

# Complete system

```text
 Camera A      Camera B      Camera C

      VVV         VVV          VVV

      ||          ||           ||

      ||==========||===========||

                 VVV

            { Receiver }

                 │

                 V

===============================

                 │

                 V

            { Decoder }

                 │
                 ├──────────────► [ VideoBuffer ]
                 │

                 V

===============================

                 │

                 V

             { Filter }

                 │

                 V

===============================

                 │

                 V

          { Encoder #1 }

          { Encoder #2 }

          { Encoder #3 }

             ▲      ▲      ▲
             │      │      │
             └──────┴──────┘

             [ VideoBuffer ]

                 │

                 V

===============================

                 │

                 V

             { Storage }
```

---

# Video Transcoder

External view.

Receives video streams.

Processes many streams.

Decodes frames.

Applies image processing.

Encodes target format.

Writes video to storage.

Used memory is limited.

Scalable.

Preserves frame order.

Continues while new streams arrive.

Supports graceful shutdown.

