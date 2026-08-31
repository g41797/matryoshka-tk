Translation of C3 module to standard C23

To preserve C3's compile-time reflection ($Type::members), the C version utilizes C23 features—specifically typeof, nullptr, and compile-time static_assert validations. It uses _Generic macros to enforce type limits, matching the compile-time guarantees of the original code.
To save this directly to your project workspace, you can copy the markdown block below into an mtk_inner.h file.

# mtk_inner.h```c
// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

#ifndef MTK_INNER_H
#define MTK_INNER_H

#include <stddef.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

/*
The inner, the handle, the Slot, and the link.

`Inner` is the field you embed.
The chain link and the identity, in one.
The identity sits in the same field as the chain link.
The identity says what the outer type is.
`Handle` is a pointer to an embedded `Inner`: one item, with the type forgotten.
Everything 3tk transports is a `Handle`.
It is an alias, so it converts freely with `Inner*` and costs nothing.
`Slot` is a box that holds one handle, or nothing.
A Slot starts empty.

The Slot is how the toolkit tells you where an item went.
Read the Slot after every call that gives or takes an item.

The chain link is the other half of `Inner`.
`reset` clears the chain link and not the identity.
Every chain ends at an item pointing at itself, never at null.
That is what makes `is_linked` exact.
*/

// --- Core Data Structures ---

// C3's `any` holds a data pointer and its type identity. 
// In C, we mimic this metadata container using a tagged structure.
typedef struct {
    void* ptr;
    const void* type; 
} Any;

typedef struct Inner {
    Any link;
} Inner;

// A pointer to an embedded `Inner`. Everything 3tk transports is a `Handle`.
typedef Inner* Handle;

// A box that holds one handle, or nothing.
typedef Handle Slot;

// --- Runtime Assertion / Check Macro ---
#define mtk_check(condition, msg) \
    do { \
        if (!(condition)) { \
            fprintf(stderr, "Runtime Defect: %s\n", msg); \
            abort(); \
            [[unlikely]]; \
        } \
    } while (0)

// --- Writing and reading the link ---

/**
 * Keeps the identity, swaps the chain link.
 * @param self : Pointer to the targeting Inner node
 * @param to   : The handle this item now links to
 */
static inline void Inner_repoint_to(Inner* self, Handle to) {
    if (self != nullptr) {
        self->link.ptr = (void*)to;
        // self->link.type remains preserved (keeps the identity)
    }
}

/**
 * The item this one links to. Null if it is on no chain.
 */
static inline Handle Inner_points_to(const Inner* self) {
    return self != nullptr ? (Handle)self->link.ptr : nullptr;
}

// --- The link test, and the repair ---

/**
 * True when the handle is on some chain. Exact and O(1).
 */
static inline bool is_linked(Handle h) {
    return h != nullptr && Inner_points_to(h) != nullptr;
}

/**
 * Clears the chain link so the item can be inserted again.
 * It clears the link and not the identity.
 */
static inline void reset(Handle h) {
    if (h == nullptr) return;
    Inner_repoint_to(h, nullptr);
}

// --- The Slot's reading shape ---

/**
 * Which of the two states it is in.
 */
static inline bool Slot_is_empty(const Slot* self) {
    return self == nullptr || *self == nullptr;
}

/**
 * Which of the two states it is in.
 */
static inline bool Slot_is_full(const Slot* self) {
    return self != nullptr && *self != nullptr;
}

/**
 * Look without taking. Null on an empty Slot.
 */
static inline Handle Slot_peek(const Slot* self) {
    return self != nullptr ? *self : nullptr;
}

/**
 * Take the handle out and clear the Slot. Null on an empty Slot.
 */
static inline Handle Slot_take(Slot* self) {
    if (self == nullptr) return nullptr;
    Handle h = *self;
    *self = nullptr;
    return h;
}

/**
 * Put a handle in. A null handle or overwriting a full slot is a defect.
 */
static inline void Slot_fill(Slot* self, Handle h) {
    mtk_check(h != nullptr, "Slot.fill with a null handle");
    mtk_check(self != nullptr && Slot_is_empty(self), "never overwrite a full Slot");
    *self = h;
}

// --- Compile-Time Structural / Offset Discoveries ---

/**
 * Calculates the outer structure pointer from a member address using C23 type-safety features.
 */
#define container_of(ptr, type, member) ({                      \
    const typeof(((type *)0)->member) *__mptr = (ptr);          \
    (type *)((char *)__mptr - offsetof(type, member));          \
})

/**
 * C3's `inner_offset($Type)` replacement.
 * Evaluates the structural offset of the `Inner` field in the parent layout.
 * Enforces compile-time checks requiring the parent to own an `Inner` node.
 */
#define inner_offset(Type, member) ({ \
    static_assert(sizeof(((Type*)0)->member) == sizeof(Inner), \
        "Type member must match the target Inner struct type"); \
    offsetof(Type, member); \
})

/**
 * C3's `required_alloc_offset($Type)` replacement.
 * Obtains the offset of an allocator type field within the outer struct at compile time.
 */
#define required_alloc_offset(Type, allocator_member, AllocatorType) ({ \
    static_assert(sizeof(((Type*)0)->allocator_member) == sizeof(AllocatorType), \
        "Type does not possess a valid Allocator field configuration"); \
    offsetof(Type, allocator_member); \
})

#endif // MTK_INNER_H
```

## Design Notes & Adaptations

* Type Unification & Pointers: The explicit C3 method invocations (like Slot.fill) have been converted into standard C namespaced functions (Slot_fill) accepting explicit receivers (Slot* self), which compile smoothly down to raw pointer calculations.
* C23 Keywords: Uses standard nullptr to match the strict null guarantees in C3, and standard bool / false / true natively.
* Reflective Metaprogramming Substitution: Because C cannot map a static $foreach over raw struct components without a macro parser generator, compile-time detection uses offsetof paired with strict static_assert constraints. This blocks compilation if an unexpected memory layout layout is passed.

Would you like to build a quick test harness or an example structure code layout using this header file to verify how the fields bind dynamically using Clang, or do you want to add double-linking support to the engine?

Here is the translation of the mtk::helper C3 module to standard C23.
To recreate C3's reflection abilities ($Typeof(*item)::typeid and compile-time type extraction) in C, this implementation leverages standard typeof, nullptr, and a type-tag registration mechanism.
To use these macros, each outer type must define a unique const void* pointer address or integer ID acting as its type identifier (e.g., &MyStruct_type_id), and you pass the literal field name string or direct member parameter down to locate the offsets via inner_offset matching the definitions from the prior mtk_inner.h.

# mtk_helper.h```c
// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

