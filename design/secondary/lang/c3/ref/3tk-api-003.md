# 3tk — API verification table, 003

Every public declaration of the C3 port, with every assert and every contract
clause copied from the source and carrying its `file:line`.

**This is not the page to learn the toolkit from.**
[3tk-api-002.md](3tk-api-002.md) is that page, and it is the one a caller
reads. Read this one to check that 002 is telling the truth, or to find where
in `3tk/src` a promise is actually made.

**It was written as the reference and it is not one.** Reviewed by the owner
2026-08-25: three of its four bullets per entry were mandatory, so every entry
filled them whether or not it had anything to say — 87 `What` bullets that
restate the declaration's own name, 30 bullets whose whole content is `O(1)`,
and 94 citation bullets against 18 lines of example code in the entire port.
The citations are the part worth keeping, and that is what this file now is.

**It is alive.** It is revised whenever `3tk/src` changes, in the same stage
that changes it. A file under `ref/` that contradicts `3tk/src` is a defect of
the stage that changed the source. The rule binds every file under `ref/`.

**It does not argue.** No ruling markers, no history, no alternatives that were
refused. Those live in [3tk-decisions-003.md](3tk-decisions-003.md).

**Every contract and every check below is copied from `3tk/src`**, with its
`file:line`. None is inferred from what a declaration ought to check.

**003 replaces 001, revised by 3TK-32 on 2026-08-25.** 001 is in `backup/`.
3TK-32 rewrote the 21 string literals in `3tk/src` that cited a specification
Part, and the one that carried a ruling marker, so that what a user is shown is
the fact they can act on. Every one of those strings is quoted here, so every
quote was rewritten with it. The removed markers are on `// [3tk: ...]` marks in
the source, and adding those marks moved lines, so every `file:line` on this
page was recomputed. No declaration, signature or body changed.

## What was measured

Measured live on 2026-08-25, against `3tk/src`:

- **67 public functions and macros.** `fn` and `macro` at column 0, minus the
  seven marked `@private` — a marker C3 ignores on a method declaration and
  warns that it ignores, so those seven are reachable and are documented
  nowhere. Treating them as internal is a convention, not a wall.
- **16 public types and constants.** `struct`, `enum`, `alias`, `typedef`,
  `const`, `faultdef`, `interface`.
- **3 interface methods** on `PoolHooks`, implemented by the application.
- **66 contract clauses** in `<* *>` blocks — `@require`, `@param`, `@return?`.
  No `@ensure` anywhere.

The seven internal declarations are not documented here. They are
`Mailbox.enqueue`, `Mailbox.dequeue`, `Mailbox.has_queued`, `Mailbox.send_at`,
`Pool.bucket_for`, `Pool.take_back`, `Pool.take_back_handle`.

## How to read an entry

**Signature** — copied from the source.

- **What** — one line.
- **Promises** — what a caller may rely on.
- **Costs** — the complexity, or the lock, or the allocation.
- **Contract** — the `<* *>` clauses, verbatim, with `file:line`.
- **Checks** — the runtime checks, verbatim, with `file:line`.

**Two check tiers appear below.**

- `mtk::@check` — live in a safe build, gone entirely under `--safe=no`.
- `always_assert` — live in every build mode, including `--safe=no -O3`.

## The modules

| module | file | what is in it |
|---|---|---|
| `mtk` | `mtk.c3` | the port's identity |
| `mtk` | `inner.c3` | `Inner`, `Handle`, `Slot`, the faults, `@check` |
| `mtk` | `queue.c3` | `InnerQueue` and its walker |
| `mtk` | `stack.c3` | `InnerStack` |
| `mtk::helper` | `helper.c3` | the crossings between a typed pointer and a handle |
| `mtk::managed` | `managed.c3` | the helper plus create and release |
| `mtk::mailbox` | `mailbox.c3` | `Mailbox` |
| `mtk::pool` | `pool.c3` | `Pool`, `PoolHooks` |

**An application imports `mtk` and whichever of the four submodules it needs.**

---

# `mtk` — mtk.c3

### `const String VERSION = "0.2.0"`

- **What** — the port's version string.
- **Costs** — a compile-time constant.

---

# `mtk` — inner.c3

## Types

### `struct Inner { any link; }`

- **What** — the structure an application embeds in its own struct. One field.
- **Promises** — `link.ptr` is the chain link. `link.type` is the type
  identity, written once by `helper::init`.
- **Costs** — 16 bytes. Every item in the program pays it.

### `alias Handle = Inner*`

- **What** — a pointer to an inner, with no type knowledge.
- **Promises** — one handle type. There are no typed variants.
- **Costs** — an alias, not a typedef: it converts freely with `Inner*`. The
  compiler learns nothing from it.

### `typedef Slot = Handle`

- **What** — a container of one handle, or of nothing.
- **Promises** — emptiness is the transfer signal. Empty means the item is
  elsewhere. Full means the item is here.
- **Costs** — distinct, so a `Handle` does not implicitly become a `Slot`. A
  zero-initialized Slot is empty; there is no initializer to forget.

### `faultdef CLOSED, TIMEOUT, NOT_AVAILABLE, NOT_CREATED, EMPTY, WOKEN, UNKNOWN_IDENTITY`

- **What** — the port's faults.
- **Promises** — the first six are runtime conditions, never defects. A correct
  program reaches every one. They are reported in every build mode and they
  never assert.
