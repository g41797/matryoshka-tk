<*
 A new outer type costs two lines: the struct, and the calls that use it.
 No alias, no helper instantiation, no registration list.

 - Create an `Event`, set its field, and send it.
 - Receive it back and confirm the field crossed unchanged.
*>
module shc::k_new_in_3tk::identity_costs_nothing;
import mtk;
import mtk::mailbox;
import shc::outers;
import shc::helpers;
import std::time;

alias EVENT  = helper::OF{Event};

faultdef AN_IDENTITY_COSTS_NO_REGISTRATION_FAILED;

fn void? a_new_type_costs_nothing(Allocator a, Mailbox* mb)
{
    Slot s;
    EVENT.create(a, &s)!;
    EVENT.must_look(&s).code = 1;
    mb.send(&s)!;

    Slot got;
    defer EVENT.release(a, &got);
    mb.receive(&got, time::ms(2000))!;
    shc::helpers::expect(AN_IDENTITY_COSTS_NO_REGISTRATION_FAILED, EVENT.must_look(&got).code == 1, "the new type crossed the mailbox unchanged")!;
}
