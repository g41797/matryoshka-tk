<*
 The inner, the handle, the Slot, the link test, and the port's check macro.

 Matryoshka, the C3 port.
 Specification: ../common/matryoshka-specification-003.md, as the core redesign
 amends it — 3tk-core-redesign-proposal-002.md, R1 to R15.
 Design rulings: 3tk-porting-proposal-004.md, decisions D1 to D16.

 inner  — Inner, the embedded structure. Part 4.
 handle — Handle, a pointer to an inner, with no type knowledge. Part 10.1.
 Slot   — a container of one handle, or of nothing. Part 9.
 outer  — the application's struct, the one that embeds an inner. A category,
          never a type: no `Outer` is declared anywhere in this port.
*>
module mtk;
import std::core::env;

<*
 The inner. Part 4.2: exactly two parts, the linkage and the identity.

 **One link, not two — R5.** `prev` is gone. Nothing in this port ever needed
 arbitrary removal, arbitrary insertion, backward traversal or a take from the
 back, and the audit that proved it is §1.1 of the redesign proposal.

 A third field is added only with a reason written down, because every item in
 the program pays for it. D3 refused an allocator here, and R6 refused a
 membership field.

 16 bytes on a 64-bit target, down from 24. An observation; no code may depend
 on it.

 **The self-link invariant — R6b, and the redesign turns on it:**

   An item on a chain has a non-null `next`; the last item of a chain points at
   itself. An item on no chain has `next == null`.

 Every insert and every removal in `queue.c3` and `stack.c3` maintains it, and
 `is_linked` below reads it. It is what makes the link test EXACT, and an exact
 link test is what let the O(n) membership walk be deleted outright — from
 this port, and then from the specification: Part 8.6 is a tombstone in 003,
 V4, and a port without an exact test carries the walk under 8.7 instead. It
 replaces invariant 16, which 003 retired in place — the row is still numbered
 16 and says so, and 16b is this. V12.

 The price, stated plainly: `next` carries two meanings, and a walk that forgets
 to test `n.next == n` loops forever rather than ending. Four sites carry it,
 and each states the end test in its own body.
*>
struct Inner
{
    Inner* next;
    typeid type;
}

<*
 A handle. Transparent, by D4: there is one handle type and no typed variants.

 It is an alias and not a typedef, so it converts freely with Inner*. The
 reading aid of Part 10.1 is what it buys; the compiler learns nothing.

 Named `Handle` and not `InnerHandle` — R1. The module prefix already says
 whose handle it is, and D4's one-handle ruling reads better short.
*>
alias Handle = Inner*;

<*
 The Slot. Distinct, by D5.

 Part 9.1: a container of one handle, or of nothing. Its emptiness is the
 transfer signal. Empty means the item is elsewhere; full means the item is
 here and this Slot's holder is responsible for it.

 Distinct rather than an alias, so that Part 9.2 rule 1 has a compile-time
 ally: a Handle does not implicitly become a Slot, and a Slot* does not
 implicitly become a Handle*. The two-star confusion of conflict C4 does not
 typecheck.

 Part 9.2 rule 2 — a Slot starts empty — is the language's default state. A
 zero-initialized Slot is null, and there is no initializer to forget.
*>
typedef Slot = Handle;

<*
 The outcome sets of Part 19, as C3 faults. D15.

 These are runtime conditions, never defects: a correct program reaches every
 one of them. They are reported in every build mode and they never assert.
 Part 15.5.

 The `interrupted` outcome of Part 2.9 is absent. D9 dropped interruption:
 C3 has no interruptible condition wait, and the SHOULD's own text permits the
 drop. **003 made that legible in the outcome tables** — V13: Parts 19.1 and
 19.2 mark *interrupted* conditional on Part 2.9 rather than listing it flat,
 so a port that drops the SHOULD drops the outcome and is still conforming.
 The timeout outcome stays, and it does.

 The redesign adds no fault and removes none. §7.

 **`UNKNOWN_IDENTITY` is not one of Part 19's outcomes, and that is deliberate.**
 3TK-15 added it for assumption A3. Part 11.7 fixes the pool's set of
 identities at creation, so asking for one that is not in it is a defect of the
 caller and not a runtime condition — the sentence above about *never defects*
 does not cover it. It exists because the honest report of that defect used to
 be `NOT_AVAILABLE`, which Part 19.3 reserves for the available-only mode, and
 a fast build has no `@check` left to catch the confusion. It is reported by
 `Pool.get` and `Pool.get_wait` and by nothing else. Part 19.2's own set is
 untouched: every Part 19 outcome those two operations can produce is still
 exactly the one Part 19.2 lists.
