// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//==============================================================================
// `OuterHelper`, the one thing a user binds — and a module of its own again.
// 3TK-63 merged it into `mtk`; `3TK-pre-65` split it back out, because one
// generic section made the whole of `mtk` read as generic on the docs site,
// where `Inner`, `Slot` and `InnerQueue` have nothing to do with `Outer`.
//
// Every declaration here is the user surface. Every member forwards to a macro
// in `inner.c3` and has no logic of its own.
//==============================================================================
<*
 The helper, bound once per outer type.

 `alias MSG = helper::OF{Msg};` — and that is the whole ceremony.
 Nine members: four crossings, `inner`, `stamp`, `linked`, `create` and `release`.
 It is a module of its own so that it is a page of its own, and so that nothing else in the core reads as parameterized by `Outer`.
*>
module mtk::helper <Outer>;

<*
 The one thing a user binds, one line per outer type.

 `alias MSG = helper::OF{Msg};` — and that is the whole ceremony.

 The carrier holds nothing.
 Its only job is to give C3's method syntax a receiver, so that `MSG.create(mem, &s)` is a line you can write.
 The value is never read, as a number or as anything else.
*>
typedef OuterHelper = uptr;

<*
 The helper for `Outer`, ready to alias.

 Uppercase, because it is a `const`, and C3 enforces the pairing in both directions.
 An uppercase alias must alias a constant, so `alias MSG = helper::OF{Msg};` is the only spelling.
*>
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
macro Outer* OuterHelper.look(self, from)
{
    $switch:
        $case $Typeof(from) == Slot*:
            // [3tk: Q-8, Part 5.2]
            inner::check_stamped(from.peek(), "the outer was never stamped: make it with `create`, or call `stamp` once");
            return inner::from_slot(from, Outer);
        $case $Typeof(from) == Inner*:
            // [3tk: Q-8, Part 5.2]
            inner::check_stamped(from, "the outer was never stamped: make it with `create`, or call `stamp` once");
            return inner::from_inner(from, Outer);
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
macro Outer* OuterHelper.must_look(self, from)
{
    $switch:
        $case $Typeof(from) == Slot*:
            // [3tk: Q-8, Part 5.2]
            inner::check_stamped(from.peek(), "the outer was never stamped: make it with `create`, or call `stamp` once");
            return inner::must_from_slot(from, Outer);
        $case $Typeof(from) == Inner*:
            // [3tk: Q-8, Part 5.2]
            inner::check_stamped(from, "the outer was never stamped: make it with `create`, or call `stamp` once");
            return inner::must_from_inner(from, Outer);
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
macro Outer* OuterHelper.take(self, Slot* slot)
{
    // [3tk: Q-8, Part 5.2]
    inner::check_stamped(slot.peek(), "the outer was never stamped: make it with `create`, or call `stamp` once");
    return inner::move_from_slot(slot, Outer);
}

<*
 Same as `take`, and it aborts on a mismatch.

 The Slot is empty afterwards.
 This form did not exist before 3TK-64: the old `move_from_slot` had no abort form.

 @param slot : "the Slot holding the outer; empty afterwards"
*>
macro Outer* OuterHelper.must_take(self, Slot* slot)
{
    // [3tk: Q-8, Part 5.2]
    inner::check_stamped(slot.peek(), "the outer was never stamped: make it with `create`, or call `stamp` once");
    Outer* outer = inner::must_from_slot(slot, Outer);
    slot.take();
    return outer;
}

// --- The other five ----------------------------------------------------------

<*
 From your pointer to the `Inner*`, stamping the identity on the way.

 The stamp may be written any number of times and is safe on a linked outer, so this costs nothing to call twice.

 @param outer : "a pointer to the outer"
*>
macro Inner* OuterHelper.inner(self, Outer* outer)
{
    inner::stamp(outer);
    return inner::to_inner(outer);
}

<*
 Writes the identity into the embedded `Inner`, and nothing else.

 For an outer you allocated by hand.
 An outer made by `create` is stamped already.
 Forgetting it is caught in a safe build, at the next crossing or at the next insertion, whichever comes first.

 @param outer : "a pointer to the outer"
*>
macro void OuterHelper.stamp(self, Outer* outer) => inner::stamp(outer);

<*
 True when the outer is on some chain.

 Exact, and O(1).

 @param outer : "a pointer to the outer"
*>
macro bool OuterHelper.linked(self, Outer* outer) => inner::is_linked(inner::to_inner(outer));

// --- Allocating and freeing --------------------------------------------------

<*
 Allocates the outer, initializes it, stamps it, and fills the Slot.

 Four steps in this order: allocate zeroed, call your `init(a)` hook if you declared one, stamp the inner, fill the Slot.
 If `init` fails the outer was never stamped, so a pointer that escaped a failed creation can never be mistaken for a live outer.
 On a hook failure the allocation is freed and the fault is propagated unchanged.
 On an allocation failure the Slot is untouched and the fault is returned.

 The toolkit reads and writes no field of your outer except the `Inner`.
 An outer that wants to keep its allocator stores this argument in its own field, under any name, in its own `init`.

 @param a : "the allocator; it is passed to your `init` hook and it is not stored"
 @param slot : "an empty Slot, filled on success"
*>
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
    inner::stamp(outer);
    slot.fill(inner::to_inner(outer));
}

<*
 Calls your `destroy(a)` hook if you declared one, empties the Slot, and frees the outer.

 A no-op on an empty Slot, so a `defer` registered before the acquisition is safe.
 It returns `void`, so it needs no `!` in a `defer`.
 A `destroy` fault therefore aborts in a safe build and is dropped in a fast one.

 @param a : "the allocator the outer was created with"
 @param slot : "the Slot holding the outer; empty afterwards"
*>
macro void OuterHelper.release(self, Allocator a, Slot* slot)
{
    if (slot.is_empty()) return;
    Outer* outer = inner::must_from_slot(slot, Outer);
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
import mtk;
import std::core::mem::alloc;
