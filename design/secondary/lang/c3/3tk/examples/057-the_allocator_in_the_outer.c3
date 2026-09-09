<*
 An outer keeps the allocator only if it says so, in an `init` hook of its own.
 The toolkit never stores one, and `release` is told which allocator to use.

 - Create a `Holder`, whose `init` hook keeps the allocator it was given.
 - Release it, naming the same allocator at the call.
 - The kept field is the outer's business, and nothing in 3tk reads it.
*>
module shc::k_new_in_3tk::the_allocator_in_the_outer;
import mtk;
import shc::outers;
import shc::helpers;

alias HOLDER = helper::OF{Holder};

faultdef THE_ALLOCATOR_IN_THE_OUTER_FAILED;

fn void? the_outer_keeps_what_it_chose_to_keep(Allocator a)
{
    Slot s;
    HOLDER.create(a, &s)!;
    shc::helpers::expect(THE_ALLOCATOR_IN_THE_OUTER_FAILED, s.is_full(), "create filled the Slot")!;

    shc::helpers::expect(THE_ALLOCATOR_IN_THE_OUTER_FAILED, HOLDER.must_look(&s).alloc == a, "the outer's own init hook did not keep the allocator")!;

    HOLDER.release(a, &s);
    shc::helpers::expect(THE_ALLOCATOR_IN_THE_OUTER_FAILED, s.is_empty(), "release freed the outer with the allocator it was given")!;
}
