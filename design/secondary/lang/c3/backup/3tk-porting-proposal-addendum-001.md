# Addendum 001 to the 3tk porting proposal — method binding, and what C3 will not hide

An addendum to [3tk-porting-proposal-003.md](3tk-porting-proposal-003.md), the
design of record. Written 2026-08-23, outside any stage.

**It is an addendum and not a revision.** It moves no decision and corrects no
sentence in 003. It records four measured facts — four about how C3 binds methods to types, one
about what it refuses to hide — facts no document in this folder states, and which the port depends on
in three places. **3TK-8 folds it into `3tk-porting-proposal-004.md`**, after
which this file is superseded and moves to `backup/`.

Measured against `c3c` 0.8.3, git `1d155ee`, LLVM 22.1.8, target linux-x64 —
the same toolchain every answer in `c3-capabilities-001.md` is stated against.
Ten probes, compiled and run.

## Why it exists

The owner asked whether C3 supports calling `functionCall(handle, ...)` as
`handle.functionCall(...)`. The answer decides how a handle-based API can be
spelled at all, and the port has been relying on the answer since 3TK-6 without
having written it down.

## M1 — There is no general UFCS

**A free function cannot be called with dot syntax.**

```c3
fn void bump_free(Foo* f, int n) { f.x += n; }
...
(&f).bump_free(1);
// Error: There is no field or method 'Foo.bump_free'.
```

C3 does **not** rewrite `a.f(b)` into `f(a, b)`. D does, and that is where the
question comes from; the two languages differ here.

## M2 — A method function does, and the association is at the declaration

```c3
fn void Foo.bump_method(&self, int n) { self.x += n; }
...
(&f).bump_method(2);            // compiles, runs
```

The receiver is written into the **name**, not inferred at the call site. Every
dotted call in `3tk/src/` — `mb.send(&s)`, `list.push_back(h)`,
`slot.is_empty()` — is a method declaration of this form. The port has no UFCS
anywhere and never had.

## M3 — A method may be declared on a type from another module

```c3
module owner;
struct Foo { int x; }

module other;
fn void Foo.foreign(&self, int n) { self.x += n; }   // compiles, runs
```

The association is **open**, not owner-only. Consequence for D1: an argument
that a split representation would force every method into the declaring module
is wrong. It would not.

One warning fell out of the same probe and confirms F2 of
`3tk-toolkit-notes-001.md`:

```
Warning: '@public' modifiers are ignored for method declarations.
```

C3 0.8.3 does not take a visibility modifier on a method at all. That is why
`NodeList.unlink_no_repair` is documented rather than hidden (`list.c3:251`).

## M4 — Methods attach to named types, never to a pointer alias

**This is the one with teeth.**

```c3
alias   Handle = Node*;
typedef Box    = Handle;

fn void Handle.viaAlias(self) { ... }
// Error: Methods can not be associated with 'Node*'.

fn void Box.viaTypedef(&self) { ((Handle)*self).x += 10; }   // compiles, runs
```

A **transparent alias to a pointer carries no methods.** A **distinct typedef
does.** Inside a typedef's method, `self` is the typedef, so reaching the
pointed-to value needs an explicit cast back through the alias — the field is
not visible through the distinct type (*"There is no field or method 'Box.x'"*).

### What M4 means for the port

`AnyHandle` is `alias AnyHandle = AnyNode*` and `Slot` is
`typedef Slot = AnyHandle` — D4 and D5, section 1 of 003. So:

- **`AnyHandle` can carry no methods of its own.** Every handle operation must
  be a method on `AnyNode`, or a free function such as `mtk::is_linked(h)` and
  `mtk::reset(h)` (`list.c3:58`, `:66`). It was never a style choice.
- **`Slot` can, and does** — `fill`, `take`, `peek`, `is_empty`, `is_full`.
- The asymmetry between the two in every signature in the port is therefore
  **partly forced by the language**, not purely by design.

