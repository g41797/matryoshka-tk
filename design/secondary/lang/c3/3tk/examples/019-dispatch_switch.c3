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

alias EVENT  = helper::OF{Event};
alias SENSOR = helper::OF{Sensor};
alias HOLDER = helper::OF{Holder};

faultdef DISPATCH_SWITCH_FAILED;

fn void touch_by_switch(Inner* inner)
{
    switch (inner.link.type)
    {
        case Event::typeid:
            EVENT.must_look(inner).code++;
        case Sensor::typeid:
            SENSOR.must_look(inner).reading++;
        case Holder::typeid:
            HOLDER.must_look(inner).id++;
        default:
            unreachable("closed set: every identity is a prong");
    }
}

fn void? dispatch_by_switch(Allocator a)
{
    Slot s;

    EVENT.create(a, &s)!;
    touch_by_switch(s.peek());
    shc::helpers::expect(DISPATCH_SWITCH_FAILED, EVENT.must_look(&s).code == 1, "the Event prong must run")!;
    EVENT.release(a, &s);

    SENSOR.create(a, &s)!;
    touch_by_switch(s.peek());
    shc::helpers::expect(DISPATCH_SWITCH_FAILED, SENSOR.must_look(&s).reading == 1, "the Sensor prong must run")!;
    SENSOR.release(a, &s);

    HOLDER.create(a, &s)!;
    touch_by_switch(s.peek());
    shc::helpers::expect(DISPATCH_SWITCH_FAILED, HOLDER.must_look(&s).id == 1, "the Holder prong must run")!;
    HOLDER.release(a, &s);
}
