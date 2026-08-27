# 3tk — the decisions

**What was decided, and where it lives in the code.** One common section, then
one section per source file.

**This is the source of truth.** It is read instead of travelling through the
folder. It accumulates; it does not argue. An entry says what stands, not the
case that was made for it and not the alternative that was refused.

**Every entry carries its marker and its `file:line`.** The marker is the way
back to the document that ruled it. Paths are relative to
`design/secondary/lang/c3/`.

**It is alive.** It is revised whenever a decision changes, and a superseded
version goes to `../backup/`.

**A change to `../3tk/src` revises this file in the same stage.** Not later,
and not as a debt for the next stage to pay. **This file contradicting
`../3tk/src` is a defect of the stage that changed the source** — the owner's
ruling, 2026-08-25. It binds every file under `ref/`, and it exists because
every other document in this folder is frozen: `ref/` is the only place
staleness can hide.

**It does not describe state.** What has run, and what is next, is in
[`../3tk-status.md`](../3tk-status.md).

---

## Common — true across the port

### Vocabulary and shape

- **Outer and Inner.** The application's struct is the outer; the structure it
  embeds is the `Inner`. `R1`. `../3tk/src/mtk.c3:8`.
- **`Outer` is a category and never a type.** No such type is declared
  anywhere. `R1`. `../3tk/src/mtk.c3:8`.
- **`Handle`, not `InnerHandle`.** The module prefix already says whose handle
  it is. `R1`. `../3tk/src/inner.c3:40`.
- **No general-purpose list.** Two ordering primitives instead: a queue for the
  mailbox, a stack for the pool. `R2`. `../3tk/src/queue.c3:2`.
- **The module IS the front door.** C3 needs no re-exporting file.
  `../3tk/src/mtk.c3:4`.

### Visibility

- **Public structs with public fields.** Hiding is possible in C3 and is
  refused on cost. `D1`. `../3tk/src/mailbox.c3:24`.
- **Internal fields carry a leading underscore.** Reading them is a
  documentation problem, not a broken invariant. `D1`.
  `../3tk/src/mailbox.c3:24`.
- **The containers are submodules, and the reason is enforcement.** A C3
  submodule cannot see its parent's `@private`, so `mtk::mailbox` and
  `mtk::pool` are structurally outside `mtk`. `../3tk/src/mtk.c3:5`.
- **A container uses only what an application could use.** `Part 17.2`, and
  `run-builds.sh` greps for it. `../3tk/src/mailbox.c3:9`,
  `../3tk/src/pool.c3:21`.
- **`@private` does not apply to a C3 method declaration**, and the compiler
  warns that it does not. Measured 2026-08-25.
  `../3tk/src/inner.c3:27`.

### The helper surface

- **No instantiation and no alias, for any type, ever.** The helper's members
  are macros over `$Type`, generated per call site. `H0`.
  `../3tk/src/helper.c3:5`.
- **`mtk::managed` follows the same shape.** `H0b`. `../3tk/src/mtk.c3:8`.
- **The identity is C3's own `Type::typeid`**, and the port does not re-export
  it. `Q2`. `../3tk/src/helper.c3:20`.
- **The border is held by convention and the layering checks, not by
  visibility.** `mtk::inner_offset` is public and cannot be private.
  `../3tk/src/inner.c3:165`.

### Checking

- **Three tiers, one port macro.** `D6`. Tier 2 is `mtk::@check`
  (`../3tk/src/inner.c3:70`); tier 3 is `mtk::CHECKED`
  (`../3tk/src/inner.c3:81`); tier 1 is `always_assert` and has two sites,
  `../3tk/src/mailbox.c3:96` and `../3tk/src/pool.c3:216`.
- **A plain `assert` never guards a contract anywhere in this port.** Under
  `--safe=no -O3` C3's `assert` is an assumption, not a removed check, and a
  violated assumption is undefined behaviour. `Q11`.
  `../3tk/src/inner.c3:70`.
- **A compiled-out check is paired with ordinary code where a hole would
  otherwise open.** `Part 8.9`. `../3tk/src/queue.c3:159`.

### Outcomes

- **C3 faults are the outcome mechanism.** `D15`. `../3tk/src/inner.c3:58`.
- **A Part 19 outcome is a runtime condition, never a defect**, and is reported
  in every build mode. `../3tk/src/inner.c3:58`.
- **Interruption is dropped.** C3 has no interruptible condition wait, and the
  SHOULD's own text permits the drop. `D9`, `Part 2.9`.
  `../3tk/src/inner.c3:58`.

### Lifetime

- **A container keeps its allocator for life, and no release call takes one.**
  `D3`, `Part 13.1`. `../3tk/src/mailbox.c3:92`, `../3tk/src/pool.c3:212`.
- **An application item keeps its allocator in the OUTER, never in the inner.**
  `D3`. `../3tk/src/inner.c3:14`.
- **A participant is allocated once and lives for the duration of the run.**
  `Part 3.1`. `../3tk/src/mailbox.c3:68`, `../3tk/src/pool.c3:164`.
- **Creation is a transaction.** Each step's failure undoes exactly what
  succeeded before it, through `defer catch`. Nothing partially constructed is
  returned or observable. `../3tk/src/mailbox.c3:68`,
  `../3tk/src/pool.c3:164`.

### Concurrency

- **One wait-loop shape, used by every waiting call.** The deadline is anchored
  once before the loop; the state is re-evaluated from scratch every turn; a
  leaver that times out passes the signal on. `D7`. `../3tk/src/mailbox.c3:223`,
  `../3tk/src/pool.c3:321`.
