<*
 `extra` is taken the same way the `Slot` is, with the same checks, so a
 composite outer's parts go back to their own free lists without a second
 call into the pool — a hook must never call back into the pool itself.

 - Get a `Holder` from a pool whose hooks track `on_put`.
 - Put it back and confirm the hook ran, with `extra` left empty because
   this outer carries no parts of its own.
*>
module exm::composite_outer_gives_back;
import mtk;
import mtk::managed;
import mtk::pool;
import exm::outers;
import exm::helpers;

faultdef A_COMPOSITE_OUTER_GIVES_BACK_ITS_PARTS_FAILED;

struct PartHooks (PoolHooks) { Allocator alloc; int on_put_calls; }

fn void PartHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic
{
    if (catch mtk::managed::create(Holder, self.alloc, slot)) return;
}

fn void PartHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic
{
    Holder* h = slot.must(Holder);
    h.id = 0;
    self.on_put_calls++;
    // a composite outer would push its parts onto `extra` here; this one
    // carries none, so `extra` stays empty.
}

fn void PartHooks.on_close(&self, InnerQueue remaining) @dynamic
{
    while (Handle h = remaining.pop_front())
    {
        Slot s;
        s.fill(h);
        mtk::managed::release(Holder, &s);
    }
}

fn void? extra_is_taken_the_same_way_as_the_slot(Allocator a)
{
    PartHooks hooks;
    hooks.alloc = a;
    typeid[1] tags = { Holder::typeid };
    Pool* p = mtk::pool::create(a, &tags, &hooks)!;
    defer { p.close(); p.release(); }

    Slot s;
    p.get(Holder::typeid, AVAILABLE_OR_NEW, &s)!;
    p.put(&s);
    exm::helpers::expect(A_COMPOSITE_OUTER_GIVES_BACK_ITS_PARTS_FAILED, hooks.on_put_calls == 1, "on_put ran once for the outer put back")!;
}
