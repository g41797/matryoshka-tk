<*
 Part 11.7: the pool's set of identities is fixed at creation, and a duplicate
 in it is a defect of the caller.

 It has to be refused rather than tolerated because `bucket_for` returns the
 FIRST bucket carrying an identity. A second bucket for an identity that
 already has one can never be found: every put lands in the first, every get
 draws from the first, and the second stays empty for the life of the pool.
 Nothing fails, nothing is reported, and the pool quietly holds half of what
 its creator asked for.

 Safe build: aborts in pool::create, before the buckets are allocated.
 Fast build: the check is gone, the pool is created with an unreachable bucket,
 and the program runs to the end — which is what a compiled-out contract costs,
 and why the check exists.
*>
module neg;
import mtk;
import mtk::pool;
import std::io;
import std::core::mem::alloc;

fn int main()
{
    NullHooks hooks;

    typeid[3] tags = { Msg::typeid, Job::typeid, Msg::typeid };   // <-- the violation

    Pool* p = pool::create(mem, &tags, &hooks)!!;

    io::printn("no check: the pool was created with a duplicate identity");

    p.close();
    p.release();
    return 0;
}
