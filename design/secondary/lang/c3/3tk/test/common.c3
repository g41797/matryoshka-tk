<*
 The outer types every test uses. **That is the whole file — H0.**

 A new outer type costs one line: the struct, and the `mtk::OF` alias under it.
 The crossing macros are macros over `$Type` and cost nothing at all — the
 alias is there so that a caller writes `MSG.must_look(&s)` and not the macro.

 Four types, each chosen to prove something:

   Msg   — the inner at a non-zero offset. Part 4.3.
   Job   — the inner at offset zero. Part 4.3's other end.
   Twin  — byte-for-byte the same layout as Msg, and a different type. Part 5.1.
   Holder — declares an `init` hook and keeps the allocator in a field of its
            own. Nothing requires it to; it is what an outer with a lifetime
            typically chooses. Part 2.2.

 The fourth is named for the property it proves — it HOLDS an allocator — and
 not for the module that read it. Nothing reads it now: since 3TK-64 the
 allocator is passed to `create` and `release`, and the field is Holder's own.

 Test assertions use `always_assert`, not `assert`. The tests run in all four
 builds of the proposal's 7.2, and a plain `assert` is a no-op in two of them —
 a test suite built on `assert` would report green in a fast build without
 having checked anything.
*>
module mtk_test;
import mtk;
import std::core::mem::alloc;

struct Msg   { int id; Inner inner; char[8] body; }
struct Job   { Inner inner; int pri; }
struct Twin  { int id; Inner inner; char[8] body; }
struct Holder { int id; Inner inner; Allocator alloc; }

fn void? Holder.init(&self, Allocator a) { self.alloc = a; return; }

// Three more, each one the subject of a test in `t_helper.c3` and of nothing
// else. `Two` and `Picky` are the outers that two retired negative programs
// used to assert were illegal.
struct Two   { int id; Inner inner; Allocator first; Allocator second; }
struct Picky { Inner inner; int id; }
struct Noisy { Inner inner; int id; }

faultdef PICKY_REFUSED;

int destroyed;

fn void? Two.init(&self, Allocator a)   { self.first = a; self.second = a; return; }
fn void? Picky.init(&self, Allocator a) => PICKY_REFUSED~;
fn void? Noisy.destroy(&self, Allocator a) { destroyed++; return; }

alias MSG    = helper::OF{Msg};
alias JOB    = helper::OF{Job};
alias TWIN   = helper::OF{Twin};
alias HOLDER = helper::OF{Holder};
alias TWO    = helper::OF{Two};
alias PICKY  = helper::OF{Picky};
alias NOISY  = helper::OF{Noisy};