- **Costs** — `UNKNOWN_IDENTITY` is the exception: it reports a defect of the
  caller. It is produced by `Pool.get` and `Pool.get_wait` and by nothing else.

### `const bool CHECKED = env::COMPILER_SAFE_MODE`

- **What** — true where the checking tiers are live.
- **Promises** — a `$if mtk::CHECKED:` block compiles to nothing in a fast
  build. Its one reader in `src/` is the duplicate-identity scan in
  `Pool.create`.

## The link

### `fn void Inner.repoint_to(&self, Handle to) @inline`

- **What** — keeps the identity, swaps the chain link.
- **Promises** — `link.type` is carried through unchanged.
- **Costs** — O(1). One `any_make`.
- **Contract** — `@param to : "the handle this item now links to; itself, if it is the end"` — `inner.c3:24`.

### `fn Handle Inner.points_to(&self) @inline`

- **What** — the chain link this item points at.
- **Promises** — null if the item is on no chain. The last item of a chain
  points at itself, so `n.points_to() == n` is the end test.
- **Costs** — O(1).

### `fn bool is_linked(Handle h) @inline`

- **What** — the link test.
- **Promises** — exact. No false negative and no false positive, for every path
  through the public surface. An item alone on a chain reports true.
- **Costs** — O(1). No field beyond `Inner.link`, and no walk.

### `fn void reset(Handle h) @inline`

- **What** — clears the link after a removal, so the item can be inserted
  again.
- **Promises** — it clears the link and not the identity. Null is a no-op.
  Every removal in `queue.c3` and `stack.c3` calls it for the caller.
- **Costs** — O(1).

## The Slot

### `fn bool Slot.is_empty(&self) @inline`

- **What** — empty means the item is elsewhere.
- **Costs** — O(1).

### `fn bool Slot.is_full(&self) @inline`

- **What** — full means the item is here, and this Slot's holder is
  responsible for it.
- **Costs** — O(1).

### `fn Handle Slot.peek(&self) @inline`

- **What** — look at the handle without taking it.
- **Promises** — the Slot is unchanged. Null on an empty Slot.
- **Costs** — O(1).

### `fn Handle Slot.take(&self) @inline`

- **What** — take the handle out and clear the Slot.
- **Promises** — null on an empty Slot, and the Slot stays empty.
- **Costs** — O(1).

### `fn void Slot.fill(&self, Handle h) @inline`

- **What** — put a handle in.
- **Promises** — a full Slot is never overwritten.
- **Costs** — O(1).
- **Contract** — `@param h : "the handle to place; must not be null"` — `inner.c3:144`.
- **Checks** — `@check(h != null, "Slot.fill with a null handle")` — `inner.c3:149`.
- **Checks** — `@check(self.is_empty(), "never overwrite a full Slot")` — `inner.c3:151`.

## The check macro

### `macro @check(#cond, $msg)`

- **What** — a contract check.
- **Promises** — in a safe build it is `always_assert`, which aborts and names
  the message. Under `--safe=no` it expands to nothing at all: the condition is
  not evaluated, and nothing is handed to the optimizer as a promise.
- **Costs** — nothing in a fast build. `$msg` must be a compile-time string.
- **Contract** — `@param #cond : "the condition that must hold"` — `inner.c3:66`.
- **Contract** — `@param $msg : "a compile-time message, named at the call site"` — `inner.c3:67`.

## Compile-time discovery

### `macro usz inner_offset($Type)`

- **What** — the offset of the outer's `Inner` field.
- **Promises** — a type with no `Inner` field, or with more than one, fails the
  build and is named in the message.
- **Costs** — compile time only.
- **Contract** — `@param $Type : "the outer type"` — `inner.c3:162`.
- **Checks** — `$assert $seen != 0 : "type " +++ $Type::name +++ " has no Inner field; it cannot be a Matryoshka item"` — `inner.c3:175`.
- **Checks** — `$assert $seen == 1 : "type " +++ $Type::name +++ " has more than one Inner field; exactly one is allowed"` — `inner.c3:177`.

### `macro usz required_alloc_offset($Type)`

- **What** — the offset of the outer's `Allocator` field.
- **Promises** — a type with no `Allocator` field fails the build, and the
  message names the helper it should have taken instead.
- **Costs** — compile time only.
- **Contract** — `@param $Type : "the outer type"` — `inner.c3:186`.
- **Checks** — `$assert $off >= 0 : "type " +++ $Type::name +++ " has no Allocator field; use mtk::helper instead of mtk::managed"` — `inner.c3:197`.

**A second declaration of the same name lives in `managed.c3:66`**, with the
same body and the same `$assert` at `managed.c3:74`.

---

# `mtk` — queue.c3

**First-in first-out. Seven operations. Nothing here allocates, the item is the
node, and every operation is O(1) in every build mode.**

**Nothing in this file can fail.** A take from an empty queue returns null.
That is an answer, not a fault.

## Types

### `struct InnerQueue { Inner* head; Inner* tail; usz count; }`

- **What** — the queue header.
- **Promises** — the count is kept, so `len` is O(1).
- **Costs** — three words per queue.

### `struct InnerQueueIterator { Inner* cur; }`

- **What** — a walker, taken from the queue.
- **Promises** — yields handles one at a time, exhausted when it returns null.
- **Costs** — one word. **Removing the current item during a walk is not
  supported.**

## The guard

### `macro InnerQueue.@guard_insert(&self, Handle h)`

