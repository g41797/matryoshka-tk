<*
 Part 11.7: the pool's set of identities is fixed at creation, so a get for an
 identity that is not in it is a defect of the caller.

 This is the A3 negative, and it is the test that fails if the A3 fix is taken
 out. It carries both halves of D6 tier 2 and a Part 19.3 assertion on top:

 Safe build: `bucket_for` returns null, the `@check` in `Pool.get` fires and
 the program aborts.

 Fast build: the check is gone, and what escapes must be `UNKNOWN_IDENTITY`.
 It used to be `NOT_AVAILABLE`, and Part 19.3 MUST says not-available comes
 ONLY from the available-only mode — so the old code broke its own
 specification in every fast build, from all three modes, and a checking build
 could not see it because the check aborted first. 3TK-12's finding P2.

 The three modes are all asserted, because *all three* is the whole of the
 defect. `get_wait` is asserted too: 3TK-15 changed it from a timeout to the
 same fault, so that the two gets do not disagree about one mistake.
*>
module neg;
import mtk;
import mtk::pool;
import std::io;
import std::core::mem::alloc;
import std::time;

<*
 The fault an expression produced, or nothing if it produced none. Local to
 this program: the port has no such macro and does not want one, because every
 caller in `src/` and `test/` branches on the fault rather than fetching it.
*>
macro fault @unknown(#expr)
{
    if (catch f = #expr) return f;
    always_assert(false, "the call succeeded, and an unknown identity cannot be served");
    return {};
}

fn int main()
{
    NullHooks hooks;

    typeid[1] tags = { Msg::typeid };
    Pool* p = pool::create(mem, &tags, &hooks)!!;

    Slot s;

    // Job is a real type and a legal identity. It is simply not one this pool
    // was created with, which is the violation. In a checking build the first
    // call below aborts and nothing after it runs.
    //
    // `@catch_is` is not reachable here — it belongs to the test runner, and a
    // negative is compiled as an ordinary program. `if (catch f = ...)` is the
    // same assertion written by hand, and it reads the fault rather than only
    // noticing that there was one.
    fault f;

    f = @unknown(p.get(Job::typeid, AVAILABLE_OR_NEW, &s));
    always_assert(f == mtk::UNKNOWN_IDENTITY,
                  "Part 19.3: available-or-new on an unknown identity must not report NOT_AVAILABLE");

    f = @unknown(p.get(Job::typeid, NEW_ONLY, &s));
    always_assert(f == mtk::UNKNOWN_IDENTITY,
                  "Part 19.3: new-only on an unknown identity must not report NOT_AVAILABLE");

    f = @unknown(p.get(Job::typeid, AVAILABLE_ONLY, &s));
    always_assert(f == mtk::UNKNOWN_IDENTITY,
                  "an unknown identity is a defect, not the available-only mode's not-available");

    f = @unknown(p.get_wait(Job::typeid, &s, time::ms(60)));
    always_assert(f == mtk::UNKNOWN_IDENTITY,
                  "A3: the waiting get reports the same defect and does not sleep on it");

    io::printn("no check: three get modes and get_wait reported UNKNOWN_IDENTITY");

    p.close();
    p.release();
    return 0;
}
