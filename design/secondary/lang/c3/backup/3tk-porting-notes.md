# Matryoshka-3tk — Porting Notes

Matryoshka-3tk is the C3 implementation of Matryoshka-Tk.

The goal is not a line-by-line port of matryoshka-ztk.

The goal is to preserve the architecture and semantics while using C3-native features where they simplify the implementation.

```text
same architecture
same semantics
C3-native implementation
````

## Core Naming

The current proposed mapping is:

| matryoshka-ztk            | matryoshka-3tk                  |
| ------------------------- | ------------------------------- |
| `PolyNode`                | `AnyNode`                       |
| `PolyHelper`              | `AnyHelper`                     |
| `Item`                    | `Any`                           |
| `ItemHandle`              | `AnyHandle`                     |
| `ItemList`                | `AnyList`                       |
| unique static tag pointer | `typeid`                        |
| optional handle / `Maybe` | nullable pointer                |
| `std.DoublyLinkedList`    | `AnyList`                       |
| Zig error unions          | C3-native result/error handling |
| Zig `std.Io` integration  | no equivalent                   |

C3 is case-sensitive.

The language concept is lowercase `any`.

The Matryoshka name may therefore use uppercase `Any`.

The two should not be confused.

```text
C3:
any

Matryoshka:
Any
AnyNode
AnyHandle
AnyList
AnyHelper
```

The exact final naming should be verified against the C3 version used by the project.

## AnyNode

`PolyNode` in Zig combines:

* intrusive list links;
* runtime type identification.

The C3 equivalent is:

```c3
struct AnyNode
{
    AnyNode* next;
    AnyNode* prev;
    typeid type;
}
```

`AnyNode` is the common representation used by generic Matryoshka infrastructure.

It provides:

```text
AnyNode
├── next
├── prev
└── type
```

The Zig implementation uses a manually created unique tag.

Matryoshka-3tk should use C3 `typeid` instead.

```text
matryoshka-ztk

PolyNode
├── next
├── prev
└── unique tag pointer


matryoshka-3tk

AnyNode
├── next
├── prev
└── typeid
```

The type is stored in the node.

The node remains intrusive.

This is different from using C3 `any` as the representation of every Matryoshka object.

`any` is therefore not a replacement for `AnyNode`.

## Inline Embedding

Concrete application and infrastructure types embed `AnyNode` inline.

The intended shape is:

```c3
struct Message
{
    inline AnyNode;

    String text;
    int id;
}
```

Conceptually:

```text
Message
├── AnyNode
│   ├── next
│   ├── prev
│   └── type
├── text
└── id
```

The same design applies to Matryoshka infrastructure objects.

For example:

```c3
struct Mbox
{
    inline AnyNode;

    @private ...
}
```

and:

```c3
struct Pool
{
    inline AnyNode;

    @private ...
}
```

The important rule is:

> `Mbox` and `Pool` are themselves AnyNode-based objects.

They do not merely contain an unrelated `AnyNode*`.

The exact C3 syntax for the inline member and the resulting conversion/member-access rules must follow the C3 version used by matryoshka-3tk.

Do not replace inline embedding with a requirement that `AnyNode` must merely be the first ordinary field unless that is required by the final C3 implementation.

Inline embedding is the intended C3-native design.

## AnyHandle

The common erased handle is:

```c3
typedef AnyHandle = AnyNode*;
```

Conceptually:

```text
Concrete object
       │
       ▼
embedded AnyNode
       │
       ▼
   AnyNode*
       │
       ▼
   AnyHandle
```

Matryoshka infrastructure uses `AnyHandle` when it does not need to know the concrete type.

For example:

```text
AnyList
Mbox item queues
Pool available items
generic infrastructure
```

all work with the common handle representation.

## Typed Handles

`AnyHandle` is the common erased handle.

Some public APIs may additionally use distinct handle types.

For example:

```c3
typedef MboxHandle = AnyNode*;
typedef PoolHandle = AnyNode*;
```

The purpose is not to change the runtime representation.

The purpose is to provide static API separation.

Conceptually:

```text
AnyHandle
    │
    ├── common infrastructure representation
    │
    ├── MboxHandle
    │      └── Mbox-specific API
    │
    └── PoolHandle
           └── Pool-specific API
