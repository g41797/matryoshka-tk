<*
 A cleanup on an empty Slot does nothing.

 - Acquire a pooled `Holder` and a heaped one.
 - Move the pooled one onto a queue, so its Slot is empty by the time cleanup runs.
 - Let both deferred cleanups run: one has nothing to do, one does.
*>
module shc::null_safe_cleanup;
import mtk;
import mtk::managed;
import mtk::pool;
import shc::outers;
import shc::helpers;

faultdef NULL_SAFE_CLEANUP_FAILED;

struct AlwaysCreateHooks (PoolHooks)
{
    Allocator alloc;
}

fn void AlwaysCreateHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic
{
    if (catch mtk::managed::create(Holder, self.alloc, slot)) return;
}

fn void AlwaysCreateHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic {}

fn void AlwaysCreateHooks.on_close(&self, InnerQueue remaining) @dynamic
{
    while (Inner* h = remaining.pop_front())
    {
        Slot s;
        s.fill(h);
        mtk::managed::release(Holder, &s);
    }
}

fn void? cleanup_survives_an_empty_slot(Allocator a)
{
    AlwaysCreateHooks hooks = { .alloc = a };
    typeid[1] tags = { Holder::typeid };
    Pool* p = mtk::pool::create(a, &tags, &hooks)!;
    defer { p.close(); p.release(); }

    InnerQueue q;
    defer
    {
        while (Inner* h = q.pop_front())
        {
            Slot s;
            s.fill(h);
            mtk::managed::release(Holder, &s);
        }
    }

    Slot pooled;
    defer p.put(&pooled);                       // no-op: the queue already took it
    p.get(Holder::typeid, AVAILABLE_OR_NEW, &pooled)!;
    q.push_back_slot(&pooled);
    shc::helpers::expect(NULL_SAFE_CLEANUP_FAILED, pooled.is_empty(), "the pooled Slot is not empty")!;

    Slot heaped;
    defer mtk::managed::release(Holder, &heaped);    // has work to do
    mtk::managed::create(Holder, a, &heaped)!;
}