- **`wait_timeout` is banned in the port.** It recomputes the deadline on every
  call. `D7`, `Part 2.5`. `../3tk/src/mailbox.c3:229`.
- **The pre-lock fast read is kept, and the re-read under the lock is not
  optional.** `D16`, `Part 15.4`. `../3tk/src/mailbox.c3:113`,
  `../3tk/src/pool.c3:229`.
- **A hook runs outside the mutex.** `Part 12.3`. `../3tk/src/pool.c3:38`.

---

## `mtk.c3`

**What it is.** The port's identity and its reading order. One constant.

- **No front-door file to write.** `import mtk` brings in everything
  `module mtk` declares, across every file that declares it. The proposal's
  re-exporting front door does not exist. `../3tk/src/mtk.c3:4`.
- **The reading order is the core in `module mtk`, then the border, then
  `Part 11`'s two optional containers.** The border and the containers are
  submodules of `mtk`. `../3tk/src/mtk.c3:5`.
- **The first five files are the required toolkit; the last two are optional
  tools.** `Part 17.1`, `Part 17.2`. `../3tk/src/mtk.c3:8`.
- **The vocabulary ruling lives here.** Outer and Inner; no `Any` prefix; no
  `NodeList`. `R1`, `R2`. `../3tk/src/mtk.c3:8`.
- **The submodule ruling lives here.** What it proves and what it does not is
  in this file. `D1`, `Part 17.2`. `../3tk/src/mtk.c3:5`.
- **Neither helper module is generic.** `H0`, `H0b`. `../3tk/src/mtk.c3:8`.
- **Part 7.1 was a SPECIFICATION defect and 004 closed it.** `V19`, `E6`.
  `../3tk/src/mtk.c3:8`.
- **The port's three ruling sets are named here** — `D1` to `D16`, `R1` to
  `R15`, and `H0`, `H0b`, `H5` to `H10`. It is the one place in the sources
  that lists them. `../3tk/src/mtk.c3:8`.
- **`VERSION` is `"0.2.0"`.** `../3tk/src/mtk.c3:10`.

---

## `inner.c3`

**What it is.** The inner (`Part 4`), the handle (`Part 10.1`), the Slot
(`Part 9`), the faults, the check macro, the link test, and the compile-time
discovery of the outer's fields. `../3tk/src/inner.c3:2`.

### The inner

- **One field, and it is a built-in pair.** `any link`: `link.ptr` is the chain
  link, `link.type` is the identity. `R6b`, `Part 4.2`, `Part 5`.
  `../3tk/src/inner.c3:14`.
- **The two meanings did not move; only where they are stored moved.** Two
  named fields until 2026-08-25. 16 bytes before, 16 after — an observation, and
  no code may depend on it. `../3tk/src/inner.c3:14`.
- **One link, not two.** `prev` is deleted. Nothing needed arbitrary removal,
  arbitrary insertion, backward traversal or a take from the back. `R5`.
  `../3tk/src/inner.c3:14`.
- **A second field is added only with a reason written down.** `D3` refused an
  allocator here; `R6` refused a membership field. `../3tk/src/inner.c3:14`.

### The self-link

- **The invariant: an item on a chain has a non-null link, the last item points
  at itself, an item on no chain has `link.ptr == null`.** `R6b`.
  `../3tk/src/inner.c3:14`.
- **It replaces invariant 16, retired in place.** `R10`, `V12`.
  `../3tk/src/inner.c3:14`.
- **The price: the link carries two meanings, and a walk that forgets
  `n.points_to() == n` loops forever.** Four sites carry the end test.
  `../3tk/src/inner.c3:14`.
- **The field is named `link` and not `next` because of that price.** On the
  last item `next` is a false claim. `../3tk/src/inner.c3:16`.

### Writing and reading the link

- **`any`'s halves are read-only**, so every link write rebuilds the whole
  value and carries the identity through by hand.
  `../3tk/src/inner.c3:28`.
- **`Inner.repoint_to` keeps the identity and swaps the chain link**, and it is
  the fourth corner of the stdlib's own table. Nine link writes go through it;
  `helper::init` is the exception. `../3tk/src/inner.c3:27`.
- **`Inner.points_to` is the reader**, and it is what lets a walk site say *the
  last item points at itself* word for word. `../3tk/src/inner.c3:34`.
- **Methods on `Inner`, not an extension of `any`** — the owner's ruling,
  2026-08-25. Extending a builtin widens the surface past what the change may
  touch. `../3tk/src/inner.c3:27`.
- **Neither is `@private`, and the language decided that.**
  `../3tk/src/inner.c3:27`.

### The handle and the Slot

- **One handle type, transparent.** An alias, not a typedef, so it converts
  freely with `Inner*`. `D4`, `Part 10.1`. `../3tk/src/inner.c3:40`.
- **The Slot is a container of one handle, or of nothing, and its emptiness is
  the transfer signal.** Empty means the item is elsewhere; full means the item
  is here and this Slot's holder is responsible for it. `Part 9.1`.
  `../3tk/src/inner.c3:49`.
- **The Slot is distinct, not an alias.** A `Handle` does not implicitly become
  a `Slot`. `D5`, `Part 9.2 rule 1`. `../3tk/src/inner.c3:49`.
- **A Slot starts empty by the language's default state.** There is no
  initializer to forget. `Part 9.2 rule 2`. `../3tk/src/inner.c3:46`.
- **A distinct Slot cannot be read with a bare null test, and the five reading
  members are the replacement.** `Part 9.9`. `../3tk/src/inner.c3:106`.
- **`Slot.fill` carries the never-overwrite check, and it is written once.**
  `Part 9.2 rule 1`. `../3tk/src/inner.c3:147`.

