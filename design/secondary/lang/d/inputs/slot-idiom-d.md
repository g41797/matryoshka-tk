# Slot Idiom in D

A Slot is a small, simple programming idiom.

It is useful when a pointer needs to move from one piece of code to another.

The Slot is a **container for a pointer**.

The pointer is either there or not there.

In D, a pointer is already nullable, so a plain pointer is enough to implement it.

---

## Start with an object

Consider a dynamically allocated object:

```d
struct Request
{
    uint id;
    ubyte[] data;
}

Request* newRequest()
{
    ................
}

auto request = newRequest();
```

`request` is a pointer:

```d
Request*
```

The `Request` object lives somewhere in allocated memory.

The pointer tells us where it is.

Now we need a container that can contain this pointer.

```d
Request* slot = null;
```

This is a Slot.

It has two possible states:

```text
null
```

or:

```text
Request*
```

`null` means:

> The Slot contains no pointer.

A non-null value means:

> The Slot contains the pointer.

Nothing special is required from D.

The Slot is simply a pointer used for this purpose.

For a concrete type, it can also be named:

```d
alias RequestSlot = Request*;
```

Then:

```d
RequestSlot slot = null;
```

`RequestSlot` is not a new kind of D type.

It is just a name that makes the intended use clear.

It's alias.

Further we will use Slot instead of RequestSlot.

Just to stress the fact that it's generic idiom.

---

## A Slot is not ordinary storage

A Slot is not normally used to keep a value while the program works with that value.

For example, this is ordinary variable usage:

```d
uint count = 0;

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
          |    Request*     |
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

```d
if (slot !is null)
{
    // slot is Request*
}
```

Or:

```d
if (slot is null) return;
```

The check is about the Slot.

Use `is` and `!is`, not `==`.

`==` on a pointer to a struct may compare what the pointers point at.

`is` compares the pointers themselves, which is what a Slot check means.

The code decides what an empty Slot means.

Sometimes empty is expected.

Sometimes it is an error.

Sometimes either state is accepted.

The Slot idiom does not prescribe the rule.

The operation designer chooses the rule.

---

## Fill the Slot

A Slot can start empty:

```d
Request* slot = null;
```

Then a pointer can be put into it:

```d
slot = newRequest();
```

The state changes:

```text
Before

Slot
 └── null


After

Slot
 └── Request*
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

The Slot belongs to the caller, so the function takes it by reference:

```d
receive(slot);
```

with:

```d
Status receive(ref Request* slot);
```

`ref` is how D says "in/out parameter".

There is no `&slot` at the call site, and no `Request**` in the signature.

Before the call:

```text
Slot
 └── null
```

After a successful call:

```text
Slot
 └── Request*
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
after:   Request*
```

If the Slot already contains a pointer, silently replacing it could lose that pointer.

So the operation may reject a non-empty Slot.

D also has an `out` parameter, which sets the argument to its default on entry:

```d
Status receive(out Request* slot);   // don't
```

This is the wrong tool here.

`out` does not reject a non-empty Slot.

It empties it, and the pointer that was there is lost.

Use `ref` and check.

---

## Move the pointer out

The pointer can be taken from the Slot.

For example:

```d
auto request = slot;
if (request is null) return;
slot = null;
```

Before:

```text
Slot
 └── Request*
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
Request* → null
```

A function can perform this operation for the caller:

```d
send(slot);
```

If `send` succeeds:

```text
Before

Slot
 └── Request*


After

Slot
 └── null

Somewhere else
 └── Request*
```

The pointer has moved from one place to another.

---

## Transfer

This is where the Slot idiom becomes useful.

Suppose one thread has a pointer and another thread must get it.

The first thread has:

```text
Thread A

Slot
 └── Request*
```

It sends the pointer.

After the transfer:

```text
Thread A                  Thread B

Slot                      Slot
 └── null                  └── Request*
                                 |
                                 v
                              Request
```

There is no second pointer to the same object.

The Slot makes the change visible.

Before the transfer:

```text
Slot → Request*
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
release(Request*)
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

Request*            null
```

This is **defensive cleanup**.

It is often useful to make release safe for both states.

Then cleanup can be registered early:

```d
Request* slot = null;
scope(exit) release(slot);

slot = newRequest();
```

`scope(exit)` runs the statement when the scope ends.

It reads the Slot as it is at that moment, not as it was when the line was written.

That is what makes early registration work.

If `newRequest()` fails and returns `null`:

```text
slot is null
```

The `scope(exit)` release does nothing.

If creation succeeds:

```text
slot is Request*
```

The `scope(exit)` release releases it.

If the pointer is later moved out:

```text
slot is null
```

The `scope(exit)` release again does nothing.

One cleanup operation covers all three cases.

---

## Release after a move

This is one of the useful properties of a Slot.

Consider:

```d
Request* slot = null;
scope(exit) release(slot);

if (create(slot) != Status.ok) return;
if (send(slot)   != Status.ok) return;
```

After `create`:

```text
Slot
 └── Request*
```

After successful `send`:

```text
Slot
 └── null
```

