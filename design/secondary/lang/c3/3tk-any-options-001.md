# `any` within `Inner` — the option space, and the owner's ruling

**A seed note, not a stage output.** Written 2026-08-24 at the end of the
3TK-17 session, before a clear, so the next session starts from the ruling and
the measurements rather than re-deriving them.

The input was [3tk-any-revision.md](3tk-any-revision.md), the owner's document.
This note does not replace it. It records what that shape costs against the code
as it stands, the option the document did not consider, and **what the owner
ruled on 2026-08-24 after the argument.**

A companion file, `3tk-any-as-inner.md`, was **deleted by the owner** and is not
an input.

---

## The ruling, first

**`any` is rejected. The rename is accepted.**

```c3
struct Inner
{
    Inner* link;    // was: next
    typeid type;
}
```

That is the whole change. `Inner` stays two words, stays `Inner*` rather than
`any`, and one field is renamed. **Everything below is why**, and none of it
needs re-arguing.

---

## Where the port stands today

`inner.c3:49`:

```c3
struct Inner
{
    Inner* next;
    typeid type;
}
```

Two words. C3's builtin `any` is the same two words — `{ ptr, type }` — so the
question was never about layout.

The crossings, all in `helper.c3`, and the whole of what reads these fields:

- `is_mine` reads `h.type`.
- `init` writes `n.next = null`, `n.type = $Typeof(*item)::typeid`.
- `to_handle` is `(char*)item + mtk::inner_offset(…)`.
- `from_handle` and `must_from_handle` are `(char*)h - mtk::inner_offset($Type)`.

**Measured in `3tk/src/`: eight uses of `inner_offset`, seven of `.type`.**

Two constraints that survive, and should not be re-argued:

- **R6b, the self-link invariant.** An item on a chain has a non-null link; the
  last item of a chain points at itself; an item on no chain has a null link. It
  is what makes the link test exact, and an exact test is what deleted the O(n)
  membership walk — from this port and then from the specification, Part 8.6
  tombstoned, V4.
- **Part 4.2 permits every option here outright.** *The field count is the
  realization's, not the specification's* — V1. **No specification change is
  needed for any of this**, including the rename.

---

## Why `any` was rejected

### The arithmetic that settles it

There are exactly **two** facts an inner must store, and neither is derivable:

- **the link** — nothing else in the program knows what an item is threaded to;
- **the type** — Part 5.4, stored and not computed.

**This item's outer address is derivable**, in O(1), from the handle alone —
`(char*)h - inner_offset($Type)`, which is exactly what `must_from_handle`
already does. The handle *is* the inner's address.

A truthful `any` is a `{ptr, type}` pair where `ptr` points at a value **of that
type**. Here that would mean `{this-outer, type}`. So a truthful `any` would
have to **evict a non-derivable fact to store a derivable one.**

> **Therefore: in two words the pair is structurally never a valid `any`.** Not
> by choice, and not fixably. `ptr` must hold the link and `type` names the
> outer, so the two halves describe **different objects**.

That is arithmetic, not preference, and it is what closed the question.

### The three options, and what happened to each

| | `Inner` | `ptr` holds | Crossing | Size | Verdict |
|---|---|---|---|---|---|
| **A** | `any link;` | the link | offset arithmetic | 16 B | **rejected** — see below |
| **B** | `inline any link;` | the link | offset arithmetic | 16 B | **rejected** — D2 |
| **C** | `any link;` + `Inner* next;` | the outer | native `anycast`, no arithmetic | 24 B | **rejected** — owner |

**C — rejected by the owner, and on the better argument.** C is genuinely
attractive: `must_from_handle` becomes `(Msg*)link.ptr`, `anycast` becomes
correct natively, most of the eight `inner_offset` sites go, and Part 7.5's
promise — *the arithmetic appears in one file* — stops needing defending because
on the crossing path it stops existing. **It was rejected not on size but on
redundancy**: it spends a word storing an address the port already computes in
O(1) from a pointer it is holding. *"We can re-calculate outer address via
pointer within `any` — I know it's not a direct one."* Correct, and 8 bytes on
every item the application allocates is the wrong price for directness.

**B — rejected on D2.** `inline` licenses the implicit conversion of `Inner` to
`any`, which makes the invalid `anycast` reachable without naming the field.
`helper.c3`'s header states D2's reason in one line: *an implicit conversion is
a crossing that appears at no call site and in no file.* Part 7.5's auditability
is what would be spent. **The owner dropped `inline` in discussion**; B is
recorded so it is not re-derived, not because it was ever live.

*One question left unmeasured, should B ever return:* whether `inline` promotes
**methods** as well as members. `helper.c3` defines `Inner.to` and `Inner.as`;
the stdlib defines `any.to` and `any.as`, and they mean opposite things on the
same receiver. **One `c3c` measurement, not an argument.**

