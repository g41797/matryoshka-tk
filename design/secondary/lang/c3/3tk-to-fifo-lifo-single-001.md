# Stop treating `NodeList` as the center of the design

This changes my recommendation.

The important fact is:

> ztk started from `std.DoublyLinkedList` and its intrusive `Node`.
>
> But the actual Matryoshka operations do not require a general-purpose doubly
> linked list.

The main functionality is closer to:

```text
Mailbox
    FIFO queue
    +
    OOB delivery

Pool
    LIFO stack / recently returned items
    +
    typed buckets
````

Therefore I would reconsider whether `NodeList` should remain a central public
abstraction in 3TK at all.

The answer depends on one question:

> Is `NodeList` part of the actual Matryoshka model, or is it inherited from
> Zig's `std.DoublyLinkedList` because ztk happened to start there?

From the functionality described here, I think the second is more likely.

---

# 1. Do not preserve `DoublyLinkedList` functionality just because ztk used it

ztk had:

```text
std.DoublyLinkedList
        +
its Node
```

That gave Matryoshka many operations almost for free.

But that does not mean 3TK needs to reproduce all of them.

A port should preserve:

```text
required behaviour
```

not:

```text
the complete capability surface accidentally inherited from the source standard
library
```

This is especially important now because the extra capability has a cost.

Every additional intrusive operation means more possible states.

For example, a general doubly linked list permits:

```text
empty
one item
many items

insert front
insert back
insert before
insert after

remove arbitrary item

append list
prepend list
split
move ranges
...
```

Even if 3TK exposes only some of these, every operation touching arbitrary
nodes increases the number of link invariants that must remain correct.

If Matryoshka actually needs only queues and stacks, a general `NodeList` is
too large a primitive.

---

# 2. Mailbox is primarily a queue

The normal mailbox operation is:

```text
send
    |
    v
tail of queue

receive
    |
    v
head of queue
```

This needs only:

```text
push_back
pop_front
```

That is a FIFO queue.

It does not require:

```text
insert_after
insert_before
remove arbitrary node
```

unless another required operation actually depends on them.

This is important because `insert_after` was inherited from the linked-list
model.

It should not survive automatically.

---

# 3. OOB is the only reason currently given for arbitrary insertion

The current design apparently requires:

```text
insert after N
```

for Mailbox OOB handling.

That is a weak reason to make the entire underlying container a general
doubly-linked list.

If OOB is logically a different delivery class, model it directly.

For example:

```text
Mailbox
    |
    +-- regular queue
    |
    +-- OOB queue
```

Then the mailbox itself decides delivery priority.

Conceptually:

```text
send(item)
    -> regular.push_back(item)

send_oob(item)
    -> oob.push_back(item)
```

And receive becomes:

```text
if OOB queue is not empty
    return OOB queue.pop_front()

if regular queue is not empty
    return regular queue.pop_front()

wait
```

This removes the need for arbitrary insertion completely.

The item links remain simple.

The ordering policy moves into the mailbox, where it belongs.

---

# 4. But verify the exact OOB semantics before using two queues

This is the critical point.

Do not replace `insert_after(N)` with two queues merely because it is simpler.

First ask:

> What exact ordering does OOB currently guarantee?

There are at least several possible meanings.

## Meaning A — OOB has absolute priority

```text
regular:
A B C

oob:
X Y

receive:
X Y A B C
```

Two queues work perfectly.

## Meaning B — OOB is inserted immediately after the currently processed item

Suppose:

```text
currently processing:
A

queue:
B C D
```

Then OOB `X` arrives:

```text
A -> X -> B -> C -> D
```

This is not simply an absolute-priority queue.

However, two queues may still reproduce it if the mailbox's receive model
defines a boundary between the current item and the next item.

For example:

```text
current item completes
    |
    v
drain OOB queue
    |
    v
continue regular queue
```

## Meaning C — OOB is inserted at a specific position relative to another queued item

For example:

```text
A B C D

insert X after B

A B X C D
```

Then two FIFO queues cannot preserve the same semantics.

But this is also a much stronger requirement than "OOB".

Therefore:

> Before changing the implementation, write the ordering examples that define
> OOB.

Do not choose the data structure first.

Choose the required order first.

---

# 5. My likely recommendation: two queues are better if OOB means priority

If the actual semantics are:

> OOB items must be delivered before ordinary queued items, while preserving
> FIFO order within OOB items and within ordinary items,

then I strongly recommend two queues.

```text
Mailbox
│
├── regular
│   A -> B -> C
│
└── oob
    X -> Y
```

Receive policy:

```text
oob first
regular second
```

Advantages:

```text
no insert_after
no arbitrary-position mutation
clear OOB policy
simple FIFO invariants
FIFO preserved inside each class
easy testing
```

The implementation becomes closer to the actual behaviour.

That is better than using a more general list operation only to implement one
special ordering rule.

---

# 6. Pool is not a queue

Pool has a different primary operation.

You described the required additional functionality as:

> get from last added.

That means the natural structure is:

```text
put
    |
    v
top

get
    |
    v
