<*
 An out-of-band outer goes before every ordinary one, and there is one level,
 not a priority queue.

 - Send an ordinary `Holder`, then an out-of-band `Sensor`.
 - Receive twice and see the `Sensor` first.
*>
module shc::out_of_band;
import mtk;
import mtk::mailbox;
import shc::outers;
import shc::helpers;
import std::time;

alias SENSOR = helper::OF{Sensor};
alias HOLDER = helper::OF{Holder};

faultdef OUT_OF_BAND_FAILED;

fn void free_outer(Allocator a, Slot* s)
{
    if (s.is_empty()) return;
    if (s.to(Holder))  { HOLDER.release(a, s); return; }
    if (s.to(Sensor))  { SENSOR.release(a, s); return; }
    unreachable("free_outer met an identity it was not written for");
}

fn void? oob_arrives_first(Allocator a, Mailbox* mb)
{
    Slot ordinary;
    HOLDER.create(a, &ordinary)!;
    mb.send(&ordinary)!;

    Slot urgent;
    SENSOR.create(a, &urgent)!;
    mb.send_oob(&urgent)!;

    Slot first;
    mb.receive(&first, time::ms(1000))!;
    shc::helpers::expect(OUT_OF_BAND_FAILED, first.to(Sensor) != null, "the out-of-band outer arrives first")!;
    free_outer(a, &first);

    Slot second;
    mb.receive(&second, time::ms(1000))!;
    shc::helpers::expect(OUT_OF_BAND_FAILED, second.to(Holder) != null, "the ordinary outer arrives second")!;
    free_outer(a, &second);
}
