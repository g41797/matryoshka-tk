# Slot Idiom

A Slot is a small, simple programming idiom.

It is useful when a pointer needs to move from one piece of code to another.

The Slot is a **container for a pointer**.

The pointer is either there or not there.

In Zig, an optional pointer is enough to implement it.

---

## Start with an object

Consider a dynamically allocated object:

```zig
const Request = struct {
    id: u32,
    data: []u8,
};

pub fn new(alloc: std.mem.Allocator) !*Request {
		................
}

const request = try Request.new(gpa);
````

`request` is a pointer:

```zig
*Request
```

The `Request` object lives somewhere in allocated memory.

The pointer tells us where it is.

Now we need a container that can contain this pointer.

```zig
var slot: ?*Request = null;
```

This is a Slot.

It has two possible states:

```text
null
```

or:

```text
*Request
```

`null` means:

> The Slot contains no pointer.

A non-null value means:

> The Slot contains the pointer.

Nothing special is required from Zig.

The Slot is simply an optional pointer used for this purpose.

For a concrete type, it can also be named:

```zig
const RequestSlot = ?*Request;
```

Then:

```zig
var slot: RequestSlot = null;
```

`RequestSlot` is not a new kind of Zig type.

It is just a name that makes the intended use clear.

It's alias.


Further we will use Slot instead of RequestSlot.

Just to stress the fact that it's generic idiom.

---

## A Slot is not ordinary storage

A Slot is not normally used to keep a value while the program works with that value.

For example, this is ordinary variable usage:

```zig
var count: u32 = 0;

count = 10;
count += 1;
```

A Slot has a different purpose.

The important operations are about the pointer:

* check it
* fill it
* take its pointer
* move its pointer
* release what it contains
* leave it empty

The object itself is somewhere else.

The Slot is the place used while the pointer moves.

---

## The two states

A Slot has two meaningful states.

```text
                 Slot

          +-----------------+
          |                 |
          |      null       |
          |                 |
          +-----------------+

                 or

          +-----------------+
          |    *Request     |
          +-----------------+
                  |
                  v
               Request
```

`null` is not an error.

It is a valid state.

It tells the code:

> There is no pointer in this Slot. (you have not it)

A non-null Slot tells the code:

> There is a pointer in this Slot. (you have it)

This makes an important fact visible in the program. (to you)

---

## Check the Slot

The first thing code can do is check the Slot.

```zig
if (slot) |request| {
    // request is *Request
}
```

Or:

```zig
const request = slot orelse return;
```

The check is about the Slot.

The code decides what an empty Slot means.

Sometimes empty is expected.

Sometimes it is an error.

Sometimes either state is accepted.

The Slot idiom does not prescribe the rule.

The operation designer chooses the rule.

---

## Fill the Slot

A Slot can start empty:

```zig
var slot: ?*Request = null;
```

Then a pointer can be put into it:

```zig
slot = try Request.new(gpa);
```

The state changes:

```text
Before

Slot
 └── null


After

Slot
 └── *Request
          |
          v
       Request
```

This is one of the basic Slot operations:

```text
empty → contains pointer
```

---

## Acquire into a Slot

A function can also fill a Slot.

For example:

```zig
receive(&slot);
```

Before the call:

```text
Slot
 └── null
```

After a successful call:

```text
Slot
 └── *Request
```

This is useful when the pointer comes from somewhere else.

The function puts the pointer into the caller's Slot.

The same idea can be used by operations called:

* `get`
* `receive`
* `acquire`
* `create`
* and many others

The names are not important.

The important part is the Slot state.

An operation may require an empty Slot before it fills it.

For example:

```text
get

before:  null
after:   *Request
```

If the Slot already contains a pointer, silently replacing it could lose that pointer.

So the operation may reject a non-empty Slot.

---

## Move the pointer out

The pointer can be taken from the Slot.

For example:

```zig
const request = slot orelse return;
slot = null;
```

Before:

```text
Slot
 └── *Request
          |
          v
       Request
```

After:

```text
Slot
 └── null

request ──► Request
```

The object did not move.

Only the pointer moved.

The Slot became empty.

This is the important state change:

```text
*Request → null
```

A function can perform this operation for the caller:

```zig
send(&slot);
```

If `send` succeeds:

```text
Before

Slot
 └── *Request


After

Slot
 └── null

Somewhere else
 └── *Request
```

The pointer has moved from one place to another.

---

## Transfer

This is where the Slot idiom becomes useful.

Suppose one task has a pointer and another task must get it.

The first task has:

```text
Task A

Slot
 └── *Request
```

It sends the pointer.

After the transfer:

```text
Task A                    Task B

Slot                      received pointer
 └── null                    │
                             v
                          *Request
                              |
                              v
                           Request
```

There is no second pointer to the same object.

The Slot makes the change visible.

Before the transfer:

```text
Slot → *Request
```

After the transfer:

```text
Slot → null
```

The other side now has the pointer.

This is the main reason to use a Slot.

---

## Release the Slot

A Slot can also be released.

A useful release operation accepts an empty Slot.

```text
release(null)
    ↓