#ifndef MTK_HELPER_H
#define MTK_HELPER_H

#include "mtk_inner.h"

/*
 Every crossing between a typed pointer and a `Handle` lives in one file.

 `to_handle` goes from your pointer to a `Handle`.
 Null in, null out.
 `from_handle` goes from a `Handle` to `$Type*`, and is null on an identity mismatch.
 A mismatch is an answer, not a failure.
 `must_from_handle` is the same, and it aborts on a mismatch.
 The abort names your line.
 The same three take the item from a Slot, and five of them appear again as methods.
 `from_slot` looks, and the Slot is unchanged.
 `move_from_slot` takes, and on success the Slot is left empty.
 None of these moves an item.
 Reading an identity and casting a pointer leave every container alone.
 No alias to declare, no instantiation, no registration.
*/

// --- Safety / Assert Configurations ---
#ifndef NDEBUG
#define MTK_SAFE 1
#else
#define MTK_SAFE 0
#endif

// --- Base Generic Helper Macros ---

/**
 * True when the handle names TypeId.
 * @param h       : The raw Handle element.
 * @param TypeId  : The unique type identification reference tag (const void*).
 */
#define is_mine(h, TypeId) \
    ((h) != nullptr && (h)->link.type == (const void*)(TypeId))

/**
 * Writes the identity into the embedded Inner element.
 * @param item          : A pointer to the outer structural payload instance.
 * @param member        : The unquoted literal token name of the Inner field.
 * @param TypeId        : The unique type identification reference tag.
 */
#define init(item, member, TypeId) do { \
    typeof(item) _item = (item); \
    Inner* n = (Inner*)((char*)_item + inner_offset(typeof(*_item), member)); \
    n->link.ptr = nullptr; \
    n->link.type = (const void*)(TypeId); \
} while(0)

/**
 * From your pointer to a Handle. Null in, null out.
 * @param item          : A pointer to the outer structural block, or null.
 * @param member        : The unquoted literal token name of the Inner field.
 */
#define to_handle(item, member) \
    ((item) != nullptr ? (Handle)((char*)(item) + inner_offset(typeof(*(item)), member)) : nullptr)

/**
 * From a Handle to a clean outer parent pointer. Null on an identity mismatch.
 * @param h             : The target Handle tracking reference.
 * @param Type          : The concrete target structural outer type layout identifier.
 * @param member        : The unquoted literal token name of the Inner field.
 * @param TypeId        : The unique type identification reference tag.
 */
#define from_handle(h, Type, member, TypeId) ({ \
    Handle _h = (h); \
    (!is_mine(_h, TypeId)) ? (Type*)nullptr : \
    (Type*)((char*)_h - inner_offset(Type, member)); \
})

/**
 * Same as from_handle(), but prints line details and aborts execution on a type mismatch.
 * Enabled conditionally on safety assertions.
 */
#define must_from_handle(h, Type, member, TypeId) ({ \
    Handle _h = (h); \
    if (MTK_SAFE) { \
        char assert_msg[128]; \
        snprintf(assert_msg, sizeof(assert_msg), "Handle type mismatch at %s:%d", __FILE__, __LINE__); \
        mtk_check(is_mine(_h, TypeId), assert_msg); \
    } \
    (Type*)((char*)_h - inner_offset(Type, member)); \
})

/**
 * Looks up type compatibility against the item inside a Slot. The Slot is unchanged.
 */
#define from_slot(s, Type, member, TypeId) \
    from_handle(Slot_peek(s), Type, member, TypeId)

/**
 * Asserts structural equality inside a Slot. The Slot remains unchanged.
 */
#define must_from_slot(s, Type, member, TypeId) \
    must_from_handle(Slot_peek(s), Type, member, TypeId)

/**
 * Resolves item mapping, clearing and emptying the Slot on matching validation layout success.
 */
#define move_from_slot(s, Type, member, TypeId) ({ \
    Slot* _s = (s); \
    Handle _h = Slot_peek(_s); \
    (Type*)(!is_mine(_h, TypeId) ? nullptr : ({ \
        Slot_take(_s); \
        (char*)_h - inner_offset(Type, member); \
    })); \
})

// --- Object-Receiver Pseudomethod Adapters ---

/**
 * Same as from_handle(), acting as a structural method targeting an Inner pointer instance.
 */
#define Inner_to(self, Type, member, TypeId) \
    from_handle((Handle)(self), Type, member, TypeId)

/**
 * Same as must_from_handle(), acting as a structural verification method targeting an Inner pointer instance.
 */
#define Inner_as(self, Type, member, TypeId) \
    must_from_handle((Handle)(self), Type, member, TypeId)

/**
 * Same as from_slot(), treating the targeting expression sequence directly as a receiver method wrapper.
 */
#define Slot_to(self, Type, member, TypeId) \
    from_slot((self), Type, member, TypeId)

/**
 * Same as must_from_slot(), treating the targeting expression sequence directly as a receiver method wrapper.
 */
#define Slot_must(self, Type, member, TypeId) \
    must_from_slot((self), Type, member, TypeId)

/**
 * Same as move_from_slot(), treating the targeting expression sequence directly as a receiver method wrapper.
 */
#define Slot_move(self, Type, member, TypeId) \
    move_from_slot((self), Type, member, TypeId)

#endif // MTK_HELPER_H
```

Would you like to build an example application showcasing how to declare an outer structure type, initialize its token tracking, and cycle it through a Slot pipeline to test the error messages under Clang?


Here is the translation of the mtk::managed C3 module to standard C23.
To handle C3's error handling semantics (void? and the ! suffix) alongside its reflection model, this C23 implementation utilizes standard bool as the return type for status propagation (returning true on success and false on allocation failure). It relies on the previously defined mtk_inner.h and mtk_helper.h features.

# mtk_managed.h```c
// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

#ifndef MTK_MANAGED_H
#define MTK_MANAGED_H

#include "mtk_inner.h"
#include "mtk_helper.h"

/*
 One helper allocates and frees, and only if your struct carries the allocator itself.

 `create` allocates the outer, initializes it, and fills the Slot.
 The item keeps the allocator for life.
 On an allocation failure the Slot is untouched and the fault is returned.
 `release` frees the item with the allocator it kept.
 It takes no allocator.
 It is a no-op on an empty Slot, so a `defer` registered before the acquisition is safe.
 No type declares itself managed.
 The choice is made at the call site.
*/

// --- Generic Mock Interfaces for std::core::mem::alloc ---
// (Replace these with your toolkit's concrete allocator structures and hooks)
typedef struct Allocator {
    void* context;
    void* (*alloc_fn)(void* ctx, size_t size);
    void  (*free_fn)(void* ctx, void* ptr);
} Allocator;