- **What** — the insert guard, run by both inserts.
- **Costs** — tier 2, and O(1). Gone in a fast build.
- **Checks** — `@check(h != null, "insert of a null handle")` — `queue.c3:50`.
- **Checks** — `@check(!is_linked(h), "the item is already on a chain")` — `queue.c3:52`.

## Questions

### `fn bool InnerQueue.is_empty(&self) @inline`

- **What** — is it empty.
- **Costs** — O(1).

### `fn usz InnerQueue.len(&self) @inline`

- **What** — how many.
- **Costs** — O(1), from the kept count.

### `fn InnerQueueIterator InnerQueue.iter(&self) @inline`

- **What** — a walker over the queue, from the head.
- **Costs** — O(1).

### `fn Handle InnerQueueIterator.next(&self)`

- **What** — the next handle, or null when the walk is exhausted.
- **Promises** — the end test is `n.points_to() == n`, and a walker written
  without it does not terminate.
- **Costs** — O(1) per item.

## Adding

### `fn void InnerQueue.push_back(&self, Handle h)`

- **What** — add at the back.
- **Promises** — the new item is the tail and is self-linked. The old tail
  points at it.
- **Costs** — O(1), plus the guard above.

### `fn void InnerQueue.push_back_slot(&self, Slot* s)`

- **What** — add at the back, from a Slot.
- **Promises** — the transfer clears the Slot.
- **Costs** — O(1). **An empty Slot is a defect, not a no-op.** The check is
  tier 2 and the early return is ordinary code, so a fast build does nothing
  rather than dereference a null.
- **Checks** — `@check(s.is_full(), "push_back_slot from an empty Slot")` — `queue.c3:112`.

## Removing

### `fn Handle InnerQueue.pop_front(&self)`

- **What** — take from the front.
- **Promises** — null on an empty queue. The returned item's link is cleared.
- **Costs** — O(1).

## Moving

### `fn void InnerQueue.append_queue(&self, InnerQueue* other)`

- **What** — move every item of another queue onto this one.
- **Promises** — `other` is empty afterwards. No repair is needed at the join.
- **Costs** — O(1), a splice. The self-move check is tier 2 and the early
  return is ordinary code; without both, the naive move rings the items into a
  cycle and loses every one.
- **Contract** — `@param other : "the queue to empty onto this one; empty afterwards"` — `queue.c3:152`.
- **Checks** — `@check(other != null, "append_queue with a null queue")` — `queue.c3:157`.
- **Checks** — `@check(other != self, "a queue cannot be moved onto itself")` — `queue.c3:159`.

---

# `mtk` — stack.c3

**Last-in first-out. Four operations, all O(1). Nothing here can fail.**

**There is no walker and no splice.** There is no Slot-shaped insert.

**No caller is entitled to the order.** The pool says the container is a stack;
it does not promise most-recently-returned-first.

## Types

### `struct InnerStack { Inner* top; usz count; }`

- **What** — the stack header.
- **Promises** — the count is kept, so `len` is O(1).
- **Costs** — two words. There is no `tail`, which is what makes
  `Pool.close`'s flatten O(n) rather than a splice.

## The guard

### `macro InnerStack.@guard_insert(&self, Handle h)`

- **What** — the insert guard. The same guard the queue carries.
- **Costs** — tier 2, and O(1).
- **Checks** — `@check(h != null, "insert of a null handle")` — `stack.c3:35`.
- **Checks** — `@check(!is_linked(h), "the item is already on a chain")` — `stack.c3:37`.

## Questions

### `fn bool InnerStack.is_empty(&self) @inline`

- **What** — is it empty.
- **Costs** — O(1).

### `fn usz InnerStack.len(&self) @inline`

- **What** — how many.
- **Costs** — O(1), from the kept count.

## Adding and removing

### `fn void InnerStack.push(&self, Handle h)`

- **What** — add on top.
- **Promises** — an item pushed onto an empty stack is the bottom and is
  self-linked. Otherwise it points at the item it covers.
- **Costs** — O(1), plus the guard above.

### `fn Handle InnerStack.pop(&self)`

- **What** — take from the top.
- **Promises** — null on an empty stack. The returned item's link is cleared.
- **Costs** — O(1). The sole item is recognised by `h.points_to() == h`.

---

# `mtk::helper` — helper.c3

**Every crossing between a typed pointer and a type-erased handle happens in
this file and nowhere else.**

**There is no instantiation and no alias, for any type, ever.** The members are
macros over `$Type`, and the code is generated per call site. A new outer type
costs nothing before it can be used — not one line.

**The type identity is C3's own `$Type::typeid`.** The port does not
re-export it.

**Two names, two behaviours.** `from_*` is the checking crossing and returns
null on a mismatch. `must_from_*` is the asserting crossing: its `@require` is
live in a safe build and gone under `--safe=no`, and it names the caller's
line.

    struct Msg { int id; Inner node; char[64] body; }

    Msg m;
    mtk::helper::init(&m);
    Handle h = mtk::helper::to_handle(&m);

    Msg* p = h.to(Msg);        // checking
    Msg* q = h.as(Msg);        // asserting

**All twelve crossings are O(1)**, and none allocates.

## The predicate

### `macro bool is_mine(Handle h, $Type)`

- **What** — does this identity name my type.
- **Promises** — a null handle is not mine. An item whose `init` was never
  called carries a zeroed typeid, which matches no type, and is refused here
  rather than mis-claimed.