```

This allows C3 methods to express the intended API:

```text
mbox_handle.send(...)
pool_handle.put(...)
```

A `MboxHandle` should not accidentally expose Pool operations.

Typed handles and `AnyHandle` therefore serve different purposes:

```text
AnyHandle
    generic transport and infrastructure

MboxHandle
    Mbox public API

PoolHandle
    Pool public API
```

The final implementation should verify exactly how C3 distinct typedefs interact with pointers and methods in the target compiler version.

## Slot

C3 pointers may be null.

Therefore a separate optional wrapper is not needed merely to represent an empty handle.

A Slot is based on:

```text
AnyHandle
=
AnyNode*
```

An empty handle is:

```c3
AnyHandle handle = null;
```

When an operation must modify the caller's handle, the API receives:

```c3
AnyHandle* slot
```

This is effectively:

```text
AnyNode**
```

Example:

```c3
AnyHandle slot = null;

// API receives:
some_operation(&slot);
```

The operation may:

* read the handle;
* replace the handle;
* consume the handle;
* clear the handle.

For example:

```c3
*slot = null;
```

after consuming the value.

Therefore:

> Slot is not another runtime wrapper type.

> Slot describes the use of an `AnyHandle` through `AnyHandle*`.

This is the C3 replacement for the Zig optional-pointer Slot pattern.

## Slot Semantics

The Slot is a container for a handle during an API operation.

The handle itself is what moves through the system.

Conceptually:

```text
slot
 │
 └── AnyHandle
       │
       └── AnyNode*
```

Do not think of the Slot itself as an object being sent.

The Slot exists so an operation can transfer or clear the caller's current handle.

Typical operations include:

```text
fromSlot
mustFromSlot
moveFromSlot
create
destroy
```

A move operation should normally:

1. validate the handle;
2. obtain the concrete object;
3. verify required invariants;
4. clear the Slot;
5. return the object.

For example:

```text
slot ──► handle

move

slot ──► null
          │
          ▼
       returned object
```

## AnyHelper

`AnyHelper` replaces Zig `PolyHelper`.

It should not be a mechanical translation.

C3 provides features that can simplify the implementation:

* `typeid`;
* compile-time type information;
* generics;
* macros;
* inline embedding;
* contracts.

The exact choice between a macro, generic facility, or combination should be decided after implementing a small working prototype.

The design requirements are more important than the exact mechanism.

`AnyHelper` should provide the operations needed to work between a concrete type and `AnyHandle`.

The conceptual API is:

```text
is
fromAny
mustFromAny
toAny

fromSlot
mustFromSlot
moveFromSlot

init

create
destroy
```

Names may be adjusted for C3 style.

The important semantics should remain.

## AnyHelper Responsibilities

For a concrete type `T`, `AnyHelper(T)` conceptually knows:

```text
T
└── inline AnyNode
```

It should provide:

### Type identification

Check whether an `AnyHandle` belongs to `T`.

Conceptually:

```text
node.type == T::typeid
```

### Conversion from AnyHandle

Convert:

```text
AnyHandle
    ↓
T*
```

A normal conversion may return null or another C3-native recoverable result if the type does not match.

A required conversion should treat a mismatch as an invariant failure.

Conceptually:

```text
fromAny
    type mismatch is represented to caller

mustFromAny
    type mismatch violates a contract
```

### Conversion to AnyHandle

Convert:

```text
T*
 ↓
