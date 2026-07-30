# Matryoshka-Tk Notation

> A visual language for discussing concurrent software systems.

---

# Why

Matryoshka-Tk defines four architectural building blocks.

* Master
* Item
* Mailbox
* Pool

The notation gives them a common visual language.

It is intentionally small.

It should work equally well in

* README files
* Markdown
* whiteboards
* presentations
* code comments

The goal is simple.

> Someone should understand the architecture before reading the explanation.

This notation is not a diagram format.

It is a vocabulary.

Diagrams are sentences written using that vocabulary.

---

# Design principles

---


## Architecture first

The notation describes architecture.

Never implementation.

---

## One symbol. One meaning.

Each symbol has exactly one responsibility.

---

## Infrastructure uses symbols

Infrastructure is represented by symbols.

* Master
* Mailbox
* Pool

---

## Application uses names

Application items are represented by their names.

Examples

```
Chunk
Chunk!
Request
Response
Connection
Shutdown!
Timer
```

The notation does not define application item names.

That is the responsibility of the application.

An item name ending with `!` denotes an Out-of-Band (OOB) Item.

---

## ASCII first

Everything should be drawable using plain text.

If it cannot be drawn in ASCII,  
it is probably too complicated.

---

## Orientation independent

A diagram may be drawn

* left to right
* right to left
* top to bottom
* bottom to top

Orientation has no meaning.

Only the notation carries meaning.

---

## Composition

Complex systems are built by composing a few simple symbols.

---

# Primitive symbols

---


## Master

```
{ Worker }
```

A Master executes.

The text identifies the Master.

Examples

```
{ HTTP Listener }

{ JPG Compressor }

{ Logger }

{ Database }

{ Recycler }
```

---

## Pool

---


```
[ Chunk ]

[ Chunk|Job ]

[ Connection|Buffer ]
```

A Pool owns reusable Items.

The names declare which Item types the Pool owns.

Masters temporarily borrow Items from a Pool and return them later.

Pools never execute.

---

## Mailbox

---


Horizontal

```
==========
```

Vertical

```
||
||
||
||
```

A Mailbox transports Items.

A Mailbox may temporarily retain waiting Items.

Its orientation has no meaning.

---

## Movement

---


Movement is independent from the Mailbox.

Horizontal

```
>>>

<<<
```

Vertical

```
VVV

^^^
```

Movement symbols describe Item movement.

They do not describe the Mailbox.

---

# Application items

---


Application items are represented by their names.

```
Chunk

Chunk!

Request

Response

Shutdown!

Connection

Timer
```

The notation intentionally does not distinguish between ordinary and Out-of-Band Items.

The application does.

---

# Mailbox contract

---


Text attached to a Mailbox declares the Item types that may traverse it.

Example

```
Chunk|Job|Shutdown!

>>>==========
```

This means the Mailbox accepts

* Chunk
* Job
* Shutdown!

It describes the communication contract.

Not the current mailbox contents.

---

# Mailbox sharing

---


Sharing belongs to the Mailbox.

Not to the Master.

The notation is qualitative.

`>>>` means "many".

It does not indicate an exact number.

---

## One producer

---


```
>==========
```

---

## Many producers

---


```
>>>==========
```

Several Masters send to the same Mailbox.

Typical examples

* logging
* event aggregation
* request collection

---

## One consumer

---


```
==========>
```

---

## Many consumers

---


```
==========>>>
```

Several Masters receive from the same Mailbox.

Typical examples

* worker pools
* parallel processing

---

## Many producers and many consumers

---


```
>>>==========>>>
```

---

# Layout

---


The notation does not prescribe layout.

Masters, Mailboxes and Pools may be positioned wherever they make the architecture easiest to understand.

Only the symbols carry meaning.

The page layout does not.

---

# Examples

---


## Worker

---


```
Chunk|Shutdown!

>>>================

{ Worker }

     |

[ Chunk ]
```

---

## Worker pool

---


```
Chunk|Shutdown!

==========>>>

{ Worker #1 }

{ Worker #2 }

{ Worker #3 }
```

---

## Logger

---


```
LogRecord

>>>============

{ Logger }

     |

[ LogRecord ]
```

---

## Request processing

```
Request|Shutdown!

>>>================

{ HTTP Server }

      |

Response

>>>================

{ Socket Writer }
```

