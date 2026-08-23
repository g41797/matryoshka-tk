# Matryoshka-Tk C3 Proof of Concept Specification> 

**Architecture Blueprint:** A Pure Intrusive, Zero-Allocation Concurrent Data-Plane for Linux/POSIX.

This document synthesizes the architectural specifications, memory invariants, toolchain configurations, and core code implementations for porting the **Matryoshka-Tk** framework to the **C3 Programming Language**.
---## 📋 Architectural Principles & Invariants
Matryoshka-Tk organizes the processing of data *after* it enters the system and *before* it leaves, completely decoupled from low-level I/O. It converts a complex application into a clean grid governed by four building blocks: **Masters, Items, Mailboxes, and Pools**.
### 1. The Strict Invariant: "Exactly One Place"An `Item` (represented at the API level as an `ItemHandle`) resides in exactly one place at any given moment:* Active inside a **Master** execution loop.* Stored inside a **Mailbox** communication queue.* Recycled inside a **Pool** storage siding.* **Never several at once.**
### 2. Radical Zero-Allocation Intrusive Model* **No Runtime Allocations:** Once the initial system configuration and boot-up phase are complete, the framework guarantees exactly **zero dynamic heap allocations or frees** during the processing lifecycle.
* **Pure Intrusive Web:** The framework allocates no internal arrays, pointers arrays, or ring buffers. `Mailboxes` and `Pools` are lightweight, flat control structures containing nothing more than raw `Node` heads and tails tracking a physical chain of objects woven directly through the application's memory footprints.* **User-Driven Generation Hooks:** The framework never escalates to an allocator to dynamically scale items. All framework objects and application items are created upfront by the user via explicit memory hooks/factories and fed into the system tracking structures.
---## 🛠️ Linux & IDE Toolchain Configuration
C3 produces native binaries with accurate standard DWARF debug symbols and targets a direct C ABI. It is highly optimized for Linux (**Fedora / Kubuntu**) server environments.
### 1. Prerequisites (Fedora & Kubuntu)```bash
# Fedora
sudo dnf groupinstall "Development Tools" "Development Libraries"
sudo dnf install lldb gdb

# Kubuntu / Debian
sudo apt update
sudo apt install build-essential lldb gdb
```

### 2. Multi-Root Project Layout (`project.json`)
C3 supports a native, source-based, multi-root approach without complex build-scripts. It cleanly partitions your library core, examples, and test runners via the targets matrix:
```json
{
  "langrev": "1",
  "version": "0.1.0",
  "sources": [ "lib/**" ],

  "targets": {
    "matryoshka_lib": {
      "type": "static-lib"
    },
    "ex_simple": {
      "type": "executable",
      "sources-add": [ "examples/simple_pipeline.c3" ]
    },
    "real_tests": {
      "type": "executable",
      "sources-add": [ "tests/real_tests.c3" ]
    },
    "test_runner_ex1": {
      "type": "executable",
      "sources-add": [ "tests/run_ex1.c3", "examples/simple_pipeline.c3" ]
    }
  }
}
```
### 3. IDE Integration & Debugging* **VS Code:** Install the official extension `C3 Language Support for VSCode` (by `c3lang`). It automatically manages the Language Server Protocol (`c3-lsp`) and formatter (`c3fmt`). Debug via standard `cppdbg` or `CodeLLDB` profiling blocks.
* **JetBrains (CLion / Rider):** Import the syntax definitions through **Editor ➔ TextMate Bundles** by linking the official VS Code C3 repository. Wire up the standalone `c3lsp` binary into **Languages & Frameworks ➔ LSP**. Use CLion's **Parallel Stacks** window to visually diagnose deadlocks across active multi-threaded POSIX worker pools.
---## 💻 Core C3 Implementation Blueprint
The following implementation leverages C3's absolute address stability (no implicit/uncontrolled struct moves) to safely maintain intrusive layout parameters.

### 1. Core Structural Primitives (`core.c3`)
```c3
module matryoshka::core;

import std::concurrency;

/**
 * The elemental building block holding physical memory links.
 * Embedded identically inside Items, Mailboxes, and Pools to map routes.
 */
struct Node {
    Node* next;
    Node* prev;
}

/**
 * Lightweight, zero-allocation mailbox structure.
 * Maps concurrently to underlying Linux POSIX thread primitives.
 */
struct Mailbox {
    Mutex mutex;
    Cond cond;
    Node* head;
    Node* tail;
}

/**
 * Factory macro to cleanly initialize a Mailbox context on user memory.
 */
fn void Mailbox::init(Mailbox* self) {
    self.mutex.init();
    self.cond.init();
    self.head = null;
    self.tail = null;
}
```

### 2. Communication & Recycling Logic (`pipeline.c3`)
```c3
module matryoshka::pipeline;

import matryoshka::core;
import std::concurrency;

/**
 * Pushes an item into the Mailbox.
 * ZERO allocations. Seamlessly rewires physical memory linkages.
 */
fn void Mailbox::push(Mailbox* self, Node* item) {
    self.mutex.lock();
    
    item.next = null;
    item.prev = self.tail;
    
    if (self.tail == null) {
        self.head = item;
        self.tail = item;
    } else {
        self.tail.next = item;
        self.tail = item;
    }
    
    self.cond.signal();
    self.mutex.unlock();
}

