**C3** handles packages/libraries differently from Zig (or Go). There is no full-featured package manager like Zig’s `build.zig` + registry or Go modules yet. The system is still early (library packaging is explicitly marked “early alpha” and subject to change), but it is practical for source-based and binary libraries.

### Core concepts

- **Modules** (language level): Namespaces declared with `module foo;` or nested `module foo::bar;`. Code is organized into modules; `import` brings them in (with sensible defaults for submodules and `std::core`).
- **Projects**: Optional but recommended for anything non-trivial. Driven by `project.json` (or `project.json5`).
- **Libraries (`.c3l`)**: The distribution unit. A directory (or compressed archive) ending in `.c3l` that contains a `manifest.json` + C3/C sources (and optionally prebuilt static/dynamic libs per target).

This is closer to “source modules + optional prebuilt artifacts” than a pure binary package system.

### Creating a project / library

```bash
# Executable (default)
c3c init myproject

# Static library
c3c init mylib --template static-lib

# Dynamic library
c3c init mylib --template dynamic-lib
```

This creates the usual layout:

```
.
├── build/
├── docs/
├── lib/          ← place for .c3l dependencies
├── resources/
├── scripts/
├── src/
│   └── ...
├── test/
├── project.json
├── LICENSE
└── README.md
```

`project.json` controls sources, dependencies, targets, optimization, linked C libraries, etc. Key fields:

- `"sources": ["src/**"]`
- `"dependencies": ["some_lib"]` (looks in `dependency-search-paths`, default `lib`)
- `"type": "executable" | "static-lib" | "dynamic-lib" | ...`
- Per-target overrides, C sources, linker flags, etc.

Build with:

```bash
c3c build          # or c3c build <target>
c3c run            # build + run
c3c clean
c3c test           # if tests are configured
```

You can also compile individual files without a project:

```bash
c3c compile file1.c3 file2.c3
c3c compile-run ...
c3c static-lib ...
c3c dynamic-lib ...
```

### Distributing a library (`.c3l`)

1. Create a directory `mylib.c3l/`.
2. Put a `manifest.json` at the root:

```json
{
  "provides": "mylib",
  "dependencies": [],          // other .c3l libs
  "sources": ["..."],          // optional
  "targets": {
    "linux-x64": {
      "linked-libraries": ["mylib_static", "c"],
      "link-args": [],
      "dependencies": []
    },
    "macos-x64": { ... },
    "windows-x64": { ... }
  }
}
```

3. Place C3 sources (and/or `.c3i` interface files) next to the manifest or in target-specific subdirs.
4. Optionally ship prebuilt static/dynamic libraries in the target subdirectories (e.g. `linux-x64/libmylib_static.a`).

The library can be used **unpacked** (just the directory) or **packed** (compressed form of the same structure). The compiler only pulls in the parts that are actually used.

**Note**: Automatic “export this project as a `.c3l`” is not fully implemented yet (`c3c dist` is also incomplete).

### Using a library (consumer side)

**In a project** (`project.json`):

```json
{
  "dependency-search-paths": ["lib"],
  "dependencies": ["mylib", "ext"]
}
```

Put the `.c3l` directories (or archives) into `lib/`. Then just `import mylib;` (or the modules it provides).

**Without a project / command line**:

```bash
c3c compile --libdir path/to/libs --lib mylib mycode.c3
# or
c3c compile --lib path/to/mylib.c3l mycode.c3
```

There is also a simple vendor helper:

```bash
c3c vendor-fetch <name>   # downloads known libraries from the official vendor repo into lib/ and updates project.json
```

The official vendor repo currently has bindings for Raylib, SDL2, SQLite, Curl, GLFW, etc.

### Comparison with your Zig workflow

| Aspect              | Zig                                      | C3 (current)                                      |
|---------------------|------------------------------------------|---------------------------------------------------|
| Source as package   | Yes (modules / packages)                 | Yes – modules + `.c3l` source packages            |
| Build system        | `build.zig` (very powerful)              | `project.json` + `c3c` commands (simpler)         |
| Binary libraries    | Possible via build system                | Supported inside `.c3l` (per-target)              |
| Package registry    | Growing (zigpackage, etc.)               | Very limited – mainly the `vendor` repo + manual  |
| Distribution        | Source + build.zig or prebuilt           | `.c3l` directory/archive + manifest               |
| Client usage        | `zig fetch` / build.zig dependency       | `dependencies` in project.json or `--lib`         |

