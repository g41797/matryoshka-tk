<*
 A `switch` over a `typeid` is the one dispatch shape ztk cannot write.

 - Create one outer of each identity, in a Slot.
 - Take the handle and switch on its identity, asserting the prong's type.
 - Release the outer once the switch has touched it.
*>
module shc::dispatch_switch;
import mtk;
import mtk::managed;
import shc::outers;
import shc::helpers;

faultdef DISPATCH_SWITCH_FAILED;

fn void touch_by_switch(Inner* h)
{
    switch (h.link.type)
    {
        case Event::typeid:
            h.as(Event).code++;
        case Sensor::typeid:
            h.as(Sensor).reading++;
        case Holder::typeid:
            h.as(Holder).id++;
        default:
            unreachable("closed set: every identity is a prong");
    }
}

fn void? dispatch_by_switch(Allocator a)
{
    Slot s;

    mtk::managed::create(Event, a, &s)!;
    touch_by_switch(s.peek());
    shc::helpers::expect(DISPATCH_SWITCH_FAILED, s.must(Event).code == 1, "the Event prong must run")!;
    mtk::managed::release(Event, &s);

    mtk::managed::create(Sensor, a, &s)!;
    touch_by_switch(s.peek());
    shc::helpers::expect(DISPATCH_SWITCH_FAILED, s.must(Sensor).reading == 1, "the Sensor prong must run")!;
    mtk::managed::release(Sensor, &s);

    mtk::managed::create(Holder, a, &s)!;
    touch_by_switch(s.peek());
    shc::helpers::expect(DISPATCH_SWITCH_FAILED, s.must(Holder).id == 1, "the Holder prong must run")!;
    mtk::managed::release(Holder, &s);
}
