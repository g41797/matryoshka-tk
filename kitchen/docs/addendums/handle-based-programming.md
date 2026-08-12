

# Handle-Based Programming

---


Handle-Based Programming is 

- a programming style 
- where components communicate through handles 
- instead of concrete object types

A handle represents an object.

The handle defines how the object is accessed.

Different handle types may serve different purposes.

---



## ItemHandle

---


`ItemHandle` has a different purpose.

It provides a common way to work with every application item.

The infrastructure never needs to know the actual item type.  
It operates only on `ItemHandle`.

The application can recover the actual item from an `ItemHandle`.

Likewise, an application item can produce its corresponding `ItemHandle`.

This allows infrastructure and application code 

- to communicate 
- using a single representation 
- while preserving access to the original object 
- when needed

---


## One pointer, two names

`ItemHandle` and `*PolyNode` are the same pointer.

The name says what you mean to do with it.

`ItemHandle` — you are carrying it.

Hold it. Send it. Put it in a Slot.

Do not look inside.

`*PolyNode` — you are opening it.

Read the tag. Reach the item.

`PolyHelper` is the only thing that takes it.

So `fromPoly` is the border:

```zig
const ev = EventPolyHelper.fromPoly(handle) orelse return;
```

The pointer arrives opaque.

It leaves as an `*Event`.

Nothing was converted. Nothing was allocated.

You changed your mind about what you were holding.

---


## Matryoshka

---


Infrastructure components such as `Mailbox` and `Pool` always exchange `ItemHandle`s.

Applications work with their own item types.

Conversion between an application item and its `ItemHandle` is explicit and inexpensive.

As a result

- the infrastructure is completely generic
- while applications remain fully type-safe
