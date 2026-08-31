# ctk-api-001.md

# ctk — C API Porting Analysis

**Status:** API/design review  
**Source:** current C23 translation of 3tk supplied for this review  
**Target:** C port of Matryoshka-Tk  
**Date:** 2026-08-30

---

## 1. Verdict

The current C translation proves that the **3tk object model can be expressed in C** without changing the core Matryoshka semantics.

The important parts map naturally:

- `Inner` → embedded C struct.
- `Handle` → pointer to embedded `Inner`.
- `Slot` → one `Handle` or `NULL`.
- `InnerQueue` → intrusive FIFO container.
- `InnerStack` → intrusive LIFO container.
- `Pool` → typed resource owner.
- `Mailbox` → concurrent transfer container.
- C3 methods → namespaced C functions.
- C3 `typeid` → explicit type identity.
- C3 generic/reflection operations → macros plus `offsetof`.
- C3 hooks/interfaces → function-pointer structures.

However, the current files should **not yet be treated as the ctk API**.

They are a useful mechanical port, but several details are either C-specific defects or signs that the API needs a deliberate C design pass.

The biggest recommendation is:

> **Keep the 3tk semantics, but do not mechanically preserve the C3 surface syntax. Design ctk as a C API with C naming, explicit receivers, explicit result values, and a small amount of carefully isolated macro machinery.**

---

# 2. What Should Be Preserved

The port should preserve the following 3tk model exactly.

## 2.1 `Inner` is the embedded identity/link field

An application object owns an embedded `Inner`.

```c
typedef struct Message {
    Inner inner;
    int value;
} Message;
```

`Inner` is not the object.

It is the part that allows Matryoshka to transport the object without knowing its outer type.

---

## 2.2 `Handle` remains the universal transported value

```c
typedef Inner* Handle;
```

This is the correct C representation.

The containers should not know about `Message`, `Request`, `Response`, or any other application type.

They only move `Handle`.

---

## 2.3 `Slot` remains the transfer boundary

```c
typedef Handle Slot;
```

This is also a good C representation.

A Slot is:

- empty → `NULL`
- full → one valid `Handle`

The important semantic rule remains:

> The Slot tells the caller where the item went.

This is particularly valuable in C because C has no C3-style optional-return syntax.

---

# 3. The C API Should Be Explicitly C-Shaped

Do not attempt to reproduce C3's method syntax.

Use:

```c
Slot_fill(&slot, handle);
Slot_take(&slot);

InnerQueue_push_back(&queue, handle);
InnerQueue_pop_front(&queue);

Pool_get(pool, type_id, mode, &slot);
Pool_put(pool, &slot);

Mailbox_send(mailbox, &slot);
Mailbox_receive(mailbox, &slot, timeout);
```

This is already what the current translation is moving toward.

That is preferable to building a macro-heavy pseudo-object system.

The receiver should always be visible.

---

# 4. Separate the Public API From Implementation Machinery

The current translation puts almost everything in headers as `static inline` functions.

That is useful for experimentation, but it should not automatically become the final ctk layout.

Recommended structure:

```text
ctk/
    include/
        ctk/
            inner.h
            helper.h
            queue.h
            stack.h
            mailbox.h
            pool.h
            managed.h
            ctk.h

    src/
        inner.c
        mailbox.c
        pool.c

    tests/
    examples/
```

The small, genuinely generic operations can remain inline.

The synchronization and lifecycle implementations should preferably live in `.c` files.

This gives ctk:

- smaller public headers,
- less macro exposure,
- stable implementation boundaries,
- easier ABI evolution,
- cleaner compiler diagnostics.

---

# 5. Important C Defect: Statement Expressions Are Not Standard C23

The current translation repeatedly uses:

```c
({
    ...
})
```

For example:

```c
#define from_handle(...) ({
    ...
})
```

This is a **GNU statement-expression extension**.

It is not standard C23.

Therefore the current implementation should not be described as:

> standard C23

without qualification.

It is better described as:

> C23 with compiler extensions

or, if GCC/Clang GNU mode is intentionally required:

> GNU C23 / C23-compatible implementation using statement expressions.

This matters for ctk because portability is part of the API decision.

---

