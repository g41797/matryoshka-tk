# 3tk — log

Narrative of the 3tk line of work. Append-only, newest first.

Not read by default. Read it for history: what was decided, when, and why.  
Current state is in [3tk-status.md](3tk-status.md).

---

## 2026-08-23 — 3TK-11: the core redesign, in code

Written: [3tk-core-redesign-notes-001.md](3tk-core-redesign-notes-001.md), and
the port itself. `3tk-status.md` updated. `../common/` untouched, as plan 006
required. No `git` command run.

**All four builds green — 59 checks, 0 failures. Both sanitizers clean. 85
tests, up from 77.**

The stage had a specification and did not have a decision to make: R1 to R15,
ruled question by question the same day. What follows is what the code taught,
not what it chose.

**`AnyNode` → `Inner`, `AnyHandle` → `Handle`, `NodeList` → `InnerQueue` and a
new `InnerStack`.** `any.c3` became `inner.c3`; `list.c3` became `queue.c3` and
`stack.c3`; `t_list.c3` became `t_queue.c3` and `t_stack.c3`. The mechanical
half was a single pass and the compiler caught every survivor, because none of
these names is a string. **The real work was five files' worth of doc comments,
every one of which argued for a shape that no longer exists.**

**The self-link has six sites, not four.** 002 §3.2 counted four — `pop`,
`push`, `append_queue`, `iter` — and that count was for the queue alone. With
the stack: `InnerQueue.push_back`, `InnerQueue.pop_front`,
`InnerQueue.append_queue`, `InnerQueueIterator.next`, `InnerStack.push`,
`InnerStack.pop`. All six are three lines or fewer, so 001's objection to
mechanism B — three meanings across eleven sites — stays answered.

**Two of the six are where a translation of the old code goes wrong.**
`pop_front` has to recognise the sole item by `head == tail`, because with the
self-link there is no null `next` anywhere on a chain and the old `if (h.next)`
would read a self-pointer as a real successor. And the walker has to end at
`n.next == n`, or it yields the last item for ever. Every walk in `t_queue.c3`
carries a count assertion for that reason: **a hang is a worse test failure than
a wrong answer, because it reports nothing.**

**Invariant 5 was the one to get wrong, and 002 §4.4 said so in advance.** The
leaver's signal in `receive`'s timeout path used to read `self._queue`, and the
mechanical rewrite is `_regular` — which leaves a queued out-of-band item with
nobody woken. It is written as a named predicate, `Mailbox.has_queued()`, over
both queues. **No test catches this one**; a missed signal is a timing defect
and the suite does not provoke it. What protects it is the name and the comment,
and that is stated rather than papered over.

**Three corrections to 002, in details rather than in decisions.**

- **The stack has five operations, not six.** §5.1's own table lists exactly
  five — `push`, `push_slot`, `pop`, `is_empty`, `len` — and the sentence above
  it says six. Twelve operations replace Part 8.2's sixteen; eleven of the
  sixteen leave the port, not nine.
- **Tier 2 does not reach a fast build.** §10.3 says the rewritten negative
  "now aborts in a fast build too, because the check is tier 2". `@check` under
  `--safe=no` expands to nothing at all — the whole of D6, and of 3TK-4's Q11
  finding. What R6b bought is the exact check at O(1) in an ordinary safe build,
  where before it cost an O(n) walk per insert. The abort was always there where
  the checks are live.
- **Two `put_all` tests were converted rather than deleted.** §10.2 expected
  both gone. §6 had named the counter itself — *the caller now writes the loop,
  with a chance of getting the refusal case wrong and losing items quietly* —
  and deleting the only tests of the refusal path is the wrong answer to a risk
  the proposal raised in writing. `t_pool.c3` grew `put_batch`, the seven-line
  loop `Pool.put`'s doc comment now recommends, and both tests point at it. The
  behaviour under test did not change; the code under test moved from the port
  to the caller, so the test moved with it.

**The layering check had to be rewritten, not renamed.** `run-builds.sh`
guarded Part 17.2 by grepping the containers for `unlink_no_repair|@guard_insert`.
`unlink_no_repair` no longer exists — with no `remove` and no `pop_back` there
is no unrepaired removal to reach for. **Grepping for a symbol that cannot
appear is a check that passes for ever having proved nothing**, which is the
exact failure `run-builds.sh` already records for `release_open_pool`. It now
greps for `@guard_insert` and for any assignment to a `.next` field.

**Two tests were supposed to fail and did.** `t_identity.c3` and `t_owned.c3`
both assert the inner's size against `2 * uptr::size + typeid::size`. They exist
so a field cannot be added to the inner without someone deciding to, and they
were the first thing the stage had to change — to `uptr::size + typeid::size`,
16 bytes.

**Part 18 re-walked: still thirty-four rows.** Row 16 retired — *the link test
is not a membership test*, which it now is — and the self-link invariant took
its place. Row 22 **kept**, against plan 006's expectation that two queues would
delete it: the anchor was the mechanism, the ordering is a promise. Row 13
strengthened, because insert is O(1) in checking builds too. Rows 1 to 12, 18,
19, 21 and 23 to 33 untouched, and section 6.2 — creation is a transaction — is
the one a rewrite loses quietly and did not: both `create` functions keep every
`defer catch` unchanged.

**One warning for the next port.** A blind rename of `Any` inside identifiers
turned `remove_from_anywhere` into `remove_from_innerwhere`, in a test that was
about to be deleted anyway. Rename on word boundaries, and read the diff.

**What this stage did not do, and the plan is why:** `../common/` is
untouched, so **the port is now ahead of the specification it is written from**.
A port written from `matryoshka-specification-002.md` today would reproduce
`prev`, the general list and the anchor. R14 rules that 003 is cut; it is still
not scheduled, and it is the strongest candidate for what runs next.
`3tk-porting-proposal-004.md` is not edited either — §10.4 leaves it as the
record of what was built.

**One open question this stage found and did not answer.**
[3tk-who-supports-slot.md](3tk-who-supports-slot.md), a note from the owner —
at `3tk/src/` while the stage ran, moved up to the folder root by the owner
immediately after — argues the containers should not support the Slot idiom at
all: that
`push_back_slot` and `push_slot` belong on `Mailbox` and `Pool`. 3TK-10 did not
rule on it and 3TK-11 did not act on it. It is in the status file's open
questions now, because the note uses names the redesign refused and a reader who
finds it cannot tell whether it is current.

---

## 2026-08-23 — the redesign is ruled, question by question, and proposal 002 is cut

Written: [3tk-core-redesign-proposal-002.md](3tk-core-redesign-proposal-002.md).
001 to `backup/`, links corrected. `3tk-status.md` updated. **No code touched.**

The owner asked for the questions one at a time rather than as a list, and that
is why three decisions moved. A list would have been accepted or refused whole.

**R6 refused — no membership field.** 001 wanted a third field, `void* chain`,
at the same 24 bytes `prev` cost. The owner said: check what is possible with
`next` alone. It is. **The last item of every chain points at itself**, so
`is_linked` is `next != null` and it is **exact** — no blind spot, and it still
deletes `contains` and the O(n) walk on every insert. `Inner` drops to two
fields and 16 bytes.

**001's argument against the self-link was measured against the wrong
container.** It said a terminator gives `next` three meanings across eleven
sites in `list.c3`. Ruling 2 abolishes that container: with nine operations
deleted, about four sites touch `next`. The field bought one query — *is it on
__this__ container* — whose only caller, `remove`, is deleted.

**R11 has a reason now, and it is not performance.** 001 recorded the pool's
reversal to last-in first-out as legal-but-arbitrary under Part 11.10. The
owner's reason is **defect surfacing**: under first-in first-out, an item given
back sits at the back of the free list, so code still keeping a pointer to it
writes to an item nobody has re-taken and nothing conflicts — and if the put
hook did not reset the contents, the stale writer sees data that still looks
plausible. Under last-in first-out the **next `get` gives that item to a new
owner**, so the two writers meet immediately and the defect appears next to its
cause. Same reasoning as not quarantining freed memory. It goes in the doc
comment on the pool's stack, because a later reader will otherwise take the
stack for an arbitrary choice.

**R15 — `put_all` is dropped**, and it retires R4. The owner said it looked
cumbersome and asked for a real opinion rather than a defence. It is: `Pool.put`
in a loop, inherited from `pool.zig:394`, no batching and no atomicity. The
claim that it encodes a fiddly loop once does not survive checking — **it does
not spare the caller the difficult case, it gives the difficult case back in a
different shape**, because a caller whose pool closed mid-batch still keeps a
partly-emptied queue. Its price was a container operation nothing else needs, a
MUST clause in Part 11.8 and the most awkward contract in the toolkit. Ruling
2's own principle applies to it, and 001 had applied that principle to
`NodeList` and not to this. **`InnerQueue` reaches seven operations and is
genuinely minimal.**

