<*
 The mailbox does the merging. There is no separate synchronization to write.

 - Three sender threads, two identities between them, send to one mailbox.
 - `receive_all` plus an outer-first chain empties it in one pass, mixed
   identities and all.
 - Count each identity that arrived.
*>
module shc::fan_in;
import mtk;
import mtk::managed;
import mtk::mailbox;
import shc::outers;
import shc::helpers;
import std::thread;

faultdef FAN_IN_FAILED;

struct SenderArgs
{
    Mailbox* mbx;
    Allocator a;
    int code;
}

fn int send_event(void* arg)
{
    SenderArgs* args = (SenderArgs*)arg;
    Slot s;
    if (catch f = mtk::managed::create(Event, args.a, &s)) return 0;
    s.must(Event).code = args.code;
    if (catch f = args.mbx.send(&s)) mtk::managed::release(Event, &s);
    return 0;
}

fn int send_holder(void* arg)
{
    SenderArgs* args = (SenderArgs*)arg;
    Slot s;
    if (catch f = mtk::managed::create(Holder, args.a, &s)) return 0;
    if (catch f = args.mbx.send(&s)) mtk::managed::release(Holder, &s);
    return 0;
}

fn void? three_senders_one_mailbox(Allocator a, Mailbox* mbx)
{
    SenderArgs ea1 = { .mbx = mbx, .a = a, .code = 1 };
    SenderArgs ea2 = { .mbx = mbx, .a = a, .code = 2 };
    SenderArgs ha  = { .mbx = mbx, .a = a };

    Thread t1, t2, t3;
    t1.create(&send_event, &ea1)!!;
    t2.create(&send_event, &ea2)!!;
    t3.create(&send_holder, &ha)!!;

    t1.join()!!;
    t2.join()!!;
    t3.join()!!;

    InnerQueue batch;
    mbx.receive_all(&batch)!;

    int events = 0;
    int holders = 0;
    while (Handle h = batch.pop_front())
    {
        Slot s;
        s.fill(h);
        if (s.to(Event))  { mtk::managed::release(Event, &s);  events++;  continue; }
        if (s.to(Holder)) { mtk::managed::release(Holder, &s); holders++; continue; }
        unreachable("fan-in met an identity it was not written for");
    }

    shc::helpers::expect(FAN_IN_FAILED, events == 2, "both Event senders landed on the one mailbox")!;
    shc::helpers::expect(FAN_IN_FAILED, holders == 1, "the Holder sender landed on the same mailbox")!;
}