- **Costs** — O(1), one typeid comparison.
- **Contract** — `@param $Type : "the outer type"` — `helper.c3:17`.

## The initializer

### `macro void init(item)`

- **What** — writes the identity into the inner.
- **Promises** — the link is cleared in the same write, so a freshly
  initialized item passes the link test and can be inserted. **This is the one
  place the identity is written.** Every creation site calls it, including the
  ones that do not allocate.
- **Costs** — O(1), one `any_make`. The type is inferred from the pointer; no
  call site names it.
- **Contract** — `@param item : "a pointer to the outer"` — `helper.c3:28`.
- **Contract** — `@require $defined($Typeof(*item)::members) : "not a struct that embeds an Inner"` — `helper.c3:29`.

## Outbound

### `macro Handle to_handle(item)`

- **What** — from a typed pointer to a handle.
- **Promises** — cannot fail. Null in, null out.
- **Costs** — O(1). The only direction that adds the offset, and the only one
  that never names a type.
- **Contract** — `@param item : "a pointer to the outer, or null"` — `helper.c3:44`.
- **Contract** — `@require $defined($Typeof(*item)::members) : "not a struct that embeds an Inner"` — `helper.c3:45`.

## Inbound, from a handle

### `macro from_handle(Handle h, $Type)`

- **What** — the checking crossing.
- **Promises** — null when the identity does not match. A mismatch is a
  legitimate state of a correct program: a walker of a heterogeneous list meets
  other types by design.
- **Costs** — O(1).
- **Contract** — `@param $Type : "the outer type expected"` — `helper.c3:57`.

### `macro must_from_handle(Handle h, $Type)`

- **What** — the asserting crossing.
- **Promises** — a mismatch is a defect of the program. **One check, not two**:
  a null handle and a wrong identity are the same kind of wrong.
- **Costs** — O(1). The `@require` compiles out in a fast build.
- **Contract** — `@param $Type : "the outer type asserted"` — `helper.c3:72`.
- **Contract** — `@require is_mine(h, $Type) : "the handle is not of this type"` — `helper.c3:73`.

## Inbound, from a Slot

### `macro from_slot(Slot* s, $Type)`

- **What** — the checking crossing from a Slot.
- **Promises** — the Slot is untouched either way. This is a look, not a take.
- **Costs** — O(1).
- **Contract** — `@param $Type : "the outer type expected"` — `helper.c3:84`.

### `macro must_from_slot(Slot* s, $Type)`

- **What** — the asserting crossing from a Slot.
- **Promises** — the Slot is untouched.
- **Costs** — O(1).
- **Contract** — `@param $Type : "the outer type asserted"` — `helper.c3:95`.

### `macro move_from_slot(Slot* s, $Type)`

- **What** — the moving crossing. The one member with two postconditions.
- **Promises** — on a match the typed pointer is returned **and** the Slot is
  cleared. On a mismatch null is returned **and** the Slot is untouched. Both
  halves are tested and neither is optional.
- **Costs** — O(1). The returned pointer is computed from the handle `peek`
  observed, not from `take()`'s return value.
- **Contract** — `@param $Type : "the outer type expected"` — `helper.c3:106`.

## The same crossings, as methods

**`Handle` is an alias for `Inner*`, so a method on `Inner` is reached through
a handle directly.** `to` and `as` are the two names `any` uses for these
operations, so a C3 reader already knows which is which.

### `macro Inner.to(&self, $Type)`

- **What** — the checking crossing, as a method. Forwards to `from_handle`.
- **Costs** — O(1).
- **Contract** — `@param $Type : "the outer type expected"` — `helper.c3:120`.

### `macro Inner.as(&self, $Type)`

- **What** — the asserting crossing, as a method.
- **Costs** — O(1).
- **Contract** — `@param $Type : "the outer type asserted"` — `helper.c3:127`.
- **Contract** — `@require is_mine((Handle)self, $Type) : "the handle is not of this type"` — `helper.c3:128`.

### `macro Slot.to(&self, $Type)`

- **What** — the checking Slot crossing, as a method. Forwards to `from_slot`.
- **Costs** — O(1).
- **Contract** — `@param $Type : "the outer type expected"` — `helper.c3:135`.

### `macro Slot.must(&self, $Type)`

- **What** — the asserting Slot crossing, as a method.
- **Costs** — O(1).
- **Contract** — `@param $Type : "the outer type asserted"` — `helper.c3:142`.

### `macro Slot.move(&self, $Type)`

- **What** — the moving Slot crossing, as a method.
- **Costs** — O(1).
- **Contract** — `@param $Type : "the outer type expected"` — `helper.c3:149`.

---

# `mtk::managed` — managed.c3

**`mtk::helper` plus a create and a release.** *Managed* means one thing: the
item keeps the allocator it was created with, so its release takes none.

**No type declares itself managed.** The distinction lives at the call site.
The one hard gate is at build time: `required_alloc_offset` refuses a type with
no `Allocator` field and names the helper it should have taken.

    struct Holder { int id; Inner node; Allocator alloc; }

    Slot s;
    mtk::managed::create(Holder, mem, &s)!;
    ...
    mtk::managed::release(Holder, &s);

### `macro void? create($Type, Allocator a, Slot* slot)`

- **What** — allocate an item and fill a Slot with it.
- **Promises** — it fills a Slot and does not return a pointer. On an
  allocation failure **the Slot is left untouched** and the fault is returned.
  The allocator is written into the item and kept for life. `helper::init` is
  called.
