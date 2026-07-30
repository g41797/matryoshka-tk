# Photo Archive Pipeline

## High-Level Description

A photo archive stores personal photos.

Users browse their collections in different ways.

* Album view.
* Grid view.
* Search results.
* Full-size view.

Showing full-resolution photos everywhere would waste storage bandwidth and slow the user interface.

Instead, the system stores two versions of every uploaded photo.

* The original photo.
* A small thumbnail.

The original photo is used for viewing and downloading.

The thumbnail is used for fast browsing and preview.

Whenever a user uploads a new photo, the system automatically creates the thumbnail and stores both files.

---

# Software Requirements

The system accepts photo uploads from clients.

Each connection uploads one JPEG photo.

For every uploaded photo the system shall:

1. Receive the JPEG file.
2. Uncompress the JPEG into an image.
3. Create a thumbnail image.
4. Compress the thumbnail as JPEG.
5. Save the original JPEG file.
6. Save the thumbnail JPEG file.
7. Reply to the client.

The original upload is preserved.

Only the thumbnail is generated.

One uploaded photo produces two stored files.

---

# Architectural View

The previous section described **what** the system does.

Now we divide the work into independent responsibilities.

```
Receive Photo

        |

        V

Uncompress JPEG

        |

        V

Create Thumbnail

        |

        V

Compress Thumbnail

        |

        V

Store Files

        |

        V

Reply
```

Each responsibility performs one task.

Each responsibility receives its input.

Each responsibility produces its output.

The output of one stage becomes the input of the next stage.

---

# Matryoshka Translation

Each responsibility becomes a Master.

The uploaded photo becomes an Item.

The Item moves from one Master to the next.

```
+------------------+
| Receive Master   |
+------------------+
          |
          V
+------------------+
| Decode Master    |
+------------------+
          |
          V
+--------------------+
| Thumbnail Master   |
+--------------------+
          |
          V
+------------------+
| Encode Master    |
+------------------+
          |
          V
+------------------+
| Storage Master   |
+------------------+
          |
          V
+------------------+
| Reply Master     |
+------------------+
```

Each Master owns the Item while it performs its work.

When finished, ownership moves to the next Master.

No two Masters process the same Item at the same time.

---

# Flow

The client uploads one JPEG photo.

The Receive Master accepts the upload.

It forwards the photo to the Decode Master.

The Decode Master uncompresses the JPEG into an image.

It transfers the image to the Thumbnail Master.

The Thumbnail Master creates a smaller version of the image.

It forwards both the original image and the thumbnail image.

The Encode Master compresses the thumbnail into JPEG.

The original JPEG upload is preserved.

The Storage Master saves:

* the original JPEG file.
* the thumbnail JPEG file.

After both files are stored, the Reply Master sends a successful response to the client.

The request is complete.

---

# Why This Example

The example is intentionally simple.

It contains a linear processing pipeline.

Each stage has one responsibility.

Each stage has a clear input and output.

The reader can focus on the architecture rather than the image-processing algorithms.

The same architectural pattern applies to many other systems, including video processing, document conversion, data transformation, and network protocols.


# PNG is better choice


The goal of the document is to explain **Matryoshka-Tk**, not JPEG support in Zig. If readers see "JPEG," some Zig developers may immediately think:

> "Wait, Zig std doesn't support JPEG."

That distracts from the architectural lesson.

Using **PNG + zstbi** avoids that issue because it's a common combination in the Zig ecosystem.

The story becomes:

* Client uploads a PNG image.
* The system reads the PNG.
* The system uncompresses it into pixels.
* The system creates a thumbnail.
* The system compresses the thumbnail as PNG.
* The system stores:

    * the original PNG
    * the thumbnail PNG


In architecture section:

> The system uncompresses the PNG image into pixels.

Then, in an implementation section or code example:

> This implementation uses `zstbi` to read and write PNG images.

Here is the end-to-end breakdown of the **Photo Archive Pipeline** flow, mapped directly to the **Matryoshka-Tk** architecture as visualized on the whiteboard:

