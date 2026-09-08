<*
 An outer-first dispatch chain frees a Slot whatever identity it holds.

 - Declare the chain once, closed over the three demo identities.
 - Create one outer of each identity in turn.
 - Release each through the chain and confirm the Slot ends empty.
*>
module shc::dispatch_outer_first;
import mtk;
import shc::outers;
import shc::helpers;

alias EVENT  = helper::OF{Event};
alias SENSOR = helper::OF{Sensor};
alias HOLDER = helper::OF{Holder};

faultdef DISPATCH_OUTER_FIRST_FAILED;

fn void free_outer(Allocator a, Slot* s)
{
    if (s.is_empty()) return;
    if (s.to(Event))  { EVENT.release(a, s);  return; }
    if (s.to(Sensor)) { SENSOR.release(a, s); return; }
    if (s.to(Holder)) { HOLDER.release(a, s); return; }
    unreachable("free_outer met an identity it was not written for");
}

fn void? dispatch_releases_every_identity(Allocator a)
{
    Slot s;

    EVENT.create(a, &s)!;
    free_outer(a, &s);
    shc::helpers::expect(DISPATCH_OUTER_FIRST_FAILED, s.is_empty(), "the chain must empty the Slot for Event")!;

    SENSOR.create(a, &s)!;
    free_outer(a, &s);
    shc::helpers::expect(DISPATCH_OUTER_FIRST_FAILED, s.is_empty(), "the chain must empty the Slot for Sensor")!;

    HOLDER.create(a, &s)!;
    free_outer(a, &s);
    shc::helpers::expect(DISPATCH_OUTER_FIRST_FAILED, s.is_empty(), "the chain must empty the Slot for Holder")!;
}
