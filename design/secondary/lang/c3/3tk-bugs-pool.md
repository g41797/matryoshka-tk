# 3tk Pool — implementation review

Comments are ignored. This review is based on the implementation and its actual control flow.

## 1. Main result

The pool has the same fundamental lifetime problem as the mailbox:

> `close()` is not the same operation as `release()`.

Closing makes the pool unusable.

It does **not** make the `Pool` object safe to destroy.

The current `release()` is therefore unsafe even after `close()`.

The most important problem is not the mutex itself. It is the fact that `get()` and `put()` deliberately execute hooks outside `_mu`.

That creates calls which are still using the `Pool` after they have released `_mu`.

The new ownership model should therefore be applied to the pool as well:

- `close()` closes the pool for clients.
- private `_close()` performs the state transition while `_mu` is already held.
- `release()` is a normal synchronized pool operation.
- `release()` closes the pool if necessary.
- `release()` waits until no other operation can still access the pool.
- only then is the pool memory destroyed.

There is one additional issue specific to the pool:

> `on_close()` itself can currently race with `on_get()` / `on_put()`.

That needs to be resolved as part of the lifetime design.

---

# 2. `release()` is currently unsafe

Current logic:

```c3
fn void Pool.release(&self)
{
    always_assert(self._closed, "releasing an open pool");
    self._cv.destroy()!!;
    self._mu.destroy();
    Allocator a = self._alloc;
    alloc::free(a, self._buckets);
    alloc::free(a, self);
}
````

Checking `_closed` does not establish that the pool is unused.

Example:

```text
Thread A                         Thread B

put()
  lock
  take item
  unlock
  on_put(...)
                                 close()
                                   lock
                                   _closed = true
                                   unlock
                                   on_close(...)

                                 release()
                                   sees _closed
                                   destroys pool
                                   frees buckets
                                   frees Pool

  on_put returns
  lock                    <-- use-after-free
```

There is also a simpler `get()` version:

```text
Thread A                         Thread B

get()
  lock
  unlock
  on_get(...)

                                 release()
                                   free Pool

  on_get(...)
  return
```

So the current assertion:

```c3
always_assert(self._closed, ...)
```

only checks **state**, not **ownership/lifetime**.

Your new mailbox conclusion applies directly here.

---

# 3. `get()` makes the problem unavoidable

This part is intentional:

```c3
self._mu.unlock();
self._hooks.on_get(want, in_pool, slot);
```

That means the pool mutex does not protect the lifetime of the pool.

While `on_get()` executes:

* another thread can call `close()`
* another thread can call `is_closed()`
* another thread can call `release()`
* another thread can call another `get()`
* another thread can call `put()`

Therefore the pool needs a lifetime mechanism independent of `_mu`.

The same is true for `put()`:

```c3
self._mu.unlock();
self._hooks.on_put(in_pool, &mine, &extra);
self._mu.lock();
```

The hook is outside the mutex by design, so `release()` must know that the operation is still active.

---

# 4. `close()` has a second lifetime problem

The current `close()` does:

```c3
self._mu.lock();

self._closed = true;
self._closed_fast.store(true, RELEASE);

...

self._cv.broadcast();
self._mu.unlock();

self._hooks.on_close(&remaining);
```

This creates an important race.

Suppose:

```text
Thread A                         Thread B

get()
  unlock
  on_get(...)

                                 close()
                                   closed = true
                                   unlock
                                   on_close(...)

  on_get(...) still running
```

Now `on_close()` can execute concurrently with `on_get()`.

Whether that is acceptable depends on the hook contract.

But the current implementation does not provide any synchronization between them.

This is especially important because the hook object is stored in:

```c3
PoolHooks _hooks;
```

and its implementation context may be shared by all three hooks.

If the intended rule is:

> hooks may run concurrently with each other

then that must explicitly include:

```text
on_get vs on_put
on_get vs on_close
on_put vs on_close
on_close vs on_close
```

If that is **not** intended, the implementation must enforce the restriction.

For a pool lifetime design, I recommend the stronger and simpler rule:

> `on_close()` must not start until all operations that were already in progress have finished.

That gives a much cleaner ownership boundary.

---

# 5. Recommended operation-lifetime model

The pool needs two separate concepts:

### Pool state

```text
OPEN
CLOSED
```

### Pool lifetime

```text
ACTIVE OPERATIONS
```

`_closed` answers:

> Can a new operation use the pool?

An operation counter answers:

> Can the Pool object still be destroyed?

These are different questions.

Conceptually:

```text
                 close
                   |
                   v