# 6. Recommendation: Minimize Statement Expressions

Most of the current macros can be redesigned without statement expressions.

For example, simple conversions can use ordinary functions where the offset is already known.

The difficult part is the generic `Type + member` conversion.

There are three possible directions.

## Option A — GNU C23

Keep statement expressions.

Advantages:

- concise,
- powerful,
- close to the current translation,
- excellent Clang/GCC support.

Disadvantage:

- not strictly standard C23.

## Option B — standard C23 macros

Use ordinary macros and require the caller to provide enough information for a standard expression.

This is more portable but less elegant.

## Option C — explicit typed conversion helpers

Use macros only at the outer boundary and ordinary functions internally.

This gives the cleanest implementation.

### Recommendation

For ctk:

> **Use C23 plus a very small, documented compiler-extension layer if that materially improves the API. Do not let statement expressions spread through the whole library.**

The Matryoshka semantics are more important than pretending every implementation detail is pure ISO C.

---

# 7. Critical Type-ID Problem

The current translation contains constructs such as:

```c
#define MAILBOX_TYPE_ID ((const void*)&"Mailbox")
```

and:

```c
#define POOL_TYPE_ID ((const void*)&"Pool")
```

This should be changed.

A string literal address is not a good type identity.

String literal pooling and translation-unit behavior make this a poor foundation for identity.

There is an even more important problem with header-defined identities:

> A `static` identity object in a header creates a separate identity in every translation unit.

A handle created in one translation unit can therefore fail an identity comparison performed in another translation unit.

---

# 8. Recommended Type-ID Model

Give each public type exactly one identity object with external linkage.

For example:

### Header

```c
extern const unsigned char ctk_mailbox_type_id;
extern const unsigned char ctk_pool_type_id;
```

### Source

```c
const unsigned char ctk_mailbox_type_id = 0;
const unsigned char ctk_pool_type_id = 0;
```

Then:

```c
#define CTK_MAILBOX_TYPE_ID ((const void*)&ctk_mailbox_type_id)
#define CTK_POOL_TYPE_ID    ((const void*)&ctk_pool_type_id)
```

This gives one address per type across the complete program.

For application types, the same model can be used:

```c
extern const unsigned char message_type_id;
```

and in exactly one `.c` file:

```c
const unsigned char message_type_id = 0;
```

This is a much better C equivalent of C3's `typeid`.

---

# 9. `Any` Should Not Be in the Core Unless It Is Actually Needed

The current `Inner` is:

```c
typedef struct Inner {
    Any link;
} Inner;
```

where:

```c
typedef struct {
    void* ptr;
    const void* type;
} Any;
```

This is mechanically understandable, but it introduces an abstraction that the rest of the design does not really need.

The actual semantic payload is:

```text
link pointer
type identity
```

A simpler representation is:

```c
typedef struct Inner {
    struct Inner* next;
    const void* type;
} Inner;
```

or, if the existing `Any` abstraction is intentionally part of ctk:

```c
typedef struct Inner {
    Handle link;
    TypeId type;
} Inner;
```

The exact layout should be decided deliberately.

Do not retain `Any` merely because C3 used `any`.

---

# 10. `Inner` Should Express the Invariant Directly

The current comments describe:

> Every chain ends at an item pointing at itself, never at null.

This is an important Matryoshka invariant.

The implementation should make this obvious.

The core operations should therefore be:

```c
Handle Inner_points_to(const Inner* self);
void Inner_repoint_to(Inner* self, Handle to);
bool Inner_is_linked(Handle h);
void Inner_reset(Handle h);
```

The names can be shortened if desired, but the semantic distinction should remain:

- `NULL` link → detached.
- self link → chain terminator.
- another handle → next element.

This is one of the strongest parts of the 3tk design and should survive the port.

---

# 11. `reset()` Is a Core Operation

The current implementation correctly keeps identity while clearing the chain link.

That distinction must remain:

```text
reset:
    clears linkage
    preserves type identity
```

It is not an object destructor.

It is not object initialization.

It is a transport-state operation.

This should be emphasized in the public API documentation.

---

# 12. Queue API Is Already Close to Good C

The current queue API is one of the strongest parts of the port.

Recommended public shape:

