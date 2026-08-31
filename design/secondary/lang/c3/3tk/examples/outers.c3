<*
 The demo outers shared by every example.

 `Event` puts the inner at offset zero.
 `Sensor` and `Holder` do not, and both cross exactly the same way.
 All three carry an `Allocator`, so all three may take `mtk::managed`.
*>
module shc::outers;
import mtk;
import std::core::mem::alloc;

struct Event  { Inner node; int code; Allocator alloc; }
struct Sensor { int reading; Inner node; Allocator alloc; }
struct Holder { int id; Inner node; Allocator alloc; }
