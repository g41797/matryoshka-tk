<*
 Part 4.4: an outer embeds exactly one inner.

 Expected to FAIL TO COMPILE, in every build mode.

 The crossing is in the body, not at an alias line — H0.
*>
module neg_nc;
import mtk;

struct TwoInners { Inner a; int mid; Inner b; }

fn int main() { TwoInners t; mtk::helper::init(&t); return 0; }
