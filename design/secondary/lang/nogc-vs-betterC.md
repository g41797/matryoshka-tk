# @nogc vs betterC


D’s **`@nogc`** and **`-betterC`** are related, but they solve different problems:

- **`@nogc`**: a function-level, compiler-enforced guarantee that the function does not allocate through D’s garbage collector.
- **`-betterC`**: a program/module-level compatibility mode that removes the dependency on the D runtime (`druntime`) and Phobos, making D code linkable into C-style programs.

There is no reliable public statistic for the percentage of D projects using either mode. The D ecosystem does not appear to publish a representative survey separating normal D, `@nogc`, and BetterC usage, so any exact percentage would be speculation.

## Main difference

| Aspect | `@nogc` | `-betterC` |
|---|---|---|
| Scope | Function, method, delegate, or inferred call graph | Whole compilation unit/program |
| Removes the GC? | Prevents that function from using it | Removes D runtime support, including GC |
| Requires druntime? | Yes, normally | No |
| Can use normal D runtime? | Yes, outside `@nogc` functions | No |
| Can use Phobos? | Some `@nogc`-compatible parts | Generally no; imports may compile only if symbols do not require runtime support |
| Dynamic arrays | Yes, if allocated externally or otherwise GC-free | No built-in dynamic arrays |
| Associative arrays | No, because their operations are GC/runtime-dependent | No |
| Exceptions | Possible outside `@nogc`; not in `@nogc` code when throwing/allocating | Not available |
| Classes | Yes, including `scope` classes in some `@nogc` cases | Not available |
| Built-in threading | Yes, subject to runtime considerations | Not available |
| C interoperability | Good | Excellent; specifically intended for C integration |
| Typical use | Low-latency sections, allocators, embedded subsystems, real-time-ish code | C libraries, kernels, bootloaders, plugins, freestanding or constrained environments |