- **Costs** — one allocation, through `alloc::new_try`. The plain `alloc::new`
  aborts on failure and would leave the untouched-Slot promise no path to be
  true on.
- **Contract** — `@param $Type : "the outer type, which must carry an Allocator field"` — `managed.c3:22`.
- **Contract** — `@param a : "the allocator the item keeps for life"` — `managed.c3:23`.
- **Contract** — `@param slot : "an empty Slot, filled on success"` — `managed.c3:24`.
- **Checks** — `mtk::@check(slot.is_empty(), "an acquisition asserts the Slot is empty on entry")` — `managed.c3:30`.

### `macro void release($Type, Slot* slot)`

- **What** — free the item, with the allocator it kept.
- **Promises** — **no allocator parameter.** A no-op on an empty Slot, which is
  what makes the defer-before-acquire shape legal: the defer is registered
  before the acquisition and runs harmlessly on the failure path. The Slot is
  empty afterwards.
- **Costs** — one free.
- **Contract** — `@param $Type : "the outer type, which must carry an Allocator field"` — `managed.c3:44`.
- **Contract** — `@param slot : "the Slot holding the item; empty afterwards"` — `managed.c3:45`.

### `macro usz required_alloc_offset($Type)`

- **What** — the offset of the outer's `Allocator` field.
- **Promises** — the same declaration as `mtk::required_alloc_offset`, with the
  same message.
- **Costs** — compile time only.
- **Contract** — `@param $Type : "the outer type"` — `managed.c3:63`.
- **Checks** — `$assert $off >= 0 : "type " +++ $Type::name +++ " has no Allocator field; use mtk::helper instead of mtk::managed"` — `managed.c3:74`.

---

# `mtk::mailbox` — mailbox.c3

**A queue of items, with waiting. Many producers, many consumers, on one
object.**

**A mailbox is itself an item.** It embeds an inner, it has a type identity,
and it can travel through another mailbox or sit on a list.

**Two queues, not one.** Out-of-band items live in their own queue and every
take tries it first, so absolute priority with first-in first-out inside each
class falls out of the structure.

**The fields are reachable and are named with a leading underscore.** C3 0.8.3
hides neither a field nor a method. Reading them is a documentation problem
rather than a broken invariant.

**Usual flow.** `create`, then any number of `send` / `receive` calls from any
number of threads, then `close` with a queue to receive the remainder, then
`release`.

## Types and identity

### `struct Mailbox`

- **What** — the mailbox. Its members are the inner, a mutex, a condition
  variable, an allocator, the closed flag and its atomic twin, the two queues,
  and the wake generation.
- **Promises** — it repeats these members rather than embedding a shared base
  struct, because a shared base would put a second inner in the outer.

### `const typeid TYPE = Mailbox::typeid`

- **What** — the mailbox's type identity, under the name its callers use.
- **Costs** — a compile-time constant.

### `macro Handle to_handle(Mailbox* p)`

- **What** — from a mailbox to a handle. Forwards to `mtk::helper::to_handle`.
- **Promises** — cannot fail.
- **Costs** — O(1).

### `macro Mailbox* of(Handle h)`

- **What** — the checking crossing back.
- **Promises** — null when the handle names another type.
- **Costs** — O(1).

## Lifetime

### `fn Mailbox*? create(Allocator a)`

- **What** — create a mailbox on the heap.
- **Promises** — **creation is a transaction.** Each failure undoes exactly
  what succeeded before it, through `defer catch`. Nothing partially
  constructed is ever returned or observable. The allocator is kept for life.
- **Costs** — one allocation, a mutex init and a condition-variable init.
- **Contract** — `@param a : "the allocator the mailbox keeps for life"` — `mailbox.c3:66`.

### `fn void Mailbox.release(&self)`

- **What** — destroy the mutex and the condition variable, and free the
  mailbox.
- **Promises** — **the mailbox must be closed first, and this is the one
  precondition the toolkit refuses to soften.** It is `always_assert`: it
  aborts in every build mode, including `--safe=no -O3`. No allocator
  parameter.
- **Costs** — one free.
- **Checks** — `always_assert(self._closed, "releasing an open mailbox")` — `mailbox.c3:96`.

### `macro bool Mailbox.@closed_fast(&self)`

- **What** — the pre-lock acquire load of the closed flag.
- **Promises** — **nothing rests on it.** Every caller that gets `false` re-reads
  `_closed` under the lock, because close may run between the two.
- **Costs** — one atomic load, no mutex.

## Sending

### `fn void? Mailbox.send(&self, Slot* slot)`

- **What** — put an item on the ordinary queue.
- **Promises** — the Slot is the answer. On success it is cleared; on a closed
  mailbox it is untouched and the sender still has the item.
- **Costs** — O(1) under the mutex, plus one signal. An empty Slot is a defect
  checked at tier 2, with an early return behind it.
- **Contract** — `@param slot : "a full Slot; cleared on success, untouched on CLOSED"` — `mailbox.c3:158`.
- **Contract** — `@return? mtk::CLOSED` — `mailbox.c3:159`.
- **Checks** — `mtk::@check(slot.is_full(), "Mailbox.send from an empty Slot")` — `mailbox.c3:166`.

### `fn void? Mailbox.send_oob(&self, Slot* slot)`

