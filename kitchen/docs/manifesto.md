
---

## Two Different Worlds

Most software systems have two very different parts.

### The I/O part

This part deals with the outside world.

* Sockets.
* Files.
* Timers.
* Event loops.
* Synchronization.
* Operating system APIs.

The I/O part

* requires low-level programming
* requires understanding how the platform works
* has its own specialists and its own way of thinking

### The Process part

This is where the application does its real work.

For example:

* Image processing.
* Video transcoding.
* Financial calculations.
* Business workflows.
* Data analysis.

Most developers specialize in this layer.

They

* understand their domain
* want to solve domain problems
* usually do not want to spend time learning unrelated

  * APIs
  * frameworks
  * infrastructure

I/O developers and Process developers often speak *different languages*.

## What Matryoshka-Tk Is For

Matryoshka-Tk

* is designed for the Process part
* does **not** replace an I/O library
* does **not** solve

  * networking
  * polling
  * file handling
  * operating system integration

Instead, it provides

* building blocks for the code that runs

  * **after** data enters the system
  * **before** data leaves the system

Its goal is

* to let developers think in terms of

  * processing
  * messages
  * pools
  * workflows
* instead of low-level I/O details

The funny part is that Matryoshka-Tk was created by an I/O developer.

Me.

## Remember

* I/O moves data.
* Matryoshka-Tk organizes work.

---

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

- an _Threaded_ Io _task_
- created by _concurrent()_
- follows the Matryoshka-Tk rules
- holds its own state
- works with Items
- communicate with another Masters and/or application


---


### Item

An **Item** is

- movable application object
  - Request
  - Connection
  - Session
  - Buffer
  - Job
  - ...
- **allocated** (as all building blocks)
- outlive the function that created them

The one rule that matters:

> An Item is in exactly one place at any moment.

**ONE PLACE**:

- or Master uses it
- or a Mailbox holds it
- or a Pool holds it

> **Never several at once**.

---

### Item and ItemHandle.

The documentation talks about _Item(s)_.      
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

A **Mailbox** moves an Item from one Master to another:

- One Master places an Item in
  - Mailbox ensures that it's only owner of Item
- Another Master later receives it
  - Mailbox ensures that receiver is only owner of Item

---


### Pool

A **Pool**

- create new Items
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

##  Take it easy

Start with Items.

Add a Pool when reuse becomes useful.

Add a Mailbox when communication becomes useful.

Organize long-running tasks as Masters.

Each step is useful right away.

Each step stays useful after the next one.

Can you describe your application using only

- Masters
- Items
- Mailboxes
- Pools

If

- **yes** - you are on the right way
- no - [you still have the chance](https://github.com/g41797/matryoshka-tk){target="_blank" rel="noopener"}

---

## Master is King

Master is YOUR CODE.

Only Master

- makes decisions
- owns application state
- talks to building blocks

Another building blocks are "slaves":

- Mailbox - communication
- Pool - storage/reuse
- Item - "data"

---

Be Master **of your** systems.
