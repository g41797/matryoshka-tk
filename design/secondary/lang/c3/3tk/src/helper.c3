// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//==============================================================================
// The core, section 3 of 3: `OuterHelper`, the one thing a user binds.
//
// This is `module mtk` again, in its generic form. C3 lets a module name be
// both plain and generic, so `mtk::to_inner(&m)` and `alias MSG = mtk::OF{Msg};`
// resolve against the same name — Appendix A.6. No module block: `mtk.c3`
// carries the description, and a module has one description however many
// sections it is written in.
//
// Refilled by 3TK-64, which deleted `managed.c3` and moved `create`/`release`
// here as members. Every member forwards to a macro in `inner.c3` and has no
// logic of its own.
//==============================================================================
// [3tk: RT-3, HS-1 to HS-10, Part 3, Part 4.2, Part 5.1]
module mtk <Outer>;

<*
 The one thing a user binds, one line per outer type.

 `alias MSG = mtk::OF{Msg};` — and that is the whole ceremony.

 The carrier holds nothing.
 Its only job is to give C3's method syntax a receiver, so that `MSG.create(mem, &s)` is a line you can write.
 Every member takes `self` and no member reads it: `Outer` arrives from the module instantiation, and every member compares against `Outer::typeid`, the compile-time constant that instantiation supplies.
 C3 has no static-method facility, and no way to alias a module instantiation as a namespace, so a zero-state type is how a generic module offers its members under one bound name.
 It is a `typedef` over `uptr` because c3c refuses a struct with no members, and because the standard library spells its own zero-state carriers that way — `LibcAllocator` and `NullAllocator` are both this shape.
 The value is never read, as a number or as anything else.
*>
// [3tk: HS-1, Part 3.1]
typedef OuterHelper = uptr;

<*
 The helper for `Outer`, ready to alias.

 Uppercase, because it is a `const`, and C3 enforces the pairing in both directions.
 An uppercase alias must alias a constant, so `alias MSG = mtk::OF{Msg};` is the only spelling.
*>
// [3tk: HS-2, Part 3.1, A.5]
const OuterHelper OF = {};

// --- The four crossings ------------------------------------------------------
//
// Two independent axes, so the names are derivable rather than memorised.
// `must_` aborts on a mismatch, plain returns null; `take` empties the Slot on
// success, `look` leaves it alone. `look` and `must_look` accept a `Slot*` or
// an `Inner*`, dispatched at compile time on `$Typeof`.

<*
 From a Slot or an inner back to `Outer*`, without disturbing the Slot.

 Null on an identity mismatch.
 A mismatch is an answer, not a failure.

 @param from : "a `Slot*` or an `Inner*`"
*>
// [3tk: HS-3, Part 3.2]
macro Outer* OuterHelper.look(self, from)
{
    $switch:
        $case $Typeof(from) == Slot*:
            return mtk::from_slot(from, Outer);
        $case $Typeof(from) == Inner*:
            return mtk::from_inner(from, Outer);
        $default:
            $error "look takes a Slot* or an Inner*";
    $endswitch
}

<*
 Same as `look`, and it aborts on a mismatch.

 Use it where a mismatch would be your own defect.
 The abort names your line.
 Under `--safe=no` the check is gone.

 @param from : "a `Slot*` or an `Inner*`"
*>
// [3tk: HS-4, Part 3.2]
macro Outer* OuterHelper.must_look(self, from)
{
    $switch:
        $case $Typeof(from) == Slot*:
            return mtk::must_from_slot(from, Outer);
        $case $Typeof(from) == Inner*:
            return mtk::must_from_inner(from, Outer);
        $default:
            $error "must_look takes a Slot* or an Inner*";
    $endswitch
}

<*
 From a Slot back to `Outer*`, emptying the Slot on success.

 Null on an identity mismatch, and then the Slot is unchanged.
 There is no `Inner*` form: an inner has no Slot to empty.

 @param slot : "the Slot holding the outer; empty afterwards on success"
*>
// [3tk: HS-5, Part 3.2]
macro Outer* OuterHelper.take(self, Slot* slot) => mtk::move_from_slot(slot, Outer);

<*
 Same as `take`, and it aborts on a mismatch.

 The Slot is empty afterwards.
 This form did not exist before 3TK-64: the old `move_from_slot` had no abort form.

 @param slot : "the Slot holding the outer; empty afterwards"
