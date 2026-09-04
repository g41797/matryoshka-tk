<*
 The `$Type` crossing needs no declared helper.

 - Create an `Event` and take its handle.
 - Cross back with the free-function form.
 - Cross back with the method form, and get the same answer.
*>
module shc::type_crossing;
import mtk;
import mtk::managed;
import shc::outers;
import shc::helpers;

faultdef TYPE_CROSSING_FAILED;

fn void? cross_with_dollar_type(Allocator a)
{
    Slot s;
    defer mtk::managed::release(Event, &s);
    mtk::managed::create(Event, a, &s)!;
    Inner* h = s.peek();

    Event* free_form = mtk::helper::from_handle(h, Event);
    shc::helpers::expect(TYPE_CROSSING_FAILED, free_form != null, "from_handle did not find the Event")!;
    free_form.code++;

    Event* method_form = h.to(Event);
    shc::helpers::expect(TYPE_CROSSING_FAILED, method_form == free_form, "h.to(Event) did not match from_handle(h, Event)")!;
    method_form.code++;

    shc::helpers::expect(TYPE_CROSSING_FAILED, free_form.code == 2, "both crossings should have reached the same Event")!;
}