top
```

This is LIFO.

A stack needs only:

```text
push_front / pop_front
```

or equivalently:

```text
push_back / pop_back
```

depending on naming.

It does not require a doubly linked list.

If the pool is typed:

```text
Pool
    |
    +-- Bucket Type A -> stack
    |
    +-- Bucket Type B -> stack
    |
    +-- Bucket Type C -> stack
```

then each bucket can have a simple intrusive stack.

Conceptually:

```text
PoolBucket
    head
    len
```

and the item only needs the link required by that stack.

---

# 7. This exposes a more important question: why does `AnyNode` need `prev`?

If the main required operations become:

```text
Mailbox:
    FIFO

Pool:
    LIFO
```

then the obvious intrusive representation is:

```text
struct AnyNode
{
    AnyNode* next;
    typeid type;
}
```

There is no obvious need for:

```text
prev
```

A singly linked intrusive node is sufficient for:

```text
queue push_back
queue pop_front

stack push_front
stack pop_front
```

For a queue, the container stores:

```text
head
tail
```

For a stack, the container stores:

```text
head
```

Therefore the main architectural question is now:

> Is `prev` required by any actual Matryoshka operation?

If not, remove it.

Do not keep:

```text
prev
next
```

because the original Zig standard library happened to use a doubly linked node.

That would be exactly the kind of source-language inheritance a port should
avoid.

---

# 8. A simpler possible core

If no required operation needs backward traversal or arbitrary removal, the
core can become:

```text
AnyNode
    next
    type

AnyHandle
    AnyNode*

Slot
    distinct typedef around AnyHandle
```

Then define only small internal/container primitives.

For example:

```text
Queue
    first
    last
    len

Stack
    top
    len
```

This is substantially simpler than:

```text
NodeList
    first
    last
    len

AnyNode
    prev
    next
    type
```

The invariant count is also lower.

For a singly linked node:

```text
unlinked:
    next == null

queue:
    tail.next == null

stack:
    top points to newest item
```

There is no `prev` symmetry to maintain.

---

# 9. But do not decide this from Mailbox and Pool alone

Before removing `prev`, search every required Matryoshka operation.

In particular check whether any part requires:

```text
remove arbitrary known item
remove from the middle
insert after arbitrary item
insert before arbitrary item
reverse traversal
splice lists
append without walking
returning a whole intrusive list
```

If one of these is required, the conclusion may change.

For example:

```text
Pool.close
    returns all items
```

does not itself require `prev`.

A whole singly linked chain can be detached in O(1):

```text
result = head
head = null
tail = null
len = 0
```

Likewise:

```text
Mailbox.close
```

can detach both queues in O(1).

So "return all items" is not by itself a reason for a doubly linked list.

The important question is arbitrary removal.

---

# 10. Be careful with "filling it with some information increases probability to fail"

I understand the concern as:

> If the core intrusive node carries information needed only by one container,
> then unrelated uses can accidentally depend on or corrupt that information.

I agree.

This is an important design principle.

For example, if Pool needs:

```text
last added
```

do not add:

```text
last_added
```

to `AnyNode`.

That is pool state.

Likewise, do not add:

```text
oob_position
```

to `AnyNode` merely because Mailbox needs special ordering.

That is mailbox state.

The core node should contain only information required by all users of the
intrusive protocol.

So:

```text
type
```

belongs naturally in `AnyNode`.

Link information belongs there only to the extent required by the common
container model.

Container-specific metadata belongs in containers or their buckets.

This gives a useful rule:

> Do not make the common item representation remember policy belonging to one
> container.

That reduces accidental coupling.

---

# 11. Recommended split of responsibility

I recommend thinking in terms of four layers.

```text
1. Item identity

    AnyNode
        type
        common intrusive link(s)

2. Transfer

    AnyHandle
    Slot

3. Ordering primitives

    FIFO queue
    LIFO stack

4. Policy containers

    Mailbox
        regular/OOB delivery policy

    Pool
        type buckets
        reuse policy
        hooks
        creation policy
```

This is cleaner than:

```text
AnyNode
    |
    v
general NodeList
    |
    +-- Mailbox
    +-- Pool
```

because `NodeList` is an implementation abstraction that may be wider than the
actual model.

The more direct shape is:

```text
             AnyNode
                |
                v
         intrusive link
           /        \
          v          v
       FIFO         LIFO
      Mailbox        Pool
```

---

# 12. Recommendation for Mailbox implementation

If the required OOB semantics permit it, use:

```text
struct MailboxImpl
{
    Queue regular;
    Queue oob;

    // synchronization and state
}
```

Each queue:

```text
first
last
len
```

The operations become:

```text
send:
    regular.push_back

send_oob:
    oob.push_back

receive:
    if oob not empty:
        return oob.pop_front

    if regular not empty:
        return regular.pop_front

    wait
```

For `receive_all`, define the exact result order explicitly.

Most likely:

```text
all OOB items first
then all regular items
```

while preserving FIFO order inside each group.

But this must match the required semantics.

If that ordering is not correct, do not force two queues.

---

# 13. Recommendation for Pool implementation

Use a LIFO chain per bucket:

```text
struct PoolBucket
{
    AnyHandle top;
    usize len;
}
```

Then:

```text
put:
    item.next = bucket.top
    bucket.top = item
    bucket.len += 1
