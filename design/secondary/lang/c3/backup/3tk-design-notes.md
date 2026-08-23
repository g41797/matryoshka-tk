# Matryoshka-3tk — C3 Design Notes

Matryoshka-3tk is the C3 implementation of Matryoshka-Tk.

The goal is to preserve the Matryoshka architecture while using C3 features directly instead of mechanically porting the Zig implementation.

## Core Mapping

| matryoshka-ztk | matryoshka-3tk |
|---|---|
| `PolyNode` | `AnyNode` |
| `PolyHelper` | `AnyHelper` |
| `ItemHandle` | `AnyHandle` |
| `ItemList` | `AnyList` |
| `Item` | `Any` |
| unique type tag | `typeid` |
| `Maybe(ItemHandle)` / optional handle | nullable pointer |
| `Slot` | `AnyHandle` used through `AnyHandle*` |
| `std.DoublyLinkedList` | own `AnyList` implementation |
| Zig error unions | C3 error/result mechanisms |
| `std.Io` | none |

## AnyNode

`PolyNode` in Zig combines the intrusive list node with a unique type tag.

C3 already provides `typeid`, so the manual tag is not needed.

The C3 equivalent is:

```c3
struct AnyNode
{
    AnyNode* next;
    AnyNode* prev;
    typeid type;
}
````

`AnyNode` is the common erased representation used by Matryoshka infrastructure.

It contains:

* `next` — intrusive list link.
* `prev` — intrusive list link.
* `type` — runtime type identification.

The type tag used by the Zig implementation is therefore replaced by `typeid`.

## Inline AnyNode

Application types embed `AnyNode` using C3's `inline` feature.

Conceptually:

```c3
struct Message
{
    inline AnyNode;

    String text;
    int id;
}
```

The application object therefore contains the intrusive node directly.

The structure is:

```text
Message
├── AnyNode
│   ├── next
│   ├── prev
│   └── type
├── text
└── id
```

The same mechanism is used for Matryoshka-owned objects such as `Mbox` and `Pool`.

## AnyHandle

`AnyHandle` is the common erased handle.

It is simply:

```c3
AnyHandle = AnyNode*;
```

Conceptually:

```text
Application object
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

Infrastructure works with `AnyHandle` and therefore does not need to know the concrete application type.

## Slot

C3 allows nullable pointers, so a separate optional/Maybe type is not required for handles.

Therefore:

```text
AnyHandle = AnyNode*
```

and a Slot is an `AnyHandle` used through a pointer:

```c3
AnyHandle* slot;
```

This is effectively a pointer-to-pointer.

An empty Slot is:

```c3
*slot = null;
```

A populated Slot contains an `AnyHandle`.

The API therefore uses:

```c3
AnyHandle*
```

where the Zig implementation used a Slot abstraction.

The Slot is a way to pass a handle that may be replaced or cleared.

It is not itself the object being sent.

## AnyHelper

`PolyHelper` becomes `AnyHelper`.

The implementation should be simpler than the Zig version because C3 already provides:

* `typeid`;
* `any`-related facilities;
* macros/generic facilities;
* compile-time type information.

`AnyHelper` should therefore not mechanically reproduce the Zig `PolyHelper`.

Its main responsibilities are expected to be:

* convert between a concrete type and `AnyNode*`;
* recover the containing object from `AnyNode*`;
* check that a concrete type is compatible with `AnyNode`;
* perform type checks using `typeid`;
* provide compile-time validation where C3's type information allows it.

An important C3 advantage is that properties of a type can be checked at compile time.

For example, `AnyHelper` may be able to validate that a supplied type:

* is an appropriate struct;
* contains the required inline `AnyNode`;
* can be converted to/from `AnyNode*`;
* satisfies the structural requirements of Matryoshka.

The exact implementation should be decided after investigating C3's generics, macros, and compile-time reflection facilities.

## Type Identification

The stored field:

```c3
typeid type;
```

provides runtime identification of the object type.

This replaces the manually created unique pointer tag used by the Zig implementation.

However, runtime `typeid` and compile-time type information should remain conceptually separate:

```text
compile time
    │
    └── validate concrete type with C3 type information

runtime
    │
    └── AnyNode.type identifies the concrete type
```

`typeid` should not automatically be treated as an enum replacement in every context.

## AnyList

C3 does not provide the intrusive doubly linked list abstraction used by the Zig implementation.

Therefore `AnyList` should be one of the first fully implemented Matryoshka-3tk components.

`AnyList` operates directly on `AnyNode*`.

The list does not need to know the concrete type of its elements.

Conceptually:

```text
AnyList
├── first: AnyHandle
├── last: AnyHandle
└── count/state as required

AnyHandle
├── next
├── prev
└── type
```

`AnyList` should provide the fundamental intrusive-list operations required by the rest of Matryoshka.

This is important because both `Mbox` and `Pool` will depend on the same primitive.

The first implementation should therefore establish:

* insertion;
* removal;
* first/last access;
* iteration;
* empty checks;
* moving nodes between lists;
* safe handling of `null`;
* ownership/in-list invariants.

The exact API should be designed around C3 rather than copied from `std.DoublyLinkedList`.

## Mbox

`Mbox` is itself an `AnyNode`-based object.

It should embed `AnyNode` inline.

Conceptually:

```c3
struct Mbox
{
    inline AnyNode;

    @private AnyHandle head;
    @private AnyHandle tail;

    // other private implementation state

    // public API
}
```