*>
// [3tk: HS-6, Part 3.2]
macro Outer* OuterHelper.must_take(self, Slot* slot)
{
    Outer* outer = mtk::must_from_slot(slot, Outer);
    slot.take();
    return outer;
}

// --- The other five ----------------------------------------------------------

<*
 From your pointer to the `Inner*`, stamping the identity on the way.

 The stamp may be written any number of times and is safe on a linked outer, so this costs nothing to call twice.
 It is what makes the identity impossible to forget.

 @param outer : "a pointer to the outer"
*>
// [3tk: HS-7, HR-5, Part 3.3, Part 5.1]
macro Inner* OuterHelper.inner(self, Outer* outer)
{
    mtk::stamp(outer);
    return mtk::to_inner(outer);
}

<*
 Writes the identity into the embedded `Inner`, and nothing else.

 For an outer you allocated by hand.
 An outer made by `create` is stamped already.
 It is called `stamp` and not `init` because `init` is the name of your own hook.

 @param outer : "a pointer to the outer"
*>
// [3tk: HS-8, Part 3.3, Part 5.1]
macro void OuterHelper.stamp(self, Outer* outer) => mtk::stamp(outer);

<*
 True when the outer is on some chain.

 Exact, and O(1).

 @param outer : "a pointer to the outer"
*>
// [3tk: HS-9, Part 3.3]
macro bool OuterHelper.linked(self, Outer* outer) => mtk::is_linked(mtk::to_inner(outer));

// --- Allocating and freeing --------------------------------------------------

<*
 Allocates the outer, initializes it, stamps it, and fills the Slot.

 Four steps in this order: allocate zeroed, call your `init(a)` hook if you declared one, stamp the inner, fill the Slot.
 Stamping after the hook is deliberate: if `init` fails the outer was never stamped, so a pointer that escaped a failed creation can never be mistaken for a live outer.
 On a hook failure the allocation is freed and the fault is propagated unchanged.
 On an allocation failure the Slot is untouched and the fault is returned.
 It returns `void?` because its caller has a real decision to make.

 The toolkit reads and writes no field of your outer except the `Inner`.
 An outer that wants to keep its allocator stores this argument in its own field, under any name, in its own `init`.

 @param a : "the allocator; it is passed to your `init` hook and it is not stored"
 @param slot : "an empty Slot, filled on success"
*>
// [3tk: RT-5, Part 3.4, Part 9.2 rule 3]
macro void? OuterHelper.create(self, Allocator a, Slot* slot)
{
    // [3tk: Part 9.2 rule 3]
    mtk::@check(slot.is_empty(), "an acquisition asserts the Slot is empty on entry");
    Outer* outer = alloc::new_try(a, Outer)!;
    $if $defined(outer.init):
        if (catch f = outer.init(a))
        {
            alloc::free(a, outer);
            return f~;
        }
    $endif
    mtk::stamp(outer);
    slot.fill(mtk::to_inner(outer));
}

<*
 Calls your `destroy(a)` hook if you declared one, empties the Slot, and frees the outer.

 A no-op on an empty Slot, so a `defer` registered before the acquisition is safe.
 It returns `void`, and that is not symmetry-breaking for its own sake: `release` is what you write in a `defer`, and C3 refuses a bare failable call there.
 The narrower reason is that a teardown fault has no recipient — `release` runs on a path that is usually already unwinding, nobody can act on "freeing failed", and the resource is gone either way.
 A `destroy` fault therefore aborts in a safe build and is dropped in a fast one.
 A failing destructor is a defect, not an outcome.

 @param a : "the allocator the outer was created with"
 @param slot : "the Slot holding the outer; empty afterwards"
*>
// [3tk: RT-5, Part 3.4, Part 9.2, Part 13.1]
macro void OuterHelper.release(self, Allocator a, Slot* slot)
{
    if (slot.is_empty()) return;
    Outer* outer = mtk::must_from_slot(slot, Outer);
    $if $defined(outer.destroy):
        fault f = @catch(outer.destroy(a));
        mtk::@check(!f, "destroy failed during release");
    $endif
    slot.take();
    alloc::free(a, outer);
}


//----------------------
// Little-endian imports
//----------------------
import std::core::mem::alloc;