**R8, R9, R12, R13, R14 accepted as proposed.** The give-back order is one
sentence for both containers. Invariant 22 is kept and only the anchor goes.
`Pool.close` empties every bucket into **one** `InnerQueue`, flattened — the
hook never sees buckets — and **no order is promised**, because the hook's loop
is the same either way. There is no `InnerList`. The specification moves to 003,
which is ruled and not scheduled.

**A banned word, and a scan scope nobody had noticed.** The owner caught one of
`rules-049.md` Part 5's banned words in 001. Part 5's own scan skips
`design/secondary/`, so **no scan has ever covered this folder** — every
document in it was written unchecked. A full scan against the whole list found
nine hits, all in 001: three of that word, four custody-sense uses of two
others, two AI-ish words. `3tk-status.md` and `3tk-log.md` were clean. 002 is
clean against the whole list. 001 was left as it is, being a record.

Four builds green and sanitizers clean throughout — nothing in `3tk/` moved.

**3TK-11 has no open question in front of it.**

---

## 2026-08-23 — 3TK-10: the core redesign, as a proposal

Written: [3tk-core-redesign-proposal-001.md](backup/3tk-core-redesign-proposal-001.md),
726 lines. **No code touched.** Four builds green, 59 checks, 0 failures, and
the sanitizers clean — trivially, because nothing in `3tk/` moved.

The stage read the owner's two documents against `3tk/src/` rather than on
trust, the way 3TK-8 read its review. That reading is the whole value of the
stage and it disagreed with its inputs in three places.

**The required-operation audit passes.** Every one of `NodeList`'s sixteen
operations was grepped for callers. `insert_before`, `remove`, `pop_back`,
`front` and `back` **have no caller in `src/` at all** — only `t_list.c3` uses
them. `insert_after` has exactly one, the out-of-band insert. `prev` has exactly
one job, `unlink_no_repair`, which serves two dead operations. Nothing needs
arbitrary removal, arbitrary insertion or backward traversal. Ruling 5 is safe.

**The out-of-band semantics are Meaning A**, absolute priority, FIFO within each
class — `mailbox.c3:143-159`. `3tk-to-fifo-lifo-single-001.md` §4 refused to
choose two queues before that was measured, and it was right to. Two queues
reproduce it exactly. `t_mailbox.c3:139-162` does not change.

**The pool is FIFO today, not LIFO** — `pool.c3:263`, `:337`, `:425`. Ruling 3
is therefore a **behaviour change**, not a container swap. It is legal: Part
11.10 promises no order, and no test asserts the current one. Recorded rather
than discovered later.

**Consequence 2 has a better answer than the four the plan listed.** With one
link the last item of every queue has `next == null`, so the double-insert guard
fails exactly where it matters. The plan named four mechanisms. The stage
proposes a fifth reading of the same choice: **`prev` is deleted and a `void*
chain` field takes its place.** The inner stays three words and 24 bytes, the
check becomes exact — no blind spot, and membership is `chain == container` in
O(1) — and **`contains` and the O(n) walk on every insert are deleted outright.**
Part 8.7's own last bullet says a port that marks membership properly is
strictly better and pays a field for it; ruling 5 is what makes the field free.
So the redesign ends up **stronger** than what it replaces, which is not how
consequence 2 was framed.

**Invariant 22 should not be deleted**, and the plan said it would be. The
*anchor* dies. The *ordering* is a promise to callers, is asserted by a test,
and is unchanged by two queues. Delete the mechanism clause of Part 11.3; keep
the row.

**The close order:** out-of-band first, then ordinary, FIFO within each — for
`close` and `receive_all` both, stated as one rule. It is the only order that
changes nothing, because the single queue already produces it.

The cost: every source file changes, about 20 of 77 tests are rewritten and the
rest renamed, and one negative — `insert_twice_same_list` — gains coverage
rather than losing it, since its check moves from tier 3 to tier 2 and fires in
a fast build too.

**Consequence 4: the recommendation is to move the specification to 003**, not
to declare a 3tk deviation. Nothing in the redesign turns on a C3 capability, so
it does not belong in a C3 document — and dtk has run no stage, so the cost
lands where nothing is built. Nine Parts would move; §8.1 names each with its
marking. `../common/` was not edited. The owner rules.

Fourteen decisions, R1 to R14. Seven are the stage's own. **R6, the `chain`
field, is the one 3TK-11 cannot start without.**

3TK-11 stays declared and not authorized.

---

## 2026-08-23 — the core redesign is ruled, and 3TK-10 will design it

Written: [3tk-staging-plan-006.md](3tk-staging-plan-006.md), adding **3TK-10**.
Plan 005 to `backup/`, links corrected. `3tk-status.md` updated. **No code
touched and no stage run** — this entry exists so the direction survives a
context clear, because until now it lived only in a conversation.

Two documents arrived in the folder from the owner:
[3tk-naming-001.md](3tk-naming-001.md), 476 lines, proposing Outer/Inner naming,
and [3tk-to-fifo-lifo-single-001.md](3tk-to-fifo-lifo-single-001.md), 1058
lines, arguing that `NodeList` should not be the centre of the design. The owner
then gave the direction in five lines, and it is the input to 3TK-10 rather
than a suggestion to be weighed:

1. Drop `Any*` and every inherited ztk name — **Outer / Inner**.
2. Stop reproducing Zig's `DoublyLinkedList`. No general-purpose list.
3. **FIFO for the mailbox, LIFO for the pool.**
4. **Two FIFOs in the mailbox**, ordinary and out-of-band.
5. **One link, not two.** `next` only.

This is the largest change since the port existed, and it is bigger than 3TK-8
and 3TK-9 together. It deletes most of Part 8, retires `NodeList`, changes the
inner that Part 4.2 fixes, and removes D14's anchor. So **3TK-10 ends at a
proposal and does not touch `3tk/src/`** — the code is 3TK-11.

**The owner confirmed the sequence and asked for it on disk**, so plan 006
carries both: 3TK-10 authorized, **3TK-11 declared and not authorized**, running
only after the ruling on the proposal. Writing the second stage down now costs
nothing and fixes the order against anyone's memory of the conversation. That is this folder's habit and there is no reason to break it for
the one change most likely to need arguing about first.

Four consequences are written into the stage so a cold session does not have to
find them:

- **Most of Part 8 goes.** `remove`, `insert_after`, `insert_before`, `pop_back`
  have no home in a FIFO or a LIFO, and several Part 18 invariants exist only to
  guard them.
- **The double-insert guard weakens, and this is the sharp one.** `is_linked`
  asks `prev != null || next != null`. With one link, the last item in a queue
  has `next == null` and is **indistinguishable from an item on no queue at
  all** — so the check fails exactly where it matters. The stage must choose a
  mechanism rather than discover the problem later.
- **Two FIFOs delete the anchor and invariant 22** — a real simplification — but
  raise a question the current design never had: what order `close` returns the
  two queues in.
- **It is a specification change, not a port change.** Parts 4, 8 and 11 are in
  `../common/` and dtk and otk read them. The stage recommends; the owner rules.

The port as it stands is untouched and green — four builds, 59 checks, 77 tests,
sanitizers clean. Nothing above is stale yet. It is about to be.

---


## 2026-08-23 — 3TK-9: the sanitizer found the tests, not the port

Written: [3tk-sanitizer-notes-001.md](3tk-sanitizer-notes-001.md),
`3tk/run-sanitizers.sh`. Changed: `3tk/test/t_pool.c3`. Plan versioned to
[005](backup/3tk-staging-plan-005.md); 004 moved to `backup/` with links corrected.
Four builds green, 59 checks. Sanitizers clean, 3 runs, 0 findings.

The last item on the candidate list that could still find a defect in the port
rather than in a document. Plan 003 asked for the concurrency tests "under
whatever sanitizer the toolchain offers" and nobody had measured what that was.
Three stages later, it found something on the first run.

**The tool was there and the machine was not.** c3c 0.8.3 has
`--sanitize=address|memory|thread`. The first attempt failed at link — *cannot
find /usr/lib64/libtsan.so.2.0.0* — and the temptation was to write that down as
a c3c limitation. Two lines of C said otherwise: plain `cc -fsanitize=thread`
fails identically, so Fedora simply does not have the runtimes installed. clang
carries its own, and `c3c --cc clang` points the link at it. No install, no
root, nothing changed on the machine. A stage that needs the owner to install
packages is a stage that does not run on a fresh checkout.

**Then: `ThreadSanitizer: reported 4 warnings`.** All four in `TestHooks` —
`gets++`, `puts++` and the two `last_*_count` writes — with three producers and
three consumers on one pool. The frames that appear in `src/` are `pool.c3:284`
and `:396`, the hook call sites, where the pool has **already unlocked**. The
port put itself in the stack trace by obeying Part 12.3.

