<*
 Part 7.4: the generator rejects a type with no inner field, at build time,
 with a message that names the offending type.

 Expected to FAIL TO COMPILE, in every build mode. The compiler's message is
 the evidence.

 The crossing is in the body, not at an alias line: H0 left no declaration to
 put it on, and a type that is never crossed with is never validated.
*>
module neg_nc;
import mtk;

struct NotAnItem { int a; int b; }

fn int main() { NotAnItem n; mtk::helper::init(&n); return 0; }
