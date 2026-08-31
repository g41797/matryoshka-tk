<*
 A mailbox travels the same way any outer does, and travelling does not
 close it.

 - Send a second mailbox's identity through a first.
 - Receive it and confirm the pointer matches.
 - Confirm the travelling mailbox is still open.
*>
module exm::mailbox_as_message;
import mtk;
import mtk::mailbox;
import exm::helpers;
import std::time;

faultdef MAILBOX_AS_MESSAGE_FAILED;

fn void? send_mailbox(Mailbox* to, Mailbox* travelling)
{
    Slot s;
    s.fill(mtk::mailbox::to_handle(travelling));
    to.send(&s)!;
}

fn Mailbox* receive_mailbox(Slot* s) => mtk::mailbox::of(s.peek());

fn void? a_travelling_mailbox_stays_open(Allocator a)
{
    Mailbox* carrier = mtk::mailbox::create(a)!;
    defer { InnerQueue left; carrier.close(&left); carrier.release(); }

    Mailbox* travelling = mtk::mailbox::create(a)!;
    defer { InnerQueue left; travelling.close(&left); travelling.release(); }

    send_mailbox(carrier, travelling)!;

    Slot s;
    carrier.receive(&s, time::ms(1000))!;
    Mailbox* got = receive_mailbox(&s);

    exm::helpers::expect(MAILBOX_AS_MESSAGE_FAILED, got == travelling, "the mailbox that arrives must be the one that was sent")!;
    exm::helpers::expect(MAILBOX_AS_MESSAGE_FAILED, !got.is_closed(), "a mailbox that is travelling is still a working endpoint")!;
}
