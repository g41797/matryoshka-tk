# Design: The Language of Matryoshka

## Why this document exists

Matryoshka introduces only a few concepts.

Those concepts must have one meaning everywhere.

This document establishes the architectural vocabulary used by the project.

It deliberately describes the architecture, not the implementation.

---

# Design foundation

Matryoshka is built on a simple concurrency principle.

> **Share by communicating.**

Rather than sharing access to application objects, communicate the application objects themselves.

An Item moves from one Master to another.

The Item is not used simultaneously by multiple Masters.

This idea follows the principle described by Bryan C. Mills:

> **Share the thing by communicating the thing.**

The same principle applies to reusable resources.

Pools communicate reusable Items.

Resource limits are resources too.

---

# Four architectural building blocks

A Matryoshka system consists of only four architectural concepts.

```
Master
Item
Mailbox
Pool
```

Everything else exists to support these four concepts.

---

# Master

A **Master** is an Io task that follows the Matryoshka rules.

Every Master is created by `io.concurrent()`.

Not every task is a Master.

A Master:

* performs work
* maintains application state
* creates and processes Items
* communicates with other Masters through Mailboxes
* obtains reusable Items from Pools

Some Masters also coordinate other Masters.

A worker is simply a Master with a dedicated responsibility.

---

# Item

An **Item** is the fundamental building block of a Matryoshka system.

An Item is an application object.

Examples include:

* Request
* Response
* Connection
* Session
* Timer
* Buffer

Items are allocated.

They are expected to live longer than the function that created them.

An Item may:

* move between Masters
* wait inside a Mailbox
* be stored inside a Pool
* participate in intrusive containers

The important rule is simple:

> **An Item is in exactly one place at any moment.**

Matryoshka is designed to prevent shared use of Items.

Instead of sharing an Item, pass the Item itself.

---

# Mailbox

A **Mailbox** communicates Items between Masters.

A Mailbox receives an Item from one Master.

It later delivers that Item to another Master.

The Mailbox does not know the concrete Item type.

It simply transfers Items.

---

# Pool

A **Pool** stores reusable Items.

Instead of destroying an Item after use, a Master may return it to a Pool.

Another Master may later obtain the same Item and use it again.

Pools communicate reusable resources.

---

# The architectural rule

Matryoshka encourages one programming style.

Do not share Items.

Communicate Items.

Move Items between Masters.

Reuse Items through Pools.

The default operation is movement.

Not sharing.

---

# Implementation

The concepts above describe the architecture.

The implementation uses additional mechanisms.

These mechanisms are not architectural concepts.

They exist only to make the architecture possible.

## PolyNode

Every Item embeds a `PolyNode`.

`PolyNode` is an implementation mechanism.

It enables:

* intrusive containers
* runtime type identification
* type-erased communication

Application code works with Items.

Matryoshka internally works with the embedded `PolyNode`.

This approach uses composition because Zig has no inheritance or base classes.

## Handles

Matryoshka APIs operate on handles rather than raw pointers.

Handles make APIs explicit and stable.

They are an implementation detail.

Architecturally, a Master communicates Items.

## ParentHandle

A pointer to an embedded `std.DoublyLinkedList.Node`, used as a handle to the  
struct that embeds it.

The mechanism is part of Zig.

* `std.DoublyLinkedList` is handed the `*Node`.
* `@fieldParentPtr` gets back to the parent struct.
* Matryoshka invents nothing here.

Only the term is ours. The book needed a word for the thing an `ItemHandle` is  
the analog of.

`ParentHandle` and `ItemHandle` are not the same.

* `ParentHandle` is plain Zig. It carries no type information.
* `ItemHandle` is Matryoshka. It is a `*PolyNode`, so it carries a tag, and the
  cast back is checked.

The term appears in Part 2 of [matryoshka-api-reference-041.md](matryoshka-api-reference-041.md),  
and in `tests/zig_mechanisms.zig`. It is not used in `src/`.

---

# Reading Matryoshka documentation

Throughout the documentation:

**Master** always means an Io task following the Matryoshka rules.

**Item** always means an application object participating in Matryoshka.

**Mailbox** always means communication between Masters.

**Pool** always means reuse of Items.

**PolyNode** always refers to the internal mechanism that enables these concepts.

Whenever possible, the documentation speaks about Items rather than pointers, nodes, or implementation details.

The architecture comes first.

The implementation exists to support it.
