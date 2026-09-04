<*
 The declaration is the condition: an `Inner*` bound in a `while` is in scope
 inside the body and nowhere else, so there is no variable left over to use
 by mistake after the loop.

 - Send three `Holder` outers into a mailbox and receive them as a batch.
 - Walk the batch with the one loop shape, releasing each as it goes.
*>
module shc::the_optional_declaration_walk;
import mtk;
import mtk::managed;
import mtk::mailbox;
import shc::outers;
import shc::helpers;

faultdef THE_OPTIONAL_DECLARATION_WALK_FAILED;

fn usz walk_and_release(InnerQueue* q)
{
    usz n;
    while (Inner* h = q.pop_front())
    {
        Slot s;
        s.fill(h);
        mtk::managed::release(Holder, &s);
        n++;
    }
    return n;
}

fn void? the_declaration_is_the_condition(Allocator a)
{
    Mailbox* mb = mtk::mailbox::create(a)!;
    defer { InnerQueue left; mb.close(&left); mb.release(); }

    for (int i = 0; i < 3; i++)
    {
        Slot s;
        defer mtk::managed::release(Holder, &s);
        mtk::managed::create(Holder, a, &s)!;
        mb.send(&s)!;
    }

    InnerQueue batch;
    mb.receive_all(&batch)!;

    usz n = walk_and_release(&batch);
    shc::helpers::expect(THE_OPTIONAL_DECLARATION_WALK_FAILED, n == 3, "the walk saw every handle the queue held")!;
    shc::helpers::expect(THE_OPTIONAL_DECLARATION_WALK_FAILED, batch.is_empty(), "pop_front left nothing behind")!;
}
