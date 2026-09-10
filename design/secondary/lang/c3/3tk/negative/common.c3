<*
 Shared types for the negative programs.

 No aliases here: a negative program that needs one declares it beside its own
 struct, so that the line under test is in the body and not at an alias.

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
import std::core::mem::alloc;

struct Msg
{
	int id;
	Inner inner;
}
struct Job
{
	Inner inner;
	int pri;
}

// The two hooks 3TK-74 made required of every outer the helper creates.
// Neither type sets anything up or winds anything down, so both bodies of both
// are empty — which is how a type says it needs neither, out loud.
fn void? Msg.init(&self, Allocator a) { return; }
fn void  Msg.finish(&self, Allocator a) { }
fn void? Job.init(&self, Allocator a) { return; }
fn void  Job.finish(&self, Allocator a) { }

<*
 A minimal hook object for the container negatives. Part 12.1: the implementing
 object is the context.
*>
struct NullHooks (PoolHooks)
{
	int unused;
}

fn void NullHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic
{
}
fn void NullHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic
{
}
fn void NullHooks.on_close(&self, InnerQueue remaining) @dynamic
{
}