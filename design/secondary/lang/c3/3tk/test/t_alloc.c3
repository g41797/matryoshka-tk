<*
 The test allocators, and the creation-failure tests that need them.

 A file of its own, on the owner's instruction of 2026-08-23. `common.c3` is
 the shared fixture every test file compiles against, and an allocator that
 fails on purpose does not belong in it. The allocators also outlive the stage
 that added them, so a file named for the subject is where the next one goes.

 What is here:

   CountingAlloc — wraps a real allocator and counts outstanding blocks.
   FailingAlloc  — wraps a CountingAlloc and refuses after N acquisitions.

 What they are for. Part 3.1's creation paths can fail at several points, and
 every failure after the first allocation has to undo exactly what succeeded
 before it. That is invisible to an ordinary test: on Linux with an ordinary
 allocator the failing branch is never taken. These allocators take it on
 purpose, and `outstanding()` says whether anything was left behind.

 `resize` is implemented because the interface requires it. Neither container
 calls it — the pool's bucket array is allocated once and never grown, Part
 11.7 — so a test that provokes a resize would be testing the allocator rather
 than the port.
*>
module mtk_test;
import mtk;
import std::core::mem::alloc;
import std::core::mem;

<*
 An allocator that counts. Every acquisition adds one, every release subtracts
 one, and `outstanding` is the difference — zero means nothing leaked.
*>
struct CountingAlloc (Allocator)
{
    Allocator inner;
    usz       acquired;
    usz       released;
}

fn void*? CountingAlloc.acquire(&self, sz size, AllocInitType init_type, sz alignment) @dynamic
{
    void* p = self.inner.acquire(size, init_type, alignment)!;
    self.acquired++;
    return p;
}

fn void*? CountingAlloc.resize(&self, void* ptr, sz new_size, sz alignment) @dynamic
    => self.inner.resize(ptr, new_size, alignment);

fn void CountingAlloc.release(&self, void* ptr, bool aligned) @dynamic
{
    self.released++;
    self.inner.release(ptr, aligned);
}

fn usz CountingAlloc.outstanding(&self) => self.acquired - self.released;

<*
 An allocator that fails on schedule. The first `budget` acquisitions succeed;
 every one after that returns OUT_OF_MEMORY, which is what a real allocator
 returns when it cannot serve a request.

 Releases always pass through, so a test can still count what came back.
*>
struct FailingAlloc (Allocator)
{
    CountingAlloc* counter;
    usz            budget;
    usz            seen;
}

fn void*? FailingAlloc.acquire(&self, sz size, AllocInitType init_type, sz alignment) @dynamic
{
    if (self.seen >= self.budget) return mem::OUT_OF_MEMORY~;
    self.seen++;
    return self.counter.acquire(size, init_type, alignment);
}

fn void*? FailingAlloc.resize(&self, void* ptr, sz new_size, sz alignment) @dynamic
    => self.counter.resize(ptr, new_size, alignment);

fn void FailingAlloc.release(&self, void* ptr, bool aligned) @dynamic
    => self.counter.release(ptr, aligned);

// --- The creation-failure tests ------------------------------------------------
//
// Part 3.1's creation paths, driven to fail at each allocation point in turn.
// The assertion is always the same and it is the only one that matters: after a
// failed creation, `outstanding()` is zero. Nothing was left behind.
//
// The budget is the number of acquisitions allowed before the allocator starts
// refusing. Budget 0 fails the object allocation itself, budget 1 lets the
// object through and fails whatever comes next, and so on.

<*
 A mailbox that cannot be allocated at all.

 **What this proves is narrow, and it is written down because a test whose
 failure is impossible is worse than no test.** Nothing was acquired, so
 nothing can leak: this checks that `create` propagates the fault instead of
 returning a half-object, not that the cleanup works.

 **`Mailbox.create`'s cleanup cannot be provoked from here.** It performs
 exactly one acquisition through the caller's allocator; every later step that
 can fail — `_mu.init()`, `_cv.init()` — allocates through the platform, not
 through this allocator. So the `defer catch` pair in `Mailbox.create` is
 correct by construction and **untested**, and the sabotage run confirms it:
 removing them leaves every test green. The pool's equivalent is provoked
 below, and it is the same shape.
*>
fn void mailbox_create_fails_at_the_object() @test
{
    CountingAlloc counter = { .inner = mem };
    FailingAlloc  failing = { .counter = &counter, .budget = 0 };

    if (catch f = mtk::mailbox::create(&failing))
    {
        always_assert(counter.outstanding() == 0, "a failed mailbox creation leaked");
        return;
    }
    always_assert(false, "creation was expected to fail and did not");
}

<*
 The pool, same base case, and the same narrow claim.
*>
fn void pool_create_fails_at_the_object() @test
{
    CountingAlloc counter = { .inner = mem };
    FailingAlloc  failing = { .counter = &counter, .budget = 0 };
    TestHooks     hooks;

    typeid[1] tags = { Holder::typeid };
    if (catch f = mtk::pool::create(&failing, tags[..], &hooks))
    {
        always_assert(counter.outstanding() == 0, "a failed pool creation leaked");
        return;
    }
    always_assert(false, "creation was expected to fail and did not");
}

<*
 **The one that was broken.** The Pool allocation succeeds and the bucket array
 does not, so `create` has a live Pool, a live mutex and a live condition
 variable when it fails.
 Before the fix, all three leaked and the caller received a fault with no way to
 reach any of them.
*>
fn void pool_create_fails_at_the_buckets() @test
{
    CountingAlloc counter = { .inner = mem };
    FailingAlloc  failing = { .counter = &counter, .budget = 1 };
    TestHooks     hooks;

    typeid[1] tags = { Holder::typeid };
    if (catch f = mtk::pool::create(&failing, tags[..], &hooks))
    {
        always_assert(counter.acquired == 1, "the Pool itself should have been allocated");
        always_assert(counter.outstanding() == 0, "the Pool was allocated and not freed");
        return;
    }
    always_assert(false, "creation was expected to fail and did not");
}

<*
 A creation that succeeds leaves nothing outstanding once it is closed and
 released. The counterpart to the three above: it proves `outstanding()` reaches
 zero on the ordinary path too, so a zero on a failure path means something.
*>
fn void a_whole_life_leaves_nothing_outstanding() @test
{
    CountingAlloc counter = { .inner = mem };

    Mailbox* mb = mtk::mailbox::create(&counter)!!;
    always_assert(counter.outstanding() == 1, "one live mailbox, one live block");

    // Part 11.6: the mailbox gives everything back. It is empty here, so the
    // list comes back empty — and that asymmetry against the pool's close is
    // the reason this call takes a list at all.
    InnerQueue returned;
    mb.close(&returned);
    always_assert(returned.is_empty(), "an empty mailbox returned items on close");
    mb.release();

    TestHooks hooks;
    typeid[1] tags = { Holder::typeid };
    Pool* p = mtk::pool::create(&counter, tags[..], &hooks)!!;
    p.close();
    p.release();

    always_assert(counter.outstanding() == 0, "a closed and released pair left blocks behind");
}
