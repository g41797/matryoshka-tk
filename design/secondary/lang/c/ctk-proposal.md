# ctk = C realization of the portable Matryoshka specification


> **ctk = C realization of the portable Matryoshka specification, targeting modern Linux/POSIX, with C11 as the language baseline and newer C features used only where they materially improve the API.**

I would **not** make C23 a hard requirement unless you have a concrete C23 feature you want in the public API.

## 1. First architectural decision

The ports should form this relationship:

```text
                 Matryoshka portable specification 005
                              │
              ┌───────────────┼───────────────┐
              │               │               │
             ztk             3tk             ctk
             Zig             C3               C
              │               │               │
        realization      realization     realization
```

Not:

```text
ztk → 3tk → ctk
```

This is important because 005 explicitly corrected the earlier problem of accidentally treating a realization's mechanism as the specification.

For ctk, **005 is the source of truth**.

The C3 implementation is useful as a second implementation/reference, but should not become the C specification.

---

# 2. Target

I suggest fixing the initial target very narrowly.

### ctk 0.1 target

* Linux
* POSIX threads
* `pthread_mutex_t`
* `pthread_cond_t`
* `pthread_cond_timedwait`
* C11 atomics
* C11 language baseline
* CMake
* CLion supported
* GCC and Clang
* 64-bit Linux

The portable API should avoid exposing POSIX types where possible.

For example:

```c
typedef struct mt_mailbox mt_mailbox;
typedef struct mt_pool mt_pool;
```

rather than exposing:

```c
pthread_mutex_t
pthread_cond_t
```

in the public header.

The implementation can use pthreads internally.

---

# 3. C version: C11 vs C23

I would choose **C11 as the compatibility baseline**.

C23 is the latest standardized C revision, but most of the Matryoshka design does not need C23.

The important C11 features already give us:

* `_Atomic`
* `<stdatomic.h>`
* `_Static_assert`
* `inline`
* designated initializers
* `_Generic` if useful
* `<threads.h>` if desired, although I would **not** use it here
* standard integer types

Linux gives us pthreads, which are a better practical foundation for ctk.

### Why not require C23?

Because the interesting Matryoshka problems are not solved by C23:

* intrusive embedding
* type identity
* type-erased handles
* Slot
* container ownership
* hook lifetime
* closed/quiet lifetime
* compile-time helper generation

C has no reflection or templates comparable to Zig/C3.

Therefore the C port should solve those explicitly rather than pretending C23 makes them disappear.

---

# 4. C has one major advantage for this design

The **inner/outer model is extremely natural in C**.

For example:

```c
typedef struct mt_node {
    struct mt_node *link;
    const void *type_id;
} mt_node;
```

Application code:

```c
typedef struct message {
    mt_node node;
    int value;
    char text[64];
} message;
```

The inner can be anywhere in the outer:

```c
typedef struct message {
    int value;
    mt_node node;
    char text[64];
} message;
```

Then ctk can recover the outer using `offsetof()`.

Conceptually:

```c
outer = (char *)node - offsetof(message, node);
```

This directly implements Part 4.3.

C therefore does **not** need the C3 `inline` mechanism.

---

# 5. But C needs a deliberate answer to type identity

This is probably the most important ctk-specific design decision.

The specification says:

> one runtime-unique value per outer type.

C has no native runtime type ID.

The natural C solution is:

```c
static const unsigned char message_type_id;
static const unsigned char request_type_id;
static const unsigned char response_type_id;
```

and:

```c
node->type_id = &message_type_id;
```

Comparison:

```c
node->type_id == &message_type_id
```

However, I would **not expose this mechanism directly to application code**.

The helper layer should own it.

---

# 6. The C helper should probably be macro-generated

This is where ctk differs substantially from ztk.

C has no:

* comptime
* templates
* generic structs
* reflection
* C3 macros with the same power

But C macros are sufficient for the required helper surface.

I would aim for something conceptually like:

```c
MT_DECLARE_NODE(message)
```

which generates the declarations needed for `message`.

Then:

```c
MT_DEFINE_NODE(message, node)
```

could generate the implementation.

The exact macro API should be designed carefully before coding.

I would **not** attempt to create a fake C "generic object".

The generated API should remain visibly C.

---

# 7. Don't make `_Generic` the foundation

C's `_Generic` is tempting.

For example:

```c
MT_FROM_NODE(message, node)
```

could theoretically dispatch based on the pointer type.

But `_Generic` is not the right foundation for Matryoshka.

