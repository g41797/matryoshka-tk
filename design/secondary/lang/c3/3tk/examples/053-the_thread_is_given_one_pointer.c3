<*
 `Thread.create` takes a `void*`, and one pointer is enough: the context
 struct is the single source of truth, reachable through the one pointer
 the thread was given. Anything the thread and the joiner both touch is
 atomic.

 - A worker receives outers from a mailbox and counts each one, through one
   `WorkerCtx` pointer.
 - The caller sends three, closes the mailbox, and joins.
*>
module exm::the_thread_is_given_one_pointer;
import mtk;
import mtk::managed;
import mtk::mailbox;
import exm::outers;
import exm::helpers;
import std::thread;
import std::time;
import std::atomic::types;

faultdef THE_THREAD_IS_GIVEN_ONE_POINTER_FAILED;

struct WorkerCtx
{
    Mailbox*    mbx;
    Allocator   alloc;
    usz         target;
    Atomic{usz} done;
}

fn void? mb_receive(Mailbox* mb, Slot* s) => mb.receive(s, time::ms(2000));

fn int worker_main(void* arg)
{
    WorkerCtx* ctx = (WorkerCtx*)arg;
    while (ctx.done.load(ACQUIRE) < ctx.target)
    {
        Slot s;
        if (catch mb_receive(ctx.mbx, &s)) break;
        mtk::managed::release(Holder, &s);
        ctx.done.add(1);
    }
    return 0;
}

fn void? one_pointer_is_the_whole_context(Allocator a, Mailbox* mb)
{
    WorkerCtx ctx = { .mbx = mb, .alloc = a, .target = 3 };
    ctx.done.store(0, RELEASE);

    Thread t;
    t.create(&worker_main, &ctx)!!;

    for (int i = 0; i < 3; i++)
    {
        Slot s;
        defer mtk::managed::release(Holder, &s);
        mtk::managed::create(Holder, a, &s)!;
        mb.send(&s)!;
    }

    t.join()!!;

    exm::helpers::expect(THE_THREAD_IS_GIVEN_ONE_POINTER_FAILED, ctx.done.load(ACQUIRE) == 3, "the worker reached every outer through the one context pointer")!;
}
