<*
 The outer types every test uses, and the helper instantiations for them.

 Four types, each chosen to prove something:

   Msg   — the inner at a non-zero offset. Part 4.3.
   Job   — the inner at offset zero. Part 4.3's other end.
   Twin  — byte-for-byte the same layout as Msg, and a different type. Part 5.1.
   Owned — carries an Allocator, so it may take mtk::owned. D3.

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
struct Owned { int id; Inner node; Allocator alloc; }

alias msg_init      = mtk::helper::init{Msg};
alias msg_to_inner  = mtk::helper::to_inner{Msg};
alias msg_from_inner= mtk::helper::from_inner{Msg};
alias msg_must      = mtk::helper::must_from_inner{Msg};
alias msg_from_slot = mtk::helper::from_slot{Msg};
alias msg_move      = mtk::helper::move_from_slot{Msg};
alias msg_is_mine   = mtk::helper::is_mine{Msg};
alias MSG_OFF       = mtk::helper::OFF{Msg};
alias MSG_TYPE      = mtk::helper::TYPE{Msg};

alias job_init     = mtk::helper::init{Job};
alias job_to_inner  = mtk::helper::to_inner{Job};
alias job_from_inner= mtk::helper::from_inner{Job};
alias JOB_OFF      = mtk::helper::OFF{Job};

alias twin_init     = mtk::helper::init{Twin};
alias twin_to_inner  = mtk::helper::to_inner{Twin};
alias twin_from_inner= mtk::helper::from_inner{Twin};
alias TWIN_TYPE     = mtk::helper::TYPE{Twin};

alias owned_create  = mtk::owned::create{Owned};
alias owned_release = mtk::owned::release{Owned};
alias OWNED_TYPE    = mtk::owned::TYPE{Owned};
