<*
 Cleanup for a received outer covers the fault path and the normal one alike.

 - Send a `Holder` to a mailbox.
 - Receive it into a Slot, with the release deferred first.
 - A closed mailbox reaches the same defer through the fault path.
*>
module shc::defer_for_received_outer;
import mtk;
import mtk::managed;
import mtk::mailbox;
import shc::outers;
import shc::helpers;
import std::time;

faultdef DEFER_RECEIVED_FAILED;

fn void receive_and_release(Mailbox* mb, Duration timeout)
{
    Slot s;
    defer mtk::managed::release(Holder, &s);
    if (catch mb.receive(&s, timeout)) return;
    s.must(Holder).id++;
}

fn void? defer_covers_both_paths(Allocator a)
{
    Mailbox* mb = mtk::mailbox::create(a)!;
    defer { InnerQueue left; mb.close(&left); mb.release(); }

    Slot sent;
    defer mtk::managed::release(Holder, &sent);
    mtk::managed::create(Holder, a, &sent)!;
    mb.send(&sent)!;

    receive_and_release(mb, time::ms(100));            // the normal path: the outer is released after use
    receive_and_release(mb, time::ms(1));               // the fault path: TIMEOUT, and the empty Slot's defer does nothing
}