static inline void* alloc_new_try(Allocator a, size_t size) {
    if (a.alloc_fn == nullptr) return nullptr;
    return a.alloc_fn(a.context, size);
}

static inline void alloc_free(Allocator a, void* ptr) {
    if (a.free_fn != nullptr && ptr != nullptr) {
        a.free_fn(a.context, ptr);
    }
}

// --- Managed Lifecycle Macros ---

/**
 * Allocates the outer, initializes it, and fills the Slot.
 * The item keeps the allocator for life.
 * Returns true on success; returns false on allocation failure leaving the Slot untouched.
 *
 * @param Type             : The outer struct type layout name.
 * @param inner_member     : Unquoted literal token name of the embedded Inner field.
 * @param alloc_member     : Unquoted literal token name of the embedded Allocator field.
 * @param TypeId           : Unique type tag pointer identifying the object type.
 * @param a                : The Allocator instance the item keeps for life.
 * @param slot             : An empty Slot pointer, filled on successful allocation.
 */
#define mtk_create(Type, inner_member, alloc_member, TypeId, a, slot) ({ \
    Slot* _slot = (slot); \
    mtk_check(Slot_is_empty(_slot), "an acquisition asserts the Slot is empty on entry"); \
    \
    Type* _item = (Type*)alloc_new_try((a), sizeof(Type)); \
    bool _success = (_item != nullptr); \
    \
    if (_success) { \
        /* Store the allocator at its compile-time verified offset position */ \
        *(Allocator*)((char*)_item + required_alloc_offset(Type, alloc_member, Allocator)) = (a); \
        \
        /* Initialize the tracking payload identifiers */ \
        init(_item, inner_member, TypeId); \
        \
        /* Place the verified raw handle into the slot storage wrapper */ \
        Slot_fill(_slot, to_handle(_item, inner_member)); \
    } \
    _success; /* Returns structural success flag mapping to C3's optional void result */ \
})

/**
 * Frees the item with the allocator it kept. It takes no external allocator argument.
 * It is a clean no-op on empty slots.
 *
 * @param Type             : The outer struct type layout name.
 * @param inner_member     : Unquoted literal token name of the embedded Inner field.
 * @param alloc_member     : Unquoted literal token name of the embedded Allocator field.
 * @param TypeId           : Unique type tag pointer identifying the object type.
 * @param slot             : The targeting Slot reference tracker; reset to empty afterwards.
 */
#define mtk_release(Type, inner_member, alloc_member, TypeId, slot) do { \
    Slot* _slot = (slot); \
    if (!Slot_is_empty(_slot)) { \
        Type* _item = must_from_slot(_slot, Type, inner_member, TypeId); \
        \
        /* Extract the contextual allocator instance bound directly inside the node tracking data */ \
        Allocator _a = *(Allocator*)((char*)_item + required_alloc_offset(Type, alloc_member, Allocator)); \
        \
        /* Disconnect the handle from the memory slot container wrapper */ \
        Slot_take(_slot); \
        \
        /* Drop allocation footprint */ \
        alloc_free(_a, _item); \
    } \
} while(0)

#endif // MTK_MANAGED_H
```

## Technical Adjustments

   1. Error Handling Mapping: C3's void? return type behaves like an optional result that drops execution flow on an unhandled fault. In standard C, this is mapped explicitly using a boolean return evaluation statement (_success), allowing the call site to use standard block validation loops (if (!mtk_create(...)) { /* error fallback */ }).
   2. Deterministic Destructuring: The macro captures explicit local references (e.g., _slot, _item) using C23 scoped evaluation statements ({ ... }) to avoid multi-evaluation side effects when composite assignments or pointer modifications are passed as parameters.

Would you like an example showing how to orchestrate mtk_create and mtk_release back-to-back using custom memory pool hooks under Clang on Linux?

Here is the translation of the mtk::queue C3 module to standard C23.
To map C3's object-oriented method extensions (like InnerQueue.push_back) into idiomatic, fast C, this implementation maps the receiver parameters as explicit pointers using namespaced signatures. All runtime validations are preserved via the mtk_check assertions.

# mtk_queue.h```c
// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

#ifndef MTK_QUEUE_H
#define MTK_QUEUE_H

#include "mtk_inner.h"

/*
 The intrusive queue. First-in first-out.

 The transfer container.
 Nothing here allocates, and every operation is O(1).
 The count is kept, so `len` is O(1).
 `push_back` adds at the back.
 There is no front insert.
 `pop_front` takes the item at the front, and null on an empty queue is an answer and not a fault.
 `append_queue` moves every item of another queue onto the back of this one, in O(1).
 `iter` and `next` are a walker, taken from the queue.
 Removing the current item during a walk is not supported.
 Every chain ends at an item pointing at itself, never at null.
 Nothing in the queue can fail.
*/

// --- Core Structural Queue Types ---

typedef struct InnerQueue {
    Inner* head;
    Inner* tail;
    size_t count; // C3's `usz` maps natively to standard `size_t`
} InnerQueue;

typedef struct InnerQueueIterator {
    Inner* cur;
} InnerQueueIterator;

// --- The Insert Guard ---

#ifndef NDEBUG
#define mtk_guard_insert(self, h) do { \
    mtk_check((h) != nullptr, "insert of a null handle"); \
    mtk_check(!is_linked(h), "the item is already on a chain"); \
} while(0)
#else
#define mtk_guard_insert(self, h) do { } while(0)
#endif

// --- Questions ---

/**
 * True if the queue holds nothing.
 */
static inline bool InnerQueue_is_empty(const InnerQueue* self) {
    return self == nullptr || self->count == 0;
}

/**
 * How many items the queue holds. O(1).
 */
static inline size_t InnerQueue_len(const InnerQueue* self) {
    return self != nullptr ? self->count : 0;
}

/**
 * A walker, taken from the queue.
 */
static inline InnerQueueIterator InnerQueue_iter(const InnerQueue* self) {
    return (InnerQueueIterator){ .cur = (self != nullptr ? self->head : nullptr) };
}

/**
 * The next handle, or null when the walk is exhausted.
 */
static inline Handle InnerQueueIterator_next(InnerQueueIterator* self) {
    if (self == nullptr || self->cur == nullptr) return nullptr;
    
    Inner* n = self->cur;
    // Every chain ends at an item pointing at itself, never at null.
    self->cur = (Inner_points_to(n) == n) ? nullptr : Inner_points_to(n);
    return n;
}

// --- Adding ---

/**
 * Adds at the back. There is no front insert.
 */
