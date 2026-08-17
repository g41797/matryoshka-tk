# Matryoshka and std.concurrency

Two things called "mailbox". They are not the same thing, and the difference is
not a matter of quality.

This note is for a D developer deciding which to use, and for a reviewer asking
why a project took a dependency instead of using the standard library.

---

## The short version

`std.concurrency` is an **actor model**. It gives you isolation, enforced by the
compiler, at the cost of allocating and copying every message.

Matryoshka is **transport plumbing**. It moves one mutable pointer from one
thread to another without allocating or copying, and leaves isolation to you.

```text
std.concurrency     no shared mutable state, by construction
Matryoshka          exactly one owner of shared mutable state, by discipline
```

Both arrive at "one owner". They arrive from opposite directions.

**Use `std.concurrency` unless you have a specific reason not to.** The reasons
are real and this document lists them, but they are reasons, not defaults.

---

## Terminology, side by side

| std.concurrency | Matryoshka | same thing? |
|---|---|---|
| `Tid` | `Mbox*` | no — see below |
| `MessageBox` | `Mbox` | close |
| `Message` (a `Variant`) | `ItemHandle` (`PolyNode*`) | no |
| `send(tid, args)` | `mbx.send(slot)` | close |
| `receive(handlers...)` | `mbx.receive(slot)` + `fromSlot!T` | no |
| `receiveOnly!T()` | `receive` then `mustFromSlot!T` | close |
| `receiveTimeout(dur, ...)` | `receive(slot, dur)` | yes |
| `prioritySend` | `send_oob` | close |
| `setMaxMailboxSize` | the pool's item budget | no — different place |
| `OwnerTerminated` | `Status.closed` | close |
| `register` / `locate` | — | not provided |
| `spawn` / `spawnLinked` | — | not provided |

The row that matters most is the first.

**A `Tid` is a thread.** It comes from `spawn` or `thisTid`. One per thread, owned
by that thread, created with it and gone with it.

**An `Mbox` is an object.** You can have twenty per thread, none at all, store one
in a struct, pass one to a function, or send one through another mailbox — a
mailbox is itself a poly item.

That is not a feature comparison. It is a different shape.

---

## The wall you hit first

`std.concurrency.send` refuses mutable aliasing at compile time.

```d
send(tid, request);        // Request* — does not compile
```

The check is `hasUnsharedAliasing`. Anything with a mutable indirection is
rejected. You may send value types, `immutable`, or `shared`.

That check is the whole safety story. It is what makes `std.concurrency` genuinely
race-free rather than merely conventional.

It also means it cannot express what Matryoshka does. Moving a mutable
`Request*` and having the sender lose access is exactly the thing the check
forbids — because the compiler cannot see that the sender gave it up.

The workarounds all cost you the guarantee:

```d
send(tid, cast(shared) request);   // now you are on your own anyway
send(tid, cast(size_t) request);   // launder the pointer through an integer
```

If you are doing either of those, `std.concurrency` is no longer providing the
safety it advertises. You have kept the allocation and the `Variant` and thrown
away the reason for them.

That is the honest test: **if your messages are pointers to mutable objects,
`std.concurrency` is not doing its job for you.**

---

## Cost per message

`std.concurrency`, minimum, per send:

```text
1. construct a Variant from the argument tuple
2. allocate a list node in the MessageBox
3. lock, link, signal, unlock
4. the payload is copied into the Variant
```

Matryoshka, per send:

```text
1. lock, link, signal, unlock
```

The item's links are already in the item. Nothing is allocated. Nothing is
copied. The object does not move.

No numbers here, because the ratio depends entirely on payload size and GC
pressure. The structural claim is enough: one path allocates per message and one
does not, and the difference compounds through the collector.

For a 64-byte control message at a thousand per second, this is irrelevant. For
a 64 KB buffer at a hundred thousand per second, it is the whole problem.

---

## Where backpressure lives

This is a design difference worth understanding rather than tallying.

```text
std.concurrency     setMaxMailboxSize(tid, n, OnCrowding.block)
                    bounds ONE queue's depth

Matryoshka          the pool holds a fixed number of items
                    bounds TOTAL items in the system
```

Ten mailboxes with a limit of 1000 each bounds you at 10,000 messages. Ten
mailboxes fed by a pool of 1000 items bounds you at 1000, no matter how they
distribute.

The pool version bounds memory. The per-queue version bounds a queue. For
middleware, memory is the thing you actually need bounded.

`OnCrowding.throwException` and `OnCrowding.ignore` have no Matryoshka
equivalent, because an exhausted pool returns `Status.notCreated` and the caller
decides.

---

## What std.concurrency gives you that Matryoshka does not

Be clear about this, because the list is not short.

**Compiler-enforced isolation.** The big one. You cannot data-race on a payload.
Matryoshka's Slot makes single ownership visible and, in D, makes copying a Slot
a compile error — but nothing stops you keeping the raw pointer you took out of
one.

**Type-dispatched receive.**

```d
receive(
    (int i)      { ................ },
    (string s)   { ................ },
    (Shutdown _) { ................ },
);
```

