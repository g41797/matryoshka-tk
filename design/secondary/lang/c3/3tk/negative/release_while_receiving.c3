<*
 Part 11.12 MUST — closed is not quiet. **Tier 1, the same as its neighbour.**

 `release_open_mailbox.c3` proves that an OPEN mailbox cannot be released. This
 one proves the harder half: a mailbox that has been closed properly can still
 not be released, while a call on it is in flight.

 A receiver is parked inside `receive`, which waits with the mutex released. The
 main thread closes — which wakes it — and releases without waiting for it to
 come back. The tool is closed. It is not quiet, and `release` says so.

 This is deterministic rather than a race: the receiver publishes that it is
 about to park, and the main thread gives it time to get inside `wait_until`
 before closing. There is no interleaving in which the receiver has returned.

 Like every tier 1 program it must abort in all four builds, including
 `--safe=no -O3`. If it ever prints its last line, the port has softened a MUST.
*>
module neg;
import mtk;
import mtk::mailbox;
import std::io;
import std::thread;
import std::time;
import std::core::mem::alloc;
import std::atomic::types;

struct Parked
{
    Mailbox*     mb;
    Atomic{usz}  waiting;
}

fn int receiver(void* arg)
{
    Parked* p = (Parked*)arg;
    Slot got;
    p.waiting.store(1, RELEASE);
    if (catch f = p.mb.receive(&got, time::sec(30))) { return 0; }
    return 0;
}

fn int main()
{
    Mailbox* mb = mailbox::create(mem)!!;

    Parked p;
    p.mb = mb;

    Thread t;
    t.create(&receiver, &p)!!;

    while (p.waiting.load(ACQUIRE) == 0) thread::sleep(time::ms(1))!!;
    thread::sleep(time::ms(100))!!;      // it is inside wait_until by now

    InnerQueue left;
    mb.close(&left);                     // CLOSED, and the receiver is woken

    mb.release();                        // <-- the violation: closed, not quiet

    io::printn("SOFTENED: a mailbox that was not quiet was released");
    t.join()!!;
    return 0;
}
