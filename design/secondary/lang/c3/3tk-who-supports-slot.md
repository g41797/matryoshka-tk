

I recommend: **`InnerList` should not support the Slot idiom. `Mailbox` and `Pool` should own it.**

With the new terminology:

```c3
fn void InnerList.push_front(&self, Handle h)
```

is the right low-level API.

## Why

`Slot` is not fundamentally about intrusive linking.

It expresses a higher-level transfer operation:

```text
caller Slot
    |
    | operation consumes Handle
    v
empty Slot
```

A list only needs to know:

```text
link this Handle
unlink this Handle
```

It should not decide:

```text
was the caller's Slot emptied?
should it remain unchanged on failure?
which operation consumed ownership?
```

Those are `Mailbox`/`Pool` semantics.

### Recommended layering

```text
Slot idiom
    ↑
Mailbox / Pool
    ↑
Queue / Stack / List
    ↑
Inner links
```

So:

```c3
fn void InnerQueue.push_back(&self, Handle h);
fn Handle InnerQueue.pop_front(&self);

fn void InnerStack.push(&self, Handle h);
fn Handle InnerStack.pop(&self);
```

Then `Mailbox` does:

```c3
fn void send(&self, Slot* slot)
{
    Handle h = slot.take();
    self.regular.push_back(h);
}
```

Conceptually:

```text
Slot ──take──> Handle ──push──> Queue
```

And `Pool` does the same where appropriate.

## Why this is especially important now

If you put Slot support into every collection:

```c3
fn void InnerQueue.push_back(&self, Slot* slot)
fn void InnerStack.push(&self, Slot* slot)
fn void InnerList.push_front(&self, Slot* slot)
```

then the Slot idiom spreads into the whole implementation.

Soon the low-level collection API has to answer questions that belong to its callers:

* Does `push` clear the Slot before or after linking?
* What happens if a future `push` can fail?
* Does every collection operation consume a Slot?
* Does an internal implementation call need to manufacture a temporary Slot?

That is unnecessary coupling.

## One important exception

I would let the **collection return a `Handle`**, not fill a `Slot`.

For example:

```c3
Handle InnerQueue.pop_front(&self);
Handle InnerStack.pop(&self);
```

Then the higher-level operation decides what happens next:

```c3
Handle h = self.queue.pop_front();

if (h != null)
    slot.put(h);
```

This keeps the low-level layer completely independent of transfer semantics.

## My recommended rule

```text
Inner collections operate on Handle.

Mailbox and Pool implement Slot semantics.

Only APIs representing an external transfer boundary take Slot*.

Internal structural APIs take and return Handle.
```

So the layering would be:

```text
APPLICATION
    |
    | Slot*
    v
MAILBOX / POOL
    |
    | Handle
    v
INNER QUEUE / INNER STACK
    |
    | Inner*
    v
INNER
```

I think this is cleaner than making:

```text
InnerList
```

aware of `Slot`.

### One nuance

Do not say **Mailbox/Pool "check" the Slot** unless you mean validation.

I would make them responsible for **the Slot contract**, not necessarily for explicit checking.

For example, if the invariant is that `send` requires a non-empty Slot:

```c3
fn void send(&self, Slot* slot)
{
    assert(slot.has());
    Handle h = slot.take();
    ...
}
```

The collection should not repeat that check.

So my answer is:

> **Yes: keep `push_front(&self, Handle h)` at the collection level.**
>
> **Slot should stop at the Mailbox/Pool boundary.**
>
> The collection works only with `Handle`; the policy container defines whether and when a caller's `Slot` is consumed.
