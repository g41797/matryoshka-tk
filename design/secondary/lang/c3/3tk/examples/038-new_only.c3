<*
 `NEW_ONLY` never takes a kept outer, even when one is free.

 - Put one `Holder` back into the pool.
 - Get with `NEW_ONLY`: the hook runs, and the pool now holds two.
*>
module shc::new_only;
import mtk;
import mtk::managed;
import mtk::pool;
import shc::outers;
import shc::helpers;

faultdef NEW_ONLY_FAILED;

struct CountingHooks (PoolHooks) { Allocator alloc; int created; }

fn void CountingHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic
{
    self.created++;
    if (catch mtk::managed::create(Holder, self.alloc, slot)) return;
}

fn void CountingHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic {}

fn void CountingHooks.on_close(&self, InnerQueue remaining) @dynamic
{
    while (Inner* h = remaining.pop_front())
    {
        Slot s;
        s.fill(h);
        mtk::managed::release(Holder, &s);
    }
}

fn void? new_ignores_what_is_kept(Allocator a)
{
    CountingHooks hooks;
    hooks.alloc = a;
    typeid[1] tags = { Holder::typeid };
    Pool* p = mtk::pool::create(a, &tags, &hooks)!;
    defer { p.close(); p.release(); }

    Slot seed;
    p.get(Holder::typeid, NEW_ONLY, &seed)!;
    p.put(&seed);
    shc::helpers::expect(NEW_ONLY_FAILED, hooks.created == 1, "the seed itself came from the hook")!;

    Slot s;
    p.get(Holder::typeid, NEW_ONLY, &s)!;
    defer p.put(&s);
    shc::helpers::expect(NEW_ONLY_FAILED, hooks.created == 2, "NEW_ONLY must ask the hook even though one outer was kept")!;
}
