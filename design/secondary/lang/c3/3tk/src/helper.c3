<*
 The per-type helper. Part 7, and the border of Part 7.5.

 One instantiation per outer type. Every crossing between a typed pointer and
 a type-erased handle happens in this file and nowhere else. That is what makes
 the address arithmetic auditable: Part 7.5 MUST.

 D2 refused `inline` on the inner field for the same reason. An implicit
 conversion is a crossing that appears at no call site and in no file.

 Instantiation, one alias per member the application uses:

     struct Msg { int id; Inner node; char[64] body; }

     alias msg_init  = mtk::helper::init{Msg};
     alias msg_of    = mtk::helper::from_inner{Msg};
     alias msg_toinner = mtk::helper::to_inner{Msg};

 A generic module instantiates per declaration, not as a whole. There is no
 one-line form.
*>
module mtk::helper <Type>;
import mtk;

<*
 The offset of Type's inner. Part 7.4's validation runs inside this call, at
 build time, and its message names Type.
*>
const usz OFF = mtk::inner_offset(Type);

<*
 The type identity. Part 5.

 Native, by Q2: unique at runtime, equal for two items of one type, different
 for two identically-shaped types, O(1) to compare. The per-type mutable byte
 ztk needed against linker merging does not exist here.
*>
const typeid TYPE = Type::typeid;

<*
 Part 7.2's predicate: does this identity name my type?

 A null handle is not mine. Part 5.5's uninitialized inner carries a zeroed
 typeid, which matches no type, so an item whose init was never called is
 refused here rather than mis-claimed.
*>
fn bool is_mine(Handle h) @inline => h != null && h.type == TYPE;

<*
 Part 7.2's initializer. Writes the identity into the inner. Part 5.4: the
 identity is stored, not computed.

 The link is cleared as well — one field now, not two — so a freshly
 initialized item passes the exact link test of Part 8.7 and can be inserted.

 Every creation site calls this, including the ones that do not allocate.
 Part 5.5.
*>
fn void init(Type* item)
{
    Inner* n = (Inner*)((char*)item + OFF);
    n.next = null;
    n.type = TYPE;
}

<*
 Part 7.2's crossing the other way: from a typed pointer to a handle.

 This one cannot fail, and it is the only direction that adds the offset.
*>
fn Handle to_inner(Type* item) @inline
{
    return item ? (Handle)((char*)item + OFF) : null;
}

<*
 The checking crossing. Part 6.3.

 Null when the identity does not match. The caller decides what to do, and a
 mismatch is a legitimate state of a correct program here — a walker of a
 heterogeneous list meets other types by design. Part 6.2.
*>
fn Type* from_inner(Handle h) @inline
{
    return is_mine(h) ? (Type*)((char*)h - OFF) : null;
}

<*
 The asserting crossing. Part 6.3.

 A mismatch is a defect of the program, not a runtime condition, so it is a
 tier 2 check and it compiles out in a fast build. Named apart from `from_inner`
 so a reader sees at the call site which one is meant.
*>
fn Type* must_from_inner(Handle h) @inline
{
    mtk::@check(is_mine(h), "must_from_inner: the handle is not of this type");
    return (Type*)((char*)h - OFF);
}

<*
 The checking crossing from a Slot. Part 7.2.

 The Slot is untouched either way. This is a look, not a take.
*>
fn Type* from_slot(Slot* s) @inline => from_inner(s.peek());

<*
 The asserting crossing from a Slot. Part 7.2. The Slot is untouched.
*>
fn Type* must_from_slot(Slot* s) @inline => must_from_inner(s.peek());

<*
 The moving crossing. Part 7.2, and the one member with two postconditions.

 On a match: the typed pointer is returned AND the Slot is cleared.
 On a mismatch: null is returned AND the Slot is untouched — Part 9.2 rule 4,
 a failing acquisition leaves the Slot unchanged.

 Both halves are tested. Neither is optional.
*>
fn Type* move_from_slot(Slot* s)
{
    if (!is_mine(s.peek())) return null;
    return (Type*)((char*)s.take() - OFF);
}
