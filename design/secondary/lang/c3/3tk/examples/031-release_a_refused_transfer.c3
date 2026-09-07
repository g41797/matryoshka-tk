<*
 A refused `send` did not happen — `send` returns `CLOSED` before it empties
 the Slot, so the outer is still the caller's to release.

 - Close a mailbox.
 - Try to send a `Holder` into it and see the send refused.
 - Release the Holder, since the mailbox never took it.
*>
module shc::release_a_refused_transfer;
import mtk;
import mtk::mailbox;
import shc::outers;
import shc::helpers;

alias HOLDER = mtk::OF{Holder};

faultdef REFUSED_TRANSFER_FAILED;

fn void? send_or_release(Allocator a, Mailbox* mb, Slot* s)
{
    if (catch f = mb.send(s))
    {
        shc::helpers::expect(REFUSED_TRANSFER_FAILED, f == mtk::CLOSED, "a refused send fails CLOSED")!;
        shc::helpers::expect(REFUSED_TRANSFER_FAILED, s.is_full(), "a refused send leaves the outer with the caller")!;
        HOLDER.release(a, s);
        return f~;
    }
}

fn void? refused_send_is_released_by_the_caller(Allocator a, Mailbox* mb)
{
    InnerQueue left;
    mb.close(&left);

    Slot s;
    HOLDER.create(a, &s)!;

    if (catch send_or_release(a, mb, &s))
    {
        mb.release();
        return;
    }
    mb.release();
    return REFUSED_TRANSFER_FAILED~;
}
