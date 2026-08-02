# Errors as compile-time type IDs — investigated, rejected

Working note. Written when the idea was proposed, 2026-08-02.

Status: rejected by the owner. No `src/` change was made.

Companion to [llvm-pointer-switch-bug-001.md](llvm-pointer-switch-bug-001.md).  
That note says why a pointer tag cannot be a `switch` prong. This one says why  
the obvious integer replacement is worse.

## The proposal

Replace the runtime type ID — a unique pointer, `PolyTag` in  
`src/polynode.zig` — with a unique Zig error.

```zig
const Player = struct {
    pub const TYPE = @intFromError(error.Player);
};
```

Tags become integers. `switch` becomes available. No registration, no  
hand-maintained enum, no generated IDs.

The public API would not change shape. `item.tag()` would return `u16` instead  
of `*const anyopaque`.

## What works

Tested on zig 0.16.0, all four optimize levels, before any design work.

- `@intFromError(error.X)` is a real comptime `u16`. It works as an array
  length and as a `switch` prong. Confirmed at Debug, ReleaseSafe, ReleaseFast  
  and ReleaseSmall.
- `@field(anyerror, some_comptime_string)` accepts an arbitrary string. An
  error can be minted from a computed name.
- `@errorName` on the value gives a free debug string.

So the DISPATCH 1 wall is specific to **pointers**. It is not a general fact  
about tags. A tag that is an integer can be switched on.

## What does not work

Two separate problems. The second is the one that killed it.

### Values are not stable

`Player` was 171 at Debug and 1 at Release. Adding two unrelated errors  
elsewhere in the program moved it from 171 to 173.

Error values are indices into the whole program's error set, assigned late.  
Any source change anywhere renumbers them. The langref says so:

> It is generally recommended to avoid this cast, as the integer representation
> of an error is not stable across source code changes.

This is survivable. Both sides of every comparison come from one compilation,  
so the comparison is self-consistent. It only bans serializing a tag — the  
same rule the pointer already carries. But an integer *looks* persistable in a  
way a pointer does not, so it is a sharper edge.

### Uniqueness cannot be derived

Errors are interned by **name**, globally. `error.Timer` in two unrelated  
modules is one value. So a unique tag needs a unique name, and no automatic  
source of one exists.

| source | result |
|---|---|
| `@typeName(T)` | path within module plus type name. **No module prefix.** Collides |
| `@typeName(@This())` on the `PolyHelper` instantiation | wraps `@typeName(T)`, adds polynode's module rather than `T`'s. Collides identically |
| `@src()` at the instantiation site | `error: '@src' outside function scope` |
| a comptime counter | `error: expected type expression, found 'var'`. No container-scope `comptime var` |

The instantiation site is always container scope:

```zig
pub const PlayerPolyHelper = PolyHelper(Player);
```

So `@src()` is unavailable at exactly the place that needs it.

### The collision, demonstrated

Two modules, each with `sub/thing.zig`, each declaring `Player`:

```
A self_name = poly.PolyHelper(sub.thing.Player)   TAG=168
B self_name = poly.PolyHelper(sub.thing.Player)   TAG=168
distinct types? true
distinct TAGs?  false
```

The types are genuinely different — `a.Player != b.thing.Player` is true. The  
tags are the same.

Repro shape: three files, `poly.zig` holding the helper, `main.zig` importing  
both `sub/thing.zig` and a second module whose own `sub/thing.zig` declares the  
same type name.

```
zig build-exe --dep poly --dep modb \
  -Mmain=main.zig -Mpoly=poly.zig -Mmodb=modb/root.zig
```

## Why it was rejected

The failure is silent.

Two types share a tag. `isIt` returns true for the wrong one. `fromPoly`  
returns a `*T` pointing at a different struct. Nothing reports it.

The pointer makes this state unrepresentable. `&_tag` is unique by  
construction — no name, no rule for a user to remember, no way to get it wrong.

Trading an impossible bug for an invisible one, to gain a `switch`, is a bad  
trade for a toolkit whose subject is safe item transfer. `TagTable` already  
does dispatch without it. See [../table-dispatch-001.md](../table-dispatch-001.md).

## Mitigations that were considered

They narrow the risk. None closes it.

- **A comptime collision check.** `assertDistinctTags` over a list of tags
  compiles and gives a clean `@compileError`. It only covers the types the  
  application remembers to list.
- **An automatic check where a tag set is already declared.** `PoolHooks.tags`
  is a `[]const` set, so pool registration could assert distinctness with no  
  user action. It covers pool users only. A bare `isIt` or `fromPoly` caller  
  keeps the silent path.
- **A per-file locator.** `@src()` is legal inside a function, so a file can
  declare `fn here() std.builtin.SourceLocation { return @src(); }` and pass it  
  to `PolyHelper`. This yields `module/file.Type` and is genuinely  
  collision-proof. It costs one line per file and an extra argument — the  
  registration burden the pointer approach exists to avoid.

## The constraint worth keeping

This outlives the proposal.

> **A generic cannot learn which module its type parameter came from.**

`@typeName` omits the module. `@src()` is illegal at container scope. There is  
no container-scope `comptime var`. Any future scheme that derives identity from  
a type meets this wall.

## Related

- [llvm-pointer-switch-bug-001.md](llvm-pointer-switch-bug-001.md) — why a
  pointer tag cannot be a `switch` prong
- [../table-dispatch-001.md](../table-dispatch-001.md) — the dispatch mechanism
  that made `switch` unnecessary
- [../patterns-025.md](../patterns-025.md) — polymorphic dispatch, all three forms
