<*
 A worker signals it has finished by sending its own mailbox back; the
 master closes and releases it, then would join the thread.

 - The worker sends its mailbox to the master's inbox.
 - The master receives it and checks the instance, a real pointer compare.
 - The master drains, closes and releases the worker's mailbox.
*>
module shc::worker_finish_signal;
import mtk;
import mtk::managed;
import mtk::mailbox;
import shc::outers;
import shc::helpers;
import std::time;

faultdef WORKER_FINISH_SIGNAL_FAILED;

fn void free_outer(Slot* s)
{
    if (s.is_empty()) return;
    if (s.to(Holder)) { mtk::managed::release(Holder, s); return; }
    unreachable("free_outer met an identity it was not written for");
}

fn void? finish_signal(Mailbox* inbox, Mailbox* worker_mbx)
{
    Slot s;
    inbox.receive(&s, time::ms(1000))!;

    Mailbox* got = mtk::mailbox::of(s.take());
    if (got != worker_mbx) return WORKER_FINISH_SIGNAL_FAILED~;

    InnerQueue left;
    got.close(&left);
    while (Handle h = left.pop_front())
    {
        Slot each;
        each.fill(h);
        free_outer(&each);
    }
    got.release();
}

fn void? finish_signal_is_a_real_pointer_check(Allocator a)
{
    Mailbox* inbox = mtk::mailbox::create(a)!;
    defer { InnerQueue left; inbox.close(&left); inbox.release(); }

    Mailbox* worker_mbx = mtk::mailbox::create(a)!;

    Slot left_over;
    defer mtk::managed::release(Holder, &left_over);
    mtk::managed::create(Holder, a, &left_over)!;
    worker_mbx.send(&left_over)!;

    Slot s;
    s.fill(mtk::mailbox::to_handle(worker_mbx));
    inbox.send(&s)!;

    finish_signal(inbox, worker_mbx)!;
}