The important point is that `Mbox` does **not** merely contain an `AnyNode*`.

`Mbox` itself has an embedded `AnyNode`.

Therefore:

```text
Mbox*
  │
  ▼
AnyNode
```

The same `AnyNode` representation can be used by generic Matryoshka infrastructure.

## Pool

`Pool` follows the same pattern.

It is itself an `AnyNode`-based object.

Conceptually:

```c3
struct Pool
{
    inline AnyNode;

    @private AnyHandle available;
    
    // other private implementation state

    // public API
}
```

Again:

```text
Pool*
  │
  ▼
AnyNode
```

`Mbox` and `Pool` therefore participate in the same AnyNode model as application objects.

## Information Hiding

C3 provides private struct fields.

This allows `Mbox` and `Pool` to remain public concrete structs while hiding implementation state.

The intended design is:

```text
public Mbox
├── inline AnyNode
├── public API
└── private implementation fields

public Pool
├── inline AnyNode
├── public API
└── private implementation fields
```

This is preferable to introducing a separate opaque handle purely for information hiding.

The exact visibility syntax should follow the C3 version used by matryoshka-3tk.

## PoolHooks

The Pool hook concept is retained from the Zig implementation.

The hook set contains:

```text
PoolHooks
├── ctx
├── tags
├── on_get
├── on_put
└── on_close
```

The general C3 shape is:

```c3
struct PoolHooks
{
    void* ctx;
    uint tags;

    // Exact signatures to be finalized.
    // Items are represented by AnyHandle / AnyNode*.

    ...
}
```

The important architectural rule is that Pool works with `AnyHandle`.

Hooks can use `AnyHelper` to recover/check the concrete application type when necessary.

Conceptually:

```text
Pool
 │
 ├── AnyHandle
 │
 └── PoolHooks
       ├── ctx
       ├── tags
       ├── on_get
       ├── on_put
       └── on_close
```

The exact hook signatures should be designed from C3 semantics rather than directly copied from Zig.

In particular, C3 error handling and pointer semantics may allow a simpler API.

## Allocators

Allocator usage is conceptually similar to Zig.

Allocation remains explicit.

Components should receive/use an allocator rather than silently depending on a global allocator.

The architecture should preserve:

* explicit allocation;
* explicit deallocation;
* clear allocator lifetime;
* allocator ownership by the appropriate component;
* no hidden global allocation dependency.

The exact allocator API is C3-specific and should not be treated as a direct translation of `std.mem.Allocator`.

## Error Handling

C3 error handling differs from Zig error unions.

The C3 implementation should therefore preserve **semantic results**, not Zig syntax.

For example, the Zig Pool result concept contains states such as:

```text
item
closed
timeout
canceled
not_created
```

The C3 implementation should express the same semantics using appropriate C3 result/error mechanisms.

Do not introduce a fake Zig-style error-union layer merely to make the port look similar.

The same principle applies to Mbox operations.

## No std.Io

Matryoshka-3tk has no equivalent of Zig's `std.Io`.

Nothing in the C3 implementation should be designed around `std.Io`.

In particular:

```text
std.Io
std.Io.Mutex
std.Io.Condition
std.Io task model
std.Io allocator integration
```

are not part of the C3 design.

Matryoshka-Tk is not an I/O framework.

Synchronization and blocking required by `Mbox` should use appropriate C3/platform facilities without introducing an artificial Matryoshka I/O abstraction.

The architecture remains independent of the I/O layer.

## Naming

If `Any` is available as a user-defined identifier in the selected C3 version, use `Any` consistently.

Preferred naming:

```text
Item       → Any
ItemHandle → AnyHandle
ItemList   → AnyList
PolyNode   → AnyNode
PolyHelper → AnyHelper
```

This is particularly natural because the C3 implementation already uses the `AnyNode` concept and C3 has its own `any` type mechanism.

Before committing the names, verify that `Any` is not a reserved keyword or otherwise unsuitable as a user-defined type name in the C3 version used by matryoshka-3tk.

## Initial Implementation Order

`AnyList` should be the first full implementation.

Reason:

```text
AnyNode
   │
   ▼
AnyHandle
   │
   ▼
AnyList
   │
   ├── Mbox
   └── Pool
```

`AnyList` establishes the intrusive-list primitive that the other components need.

After that, implement the type/handle layer:

```text
AnyNode
AnyHandle
AnyHelper
```

Then build:

```text
AnyList
    ↓
Mbox
Pool
```

and finally integrate:

```text
PoolHooks
Slot APIs
error/result semantics
synchronization
allocation
```

## Important Design Rule

Do not make matryoshka-3tk a line-by-line translation of matryoshka-ztk.

The goal is:

```text
same architecture
same semantics
different language-native implementation
```

C3 features should be used where they simplify the implementation:

```text
typeid
    ↓
simpler type identification

inline
    ↓
direct AnyNode embedding

nullable pointers
    ↓
simple AnyHandle / Slot representation

private fields
    ↓
direct information hiding

compile-time type information
    ↓
stronger AnyHelper validation

C3 error mechanisms
    ↓
native result/error handling

C3 allocators
    ↓
native allocation model

C3 synchronization
    ↓
native Mbox implementation
```

The Matryoshka architecture remains the invariant.

The implementation details are allowed to differ where C3 provides a better or simpler mechanism.
