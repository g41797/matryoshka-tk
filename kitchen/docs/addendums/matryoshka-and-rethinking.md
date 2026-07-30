# Matryoshka-Tk and Rethinking Patterns
## Inspired by ["Rethinking Classical Concurrency Patterns"](https://drive.google.com/file/d/1nPdvhB0PutEJzdCq5ms6UI58dp50fcAN){:target="_blank"}

The paper is written in Go.

Matryoshka-Tk reaches many of the same conclusions.

But from a different direction.

The paper starts with channels.

Matryoshka starts with who holds the object.

---

# Pattern 1
## Communicate the object

Classic thinking

- Share memory.
- Send notification.
- Receiver finds the object.

Matryoshka

- Send the object itself.
- The right to use it moves with the object.
- No second lookup.

Matryoshka

Mailbox transfers PolyNode.

Not pointer plus signal.

Not index plus signal.

The object.

---

# Pattern 2
## The handoff is the message

Classic

Signal says:

"Something changed."

Receiver must inspect shared state.

Matryoshka

Receiving an object means:

"I own it now."

No additional protocol.

No hidden state.

Who holds it is explicit.

---

# Pattern 3
## Resources are objects

Classic

Signal that a resource became available.

Matryoshka

Pool stores reusable objects.

Pool returns objects.

Pool accepts objects back.

No "resource available" signal.

The object is the signal.

---

# Pattern 4
## No detached notifications

Condition variables split:

- data
- notification

This creates problems.

- forgotten signal
- spurious wakeup
- starvation
- cancellation problems

Matryoshka removes the split.

Mailbox contains data.

Receiving data is notification.

Impossible to receive a notification without data.

---

# Pattern 5
## One object.
## One owner.

Everything has exactly one owner.

Object exists in exactly one place.

Possible places

- Master
- Mailbox
- Pool

Never two.

Never zero.

This becomes the synchronization model.

Not mutexes.

Exclusive access.

---

# Pattern 6
## Synchronize by transfer

Traditional code

Lock.

Modify.

Signal.

Unlock.

Matryoshka

Send object.

Receive object.

Continue.

Synchronization happens naturally.

Because the holder changes.

---

# Pattern 7
## Metadata is an object too

Matryoshka

Mailbox.

Pool.

Even higher-level infrastructure.

Everything can become a PolyNode.

Infrastructure becomes data.

Infrastructure can move.

---

# Pattern 8
## Explicit destinations

Broadcast wakes everyone.

Most wakeups are useless.

Mailbox knows destination.

One sender.

One receiver.

No broadcast.

No guessing.

---

# Pattern 9
## Cancellation is another channel

Matryoshka-Tk uses three independent paths.

DATA

Objects move.

INTERRUPT

Immediate wakeup.

CANCEL

Stop request.

Each path has one purpose.

No mixing.

---

# Pattern 10
## Reuse objects.
## Not allocations.

Pool owns reusable objects.

Applications stop thinking about allocation.

They think about who holds what.

---

# Pattern 11
## Masters own state

Each Master owns its own state.

Communication happens through Mailboxes.

State stays local.

Objects move.

Not memory.

---

# Pattern 12
## Long-lived actors.
## Short-lived jobs.

Masters are long-lived.

Objects are long-lived.

Jobs are short-lived.

Job appears.

Job finishes.

Who holds it remains clear.

---

# Pattern 13
## Infrastructure is boring

Developers do not build synchronization.

They build software.

Infrastructure quietly handles

- exclusive access
- transfer
- reuse

The application stays boring.

---

# Pattern 14
## Architecture before concurrency

Concurrency is an implementation detail.

Architecture decides

- who owns
- who communicates
- who reuses

The runtime only executes the design.

---

# Common Philosophy

Both reach similar principles.

- Communicate instead of sharing.
- Send the thing.
- Remove hidden state.
- Make the holder obvious.
- Reduce synchronization.
- Reduce accidental complexity.

---

# Where Matryoshka Goes Further

The paper communicates values.

Matryoshka communicates who holds the object.

The paper replaces condition variables.

Matryoshka removes doubt about who holds it.

The paper simplifies concurrent code.

Matryoshka simplifies concurrent systems.

The paper is about communication.

Matryoshka is about architecture built on communication.

The holder first.

Communication second.

Concurrency becomes almost boring.  
```