OPEN ----------> CLOSED
                   |
                   |
             existing operations
                   |
                   v
             active == 0
                   |
                   v
                release
```

The important rule is:

> Once closed, no new operation starts, but operations already admitted are allowed to finish.

---

# 6. `release()` should not require the caller to close first

I agree with your mailbox direction.

For the pool:

```c3
release()
```

should mean:

1. acquire the pool's synchronization;
2. close the pool if it is still open;
3. prevent new operations;
4. wait until all other operations have finished;
5. obtain/finish destruction of the remaining items;
6. save allocator locally;
7. destroy synchronization objects;
8. free buckets;
9. free the Pool.

So:

```text
close()
```

means:

> "Stop accepting new users."

while:

```text
release()
```

means:

> "Stop accepting new users, wait for everybody already using it, then destroy it."

That is much safer than:

```text
close();
release();
```

being two separate caller responsibilities.

---

# 7. Private `_close()` is a good fit

The pool should have the same internal split you proposed for mailbox.

Something conceptually like:

```c3
fn InnerQueue* Pool._close(&self)
```

with the important restriction:

> `_close()` is called while `_mu` is already locked.

It should:

* test `_closed`;
* set `_closed`;
* publish `_closed_fast`;
* remove all free items;
* broadcast waiters;
* return the remaining queue.

It should **not** lock or unlock `_mu`.

Then:

```text
close()
    lock
    remaining = _close()
    unlock
    on_close(remaining)

release()
    lock
    remaining = _close()
    wait for active operations
    unlock
    on_close(remaining)
    destroy/free
```

However, there is an important ordering issue here.

You cannot let `release()` call `on_close()` and free the pool while an earlier public `close()` is still executing its own `on_close()`.

Therefore the lifetime accounting must also cover the close operation itself.

---

# 8. Better rule for `on_close()`

I would make this the pool invariant:

> There is exactly one pool-closing phase. `on_close()` is called once for the items owned by the pool at the moment of closure, and any items returned by operations already in flight are handled before the pool lifetime ends.

This avoids making `on_close()` a potentially unbounded series of callbacks.

The current `put()` design allows:

```c3
if (self._closed)
{
    ...
    self._hooks.on_close(&stragglers);
}
```

That is workable, but it means `on_close()` can be called multiple times and concurrently.

That makes hook lifetime substantially harder.

I would reconsider this.

---

# 9. The `put()` race is otherwise logically well designed

This part is good:

```c3
Slot mine;
mine.fill(slot.take());

InnerQueue extra;

self._mu.unlock();
self._hooks.on_put(in_pool, &mine, &extra);
self._mu.lock();
```

The caller's Slot is cleared **before** entering the hook.

That establishes a clean ownership transfer:

```text
caller
   |
   | take
   v
mine
   |
   | on_put
   v
hook
```

If the pool closes while the hook runs, the code does not simply put the result into the closed pool.

Instead:

```c3
if (self._closed)
{
    ...
    self._hooks.on_close(&stragglers);
    return;
}
```

That is conceptually correct.

The problem is not this ownership decision.

The problem is that `release()` currently has no way to know that this `put()` is still alive.

---

# 10. `get()` has an important semantic race

This sequence is currently possible:

```text
get()
    removes free item
    returns it
```

and separately:

```text
close()
    removes remaining free items
    on_close()
```

That is fine.

But for the creation path:

```c3
self._mu.unlock();
self._hooks.on_get(want, in_pool, slot);
```

the hook may create an item after the pool has already closed.

Example:

```text
get()                         close()

unlock
                              closed = true
                              collect free items
                              on_close()

