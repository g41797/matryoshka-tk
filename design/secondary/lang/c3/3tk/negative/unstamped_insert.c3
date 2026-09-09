<*
 Part 5.2: an UNSTAMPED outer entering a chain.

 The outer is hand-allocated — on the stack here — and `stamp` is never called,
 so its `Inner` carries a chain link and no identity. `to_inner` does not stamp;
 only `create`, `stamp` and the helper's `inner` do.

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
    Msg m;                                  // never stamped

    InnerQueue list;
    list.push_back(inner::internal::to_inner(&m));    // <-- the violation

    io::printfn("no check: an unstamped outer is on a queue of %d", (int)list.len());
    return 0;
}