When the function returns, the `scope(exit)` release sees an empty Slot.

Nothing happens.

There is no second release.

After a failed `send`, the Slot is unchanged.

The pointer is still ours, and the `scope(exit)` release frees it.

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
Slot is null
```

Why?

Because this:

```text
Slot
 └── Request*
```

must not silently become:

```text
Slot
 └── OtherRequest*
```

The first pointer would be lost.

So an operation such as `get` or `receive` may check that the Slot is empty:

```d
Status receive(ref Request* slot)
{
    assert(slot is null);
    ................
}
```

Similarly, an operation that moves a pointer out may require a non-empty Slot.

It has nothing to move if the Slot is empty.

For example:

```text
send

Slot is Request*  → send it
Slot is null      → error / programming mistake
```

Again, this is a rule of the operation.

Not a rule of the Slot itself.

Note that `assert` disappears under `-release`.

The rules are checked while you develop, not while you ship.

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

## Release without a garbage collector

The Slot idiom says nothing about who owns the object.

That is the point.

Without a GC, `release` is where ownership is spelled out:

```d
void release(ref Request* slot) @nogc nothrow
{
    if (slot is null) return;
    free(slot);
    slot = null;
}
```

Do not allocate the object with `new` if you release it this way.

`new` gives you GC memory, and `free` on GC memory is undefined.

Pick one and stay with it:

```text
malloc / free
```

or:

```text
your allocator's alloc / dealloc
```

The Slot does not care which.

It only cares that the Slot is empty afterwards.

Note also the order inside `release`.

It frees, then empties the Slot.

A `release` that frees and forgets leaves a Slot pointing at dead memory, and
the next check says the pointer is still there.

---

## The basic Slot operations

The pattern can be reduced to four main state changes.

```text
create / acquire

    null
      │
      ▼
  Request*
```

```text
move

  Request*
      │
      ▼
     null
```

```text
release

  Request*
      │
      ▼
     null
```

And:

```text
check

   null          → empty
   Request*      → contains pointer
```

`use` is different.

Using the object is not a Slot operation.

```text
Slot
  │
  ▼
Request*
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

Without a Slot, code can simply pass `Request*` around.

But then the state is less explicit.

A pointer variable can still contain a pointer after that pointer has been passed somewhere else.

The programmer must remember that the pointer is no longer available here.

With a Slot:

```text
before transfer

Slot → Request*
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

It is especially useful when pointers move between threads.

One thread can give the pointer to another thread.

The Slot in the first thread becomes empty.

The second thread gets the pointer in its own Slot.

There is one pointer.

There is one current place for it.

The Slot makes that change explicit.

---

## What D leaves open

In D, a Slot and an ordinary pointer have the same type.

```d
Request* slot;      // a Slot
Request* request;   // an ordinary pointer
```

The alias helps a reader.

It does not help the compiler.

So two things stay possible.

A copy the idiom forbids:

```d
Request* other = slot;    // now two names for one object
```

And a leak the idiom cannot see:

```d
{
    Request* slot = null;
    create(slot);
}                          // scope ends, pointer dropped, nothing said
```

Both are what the discipline is for.

If the discipline is enough for your code, stop here.

The plain pointer is the Slot, and the rest of this document is optional.

---

## A strict Slot

D can turn those two cases into a compiler error and an assert.

```d
import core.attribute : mustuse;

@mustuse struct Slot
{
    private Request* h;

    // One owner. A Slot cannot be copied from another Slot.
    @disable this(this);
    @disable void opAssign(ref Slot);

    // A Slot must be empty when it dies.
    ~this() @nogc nothrow
    {
        assert(h is null, "Slot destroyed non-empty - pointer dropped");
    }

    bool empty() const @nogc nothrow { return h is null; }

    // Reads the pointer. The Slot keeps it.
    Request* peek() @nogc nothrow { return h; }

    // The only way out. The Slot is left empty.
    Request* take() @nogc nothrow
    {
        auto t = h;
        h = null;
        return t;
    }

    // The only way in. Rejects a non-empty Slot.
    void put(Request* p) @nogc nothrow
    {
        assert(h is null, "Slot already holds a pointer");
        assert(p !is null);
        h = p;
    }
}
```

What each line buys:

```text
@disable this(this)   →  a second name for one object won't compile
~this() assert        →  a dropped pointer reports at the line it was dropped
@mustuse              →  a returned Slot cannot be discarded
```

The destructor does not release.

It cannot.

The Slot does not know whether the object came from `malloc`, from a pool, or
from somewhere that still owns it.

That is the same knowledge the transfer code does not have either.

So it asserts, and leaves the releasing to whoever knows.

The cost is that every access becomes a call:

```d
Slot slot;
scope(exit) release(slot);

if (create(slot) != Status.ok) return;

slot.peek().id = 7;

if (send(slot) != Status.ok) return;
```

Same idiom.

Same four state changes.

The rules are now checked by the compiler instead of by you.

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
   | Request*| ─────────────────► | Request*|
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

```d
Request*
```

The useful part is the discipline around that simple type.

The Slot makes the transfer visible.
