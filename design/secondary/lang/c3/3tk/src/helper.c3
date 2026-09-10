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
//
// NO HOOKS SUBMODULE, and 3TK-74 replaced 3TK-70's argument for that without
// disturbing the ruling. 3TK-70 refused an `interface OuterHooks` because both
// hooks were OPTIONAL and an inert interface would read as mandatory. B-1
// deletes that premise: the hooks are required now. The reason that stands is
// stronger and it is about the interface, not about optionality — an interface
// exists to carry a choice across a boundary AT RUNTIME, and these hooks are
// never passed. There is nothing to implement and nothing to hand over, so an
// interface would add a vtable dispatch to answer a question the compiler
// already knows, on a helper that has no instantiation at all. A module needs
// declarations and these have none: they are resolved on the type by name.
// A later stage that finds 3TK-70's sentence must not read the ruling as
// lapsed with its argument.
//==============================================================================
<*
 The helper, bound once per outer type.

 `alias MSG = helper::OF{Msg};` — and that is the whole ceremony.
 Nine members: four crossings, `inner`, `stamp`, `linked`, `create` and `release`.
 It is a module of its own so that it is a page of its own, and so that nothing else in the core reads as parameterized by `Outer`.

 EVERY OUTER THIS HELPER CREATES DECLARES TWO HOOKS, and the helper is where they run.
 `fn void? Outer.init(&self, Allocator a)` is called by `create`, after the allocation and before the stamp.
 `fn void Outer.finish(&self, Allocator a)` is called by `release`, before the Slot is emptied and the outer freed.
 Neither is optional and AN EMPTY BODY IS FINE — that is how a type says it has nothing to do.

 Why you must write two methods that may do nothing.
 A per-type fact with no default should be stated rather than inferred from absence, and absence was the ambiguity: no `init` used to mean either this type needs none or you spelled the name wrong, and nothing could tell the two apart.
 The hooks are found on the type by name, at compile time, so a wrong name used to make the branch vanish silently.
 Requiring the declaration is what makes the misspelling loud, and `initialize` or `deinit` where `init` belongs is now a compile error naming your line.
 (`Init` is not among the near misses: C3 refuses a method name that begins with a capital.)

 Nothing is registered, and there is no interface to implement.
 A hook with the wrong signature or the wrong return type is loud as well: the branch compiles and then fails.
 `finish` returns plain `void`, so it cannot fail — `release` returns `void` deliberately, and a fault no caller can act on is not worth declaring.

 THE CONTAINERS ARE OUTSIDE THIS.
 `Mailbox` and `Pool` bind the helper for crossing and never call `create`: they allocate themselves, because they hold a mutex and a condition variable whose teardown order is the whole of their release.
 The rule binds every outer the helper creates, and an outer bound only for crossing is not making `create`'s contract.

 The pool's hooks are a different shape and the difference is worth one sentence, because both are inversions and the confusion is a fair one.
 A pool's hooks are POLICY: one answer per pool, chosen when you create it, so you pass them in as a `PoolHooks` implementation.
 An outer's hooks are the TYPE'S OWN: one answer per type, fixed forever at compile time, so you declare them on the type.
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
                    inner::internal::check_stamped(from.peek(), "the outer was never stamped: make it with `create`, or call `stamp` once");
            return inner::internal::from_slot(from, Outer);
        $case $Typeof(from) == Inner*:
                    inner::internal::check_stamped(from, "the outer was never stamped: make it with `create`, or call `stamp` once");
            return inner::internal::from_inner(from, Outer);
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
                    inner::internal::check_stamped(from.peek(), "the outer was never stamped: make it with `create`, or call `stamp` once");
            return inner::internal::must_from_slot(from, Outer);
        $case $Typeof(from) == Inner*:
                    inner::internal::check_stamped(from, "the outer was never stamped: make it with `create`, or call `stamp` once");
            return inner::internal::must_from_inner(from, Outer);
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
    inner::internal::check_stamped(slot.peek(), "the outer was never stamped: make it with `create`, or call `stamp` once");
    return inner::internal::move_from_slot(slot, Outer);
}

<*
 Same as `take`, and it aborts on a mismatch.

 The Slot is empty afterwards.
 This form did not exist before 3TK-64: the old `move_from_slot` had no abort form.

 @param slot : "the Slot holding the outer; empty afterwards"