```c
typedef struct {
    Handle head;
    Handle tail;
    size_t count;
} InnerQueue;

bool   InnerQueue_is_empty(const InnerQueue*);
size_t InnerQueue_len(const InnerQueue*);

void   InnerQueue_push_back(InnerQueue*, Handle);
Handle InnerQueue_pop_front(InnerQueue*);

InnerQueue InnerQueue_take(InnerQueue*);
void InnerQueue_append_queue(InnerQueue*, InnerQueue*);
```

The important semantics remain:

- O(1) push.
- O(1) pop.
- O(1) append.
- O(1) length.
- no allocation.
- ownership remains with the caller.

This is a good fit for C.

---

# 13. Queue Iterator Needs One Decision

The current iterator is:

```c
typedef struct InnerQueueIterator {
    Inner* cur;
} InnerQueueIterator;
```

This is reasonable.

The C API should probably expose:

```c
InnerQueueIterator InnerQueue_iter(const InnerQueue*);
Handle InnerQueueIterator_next(InnerQueueIterator*);
```

rather than attempting a callback-based iterator.

The iterator should retain the 3tk rule:

> Removing the current item during a walk is not supported.

That restriction is useful because it keeps the iterator simple and O(1).

---

# 14. Stack API Is Also Appropriate

The current stack is simple:

```c
typedef struct {
    Handle top;
    size_t count;
} InnerStack;
```

Recommended API:

```c
bool   InnerStack_is_empty(const InnerStack*);
size_t InnerStack_len(const InnerStack*);

void   InnerStack_push(InnerStack*, Handle);
Handle InnerStack_pop(InnerStack*);
```

Do not add unnecessary iteration or splice operations.

The current design intentionally makes the stack a small internal storage primitive.

Keep it small.

---

# 15. Debug Guards Need Consistent Policy

The queue and stack insertion guards are disabled under `NDEBUG`.

But some other checks, such as `mtk_check`, remain active.

This creates two classes of contract:

```text
debug-only validation
always-on validation
```

That is fine if intentional.

It should be documented.

Otherwise the API may appear inconsistent.

A useful split is:

### Programmer-contract violations

Examples:

- null handle insertion,
- already-linked item,
- wrong Slot state,
- unknown Pool identity.

These can be debug assertions if release builds are explicitly contract-trusting.

### Runtime operational results

Examples:

- closed,
- empty,
- timeout,
- woken,
- allocation failure.

These must remain normal API results.

This distinction should become part of ctk's design.

---

# 16. `Slot_fill()` Is Correctly Strict

This is a good rule:

```c
Slot_fill(slot, handle);
```

must reject:

- a null handle,
- overwriting a full Slot.

This preserves a very useful invariant:

> A Slot is never silently overwritten.

Likewise:

```c
Slot_take()
```

is a destructive read.

The current API has a good trio:

```c
Slot_is_empty()
Slot_is_full()
Slot_peek()
Slot_take()
```

Keep it.

---

# 17. Managed API Needs a C-Specific Redesign

The current:

```c
mtk_create(...)
mtk_release(...)
```

is heavily macro driven.

The semantics are good:

- allocation,
- allocator stored with object,
- initialization,
- Slot filled on success,
- release uses object's allocator.

But the C API should probably expose a more readable call convention.

For example:

```c
bool ctk_create(
    Allocator allocator,
    size_t size,
    ...
);
```

or a type-specific macro only around the structural information.

The current API forces many arguments:

```text
Type
inner_member
alloc_member
TypeId
allocator
slot
```

This is a consequence of replacing C3 reflection.

It should not automatically become the permanent public API.

---

# 18. Reflection Should Be Confined to the Boundary

The current macros use:

```c
offsetof(Type, member)
```

This is a good replacement mechanism for the C3 reflection used by 3tk.

But it should be confined to a few macros:

```text
to_handle
from_handle
init
required_alloc_offset
```

Everything else should operate on:

```text
Handle
Slot
Inner
TypeId
```

This gives ctk a clean internal model.

---

# 19. `from_handle()` Is a Good C Equivalent

The current semantic contract is strong:

```text
from_handle:
    wrong identity → NULL
```

while:

```text
must_from_handle:
    wrong identity → programmer error
```

