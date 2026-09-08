// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

<*
 An outer-transfer and outer-reuse toolkit for concurrent C3 programs.

 Three small tools, each one usable on its own.
 The core is type identity for an outer, and two containers that never allocate.
 `mtk::inner` is the inner, the Slot, the link and the crossings.
 `mtk::queue` is the intrusive queue and its walker.
 `mtk::helper` is the one thing you bind, one line per outer type.
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
 `import mtk;` gives this module and every submodule of it.
 This module holds `VERSION`, the faults, `@check` and `CHECKED`.
 They are the vocabulary every submodule and every user shares.
 Each subject is on the page of the module that holds it.

 We present you [[LOC]] lines of source.
*>
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
faultdef CLOSED, TIMEOUT, NOT_AVAILABLE, NOT_CREATED, EMPTY, WOKEN, UNKNOWN_IDENTITY;

<*
 Aborts in a safe build and names the message.

 Under `--safe=no` it expands to nothing.

 @param #cond : "the condition that must hold"
 @param $msg : "a compile-time message, named at the call site"
*>
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
const bool CHECKED = env::COMPILER_SAFE_MODE;
