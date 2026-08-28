<*
 Part 11.12 MUST — closed is not quiet, the parked-getter half. **Tier 1.**

 `release_open_pool.c3` proves that an OPEN pool cannot be released. This one
 proves the harder half, and it is the pool's counterpart to
 `release_while_receiving.c3`: a pool that has been closed properly still
 cannot be released while a `get_wait` that the close woke has not yet come
 back to its caller.

 This is deterministic rather than a race: the getter publishes that it is about
 to park, and the main thread gives it time to get inside `wait_until` before
 closing. There is no interleaving in which the getter has returned.

 Like every tier 1 program it must abort in all four builds, including
 `--safe=no -O3`. If it ever prints its last line, the port has softened a MUST.
*>
module neg;
import mtk;
import mtk::pool;
import std::io;
import std::thread;
import std::time;
import std::core::mem::alloc;
import std::atomic::types;

struct Parked
{
    Pool*       p;
    Atomic{usz} waiting;
}

fn int getter(void* arg)
{
    Parked* k = (Parked*)arg;
    Slot got;
    k.waiting.store(1, RELEASE);
    if (catch f = k.p.get_wait(Msg::typeid, &got, time::sec(30))) { return 0; }
    return 0;
}

fn int main()
{
    NullHooks hooks;
    typeid[1] tags = { Msg::typeid };
    Pool* p = pool::create(mem, &tags, &hooks)!!;

    Parked k;
    k.p = p;

    Thread t;
    t.create(&getter, &k)!!;

    while (k.waiting.load(ACQUIRE) == 0) thread::sleep(time::ms(1))!!;
    thread::sleep(time::ms(100))!!;      // it is inside wait_until by now

    p.close();                           // CLOSED, and the getter is woken

    p.release();                         // <-- the violation: closed, not quiet

    io::printn("SOFTENED: a pool that was not quiet was released");
    t.join()!!;
    return 0;
}