### The faults

- **The Part 19 outcome sets are C3 faults.** `D15`, `Part 15.5`.
  `../3tk/src/inner.c3:58`.
- **`UNKNOWN_IDENTITY` is not a Part 19 outcome, and that is deliberate.** The
  pool's identity set is fixed at creation, so asking outside it is a caller
  defect. It exists because the honest report used to be `NOT_AVAILABLE`, which
  `Part 19.3` reserves for the available-only mode. Reported by `Pool.get` and
  `Pool.get_wait` and by nothing else. `A3`, `P2`, `Part 11.7`.
  `../3tk/src/inner.c3:55`.
- **`interrupted` is absent, and 003 made that legible in the outcome tables.**
  `D9`, `V13`. `../3tk/src/inner.c3:58`.

### The checks

- **`mtk::@check` is tier 2, and under `--safe=no` it expands to nothing at
  all** — the condition is not evaluated and nothing is handed to the optimizer
  as a promise. `D6`, `Q11`. `../3tk/src/inner.c3:70`.
- **It is public, not `@private`.** `@private` does not reach a submodule, and
  `Part 17.2` entitles an application to the same check.
  `../3tk/src/inner.c3:70`.
- **The message is a compile-time string**, because `always_assert` takes one.
  `../3tk/src/inner.c3:70`.
- **`mtk::CHECKED` is tier 3, and the pool's duplicate-identity scan is the
  port's last reader.** `R6b` deleted the other one. `D6`.
  `../3tk/src/inner.c3:81`.

### The link test and the repair

- **The link test is exact, and it costs no field.** `h.points_to() != null`
  answers *is this item on some chain* with no false negative and no false
  positive, in O(1), through the public surface. `R6b`, `Part 8.7`, `V5`.
  `../3tk/src/inner.c3:91`.
- **`Part 8.6` and its O(n) walk are deleted outright.** A check that refuses
  an item on ANY chain catches everything the same-container walk caught.
  `V4`, `D12`. `../3tk/src/inner.c3:91`.
- **What it does not catch: a chain corrupted by code that reached around the
  container surface.** `../3tk/src/inner.c3:91`.
- **`reset` clears the LINK and not the identity.** `Part 5.4`'s identity is
  written once, by `helper::init`. `Part 8.8`. `../3tk/src/inner.c3:97`.
- **The link test and the repair live with the inner, not with a container**,
  because after `R6b` they are statements about one item.
  `../3tk/src/inner.c3:83`.

### Compile-time discovery

- **`inner_offset` is where `Part 4.4` — one inner per outer — is checked, and
  it is the only place it can be.** Both messages name the offending type.
  `Part 4.3`, `Part 7.4`. `../3tk/src/inner.c3:165`.
- **A `return` inside `$foreach` does not end compile-time iteration**, so the
  count accumulates and the assertions run afterwards.
  `../3tk/src/inner.c3:165`.
- **`required_alloc_offset` counts as `inner_offset` counts, and refuses a
  type with two `Allocator` fields.** Before, it overwrote on every match and
  took the last silently, so which allocator `release` returned the memory to
  was decided by declaration order and stated nowhere. The two discovery macros
  now read alike and both messages name the offending type. `P1`, `Part 4.4`.
  `../3tk/src/inner.c3:186`.
- **`required_alloc_offset` is declared once, in `mtk::inner`.** `mtk::managed`
  is its only caller and names it qualified. `P2`.
  `../3tk/src/inner.c3:186`.
- **`required_alloc_offset` lives inside a macro** because a module-scope
  `$assert` in a generic module cannot see the module's type parameter. `D3`.
  `../3tk/src/inner.c3:189`.

---

## `helper.c3`

**What it is.** The border. Every crossing between a typed pointer and a
type-erased handle. `Part 7`, `Part 7.5`.

- **Every crossing happens in this file and nowhere else.** That is what makes
  the address arithmetic auditable. `Part 7.5` MUST.
  `../3tk/src/helper.c3:4`.
- **No `inline` on the inner field.** An implicit conversion is a crossing that
  appears at no call site and in no file. `D2`. `../3tk/src/helper.c3:7`.
- **The members are macros over `$Type`; a new outer type costs not one line.**
  `H0`. `../3tk/src/helper.c3:5`.
- **The identity is `Type::typeid`, native.** No per-type mutable byte, which
  is what ztk needed against linker merging. `Q2`, `Part 7.2`.
  `../3tk/src/helper.c3:20`.
- **`helper.c3` is not a wall.** `mtk::inner_offset` is public, so any module
  importing `mtk` can compute an offset and cast. `H0` neither creates nor
  fixes that. `../3tk/src/inner.c3:165`.
- **A macro's boundary guard is a `@require` that reports at the CALLER's line.**
  `Part 15.5`'s tiers come from the language here, not from `mtk::@check`.
  `../3tk/src/helper.c3:29`.
- **One thing is lost against per-type instantiation:** a type declared but
  never crossed with is never validated, because there is no instantiation to
  force `Part 7.4`'s check. `../3tk/src/helper.c3:7`.
- **Part 7.1 as 004 words it is what this file is**, and the history of the
  correction is kept because a reader meeting this file next to 003 should know
  which way it ran. `E6`, `V19`. `../3tk/src/helper.c3:7`.

### The members

- **`is_mine` refuses a null handle and an uninitialized item.** A zeroed
  typeid matches no type. `Part 5.5`, `Part 7.2`.
  `../3tk/src/helper.c3:20`.
- **`init` writes the identity and clears the link in one write**, and it is
  the ONE `any_make` in the port whose second argument is not an existing
  `link.type`. That is the whole of `Part 5.4`'s *written once*, and it is one
  grep. `../3tk/src/helper.c3:35`.