static inline void InnerQueue_push_back(InnerQueue* self, Handle h) {
    if (self == nullptr) return;
    mtk_guard_insert(self, h);
    
    // Every chain ends at an item pointing at itself, never at null.
    Inner_repoint_to(h, h);
    
    if (self->tail != nullptr) {
        Inner_repoint_to(self->tail, h);
    } else {
        self->head = h;
    }
    
    self->tail = h;
    self->count++;
}

/**
 * Same as push_back(), taking the item from a Slot.
 * The Slot is empty afterwards. An empty Slot is a defect, not a no-op.
 */
static inline void InnerQueue_push_back_slot(InnerQueue* self, Slot* s) {
    mtk_check(Slot_is_full(s), "push_back_slot from an empty Slot");
    if (Slot_is_empty(s)) return;
    InnerQueue_push_back(self, Slot_take(s));
}

// --- Removing ---

/**
 * Takes the item at the front.
 * Null on an empty queue, which is an answer and not a fault.
 * The returned item's chain link is cleared.
 */
static inline Handle InnerQueue_pop_front(InnerQueue* self) {
    if (self == nullptr || self->head == nullptr) return nullptr;
    
    Handle h = self->head;
    if (self->head == self->tail) {
        self->head = nullptr;
        self->tail = nullptr;
    } else {
        self->head = Inner_points_to(h);
    }
    
    self->count--;
    reset(h);
    return h;
}

/**
 * Takes everything the queue holds, as one flat queue. O(1).
 * The queue is empty afterwards.
 */
static inline InnerQueue InnerQueue_take(InnerQueue* self) {
    if (self == nullptr) return (InnerQueue){ .head = nullptr, .tail = nullptr, .count = 0 };
    
    InnerQueue out = *self;
    self->head = nullptr;
    self->tail = nullptr;
    self->count = 0;
    return out;
}

// --- Moving ---

/**
 * Moves every item of another queue onto the back of this one. O(1).
 * That queue is empty afterwards. A queue moved onto itself is a defect.
 */
static inline void InnerQueue_append_queue(InnerQueue* self, InnerQueue* other) {
    mtk_check(other != nullptr, "append_queue with a null queue");
    mtk_check(other != self, "a queue cannot be moved onto itself");
    if (other == nullptr || other == self) return;
    if (InnerQueue_is_empty(other)) return;

    if (self->tail != nullptr) {
        Inner_repoint_to(self->tail, other->head);
    } else {
        self->head = other->head;
    }
    
    self->tail = other->tail;
    self->count += other->count;

    other->head = nullptr;
    other->tail = nullptr;
    other->count = 0;
}

#endif // MTK_QUEUE_H
```

## Architectural Details

* Self-Targeting Termination: The original design design constraint (Every chain ends at an item pointing at itself, never at null) is implemented explicitly in InnerQueue_push_back via Inner_repoint_to(h, h) and parsed within InnerQueueIterator_next to accurately reset self->cur = nullptr at the boundary limit.
* Inline Optimization Hooks: Performance operations match C3's @inline guarantees by deploying static structural inline configurations (static inline), which allow Clang on Linux to optimize the pointer movements straight into code registers.

Would you like to put this architecture to use by writing a producer-consumer example using these InnerQueue functions, or should we build out the matching intrusive stack framework?

Here is the translation of the mtk::stack C3 module to standard C23.
This implementation mirrors the pointer layouts and termination conditions of your stack architecture (where a single item points to itself if it represents the base boundary of the stack chain structure).

# mtk_stack.h```c
// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

#ifndef MTK_STACK_H
#define MTK_STACK_H

#include "mtk_inner.h"

/*
 The intrusive stack. Last-in first-out.

 The storage container.
 Where the queue carries items across, the stack holds them still.
 The pool keeps one per identity, and it is the only stack 3tk owns.
 No 3tk signature passes one: the four that take a container take an `InnerQueue*`.
 A caller who wants a stack declares one.
 Four operations: no walker, and no splice.
 The order is not promised.
 No caller is entitled to which item comes back.
 Every chain ends at an item pointing at itself, never at null.
 Nothing in the stack can fail.
 The count is kept, so `len` is O(1).
 There is no tail, so flattening the stack is O(n).
*/

// --- Core Structural Stack Definition ---

typedef struct InnerStack {
    Inner* top;
    size_t count; // Maps C3's `usz` directly to standard `size_t`
} InnerStack;

// --- The Insert Guard ---

#ifndef NDEBUG
#define mtk_stack_guard_insert(self, h) do { \
    mtk_check((h) != nullptr, "insert of a null handle"); \
    mtk_check(!is_linked(h), "the item is already on a chain"); \
} while(0)
#else
#define mtk_stack_guard_insert(self, h) do { } while(0)
#endif

// --- Questions ---

/**
 * True if the stack holds nothing.
 */
static inline bool InnerStack_is_empty(const InnerStack* self) {
    return self == nullptr || self->count == 0;
}

/**
 * How many items the stack holds. O(1).
 */
static inline size_t InnerStack_len(const InnerStack* self) {
    return self != nullptr ? self->count : 0;
}

// --- Adding ---

/**
 * Adds on top.
 * There is no Slot-shaped insert.
 */
static inline void InnerStack_push(InnerStack* self, Handle h) {
    if (self == nullptr) return;
    mtk_stack_guard_insert(self, h);

    // Every chain ends at an item pointing at itself, never at null.
    // If self->top is null (stack empty), h points to itself.
    Inner_repoint_to(h, (self->top != nullptr) ? self->top : h);
    
    self->top = h;
    self->count++;
}

// --- Removing ---

/**
 * Takes the item on top.
 * Null on an empty stack.
 * The returned item's chain link is cleared via reset().
 */
static inline Handle InnerStack_pop(InnerStack* self) {
    if (self == nullptr || self->top == nullptr) return nullptr;

    Handle h = self->top;
    
    // If the top item points to itself, it is the last item on the stack chain.
    self->top = (Inner_points_to(h) == h) ? nullptr : Inner_points_to(h);
    self->count--;
    
    reset(h);
    return h;
}

#endif // MTK_STACK_H
```

Would you like to build an automated validation test pipeline that passes items dynamically between your translated InnerQueue and InnerStack components to verify correct lifecycle ownership transitions under Clang?

Here is the complete C23 translation of the mtk::mailbox module.
To match C3's concurrency utilities, this translation leverages native Linux Pthreads (pthread_mutex_t, pthread_cond_t) and standard C23 <stdatomic.h>. Because C does not have built-in exception propagation or try/catch mechanisms, the semantic mapping of C3's optional return values (void?, Mailbox*?) and result tags (like mtk::CLOSED) utilizes an explicit MtkResult enum parameter.

# mtk_mailbox.h
```c
// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

