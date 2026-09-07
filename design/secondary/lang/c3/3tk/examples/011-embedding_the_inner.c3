<*
 One `Inner` field, anywhere in the struct, makes it an outer.

 - Embed exactly one `Inner` in `Sensor`.
 - Confirm the crossing works from a field that is not at offset zero.
*>
module shc::embedding_the_inner;
import mtk;
import shc::outers;
import shc::helpers;

alias SENSOR = mtk::OF{Sensor};

faultdef EMBEDDING_THE_INNER_FAILED;

fn void? embed_one_inner_anywhere(Allocator a)
{
    Slot s;
    defer SENSOR.release(a, &s);
    SENSOR.create(a, &s)!;

    Sensor* found = s.to(Sensor);
    shc::helpers::expect(EMBEDDING_THE_INNER_FAILED, found != null, "Sensor did not cross with its Inner off offset zero")!;
    found.reading = 1;
}