on_get()
creates item
returns it
```

The current implementation returns that newly created item to the caller.

This is not necessarily wrong.

In fact, it can be a reasonable ownership rule:

> An operation admitted before close is allowed to finish and its result belongs to that operation.

But this must be deliberate.

If that is the desired rule, the active-operation lifetime mechanism should preserve it.

Do **not** solve the race by simply checking `_closed` after `on_get()` and discarding the item.

The hook has created an item for the caller, and ownership has already moved.

---

# 11. `get_wait()` is different

`get_wait()` does not call hooks.

It holds `_mu` during the wait:

```c3
self._mu.lock();
defer self._mu.unlock();
```

and close broadcasts:

```c3
self._cv.broadcast();
```

So close wakes the waiter and it observes:

```c3
if (self._closed) return mtk::CLOSED~;
```

That part is good.

However, `get_wait()` is still an active operation for lifetime purposes.

Therefore:

```text
release()
```

must not destroy the pool while a thread is inside `get_wait()`.

The close broadcast should cause it to leave.

Then its active-operation count can drop.

---

# 12. Do not use the mutex itself as the lifetime mechanism

It may be tempting to make `release()` wait by simply locking `_mu`.

That is insufficient.

For example:

```text
get()
  unlock
  on_get()
```

The mutex is free while `on_get()` is running.

So:

```c3
release()
    _mu.lock()
```

can succeed while `on_get()` is still executing.

The lifetime mechanism must therefore survive mutex unlock.

---

# 13. Active-operation counter is the natural solution

The pool already has a condition variable.

A natural design is:

```c3
usz _active;
bool _closed;
```

with an internal condition for lifetime waiting.

Conceptually:

```text
enter operation:

lock
if closed:
    unlock
    fail

_active++
unlock
```

and:

```text
leave operation:

lock
_active--
if _active == 0:
    signal/broadcast
unlock
```

Then `release()`:

```text
lock
close
while _active != 0:
    wait
unlock

destroy/free
```

But there is an important detail:

## `release()` itself must count as an owner of the Pool while it is waiting.

Otherwise another release could race with it.

I would not try to support simultaneous `release()` calls.

That should be a separate ownership rule.

---

# 14. Simultaneous release

Your original observation was:

> We never guard simultaneous releases — by design.

I agree with that direction.

The simplest contract is:

> `release()` must not be called concurrently with another `release()`.

But that is not the same as:

> `release()` may race with ordinary pool operations.

Ordinary operations need protection.

So the intended contract can be:

```text
release vs release
    forbidden / caller responsibility

release vs get
    supported

release vs get_wait
    supported

release vs put
    supported

release vs close
    supported
```

If you want that model, document and test exactly this.

---

# 15. `close()` vs `release()` needs one more state

If both are allowed concurrently, `_closed` alone is insufficient.

Consider:

```text
Thread A                 Thread B

close()
  _closed = true
  unlock
  on_close()

                         release()
                           sees closed
                           waits active == 0
                           ...
                           free Pool
```

If `on_close()` is not represented by the active lifetime accounting, `release()` can free the Pool while `close()` is still executing its hook.

Therefore either:

### Option A — count the close callback as active

or:

### Option B — make closing/cleanup a state machine with a completion condition.

I prefer **A**, because it fits the existing design.

---

# 16. Stronger operation definition

Treat every public operation as holding a temporary lifetime reference.

For example:

```text
get:
    acquire lifetime
    check closed
    ...
    release lifetime

put:
    acquire lifetime
    ...
    hook
    ...
    release lifetime

get_wait:
    acquire lifetime
    wait
    release lifetime

close:
    acquire lifetime
    close
    on_close
    release lifetime

release:
    acquire final ownership
    close
    wait for other lifetime references
    destroy
```

The exact implementation can be simpler than this conceptual model.

The important point is the invariant:

> The Pool cannot be freed while any operation still has a reference to it.

---

# 17. `on_close()` and `on_put()` context lifetime

This is the biggest hook-specific question.

Current code permits:

```text
on_put()
    ...
```

while another thread executes:

```text
on_close()
    ...
