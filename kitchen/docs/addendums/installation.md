# Installation

---

- matryoshka-tk - is name of the project/repository
- matryoshka - is name of the module

---


Add *Matryoshka-Tk* to build.zig.zon:  
```bash
zig fetch --save git+https://github.com/g41797/matryoshka-tk
```

Add *matryoshka-tk* to build.zig:

```zig title="Add dependency"
    const matryoshka: *build.Dependency = b.dependency("matryoshka", .{
        .target = target,
        .optimize = optimize,
    });
```

```zig title="For any xyz_mod module that uses matryoshka, add the following code"     
    xyz_mod.addImport("matryoshka", matryoshka.module("matryoshka"));
```
```zig title="Import matryoshka"
pub const matryoshka = @import("matryoshka");
```

---
