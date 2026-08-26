# 3tk implementation review: `inner.c3` and `helper.c3`

Scope:

- Implementation only.
- Comments are not analyzed.
- The review is based on the two provided files.
- No assumptions about code not present in these files.

## Overall result

The design is internally consistent in its main representation:

```text
Outer item
    contains exactly one Inner

Inner*
    = Handle

Handle
    carries:
    - link pointer in `link.ptr`
    - outer type identity in `link.type`

Slot
    = one Handle
    = `Handle*` passed to methods
````

The most important implementation problem is the initialization state.

`Inner.link` is used simultaneously as:

* the type identity storage, and
* the intrusive chain link storage.

This is intentional and can work.

However, several operations read `self.link.type` before there is a guaranteed initialized identity.

There is also one clear contradiction between the documented/checking contract of `must_from_handle` and its actual implementation.

---

# 1. `must_from_handle` does not implement its own contract

## Current implementation

```c3
macro must_from_handle(Handle h, $Type)
    => ($Type*)((char*)h - mtk::inner::inner_offset($Type));
```

The function does not:

* check `h != null`;
* check the stored type identity;
* abort on a mismatch;
* use `mtk::@check`.

Therefore it is not the asserted version of `from_handle`.

For example:

```c3
Other* other = must_from_handle(h, Other);
```

will blindly calculate an address using `Other`'s `Inner` offset.

If `h` belongs to another type, this produces an invalid typed pointer rather than aborting.

## This is the strongest contradiction in the two files

`from_handle`:

```c3
if (!is_mine(h, $Type)) return ($Type*)null;
```

but `must_from_handle` performs no equivalent assertion.

The same problem propagates to:

```c3
macro Inner.as(&self, $Type)
    => ($Type*)((char*)self - mtk::inner::inner_offset($Type));
```

and indirectly to:

```c3
must_from_slot
Slot.must
```

## Recommendation

Make the assertion real:

```c3
macro must_from_handle(Handle h, $Type)
{
    mtk::@check(is_mine(h, $Type), "handle is not of this type");
    return ($Type*)((char*)h - mtk::inner::inner_offset($Type));
}
```

Then `Inner.as` should delegate to the same implementation:

```c3
macro Inner.as(&self, $Type)
    => must_from_handle((Handle)self, $Type);
```

This gives one implementation of the identity check.

It also prevents the method and free-function versions from drifting apart.

---

# 2. `init` can read an uninitialized `any`

## Current implementation

```c3
macro void init(item)
{
    Inner* n = (Inner*)((char*)item + mtk::inner::inner_offset($Typeof(*item)));
    n.link = any_make(null, $Typeof(*item)::typeid);
}
```

This is good because it writes the complete initial `any` value.

However, before `init`:

```c3
Inner.repoint_to
```

does this:

```c3
self.link = any_make(to, self.link.type);
```

So `repoint_to` reads:

```c3
self.link.type
```

The code therefore requires this invariant:

> `init()` must happen before any operation that calls `repoint_to()`.

The implementation itself does not enforce this.

The same general problem exists in:

```c3
is_mine
```

which reads:

```c3
h.link.type
```

That may be intentional for an uninitialized item, but the code must never invoke it on storage whose `Inner` has not been initialized to a valid `any` representation.

## Recommendation

The clean implementation rule should be:

```text
Creation
    allocate/create Outer

Initialization
    helper.init(&outer)

After initialization
    Inner may be used as Handle
    link may be repointed
    identity may be checked

Before initialization
    Inner is not a valid Handle
```

I would not add extra state just to detect this.

The current design already has the required state.

The important improvement is to make sure all constructors/factories in the rest of 3tk call `init()` before exposing the object as a `Handle`.

---

# 3. `reset` depends on initialized identity

## Current implementation

```c3
fn void reset(Handle h) @inline
{
    if (!h) return;
    h.repoint_to(null);
}
```

And:

```c3
fn void Inner.repoint_to(&self, Handle to) @inline
    => self.link = any_make(to, self.link.type);