```

If the hook implementation has state such as:

```text
struct MyHooks
{
    SomeState* state;
}
```

then both callbacks may access `state`.

The pool cannot protect that state because it intentionally releases `_mu` before invoking hooks.

Therefore you have two possible contracts.

### Contract 1 — hooks must be thread-safe

Then concurrent:

```text
on_get
on_put
on_close
```

are allowed.

This is valid, but must be explicit.

### Contract 2 — `on_close` waits for existing hooks

Then:

```text
on_get
on_put
```

finish before:

```text
on_close
```

starts.

For pool destruction, I recommend Contract 2.

It gives a much stronger lifecycle guarantee and makes `release()` substantially easier to reason about.

---

# 18. `take_back_handle()` should remain a hard failure

This change is good:

```c3
PoolBucket* b = self.bucket_for(h.link.type);
mtk::@check(b != null, ...);
b.free.push(h);
```

Do not restore:

```c3
if (!b) return;
```

A hook returning an identity not owned by this pool is an application defect.

Silently dropping it would be much worse.

There is one implementation concern:

If `@check` disappears in a fast build, then:

```c3
b.free.push(h);
```

would dereference null.

That is actually acceptable **if your fast-build philosophy is that application defects have undefined/fatal consequences rather than graceful recovery**.

But if fast builds must remain memory-safe, then this needs an unconditional failure rather than `@check`.

The same question applies to:

```c3
Pool.get()
Pool.put()
```

for unknown identities.

The current code intentionally treats `UNKNOWN_IDENTITY` as a checking-build defect.

That policy should remain consistent.

---

# 19. `count_of()` has a useful existing property

This is good:

```c3
PoolBucket* b = self.bucket_for(t);
return b ? b.free.len() : 0;
```

It does not treat an unknown identity as a defect.

That makes sense because this is an informational query.

So the distinction is reasonable:

```text
get/put:
    unknown identity = programming defect

count_of:
    unknown identity = 0
```

I would keep that.

---

# 20. `create()` is mostly structurally sound

The construction sequence is good:

```c3
Pool* p = alloc::new_try(...)
defer catch alloc::free(...)

helper::init(p)
...
_mu.init()
...
_cv.init()
...
_buckets = alloc::new_array_try(...)
```

The cleanup ordering also looks correct:

```text
bucket allocation failure
    -> destroy cv
    -> destroy mutex
    -> free Pool
```

One thing to verify in actual C3 compilation is the exact cleanup behavior of:

```c3
defer catch p._cv.destroy()!!;
```

but from the implementation structure itself there is no obvious ownership contradiction.

---

# 21. Bucket lookup is currently O(n)

```c3
foreach (&b : self._buckets)
    if (b.tag == t) return b;
```

This is not a correctness problem.

It means:

```text
get()
put()
get_wait()
count_of()
```

have an O(number-of-identities) lookup.

That may be completely appropriate because:

* the identity set is fixed;
* the pool is created once;
* the number of identities is probably small;
* there is no allocation during normal operation.

I would **not** introduce a hash table merely to optimize this.

The flat array is a clean design.

---

# 22. `get()` stale `in_pool` is fine

This:

```c3
usz in_pool = b.free.len();
self._mu.unlock();
self._hooks.on_get(want, in_pool, slot);
```

is necessarily approximate because the hook runs without the mutex.

The important thing is that the API calls it a hint.

No problem there.

Likewise for `on_put()`.

Do not attempt to make these values exact.

That would require holding the mutex across user code, which would be much worse.

---

# 23. `broadcast()` after put is conservative

Current code:

```c3
self._cv.broadcast();
```

after items are returned.

That is correct but potentially more wakeups than necessary.

A single returned item only allows one waiter to acquire that item.

`signal()` could therefore be enough for ordinary pool reuse.

However, because multiple items can arrive through `extra`, `broadcast()` is defensible.

I would not change this unless profiling shows contention.

Correctness first.

---

# 24. The `extra` mechanism is good

This is a useful design:

```c3
InnerQueue extra;
self._hooks.on_put(in_pool, &mine, &extra);
```

The hook can return:

```text
mine
+
extra
```

and the pool validates every returned identity through:

```c3
take_back_handle()
```

That gives the hook a controlled way to return multiple items without exposing the pool internals.

I would keep it.

---

# 25. One thing I would change in `put()`

The current sequence is:

```c3
self._hooks.on_put(...);