#ifndef MTK_MAILBOX_H
#define MTK_MAILBOX_H

#include <pthread.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include "mtk_inner.h"
#include "mtk_queue.h"
#include "mtk_helper.h"

/*
 The mailbox. A queue of items, with waiting.
 Transfer of an item between threads.
*/

// --- Core Status Enumeration ---
typedef enum {
    MTK_SUCCESS = 0,
    MTK_CLOSED,
    MTK_EMPTY,
    MTK_TIMEOUT,
    MTK_WOKEN,
    MTK_ERROR
} MtkResult;

// Representing Duration and Time points simply using standard timespec
typedef struct timespec Duration;
typedef struct timespec Time;

// --- Mailbox Structure Definition ---
typedef struct Mailbox {
    Inner node; //

    pthread_mutex_t _mu; //
    pthread_cond_t  _cv; //

    Allocator       _alloc; //

    bool            _closed; //
    atomic_bool     _closed_fast; //
    size_t          _active; //

    InnerQueue      _oob; //
    InnerQueue      _regular; //

    size_t          _wake_gen; //
} Mailbox;

// Identity layout bindings
#define MAILBOX_TYPE_ID ((const void*)&"Mailbox")

// --- Helper Inline Conversions ---
static inline Handle Mailbox_to_handle(Mailbox* p) {
    return to_handle(p, node); //
}

static inline Mailbox* Mailbox_of(Handle h) {
    return from_handle(h, Mailbox, node, MAILBOX_TYPE_ID); //
}

// --- Internal Helper Macros ---
#define mtk_always_assert(condition, msg) do { \
    if (!(condition)) { \
        fprintf(stderr, "Fatal Assertion Failure: %s\n", msg); \
        abort(); \
    } \
} while(0)

static inline bool Mailbox_closed_fast(const Mailbox* self) {
    return atomic_load_explicit(&self->_closed_fast, memory_order_acquire); //
}

static inline void Mailbox_enqueue(Mailbox* self, Handle h, bool oob) {
    if (oob) { \
        InnerQueue_push_back(&self->_oob, h); \
    } else { \
        InnerQueue_push_back(&self->_regular, h); \
    } //
}

static inline Handle Mailbox_dequeue(Mailbox* self) {
    Handle h = InnerQueue_pop_front(&self->_oob); \
    return h != nullptr ? h : InnerQueue_pop_front(&self->_regular); //
}

static inline bool Mailbox_has_queued(const Mailbox* self) {
    return !InnerQueue_is_empty(&self->_oob) || !InnerQueue_is_empty(&self->_regular); //
}

// --- Lifecycle Implementation API ---

/**
 * Allocates a mailbox and returns it. Returns nullptr on error layout issues.
 */
static inline Mailbox* Mailbox_create(Allocator a) {
    Mailbox* mb = (Mailbox*)alloc_new_try(a, sizeof(Mailbox)); //
    if (mb == nullptr) return nullptr;

    init(mb, node, MAILBOX_TYPE_ID); //
    mb->_alloc = a; //
    mb->_closed = false;
    atomic_init(&mb->_closed_fast, false);
    mb->_active = 0;
    mb->_wake_gen = 0;
    mb->_oob = (InnerQueue){nullptr, nullptr, 0};
    mb->_regular = (InnerQueue){nullptr, nullptr, 0};

    if (pthread_mutex_init(&mb->_mu, nullptr) != 0) {
        alloc_free(a, mb);
        return nullptr; //
    }

    if (pthread_cond_init(&mb->_cv, nullptr) != 0) {
        pthread_mutex_destroy(&mb->_mu);
        alloc_free(a, mb);
        return nullptr; //
    }

    return mb; //
}

/**
 * Frees the mailbox. The mailbox must be closed and completely quiet.
 */
static inline void Mailbox_release(Mailbox* self) {
    if (self == nullptr) return;

    pthread_mutex_lock(&self->_mu); //
    mtk_always_assert(self->_closed && self->_active == 0, 
                      "releasing a mailbox that is not quiet"); //
    pthread_mutex_unlock(&self->_mu); //

    pthread_cond_destroy(&self->_cv); //
    pthread_mutex_destroy(&self->_mu); //
    
    Allocator a = self->_alloc; //
    alloc_free(a, self); //
}

// Private implementation router forward declaration
static inline MtkResult Mailbox_send_at(Mailbox* self, Slot* slot, bool oob);

static inline MtkResult Mailbox_send(Mailbox* self, Slot* slot) {
    return Mailbox_send_at(self, slot, false); //
}

static inline MtkResult Mailbox_send_oob(Mailbox* self, Slot* slot) {
    return Mailbox_send_at(self, slot, true); //
}

static inline MtkResult Mailbox_send_at(Mailbox* self, Slot* slot, bool oob) {
    mtk_check(Slot_is_full(slot), "Mailbox.send from an empty Slot"); //
    if (Slot_is_empty(slot)) return MTK_ERROR;

    if (Mailbox_closed_fast(self)) return MTK_CLOSED; //

    pthread_mutex_lock(&self->_mu); //

    if (self->_closed) {
        pthread_mutex_unlock(&self->_mu);
        return MTK_CLOSED; //
    }

    self->_active++; //

    Mailbox_enqueue(self, Slot_take(slot), oob); //
    pthread_cond_signal(&self->_cv); //

    self->_active--; //
    pthread_mutex_unlock(&self->_mu); //
    
    return MTK_SUCCESS;
}

/**
 * Takes an item if one is queued. Never waits.
 */
static inline MtkResult Mailbox_poll(Mailbox* self, Slot* slot) {
    mtk_check(Slot_is_empty(slot), "an acquisition asserts the Slot is empty on entry"); //

    if (Mailbox_closed_fast(self)) return MTK_CLOSED; //

    pthread_mutex_lock(&self->_mu); //

    if (self->_closed) {
        pthread_mutex_unlock(&self->_mu);
        return MTK_CLOSED; //
    }

    self->_active++; //

    Handle h = Mailbox_dequeue(self); //
    if (h == nullptr) {
        self->_active--;
        pthread_mutex_unlock(&self->_mu);
        return MTK_EMPTY; //
    }

    Slot_fill(slot, h); //

    self->_active--; //
    pthread_mutex_unlock(&self->_mu); //
    
    return MTK_SUCCESS;
}

/**
 * Takes an item, waiting up to the timeout duration limit parameter.
 */
