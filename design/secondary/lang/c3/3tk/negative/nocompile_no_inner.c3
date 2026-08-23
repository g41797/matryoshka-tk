<*
 Part 7.4: the generator rejects a type with no inner field, at build time,
 with a message that names the offending type.

 Expected to FAIL TO COMPILE, in every build mode. The compiler's message is
 the evidence.
*>
module neg_nc;
import mtk;

struct NotAnItem { int a; int b; }

alias bad = mtk::helper::init{NotAnItem};

fn int main() { NotAnItem n; bad(&n); return 0; }
