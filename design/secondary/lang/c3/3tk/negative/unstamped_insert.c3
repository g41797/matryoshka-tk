<*
 Part 5.2: an UNSTAMPED outer entering a chain.

 The outer is hand-allocated — on the stack here — and `stamp` is never called,
 so its `Inner` carries a chain link and no identity. `to_inner` does not stamp
 and does not check; `create` and `stamp` are the only two doors that write an
 identity, and since 3TK-75 the helper's `inner` verifies one.

 That last sentence is why the crossing below is the raw macro. `MSG.inner(&m)`
 would abort here — at the crossing out, not at the insertion — and the
 insertion is the boundary this program exists to prove.

 This is the earlier of the two boundaries. The identity is not read until some
 later crossing, and by then the site that omitted the stamp is gone from the
 stack; catching it at the insertion is what gives the message a home.

 Safe build: aborts in `InnerQueue.@guard_insert`.
 Fast build: exits 0 with an unstamped outer sitting on the queue.
*>
module neg;
import mtk;
import std::io;

fn int main()
{
	// NOT allocated through the helper, and it cannot be: `create` always
	// stamps, and an outer that was never stamped is the whole subject here.
	Msg m; // never stamped

	InnerQueue list;
	list.push_back(inner::internal::to_inner(&m)); // <-- the violation

	io::printfn("no check: an unstamped outer is on a queue of %d", (int)list.len());
	return 0;
}