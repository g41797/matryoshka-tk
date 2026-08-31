<*
 A wrapper carries what the endpoint alone cannot: a job id beside the
 mailbox.

 - Wrap an inbox mailbox with a job id in a `WorkerInbox`.
 - Send the wrapper.
 - Receive it back and confirm both the endpoint and the job id crossed.
*>
module shc::infrastructure_wrapper;
import mtk;
import mtk::managed;
import mtk::mailbox;
import shc::helpers;
import std::time;

faultdef INFRASTRUCTURE_WRAPPER_FAILED;

struct WorkerInbox
{
    Inner       node;
    Allocator   alloc;
    Mailbox*    mbx;
    int         job_id;
}

fn void? wrap_and_send(Allocator a, Mailbox* to, Mailbox* inbox, int job_id)
{
    Slot s;
    defer mtk::managed::release(WorkerInbox, &s);
    mtk::managed::create(WorkerInbox, a, &s)!;

    WorkerInbox* w = s.must(WorkerInbox);
    w.mbx = inbox;
    w.job_id = job_id;

    to.send(&s)!;
}

fn void? wrapper_carries_the_job_id(Allocator a, Mailbox* to, Mailbox* inbox)
{
    wrap_and_send(a, to, inbox, 42)!;

    Slot s;
    defer mtk::managed::release(WorkerInbox, &s);
    to.receive(&s, time::ms(1000))!;

    WorkerInbox* w = s.must(WorkerInbox);
    shc::helpers::expect(INFRASTRUCTURE_WRAPPER_FAILED, w.mbx == inbox, "the wrapper must carry the same inbox pointer")!;
    shc::helpers::expect(INFRASTRUCTURE_WRAPPER_FAILED, w.job_id == 42, "the wrapper must carry the job id")!;
}
