<*
 A refused `put` leaves the outer with the caller. Read the Slot.

 - Close a pool.
 - Try to put a `Holder` back into it.
 - The primary defer runs first and does nothing; the fallback releases it.
*>
module shc::refused_put_fallback;
import mtk;
import mtk::managed;
import mtk::pool;
import shc::outers;
import shc::helpers;

faultdef FALLBACK_RELEASE_FAILED;

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

fn void put_or_release(Pool* p, Slot* s)
{
    defer mtk::managed::release(Holder, s);   // fallback: runs only if the pool refused
    defer p.put(s);                           // primary: empties the Slot if the pool kept it
}

fn void? fallback_releases_what_the_pool_refused(Allocator a)
{
    AlwaysCreateHooks hooks = { .alloc = a };
    typeid[1] tags = { Holder::typeid };
    Pool* p = mtk::pool::create(a, &tags, &hooks)!;

    Slot s;
    mtk::managed::create(Holder, a, &s)!;

    p.close();

    shc::helpers::expect(FALLBACK_RELEASE_FAILED, s.is_full(), "the Holder is missing before the refused put")!;
    put_or_release(p, &s);
    shc::helpers::expect(FALLBACK_RELEASE_FAILED, s.is_empty(), "the fallback did not take the Holder")!;

    p.release();
}