**Practical recommendation for a “same as my Zig packages” workflow**:

1. Keep your library as a normal C3 project (or just a set of modules).
2. For distribution, package it as a `.c3l` (source + optional prebuilts + manifest).
3. Consumers either:
   - Drop the `.c3l` into their `lib/` and list it in `dependencies`, or
   - Point at it with `--lib` / `--libdir`.
4. For pure source-style usage (like many Go/Zig packages), you can also just vendor the source files and add them to the consumer’s `"sources"`.

The ecosystem is still maturing—expect the library format and tooling to improve. Check the official docs regularly:

- https://c3-lang.org/misc-advanced/library-packaging/
- https://c3-lang.org/build-your-project/project-config/
- https://c3-lang.org/build-your-project/build-commands/
- https://github.com/c3lang/vendor

If you have a concrete Zig package structure you want to map 1:1, share more details and I can sketch the corresponding C3 layout/manifest.

**matryoshka-tk** is your Zig package — a small (~720–750 LOC) ownership-oriented toolkit for building background / multitasking systems (the “second world”: processing data inside long-running tasks).

### What it provides

Core building blocks (layered like Russian dolls):

1. **PolyNode + ItemHandle + Slot** — ownership identity and transfer
2. **Mailbox** — ownership transport (send / receive, OOB, etc.)
3. **Pool** — ownership lifecycle (get / put, recycling, hooks)
4. Higher-level patterns (Master, Select, Group, Future, pipelines, shutdown, etc.)

It is designed so developers think in terms of **processing**, **inter-task communication**, **reuse**, and **workflows** instead of low-level concurrency details. Typical use case: image-processing pipelines and similar long-running systems.

### How it is packaged & distributed today (Zig)

- `build.zig` + `build.zig.zon` (name `matryoshka`, version `0.0.1`, minimum Zig 0.16)
- Root module: `src/matryoshka.zig`
- Exposed as a **static library** + Zig module that clients import
- Clients typically consume it as a **source module** (via `zig fetch` / dependency in their own `build.zig.zon`), exactly the style you described earlier (“bound by client code as source modules, like Go”)
- Extra steps: unit tests, “core surface”, stories, docs generation

Docs live at https://g41797.github.io/matryoshka-tk/

---

### Mapping this to C3 (build / distribute / use)

Given your earlier question, here is the natural C3 equivalent:

| Zig side                          | C3 equivalent                                      | Notes |
|-----------------------------------|----------------------------------------------------|-------|
| Source module + `build.zig`       | Project with `project.json` + modules              | `c3c init matryoshka --template static-lib` |
| `src/matryoshka.zig` (and subfiles) | `src/**/*.c3` with `module matryoshka;` / nested modules | Keep the same logical layering (polynode, mailbox, pool…) |
| Static library artifact           | `"type": "static-lib"` target                      | Optional – pure source use is also fine |
| Client dependency                 | `.c3l` package **or** just vendored sources        | Recommended: ship as `matryoshka.c3l` |
| `zig fetch` / `build.zig.zon`     | Put `.c3l` in consumer’s `lib/` + list in `"dependencies"` **or** `--lib` | No real registry yet; manual / vendor-fetch style |

#### Suggested C3 packaging steps

1. **Create the library project**
   ```bash
   c3c init matryoshka --template static-lib
   ```

2. **Structure**
   ```
   matryoshka/
   ├── src/
   │   ├── matryoshka.c3          // root / re-exports
   │   ├── polynode.c3
   │   ├── mailbox.c3
   │   ├── pool.c3
   │   └── …
   ├── project.json
   └── …
   ```

3. **Ship as `.c3l`** (the distribution unit)
   - Directory `matryoshka.c3l/` containing:
     - `manifest.json` (`"provides": "matryoshka"`, target entries, optional linked libs)
     - the C3 sources (or `.c3i` interfaces + prebuilt static lib per target)
   - Consumers drop it into their `lib/` folder and add `"matryoshka"` to `"dependencies"`.

4. **Consumer usage**
   ```c3
   import matryoshka;          // or matryoshka::mailbox; etc.
   // then use PolyNode / Mailbox / Pool exactly as in the Zig design
   ```

Because the library is deliberately small and ownership-centric (no heavy runtime), a pure-source `.c3l` (or even just vendoring the `.c3` files) works very well — the same “source module” style you already use with Zig/Go.

