<*
 Part 11.12 MUST — closed is not quiet, at the pool's worst site. **Tier 1.**

 Part 12.3 forbids holding the mutex across a call into application code, so
 `Pool.put` opens it around `on_put`. A release that runs in that window
 destroys the mutex and frees the block, and the `put` then re-takes a mutex
 that no longer exists. This is the defect the count was added for.

 The hook parks until the main thread has published that it is about to
 release, so the window is entered deliberately rather than raced for. The
 releasing thread then finds the pool closed and the count at one, and stops.

 Like every tier 1 program it must abort in all four builds, including
 `--safe=no -O3`. If it ever prints its last line, the port has softened a MUST.
*>
module neg;
import mtk;
import mtk::helper;
import mtk::pool;
import std::io;
import std::thread;
import std::time;
import std::core::mem::alloc;
import std::atomic::types;

struct ParkingHooks (PoolHooks)
{
    Atomic{usz} inside;      // the put is in on_put
    Atomic{usz} go;          // the main thread is about to release
}

fn void ParkingHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic { }

fn void ParkingHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic
{
    self.inside.store(1, RELEASE);
    while (self.go.load(ACQUIRE) == 0) thread::sleep(time::ms(1))!!;
    thread::sleep(time::ms(200))!!;     // the release has run by now
}

fn void ParkingHooks.on_close(&self, InnerQueue remaining) @dynamic
{
    while (Inner* inner = remaining.pop_front()) { }
}

struct Giving
{
    Pool*  p;
    Inner* outer;
}

fn int giver(void* arg)
{
    Giving* g = (Giving*)arg;
    Slot s;
    s.fill(g.outer);
    g.p.put(&s);                        // parks inside on_put
    return 0;
}

Msg one;

fn int main()
{
    ParkingHooks hooks;
    typeid[1] tags = { Msg::typeid };
    Pool* p = pool::create(mem, &tags, &hooks)!!;

    mtk::helper::init(&one);

    Giving g;
    g.p = p;
    g.outer = mtk::helper::to_inner(&one);

    Thread t;
    t.create(&giver, &g)!!;

    while (hooks.inside.load(ACQUIRE) == 0) thread::sleep(time::ms(1))!!;

    p.close();                          // CLOSED, and the put is still in its hook
    hooks.go.store(1, RELEASE);

    p.release();                        // <-- the violation: closed, not quiet

    io::printn("SOFTENED: a pool was released while a put was inside on_put");
    t.join()!!;
    return 0;
}
