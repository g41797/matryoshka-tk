<*
 An out-of-band outer goes before every ordinary one, and there is one level,
 not a priority queue.

 - Send an ordinary `Holder`, then an out-of-band `Sensor`.
 - Receive twice and see the `Sensor` first.
*>
module exm::out_of_band;
import mtk;
import mtk::managed;
import mtk::mailbox;
import exm::outers;
import exm::helpers;
import std::time;

faultdef OUT_OF_BAND_FAILED;

fn void free_outer(Slot* s)
{
    if (s.is_empty()) return;
    if (s.to(Holder))  { mtk::managed::release(Holder, s); return; }
    if (s.to(Sensor))  { mtk::managed::release(Sensor, s); return; }
    unreachable("free_outer met an identity it was not written for");
}

fn void? oob_arrives_first(Allocator a, Mailbox* mb)
{
    Slot ordinary;
    mtk::managed::create(Holder, a, &ordinary)!;
    mb.send(&ordinary)!;

    Slot urgent;
    mtk::managed::create(Sensor, a, &urgent)!;
    mb.send_oob(&urgent)!;

    Slot first;
    mb.receive(&first, time::ms(1000))!;
    exm::helpers::expect(OUT_OF_BAND_FAILED, first.to(Sensor) != null, "the out-of-band outer arrives first")!;
    free_outer(&first);

    Slot second;
    mb.receive(&second, time::ms(1000))!;
    exm::helpers::expect(OUT_OF_BAND_FAILED, second.to(Holder) != null, "the ordinary outer arrives second")!;
    free_outer(&second);
}
