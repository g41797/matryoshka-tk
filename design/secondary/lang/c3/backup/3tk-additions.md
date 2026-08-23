# 1 Pool Hooks possible implementation

Yes. After checking the current C3 interface model, I think interfaces are a better candidate for PoolHooks than a struct containing function pointers.

C3 interfaces are specifically intended to define a set of methods implemented by a type. An interface value carries a pointer plus typeid, and an implementing type provides the methods with @dynamic. (C3 Programming Language)
Possible PoolHooks interface

The shape could be:

interface PoolHooks
{
    void on_get(AnyHandle item);
    AnyHandle on_put(AnyHandle item);
    void on_close();
}

Then an application-specific hooks type implements it:

struct MyHooks (PoolHooks)
{
    void* ctx;
}

fn void MyHooks.on_get(MyHooks* self, AnyHandle item) @dynamic
{
    // ...
}

fn AnyHandle MyHooks.on_put(MyHooks* self, AnyHandle item) @dynamic
{
    // ...
    return item;
}

fn void MyHooks.on_close(MyHooks* self) @dynamic
{
    // ...
}

And Pool could hold:

struct Pool
{
    inline AnyNode;

    @private PoolHooks hooks;
    @private AnyHandle available;
}

But there is an important difference

Our old Zig PoolHooks had:

ctx
tags
on_get
on_put
on_close

An interface changes the model:

PoolHooks
    │
    └── implementation object
          ├── application state
          ├── on_get()
          ├── on_put()
          └── on_close()

So ctx disappears as a separate field.

The implementation object itself becomes the context.

That is actually very attractive in C3.

For example:

Pool
 │
 │ PoolHooks interface
 ▼
MyHooks
 ├── ctx/state
 ├── on_get
 ├── on_put
 └── on_close

This is cleaner than:

Pool
 │
 ▼
PoolHooks
 ├── ctx
 ├── function pointer
 ├── function pointer
 └── function pointer

What about tags?

tags is the one part I would not automatically put into the interface.

If tags are configuration/metadata belonging to the hook implementation, they can simply be fields of MyHooks.

If Pool itself needs to inspect tags generically, then we should define how that is exposed—possibly as another interface method.
Important C3 advantage

C3 interfaces give us dynamic dispatch without manually constructing a vtable. The compiler retains @dynamic methods for interface/runtime dispatch. (C3 Programming Language)

And this fits especially well with our AnyNode/typeid direction:

AnyNode
    │
    └── typeid ──► concrete Any type

PoolHooks
    │
    └── interface ──► concrete hook implementation

There is also a useful distinction:

    AnyHandle / AnyNode = type-erased data object.

    PoolHooks interface = type-erased behavior.

That is a very natural C3 design.
One thing to reconsider

I would not include ctx in the interface signatures.

This:

void on_get(void* ctx, AnyHandle item);

would be carrying the C-style callback model into C3.

The interface model gives us:

void MyHooks.on_get(MyHooks* self, AnyHandle item) @dynamic

where self is the context.

So my current recommendation is:

Use a PoolHooks interface, and make the hook implementation object itself carry the state formerly represented by ctx.

That is more C3-native than a function-pointer callback table. (C3 Programming Language)