```

and:

```text
get:
    item = bucket.top

    if item != null:
        bucket.top = item.next
        item.next = null
        bucket.len -= 1

    return item
```

This directly implements:

> get from last added.

There is no need to fill a general list with information or operations that
Pool does not use.

The bucket owns the reuse policy.

`AnyNode` only provides the common link.

---

# 14. Important consequence: Queue and Stack cannot share one node simultaneously

If `AnyNode` has only one `next` link, an item can belong to only one intrusive
chain at a time.

For Matryoshka this appears compatible with the intended model:

```text
an item moves
it is not simultaneously used by multiple containers
```

That is actually a useful alignment between the representation and the model.

But verify every operation.

If one item must ever simultaneously be:

```text
in Mailbox
and
in Pool
```

then one link is insufficient.

From the described model, that should not be allowed anyway.

Therefore a single link may enforce the intended architecture more directly.

---

# 15. This may make implementation hiding easier

This connects to the previous question.

If Mailbox and Pool use small private queue/stack primitives rather than a
public general `NodeList`, their operational representation becomes easier to
hide.

For example:

```text
public Pool
    AnyNode identity
    lifetime state
    private implementation

private PoolImpl
    mutex
    closed
    buckets
        top
        len
```

and:

```text
public Mailbox
    AnyNode identity
    lifetime state
    private implementation

private MailboxImpl
    mutex
    condition
    closed
    regular queue
    OOB queue
```

There is less reason for applications to see any general list type.

So this design may improve both:

```text
smaller core
+
better implementation hiding
```

at the same time.

---

# 16. Do not keep `NodeList` merely as a "useful generic utility"

This is my strongest advice.

A generic utility is not free in a low-level toolkit.

It adds:

* API surface;
* invariants;
* tests;
* possible misuse;
* future compatibility obligations;
* temptation to use operations that were not part of the original design.

The last point matters most.

Suppose `NodeList` exposes:

```text
insert_after
remove
append
prepend
```

Then later code may start depending on them.

Now the generic list becomes architecturally required even if the original
Mailbox and Pool did not need it.

That is exactly the growth path you should avoid.

Do not create capability merely because it may be useful later.

Add an operation when a real Matryoshka behaviour requires it.

---

# 17. Recommended capability audit before changing the core

Make a table of actual required operations.

For example:

| Required behaviour     | Mailbox    | Pool   | Needs `prev`? | Needs arbitrary insert/remove? |
| ---------------------- | ---------- | ------ | ------------: | -----------------------------: |
| FIFO send/receive      | yes        | no     |            no |                             no |
| OOB delivery           | yes        | no     |   probably no |     depends on exact semantics |
| last-added reuse       | no         | yes    |            no |                             no |
| detach all on close    | yes        | yes    |            no |                             no |
| type buckets           | no         | yes    |            no |                             no |
| hooks                  | no         | yes    |            no |                             no |
| arbitrary item removal | verify     | verify |    likely yes |                            yes |
| arbitrary insertion    | verify OOB | no     |    likely yes |                            yes |

Then make the node shape follow the table.

Not the other way around.

---

# 18. My preferred direction

Based on the functionality described here, I would investigate this architecture:

```text
                         AnyNode
                    +----------------+
                    | type           |
                    | next           |
                    +----------------+
                           |
                           v
                    AnyHandle / Slot
                           |
             +-------------+-------------+
             |                           |
             v                           v
        FIFO primitive              LIFO primitive
       head / tail / len             top / len
             |                           |
             v                           v
          Mailbox                       Pool
       regular + OOB                typed buckets
```

With the important condition:

> Only remove `prev` and the general list after the full required-operation
> audit proves that no actual Matryoshka behaviour needs arbitrary insertion or
> removal.

If the audit passes, this is, in my opinion, a better 3TK design than porting
Zig's `DoublyLinkedList` model.

---

# Final advice

I would **not** start from:

```text
ztk uses DoublyLinkedList
therefore 3TK needs NodeList
```

I would start from:

```text
What ordering operations does Matryoshka actually require?
```

Your new observations strongly suggest:

```text
Mailbox = FIFO + special OOB policy
Pool    = LIFO per type
```

If the OOB policy can be represented as two queues, then the general
`insert_after` requirement disappears.

If no other operation needs arbitrary removal or insertion, then `prev` may
also disappear.

That would give you:

```text
less state
fewer invariants
smaller item node
smaller API
less accidental capability
less future misuse
simpler implementation
```

The key principle I recommend is:

> Do not port the source container.
>
> Port the required ordering behaviour.

And one more principle is equally important:

> Do not put container policy into `AnyNode`.
>
> Keep the common node minimal.
>
> Put FIFO policy in Mailbox.
>
> Put LIFO reuse policy in Pool.
>
> Add information to the item only when every user of the item protocol
> genuinely needs it.

That is the direction I would investigate before doing the next 3TK
implementation stage.