**A — rejected as a net loss in clarity.** A buys nothing semantically: not one
builtin operation becomes available, because `anycast`, `any.to` and `any.as`
are all *wrong* on a pair whose halves describe different objects — and `.to`
and `.as` are worse than wrong, they dereference and copy. What is left is
spelling. And the spelling misleads: `Inner* next` is typed, so no reader can
mistake what it points at, whereas `any link` **looks** like a value-carrying
`any` to every C3 reader who knows the type, when it structurally cannot be one.
It creates the wrong inference and then needs a comment to undo it.

**The document's aim survives the rejection.** *"It makes the unusual meaning of
the builtin `any` visible"* — the two-part structure of Part 4.2 is worth making
visible, and the rename below is what does it, without borrowing a type whose
contract the port cannot keep.

---

## Why the rename was accepted

**`next` makes a claim the field does not keep.** Under R6b the last item of a
chain **points at itself** — so on that item `next` is not the next thing, it is
the same thing. `inner.c3:45` already confesses this in the port's own words:

> The price, stated plainly: `next` carries two meanings, and a walk that
> forgets to test `n.next == n` loops forever rather than ending.

The rename does not remove the two meanings — nothing can, that is R6b's
bargain. **It stops the name asserting the wrong one.** `link` stays true on the
last item, on an unlinked item, and everywhere between. `next` is true on all
but the ends, which are exactly the cases a careless walk gets wrong.

**And `link` is the specification's own word.** Part 4.2 names the two parts
**Linkage** and **Identity**, and 004's *3tk* realization line reads *one link
field plus the identity*. After the rename the code stops being the only place
that calls it something else, and `link` / `type` corresponds straight across.

---

## The cost, measured

**59 mentions of `next` across 14 files. 35 are field accesses (`.next`)** —
mechanical, and every one compiler-checked.

| Where | mentions |
|---|---|
| `src/queue.c3` | 13 |
| `src/inner.c3` | 9 |
| `src/stack.c3` | 5 |
| `src/helper.c3`, `mailbox.c3`, `managed.c3`, `pool.c3` | 1 each |
| `test/t_queue.c3` | 14 |
| `test/t_stack.c3` | 4 |
| `test/t_pool.c3` | 3 |
| `test/t_alloc.c3`, `t_identity.c3` | 2 each |
| `test/t_managed.c3` | 1 |
| `negative/insert_twice_same_queue.c3` | 2 |

**The remaining ~24 are prose, and they are the real work.** About half are the
R6b paragraphs in `inner.c3` that *argue about the name itself* — `inner.c3:34`,
`:45`, `:164` — and want rewording, not substitution. A paragraph explaining why
`next` carries two meanings reads differently once the field is called `link`,
and the confession above becomes **an argument for the new name** rather than an
apology for the old one.

**The trap: `queue.c3` and `stack.c3` hold 18 of the 35 field accesses, and the
four walk sites each state the end test in their own body.** That is where a
careless mechanical pass leaves a comment disagreeing with its code. **Rewrite
the exemplar first, then sweep** — the folder's own rule.

`is_linked` and `unlink` in `inner.c3` read *better* after: `h.link != null` is
the sentence their doc comments already use.

---

## What this is not

- **No specification change.** Part 4.2/V1 already leaves the field count to the
  realization, and 004's *3tk* line already says *link field*. **Nothing in
  `../common/` is touched**, and 004 stands as cut.
- **No layout change.** Two words before, two words after.
- **No behaviour change.** R6b, the exact link test, Part 8.6's deletion and
  every invariant are untouched. **The test suite should pass unchanged** — 63
  checks, four builds — and that is the stage's own verification.

---

## Advice on the stage

**This is a code stage, and it is small but not mechanical.** It ends green, not
at a ruling — the ruling is above.

Plan 009 is spent: 3TK-0 to 3TK-17 have all run. **Plan 010 declares this one**,
and it can now be written, because the decision it carries exists.

Three things already owed, unrelated to this, and each still wanting a stage the
owner names — carried from 3TK-17's report so they are not lost:

1. **Three doc comments in `3tk/src/` still cite specification 003** —
   `mtk.c3:48`, `inner.c3:5`, and `helper.c3:51`, whose guard telling the reader
   not to "fix" the file to match Part 7.1 **is stale now that 004 has reworded
   it.** `inner.c3` is touched by this rename anyway, which makes it the cheap
   moment to take at least that one.
2. **`3tk-deviations-001.md`'s P2 row is stale** — 3TK-15's finding.
3. **otk has never been told the portable specification exists.**
