<*
 The layer beneath the helper: the same crossing, spelled three ways.

 `EVENT.look(inner)` is the spelling to reach for. The other two are what it
 forwards to, shown here so that the forwarding is visible and so that code
 with no helper bound has a way across.

 - Create an `Event` and take its inner.
 - Cross back with the helper member.
 - Cross back with the free-function form, and get the same answer.
 - Cross back with the method form, and get the same answer again.
*>
module shc::type_crossing;
import mtk;
import shc::outers;
import shc::helpers;

alias EVENT  = helper::OF{Event};

faultdef TYPE_CROSSING_FAILED;

fn void? cross_with_dollar_type(Allocator a)
{
    Slot s;
    defer EVENT.release(a, &s);
    EVENT.create(a, &s)!;
    Inner* inner = s.peek();

    Event* helper_form = EVENT.look(inner);
    shc::helpers::expect(TYPE_CROSSING_FAILED, helper_form != null, "EVENT.look did not find the Event")!;
    helper_form.code++;

    Event* free_form = inner::from_inner(inner, Event);
    shc::helpers::expect(TYPE_CROSSING_FAILED, free_form == helper_form, "from_inner did not match EVENT.look")!;
    free_form.code++;

    Event* method_form = inner.to(Event);
    shc::helpers::expect(TYPE_CROSSING_FAILED, method_form == free_form, "inner.to(Event) did not match from_inner(inner, Event)")!;
    method_form.code++;

    shc::helpers::expect(TYPE_CROSSING_FAILED, free_form.code == 3, "all three crossings should have reached the same Event")!;
}
