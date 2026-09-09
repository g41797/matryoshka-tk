<*
 Cleanup for a received outer covers the fault path and the normal one alike.

 - Send a `Holder` to a mailbox.
 - Receive it into a Slot, with the release deferred first.
 - A closed mailbox reaches the same defer through the fault path.
*>
module shc::b_cleanup::defer_for_received_outer;
import mtk;
import mtk::mailbox;
import shc::outers;
import shc::helpers;
import std::time;

alias HOLDER = helper::OF{Holder};

faultdef DEFER_RECEIVED_FAILED;

fn void receive_and_release(Allocator a, Mailbox* mb, Duration timeout)
{
    Slot s;
    defer HOLDER.release(a, &s);
    if (catch mb.receive(&s, timeout)) return;
    HOLDER.must_look(&s).id++;
}

fn void? defer_covers_both_paths(Allocator a)
{
    Mailbox* mb = mtk::mailbox::create(a)!;
    defer { InnerQueue left; mb.close(&left); mb.release(); }

    Slot sent;
    defer HOLDER.release(a, &sent);
    HOLDER.create(a, &sent)!;
    mb.send(&sent)!;

    receive_and_release(a, mb, time::ms(100));            // the normal path: the outer is released after use
    receive_and_release(a, mb, time::ms(1));               // the fault path: TIMEOUT, and the empty Slot's defer does nothing
}
