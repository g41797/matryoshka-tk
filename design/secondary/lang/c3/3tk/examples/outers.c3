<*
 The demo outers shared by every example.

 `Event` puts the inner at offset zero.
 `Sensor` and `Holder` do not, and both cross exactly the same way.

 All three declare an `init` hook that keeps the allocator they were made with.
 That is a choice each outer makes for itself, and not a rule.
 The toolkit reads no field of an outer except the `Inner`, and it never stores the allocator for you.
 An outer that has no use for one declares no hook and carries no such field.

 There is no alias here, and that is a language fact rather than a choice:
 C3 refuses an unprefixed alias from another module, so a shared alias would
 have to be written `outers::HOLDER` at every call.
 The alias is per-module ceremony, one line per outer type a module uses, and
 every example file below carries its own.
*>
module shc::outers;
import mtk;
import std::core::mem::alloc;

struct Event  { Inner inner; int code; Allocator alloc; }
struct Sensor { int reading; Inner inner; Allocator alloc; }
struct Holder { int id; Inner inner; Allocator alloc; }

fn void? Event.init(&self, Allocator a)  { self.alloc = a; return; }
fn void? Sensor.init(&self, Allocator a) { self.alloc = a; return; }
fn void? Holder.init(&self, Allocator a) { self.alloc = a; return; }