- **`init` stays a separate call and is not folded into construction.** `H8`.
  `../3tk/src/helper.c3:31`.
- **`to_handle` is the only direction that adds the offset, and it cannot
  fail.** The type is inferred; no call site names it.
  `../3tk/src/helper.c3:48`.
- **An inbound crossing names its type, and that is not ceremony.** A crossing
  from an erased handle must say what it expects.
  `../3tk/src/helper.c3:60`.
- **`from_handle` returns null on a mismatch, which is a legitimate state of a
  correct program** — a walker of a heterogeneous list meets other types by
  design. `Part 6.2`, `Part 6.3`. `../3tk/src/helper.c3:60`.
- **`must_from_handle` is the asserting form, named apart**, and its `@require`
  compiles out under `--safe=no`. `Part 6.3`.
  `../3tk/src/helper.c3:76`.
- **One check, not two.** A null handle and a wrong identity are the same kind
  of wrong. `H7`, `Part 15.5`. `../3tk/src/helper.c3:75`.
- **`move_from_slot` has two postconditions and both are tested.** On a match
  the pointer is returned AND the Slot is cleared; on a mismatch null is
  returned AND the Slot is untouched. `Part 9.2 rule 4`.
  `../3tk/src/helper.c3:109`.
- **It computes from the handle `peek` observed, not from `take()`'s return
  value.** `H6`. `../3tk/src/helper.c3:111`.
- **`to` and `as` are `any`'s own names**, so a C3 reader already knows which is
  which. `../3tk/src/helper.c3:122`.
- **`to_handle`/`from_handle`, not `to_inner`/`from_inner`.** `H5`.
  `../3tk/src/helper.c3:47`.

---

## `managed.c3`

**What it is.** `mtk::helper` plus a create and a release. `Part 7.3`, `D10`.

- **The name is `managed`, not `owned`.** *Managed* means one thing: the item
  keeps the allocator it was created with, so its release takes none. No
  collector, no tracing, no background anything. `H10`.
  `../3tk/src/managed.c3:4`.
- **Two modules rather than one branching generator.** `Part 7.3` allows the
  distinction to be drawn by a separate name. `D10`.
  `../3tk/src/managed.c3:11`.
- **This module composes `mtk::helper` through the module rather than repeating
  it**, so the members of `Part 7.2` exist once.
  `../3tk/src/managed.c3:13`.
- **The distinction lives at the CALL SITE. No type declares itself managed,
  and the absence of a marker is a ruling.** `E7`, `H0b`, `D10`.
  `../3tk/src/managed.c3:8`.
- **The one hard gate is at build time:** `required_alloc_offset` refuses a
  type with no `Allocator` field and names the helper it should have taken.
  It is declared in `mtk::inner` and nowhere else. `Part 7.4`, `P2`.
  `../3tk/src/inner.c3:186`.
- **`Part 20` decision 2 is answered per type, at the type's own choice**, and
  not once for the whole port. `D3`. `../3tk/src/managed.c3:7`.
- **`release` names its type**, which the instantiated form did not have to,
  and that is an improvement at the call site.
  `../3tk/src/managed.c3:48`.

### The two members

- **Creation is an acquisition.** It fills a Slot and returns no pointer, so it
  obeys `Part 9.2` rules 3 and 4 like every other acquisition. `Part 9.8`.
  `../3tk/src/managed.c3:27`.
- **`alloc::new_try`, not `alloc::new`.** The plain form aborts on a failed
  allocation, which would leave rule 4 no path to be true on.
  `../3tk/src/managed.c3:31`.
- **`release` is a no-op on an empty Slot**, which is what makes `Part 9.7`
  legal: the defer is registered before the acquisition.
  `Part 9.2 rule 6`. `../3tk/src/managed.c3:41`.
- **No release call takes an allocator.** `Part 13.1`'s sharp clause.
  `../3tk/src/managed.c3:40`.

---

## `queue.c3`

**What it is.** The intrusive queue, first-in first-out. `Part 8`. Seven
operations.

- **There is no general-purpose list.** `NodeList` offered sixteen operations
  and nine had no caller. `R2`, `R3`. `../3tk/src/queue.c3:2`.
- **003 made that a legal reading of `Part 8.1` rather than a deviation.** 8.1
  says *ordering primitives*. `V2`. `../3tk/src/queue.c3:10`.
- **Nothing allocates, the item is the node, and every operation is O(1)** — in
  every build mode, because `R6b` deleted the insert walk.
  `../3tk/src/queue.c3:4`.
- **This is the port's TRANSFER container.** What crosses the public surface is
  always an `InnerQueue`. `R13`. `../3tk/src/queue.c3:5`.
- **This is the layer where the checks live, and `Part 8.10`'s bridge is
  dropped** — C3's stdlib has no intrusive list, so there is no other side.
  `Part 8.5`. `../3tk/src/queue.c3:10`.
- **No operation here can fail, and there is no fault type in the file.** A
  take from an empty queue returns null; that is an answer.
  `Part 19.4`. `../3tk/src/queue.c3:8`.
- **The count is kept, so `len` is O(1).** `Part 11.7` asks for a separate
  count only where the length is not. `../3tk/src/queue.c3:16`.
- **The walker is `Part 8.4`, and removing the current item during a walk is
  not supported.** `../3tk/src/queue.c3:31`.
- **The dispatch table is the application's, not something the toolkit ships.**
  `V18`, `Part 6.5`. `../3tk/src/queue.c3:33`.
