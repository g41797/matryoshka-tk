<*
 `AVAILABLE_OR_NEW` reuses a kept outer, and only asks the hook when none is
 kept.

 - Seed the pool with one `Holder` and put it back.
 - Get with `AVAILABLE_OR_NEW`: the kept outer comes back, the hook does not run.
 - Put it back, get again: still the same outer, the hook still has not run.
*>
module shc::available_or_new;
import mtk;
import mtk::managed;
import mtk::pool;
import shc::outers;
import shc::helpers;

faultdef AVAILABLE_OR_NEW_FAILED;

struct CountingHooks (PoolHooks) { Allocator alloc; int created; }

fn void CountingHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic
{
    self.created++;
    if (catch mtk::managed::create(Holder, self.alloc, slot)) return;
}

fn void CountingHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic {}

fn void CountingHooks.on_close(&self, InnerQueue remaining) @dynamic
{
    while (Inner* inner = remaining.pop_front())
    {
        Slot s;
        s.fill(inner);
        mtk::managed::release(Holder, &s);
    }
}

fn void? reuse_before_create(Allocator a)
{
    CountingHooks hooks;
    hooks.alloc = a;
    typeid[1] tags = { Holder::typeid };
    Pool* p = mtk::pool::create(a, &tags, &hooks)!;
    defer { p.close(); p.release(); }

    Slot s;
    p.get(Holder::typeid, AVAILABLE_OR_NEW, &s)!;
    shc::helpers::expect(AVAILABLE_OR_NEW_FAILED, hooks.created == 1, "the first get has nothing kept, so the hook must run")!;
    p.put(&s);

    Slot s2;
    p.get(Holder::typeid, AVAILABLE_OR_NEW, &s2)!;
    shc::helpers::expect(AVAILABLE_OR_NEW_FAILED, hooks.created == 1, "a kept outer must be reused, so the hook must not run again")!;
    p.put(&s2);
}
