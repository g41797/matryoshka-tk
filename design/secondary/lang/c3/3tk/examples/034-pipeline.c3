<*
 Each stage has one outer at a time, so the Slot idiom holds at every hop.

 - A stage thread loops on an input mailbox, doubling each value and passing
   it on.
 - An end-of-stream marker travels the chain like anything else, and the
   stage that receives it forwards it once and stops.
 - The caller sends three values and the marker, then drains the output
   mailbox.
*>
module shc::pipeline;
import mtk;
import mtk::managed;
import mtk::mailbox;
import shc::outers;
import shc::helpers;
import std::thread;
import std::time;

faultdef PIPELINE_FAILED;

const int END_OF_STREAM = -1;

struct StageArgs
{
    Mailbox* in_mbx;
    Mailbox* out_mbx;
}

fn int double_and_forward(void* arg)
{
    StageArgs* a = (StageArgs*)arg;
    while (true)
    {
        Slot s;
        if (catch f = a.in_mbx.receive(&s, time::ms(2000))) return 0;
        Event* e = s.must(Event);
        if (e.code == END_OF_STREAM)
        {
            if (catch f = a.out_mbx.send(&s)) mtk::managed::release(Event, &s);
            return 0;
        }
        e.code = e.code * 2;
        if (catch f = a.out_mbx.send(&s)) { mtk::managed::release(Event, &s); return 0; }
    }
}

fn void? values_cross_one_stage_doubled(Allocator a, Mailbox* in_mbx, Mailbox* out_mbx)
{
    StageArgs args = { .in_mbx = in_mbx, .out_mbx = out_mbx };
    Thread stage;
    stage.create(&double_and_forward, &args)!!;

    for (int i = 1; i <= 3; i++)
    {
        Slot s;
        mtk::managed::create(Event, a, &s)!;
        s.must(Event).code = i;
        in_mbx.send(&s)!;
    }
    Slot marker;
    mtk::managed::create(Event, a, &marker)!;
    marker.must(Event).code = END_OF_STREAM;
    in_mbx.send(&marker)!;

    int total = 0;
    bool saw_marker = false;
    for (int received = 0; received < 4; received++)
    {
        Slot s;
        defer mtk::managed::release(Event, &s);
        out_mbx.receive(&s, time::ms(2000))!;
        Event* e = s.must(Event);
        if (e.code == END_OF_STREAM) { saw_marker = true; continue; }
        total += e.code;
    }

    stage.join()!!;

    shc::helpers::expect(PIPELINE_FAILED, total == 2 + 4 + 6, "every value crossed the stage doubled")!;
    shc::helpers::expect(PIPELINE_FAILED, saw_marker, "the end-of-stream marker travelled the chain too")!;
}
