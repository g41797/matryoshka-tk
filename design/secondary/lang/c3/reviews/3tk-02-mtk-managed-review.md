# 3tk implementation review: `mtk.c3` and `managed.c3`

Scope:

- Implementation only.
- Comments are not analyzed.
- This review checks contradictions and implementation problems visible in these two files.
- It also checks interaction with the previously shown `helper.c3` and `inner.c3`.
- No assumptions are made about code not shown.

# Overall result

`mtk.c3` is small and internally consistent.

`managed.c3` has one clear issue already found in the previous review:

- `required_alloc_offset` accepts multiple `Allocator` fields and silently selects the last one.

There is also one important implementation dependency:

- `managed::create` relies on the exact failure behavior of `alloc::new_try(a, $Type)!`.

If `new_try` faults in the normal `void?` sense, the current code is correct.
If the postfix `!` means something else in this C3 context, that must be checked.

Apart from that, the basic `create` / `release` flow is coherent.

---

# 1. `mtk.c3`: module structure is consistent

The file declares:

```c3
module mtk;
````

and imports:

```c3
import mtk::helper;
```

The rest of the shown implementation uses submodules:

```text
mtk
mtk::inner
mtk::helper
mtk::managed
```

This is consistent with the intended one-import structure, assuming the build/module layout exports the submodules as expected.

No implementation contradiction is visible here.

---

# 2. `VERSION` is a normal constant

```c3
const String VERSION = "0.0.1";
```

No problem is visible.

The only future consideration is whether public API users need a compile-time semantic version value rather than a string.

There is no evidence that this is currently needed.

Keep the string.

Do not add version structs or parsing machinery without a use case.

---

# 3. Fault definitions are consistent with `void?` style

```c3
faultdef CLOSED, TIMEOUT, NOT_AVAILABLE, NOT_CREATED, EMPTY, WOKEN, UNKNOWN_IDENTITY;
```

This is compatible with:

```c3
macro void? create(...)
```

The important implementation question is whether all of these faults are actually needed by the current implementation.

That cannot be determined from these two files alone.

There is no contradiction inside `mtk.c3`.

---

# 4. `@check` correctly disappears in non-safe mode

Current implementation:

```c3
macro @check(#cond, $msg)
{
    $if env::COMPILER_SAFE_MODE:
        always_assert(#cond, $msg);
    $endif
}
```

and:

```c3
const bool CHECKED = env::COMPILER_SAFE_MODE;
```

These are internally consistent.

In safe mode:

```text
@check(condition, message)
    performs always_assert
```

In non-safe mode:

```text
@check(...)
    expands to nothing
```

and:

```text
CHECKED == false
```

No contradiction is visible.

One small point:

`@check` accepts:

```c3
#cond
```

while the message is:

```c3
$msg
```

This is correct only if the intended call syntax consistently passes a condition expression and a compile-time message.

The shown calls do that.

For example:

```c3
mtk::@check(slot.is_empty(), "...");
```

So no change is needed.

---

# 5. `managed::create` has the correct Slot ordering

Current implementation:

```c3
macro void? create($Type, Allocator a, Slot* slot)
{
    mtk::@check(slot.is_empty(), "an acquisition asserts the Slot is empty on entry");
    $Type* item = alloc::new_try(a, $Type)!;
    *(Allocator*)((char*)item + mtk::inner::required_alloc_offset($Type)) = a;
    helper::init(item);
    slot.fill(helper::to_handle(item));
}
```

The sequence is:

```text
1. Check Slot is empty.
2. Allocate outer.
3. Store Allocator in outer.
4. Initialize Inner.
5. Convert outer to Handle.
6. Fill Slot.
```

This is good.

In particular, the Slot is filled last.

Therefore a successfully returned item cannot be observed in the Slot before:

```text
Allocator is stored.
Inner is initialized.
Handle identity exists.
```

This is the correct order.

---

# 6. `managed::create` correctly leaves Slot unchanged before allocation

The only operation on the Slot before allocation is:

```c3
slot.is_empty()
```

which is only a safe-build assertion.

The Slot is not modified until:

```c3
slot.fill(...)
```

Therefore, assuming allocation failure exits through:

```c3
alloc::new_try(a, $Type)!
```

the Slot remains unchanged.

This matches the intended acquisition behavior.

No change is needed.

---

# 7. The exact behavior of `alloc::new_try(...)!` must be confirmed

This line is central:

```c3
$Type* item = alloc::new_try(a, $Type)!;
```

The macro itself returns:

```c3
void?
```

So the implementation depends on `!` propagating the allocation fault correctly.

If C3 fault propagation works as expected here, the code is correct.

Then the effective flow is:

```text
allocation succeeds
    continue

allocation fails
    immediately return the fault
    Slot remains unchanged
```

There is no visible contradiction.

However, this is a compiler/library semantic dependency, not something guaranteed by the code itself.

I would not change the implementation.

I would just verify this with a small compile test if it has not already been tested.

---

# 8. Storing the allocator before `helper::init` is correct

Current order:

```c3
*(Allocator*)((char*)item + offset) = a;
helper::init(item);
```

There is no dependency between these operations in the shown implementation.

`helper::init` initializes the `Inner`.

The allocator field belongs to the outer.

Either order could work.

The current order is good because after `helper::init`, the object is already structurally closer to a valid item.

More importantly, no Handle is exposed before both operations complete.

No problem is visible.

---

# 9. `release` correctly preserves the allocator before freeing

Current implementation:

```c3
macro void release($Type, Slot* slot)
{
    if (slot.is_empty()) return;
    $Type* item = helper::must_from_slot(slot, $Type);
    Allocator a = *(Allocator*)((char*)item + mtk::inner::required_alloc_offset($Type));
    slot.take();
    alloc::free(a, item);
}
```

The order is:

```text
1. Return if empty.
2. Recover typed outer.
3. Copy Allocator.
4. Clear Slot.
5. Free outer.
```

This is correct.

In particular:

```c3
Allocator a = ...
```

happens before:

```c3
alloc::free(a, item);
```

so the allocator is not read from freed memory.

Also:

```c3
slot.take();
```

happens before freeing.

Therefore the caller's Slot does not temporarily retain a dangling Handle after `free`.

This is good.

---

# 10. `release` currently depends on the broken `must_from_handle` contract

`release` calls:

```c3
helper::must_from_slot(slot, $Type);
```

From the previously shown helper implementation:

```c3
macro must_from_slot(Slot* s, $Type)
    => must_from_handle(s.peek(), $Type);
```

But the previous implementation of:

```c3
must_from_handle
```

did not actually check identity.

Therefore, with the current earlier code, this call:

```c3
managed::release(WrongType, slot);
```

can calculate an invalid outer pointer.

Then:

```c3
required_alloc_offset(WrongType)
```

is applied to the wrong address.

Finally:

```c3
alloc::free(a, item);
```

may use garbage.

This is an important interaction problem.

It is solved by the previously recommended fix:

```c3
macro must_from_handle(Handle h, $Type)
{
    mtk::@check(is_mine(h, $Type), "handle is not of this type");
    return ($Type*)((char*)h - mtk::inner::inner_offset($Type));
}
```

After that fix, `managed::release` correctly asserts the required type identity in a safe build.

---

# 11. `release` is safe on an empty Slot

Current code:

```c3
if (slot.is_empty()) return;
```

This happens before:

```c3
helper::must_from_slot(...)
```

Therefore an empty Slot does not cause a conversion attempt.

This is correct.

The function is genuinely idempotent with respect to an empty Slot:

```text
empty Slot
    release
        Slot remains empty
        no allocation action
```

No change is needed.

---

# 12. `release` only checks type in checked builds

After fixing `must_from_handle` as recommended, the check is based on:

```c3
mtk::@check(...)
```

But:

```c3
@check
```

disappears under:

```text
--safe=no
```

Therefore in non-safe mode:

```text
release with wrong $Type
    performs unchecked pointer recovery
```

This is consistent with the toolkit's checked/unchecked design.

It is not a contradiction.

But it means `$Type` is a real API contract, not runtime protection in release/non-safe builds.

That is probably the intended model.

I would keep it.

---

# 13. `required_alloc_offset` has the same ambiguity problem found earlier

Current implementation:

```c3
macro usz required_alloc_offset($Type)
{
    var $off = -1;
    $foreach $m : $Type::members:
        $if $m.type == Allocator:
            $off = $m.offset;
        $endif
    $endforeach
    $assert $off >= 0 : "...";
    return $off;
}
```

Consider:

```c3
struct Item
{
    Allocator first;
    Inner inner;
    Allocator second;
}
```

The result is implicitly:

```text
offset(second)
```

because the last matching member overwrites `$off`.

There is no explicit rule saying that the last field is the allocator used for managed allocation.

This is the clearest implementation problem in `managed.c3`.

## Recommended fix

Require exactly one `Allocator` field:

```c3
macro usz required_alloc_offset($Type)
{
    var $off = -1;
    var $count = 0;

    $foreach $m : $Type::members:
        $if $m.type == Allocator:
            $off = $m.offset;
            $count = $count + 1;
        $endif
    $endforeach

    $assert $count != 0 :
        "type " +++ $Type::name +++ " has no Allocator field; use mtk::helper instead of mtk::managed";

    $assert $count == 1 :
        "type " +++ $Type::name +++ " has more than one Allocator field";

    return $off;
}
```

This matches the existing `inner_offset` approach:

```text
exactly one Inner
exactly one Allocator
```

That is the most coherent rule for the current implementation.

---

# 14. The Allocator field does not need a fixed name

The implementation searches by type:

```c3
$m.type == Allocator
```

rather than by field name.

This means all of these can work:

```c3
Allocator alloc;
```

```c3
Allocator allocator;
```

```c3
Allocator memory;
```

This is a good design for the current managed helper.

The implementation needs only the offset.

No field name should be imposed without an actual need.

Keep this.

---

# 15. `managed::create` and `managed::release` are symmetric

The two operations use the same compile-time mechanism:

```c3
mtk::inner::required_alloc_offset($Type)
```

Creation:

```text
store Allocator at offset
```

Release:

```text
read Allocator from same offset
```

This is important and correct.

The allocator does not need to be passed to `release`.

The item itself contains the required allocator information.

No contradiction is visible.

---

# 16. There is a possible duplication problem around `required_alloc_offset`

In the earlier review, `required_alloc_offset` appeared associated with the helper/inner implementation discussion.

Here it is defined in:

```text
module mtk::managed
```

but called as:

```c3
mtk::inner::required_alloc_offset($Type)
```

inside:

```c3
managed::create
managed::release
```

If the code is exactly as pasted, this is a module-location contradiction.

The function shown in `managed.c3` is:

```c3
macro usz required_alloc_offset($Type)
```

inside:

```c3
module mtk::managed;
```

Its qualified name should therefore be:

```c3
mtk::managed::required_alloc_offset
```

not:

```c3
mtk::inner::required_alloc_offset
```

But `create` uses:

```c3
mtk::inner::required_alloc_offset($Type)
```

and `release` does the same.

## This is a concrete problem if the pasted code is exact

Either:

```text
required_alloc_offset belongs in mtk::inner
```

or the calls should be:

```c3
required_alloc_offset($Type)
```

or:

```c3
mtk::managed::required_alloc_offset($Type)
```

Since the macro is only used by `managed::create` and `managed::release`, the cleanest arrangement is probably:

```c3
required_alloc_offset($Type)
```

inside the same module.

For example:

```c3
*(Allocator*)((char*)item + required_alloc_offset($Type)) = a;
```

and:

```c3
Allocator a = *(Allocator*)((char*)item + required_alloc_offset($Type));
```

This is the most important newly found contradiction.

---

# 17. The `mtk::inner` import is therefore currently questionable

`managed.c3` imports:

```c3
import mtk::inner;
```

That may currently exist only because of:

```c3
mtk::inner::required_alloc_offset
```

If `required_alloc_offset` remains in `mtk::managed`, this import may no longer be needed.

The other imports are used:

```c3
import mtk;
import mtk::helper;
import std::core::mem::alloc;
```

So after fixing the qualification, check whether:

```c3
import mtk::inner;
```

is still required.

Do not keep unused imports.

---

# Recommended minimal changes

## Required

### 1. Fix the module qualification of `required_alloc_offset`

Because the shown definition is in:

```text
mtk::managed
```

use:

```c3
required_alloc_offset($Type)
```

inside `managed.c3`.

So:

```c3
*(Allocator*)((char*)item + required_alloc_offset($Type)) = a;
```

and:

```c3
Allocator a = *(Allocator*)((char*)item + required_alloc_offset($Type));
```

Then remove:

```c3
import mtk::inner;
```

if it is no longer used.

---

### 2. Require exactly one `Allocator` field

The current implementation silently selects the last one.

Add a count and assert exactly one.

---

### 3. Fix `must_from_handle`

This is required because `managed::release` depends on typed recovery being checked.

Use:

```c3
macro must_from_handle(Handle h, $Type)
{
    mtk::@check(is_mine(h, $Type), "handle is not of this type");
    return ($Type*)((char*)h - mtk::inner::inner_offset($Type));
}
```

---

# Optional verification

Compile-test the failure path of:

```c3
alloc::new_try(a, $Type)!
```

The required behavior is:

```text
allocation fails
    -> create returns the allocation fault
    -> Slot is unchanged
```

The implementation appears designed correctly for this behavior.

This is only worth verifying because the correctness depends on C3's fault propagation semantics.

---

# Final assessment

`mtk.c3` has no visible implementation problem.

`managed.c3` has a coherent allocation/release design:

```text
create
    allocate
    store allocator
    initialize Inner
    fill Slot

release
    recover typed outer
    copy allocator
    clear Slot
    free outer
```

The main concrete problems are:

1. **`required_alloc_offset` is defined in `mtk::managed` but called as `mtk::inner::required_alloc_offset`.**
2. **`required_alloc_offset` silently accepts multiple `Allocator` fields and chooses the last one.**
3. **`managed::release` depends on the previously found broken implementation of `must_from_handle`.**

After fixing those, I do not see a reason to redesign the implementation.

The current model remains simple and consistent:

```text
mtk
    faults
    checked assertion mechanism

helper
    identity
    Handle
    Slot
    typed recovery

managed
    optional allocation helper
    allocator stored in the outer item
    allocator recovered at release time
```

No extra state, registration, allocator wrapper, managed base type, or automatic ownership mechanism is needed based on these files.