---

# Reading diagrams

---


The notation separates four independent concepts.

Infrastructure

```
{ Master }

========== (mailbox)

[ Pool ]
```

Application items

```
Chunk

Request

Shutdown!
```

Movement

```
>>>

<<<

VVV

^^^
```

Contract

```
Chunk|Request|Shutdown!
```

Together they describe the architecture.

---


# Two views

---


There are **two views** of the same system.

---


## Implementation view

---


Mailbox and Pool are generic infrastructure.

They know only about `ItemHandle` (`PolyNode`).

```text
Mailbox <-> ItemHandle
Pool    <-> ItemHandle
```

They never know whether the handle belongs to a `Request`, `Chunk`, `Timer`, or `VideoBuffer`.

---

## Architectural (user) view

---


The developer never thinks in terms of `ItemHandle`.

The developer thinks in terms of the application's objects.

```text
Request
Response
VideoBuffer
StreamContext
Shutdown!
```

So the diagrams intentionally show

```text
Request|Shutdown!

>>>==========
```

instead of

```text
ItemHandle|ItemHandle
```

because the diagram communicates **the application's architecture**, not the runtime implementation.

---

The same applies to Pools.

Implementation:

```text
Pool<ItemHandle>
```

Diagram:

```text
[ VideoBuffer ]

[ Connection ]

[ Chunk|Job ]
```

because those are the reusable application objects from the developer's point of view.

---

So the notation is deliberately **domain-oriented**, while the implementation is **type-erased**.

The notation answers:

> *What moves through the system?*

The implementation answers:

> *How is that movement implemented?*


---

The rule is:

- Use the compact notation when it is sufficient.
- Expand into concrete examples when it improves understanding.
- Never violate the architectural semantics.
- Optimize for communication, not minimal symbol count.

---

For example, if the notation says  
```
==========>>>
```
means "many consumers", but the reader benefits from seeing actual Masters, I will draw  
```
==========>>>

{ Encoder #1 }
{ Encoder #2 }
{ Encoder #3 }
```

Likewise for producers:  
```
>>>==========

may become

{ Camera #1 }
{ Camera #2 }
{ Camera #3 }

      │
      V

>>>==========
```

---

# Clarifications

---


The diagrams should look like flow charts, where every element of the flow is expressed using the Matryoshka notation.

That means free usage of:

Horizontal mailboxes  
```
==========
```

Vertical mailboxes  
```
||
||
||
```

Horizontal movement  
```
>>>

<<<
```

Vertical movement  
```
VVV

^^^
```

and combine them naturally in one drawing.

For example, a decoder 

- at the top sending work 
- to a vertical mailbox
- with three workers below
- is completely valid.

Likewise, a Pool 

- may sit on the side 
- because it is not part of the communication path 
- but of the transfer path.

The resulting diagrams 

- should resemble architecture sketches 
- suitable for whiteboard
- not sequence diagrams or UML.



---


# Layers


---


The reader should be able to tell immediately which layer they're reading:

- External — what the system does.
- Architecture — how responsibilities are organized.
- Implementation — how it's built.

---


| Level          | Good                           | Avoid                                 |
| -------------- | ------------------------------ | ------------------------------------- |
| External       | Handles more load.             | Adds workers.                         |
| External       | Works with limited memory.     | Reuses buffers.                       |
| Architecture   | Pool manages reusable buffers. | `std.ArrayList` buffer cache.         |
| Implementation | Uses intrusive pools.          | (this belongs in implementation docs) |


---


# Non-goals

---


The notation does not describe

* scheduling
* async implementation
* mutexes
* queues
* synchronization primitives
* memory allocation
* Zig APIs

Those belong to implementation.

---

# Future extensions

---


Possible extensions include

* master hierarchy
* recycler
* timers
* cancellation
* item transfer
* system boundaries
* external systems

New concepts should reuse the existing notation whenever possible.

New symbols should be introduced only when absolutely necessary.

---

# Design goal

---


The notation should be learnable in five minutes.

A developer should be able to sketch a Matryoshka architecture on a whiteboard.

Another Matryoshka developer should immediately understand it.

The notation should become the common language for discussing Matryoshka-Tk systems.


---


# When

---


Who knows...


---

