# Tag vs Tagged Union

---

## Two different problems

Zig's tagged union solves compile-time type selection:

```zig
const Message = union(enum) {
    event: Event,
    sensor: Sensor,
    mailbox: *Mbox,
};

switch (msg) {
    .event => ...,
    .sensor => ...,
    .mailbox => ...,
}
```

- The type is known by the union itself.
- Every variant is listed in the type. A closed set, decided at compile time.

A `PolyNode` tag solves a different problem: runtime identity, after the type has already  
been erased.

```text
Tagged union                      PolyNode tag

closed set of types               open set of types
known at compile time             discovered at runtime
one union, N variants              one pointer, any embedding type
```

## Why Matryoshka needs the second one

Mailbox and Pool store `*PolyNode`, not a union:

```text
Mailbox stores  →  *PolyNode
Pool stores     →  *PolyNode
```

Neither one knows what's behind the pointer — `Event`, `Sensor`, `*Mbox`,  
anything. The type is gone the moment it becomes a `*PolyNode`.

```text
const item: *PolyNode = ...;

Without a tag: "what is this?" — unanswerable.

With a tag:
  if (item.tag == EVENT_TAG)   { ... }
  if (item.tag == SENSOR_TAG)  { ... }
  if (item.tag == MAILBOX_TAG) { ... }
```

The tag is the only thing that survives type erasure.

## Why not put everything in one tagged union instead?

That would work — until every store in the system has to agree on one closed set of  
variants:

```text
Mailbox stores Message
Pool stores Message
Everything stores Message
```

Matryoshka chooses the opposite: `*PolyNode` for everything, so any type — `Event`,  
`Sensor`, `*Mbox`, a type added next year — embeds directly, with:

- no wrapper allocation
- no copying into a union
- no central registry of every possible variant

## Comparing the two

```text
                    Tagged union       PolyNode tag
Type erased?             no                yes
Known at compile time?   yes               no
Fixed set of variants?   yes               no  (open world)
```

Adding `DatabaseConnection` next year:

- Tagged union: add a new variant, recompile every `switch` that touches the union.
- PolyNode tag: add `DATABASE_TAG`. Mailbox and Pool code — untouched.

## When each one fits

- **Pure application events** (a fixed, known set: timer, network, shutdown) — a tagged
  union is the better fit. Small, closed, compile-time checked.

- **Matryoshka's own infrastructure** (Mailbox, Pool, anything that must move through
  them without the infrastructure knowing its type) — a `PolyNode` tag is required. There  
  is no compile-time way to recover `*Event` / `*Sensor` / `**Mbox` from the same  
  intrusive queue otherwise.

Tagged unions answer *"which variant is this value?"*.  
PolyNode tags answer *"which concrete item sits behind this type-erased pointer?"*  

Different questions — both useful, in different places.
