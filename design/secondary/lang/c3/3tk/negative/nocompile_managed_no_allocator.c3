<*
 D3: mtk::managed requires an Allocator field in the OUTER, and the build-time
 message names mtk::helper as the alternative.

 Expected to FAIL TO COMPILE, in every build mode.

 The crossing is in the body, not at an alias line — H0b.
*>
module neg_nc;
import mtk;

struct Plain { int id; Inner inner; }

fn int main() { Slot s; mtk::managed::create(Plain, mem, &s)!!; return 0; }
