# 3tk — the helper surface in code (notes 001)

Stage 3TK-16, 2026-08-24. What the code taught, in the shape of the toolkit,
container, sanitizer and redesign notes.

**The stage built four ruled items and made no ruling of its own.** H0 and H0b
(the helper and the managing helper become macros), H5 (the crossings are named
for the *handle*), H10 (`mtk::owned` becomes `mtk::managed`), plus the **V19**
row in [3tk-deviations-001.md](3tk-deviations-001.md), Part 7.3's row, and one
line of `run-builds.sh`. The specification of the stage is
[3tk-helper-proposal-001.md](3tk-helper-proposal-001.md) as the owner ruled it,
and nothing here re-argues it.

---

## The result, in one screen

| | Before | After |
|---|---|---|
| `alias` lines naming `mtk::helper` or `mtk::owned` | **35** | **0** |
| — `test/common.c3` | 20 | 0 |
| — `negative/common.c3` | 7 | 0 |
| — `src/mailbox.c3` + `src/pool.c3` | 8 | 0 |
| Generic modules | 2 | **0** |
| `src/helper.c3` | 126 lines, `module mtk::helper <Type>` | 218 lines, `module mtk::helper` |
| `src/owned.c3` → `src/managed.c3` | 85 lines | 101 lines |
| `test/common.c3` | 47 lines | **30**, and 22 of them are the header |
| Tests | 85 | **87** |
| `run-builds.sh` checks | 59 | **59** |
| Sanitizer checks | 3 | 3 |

**Four builds green, 59 checks, 0 failed. 87 tests over four builds. Thread and
address sanitizers clean, 3 checks.** The check count is stated and not
inherited: a renamed compile-time negative is still one negative, so 59 is 59
for a reason and not because the sentence was copied.

**`test/common.c3` is the number to look at.** It is four struct declarations
and a doc comment. A new outer type costs nothing at all before it can be used
— not one line, anywhere. That was H0's whole claim and it is the file.

---

## 1. Three spellings the proposal's scratch measurements did not carry

The proposal's M11 to M15 were run in scratch and every line it quotes is real
output. Three details still had to be found again in the port, and they are the
sort of thing that costs an hour if they are not written down.

**`$Type.typeid` does not compile. It is `$Type::typeid`.**

```
Error: A type can't appear here.
```

The port already knew this — `run-builds.sh:108` records that `Msg.typeid` does
not compile on c3c 0.8.3, and the old `helper.c3:38` wrote `Type::typeid` — but
the knowledge lived in a comment about a negative test rather than anywhere a
rewrite would meet it. **A double colon reaches a type's compile-time members; a
dot does not.**

**`$typeof(x)::typeid` does not parse. It is `$Typeof(x)::typeid`.**

```
Error: Expected the ending ')' here.
```

Two builtins, one letter apart, and only the capitalized one may be followed by
`::`. `$typeof` yields a type usable as a type; `$Typeof` yields one usable as a
compile-time namespace. The proposal wrote `$Typeof` throughout and was right;
this stage typed the lowercase form from habit and the compiler caught it at
once.

**`to_handle(null)` cannot be written any more**, and this is a real
consequence of H0 rather than a spelling. The outbound crossing infers its type
from the pointer, so a bare `null` gives it nothing to infer from — the same
shape as the proposal's *"the moving crossing needs `return ($Type*)null`"*, in
the other direction. `test/t_identity.c3`'s null case became
`to_handle((Msg*)null)`, which is what it always meant: **a null pointer of a
known type makes no handle.** The test did not weaken; it stopped being able to
lie about which type it was crossing.

---

## 2. What moved, measured against the proposal's estimate

The proposal counted `mtk::owned` at 12 sites, `OWNED_TYPE` at 47 and the
`Owned` fixture at 34, and said all three were caught by the compiler.

**They were, and the count was low, because the estimate covered the rename and
not the surface.** After the rewrite the port holds **182** `mtk::helper::`
calls in `test/`, **24** in `negative/` and **9** in `src/`, plus **25**
`mtk::managed::` calls. Roughly 240 call sites moved, against 93 estimated.

**The difference is not a miss. It is where the alias went.** Every one of those
call sites used to be a short name — `msg_init`, `msg_to_inner`, `msg_must` —
that an alias line supplied. Deleting 35 alias lines moved the type from the
declaration to the call, and the call sites are where the types now live. That
is H0's trade, stated in the proposal, and the arithmetic of it is: **35 lines
of ceremony deleted, ~240 call sites made explicit about a type they were
already about.**

**Every survivor was caught by the compiler, and none was caught by a reader.**
The rewrite was mechanical — a paren-matching rewriter over the ten call shapes
— and the compiler found each of the eight sites it did not know about
(`mtk::helper::must_from_slot{Holder}` written inline, `mtk::helper::OFF{Holder}`
in a layout test, `mtk::managed::create{Plain}` in a negative). **Not one
survivor was silent.**

---

## 3. The rename trap 3TK-11 wrote down, and what it cost here

3TK-11's warning was *rename on word boundaries, and read the diff*, after a
blind pass turned `remove_from_anywhere` into `remove_from_innerwhere`. This
stage renamed on three axes at once and the warning held on all three.

- **`owned` → `managed`** — safe, and it is not a substring of anything.
- **`Owned` → `Holder`** — the fixture, at 34 sites. Word-boundary regex, and
  the four prose occurrences in doc comments were meant to move too.