self._mu.lock();

if (self._closed)
{
    ...
    self._mu.unlock();
    self._hooks.on_close(&stragglers);
    return;
}
```

If you adopt the stronger lifecycle rule, this can become simpler.

The operation itself remains active while `on_put()` runs.

Then close can wait for active hooks before its final `on_close()`.

That eliminates the special concurrent:

```c3
on_put -> on_close(stragglers)
```

path.

The resulting model becomes:

```text
put started before close
        |
        v
     on_put
        |
        v
put finishes
        |
        v
close can finalize
```

This is much easier to explain.

---

# 26. Recommended pool ownership model

I would make the final semantics:

```text
OPEN
  |
  | close/release
  v
CLOSING
  |
  | no operations already in flight
  v
CLOSED
  |
  | release
  v
DESTROYED
```

But `CLOSED` and `DESTROYED` are not necessarily states stored in the object.

The implementation only needs enough state to enforce the transitions.

The crucial distinction is:

```text
closed
```

means:

> no new operation may enter.

while:

```text
active == 0
```

means:

> no operation can still touch the object.

---

# 27. Recommended API semantics

I would settle on:

```text
Pool.close()
    close for clients
    idempotent
    does not destroy Pool
    wakes waiters
    waits/coordinates with already admitted operations
    calls on_close for remaining items

Pool.release()
    closes if necessary
    waits for all other operations
    guarantees no operation can still access Pool
    performs final cleanup
    frees Pool
```

And:

```text
Pool.release()
```

does **not** require:

```c3
Pool.close()
```

first.

That is a significant improvement over the current API.

---

# 28. What I would NOT change

I would keep these parts:

```text
one fixed bucket array
one InnerStack per identity
typeid identity
no allocation during get/put
hooks outside mutex
Slot ownership transfer
UNKNOWN_IDENTITY as a programming defect
flat bucket lookup
no put_all()
```

I would also keep the current stack behavior.

The pool's choice of stack is independent of the lifetime problem.

---

# 29. Priority of changes

### Must fix

1. `release()` cannot simply check `_closed`.
2. `release()` must wait for operations currently outside `_mu`.
3. `release()` must not race with `on_get()`.
4. `release()` must not race with `on_put()`.
5. `release()` must not race with `on_close()`.
6. Define what happens when `close()` races with an already-running hook.
7. Make the hook-context lifetime rule explicit.

### Strongly recommended

8. Introduce private `_close()` with no lock/unlock.
9. Make `release()` close an open pool.
10. Make closing and final destruction separate phases.
11. Avoid concurrent `on_close()` calls if possible.
12. Let close wait for already-running `on_get`/`on_put` operations before final `on_close()`.

### Not necessary now

13. Replace the flat bucket array with a hash table.
14. Optimize `broadcast()`.
15. Optimize `count_of()`.
16. Add `put_all()`.

---

# 30. Final design recommendation

The important architectural decision is this:

> **Do not try to solve Pool lifetime by strengthening `_closed`.**

`_closed` answers the wrong question.

The pool needs a separate lifetime/operation mechanism.

The clean model is:

```text
                 _mu
                  |
       +----------+----------+
       |                     |
   pool state          active operations
       |                     |
    _closed              lifetime
       |                     |
       +----------+----------+
                  |
               release
                  |
          active == 0
                  |
             destroy Pool
