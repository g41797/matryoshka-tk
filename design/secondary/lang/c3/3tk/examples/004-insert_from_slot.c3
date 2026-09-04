<*
 `push_back_slot` empties the Slot itself, so there is no line to forget.

 - Create a `Holder` into a Slot.
 - Set a field.
 - Push it onto a queue straight from the Slot.
 - Drain the queue and release what was pushed.
*>
module shc::insert_from_slot;
import mtk;
import mtk::managed;
import shc::outers;
import shc::helpers;

faultdef INSERT_FROM_SLOT_FAILED;

fn void? insert_from_a_slot(Allocator a)
{
    InnerQueue q;
    Slot s;
    defer mtk::managed::release(Holder, &s);
    mtk::managed::create(Holder, a, &s)!;
    s.must(Holder).id = 7;

    q.push_back_slot(&s);
    shc::helpers::expect(INSERT_FROM_SLOT_FAILED, s.is_empty(), "push_back_slot left the Slot full")!;

    while (Inner* h = q.pop_front())
    {
        Slot popped;
        popped.fill(h);
        mtk::managed::release(Holder, &popped);
    }
}