```

Therefore `reset` is not merely:

```text
set link pointer to null
```

It reconstructs the complete `any` while preserving:

```c3
self.link.type
```

So again it reads the identity.

This is correct after `init()`.

It is not safe as a generic cleanup operation for arbitrary uninitialized `Inner`.

## Recommendation

No structural change is necessary.

Just treat `reset()` as an operation on a valid initialized `Handle`, not on raw `Inner` storage.

---

# 4. `move_from_slot` has a small implementation improvement

## Current implementation

```c3
macro move_from_slot(Slot* s, $Type)
{
    Handle h = s.peek();
    if (!is_mine(h, $Type)) return ($Type*)null;
    s.take();
    return ($Type*)((char*)h - mtk::inner::inner_offset($Type));
}
```

The logic is correct:

* read;
* check identity;
* leave Slot unchanged on mismatch;
* clear Slot on success;
* return outer pointer.

But:

```c3
s.take();
```

throws away the returned handle.

Since `h` was already read, this is not incorrect.

Still, it creates two reads of the Slot state.

A simpler implementation is:

```c3
macro move_from_slot(Slot* s, $Type)
{
    Handle h = s.peek();
    if (!is_mine(h, $Type)) return ($Type*)null;
    s.take();
    return from_handle(h, $Type);
}
```

Or, if avoiding the second type check matters:

```c3
macro move_from_slot(Slot* s, $Type)
{
    Handle h = s.peek();
    if (!is_mine(h, $Type)) return ($Type*)null;
    s.take();
    return ($Type*)((char*)h - mtk::inner::inner_offset($Type));
}
```

The current code is already semantically correct.

This is only a minor consistency/readability improvement.

---

# 5. `Slot.take` contains unnecessary casts

Current code:

```c3
fn Handle Slot.take(&self) @inline
{
    Handle h = (Handle)*self;
    *self = (Slot)(Handle)null;
    return h;
}
```

Since:

```c3
typedef Slot = Handle;
```

the implementation can likely be simpler:

```c3
fn Handle Slot.take(&self) @inline
{
    Handle h = *self;
    *self = null;
    return h;
}
```

Likewise:

```c3
fn bool Slot.is_empty(&self) @inline => !(Handle)*self;
```

can conceptually be:

```c3
fn bool Slot.is_empty(&self) @inline => *self == null;
```

and:

```c3
fn bool Slot.is_full(&self) @inline => (Handle)*self != null;
```

can be:

```c3
fn bool Slot.is_full(&self) @inline => *self != null;
```

Whether C3 accepts all of these shorter forms depends on the exact alias/typedef behavior being used.

If it does, the shorter version better expresses the intended representation.

This is not a design problem.

---

# 6. `Slot` is a typedef rather than a distinct struct

The current representation is:

```c3
typedef Slot = Handle;
```

This has an important consequence.

A `Slot` is physically and semantically almost just a nullable `Handle`.

That is useful for:

```c3
Slot slot = null;
slot.fill(h);
```

and for passing:

```c3
&slot
```

as the pointer-to-slot idiom.

But the compiler cannot strongly distinguish:

```text
Handle
```

from:

```text
Slot
```

in all contexts where typedef conversion is allowed.

For example, an accidental API mix-up may be easier than if `Slot` were a wrapper struct.

## Recommendation

For the current 3tk idiom, I would keep:

```c3
typedef Slot = Handle;
```

The simplicity is probably worth it.

But the API should consistently expose Slot operations through:

```c3
Slot.fill
Slot.take
Slot.peek
Slot.is_empty
Slot.is_full
```

rather than treating a Slot as an ordinary Handle.

Do not add a wrapper struct unless an actual implementation problem appears.

There is no evidence in these two files that one is currently necessary.

---

# 7. `inner_offset` correctly enforces exactly one `Inner`, but only direct members are considered

Current implementation walks:

```c3
$Type::members
```

and checks:

```c3
$m.type == Inner
```

This means the implementation supports the intended shape:

```c3
struct Message
{
    Inner inner;
    String text;
}
```

But it does not appear to discover an `Inner` hidden inside another nested struct.

That is probably correct for this design.

For example:

```c3
struct Base
{
    Inner inner;
}

struct Message
{
    Base base;
    String text;
}
```

would not satisfy the direct-member search unless C3's member reflection expands this in some special way.

## Recommendation

Keep the direct-member rule.

It makes:

```c3
inner_offset($Type)
```

simple and deterministic.

Do not add recursive discovery without a real use case.

Recursive discovery would also make "exactly one Inner" less obvious.

---

# 8. `required_alloc_offset` does not enforce exactly one `Allocator`

Current code:

```c3
macro usz required_alloc_offset($Type)
{
    var $off = -1;
    $foreach $m : $Type::members:
        $if $m.type == Allocator:
            $off = $m.offset;
        $endif
    $endforeach
    $assert $off >= 0 : ...;
    return $off;
}
```

Unlike `inner_offset`, this accepts multiple matching fields.

If two `Allocator` fields exist:

```c3
struct X
{
    Allocator a;
    Allocator b;
}
```

the last one encountered wins.

That may be intentional.

But it is inconsistent with the stricter discovery rule used for `Inner`.

## Recommendation

Decide whether the managed helper requires exactly one allocator field.

If yes, use the same pattern as `inner_offset`:

```c3
var $off = -1;
var $seen = 0;

$foreach $m : $Type::members:
    $if $m.type == Allocator:
        $off = $m.offset;
        $seen = $seen + 1;
    $endif
$endforeach

$assert $seen != 0 : "...";
$assert $seen == 1 : "...";
```

If multiple allocators are intentionally allowed, the current implementation needs a way to identify which one is the managed allocator.

Without that, "last Allocator member wins" is an implicit rule.

Based only on these two files, exactly one is the safer implementation.

---

# 9. `init` and `to_handle` duplicate the same pointer calculation

Both calculate:

```c3
(char*)item + mtk::inner::inner_offset($Typeof(*item))
```

For example:

```c3
macro Handle to_handle(item)
    => item ? (Handle)((char*)item + mtk::inner::inner_offset($Typeof(*item))) : null;