```

And because hooks execute outside `_mu`:

```text
on_get
on_put
on_close
```

must participate in that lifetime model.

For the port, I would make the strongest invariant:

> **Once `close()` starts, no new pool operation is admitted. Operations already admitted are allowed to finish. `on_close()` runs only after those operations have finished. `release()` waits for the same boundary before destroying the pool.**

That removes the current `put()` straggler complexity and gives `Pool` the same clear ownership rule you are moving toward for `Mailbox`.


====== Second advice =================

Yes. For `Pool`, I would apply the same **owner/release correction as Mailbox**, but there is one important extra issue: `Pool.close()` has an application hook, so the definition of “quiet” must include the entire `on_close()` call, not only the mutex-protected part.

## Analysis report — Pool

### 1. The current `Pool.release()` has the same fundamental defect

Current logic:

```c3
always_assert(self._closed, ...);
self._cv.destroy()!!;
self._mu.destroy();
Allocator a = self._alloc;
alloc::free(a, self._buckets);
alloc::free(a, self);
```

The problem is not merely "release requires close".

The real problem is:

> **`_closed == true` does not mean nobody is still using the Pool.**

For example:

```text
Thread A                         Thread B

put()
  lock
  ...
  unlock
  on_put(...)
                                 close()
                                   lock
                                   _closed = true
                                   drain buckets
                                   unlock
                                   on_close(...)
                                 release()
                                   free pool
  lock                 <-- UAF
```

So the existing `2DO` is correctly identifying a real lifetime problem.

---

# 2. The proposed fix is correct, but Pool needs one extra rule

The proposed mechanism:

```text
active calls
      |
      v
release closes object
      |
      v
wait until active == 0
      |
      v
destroy/free
```

is the right direction.

A counter alone is not enough.

The counter must be protected by the Pool mutex, and `release()` must wait on a condition variable.

The important invariant becomes:

> **After Pool has been closed, no new public operation can enter, and release waits until every operation already in progress has completely returned.**

That last word matters.

For Pool:

```text
operation started
    |
    +-- mutex part
    |
    +-- unlock
    |
    +-- on_get / on_put
    |
    +-- relock
    |
    +-- final pool work
    |
    +-- on_close, if applicable
    |
operation finished
```

The count must cover the **whole operation**, including the hook window.

---

# 3. `Pool.put()` is the critical test

Your current `put()` has:

```c3
self._mu.unlock();
self._hooks.on_put(in_pool, &mine, &extra);
self._mu.lock();

if (self._closed)
{
    ...
    self._mu.unlock();
    if (!stragglers.is_empty()) self._hooks.on_close(&stragglers);
    return;
}
```

Therefore the active count must behave approximately like:

```text
put enters
    active++

unlock
on_put()
lock

if closed:
    ...
    unlock
    on_close()
    active--
    return

...
unlock
active--
```

**The decrement cannot happen immediately after `on_put()`.**

Otherwise this race remains:

```text
put:
    active--
    on_close()             <-- still running

release:
    sees active == 0
    free(pool)

put:
    continues using pool
```

So the Pool-specific requirement is:

> `active` covers `on_put()` and any subsequent `on_close()` caused by that put.

That is the most important detail in the implementation.

---

# 4. `Pool.close()` must also remain active until `on_close()` returns

This is another important consequence.

Current `close()`:

```c3
lock
_closed = true
drain
broadcast
unlock

_hooks.on_close(&remaining)
```

If `close()` is counted only until the unlock, this is unsafe:

```text
close:
    active++
    ...
    unlock
    active--          <-- WRONG

    on_close()

release:
    active == 0
    free(pool)

close:
    on_close()        <-- application still using pool/hook state
```

Therefore:

```text
close:
    active++
    lock
    _close()
    unlock
    on_close()
    active--
```

The count represents the **public operation**, not merely the time spent holding the Pool mutex.

---

# 5. This also resolves the "two on_close calls" issue

Your second supplied document is important here.

`on_close()` is allowed to happen:

```text
close()                         -> on_close(remaining)
concurrent put()                -> on_close(stragglers)
```

They may be concurrent.

The release/quiet mechanism should **not attempt to serialize those hooks**.

Instead:

```text
close
  active = 1
  |
  +---- on_close()
  |
  active = 0


put
  active = 1
  |
  +---- on_put()
  |
  +---- discovers closed
  |
  +---- on_close(stragglers)
  |
  active = 0
```

Then:

```text
release
    |
    +-- close
    |
    +-- wait active == 0
    |
    +-- free