AnyHandle
```

### Slot operations

Work with:

```text
AnyHandle*
```

without requiring a separate optional wrapper type.

### Initialization

Initialize the embedded node:

```text
next = null
prev = null
type = T::typeid
```

The exact initializer syntax should be C3-native.

## Compile-Time Validation

This is one of the main areas where the C3 implementation may improve on the Zig implementation.

`AnyHelper(T)` should investigate whether C3 compile-time facilities can validate that `T` is a valid Matryoshka Any type.

Possible checks include:

* `T` is an appropriate struct;
* `T` contains or embeds `AnyNode` in the required way;
* the conversion between `T` and its embedded `AnyNode` is valid;
* required helper assumptions hold.

The exact available checks depend on the C3 reflection and macro facilities actually supported by the target compiler version.

Do not claim a particular compile-time check exists until it has been verified with working C3 code.

The intended model is:

```text
compile time
    │
    ├── validate T
    └── generate or specialize helper operations

runtime
    │
    └── compare stored node.type with expected typeid
```

Compile-time validation and runtime type identification solve different problems.

Both may be used by `AnyHelper`.

## Runtime Type Checks

The runtime type stored in `AnyNode` should be checked at conversion boundaries.

For example:

```text
AnyHandle
    │
    ▼
AnyHelper(T).fromAny
    │
    ├── type matches
    │      └── return T*
    │
    └── type does not match
           └── report mismatch
```

A required conversion should use a contract or assertion.

Wrong internal handle types are normally programming errors.

They should not become ordinary Pool or Mbox result states.

Therefore:

```text
type mismatch
    ↓
invariant / contract failure
```

rather than:

```text
type mismatch
    ↓
normal application error
```

The exact C3 contract syntax must follow the target compiler version.

## Typeid and switch

C3 `typeid` may support switching on concrete types.

This can be useful when code intentionally handles several known concrete types.

For example conceptually:

```text
switch node.type
├── Mbox
├── Pool
└── ...
```

However, this is not the primary purpose of `AnyHelper`.

`AnyHelper` should normally convert one known expected type.

The common operation remains:

```text
node.type == expected typeid
```

Do not design the basic Any infrastructure around large type switches unless there is a real use case.

## AnyList

C3 does not provide the intrusive doubly linked list abstraction used by the Zig implementation.

Therefore `AnyList` should be one of the first full Matryoshka-3tk implementations.

`AnyList` operates directly on:

```text
AnyHandle
=
AnyNode*
```

The concrete type of each element is irrelevant to the list.

Conceptually:

```text
AnyList
├── first
├── last
└── state required by the implementation

AnyNode
├── next
├── prev
└── type
```

The first implementation should establish the fundamental intrusive-list invariants and operations required later by `Mbox` and `Pool`.

Likely operations include:

* empty;
* first;
* last;
* push;
* append;
* insert;
* remove;
* pop;
* iteration;
* reset.

The exact API should follow Matryoshka semantics and C3 style.

It should not be copied mechanically from Zig `std.DoublyLinkedList`.

Important invariants include:

* a node must not be inserted twice;
* removal clears or otherwise consistently updates links;
* list boundaries remain valid;
* moving a node between lists preserves intrusive-list invariants.

`AnyList` should become the first right-sized complete building block because later components depend on it.

```text
AnyNode
    ↓
AnyHandle
    ↓
AnyList
   ↙   ↘
Mbox  Pool
```

## Mbox

`Mbox` is an AnyNode-based object.

Its conceptual shape is:

```c3
struct Mbox
{
    inline AnyNode;

    // private implementation state

    // public API
}
```

C3 private fields allow the concrete struct to remain public while implementation state remains hidden.

Conceptually:

```text
Mbox
├── inline AnyNode
├── public API
└── private implementation state
```

This means a separate opaque handle is not required merely for information hiding.

Typed handles may still be useful for API separation.

Those are different concerns.

```text
private fields
    hide implementation state

typed handles
    restrict API usage
```

Do not mix these two reasons.

## Pool

`Pool` follows the same AnyNode-based design.

Conceptually:

```c3
struct Pool
{
    inline AnyNode;

    // private implementation state