**The contract the tests broke is the port's own**, and it is written into
`PoolHooks`'s doc comment as a contract rather than a warning: *hooks run
outside the mutex, several at once, and a hook that touches shared state
protects it itself.* `TestHooks` did not. It had been racing since 3TK-7 while
every build reported green in four modes — because a data race is precisely the
defect a passing test suite cannot see. The stage justified itself on its first
run, and not in the way it expected: it did not find a bug in the toolkit, it
found the toolkit's own tests failing to keep the toolkit's own rule.

**The wrong fix was one line and would have passed.** Hold the pool's mutex
across the hook call and all four warnings vanish — along with Part 12.3, which
exists to keep application code from running under a toolkit lock. A sanitizer
says *there is a race*. It does not say *which side is wrong*, and that
judgement is not the tool's. The counters became `Atomic{usz}`, the same
mechanism the port uses for `_closed_fast`, in the hook where the specification
puts the responsibility.

After the fix: zero warnings on `thread safe -O0`, zero on `thread fast -O3` —
the mode where asserts are gone and the optimizer is most aggressive, and the
one a race would most likely survive into — and AddressSanitizer clean.

**The harness stayed honest.** `run-sanitizers.sh` is a second script, not a row
in `run-builds.sh`, because the gate requires `c3c` and nothing else and that
property is worth more than the coverage. It skips loudly and **exits 2** when
its compiler is absent — *a skip is not a pass* — and it separates *did not
build* from *found something*, which is 3TK-8's harness lesson applied before it
could cost anything twice.

**One fact nine stages had missed.** `c3c --help` carries `--test-noleak:
Disable tracking allocator and memory leak detection for tests.` Leak detection
has been **on by default** in every `c3c test` run this port has ever made, and
no document said so. It takes nothing from 3TK-8's `t_alloc.c3` — that finds
leaks on paths the tests cannot otherwise reach — but a port reading these notes
should know the default exists before building its own.

*Advice on clear: clear.* The stage is closed and the notes carry everything.

---

## 2026-08-23 — 3TK-8: the review answered, and a leak nobody could reach

Written: [3tk-porting-proposal-004.md](3tk-porting-proposal-004.md), the design
of record. `3tk/test/t_alloc.c3`, new. `3tk/src/mailbox.c3` and
`3tk/src/pool.c3`, changed. Proposal 003, the 003 review and addendum 001 moved
to `backup/`, links corrected in place. Four builds green, 59 checks, 0
failures, 77 tests.

The input was `3tk-porting-proposal-003-review.md`: 28 items, about design and
implementation rather than prose. It was read against `3tk/src/` before anything
was accepted, and that audit changed most of the verdicts — five of its items
were already true in the code, three of those in better shape than it assumed.

**D1's argument was wrong for three versions, and its ruling was right the whole
time.** That is why nobody checked it. D1 said hiding the container internals
must cost Part 11.1's MUST, having weighed two shapes; the review found a third
that keeps `Pool` an item and hides only the operational state. The review put
the confusion precisely: Part 11.1 requires *the container is itself an item*,
and D1 assumed that implies *every byte of its state is inside the public
struct*. It does not.

The owner ruled the same day, and the reason is better than the one it replaced:
*"I don't like wars with language. If it does not support the feature + I need
additional allocation — better not change code and add comment and update
docs."* Nine measurements now stand behind it. **M5 is the one that decides the
section** and it came from the owner asking the sharpest version of the
question — restrict fields, not functions, via a `@private` fields-only struct
inlined into the container. Six probes say C3 0.8.3 does not deliver it at any
price: `@private` on a field is refused outright, on a struct it hides the type
*name* only, and `inline` makes it worse by lifting the members into the outer's
namespace. So no shape hides container state while leaving it inside the object.
Hiding costs an allocation per container and buys a convention, not an
enforcement. The port declines, on the record, on cost — **not** on Part 11.1.

**One real defect, and it is the kind that survives reviews.** Neither
`Pool.create` nor `Mailbox.create` cleaned up after a partial failure. The pool
allocated itself, a mutex, a condition variable, then the bucket array — and a
failure at the last leaked all four. Both are transactions now, `defer catch`,
in the shape `std::threads::channel` uses for the same problem.

Two stages and two reviews walked past it, and the reason is worth keeping: the
leak lives in an error path no ordinary test takes, because on Linux `new_try`
does not fail. The port had no way to make an allocator fail. So 3TK-8 built
one, in `test/t_alloc.c3` — its own file, on the owner's instruction, because
`common.c3` is the shared fixture every other test compiles against.

**The test was checked by sabotage, not by passing.** Removing the pool's
`defer catch` lines turns the suite red. Removing the mailbox's leaves it green
— its only acquisition through the caller's allocator is the object itself, so
that path cannot be provoked at all. Both facts are written at the test site.
A test whose failure is impossible is worse than no test, and the honest thing
is to say which is which rather than count four tests and call the fix covered.

**Section 6 is the durable half of this stage.** Six implementation invariants
the port already honoured and no document stated: the pre-lock atomic as a hint
that may reject but never authorize; creation as a transaction; `close` is not
`destroy`; the hook unlock/relock contract and the staleness of everything read
before it; no reference into bucket storage across a hook, with `Pool.get_wait`
named as the one safe exception and why; and the lock order as a statement about
today rather than a timeless property. Plus the `AnyHandle`/`Slot` signature
rule, audited against every public signature, with no violation found — and M4
under it, because a method cannot attach to a pointer alias, so C3 will only let
one of the two be an object.

Deferred with the reason written down rather than dropped: the `NodeList`
mutation core. Removal is already centralized in `unlink_no_repair`; the four
insert sites are different shapes and collapsing them buys less than it costs
while every test is green. Rejected: the opaque `char[N]` storage, for the
reasons the review itself gives against it.

Four text corrections closed the drift the review found: the Part 4.2 mapping
row and D12 still said "a third field" when the inner has three, the 24 bytes
read as an invariant in one row when it is an observation, and Part 15.2's lock
statement was timeless where it should be current.

**No decision moved.** Sixteen decisions, four versions, and D1 reaffirmed after
its argument was found defective — which is the distinction this folder keeps: a
ruling and the reason for it are not the same thing, and only one of them was
wrong.

*Advice on clear: clear.* The stage is closed, the documents carry everything,
and nothing in context is needed by the candidates for a 3TK-9.

---


## 2026-08-23 — 3TK-8's four questions, all ruled before the stage started

The owner answered every open question in the stage, one at a time, so 3TK-8
begins with nothing outstanding. The rulings, and what each changed:

**D1 stands, and the reason is replaced.** Public direct representation, and no
code changes for the sake of hiding. The owner's reason is better than the one
the document currently carries — *no wars with the language.* C3 0.8.3 enforces
no field privacy at any price (addendum 001, M5), so the port declines to buy an
allocation and a lifetime rule per container for a boundary the language will
not keep. A comment marks it instead. The `Impl*` split is rejected on cost, on
the record, and **not** on Part 11.1 — which is the correction `003-review`
asked for, reached from the other direction.

**The capability answers live in proposal 004 only.** `c3-capabilities-001.md`
is the 3TK-4 output and is not amended; no 002 is cut. One home for the
measurements, beside the decision they support.

**The failing-allocator test gets built, in a file of its own.** The owner's
advice, and it is better than the plan's first draft: `3tk/test/t_alloc.c3`
rather than an addition to `common.c3`. `common.c3` is the shared fixture every
test file compiles against, and an allocator that fails on purpose does not
belong in it. The allocators also outlive this stage — counting, failing, an
arena later — and a file named for the subject is where the second one goes
without a discussion. Verified while writing it down: `project.json` declares
`"test-sources": [ "test" ]`, so the harness needs no edit at all.

**The 003 review moves to `backup/`** once 004 answers it, as the first review
did — and only after 004 carries what a current reader needs from it. Until
then it is input and stays live.

Two of the four rulings changed the plan rather than confirming it: the
dedicated test file, and D1's replacement reasoning. Both are in
`3tk-staging-plan-004.md`, and the questions are kept with their answers because
the reasons are part of the design record.

Still no code touched. `3tk/run-builds.sh` last reported four builds green, 59
checks, 0 failures.

---

## 2026-08-23 — D1 ruled again, and the reason replaced

The owner closed the review's central question. D1's **ruling** stands — public
direct representation, `Mailbox` and `Pool` as public structs with their state
stored directly in them — and **no code changes for the sake of hiding.**

The owner's words, because the reason is better than the one D1 currently
gives: *"I don't like wars with language. If it does not support the feature and
I need an additional allocation — better not change code, add a comment and
update the docs."*