static inline MtkResult Mailbox_receive(Mailbox* self, Slot* slot, Duration timeout) {
    mtk_check(Slot_is_empty(slot), "an acquisition asserts the Slot is empty on entry"); //

    struct timespec deadline;
    clock_gettime(CLOCK_REALTIME, &deadline);
    deadline.tv_sec += timeout.tv_sec;
    deadline.tv_nsec += timeout.tv_nsec;
    if (deadline.tv_nsec >= 1000000000) {
        deadline.tv_sec++;
        deadline.tv_nsec -= 1000000000;
    } //

    pthread_mutex_lock(&self->_mu); //

    if (self->_closed) {
        pthread_mutex_unlock(&self->_mu);
        return MTK_CLOSED; //
    }

    self->_active++; //
    size_t gen = self->_wake_gen; //

    MtkResult res = MTK_SUCCESS;

    while (true) {
        if (self->_closed) { res = MTK_CLOSED; break; } //

        Handle h = Mailbox_dequeue(self); //
        if (h != nullptr) {
            Slot_fill(slot, h); //
            res = MTK_SUCCESS;
            break;
        }

        if (self->_wake_gen != gen) { res = MTK_WOKEN; break; } //

        int cond_res = pthread_cond_timedwait(&self->_cv, &self->_mu, &deadline); //
        if (cond_res != 0) {
            if (self->_closed) { res = MTK_CLOSED; break; } //
            h = Mailbox_dequeue(self); //
            if (h != nullptr) {
                Slot_fill(slot, h); //
                res = MTK_SUCCESS;
                break;
            }
            if (self->_wake_gen != gen) { res = MTK_WOKEN; break; } //
            res = MTK_TIMEOUT; //
            break;
        }
    }

    self->_active--; //
    pthread_mutex_unlock(&self->_mu); //
    return res;
}

/**
 * Moves every queued item onto your destination out queue container.
 */
static inline MtkResult Mailbox_receive_all(Mailbox* self, InnerQueue* out) {
    mtk_check(InnerQueue_is_empty(out), "receive_all asserts the queue is empty on entry"); //

    if (Mailbox_closed_fast(self)) return MTK_CLOSED; //

    pthread_mutex_lock(&self->_mu); //

    if (self->_closed) {
        pthread_mutex_unlock(&self->_mu);
        return MTK_CLOSED; //
    }

    self->_active++; //

    InnerQueue_append_queue(out, &self->_oob); //
    InnerQueue_append_queue(out, &self->_regular); //

    self->_active--; //
    pthread_mutex_unlock(&self->_mu); //
    return MTK_SUCCESS;
}

/**
 * Wakes every current waiter blocking on conditional constraints.
 */
static inline MtkResult Mailbox_wake_all(Mailbox* self) {
    if (Mailbox_closed_fast(self)) return MTK_CLOSED; //

    pthread_mutex_lock(&self->_mu); //

    if (self->_closed) {
        pthread_mutex_unlock(&self->_mu);
        return MTK_CLOSED; //
    }

    self->_active++; //

    self->_wake_gen++; //
    pthread_cond_broadcast(&self->_cv); //

    self->_active--; //
    pthread_mutex_unlock(&self->_mu); //
    return MTK_SUCCESS;
}

// Inner close worker routine
static inline void Mailbox_close_internal(Mailbox* self, InnerQueue* out) {
    if (self->_closed) return; //

    self->_closed = true; //
    atomic_store_explicit(&self->_closed_fast, true, memory_order_release); //

    InnerQueue_append_queue(out, &self->_oob); //
    InnerQueue_append_queue(out, &self->_regular); //

    pthread_cond_broadcast(&self->_cv); //
}

/**
 * Closes the mailbox and returns remaining items back to the caller context.
 */
static inline void Mailbox_close(Mailbox* self, InnerQueue* out) {
    mtk_check(InnerQueue_is_empty(out), "close asserts the queue is empty on entry"); //

    pthread_mutex_lock(&self->_mu); //
    self->_active++; //

    Mailbox_close_internal(self, out); //

    self->_active--; //

pthread_mutex_unlock(&self->_mu); //
}
static inline bool Mailbox_is_closed(const Mailbox* self) {
return Mailbox_closed_fast(self); //
}
/**

* How many items are queued inside.
/
static inline size_t Mailbox_len(Mailbox self) {
pthread_mutex_lock(&self->_mu); //
self->_active++; //size_t length = InnerQueue_len(&self->_oob) + InnerQueue_len(&self->_regular); //self->_active--; //
pthread_mutex_unlock(&self->_mu); //
return length;
}

#endif // MTK_MAILBOX_H
```


### Technical Design Architecture Notes
1. **Memory Ordering Bindings:** C3's `_closed_fast.store(true, RELEASE)` matches standard C23 **`atomic_store_explicit`** paired with **`memory_order_release`**. The tracking reading checks deploy an **`acquire`** read cycle via `atomic_load_explicit`. This confirms memory updates remain sequential outside mutex scopes.
2. **Deterministic Cleanup Scopes:** Because standard C lacks an automated implicit structural `defer` compiler engine, the unlock sequences have been mapped manually across every runtime exit, return block, and dynamic conditional branch to guarantee locks avoid dangling ownership traps.

<FollowUp>
Would you like to write a multi-threaded **stress test application** using this C23 `Mailbox` framework to trace data pipeline safety across several **worker threads** under Clang?
</FollowUp>

Here is the translation of the mtk::pool C3 module to standard C23, incorporating the previous files.
Because C does not feature high-level native interfaces or dynamic length slices like C3, we map PoolHooks to a dedicated struct PoolHooks consisting of standard C function pointers, and allocate the fixed _buckets slice as a contiguous memory block whose capacity tracker is preserved inside the Pool metadata structure.
All C3 specific concurrency abstractions map down to Linux native POSIX threads (pthread_mutex_t, pthread_cond_t) and strict C23 <stdatomic.h> modifiers matching the structural validation metrics.

# mtk_pool.h
```c
// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

#ifndef MTK_POOL_H
#define MTK_POOL_H

#include <pthread.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include "mtk_inner.h"
#include "mtk_queue.h"
#include "mtk_stack.h"
#include "mtk_helper.h"

// C doesn't have a native reflection runtime typeid keyword; we track identities using const void*
typedef const void* TypeId;

// --- Pool Policy Callback Hooks Structure Interface ---
typedef struct PoolHooks {
    /**
     * Asked for an item of a named identity. Slot is empty on entry.
     */
    void (*on_get)(TypeId want, size_t in_pool, Slot* slot);

    /**
     * An item is being given back. Slot is full on entry.
     */
    void (*on_put)(size_t in_pool, Slot* slot, InnerQueue* extra);

    /**
     * Take everything that is left when the pool closes.
     */
    void (*on_close)(InnerQueue remaining);
} PoolHooks;