The fundamental operation is:

```text
type-erased handle
        ↓
runtime identity check
        ↓
typed pointer
```

That is runtime type identification, not compile-time overload resolution.

Use macros for **code generation**, not as a replacement for the runtime identity mechanism.

---

# 8. Suggested core types

I would keep the core extremely small.

Something approximately like:

```c
typedef struct mt_node mt_node;

typedef mt_node *mt_handle;

typedef mt_handle mt_slot;
```

with:

```c
struct mt_node {
    mt_node *link;
    const void *type_id;
};
```

This is attractive because it maps directly onto Parts 4, 5, 8 and 9.

A Slot then has exactly the intended semantics:

```c
mt_slot slot = NULL;
```

Acquire:

```c
mt_pool_get(pool, type_id, &slot);
```

Transfer:

```c
mt_mailbox_send(mailbox, &slot);
```

Typed claim:

```c
message *msg = message_from_slot(&slot);
```

The important property is:

```text
slot != NULL  → caller owns item
slot == NULL  → item moved elsewhere
```

---

# 9. I would make Slot a distinct C type

This is one place where I would choose the stronger option from Part 20.

Instead of:

```c
typedef mt_node *mt_slot;
```

I would seriously consider:

```c
typedef struct {
    mt_node *node;
} mt_slot;
```

Then:

```c
mt_slot slot = { 0 };
```

and:

```c
slot.node
```

rather than:

```c
slot
```

This makes accidental mixing of handles and Slots harder.

For example:

```c
mt_handle h;
mt_slot slot;
```

are now visibly different things.

That is valuable in C because the compiler gives us much less protection than Zig or C3.

### But

I would **not** make Slot opaque.

The zero/null representation is useful and simple.

So my recommendation is:

> **distinct struct type, transparent representation.**

---

# 10. Exact link test: use the C3 idea

I strongly recommend carrying the 3tk realization here.

Use the **self-link terminator** rather than adding a membership field.

Conceptually:

```text
not linked:
    node->link == NULL

linked:
    ...
```

But because a singly-linked structure needs a terminator, use:

```text
last node
    link → itself
```

Then:

```c
node->link != NULL
```

means linked.

Walking ends with:

```c
if (node->link == node)
    ...
```

This gives ctk the same useful property as 3tk:

> **one link field, exact O(1) linked test.**

That is particularly attractive in C because every application item pays for every field.

---

# 11. Two primitives

I would also follow the newer specification rather than recreating ztk's general list.

Implement:

```text
mt_queue
mt_stack
```

### Queue

For mailbox:

```text
push_back
pop_front
empty
count
move_all
push_slot
```

### Stack

For pool buckets:

```text
push
pop
empty
count
move_all
push_slot
```

This keeps the C implementation small.

It also avoids implementing:

* middle removal
* insert before
* insert after
* previous links
* unnecessary walkers

unless a later use proves they are needed.

---

# 12. Mailbox representation

I recommend two queues.

```text
mailbox
 ├── out_of_band queue
 └── ordinary queue
```

Receive:

```text
if out_of_band not empty
    take from out_of_band
else
    take from ordinary
```

This is much cleaner than reproducing the ztk anchor mechanism.

It directly expresses the actual invariant:

```text
OOB FIFO
before
ordinary FIFO
```

And both insertions remain O(1).

---

# 13. Pool representation

The pool should be identity-indexed.

Conceptually:

```text
pool
 ├── identity A → stack
 ├── identity B → stack
 ├── identity C → stack
 └── ...
```

The major C question is:

> How do we map `type_id` → bucket?

I would **not** build a general hash table initially.

Since the set of identities is fixed at pool creation, use a registration table.

For example:

```text
pool creation
    ↓
registered identities
    ↓
bucket per identity
```

Each bucket contains:

```c
struct mt_bucket {
    const void *type_id;
    mt_stack items;
};
```

Lookup can initially be linear.

That is acceptable if the number of registered item types is modest, and it keeps the implementation dramatically simpler.

A later implementation can replace lookup without changing the API.

---

# 14. Pool hooks

C should use the straightforward representation:

```c
typedef struct {
    void *ctx;

    void (*on_get)(...);
    void (*on_put)(...);
    void (*on_close)(...);
} mt_pool_hooks;
```

This follows the portable specification exactly.

Do not try to create a pseudo-object-oriented C interface.

The callback + `void *ctx` pattern is idiomatic C and is exactly what the design needs.

---

# 15. The dangerous Part 12.3 must be designed first