- **The insert guard is ONE check, tier 2**, and it moves the guard from tier 3
  to tier 2 so a safe build pays O(1) per insert. `R6b`, `V4`.
  `../3tk/src/queue.c3:45`.
- **The end test `n.points_to() == n` is not optional.** A walker that followed
  the link blindly would hand the last item back for ever.
  `../3tk/src/queue.c3:82`.
- **There is no `push_front`.** `R15` dropped `Pool.put_all`, its only caller.
  `../3tk/src/queue.c3:91`.
- **`push_back_slot` is required at the public surface**, because `Part 12.5`'s
  composite hook gives a container to the application. `V3`.
  `../3tk/src/queue.c3:109`.
- **An empty Slot is a defect on an insert, not a no-op.** Rule 6's tolerance
  is for release. `../3tk/src/queue.c3:107`.
- **`pop_front` recognises the sole item by `head == tail`**, not by a null
  link: with the self-link there is no null link on a chain.
  `../3tk/src/queue.c3:130`.
- **`append_queue` is O(1) and needs no repair at the join.** `other.tail` is
  already self-linked. `Part 8.9`. `../3tk/src/queue.c3:147`.
- **Self-move is refused twice — an assert and an early return** — because the
  naive move rings the items into a cycle and loses every one.
  `Part 8.9`. `../3tk/src/queue.c3:159`.

---

## `stack.c3`

**What it is.** The intrusive stack, last-in first-out. `Part 8`. Four
operations.

- **`Part 8.1` permits it in the plural since 003.** `V2`.
  `../3tk/src/stack.c3:10`.
- **The pool keeps one per identity, and it is the only `InnerStack` in the
  port.** It is on no signature 3tk publishes — the four container-typed ones
  take an `InnerQueue*` — and **it is available to a caller like the queue.**
  The owner's ruling, 2026-08-26; `R13`'s middle clause was revised to match it,
  and `002` of this file is that revision. `R2`, `R11`, `R13`.
  `../3tk/src/stack.c3:4`.
- **No walker** — nothing walks a free list and `Part 8.4` is a SHOULD — **and
  no splice**, because a stack keeps no tail. `../3tk/src/stack.c3:5`.
- **There is no Slot-shaped insert.** `push_slot`'s only caller was `put_all`,
  which `R15` dropped; with that gone it had none, and it was deleted
  2026-08-24 on the owner's instruction. **The 2026-08-26 ruling does not
  reopen it** — `R15` is the ground that stands, and the ruling only retires a
  second one that said no application could reach a stack. `R15`, `R13`, `P6`.
  `../3tk/src/stack.c3:59`.
- **The stack is the storage container, where the queue is the transfer
  container.** Items rest in it until they are wanted again. That is the
  stack's own reason, and it does not depend on the pool. `R2`.
  `../3tk/src/stack.c3:8`.
- **The pool reuses last-in first-out for DEFECT SURFACING, not for
  performance.** The item just given back is on top, so a stale writer and a new
  holder collide immediately instead of much later. It is the owner's reason, and
  this entry is the only place it is written down. `R11`.
  `../3tk/src/stack.c3:2`.
- **No caller is entitled to the order, and that is what keeps the property
  useful.** `Part 11.7` stays silent on order; `Part 11.10` MUST already
  promises nothing. `R11`, `R14`. `../3tk/src/stack.c3:6`.
- **There is no `tail`.** That is what makes `Pool.close`'s flatten O(n) rather
  than a splice, and `R12` accepted the cost.
  `../3tk/src/stack.c3:17`.
- **`top` and a kept count, so `len` is O(1)**, and `Part 12.4`'s hint is read
  from it under the lock. `../3tk/src/stack.c3:16`.
- **The insert guard is the same one the queue carries, for the same reason.**
  `R6b`. `../3tk/src/stack.c3:29`.
- **The bottom item points at itself, and `pop` recognises the sole item by
  `h.points_to() == h`.** `../3tk/src/stack.c3:7`.
- **Nothing here can fail.** `Part 19.4`. `../3tk/src/stack.c3:8`.

---

## `mailbox.c3`

**What it is.** A queue of items, with waiting. Many producers, many consumers,
on one object. `Part 11.3` to `11.6`, `Part 19.1`.

### The structure

- **The mailbox is itself an item.** It embeds an inner, has a type identity,
  and can travel through another mailbox. `D1` kept that literal by refusing the
  opaque-type route: a `typedef Mailbox = void` embeds nothing. `Part 11.1`.
  `../3tk/src/mailbox.c3:24`.
- **The five parts are spelled out rather than shared.** Sharing them would put
  a second inner in the outer and break `Part 4.4`. After 003 the refusal is the
  specification's to allow. `V6`, `Part 11.2`.
  `../3tk/src/mailbox.c3:24`.
- **TWO queues, not one list with an anchor.** Out-of-band items live in their
  own queue and every take tries `_oob` first, so absolute priority with
  first-in first-out inside each class falls out of the structure. `R7`, `V7`,
  `Part 11.3`. `../3tk/src/mailbox.c3:121`.
- **Invariant 22 is kept; only the mechanism that produced it was deleted.**
  `R9`. `../3tk/src/mailbox.c3:132`.
- **The closed flag is a pair** — read and set under the mutex, also readable
  through the atomic and always re-read under it. `D16`, `Part 15.3`,
  `Part 15.4`. `../3tk/src/mailbox.c3:113`.
- **The wake generation is bumped by the waker, captured by each waiter before
  it waits, compared after every wakeup.** `Part 11.5`.
  `../3tk/src/mailbox.c3:235`.
- **The container's own crossings are macros forwarding to `mtk::helper`.**
  `H0` left no alias to write. `../3tk/src/mailbox.c3:46`.

