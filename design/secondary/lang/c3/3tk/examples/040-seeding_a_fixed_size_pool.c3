<*
 The seed count becomes the backpressure limit: an `on_get` that leaves the
 Slot empty once the seed is exhausted makes the pool never grow past it.

 - Seed a fixed size.
 - `AVAILABLE_OR_NEW` past the seed reports `NOT_CREATED`.
*>
module exm::seeding_a_fixed_size_pool;
import mtk;
import mtk::managed;
import mtk::pool;
import exm::outers;
import exm::helpers;

faultdef SEEDING_A_FIXED_SIZE_POOL_FAILED;

struct CappedHooks (PoolHooks) { Allocator alloc; usz cap; usz live; }

fn void CappedHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic
{
    if (self.live >= self.cap) return; // empty Slot -> NOT_CREATED
    if (catch mtk::managed::create(Holder, self.alloc, slot)) return;
    self.live++;
}

fn void CappedHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic {}

fn void CappedHooks.on_close(&self, InnerQueue remaining) @dynamic
{
    while (Handle h = remaining.pop_front())
    {
        Slot s;
        s.fill(h);
        self.live--;
        mtk::managed::release(Holder, &s);
    }
}

fn void? seed(Pool* p, Allocator a, usz n)
{
    for (usz i = 0; i < n; i++)
    {
        Slot s;
        defer mtk::managed::release(Holder, &s);
        mtk::managed::create(Holder, a, &s)!;
        p.put(&s); // the defer releases it only if the pool refused
    }
}

fn void? seed_caps_the_pool(Allocator a)
{
    CappedHooks hooks;
    hooks.alloc = a;
    hooks.cap = 2;
    typeid[1] tags = { Holder::typeid };
    Pool* p = mtk::pool::create(a, &tags, &hooks)!;
    defer { p.close(); p.release(); }

    seed(p, a, 2)!;
    hooks.live = 2;

    Slot s1;
    p.get(Holder::typeid, AVAILABLE_OR_NEW, &s1)!;
    defer p.put(&s1);
    Slot s2;
    p.get(Holder::typeid, AVAILABLE_OR_NEW, &s2)!;
    defer p.put(&s2);

    Slot s3;
    if (catch f = p.get(Holder::typeid, AVAILABLE_OR_NEW, &s3))
    {
        exm::helpers::expect(SEEDING_A_FIXED_SIZE_POOL_FAILED, f == mtk::NOT_CREATED, "past the seed the hook must report NOT_CREATED")!;
        return;
    }
    return SEEDING_A_FIXED_SIZE_POOL_FAILED~;
}
