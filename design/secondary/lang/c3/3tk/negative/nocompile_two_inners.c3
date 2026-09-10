<*
 Part 4.4: an outer embeds exactly one inner.

 Expected to FAIL TO COMPILE, in every build mode.

 The crossing is in the body, not at an alias line — H0. It is the raw
 `inner::internal::stamp` and not a helper member for the reason
 `nocompile_no_inner` gives at length: the refusal under test is the crossing's
 own, and it is written where the compiler's message can name this line.
*>
module neg_nc;
import mtk;

struct TwoInners
{
	Inner a;
	int mid;
	Inner b;
}

fn int main()
{
	TwoInners t;
	inner::internal::stamp(&t);
	return 0;
}