nothing to release
    ↓
Slot stays null
```

And:

```text
release(*Request)
    ↓
release Request
    ↓
Slot becomes null
```

So:

```text
Before              After

null                null

or                  or

*Request             null
```

This is **defensive cleanup**.

It is often useful to make release safe for both states.

Then cleanup can be registered early:

```zig
var slot: ?*Request = null;
defer release(&slot);

slot = try createRequest();
```

If `createRequest()` fails:

```text
slot == null
```

The deferred release does nothing.

If creation succeeds:

```text
slot == *Request
```

The deferred release releases it.

If the pointer is later moved out:

```text
slot == null
```

The deferred release again does nothing.

One cleanup operation covers all three cases.

---

## Release after a move

This is one of the useful properties of a Slot.

Consider:

```zig
var slot: ?*Request = null;
defer release(&slot);

try create(&slot);
try send(&slot);
```

After `create`:

```text
Slot
 └── *Request
```

After successful `send`:

```text
Slot
 └── null
```

When the function returns, the deferred release sees an empty Slot.

Nothing happens.

There is no second release.

The Slot records the current state.

---

## Not every operation has the same rule

The Slot idiom does not say:

> Every operation must accept `null`.

Nor does it say:

> Every operation must reject `null`.

The programmer decides.

For example:

```text
create

expects: empty
returns: non-empty
```

```text
receive

expects: empty
returns: non-empty on success
```

```text
send

expects: non-empty
returns: empty on success
```

```text
release

accepts: empty or non-empty
returns: empty
```

These are examples.

Other operations may have different rules.

The important thing is that the rules are visible.

---

## Strict operations

Some operations should be strict.

Suppose an operation fills a Slot.

It may require:

```text
Slot == null
```

Why?

Because this:

```text
Slot
 └── *Request
```

must not silently become:

```text
Slot
 └── *OtherRequest
```

The first pointer would be lost.

So an operation such as `get` or `receive` may check that the Slot is empty.

Similarly, an operation that moves a pointer out may require a non-empty Slot.

It has nothing to move if the Slot is empty.

For example:

```text
send

Slot == *Request  → send it
Slot == null      → error / programming mistake
```

Again, this is a rule of the operation.

Not a rule of the Slot itself.

---

## Defensive operations

Other operations are naturally defensive.

Release is the obvious example.

An empty Slot is already in the desired final state:

```text
release(null) → null
```

This makes cleanup simpler.

It also makes cleanup safe on paths where the pointer was never created.

Or where the pointer was already moved.

---

## The basic Slot operations

The pattern can be reduced to four main state changes.

```text
create / acquire

    null
      │
      ▼
   *Request
```

```text
move

   *Request
      │
      ▼
     null
```

```text
release

   *Request
      │
      ▼
     null
```

And:

```text
check

   null          → empty
   *Request      → contains pointer
```

`use` is different.

Using the object is not a Slot operation.

```text
Slot
  │
  ▼
*Request
  │
  ▼
Request
```

The code can use `Request` normally.

The Slot matters when the pointer is checked, filled, moved, or released.

---

## The Slot is reusable

The same Slot can be used again.

For example:

```text
create
   ↓
Slot contains pointer
   ↓
use
   ↓
send
   ↓
Slot is empty
   ↓
receive
   ↓
Slot contains pointer
   ↓
use
   ↓
release
   ↓
Slot is empty
```

The Slot is not tied to one particular object.

It is a temporary container used for pointer transfer.

---

## Why this is useful

Without a Slot, code can simply pass `*Request` around.

But then the state is less explicit.

A pointer variable can still contain a pointer after that pointer has been passed somewhere else.

The programmer must remember that the pointer is no longer available here.

With a Slot:

```text
before transfer

Slot → *Request
```

and after:

```text
Slot → null
```

The state is visible.

This helps prevent accidental reuse.

It helps prevent releasing something after it was already released.

It helps prevent sending the same pointer again.

It helps prevent replacing a pointer that is still present.

It is especially useful when pointers move between tasks.

One task can give the pointer to another task.

The Slot in the first task becomes empty.

The second task gets the pointer in its own Slot.

There is one pointer.

There is one current place for it.

The Slot makes that change explicit.

---

## Slot idiom in one picture

```text
                    transfer

        +------------------------------+
        |                              |
        v                              |
   +---------+                    +---------+
   |  Slot A |                    |  Slot B |
   |         |                    |         |
   | *Request| ─────────────────► | *Request|
   +---------+                    +---------+
        |                              |
        |                              |
        v                              v
      null                           use
```

The pointer moves.

The object does not.

The source Slot becomes empty.

The destination Slot becomes non-empty.

---

## The simple rule

A Slot is a container for a pointer.

Use it when the pointer needs to move.

Check it.

Fill it.

Take the pointer from it.

Move the pointer.

Release what it contains.

Keep it empty when the pointer has moved away.

The Slot itself is simple:

```zig
?*Request
```

The useful part is the discipline around that simple type.

The Slot makes the transfer visible.

```
