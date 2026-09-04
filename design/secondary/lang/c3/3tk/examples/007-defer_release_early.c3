<*
 Creating an outer on the heap: the defer goes before the create.

 - Register the release first.
 - Create a `Holder`.
 - Send it on. The defer finds nothing to do.
*>
module shc::defer_release_early;
import mtk;
import mtk::managed;
import mtk::mailbox;
import shc::outers;
import shc::helpers;

faultdef DEFER_RELEASE_EARLY_FAILED;

fn void? send_a_fresh_holder(Allocator a, Mailbox* mb)
{
    Slot s;
    defer mtk::managed::release(Holder, &s);
    mtk::managed::create(Holder, a, &s)!;
    s.must(Holder).id = 42;
    mb.send(&s)!;                                       // on success the defer does nothing
}

fn void? defer_release_goes_before_the_create(Allocator a)
{
    Mailbox* mb = mtk::mailbox::create(a)!;
    defer { InnerQueue left; mb.close(&left); mb.release(); }

    send_a_fresh_holder(a, mb)!;

    InnerQueue left;
    mb.close(&left);
    Inner* inner = left.pop_front();
    shc::helpers::expect(DEFER_RELEASE_EARLY_FAILED, inner != null, "the mailbox did not keep the Holder")!;
    Slot s;
    s.fill(inner);
    mtk::managed::release(Holder, &s);
}
