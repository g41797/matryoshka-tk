<*
 The inner, the handle, the Slot, and the port's check macro.

 Matryoshka, the C3 port. Specification: matryoshka-specification-001.md.
 Design rulings: 3tk-porting-proposal-001.md, decisions D1 to D16.

 inner  — AnyNode, the embedded structure. Part 4.
 handle — AnyHandle, a pointer to an inner, with no type knowledge. Part 10.1.
 Slot   — a container of one handle, or of nothing. Part 9.
 item   — the outer struct, seen by the application.
*>
module mtk;
import std::core::env;

<*
 The inner. Part 4.2: exactly two parts, the links and the identity.

 A third field is added only with a reason written down, because every item in
 the program pays for it. D3 refused an allocator here for that reason.

 24 bytes on a 64-bit target.
*>
struct AnyNode
{
    AnyNode* prev;
    AnyNode* next;
    typeid   type;
}

<*
 A handle. Transparent, by D4: there is one handle type and no typed variants.

 It is an alias and not a typedef, so it converts freely with AnyNode*. The
 reading aid of Part 10.1 is what it buys; the compiler learns nothing.
*>
alias AnyHandle = AnyNode*;

<*
 The Slot. Distinct, by D5.

 Part 9.1: a container of one handle, or of nothing. Its emptiness is the
 transfer signal. Empty means the item is elsewhere; full means the item is
 here and this Slot's holder is responsible for it.

 Distinct rather than an alias, so that Part 9.2 rule 1 has a compile-time
 ally: an AnyHandle does not implicitly become a Slot, and a Slot* does not
 implicitly become an AnyHandle*. The two-star confusion of conflict C4 does
 not typecheck.

 Part 9.2 rule 2 — a Slot starts empty — is the language's default state. A
 zero-initialized Slot is null, and there is no initializer to forget.
*>
typedef Slot = AnyHandle;

<*
 The outcome sets of Part 19, as C3 faults. D15.

 These are runtime conditions, never defects: a correct program reaches every
 one of them. They are reported in every build mode and they never assert.
 Part 15.5.

 The `interrupted` outcome of Part 2.9 is absent. D9 dropped interruption:
 C3 has no interruptible condition wait, and the SHOULD's own text permits the
 drop.
*>
faultdef CLOSED, TIMEOUT, NOT_AVAILABLE, NOT_CREATED, EMPTY, WOKEN;

<*
 A contract check. Tier 2 of D6.

 In a safe build this is `always_assert`, which aborts and names the message.
 In `--safe=no` it expands to nothing at all: the condition is not evaluated,
 and nothing is handed to the optimizer as a promise it may act on.

 That last clause is the whole point. C3's own `assert` under `--safe=no -O3`
 is not a removed check, it is an assumption, and a violated assumption is
 undefined behaviour rather than a missed diagnostic. 3TK-4's Q11 probe
 segfaulted on exactly that. No plain `assert` guards a contract anywhere in
 this port.

 Public, not `@private`. Two reasons, and the second is the real one:
 `@private` in C3 does not reach a submodule, so `mtk::helper` could not see
 it; and Part 17.2 says the containers use only what an application could use,
 which makes an application writing its own Slot-shaped call entitled to the
 same check.

 The message is a compile-time string, because `always_assert` takes one.

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
 True where the checking tiers of D6 are live. Tier 3 guards read this.
*>
const bool CHECKED = env::COMPILER_SAFE_MODE;

// --- The Slot's reading shape -----------------------------------------------
//
// Part 9.9 predicted the cost of a distinct Slot: it cannot be read with the
// language's bare null test. These five are the replacement, and they say more
// than a null test does.

<*
 Part 9.1: empty means the item is elsewhere.
*>
fn bool Slot.is_empty(&self) @inline => !(AnyHandle)*self;

<*
 Part 9.1: full means the item is here, and this Slot's holder is responsible.
*>
fn bool Slot.is_full(&self) @inline => (AnyHandle)*self != null;

<*
 Look at the handle without taking it. The Slot is unchanged.

 Null on an empty Slot.
*>
fn AnyHandle Slot.peek(&self) @inline => (AnyHandle)*self;

<*
 Take the handle out and clear the Slot. Part 9.2 rule 5: a transfer clears it.

 Null on an empty Slot, and the Slot stays empty.
*>
fn AnyHandle Slot.take(&self) @inline
{
    AnyHandle h = (AnyHandle)*self;
    *self = (Slot)(AnyHandle)null;
    return h;
}

<*
 Put a handle in. Part 9.2 rule 1: never overwrite a full Slot.

 The check is tier 2 of D6. It is the single most-repeated contract in the
 toolkit, and this is the one place it is written.

 @param h : "the handle to place; must not be null"
*>
fn void Slot.fill(&self, AnyHandle h) @inline
{
    @check(h != null, "Slot.fill with a null handle");
    @check(self.is_empty(), "Part 9.2 rule 1: never overwrite a full Slot");
    *self = (Slot)h;
}

// --- Compile-time discovery of the outer's fields ----------------------------

<*
 The offset of the outer's inner field. Part 4.3, and Part 7.4's validation.

 Part 4.4 — one inner per outer — is checked here too, and it is the only
 place it can be checked.

 Both messages name the offending type, which is Part 7.4's last clause.

 A `return` inside `$foreach` does not end compile-time iteration, so the
 count accumulates and the assertions run afterwards.

 @param $Type : "the outer type"
*>
macro usz node_offset($Type)
{
    var $off = -1;
    var $seen = 0;
    $foreach $m : $Type::members:
        $if $m.type == AnyNode:
            $off = $m.offset;
            $seen = $seen + 1;
        $endif
    $endforeach
    $assert $seen != 0 : "type " +++ $Type::name +++ " has no AnyNode field; it cannot be a Matryoshka item";
    $assert $seen == 1 : "type " +++ $Type::name +++ " has more than one AnyNode field; Part 4.4 allows exactly one";
    return $off;
}

<*
 The offset of the outer's Allocator field, for D3's owning helper.

 The assertion is Part 7.4's message clause doing more than it was asked to: a
 type that took the wrong helper is told at build time which one it should
 have taken.

 A module-scope `$assert` in a generic module cannot see the module's type
 parameter, so the check lives here, inside a macro, where `$Type::name`
 resolves. Nothing else calls this.

 @param $Type : "the outer type"
*>
macro usz required_alloc_offset($Type)
{
    var $off = -1;
    $foreach $m : $Type::members:
        $if $m.type == Allocator:
            $off = $m.offset;
        $endif
    $endforeach
    $assert $off >= 0 : "type " +++ $Type::name +++ " has no Allocator field; use mtk::helper instead of mtk::owned";
    return $off;
}
