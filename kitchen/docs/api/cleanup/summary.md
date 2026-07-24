# API Reference — Cooperative Cleanup — Pattern summary

---

## Pattern summary

```text
Pattern 1 (pool item)            Pattern 2 (heap item)

  null ──► get ──► non-null        null ──► create ──► non-null
    ▲                │               ▲                   │
    │    put (defer) │               │  destroy (defer)  │
    └────────────────┘               └───────────────────┘
         (recycle)                          (free)

         transfer →                         transfer →
         slot = null                           slot = null
         defer: no-op                       defer: no-op
```

---