### The operations

- **Creation is a transaction**, in the shape `std::threads::channel` uses.
  `../3tk/src/mailbox.c3:68`.
- **Close before release is the one precondition the toolkit refuses to
  soften**, and it is tier 1: `always_assert`, aborting in every build mode.
  `D6`, `Part 11.12` MUST. `../3tk/src/mailbox.c3:92`.
- **`send` is Slot-shaped: on success the Slot is cleared, on a closed mailbox
  it is untouched and the sender still has the item.** `Part 9.3`,
  `Part 11.6`. `../3tk/src/mailbox.c3:154`.
- **Out-of-band is ONE priority level, not a priority queue**, and two queues
  are one level with a cleaner home. `D14`, `R7`, `Part 11.4`.
  `../3tk/src/mailbox.c3:166`.
- **`poll` is kept beside `receive` although a zero-timeout receive has the
  same reach**, because the two differ in how the empty case is reported.
  `D13`. `../3tk/src/mailbox.c3:194`.
- **The wait loop carries four MUSTs**: the deadline anchored once; a wakeup
  carries no meaning; a leaver on a timeout signals if the queue is not empty;
  the closed flag read under the mutex. `D7`, `Part 2.4`, `Part 2.5`,
  `Part 2.6`, `Part 15.3`. `../3tk/src/mailbox.c3:223`.
- **The leaver must test BOTH queues**, or it consumes a signal and leaves a
  queued out-of-band item with nobody woken.
  `../3tk/src/mailbox.c3:257`.
- **The give-back order, one rule for `receive_all` and `close` both:** the
  queue is in the order `receive` would have taken them out — out-of-band first,
  then ordinary, first-in first-out within each. `R8`.
  `../3tk/src/mailbox.c3:271`.
- **`receive_all` gives the whole batch to the caller, and releasing the items
  is the caller's work.** What they are is knowledge the mailbox never had.
  `Part 11.6`. `../3tk/src/mailbox.c3:271`.
- **`wake_all` does not persist.** A thread that starts waiting afterwards
  captures the new generation and is unaffected. `Part 11.5`.
  `../3tk/src/mailbox.c3:296`.
- **`close` is callable more than once, and the test-and-set is inside the
  mutex.** `Part 11.12`. `../3tk/src/mailbox.c3:319`.
- **The named mistake: discarding the queue `close` returns drops the items**,
  and after `R6b` the refusal at the first reuse is exact.
  `Part 11.6`. `../3tk/src/mailbox.c3:319`.
- **`receive_all` and `close` assert the caller's queue is empty on entry, the
  way every Slot acquisition does.** Both say so in the contract and neither
  checked it; both call `append_queue`, which appends. A reused queue got a
  silently longer chain with no way to tell where the mailbox's items began.
  Tier 2, and no paired `if` — appending onto a non-empty queue in a fast build
  is defined, not a hole. `P3`, `Part 9.2 rule 3`.
  `../3tk/src/mailbox.c3:284`, `../3tk/src/mailbox.c3:329`.
- **The two vacuous `Part 2.6` signals are gone.** A timed-out waiter reached
  `if (self.has_queued()) self._cv.signal()` only when the `dequeue` two lines
  above had returned null, and under the same held mutex — the condition could
  not be true. `Part 2.6` is satisfied by that dequeue and by a stronger route:
  a waiter that finds an item does not leave at all, so the wakeup it might
  have consumed it consumed by taking the item. Removed rather than kept, on
  the `A3` precedent recorded for the pool's get loop: a live-looking branch
  that cannot be taken is a reader's trap. The function-level `Part 2.6` marker
  stands, because the port still owes and still keeps the MUST. `P4`.
  `../3tk/src/mailbox.c3:230`, `../3tk/src/pool.c3:341`.
- **`len` is read under the lock and is stale by the time the caller reads
  it.** `Part 12.4`. `../3tk/src/mailbox.c3:349`.

---

## `pool.c3`

**What it is.** A keeper of reusable items, grouped by type identity. Policy is
not in the pool; policy is in the hooks. `Part 11.7` to `11.10`, `Part 12`,
`Part 19.2`.

### The shape

- **The sharpest asymmetry in the toolkit lives here:** the mailbox gives
  everything back to a caller, and the pool's close gives nothing back at all.
  `Part 11.8`. `../3tk/src/pool.c3:21`.
- **`put_all` is gone.** It was `Pool.put` in a loop — no lock kept, the hook
  still run per item, no batching and no atomicity — and it handed the difficult
  case back in a different shape. `R15`. `../3tk/src/pool.c3:21`.
- **The counter is recorded:** the caller now writes that loop itself, with a
  chance of getting the refusal case wrong. `R15`.
  `../3tk/src/pool.c3:21`.
- **The hooks are a C3 interface, and `ctx` disappears** — the implementing
  object IS the context. `Part 12.1` MUST. `../3tk/src/pool.c3:38`.
- **A hook runs outside the mutex, several at once on different threads. It
  protects its own shared state, does not call back into the pool, and does not
  block.** `Part 12.3`. `../3tk/src/pool.c3:38`.
- **One free STACK per identity.** `R11`, `Part 11.7`.
  `../3tk/src/pool.c3:106`.
- **No count field beside the stack**, because `InnerStack.len` is O(1) and
  `Part 12.4`'s hint is read from it under the lock.
  `../3tk/src/pool.c3:106`.
- **The buckets are a flat slice, allocated once and scanned linearly.** A hash
  map would buy nothing: the set is small, fixed, and never grows.
  `Part 11.7`. `../3tk/src/pool.c3:119`.
