<*
 `mailbox::create` and `pool::create` return a pointer, not a Slot. There is
 no acquisition Slot, no detach line, and no window between them to guard.

 - Build a `Master` whose fields are plain `Mailbox*` and `Pool*`.
 - Confirm neither is an optional and neither needs unwrapping.
*>
module shc::acquiring_the_resources;
import mtk;
import mtk::managed;
import mtk::mailbox;
import mtk::pool;
import shc::outers;
import shc::helpers;
import std::core::mem::alloc;

faultdef ACQUIRING_THE_RESOURCES_FAILED;

struct AcquireHooks (PoolHooks) { Allocator alloc; }

fn void AcquireHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic
{
    if (catch mtk::managed::create(Event, self.alloc, slot)) return;
}

fn void AcquireHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic {}

fn void AcquireHooks.on_close(&self, InnerQueue remaining) @dynamic
{
    while (Inner* inner = remaining.pop_front())
    {
        Slot s;
        s.fill(inner);
        mtk::managed::release(Event, &s);
    }
}

struct Master
{
    Allocator alloc;
    Mailbox*  mbx;
    Pool*     pool;
    usz       processed;
}

fn Master*? master_create(Allocator a, PoolHooks hooks)
{
    Master* self = alloc::new_try(a, Master)!;
    self.alloc = a;
    self.processed = 0;

    typeid[1] ids = { Event::typeid };
    self.mbx = mtk::mailbox::create(a)!;
    self.pool = mtk::pool::create(a, &ids, hooks)!;
    return self;
}

fn void? resources_are_plain_pointers(Allocator a)
{
    AcquireHooks hooks;
    hooks.alloc = a;
    Master* m = master_create(a, &hooks)!;

    shc::helpers::expect(ACQUIRING_THE_RESOURCES_FAILED, m.mbx != null, "the mailbox is a plain pointer, not a Slot")!;
    shc::helpers::expect(ACQUIRING_THE_RESOURCES_FAILED, m.pool != null, "the pool is a plain pointer, not a Slot")!;

    InnerQueue left;
    m.mbx.close(&left);
    m.mbx.release();
    m.pool.close();
    m.pool.release();
    alloc::free(a, m);
}
