<*
 The inner, the handle, the Slot, the link test, and the port's check macro.
*>
// [3tk: D1 to D16, R1 to R15, Part 4, Part 9, Part 10.1]
module mtk;
import std::core::env;

<*
 The inner. Exactly two parts, the linkage and the identity.

 `link.ptr` is the chain link; `link.type` is the identity.
*>
// [3tk: R5, R6, R6b, D3, V12, Part 4.2, Part 5]
struct Inner
{
    any link;
}

// --- Writing and reading the link -------------------------------------------

<*
 Keep the identity, swap the chain link.

 @param to : "the handle this item now links to; itself, if it is the end"
*>
// [3tk: R6b]
fn void Inner.repoint_to(&self, Handle to) @inline
    => self.link = any_make(to, self.link.type);

<*
 The chain link this item points at. Null if it is on no chain.
*>
// [3tk: R6b]
fn Handle Inner.points_to(&self) @inline => (Handle)self.link.ptr;

<*
 A handle. One handle type, and it converts freely with `Inner*`.
*>
// [3tk: D4, R1, Part 10.1]
alias Handle = Inner*;

<*
 The Slot. A container of one handle, or of nothing.

 Empty means the item is elsewhere. Full means the item is here.
 A Slot starts empty.
*>
// [3tk: D5, Part 9.1, Part 9.2 rule 1, Part 9.2 rule 2]
typedef Slot = Handle;

<*
 The outcome sets, as C3 faults.

 These are runtime conditions, never defects. A correct program reaches them.
 `UNKNOWN_IDENTITY` comes only from `Pool.get` and `Pool.get_wait`.
*>
// [3tk: D9, D15, A3, V13, Part 15.5, Part 19]
faultdef CLOSED, TIMEOUT, NOT_AVAILABLE, NOT_CREATED, EMPTY, WOKEN, UNKNOWN_IDENTITY;

<*
 A contract check.

 In a safe build it aborts and names the message.
 Under `--safe=no` it expands to nothing, and the condition is not evaluated.

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
 True where the checking tiers are live. Tier 3 guards read this.
*>
// [3tk: D6]
const bool CHECKED = env::COMPILER_SAFE_MODE;

// --- The link test, and the repair -------------------------------------------

<*
 True if the handle is on some chain. Exact, and O(1).

 False for a null handle.
*>
// [3tk: R6b, D12, V4, V5, Part 8.6, Part 8.7]
fn bool is_linked(Handle h) @inline => h != null && h.points_to() != null;

<*
 Clear the chain link, so the item can be inserted again.

 Every removal in `queue.c3` and `stack.c3` calls it for the caller.
 It clears the link and not the identity.
*>
// [3tk: Part 5.4, Part 8.8]
fn void reset(Handle h) @inline
{
    if (!h) return;
    h.repoint_to(null);
}

// --- The Slot's reading shape -----------------------------------------------

<*
 True if the Slot holds nothing.
*>
// [3tk: Part 9.1, Part 9.9]
fn bool Slot.is_empty(&self) @inline => !(Handle)*self;

<*
 True if the Slot holds a handle.
*>
// [3tk: Part 9.1, Part 9.9]
fn bool Slot.is_full(&self) @inline => (Handle)*self != null;

<*
 Look at the handle without taking it. The Slot is unchanged.

 Null on an empty Slot.
*>
// [3tk: Part 9.9]
fn Handle Slot.peek(&self) @inline => (Handle)*self;

<*
 Take the handle out and clear the Slot.

 Null on an empty Slot, and the Slot stays empty.
*>
// [3tk: Part 9.2 rule 5, Part 9.9]
fn Handle Slot.take(&self) @inline
{
    Handle h = (Handle)*self;
    *self = (Slot)(Handle)null;
    return h;
}

<*
 Put a handle in. Never overwrite a full Slot.

 @param h : "the handle to place; must not be null"
*>
// [3tk: D6, Part 9.2 rule 1, Part 9.9]
fn void Slot.fill(&self, Handle h) @inline
{
    @check(h != null, "Slot.fill with a null handle");
    // [3tk: Part 9.2 rule 1]
    @check(self.is_empty(), "never overwrite a full Slot");
    *self = (Slot)h;
}

// --- Compile-time discovery of the outer's fields ----------------------------

<*
 The offset of the outer's `Inner` field.

 A type with no `Inner` field, or with more than one, fails to compile.

 @param $Type : "the outer type"
*>
// [3tk: Part 4.3, Part 4.4, Part 7.4]
macro usz inner_offset($Type)
{
    var $off = -1;
    var $seen = 0;
    $foreach $m : $Type::members:
        $if $m.type == Inner:
            $off = $m.offset;
            $seen = $seen + 1;
        $endif
    $endforeach
    $assert $seen != 0 : "type " +++ $Type::name +++ " has no Inner field; it cannot be a Matryoshka item";
    // [3tk: Part 4.4]
    $assert $seen == 1 : "type " +++ $Type::name +++ " has more than one Inner field; exactly one is allowed";
    return $off;
}

<*
 The offset of the outer's `Allocator` field, for the owning helper.

 A type with no `Allocator` field fails to compile.

 @param $Type : "the outer type"
*>
// [3tk: D3, Part 7.4]
macro usz required_alloc_offset($Type)
{
    var $off = -1;
    $foreach $m : $Type::members:
        $if $m.type == Allocator:
            $off = $m.offset;
        $endif
    $endforeach
    $assert $off >= 0 : "type " +++ $Type::name +++ " has no Allocator field; use mtk::helper instead of mtk::managed";
    return $off;
}