- **What** — send ahead of every ordinary item.
- **Promises** — first-in first-out among out-of-band items themselves.
  **One priority level.** This is not a priority queue.
- **Costs** — as `send`. Both share `send_at`, and both share its check.
- **Contract** — `@param slot : "a full Slot; cleared on success, untouched on CLOSED"` — `mailbox.c3:158`.
- **Contract** — `@return? mtk::CLOSED` — `mailbox.c3:266`.

## Receiving

### `fn void? Mailbox.poll(&self, Slot* slot)`

- **What** — take an item if one is queued. **Never waits.**
- **Promises** — three outcomes: an item, `EMPTY`, or `CLOSED`. A receive with
  a zero timeout has the same reach; the two differ in how the empty case is
  reported, and a caller reading outcomes is entitled to the difference.
- **Costs** — O(1) under the mutex.
- **Contract** — `@param slot : "an empty Slot; filled on success"` — `mailbox.c3:214`.
- **Contract** — `@return? mtk::CLOSED, mtk::EMPTY` — `mailbox.c3:187`.
- **Checks** — `mtk::@check(slot.is_empty(), "an acquisition asserts the Slot is empty on entry")` — `mailbox.c3:222`.

### `fn void? Mailbox.receive(&self, Slot* slot, Duration timeout)`

- **What** — take an item, waiting up to a timeout.
- **Promises** — four outcomes: an item, `CLOSED`, `TIMEOUT`, or `WOKEN`. The
  deadline is anchored once, before the loop. A wakeup carries no meaning and
  the state is re-evaluated from scratch every turn. A waiter leaving on a
  timeout takes one last look, and signals if anything is still queued.
- **Costs** — blocks on the condition variable. There is no interruption: C3
  has no interruptible condition wait.
- **Contract** — `@param slot : "an empty Slot; filled on success"` — `mailbox.c3:214`.
- **Contract** — `@param timeout : "how long to wait"` — `mailbox.c3:215`.
- **Contract** — `@return? mtk::CLOSED, mtk::TIMEOUT, mtk::WOKEN` — `mailbox.c3:216`.
- **Checks** — `mtk::@check(slot.is_empty(), "an acquisition asserts the Slot is empty on entry")` — `mailbox.c3:222`.

### `fn void? Mailbox.receive_all(&self, InnerQueue* out)`

- **What** — take the whole batch at once.
- **Promises** — every queued item is moved onto `out`, in the order `receive`
  would have taken them: out-of-band first, then ordinary, first-in first-out
  within each. Releasing the items is the caller's work — what they are is
  knowledge the mailbox never had.
- **Costs** — two O(1) splices under the mutex.
- **Contract** — `@param out : "an empty queue; every queued item is moved onto it, in receive order"` — `mailbox.c3:265`.
- **Contract** — `@return? mtk::CLOSED` — `mailbox.c3:288`.

## Waking, closing, questions

### `fn void? Mailbox.wake_all(&self)`

- **What** — release every current waiter.
- **Promises** — each released waiter reports `WOKEN`. **The mailbox stays
  open.** The effect does not persist: a thread that starts waiting afterwards
  captures the new generation and is unaffected.
- **Costs** — one broadcast under the mutex.
- **Contract** — `@return? mtk::CLOSED` — `mailbox.c3:288`.

### `fn void Mailbox.close(&self, InnerQueue* out)`

- **What** — close the mailbox and give back what was left.
- **Promises** — **cannot fail.** Callable more than once; the second call
  takes nothing. Every remaining item is moved onto `out`, in receive order.
  Every waiter is released.
- **Costs** — two O(1) splices and one broadcast, under the mutex.
- **The named mistake** — discarding the queue this returns loses the items,
  and those items keep their links, so a later send refuses them. The refusal
  is exact, so the mistake surfaces at the first reuse.
- **Contract** — `@param out : "an empty queue; the remainder is moved onto it, in receive order"` — `mailbox.c3:311`.

### `fn bool Mailbox.is_closed(&self)`

- **What** — is it closed.
- **Promises** — a hint outside the lock, and honest under it.
- **Costs** — one atomic load, no mutex.

### `fn usz Mailbox.len(&self)`

- **What** — how many are queued, across both queues.
- **Promises** — **a hint, and stale by the time the caller reads it.**
- **Costs** — O(1) under the mutex.

---

# `mtk::pool` — pool.c3

**A keeper of reusable items, grouped by type identity.**

**Policy is not in the pool. Policy is in the hooks.**

**The pool's close gives nothing back to the caller.** Everything the pool
still held goes to the close hook. That is the mirror image of the mailbox's
close and the sharpest asymmetry in the toolkit.

**The identity set is fixed at creation and is not empty.** An identity outside
it is a defect of the caller: a checking build aborts, and a fast build reports
`UNKNOWN_IDENTITY`.

**There is no `put_all`.** A caller giving a batch back writes the loop itself:

    while (mtk::Handle h = batch.pop_front())
    {
        Slot s;
        s.fill(h);
        p.put(&s);
        if (s.is_full()) { batch.push_back(h); break; }   // refused
    }

**Usual flow.** `create` with the identity set and the hooks, then any number of
`get` / `put` calls from any number of threads, then `close`, then `release`.

## The hooks

### `interface PoolHooks`

- **What** — the three hooks, as a C3 interface. The implementing object is the
  context; there is no separate `ctx` parameter.