Keep both.

This is particularly valuable in C because there is no native generic object system.

Recommended naming could be:

```c
ctk_from_handle(...)
ctk_require_handle(...)
```

or retain:

```c
from_handle(...)
must_from_handle(...)
```

The important thing is the semantic difference.

---

# 20. `move_from_slot()` Is Especially Useful

The current operation:

```c
move_from_slot(...)
```

has a good ownership semantic:

1. inspect the handle;
2. verify identity;
3. convert to outer object;
4. clear Slot only after successful validation.

This is exactly the sort of operation C benefits from.

It avoids forcing every caller to write the sequence manually.

---

# 21. Mailbox Is Where the Port Needs the Most Review

The high-level mapping is correct:

```text
Mailbox
    mutex
    condition
    allocator
    closed state
    active operation count
    OOB queue
    regular queue
    wake generation
```

The concurrency architecture should remain.

However, the C implementation should receive a dedicated correctness pass before being considered complete.

---

# 22. Important Mailbox API Defect

The current source contains:

```c
static inline size_t Mailbox_len(Mailbox self)
```

This is wrong.

It passes the entire mailbox by value.

A `Mailbox` contains:

```c
pthread_mutex_t
pthread_cond_t
```

Copying those objects is not a valid way to invoke the method.

It should be:

```c
static inline size_t Mailbox_len(const Mailbox* self)
```

and:

```c
Mailbox_len(self);
```

The same general rule should be applied throughout ctk:

> **Never pass synchronization-bearing objects by value.**

---

# 23. The Same Problem Exists in Pool

The current code contains:

```c
static inline void Pool_close(Pool self)
```

and:

```c
static inline size_t Pool_count_of(Pool self, TypeId t)
```

Both should take pointers:

```c
void Pool_close(Pool* self);
size_t Pool_count_of(const Pool* self, TypeId t);
```

This is not merely stylistic.

Copying `pthread_mutex_t` or `pthread_cond_t` is a correctness problem.

---

# 24. Remove Accidental `Pool_to_handle(self)`

The current `Pool_put()` contains:

```c
Pool_to_handle(self);
```

with no use of the result.

This appears to be an accidental remnant of the source translation.

It should be removed.

The ctk review should explicitly eliminate such mechanical-port artifacts.

---

# 25. Mailbox Active Count Has a Clear Purpose

The current `_active` mechanism is useful.

It protects lifecycle operations that temporarily release the mutex.

For example:

```text
Pool operation starts
    _active++

unlock mutex

application hook runs

lock mutex
    _active--

```

This is important because the object cannot be released while an operation is still using it.

The same principle applies to Mailbox and Pool close/release.

This should remain a documented lifecycle invariant.

---

# 26. Hooks Must Run Outside the Pool Mutex

The current Pool design gets this important point right.

The sequence is:

```text
lock
validate
_active++
collect state
unlock

hook()

lock
_active--
unlock
```

The hook must not execute while holding the Pool mutex.

Otherwise application code could:

- call back into Pool,
- allocate,
- block,
- communicate,
- call another Matryoshka component,

while the Pool lock is held.

That would create unnecessary deadlock and latency risks.

Keep the current architectural direction.

---

# 27. Pool Close / Put Needs Dedicated Stress Tests

The most delicate sequence is:

```text
Pool_put()
    detach item
    unlock
    on_put()
    lock
    observe closed
    route returned item to on_close()
```

This is the correct area to preserve from the 3tk design.

It needs tests for:

1. close before `on_put`;
2. close during `on_put`;
3. `on_put` returns the original item;
4. `on_put` returns extra items;
5. `on_put` returns an invalid identity;
6. release after close;
7. concurrent get/put/close.

This is more important than adding additional API features.

---

# 28. Result Types Should Be Explicit

The current:

```c
typedef enum {
    MTK_SUCCESS,
    MTK_CLOSED,
    MTK_EMPTY,
    MTK_TIMEOUT,
    MTK_WOKEN,
    MTK_ERROR
} MtkResult;
```

is a good C translation strategy.

But `MTK_ERROR` is too broad.

Where practical, distinguish:

```text
closed
empty
timeout
woken
not_created
invalid_argument
```

