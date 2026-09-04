<*
 Part 11.12 MUST — the straggler path is covered too. **Tier 1.**

 Part 12.2: a `put` whose `on_put` ran while the pool was being closed hands
 its outers to `on_close` itself, from inside `put`. That second hook call is
 application code running after the close has already finished, and a count
 that stopped at `on_put` would report zero while it ran.

 So this program lowers nothing until the straggler hook has returned: the
 `on_put` hook parks, the main thread closes, and the `put` wakes to find the
 pool closed and calls `on_close` with its own outer. The release runs there.

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

struct StragglerHooks (PoolHooks)
{
    Atomic{usz} in_put;       // the put is in on_put
    Atomic{usz} closed;       // the main thread has closed
    Atomic{usz} straggling;   // the put is in the straggler on_close
    Atomic{usz} go;           // the main thread is about to release
}

fn void StragglerHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic { }

fn void StragglerHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic
{
    // keep the outer, so the close that arrives meanwhile makes it a straggler
    self.in_put.store(1, RELEASE);
    while (self.closed.load(ACQUIRE) == 0) thread::sleep(time::ms(1))!!;
}

fn void StragglerHooks.on_close(&self, InnerQueue remaining) @dynamic
{
    bool straggler = !remaining.is_empty();
    while (Inner* inner = remaining.pop_front()) { }
    if (!straggler) return;             // the close's own call, which is empty here

    self.straggling.store(1, RELEASE);
    while (self.go.load(ACQUIRE) == 0) thread::sleep(time::ms(1))!!;
    thread::sleep(time::ms(200))!!;     // the release has run by now
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
    g.p.put(&s);
    return 0;
}

Msg one;

fn int main()
{
    StragglerHooks hooks;
    typeid[1] tags = { Msg::typeid };
    Pool* p = pool::create(mem, &tags, &hooks)!!;

    helper::init(&one);

    Giving g;
    g.p = p;
    g.outer = helper::to_inner(&one);

    Thread t;
    t.create(&giver, &g)!!;

    while (hooks.in_put.load(ACQUIRE) == 0) thread::sleep(time::ms(1))!!;

    p.close();                          // the close's own hook gets nothing
    hooks.closed.store(1, RELEASE);     // the put wakes, and strags

    while (hooks.straggling.load(ACQUIRE) == 0) thread::sleep(time::ms(1))!!;
    hooks.go.store(1, RELEASE);

    p.release();                        // <-- the violation: closed, not quiet

    io::printn("SOFTENED: a pool was released while a straggler hook was running");
    t.join()!!;
    return 0;
}
