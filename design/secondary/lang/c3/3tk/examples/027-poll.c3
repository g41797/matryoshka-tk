<*
 `poll` never waits. `EMPTY` says there was nothing there, not that anything
 went wrong.

 - Poll an empty mailbox and see `EMPTY`.
 - Send a `Holder`, then poll again and receive it.
*>
module exm::poll;
import mtk;
import mtk::managed;
import mtk::mailbox;
import exm::outers;
import exm::helpers;

faultdef POLL_FAILED;

fn void free_outer(Slot* s)
{
    if (s.is_empty()) return;
    if (s.to(Holder)) { mtk::managed::release(Holder, s); return; }
    unreachable("free_outer met an identity it was not written for");
}

fn void? poll_then_send_then_poll(Allocator a, Mailbox* mb)
{
    Slot s;
    if (catch f = mb.poll(&s))
    {
        exm::helpers::expect(POLL_FAILED, f == mtk::EMPTY, "an empty mailbox polls EMPTY")!;
    }
    else
    {
        return POLL_FAILED~;
    }

    Slot sent;
    mtk::managed::create(Holder, a, &sent)!;
    mb.send(&sent)!;

    Slot got;
    mb.poll(&got)!;
    exm::helpers::expect(POLL_FAILED, got.to(Holder) != null, "the polled outer is the Holder that was sent")!;
    free_outer(&got);
}