```

This is exactly the right separation:

* `Pool` does **not** serialize application hooks.
* `Pool` **does** guarantee that release waits for all calls to finish.

Those are different responsibilities.

---

# 6. I would change the meaning of `release()`

The new semantics should be explicit:

### `close()`

Means:

> Stop accepting new operations and dispose of the Pool's contents through `on_close()`.

### `release()`

Means:

> Close the Pool if necessary, wait until all operations already in flight finish, then destroy and free the Pool.

Therefore:

```text
close()
```

is not required before:

```text
release()
```

any more.

This matches your Mailbox ruling:

> **Any release closes the object, regardless of its current state.**

So the old:

```c3
always_assert(self._closed, "releasing an open pool");
```

must disappear.

---

# 7. `release()` should not call public `close()`

Your proposed separation is good:

```text
close()
    lock
    _close()
    unlock
    on_close()

release()
    lock
    _close()
    wait for active == 0
    ...
    unlock
    destroy/free
```

But I would make the internal operation slightly more precise.

Something like:

```text
_close()
    assumes mutex held
    marks closed
    drains buckets
    broadcasts waiters
    returns remaining queue
```

It should **not**:

* lock
* unlock
* call hooks
* destroy anything
* free anything

That gives both public paths a common state transition.

---

# 8. There is one subtle ordering issue

I would use this conceptual order for `release()`:

```text
lock

mark closed
drain pool
broadcast waiters

wait until active calls == 0

save allocator

unlock

on_close(remaining)

destroy mutex/cv
free buckets
free pool
```

But there is a problem with putting `on_close()` after the wait and then freeing: **`on_close()` itself is application code and may need the Pool's hook state, but it does not need the Pool object according to the contract.**

The cleaner model is therefore:

```text
release:
    close state
    wait for all other calls
    take final remaining queue
    unlock
    call on_close(remaining)
    destroy/free
```

The key is that **release itself is not counted as an ordinary active operation**.

Otherwise it would wait for itself forever.

---

# 9. The hardest case: concurrent `close()` + `release()`

This should be explicitly tested.

Suppose:

```text
Thread A                 Thread B

close()
  active++
  lock
  _close()
  unlock
                         release()
                           lock
                           sees closed
                           wait active == 0

  on_close()
  active--
                         wake
                         destroy/free
```

This is safe.

`release()` must not free until `close()` has finished its hook.

That is exactly why `active` must remain elevated through `on_close()`.

---

# 10. `release()` itself should probably use `_close()`

This gives the desired idempotent behavior.

If the Pool is open:

```text
release()
    _close()
    wait
    free
```

If another thread already closed it:

```text
release()
    sees closed
    wait
    free
```

If another thread is currently executing `close()`:

```text
release()
    sees closed
    waits for close's active count
    free
```

This is much better than requiring the caller to coordinate:

```text
close();
release();
```

The Pool becomes responsible for its own lifetime transition.

---

# 11. But there is a fundamental limitation

There is one thing this mechanism **cannot** protect against:

```c3
Pool* p = ...;

thread A:
    p.put(...);

thread B:
    p.release();
```

if thread A has **not yet entered the Pool at all** when thread B starts release.

That is not an internal Pool race if `release()` closes the Pool first:

```text
release:
    lock
    _closed = true
    unlock/free
```

Thread A then attempts to start.

It has a pointer to freed memory.

So the lifetime contract must distinguish:

### Operation already entered

Pool can protect it.

### Caller possesses a Pool pointer but has not entered

Pool cannot protect it.

This is a normal object-lifetime boundary.

The ruling therefore needs to mean:

> `release()` waits for calls already in flight.

It cannot mean:

> `release()` makes arbitrary future uses of an old pointer safe.

I would state this clearly in the shared specification.

---

# 12. Entry protocol matters

Because of that, the counter should be acquired while holding `_mu`.

Conceptually:

```text
enter:
    lock
    if closed:
        unlock
        return CLOSED

    active++
    unlock
```

Then the operation owns an internal lifetime reference.

For operations that already need the mutex, this can be folded into their existing locking.

For `Pool.get()`:

```text
lock
if closed -> unlock
active++
...
unlock
hook
...
finish
```

For `Pool.put()`:

```text
lock
if closed -> unlock
active++

