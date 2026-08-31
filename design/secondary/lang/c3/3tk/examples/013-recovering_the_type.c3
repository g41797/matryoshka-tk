<*
 Four ways back to a typed pointer, chosen by whether a mismatch is normal.

 - Cross with `to`, which is null on a mismatch.
 - Cross with `as`, which asserts and costs nothing in a fast build.
 - Peek through the Slot with `to`, leaving it full.
 - Take through the Slot with `move`, leaving it empty.
*>
module shc::recovering_the_type;
import mtk;
import mtk::managed;
import shc::outers;
import shc::helpers;

faultdef RECOVERING_THE_TYPE_FAILED;

fn void? recover_four_ways(Allocator a)
{
    Slot s;
    defer mtk::managed::release(Holder, &s);
    mtk::managed::create(Holder, a, &s)!;
    Handle h = s.peek();

    Holder* checked = h.to(Holder);
    shc::helpers::expect(RECOVERING_THE_TYPE_FAILED, checked != null, "to() did not find the Holder")!;

    Holder* asserted = h.as(Holder);
    shc::helpers::expect(RECOVERING_THE_TYPE_FAILED, asserted == checked, "as() should match to()")!;

    Holder* peeked = s.to(Holder);
    shc::helpers::expect(RECOVERING_THE_TYPE_FAILED, peeked == checked, "Slot.to() should match Inner.to()")!;
    shc::helpers::expect(RECOVERING_THE_TYPE_FAILED, s.is_full(), "Slot.to() must leave the Slot full")!;

    Holder* taken = s.move(Holder);
    shc::helpers::expect(RECOVERING_THE_TYPE_FAILED, taken == checked, "Slot.move() should match Inner.to()")!;
    shc::helpers::expect(RECOVERING_THE_TYPE_FAILED, s.is_empty(), "Slot.move() must leave the Slot empty")!;

    s.fill(h);
}
