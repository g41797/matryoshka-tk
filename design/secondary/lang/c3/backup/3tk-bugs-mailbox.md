# Owner thinking — Mailbox

## 1. The important change

The old rule was:

```text
close()
release()
````

with:

```text
release requires closed == true
```

That rule is too weak.

`close()` only changes the mailbox state.

It does NOT mean:

```text
no other call is using the Mailbox object
```

Therefore:

```text
Thread A                         Thread B

receive()
    lock
    ...
                                 release()
                                     lock
                                     closed = true
                                     unlock
                                     free(self)
    ...
    unlock
```

is still possible.

`receive()` has a live pointer to `self`, but `release()` has already freed it.

So the real rule is:

```text
closed != released
```

and:

```text
closed != no users
```

Those are three different states.

---

## 2. Allowing release of an open mailbox is a good API direction

This is better:

```text
close()
    closes the mailbox
    returns remaining items

release(out)
    closes the mailbox if necessary
    returns remaining items
    waits for users
    destroys the mailbox
```

The important semantic distinction becomes:

### `close`

A client operation.

It means:

```text
"Stop accepting/supplying mailbox work and wake everybody."
```

The mailbox remains alive.

### `release`

The owner operation.

It means:

```text
"Close the mailbox, wait until nobody is using it,
then destroy the mailbox object."
```

That is a much cleaner ownership model.

---

## 3. `_close()` is a good internal split

This part is good:

```text
close()
    lock
    _close()
    unlock

release()
    lock
    _close()
    wait for users
    save allocator
    unlock
    destroy synchronization objects
    free memory
```

But `_close()` must have a very precise contract.

It should:

```text
- execute while _mu is locked
- never lock
- never unlock
- mark the mailbox closed
- publish closed_fast
- move queued items to `out`
- wake waiters
```

So:

```c3
fn void Mailbox._close(&self, InnerQueue* out)
{
    // _mu is already locked

    if (self._closed) return;

    self._closed = true;
    self._closed_fast.store(true, RELEASE);

    out.append_queue(&self._oob);
    out.append_queue(&self._regular);

    self._cv.broadcast();
}
```

That is a clean primitive.

---

## 4. Returning `InnerQueue* out` from `_close()` is also good

I would make this explicit:

```c3
fn void Mailbox._close(&self, InnerQueue* out)
```

rather than literally returning an `InnerQueue*`.

The queue is caller-owned storage.

That gives both operations the same mechanism:

```c3
fn void? Mailbox.close(&self, InnerQueue* out)
{
    mtk::@check(out.is_empty(), "close asserts the queue is empty on entry");

    self._mu.lock();
    self._close(out);
    self._mu.unlock();
}
```

and:

```c3
fn void Mailbox.release(&self, InnerQueue* out)
{
    ...
}
```

This also preserves the useful property that the mailbox never allocates storage for the returned items.

---

# 5. But there is a serious problem with "we never guard simultaneous releases"

This is the part I would **not** accept as stated.

Suppose:

```text
Thread A                    Thread B

release(&mb, &a)
                            release(&mb, &b)

lock                       lock
_close()
unlock                     ...
free(mb)
                            ...
                            free(mb)
```

or:

```text
Thread A                    Thread B

lock                       lock
_close()
unlock
                            _close() sees closed
                            unlock
free(mb)
                            free(mb)
```

The second thread can still access the object after the first one has freed it.

That is a double-free/use-after-free problem.

More importantly:

> Once one thread is allowed to free `Mailbox`, there is no operation that another thread can safely perform through the same `Mailbox*`.

Therefore "simultaneous release is not guarded by design" can only be true if the ownership contract says:

```text
There is exactly one owner capable of calling release().
```

If multiple threads may call `release()` on the same pointer, the object needs a lifetime mechanism outside this simple close protocol.

I would therefore state the rule explicitly:

```text
Mailbox operations may be concurrent.

release() is an owner operation.