/**
 * Pops an item out of the Mailbox with a strict timeout constraint.
 * ZERO allocations. Disconnects the node from the head of the chain.
 */
fn Node* Mailbox::pop_timeout(Mailbox* self, uint timeout_ms) {
    self.mutex.lock();
    
    while (self.head == null) {
        // Direct kernel-level wait using pthreads futex boundary
        if (!self.cond.wait_timeout(&self.mutex, timeout_ms)) {
            self.mutex.unlock();
            return null; // Timed out (Backpressure signal returned safely)
        }
    }
    
    Node* item = self.head;
    self.head = self.head.next;
    
    if (self.head == null) {
        self.tail = null;
    } else {
        self.head.prev = null;
    }
    
    self.mutex.unlock();
    
    // Completely isolate links before handing over thread context ownership
    item.next = null;
    item.prev = null;
    return item;
}

/**
 * Pure Recycler Pool structure.
 * Contains no dependencies on allocators or factory scale-ups.
 */
struct Pool {
    Mutex mutex;
    Node* free_list;
    uint count;
}

fn void Pool::init(Pool* self) {
    self.mutex.init();
    self.free_list = null;
    self.count = 0;
}

fn Node* Pool::get(Pool* self) {
    self.mutex.lock();
    
    if (self.free_list == null) {
        self.mutex.unlock();
        return null; // Signals immediate system backpressure
    }
    
    Node* item = self.free_list;
    self.free_list = (Node*)item.next;
    self.count--;
    
    self.mutex.unlock();
    return item;
}

fn void Pool::put(Pool* self, Node* item) {
    self.mutex.lock();
    
    item.next = self.free_list;
    self.free_list = item;
    self.count++;
    
    self.mutex.unlock();
}
```

### 3. Verification Workflow Execution (`main.c3`)
```c3
module main;

import matryoshka::core;
import matryoshka::pipeline;
import std::allocator;
import std::io;

// Concrete application item payload mapping to the 'ItemHandle' abstract concepts
struct JobTicket {
    Node node; // The mandatory intrusive hook placed explicitly at the top
    int id;
}

fn int main(String[] args) {
    printn("Initializing Matryoshka-Tk Static Framework Test Workflow...");

    // 1. The user provides a localized allocator for startup configurations
    Allocator* startup_alloc = allocator::page();

    // 2. All participants are allocated on the heap once during initialization
    Mailbox* task_mbox = (Mailbox*)startup_alloc.alloc(sizeof(Mailbox));
    Pool* dynamic_pool = (Pool*)startup_alloc.alloc(sizeof(Pool));

    task_mbox.init();
    dynamic_pool.init();

    // 3. User factory hook: Pre-instantiating items and feeding them to the Pool
    for (int i = 0; i < 5; i++) {
        JobTicket* ticket = (JobTicket*)startup_alloc.alloc(sizeof(JobTicket));
        ticket.id = 100 + i;
        
        dynamic_pool.put((Node*)ticket);
    }

    printn("System fully locked down. Starting non-allocating processing routines.");

    // Execution Simulation: Fetching from Pool and sending to Mailbox
    Node* managed_item = dynamic_pool.get();
    if (managed_item != null) {
        JobTicket* working_ticket = (JobTicket*)managed_item;
        printn("Master unlinked Item ID: ", working_ticket.id);
        
        // Pass item through the mailbox pipeline cleanly without a single allocation
        task_mbox.push(managed_item);
    }

    return 0;
}
```
---## 🔄 Automated CI/CD Docs Architecture
The C3 documentation workflow leverages the exact source-to-markdown strategy using **Material for MkDocs**. The `c3c docgen` command acts as a non-proprietary scanner that extracts JavaDoc blocks (`/** ... */`) into a flat json layout that can be parsed dynamically during runtime actions.

### GitHub Actions Document Configuration Pipeline (`.github/workflows/docs.yml`)
```yaml
name: Generate and Deploy Docs
on:
  push:
    branches:
      - main

permissions:
  contents: write

jobs:
  deploy-docs:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Codebase
        uses: actions/checkout@v4

      - name: Setup Python Environment
        uses: actions/setup-python@v5
        with:
          python-version: '3.x'

      - name: Install MkDocs & Theme
        run: |
          pip install mkdocs-material

      - name: Fetch and Install C3 Compiler
        run: |
          curl -sL https://github.com | tar -xz
          sudo mv c3c /usr/local/bin/

      - name: Run Native C3 Docgen Extraction
        run: |

c3c docgen src/
- name: Execute MkDocs Build and Render Hook
run: |
mkdocs gh-deploy --force
```


***

### 🔎 Questions to Advance to the Next Phase

To tailor the subsequent coding blocks exactly to your testing timeline, let me know:
* How should we approach **Type Erasure for the `ItemHandle` API**? Do you want to use **C3 macros** to automate the pointer casting, or implement a **`PolyNode` structural pattern** where the payload's type metadata is tracked inside a dedicated enum byte field?
* For the **Master** tracking loop, should each active Master be registered as an intrusive node inside an **Active Workers List**, allowing your orchestration engine to traverse and track threads without allocating standard runtime list contexts?


