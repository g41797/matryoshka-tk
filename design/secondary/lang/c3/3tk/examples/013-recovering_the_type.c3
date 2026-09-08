<*
 The helper's four crossings, and the four methods they forward to.

 `HOLDER.look`, `must_look`, `take` and `must_take` are the spellings to reach
 for: two axes, so the names are derivable rather than memorised. `must_`
 aborts on a mismatch and plain returns null; `take` empties the Slot and
 `look` leaves it alone. The `Inner` and `Slot` methods below are the layer
 beneath, shown once so the forwarding is visible.

 - Cross an inner with `look`, which is null on a mismatch, and with `to`.
 - Cross an inner with `must_look`, which asserts, and with `as`.
 - Peek through the Slot with `look`, leaving it full, and with `to`.
 - Take through the Slot with `take`, leaving it empty, and with `move`.
*>
module shc::recovering_the_type;
import mtk;
import shc::outers;
import shc::helpers;

alias HOLDER = helper::OF{Holder};

faultdef RECOVERING_THE_TYPE_FAILED;

fn void? recover_four_ways(Allocator a)
{
    Slot s;
    defer HOLDER.release(a, &s);
    HOLDER.create(a, &s)!;
    Inner* inner = s.peek();

    Holder* checked = HOLDER.look(inner);
    shc::helpers::expect(RECOVERING_THE_TYPE_FAILED, checked != null, "look() did not find the Holder")!;
    shc::helpers::expect(RECOVERING_THE_TYPE_FAILED, inner.to(Holder) == checked, "Inner.to() should match look()")!;

    Holder* asserted = HOLDER.must_look(inner);
    shc::helpers::expect(RECOVERING_THE_TYPE_FAILED, asserted == checked, "must_look() should match look()")!;
    shc::helpers::expect(RECOVERING_THE_TYPE_FAILED, inner.as(Holder) == checked, "Inner.as() should match must_look()")!;

    Holder* peeked = HOLDER.look(&s);
    shc::helpers::expect(RECOVERING_THE_TYPE_FAILED, peeked == checked, "look() on a Slot should match look() on an inner")!;
    shc::helpers::expect(RECOVERING_THE_TYPE_FAILED, s.to(Holder) == checked, "Slot.to() should match look()")!;
    shc::helpers::expect(RECOVERING_THE_TYPE_FAILED, s.is_full(), "look() must leave the Slot full")!;

    Holder* taken = HOLDER.take(&s);
    shc::helpers::expect(RECOVERING_THE_TYPE_FAILED, taken == checked, "take() should match look()")!;
    shc::helpers::expect(RECOVERING_THE_TYPE_FAILED, s.is_empty(), "take() must leave the Slot empty")!;

    s.fill(inner);
}
