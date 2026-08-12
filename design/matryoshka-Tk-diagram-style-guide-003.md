# Matryoshka-Tk Diagram Style Guide

> A guide for communicating software architecture using Matryoshka-Tk notation.

Change from -002: banned-word pass. `Scalable` replaced with a plain  
statement of the requirement, and the hold-language pass finished here —  
"Ownership moves." → "The holder changes.", and the section that carried the  
same word in its title is now `# Holding`. No notation change.

---

# Goal

The notation is a communication tool.

Not an implementation tool.

Not a drawing tool.

Its purpose is simple.

Help people discuss software architecture.

---

# Audience

The primary audience is a software engineer.

The notation should also be readable by

- architects
- reviewers
- maintainers
- new team members

No previous Matryoshka-Tk knowledge should be required.

---

# Philosophy

Architecture first.

Implementation second.

Code last.

The notation should explain

- what the system is
- how the system is organized
- how work moves

The notation should not explain

- how algorithms work
- how code is written
- how data structures are implemented

---

# Three abstraction levels

Every diagram belongs to exactly one level.

Never mix levels.

---

## Level 1 — External

Describe capabilities.

Describe behavior.

Describe the system as a product.

Examples

- Receives requests.
- Stores files.
- Processes video.
- Works with limited memory.
- Handles growing load.
- Fault tolerant.

Never describe implementation.

---

## Level 2 — Architecture

Describe responsibilities.

Describe hold.

Describe communication.

Show

- Masters
- Mailboxes
- Pools
- Items

Describe

- who owns
- who communicates
- who executes

---

## Level 3 — Implementation

Describe mechanisms.

Examples

- ItemHandle
- PolyNode
- intrusive lists
- lock-free queue
- allocator

This level normally belongs

in implementation documentation.

Not architecture documentation.

---

# Domain first

Architecture diagrams use domain language.

Draw

- Request
- Response
- Connection
- Frame
- VideoBuffer
- Shutdown!

Do not draw

- ItemHandle
- PolyNode
- Node
- QueueNode

Mailbox and Pool know ItemHandle.

The reader does not.

---

# One diagram

Every diagram answers one question.

Examples

- What are the Masters?
- How does work flow?
- Where is concurrency?
- Where is hold?
- Where is backpressure?
- How is shutdown propagated?

If a diagram answers many questions

split it.

---

# Progressive disclosure

Build understanding gradually.

Example

- external view
- system overview
- main flow
- worker farm
- hold
- memory reuse
- complete architecture

Never start

with the most complicated diagram.

---

# Draw architecture

Draw responsibilities.

Draw communication.

Draw hold.

Draw concurrency.

Avoid

- UML
- sequence diagrams
- class diagrams
- object graphs

---

# Draw for humans

Imagine

- a whiteboard
- a notebook
- README.md
- a terminal

If a human avoids drawing it

it is too complicated.

---

# Keep diagrams small

Prefer

- many diagrams
- one idea each

Instead of

- one huge diagram
- many unrelated ideas

---


# ASCII first

The notation is ASCII first.

Every diagram should be easy to type.

Every diagram should be easy to edit.

Every diagram should be readable

- in Markdown
- in GitHub
- in a terminal
- in plain text

Prefer

- V
- ^
- >
- <
- |
- -
- =
- ()
- []
- {}

Avoid Unicode symbols

unless they significantly improve readability.

---


# Mailboxes

Mailbox represents communication.

Mailbox is passive.

Mailbox owns no behavior.

Mailbox may be

- horizontal
- vertical

Mailbox may connect

- one producer
- many producers
- one consumer
- many consumers

Choose the layout

that communicates best.

---

# Pools

Pool represents hold.

Pool represents reuse.

Pool is passive.

Pool does not communicate.

Pool usually appears

beside the communication flow.

Pool never connects directly

to a Mailbox.

---

# Masters

Master executes.

Master owns.

Master decides.

Master communicates

only through Mailboxes.

Master interacts with Pools

through hold.

---

# Items

Items move.

The holder changes.

Items are never shared.

Items have domain names.

Examples

- Request
- Chunk
- Frame
- Connection
- Shutdown!

---

# Flow

Communication has direction.

Draw movement.

Not connectivity.

The diagram should feel alive.

---

# Holding

Communication

moves Items.

Pools

manage hold.

These are different relationships.

Show them differently.

---

# Multiple workers

Show one worker

when enough.

Show many workers

when it improves understanding.

Compact notation

and expanded notation

are equally valid.

Choose clarity.

---

# Orientation

Orientation has no meaning.

Horizontal is valid.

Vertical is valid.

Mixed is valid.

Rotate freely.

Choose

the easiest layout

to read.

---

# Text

Use simple English.

One idea per line.

Short sentences.

Staccato rhythm.

Avoid nested thoughts.

Every line

should introduce

one new idea.

---

# Naming

Prefer domain names.

Good

- Request
- Frame
- Stream
- Connection
- VideoBuffer

Avoid generic names.

Examples

- Object
- Data
- Message
- Struct
- Node

---

# Whiteboard rule

Every diagram

should be drawable

from memory

after a short discussion.

If not

simplify it.

---

# README rule

Every diagram

should remain readable

- in Markdown
- in plain text
- in a terminal
- without colors
- without rendering

ASCII first.

Everything else

is optional.

---

# Reader rule

The reader should understand

the idea

before noticing

the notation.

Notation supports communication.

Notation never becomes

the subject.

---

# Final checklist

Before publishing

ask yourself

- Does this answer one question?
- Is the abstraction level consistent?
- Is implementation hidden?
- Are Item names domain-oriented?
- Is communication obvious?
- Is hold obvious?
- Is concurrency obvious?
- Is the diagram easy to redraw?
- Does it fit naturally in a README?
- Can it be understood in one minute?
- Would I draw it on a whiteboard?

=============================================

I completely agree. That's a much better convention.

If a single `|` were used, diagrams like this become ambiguous:

```text
{ Master }
    |
[ Pool ]
```

Is that:

* a mailbox?
* a connection?
* hold?
* just spacing?

The reader has to guess.

Using **double vertical bars** makes the symbol immediately recognizable as a **vertical Mailbox**, just as `==========` is immediately recognizable as a horizontal Mailbox.

So the notation becomes:

```text
Horizontal Mailbox

==========

Vertical Mailbox

||
||
||
```

Flow is separate:

```text
Horizontal

>>>

<<<

Vertical

VVV

^^^
```

This also keeps the notation orthogonal:

| Concept | Horizontal    | Vertical      |   |           |
| ------- | ------------- | ------------- | - | --------- |
| Mailbox | `==========`  | `             |   | ` stacked |
| Flow    | `>>>` / `<<<` | `VVV` / `^^^` |   |           |

I think this is a significant improvement because every symbol now has exactly one meaning.

* `=` → horizontal Mailbox
* `||` → vertical Mailbox
* `>` / `<` → horizontal movement
* `V` / `^` → vertical movement

No symbol is overloaded, which is exactly what a notation should strive for.
