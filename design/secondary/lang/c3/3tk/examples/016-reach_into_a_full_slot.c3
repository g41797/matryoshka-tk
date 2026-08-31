<*
 Inspection leaves the Slot full, ready for the next line.

 - Create a `Holder` into a Slot.
 - Reach in with `must` and set a field.
 - Send it from the same, still-full Slot.
 - Receive it back and release it.
*>
module shc::reach_into_a_full_slot;
import mtk;
import mtk::managed;
import mtk::mailbox;
import shc::outers;
import shc::helpers;
import std::time;

faultdef REACH_INTO_A_FULL_SLOT_FAILED;

fn void? reach_in_then_send(Allocator a, Mailbox* mb)
{
    Slot s;
    defer mtk::managed::release(Holder, &s);
    mtk::managed::create(Holder, a, &s)!;
    s.must(Holder).id = 42;
    shc::helpers::expect(REACH_INTO_A_FULL_SLOT_FAILED, s.is_full(), "reaching in with must() must leave the Slot full")!;
    mb.send(&s)!;

    Slot got;
    mb.receive(&got, time::ms(1000))!;
    mtk::managed::release(Holder, &got);
}