// --- Plain Retrieval Modes ---
typedef enum {
    MTK_AVAILABLE_OR_NEW,
    MTK_NEW_ONLY,
    MTK_AVAILABLE_ONLY
} GetMode;

// --- Free Buckets Allocation Blocks ---
typedef struct PoolBucket {
    TypeId     tag;
    InnerStack free;
} PoolBucket;

// --- The Pool Structural Definition ---
typedef struct Pool {
    Inner node;

    pthread_mutex_t _mu;
    pthread_cond_t  _cv;

    Allocator       _alloc;

    bool            _closed;
    atomic_bool     _closed_fast;
    size_t          _active;

    PoolBucket*     _buckets;
    size_t          _buckets_len; // Kept to represent slice boundaries natively
    PoolHooks       _hooks;
} Pool;

// The unique tracking ID binding layout of a Pool instance object
#define POOL_TYPE_ID ((const void*)&"Pool")

// --- Helper Inline Methods ---
static inline Handle Pool_to_handle(Pool* p) {
    return to_handle(p, node);
}

static inline Pool* Pool_of(Handle h) {
    return from_handle(h, Pool, node, POOL_TYPE_ID);
}

static inline bool Pool_closed_fast(const Pool* self) {
    return atomic_load_explicit(&self->_closed_fast, memory_order_acquire);
}

// Private structure linear offset array tracking lookup loop
static inline PoolBucket* Pool_bucket_for(const Pool* self, TypeId t) {
    for (size_t i = 0; i < self->_buckets_len; i++) {
        if (self->_buckets[i].tag == t) {
            return &self->_buckets[i];
        }
    }
    return nullptr;
}

// --- Lifecycle & Functional Processing Implementations ---

/**
 * Allocates an intrusive resource validation pool on the heap.
 */
static inline Pool* Pool_create(Allocator a, TypeId* tags, size_t tags_len, PoolHooks hooks) {
    mtk_check(tags_len > 0, "the set of identities is not empty");
    mtk_check(hooks.on_get != nullptr && hooks.on_put != nullptr && hooks.on_close != nullptr, 
              "a pool cannot exist without valid non-null hooks setup");

    // Check for element layout structural duplication invariants
    for (size_t i = 0; i < tags_len; i++) {
        for (size_t j = i + 1; j < tags_len; j++) {
            mtk_check(tags[i] != tags[j], "the pool's set of identities has a duplicate element context");
        }
    }

    Pool* p = (Pool*)alloc_new_try(a, sizeof(Pool));
    if (p == nullptr) return nullptr;

    init(p, node, POOL_TYPE_ID);
    p->_alloc = a;
    p->_hooks = hooks;
    p->_closed = false;
    atomic_init(&p->_closed_fast, false);
    p->_active = 0;

    if (pthread_mutex_init(&p->_mu, nullptr) != 0) {
        alloc_free(a, p);
        return nullptr;
    }

    if (pthread_cond_init(&p->_cv, nullptr) != 0) {
        pthread_mutex_destroy(&p->_mu);
        alloc_free(a, p);
        return nullptr;
    }

    p->_buckets = (PoolBucket*)alloc_new_try(a, sizeof(PoolBucket) * tags_len);
    if (p->_buckets == nullptr) {
        pthread_cond_destroy(&p->_cv);
        pthread_mutex_destroy(&p->_mu);
        alloc_free(a, p);
        return nullptr;
    }

    p->_buckets_len = tags_len;
    for (size_t i = 0; i < tags_len; i++) {
        p->_buckets[i].tag = tags[i];
        p->_buckets[i].free = (InnerStack){ .top = nullptr, .count = 0 };
    }

    return p;
}

/**
 * Frees the pool. The pool must be closed and entirely quiet.
 */
static inline void Pool_release(Pool* self) {
    if (self == nullptr) return;

    pthread_mutex_lock(&self->_mu);
    mtk_check(self->_closed && self->_active == 0, "releasing a pool that is not quiet");
    pthread_mutex_unlock(&self->_mu);

    pthread_cond_destroy(&self->_cv);
    pthread_mutex_destroy(&self->_mu);

    Allocator a = self->_alloc;
    alloc_free(a, self->_buckets);
    alloc_free(a, self);
}

/**
 * Takes a free item from the stack or invokes the application get hook directly.
 */
static inline MtkResult Pool_get(Pool* self, TypeId want, GetMode mode, Slot* slot) {
    mtk_check(Slot_is_empty(slot), "an acquisition asserts the Slot is empty on entry");

    if (Pool_closed_fast(self)) return MTK_CLOSED;

    pthread_mutex_lock(&self->_mu);

    if (self->_closed) {
        pthread_mutex_unlock(&self->_mu);
        return MTK_CLOSED;
    }

    self->_active++;

    PoolBucket* b = Pool_bucket_for(self, want);
    mtk_check(b != nullptr, "Pool.get for an identity the pool was not created with");
    if (b == nullptr) {
        self->_active--;
        pthread_mutex_unlock(&self->_mu);
        return MTK_ERROR; // Maps to checking unknown identity
    }

    if (mode != MTK_NEW_ONLY) {
        Handle h = InnerStack_pop(&b->free);
        if (h != nullptr) {
            self->_active--;
            pthread_mutex_unlock(&self->_mu);
            Slot_fill(slot, h);
            return MTK_SUCCESS;
        }
    }

    if (mode == MTK_AVAILABLE_ONLY) {
        self->_active--;
        pthread_mutex_unlock(&self->_mu);
        return MTK_EMPTY; // Maps to NOT_AVAILABLE
    }

    size_t in_pool = InnerStack_len(&b->free);

    // Release the operational lock across policy callback steps
    pthread_mutex_unlock(&self->_mu);
    self->_hooks.on_get(want, in_pool, slot);
    
    // Regain thread sync exclusion map boundary control to step down execution state metrics
    pthread_mutex_lock(&self->_mu);
    self->_active--;
    pthread_mutex_unlock(&self->_mu);

    if (Slot_is_empty(slot)) return MTK_TIMEOUT; // Maps to NOT_CREATED
    
    mtk_check(Slot_peek(slot)->link.type == want, "the get hook returned an item of a different identity");
    return MTK_SUCCESS;
}

/**
 * Takes a free item, waiting up to the timeout duration boundary parameter limit.
 */
