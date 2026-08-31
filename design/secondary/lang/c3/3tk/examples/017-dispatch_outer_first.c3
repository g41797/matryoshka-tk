<*
 An outer-first dispatch chain frees a Slot whatever identity it holds.

 - Declare the chain once, closed over the three demo identities.
 - Create one outer of each identity in turn.
 - Release each through the chain and confirm the Slot ends empty.
*>
module exm::dispatch_outer_first;
import mtk;
import mtk::managed;
import exm::outers;
import exm::helpers;

faultdef DISPATCH_OUTER_FIRST_FAILED;

fn void free_outer(Slot* s)
{
    if (s.is_empty()) return;
    if (s.to(Event))  { mtk::managed::release(Event, s);  return; }
    if (s.to(Sensor)) { mtk::managed::release(Sensor, s); return; }
    if (s.to(Holder)) { mtk::managed::release(Holder, s); return; }
    unreachable("free_outer met an identity it was not written for");
}

fn void? dispatch_releases_every_identity(Allocator a)
{
    Slot s;

    mtk::managed::create(Event, a, &s)!;
    free_outer(&s);
    exm::helpers::expect(DISPATCH_OUTER_FIRST_FAILED, s.is_empty(), "the chain must empty the Slot for Event")!;

    mtk::managed::create(Sensor, a, &s)!;
    free_outer(&s);
    exm::helpers::expect(DISPATCH_OUTER_FIRST_FAILED, s.is_empty(), "the chain must empty the Slot for Sensor")!;

    mtk::managed::create(Holder, a, &s)!;
    free_outer(&s);
    exm::helpers::expect(DISPATCH_OUTER_FIRST_FAILED, s.is_empty(), "the chain must empty the Slot for Holder")!;
}
