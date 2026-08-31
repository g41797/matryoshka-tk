<*
 An outer with a lifetime carries the `Allocator` it was made with, so
 `release` needs none handed back to it.

 - Create a `Holder`.
 - Release it with no allocator argument.
*>
module shc::the_allocator_in_the_outer;
import mtk;
import mtk::managed;
import shc::outers;
import shc::helpers;

faultdef THE_ALLOCATOR_IN_THE_OUTER_FAILED;

fn void? release_takes_no_allocator(Allocator a)
{
    Slot s;
    mtk::managed::create(Holder, a, &s)!;
    shc::helpers::expect(THE_ALLOCATOR_IN_THE_OUTER_FAILED, s.is_full(), "create filled the Slot")!;

    mtk::managed::release(Holder, &s);
    shc::helpers::expect(THE_ALLOCATOR_IN_THE_OUTER_FAILED, s.is_empty(), "release needed no allocator to free what create made with one")!;
}