- **Promises** — **hooks run outside the pool's mutex, several at once on
  different threads.** This is a contract, not a warning.
- **Costs** — a hook that touches shared state protects it itself. **A hook does
  not call back into the pool, and does not block or wait.**

### `fn void PoolHooks.on_get(typeid want, usz in_pool, Slot* slot)`

- **What** — an item of a named identity was asked for and none was available.
- **Promises** — the Slot is empty on entry. Create one, or leave it empty to
  report failure; an empty Slot afterwards becomes `NOT_CREATED`. Returning an
  item of a different identity is a defect of the application, and the pool
  checks for it at tier 2.
- **Costs** — called with no lock held.
- **Contract** — `@param want : "the identity asked for"` — `pool.c3:48`.
- **Contract** — `@param in_pool : "how many of this identity remain, AFTER the removal. A hint, and stale"` — `pool.c3:49`.
- **Contract** — `@param slot : "empty on entry; fill it or leave it"` — `pool.c3:50`.

### `fn void PoolHooks.on_put(usz in_pool, Slot* slot, InnerQueue* extra)`

- **What** — an item is being given back.
- **Promises** — four outcomes and none mandated. Released with nothing kept:
  empty the Slot. Kept as it is, or kept after a reset: leave it full. Released
  with a different item put back: replace the contents. **A full Slot on return
  means one thing — an item is kept, original or replacement.**
- **Costs** — called with no lock held. Items added to `extra` are taken the
  same way, with the same checks: that is how a composite item gives its parts
  back.
- **Contract** — `@param in_pool : "how many of this identity are held, BEFORE the addition. A hint"` — `pool.c3:64`.
- **Contract** — `@param slot : "full on entry"` — `pool.c3:65`.
- **Contract** — `@param extra : "an empty queue; items added here are taken the same way, with the same checks"` — `pool.c3:66`.

### `fn void PoolHooks.on_close(InnerQueue* remaining)`

- **What** — the pool is going down.
- **Promises** — called with everything that remained, as one flat queue, and
  **the hook is responsible for processing or releasing every item in it.**
  Called outside the mutex, after the closed flag is already set.
- **Costs** — **called once by `close`, and possibly once more with
  stragglers** from a `put` whose hook was still running when the close fired.
  A hook writes the same loop either way, and **must not free its own context
  on the first call.**
- **Contract** — `@param remaining : "everything the pool still held, flattened across every identity. No order is promised"` — `pool.c3:80`.

## Types and identity

### `enum GetMode { AVAILABLE_OR_NEW, NEW_ONLY, AVAILABLE_ONLY }`

- **What** — the three modes of a plain get.
- **Promises** — `AVAILABLE_ONLY` is the only mode that can report
  `NOT_AVAILABLE`. `NEW_ONLY` never takes a stored item.

### `struct PoolBucket { typeid tag; InnerStack free; }`

- **What** — one free stack per identity.
- **Promises** — a stack, and the reason is defect surfacing: the item just
  given back is on top, so the next `get` passes it straight to a new user and
  a stale writer collides with that user immediately instead of much later.
- **Costs** — no count field beside it. `InnerStack.len` is O(1), and the hint
  given to a hook is read from it under the lock.

### `struct Pool`

- **What** — the pool. Its members are the inner, a mutex, a condition
  variable, an allocator, the closed flag and its atomic twin, the bucket
  slice, and the hooks.
- **Costs** — the buckets are a flat slice allocated once and scanned linearly.
  The set is small, fixed, and never grows, so a hash map would buy nothing.

### `const typeid TYPE = Pool::typeid`

- **What** — the pool's type identity, under the name its callers use.

### `macro Handle to_handle(Pool* p)`

- **What** — from a pool to a handle.
- **Promises** — cannot fail.
- **Costs** — O(1).

### `macro Pool* of(Handle h)`

- **What** — the checking crossing back.
- **Promises** — null when the handle names another type.
- **Costs** — O(1).

## Lifetime

### `fn Pool*? create(Allocator a, typeid[] tags, PoolHooks hooks)`

- **What** — create a pool on the heap.
- **Promises** — **the hooks are a parameter of creation and not a later
  step**: a pool cannot exist without them. The identity set is fixed here.
  **Creation is a transaction**: each failure undoes exactly what succeeded
  before it. Nothing partially constructed is ever returned or observable.
- **Costs** — two allocations — the pool and the bucket slice — plus a mutex
  init and a condition-variable init. **The duplicate scan is O(n²) and is
  compiled only where the tiers are live.** It runs before anything is
  allocated, so it needs no cleanup.
- **Contract** — `@param a : "the allocator the pool keeps for life"` — `pool.c3:159`.
- **Contract** — `@param tags : "the identities this pool holds. Not empty, and no duplicates — both checked"` — `pool.c3:160`.
- **Contract** — `@param hooks : "the policy"` — `pool.c3:161`.
- **Checks** — `mtk::@check(tags.len > 0, "the set of identities is not empty")` — `pool.c3:167`.
- **Checks** — `mtk::@check(hooks != null, "a pool cannot exist without hooks")` — `pool.c3:169`.
- **Checks** — `mtk::@check(t != u, "the pool's set of identities has a duplicate")` — `pool.c3:178`.

### `fn void Pool.release(&self)`

- **What** — destroy the mutex and the condition variable, and free the buckets
  and the pool.
- **Promises** — **the pool must be closed first.** `always_assert`, aborting
  in every build mode: releasing an open pool means the items it still held
  never reached the close hook.
