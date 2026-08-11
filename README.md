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

## NAQ (Never Asked Questions)

---


<details>  
<summary>On the landing page, I saw the Matryoshka LOC count. How do you calculate it?</summary>

- Only src/*.zig files
- Comments, imports and empty lines are excluded 

Today (11 Aug 2026) - **722** LOC

</details>

---



## Want to understand it?

---


Read this <a href="https://g41797.github.io/matryoshka-tk/" target="_blank" rel="noopener noreferrer">beautiful documentation</a>

---

