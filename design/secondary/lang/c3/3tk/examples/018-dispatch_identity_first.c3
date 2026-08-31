<*
 Identity-first dispatch answers a bare `typeid`, with no outer to cross with.

 - Build a pool hook object that creates by identity alone.
 - Get one outer of each identity the pool was created with.
 - Close the pool and let `on_close` release what is left through the outer-first chain.
*>
module shc::dispatch_identity_first;
import mtk;
import mtk::managed;
import mtk::pool;
import shc::outers;
import shc::helpers;
import shc::dispatch_outer_first;

faultdef DISPATCH_IDENTITY_FIRST_FAILED;

struct CreateByIdentityHooks (PoolHooks)
{
    Allocator alloc;
}

fn void CreateByIdentityHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic
{
    if (want == Event::typeid)  { if (catch mtk::managed::create(Event,  self.alloc, slot)) {} return; }
    if (want == Sensor::typeid) { if (catch mtk::managed::create(Sensor, self.alloc, slot)) {} return; }
    if (want == Holder::typeid) { if (catch mtk::managed::create(Holder, self.alloc, slot)) {} return; }
    // an identity the pool was not created with never reaches here
}

fn void CreateByIdentityHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic {}

fn void CreateByIdentityHooks.on_close(&self, InnerQueue remaining) @dynamic
{
    while (Handle h = remaining.pop_front())
    {
        Slot s;
        s.fill(h);
        shc::dispatch_outer_first::free_outer(&s);
    }
}

fn void? get_one_of_each_then_close(Allocator a)
{
    CreateByIdentityHooks hooks = { .alloc = a };
    typeid[3] ids = { Event::typeid, Sensor::typeid, Holder::typeid };
    Pool* p = mtk::pool::create(a, &ids, &hooks)!;

    Slot s;
    p.get(Event::typeid, AVAILABLE_OR_NEW, &s)!;
    shc::helpers::expect(DISPATCH_IDENTITY_FIRST_FAILED, s.to(Event) != null, "on_get must fill the Slot with the identity asked for")!;
    p.put(&s);

    p.get(Sensor::typeid, AVAILABLE_OR_NEW, &s)!;
    shc::helpers::expect(DISPATCH_IDENTITY_FIRST_FAILED, s.to(Sensor) != null, "on_get must fill the Slot with the identity asked for")!;
    p.put(&s);

    p.get(Holder::typeid, AVAILABLE_OR_NEW, &s)!;
    shc::helpers::expect(DISPATCH_IDENTITY_FIRST_FAILED, s.to(Holder) != null, "on_get must fill the Slot with the identity asked for")!;
    p.put(&s);

    p.close();          // on_close dispatches the three kept outers through free_outer
    p.release();
}
