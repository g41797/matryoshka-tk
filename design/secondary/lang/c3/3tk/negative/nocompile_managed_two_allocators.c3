<*
 Part 4.4, applied to the allocator: an outer carries exactly one Allocator.

 Expected to FAIL TO COMPILE, in every build mode.

 The crossing is in the body, not at an alias line — H0b.
*>
module neg_nc;
import mtk;

struct TwoAllocators { int id; Inner inner; Allocator a; Allocator b; }

fn int main() { Slot s; mtk::managed::create(TwoAllocators, mem, &s)!!; return 0; }
