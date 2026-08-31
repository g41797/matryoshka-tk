<*
 `receive_all` takes one lock instead of one per outer, and the outers it
 hands back belong to the caller from that moment on.

 - Send three `Holder`s.
 - Drain them all in one call.
 - Release each one.
*>
module exm::receive_all;
import mtk;
import mtk::managed;
import mtk::mailbox;
import exm::outers;
import exm::helpers;

faultdef RECEIVE_ALL_FAILED;

fn void? send_three(Allocator a, Mailbox* mb)
{
    for (int i = 0; i < 3; i++)
    {
        Slot s;
        mtk::managed::create(Holder, a, &s)!;
        mb.send(&s)!;
    }
}

fn void? receive_all_at_once(Allocator a, Mailbox* mb)
{
    send_three(a, mb)!;

    InnerQueue batch;
    mb.receive_all(&batch)!;

    usz count = 0;
    while (Handle h = batch.pop_front())
    {
        Slot s;
        s.fill(h);
        exm::helpers::expect(RECEIVE_ALL_FAILED, s.to(Holder) != null, "every drained outer is the Holder that was sent")!;
        mtk::managed::release(Holder, &s);
        count++;
    }
    exm::helpers::expect(RECEIVE_ALL_FAILED, count == 3, "all three outers came back in one call")!;
}