*>
macro Outer* OuterHelper.must_take(self, Slot* slot)
{
    inner::internal::check_stamped(slot.peek(), "the outer was never stamped: make it with `create`, or call `stamp` once");
    Outer* outer = inner::internal::must_from_slot(slot, Outer);
    slot.take();
    return outer;
}

// --- The other five ----------------------------------------------------------

<*
 From your pointer to the `Inner*`. This door only reads.

 The identity is yours to write: `create` stamps what it makes, and `stamp` is the door for an outer you allocated by hand.
 In a safe build this one verifies that identity, and names your line when it is missing or when it names another type.
 Under `--safe=no` it verifies nothing and the crossing is the address arithmetic alone.
 Null passes through and answers null.

 @param outer : "a pointer to the outer"
*>
macro Inner* OuterHelper.inner(self, Outer* outer)
{
    mtk::@check(outer == null || inner::internal::is_mine(inner::internal::to_inner(outer), Outer),
        "the outer was never stamped, or carries another type: make it with `create`, or call `stamp` once");
    return inner::internal::to_inner(outer);
}

<*
 Writes the identity into the embedded `Inner`, and nothing else.

 For an outer you allocated by hand.
 An outer made by `create` is stamped already.
 Forgetting it is caught in a safe build, at the next crossing or at the next insertion, whichever comes first.

 @param outer : "a pointer to the outer"
*>
macro void OuterHelper.stamp(self, Outer* outer) => inner::internal::stamp(outer);

<*
 True when the outer is on some chain.

 Exact, and O(1).
 It accepts an `Outer*` or an `Inner*`, dispatched at compile time on `$Typeof`, the way `look` and `must_look` do: a caller who has just taken one off a queue holds the inner and has nothing to cross back for.

 @param from : "an `Outer*` or an `Inner*`"
*>
macro bool OuterHelper.linked(self, from)
{
    $switch:
        $case $Typeof(from) == Outer*:
            return inner::internal::is_linked(inner::internal::to_inner(from));
        $case $Typeof(from) == Inner*:
            return inner::internal::is_linked(from);
        $default:
            $error "linked takes an Outer* or an Inner*";
    $endswitch
}

// --- Allocating and freeing --------------------------------------------------

<*
 Allocates the outer, initializes it, stamps it, and fills the Slot.

 Four steps in this order: allocate zeroed, call your `init(a)` hook, stamp the inner, fill the Slot.
 `Outer` must declare `fn void? Outer.init(&self, Allocator a)` and `fn void Outer.finish(&self, Allocator a)`, and an empty body is fine — a type with neither to write declares both and leaves them empty.
 That is checked at compile time, here and in `release`, so a misspelled hook names your line instead of vanishing.
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
    $assert $defined(outer.init) : "every outer the helper creates declares `fn void? Outer.init(&self, Allocator a)` — an empty body is fine";
    $assert $defined(outer.finish) : "every outer the helper creates declares `fn void Outer.finish(&self, Allocator a)` — an empty body is fine";
    if (catch f = outer.init(a))
    {
        alloc::free(a, outer);
        return f~;
    }
    inner::internal::stamp(outer);
    slot.fill(inner::internal::to_inner(outer));
}

<*
 Calls your `finish(a)` hook, empties the Slot, and frees the outer.

 A no-op on an empty Slot, so a `defer` registered before the acquisition is safe.
 It returns `void`, so it needs no `!` in a `defer`, and `finish` returns `void` for the same reason: a fault raised there would reach no caller who could act on it.
 `finish` is not `destroy`, and the name is the warning — do not tear the outer down here. `release` frees it the moment your hook returns.
 Give up what the outer acquired and leave the memory alone.
 The same compile-time check as `create`: both hooks must be declared, and an empty body is fine.

 @param a : "the allocator the outer was created with"
 @param slot : "the Slot holding the outer; empty afterwards"
*>
macro void OuterHelper.release(self, Allocator a, Slot* slot)
{
    if (slot.is_empty()) return;
    Outer* outer = inner::internal::must_from_slot(slot, Outer);
    $assert $defined(outer.init) : "every outer the helper creates declares `fn void? Outer.init(&self, Allocator a)` — an empty body is fine";
    $assert $defined(outer.finish) : "every outer the helper creates declares `fn void Outer.finish(&self, Allocator a)` — an empty body is fine";
    outer.finish(a);
    slot.take();
    alloc::free(a, outer);
}


//----------------------
// Little-endian imports
//----------------------
import mtk;
import std::core::mem::alloc;