That is the whole argument, and it is stronger than what it replaces. 003 says
Part 11.11 is skipped because the only mechanism that delivers it costs Part
11.1's MUST. That was never true, and both `003-review` and addendum 001 M5 show
why. What is true is narrower and harder: **C3 0.8.3 enforces no field privacy
at any price.** Not through `@private` on a struct, which hides the type name
and leaves every field reachable. Not through `inline`, which lifts the fields
into the outer's namespace and makes it worse. Not through `@private` on a
field, which the compiler refuses outright. The shapes that *would* hide the
state — the `Impl*` pointer, the opaque `char[N]` — all work by moving it out
of the object, and they cost an allocation and a lifetime rule per container.

So the port pays nothing for a boundary the language will not keep, and marks
it with a comment instead. Reachable fields plus a documented convention, with
the price visible. The `Impl*` split is rejected **on the record and on cost**,
not on Part 11.1 — which is exactly the correction the review asked for, now
arrived at from the other direction.

3TK-8 carries it: D1's argument rewritten, the field-role comments written, the
documents updated, and no signature moved. One of the stage's four open
questions is closed; three remain and none blocks it.

---

## 2026-08-23 — how C3 binds methods, and what it will not hide

Written: [3tk-porting-proposal-addendum-001.md](backup/3tk-porting-proposal-addendum-001.md).
Not a stage and not a revision — an addendum. It moves no decision, changes no
code, and 3TK-8 folds it into proposal 004.

The owner asked whether C3 supports calling `functionCall(handle, ...)` as
`handle.functionCall(...)`. Four probes against `c3c` 0.8.3 answered it, and
the answer was worth keeping.

**No.** C3 has no UFCS: a free function called with dot syntax is a hard error.
What it has is method functions, `fn void Type.f(&self)`, where the receiver is
written into the declaration. Every dotted call in `3tk/src/` is one of those.
D is the language that does the rewrite, which is where the question came from.

Two things fell out that the folder had never written down. A method may be
declared on a type from **another** module — so no argument about the split
representation may claim it would force methods into one module. And methods
attach to named types and **never to a pointer alias**: `alias AnyHandle =
AnyNode*` can carry no methods, while `typedef Slot` can. The asymmetry between
handle and Slot in every signature in the port is therefore **partly forced by
the language**, not purely a design choice — which gives D5 a second leg and is
the fact the review's §14 signature rule should be stated with.

The probes also reproduced F2 of the toolkit notes from the compiler's own
mouth: *"'@public' modifiers are ignored for method declarations."*

**M5 came from a second question the same day, and it is the one that matters
to D1.** The owner wanted field access restricted without restricting
functions: a `@private` fields-only struct, `inline` inside the public
container, transparent to `mtk`'s own methods and closed to an application. Six
probes say C3 0.8.3 does not deliver it. `@private` on a struct is a
**type-name** rule — another module cannot *name* `MailboxInternals`, which is
real — but every field inside it stays readable, writable and addressable
through the outer, and the write lands. `@private` on a field is refused
outright: *"'@private' cannot be used here."* There is no field-level privacy in
the language.

`inline` makes it worse rather than better. It lifts the hidden fields into the
outer's namespace, so `mb.closed` needs no `.guts` at all. And `inline` must be
the **first** field, which puts it in competition with `AnyNode node` for
position — survivable, since D2 already lets the inner sit anywhere, and the
only part of the idea that was.

The consequence is that the review's central dichotomy is now standing on
measurement instead of inference. **No shape hides container state while
leaving it inside the object.** Hiding costs an indirection — and it does not
cost Part 11.1. That is exactly what `003-review` argued, and D1's rewrite in
proposal 004 can now say it with the probes behind it.

Nothing was touched but documents. `3tk/run-builds.sh` last reported four
builds green, 59 checks, 0 failures.

---

## 2026-08-23 — a second review, and the plan versioned to 004 for it

Written: [3tk-staging-plan-004.md](backup/3tk-staging-plan-004.md), adding **3TK-8**.
Plan 003 moved to `backup/` and every link naming it corrected in place.
`3tk-status.md` updated. Nothing of 3TK-8 has run — no measurement, no
document, no code.

The input is `3tk-porting-proposal-003-review.md`, which arrived in the folder
untracked. It reads proposal 003 for **design and implementation** and says so
in its own scope section: *not advice about improving the document structure or
prose*. That is a different instrument from the first review, and it earned a
different answer.

**Why a stage and not a revision.** Proposal 003 came out of a revision — the
owner accepted the decisions, the review was answered, no plan version was cut.
This one touches `3tk/src/`, adds tests, and needs a measured answer from `c3c`
before its central paragraph can be written. Measurement plus code is
stage-shaped, and the alternative is an unrecorded revision that quietly
rewrites the port. So it got a row, and the plan got a version.

**The audit came before the plan.** The previous review was written against the
proposal text and had never opened `3tk/src/`, which is why most of its findings
were text drift. This one makes claims about the code, so every claim was
checked against the code before the stage's scope was fixed. What that changed:

*The headline is real.* D1 weighs two shapes — public fields, or
`typedef Pool = void` — and concludes that hiding must cost Part 11.1's MUST. A
third shape exists: `struct Pool { AnyNode node; PoolImpl* impl; }`. `Pool` is
still the type the application names, still embeds `AnyNode`, still crosses
through `mtk::helper{Pool}`, still sits on a `NodeList`. The review separates
two requirements D1 collapses — *the container is itself an item*, which Part
11.1 requires, and *every byte of its state is in the public struct*, which D1
assumes follows. It does not follow. The ruling stays; the argument goes.

*Five items were already satisfied, and one better than the review assumed.*
The pre-lock atomic is already a hint with a mandatory re-read. `close` is
already not `destroy`. And §19 asks that no `PoolBucket*` be carried across a
hook call — `Pool.put` already re-looks-up by identity in `take_back_handle`
rather than holding `b` across the unlock. Those become documented invariants,
which is the cheapest and most durable part of the whole review: the code
honours them and no document states them, so a later improvement could undo
them in silence.

*One real defect, and the review could not see it.* §20 asks for `Pool.create`
to be transactional, reasoning about a design it thought might exist. Read
against the code, the defect is real and broader than its framing: **neither
creation path cleans up after a partial failure.** `Pool.create` (`pool.c3:158`)
allocates the `Pool`, then a failure in `_mu.init()!`, `_cv.init()!` or
`new_array_try(...)!` propagates out and leaks it, plus whatever was already
initialized. `Mailbox.create` (`mailbox.c3:78`) is the same shape. The
duplicate-identity check 003 added runs before any allocation, so that part was
already transactional — the allocation sequence never was. Two reviews and two
stages walked past it.

*Four drifts are text-only, and narrower than stated.* Section 1 of 003 already
states the two-parts/three-fields distinction correctly; only the Part 4.2
mapping row and D12 kept the old wording. Nothing in `3tk/src/` asserts
`sizeof(AnyNode) == 24` — checked, not assumed.

*One thing is deferred rather than rejected.* §15 wants a private mutation core
under `NodeList`. Removal is already centralized in `unlink_no_repair`; the four
insert sites are genuinely different shapes, and collapsing them buys less than
it costs while every test is green. Written down so a later stage can take it,
rather than dropped.

3TK-8's plan section carries the whole audit as a table — what the review
claimed, and what the code said back — so the stage starts from evidence rather
than from assertions. Four questions for the owner are in it, and none of them
blocks it from starting.

`3tk/run-builds.sh` still reports four builds green, 59 checks, 0 failures. No
code has been touched yet.

---

## 2026-08-23 — the specification left this folder

Moved: `matryoshka-specification-002.md` and `ztk-audit-001.md` to
[`../common/`](../common/README.md), and specification 001 to
`../common/backup/`. Created `../common/README.md` and
[`../common/port-flow-001.md`](../common/port-flow-001.md). Not a stage, and not
a revision either — nothing was rewritten. A reorganization.

The reason is the review answered earlier the same day. Twenty-seven items were
raised against the C3 proposal and **two of them were specification defects**.
The specification describes itself as language-neutral and self-contained — *a
port is written from this file alone* — yet it lived inside `c3/`, one
consumer's folder. Had those two been fixed only in the C3 document, the same
trap would have stayed set for dtk and otk. A shared input that lives in a
consumer's folder is a fork waiting to happen, so it now lives where it belongs
and every port links to it.

The ztk audit went with it for the same reason: it is read-only evidence about
**Zig**, the reference implementation, and there is nothing C3 in it.