One correction from our earlier discussion is also now clear: Any cannot be used as our user-defined type name because any is a reserved C3 keyword (C3 identifiers are case-sensitive, but the language's naming rules also reserve the keyword itself). (C3 Programming Language) So AnyNode, AnyHandle, etc. are fine, but a type literally named Any should not be part of the design.



# 2 Mbox/Pool possible implementation


**Yes**, you can call it that way in C3.

### How it works

In C3, methods are just functions whose name is prefixed with the type:

```c3
fn void Something.doSomething(Something* smt)
{
    // ...
}
```

You can invoke them with **dot syntax**.

### Calling rules

Given:

```c3
Something* s = &some_value;
```

Both of these are valid and equivalent:

```c3
s.doSomething();                 // preferred style
Something.doSomething(s);        // explicit form
```

- When you write `s.doSomething()`, C3 sees that the first parameter of the method is `Something*` and that `s` is already a `Something*`, so it just passes `s` as the first argument.
- The same method can also be called on a value:

```c3
Something value = ...;
value.doSomething();             // C3 automatically takes the address → passes &value
```

### Summary

| Receiver          | Method first param     | Call style              | What is passed     |
|-------------------|------------------------|-------------------------|--------------------|
| `Something*`      | `Something*`           | `s.doSomething()`       | `s` (the pointer)  |
| `Something` (value) | `Something*`         | `value.doSomething()`   | `&value`           |
| either            | `Something` (by value) | `.doSomething()`        | the value itself   |

So yes — with a method defined as `fn void Something.doSomething(Something* smt)`, the call `s.doSomething()` works perfectly.


# 3 Proposal for Slot - usage ptr to ptr

The reason comes down to a fundamental design difference in how these three languages handle pointers and nullability.
While all three languages are modern replacements for C, they chose completely opposite paths regarding whether a standard pointer is allowed to be null by default.
Here is the breakdown of why your code looks different in each language:
1. Zig: *?*T

    Pointers are Non-Null by Default: In Zig, a standard pointer *T cannot be null. The compiler will throw an error if you try to assign null to it.
    The Solution: To allow a pointer to be empty, you must wrap it in an optional type using ?. Therefore, an optional pointer is written as ?*T.
    The Slot Argument: To pass that slot into a function as an in/out parameter, you take a pointer to the optional pointer, resulting in *?*T. [1, 2] 

2. Odin: ^Maybe(T) or ^Maybe(^T)

    Pointers are Nullable, but explicit safety is preferred: In Odin, raw pointers (^T) can technically be nil. However, Odin provides a built-in Maybe generic type to explicitly declare that a value or pointer might be missing, which works beautifully with its switch pattern matching.
    The Slot Argument: To pass this container into a function as an in/out parameter, you pass a pointer to the Maybe wrapper, giving you ^Maybe(^T). [3, 4, 5, 6] 

3. C3: **T (Double Pointer)

    Pointers are Nullable by Default: Unlike Zig, C3 decided to keep the classic C behavior for pointers. In C3, any standard pointer (Request*) is inherently allowed to be null. You do not need a special keyword or symbol to make a pointer nullable.
    The Native Optional (~) is NOT for pointers: C3 has an optional type T~, but it is not a simple null-pointer wrapper like Zig's ?. In C3, ~ creates a heavy "Result/Fault" structure meant for error handling. Wrapping a pointer in a C3 optional (Request*~) adds unnecessary memory and runtime overhead. [7]
    The Slot Argument: Since a standard pointer Request* can already be null, it already functions exactly like Zig's ?*T. To pass it as an in/out argument, you just use a standard C-style pointer-to-a-pointer: Request**.

Comparison Summary
Language	The Pointer	The "Slot" (Optional Pointer)	In/Out Argument (Pointer to Slot)
Zig	*T (Never Null)	?*T	*?*T
Odin	^T (Can be Nil)	Maybe(^T)	^Maybe(^T)
C3	T* (Can be Null)	T*	T**
You are using a double pointer in C3 because C3 pointers already have Zig's ? optional logic built right into them.
If you want to tell the C3 compiler explicitly that a pointer should never be null, you have to use a macro contract or a runtime check, whereas Zig makes you opt-in to nullability explicitly.
Would you like to see how to add a C3 Function Contract (@require) to your double-pointer functions so the compiler can still guarantee safety like Zig does?

[1] https://zig.guide
[2] https://pedropark99.github.io
[3] https://odin-lang.org
[4] https://odin-lang.org
[5] https://www.reddit.com
[6] https://news.ycombinator.com
[7] https://lobste.rs


# 4 AnyNode thinkings

**No — not directly.**

### Why

```c3
typedef MboxHandle = AnyNode*;   // distinct type
typedef PoolHandle = AnyNode*;   // distinct type
```

- `mbh` has type `MboxHandle`
- `&mbh` has type `MboxHandle*`
- The function expects `AnyNode**`

Because `MboxHandle` is a **distinct** type, there is **no** implicit conversion from `MboxHandle*` → `AnyNode**`.

### What works

You need an explicit cast (or a temporary):

```c3
// Option 1: explicit cast
doit((AnyNode**)&mbh, ...);
doit((AnyNode**)&plt, ...);

// Option 2: temporary of the base type
AnyNode* tmp = mbh;          // this conversion is also not implicit
                             // unless you used `inline`
doit(&tmp, ...);
```

### If you want the conversion to be implicit

Make the handles `inline`:

```c3
typedef MboxHandle = inline AnyNode*;
typedef PoolHandle = inline AnyNode*;
```

Then:

```c3
AnyNode* n = mbh;        // OK – converts to base type
```

But even with `inline`, taking the address still gives you `MboxHandle*`, so:

```c3
doit(&mbh, ...);         // still NOT allowed
```

You would still need the cast for the double pointer.

### Summary

| Call                    | Allowed? | Reason                              |
|-------------------------|----------|-------------------------------------|
| `doit(&mbh, ...)`       | No       | `MboxHandle*` ≠ `AnyNode**`         |
| `doit((AnyNode**)&mbh)` | Yes      | Explicit cast                       |
| `doit(&tmp)` where `tmp` is `AnyNode*` | Yes | Correct type                |

So for a function taking `AnyNode**` you must cast (or go through a temporary of type `AnyNode*`).

