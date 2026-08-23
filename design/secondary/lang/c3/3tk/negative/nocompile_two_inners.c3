<*
 Part 4.4: an outer embeds exactly one inner.

 Expected to FAIL TO COMPILE, in every build mode.
*>
module neg_nc;
import mtk;

struct TwoInners { AnyNode a; int mid; AnyNode b; }

alias bad = mtk::helper::init{TwoInners};

fn int main() { TwoInners t; bad(&t); return 0; }