    // public API
}
```

Again:

```text
Pool
├── inline AnyNode
├── public API
└── private implementation state
```

`Pool` itself is not an ordinary application item.

It has its own lifetime and construction requirements.

This affects `AnyHelper.create` and `AnyHelper.destroy`.

## create and destroy

Normal application Any types should be able to use convenience allocation helpers.

Conceptually:

```text
create
    allocate T
    initialize T
    initialize AnyNode
    store AnyHandle in Slot

destroy
    validate handle
    verify required invariants
    clear Slot
    destroy/deallocate T
```

`Mbox` and `Pool` have different lifetime requirements.

They should not be forced through the same generic construction path merely because they also embed `AnyNode`.

However, the opt-out mechanism must be real and explicit.

Do not depend on speculative syntax such as an unverified:

```text
Type.has_tag(...)
```

or an invented attribute convention.

Possible designs to investigate are:

### Separate helper variants

```text
AnyHelper(T)
    full helper

AnyHelperNoAlloc(T)
    no create/destroy
```

### Explicit helper configuration

A macro or generic parameter selects whether allocation helpers are generated.

Conceptually:

```text
AnyHelper(T, with_create_destroy)
```

### Core helper plus allocation extension

Keep:

```text
AnyHelper
```

for conversion and initialization.

Provide allocation helpers separately.

This may be the simplest separation because construction is not fundamentally part of type conversion.

The final choice should be made after testing what C3 macros and generics make cleanest.

The important rule is:

> Do not invent language features to reproduce the Zig implementation.

> Prefer the simplest verified C3 design.

## PoolHooks

The existing Pool hook model contains:

```text
PoolHooks
├── ctx
├── tags
├── on_get
├── on_put
└── on_close
```

The C3 implementation should be reconsidered separately.

A possible C3-native direction is an interface.

That would change:

```text
ctx + function pointers
```

into:

```text
hook implementation object
+
dynamic hook methods
```

Conceptually:

```text
Pool
 │
 ▼
PoolHooks interface
 │
 ▼
concrete hook implementation
├── state
├── tags or configuration
├── on_get
├── on_put
└── on_close
```

In this design the implementation object itself replaces the old callback `ctx`.

However, this should not be treated as final until the exact C3 interface implementation is verified.

The interface design and function-pointer design should be compared against:

* simplicity;
* allocation requirements;
* lifetime;
* whether hooks may be absent;
* static versus dynamic dispatch;
* how tags are exposed;
* compatibility with the existing Pool semantics.

The existing hook semantics should be preserved before choosing the C3 representation.

## Allocators

Allocator usage should remain explicit.

The C3 implementation should preserve the architectural principles:

* no hidden global allocator requirement;
* explicit allocation;
* explicit deallocation;
* clear allocator lifetime;
* construction controlled by the owning component.

The exact C3 allocator type and API should be used directly.

Do not mechanically reproduce:

```text
std.mem.Allocator
```

from Zig.

Preserve the allocation semantics.

Use C3-native allocator mechanics.

## Error and Result Handling

C3 error handling differs from Zig error unions.

Matryoshka-3tk should preserve semantic outcomes rather than Zig syntax.

For example, Pool may need outcomes conceptually equivalent to:

```text
item
closed
timeout
canceled
not_created
```

These are operation results.

They should be represented using the appropriate C3-native result/error mechanisms.

Do not automatically treat every non-item result as an error.

There is an important distinction:

```text
expected operational outcome
    closed
    timeout
    canceled
    not_created
```

versus:

```text
programming invariant failure
    wrong handle type
    invalid intrusive links
    impossible internal state
```

The first category belongs to the public operation semantics.

The second category belongs to contracts/assertions/invariants.

This distinction should remain explicit throughout the port.

## No std.Io Dependency

Matryoshka-3tk has no Zig `std.Io` dependency.

There is no reason to invent a C3 equivalent.

Matryoshka-Tk is not an I/O framework.

Therefore:

```text
matryoshka-ztk
    std.Io integration

matryoshka-3tk
    no corresponding abstraction
