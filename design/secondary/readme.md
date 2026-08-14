![](kitchen/_logo/matryoshka-tk-logo.png)

---

# Matryoshka-Tk — Toolkit for Building Multitasking Systems in Zig

---

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Linux](https://github.com/g41797/matryoshka-tk/actions/workflows/linux.yml/badge.svg)](https://github.com/g41797/matryoshka-tk/actions/workflows/linux.yml)
[![Windows](https://github.com/g41797/matryoshka-tk/actions/workflows/windows.yml/badge.svg)](https://github.com/g41797/matryoshka-tk/actions/workflows/windows.yml)
[![macOS](https://github.com/g41797/matryoshka-tk/actions/workflows/mac.yml/badge.svg)](https://github.com/g41797/matryoshka-tk/actions/workflows/mac.yml)
[![Deploy Documentation](https://github.com/g41797/matryoshka-tk/actions/workflows/docs.yml/badge.svg)](https://github.com/g41797/matryoshka-tk/actions/workflows/docs.yml)


---


Software has two worlds.

- The first moves data.
- The second processes data.

Matryoshka-Tk is a _toolkit_ for the second world.


---

## What Matryoshka-Tk Is For

---

Matryoshka-Tk provides

- tools for the code that runs
  - **after** data enters the system
  - **before** data leaves the system
  - **within** long-running _tasks_

Typical example of such system - _Image processing pipeline_.

Goal of Matryoshka:

- to let developers think in terms of
  - processing
  - inter-tasks communication
  - reusing
  - workflows
- instead of low-level details

---

## Main principles: Intrusion and Type erasure

---

<a href="https://ziglang.org/documentation/0.16.0/std/#std.DoublyLinkedList" target="_blank" rel="noopener noreferrer">std.DoublyLinkedList</a> works with <a href="https://ziglang.org/documentation/0.16.0/std/#std.DoublyLinkedList.Node" target="_blank" rel="noopener noreferrer">Nodes</a>.

Just 

- embed Node to you structs 
- use DoublyLinkedList functions

DoublyLinkedList does not care 

- what's the type of parent struct 
- whether structs in the list have the same type

Because Node already has pointers , DoublyLinkedList 

- does not need allocate wrappers for structs
- uses existing pointers(links)

Terms:

- **Intrusion** — the links are part of the struct
- **Type erasure** —  DoublyLinkedList operates on Node, not on the concrete type

---


Caller 

- follows its own rules 
- can get pointer to the parent struct 
- via <a href="https://ziglang.org/documentation/0.16.0/#toc-fieldParentPtr"  target="_blank" rel="noopener noreferrer">@fieldParentPtr</a>

---


This simple mechanism is the basis of Matryoshka.


---

## PolyNode - smart brother of Node

---

Matryoshka defines its own common node: <a href="https://g41797.github.io/matryoshka-tk/apidocs/#matryoshka.polynode.PolyNode"  target="_blank" rel="noopener noreferrer">PolyNode</a>

Additionally to expected Node functionality, PolyNode supplies <a href="https://g41797.github.io/matryoshka-tk/apidocs/#matryoshka.polynode.PolyHelper"  target="_blank" rel="noopener noreferrer">helper</a> for

- safe upcasting to parent struct
- without direct dealing with @fieldParentPtr


In order to be _Matryoshka compatible_, application struct should 

- embed _PolyNode_
- be allocated '_on heap_'

Such struct called _Item_.

Don't panic regarding allocations - Matryoshka supports 

- effective mechanism of Item reusing
- called Pool

## ...

It provides three building blocks.

- PolyNode
- Mailbox
- Pool

Together they helps you organizes processing.

---

## PolyNode — Smart Brother of Zig's `std.DoublyLinkedList.Node`

As Zig developer, you already familiar with _DoublyLinkedList_ and it's _Node_.

```zig
/// This struct contains only the prev and next pointers and not any data
/// payload. The intended usage is to embed it intrusively into another data
/// structure and access the data with `@fieldParentPtr`.
pub const Node = struct {
  prev: ?*Node = null,
  next: ?*Node = null,
};
```

Embedding (_intrusion_) of Node to structure helps 

- to 'link' structures with different types
- without knowledge about actual type

It helps to _Intrusive Container_ (DoublyLinkedList).

But application still should guess what is the type of parent struct.

```zig
pub const PolyNode = struct {
    node: std.DoublyLinkedList.Node = .{},
    tag: *const anyopaque = undefined,
};
```


## Four building blocks. One principle. Common language.

Every Matryoshka-Tk system is built from _four building blocks_:

- **Master** — execution
- **Item** — state/data/command/...
- **Mailbox** — communication
- **Pool** — resource reuse

They all follow one _principle_:

> **Share by communicating.**

You stop talking about:

- tasks
- futures
- mutexes
- queues

You start talking on Matryoshka-Tk language:

- Masters
- Items
- Mailboxes
- Pools


---


### Master

A **Master** is

- 100% YOUR CODE
- an _Threaded_ Io _task_
- created by _concurrent()_
- usually long running
- process oriented
- works with **Items**
- communicate via **Mailboxes** with another Masters and/or application
- reuses Items via **Pools**


---


### Item

An **Item** is

- YOUR DATA/CODE with embedded Matryoshka struct 
- movable application object
    - PDL Page
    - Image
    - PrintTicket
    - ...
- **allocated** (as all building blocks)
- usually outlive the function that created them

---

### Item and ItemHandle.

The documentation talks about _Item_.      
The API works with an **ItemHandle**.  

You are thinking in terms of:

- read _file_
- write _file_
- close _file_

on API level one of the arguments is _file handle_.

The same is for Matryoshka-Tk API

- you are thinking in terms of _Item_ - Application entity
- API is working with _ItemHandle_ - Matryoshka-Tk entity


---


### Mailbox

A **Mailbox** transfers an Item from one Master to another:

- One Master sends an Item to
  - Mailbox ensures that it's only owner of Item
- Another Master later receives it
  - Mailbox ensures that receiver is only owner of Item

---


### Pool

A **Pool**

- creates new Items
- holds reusable Items

Usually Master

- gets Item from Pool
- process Item
- on finish
  - send Item to another Master for further processing
  - returns Item to Pool

A Pool is not storage.  
An empty Pool is

- not an error
- it is backpressure.

Matryoshka-Tk supports backpressure 'naturally'

---

## Take it easy

Start with Items.

Add a Pool when reuse becomes useful.

Add a Mailbox when communication becomes useful.

Organize long-running tasks as Masters.

Can you describe your application using only

- Masters
- Items
- Mailboxes
- Pools

If
- **yes** - you are on the right way
- no - [you still have the chance](https://github.com/g41797/matryoshka-tk)

---
