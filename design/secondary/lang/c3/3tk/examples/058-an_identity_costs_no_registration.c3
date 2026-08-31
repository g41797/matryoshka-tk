<*
 A new outer type costs two lines: the struct, and the calls that use it.
 No alias, no helper instantiation, no registration list.

 - Create an `Event`, set its field, and send it.
 - Receive it back and confirm the field crossed unchanged.
*>
module exm::identity_costs_nothing;
import mtk;
import mtk::managed;
import mtk::mailbox;
import exm::outers;
import exm::helpers;
import std::time;

faultdef AN_IDENTITY_COSTS_NO_REGISTRATION_FAILED;

fn void? a_new_type_costs_nothing(Allocator a, Mailbox* mb)
{
    Slot s;
    mtk::managed::create(Event, a, &s)!;
    s.must(Event).code = 1;
    mb.send(&s)!;

    Slot got;
    defer mtk::managed::release(Event, &got);
    mb.receive(&got, time::ms(2000))!;
    exm::helpers::expect(AN_IDENTITY_COSTS_NO_REGISTRATION_FAILED, got.must(Event).code == 1, "the new type crossed the mailbox unchanged")!;
}