---

## 1. Core Architectural Concepts

* **Master:** A processing unit/task that owns application state, executes a single responsibility, and processes items one at a time.
* **Mailbox:** A thread-safe communication channel used to pass items between Masters.
* **Item:** The data container (carrying image bytes, pixel buffers, or commands) that moves from master to master.
* **Pool:** A thread-safe memory manager that recycles allocated **Items** to avoid expensive heap allocations.

---

## 2. Step-by-Step Data Flow

```
[ Client ] 
    │ (Uploads PNG)
    ▼
[ Receive Master ] ──(Pulls Item)──► [ Item Pool ]
    │ (Stores raw bytes, extracts ID)
    ▼ ──(Mailbox)──►
[ Decode Master ]
    │ (Expands PNG to Raw Pixels via `zstbi`)
    ├─────────────────────────────┐
    ▼ (Original Pixels)           ▼ (Original PNG Data)
[ Thumbnail Master ]       [ Storage Master ]
    │ (Resizes to thumbnail)      │
    ▼                             │
[ Encode Master ]                 │
    │ (Compresses to PNG)         │
    ▼                             │
[ Storage Master ] ◄──────────────┘
    │ (Persists Original + Thumbnail)
    ▼
[ Reply Master ] ──(Recycles Item)──► [ Item Pool ]
    │
    ▼
[ Client ] (Success Response)

```

---

### Execution Stages

1. **Intake (`Receive Master`)**
* Accepts the incoming upload containing the raw **PNG data** and request metadata.
* Fetches an empty **Item** from the **Item Pool** to store the incoming payload.
* Hands off ownership of the populated **Item** to the next stage via a **Mailbox**.


2. **Pixel Expansion (`Decode Master`)**
* Receives the **Item** from the **Receive Master**.
* Decodes the raw PNG payload into uncompressed, raw pixel buffers using `zstbi`.
* Retains both the raw input PNG (for storage) and the raw pixel buffer (for thumbnail processing).


3. **Resizing (`Thumbnail Master`)**
* Processes the uncompressed pixel buffer from the **Decode Master**.
* Generates a scaled-down thumbnail pixel buffer according to target aspect ratio/scaling profile rules.


4. **Compression (`Encode Master`)**
* Accepts the scaled-down pixel buffer.
* Encodes the thumbnail back into compressed **PNG format** using `zstbi`.


5. **Persistence (`Storage Master`)**
* Collects both required artifacts:
1. The **Original PNG** file.
2. The newly encoded **Thumbnail PNG** file.


* Writes both items to the persistence storage/disk bucket and updates job metadata state.


6. **Response & Recycling (`Reply Master`)**
* Confirms successful storage of both assets.
* Sends an acknowledgment/success reply (`Reply: SUCCESS, ID`) back to the client.
* Returns the processed **Item** back to the **Item Pool** so it can be reused by future uploads without reallocating memory.



# Photo Archive & Print Pipeline

---

## 1. Customer Point of View

From a user's perspective, the process is fast, quiet, and high-quality:

1. **Upload Phase:** 
   * You upload a full-resolution photo (PNG) to the system. 
   * The upload completes quickly, and you receive an instant confirmation.

2. **Design & Layout Phase (Fast Browsing):**
   * As you assemble your photo book or print layout, the editor runs smoothly without lag.
   * The application uses lightweight thumbnails to let you arrange, crop, and preview pages instantly without waiting for huge files to load over the network.

3. **Final Print & Fulfillment:**
   * When you submit your order, the system automatically pulls your original, untouched high-resolution image behind the scenes.
   * The final printed surface is generated using full pixel fidelity, ensuring sharp, professional-grade print quality.

---

## 2. Developer Point of View (Matryoshka-Tk Architecture)

From an architectural standpoint, the system is a linear, thread-isolated processing pipeline using domain-specific structs (no generic type-erased `Item` terminology on the design board). 

