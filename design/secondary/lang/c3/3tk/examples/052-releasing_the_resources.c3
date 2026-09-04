<*
 `close` and `release` are two calls in 3tk, and the pool's `close` gives
 nothing back — `on_close` gets everything kept.

 - Build a `Master` that owns an allocation, a mailbox and a pool.
 - Take it down in reverse acquisition order, walking the mailbox's
   remainder itself and leaving the pool's to its hook.
*>
module shc::releasing_the_resources;
import mtk;
import mtk::managed;
import mtk::mailbox;
import mtk::pool;
import shc::outers;
import shc::helpers;
import std::core::mem::alloc;

faultdef RELEASING_THE_RESOURCES_FAILED;

struct ReleaseHooks (PoolHooks) { Allocator alloc; int closed_count; }

fn void ReleaseHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic
{
    if (catch mtk::managed::create(Holder, self.alloc, slot)) return;
}

fn void ReleaseHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic {}

fn void ReleaseHooks.on_close(&self, InnerQueue remaining) @dynamic
{
    while (Inner* h = remaining.pop_front())
    {
        Slot s;
        s.fill(h);
        mtk::managed::release(Holder, &s);
        self.closed_count++;
    }
}

struct Master
{
    Allocator   alloc;
    Mailbox*    mbx;
    Pool*       pool;
    ReleaseHooks* hooks;
}

fn void Master.shut_down(&self)
{
    InnerQueue left;
    self.mbx.close(&left);
    while (Inner* h = left.pop_front())
    {
        Slot s;
        s.fill(h);
        mtk::managed::release(Holder, &s);
    }
    self.mbx.release();

    self.pool.close();                 // on_close gets everything kept
    self.pool.release();
    alloc::free(self.alloc, self);
}

fn void? reverse_acquisition_order(Allocator a)
{
    ReleaseHooks* hooks = alloc::new_try(a, ReleaseHooks)!;
    hooks.alloc = a;
    defer alloc::free(a, hooks);

    typeid[1] ids = { Holder::typeid };
    Master* m = alloc::new_try(a, Master)!;
    m.alloc = a;
    m.hooks = hooks;
    m.mbx = mtk::mailbox::create(a)!;
    m.pool = mtk::pool::create(a, &ids, hooks)!;

    Slot kept;
    m.pool.get(Holder::typeid, AVAILABLE_OR_NEW, &kept)!;
    m.pool.put(&kept);                 // stays in the pool's free list

    Slot pending;
    m.pool.get(Holder::typeid, NEW_ONLY, &pending)!;   // a second, distinct outer — AVAILABLE_OR_NEW would reuse "kept"
    m.mbx.send(&pending)!;             // left in the mailbox at shutdown

    m.shut_down();
    shc::helpers::expect(RELEASING_THE_RESOURCES_FAILED, hooks.closed_count == 1, "the pool's remainder reached on_close; the mailbox's remainder is what shut_down walked itself")!;
}
