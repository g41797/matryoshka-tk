<*
 Shared types for the negative programs. No aliases — H0.

 A negative program provokes one contract violation and is expected to ABORT
 in a checking build. In a fast build the same program must run to the end and
 exit 0, because D6 tier 2 compiles the check out entirely rather than handing
 the optimizer an assumption.

 Both halves are the test. A build where the violation is undefined behaviour
 rather than a compiled-out check is exactly what 3TK-4's Q11 probe found, and
 exactly what this port exists to avoid.
*>
module neg;
import mtk;
import mtk::pool;

struct Msg { int id; Inner inner; }
struct Job { Inner inner; int pri; }

<*
 A minimal hook object for the container negatives. Part 12.1: the implementing
 object is the context.
*>
struct NullHooks (PoolHooks)
{
    int unused;
}

fn void NullHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic { }
fn void NullHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic { }
fn void NullHooks.on_close(&self, InnerQueue remaining) @dynamic { }
