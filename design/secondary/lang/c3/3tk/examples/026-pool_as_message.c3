<*
 A pool is an outer too: sharing its pointer shares the reuse policy that
 was set up at creation.

 - Send a pool's identity through a mailbox.
 - Receive it and confirm the pointer matches, hooks and all.
*>
module exm::pool_as_message;
import mtk;
import mtk::mailbox;
import mtk::pool;
import exm::outers;
import exm::helpers;
import std::time;

faultdef POOL_AS_MESSAGE_FAILED;

struct NoopHooks (PoolHooks) { bool _unused; }

fn void NoopHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic {}
fn void NoopHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic {}
fn void NoopHooks.on_close(&self, InnerQueue remaining) @dynamic {}

fn void? send_pool(Mailbox* to, Pool* p)
{
    Slot s;
    s.fill(mtk::pool::to_handle(p));
    to.send(&s)!;
}

fn void? a_travelling_pool_carries_its_policy(Allocator a)
{
    Mailbox* to = mtk::mailbox::create(a)!;
    defer { InnerQueue left; to.close(&left); to.release(); }

    NoopHooks hooks;
    typeid[1] tags = { Holder::typeid };
    Pool* p = mtk::pool::create(a, &tags, &hooks)!;
    defer { p.close(); p.release(); }

    send_pool(to, p)!;

    Slot s;
    to.receive(&s, time::ms(1000))!;
    Pool* got = mtk::pool::of(s.peek());

    exm::helpers::expect(POOL_AS_MESSAGE_FAILED, got == p, "the pool that arrives must be the one that was sent")!;
}