- **Costs** — two frees.
- **Checks** — `always_assert(self._closed, "releasing an open pool")` — `pool.c3:215`.

### `macro bool Pool.@closed_fast(&self)`

- **What** — the pre-lock acquire load of the closed flag.
- **Promises** — the same rule as the mailbox: never without the re-check under
  the lock.
- **Costs** — one atomic load, no mutex.

## Getting

### `fn void? Pool.get(&self, typeid want, GetMode mode, Slot* slot)`

- **What** — take a stored item, or ask the hook for a new one.
- **Promises** — four faults: `CLOSED`, `NOT_AVAILABLE`, `NOT_CREATED`,
  `UNKNOWN_IDENTITY`. `NOT_AVAILABLE` comes only from `AVAILABLE_ONLY`, and
  `NOT_CREATED` only from a hook that produced nothing.
- **Costs** — O(n) in the number of identities for the bucket lookup, then
  O(1). **The hook runs outside the mutex**, and everything read before
  unlocking is stale when it returns.
- **Contract** — `@param want : "the identity wanted"` — `pool.c3:309`.
- **Contract** — `@param mode : "which of the three modes"` — `pool.c3:251`.
- **Contract** — `@param slot : "an empty Slot; filled on success"` — `pool.c3:310`.
- **Contract** — `@return? mtk::CLOSED, mtk::NOT_AVAILABLE, mtk::NOT_CREATED, mtk::UNKNOWN_IDENTITY` — `pool.c3:253`.
- **Checks** — `mtk::@check(slot.is_empty(), "an acquisition asserts the Slot is empty on entry")` — `pool.c3:318`.
- **Checks** — `mtk::@check(b != null, "Pool.get for an identity the pool was not created with")` — `pool.c3:268`.
- **Checks** — `mtk::@check(slot.peek().link.type == want, "the get hook returned an item of a different identity")` — `pool.c3:297`.

### `fn void? Pool.get_wait(&self, typeid want, Slot* slot, Duration timeout)`

- **What** — take a stored item, waiting up to a timeout.
- **Promises** — **it never creates.** No hook is called on this path. Where a
  plain get in `AVAILABLE_ONLY` mode reports `NOT_AVAILABLE`, this reports
  `TIMEOUT`, and the divergence is deliberate. Three faults: `CLOSED`,
  `TIMEOUT`, `UNKNOWN_IDENTITY`.
- **Costs** — blocks on the condition variable. The bucket lookup happens once,
  before the loop; the bucket slice is allocated once and never grown, moved or
  reallocated, so its address stays valid for the pool's whole life, and only
  its contents change under the lock.
- **Contract** — `@param want : "the identity wanted"` — `pool.c3:309`.
- **Contract** — `@param slot : "an empty Slot; filled on success"` — `pool.c3:310`.
- **Contract** — `@param timeout : "how long to wait"` — `pool.c3:311`.
- **Contract** — `@return? mtk::CLOSED, mtk::TIMEOUT, mtk::UNKNOWN_IDENTITY` — `pool.c3:312`.
- **Checks** — `mtk::@check(slot.is_empty(), "an acquisition asserts the Slot is empty on entry")` — `pool.c3:318`.
- **Checks** — `mtk::@check(b != null, "Pool.get_wait for an identity the pool was not created with")` — `pool.c3:327`.

## Putting

### `fn void Pool.put(&self, Slot* slot)`

- **What** — give an item back.
- **Promises** — **returns nothing. The Slot is the answer, not the outcome.**
  Cleared means the pool took it; unchanged means it was refused and the caller
  still has the item. **This path cannot fail and cannot be interrupted**: a
  worker that must give its item back must always be able to.
- **Costs** — O(n) in the number of identities for each bucket lookup.
  **The put hook runs outside the mutex, and the closed flag is re-read after
  it.** A close can run to completion inside that window; anything this call is
  still holding then goes to the close hook, and the caller's Slot stays
  cleared because the pool did take the item.
- **Contract** — `@param slot : "a full Slot; cleared if the pool took the item"` — `pool.c3:364`.
- **Checks** — `mtk::@check(b != null, "Pool.put of an identity the pool was not created with")` — `pool.c3:380`.
- **Checks** — `mtk::@check(b != null, "the put hook returned an identity the pool was not created with")` — `pool.c3:573`, reached through the private store path for both the Slot and each item of `extra`.

## Closing and questions

### `fn void Pool.close(&self)`

- **What** — close the pool and give everything it held to the close hook.
- **Promises** — **cannot fail. Nothing comes back to the caller.** Callable
  more than once: the second call takes nothing and does **not** run the hook
  again. The hook is called once, outside the mutex, after the flag is set.
  Every bucket is emptied into one queue, flattened; the hook never sees
  buckets or per-identity groups. **No order is promised.**
- **Costs** — O(n) in the items kept, once, on a pool going down. A stack keeps
  no tail, so the O(1) splice is not available. The loop repairs every item's
  self-link on the way, which a splice would have had to walk and do anyway.

### `fn bool Pool.is_closed(&self)`

- **What** — is it closed.
- **Costs** — one atomic load, no mutex.

### `fn usz Pool.count_of(&self, typeid t)`

- **What** — how many of one identity are held.
- **Promises** — **a hint, stale on return.** Zero for an identity the pool was
  not created with.
- **Costs** — O(n) in the number of identities, under the mutex.
