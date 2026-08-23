<*
 D3: mtk::owned requires an Allocator field in the OUTER, and the build-time
 message names mtk::helper as the alternative.

 Expected to FAIL TO COMPILE, in every build mode.
*>
module neg_nc;
import mtk;

struct Plain { int id; AnyNode node; }

alias bad = mtk::owned::create{Plain};

fn int main() { Slot s; bad(mem, &s)!!; return 0; }