`port-flow-001.md` is new, and it is the 3tk process with C3 removed. Three
tiers, because the failure mode of reusing a proven flow is inheriting the
previous language's answers along with its questions. Tier 1 transfers as
written — cold-start stages, *finishing a stage does not start the next*, the
provenance rule, the three shapes of negative test, **compile judged separately
from run**, and sabotage verification. The compile-versus-run rule carries the
`release_open_pool` story as its reason, because a rule with a corpse attached
is obeyed. Tier 2 transfers only as a question, and the sharpest entry is the
build matrix: **not four builds** — four is this port's `--safe` × `-O` axis, and
a port that copies the number has performed a ritual rather than a verification.

Fourteen links across nine files were rewritten, in both directions, by
resolving each link's basename against where the file actually lives. Zero
dangling links after. The two `.c3` headers naming `matryoshka-specification-001.md`
were left exactly as they are — they mention the file, they do not link to it,
and they are provenance. A path is not a pointer.

`3tk/run-builds.sh` still reports four builds green, 59 checks, 0 failures. The
move touched no code.

---

## 2026-08-23 — the review answered, and a test that never ran

Written: `matryoshka-specification-002.md`, `3tk-porting-proposal-003.md`.
Both predecessors stay on disk. Not a stage — a revision, so no plan version.

The input was `3tk-porting-proposal-review.md`: 27 items against proposal 002,
careful and mostly right. It had been written against the proposal text alone
and had never opened `3tk/src/`, so every item was re-audited against the
specification, the ztk reference, the C3 source and the tests before anything
was changed. That changed several verdicts.

**Two items were not proposal defects at all.** Part 4.2 says the inner has
"exactly two parts" and then warns against "a third field", when `prev`, `next`
and `type` are already three — the proposal had faithfully inherited the
specification's own imprecision. And the review asked which wins when a mailbox
is closed but still holds items, a question the specification leaves open and
its outcome tables invite. It cannot happen: `close` drains the queue in one
step under the mutex and a send after the flag is refused under that same
mutex. ztk agrees. Both went into the specification instead, where the other
three ports will find them, and the second became **invariant 34** — a closed
container is empty.

**One item was rejected.** The review suggested `wake_all` need not report
`CLOSED`. Part 19.1 fixes that outcome set, and the port is right; only the
reason was missing.

**One became code.** `Pool.create` accepted a duplicate identity, and
`bucket_for` returns the first match, so a second bucket for the same identity
would never be found — a pool quietly holding half of what its creator asked
for. It now refuses, tier 2, with a negative program. The owner ruled on this
one directly.

**And building that found something the review could not have seen.**
`negative/release_open_pool.c3` had never compiled. It spelled a type's
identity `Msg.typeid`, which c3c 0.8.3 rejects, and the harness ran
`compile-run` and read any non-zero exit as the abort it was looking for — a
compile failure is a non-zero exit. So the pool half of Part 11.12, *the one
precondition the specification refuses to soften*, the only site that aborts in
all four builds, had been resting on a program that never ran, reported green
the whole time.

The spelling is fixed and the harness now compiles and runs as separately
judged steps, failing loudly on a negative that will not build. The new
duplicate-tag check was sabotaged before being trusted, and the suite went red
in both checking builds as it should.

Four builds green: 59 checks, 73 tests. Part 18 is thirty-four invariants now,
twenty-nine of them tested.

The lesson is D7's, from the other side. D7 was proved by sabotaging a correct
implementation and watching the suite catch it. This was the same lesson unpaid:
a test nobody had ever seen fail, passing for a reason nobody had checked.

---

## 2026-08-23 — the owner's ruling, and the port closes

Written: `3tk-porting-proposal-002.md`. `3tk-porting-proposal-001.md` stays on
disk, superseded.

**The owner accepted all sixteen decisions, and accepted G1's submodules.**
Not a stage — a ruling, which is why it produced no plan version.

The decisions had been marked *PROPOSED — owner overridable* since 3TK-5, which
ran without the ruling it was waiting for. 3TK-6 and 3TK-7 then built them, and
all sixteen survived contact with the compiler. That was the evidence the ruling
had been waiting for, and it is the reason the ruling is one line rather than a
review of sixteen arguments.

Version 002 says *ruling* where 001 said *proposal*. The arguments are unchanged
— each decision still carries the alternative it rejects, because the reason a
thing was chosen outlives the choosing.

Nine amendments folded in, each marked with the finding that produced it, and
**none of them moves a decision**:

- **G1**, the one the owner ruled on separately: the containers are
  `module mtk::mailbox` and `module mtk::pool`, not `module mtk`. Section 1
  now carries the module names beside the file names and says why — a C3
  submodule cannot see its parent's `@private` declarations, so Part 17.2's
  layering is enforced by the compiler rather than promised.
- **F1**, the worst thing 001 got wrong: the safe optimized build is
  `--safe=yes -O3`, not `-O3`. Section 7.2 now says so and says never to infer
  the mode from the `-O` level.
- F3 and F5 on `@check`: not `@private`, and the message is compile-time.
- F4: one alias per declaration; there is no whole-module form.
- G2: `return mtk::CLOSED~;`, because `?` marks the optional type.
- G4: a flat `PoolBucket[]` instead of a `HashMap`.
- G5: `put` involves two Slots, and section 5.9 now says which is which.
- Section 9 became a record of what was built instead of a plan for what might
  be.

The conflict register's seven closures are marked accepted with it.

**The 3tk line of work is complete.** The port covers all of Part 22, all
thirty-three invariants of Part 18 are reached, and `3tk/run-builds.sh` is green
in four builds. What remains is outside the specification: a sanitizer run, a
cross-target build, and packaging.

Advice: **clear.** Nothing is pending.

---

## 2026-08-23 — 3TK-7, the two containers in C3

Written: `3tk/src/mailbox.c3`, `3tk/src/pool.c3`, three more test files, four
more negative programs, and `3tk-containers-notes-001.md`, 299 lines.

The plan was versioned to `3tk-staging-plan-003.md` first. Its only change is
the addition of 3TK-7.

Steps 6 and 7 of Part 22. **The port is now complete against the
specification** — Part 17.1's required tool and both of Part 17.2's optional
ones.

The owner was offered the mailbox/pool split when 3TK-7 was scoped and did not
take it, so both containers were done in one stage. The mailbox was finished
and green before the pool was started, so the seam stayed available throughout.

**Result: all four builds green, 55 checks, 0 failures.** 71 tests run four
times, 6 runtime negatives, 2 tier 1 negatives, 3 compile-time refusals, and 3
layering checks. 37 tests at the end of 3TK-6, 71 now.

The three things plan 003 named in advance all landed.

**D7's wait loop, and a test that can tell.** The trouble with Part 2.5 is that
a wrong implementation passes every ordinary timeout test.
`the_deadline_is_anchored_once` has a second thread broadcast every 20ms for a
second while a waiter asks for 200ms. Anchored, it returns at ~200ms; on
`wait_timeout` every broadcast restarts the timeout. **The test was verified by
sabotage** — `wait_until(deadline)` was swapped for `wait_timeout(timeout)` and
the suite reported `FAILED: 70 passed, 1 failed` with the intended message. The
sabotage was reverted. A test for an invariant of this shape is worth nothing
until it has been seen to fail.

**D6 tier 1 has its first two sites.** `Mailbox.release` and `Pool.release` use
`always_assert` and abort in every build mode, `--safe=no -O3` included.
`run-builds.sh` grew a third negative shape for them: every other negative
asserts opposite behaviours across builds, and a tier 1 negative asserts the
same behaviour in all four. Both programs print `SOFTENED:` if they ever reach
their last line and the script fails on that string.

**Part 12.3.** `hooks_run_outside_the_mutex` has the hook count its own
concurrent entries and hold itself open. Four threads, and if the pool held its
lock the maximum would be one.

Six findings. The first is a structural change and needs the owner:

- **G1. The containers belong in submodules, and C3 makes Part 17.2 free.** The
  proposal put `Mailbox` and `Pool` in `module mtk`, which makes the layering a
  promise checkable only by review. F3 of the toolkit notes — `@private` does
  not reach a submodule — was recorded there as an irritation and is the
  solution here. `module mtk::mailbox` and `module mtk::pool` are structurally
  outside `mtk`, so **Part 17.2 is enforced by the compiler**. The move was not
  free and the compiler said so at once, with six errors demanding
  `mtk::CLOSED` instead of `CLOSED` — which is the enforcement working. The API
  reads better too: `mailbox::create(a)`, `pool::of(h)`. **Recommended as an
  amendment to the proposal's section 1; the owner's to accept.**
- **G2.** The fault-return operator is `~`, not `?`. `return CLOSED~;`. D15
  chose faults and did not spell the return.
- **G3. Part 11.2's shared base cannot be a shared struct.** Part 4.4 allows one
  inner per outer, so a base carrying the inner and embedded in both containers
  gives each an inner one level down. The five members are repeated instead,
  which 11.2's own text permits. Recorded because a reader who takes 11.2 as a
  factoring instruction will build the bug.