Do not collapse normal semantic results into generic error values.

A possible ctk result set is:

```c
typedef enum {
    CTK_OK,
    CTK_CLOSED,
    CTK_EMPTY,
    CTK_TIMEOUT,
    CTK_WOKEN,
    CTK_NOT_CREATED,
    CTK_ERROR
} CtkResult;
```

The exact names should be aligned with the final 3tk portable specification.

---

# 29. Avoid Pretending C Has C3 Optional Results

The current managed translation says C3 `void?` maps to `bool`.

That is workable, but the public C documentation should describe the C semantics directly.

For example:

```c
bool ctk_create(...);
```

means:

```text
true  = object created and Slot filled
false = allocation failed and Slot unchanged
```

That is clearer than explaining it as a simulation of C3.

The C port should stand on its own.

---

# 30. Allocator Should Become a Shared Primitive

`Allocator` currently appears in `mtk_managed.h` and is then reused by Mailbox and Pool.

It should have its own header:

```text
allocator.h
```

For example:

```c
typedef struct CtkAllocator {
    void* context;
    void* (*alloc)(void*, size_t);
    void  (*free)(void*, void*);
} CtkAllocator;
```

The naming should be chosen once and used consistently.

---

# 31. Do Not Tie the Core API to Linux Pthreads

The current mailbox and pool translation directly uses:

```c
pthread_mutex_t
pthread_cond_t
```

This is fine for the first C prototype.

It should not automatically become the portable ctk API.

Matryoshka-Tk is the architecture.

The concurrency implementation is an implementation layer.

Therefore consider:

```text
ctk core
    Inner
    Handle
    Slot
    Queue
    Stack
    Helper
    Managed

ctk synchronization backend
    mutex
    condition
    atomic
    time
```

This keeps the same architectural separation already established for Matryoshka-Tk.

---

# 32. Recommended First C Target

Do not attempt to make ctk universally portable immediately.

A practical first target is:

```text
C23
Clang
Linux
pthread
stdatomic
```

Then make the API boundary clean enough that another synchronization backend can be introduced later.

This gives a much smaller first implementation task.

---

# 33. Naming Recommendation

The current translation retains many `InnerXxx` names.

That is reasonable because `Inner` is a real architectural concept.

Recommended naming:

```text
Ctk / public generic
    Handle
    Slot
    TypeId
    Inner

containers
    InnerQueue
    InnerStack

conversions
    to_handle
    from_handle
    must_from_handle

lifecycle
    create
    release

concurrency
    Mailbox
    Pool
```

Alternatively prefix all public symbols:

```text
ctk_inner_...
ctk_queue_...
ctk_pool_...
ctk_mailbox_...
```

For a library intended for integration into larger C applications, the second approach is safer against symbol collisions.

A good compromise is:

```text
CtkHandle
CtkSlot
CtkTypeId
CtkInner

CtkQueue
CtkStack
CtkMailbox
CtkPool
```

with:

```text
ctk_queue_push_back()
ctk_mailbox_send()
ctk_pool_get()
```

The final naming convention should be decided before implementation grows.

---

# 34. Do Not Introduce an OO Framework

The C API does not need:

- virtual tables for containers,
- base classes,
- inheritance macros,
- generic object structs,
- method-dispatch macros.

The 3tk architecture already has the useful form of polymorphism:

```text
typed application object
        ↓
embedded Inner
        ↓
Handle
        ↓
generic Matryoshka container
```

That is enough.

The C port should preserve this structural polymorphism rather than inventing runtime OO.

---

# 35. Suggested API Layers

The final ctk API should have approximately five layers.

## Layer 1 — Intrusive identity

```text
Inner
Handle
TypeId
reset
is_linked
```

## Layer 2 — Slot

```text
Slot
Slot_is_empty
Slot_is_full
Slot_peek
Slot_take
Slot_fill
```

## Layer 3 — Structural containers

```text
Queue
Stack
```

## Layer 4 — Typed ownership

```text
Helper
Managed
Pool
```

## Layer 5 — Concurrency

```text
Mailbox
Pool waiting
```

This is essentially the existing 3tk architecture translated into a C-friendly dependency graph.

---

# 36. Header Dependency Direction

Recommended dependency direction:

