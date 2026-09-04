<*
 Acquiring from a pool: the defer goes before the get.

 - Register the return-to-pool cleanup first.
 - Get a `Holder` from the pool.
 - Set a field.
 - Let the deferred `put` give it back.
*>
module shc::defer_put_early;
import mtk;
import mtk::managed;
import mtk::pool;
import shc::outers;
import shc::helpers;

faultdef DEFER_PUT_EARLY_FAILED;

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

fn void? get_from_a_pool(Pool* p)
{
    Slot s;
    defer p.put(&s);                                    // nothing to do if the get failed
    p.get(Holder::typeid, AVAILABLE_OR_NEW, &s)!;
    s.must(Holder).id = 1;
}

fn void? defer_put_goes_before_the_get(Allocator a)
{
    AlwaysCreateHooks hooks = { .alloc = a };
    typeid[1] tags = { Holder::typeid };
    Pool* p = mtk::pool::create(a, &tags, &hooks)!;
    defer { p.close(); p.release(); }

    get_from_a_pool(p)!;
    shc::helpers::expect(DEFER_PUT_EARLY_FAILED, p.count_of(Holder::typeid) == 1, "the pool did not get its Holder back")!;
}