Only the owner may call release().
```

That is much simpler than trying to make destruction itself multi-owner.

---

# 6. The missing mechanism: active callers

Even if only one thread calls `release()`, you still need to handle:

```text
Thread A                         Owner

receive()
    lock
    ...
                                 release()
                                     lock
                                     _close()
                                     ...
```

If `release()` unlocks and immediately frees, `receive()` may still be executing.

Therefore `release()` needs to know:

```text
How many operations are currently using the mailbox?
```

A simple conceptual state is:

```text
_active
_closed
_releasing
```

For example:

```text
normal:

    active = N
    closed = false

close:

    closed = true
    active unchanged

release:

    closed = true
    releasing = true
    wait until active == 0
    destroy
```

But there is an important ordering requirement:

> A new operation must not increment `active` after `release()` has decided that it can destroy the object.

So the "enter operation" protocol and the release protocol must share the same lock/state transition.

---

# 7. The basic lifetime protocol

Conceptually:

```text
enter:
    lock
    if closed:
        unlock
        return CLOSED

    active++
    unlock

    use mailbox

    lock
    active--
    if active == 0:
        signal/broadcast
    unlock
```

But this needs to be adapted carefully because some mailbox operations already hold `_mu` for their entire operation.

For example `receive()` currently does:

```text
lock
...
wait
...
unlock
```

So it can naturally count itself as an active user while holding the mutex.

The important thing is that:

```text
release()
```

must not free the object until every such active operation has left.

---

# 8. Waiting for active users

The release sequence should conceptually be:

```text
lock

_close(&out)

_mark_releasing()

while (_active != 0)
    wait

save allocator

unlock

destroy condition variable
destroy mutex
free mailbox
```

The actual implementation must account for the fact that the condition variable itself cannot be destroyed until all users are gone.

This is the point of the owner protocol.

---

# 9. Do not hold `_mu` while destroying it

Your proposed sequence:

```text
save allocator locally
unlock
release memory
```

is correct in principle, but there is one missing step.

The synchronization objects must be destroyed before the memory is freed:

```text
lock
close
wait for active == 0
save allocator
unlock

_cv.destroy()
_mu.destroy()

alloc::free(allocator, self)
```

And because `active == 0` is established while holding `_mu`, no mailbox operation should still be using `_cv` or `_mu` after the unlock.

That is the lifetime boundary.

---

# 10. `close()` and `release()` then have a useful asymmetry

This becomes very clean:

```text
close()
    changes state
    returns items
    mailbox remains alive

release()
    changes state if necessary
    returns items
    waits for active users
    destroys mailbox
```

So:

```text
close != destruction
```

and:

```text
release = close + lifetime termination
```

This is a much stronger model than the current:

```text
close first
release later
```

because the API itself can enforce the important transition.

---

# 11. The `defer` question

Your proposed client pattern is good:

```c3
InnerQueue iq;

defer queue_outers_release(&iq);
defer mbox.release(&iq);
```

C3 executes deferred statements in **reverse textual order**. ([c3-lang.org][1])

Therefore the actual order is:

```text
mbox.release(&iq)
queue_outers_release(&iq)
```

That is exactly what you want.

The mailbox must first give the remaining items to `iq`.

Then the client releases those items.

So this is a good pattern:

```c3
InnerQueue iq;

defer queue_outers_release(&iq);
defer mbox.release(&iq);
```

It is effectively:

```text
normal code
    ↓
release mailbox → fills iq
    ↓
release queue contents
```

The declaration order is important and should be documented.

---

# 12. The address passed to both defers

This is also good:

```c3
InnerQueue iq;

