<*
 A step is one thing, and the name is the documentation. Everything it
 needs is on `self` or in its parameters — a step reaches for no global.

 - `seed_the_work` sends four `Event`s, a loop that is one unit at its level.
 - `process_the_work` is `wake_all` and nothing else.
 - Confirm all four crossed, in order.
*>
module shc::the_step;
import mtk;
import mtk::managed;
import mtk::mailbox;
import shc::outers;
import shc::helpers;

faultdef THE_STEP_FAILED;

struct StepMaster
{
    Allocator alloc;
    Mailbox*  mbx;
}

fn void? StepMaster.seed_the_work(&self)
{
    for (int i = 1; i <= 4; i++)
    {
        Slot s;
        defer mtk::managed::release(Event, &s);
        mtk::managed::create(Event, self.alloc, &s)!;
        s.must(Event).code = i;
        self.mbx.send(&s)!;
    }
}

fn void? StepMaster.process_the_work(&self) { return self.mbx.wake_all(); }

fn void? one_step_one_name(Allocator a, Mailbox* mb)
{
    StepMaster m = { .alloc = a, .mbx = mb };
    m.seed_the_work()!;
    m.process_the_work()!;

    InnerQueue batch;
    mb.receive_all(&batch)!;
    int total = 0;
    while (Handle h = batch.pop_front())
    {
        Slot s;
        s.fill(h);
        defer mtk::managed::release(Event, &s);
        total += s.must(Event).code;
    }
    shc::helpers::expect(THE_STEP_FAILED, total == 1 + 2 + 3 + 4, "seed_the_work sent all four, in order")!;
}
