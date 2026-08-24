<*
 The outer types every test uses. **That is the whole file — H0.**

 There is not one alias here and there is nothing else to write. `mtk::helper`
 and `mtk::managed` are macros over `$Type`, so a new outer type costs nothing
 before it can be used: declare the struct and cross with it.

 Four types, each chosen to prove something:

   Msg   — the inner at a non-zero offset. Part 4.3.
   Job   — the inner at offset zero. Part 4.3's other end.
   Twin  — byte-for-byte the same layout as Msg, and a different type. Part 5.1.
   Holder — carries an Allocator, so it may take mtk::managed. D3.

 The fourth is named for the property it proves — it HOLDS an allocator — and
 not for the module that reads it. H10.

 Test assertions use `always_assert`, not `assert`. The tests run in all four
 builds of the proposal's 7.2, and a plain `assert` is a no-op in two of them —
 a test suite built on `assert` would report green in a fast build without
 having checked anything.
*>
module mtk_test;
import mtk;
import std::core::mem::alloc;

struct Msg   { int id; Inner node; char[8] body; }
struct Job   { Inner node; int pri; }
struct Twin  { int id; Inner node; char[8] body; }
struct Holder { int id; Inner node; Allocator alloc; }