This is the part I would emphasize most in the ctk proposal.

The pool needs:

```text
lock
 ↓
remove item
 ↓
unlock
 ↓
application hook
 ↓
lock
 ↓
re-read closed
```

The critical race is:

```text
Thread A                         Thread B

put()
  lock
  take item
  unlock
  hook()
                                close()
                                  lock
                                  closed = true
                                  drain
                                  unlock
                                  close_hook()

hook returns
  lock
  read closed == true
  send hook-produced items
  to close hook
```

Therefore ctk must explicitly implement the 005 rule:

> **After every put hook returns, re-read `closed` under the pool mutex.**

And the call remains counted until the hook has returned.

---

# 16. Quiet lifetime

This is the other area where ctk should **not** simply copy ztk.

I would implement the 005 model directly:

```text
OPEN
  ↓ close()
CLOSED
  ↓ last in-flight call returns
QUIET
  ↓ release()
FREED
```

The container should maintain something like:

```c
size_t active_calls;
```

under its mutex.

Every accepted call does:

```text
lock
check closed
active_calls++
unlock
```

and on completion:

```text
lock
active_calls--
unlock
```

Release checks:

```text
closed == true
active_calls == 0
```

and **does not wait**.

This is precisely the new 005 rule.

---

# 17. Important C API question: release

I would make release take only the object.

For example:

```c
void mt_mailbox_destroy(mt_mailbox *mailbox);
void mt_pool_destroy(mt_pool *pool);
```

Not:

```c
void mt_pool_destroy(mt_pool *pool, allocator *allocator);
```

For Linux C, the allocator decision needs more thought.

---

# 18. Allocator decision

For ctk I recommend:

### Infrastructure

Use an allocator supplied at creation, stored in the object.

But because this is C, the allocator should probably be a tiny callback interface:

```c
typedef struct {
    void *ctx;
    void *(*alloc)(void *ctx, size_t size);
    void (*free)(void *ctx, void *ptr);
} mt_allocator;
```

Then:

```c
mt_pool_create(..., mt_allocator allocator);
```

and:

```c
mt_pool_destroy(pool);
```

uses the stored allocator.

This follows Part 13.1.

### Application items

I would initially **not require an allocator field in every application item**.

That preserves the very small inner:

```text
link
type_id
```

and leaves item lifetime to application policy.

This should be documented as the ctk decision for Part 20.2.

---

# 19. Thread implementation

For Linux:

```c
pthread_create()
pthread_mutex_init()
pthread_cond_init()
pthread_cond_wait()
pthread_cond_timedwait()
pthread_mutex_lock()
pthread_mutex_unlock()
pthread_cond_signal()
pthread_cond_broadcast()
```

The toolkit itself does not call `pthread_create()`.

The application owns the threads.

This is important:

```text
ctk
 ├── does NOT create threads
 ├── does NOT own threads
 └── does NOT implement a scheduler
```

The application does:

```c
pthread_create(...)
```

and gives each worker its mailbox/pool handles.

---

# 20. Timed wait

This should be much simpler than ztk.

Linux pthreads already provides:

```c
pthread_cond_timedwait()
```

So ctk does not need the Zig-specific timed-condition machinery.

The only tricky part is getting the semantics right:

```text
duration
   ↓
absolute deadline
   ↓
while condition false
    pthread_cond_timedwait(deadline)
```

Never recreate the deadline after a spurious wakeup.

I would test this specifically.

---

# 21. Clock choice

For timed waits, ctk should configure the condition variable to use a monotonic clock if Linux/POSIX permits it:

```c
pthread_condattr_setclock(&attr, CLOCK_MONOTONIC);
```

Then the ctk deadline can be based on:

```c
clock_gettime(CLOCK_MONOTONIC, ...)
```

This avoids wall-clock changes affecting timeouts.

This is an implementation improvement over simply copying whatever the C3 port currently does.

---

# 22. Interruption

I would initially answer Part 20.8:

> **ctk does not model interruption.**

So ctk outcomes are:

```text
timeout
closed
woken
item
```

with no `interrupted`.

There is no need to introduce pthread cancellation into the toolkit.

In fact, I would strongly recommend **not using pthread cancellation** as the implementation of Part 2.9.

It complicates the lifetime contract substantially.

---

# 23. Pre-lock closed fast path

I would initially **drop it**.

Part 15.4 explicitly allows this.

So:

```text
lock
 ↓
read closed
 ↓
perform operation
 ↓
unlock
```