```text
allocator
    ↓
inner
    ↓
slot/helper
    ↓
queue / stack
    ↓
managed
    ↓
pool / mailbox
```

Avoid circular header dependencies.

In particular:

```text
inner.h
```

should not depend on Pool or Mailbox.

---

# 37. Test Strategy

The C port should not rely only on compiling examples.

Build tests around invariants.

## Inner tests

- initialization preserves identity;
- reset preserves identity;
- detached item has null link;
- linked item has non-null link;
- self-link terminates chain.

## Slot tests

- empty initially;
- fill;
- peek;
- take;
- double fill fails;
- null fill fails.

## Queue tests

- FIFO;
- count;
- singleton;
- multiple elements;
- append;
- take;
- iterator.

## Stack tests

- LIFO;
- count;
- singleton;
- empty pop;
- reset after pop.

## Helper tests

- correct identity;
- wrong identity;
- `from_handle`;
- `must_from_handle`;
- Slot conversion;
- move semantics.

## Pool tests

- get new;
- get available;
- put;
- get_wait;
- timeout;
- close;
- hooks;
- concurrent close/put/get.

## Mailbox tests

- send;
- poll;
- receive;
- timeout;
- wake;
- OOB priority;
- receive_all;
- close;
- concurrent send/receive/close;
- release only after quiet.

---

# 38. Sanitizers Should Be Part of the Default Test Environment

For the C port, add at least:

```text
-fsanitize=address,undefined
```

and for concurrency testing where available:

```text
-fsanitize=thread
```

Also build with:

```text
-Wall
-Wextra
-Wpedantic
-Wconversion
-Wshadow
```

The exact warning set can be tuned later.

The important point is that the C port needs compiler diagnostics much more aggressively than the C3 implementation.

---

# 39. CI Should Test More Than One Compiler

Initial CI should contain at least:

```text
Clang
GCC
```

on Linux.

The reason is not broad portability yet.

It is to detect accidental dependence on one compiler's C extensions.

If GNU statement expressions remain, the CI should explicitly document that dependency.

---

# 40. Documentation Generation

The C API is a good candidate for Doxygen.

Use Doxygen for:

- public structs;
- functions;
- macros;
- lifecycle contracts;
- invariants.

The source comments can remain ordinary Doxygen comments.

The API documentation should explain the **C semantics**, not repeatedly describe how C3 was translated.

The 3tk specification can remain the semantic reference.

The ctk API documentation should be its C realization.

---

# 41. Recommended Repository Layout

A clean first repository layout:

```text
ctk/
├── include/
│   └── ctk/
│       ├── allocator.h
│       ├── inner.h
│       ├── helper.h
│       ├── queue.h
│       ├── stack.h
│       ├── managed.h
│       ├── mailbox.h
│       ├── pool.h
│       └── ctk.h
│
├── src/
│   ├── mailbox.c
│   ├── pool.c
│   └── typeid.c
│
├── tests/
│   ├── test_inner.c
│   ├── test_slot.c
│   ├── test_queue.c
│   ├── test_stack.c
│   ├── test_helper.c
│   ├── test_pool.c
│   └── test_mailbox.c
│
├── examples/
│
├── docs/
│
├── CMakeLists.txt
├── Makefile
├── README.md
└── LICENSE
```

The build system itself can be kept very small.

---

# 42. Package Manager

Do not make package management part of the ctk core API.

The library should be deployable as:

```text
headers + source
```

or:

```text
static library + headers
```

The package-manager decision can come after the API stabilizes.

The important requirement is that the repository has a reproducible build and test flow.

---

# 43. The Port Should Not Copy C3 Syntax Blindly

The current translation is useful because it exposes where C3's language features were doing real work.

The next step should therefore be a **semantic port**, not another mechanical translation.

For every C3 construct ask:

```text
What invariant does this provide?
```

Then implement that invariant in the simplest C form.

Examples:

```text
C3 typeid
    → stable TypeId object

C3 reflection
    → limited offsetof macros

C3 method syntax
    → explicit receiver

C3 optional result
    → explicit C result + Slot

C3 interface
    → function-pointer table

C3 slice
    → pointer + length

C3 defer
    → explicit cleanup discipline
```

