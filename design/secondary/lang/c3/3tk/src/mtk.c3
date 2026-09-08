// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

<*
 An outer-transfer and outer-reuse toolkit for concurrent C3 programs.

 Three small tools, each one usable on its own.
 The core is type identity for an outer, and two containers that never allocate.
 `mtk::mailbox` is transfer of an outer between threads.
 `mtk::pool` is reuse of an outer, decided by your hooks.
 Mailbox and pool are both optional.
 The core alone is a valid use.

 Share by communicating.
 Do not share access to an outer, move the outer.
 One place has the outer at a time.
 That gives a concurrent program with no lock around application data.

 Not a container library.
 The queue and the stack exist because the mailbox and the pool need them, and a caller may use the queue directly.
 The stack is private to the pool.
 Not an allocator.
 Every outer is allocated and freed by your code, or by your hooks.
 Not a garbage collector.
 The toolkit never frees an outer you gave it, except through a hook you wrote.
 Not a coordinator.
 There is no `Master` type.

 One import gives the toolkit.
 `module mtk` is declared by two files, and the helper, the queue, the mailbox and the pool are submodules of it.
 This module holds `VERSION`, the faults, `@check` and `CHECKED`.
 It holds the inner, the Slot, the link and the crossings.

 You send and receive your own struct.
 The struct is the outer, and it is yours.
 You give the infrastructure one thing, an `Inner` embedded in it.
 From then on the infrastructure never sees your type.
 It moves `Inner*`, intrusively and with the type erased.

 `Inner` is the field you embed.
 The chain link and the identity, in one.
 The identity sits in the same field as the chain link.
 The identity says what the outer type is.
 A pointer to an embedded `Inner` is one outer, with the type forgotten.
 It is spelled `Inner*`, because that is all it is, and 3tk transports nothing else.
 `Slot` is a box that holds one `Inner*`, or nothing.
 A Slot starts empty.

 The Slot is how the toolkit tells you where an outer went.
 Read the Slot after every call that gives or takes an outer.

 The chain link is the other half of `Inner`.
 `reset` clears the chain link and not the identity.
 Every chain ends at an inner pointing at itself, never at null.
 That is what makes `is_linked` exact.

 You send and receive your own struct.
 You give the infrastructure one thing, an `Inner` embedded in it.
 From then on the infrastructure never sees your type.
 It moves `Inner*`, intrusively and with the type erased.
 You get your struct back by crossing once, from `Inner*` to `Outer*`.
 The identity in the `Inner` is what makes that crossing safe.

 `to_inner` goes from your pointer to the `Inner*`.
 Null in, null out.
 `from_inner` goes from an `Inner*` back to `$Type*`, and is null on an identity mismatch.
 A mismatch is an answer, not a failure.
 `must_from_inner` is the same, and it aborts on a mismatch.
 The abort names your line.
 The same three take the outer from a Slot, and five of them appear again as methods.
 `from_slot` looks, and the Slot is unchanged.
 `move_from_slot` takes, and on success the Slot is left empty.
 None of these moves an outer.
 Reading an identity and casting a pointer leave every container alone.
 No alias to declare, no instantiation, no registration.

 The intrusive queue. First-in first-out.
 The transfer container.
 Nothing here allocates, and every operation is O(1).
 The count is kept, so `len` is O(1).
 `push_back` adds at the back.
 There is no front insert.
 `pop_front` takes the outer at the front, and null on an empty queue is an answer and not a fault.
 `append_queue` moves every outer of another queue onto the back of this one, in O(1).
 `iter` and `next` are a walker, taken from the queue.
 Removing the current outer during a walk is not supported.
 Every chain ends at an inner pointing at itself, never at null.
 Nothing in the queue can fail.
*>
// [3tk: D1 to D16, R1 to R15, H0, H0b, H5 to H10, E6, V19, Part 17.1, Part 17.2]
module mtk;
import std::core::env;
<*
 The toolkit's version string.
*>
const String VERSION = "0.0.1";

<*
 The faults are outcomes a correct program reaches.

 A 3tk call that can fail returns `void?`.
 A defect is not a fault.
 A defect aborts.
 `UNKNOWN_IDENTITY` is the one that is also a defect.
 It comes only from `Pool.get` and `Pool.get_wait`.
*>
// [3tk: D9, D15, A3, V13, Part 15.5, Part 19]
faultdef CLOSED, TIMEOUT, NOT_AVAILABLE, NOT_CREATED, EMPTY, WOKEN, UNKNOWN_IDENTITY;

<*
 Aborts in a safe build and names the message.

 Under `--safe=no` it expands to nothing.

 @param #cond : "the condition that must hold"
 @param $msg : "a compile-time message, named at the call site"
*>
// [3tk: D6, Q11, Part 17.2]
macro @check(#cond, $msg)
{
    $if env::COMPILER_SAFE_MODE:
        always_assert(#cond, $msg);
    $endif
}

<*
 True where those checks are live.

 Guard an expensive check with it.
*>
// [3tk: D6]
const bool CHECKED = env::COMPILER_SAFE_MODE;
