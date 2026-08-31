<*
 A refused `send` did not happen — `send` returns `CLOSED` before it empties
 the Slot, so the outer is still the caller's to release.

 - Close a mailbox.
 - Try to send a `Holder` into it and see the send refused.
 - Release the Holder, since the mailbox never took it.
*>
module exm::release_a_refused_transfer;
import mtk;
import mtk::managed;
import mtk::mailbox;
import exm::outers;
import exm::helpers;

faultdef REFUSED_TRANSFER_FAILED;

fn void? send_or_release(Mailbox* mb, Slot* s)
{
    if (catch f = mb.send(s))
    {
        exm::helpers::expect(REFUSED_TRANSFER_FAILED, f == mtk::CLOSED, "a refused send fails CLOSED")!;
        exm::helpers::expect(REFUSED_TRANSFER_FAILED, s.is_full(), "a refused send leaves the outer with the caller")!;
        mtk::managed::release(Holder, s);
        return f~;
    }
}

fn void? refused_send_is_released_by_the_caller(Allocator a, Mailbox* mb)
{
    InnerQueue left;
    mb.close(&left);

    Slot s;
    mtk::managed::create(Holder, a, &s)!;

    if (catch send_or_release(mb, &s))
    {
        mb.release();
        return;
    }
    mb.release();
    return REFUSED_TRANSFER_FAILED~;
}
