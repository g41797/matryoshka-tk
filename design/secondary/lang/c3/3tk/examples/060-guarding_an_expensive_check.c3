<*
 `mtk::CHECKED` is the same question `@check` asks, as a value — for a block
 too expensive to write inside the argument itself.

 - Send one `Holder` into a mailbox and receive it back as a batch of one.
 - Take its handle and run a guarded check that only walks the queue when
   the build is checking anything at all.
*>
module shc::guarding_an_expensive_check;
import mtk;
import mtk::managed;
import mtk::mailbox;
import shc::outers;
import shc::helpers;

faultdef GUARDING_AN_EXPENSIVE_CHECK_FAILED;

fn void guarded_walk(InnerQueue* q, Handle h)
{
    mtk::@check(h != null, "this walk was given a handle");

    if (mtk::CHECKED)
    {
        usz n;
        InnerQueueIterator it = q.iter();
        while (Handle each = it.next()) { n++; }
        mtk::@check(n == q.len(), "the queue's kept count matches its chain");
    }
}

fn void? the_guard_costs_nothing_in_a_fast_build(Allocator a)
{
    Mailbox* mb = mtk::mailbox::create(a)!;
    defer { InnerQueue left; mb.close(&left); mb.release(); }

    Slot s;
    defer mtk::managed::release(Holder, &s);
    mtk::managed::create(Holder, a, &s)!;
    mb.send(&s)!;

    InnerQueue batch;
    mb.receive_all(&batch)!;
    Handle h = batch.pop_front();
    guarded_walk(&batch, h);

    Slot got;
    got.fill(h);
    defer mtk::managed::release(Holder, &got);
    shc::helpers::expect(GUARDING_AN_EXPENSIVE_CHECK_FAILED, got.is_full(), "the guarded check did not disturb the handle")!;
}