BetterC retains much more of D’s language than its name suggests: templates, compile-time function execution, metaprogramming, slices of static arrays, RAII, `scope(exit)`, bounds checking, and many struct features remain available. However, GC, classes, exceptions, associative arrays, built-in threading, and dynamic arrays are unavailable. [dlang](https://dlang.org/spec/betterc.html)

## What `@nogc` means

A function marked `@nogc` cannot directly or indirectly perform operations that allocate through the GC. For example:

```d
@nogc void process()
{
    int[256] buffer;       // Stack allocation: OK
    auto slice = buffer[]; // Slice: OK
    // auto a = new int [stackoverflow](https://stackoverflow.com/questions/34426289/does-a-pure-and-nothrow-function-which-does-not-pass-out-memory-automatically-co); // Error: GC allocation
}
```

The restriction propagates through calls:

```d
@nogc void process()
{
    helper(); // helper must also be @nogc
}

void helper()
{
    // Not @nogc
}
```

Typical GC-using operations forbidden in `@nogc` code include:

- `new` for GC allocation.
- Dynamic-array concatenation.
- Array appending.
- Resizing a dynamic array.
- Associative-array construction and operations.
- Calling a function that is not `@nogc`.
- Creating escaping closures that require GC allocation.

The language specification describes `@nogc` as a function attribute and treats it as part of the function type. It also notes that `@nogc` prevents the function from allocating through the GC, but does not by itself guarantee that no other thread can trigger a GC collection. [dlang](https://dlang.org/spec/function.html)

For a whole application, you can put `@nogc` on the call root:

```d
@nogc
void main()
{
    run_application();
}
```

Then the compiler checks the reachable call graph. This is often more practical than annotating every function manually.

### Important qualification

`@nogc` does **not** mean:

- no allocation at all;
- no heap allocation at all;
- no libc allocation;
- no custom allocator;
- no stack growth;
- no runtime overhead;
- no GC activity anywhere in the process.

It means specifically that the checked function does not use D’s GC allocation mechanisms. You can still use:

- `malloc`/`free`;
- `core.memory.malloc`-style facilities;
- custom arenas;
- region allocators;
- object pools;
- manually managed buffers;
- stack allocation.

For latency-sensitive code, `@nogc` is usually combined with explicit allocator ownership and often `GC.disable()` at a carefully controlled application boundary. The specification explicitly distinguishes the compiler guarantee of `@nogc` from disabling GC collections globally. [dlang](https://dlang.org/spec/function.html)

## What BetterC means

BetterC is enabled with a compiler option such as:

```sh
dmd -betterC app.d
ldc2 -betterC app.d
```

It makes the program depend only on the C runtime rather than D’s runtime library. A BetterC program can even provide a C-linkage entry point:

```d
extern(C) void main()
{
    import core.stdc.stdio : puts;

    puts("Hello from BetterC");
}
```

The primary purpose is integration with existing C applications and environments where initializing D’s runtime would be undesirable or impossible. The official documentation lists these goals:

- easier integration into C build systems;
- linking D modules into C programs;
- avoiding required `druntime` initialization;
- avoiding complications from mixing D GC and manual memory management. [dlang](https://dlang.org/spec/betterc.html)

BetterC is therefore not merely “D with `@nogc` everywhere.” It changes the available language/runtime environment.

For example, this is valid ordinary D:

```d
void main()
{
    auto values = [1, 2, 3];
    values ~= 4;
}
```

But it is not suitable for BetterC because dynamic-array allocation and resizing require runtime support. In BetterC, use fixed-size storage or explicit allocation:

```d
extern(C) void main()
{
    int [dev](https://dev.to/kapendev/avoiding-the-gc-in-d-stack-buffers-arenas-21o8) values = [1, 2, 3, 0];
    values [forum.dlang](https://forum.dlang.org/thread/ogxomrcxkjhzdtewolck@forum.dlang.org) = 4;
}
```

You can still use slices over existing storage:

```d
void sum(int[] values)
{
    int result;

    foreach (value; values)
        result += value;
}
```

The slice itself is only a pointer and length; the storage must come from somewhere else.

## When to use `@nogc`

Use `@nogc` when you want to retain most of normal D but enforce allocation discipline in selected parts of the program.

Good use cases include:

- packet parsing and serialization;
- network polling loops;
- audio callbacks;
- game-engine inner loops;
- lock-free queues;
- interrupt-adjacent code;
- embedded subsystems that still use a hosted runtime;
- custom allocators and memory-resource libraries;
- latency-sensitive worker threads;
- libraries that should offer deterministic allocation behavior.

A common architecture is:

```text
normal D application
├── configuration and startup: normal D, possibly GC
├── business logic: normal D or selectively @nogc
├── network/data plane: @nogc
├── allocator layer: explicit/manual
└── C/OS bindings: @nogc
```

This gives you a productive high-level environment while enforcing stronger rules where they matter.

For a systems programmer, this is often the best default choice when:

- you need D’s templates and metaprogramming;
- you want to use classes or ordinary D libraries;
- you need normal threading facilities;
- you still want compiler verification of no-GC call paths;
- you are building a hosted Linux, BSD, Windows, or macOS application.

## When to use BetterC

Use BetterC when the absence of `druntime` is a central requirement, not merely when you dislike GC.

Good use cases include:

- adding D modules to an existing C project;
- writing a C-callable library;
- small native libraries with a C ABI;
- firmware or bare-metal-adjacent code;
- boot-time or startup code;
- environments where runtime initialization is unavailable;
- plugins loaded by a C host;
- low-level OS components;
- projects that must use only explicit memory management;
- incremental migration from C to D.

BetterC is particularly attractive for a library such as:

```text
C application
├── existing C code
├── D BetterC parser
├── D BetterC data structures
└── C ABI boundary
```

The host does not need to initialize the D runtime merely to call the BetterC component.

However, BetterC imposes more design restrictions than `@nogc`. You lose built-in dynamic arrays, associative arrays, exceptions, classes, and built-in threading. The official documentation lists these as unavailable features. [dlang](https://dlang.org/spec/betterc.html)

## When to use neither

Normal D is usually preferable for:

- web services;
- command-line tools;
- build tools;
- desktop applications;
- compilers and developer tools;
- applications where occasional GC pauses are acceptable;
- code that benefits substantially from Phobos;
- projects with complex object graphs and ordinary dynamic collections.

Normal D does not force you to use the GC everywhere. You can manually manage important objects, use `scope`, use custom allocators, and mark selected functions `@nogc`.

## Can they be combined?

Yes, but the combination is often redundant at the application level:

```sh
ldc2 -betterC app.d
```

BetterC already excludes the GC and runtime-dependent features. You can still use `@nogc` in BetterC code as documentation and as an additional function-level contract, but BetterC is the stronger environmental restriction.

The more common practical arrangement is:

```text
normal D application
└── @nogc library/module
```

rather than:

```text
normal D application
└── BetterC module
```

Use BetterC when the module must be independent of `druntime`; use `@nogc` when the module may live inside a normal D process but must not allocate through the GC.

## Rough adoption estimate

No defensible percentage is available for:

- D projects using `@nogc`;
- D projects using BetterC;
- functions marked `@nogc`;
- production applications compiled with `-betterC`.

The reason is that these are build and API-design choices, not standard categories tracked by common developer surveys. Public D documentation and community material discuss both features, but they do not provide a representative usage census. Therefore, percentages such as “30% use `@nogc`” or “10% use BetterC” should not be treated as evidence.

A qualitative estimate is safer:

| Mode | Likely ecosystem position |
|---|---|
| Normal D with optional manual allocation | Dominant |
| Selective `@nogc` functions/modules | Common in systems-oriented and performance-sensitive libraries |
| Whole-program `@nogc` | Specialized |
| BetterC | Niche, but important for C integration and constrained targets |

The D community itself often recommends normal D plus `@nogc`/manual allocation when the requirement is simply to avoid GC, while BetterC is more appropriate when the D runtime must not be linked or initialized. [forum.dlang](https://forum.dlang.org/thread/ogxomrcxkjhzdtewolck@forum.dlang.org)

## Practical recommendation

For most systems software, choose in this order:

1. Start with **normal D**.
2. Design ownership and allocation boundaries explicitly.
3. Mark low-level APIs and hot paths **`@nogc`**.
4. Use custom allocators, arenas, pools, or caller-provided buffers.
5. Choose **BetterC** only if you specifically need no `druntime`, C-host integration, or a constrained runtime environment.

In short:

```text
Need no GC in selected code?       Use @nogc.
Need no D runtime at all?          Use -betterC.
Need both?                         Use -betterC and retain @nogc contracts.
Need maximum D productivity?       Use normal D with selective @nogc.
```

# Embedded development

For embedded development, D is usually used in one of three ways:

1. **BetterC D without `druntime`** for bare-metal microcontrollers.
2. **Normal D with a cross-compiled/minimal runtime** for embedded Linux or larger RTOS systems.
3. **D as a library or module alongside C**, using D’s C ABI and existing vendor SDKs.

The most common bare-metal configuration is roughly:

```text
LDC or GDC
+ -betterC
+ no GC
+ explicit memory management
+ custom startup code
+ linker script
+ C or D hardware-register bindings
```

D’s official documentation specifically mentions LDC as being able to target ARM, RISC-V, MIPS, and other embedded architectures. [dlang](https://dlang.org/areas-of-d-usage.html)

## Typical choices

| Target | Usual D approach | Runtime |
|---|---|---|
| Cortex-M bare metal | LDC or GDC + BetterC | None or minimal custom runtime |
| AVR/very small MCU | Usually C; D is difficult and niche | Minimal compiler support required |
| RISC-V microcontroller | LDC/GDC + BetterC | None or minimal runtime |
| Embedded Linux | LDC/GDC + normal D | Cross-compiled `druntime` and Phobos subset |
| RTOS-based system | BetterC or custom runtime | RTOS and selected D runtime pieces |
| Application processor, e.g. Cortex-A | Normal D | Usually full or rebuilt runtime |
| D library inside C firmware | BetterC + `extern(C)` API | No D runtime required |

## Bare-metal microcontrollers

For a Cortex-M or similar MCU, D is normally compiled with **LDC** or **GDC**, not the default host-oriented DMD compiler.

A typical toolchain contains:

- LDC or a GDC cross-compiler.
- `arm-none-eabi-ld` or GCC’s linker driver.
- A target-specific linker script.
- Startup code and interrupt vector table.
- CMSIS, vendor HAL, or custom register definitions.
- OpenOCD and GDB for flashing/debugging.
- Newlib, picolibc, or no C library, depending on the target.

The D compiler handles language code, but it does not automatically provide the complete embedded platform integration. You still need startup code, memory layout, interrupt vectors, peripheral definitions, and a linker configuration.

A minimal target might look like:

```sh
ldc2 \
  -mtriple=thumb-none-eabi \
  -mcpu=cortex-m4 \
  -betterC \
  -c \
  src/main.d
```

The exact target triple and flags depend on the LDC version and target ABI. An older D community example demonstrates the general Cortex-M workflow with LDC/GDC, `-betterC`, a linker script, OpenOCD, and GDB. [wiki.dlang](https://wiki.dlang.org/Minimal_semihosted_ARM_Cortex-M_%22Hello_World%22)

## What code is usable

A BetterC embedded program typically uses:

- structs;
- static arrays;
- slices over caller-owned memory;
- templates;
- compile-time function execution;
- `enum` constants;
- `scope(exit)`;
- `static assert`;
- `extern(C)` declarations;
- inline assembly where supported;
- direct memory-mapped I/O;
- custom allocators;
- manually managed buffers.

Example:

```d
struct Uart
{
    volatile uint32_t* status;
    volatile uint32_t* data;

    void writeByte(ubyte value) @nogc
    {
        while ((*status & TX_READY) == 0) {}
        *data = value;
    }
}
```

In real code, you would normally import integer types from a suitable low-level module or define target-specific types yourself.

The important distinction is that a **slice** can work in BetterC, while creating or growing a dynamic array generally cannot. A slice is just a pointer and length; it does not own storage.

```d
void send(ubyte[] buffer) @nogc
{
    foreach (byte; buffer)
        write_uart(byte);
}
```

The caller must provide `buffer` storage.

## Memory management

Embedded D programs generally choose one of these models:

### Static allocation

Use global or static buffers:

```d
__gshared ubyte rxBuffer[512];
```

This is simple and predictable, but global mutable state must be managed carefully, especially with interrupts and multiple execution contexts.

### Stack allocation

Use fixed-size local arrays:

```d
void decode() @nogc
{
    ubyte temporary[128];
}
```

This is useful for small bounded operations, but stack size must be known and monitored.

### Caller-provided buffers

This is usually the cleanest model for reusable embedded libraries:

```d
size_t encode(
    const(Message) message,
    ubyte[] output
) @nogc
{
    // Write only into output.
    // Return number of bytes written.
}
```

### Arena or pool allocation

For systems that need dynamic objects but cannot tolerate the GC, implement an arena, slab, pool, or region allocator. D’s templates and slices are useful here, but the allocator must be explicit.

### C allocator

On embedded Linux or systems with a C library, `malloc` and `free` may be available. On small bare-metal systems, they may be absent or unsuitable.

## `@nogc` versus BetterC for embedded

For small MCUs, BetterC is usually the more relevant choice because it avoids `druntime` entirely.

```text
Bare metal, no runtime startup:
    BetterC

Embedded Linux:
    Normal D + cross-compiled runtime

Latency-sensitive code inside a larger D system:
    @nogc

D module linked into an existing C firmware:
    BetterC + extern(C)
```

`@nogc` alone is not enough for bare metal. It prevents GC allocation in annotated code, but a normal D executable can still depend on `druntime`, module initialization, thread-local storage, exception support, and other runtime facilities.

BetterC removes those dependencies and disables features that require them. In particular, BetterC does not provide the GC, classes, exceptions, built-in threading, dynamic arrays, associative arrays, or normal module constructors/destructors. [docarchives.dlang](https://docarchives.dlang.io/v2.078.0/spec/betterc.html)

## Interrupts and real-time code

D can be useful for interrupt-driven firmware, but interrupt handlers should usually be written with strict restrictions:

- no GC allocation;
- no exceptions;
- no blocking;
- no locks that can deadlock against interrupt context;
- no unbounded loops unless hardware behavior guarantees termination;
- no initialization that depends on module constructors;
- careful use of `volatile` and memory barriers;
- minimal work inside the handler;
- communicate with the main loop through a ring buffer or atomic state.

A typical architecture is:

```text
interrupt handler
    └── writes event into fixed ring buffer

main loop/task
    └── consumes events
    └── performs larger computations

drivers
    └── expose @nogc, allocation-free APIs

application layer
    └── may use normal D if the platform has enough resources
```

D’s `@nogc` is useful for checking that interrupt and driver code does not accidentally enter the GC. However, `@nogc` is not a complete real-time guarantee: it does not prove bounded execution time, absence of blocking, absence of cache effects, or absence of interrupt latency.

## Embedded Linux

Embedded Linux is considerably easier than bare metal. Examples include ARM Cortex-A boards, Raspberry Pi-class systems, industrial gateways, and custom Linux devices.

Here you can usually use:

- normal D;
- LDC or GDC cross-compilation;
- `druntime`;
- a selected portion of Phobos;
- POSIX APIs;
- pthreads;
- sockets;
- filesystems;
- C vendor SDKs.

The D runtime must be built for the target, normally with LDC’s runtime-building tools or a GDC cross-toolchain. The D wiki documents cross-compiling LDC/GDC programs and building the runtime for ARM Linux targets. [wiki.dlang](https://wiki.dlang.org/Programming_in_D_tutorial_on_Embedded_Linux_ARM_devices)

For embedded Linux, the practical choice is often:

```text
normal D for application code
@nogc for critical I/O and real-time-ish paths
explicit allocators where latency matters
```

There is usually no reason to use BetterC unless you specifically need to avoid runtime initialization or integrate D into a C process.

## Hardware access and vendor SDKs

D normally does not have a universal embedded hardware abstraction layer comparable to vendor C ecosystems. You typically use one of these approaches:

- translate vendor C headers;
- write thin `extern(C)` declarations;
- use existing C headers through bindings;
- define registers and bitfields in D;
- wrap a C HAL with a safer D API;
- write a board-support package in D.

A common design is to keep the hardware-specific layer small:

```text
vendor SDK / register definitions
        ↓
thin D bindings
        ↓
allocation-free D driver
        ↓
portable D protocol or application logic
```

This is a good fit for D because portable protocol parsing, serialization, state machines, and compile-time configuration can be written independently of the MCU.

## How mature is D for embedded?

D is technically capable, but embedded support is much less standardized than C or C++. The main limitations are:

- fewer vendor SDK examples;
- fewer ready-made board-support packages;
- less RTOS integration;
- more manual compiler/linker setup;
- limited library support for very small MCUs;
- potential runtime-porting work;
- smaller community and tooling ecosystem;
- fewer production references.

D is more attractive for:

- Cortex-M3/M4/M7-class systems;
- RISC-V systems with reasonable flash/RAM;
- embedded Linux;
- firmware teams already comfortable maintaining toolchains;
- protocol-heavy or data-structure-heavy firmware;
- projects that benefit from templates and compile-time generation.

It is less attractive for:

- tiny 8-bit MCUs;
- teams requiring vendor-certified libraries;
- projects where every engineer expects standard IDE support;
- systems with extremely strict certification/tool qualification requirements;
- projects where the available SDK is tightly coupled to C++ templates or proprietary tooling.

## Recommended starting point

For a new Cortex-M D experiment, I would use:

```text
LDC
+ LLVM ARM backend
+ -betterC
+ fixed-size buffers
+ @nogc on drivers and handlers
+ C ABI for startup/vendor code initially
+ linker script
+ CMake or a simple Makefile
+ OpenOCD + GDB
```

Start with a blinking LED, UART output, and an interrupt-driven timer. Once that works, add a fixed-capacity ring buffer and a protocol parser. Keep the board-specific code separate from portable D code.

The key rule is: **use BetterC to remove runtime dependencies, and use `@nogc` to enforce allocation-free APIs**. They complement each other, but neither replaces the embedded platform work involving startup, linking, interrupts, clocks, memory layout, and peripheral support.