defer queue_outers_release(&iq);
defer mbox.release(&iq);
```

Both deferred calls refer to the same local `iq`.

The deferred statements execute when the scope exits, and the variable is still in scope at that point. C3 specifies that `defer` schedules the statement for scope exit. ([c3-lang.org][1])

So the important requirement is simply:

```text
iq must remain alive until both defers execute.
```

A local variable in the same enclosing scope satisfies that.

I would test exactly this case rather than relying only on reasoning.

---

# 13. One important API improvement

I would use the same name and semantics everywhere:

```c3
close(&self, InnerQueue* out)
release(&self, InnerQueue* out)
```

Both require:

```text
out is empty on entry
```

Both produce:

```text
out contains everything that the mailbox owned at the moment of close
```

But with one difference:

```text
close()
    mailbox remains usable as an object,
    but is closed

release()
    mailbox becomes unusable and is destroyed
```

That makes the `InnerQueue` ownership story very easy to explain.

---

# 14. One subtle point: `release()` must not call public `close()`

Do not implement:

```c3
release()
{
    close(&out);
    ...
}
```

if `close()` performs its own lock/unlock.

Your proposed `_close()` split is better:

```c3
release()
{
    self._mu.lock();

    self._close(out);

    // lifetime protocol here

    ...
}
```

and:

```c3
close()
{
    self._mu.lock();

    self._close(out);

    self._mu.unlock();
}
```

This avoids duplicated state-transition logic and avoids lock nesting.

---

# 15. What I would change in the current code

Current:

```c3
fn void Mailbox.release(&self)
{
    always_assert(self._closed, ...);

    self._cv.destroy()!!;
    self._mu.destroy();

    Allocator a = self._alloc;
    alloc::free(a, self);
}
```

I would change the design to:

```text
Mailbox.close(out)
    ↓
lock
_close(out)
unlock


Mailbox.release(out)
    ↓
lock
_close(out)
mark destruction/release
wait for active callers
save allocator
unlock
destroy cv
destroy mutex
free self
```

And remove the rule:

```text
release requires closed
```

because `release()` itself closes.

---

# 16. But don't call the problem "simultaneous release"

The fundamental problem is broader:

```text
destruction while another operation is using the object
```

There are two cases:

### Case A — release vs ordinary API call

```text
release()
receive()
send()
poll()
len()
wake_all()
...
```

This MUST be handled by the lifetime protocol.

### Case B — release vs release

```text
release()
release()
```

This cannot be safely solved merely by `_close()`.

You need either:

```text
single-owner release
```

or:

```text
separate external lifetime/reference ownership
```

For Matryoshka, I strongly prefer the first.

The mailbox can be concurrently used.

The mailbox can have many producers/consumers.

But:

```text
the owner destroys the mailbox
```

should remain a single-owner operation.

---

# 17. Final owner model

I think the clean model is:

```text
                    Mailbox
                       │
             ┌─────────┴─────────┐
             │                   │
        client access        owner access
             │                   │
      send/receive/etc.       release()
             │                   │
        concurrent             exclusive
             │                   │
             └───────┬───────────┘
                     │
                   close
                     │
              no new work
                     │
              wait for users
                     │
                 destroy
```

And the ownership rule is:

> **The mailbox is concurrently usable, but destruction belongs to one owner.**

That is the important design boundary.

---

## Verdict

Your direction is **good and worth implementing**:

* `release()` should be able to close an open mailbox.
* `close()` should remain the non-destructive client operation.
* `_close(out)` should be the lock-held primitive.
* `release(out)` should use the same output queue.
* `release()` should wait for active mailbox operations before destruction.
* The allocator should be copied locally before unlocking.
* `defer` with the queue cleanup declared first and mailbox release declared second gives the desired reverse-order cleanup. ([c3-lang.org][1])

But I would **not** keep this statement:

```text
We never guard simultaneous releases - by design.
```

Replace it with:

```text
release is an owner operation.
Only the owner may release a Mailbox.
Concurrent mailbox operations are supported.
Concurrent release calls are not supported.
```

That gives you a real ownership rule instead of leaving a double-free race as an intentional property.

```
```

[1]: https://c3-lang.org/implementation-details/specification/?utm_source=chatgpt.com "C3 Specification - C3 Programming Language"
