<*
 The one check an example is allowed to make.

 `expect` takes the fault to return, the condition, and the message.
 It survives all four builds, unlike `assert`.
*>
module exm::helpers;
import std::io;

<*
 Returns `f` when `cond` is false, and reports `msg` first.

 @param f : "the fault to return on failure"
 @param cond : "the condition that must hold"
 @param msg : "named for the caller, printed on failure"
*>
fn void? expect(fault f, bool cond, String msg)
{
    if (!cond)
    {
        io::eprintfn("expect failed: %s", msg);
        return f~;
    }
}