This sharpens the §14 signature rule that review `003-review` asks for, and
3TK-8 should state the rule with M4 attached: the reason a Slot reads as an
object and a handle reads as a value is that C3 will only let one of them be an
object.

D5's argument is unaffected and gains a second leg. 003 argues the distinct
`Slot` for the compiler's benefit — it can tell a container of a handle from a
handle. M4 adds that the distinct type is also **the only one of the two that
can own behaviour**.

## M5 — There is no field-level privacy, and `inline` does not create one

**The owner's question, 2026-08-23:** restrict access to *fields* without
restricting *functions*. The shape proposed was a private fields-only struct,
inlined into the public container:

```c3
struct MailboxInternals @private { Mutex mu; bool closed; ... }
struct Mailbox { inline MailboxInternals guts; AnyNode node; }
```

so that `mtk`'s own methods reach `self.mu` transparently and an application
cannot. **C3 0.8.3 does not deliver it.** Six probes:

| Probe | Result |
|---|---|
| `inline` on a field that is not the first | **Error** — *"Only the first element may be `inline`, did you order your fields wrong?"* |
| `inline` private struct as the first field; the module's own methods use `self.counter` | **Compiles and runs.** Transparent inside the module, as intended |
| Another module writes `b.counter = 99` | **Compiles**, and the write lands — the module then reads 99 |
| Another module writes `b.guts.counter` | **Compiles** |
| Another module takes `&b.guts.counter` and writes through it | **Compiles**, and the write lands |
| `Guts guts @private;` — privacy on the *field* | **Error** — *"'@private' cannot be used here"* |

**`@private` on a struct is a type-name rule, not a field-access rule.** What it
does buy is real but small: an application **cannot name the type** — no
variable of it, no function taking one, no embedding it. What it does not buy:
the fields inside it stay readable, writable and addressable through the outer.

**`inline` makes it worse, not better.** It lifts the hidden fields into the
outer's own namespace, so `mb.closed` — no `.guts` to write — is exactly as
reachable as any public field. A *named* private field at least costs the
application a `.guts` to say out loud, which is a legibility signal rather than
a barrier. Neither is enforcement.

There is no field-level privacy in the language at all. That is the same wall as
**F2** of `3tk-toolkit-notes-001.md` — C3 0.8.3 ignores `@private` on method
declarations too, confirmed by M3's compiler warning — and it is why
`NodeList.unlink_no_repair` is documented rather than hidden.

### What M5 settles

**Restricting field access while leaving functions public is not achievable in
C3 0.8.3 by any shape that keeps the state inside the object.** The only
mechanisms that actually stop an application reaching a field move the state
*out* of the public struct: the `Impl*` pointer of `003-review` §1, or the
opaque `char[N]` of its §7. Both cost what D1 says they cost. **Neither costs
Part 11.1** — which is the review's original point, now standing on a measured
floor instead of an inference.

Two notes for whoever writes D1 in proposal 004:

- `inline` here would sit badly with **D2**, which refuses `inline` for
  `AnyNode` because it makes a crossing invisible at the call site. A second
  `inline` in the same struct spreads the same fog over the container's state.
- The first-field constraint puts `inline MailboxInternals` and `AnyNode node`
  in competition for position. The inner would have to move, which **D2
  explicitly permits** — *at whatever offset the outer's author likes* — so that
  part is survivable. It is the only part that is.

A measured *no* is worth as much to **dtk** and **otk** as a yes: D has real
field privacy and Odin does not work this way either, so a port reading this
folder should know the C3 answer was tested rather than assumed.

## What this addendum does not do

- It moves no decision. D4 and D5 stand exactly as accepted.
- It changes no code. The port already obeys all four facts; it simply never
  said so.
- It is not a `c3-capabilities-002.md`. That would supersede a finished stage
  output, and whether to cut one is an open question for the owner — see
  [3tk-status.md](../3tk-status.md).

## Provenance

The four probes live in the session scratchpad and are not kept: each is a
dozen lines, and the results above are the record. 3TK-8 re-runs any of them on
demand — the toolchain is local, `c3c` at `/usr/bin/c3c`.