This produces a better C library than trying to reproduce the language.

---

# 44. Proposed ctk API Principle

The central API rule should be:

> **Ctk moves handles, not objects.**

Then:

> **The application owns the object. Ctk owns only the transport or storage state appropriate to the component.**

And:

> **A Slot records transfer ownership at an API boundary.**

These three statements explain most of the library.

---

# 45. Recommended Changes Before Coding Further

Priority order:

### P0 — Correctness

1. Fix all synchronization-bearing by-value receivers.
2. Replace string-literal type IDs.
3. Resolve the statement-expression portability decision.
4. Remove mechanical translation leftovers such as unused `Pool_to_handle()`.
5. Audit all lock/unlock paths.
6. Stress-test close/release against active operations.

### P1 — API

7. Establish final C naming convention.
8. Separate allocator into its own module.
9. Define the public result enum.
10. Define the public TypeId mechanism.
11. Decide which macros remain public.
12. Decide header-only vs `.c` implementation.

### P2 — Infrastructure

13. Add Clang/GCC CI.
14. Add ASan/UBSan.
15. Add ThreadSanitizer tests.
16. Add Doxygen.
17. Add examples.
18. Add installation/package metadata.

---

# 46. Final Recommendation

The current C translation is a **good prototype and a useful semantic probe**.

It has demonstrated that the 3tk design maps cleanly to C.

But it should not be frozen as the ctk API yet.

The best next step is:

```text
3tk semantic specification
        ↓
current C mechanical translation
        ↓
ctk API cleanup
        ↓
small C implementation
        ↓
tests + sanitizers
        ↓
documentation
```

The C port should be deliberately **boring**.

That is an advantage.

Use:

- structs,
- pointers,
- function pointers,
- `_Atomic`,
- pthreads initially,
- `offsetof`,
- a few macros,
- explicit results.

Avoid building a C imitation of C3.

The most valuable thing being ported is not C3 syntax.

It is the **Matryoshka ownership, identity, Slot, intrusive-container, Pool, Mailbox, and lifecycle model**.

---

## 47. Short API Target

A useful first target for ctk is approximately:

```c
/* identity */
typedef struct CtkInner CtkInner;
typedef CtkInner* CtkHandle;
typedef CtkHandle CtkSlot;
typedef const void* CtkTypeId;

/* slot */
bool       ctk_slot_is_empty(const CtkSlot*);
bool       ctk_slot_is_full(const CtkSlot*);
CtkHandle  ctk_slot_peek(const CtkSlot*);
CtkHandle  ctk_slot_take(CtkSlot*);
void       ctk_slot_fill(CtkSlot*, CtkHandle);

/* inner */
bool       ctk_is_linked(CtkHandle);
void       ctk_reset(CtkHandle);

/* queue */
void       ctk_queue_push_back(CtkQueue*, CtkHandle);
CtkHandle  ctk_queue_pop_front(CtkQueue*);
void       ctk_queue_append(CtkQueue*, CtkQueue*);

/* stack */
void       ctk_stack_push(CtkStack*, CtkHandle);
CtkHandle  ctk_stack_pop(CtkStack*);

/* mailbox */
CtkResult  ctk_mailbox_send(CtkMailbox*, CtkSlot*);
CtkResult  ctk_mailbox_poll(CtkMailbox*, CtkSlot*);
CtkResult  ctk_mailbox_receive(CtkMailbox*, CtkSlot*, CtkDuration);

/* pool */
CtkResult  ctk_pool_get(CtkPool*, CtkTypeId, CtkGetMode, CtkSlot*);
CtkResult  ctk_pool_get_wait(CtkPool*, CtkTypeId, CtkSlot*, CtkDuration);
void       ctk_pool_put(CtkPool*, CtkSlot*);
```

This is not intended as the final header.

It is the **shape** the final API should converge toward.

---

# 48. Bottom Line

**Port the architecture, not the language.**

The current translation is far enough along to justify starting a dedicated ctk API pass.

The most important fixes are the **stable TypeId mechanism**, **pointer receivers for synchronization objects**, **explicit C result semantics**, and a decision about **GNU statement expressions versus strict C23**.

Once those are resolved, the remaining port is comparatively straightforward.