- **The five parts are repeated rather than shared, as in the mailbox.** `V6`.
  `../3tk/src/pool.c3:119`.
- **Only the public surface of the core is used** — five types, `InnerStack`
  being the new one. `Part 17.2`. `../3tk/src/pool.c3:21`.

### The hook contracts

- **`on_get`:** the Slot is empty on entry; create one, or leave it empty to
  report failure. An empty Slot afterwards becomes `NOT_CREATED`. Returning a
  different identity is a defect of the application. `Part 12.2`.
  `../3tk/src/pool.c3:52`.
- **The contract says which build catches it.** The identity check is
  `mtk::@check`, and `Q4` confirmed the tier: `Part 12.2` files a hook's wrong
  identity as an ordinary defect of the application, so it is not one of the
  two `always_assert` sites. A fast build therefore cannot catch it, and the
  hook contract now says so. Without that sentence a reader could take the rule
  for a guarantee, when the failure is silent: every crossing downstream then
  answers correctly about the wrong type. `W2`. `../3tk/src/pool.c3:52`.
- **`on_put` has four outcomes and none is mandated.** A full Slot on return
  means one thing: an item is kept, original or replacement. `Part 12.2`.
  `../3tk/src/pool.c3:69`.
- **`extra` is the composite mechanism**: items added there are taken the same
  way, with the same checks. `Part 12.5`. `../3tk/src/pool.c3:69`.
- **`on_close` is called once by `close`, and possibly once more with
  stragglers**, and a hook must not free its own context on the first call.
  003 weakened `Part 12.2` for exactly this, and it is the only MUST 003
  weakens. `V11`. `../3tk/src/pool.c3:83`.
- **`on_close` receives one flat queue and no order is promised.** `R12`.
  `../3tk/src/pool.c3:83`.
- **The count handed to a hook is a hint and is stale** — after the removal on
  get, before the addition on put. `Part 12.4`.
  `../3tk/src/pool.c3:52`, `../3tk/src/pool.c3:69`.

### Creation and release

- **The hooks are a parameter of creation, not a later step.** A pool cannot
  exist without them. `Part 12.1` MUST. `../3tk/src/pool.c3:164`.
- **The identity set is fixed at creation and is not empty.** `Part 11.7`.
  `../3tk/src/pool.c3:167`.
- **A duplicate identity is refused at creation**, because `bucket_for` returns
  the FIRST match and a second bucket would be unreachable for the pool's whole
  life — a silent halving rather than a fault. `Part 11.7`.
  `../3tk/src/pool.c3:172`.
- **That scan is tier 2 with its O(n^2) cost behind the tier gate** — the
  technique `Part 8.6` used, surviving the Part's deletion with no Part left to
  cite. `D6`. `../3tk/src/pool.c3:172`.
- **Creation is a transaction**, and the bucket array is the last thing
  allocated and the one most likely to fail.
  `../3tk/src/pool.c3:164`.
- **Releasing an open pool aborts in every build mode.** The second of the
  port's two tier 1 sites. `D6`, `Part 11.12` MUST.
  `../3tk/src/pool.c3:212`.

### Get, put, close

- **`Part 19.3`'s asymmetry:** `NOT_AVAILABLE` comes only from
  `AVAILABLE_ONLY`, and `NOT_CREATED` only from a hook that produced nothing.
  `../3tk/src/pool.c3:262`.
- **An identity outside the pool's set is a caller defect.** A checking build
  aborts; a fast build reports `UNKNOWN_IDENTITY`. `A3`, `P2`, `Part 11.7`.
  `../3tk/src/pool.c3:241`.
- **Everything read before the pool unlocks for a hook is stale when the hook
  returns.** `Part 12.3`. `../3tk/src/pool.c3:298`.
- **No lock is held across a call into application code.** `Part 12.3`,
  `Part 15.2`. `../3tk/src/pool.c3:298`.
- **`get_wait` never creates. No hook is called on that path**, and where a
  plain get in `AVAILABLE_ONLY` reports `NOT_AVAILABLE` this reports `TIMEOUT`.
  `Part 11.9` calls the divergence deliberate. `../3tk/src/pool.c3:321`.
- **ztk's book says twice that `get_wait` calls the creation hook. The ztk code
  says it does not, and the code is the truth.**
  `../3tk/src/pool.c3:321`.
- **`get_wait` reports `UNKNOWN_IDENTITY` too, on two grounds that are not
  conformance:** the two gets must not disagree about the same defect, and a
  defect that sleeps for the whole timeout gets diagnosed as a performance
  problem. `A3`. `../3tk/src/pool.c3:335`.
- **`get_wait` is the one place that holds a `PoolBucket*` across a release of
  the mutex**, and it is safe because the bucket slice is allocated once and
  never grown, moved or reallocated. Only the contents change, and they are
  re-read every turn. `../3tk/src/pool.c3:335`.
- **No such pointer may be held across a call into application code.** A hook
  may put items back, and the rule there is to look the bucket up again by
  identity. `../3tk/src/pool.c3:335`.
- **No `if (b)` guard on either pop in the loop.** The early return made `b`
  non-null, and a live-looking branch that cannot be taken is a reader's trap.
  `A3`. `../3tk/src/pool.c3:343`.
- **`put` returns nothing: the Slot is the answer, not the outcome.** Cleared
  means the pool took it; unchanged means it was refused. `Part 9.4`.
  `../3tk/src/pool.c3:373`.
- **Unchanged means the POOL refused it, before any hook ran.** All four such
  paths — an empty Slot, the fast closed read, the closed flag under the mutex,
  an unknown identity — precede the hook, and none of `on_put`'s four outcomes
  gives the item back. The contract said only *it was refused*, which read as
  though a hook could hand it back. Reworded, not rebuilt: taking the item
  before the answer is known is the ruled design. `W1`, ruled 2026-08-24.
  `../3tk/src/pool.c3:373`.