```

and:

```c3
Inner* n = (Inner*)((char*)item + mtk::inner::inner_offset($Typeof(*item)));
```

This is not a correctness problem.

But this calculation is fundamental to the implementation.

## Recommendation

A small internal helper could centralize it:

```c3
macro Inner* inner_from_outer(item)
    => item ? (Inner*)((char*)item + inner_offset($Typeof(*item))) : null;
```

Then:

```c3
macro Handle to_handle(item)
    => (Handle)inner_from_outer(item);
```

and:

```c3
macro void init(item)
{
    Inner* n = inner_from_outer(item);
    n.link = any_make(null, $Typeof(*item)::typeid);
}
```

This is optional.

The current code is still small enough that duplication is not yet dangerous.

---

# 10. The `Inner` method conversion should preferably reuse free helpers

Current method:

```c3
macro Inner.to(&self, $Type)
    => from_handle((Handle)self, $Type);
```

This is good.

But:

```c3
macro Inner.as(&self, $Type)
    => ($Type*)((char*)self - mtk::inner::inner_offset($Type));
```

duplicates the unchecked conversion.

After fixing `must_from_handle`, it should become:

```c3
macro Inner.as(&self, $Type)
    => must_from_handle((Handle)self, $Type);
```

This is a direct improvement.

The public API then has one implementation path:

```text
from_handle
    ↕
Inner.to

must_from_handle
    ↕
Inner.as
```

and:

```text
from_slot
    ↕
Slot.to

must_from_slot
    ↕
Slot.must

move_from_slot
    ↕
Slot.move
```

That is the cleanest consistency structure.

---

# 11. `is_linked` representation is consistent with `reset`

Current implementation:

```c3
fn bool is_linked(Handle h) @inline
    => h != null && h.points_to() != null;
```

and:

```c3
fn void reset(Handle h) @inline
{
    if (!h) return;
    h.repoint_to(null);
}
```

This is internally consistent.

The type identity remains in:

```c3
link.type
```

while:

```c3
link.ptr
```

is cleared.

Therefore:

```text
initialized, not linked
    ptr  = null
    type = Outer::typeid

initialized, linked
    ptr  = Handle
    type = Outer::typeid
```

This is a good representation for the intended dual-purpose `any`.

No contradiction was found here.

---

# 12. `is_mine` should remain the single identity predicate

Current implementation:

```c3
macro bool is_mine(Handle h, $Type)
    => h != null && h.link.type == $Type::typeid;
```

This is the correct central predicate for the rest of the code.

It is used by:

```c3
from_handle
move_from_slot
```

The implementation should also be used by:

```c3
must_from_handle
```

after fixing it.

Do not create a second identity mechanism.

The current architecture is strongest when all typed recovery goes through the same test.

---

# Recommended minimal changes

These are the changes I recommend based on actual issues visible in the two files.

## Required

### Fix `must_from_handle`

```c3
macro must_from_handle(Handle h, $Type)
{
    mtk::@check(is_mine(h, $Type), "handle is not of this type");
    return ($Type*)((char*)h - mtk::inner::inner_offset($Type));
}
```

### Make `Inner.as` reuse it

```c3
macro Inner.as(&self, $Type)
    => must_from_handle((Handle)self, $Type);
```

This removes the current contract contradiction.

---

## Recommended

### Make `required_alloc_offset` reject ambiguity

Use the same exactly-one-field rule as `inner_offset`, unless the larger implementation has an explicit allocator-selection mechanism.

---

## Optional cleanup

If accepted by the C3 compiler:

```c3
fn bool Slot.is_empty(&self) @inline => *self == null;

fn bool Slot.is_full(&self) @inline => *self != null;

fn Handle Slot.peek(&self) @inline => *self;

fn Handle Slot.take(&self) @inline
{
    Handle h = *self;
    *self = null;
    return h;
}
```

This better reflects that `Slot` is simply:

```c3
typedef Slot = Handle;
```

---

# Final assessment

The core implementation is coherent.

The main model:

```text
Inner
    = intrusive link + type identity

Handle
    = Inner*

Slot
    = nullable Handle storage

typeid
    = identity of the outer type

offset discovery
    = recovery from Inner* to Outer*
```

fits together correctly.

The two actual implementation issues are:

1. **`must_from_handle` does not check or abort despite being the asserted conversion API.**
2. **`required_alloc_offset` silently chooses one of multiple `Allocator` fields.**

The first should definitely be fixed.

The second should be fixed unless multiple allocators are explicitly part of the managed-helper design.

The initialization dependency is also important:

```text
An Outer must be initialized with helper.init()
before its Inner is used as a Handle or passed to operations
that read or preserve link.type.
```

I would keep the overall design.

I would not introduce extra tags, extra initialization flags, wrapper objects, registration, or more generic machinery based on these two files.