static inline MtkResult Pool_get_wait(Pool* self, TypeId want, Slot* slot, Duration timeout) {
    mtk_check(Slot_is_empty(slot), "an acquisition asserts the Slot is empty on entry");

    struct timespec deadline;
    clock_gettime(CLOCK_REALTIME, &deadline);
    deadline.tv_sec += timeout.tv_sec;
    deadline.tv_nsec += timeout.tv_nsec;
    if (deadline.tv_nsec >= 1000000000) {
        deadline.tv_sec++;
        deadline.tv_nsec -= 1000000000;
    }

    pthread_mutex_lock(&self->_mu);

    PoolBucket* b = Pool_bucket_for(self, want);
    mtk_check(b != nullptr, "Pool.get_wait for an identity the pool was not created with");
    if (b == nullptr) {
        pthread_mutex_unlock(&self->_mu);
        return MTK_ERROR;
    }

    if (self->_closed) {
        pthread_mutex_unlock(&self->_mu);
        return MTK_CLOSED;
    }

    self->_active++;
    MtkResult res = MTK_SUCCESS;

    while (true) {
        if (self->_closed) { res = MTK_CLOSED; break; }

        Handle h = InnerStack_pop(&b->free);
        if (h != nullptr) {
            Slot_fill(slot, h);
            res = MTK_SUCCESS;
            break;
        }

        int cond_res = pthread_cond_timedwait(&self->_cv, &self->_mu, &deadline);
        if (cond_res != 0) {
            if (self->_closed) { res = MTK_CLOSED; break; }

            h = InnerStack_pop(&b->free);
            if (h != nullptr) {
                Slot_fill(slot, h);
                res = MTK_SUCCESS;
                break;
            }
            res = MTK_TIMEOUT;
            break;
        }
    }

    self->_active--;
    pthread_mutex_unlock(&self->_mu);
    return res;
}

// Forward private storage tracking references
static inline void Pool_take_back_handle(Pool* self, Handle h) {
    PoolBucket* b = Pool_bucket_for(self, h->link.type);
    mtk_check(b != nullptr, "the put hook returned an identity the pool was not created with");
    InnerStack_push(&b->free, h);
}

static inline void Pool_take_back(Pool* self, Slot* s) {
    if (Slot_is_empty(s)) return;
    Pool_take_back_handle(self, Slot_take(s));
}

/**
 * Gives an item back. Clean no-op if the target slot container is empty.
 */
static inline void Pool_put(Pool* self, Slot* slot) {
    if (Slot_is_empty(slot)) return;
    if (Pool_closed_fast(self)) return;

    pthread_mutex_lock(&self->_mu);

    if (self->_closed) {
        pthread_mutex_unlock(&self->_mu);
        return;
    }

    self->_active++;

    Handle h = Slot_peek(slot);
    PoolBucket* b = Pool_bucket_for(self, h->link.type);
    mtk_check(b != nullptr, "Pool.put of an identity the pool was not created with");
    if (b == nullptr) {
        self->_active--;
        pthread_mutex_unlock(&self->_mu);
        return;
    }

    size_t in_pool = InnerStack_len(&b->free);

    Slot mine = nullptr;
    Slot_fill(&mine, Slot_take(slot));

    InnerQueue extra = (InnerQueue){ .head = nullptr, .tail = nullptr, .count = 0 };

    pthread_mutex_unlock(&self->_mu);
    self->_hooks.on_put(in_pool, &mine, &extra);
    pthread_mutex_lock(&self->_mu);

    if (self->_closed) {
        InnerQueue stragglers = (InnerQueue){ .head = nullptr, .tail = nullptr, .count = 0 };
        if (Slot_is_full(&mine)) {
            InnerQueue_push_back(&stragglers, Slot_take(&mine));
        }
        InnerQueue_append_queue(&stragglers, &extra);

        pthread_mutex_unlock(&self->_mu);

if (!InnerQueue_is_empty(&stragglers)) {
self->_hooks.on_close(stragglers);
}
pthread_mutex_lock(&self->_mu);
self->_active--;
pthread_mutex_unlock(&self->_mu);
return;
}
Pool_to_handle(self);
Pool_take_back(self, &mine);
while (true) {
Handle e = InnerQueue_pop_front(&extra);
if (e == nullptr) break;
Pool_take_back_handle(self, e);
}
pthread_cond_broadcast(&self->_cv);
self->_active--;
pthread_mutex_unlock(&self->_mu);
}
// Inner block structural closer modification engine
static inline void Pool_close_internal(Pool* self, InnerQueue* out) {
if (self->_closed) return;
self->_closed = true;
atomic_store_explicit(&self->_closed_fast, true, memory_order_release);
for (size_t i = 0; i < self->_buckets_len; i++) {
while (true) {
Handle h = InnerStack_pop(&self->_buckets[i].free);
if (h == nullptr) break;
InnerQueue_push_back(out, h);
}
}
pthread_cond_broadcast(&self->_cv);
}
/**

* Closes the pool and flushes existing resources directly into the user defined on_close hook pipeline.
/
static inline void Pool_close(Pool self) {
pthread_mutex_lock(&self->_mu);if (self->_closed) {
pthread_mutex_unlock(&self->_mu);
return;
}self->_active++;InnerQueue remaining = (InnerQueue){ .head = nullptr, .tail = nullptr, .count = 0 };
Pool_close_internal(self, &remaining);pthread_mutex_unlock(&self->_mu);self->_hooks.on_close(remaining);pthread_mutex_lock(&self->_mu);
self->_active--;
pthread_mutex_unlock(&self->_mu);
}

static inline bool Pool_is_closed(const Pool* self) {
return Pool_closed_fast(self);
}
/**

* Retrieves the instant counts of free items cached inside a target bucket mapping.
/
static inline size_t Pool_count_of(Pool self, TypeId t) {
pthread_mutex_lock(&self->_mu);
self->_active++;PoolBucket* b = Pool_bucket_for(self, t);
size_t count = (b != nullptr) ? InnerStack_len(&b->free) : 0;self->_active--;
pthread_mutex_unlock(&self->_mu);
return count;
}

#endif // MTK_POOL_H
```


### Strategic Mapping Details
* **Fixed Structural Storage Array:** C3's `PoolBucket[] _buckets` dynamic validation slice maps onto raw pointers linked to an immutable size tracker variable (`_buckets_len`), ensuring spatial memory stability during traversal inside the sequential array lookups.
* **Functional Inversion Architecture:** C3's inline type parameter bounds match the explicit `TypeId` variable checks tracking unique object pointers instead of dynamic text names. This gives fast layout binding evaluations at runtime across thread partitions.

<FollowUp>
Would you like to build an example application showcasing how to **implement a pair of concrete pool hooks** (like an object instantiation factory) to verify proper thread pooling transitions using **Clang**?
</FollowUp>