- **`put` cannot fail and cannot be interrupted.** A worker that must give its
  item back must always be able to. `Part 2.10`.
  `../3tk/src/pool.c3:373`.
- **`put` re-reads the closed flag after the hook.** `Part 12.3` MUST forces
  the mutex open across a hook, and a close can run to completion inside that
  window. `P1`, ruled 2026-08-24. `../3tk/src/pool.c3:402`.
- **One rule for that window, and it is the pool's own: what the pool holds
  when it discovers it is closed goes to `on_close`.** Invariant 34 holds —
  nothing lands in a bucket after the flag is set. `Part 11.8` holds — nothing
  comes back to the caller. `P1`, `V11`. `../3tk/src/pool.c3:402`.
- **The alternative, restoring the caller's Slot, cannot carry `extra`**, whose
  items the caller never had. `../3tk/src/pool.c3:402`.
- **`close` empties every bucket into ONE queue, flattened.** The close hook
  never sees buckets or per-identity groups. `R12`.
  `../3tk/src/pool.c3:461`.
- **That flatten is `pop` then `push_back`, O(n) once, on a pool going down**,
  and the loop repairs every item's self-link on the way — which a splice would
  have had to walk and do anyway. `R12`. `../3tk/src/pool.c3:461`.
- **No order is promised, and `push_back` is chosen for being the simplest
  write.** `R12`. `../3tk/src/pool.c3:461`.
- **`close` is callable more than once and does NOT run the hook again.** The
  test-and-set is inside the mutex. `Part 11.12`.
  `../3tk/src/pool.c3:451`.
- **The hook is called ONCE, OUTSIDE the mutex, AFTER the flag is set.**
  `Part 12.2`. `../3tk/src/pool.c3:471`.
- **`count_of` is a hint, stale on return.** `Part 12.4`.
  `../3tk/src/pool.c3:485`.

---

## Appendix A — markers ruled in the folder that no source cites

**Accounted for, not restated.** Each is a real ruling; none of them appears in
`3tk/src` today, and the reason is given.

| Marker | What it decided | Why no source cites it |
|---|---|---|
| `R3` | Nine of `Part 8.2`'s sixteen operations are deleted | A consequence of `R2`. `queue.c3` and `stack.c3` carry what survived |
| `R4` | The queue keeps a front insert for `Part 11.8` | **RETIRED by `R15`.** `queue.c3:136` records the deletion |
| `R6` | A membership field in `Inner` | **REFUSED 2026-08-23.** Named at `inner.c3:38` as one of the two refusals |
| `R10` | Invariant 16 is retired and replaced by the self-link invariant | Reaches the source as `V12`, `inner.c3:52` |
| `R14` | The specification moves to 003; `Part 11.7` stays silent on order | A specification action. Its second half is at `stack.c3:46` |
| `D8` | The names — `AnyNode`, `AnyHandle`, `NodeList` | Superseded by `R1` and `R2`. No name it chose survives |
| `D11` | The porting order is `Part 22` as written | A process ruling. Nothing in the code can carry it |
| `H1` to `H4` | The per-type helper instance, `OFF` private, `TYPE` public | Written before `H0` and superseded by it. `H0` left no per-type object |
| `H9` | The two layout tests stop asking the helper for the offset | A ruling about `3tk/test`, not about `src/`. `mtk.c3:54` names it in the ruling list only |
| `A4` | `Part 6.5` is defaulted, not skipped | Its subject is `P5` in the audit, not a line of code |
| `A5` | The doc comments are a debt | The subject of plan 015, not of a source line |
| `Q1`, `Q3` to `Q10`, `Q12` | The C3 capability probes | Answered in `../c3-capabilities-001.md`. `Q2` and `Q11` are the two whose answers changed a design decision, and both are cited above |
| `S1` to `S7` | The sanitizer findings | `../3tk-sanitizer-notes-001.md`. About the runs and the tests, not about `src/` |
| `V8` to `V10`, `V14` to `V17` | Specification edits carried into 003 | Edits to the specification's own text. The port's side of each is above, under the file it belongs to |
| `P3`, `P4`, `P5` | Audit findings, still open | Not fixed, so no source line records them. `../3tk-deviations-001.md` holds them |
| `P7` | The wait loop passes the timeout again on every iteration | A finding of `../3tk-drafts-review-001.md` about a draft, not a ruling of this port. See Appendix B |
| `E7` | Nothing is lost by `H0b`; the premise was wrong | It is cited — `managed.c3:21`. Listed here because the marker is not spelled at that line |

---

## Appendix B — two things found, and neither is ruled here

**Reported, not decided.** `3TK-19`'s precedent: a decision no document holds is
not taken by this stage.

- **The marker letters collide across two documents.**
  `../3tk-drafts-review-001.md` numbers its own findings `P1` to `P19`, `D1` to
  `D20` and `H1` to `H7`, and those are different decisions from the `P`, `D`
  and `H` series of the audit and the two proposals. A reader who meets a bare
  `D3` cannot tell which document it belongs to without the context. This file
  uses the proposals' and the audit's series throughout, and names the drafts
  review where it means it.

- **`required_alloc_offset` was declared twice, identically. Ruled and gone
  2026-08-27.** The copy in `managed.c3` had no reader: both call sites name
  `mtk::inner::required_alloc_offset` by its qualified name. The copy was
  removed, the `mtk::inner` declaration stands, and the entry above says so.
  `P2`. `../3tk/src/inner.c3:186`.
