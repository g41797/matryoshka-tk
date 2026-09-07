<*
 A `switch` over a `typeid` is the one dispatch shape ztk cannot write.

 - Create one outer of each identity, in a Slot.
 - Take the inner and switch on its identity, asserting the prong's type.
 - Release the outer once the switch has touched it.
*>
module shc::dispatch_switch;
import mtk;
import shc::outers;
import shc::helpers;

alias EVENT  = mtk::OF{Event};
alias SENSOR = mtk::OF{Sensor};
alias HOLDER = mtk::OF{Holder};

faultdef DISPATCH_SWITCH_FAILED;

fn void touch_by_switch(Inner* inner)
{
    switch (inner.link.type)
    {
        case Event::typeid:
            inner.as(Event).code++;
        case Sensor::typeid:
            inner.as(Sensor).reading++;
        case Holder::typeid:
            inner.as(Holder).id++;
        default:
            unreachable("closed set: every identity is a prong");
    }
}

fn void? dispatch_by_switch(Allocator a)
{
    Slot s;

    EVENT.create(a, &s)!;
    touch_by_switch(s.peek());
    shc::helpers::expect(DISPATCH_SWITCH_FAILED, s.must(Event).code == 1, "the Event prong must run")!;
    EVENT.release(a, &s);

    SENSOR.create(a, &s)!;
    touch_by_switch(s.peek());
    shc::helpers::expect(DISPATCH_SWITCH_FAILED, s.must(Sensor).reading == 1, "the Sensor prong must run")!;
    SENSOR.release(a, &s);

    HOLDER.create(a, &s)!;
    touch_by_switch(s.peek());
    shc::helpers::expect(DISPATCH_SWITCH_FAILED, s.must(Holder).id == 1, "the Holder prong must run")!;
    HOLDER.release(a, &s);
}
