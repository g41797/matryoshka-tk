<*
 `InnerQueue` is the one list type, walked two ways.

 - Send three `Holder` outers into a mailbox.
 - Receive them all at once into an `InnerQueue`.
 - Walk it with an iterator, without consuming it.
 - Walk it again with `pop_front`, releasing each outer.
*>
module shc::walk_a_batch;
import mtk;
import mtk::managed;
import mtk::mailbox;
import shc::outers;
import shc::helpers;

faultdef WALK_A_BATCH_FAILED;

fn void? walk_a_received_batch(Allocator a)
{
    Mailbox* mb = mtk::mailbox::create(a)!;
    defer { InnerQueue left; mb.close(&left); mb.release(); }

    for (int i = 0; i < 3; i++)
    {
        Slot s;
        defer mtk::managed::release(Holder, &s);
        mtk::managed::create(Holder, a, &s)!;
        s.must(Holder).id = i;
        mb.send(&s)!;
    }

    InnerQueue batch;
    mb.receive_all(&batch)!;

    usz seen;
    InnerQueueIterator it = batch.iter();
    while (Inner* h = it.next()) { seen++; }
    shc::helpers::expect(WALK_A_BATCH_FAILED, seen == 3, "the iterator should see all three without consuming them")!;
    shc::helpers::expect(WALK_A_BATCH_FAILED, batch.len() == 3, "walking with an iterator must not consume the queue")!;

    while (Inner* h = batch.pop_front())
    {
        Slot s;
        s.fill(h);
        mtk::managed::release(Holder, &s);
    }
    shc::helpers::expect(WALK_A_BATCH_FAILED, batch.is_empty(), "pop_front should have drained the queue")!;
}
