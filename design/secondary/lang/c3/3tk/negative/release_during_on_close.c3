<*
 Part 11.12 MUST — the count covers `close`, not only the calls that look like
 work. **Tier 1.**

 `Pool.close` publishes CLOSED, opens the mutex, and then runs `on_close` with
 everything the pool held. That hook is application code holding pool-derived
 outers, and the close has not returned while it runs. A release that ran there
 would free the block under it.

 So the closing thread is not the releasing thread here: `on_close` parks, and
 a second thread releases. The pool is closed — `is_closed` says so — and it is
 not quiet.

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
    Atomic{usz} inside;      // the close is in on_close
    Atomic{usz} go;          // the main thread is about to release
}

fn void ParkingHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic { }
fn void ParkingHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic { }

fn void ParkingHooks.on_close(&self, InnerQueue remaining) @dynamic
{
    while (Inner* inner = remaining.pop_front()) { }
    self.inside.store(1, RELEASE);
    while (self.go.load(ACQUIRE) == 0) thread::sleep(time::ms(1))!!;
    thread::sleep(time::ms(200))!!;     // the release has run by now
}

fn int closer(void* arg)
{
    Pool* p = (Pool*)arg;
    p.close();                          // parks inside on_close
    return 0;
}

fn int main()
{
    ParkingHooks hooks;
    typeid[1] tags = { Msg::typeid };
    Pool* p = pool::create(mem, &tags, &hooks)!!;

    Thread t;
    t.create(&closer, p)!!;

    while (hooks.inside.load(ACQUIRE) == 0) thread::sleep(time::ms(1))!!;
    hooks.go.store(1, RELEASE);

    p.release();                        // <-- the violation: closed, not quiet

    io::printn("SOFTENED: a pool was released while its close hook was running");
    t.join()!!;
    return 0;
}