*>
faultdef CLOSED, TIMEOUT, NOT_AVAILABLE, NOT_CREATED, EMPTY, WOKEN, UNKNOWN_IDENTITY;

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

 After the redesign the containers have no tier 3 guard left — the insert walk
 was the only one, and R6b deleted it. `pool.c3`'s duplicate-identity scan at
 creation is the port's last reader.
*>
const bool CHECKED = env::COMPILER_SAFE_MODE;

// --- The link test, and the repair -------------------------------------------
//
// These live with the Inner and not with a container, because after R6b they
// are statements about ONE item and no container is consulted to answer them.

<*
 The link test. Part 8.7, and **it is now exact** — R6b.

 003 turned that from this port's choice into everyone's rule: Part 8.7 says
 the link test MUST be exact and names the three prices — a terminator, a
 field, or the O(n) walk. R6b paid the first. V5.

 On a chain, `next` is never null: the last item points at itself. Off a chain,
 `next` is always null. So this answers *is this item on some chain* with no
 false negative and no false positive, in O(1), through the public surface.

 The blind spot 002's Part 8.7 made a MUST to document — an item ALONE on a
 list reporting false — is closed, and it cost no field. **003 does not
 document that blind spot; it forbids it**, which is why the sentence above
 reads as a rule rather than as this port doing better than asked. D12's
 accepted hole is gone with it, and so is Part 8.6, **deleted outright in 003**
 along with its O(n) walk: a check that refuses an item on ANY chain catches
 everything the same-container walk caught and more.

 What it does not catch, stated so nobody claims more: a chain corrupted by
 code that reached around the container surface. It is exact for every path
 through the public surface.
*>
fn bool is_linked(Handle h) @inline => h != null && h.next != null;

<*
 The repair. Part 8.8.

 After a removal the item's link is cleared, so it passes the link test and can
 be inserted again. Every removal in `queue.c3` and `stack.c3` calls this for
 the caller.

 One field to clear now, not two. The wording of Part 8.8 is unchanged.
*>
fn void reset(Handle h) @inline
{
    if (!h) return;
    h.next = null;
}

// --- The Slot's reading shape -----------------------------------------------
//
// Part 9.9 predicted the cost of a distinct Slot: it cannot be read with the
// language's bare null test. These five are the replacement, and they say more
// than a null test does.

<*
 Part 9.1: empty means the item is elsewhere.
*>
fn bool Slot.is_empty(&self) @inline => !(Handle)*self;

<*
 Part 9.1: full means the item is here, and this Slot's holder is responsible.
*>
fn bool Slot.is_full(&self) @inline => (Handle)*self != null;

<*
 Look at the handle without taking it. The Slot is unchanged.

 Null on an empty Slot.
*>
fn Handle Slot.peek(&self) @inline => (Handle)*self;

<*
 Take the handle out and clear the Slot. Part 9.2 rule 5: a transfer clears it.

 Null on an empty Slot, and the Slot stays empty.
*>
fn Handle Slot.take(&self) @inline
{
    Handle h = (Handle)*self;
    *self = (Slot)(Handle)null;
    return h;
}

<*
 Put a handle in. Part 9.2 rule 1: never overwrite a full Slot.

 The check is tier 2 of D6. It is the single most-repeated contract in the
 toolkit, and this is the one place it is written.

 @param h : "the handle to place; must not be null"
*>
fn void Slot.fill(&self, Handle h) @inline
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

 Both messages name the offending type, which is Part 7.4's last clause, and
 both now name `Inner` — R1.

 A `return` inside `$foreach` does not end compile-time iteration, so the
 count accumulates and the assertions run afterwards.

 @param $Type : "the outer type"
*>
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
    $assert $seen == 1 : "type " +++ $Type::name +++ " has more than one Inner field; Part 4.4 allows exactly one";
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
    $assert $off >= 0 : "type " +++ $Type::name +++ " has no Allocator field; use mtk::helper instead of mtk::managed";
    return $off;
}