### Key Architectural Rules
* **Masters (Active Units):** Dedicated OS threads or tasks. Each Master owns application state and executes a single responsibility.
* **Mailboxes & Pools (Passive Channels):** 
  * **Mailbox:** Thread-safe queue used strictly by Masters to pass struct ownership.
  * **Pool:** Thread-safe pool used by Masters to request or recycle pre-allocated memory blocks.
  * *Mailboxes and Pools do not interact with each other directly; only Masters initiate operations on them.*

---

### End-to-End Processing Flow


```

```
                         [ Client Upload ]
                                 │  
                                 ▼ (PNG Struct)  
                          ┌─────────────┐  
                          │ RECEIVE     │ ◄─── (Gets pre-allocated  
                          │ MASTER      │      buffer from Pool)  
                          └──────┬──────┘  
                                 │ (Mailbox)  
                                 ▼  
                          ┌─────────────┐  
                          │ DECODE      │  
                          │ MASTER      │ (Uncompresses via `zstbi`)  
                          └──────┬──────┘  
                                 ├───────────────────────────────┐  
                 (Pixels Struct) │                               │ (PNG Struct - High Res)  
                                 ▼                               ▼  
                          ┌─────────────┐                 ┌─────────────┐  
                          │ THUMBNAIL   │                 │             │  
                          │ MASTER      │ (Resizes)       │             │  
                          └──────┬──────┘                 │             │  
                                 │ (Pixels Struct)        │             │  
                                 ▼                        │ STORAGE     │  
                          ┌─────────────┐                 │ MASTER      │  
                          │ ENCODE      │                 │             │  
                          │ MASTER      │ (Compresses)    │             │  
                          └──────┬──────┘                 │             │  
                                 │ (PNG Struct - Thumb)   │             │  
                                 └──────────────────────► │             │  
                                                          └──────┬──────┘  
                                                                 │  
                                                                 ▼  
                                                           ┌───────────┐  
                                                           │  DISK /   │  
                                                           │ PERSISTED │  
                                                           └─────┬─────┘  
                                                                 │  
                                                                 ▼  
                                                          ┌─────────────┐  
                                                          │ REPLY       │ ──► [ Client Response ]  
                                                          │ MASTER      │ ──► (Recycles Structs  
                                                          └─────────────┘      to Pool)

```

```

---

### Step-by-Step Implementation Flow

1. **Intake (`Receive Master`)**
   * Fetches an unallocated memory buffer from the `PNG Pool`.
   * Reads raw bytes from the network into the buffer and assigns a unique `RequestID`.
   * Sends the `PNG` struct into the `Decode Mailbox`.

2. **Pixel Expansion (`Decode Master`)**
   * Reads the `PNG` struct from its Mailbox.
   * Decodes the PNG byte stream into raw image `Pixels` using `zstbi`.
   * Passes the original `PNG` struct directly to the `Storage Master` (retaining full resolution for printing).
   * Passes the raw `Pixels` struct to the `Thumbnail Master`.

3. **Thumbnail Generation (`Thumbnail Master`)**
   * Takes the raw high-res `Pixels` struct and applies downscaling logic.
   * Produces a lightweight `Thumbnail Pixels` struct.

4. **Thumbnail Compression (`Encode Master`)**
   * Encodes the `Thumbnail Pixels` into a compressed `Thumbnail PNG` struct via `zstbi`.
   * Sends the `Thumbnail PNG` struct to the `Storage Master`.

5. **Persistence (`Storage Master`)**
   * Receives two concrete items for the job:
     * **`PNG` (Original High-Res):** Saved for downstream surface generation / print ticket processing.
     * **`PNG` (Thumbnail):** Saved for immediate UI preview and page composition requests.
   * Writes both files to disk/storage and forwards execution status to the `Reply Master`.

6. **Response & Memory Recycling (`Reply Master`)**
   * Transmits success status back to the client.
   * Returns used `PNG` and `Pixels` structs back to their respective **Pools** for reuse, avoiding dynamic heap allocation on future requests.


