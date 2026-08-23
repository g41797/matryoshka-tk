# First phase of dtk

> **Phase 1: Linux/POSIX only + Manual only.**

This removes the two biggest sources of uncertainty at once.

## Why this changes everything

### 1. No GC visibility problem

All Matryoshka objects and Items are manually allocated:

```text
Mbox ──────┐
Pool ──────┼── manual memory
Item ──────┘
```

So there is no question of:

```text
GC Item
   ↓
pointer hidden in manually allocated Mbox
   ↓
GC does not see it
```

That whole difficult design disappears.

### 2. No Manual/Managed dual implementation

Instead of immediately solving:

```text
                dtk
               /   \
          Manual   Managed
```

you start with:

```text
dtk
 |
 +-- POSIX
 |
 +-- Manual
```

The architecture can be proved first.

Later you can ask:

> Can Managed be added without damaging this design?

That is much safer than designing everything today for a mode you may never need.

### 3. POSIX gives you real synchronization primitives

You don't need to invent a synchronization abstraction immediately.

For Linux:

```text
pthread_mutex_t
pthread_cond_t
clock_gettime
```

are sufficient for the core blocking Mbox.

Conceptually:

```d
struct Mbox
{
    pthread_mutex_t mutex;
    pthread_cond_t condition;

    ...
}
```

These can be embedded directly in the manually allocated `Mbox`.

That is actually a **much cleaner fit** for your heap-allocated struct model than D `core.sync.Mutex`, which is itself a class.

You still need a small D binding/wrapper, but that is not "creating your own synchronization system." You are directly using POSIX.

## 4. Intrusion becomes simpler

Now the fundamental model is simply:

```text
manual allocation
      ↓
stable address
      ↓
Item*
      ↓
embedded PolyNode
      ↓
intrusive lists
```

No GC interaction.

No moving GC.

No hidden root registration.

This is an extremely natural environment for Matryoshka.

## 5. It may allow a very strong Item invariant

I would now investigate:

```d
struct PolyNode
{
    @disable this(ref PolyNode);
    @disable this(PolyNode);

    PolyNode* next;
    PolyNode* prev;
}
```

Then a Matryoshka Item containing `PolyNode` cannot be casually copied/moved by normal D code.

Combined with Manual allocation:

```text
allocate Item
      ↓
stable address for whole lifetime
      ↓
Matryoshka moves only ItemHandle
```

This is probably the cleanest D expression of the Matryoshka model.

---

# I would simplify the initial design drastically

Instead of our previous proposal:

```text
Manual
Managed
core.sync
custom synchronization?
shared?
GC visibility
BetterC?
Windows
macOS
```

start with:

```text
matryoshka-dtk
│
├── Linux
│
├── POSIX
│
├── Manual memory
│
├── pthread synchronization
│
├── heap-allocated stable Items
│
├── intrusive structures
│
├── Mailbox
├── Pool
└── Master architecture
```

This is a **much more realistic first project**.

---

# But I would make one distinction: Linux-only vs POSIX-only

I recommend saying:

> **POSIX is the implementation target. Linux is the supported platform.**

Why?

Because you can write against:

```text
POSIX threads
POSIX condition variables
POSIX monotonic clock
POSIX memory facilities
```

while initially testing and supporting only Linux.

So the project can be:

```text
Platform abstraction:
    none

Implementation API:
    POSIX

Supported platform:
    Linux
```

That leaves the door open without promising portability.

Later:

```text
Linux
   ↓
works well
   ↓
test another POSIX system
```

You may discover that no architectural changes are required.

---

# Does this mean `-betterC`?

**No. I would not make that decision yet.**

Manual-only does not mean BetterC.

The initial goal should be:

```text
Manual
+
@nogc where applicable
+
minimal dependencies
+
POSIX
```

Then, after the core works:

```text
Can it compile with -betterC?
```

If yes, great.

If no, ask whether BetterC provides enough value to justify changing the architecture.

Don't let BetterC control the design now.

---

# The biggest consequence: PolyHelper becomes simpler

Your earlier idea about:

```text
PolyHelper!(T, Manual)
PolyHelper!(T, Managed)
```

also becomes unnecessary **for now**.

You need only:

```text
PolyHelper!(T)
```

because every Matryoshka Item belongs to the same allocation regime:

```text
Manual
```

This is actually good.

Don't introduce allocation metadata until there are at least two allocation domains.

Otherwise you are designing for a problem that does not exist.

Later, if Managed is added:

```text
PolyHelper!(T, Manual)
PolyHelper!(T, Managed)
```

can be considered.

But I would not put `AllocationMode` into `PolyNode` now.

---

# My strongest recommendation

I would redefine the initial feasibility test as:

```text
Can D express this cleanly?

                    Master
                       │
              ┌────────┴────────┐
              │                 │
           Mbox*              Pool*
              │                 │
              └───────┬─────────┘
                      │
                  PolyNode*
                      │
                   Item*
                      
All objects:
    manually allocated
    stable address

Concurrency:
    POSIX threads
    pthread mutex
    pthread condition

Platform:
    Linux only

No:
    GC
    fibers
    Windows
    macOS
    async runtime
    scheduler
    BetterC requirement
```

If **this** does not fit D naturally, I would not continue with Managed mode or multi-platform support.

If this fits well, then `matryoshka-dtk` has passed the important test.

## My advice

**Yes: make "Linux only + Manual only" the initial main decision.**

I think it makes the D port **more likely to succeed**, not less ambitious.

You are not giving up features.

You are removing assumptions and proving the actual architecture first.

And importantly, it aligns very well with what Matryoshka already is: **stable, manually managed Items moving through intrusive infrastructure, rather than values being copied between language-managed containers.**
