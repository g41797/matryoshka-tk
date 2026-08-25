# Naming proposal: Outer / Inner

## Core terminology

Use two different naming levels.

### Conceptual architecture

```text
Outer
Inner
````

An application-defined value is the **Outer**.

The representation embedded by 3TK is the **Inner**.

```text
+---------------------------+
|           Outer           |
|                           |
| application-defined data  |
|                           |
|    +-----------------+    |
|    |      Inner      |    |
|    +-----------------+    |
+---------------------------+
```

The relation is explicit:

```text
Outer
  contains
Inner
```

3TK operates on the `Inner`.

The application operates on the complete `Outer`.

A Helper crosses the boundary:

```text
Outer
  ↕ Helper
Inner
```

---

## Actual C3 names

I recommend considering:

```text
mtk::Inner
mtk::Handle
mtk::Slot

mtk::InnerQueue
mtk::InnerStack
```

This is internally consistent.

```text
Inner
    the common representation embedded by an Outer

Handle
    a type-erased pointer to Inner

Slot
    a location containing an optional Handle

InnerQueue
    FIFO ordering of Inners

InnerStack
    LIFO ordering of Inners
```

---

# Why `Inner` may be better than `Node`

`Node` describes the implementation mechanism.

It comes from intrusive linked structures.

`Inner` describes the architecture.

That distinction matters because 3TK is no longer simply porting
`std.DoublyLinkedList.Node`.

If the design changes from:

```text
DoublyLinkedList.Node
```

to a minimal common representation used by:

```text
Mailbox
Pool
Queue
Stack
```

then `Node` may describe an implementation detail rather than the main concept.

`Inner` says exactly what the type is:

> the representation inside an application-defined Outer.

This is especially good because the design already has an explicit boundary:

```text
application
    |
    | Outer
    v
+----------------+
| application    |
| data           |
|                |
|    Inner       | <---- 3TK boundary
+----------------+
    |
    v
3TK
```

So:

```text
Outer / Inner
```

describes the whole model.

---

# Strong advantage: no inherited Zig terminology

This avoids all of the problematic names:

```text
Any
Item
AnyNode
PolyNode
```

None of them is needed.

The terminology becomes native to the 3TK design:

```text
Outer
Inner
Handle
Slot
Helper
```

That is a very coherent vocabulary.

---

# Collections

If the minimal intrusive representation uses one link, I would use:

```text
InnerQueue
InnerStack
```

For example:

```text
Mailbox
    regular: InnerQueue
    oob:     InnerQueue

PoolBucket
    available: InnerStack
```

This is clear:

```text
InnerQueue
    queues 3TK Inners

InnerStack
    stacks 3TK Inners
```

If a general list survives because a real requirement needs it:

```text
InnerList
```

The complete family is then:

```text
Inner
InnerList
InnerQueue
InnerStack
```

This is more coherent than:

```text
AnyNode
AnyNodeList
AnyNodeQueue
AnyNodeStack
```

and also more architectural than:

```text
Node
NodeList
NodeQueue
NodeStack
```

---

# Handle

The relation is especially clean:

```text
Outer
  |
  | contains
  v
Inner
  |
  | addressed by
  v
Handle
  |
  | stored in
  v
Slot
```

Or:

```text
Concrete Outer
       ↕
     Helper
       ↕
      Inner
       ↕
     Handle
       ↕
       Slot
```

This is probably the cleanest terminology found so far.

---

# Important restriction

I would use `Outer` and `Inner` primarily as **representation concepts**.

Do not let them replace concrete application language.

For example:

Bad:

> Send the Outer to the Mailbox.

Better:

> Send the request.

But when explaining the generic boundary:

> Every Outer embeds an Inner.

> 3TK operates only on the Inner.

> A Helper restores the concrete Outer from an Inner.

This is exactly where these terms are useful.

---

# Example

```c3
struct Request
{
    Inner inner;

    String text;
    int id;
}
```

Conceptually:

```text
Request
    is an Outer

Request.inner
    is its Inner
```

3TK receives:

```text
Handle
    ↓
Request.inner
```

The type-specific Helper can recover:

```text
Handle
    ↓
Inner
    ↓
Request*
```

The toolkit never needs a common `Outer` type.

`Outer` is a conceptual category.

`Inner` is the actual common representation.

---

# One concern: `Inner` is more abstract than `Node`

This is the only real disadvantage.

Someone seeing:

```c3
InnerQueue
```

without knowing 3TK may initially ask:

> Inner of what?

`NodeQueue` is immediately recognizable as an intrusive queue.

However, I think the namespace and architecture solve this:

```text
mtk::Inner
mtk::InnerQueue
mtk::InnerStack
```

Inside 3TK, `Inner` has one precise meaning.

Also, this abstraction is intentional.

The common representation may evolve.

For example, today it may contain:

```text
next
type
```

Tomorrow the exact representation could change.

The architectural role remains:

```text
Inner
```

That is an advantage over naming it after the current link mechanism.

---

# Final recommendation

I now prefer this naming over the previous `Outer` / `Node` proposal:

```text
CONCEPTUAL AND CORE MODEL

Outer
    complete application-defined value

Inner
    common 3TK representation embedded by an Outer

Handle
    type-erased pointer to Inner

Slot
    optional location holding a Handle

Helper
    type-specific mapping between Outer and Inner
```

Collections:

```text
InnerQueue
InnerStack

InnerList
    only if genuinely required
```

The complete vocabulary becomes:

```text
Outer
  |
  +-- Inner
         |
         +-- Handle
                |
                +-- Slot

Helper
    Outer ↔ Inner

InnerQueue
InnerStack
InnerList
```

I think this is the **most coherent naming direction so far**.

It directly describes the actual architecture.

It removes the misleading `Any`.

It avoids reintroducing `Item` only because ztk used it.

And it avoids tying the main representation name to `DoublyLinkedList.Node` if
3TK is moving toward dedicated queue and stack primitives.

My preferred choice now is:

# `Outer` / `Inner`

with:

```text
Inner
InnerQueue
InnerStack
```

as the actual 3TK naming family.