- **G4.** A flat `PoolBucket[]` beats the proposal's `HashMap` for a set that is
  fixed at creation and small.
- **G5. `put` involves two Slots, and the proposal did not say so.** The pool
  takes the item from the caller's Slot before the hook sees anything, and
  hands the hook a Slot of its own. Passing the caller's through would make a
  hook that keeps the item read as *refused*.
- G6: small spellings again.

**Sixteen decisions, sixteen exercised, sixteen survived.** Across both code
stages the amendments are two spellings and one structural recommendation, and
none in substance.

**Part 18 is complete.** All thirty-three invariants reached: twenty-eight
tested or provoked, five structural or documented, and each says which.

What is not done, listed honestly in the notes: no sanitizer run — plan 003
asked for one and it was not done, nor was it measured whether c3c 0.8.3 offers
one; the signal hand-off test is a race run 20 times, which is evidence rather
than proof; and linux-x64 is the only target built, where ztk is green on three.

Advice: **clear.** The port is complete and the documents carry it. What is
waiting is the owner's ruling on the sixteen decisions — which now have the
evidence they were waiting for, since all sixteen have survived a compiler — and
G1 as an amendment.

---

## 2026-08-23 — 3TK-6, the toolkit in C3

Written: `3tk/` — 5 source files, 5 test files, 9 negative programs, a
`project.json` and `run-builds.sh` — and `3tk-toolkit-notes-001.md`, 322 lines.

The plan was versioned to `3tk-staging-plan-002.md` first. Its only change is
the addition of 3TK-6; stages 3TK-0 to 3TK-5 are reproduced unaltered. The
provenance lines in the 3TK-1 to 3TK-5 outputs still name plan 001, because
that is the version they ran under; the live pointers in `3tk-status.md` were
repointed.

**The first stage that writes C3.** Steps 2 to 5 of Part 22: the inner and the
identity, the per-type helper with the crossings, the Slot and its six rules,
the list with both insert checks. Part 17.1's one required tool. The two
containers are not here.

The owner named the stage and told it to run in the same breath, without ruling
separately on the sixteen decisions. That was read as acceptance of
`3tk-porting-proposal-001.md` as written, and the plan section says so.

**Result: all four builds green, 44 checks, 0 failures.** 37 tests run four
times, 6 runtime negative programs, 3 compile-time refusals. `run-builds.sh` is
the verification and exits non-zero on any failure.

The negatives are the part that carries weight. Each provokes one contract
violation and asserts **both** halves: it must abort in a checking build, and
it must run to the end and exit 0 in a fast one. A negative that aborted in a
fast build would mean a plain `assert` had survived somewhere.

Nine findings. The first is the one that matters:

- **F1. `-O2` and above turn safe mode off, silently.** The proposal's section
  7.2 spelled the "safe, optimized" build `-O3`. Measured: `-O3` reports
  `SAFE_MODE=false`. So that build was the fast build under another name, and a
  suite run under it tested nothing new. The first run of `run-builds.sh`
  caught it exactly as designed — five negatives reported *did NOT abort in a
  checking build*. The script was right and the proposal was wrong. Every build
  in the port is now explicit on both sides, `--safe=yes` or `--safe=no`, and
  the mode is never inferred from the `-O` level. 3TK-4's Q11 measured the
  default and `--safe=no -O3`; neither exposes the implicit switch. The study is
  short by one row, not wrong.
- **F2. `@private` is ignored on method declarations, entirely.** C3 0.8.3 can
  hide neither a field (Q4) nor a method. This lands on D1 and strengthens it:
  D1 chose the border over the opaque type, and the alternative it did not
  consider turns out not to exist either. `NodeList.contains` and
  `NodeList.unlink_no_repair` are public whether the port likes it or not, and
  the second is named for what it leaves undone.
- **F3. `@private` does not reach a submodule**, so `@check` cannot be private
  as D6's sample wrote it. The resolution is Part 17.2 rather than a
  workaround: an application writing its own Slot-shaped call is entitled to
  the same contract check, so `@check` is public on purpose.
- **F4. A generic module instantiates per declaration, not as a whole.** The
  proposal's section 1 showed `alias msg = mtk::helper{Msg};`. There is no such
  form — nine aliases, or inline instantiation. 3TK-4's Q1 said this and the
  proposal contradicted it.
- F5 to F9: `always_assert` takes a compile-time message; a module-scope
  `$assert` cannot see a generic module's type parameter; `alloc::new` aborts
  and `alloc::new_try` is what Part 9.2 rule 4 needs; eight small spellings the
  proposal guessed at; and there is no front door to write, because in C3 the
  module is the front door.

**The sixteen decisions: nine exercised, nine survived.** Nothing the code met
contradicted a decision. D3 and D6 were amended in spelling only, by F6/F7 and
F5. Seven are untouched because they belong to the containers — D7, D9, D13,
D14, D16 — or are barely reachable here, D15.

Part 18: the toolkit reaches twenty invariants and fifteen are tested or
provoked; rows 6 and 14 are structural and say so.

One thing worth keeping. D12 accepted the link test's blind spot, and an
accepted cost that is only documented gets "fixed" by the next reader.
`the_link_test_has_a_blind_spot` asserts that an item alone on a list reports
false, so closing the blind spot fails a test that names D12. Its mirror,
`the_walk_has_a_blind_spot_too`, states the other half of Part 8.6's argument.

Three places where the specification is silent and the code had to choose are
recorded in the notes as findings rather than taken quietly: inserting from an
empty Slot, removing an item that is not on this list, and null as the answer
from an empty list.

The stage created the tree at the repository root by mistake and moved it under
`c3/3tk/` before anything was committed. The storage rule holds.

Advice: **clear.** The container stage, if the owner names it, reads the
proposal, the specification and `3tk-toolkit-notes-001.md`. The notes carry
what the code taught; the code carries the rest. What must not be lost is F1,
and it is written in three places — the notes, this entry, and a comment block
in `run-builds.sh` itself.

---

## 2026-08-23 — 3TK-5, the 3tk porting proposal

Written: `3tk-porting-proposal-001.md`. 984 lines.

Inputs: `matryoshka-specification-001.md`, `3tk-drafts-review-001.md`,
`c3-capabilities-001.md`, and this folder's status file. The seven drafts were
not reopened. `src/` was not reopened. No C3 was compiled in this stage — 3TK-4
did the compiling, and this stage reads its results.

**The stage ran without the two owner rulings it was waiting on.** `3tk-status.md`
recorded 3TK-5 as blocked on the C1-to-C11 ruling and on Q4. Neither had been
given. A porting proposal is the document where such rulings are *proposed*, so
every open decision is decided in it, argued, and marked **PROPOSED — owner
overridable**. Nothing in the file is settled until the owner says so.

Sixteen decisions, D1 to D16. They absorb the eight items the capability study
carried forward, the eleven of the conflict register, and the ten of Part 20.

The four that carry weight:

- **D1, Q4.** Public struct, public fields, the helper border does the work.
  Part 11.11 SHOULD is skipped with the reason written down: the only C3
  mechanism that delivers it — `typedef Pool = void` — costs Part 11.1 MUST,
  the containers being themselves items. A SHOULD is not traded for a MUST.
- **D3, the allocators.** Answered per type rather than once for the port. The
  inner does not grow a third field (Part 4.2, every item pays). An item that
  wants a release with no allocator parameter keeps the allocator in its own
  *outer* and takes `mtk::owned <Type>`, whose build-time `$assert` finds the
  field and, when it is missing, names the other helper in the message. C7 and
  the status file's first open question are answered together, as the review
  required.
- **D6, the assert policy.** Q11's trap — a plain `assert` under `--safe=no -O3`
  is an assumption the optimizer may act on, not a removed check — is routed
  around rather than documented. One port macro, `mtk::@check`, expands to
  `always_assert` in a safe build and to *nothing* otherwise. Three tiers:
  `always_assert` for Part 11.12 alone, `@check` for every other contract
  violation, a `$if COMPILER_SAFE_MODE` block for Part 8.6's O(n) walk. No
  plain `assert` guards a contract anywhere in the port.
- **D5 with D4.** The Slot is a distinct `typedef`; the handle is a transparent
  alias and there is only one of it. The cast cost that sinks typed handles
  (C10) does not arise for the Slot, because every function that takes one takes
  `Slot*` by design. The two-star confusion four drafts fell into no longer
  typechecks.

