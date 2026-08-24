# 3tk — the helper surface, re-thought (proposal 001)

Output of **3TK-14**, 2026-08-24. Declared in
[3tk-staging-plan-008.md](backup/3tk-staging-plan-008.md), started on the owner's line.

**This is a proposal. No file under `3tk/` was changed.** `run-builds.sh`
reports *passed 59, failed 0, all four builds green*; `run-sanitizers.sh`
reports *passed 3, failed 0, sanitizers clean, 85 tests*. Both were run at the
end of this stage, and both are green trivially, because nothing was touched.

The input is [3tk-helper-alternatives.md](3tk-helper-alternatives.md), from the
owner. **It is advice, not a ruling.** It contradicts itself on purpose: the
design its *My ranking* section calls its clear favourite is withdrawn by its
own *Important correction*. Both halves were tested with the compiler, and the
correction is right.

**A second input arrived mid-stage**, also from the owner: read
`std::collections::interfacelist`, `std::collections::anylist` *and another
sources in std*. It was the right advice and it changed the recommendation.
Part A2 is what the stdlib said, and **H0 is what this stage now proposes**;
H1 to H3, measured before that, are the best shape available without macros and
stand as the alternative.

Every item below is numbered and stands alone. **H0, H0b and H1 to H10 are
accept-or-reject, one at a time.**

**Ruled by the owner on 2026-08-24: H0 and H1 to H9 as marked in place** — H0
and H0b accepted, **H5 accepted**, H1 to H3 withdrawn, H4, H6, H8 and H9 settled
by H0, H7 taken as recommended, **H10 accepted** — `mtk::owned` becomes
`mtk::managed` and the fixture becomes `struct Holder`. **Every H item is now
ruled.** Two consequences of accepting H0 — **E6 and E7 in Part E — are still
unruled**, and E6 decides whether the code stage also writes a deviation row.

---

# Part A — What the compiler said

Every claim about C3 in this document is a program that was compiled by
`/usr/bin/c3c`, version **0.8.3**, LLVM 22.1.8, on this machine, with its
output quoted. The scratch directory is outside `3tk/` and is no part of the
port; `run-builds.sh` never sees it.

Where a claim is *not* backed by a run, it is marked **opinion** in place.

## M1 — A generic module cannot declare a method on its own type parameter

The note's first and favourite design. Source:

```c3
module probe::helper <Type>;
import probe;

const usz OFF = 8;
const typeid TYPE = Type::typeid;

fn void Type.init(Type* self)
{
    Node* n = (Node*)((char*)self + OFF);
    n.next = null;
    n.type = TYPE;
}
```

Command: `c3c compile helper.c3 main.c3 -o p1b`

```
 7: fn void Type.init(Type* self)
            ^^^^
(helper.c3:7:9) Error: 'Type' could not be found, did you spell it right?
```

The same error with `fn void Type.init(&self)`, and the same error with the
generic module and the application in one file. The method's receiver name is
resolved as an ordinary type name and the module's type parameter is not one.

**The note's own correction is confirmed.** `msg.init()` and
`Msg.from_handle(h)` are not available in C3 0.8.3, and the ranking that puts
them first is ranking something that does not compile.

## M2 — An instantiated generic module cannot be aliased as a namespace

The note's second design, the one its correction falls back to. Four spellings
were tried. Source of the first:

```c3
alias MsgHelper = probe::helper{Msg};
```

```
 5: alias MsgHelper = probe::helper{Msg};
                      ^^^^^^^^^^^^^
(main.c3:5:19) Error: 'probe::helper' could not be found, did you spell it right?
```

| Spelling | Diagnostic |
|---|---|
| `alias MsgHelper = probe::helper{Msg};` | `'probe::helper' could not be found, did you spell it right?` |
| `alias MsgHelper = probe::helper;` | `'probe::helper' could not be found, did you spell it right?` |
| `alias MsgHelper = probe::helper{Msg}::;` | `Expected ';'` |
| `import probe::helper{Msg};` | `Expected ';'` |

**A generic module is not a value and not a type.** It cannot be named except
through one of its declarations. `mtk::helper{Msg}` names nothing;
`mtk::helper::init{Msg}` names a function. That is the whole of why
`test/common.c3` looks the way it does, and no amount of alias discipline fixes
it.

**Both of the note's proposals are unavailable.** Its fallback — many aliases —
is what the port already has.

## M3 — But a *generic type declared inside* the generic module can be aliased

This is not in the note. It is the shape that survives M1 and M2.

A generic module may declare a struct, and that struct is generic over the
module's parameter. Methods may be declared on **it** — it is a concrete named
type at the point of declaration — and their bodies see `Type` normally.

```c3
module probe::helper <Type>;
struct Helper { char unused; }
const Helper OF = {};
fn void Helper.init(self, Type* item) { ... }
```

One alias per outer type, to the constant:

```c3
alias MSG = probe::helper::OF{Msg};
```

```
Program linked to executable './p4'.
is_mine=true roundtrip=true
```

Two constraints the compiler imposed, both worked around and both worth
recording:

- `struct Helper { }` — `Error: Zero sized structs are not permitted.` One
  unused byte is the price. It is a compile-time-only value; no item carries it.
- `struct H { ... }` — `Error: Names of structs cannot be all uppercase.`

## M4 — The alias must be ALL-CAPS, because it aliases a constant

```
 5: alias msg = probe::helper::OF{Msg};
(m3.c3:5:13) Error: An alias starting with a lowercase letter is expected to
alias a non-constant. If you want to alias a constant, make sure the alias name
is all uppercase letters.

 5: alias Msg_h = probe::helper::OF{Msg};
(m4.c3:5:7) Error: An upper-case alias must always alias a type.
```

So the call site is `MSG.init(&m)`, not `msg.init(&m)` and not
`MsgHelper.init(&m)`. **This is the one aesthetic cost of M3 and it is not
negotiable in 0.8.3.** The alternative — aliasing the *type* `Helper{Msg}` and
declaring a `const` of it — spends two lines to reach the same all-caps name.

## M5 — The whole of Part 7.2 works in this shape, against the real `src/`

`3tk/src/` was copied to scratch, `helper.c3` and `owned.c3` were rewritten to
the M3 shape, and `mailbox.c3` and `pool.c3` were repointed. **Zero errors.**

A behavioural proof was then written over the four test fixtures — `Msg`,
`Job`, `Twin`, `Owned`:

```
identity distinct        : true
to_handle/from_handle    : true
from_handle wrong type   : true
from_handle null         : true
must_from_handle         : true
is_mine yes/no           : true
Job inner at offset zero : true
from_slot, slot untouched: true
must_from_slot           : true
move mismatch: nothing   : true
move mismatch: untouched : true
move match: got item     : true
move match: slot cleared : true
owned create fills slot  : true
owned kept its allocator : true
owned release empties    : true
```

Sixteen lines, all true, including both postconditions of the moving crossing
on both paths — Part 7.2's one member with two of them. The same program
compiled and ran identically under `-O3 --safe=no`, so the tier-2 `@check`
still compiles out.

## M6 — `@private` on `OFF` really does close it, and composition survives

With `const usz OFF @private`, from another module:

```
 2: alias MSG_OFF = probe::helper::OFF{Msg};
                    ^^^^^^^^^^^^^^^^^^
(probe_priv.c3:2:17) Error: 'probe::helper::OFF' could not be found, did you
spell it right?
```

And `mtk::owned` — a *different* generic module — still composes the helper,
because it reaches it through the instance and not through the constant:

```c3
mtk::helper::OF{Type}.init(item);
slot.fill(mtk::helper::OF{Type}.to_handle(item));
```

That compiled and ran (M5's last three lines).

## M7 — Part 7.4's build-time validation survives the private `OFF`

The concern: if nothing public names `OFF`, does instantiating `OF` still force
`mtk::inner_offset` to run and its `$assert` to fire? It does.

```
(main.c3:15:13) Error: type NotAnItem has no Inner field; it cannot be a
Matryoshka item
 3: const usz OFF @private = probe::inner_offset(Type);
                             ^^^^^^^^^^^^^^^^^^^^^^^^^
(helper.c3:3:26) Note: Inlined from here.
```

And against the real `owned.c3`, for a type with no `Allocator`:

```
(inner.c3:274:13) Error: type Plain has no Allocator field; use mtk::helper
instead of mtk::owned
(owned.c3:7:27) Note: Inlined from here.
```

The message still names the offending type, and it still contains the literal
`mtk::helper` that `run-builds.sh:71` greps for. **The three `nocompile_*`
negative tests survive the change**, with their alias lines repointed.

## M8 — Hiding `OFF` is a speed bump, not a border

This is the measurement that decides H3, and it cuts against the note.

`mtk::inner_offset` is **public**, at `src/inner.c3:238`, and application code
can call it today:

```c3
module reachprobe;
import mtk;
struct Msg { int id; Inner node; }
fn Msg* by_hand(Handle h) => (Msg*)((char*)h - mtk::inner_offset(Msg));
```

**That compiles. Zero errors.** So the arithmetic Part 7.5 confines is already
one public macro call away, with or without `helper::OFF`.

And it cannot simply be closed, because `mtk::helper` is a *submodule* and C3's
`@private` is module-scoped, not tree-scoped — the same property
`run-builds.sh` already checks and relies on for `mailbox.c3` and `pool.c3`:

```
(helper.c3:4:26) Error: The macro 'mtk::inner_offset' is '@private' and not
visible from other modules.
```

**`inner_offset` must stay public for the helper to exist at all.** Part 7.5's
MUST is therefore held by convention, review and the layering checks — not by
visibility — and it always was. That is worth saying out loud once.

---

# Part A2 — What the C3 standard library already does

Added after the owner pointed at `std::collections::interfacelist`,
`std::collections::anylist` **and "another sources in std"**. The advice was
right and it moves the recommendation: **the stdlib solves this exact problem,
and not with a helper object.**

Same compiler, same machine, same rule — every claim is a program that ran.

## M9 — The stdlib's own answer to Part 6.3 is a macro taking `$Type`

C3's core carries the checking and asserting crossings already, for its own
type-erased value. `core/builtin.c3:111-134`:

```c3
macro anycast(any v, $Type) @builtin
{
	if (v.type != $Type) return TYPE_MISMATCH~;
	return ($Type*)v.ptr;
}

<*
  @return? TYPE_MISMATCH
*>
macro any.to(self, $Type)
{
	if (self.type != $Type) return TYPE_MISMATCH~;
	return *($Type*)self.ptr;
}

<*
 @require self.type == $Type : "The 'any' contained an unexpected type."
*>
macro any.as(self, $Type)
{
	return *($Type*)self.ptr;
}
```

Read that against Part 6.3 and Part 7.2. It is the same design:

- `v.type != $Type` — a stored `typeid` field compared against a type name.
  **That is `is_mine`.**
- `.to()` — the **checking** crossing.
- `.as()` — the **asserting** crossing, expressed as a `@require` contract.
- The type is named **at the call site**, as an argument. **There is no
  per-type instantiation, no generic module, and no alias.**

*3tk's `Handle` and C3's `any` are not the same thing and this is not a proposal
to use `any`.* An `any` is a fat pointer — pointer plus `typeid`, two words —
and Part 4.2 puts the identity in the inner precisely so a handle stays one
word. What transfers is the **surface**, not the representation.

## M10 — `interfacelist` confirms the H1 shape is the stdlib's idiom too

`collections/interfacelist.c3:7-29`: a generic module declaring a struct with
methods on it, and `collections/anylist.c3:21` naming one instantiation:

```c3
module std::collections::interfacelist <Type>;
struct InterfaceList (Printable) { ... }
fn InterfaceList* InterfaceList.init(&self, Allocator allocator, ...)
```
```c3
typedef AnyList = inline InterfaceList {any};
fn any? AnyList.first_any(&self) @inline => InterfaceList {any}.first(self);
```

So **H1 is not an invention** — a generic struct inside a generic module is how
the stdlib writes this, and `InterfaceList {any}.first(self)` shows a method
called on an instantiated generic type with an explicit receiver. `typedef X =
inline Generic{T}` appears three times in the stdlib (`anylist.c3:21`,
`priorityqueue.c3:26-27`) and is its way of naming one instantiation.

**But the stdlib reaches for that shape for a *container*, which has state, and
for the crossings it reaches for macros.** The helper has no state. That is the
whole argument of H0 below.

## M11 — The macro surface compiles, and needs no alias at all

Part 7.2's members as macros in a plain (non-generic) `mtk::helper`:

```c3
macro bool is_mine(Handle h, $Type) => h != null && h.type == $Type;

<* @require $defined($Typeof(*item)::members) : "not a struct that embeds an Inner" *>
macro Handle to_handle(item)
    => item ? (Handle)((char*)item + mtk::inner_offset($Typeof(*item))) : null;

macro from_handle(Handle h, $Type)
    => is_mine(h, $Type) ? ($Type*)((char*)h - mtk::inner_offset($Type)) : null;

<* @require is_mine(h, $Type) : "the handle is not of this type" *>
macro must_from_handle(Handle h, $Type) => ($Type*)((char*)h - mtk::inner_offset($Type));

macro move_from_slot(Slot* s, $Type)
{
    Handle h = s.peek();
    if (!is_mine(h, $Type)) return ($Type*)null;
    s.take();
    return ($Type*)((char*)h - mtk::inner_offset($Type));
}
```

`init` and `to_handle` need no type argument at all — `$Typeof(*item)` infers
it. Only the *inbound* crossings need a type named, and that is not ceremony:
a crossing from an erased handle must say what it expects.

## M12 — And as methods on `Handle` and `Slot`, in C3's own `to`/`as` names

```c3
macro Inner.to(&self, $Type) => from_handle((Handle)self, $Type);

<* @require is_mine((Handle)self, $Type) : "the handle is not of this type" *>
macro Inner.as(&self, $Type) => ($Type*)((char*)self - mtk::inner_offset($Type));

macro Slot.to(&self, $Type)   => from_slot(self, $Type);
macro Slot.must(&self, $Type) => must_from_slot(self, $Type);
macro Slot.move(&self, $Type) => move_from_slot(self, $Type);
```

`Handle` is `alias Handle = Inner*` (`src/inner.c3:59`), so a method on `Inner`
taking `&self` is reached through a handle directly. The call site:

```c3
Msg m;
mtk::helper::init(&m);
Handle h = mtk::helper::to_handle(&m);

Msg* p = h.to(Msg);        // checking
Msg* q = h.as(Msg);        // asserting
Msg* a = s.to(Msg);        // checking, from a Slot
Msg* b = s.must(Msg);      // asserting, from a Slot
Msg* c = s.move(Msg);      // moving
```

**Zero aliases. Not one, for any type, anywhere.** And `to`/`as` are not
invented — they are the names `any` uses for these two operations, so a C3
reader already knows which is which.

## M13 — Measured against the real `src/`, containers and all

`3tk/src/` was copied to scratch and `helper.c3` and `owned.c3` were rewritten
as above; `mailbox.c3` and `pool.c3` were repointed and their **eight file-local
alias lines deleted outright** (`mailbox.c3:74-77`, `pool.c3:169-172`), `TYPE`
becoming `const typeid TYPE = Mailbox::typeid;`.

**Zero errors.** The behavioural proof — over `Msg`, `Job`, `Twin`, `Owned`, and
a live mailbox round trip — with **no `alias` line in the test file at all**:

```
identity distinct        : true
to_handle/from_handle    : true
from_handle wrong type   : true
from_handle null         : true
must_from_handle         : true
is_mine yes/no           : true
Job inner at offset zero : true
from_slot, slot untouched: true
must_from_slot           : true
move mismatch: nothing   : true
move mismatch: untouched : true
move match: got item     : true
move match: slot cleared : true
owned create fills slot  : true
owned item recovered     : true
owned release empties    : true
mailbox round trip       : true
```

Seventeen, all true, and identical under `-O3 --safe=no`.

## M14 — `@require` is the port's tier 2, natively, with a better diagnostic

The asserting crossing as a `@require` contract, in a safe build:

```
ERROR: '@require "is_mine(h, $Type)" violated: 'the handle is not of this type'.'
  in must_from_handle (mtk.c3:11) [./tq]
  in main (t.c3:11) [./tq] [inline]
```

Under `-O3 --safe=no` the same program runs to completion and returns 0. **That
is exactly D6's tier 2 and Part 15.5's contract violation**, obtained from the
language rather than from `mtk::@check`, and it names the *caller's* line as
well as the helper's.

A macro is untyped at its boundary, and that is the shape's real cost. It is
repairable with the same mechanism, and the stdlib does this everywhere
(`enumset.c3:6`, `complex.c3:16`, `range.c3:2`, `hashset.c3:2`). Passing an
`int*`:

```
(n3.c3:3:34) Error: @require "$defined($Typeof(*item)::members)" violated:
'not a struct that embeds an Inner'.
```

The error is at **the caller's line**, in the port's own words.

**A correction, recorded because the stage got it wrong once.** The first
version of that guard was spelled `$Typeof(*item).members`, with a dot. It
compiled, and it rejected *every* type including valid ones — a guard that
always fires reads exactly like a guard that works, if you only run the negative
case. `$Type::members` takes a double colon. Both directions are verified above.

## M15 — Part 7.4's validation survives, and still names the type

With no per-type instantiation, `mtk::inner_offset($Type)` runs at each use
rather than once per helper:

```
(mtk.c3:20:13) Error: type NotAnItem has no Inner field; it cannot be a
Matryoshka item
```

The three `nocompile_*` negative tests keep working; their `alias bad = ...`
line becomes a one-line function body that crosses. **The one real change: a
type that is declared but never crossed with is never validated.** Today the
alias validates it at declaration. That is a small loss and it is named here
rather than buried.

---

# Part B0 — The surface this stage now recommends

## H0 — The helper becomes macros. No alias, for any type, ever

> **ACCEPTED by the owner, 2026-08-24.** H1 and H2 are withdrawn; H3 is moot.
> The code stage that carries it has not been named.

`mtk::helper` stops being a generic module and becomes an ordinary one carrying
Part 7.2's members as macros over `$Type`, plus the `to`/`as`/`must`/`move`
methods of M12 on `Handle` and `Slot`. Measured in M11, M12, M13, M14, M15.

**Why this and not H1.** The stdlib settles it. C3 has a type-erased value with
a stored identity and two crossings, and it does **not** generate a helper
object per type for them — `anycast`, `any.to`, `any.as` are macros that take
the type at the call site (M9). The stdlib reaches for the generic-struct shape
for *containers*, which have state (M10). **The helper has no state.** Its
`Helper` struct under H1 exists only to hang methods on, carries one unused
byte, and forces an ALL-CAPS alias per type because C3 will not let a constant
be aliased any other way (M4).

**What the reader gains.** `h.to(Msg)` and `h.as(Msg)` say checking and
asserting in the two words a C3 reader has already learned from `any`. Part
6.3's *named apart so a reader sees at the call site which one is meant* is
satisfied by the language's own vocabulary rather than by this port's.

**What it costs, stated plainly.**

1. **Part 7.1's literal words stop describing the port.** *"For each outer type
   there is a helper bound to that one type. The helper is generated at compile
   time from the type."* Under H0 there is no per-type helper object; the code
   is generated per **call site**. Part 7.1 is a SHOULD and its own next line
   says *the shape is fixed, generation is the convenience* — every member of
   7.2 is present and every crossing is still in one file — but the sentence no
   longer reads true, and **this stage will not decide that.** See E6.
2. **Macros are untyped at the boundary.** Repaired with `@require` guards, and
   the repair is the stdlib's own habit — M14.
3. **A declared-but-unused type is no longer validated** — M15.
4. **The moving crossing needs `return ($Type*)null`**, because a macro's return
   type is inferred and a bare `null` gives it nothing to infer from. One cast,
   in one place, in the port.

## H0b — `mtk::owned` follows, and this one touches D10

> **ACCEPTED by the owner, 2026-08-24**, together with H0. **This carries D10's
> spelling with it** — two generic modules become two modules — and it carries
> E6 and E7, which are consequences and are still unruled.

Measured in M13.

```c3
macro void? create($Type, Allocator a, Slot* slot)
macro void release($Type, Slot* slot)
```

```c3
mtk::owned::create(Owned, mem, &s)!;
mtk::owned::release(Owned, &s);
```

`release` gains a type argument it does not have today. That is a real
signature change and it is an improvement at the call site: releasing is a typed
operation and the current `owned_release(&s)` hides which type's allocator is
about to be read.

**But it moves D10's words, and the stage will not move them.** D10 rules *two
generic modules, `mtk::helper` and `mtk::owned`*. Under H0b they are two
modules, not generic ones. Part 7.3 allows the distinction to be made *"by any
means its language offers: two generators, an interface, a flag, a separate
name"* — two separate names is on that list, so the **rule** is satisfied and
only the **ruling's spelling** moves.

There is a sharper edge underneath, and it is named because it is the sort of
thing that is discovered too late. Today `mtk::owned{Type}` is an
instantiation, so *the type declares* that it is an owning type. Under H0b any
caller may invoke `mtk::owned::create` on any type that happens to have an
`Allocator` field. Part 7.3's *distinction* survives at the call site but stops
being a property of the type. **That is a question for the owner, not an answer
from this stage.**

---

# Part B — The proposed surface, if H0 is rejected — **WITHDRAWN**

> **H0 was accepted, so H1, H2 and H3 are withdrawn and need no ruling.** They
> are kept in place, unedited, because they are the record of what was measured
> before Part A2 existed and of what the port would have looked like without
> macros. Nothing below this heading is a live question.

**H1 to H3 were the best shape available without macros.** They stand exactly as
written and were measured before Part A2 existed. **H4 to H9 are independent of
the choice** and apply to either surface.

## H1 — The helper becomes a per-type instance; one alias replaces nine

> **WITHDRAWN — superseded by H0, accepted 2026-08-24.**

`mtk::helper` gains a `Helper` struct and a `const Helper OF`, and its eight
functions become methods on `Helper`. An application writes **one** line per
outer type:

```c3
alias MSG = mtk::helper::OF{Msg};
```

and then:

```c3
Msg m;
MSG.init(&m);
Handle h = MSG.to_handle(&m);

Msg* p = MSG.from_handle(h);
Msg* q = MSG.must_from_handle(h);
Msg* a = MSG.from_slot(&s);
Msg* b = MSG.must_from_slot(&s);
Msg* c = MSG.move_from_slot(&s);

if (MSG.is_mine(h)) { ... }
```

Measured in M3 and M5. `self` is taken **by value** — the struct is one unused
byte, the methods never read it, and by-value spares every call site the
address of a constant.

**What it is not.** It is not the note's favourite (M1 refuses it) and not the
note's fallback (M2 refuses it). It is the nearest shape C3 0.8.3 actually has,
and it delivers the property the note was after: *one declaration instead of
eight*, with the helper boundary still visible at every call site.

**What it costs.** The all-caps alias of M4, and one unused byte in a
compile-time constant.

## H2 — `mtk::owned` takes the same shape

> **WITHDRAWN — superseded by H0b, accepted 2026-08-24.**

Depends on H1.

`mtk::owned` gains `struct Owner` and `const Owner OF`, and `create` and
`release` become methods. It composes the helper through the instance, so D10's
ruling — *two generic modules, `owned` composing `helper` rather than copying
it* — is unchanged and is if anything better served: `owned` no longer needs to
re-declare `OFF`.

```c3
alias OWNER = mtk::owned::OF{Owned};
OWNER.create(mem, &s)!;
OWNER.release(&s);
```

Measured in M5 and M6. **This is the answer to the stage's `owned` question,
and it is not a reopening of D10.** Two modules stay two modules.

**One deletion falls out.** `src/owned.c3:30` declares
`const usz OFF = mtk::helper::OFF{Type};` and **nothing in the file ever reads
it** — `create` and `release` use `AOFF` (`owned.c3:62`, `owned.c3:82`) and
otherwise go through the helper. It is dead, today, before any of this.

## H3 — `OFF` becomes `@private`

> **MOOT — H0 leaves no `OFF` to export.** The macros call `mtk::inner_offset`
> directly and there is no per-type instantiation to carry a constant. **M8's
> finding survives and is the part that matters**: `mtk::inner_offset` is public
> and cannot be closed, so Part 7.5's MUST is held by convention and the
> layering checks, not by visibility. That sentence belongs in the new
> `helper.c3`'s doc comment.

Depends on H1.

The note's argument is that exporting `OFF` hands application code the
arithmetic Part 7.5 confines to the helper. That argument is **correct in
direction and overstated in effect**, and M8 is why: `mtk::inner_offset` is
public and cannot be closed, so the door stays open either way.

Accept it anyway, on a narrower claim: it removes two alias lines that exist
only to let a test assert a layout fact, and it makes `helper.c3` the only file
in the port that names an offset. **State the limit in the doc comment** so the
next reader does not believe visibility is doing work it is not doing.

Costs two call sites — see H9.

## H4 — `TYPE` stays public. The note is wrong here

> **SETTLED BY H0 — no separate ruling needed.** Under H0 the port re-exports
> no identity at all: an application writes `Owned::typeid`, in the language.
> The note's proposal — hide it — is refused either way, and the evidence below
> is why. It is kept because it is the reason the 46 `OWNED_TYPE` call sites
> become `Owned::typeid` rather than disappearing.

The note recommends keeping `TYPE` private, on the argument that `is_mine(h)`
is the public form of the test. **That is true for the crossing and false for
the port**, because the identity is not only a crossing predicate — it is the
pool's key.

Evidence, from the port's own public signatures:

```
src/pool.c3:194   fn Pool*? create(Allocator a, typeid[] tags, PoolHooks hooks)
src/pool.c3:289   fn void? Pool.get(&self, typeid want, GetMode mode, Slot* slot)
src/pool.c3:351   fn void? Pool.get_wait(&self, typeid want, Slot* slot, Duration timeout)
src/pool.c3:571   fn usz Pool.count_of(&self, typeid t)
src/pool.c3:72    fn void on_get(typeid want, usz in_pool, Slot* slot);
```

Part 11.7 keys the pool on the identity, and every one of those is application
API. `OWNED_TYPE` alone is read at **46 call sites** across `test/`, and
`MSG_TYPE` and `JOB_TYPE` are what `negative/duplicate_pool_tags.c3:27` and
`negative/release_open_pool.c3:15` are built from. An application that cannot
name its own type's identity cannot create a pool.

Part 7.2's first member is *the type identity value*. It is a MUST, and it is a
value, not a predicate. **`TYPE` is public and stays public.**

## H5 — `to_inner`/`from_inner` become `to_handle`/`from_handle`

> **ACCEPTED by the owner, 2026-08-24.** The member names are
> `to_handle` / `from_handle` / `must_from_handle`, and `is_mine`. The
> `to`/`as`/`must`/`move` methods on `Handle` and `Slot` are unaffected — they
> are C3's own names and never depended on this ruling.
>
> **M11 to M13 were re-run under the accepted spelling** rather than edited, so
> every quoted line in this document is still output from a program that ran.
> **The measured spelling was `handle_of` and it was wrong** — see *The
> correction* below.

### The evidence, and it is one line

**R1 did not choose `inner` over `handle`. It chose a direction prefix.** The
R1 rename table, `3tk-core-redesign-proposal-002.md:174` and `:182`:

```
| `AnyHandle`           | **`Handle`**   | Still a transparent alias for `Inner*`. D4 stands |
| `mtk::helper::to_any` | **`to_inner`** | An inherited name, and it now says the direction  |
```

The stated reason for `to_inner` is *"it now says the direction"* — the `to_`
prefix, not the noun. **And the same pass, in the same table, kept the word
*handle* for the type.** The noun was picked mechanically to match `Inner`
while de-`Any`-ing the port; `inner` against `handle` was never the question
being asked that day.

**So H5 does not reverse R1. It finishes it.** It keeps the direction prefix R1
valued and corrects the noun to match the type the signature already declares.
The one real objection — *this was ruled the day before* — does not survive
reading what was actually ruled.

### What it fixes

`to_inner` returns `Handle`. `from_inner` takes `Handle`. Part 10.2 says *a
reader of a signature learns from the name which side of the border they are
on*, and today the name says one word while the type says the other. Part 10.1
defines *handle* as **"a pointer to an inner, seen by the toolkit, with no type
knowledge"** — which is exactly what crosses.

**The word *inner* keeps every job that is genuinely its own**: `Inner`,
`inner_offset`, `src/inner.c3`, and all the prose. It stops naming a handle,
and nothing else.

### H0 shrank what this governs

The surface an application reads most is now the methods, and they carry
neither word:

```c3
Msg* p = h.to(Msg);      Msg* q = h.as(Msg);      Msg* c = s.move(Msg);
```

H5 governs the free macros only — used where no handle is in hand yet, and
inside the containers.

### The correction

**M11 to M13 were measured with `handle_of(&m)`, and that spelling was this
stage's own invention, not the note's and not R1's.** It is the worse choice:
it drops the direction prefix that was R1's entire stated reason, and it breaks
the symmetry with `from_handle`. The accepted spelling is **`to_handle`**.

The probes were re-run rather than the document edited. Under `to_handle`, in a
checked build:

```
identity distinct        : true
to_handle/from_handle    : true
from_handle wrong type   : true
from_handle null         : true
must_from_handle         : true
is_mine yes/no           : true
Job inner at offset zero : true
from_slot, slot untouched: true
must_from_slot           : true
move mismatch: nothing   : true
move mismatch: untouched : true
move match: got item     : true
move match: slot cleared : true
owned create fills slot  : true
owned item recovered     : true
owned release empties    : true
mailbox round trip       : true
```

Seventeen, all true, zero errors, and identical under `-O3 --safe=no`. The two
diagnostics quoted in M14 and M15 were re-run too and are unchanged in
substance:

```
(n3.c3:3:34) Error: @require "$defined($Typeof(*item)::members)" violated:
'not a struct that embeds an Inner'.

(inner.c3:248:13) Error: type NotAnItem has no Inner field; it cannot be a
Matryoshka item
```

**A stage that renames a thing in its own quoted output has stopped quoting.**
That is why this was re-run, and it is the rule 3TK-4 set and this stage
inherited.

## H6 — `move_from_slot` stops depending on `take()`'s return value

> **CARRIED BY H0 — no separate ruling needed.** The macro measured in M11 and
> M13 is already written in the corrected form. Ruling H0 ruled this.

The note claims the current code takes and then subtracts. **Checked, and the
note is half right.** `helper.c3:122-126`:

```c3
fn Type* move_from_slot(Slot* s)
{
    if (!is_mine(s.peek())) return null;
    return (Type*)((char*)s.take() - OFF);
}
```

It **does** validate before it consumes — Part 9.2 rule 4 is honoured and the
mismatch path never touches the Slot. That half of the note's row is *conforms*.

What remains is smaller and real: the returned pointer is computed from
`take()`'s result, so the function silently depends on `Slot.take`
(`src/inner.c3:200-205`) returning exactly the handle `peek` observed. It does.
But the dependency is invisible at this call site and is exactly the sort of
thing a future change to `Slot` would break quietly.

```c3
fn Type* move_from_slot(Slot* s)
{
    Handle h = s.peek();
    if (!is_mine(h)) return null;
    s.take();
    return (Type*)((char*)h - OFF);
}
```

One extra line, one fewer assumption. Measured in M5 — both postconditions on
both paths, still true.

## H7 — `must_from_handle` keeps **one** check, not two

**Accept or reject. The stage recommends rejecting the note here.**

The note proposes splitting the single `@check` at `helper.c3:97` into a null
check and a wrong-type check, for a better diagnostic.

Part 15.5 decides it, and it decides against. Both cases are the same kind of
wrong — *a contract violation, a defect of the calling program* — and both
compile out together in a fast build (`@check`, `src/inner.c3:118-123`). The
tiers do not distinguish them, so splitting buys a message and costs a branch
in exactly the builds where checks are on and a developer is already at a
debugger with the handle in hand.

`helper.c3:47`'s doc comment already records the substantive point — that a
zeroed `typeid` from an uninitialized item is refused here rather than
mis-claimed, Part 5.5.

**Reject, and say why in the doc comment**, so the question does not come back.

## H8 — `init` stays an explicit, separately-called operation

> **NOTHING CHANGES — no ruling needed.** Recorded so the item is closed.

The note argues for keeping initialization explicit rather than folding it into
construction, and the port already does exactly that — Part 5.5 requires every
creation site to call it, including the ones that do not allocate, and
`helper.c3:53-57` says so. Under H1 the spelling becomes `MSG.init(&m)`, which
is the note's own preferred `Msg.init(&msg)` form as closely as M1 permits.

The note's optional extra — a debug null check inside `init` — is **not**
proposed. It is the same Part 15.5 argument as H7.

## H9 — The two layout tests stop asking the helper for the offset

> **FORCED BY H0 — no ruling needed.** There is no `OFF` under H0, so the three
> assertions must move to `mtk::inner_offset` whatever anyone prefers.

Originally required by H3.

`test/t_identity.c3:29-30` and `test/t_owned.c3:102` are the only readers of
`OFF`:

```c3
always_assert(MSG_OFF != 0, "Msg's inner should not be at offset zero");
always_assert(JOB_OFF == 0, "Job's inner should be at offset zero");
always_assert(mtk::helper::OFF{Owned} == 8, "Owned's inner moved");
```

**These are assertions about the fixtures' layout, not about the helper.** They
belong to `mtk::inner_offset`, which is where the offset is actually computed:

```c3
always_assert(mtk::inner_offset(Msg) != 0, "Msg's inner should not be at offset zero");
always_assert(mtk::inner_offset(Job) == 0, "Job's inner should be at offset zero");
always_assert(mtk::inner_offset(Owned) == 8, "Owned's inner moved");
```

C3 has no `offsetof` — no such member exists on a type
(`Error: No member 'offsetof' found.`) and the string appears nowhere in the
stdlib — so `mtk::inner_offset` is the port's own and only spelling for this,
and these three tests are its natural caller.

---

# Part B1 — The name

## H10 — `mtk::owned` becomes `mtk::managed`, or something else, or stays

Added 2026-08-24, on the owner's question: *is it time to replace `owned` with
`managed`?*

> **ACCEPTED by the owner, 2026-08-24 — candidate 1, the stage's
> recommendation.** `mtk::owned` becomes **`mtk::managed`**, with the
> garbage-collector connotation disarmed in one sentence of the module's doc
> comment. **The sub-question was part of the recommendation and is taken as
> accepted with it: the test fixture `struct Owned` becomes `struct Holder`.**
> If only the module rename was meant, say so — nothing is written yet and the
> fixture is a one-line reversal.
>
> **Measured after acceptance — see *The footprint, measured* below.** The
> rename compiles clean against the H0 surface, and **`run-builds.sh`'s
> expectation string does not change**, which is not obvious and was checked.

Added as a naming ruling, in the shape 3TK-10's naming items took — the stage
argues and the owner rules.

### Nothing in the rules constrains it

**The specification never uses the word.** `owned`, `owning`, `managed`,
`manage` — not one occurrence anywhere in
[matryoshka-specification-003.md](../common/matryoshka-specification-003.md).
Part 7.3 says the distinction may be made by *"two generators, an interface, a
flag, a separate name"*, and Part 7.1 says the spelling is the port's business.
**This is 3tk's word to choose, and changing it changes no rule.**

### What the word has to say

The module adds `create` and `release` to a type that carries an `Allocator`
field. Part 13.1: *an object takes an allocator at creation, keeps it for life,
releases itself with the kept one, and no release call takes an allocator as a
parameter.* The name should point at **that**.

### The three candidates

**1. `mtk::managed`** — the owner's proposal.

- **For.** `owned` is passive and invites *owned by whom?*, and the answer is
  nobody: D3's argument is that the item keeps **its own** allocator in its own
  outer. `managed` answers the question the module actually poses — managed by
  the toolkit's create and release.
- **For.** The port's own prose already reaches for the verb. `src/owned.c3:13`
  describes the other case as *"An item that does not want to pay the pointer
  takes `mtk::helper` and manages its own lifetime."* `mtk::managed` against
  *manages its own lifetime* is a clean, readable pair and it is the contrast
  that sentence was already drawing.
- **For, and this is the family argument.** The only place this vocabulary
  appears anywhere in the corpus is Zig's own, quoted in the ztk audit at
  `ztk-audit-001.md:264` — `AutoHashMapUnmanaged`. **In Zig, *managed* means
  precisely *keeps its allocator*, which is Part 13.1 verbatim.** For a port
  family, borrowing a word one of the family's languages already defines
  identically is worth something.
- **Against, and it is a cross-port cost that does not go away.** `managed`
  carries garbage-collector baggage — .NET's *managed code*, *managed heap*.
  This toolkit has no runtime and no collector. **dtk is a D port scoped
  `@nogc`**, and a D reader meets that word with a collector in mind. The word
  would be doing the opposite of its job for exactly one of the four ports.

**2. `mtk::owned` stays.**

- **For.** It is not wrong, only weak. It is written down in D10, in Part 7.3's
  3tk row of the deviation audit, and in 25 lines of doc comment. It costs
  nothing to keep.
- **Against.** H0b rewrites `owned.c3` from scratch anyway, so "it costs nothing
  to keep" is the argument for a file that is not being rewritten. This one is.

**3. A third name that sidesteps both problems.** The stage offers
`mtk::allocated`, and says plainly it prefers `managed` to it.

- **For.** It states the fact and imports no runtime connotation: this type was
  allocated by the toolkit and will be freed by it. `mtk::helper` against
  `mtk::allocated` needs no gloss in any of the four languages.
- **Against.** It names the *mechanism* where `managed` names the
  *relationship*, and the relationship is the thing Part 7.3 is about — the
  create and the release are Slot-shaped operations, not merely an allocation.
  It also reads oddly at the call site: `mtk::allocated::release(Owned, &s)`.

**The stage's recommendation: `managed`, and record the GC connotation in the
module's doc comment in one sentence**, aimed at the D and C# reader, so the
word arrives already disarmed. That is cheaper than choosing a weaker word to
avoid a misreading a single sentence prevents. **Accepted.**

**The sentence the code stage owes.** Something to this effect, in
`managed.c3`'s header, because dtk is the port that will meet it wrong:

> *Managed* here is Zig's sense, not .NET's: the item **keeps its allocator**
> and releases itself with the kept one — Part 13.1. There is no collector, no
> runtime and no tracing anywhere in this toolkit. The contrast is with
> `mtk::helper`, whose items manage their own lifetime.

### The sub-question: `struct Owned` is a different thing

`struct Owned { int id; Inner node; Allocator alloc; }` is a **test fixture**,
declared twice — `test/common.c3:23` and `negative/create_into_full_slot.c3:17`
— and read at 34 sites. It is not the module and renaming the module does not
settle it.

`test/common.c3:9` says what it is for: *"Owned — carries an Allocator, so it
may take mtk::owned. D3."* The fixture exists to prove one thing, and its three
siblings are named for what they prove — `Msg` for a non-zero offset, `Job` for
offset zero, `Twin` for two identical layouts with different identities.

So the fixture should be named for its property, not for which helper it takes.
**The stage's recommendation: `struct Holder`** — it *holds* an allocator, which
is the property under test, and it stays true no matter what the module is
called. `struct Managed` would work and re-couples the fixture to the module's
name for no gain. **Accepted with H10; reversible in one line if only the module
was meant.**

`test/common.c3:9`'s gloss becomes *"Holder — carries an Allocator, so it may
take mtk::managed. D3."*

### The cost, and why now

| | Sites | Caught by the compiler |
|---|---|---|
| `mtk::owned` | 12 | yes |
| `OWNED_TYPE` | 47 | yes — and **H0 deletes these anyway**, to `Owned::typeid` |
| `Owned` the fixture | 34 | yes |

**None of these names is a string**, so C3 reports every survivor — with the
warning 3TK-11 paid for and wrote down: *rename on word boundaries, and read the
diff*, after a blind pass turned `remove_from_anywhere` into
`remove_from_innerwhere`.

**On timing, which is what was asked. Now — meaning inside the code stage that
carries H0b, not before it and not as a stage of its own:**

1. **H0b rewrites `owned.c3` from scratch** and changes `release`'s signature.
2. **3TK-15's A5 repoints doc comments in the same files.**
3. `owned.c3`'s 25-line header is prose about D3 and D10 that a rename touches
   anyway.

One pass instead of three. A rename ruled now and applied later, by itself, is a
third sweep over files that will have just been rewritten twice.

### The footprint, measured

Run in scratch against the accepted H0 surface, after the ruling.

**The rename compiles clean.** `owned.c3` → `managed.c3`, `mtk::owned` →
`mtk::managed` throughout, `Owned` → `Holder` in the fixtures: **zero errors**,
and the behavioural proof still returns seventeen `true`.

**`run-builds.sh` does not change, and that is worth having checked.** The
compile-time negative for a type with no allocator is keyed at
`run-builds.sh:71` on the literal string `mtk::helper`:

```bash
declare -A NOCOMPILE_EXPECT=(
  [nocompile_no_inner]="NotAnItem"
  [nocompile_two_inners]="TwoInners"
  [nocompile_owned_no_allocator]="mtk::helper"
)
```

The message at `src/inner.c3:274` names **both** modules — *use `mtk::helper`
instead of `mtk::owned`* — so only its second half moves. Under the rename:

```
(inner.c3:274:13) Error: type Plain has no Allocator field; use mtk::helper
instead of mtk::managed
```

**The expectation string `mtk::helper` survives untouched.** The check passes
without editing the harness.

**Filenames are the one place a decision is still needed, and it is small.**
Two carry the word:

- **`test/t_owned.c3`** — the suite is compiled by `c3c test`
  (`run-builds.sh:95`), which discovers files itself. Renaming it to
  `t_managed.c3` is **free**: no line of any script names it.
- **`negative/nocompile_owned_no_allocator.c3`** — this one **is** named, as a
  hard-coded key at `run-builds.sh:71` and driven from `:161`. Renaming it to
  `nocompile_managed_no_allocator.c3` costs **exactly one line** of
  `run-builds.sh`, and the word in that filename names the module you tried to
  use, so leaving it stale is the worse outcome.

**The stage's advice: rename both files, and edit the one line.** It is the only
edit `run-builds.sh` needs for the whole of H0, H0b, H5 and H10 together — Part
D's *no change to `run-builds.sh` is proposed* was written before H10 existed
and is corrected here.

### What a ruling here drags with it

D10 is titled *"Two generic modules"* and names `mtk::owned` in its ruling text.
**H0b already moves that ruling's spelling; H10 moves the name inside it.**
Neither changes what D10 decided. `3tk-porting-proposal-004.md` is the design of
record and **the stage does not rewrite a finished stage's output** — so if H10
is accepted, the code stage records the rename in `3tk-deviations-001.md` and in
the log, and D10's text keeps its original words with a pointer. That is the
rule this folder already uses for a superseded name.

---

# Part C — Conformance

## Part 7.2 — every member, in the proposed surface

| Part 7.2 requires | Today | Under H0 | Under H1 + H5 |
|---|---|---|---|
| The type identity value | `TYPE`, `helper.c3:38` | `Msg::typeid`, C3's own | `TYPE`, public — **H4** |
| A predicate: does this identity name my type? | `is_mine`, `:47` | `is_mine(h, Msg)` | `Helper.is_mine` |
| Checking crossing, handle → typed pointer | `from_inner`, `:83` | `h.to(Msg)` | `Helper.from_handle` |
| Asserting crossing, handle → typed pointer | `must_from_inner`, `:95` | `h.as(Msg)` | `Helper.must_from_handle` |
| Checking crossing, Slot → typed pointer | `from_slot`, `:106` | `s.to(Msg)` | `Helper.from_slot` |
| Asserting crossing, Slot → typed pointer | `must_from_slot`, `:111` | `s.must(Msg)` | `Helper.must_from_slot` |
| Moving crossing from a Slot, both postconditions | `move_from_slot`, `:122` | `s.move(Msg)` — **H6** | `Helper.move_from_slot` — **H6** |
| Crossing the other way, cannot fail | `to_inner`, `:71` | `to_handle(&m)` | `Helper.to_handle` |
| An initializer that writes the identity | `init`, `:59` | `init(&m)` — **H8** | `Helper.init` — **H8** |

**Nine members present under either surface, none dropped, none added.** M5
exercised all nine plus `owned`'s two; M13 exercised all nine plus `owned`'s two
plus a live mailbox round trip.

Under H0 the identity is C3's `Msg::typeid` and the port stops re-exporting it.
That is not a member being dropped — Part 7.2's first member is *the type
identity value*, and `Msg::typeid` is it. **H4's evidence stands either way**:
the pool's public API is keyed on `typeid`, so the application must be able to
name it, and under H0 it names it in the language rather than through an alias.

Part 6.3's *named apart so a reader sees at the call site which one is meant*
holds: `MSG.from_handle` against `MSG.must_from_handle`.

## Part 7.1 — the per-type helper. **The one place H0 has a cost**

*"For each outer type there is a helper bound to that one type. The helper is
generated at compile time from the type."*

- **H1 satisfies this literally.** `mtk::helper::OF{Msg}` is a helper bound to
  one type, generated from it.
- **H0 does not.** There is no per-type helper object; the code is generated per
  call site. Part 7.1 is a SHOULD, its next line says *the shape is fixed,
  generation is the convenience*, and every member of 7.2 is present — but the
  sentence stops describing the port, and a port that quietly stops matching a
  SHOULD is how deviations are born. **E6 raises it as a question and this stage
  does not answer it.**

## Part 7.4 — validation

Unchanged and still at build time, with the message naming the type — M7 under
H1, M15 under H0. **H0 loses one thing**: a type declared and never crossed with
is never validated, because there is no instantiation to force it.

## Part 7.5 — the border

`OFF` goes private (H3) and every crossing still happens in `helper.c3`. **Under
H0 the question dissolves**: there is no `OFF` to export, because there is no
per-type instantiation — the macros call `mtk::inner_offset` directly. But
M8 is the honest statement and it must go into the doc comment: **the border is
held by convention and the layering checks, not by visibility**, because
`mtk::inner_offset` is public and cannot be made private without breaking the
helper. That is true of the port today; H3 does not create it and does not fix
it.

## Part 10.1 — the four words

H5 is the only item that touches this, and it is argued from Part 10.1 rather
than against it. *inner*, *handle*, *Slot*, *item* all keep their jobs.

## Part 15.5 — the tiers

H7 is decided by it, against the note.

---

# Part D — The cost

## Under H0: `test/common.c3` keeps its four structs and loses every alias

```c3
struct Msg   { int id; Inner node; char[8] body; }
struct Job   { Inner node; int pri; }
struct Twin  { int id; Inner node; char[8] body; }
struct Owned { int id; Inner node; Allocator alloc; }
```

**That is the whole file.** Twenty alias lines become none, `negative/common.c3`
loses seven, and `src/mailbox.c3:74-77` and `src/pool.c3:169-172` lose eight
between them — deleted in M13, not repointed. A new outer type costs **nothing**
before it can be used.

`MSG_TYPE`, `TWIN_TYPE`, `JOB_TYPE` and `OWNED_TYPE` become `Msg::typeid`,
`Twin::typeid`, `Job::typeid` and `Owned::typeid` at their 46-plus call sites —
mechanical, and it deletes the indirection rather than renaming it.

## Under H1: `test/common.c3`, the honest measure

**The plan and the status file both say seventeen alias lines. The file has
twenty** — `test/common.c3:25-47`. Nine for `Msg`, four for `Job`, four for
`Twin`, three for `Owned`.

Before, twenty lines:

```c3
alias msg_init      = mtk::helper::init{Msg};
alias msg_to_inner  = mtk::helper::to_inner{Msg};
alias msg_from_inner= mtk::helper::from_inner{Msg};
alias msg_must      = mtk::helper::must_from_inner{Msg};
alias msg_from_slot = mtk::helper::from_slot{Msg};
alias msg_move      = mtk::helper::move_from_slot{Msg};
alias msg_is_mine   = mtk::helper::is_mine{Msg};
alias MSG_OFF       = mtk::helper::OFF{Msg};
alias MSG_TYPE      = mtk::helper::TYPE{Msg};

alias job_init      = mtk::helper::init{Job};
alias job_to_inner  = mtk::helper::to_inner{Job};
alias job_from_inner= mtk::helper::from_inner{Job};
alias JOB_OFF       = mtk::helper::OFF{Job};

alias twin_init     = mtk::helper::init{Twin};
alias twin_to_inner = mtk::helper::to_inner{Twin};
alias twin_from_inner= mtk::helper::from_inner{Twin};
alias TWIN_TYPE     = mtk::helper::TYPE{Twin};

alias owned_create  = mtk::owned::create{Owned};
alias owned_release = mtk::owned::release{Owned};
alias OWNED_TYPE    = mtk::owned::TYPE{Owned};
```

After, **eight**:

```c3
alias MSG   = mtk::helper::OF{Msg};
alias JOB   = mtk::helper::OF{Job};
alias TWIN  = mtk::helper::OF{Twin};
alias OWNED = mtk::helper::OF{Owned};
alias OWNER = mtk::owned::OF{Owned};

alias MSG_TYPE   = mtk::helper::TYPE{Msg};
alias TWIN_TYPE  = mtk::helper::TYPE{Twin};
alias OWNED_TYPE = mtk::owned::TYPE{Owned};
```

**The number that matters is not 20 → 8. It is the slope.** Today a new outer
type costs up to nine lines before it can be used, and a type that wants one
more operation costs one more line. After, a plain type costs **one** line, an
owning type **two**, and the whole surface arrives with it. The `OWNED` line is
needed because the tests reach the plain surface of an owning type — the two
generic modules of D10 are two instantiations, which is D10 working as ruled.

`negative/common.c3:20-26` goes from seven alias lines to four by the same
arithmetic. The three `nocompile_*` files carry one alias each, and each is
repointed to `OF` — M7.

## Call sites that move

Counted by word boundary across the three trees.

| Where | Calls through an alias | Inline `mtk::helper::x{T}` / `mtk::owned::x{T}` | Alias declarations |
|---|---|---|---|
| `src/` | — | 5 (all in `owned.c3`) | 8 (`mailbox.c3:74-77`, `pool.c3:169-172`) |
| `test/` | 237 | 13 | 20 |
| `negative/` | 22 | 2 | 10 (7 in `common.c3`, 3 in the `nocompile_*` files) |

**Roughly 280 call sites and 38 declarations, and every one is mechanical**: `msg_init(&m)` becomes
`MSG.init(&m)`; `mtk::helper::must_from_slot{Owned}(&s)` becomes
`OWNED.must_from_slot(&s)`. C3 catches every survivor at compile time, because
none of these names is a string.

`src/mailbox.c3:74-77` and `src/pool.c3:169-172` each carry four file-local
aliases (`init`, `to_inner`, `of`, `TYPE`) and each becomes one instance
constant plus the `TYPE` alias. Both containers compiled in M5.

## `run-builds.sh`

59 checks. The three that read helper names are the `nocompile_*` message
greps, and `run-builds.sh:71` expects the literal `mtk::helper` in
`nocompile_owned_no_allocator`'s diagnostic. **M7 quoted that exact message
under the proposed shape.** The three layering checks read module structure,
not member names, and are untouched.

**One line of `run-builds.sh` changes, and only because of H10** — the
`nocompile_owned_no_allocator` key at `:71`, if that file is renamed with the
module. Nothing in H0, H0b or H5 touches the harness at all; the expectation
*string* `mtk::helper` survives the rename, which was measured, not assumed.
See H10's *The footprint, measured*.

---

# Part E — What this stage will not answer

1. **Whether any of this is worth doing.** No rule requires it. Part 7.1 says
   the spelling is the port's business and Part 7.2's members are all present
   either way. This is a surface change the owner asked for, and every item
   above is a separate yes or no.
2. **D4 is not reopened and nothing here needs it moved.** **D10 is touched by
   H0b and only in its spelling** — two generic modules become two modules, and
   Part 7.3's list of permitted means includes *a separate name*. The stage says
   so as a question and does not answer it, which is the shape 3TK-10 used. H2,
   the no-macro alternative, does not touch D10 at all.
3. **Whether `mtk::inner_offset` should be harder to reach from application
   code.** M8 found it is the real door and that C3's module-scoped `@private`
   cannot close it while the helper is a submodule. Closing it would mean
   changing the port's module structure — `mtk::helper` inside `mtk` rather
   than beside it — and that touches the layering checks Part 17.2 rests on.
   **That is a question, and this stage does not answer it.**
4. **Nothing in `../common/` is touched**, and the specification needs no
   change for any item here. Part 7.1 already says the spelling is free.
5. **~~Whether Part 7.1 still describes the port, if H0 is accepted.~~ RULED
   2026-08-24: it is a *specification* defect, an **S/V** row, not a port
   deviation.** See *E6, ruled* below.
6. **~~Whether the owning distinction may stop being a property of the type.~~
   RULED 2026-08-24: it never was one in 3tk, and nothing is lost.** See *E7,
   ruled* below.
7. **The code stage.** This is a proposal. If items are accepted, the rewrite
   is a separate stage the owner names, and 3TK-15's A5 repoints doc comments
   in the same files — which is why the plan puts it after this one.

---

# Verification

1. `3tk/run-builds.sh` — *passed 59, failed 0, all four builds green*.
   `3tk/run-sanitizers.sh` — *passed 3, failed 0, 85 tests, clean*. Both
   trivially, because no file under `3tk/` was changed.
2. **Every claim about C3 carries a compiled program and its output** — M1 to
   M15, including one guard that was wrong on its first spelling and is
   corrected in place with both directions re-verified (M14). Where a statement is judgement rather than measurement it says so in
   place: H1's cost, H5's reading, H7's recommendation.
3. **Every claim about the port carries a file and line** — Part B and Part D
   throughout.
4. **Every one of Part 7.2's members is accounted for, under both surfaces** —
   Part C's table, nine rows, two columns. M5 ran all nine under H1; M13 ran all
   nine under H0, plus `owned` and a live mailbox round trip, in a checked build
   and under `-O3 --safe=no`.
5. The scratch directory is outside `3tk/`, is not built by `run-builds.sh`,
   and is no part of the port.

---

# Part F — The rulings on Part E

## E6, ruled — Part 7.1 is a specification defect. An **S/V** row, `every port`

**Ruled by the owner, 2026-08-24.**

Part 7.1's three clauses, against H0:

| Clause | Under H0 |
|---|---|
| *generated at compile time from the type* | **true** — macro expansion is compile-time generation from the type |
| *carries the type identity of Part 5, and the crossings of Part 6* | **true** |
| *for each outer type there is a helper bound to that one type* | **the only one that fails** |

**And Part 7.1's own closing sentence sets the floor lower than H0 sits.** *"A
port with no compile-time generation writes the same block by hand for each
type, and loses **only the typing**."* Hand-written per-type blocks are
conformant. H0 is *above* that floor on the thing the sentence says matters —
it generates — and below it only on having a **named per-type object**, which is
a mechanism and not a promise.

**That one failing clause is ztk's mechanism, and this is the disease 3TK-13
existed to cure.** 002 was written from ztk and stated Zig's mechanism where the
design has only a promise, **in fourteen places**; 003 fixed all fourteen. **Part
7.1 is the fifteenth, and 3TK-13 missed it** — a comptime-per-type-struct shape
written up as though it were the requirement.

**The deciding argument is dtk, and it is the same argument that moved the
specification into `../common/` on 2026-08-23.** dtk has a prepared folder and
no stage has run. D's idiomatic answer to *generate code per type* is templates
and mixins — call-site expansion, the same shape as a C3 macro, **not** a
per-type struct. Fixing Part 7.1 inside this consumer's folder would leave the
identical trap set for D, and for Odin after it. A shared input read as a
port-local problem is a fork waiting to happen.

**So the row is an S, scope `every port`, in the vocabulary
`3tk-deviations-001.md` already uses** — V1, V2 and V3 are the precedent, and
003's change log at lines 1629-1631 shows how a V is consumed by a specification
stage. **It is not a P.** Filing a P would record the port as wrong where the
specification overreached, and keeping those two apart is the entire value of
that audit.

**What is owed, and by whom — 3TK-14 may write none of it.**

1. **The V row in `3tk-deviations-001.md`.** That file is 3TK-12's output and
   **this stage may not rewrite a finished stage's output.** The code stage that
   carries H0 writes the row, because that is when the port actually stops
   matching the sentence.
2. **The rewording of Part 7.1 in `../common/`.** No stage may touch
   `../common/` under plan 008, and **no such stage is declared.** It needs one,
   and it is small: Part 7.1 states the promise and shows both realizations,
   marked *ztk* and *3tk*, exactly as 003 did for the other fourteen.
3. **Sequencing: before dtk's first stage, not after.** Cheap now; a second
   port's worth of the same argument later.

## E7, ruled — nothing is lost. The premise was wrong

**Ruled by the owner, 2026-08-24. No change to anything.**

The stage raised E7 as *the owning distinction stops being a property of the
type*. **It was never a property of the type in 3tk.**

- `struct Owned { int id; Inner node; Allocator alloc; }` — `test/common.c3:23`.
  **No marker. The type declares nothing.**
- `src/owned.c3:5` says so outright: *"ztk spells this distinction with a marker
  constant and pays 110 duplicated lines; **C3 has no property to branch on and
  needs neither**."*

**D10 already moved the decision off the type.** `alias owned_create =
mtk::owned::create{Owned};` is written by the *application*, not by the type —
an instantiation is a declaration, not a permission. H0b moves it from the alias
line to the call line, and both are on the application's side of the fence.

**The hard gate survives, measured under the H10 rename:**

```
Error: type Plain has no Allocator field; use mtk::helper instead of mtk::managed
```

`mtk::required_alloc_offset($Type)` still refuses at build time, so *a type with
no allocator cannot be managed* holds in both shapes.

**What is genuinely unguarded** is a type that *has* an `Allocator` but wants to
allocate itself — and it was unguarded before too, because nothing stopped the
application from writing the alias.

**What the code stage owes:** one sentence in `managed.c3`'s header recording
that the distinction lives at the call site and that D10 is why, so the question
is not re-asked; and Part 7.3's row in `3tk-deviations-001.md` updated from
*"D10, two generic modules"* to *"two modules"*.