```

Synchronization and blocking required by `Mbox` should use appropriate C3 or platform facilities.

The Matryoshka architecture itself remains independent of the I/O implementation.

Do not introduce an artificial:

```text
3tk Io
```

layer merely because ztk uses Zig `std.Io`.

## Public Structs and Private State

C3 allows a useful design for Matryoshka components.

The type may be public.

Its implementation state may remain private.

Conceptually:

```text
public Pool
├── public operations
├── inline AnyNode
└── private state
```

and:

```text
public Mbox
├── public operations
├── inline AnyNode
└── private state
```

This can simplify the information-hiding design compared with approaches that require opaque handles only to hide fields.

Again, typed handles may still exist.

Their purpose is API typing, not necessarily information hiding.

## Import Placement

C3 imports do not need to appear textually before every use in the same file in the simple way assumed by some languages.

The project may therefore place imports according to C3 rules and source organization.

For readability, imports should still normally be organized clearly.

Do not impose an artificial "all imports must be at the beginning before any declaration" rule unless required by the C3 compiler or project style.

The compiler's actual module/import rules should remain the authority.

## Initial Implementation Order

The recommended order is:

```text
1. Verify core C3 language assumptions with small compilable examples
   │
   ├── inline AnyNode embedding
   ├── typeid initialization and comparison
   ├── concrete ↔ AnyNode conversion
   ├── distinct handle typedefs
   ├── methods on typed handles
   ├── contracts
   └── macro/generic capabilities needed by AnyHelper
   │
2. Implement AnyNode and AnyHandle
   │
3. Implement AnyList completely
   │
4. Prototype AnyHelper
   │
   ├── compile-time validation
   ├── fromAny
   ├── toAny
   ├── Slot operations
   └── init
   │
5. Decide create/destroy separation
   │
6. Implement Mbox
   │
7. Implement Pool
   │
8. Finalize PoolHooks
   │
9. Integrate C3-native synchronization
   │
10. Finalize C3-native result/error APIs
```

The first complete real building block should be:

```text
AnyList
```

This gives the project a tested intrusive foundation before adding concurrency, blocking, hooks, allocation policy, and complex result semantics.

## Verification Rule

Several earlier proposals were written before exact C3 syntax and semantics were verified.

For matryoshka-3tk, every language-specific design should be divided into two categories.

### Confirmed design

These are architectural decisions:

```text
AnyNode replaces PolyNode
typeid replaces the Zig unique tag
AnyNode is intrusive
concrete objects embed AnyNode inline
AnyHandle is AnyNode*
Slot uses AnyHandle*
AnyList replaces std.DoublyLinkedList usage
Mbox and Pool are AnyNode-based objects
private fields can hide implementation state
no std.Io equivalent is required
C3-native error handling should replace Zig error syntax
```

### Requires a compilable C3 prototype

These are implementation details:

```text
exact AnyHelper macro/generic syntax
exact compile-time validation syntax
exact inline conversion syntax
exact distinct typedef behavior
exact contract syntax
exact create/destroy opt-out mechanism
exact allocator API
exact interface implementation for PoolHooks
exact synchronization primitives
```

Do not turn a possible C3 feature into a Matryoshka design dependency until it has been compiled and tested.

## Main Porting Principle

Matryoshka-3tk should not imitate the surface syntax of matryoshka-ztk.

The architecture is the invariant.

The implementation is allowed to become simpler where C3 provides a direct mechanism.

```text
Zig unique tag
        ↓
C3 typeid

Zig Maybe/optional handle
        ↓
nullable pointer

Zig intrusive list dependency
        ↓
own AnyList

Zig PolyHelper
        ↓
C3-native AnyHelper

Zig opaque information-hiding approach
        ↓
public structs with private state where appropriate

Zig std.Io integration
        ↓
no equivalent abstraction

Zig error unions
        ↓
C3-native result/error design
```

The objective is not:

```text
make C3 look like Zig
```

The objective is:

```text
make Matryoshka work naturally in C3
```
