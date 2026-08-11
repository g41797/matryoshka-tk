![](kitchen/_logo/matryoshka-tk-logo.png)

---

# Matryoshka-Tk — Toolkit for Building Multitasking Systems

---

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Linux](https://github.com/g41797/matryoshka-tk/actions/workflows/linux.yml/badge.svg)](https://github.com/g41797/matryoshka-tk/actions/workflows/linux.yml)
[![Windows](https://github.com/g41797/matryoshka-tk/actions/workflows/windows.yml/badge.svg)](https://github.com/g41797/matryoshka-tk/actions/workflows/windows.yml)
[![macOS](https://github.com/g41797/matryoshka-tk/actions/workflows/mac.yml/badge.svg)](https://github.com/g41797/matryoshka-tk/actions/workflows/mac.yml)
[![Deploy Documentation](https://github.com/g41797/matryoshka-tk/actions/workflows/docs.yml/badge.svg)](https://github.com/g41797/matryoshka-tk/actions/workflows/docs.yml)


---


Software has two worlds.

- The first moves data.
- The second processes data.

Matryoshka-Tk is a _toolkit_ for the second world.


---

## What Matryoshka-Tk Is For

---

Matryoshka-Tk provides

- tools for the code that runs
  - **after** data enters the system
  - **before** data leaves the system
  - **within** long-running _tasks_

Typical example of such system - Image processing pipeline.

Goal of Matryoshka:

- to let developers think in terms of
  - processing
  - inter-tasks communication
  - reusing
  - workflows
- instead of low-level details

---


## Want to understand it?


>Read this <a href="https://g41797.github.io/matryoshka-tk/" target="_blank" rel="noopener noreferrer">beautiful documentation</a>


---


## NAQ (Never Asked Questions)

---


<details>  
<summary>How do you calculate Matryoshka LOC?</summary>
- only src/*.zig files
- comments, imports and empty lines are excluded 
</details>

---

## Influencers

---


- B.Mills <a href="[url](https://drive.google.com/file/d/1nPdvhB0PutEJzdCq5ms6UI58dp50fcAN/view)" target="_blank" rel="noopener noreferrer">Rethinking Classical Concurrency Patterns</a>
- <a href="https://github.com/g41797/mailbox" target="_blank" rel="noopener noreferrer">Former Mailbox</a>
- <a href="https://github.com/g41797/tofu" target="_blank" rel="noopener noreferrer">Matryoshka ideas kindergarden</a>
- <a href="https://github.com/g41797/matryoshka/" target="_blank" rel="noopener noreferrer">Former Matryoshka</a>
- <a href="https://ziggit.dev/t/new-linkedlist-api-footgun/10853/" target="_blank" rel="noopener noreferrer">New LinkedList API footgun</a>
- \*?\*T

---
