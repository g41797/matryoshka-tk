<*
 One reuse policy, and a separate free list per identity.

 - Reuse entry 18's `CreateByIdentityHooks`, over the same three identities.
 - Get and put each identity; each keeps to its own list.
*>
module shc::a_pool_of_several_identities;
import mtk;
import mtk::pool;
import shc::outers;
import shc::helpers;
import shc::dispatch_identity_first;

faultdef POOL_OF_SEVERAL_IDENTITIES_FAILED;

fn void? one_policy_three_identities(Allocator a)
{
    shc::dispatch_identity_first::CreateByIdentityHooks hooks = { .alloc = a };
    typeid[3] ids = { Event::typeid, Sensor::typeid, Holder::typeid };
    Pool* p = mtk::pool::create(a, &ids, &hooks)!;
    defer { p.close(); p.release(); }

    Slot se;
    p.get(Event::typeid, AVAILABLE_OR_NEW, &se)!;
    p.put(&se);

    Slot ss;
    p.get(Sensor::typeid, AVAILABLE_OR_NEW, &ss)!;
    p.put(&ss);

    Slot sh;
    p.get(Holder::typeid, AVAILABLE_OR_NEW, &sh)!;
    p.put(&sh);

    shc::helpers::expect(POOL_OF_SEVERAL_IDENTITIES_FAILED, p.count_of(Event::typeid) == 1, "the Event free list must hold what was put back")!;
    shc::helpers::expect(POOL_OF_SEVERAL_IDENTITIES_FAILED, p.count_of(Sensor::typeid) == 1, "the Sensor free list must hold what was put back")!;
    shc::helpers::expect(POOL_OF_SEVERAL_IDENTITIES_FAILED, p.count_of(Holder::typeid) == 1, "the Holder free list must hold what was put back")!;
}
