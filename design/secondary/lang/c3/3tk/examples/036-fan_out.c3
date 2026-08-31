<*
 The mailbox does the distribution. No round-robin in application code.

 - Several worker threads compete on one mailbox, each looping until it is
   closed.
 - The caller sends more outers than it lets the workers claim, then closes.
 - `close` gives back whatever no worker claimed, and the closer releases it
   — every time.
*>
module shc::fan_out;
import mtk;
import mtk::managed;
import mtk::mailbox;
import shc::outers;
import shc::helpers;
import std::thread;
import std::time;
import std::atomic::types;

faultdef FAN_OUT_FAILED;

struct WorkerArgs
{
    Mailbox* mbx;
    Atomic{int}* claimed;
}

fn int claim_until_closed(void* arg)
{
    WorkerArgs* a = (WorkerArgs*)arg;
    while (true)
    {
        Slot s;
        if (catch f = a.mbx.receive(&s, time::ms(2000))) return 0;
        mtk::managed::release(Holder, &s);
        a.claimed.add(1);
    }
}

fn void? each_outer_goes_to_exactly_one_worker(Allocator a, Mailbox* mbx)
{
    for (int i = 0; i < 6; i++)
    {
        Slot s;
        mtk::managed::create(Holder, a, &s)!;
        mbx.send(&s)!;
    }

    Atomic{int} claimed;
    claimed.store(0);
    WorkerArgs wargs = { .mbx = mbx, .claimed = &claimed };

    Thread w1, w2, w3;
    w1.create(&claim_until_closed, &wargs)!!;
    w2.create(&claim_until_closed, &wargs)!!;
    w3.create(&claim_until_closed, &wargs)!!;

    thread::sleep(time::ms(100))!!;   // give the workers time to claim what they can

    InnerQueue left;
    mbx.close(&left);

    w1.join()!!;
    w2.join()!!;
    w3.join()!!;

    int leftover = 0;
    while (Handle h = left.pop_front())
    {
        Slot s;
        s.fill(h);
        mtk::managed::release(Holder, &s);
        leftover++;
    }

    shc::helpers::expect(FAN_OUT_FAILED, claimed.load() + leftover == 6, "every outer was either claimed or came back from close")!;

    mbx.release();
}