That is genuinely pleasant, and Matryoshka's tag-check-then-cast is not as
pleasant:

```d
if (auto r = fromSlot!Request(s))       { ................ }
else if (auto c = fromSlot!Command(s))  { ................ }
```

**Thread lifecycle.** `spawn`, `spawnLinked`, `ownerTid`, `LinkTerminated`,
`OwnerTerminated`. Supervision trees fall out of this. Matryoshka has none of
it — you bring your own threads and your own shutdown.

**A name registry.** `register("logger", tid)` and `locate("logger")`. Matryoshka
leaves naming to the application.

**Fibers.** `Generator` and fiber-based `Tid`s. Matryoshka is thread-based.

**Zero dependencies, and every D developer already knows it.** Do not undervalue
this. A reviewer reading `receive((Request r) { ... })` needs no context. A
reviewer reading `mustFromSlot!Request(s)` needs a document.

---

## What Matryoshka gives you that std.concurrency does not

**It works without a GC.** This is not a tuning difference. `std.concurrency` is
GC-only: `Variant`, the message list, and `send` all allocate. There is no
`@nogc` path and no `-betterC` path. If your application is Manual mode, the
standard library is not an option — not a slow option, not an option.

**Zero copy for large payloads.** The pointer moves. A 1 MB buffer costs the same
to send as a 16-byte one.

**Zero allocation on the message path.** With a pool, steady-state allocation is
zero, so collections become rare even in Managed mode. This is the thing that
makes a GC application viable at rate.

**Mailboxes as objects.** Many per thread. Stored in structs. Passed as values.
Created before the thread that will drain them, and outliving it. A mailbox is
itself a poly item, so a mailbox can be sent through a mailbox.

**Heterogeneous queues without boxing.** One list, items of different types,
distinguished by tag, no wrapper allocated per element. `std.concurrency` gets
heterogeneity from `Variant`, which is where the allocation comes from.

**Status codes, not exceptions.** `Status.closed` instead of `OwnerTerminated`
thrown at you. Necessary for `nothrow`, and necessary for `@nogc`.

**Close returns your items.** `mbx.close()` hands back everything still queued so
you can return it to the pool. `std.concurrency` has no equivalent; a terminated
thread's mailbox contents are simply collected.

**Out-of-band messages with defined ordering.** Every OOB precedes every regular
message, and the invariant holds under contention. `prioritySend` is close, but
an unhandled priority message throws in the receiver, which is a different
contract.

---

## Choosing

Use **`std.concurrency`** when all of these hold:

```text
[ ] The application is Managed mode anyway.
[ ] Payloads are small, or naturally immutable.
[ ] One logical inbox per thread is the right model.
[ ] Message rate is thousands per second, not millions.
[ ] You want spawn/link/supervision for free.
```

Use **Matryoshka** when any one of these holds:

```text
[ ] Manual mode, -betterC, or a measured latency budget.
[ ] Payloads are large buffers you cannot afford to copy.
[ ] Messages are mutable objects whose ownership transfers.
[ ] You need more than one mailbox per thread, or a mailbox
    decoupled from any thread's lifetime.
[ ] You need total item memory bounded, not per-queue depth.
[ ] Allocation per message is unacceptable.
```

The first box in the second list is the common one. If the application is
Manual, there is no decision to make.

---

## Using both

They are not exclusive, and the split is natural:

```text
control plane      std.concurrency
                   start, stop, reconfigure, report, supervise.
                   Low rate. Small messages. Wants spawn and linking.

data plane         Matryoshka
                   the actual traffic. High rate. Large payloads.
                   Wants zero copy and a bounded pool.
```

A worker thread can hold both: a `Tid` for lifecycle and an `Mbox*` for work.
They do not interfere — different queues, different concerns.

This is usually the right answer for a service, and it is worth saying to a
reviewer who asks why the standard library was not enough. It was, for half the
problem.

---

## The layering argument

The cleanest way to see the relationship:

> `std.concurrency` could be implemented on top of Matryoshka. The reverse is
> not possible.

An actor layer needs a queue that moves messages between threads. Matryoshka is
that queue, minus the policy. Add a `Variant` item type, one mailbox per thread,
`spawn`, and a registry, and you have rebuilt `std.concurrency` — with pooling
underneath it.

Going the other way is blocked by the aliasing check. You cannot build zero-copy
mutable transfer on a transport that refuses mutable aliasing by design.

That asymmetry is the whole comparison. One is a policy; the other is the
mechanism a policy is built from.

---

## One correction worth stating

`std.concurrency`'s `Tid` and the `register`/`locate` registry were designed with
out-of-process messaging in mind, and the module documentation says so.

Phobos ships no remote transport. There is no wire format, no serialization
layer, and no network `Tid`. Everything in `std.concurrency` is in-process.

Worth knowing before it appears in a design as an assumed capability.

---

## Summary

