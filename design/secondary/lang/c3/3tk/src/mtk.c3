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
 The queue and the stack exist because the mailbox and the pool need them, and a caller may use either one directly.
 Not an allocator.
 Every outer is allocated and freed by your code, or by your hooks.
 Not a garbage collector.
 The toolkit never frees an outer you gave it, except through a hook you wrote.
 Not a coordinator.
 There is no `Master` type.

 One import gives the toolkit.
 `module mtk` is declared by one file, and the rest are submodules of it.
 This module holds `VERSION`, the faults, `@check` and `CHECKED`.
*>
// [3tk: D1 to D16, R1 to R15, H0, H0b, H5 to H10, E6, V19, Part 17.1, Part 17.2]
module mtk;
import std::core::env;
import mtk::helper;
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
