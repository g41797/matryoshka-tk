# Mailbox vs TypeErasedQueue 

---

## Two opposite designs

| | `std.Io.TypeErasedQueue` | Matryoshka Mailbox |
|---|---|---|
| Storage | Queue owns it | Mailbox owns none — moves what already exists |
| Elements | Copied in | Moved in, never copied |
| Capacity | Bounded | Unbounded |
| Backpressure | Inside the queue | Outside — Pool, or the application |
| A producer that's full | Waits for a free slot | Never waits for capacity — only for a receiver |
| A consumer receives | A copied value | The item itself |

```text
TypeErasedQueue                     Mailbox

storage + sync + capacity           sync + moving items between owners
```

## TypeErasedQueue is a synchronization primitive

Its job: *"I have N slots. Coordinate access to them."*

That means it needs:

- waiting producers, waiting consumers
- a notion of capacity
- per-waiter conditions
- rules for who wakes next

Slots are the center of the design. The items passing through are secondary.

## Mailbox is a transport primitive

Matryoshka's premise: the item already exists somewhere.

```text
create it → send it → receive it → reuse it or free it
```

A Mailbox never creates storage, never owns capacity. It only moves a handle from one  
holder to another — a narrower job than a queue's.

## Pool becomes the backpressure mechanism instead

```text
Bounded-queue design:              Matryoshka design:

Producer                           Producer
   ↓                                  ↓
bounded queue                      Pool → item
   ↓                                  ↓
Consumer                           Mailbox
                                       ↓
                                    Consumer
                                       ↓
                                    Pool
```

When the Pool is empty, the producer waits — the Mailbox itself has no opinion about it.

## Four responsibilities, four owners

```text
Mailbox     synchronization + moving items between owners
Pool        lifecycle, capacity, reuse
Allocator   memory
Master      scheduling, application policy
```

A `TypeErasedQueue` bundles synchronization, storage, capacity, and allocation policy  
into one type. 

Matryoshka splits them — each piece has exactly one job.

## Mailbox is not really a queue

Internally, a Mailbox uses `std.DoublyLinkedList` — an implementation detail, not the  
architecture. 

The API reflects the real job:

```zig
mbx.send(...)
mbx.receive(...)
```

not

```zig
enqueue(...)
dequeue(...)
```

A queue stores values.  

A Mailbox 

- moves the item 
- that already exists 
- from one holder
- to the next.