| | std.concurrency | Matryoshka |
|---|---|---|
| model | actor / isolation | ownership transfer |
| isolation enforced by | the compiler | discipline, plus the Slot |
| mutable pointer payloads | forbidden | the point |
| allocation per message | yes — `Variant` + node | none |
| copy per message | yes | none |
| GC required | yes | no |
| `-betterC` | no | yes, in Manual mode |
| `@nogc` | no | yes, in Manual mode |
| mailboxes per thread | exactly one | any number |
| mailbox is a value you can pass | no | yes |
| heterogeneous queue | via `Variant` | via tag, no boxing |
| backpressure bounds | one queue's depth | total items |
| errors reported by | exceptions | status codes |
| close returns queued items | no | yes |
| thread lifecycle | `spawn`, `spawnLinked` | not provided |
| name registry | yes | not provided |
| fibers | yes | not provided |
| in the standard library | yes | no |
| reviewer needs a document | no | yes |

---

## The simple rule

If your messages are values, use `std.concurrency`.

If your messages are objects whose ownership moves, and you cannot afford to
allocate or copy them, that is what Matryoshka is for.

If you are in Manual mode, the question does not arise.

Agreed, and the doc understates it. I listed "no thread lifecycle" under what `std.concurrency` gives you — it belongs on the other side of the table. Not owning the thread is why an `Mbox` can be created before any thread exists, handed to several, and outlive all of them.

It also sharpens the aliasing argument. `std.concurrency.spawn` applies the same `hasUnsharedAliasing` check to its arguments:

```d
spawn(&worker, mbx);                 // Mbox* — does not compile
spawn(&worker, cast(shared) mbx);    // compiles, guarantee gone
```

So even for the one job it would do for you, it refuses the mailbox. Meanwhile:

```c
pthread_create(&tid, null, &entry, mbx);   // void*, no ceremony, no allocation
```

## What "suitable" means in D, concretely

**Any pthread can drain a mailbox.** A pthread condvar doesn't care whether druntime created the thread. That is what makes the agnosticism real rather than aspirational.

**Managed mode adds one requirement:** a thread druntime didn't create must call `thread_attachThis()` before touching items, because in Managed mode the items are GC memory and an unattached stack isn't scanned. Manual mode has no such requirement.

**Manual mode subtracts one option:** `core.thread.Thread` is a class, so it is GC-allocated, and a delegate closure passed to it allocates too. In Manual mode you go to `pthread_create` / `CreateThread` directly. Which is fine — the `void*` argument is exactly the shape you want.

## The one place the claim doesn't hold

Fibers.

`Condition.wait` blocks the carrier thread. A fiber calling `receive` parks every other fiber on that thread, not just itself. So "any execution context" means any *thread*, not any scheduler.

This is precisely what `Io.Mutex` and `Io.Condition` buy you in Zig 0.16 — the primitive knows about the runtime and can yield instead of block. D has no integration point, so the D port genuinely loses that, as noted in the porting analysis.

If a fiber scheduler ever needs to drain a mailbox, the options are `try_receive` plus yield, or an eventfd/pipe the scheduler can poll. Neither belongs in the toolkit; both belong in whatever integrates it.

## Ordering, since you raised spawn

The teardown sequence is the part that bites:

```text
close()      →  marks closed, broadcasts, hands back queued items
join()       →  every blocked receiver has observed Status.closed and left
destroy()    →  now safe
```

Destroying before joining is a use-after-free on the mutex itself, and it looks like a random crash in `pthread_cond_broadcast`. Worth one line in the mailbox docs.

I can fold all of this into the comparison doc — moving lifecycle to the Matryoshka column and adding the fiber caveat — if you want it consistent.

No — you can pass it. My sentence was about `std.concurrency.spawn` specifically and read as a general claim. That was sloppy phrasing on my part.

Only `spawn` applies the aliasing check, because that check *is* its safety model. The other two ways to start a thread have no such check.

**`core.thread.Thread` — works, Managed mode:**

```d
auto mbx = new Mbox(...);

auto t = new Thread({ worker(mbx); });
t.start();
```

No check, no cast. The delegate closure captures `mbx` as an ordinary mutable pointer. The closure itself is GC-allocated, so this is a Managed-mode option.

**`pthread_create` — works everywhere, including Manual and betterC:**

```d
extern(C) void* entry(void* arg) nothrow
{
    auto mbx = cast(Mbox*) arg;
    ................
    return null;
}

pthread_t tid;
pthread_create(&tid, null, &entry, mbx);
```

Zero allocation, zero ceremony. This is the one Manual mode uses.

**`std.concurrency.spawn` — needs a cast:**

```d
static void worker(shared Mbox* m)
{
    auto mbx = cast(Mbox*) m;
    ................
}

spawn(&worker, cast(shared) mbx);
```

Compiles and runs correctly. The cast is safe here in fact — a mailbox is internally synchronised, which is exactly what `shared` is supposed to mean — but the compiler is taking your word for it rather than checking.

So the accurate version of my claim is narrower: **`spawn` cannot type-check a mailbox handoff, so if you use it you are asserting the safety yourself.** That is a comment on `std.concurrency`'s model, not a limit on Matryoshka. Passing an `Mbox*` to a thread is routine, and the pthread form is the one the design is actually shaped for.


