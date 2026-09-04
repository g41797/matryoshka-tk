<*
 A coordinator sequences discrete steps, and its own body says so in one
 glance — no step reaches around another to touch a `Slot` or an inner.

 - Seed the work: pull outers from the pool and send them to the mailbox.
 - Process the work: receive each outer, put it back, and count it.
 - Shut down: close the mailbox, put back what it kept, then close the pool.
*>
module shc::the_coordinator;
import mtk;
import mtk::managed;
import mtk::mailbox;
import mtk::pool;
import shc::outers;
import shc::helpers;
import std::time;

faultdef THE_COORDINATOR_FAILED;

struct CoordinatorHooks (PoolHooks) { Allocator alloc; }

fn void CoordinatorHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic
{
    if (catch mtk::managed::create(Holder, self.alloc, slot)) return;
}

fn void CoordinatorHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic {}

fn void CoordinatorHooks.on_close(&self, InnerQueue remaining) @dynamic
{
    while (Inner* inner = remaining.pop_front())
    {
        Slot s;
        s.fill(inner);
        mtk::managed::release(Holder, &s);
    }
}

struct Master
{
    Allocator alloc;
    Mailbox*  mbx;
    Pool*     pool;
    usz       processed;
}

fn void? Master.seed_the_work(&self)
{
    for (usz i = 0; i < 3; i++)
    {
        Slot s;
        self.pool.get(Holder::typeid, AVAILABLE_OR_NEW, &s)!;
        self.mbx.send(&s)!;
    }
}

fn void? Master.process_the_work(&self)
{
    for (usz i = 0; i < 3; i++)
    {
        Slot s;
        self.mbx.receive(&s, time::ms(2000))!;
        self.pool.put(&s);
        self.processed++;
    }
}

fn void Master.shut_down(&self)
{
    InnerQueue left;
    self.mbx.close(&left);
    while (Inner* inner = left.pop_front())
    {
        Slot s;
        s.fill(inner);
        self.pool.put(&s);
    }
    self.mbx.release();
    self.pool.close();
    self.pool.release();
}

fn void? Master.run(&self)
{
    self.seed_the_work()!;
    self.process_the_work()!;
    self.shut_down();
    if (self.processed == 0) return THE_COORDINATOR_FAILED~;
}