rather than:

```text
atomic closed read
 ↓
possibly lock
 ↓
re-read closed
```

The simpler implementation is much easier to audit.

Later, if profiling shows the closed check is hot, add the atomic fast path.

This should be documented as the ctk decision, not silently omitted.

---

# 24. Assertions

C gives us:

```c
assert()
```

but `assert()` disappears under `NDEBUG`.

That is appropriate for most contract violations.

However:

```text
destroy(open container)
destroy(closed but active container)
```

must remain fatal in **all builds**, according to Part 11.12.

Therefore I would have a separate internal mechanism:

```c
mt_contract_fail(...)
```

for the unconditional lifetime violation.

For ordinary checks:

```c
assert(...)
```

is enough.

---

# 25. Opaque public structures

Here C is particularly good.

Public:

```c
typedef struct mt_mailbox mt_mailbox;
typedef struct mt_pool mt_pool;
```

Private implementation:

```c
struct mt_mailbox {
    mt_node node;
    pthread_mutex_t mutex;
    pthread_cond_t cond;
    bool closed;
    size_t active_calls;
    ...
};
```

This gives ctk a genuine improvement over ztk.

The application cannot accidentally manipulate:

* mutex
* condition variable
* closed state
* queue
* active call count

directly.

---

# 26. Suggested repository

I would create:

```text
matryoshka-tk/
    c/
        README.md
        CMakeLists.txt

        include/
            matryoshka/
                node.h
                helper.h
                slot.h
                queue.h
                stack.h
                mailbox.h
                pool.h
                allocator.h

        src/
            node.c
            queue.c
            stack.c
            mailbox.c
            pool.c

        tests/
            test_node.c
            test_slot.c
            test_queue.c
            test_stack.c
            test_mailbox.c
            test_pool.c
            test_concurrency.c
            test_lifetime.c

        examples/
            echo.c
            pool.c
            mailbox.c
```

But I would first decide whether this belongs in a separate repository.

If the existing naming convention is:

```text
matryoshka-ztk
matryoshka-3tk
```

then:

```text
matryoshka-ctk
```

is the cleanest.

---

# 27. CLion vs VS Code

For this project I recommend **CLion** as the primary IDE.

CMake + CLion is an excellent match for ctk.

Use:

```text
CMake
GCC
Clang
clangd
CTest
GDB
```

CLion gives you:

* CMake integration
* debugger
* sanitizer integration
* test integration
* refactoring
* code navigation
* pthread debugging
* compile database handling

VS Code is perfectly usable, especially with:

```text
clangd
CMake Tools
CodeLLDB
```

but I would make the project **IDE-neutral**.

The repository should require only:

```text
cmake
cc
make/ninja
```

CLion is then just the preferred development environment.

---

# 28. Sanitizers should be first-class

This is particularly important for ctk because the specification has several lifetime traps.

CI should run:

```text
AddressSanitizer
UndefinedBehaviorSanitizer
ThreadSanitizer
```

especially:

```text
-lpthread
-fsanitize=address,undefined
-fsanitize=thread
```

The lifetime tests should be designed around the exact 005 failures.

---

# 29. Tests should follow the specification, not the implementation

I would structure the tests around Parts/invariants.

For example:

```text
test_part04_intrusion
test_part05_identity
test_part06_crossing
test_part08_link_test
test_part09_slot
test_part11_mailbox
test_part11_pool
test_part11_closed_quiet
test_part12_hook_race
test_part14_transfer
test_part15_concurrency
```

This is much more useful than copying the C3 test names.

---

# 30. The most important concurrency test

The ctk test suite absolutely needs a deterministic reproduction of the 005 race.

Something like:

```text
put()
   |
   | unlock
   v
on_put()
   |
   |--- block here
   |
close()
   |
   | closed = true
   | drain
   | on_close()
   |
   v
release opportunity
   |
on_put() resumes
   |
   v
re-lock
   |
read closed
   |
send held items to on_close
```

The test must prove:

```text
invariant 34
invariant 35
quiet lifetime
```

and not merely rely on probabilistic thread scheduling.

This was exactly the kind of defect that produced 005, so ctk should make it a deliberate test from day one.

---

# 31. Proposed ctk implementation stages

I would use **six stages**, rather than trying to port everything in one pass.

### CTK-01 — Capability and API decision

Produce:

```text
ctk-capabilities.md
ctk-decisions.md
ctk-api.md
```

Answer every Part 20 and Part 21 question.

Particularly:

* C11 baseline
* Slot representation
* identity mechanism
* helper generation
* exact link test
* allocator
* interruption
* atomics
* queue/stack
* hook interface

No implementation yet.

---

### CTK-02 — Core

Implement:

```text
node
identity
helper
Slot
queue
stack
```

No mailbox.

No pool.

Tests for Parts 4–10.

This is the actual Matryoshka core.

---

### CTK-03 — Mailbox

Implement:

```text
send
send_oob
receive
poll
receive_batch
close
wake_all
```

with:

```text
mutex
condition variable
closed
active_calls
```

Tests for Parts 11.3–11.6.

---

### CTK-04 — Pool

Implement:

```text
get
get_wait
put
close
```

and identity buckets.

Then hooks.

---

### CTK-05 — Lifetime and concurrency hardening

This stage is important enough to be separate.

Verify:

```text
Part 11.12
Part 12.3
Part 15
Invariant 34
Invariant 35
```

with deterministic race tests and sanitizers.

---

### CTK-06 — Examples and documentation

Only after the implementation is stable:

```text
README
API reference
architecture
Slot idiom
hooks
lifetime
porting notes
examples
```

---

# 32. Proposed ctk-specific decisions

My initial proposal would be:

| Decision                   | ctk                               |
| -------------------------- | --------------------------------- |
| Language                   | **C11**                           |
| Target                     | Linux/POSIX                       |
| Compiler                   | GCC + Clang                       |
| Build                      | CMake                             |
| IDE                        | CLion primary, VS Code supported  |
| Threads                    | pthread                           |
| Mutex                      | pthread mutex                     |
| Condition                  | pthread condition                 |
| Timed wait                 | `pthread_cond_timedwait`          |
| Clock                      | `CLOCK_MONOTONIC`                 |
| Interruption               | excluded                          |
| Atomics                    | C11                               |
| Closed fast path           | initially omitted                 |
| Inner                      | embedded `mt_node`                |
| Identity                   | address of per-type static object |
| Helper                     | macros                            |
| Slot                       | distinct transparent struct       |
| Link test                  | self-link terminator              |
| List                       | no general list initially         |
| Mailbox                    | two FIFO queues                   |
| Pool                       | stack per identity                |
| Pool lookup                | fixed registration table          |
| Hooks                      | function pointers + `void *ctx`   |
| Infrastructure             | opaque public structs             |
| Allocator                  | stored in infrastructure          |
| Application item allocator | none initially                    |
| Quiet tracking             | `active_calls`                    |
| Release                    | closed + quiet required           |
| Release check              | unconditional                     |
| Interruption               | no                                |
| Scheduler                  | no                                |
| Thread creation            | application                       |
| Async runtime              | no                                |

---

# 33. One thing I would change in the portable specification before ctk

I would **not change 005 yet**.

Instead, ctk should expose questions that 005 deliberately leaves open.

The important one is the C helper.

C cannot honestly claim:

> generated per-type helper

in the same sense as Zig or C3.

Its mechanism will be macro expansion.

That is perfectly conformant under the new 7.1 wording.

So ctk can become another useful realization proving that 005 is genuinely language-independent:

```text
ztk → comptime-generated named helper
3tk → macro call-site expansion
ctk → C preprocessor-generated API
```

That is exactly the kind of evidence the evolution from 002 → 005 was trying to achieve.

---

# 34. Overall recommendation

I think **ctk is a very good next port**, and C may actually expose weaknesses that Zig and C3 hide.

The key principle should be:

> **Do not port the C3 implementation. Port the 005 contract.**

Use 3tk as an implementation reference where it already found a better realization:

* one-link intrusive nodes
* exact self-link membership
* queue + stack
* two mailbox queues
* opaque containers
* deterministic lifetime testing

But independently decide the C mechanisms.

The resulting three realizations would then be meaningfully different:

```text
                Portable specification 005
                           │
       ┌───────────────────┼───────────────────┐
       │                   │                   │
       ▼                   ▼                   ▼
      ztk                  3tk                 ctk
      Zig                  C3                   C
       │                    │                   │
 comptime              macros/typeid       preprocessor
 std.Io                C3 threads          pthread
 intrusive list        queue + stack       queue + stack
 named helper          call-site helper    macro helper
```

**My strongest recommendation is to make CTK-01 a written capability/decision stage before writing C code.** That will prevent the C implementation from accidentally turning C limitations into new Matryoshka rules—the exact failure mode that 003–005 were created to eliminate.
