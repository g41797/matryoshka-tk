<*
 The hook object is the context: no `ctx: *anyopaque`, no cast. The struct
 implementing `PoolHooks` reaches its own fields as `self.field`.

 - `on_get` reads `self.cap` and `self.live` with no cast.
 - `on_close` gives the remainder back to the same object.
*>
module shc::the_hook_object_is_the_context;
import mtk;
import mtk::managed;
import mtk::pool;
import shc::outers;
import shc::helpers;
import std::atomic::types;

faultdef HOOK_OBJECT_IS_THE_CONTEXT_FAILED;

struct CappedHooks (PoolHooks)
{
    Allocator     alloc;
    usz           cap;
    Atomic{usz}   live;
}

fn void CappedHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic
{
    if (self.live.load(ACQUIRE) >= self.cap) return; // empty Slot -> NOT_CREATED
    if (catch mtk::managed::create(Holder, self.alloc, slot)) return;
    self.live.add(1);
}

fn void CappedHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic
{
    Holder* h = slot.must(Holder);
    h.id = 0; // cleaned, and kept
}

fn void CappedHooks.on_close(&self, InnerQueue remaining) @dynamic
{
    while (Inner* h = remaining.pop_front())
    {
        Slot s;
        s.fill(h);
        self.live.sub(1);
        mtk::managed::release(Holder, &s);
    }
}

fn void? no_cast_needed(Allocator a)
{
    CappedHooks hooks;
    hooks.alloc = a;
    hooks.cap = 1;
    typeid[1] tags = { Holder::typeid };
    Pool* p = mtk::pool::create(a, &tags, &hooks)!;
    defer { p.close(); p.release(); }

    Slot s;
    p.get(Holder::typeid, AVAILABLE_OR_NEW, &s)!;
    s.must(Holder).id = 7;
    p.put(&s);

    shc::helpers::expect(HOOK_OBJECT_IS_THE_CONTEXT_FAILED, hooks.live.load(ACQUIRE) == 1, "the hook's own field must reflect what it did")!;
}