Here is a concrete, ready-to-adapt sketch for porting **matryoshka-tk** to C3.

### 1. Library project (`project.json`)

Place this at the root of the C3 library project (created with `c3c init matryoshka --template static-lib` or manually).

```json
{
  "langrev": "1",
  "version": "0.0.1",
  "authors": [ "g41797" ],
  "warnings": [ "no-unused" ],

  "dependency-search-paths": [ "lib" ],
  "dependencies": [],

  "sources": [ "src/**" ],
  "test-sources": [ "tests/**" ],

  "output": "build",

  "targets": {
    "matryoshka": {
      "type": "static-lib",
      "name": "matryoshka"
    },
    "matryoshka-debug": {
      "type": "static-lib",
      "name": "matryoshka",
      "opt": "O0",
      "safe": true,
      "debug-info": "full"
    },
    "matryoshka-release": {
      "type": "static-lib",
      "name": "matryoshka",
      "opt": "O3",
      "safe": false,
      "strip-unused": true
    },
    "test": {
      "type": "test",
      "sources": [ "src/**", "tests/**" ]
    }
  },

  "opt": "O0",
  "safe": true,
  "debug-info": "full",
  "use-stdlib": true,
  "single-module": false,
  "link-libc": true
}
```

**Notes**
- Default target builds a static library.
- Separate debug/release targets give you the usual flexibility.
- `single-module: false` keeps the layered module structure (polynode, mailbox, pool…) clean.
- Add C sources later if you need any platform-specific helpers.

Suggested source layout:

```
src/
├── matryoshka.c3          // root re-exports
├── polynode.c3
├── mailbox.c3
├── pool.c3
├── polyhelper.c3          // optional
└── ...
tests/
└── ...
```

Each file starts with the appropriate module declaration, e.g.:

```c3
module matryoshka::polynode;
```

or a flatter scheme if you prefer.

---

### 2. Distribution package (`manifest.json` inside `matryoshka.c3l/`)

Create a directory `matryoshka.c3l/` (this is what consumers will drop into their `lib/` folder).

```json
{
  "provides": "matryoshka",
  "version": "0.0.1",
  "authors": [ "g41797" ],

  "dependencies": [],

  "sources": [
    "src/**"
  ],

  "targets": {
    "linux-x64": {
      "linked-libraries": [],
      "link-args": []
    },
    "linux-aarch64": {
      "linked-libraries": [],
      "link-args": []
    },
    "macos-x64": {
      "linked-libraries": [],
      "link-args": []
    },
    "macos-aarch64": {
      "linked-libraries": [],
      "link-args": []
    },
    "windows-x64": {
      "linked-libraries": [],
      "link-args": []
    },
    "windows-aarch64": {
      "linked-libraries": [],
      "link-args": []
    }
  }
}
```

**Directory layout of the `.c3l` package**

```
matryoshka.c3l/
├── manifest.json
├── src/
│   ├── matryoshka.c3
│   ├── polynode.c3
│   ├── mailbox.c3
│   ├── pool.c3
│   └── ...
└── (optional later)
    ├── linux-x64/
    │   └── libmatryoshka.a
    ├── macos-aarch64/
    │   └── libmatryoshka.a
    └── ...
```

Because matryoshka-tk is pure ownership logic and very small, shipping **source only** is the recommended and simplest approach (exactly matching your current Zig “source module” style). Pre-built static libraries per target can be added later if you want faster consumer builds.

---

### 3. How a consumer uses it

**Option A – Project style (recommended)**

In the consumer’s `project.json`:

```json
{
  "dependency-search-paths": [ "lib" ],
  "dependencies": [ "matryoshka" ],
  ...
}
```

Then:

```c3
import matryoshka;
import matryoshka::polynode;
import matryoshka::mailbox;
import matryoshka::pool;
// ...
```

**Option B – Command-line / no project**

```bash
c3c compile --libdir ./lib --lib matryoshka myapp.c3
```

---

### Quick start commands for you

```bash
# 1. Create the library project
c3c init matryoshka --template static-lib
cd matryoshka

# 2. Replace the generated project.json with the one above
# 3. Put your (ported) sources under src/
# 4. Build
c3c build
c3c build matryoshka-release

# 5. Package for distribution
mkdir -p ../matryoshka.c3l
cp -r src ../matryoshka.c3l/
# write the manifest.json shown above into ../matryoshka.c3l/
```