Also decided: no `inline` on the inner field (D2, for Part 7.5 and Part 10.1);
interruption dropped (D9, as Part 2.9's own text permits); two composing generic
modules instead of ztk's branching generator (D10); Part 22's order kept (D11);
`NodeList`, not `AnyList`, because `std::collections::anylist` exists and
copies (D8); faults as the outcome mechanism (D15); the pre-lock fast path kept
with its mandatory re-check (D16).

The mapping covers every MUST and SHOULD of Parts 1 to 17, part by part, with
the full sixteen-operation list surface (C6), the three hook signatures as the
specification requires them, and both container surfaces with their outcome
sets. `put` and `put_all` return `void`, not `void?` — Part 9.4, the Slot is the
answer.

Six things are dropped: two SHOULDs with written reasons, three MAYs whose
conditions are not met, and the `interrupted` outcome as a consequence of D9.

Build and test: one `project.json`, closing C9 with a third shape rather than
choosing between two that were never compiled, and **four builds, every time**.
The fourth — `--safe=no -O3` — is the one that segfaulted in Q11's probe, and
running it is what proves D6 was applied. The layering claim of Part 17.2 is
made a test: `mailbox.c3` and `pool.c3` reference no `@private` name of the core
four.

All eleven conflicts are now closed — four by 3TK-4, seven here, every one of
the seven overridable.

`kitchen/tools/check_design.sh` still exits 1, unchanged in cause. This file adds
one orphan row for the same `context.md` drift 3TK-2 hit. Not a regression, and
not fixed here.

Advice: **clear.** 3TK-6, if the owner names it, writes C3 from the proposal and
the specification. Nothing in this stage's reasoning is needed once the file is
on disk — the file *is* the reasoning. What must not be lost is the state of the
sixteen decisions, and that lives in `3tk-status.md`.

---

## 2026-08-23 — 3TK-4, the C3 capability study

Written: `c3-capabilities-001.md`. 740 lines.

Inputs: the C3 stdlib at `/home/g41797/dev/langs/c3/lib/std/`, Part 21 of the
specification, and the conflict register of `3tk-drafts-review-001.md`. The
drafts themselves were not reopened. `src/` was not reopened.

Toolchain measured: `c3c` 0.8.3, git `1d155ee`, LLVM 22.1.8, linux-x64.

Method. Twelve probes, compiled and run, three of them negative — written to
fail, with the compiler message as the evidence. Every answer is marked
*verified* (compiled) or *read* (stdlib source only). Probe sources are
reproduced inside the document rather than kept as files, so it is
self-contained.

Result: eleven of the twelve questions are a clean yes.

- Q1 generic modules. A full per-type helper, Part 7.2's seven members, was
  generated for two outer types and exercised, including the moving crossing on
  a mismatch.
- Q2 `typeid` satisfies every clause of Part 5.1. Two identically-shaped
  structs carry different values. This closes C1.
- Q3 both embeddings work. `inline` gives an implicit conversion; `::members`
  gives the offset, so the inner may sit anywhere. Part 4.3's offset-zero
  fallback is not needed.
- Q4 is the one real no. **C3 0.8.3 has no private struct fields**, and a
  public alias to a `@private` struct re-exports the layout. A
  `typedef Pool = void` does hide, at the cost that the container is no longer
  literally the struct embedding the inner. Two drafts build on private fields.
- Q5 interfaces with `@dynamic`. An interface value is nullable and carries the
  concrete typeid. The specification's own hook signatures compile; the three
  in `3tk-additions.md` were a misreading, not a C3 limit.
- Q7 threads, mutex, and **three** condition waits, one of them `wait_until` on
  an absolute deadline. Part 16 row 7 — ztk's 71 hand-written lines — is
  deleted. The relative `wait_timeout` recomputes the deadline on every call,
  so a loop built on it silently violates Part 2.5.
- Q11 has a trap. A plain `assert` is active in a safe build, a no-op at
  `--safe=no -O0`, and an optimizer assumption at `--safe=no -O3` — where a
  violated one is undefined behaviour, not a missed check. `always_assert`
  aborts in every mode, which is what Part 11.12 needs.
- Q12 `$Type::members` with `.name`, `.type`, `.offset`. Part 7.4's validation
  runs at build time and names the offending type, verified.

Also found, in no draft: `any` is reserved as a module name but `Any` is a
usable type name, which closes C3; a struct name that is all uppercase is
rejected; and `std::collections::anylist` already exists and shallow-copies
every element, which is the semantic opposite of the Matryoshka list under the
name the drafts chose for it.

Rulings delivered on the register: C1 and C3 closed, C5 closed on the
mechanism, C2 and C10 priced but left open, C7 narrowed, C4 C6 C8 C9 C11
untouched as not C3 questions. One question reopened that the drafts had
settled: Q4.

*Advice on clear: yes. 3TK-5 reads this document, not this reasoning.*

---

## 2026-08-23 — 3TK-3, the drafts review

Written: `3tk-drafts-review-001.md`. 462 lines.

Inputs: the seven `c3/` drafts, `matryoshka-specification-001.md`,
`ztk-audit-001.md`. Nothing else was opened. `src/` was not reopened.

Shape of the file:

- One table per draft. One row per claim, with a verdict, the conflicting
  draft where there is one, and a recommendation.
- Six verdicts: HOLDS, GAP, CONFLICT-S against the specification, CONFLICT-D
  against another draft, UNVERIFIED for a C3 language claim, OUT for anything
  outside the specification's subject.
- Section 8 lists what no draft covers: 22 parts, and 12 of the 33 invariants
  of Part 18.
- Section 9 is the conflict register, C1 to C11. Each names both sides and
  what the specification says.
- Section 10 is what to carry into 3TK-4 and 3TK-5.

What the review found.

- 117 claims measured across the seven files.
- `3tk-poc.md` is the outlier. Its node has no type identity field, so Parts 5,
  6 and 7 have nothing to stand on, and its pool has one free list instead of
  one per identity. It also ships a `Master`, which Part 1.3 forbids by name.
  Its wait loop restarts the timeout on every spurious wakeup, against Part
  2.5. It predates the other six by three days.
- `3tk-porting-notes.md` is the best of the seven. Its verification rule — what
  is confirmed architecture versus what needs a compilable prototype — is Part
  21 arrived at independently.
- Four drafts assume C3 `typeid` satisfies Part 5.1 and none of them checks it.
  `ztk-to-3tk.md` flagged it as the dangerous area and was ignored. That is
  conflict C1 and it is 3TK-4's first question.
- All four drafts that name the Slot attach the word to the pointer-to-Slot
  rather than to the Slot. The representation they propose is right. Conflict
  C4, and `3tk-porting-notes.md` has it in its *confirmed* column.
- The hooks interface of `3tk-additions.md` picks the mechanism the
  specification leans to, then gets all three signatures wrong against Part
  12.2, and drops `tags`, which Part 11.7 needs.
- `3tk-build-dist.md` and `3tk-poc.md` both describe a fourth layer — Master,
  Select, Group, Future — that Part 1.2, Part 1.3 and Part 16 all deny.

Nothing was resolved. Eleven conflicts are registered and the owner rules.

Recommended retirement: `3tk-poc.md` and `ztk-to-3tk.md`, kept on disk.

*Advice on clear: no. The ruling on C1 to C11 needs this reasoning in context.*

---

## 2026-08-23 — 3TK-2, the portable specification

Written: `matryoshka-specification-001.md`. 22 numbered parts, plus Part 0 for
the conformance markings and Part 21 for the questionnaire.

Inputs: `ztk-audit-001.md` and this plan. `src/` was not reopened, as the plan
required.

Shape of the file:

- Part 0 defines MUST, SHOULD, MAY, EXCLUDED. Every element in Parts 1 to 20
  carries one.
- Parts 1 to 15 are the owner's spine, one section each, in the owner's order.
- Part 16 is the excluded surface, twelve rows, from `audit 4`.
- Part 18 restates every MUST as a 33-row table, in the order a port meets
  them.
- Part 19 is the outcome set, as values, with no error sets.
- Part 20 is the ten decisions each port makes for itself.
- Part 21 is the questionnaire, twelve questions, each with a "if no" line
  naming what the port pays instead.
- Part 22 is a suggested porting order. Not conformance.

Decisions taken while writing, and why:

- **The heading "execution model" was not used.** Both words are on the banned
  list of `rules-049.md` Part 5. The plan names that section. Part 2 is called
  "Threads and waiting" and says so in its first line.
- **The word "idiomatic" was not used** either, for the same reason. The plan
  uses it. The specification says "the port's business" instead.
- **The questionnaire grew from ten questions to twelve.** The plan listed
  eight subjects. The audit's draft list had ten. Two more earned a place:
  build modes, because Part 8.6 and Part 15.5 both depend on whether an assert
  can be compiled out; and compile-time reflection on fields, which is separate
  from compile-time generation and a language can have one without the other.
- **The excluded surface was compressed from 16 rows to 12.** Four of the
  audit's rows are the same declaration counted on both containers. The
  specification is language-neutral, so it names the declaration once.
- **Two spellings were added to Part 16 that the audit did not call excluded**
  — error sets as the return channel, and the marker constant that selects the
  reduced helper. Both are `audit 3` rows marked incidental. Neither is a
  semantic, and a port that copies them has copied Zig.
- **The waiting-get contradiction was resolved toward the code.** Part 11.9
  says the waiting get never creates, and records that the book disagrees. The
  audit's ruling, carried forward.
- **The allocator was written as SHOULD, not MUST.** Part 13.1 states the
  intended shape. Part 13.3 records that ztk is not there. Part 13.4 leaves the
  application-item half open for 3TK-5, as the audit asked.

What the writing produced that the plan did not predict:

- The link-test blind spot (`audit 2.2`) is not a Zig detail. It is a design
  line that every port meets, and it costs a field per item to close. It became
  Part 8.7, a MUST, and a decision in Part 20.
- The memory-ordering half of a transfer (`audit 2.8`) is invisible in every
  signature and is the reason the toolkit needs no locks around application
  data. It became Part 14.2, and it is the invariant most likely to be lost in
  a port that reads only the signatures.
- Part 17 is not in the plan's list. The three tools with two optional is in
  the plan's second paragraph of the stage, and it turned out to be the test of
  the layering *and* the porting order. It earned its own part.

Length: 1366 lines against the plan's expected 600-900. The staccato rule of
`rules-049.md` Part 6 is one fact per line, and 33 invariants plus 12 questions
plus 22 parts do not compress below this without dropping facts. Flagged for
the owner. Nothing was padded; nothing was cut to fit.

Verification:

- Banned-word scan of the new file: four hits, two fixed ("holds" in the
  custody sense, "underneath"), two kept. `unlock` is the mutex operation.
  `holds` in "this holds for" is the truth sense, not custody.
- `kitchen/tools/check_design.sh` exits 1, not the 0 the plan expected. It
  exited 1 before this stage too. 43 problems: 14 dead links in `design/`, and
  29 orphans, every one of them under `design/secondary/lang/`. This stage
  added exactly one row — the new specification file — and it is the drift
  already recorded as `audit 7.1`: `design/secondary/context.md` does not list
  the `lang/` subfolders at all. Not fixed. Owner's call.

---

## 2026-08-23 — 3TK-1, the ztk audit

Read-only stage. Five `src/` files and eight documents, nothing else. The
firewall against the seven `c3/` drafts was kept.

Written: `ztk-audit-001.md`. Seven sections, as the plan named them.

What the reading produced that the plan did not predict:

- The excluded surface is 16 declarations, not a vague "the Io parts". Twelve
  of them vanish outright in a language whose condition variable has a timed
  wait. `src/internal/cond_timeout.zig` is 71 lines that exist for one missing
  standard-library call.
- The allocator gap is wider than "ztk is not exactly there". Both containers
  already keep an allocator at creation — and both `destroy` functions take
  another one as a parameter and use *that*, never the kept one. Nothing checks
  the two match. Application items keep none at all, and `PolyNode` has no field
  for one.
- Five more intended-versus-actual gaps beside the allocator. The largest:
  `Pool.get_wait` does not call `on_get`, and the book says twice that it does.
  The code is the truth.
- Four pieces of documentation drift, none of which touches `src/`. The
  architecture note still shows the pre-API-12 handle shape, and the Zig-0.16
  notes still say `_Mailbox` / `_Pool`.

Three invariants the plan did not list, found in the code and worth a section
each in the specification:

- The deadline is anchored once, before the retry loop. Converting a duration
  inside the loop restarts the timeout on every spurious wakeup. Both waiting
  functions say so in the same words.
- A waiter that leaves on timeout or cancel re-signals if the container is not
  empty. Without it a pending signal dies with the leaver.
- The transfer orders memory. The new holder sees every write the previous one
  made, because the container publishes through its own mutex. That is why the
  toolkit can assert on an item's internal state at all, and it appears in no
  signature.

Judgement calls recorded in the audit rather than made silently:

- `Mbox.wakeUpAll` is *not* an Io bridge and stays in scope. It has its own
  epoch mechanism.
- Table dispatch's "no switch over tags" is a Zig obstacle, not a Matryoshka
  invariant. The invariant it protects — one handler per (receiver, tag) pair,
  the Slot carries the result — is portable.
- Whether `send_oob` survives a port is left open. It is one priority level,
  and it exists because the two-channel model folds signals into the data
  channel as tagged items at the front.

44 features classified essential / should / may / incidental / excluded, one row
each with its reason. The recurring verdict is "shape essential, spelling free":
the tag, the compile-time helper, the hooks interface and scope-exit cleanup are
all required in shape and free in spelling.

Advice: clear. The specification works from `ztk-audit-001.md`, not from the
reading. Nothing in this session's context is needed by 3TK-2 that the audit
does not carry.

## 2026-08-23 — 3TK-0, the staging plan

The port family got its names: otk (Odin), ztk (Zig), 3tk (C3), dtk (D). 3tk is  
the active target. otk is refactored later, ztk tuned later, dtk is thinking  
only.

The owner set the storage rule first: every file for this work — plans, status,  
log, outputs — lives in `design/secondary/lang/c3/`. The main `design/STATUS.md`  
and `STATUS-LOG.md` stay untouched. Plans do not live in Claude memory.

The seven drafts already in this folder were written at different times by  
different AIs and contradict each other. That is what made a specification  
necessary rather than a porting note: without a yardstick, the contradictions  
propagate into whatever gets written next.

The owner gave the spine of the specification directly:

- plain threads, not fibers, not goroutines
- participants are long-lived heap objects
- intrusion — an embedded inner structure carrying the list links
- identity of the outer, carried in the inner
- self-identification by comparing against that identity
- a compile-time-generated per-type helper: initializer plus the conversions
  across the type-erased border
- an intrusive list for heterogeneous items
- the Slot idiom, a container of pointers
- deliberate synonyms — handle, slot, item — kept, not collapsed
- Mbox and Pool on one internal base, implementations hidden where the language
  allows, hooks as an interface
- allocators taken at creation and held for life — the direction, not yet
  exactly what ztk does

Two rulings on vocabulary. **inner** and **outer**, never "parent", because  
"parent" names a different relation in each language. And porting is not  
transpiling: idiomatic code per language, the tag being the example — hand-rolled  
in ztk, native in C3.

Two exclusions. Everything built for the `std.Io` bridge is out of scope for  
ports, and the specification must be self-contained, with only the three `src/`  
files as external reference — so it can serve dtk as well as 3tk.

Advice given and accepted on the shape of the specification: conformance  
markings (MUST / SHOULD / MAY / EXCLUDED) on every element, and a closing  
capability questionnaire that each language answers in turn. That questionnaire  
is what makes the later proposal stages mechanical without making them  
transliterations.

Two changes the owner made to the proposed staging: the review stage was named  
"ledger", which was rejected as unclear, and is now **3TK-3 drafts review**; and  
the C3 install step was dropped, because C3 is already installed —  
`/usr/bin/c3c`, stdlib at `/home/g41797/dev/langs/c3/lib/std/`.

The owner added the cold-start rule: every stage must be runnable after a  
context clear, and every stage must end by advising whether to clear.

Written: `3tk-staging-plan-001.md`, `3tk-status.md`, `3tk-log.md`.

Follow-up the same day, at the owner's instruction: the cold-start rule was
incomplete without a way to *invoke* a stage. Each stage now prints the exact
line the owner types to start it after a clear, and the status file repeats the
next one. A stage closes by naming the command for the next. Without that, cold
start meant "the agent could run it", not "the owner can start it".

## 2026-08-23 — versioning ruled

The three files created for 3TK-0 were inconsistent: all carried a `-001`
suffix, and all three were then edited in place, which Part 0 forbids.

Owner's ruling: the same three-way split `design/` already uses.

- `3tk-status.md` and `3tk-log.md` lose the suffix and are edited in place. They
  are entry points, not documents — the analogues of `STATUS.md` and
  `STATUS-LOG.md`.
- The plan keeps its suffix. A change makes `3tk-staging-plan-002.md`, and the
  superseded version stays on disk, listed in the status file.
- Every stage output is versioned the same way.

That created one problem and fixed it in the same move. The start command named
the plan by version, and a versioned filename moves, so every bump would have
broken the line the owner types. The command now names `3tk-status.md`, which
never moves and which says which plan version is current.

Renamed: `3tk-status-001.md` to `3tk-status.md`, `3tk-log-001.md` to
`3tk-log.md`. Both were created the same day and untracked, so no `git mv` was
involved. Every cross-reference repointed.

Owner's ruling on the same day: the plan stays `3tk-staging-plan-001.md`. The
edits made during 3TK-0 — the start commands, the versioning section — are part
of its initial version, not revisions of a published one. Nothing referenced it
yet. Versioning is strict from here: the next change makes `-002`.