...
unlock
on_put()
lock
...
unlock
possibly on_close()
active--
```

The final decrement needs a reliable "leave operation" path.

---

# 13. I would avoid an atomic active counter

Your supplied reasoning is right.

There is no need for:

```c3
Atomic{usz} _active;
```

The Pool already has:

```c3
Mutex _mu;
ConditionVariable _cv;
```

So:

```c3
usz _active;
```

is sufficient.

The mutex protects:

```text
_closed
_active
_buckets
```

and the condition variable waits for:

```text
_active == 0
```

This keeps the common path cheap and conceptually simple.

---

# 14. Recommended Pool structure

I would add only:

```c3
usz _active;
```

to the Pool.

So:

```c3
struct Pool
{
    Inner node;

    Mutex             _mu;
    ConditionVariable _cv;

    Allocator         _alloc;

    bool         _closed;
    Atomic{bool} _closed_fast;

    usz _active;

    PoolBucket[] _buckets;
    PoolHooks    _hooks;
}
```

No atomic is needed for `_active`.

---

# 15. What I would change in the documentation

The old statement:

> Close it first. Releasing an open pool aborts in every build mode.

should become something like:

> Release closes the pool if it is still open. It waits for calls already in flight to finish, then frees the pool. It does not take an allocator.

And importantly:

> Closing stops new calls, but closing alone does not make the pool quiet. Release waits for the calls already in flight.

That is the real semantic change.

For `Pool.put()` specifically, the hook description should continue saying that hooks are not serialized. Do **not** accidentally turn the new lifetime mechanism into a hook serialization mechanism.

---

# 16. Tests I would require

The deterministic test from your `Q5` document is exactly the right one.

### Test A — release while `on_put` is running

```text
worker:
    pool.put()
        on_put:
            signal main
            wait for main

main:
    wait for hook
    pool.release()
```

Expected:

```text
release() blocks
hook returns
put finishes
release() finishes
program exits
```

This catches the original UAF.

### Test B — release while `on_close` is running

```text
worker:
    pool.close()
        on_close:
            signal main
            wait for main

main:
    wait for hook
    pool.release()
```

Expected:

```text
release() waits
on_close returns
release() frees
```

This verifies that the active count covers `on_close()`.

### Test C — concurrent `put` produces second `on_close`

This specifically validates your already-established Part 12.2 behavior:

```text
put
  on_put waits

main:
  close()
  release()

put:
  on_put returns
  discovers closed
  on_close(stragglers)
```

Expected:

```text
release waits for both operations
```

This is probably the **most valuable Pool-specific negative**.

---

# 17. Final recommendation

I would accept the `Q5` ruling for Pool with this precise formulation:

> **Pool.release() closes the Pool if necessary, waits until every Pool operation already in flight has completed, including application hook execution, and only then destroys the Pool.**

And implementation-wise:

1. Add `usz _active`.
2. Count every public operation that successfully enters.
3. Count through the entire operation, including `on_get`, `on_put`, and `on_close`.
4. `_close()` only changes state/drains/broadcasts while `_mu` is held.
5. `close()` calls `_close()`, unlocks, runs `on_close()`, then leaves the operation.
6. `release()` calls `_close()` if needed.
7. `release()` waits for `_active == 0`.
8. `release()` saves the allocator before unlocking.
9. Destroy/free only after the object is quiet.
10. Do **not** serialize `on_close()` calls.
11. Add deterministic tests for `on_put` and `on_close` races.
12. Update the shared specification before making this a 3tk-only promise.

### One important correction to the Q5 document

I would slightly change its wording from:

> "The closed flag already stops new calls from starting, so the count is monotonically falling once close has run."

to:

> **"The closed flag prevents a call that acquires the Pool mutex after closure from becoming active, so once closure is established the active count can only fall."**

That is more exact. A caller can still *attempt* to call through an old pointer after release, but that is outside what the Pool can make safe.

Overall, **the Pool fix is sound and should follow the Mailbox fix closely, with `on_put` and `on_close` included in the definition of “in flight.”**