- **`inner` → `handle` in member names only** — **the dangerous one**, and it
  was never done as a rename. `to_inner`, `from_inner` and `must_from_inner`
  were rewritten by name, one shape at a time, precisely so that `Inner`,
  `inner_offset`, `src/inner.c3` and every line of prose about the inner would
  be untouchable by construction. **A blind `inner` → `handle` pass would have
  destroyed the port.** H5 renames three members and nothing else.

**Four stale words survived the mechanical pass and were caught by reading**:
two assertion messages still saying *to_inner*, a negative's doc comment saying
*aborts in must_from_inner*, another saying *aborts in owned::create*, and a
test function still named `an_owned_item_is_an_ordinary_item`. **None of them
was a compiler error.** Prose does not compile, and a rename that only satisfies
the compiler leaves the file lying to the next reader.

---

## 4. The containers kept a public surface, and it stopped being an alias

`mailbox.c3` and `pool.c3` each carried four alias lines — `init`, `to_inner`,
`of`, `TYPE`. **Three of the four are the container's own public surface**: a
`Mailbox` is an item like any other (Part 11.1), and `t_mailbox.c3:45-48` and
`t_pool.c3:136-139` cross with it exactly as an application would.

So the eight alias lines went, and six declarations took their place — not
aliases, and not per-type instantiations:

```c3
const typeid TYPE = Mailbox::typeid;
macro Handle to_handle(Mailbox* p) => mtk::helper::to_handle(p);
macro Mailbox* of(Handle h) => mtk::helper::from_handle(h, Mailbox);
```

`init` needed no replacement at all — the two internal callers now write
`mtk::helper::init(mb)` directly.

**This is the one place the stage exercised judgment inside a ruled item, and it
is worth naming.** The proposal's M13 deleted these eight lines *outright* and
repointed their callers. Deleting them entirely would have moved a container's
public crossing into every test that performs it. **The containers keep their
names and the aliases are gone** — which is what H0 rules (no alias, for any
type) and what Part 11.1 wants (a container is an item, and its callers need a
way back).

---

## 5. The three `nocompile_*` negatives changed shape, and one of them lost a little

Each of the three was an `alias bad = ...{SomeBadType};` line whose declaration
is what the compiler refused. **Under H0 there is no declaration to refuse**, so
the crossing moved into `main`:

```c3
fn int main() { NotAnItem n; mtk::helper::init(&n); return 0; }
```

**All three still refuse, in all four builds, and all three messages still name
the offending type** — `NotAnItem`, `TwoInners`, `mtk::helper`.

**The proposal's M15 loss is real and is now visible in the suite**: a type
declared and never crossed with is never validated. The old form validated
`NotAnItem` at its alias line; the new form validates it at the call. The
negatives are unaffected because they call — but a port reading these files
should know that Part 7.4's check is now a property of *use*, not of
*declaration*.

**`nocompile_owned_no_allocator.c3` became
`nocompile_managed_no_allocator.c3`**, and the proposal's measurement held
exactly: the expectation string is `mtk::helper` — the *alternative* the message
names, not the module you misused — so **`run-builds.sh` needed one line
changed, the array key, and nothing else.**

---

## 6. What the stage added that no item asked for: two tests

`test/t_identity.c3` gained `the_methods_cross_the_same_border` and
`the_slot_methods_cross_the_same_border`. **85 tests became 87.**

M12's `h.to(Msg)`, `h.as(Msg)`, `s.to`, `s.must` and `s.move` are five new
declarations that do address arithmetic, and the free macros are what the rest
of the suite exercises. **A separate declaration is a separate way to get the
offset wrong**, and the method surface is the one an application reads most —
it is the whole reader-facing argument for H0. It was untested; now it is not.

No test was removed. H0 removed none, as the plan required.

---

## 7. What this stage did not do

- **`../common/` is untouched.** Part 7.1 is wrong and stays wrong until 3TK-17.
  The stage recorded **V19** and did not conform to a Part its own folder has
  ruled defective.
- **3TK-15's work is not done.** A5's doc-comment repointing across the port is
  the next stage. The files this stage rewrote — `helper.c3`, `managed.c3`,
  `test/common.c3`, `negative/common.c3` — carry correct citations. **Every
  other file's stale `002` citation was left exactly where it was**, including
  `mtk.c3`'s, which this stage repointed only because it was rewriting the two
  lines that name the helper modules anyway.
- **No ruled item was re-opened.** H7 stands as recommended and its reason is
  now in `must_from_handle`'s doc comment, so the question does not come back.
  H6's corrected form is in `move_from_slot`. H8's explicitness is stated where
  `init` is declared. H9's three assertions call `mtk::inner_offset` directly.
- **No `git` command was run.**

---

## 8. The one thing a later reader should not undo

`src/helper.c3`'s header ends with a sentence that is there on purpose:

> Part 7.1 as `matryoshka-specification-003.md` words it asks for a helper
> object bound to one type. This port has none, and that sentence is a
> SPECIFICATION defect, not a port defect — E6, and `3tk-deviations-001.md`
> V19. 3TK-17 rewords it. **Do not "fix" this file to match it.**

A stage that reads Part 7.1, sees the port does not match, and adds a per-type
struct to conform would un-rule a ruling and re-introduce ztk's mechanism as a
requirement. The sentence is the guard on that, and it can come out when 004 is
cut.
