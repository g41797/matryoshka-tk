<*
 Two mailboxes, never one. On one mailbox the caller could receive its own
 request back.

 - A worker loops on the request mailbox until it is closed.
 - The caller sends a request and blocks on the response mailbox, with a
   timeout.
 - The worker answers on the response mailbox, and the caller reads it.
*>
module shc::request_response;
import mtk;
import mtk::managed;
import mtk::mailbox;
import shc::outers;
import shc::helpers;
import std::thread;
import std::time;

faultdef REQUEST_RESPONSE_FAILED;

struct RRArgs
{
    Mailbox* req_mbx;
    Mailbox* resp_mbx;
}

fn int answer_one_request(void* arg)
{
    RRArgs* a = (RRArgs*)arg;
    Slot s;
    if (catch f = a.req_mbx.receive(&s, time::ms(2000))) return 0;
    Event* e = s.must(Event);
    e.code = e.code * 2;
    if (catch f = a.resp_mbx.send(&s)) mtk::managed::release(Event, &s);
    return 0;
}

fn void? one_request_one_response(Allocator a, Mailbox* req_mbx, Mailbox* resp_mbx)
{
    RRArgs args = { .req_mbx = req_mbx, .resp_mbx = resp_mbx };
    Thread worker;
    worker.create(&answer_one_request, &args)!!;

    Slot s;
    mtk::managed::create(Event, a, &s)!;
    s.must(Event).code = 21;
    req_mbx.send(&s)!;

    Slot reply;
    defer mtk::managed::release(Event, &reply);
    resp_mbx.receive(&reply, time::ms(2000))!;

    worker.join()!!;

    shc::helpers::expect(REQUEST_RESPONSE_FAILED, reply.must(Event).code == 42, "the response carries the doubled request")!;
}
